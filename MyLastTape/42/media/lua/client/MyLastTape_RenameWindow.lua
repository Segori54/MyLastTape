require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "MyLastTape_Metadata"

MyLastTapeRenameWindow = ISPanel:derive("MyLastTapeRenameWindow")
MyLastTapeRenameWindow.instance = nil

local function screenCenter(width, height)
    local core = getCore and getCore() or nil
    local screenWidth = core and core.getScreenWidth and core:getScreenWidth() or width
    local screenHeight = core and core.getScreenHeight and core:getScreenHeight() or height
    return math.floor((screenWidth - width) / 2), math.floor((screenHeight - height) / 2)
end

function MyLastTapeRenameWindow:initialise()
    ISPanel.initialise(self)
end

function MyLastTapeRenameWindow:createChildren()
    ISPanel.createChildren(self)

    self.entry = ISTextEntryBox:new(self.initialName or "", 16, 52, self.width - 32, 24)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry:setMaxTextLength(MyLastTapeMetadata.getMaxNameLength())
    self.entry.onCommandEntered = function()
        self:onSave()
    end
    self:addChild(self.entry)

    self.cancelButton = ISButton:new(self.width - 184, self.height - 38, 80, 25, "Cancel", self, MyLastTapeRenameWindow.onCancel)
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    self:addChild(self.cancelButton)

    self.saveButton = ISButton:new(self.width - 96, self.height - 38, 80, 25, "Save", self, MyLastTapeRenameWindow.onSave)
    self.saveButton:initialise()
    self.saveButton:instantiate()
    self:addChild(self.saveButton)
end

function MyLastTapeRenameWindow:onSave()
    if self.onSaveCallback then
        self.onSaveCallback(self.player, self.itemId, self.entry and self.entry:getText() or "")
    end
    self:close()
end

function MyLastTapeRenameWindow:onCancel()
    self:close()
end

function MyLastTapeRenameWindow:close()
    if self.entry and self.entry.unfocus then
        self.entry:unfocus()
    end
    self:removeFromUIManager()
    if MyLastTapeRenameWindow.instance == self then
        MyLastTapeRenameWindow.instance = nil
    end
end

function MyLastTapeRenameWindow:prerender()
    ISPanel.prerender(self)
    self:drawRectStatic(0, 0, self.width, self.height, 0.92, 0.08, 0.08, 0.08)
    self:drawRectBorderStatic(0, 0, self.width, self.height, 0.8, 0.55, 0.55, 0.55)
    self:drawTextCentre("Rename My Last Tape", self.width / 2, 14, 1, 1, 1, 1, UIFont.Medium)
    self:drawText("Name:", 16, 34, 1, 1, 1, 1, UIFont.Small)
end

function MyLastTapeRenameWindow.open(player, itemId, initialName, onSaveCallback)
    if MyLastTapeRenameWindow.instance then
        MyLastTapeRenameWindow.instance:close()
    end

    local width, height = 360, 128
    local x, y = screenCenter(width, height)
    local window = MyLastTapeRenameWindow:new(x, y, width, height, player, itemId, initialName, onSaveCallback)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window.entry:focus()
    window.entry:selectAll()
    MyLastTapeRenameWindow.instance = window
    return window
end

function MyLastTapeRenameWindow:new(x, y, width, height, player, itemId, initialName, onSaveCallback)
    local o = ISPanel.new(self, x, y, width, height)
    o.player = player
    o.itemId = tostring(itemId or "")
    o.initialName = tostring(initialName or "")
    o.onSaveCallback = onSaveCallback
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.55, g = 0.55, b = 0.55, a = 0.9 }
    o.moveWithMouse = true
    return o
end

return MyLastTapeRenameWindow
