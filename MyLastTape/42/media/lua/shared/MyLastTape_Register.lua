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

NMTrackCatalog.registerEntry(
    MEDIA_FULL_TYPE,
    CASSETTE_CARRIER,
    {
        {
            sound = "NMZomboidTheme2",
            label = "My Last Tape - Test Track",
            trackNumber = 1
        }
    }
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

function MyLastTapeAutoDJ.rebuildPlaylist(player, reason)
    local playlist = {}
    local seenSounds = {}
    local seenMediaTypes = {}

    print("[MyLastTape] Scanning accessible media")

    local inventories = NMInventoryHelpers
        and NMInventoryHelpers.collectAccessibleSourceInventories
        and NMInventoryHelpers.collectAccessibleSourceInventories(player)
        or {}

    for i = 1, #inventories do
        local items = {}
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
        print("[MyLastTape] AutoDJ found no external cassette tracks; keeping fallback track")
        print("[MyLastTape] Playlist size: 0")
        return false, 0
    end

    shuffle(playlist)
    for i = 1, #playlist do
        playlist[i].trackNumber = i
    end

    print("[MyLastTape] Playlist size: " .. tostring(#playlist))
    NMTrackCatalog.registerEntry(MEDIA_FULL_TYPE, CASSETTE_CARRIER, playlist)
    print(string.format(
        "[MyLastTape] AutoDJ playlist registered (%d tracks, reason=%s)",
        #playlist,
        tostring(reason or "unknown")
    ))
    return true, #playlist
end
