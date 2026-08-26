require "intents/NMClientIntentDispatch"

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"
local MODDATA_KEY = "MyLastTape"
local PLAYLIST_KEY = "playlist"
local BRIDGE_KEY = "insertedPlaylist"
local SCHEMA_VERSION = 1

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

local function readCassettePlaylist(cassette)
    if not (cassette and cassette.getModData and MyLastTapeAutoDJ and MyLastTapeAutoDJ.clonePlaylist) then
        return nil
    end
    local state = cassette:getModData()[MODDATA_KEY]
    local playlist = type(state) == "table" and MyLastTapeAutoDJ.clonePlaylist(state[PLAYLIST_KEY]) or nil
    if type(playlist) == "table" and #playlist > 0 then
        return playlist
    end
    return nil
end

local function writeCassettePlaylist(cassette, playlist)
    if not (cassette and cassette.getModData and MyLastTapeAutoDJ and MyLastTapeAutoDJ.clonePlaylist) then
        return false
    end
    local copy = MyLastTapeAutoDJ.clonePlaylist(playlist)
    if #copy < 1 or (MyLastTapeAutoDJ.isFallbackPlaylist and MyLastTapeAutoDJ.isFallbackPlaylist(copy)) then
        return false
    end
    cassette:getModData()[MODDATA_KEY] = {
        version = SCHEMA_VERSION,
        [PLAYLIST_KEY] = copy
    }
    return true
end

local function saveDeviceBridge(device, playlist)
    if not (device and device.getModData and MyLastTapeAutoDJ and MyLastTapeAutoDJ.clonePlaylist) then
        return false
    end
    local copy = MyLastTapeAutoDJ.clonePlaylist(playlist)
    if #copy < 1 or (MyLastTapeAutoDJ.isFallbackPlaylist and MyLastTapeAutoDJ.isFallbackPlaylist(copy)) then
        return false
    end
    local md = device:getModData()
    md[MODDATA_KEY] = md[MODDATA_KEY] or {}
    md[MODDATA_KEY][BRIDGE_KEY] = {
        version = SCHEMA_VERSION,
        [PLAYLIST_KEY] = copy
    }
    -- Phase 1 used this as persistent device state. A device must never be
    -- the source of a cassette playlist, so remove that legacy data.
    md[MODDATA_KEY][PLAYLIST_KEY] = nil
    md[MODDATA_KEY].hasRecordedPlaylist = nil
    return true
end

local function readDeviceBridge(device)
    if not (device and device.getModData and MyLastTapeAutoDJ and MyLastTapeAutoDJ.clonePlaylist) then
        return nil
    end
    local state = device:getModData()[MODDATA_KEY]
    local bridge = type(state) == "table" and state[BRIDGE_KEY] or nil
    local playlist = type(bridge) == "table" and MyLastTapeAutoDJ.clonePlaylist(bridge[PLAYLIST_KEY]) or nil
    if type(playlist) == "table" and #playlist > 0 then
        return playlist
    end
    return nil
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
    print("[MyLastTape] AutoDJ disabled in multiplayer for MVP-0.4 Phase 2")
elseif NMClientIntentDispatch and NMClientIntentDispatch._myLastTapeAutoDJWrapped ~= true then
    local originalPerformIntent = NMClientIntentDispatch.performIntent

    NMClientIntentDispatch.performIntent = function(player, item, action, args)
        local name = tostring(action or "")

        if name == "insert_media" and isMyLastTapeInsert(args) then
            local sourceCassette = findItemById(player, args and args.mediaItemId)
            local playlist = readCassettePlaylist(sourceCassette)
            local shouldBridge = playlist ~= nil

            if playlist then
                print("[MyLastTape] mode=load-cassette cassetteId=" .. itemId(sourceCassette)
                    .. " " .. deviceIdentity(item)
                    .. " tracks=" .. tostring(#playlist)
                    .. " fingerprint=" .. playlistFingerprint(playlist))
                MyLastTapeAutoDJ.registerPlaylist(playlist)
            elseif MyLastTapeAutoDJ and MyLastTapeAutoDJ.rebuildPlaylist then
                print("[MyLastTape] mode=create cassetteId=" .. itemId(sourceCassette)
                    .. " " .. deviceIdentity(item))
                _, _, playlist, shouldBridge = MyLastTapeAutoDJ.rebuildPlaylist(player, "insert_media")
            end

            print("[MyLastTape] Playlist tracks: " .. tostring(playlist and #playlist or 0))
            local inserted, insertReason = originalPerformIntent(player, item, action, args)
            if inserted == true and shouldBridge == true then
                saveDeviceBridge(item, playlist)
            elseif inserted == true then
                clearDeviceBridge(item)
            end
            return inserted, insertReason
        end

        if name == "eject_media" then
            local playlist = readDeviceBridge(item)
            if not playlist then
                return originalPerformIntent(player, item, action, args)
            end

            local beforeIds = snapshotMyLastTapeIds(player)
            local ejected, ejectReason = originalPerformIntent(player, item, action, args)
            if ejected ~= true then
                return ejected, ejectReason
            end

            local producedCassette = findProducedCassette(player, beforeIds)
            if producedCassette and writeCassettePlaylist(producedCassette, playlist) then
                clearDeviceBridge(item)
                print("[MyLastTape] mode=eject-save cassetteId=" .. itemId(producedCassette)
                    .. " " .. deviceIdentity(item)
                    .. " tracks=" .. tostring(#playlist)
                    .. " fingerprint=" .. playlistFingerprint(playlist))
            else
                print("[MyLastTape] eject-save failed: produced cassette not found; bridge retained")
            end
            return ejected, ejectReason
        end

        return originalPerformIntent(player, item, action, args)
    end

    NMClientIntentDispatch._myLastTapeAutoDJWrapped = true
    print("[MyLastTape] AutoDJ intent hook installed")
end
