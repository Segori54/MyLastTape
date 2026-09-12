require "ISUI/ISPanel"
require "ISUI/ISButton"
require "MyLastTape_Metadata"
require "MyLastTape_ReorderableList"

MyLastTapePlaylistEditorWindow = ISPanel:derive("MyLastTapePlaylistEditorWindow")
MyLastTapePlaylistEditorWindow.instance = nil
-- Preserve the public 0.6 name for any external caller.
MyLastTapePlaylistWindow = MyLastTapePlaylistEditorWindow

local function screenCenter(width, height)
    local core = getCore and getCore() or nil
    local sw = core and core.getScreenWidth and core:getScreenWidth() or width
    local sh = core and core.getScreenHeight and core:getScreenHeight() or height
    return math.floor((sw - width) / 2), math.floor((sh - height) / 2)
end

local function copyTrack(track)
    local source, out = type(track) == "table" and track or {}, {}
    for key, value in pairs(source) do out[key] = value end
    return out
end

local function makeRows(playlist)
    local rows = {}
    for i = 1, #(playlist or {}) do
        rows[#rows + 1] = { rowId = "mlt-row-" .. tostring(i), track = copyTrack(playlist[i]) }
    end
    return rows
end

local function playlistFromRows(rows)
    local playlist = {}
    for i = 1, #(rows or {}) do
        local track = copyTrack(rows[i].track)
        track.trackNumber = i
        playlist[#playlist + 1] = track
    end
    return MyLastTapeMetadata.clonePlaylist(playlist)
end

local function durationSeconds(track)
    if type(track) ~= "table" then return nil end
    if tonumber(track.durationMs) then return tonumber(track.durationMs) / 1000 end
    return tonumber(track.durationSeconds) or tonumber(track.lengthSeconds) or tonumber(track.duration)
end

local function formatDuration(rows)
    local total, known = 0, false
    for i = 1, #(rows or {}) do
        local seconds = durationSeconds(rows[i].track)
        if seconds and seconds >= 0 then total, known = total + seconds, true end
    end
    if not known then return nil end
    total = math.floor(total + 0.5)
    return string.format("%dh %02dm", math.floor(total / 3600), math.floor((total % 3600) / 60))
end

local function shuffle(rows)
    for i = #rows, 2, -1 do
        local j = ZombRand and (ZombRand(i) + 1) or math.random(i)
        rows[i], rows[j] = rows[j], rows[i]
    end
end

function MyLastTapePlaylistEditorWindow:initialise()
    ISPanel.initialise(self)
end

function MyLastTapePlaylistEditorWindow:createChildren()
    ISPanel.createChildren(self)
    self.trackList = MyLastTapeReorderableList:new(16, 84, self.width - 32, self.height - 142)
    self.trackList:initialise()
    self.trackList:instantiate()
    self.trackList:setRows(self.workingRows)
    self:addChild(self.trackList)

    self.shuffleButton = ISButton:new(16, self.height - 42, 80, 25, "Shuffle", self, MyLastTapePlaylistEditorWindow.onShuffle)
    self.undoButton = ISButton:new(104, self.height - 42, 70, 25, "Undo", self, MyLastTapePlaylistEditorWindow.onUndo)
    self.closeButton = ISButton:new(self.width - 184, self.height - 42, 80, 25, "Close", self, MyLastTapePlaylistEditorWindow.onClose)
    self.saveButton = ISButton:new(self.width - 126, self.height - 42, 110, 25, "Save / Re-record", self, MyLastTapePlaylistEditorWindow.onSave)
    for _, button in ipairs({ self.shuffleButton, self.undoButton, self.closeButton, self.saveButton }) do
        button:initialise()
        button:instantiate()
        self:addChild(button)
    end
end

function MyLastTapePlaylistEditorWindow:onShuffle()
    if self.trackList then
        shuffle(self.trackList.rows)
        self.trackList:clearSelection()
        self.trackList.selectionAnchorRowId = nil
    end
end

function MyLastTapePlaylistEditorWindow:onUndo()
    if self.trackList then
        self.workingRows = MyLastTapeReorderableList.copyRows(self.originalRows)
        self.trackList:setRows(self.workingRows)
    end
end

function MyLastTapePlaylistEditorWindow:onSave()
    local rows = self.trackList and self.trackList.rows or self.workingRows
    local playlist = playlistFromRows(rows)
    if self.onSaveCallback then
        local saved, message = self.onSaveCallback(self.player, self.itemId, playlist)
        if saved ~= true then
            self.saveError = tostring(message or "Could not save this cassette.")
            return
        end
    end
    self:close()
end

function MyLastTapePlaylistEditorWindow:onClose()
    self:close()
end

function MyLastTapePlaylistEditorWindow:close()
    if self.trackList then self.trackList:clearDrag() end
    self:removeFromUIManager()
    if MyLastTapePlaylistEditorWindow.instance == self then
        MyLastTapePlaylistEditorWindow.instance = nil
    end
end

function MyLastTapePlaylistEditorWindow:prerender()
    ISPanel.prerender(self)
    self:drawRectStatic(0, 0, self.width, self.height, 0.92, 0.08, 0.08, 0.08)
    self:drawRectBorderStatic(0, 0, self.width, self.height, 0.8, 0.55, 0.55, 0.55)
    self:drawText("MY LAST TAPE", 16, 12, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(self.title, 16, 33, 0.92, 0.92, 0.92, 1, UIFont.Small)
    local rows = self.trackList and self.trackList.rows or self.workingRows
    local info = tostring(#rows) .. " tracks"
    local length = formatDuration(rows)
    if length then info = info .. "  -  " .. length end
    self:drawText(info, 16, 51, 0.72, 0.72, 0.72, 1, UIFont.Small)
    if self.creator then self:drawText("Creator: " .. self.creator, self.width - 160, 33, 0.72, 0.72, 0.72, 1, UIFont.Small) end
    if self.recordedDate then self:drawText(self.recordedDate, self.width - 160, 51, 0.72, 0.72, 0.72, 1, UIFont.Small) end
    if self.saveError then self:drawText(self.saveError, 16, self.height - 66, 1, 0.5, 0.5, 1, UIFont.Small) end
end

function MyLastTapePlaylistEditorWindow.open(player, itemId, title, playlist, metadata, onSaveCallback)
    if MyLastTapePlaylistEditorWindow.instance then MyLastTapePlaylistEditorWindow.instance:close() end
    local width, height = 520, 470
    local x, y = screenCenter(width, height)
    local window = MyLastTapePlaylistEditorWindow:new(x, y, width, height, player, itemId, title, playlist, metadata, onSaveCallback)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    MyLastTapePlaylistEditorWindow.instance = window
    return window
end

function MyLastTapePlaylistEditorWindow:new(x, y, width, height, player, itemId, title, playlist, metadata, onSaveCallback)
    local o = ISPanel.new(self, x, y, width, height)
    local firstRows = makeRows(MyLastTapeMetadata.clonePlaylist(playlist))
    o.player = player
    o.itemId = tostring(itemId or "")
    o.title = tostring(title or "My Last Tape")
    o.originalRows = MyLastTapeReorderableList.copyRows(firstRows)
    o.workingRows = MyLastTapeReorderableList.copyRows(firstRows)
    o.creator = metadata and metadata.creator and tostring(metadata.creator) or nil
    o.recordedDate = metadata and metadata.recordedDate and tostring(metadata.recordedDate) or nil
    o.onSaveCallback = onSaveCallback
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.55, g = 0.55, b = 0.55, a = 0.9 }
    o.moveWithMouse = true
    return o
end

return MyLastTapePlaylistEditorWindow
