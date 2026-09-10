require "music/NMTrackCatalog"
require "contracts/NMMediaContract"

MyLastTapeAutoDJ = MyLastTapeAutoDJ or {}

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"
local CASSETTE_CARRIER = "nm_carrier_cassette"

print("[MyLastTape] Registering cassette")

NMMediaContract.registerMediaTypeAlias(
    "LastTape",
    CASSETTE_CARRIER
)

print("[MyLastTape] Cassette registered successfully")

local function copyTrack(track)
    if type(track) ~= "table" then
        return nil
    end

    local sound = tostring(track.sound or "")
    if sound == "" then
        return nil
    end

    local copy = {
        sound = sound,
        label = tostring(track.label or sound),
    }

    if track.trackNumber ~= nil then copy.trackNumber = track.trackNumber end
    if track.durationMs ~= nil then copy.durationMs = track.durationMs end
    if track.durationSeconds ~= nil then copy.durationSeconds = track.durationSeconds end
    if track.lengthSeconds ~= nil then copy.lengthSeconds = track.lengthSeconds end
    if track.duration ~= nil then copy.duration = track.duration end

    return copy
end

function MyLastTapeAutoDJ.clonePlaylist(tracks)
    local out = {}
    if type(tracks) ~= "table" then
        return out
    end
    for i = 1, #tracks do
        local track = copyTrack(tracks[i])
        if track then
            out[#out + 1] = track
        end
    end
    return out
end

function MyLastTapeAutoDJ.playlistFingerprint(tracks)
    local playlist = MyLastTapeAutoDJ.clonePlaylist(tracks)
    local sounds = {}
    local limit = math.min(#playlist, 3)
    for i = 1, limit do
        sounds[#sounds + 1] = tostring(playlist[i].sound or "")
    end
    return tostring(#playlist) .. ":" .. table.concat(sounds, ",")
end

function MyLastTapeAutoDJ.registerPlaylist(tracks)
    local playlist = MyLastTapeAutoDJ.clonePlaylist(tracks)
    if #playlist < 1 then
        return false, 0, playlist
    end
    NMTrackCatalog.registerEntry(MEDIA_FULL_TYPE, CASSETTE_CARRIER, playlist)
    return true, #playlist, playlist
end

function MyLastTapeAutoDJ.clearRegisteredPlaylist()
    if NMTrackCatalog and type(NMTrackCatalog.entries) == "table" then
        NMTrackCatalog.entries[MEDIA_FULL_TYPE] = nil
    end
end

local function shuffle(tracks)
    for i = #tracks, 2, -1 do
        local j
        if ZombRand then
            j = ZombRand(i) + 1
        else
            j = math.random(i)
        end
        tracks[i], tracks[j] = tracks[j], tracks[i]
    end
end

function MyLastTapeAutoDJ.buildPlaylist(player, reason)
    local playlist = {}
    local seenSounds = {}
    local seenMediaTypes = {}

    print("[MyLastTape] Scanning accessible media")

    local inventories = NMInventoryHelpers
        and NMInventoryHelpers.collectVisibleUiSourceInventories
        and NMInventoryHelpers.collectVisibleUiSourceInventories(player)
        or {}

    for i = 1, #inventories do
        local items = {}
        local containerType = inventories[i] and inventories[i].getType and tostring(inventories[i]:getType() or "") or "unknown"
        print("[MyLastTape] Source inventory " .. tostring(i) .. ": " .. containerType)
        if NMInventoryHelpers and NMInventoryHelpers.collectItemsRecursive then
            NMInventoryHelpers.collectItemsRecursive(inventories[i], items)
        end

        for j = 1, #items do
            local item = items[j]
            local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""

            if fullType ~= ""
                and fullType ~= MEDIA_FULL_TYPE
                and not seenMediaTypes[fullType]
            then
                seenMediaTypes[fullType] = true

                local carrier = NMMediaContract
                    and NMMediaContract.resolveMediaCarrier
                    and NMMediaContract.resolveMediaCarrier(fullType)
                    or nil

                if tostring(carrier or "") == CASSETTE_CARRIER then
                    print("[MyLastTape] Found cassette: " .. fullType)

                    local resolver = NMMusic and NMMusic.resolveTracks or nil
                    local ok, resolved = false, nil
                    if resolver then
                        ok, resolved = pcall(resolver, fullType)
                    end
                    local tracks = ok and resolved and resolved.tracks or nil
                    local resolvedCount = type(tracks) == "table" and #tracks or 0
                    print("[MyLastTape] Resolved tracks: " .. tostring(resolvedCount))

                    if type(tracks) == "table" then
                        for k = 1, #tracks do
                            local track = copyTrack(tracks[k])
                            if track and not seenSounds[track.sound] then
                                seenSounds[track.sound] = true
                                playlist[#playlist + 1] = track
                            end
                        end
                    end
                end
            end
        end
    end

    if #playlist < 1 then
        print("[MyLastTape] AutoDJ found no external cassette tracks")
        return false, 0, playlist, false
    end

    if #playlist > 1 then
        shuffle(playlist)
    end
    for i = 1, #playlist do
        playlist[i].trackNumber = i
    end

    print("[MyLastTape] Playlist size: " .. tostring(#playlist))
    return true, #playlist, playlist, true
end

function MyLastTapeAutoDJ.rebuildPlaylist(player, reason)
    local built, count, playlist, recorded = MyLastTapeAutoDJ.buildPlaylist(player, reason)
    if not built then
        return false, count, playlist, recorded
    end
    local registered, count, registeredPlaylist = MyLastTapeAutoDJ.registerPlaylist(playlist)
    print(string.format(
        "[MyLastTape] AutoDJ playlist registered (%d tracks, reason=%s)",
        count or 0,
        tostring(reason or "unknown")
    ))
    return registered, count, registeredPlaylist, recorded
end

-- New Music normally falls back to the suffix of any unregistered FullType.
-- A blank My Last Tape must instead resolve to no tracks. The wrapper is
-- restricted to this addon's own FullType and leaves every other resolver path
-- untouched.
if NMMusic and type(NMMusic.resolveTracks) == "function" and NMMusic._myLastTapeBlankResolverWrapped ~= true then
    local originalResolveTracks = NMMusic.resolveTracks
    NMMusic.resolveTracks = function(mediaFullType)
        if tostring(mediaFullType or "") == MEDIA_FULL_TYPE then
            local entry = NMTrackCatalog and NMTrackCatalog.resolveTracks and NMTrackCatalog.resolveTracks(MEDIA_FULL_TYPE) or nil
            if type(entry) ~= "table" or type(entry.tracks) ~= "table" or #entry.tracks < 1 then
                return nil
            end
        end
        return originalResolveTracks(mediaFullType)
    end
    NMMusic._myLastTapeBlankResolverWrapped = true
end
