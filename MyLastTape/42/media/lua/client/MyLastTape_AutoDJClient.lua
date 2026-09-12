require "intents/NMClientIntentDispatch"
require "MyLastTape_Metadata"

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"
local MODDATA_KEY = "MyLastTape"
local PLAYLIST_KEY = "playlist"
local BRIDGE_KEY = "insertedCassette"

local function isMultiplayerClient()
    return NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true
end

local function itemId(item)
    if item and item.getID then
        return tostring(item:getID() or "")
    end
    return ""
end

local function deviceIdentity(device)
    local id = itemId(device)
    local uuid = NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid
        and NMInventoryHelpers.getItemStateUuid(device)
        or ""
    return "id=" .. id .. " uuid=" .. tostring(uuid or "")
end

local function playlistFingerprint(playlist)
    if not (MyLastTapeAutoDJ and MyLastTapeAutoDJ.playlistFingerprint) then
        return "unavailable"
    end
    return MyLastTapeAutoDJ.playlistFingerprint(playlist)
end

local function findItemById(player, id)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not (inventory and NMInventoryHelpers and NMInventoryHelpers.findItemById) then
        return nil
    end
    return NMInventoryHelpers.findItemById(inventory, id)
end

local function findSourceCassette(player, args)
    local payload = args or {}
    if NMInventoryHelpers and NMInventoryHelpers.findAccessibleItemByIdOrUuid then
        local accessible = NMInventoryHelpers.findAccessibleItemByIdOrUuid(
            player,
            payload.mediaItemId,
            payload.mediaItemUuid
        )
        if accessible then
            return accessible
        end
    end
    return findItemById(player, payload.mediaItemId)
end

local function saveDeviceBridge(device, cassetteState)
    if not (device and device.getModData and MyLastTapeMetadata) then
        return false
    end
    local copy = MyLastTapeMetadata.cloneState(cassetteState)
    local md = device:getModData()
    md[MODDATA_KEY] = md[MODDATA_KEY] or {}
    md[MODDATA_KEY][BRIDGE_KEY] = copy
    -- Phase 1 used this as persistent device state. A device must never be
    -- the source of a cassette playlist, so remove that legacy data.
    md[MODDATA_KEY][PLAYLIST_KEY] = nil
    md[MODDATA_KEY].hasRecordedPlaylist = nil
    return true
end

local function readDeviceBridge(device)
    if not (device and device.getModData and MyLastTapeMetadata) then
        return nil
    end
    local state = device:getModData()[MODDATA_KEY]
    local bridge = type(state) == "table" and state[BRIDGE_KEY] or nil
    if type(bridge) ~= "table" then
        return nil
    end
    local copy = MyLastTapeMetadata.cloneState(bridge)
    return copy
end

local function clearDeviceBridge(device)
    if not (device and device.getModData) then return end
    local state = device:getModData()[MODDATA_KEY]
    if type(state) == "table" then
        state[BRIDGE_KEY] = nil
        state[PLAYLIST_KEY] = nil
        state.hasRecordedPlaylist = nil
    end
end

local function snapshotMyLastTapeIds(player)
    local seen = {}
    local inventory = player and player.getInventory and player:getInventory() or nil
    local items = {}
    if inventory and NMInventoryHelpers and NMInventoryHelpers.collectItemsRecursive then
        NMInventoryHelpers.collectItemsRecursive(inventory, items)
    end
    for i = 1, #items do
        local candidate = items[i]
        if candidate and candidate.getFullType and tostring(candidate:getFullType() or "") == MEDIA_FULL_TYPE then
            seen[itemId(candidate)] = true
        end
    end
    return seen
end

local function findProducedCassette(player, beforeIds)
    local inventory = player and player.getInventory and player:getInventory() or nil
    local items = {}
    if inventory and NMInventoryHelpers and NMInventoryHelpers.collectItemsRecursive then
        NMInventoryHelpers.collectItemsRecursive(inventory, items)
    end
    for i = 1, #items do
        local candidate = items[i]
        if candidate and candidate.getFullType
            and tostring(candidate:getFullType() or "") == MEDIA_FULL_TYPE
            and not beforeIds[itemId(candidate)]
        then
            return candidate
        end
    end
    return nil
end

local function isMyLastTapeInsert(args)
    local payload = args or {}
    return tostring(payload.mediaFullType or payload.mediaEjectFullType or "") == MEDIA_FULL_TYPE
end

if isMultiplayerClient() then
    print("[MyLastTape] AutoDJ disabled in multiplayer for MVP-0.6")
elseif NMClientIntentDispatch and NMClientIntentDispatch._myLastTapeAutoDJWrapped ~= true then
    local originalPerformIntent = NMClientIntentDispatch.performIntent

    NMClientIntentDispatch.performIntent = function(player, item, action, args)
        local name = tostring(action or "")

        if name == "insert_media" and isMyLastTapeInsert(args) then
            local sourceCassette = findSourceCassette(player, args)
            if not sourceCassette then
                print("[MyLastTape] Insert blocked: source cassette not found")
                return false, "cassette_source_not_found"
            end
            local cassetteState = MyLastTapeMetadata.readState(sourceCassette)
            local playlist = cassetteState.playlist

            if cassetteState.recorded == true and type(playlist) == "table" and #playlist > 0 then
                print("[MyLastTape] mode=load-cassette cassetteId=" .. itemId(sourceCassette)
                    .. " " .. deviceIdentity(item)
                    .. " tracks=" .. tostring(#playlist)
                    .. " fingerprint=" .. playlistFingerprint(playlist))
                MyLastTapeAutoDJ.registerPlaylist(playlist)
            else
                playlist = nil
                cassetteState.playlist = nil
                cassetteState.recorded = false
                if MyLastTapeAutoDJ and MyLastTapeAutoDJ.clearRegisteredPlaylist then
                    MyLastTapeAutoDJ.clearRegisteredPlaylist()
                end
                print("[MyLastTape] mode=insert-blank cassetteId=" .. itemId(sourceCassette)
                    .. " " .. deviceIdentity(item))
            end

            print("[MyLastTape] Playlist tracks: " .. tostring(playlist and #playlist or 0))
            local inserted, insertReason = originalPerformIntent(player, item, action, args)
            if inserted == true then
                saveDeviceBridge(item, cassetteState)
            end
            return inserted, insertReason
        end

        if name == "play" then
            local cassetteState = readDeviceBridge(item)
            if cassetteState and cassetteState.recorded ~= true then
                print("[MyLastTape] Blank cassette: playback blocked")
                return false, "blank_cassette"
            end
        end

        if name == "eject_media" then
            local cassetteState = readDeviceBridge(item)
            if not cassetteState then
                return originalPerformIntent(player, item, action, args)
            end

            local beforeIds = snapshotMyLastTapeIds(player)
            local ejected, ejectReason = originalPerformIntent(player, item, action, args)
            if ejected ~= true then
                return ejected, ejectReason
            end

            local producedCassette = findProducedCassette(player, beforeIds)
            if producedCassette and MyLastTapeMetadata.writeState(producedCassette, cassetteState) then
                clearDeviceBridge(item)
                print("[MyLastTape] mode=eject-save cassetteId=" .. itemId(producedCassette)
                    .. " " .. deviceIdentity(item)
                    .. " tracks=" .. tostring(cassetteState.playlist and #cassetteState.playlist or 0)
                    .. " fingerprint=" .. playlistFingerprint(cassetteState.playlist))
            else
                print("[MyLastTape] eject-save failed: produced cassette not found; bridge retained")
            end
            return ejected, ejectReason
        end

        return originalPerformIntent(player, item, action, args)
    end

    NMClientIntentDispatch._myLastTapeAutoDJWrapped = true
    print("[MyLastTape] AutoDJ intent hook installed")

    -- Vehicle radios use a separate dispatch entry point in New Music. Keep
    -- the same cassette bridge on the radio part so ejecting recreates the
    -- physical tape with its playlist, name and visual variant intact.
    if type(NMClientIntentDispatch.performVehicleIntent) == "function"
        and NMClientIntentDispatch._myLastTapeVehicleAutoDJWrapped ~= true
    then
        local originalPerformVehicleIntent = NMClientIntentDispatch.performVehicleIntent

        NMClientIntentDispatch.performVehicleIntent = function(player, vehicle, part, action, args)
            local name = tostring(action or "")

            if name == "insert_media" and isMyLastTapeInsert(args) then
                local sourceCassette = findSourceCassette(player, args)
                if not sourceCassette then
                    print("[MyLastTape] Vehicle insert blocked: source cassette not found")
                    return false, "cassette_source_not_found"
                end
                local cassetteState = MyLastTapeMetadata.readState(sourceCassette)
                local playlist = cassetteState.playlist

                if cassetteState.recorded == true and type(playlist) == "table" and #playlist > 0 then
                    MyLastTapeAutoDJ.registerPlaylist(playlist)
                else
                    cassetteState.playlist = nil
                    cassetteState.recorded = false
                    if MyLastTapeAutoDJ and MyLastTapeAutoDJ.clearRegisteredPlaylist then
                        MyLastTapeAutoDJ.clearRegisteredPlaylist()
                    end
                end

                local inserted, insertReason = originalPerformVehicleIntent(player, vehicle, part, action, args)
                if inserted == true then
                    saveDeviceBridge(part, cassetteState)
                    if vehicle and vehicle.transmitPartModData then
                        vehicle:transmitPartModData(part)
                    end
                    print("[MyLastTape] mode=vehicle-load-cassette cassetteId=" .. itemId(sourceCassette)
                        .. " vehicleId=" .. tostring(vehicle and vehicle.getId and vehicle:getId() or "")
                        .. " partId=" .. tostring(part and part.getId and part:getId() or "")
                        .. " tracks=" .. tostring(playlist and #playlist or 0)
                        .. " fingerprint=" .. playlistFingerprint(playlist))
                end
                return inserted, insertReason
            end

            if name == "play" then
                local cassetteState = readDeviceBridge(part)
                if cassetteState and cassetteState.recorded ~= true then
                    print("[MyLastTape] Blank vehicle cassette: playback blocked")
                    return false, "blank_cassette"
                end
            end

            if name == "eject_media" then
                local cassetteState = readDeviceBridge(part)
                if not cassetteState then
                    return originalPerformVehicleIntent(player, vehicle, part, action, args)
                end

                local beforeIds = snapshotMyLastTapeIds(player)
                local ejected, ejectReason = originalPerformVehicleIntent(player, vehicle, part, action, args)
                if ejected ~= true then
                    return ejected, ejectReason
                end

                local producedCassette = findProducedCassette(player, beforeIds)
                if producedCassette and MyLastTapeMetadata.writeState(producedCassette, cassetteState) then
                    clearDeviceBridge(part)
                    if vehicle and vehicle.transmitPartModData then
                        vehicle:transmitPartModData(part)
                    end
                    print("[MyLastTape] mode=vehicle-eject-save cassetteId=" .. itemId(producedCassette)
                        .. " vehicleId=" .. tostring(vehicle and vehicle.getId and vehicle:getId() or "")
                        .. " partId=" .. tostring(part and part.getId and part:getId() or "")
                        .. " tracks=" .. tostring(cassetteState.playlist and #cassetteState.playlist or 0)
                        .. " fingerprint=" .. playlistFingerprint(cassetteState.playlist))
                else
                    print("[MyLastTape] vehicle eject-save failed: produced cassette not found; bridge retained")
                end
                return ejected, ejectReason
            end

            return originalPerformVehicleIntent(player, vehicle, part, action, args)
        end

        NMClientIntentDispatch._myLastTapeVehicleAutoDJWrapped = true
        print("[MyLastTape] Vehicle AutoDJ intent hook installed")
    end
end
