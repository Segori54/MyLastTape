MyLastTapeMetadata = MyLastTapeMetadata or {}

local MODDATA_KEY = "MyLastTape"
local BLANK_DISPLAY_NAME = "Blank Cassette"
local RECORDED_DISPLAY_NAME = "My Last Tape"
local MAX_NAME_LENGTH = 48

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
        label = tostring(track.label or sound)
    }
    if track.trackNumber ~= nil then copy.trackNumber = track.trackNumber end
    if track.durationMs ~= nil then copy.durationMs = track.durationMs end
    if track.durationSeconds ~= nil then copy.durationSeconds = track.durationSeconds end
    if track.lengthSeconds ~= nil then copy.lengthSeconds = track.lengthSeconds end
    if track.duration ~= nil then copy.duration = track.duration end
    return copy
end

function MyLastTapeMetadata.clonePlaylist(tracks)
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

local function truncateUtf8(text, maxChars)
    local count = 0
    local out = {}
    for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > maxChars then
            break
        end
        out[#out + 1] = char
    end
    return table.concat(out)
end

function MyLastTapeMetadata.normalizeName(value)
    local text = tostring(value or "")
    text = text:gsub("[\r\n\t]", " ")
    text = text:gsub("[%z\1-\8\11\12\14-\31\127]", "")
    text = text:gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$") or ""
    text = truncateUtf8(text, MAX_NAME_LENGTH)
    return text ~= "" and text or nil
end

function MyLastTapeMetadata.cloneState(state)
    local input = type(state) == "table" and state or {}
    local playlist = MyLastTapeMetadata.clonePlaylist(input.playlist)
    local recorded = #playlist > 0
    return {
        version = 2,
        recorded = recorded,
        name = MyLastTapeMetadata.normalizeName(input.name),
        playlist = recorded and playlist or nil
    }
end

function MyLastTapeMetadata.readState(item)
    local raw = item and item.getModData and item:getModData()[MODDATA_KEY] or nil
    return MyLastTapeMetadata.cloneState(raw)
end

function MyLastTapeMetadata.hasPersistentData(state)
    local copy = MyLastTapeMetadata.cloneState(state)
    return copy.recorded == true or copy.name ~= nil
end

function MyLastTapeMetadata.applyDisplayName(item, state)
    if not (item and item.setName) then
        return
    end
    local copy = MyLastTapeMetadata.cloneState(state)
    item:setName(copy.name or (copy.recorded and RECORDED_DISPLAY_NAME or BLANK_DISPLAY_NAME))
end

function MyLastTapeMetadata.writeState(item, state)
    if not (item and item.getModData) then
        return false
    end
    local copy = MyLastTapeMetadata.cloneState(state)
    local md = item:getModData()
    if MyLastTapeMetadata.hasPersistentData(copy) then
        md[MODDATA_KEY] = copy
    else
        md[MODDATA_KEY] = nil
    end
    MyLastTapeMetadata.applyDisplayName(item, copy)
    return true
end

function MyLastTapeMetadata.getDisplayName(item)
    local state = MyLastTapeMetadata.readState(item)
    if state.name then
        return state.name
    end
    if item and item.getDisplayName then
        return tostring(item:getDisplayName() or (state.recorded and RECORDED_DISPLAY_NAME or BLANK_DISPLAY_NAME))
    end
    return state.recorded and RECORDED_DISPLAY_NAME or BLANK_DISPLAY_NAME
end

function MyLastTapeMetadata.getDefaultDisplayName()
    return BLANK_DISPLAY_NAME
end

function MyLastTapeMetadata.getMaxNameLength()
    return MAX_NAME_LENGTH
end

return MyLastTapeMetadata
