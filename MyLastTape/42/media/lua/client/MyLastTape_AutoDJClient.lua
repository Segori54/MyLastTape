require "intents/NMClientIntentDispatch"

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"
local PERSISTENCE_KEY = "MyLastTape"
local PLAYLIST_KEY = "playlist"

local function isMyLastTapeInsert(args)
    local payload = args or {}
    return tostring(payload.mediaFullType or payload.mediaEjectFullType or "") == MEDIA_FULL_TYPE
end

local function isMultiplayerClient()
    return NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true
end

local function loadPersistentPlaylist(device)
    if not (device and device.getModData and MyLastTapeAutoDJ and MyLastTapeAutoDJ.clonePlaylist) then
        return nil
    end
    local saved = device:getModData()[PERSISTENCE_KEY]
    local playlist = type(saved) == "table" and MyLastTapeAutoDJ.clonePlaylist(saved[PLAYLIST_KEY]) or nil
    if type(playlist) == "table" and #playlist > 0 then
        return playlist
    end
    return nil
end

local function savePersistentPlaylist(device, playlist)
    if not (device and device.getModData and MyLastTapeAutoDJ and MyLastTapeAutoDJ.clonePlaylist) then
        return false
    end
    local copy = MyLastTapeAutoDJ.clonePlaylist(playlist)
    if #copy < 1 then
        return false
    end
    local md = device:getModData()
    md[PERSISTENCE_KEY] = md[PERSISTENCE_KEY] or {}
    md[PERSISTENCE_KEY][PLAYLIST_KEY] = copy
    return true
end

if isMultiplayerClient() then
    print("[MyLastTape] AutoDJ disabled in multiplayer for MVP-0.2")
elseif NMClientIntentDispatch and NMClientIntentDispatch._myLastTapeAutoDJWrapped ~= true then
    local originalPerformIntent = NMClientIntentDispatch.performIntent

    NMClientIntentDispatch.performIntent = function(player, item, action, args)
        local name = tostring(action or "")

        if name ~= "insert_media" or not isMyLastTapeInsert(args) then
            return originalPerformIntent(player, item, action, args)
        end

        local playlist = loadPersistentPlaylist(item)
        local created = playlist == nil

        if playlist then
            print("[MyLastTape] Loading persistent playlist")
            MyLastTapeAutoDJ.registerPlaylist(playlist)
        elseif MyLastTapeAutoDJ and MyLastTapeAutoDJ.rebuildPlaylist then
            -- Tali builds the insert payload from the catalog, so the new list
            -- must exist before the native insert transition resets trackIndex.
            print("[MyLastTape] Creating persistent playlist")
            _, _, playlist = MyLastTapeAutoDJ.rebuildPlaylist(player, "insert_media")
        end

        print("[MyLastTape] Playlist tracks: " .. tostring(playlist and #playlist or 0))

        local inserted, insertReason = originalPerformIntent(player, item, action, args)
        if inserted == true and created then
            savePersistentPlaylist(item, playlist)
        end

        return inserted, insertReason
    end

    NMClientIntentDispatch._myLastTapeAutoDJWrapped = true
    print("[MyLastTape] AutoDJ intent hook installed")
end
