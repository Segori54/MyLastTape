require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"

MyLastTapePlaylistWindow = ISPanel:derive("MyLastTapePlaylistWindow")
MyLastTapePlaylistWindow.instance = nil

local function screenCenter(width, height)
    local core = getCore and getCore() or nil
    local screenWidth = core and core.getScreenWidth and core:getScreenWidth() or width
    local screenHeight = core and core.getScreenHeight and core:getScreenHeight() or height
    return math.floor((screenWidth - width) / 2), math.floor((screenHeight - height) / 2)
end

function MyLastTapePlaylistWindow:initialise()
    ISPanel.initialise(self)
end

function MyLastTapePlaylistWindow:createChildren()
    ISPanel.createChildren(self)

    self.trackList = ISScrollingListBox:new(16, 48, self.width - 32, self.height - 104)
    self.trackList:initialise()
    self.trackList:instantiate()
    self.trackList.itemheight = 20
    self.trackList.drawBorder = true
    self.trackList.doDrawItem = function(list, y, item, alt)
        local selected = list.selected == item.index
        if selected then
            list:drawRect(0, y, list.width, list.itemheight, 0.3, 0.3, 0.5, 0.8)
        elseif alt then
            list:drawRect(0, y, list.width, list.itemheight, 0.12, 0.2, 0.2, 0.2)
        end
        list:drawText(item.text or "", 6, y + 2, 1, 1, 1, 1, UIFont.Small)
        return y + list.itemheight
    end
    self:addChild(self.trackList)

    for i = 1, #(self.playlist or {}) do
        local track = self.playlist[i]
        local number = tonumber(track and track.trackNumber) or i
        local label = tostring(track and track.label or track and track.sound or "Unknown track")
        self.trackList:addItem(string.format("%02d. %s", number, label), track)
    end

    self.closeButton = ISButton:new(self.width - 96, self.height - 42, 80, 25, "Close", self, MyLastTapePlaylistWindow.onClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)
end

function MyLastTapePlaylistWindow:onClose()
    self:close()
end

function MyLastTapePlaylistWindow:close()
    self:removeFromUIManager()
    if MyLastTapePlaylistWindow.instance == self then
        MyLastTapePlaylistWindow.instance = nil
    end
end

function MyLastTapePlaylistWindow:prerender()
    ISPanel.prerender(self)
    self:drawRectStatic(0, 0, self.width, self.height, 0.92, 0.08, 0.08, 0.08)
    self:drawRectBorderStatic(0, 0, self.width, self.height, 0.8, 0.55, 0.55, 0.55)
    self:drawTextCentre(self.title or "My Last Tape Playlist", self.width / 2, 14, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(tostring(#(self.playlist or {})) .. " tracks", 16, 32, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function MyLastTapePlaylistWindow.open(title, playlist)
    if MyLastTapePlaylistWindow.instance then
        MyLastTapePlaylistWindow.instance:close()
    end

    local width, height = 460, 420
    local x, y = screenCenter(width, height)
    local window = MyLastTapePlaylistWindow:new(x, y, width, height, title, playlist)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    MyLastTapePlaylistWindow.instance = window
    return window
end

function MyLastTapePlaylistWindow:new(x, y, width, height, title, playlist)
    local o = ISPanel.new(self, x, y, width, height)
    o.title = tostring(title or "My Last Tape Playlist")
    o.playlist = playlist or {}
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.55, g = 0.55, b = 0.55, a = 0.9 }
    o.moveWithMouse = true
    return o
end

return MyLastTapePlaylistWindow
