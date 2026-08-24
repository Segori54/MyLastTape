require "intents/NMClientIntentDispatch"

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"

local function isMyLastTapeInsert(args)
    local payload = args or {}
    return tostring(payload.mediaFullType or payload.mediaEjectFullType or "") == MEDIA_FULL_TYPE
end

local function isMyLastTapeLoadedInDevice(item)
    local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    local state = profile and NMDeviceState and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
    return state and tostring(state.mediaFullType or "") == MEDIA_FULL_TYPE and state.isPlaying ~= true
end

local function isMultiplayerClient()
    return NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true
end

if isMultiplayerClient() then
    print("[MyLastTape] AutoDJ disabled in multiplayer for MVP-0.2")
elseif NMClientIntentDispatch and NMClientIntentDispatch._myLastTapeAutoDJWrapped ~= true then
    local originalPerformIntent = NMClientIntentDispatch.performIntent

    NMClientIntentDispatch.performIntent = function(player, item, action, args)
        local name = tostring(action or "")

        if MyLastTapeAutoDJ and MyLastTapeAutoDJ.rebuildPlaylist then
            if name == "insert_media" and isMyLastTapeInsert(args) then
                MyLastTapeAutoDJ.rebuildPlaylist(player, "insert_media")
            elseif name == "play" and isMyLastTapeLoadedInDevice(item) then
                MyLastTapeAutoDJ.rebuildPlaylist(player, "play")
            end
        end

        return originalPerformIntent(player, item, action, args)
    end

    NMClientIntentDispatch._myLastTapeAutoDJWrapped = true
    print("[MyLastTape] AutoDJ intent hook installed")
end
