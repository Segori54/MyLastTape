require "intents/NMClientIntentDispatch"

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"

local function isMyLastTapeInsert(args)
    local payload = args or {}
    return tostring(payload.mediaFullType or payload.mediaEjectFullType or "") == MEDIA_FULL_TYPE
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

        if name ~= "insert_media" or not isMyLastTapeInsert(args) then
            return originalPerformIntent(player, item, action, args)
        end

        if MyLastTapeAutoDJ and MyLastTapeAutoDJ.rebuildPlaylist then
            -- Tali builds the insert payload from the catalog, so the new list
            -- must exist before the native insert transition resets trackIndex.
            MyLastTapeAutoDJ.rebuildPlaylist(player, "insert_media")
        end

        local inserted, insertReason = originalPerformIntent(player, item, action, args)
        return inserted, insertReason
    end

    NMClientIntentDispatch._myLastTapeAutoDJWrapped = true
    print("[MyLastTape] AutoDJ intent hook installed")
end
