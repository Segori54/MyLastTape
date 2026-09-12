require "ISUI/ISPanel"

-- A deliberately small, self-contained list.  ISScrollingListBox has useful
-- rendering hooks, but its single-selection model is not a good fit for an
-- editor that needs stable multi-selection and insertion feedback.
MyLastTapeReorderableList = ISPanel:derive("MyLastTapeReorderableList")

local ROW_HEIGHT = 24
local HANDLE_WIDTH = 22
local REMOVE_WIDTH = 24
local SCROLLBAR_WIDTH = 12
local DRAG_THRESHOLD = 5
local AUTO_SCROLL_EDGE = 28
local AUTO_SCROLL_STEP = 8

local function modifierDown(name)
    local fn = _G and _G[name] or nil
    return type(fn) == "function" and fn() == true
end

local function copyTrack(track)
    local source = type(track) == "table" and track or {}
    local out = {}
    for key, value in pairs(source) do
        out[key] = value
    end
    return out
end

local function copyRows(rows)
    local out = {}
    for i = 1, #(rows or {}) do
        local row = rows[i]
        out[#out + 1] = { rowId = row.rowId, track = copyTrack(row.track) }
    end
    return out
end

function MyLastTapeReorderableList:initialise()
    ISPanel.initialise(self)
end

function MyLastTapeReorderableList:setRows(rows)
    self.rows = rows or {}
    self.selectedRowIds = {}
    self.selectionAnchorRowId = nil
    self.scrollY = math.max(0, math.min(self.scrollY or 0, self:maxScrollY()))
    self:clearDrag()
end

function MyLastTapeReorderableList:maxScrollY()
    return math.max(0, #self.rows * ROW_HEIGHT - self.height)
end

function MyLastTapeReorderableList:contentWidth()
    return self.width - (self:maxScrollY() > 0 and SCROLLBAR_WIDTH or 0)
end

function MyLastTapeReorderableList:absoluteMouse()
    local ax = self.getAbsoluteX and self:getAbsoluteX() or 0
    local ay = self.getAbsoluteY and self:getAbsoluteY() or 0
    return (getMouseX and getMouseX() or ax) - ax, (getMouseY and getMouseY() or ay) - ay
end

function MyLastTapeReorderableList:rowAtLocalY(y)
    local index = math.floor((y + self.scrollY) / ROW_HEIGHT) + 1
    return index >= 1 and index <= #self.rows and index or nil
end

function MyLastTapeReorderableList:isSelected(rowId)
    return self.selectedRowIds[rowId] == true
end

function MyLastTapeReorderableList:clearSelection()
    self.selectedRowIds = {}
end

function MyLastTapeReorderableList:selectOnly(rowId)
    self.selectedRowIds = {}
    if rowId then self.selectedRowIds[rowId] = true end
    self.selectionAnchorRowId = rowId
end

function MyLastTapeReorderableList:selectRange(anchorId, rowId)
    local first, last = nil, nil
    for i = 1, #self.rows do
        if self.rows[i].rowId == anchorId then first = i end
        if self.rows[i].rowId == rowId then last = i end
    end
    if not (first and last) then
        self:selectOnly(rowId)
        return
    end
    if first > last then first, last = last, first end
    self.selectedRowIds = {}
    for i = first, last do self.selectedRowIds[self.rows[i].rowId] = true end
end

function MyLastTapeReorderableList:applyClickSelection(rowId)
    if modifierDown("isShiftKeyDown") and self.selectionAnchorRowId then
        self:selectRange(self.selectionAnchorRowId, rowId)
    elseif modifierDown("isCtrlKeyDown") then
        self.selectedRowIds[rowId] = not self.selectedRowIds[rowId]
        self.selectionAnchorRowId = rowId
    else
        self:selectOnly(rowId)
    end
end

function MyLastTapeReorderableList:removeSelected()
    local kept = {}
    for i = 1, #self.rows do
        if not self:isSelected(self.rows[i].rowId) then kept[#kept + 1] = self.rows[i] end
    end
    self.rows = kept
    self:clearSelection()
    self.selectionAnchorRowId = nil
    self.scrollY = math.min(self.scrollY, self:maxScrollY())
    self:clearDrag()
    return true
end

function MyLastTapeReorderableList:selectedCount()
    local count = 0
    for _ in pairs(self.selectedRowIds) do count = count + 1 end
    return count
end

function MyLastTapeReorderableList:removeRow(rowId)
    -- A hovered Remove button also acts as the batch-delete affordance when
    -- its row belongs to the current multi-selection.
    if not self:isSelected(rowId) or self:selectedCount() < 2 then
        self.selectedRowIds = { [rowId] = true }
    end
    self:removeSelected()
end

function MyLastTapeReorderableList:clearDrag()
    self.pressedRowId = nil
    self.pressedMouseX = nil
    self.pressedMouseY = nil
    self.dragging = false
    self.dropInsertIndex = nil
    if self.setCapture then self:setCapture(false) end
end

function MyLastTapeReorderableList:beginDrag()
    self.dragging = true
    if self.setCapture then self:setCapture(true) end
end

function MyLastTapeReorderableList:inRemoveZone(x)
    return x >= self:contentWidth() - REMOVE_WIDTH
end

function MyLastTapeReorderableList:inScrollbar(x)
    return self:maxScrollY() > 0 and x >= self:contentWidth()
end

function MyLastTapeReorderableList:updateDropTarget(localY)
    local raw = (localY + self.scrollY) / ROW_HEIGHT
    local index = math.floor(raw) + 1
    if (raw - math.floor(raw)) >= 0.5 then index = index + 1 end
    self.dropInsertIndex = math.max(1, math.min(#self.rows + 1, index))
end

function MyLastTapeReorderableList:autoScroll(localY)
    local maximum = self:maxScrollY()
    if maximum <= 0 then return end
    if localY < AUTO_SCROLL_EDGE then
        self.scrollY = math.max(0, self.scrollY - AUTO_SCROLL_STEP)
    elseif localY > self.height - AUTO_SCROLL_EDGE then
        self.scrollY = math.min(maximum, self.scrollY + AUTO_SCROLL_STEP)
    end
end

function MyLastTapeReorderableList:commitDrag()
    local target = self.dropInsertIndex
    if not target then return end
    local moving, kept, beforeTarget = {}, {}, 0
    for i = 1, #self.rows do
        local row = self.rows[i]
        if self:isSelected(row.rowId) then
            moving[#moving + 1] = row
            if i < target then beforeTarget = beforeTarget + 1 end
        else
            kept[#kept + 1] = row
        end
    end
    if #moving == 0 then return end
    target = target - beforeTarget
    target = math.max(1, math.min(#kept + 1, target))
    local out = {}
    for i = 1, target - 1 do out[#out + 1] = kept[i] end
    for i = 1, #moving do out[#out + 1] = moving[i] end
    for i = target, #kept do out[#out + 1] = kept[i] end
    self.rows = out
end

function MyLastTapeReorderableList:onMouseDown(x, y)
    if self:inScrollbar(x) then
        local maximum = self:maxScrollY()
        self.scrollY = math.max(0, math.min(maximum, (y / math.max(1, self.height)) * maximum))
        return true
    end
    local index = self:rowAtLocalY(y)
    if not index then
        self:clearSelection()
        return true
    end
    local row = self.rows[index]
    if self:inRemoveZone(x) then
        self:removeRow(row.rowId)
        return true
    end
    if not self:isSelected(row.rowId) or modifierDown("isCtrlKeyDown") or modifierDown("isShiftKeyDown") then
        self:applyClickSelection(row.rowId)
    end
    self.pressedRowId = row.rowId
    local mx, my = self:absoluteMouse()
    self.pressedMouseX, self.pressedMouseY = mx, my
    return true
end

function MyLastTapeReorderableList:onMouseMove(dx, dy)
    local mx, my = self:absoluteMouse()
    if self.pressedRowId then
        local moved = math.abs(mx - self.pressedMouseX) >= DRAG_THRESHOLD or math.abs(my - self.pressedMouseY) >= DRAG_THRESHOLD
        if moved and not self.dragging then self:beginDrag() end
    end
    if self.dragging then
        self:autoScroll(my)
        self:updateDropTarget(my)
    end
    return true
end

function MyLastTapeReorderableList:onMouseMoveOutside(dx, dy)
    return self:onMouseMove(dx, dy)
end

function MyLastTapeReorderableList:finishMouse()
    if self.dragging then self:commitDrag() end
    self:clearDrag()
    return true
end

function MyLastTapeReorderableList:onMouseUp(x, y)
    return self:finishMouse()
end

function MyLastTapeReorderableList:onMouseUpOutside(x, y)
    return self:finishMouse()
end

function MyLastTapeReorderableList:onMouseWheel(delta)
    self.scrollY = math.max(0, math.min(self:maxScrollY(), self.scrollY - delta * ROW_HEIGHT * 2))
    return true
end

function MyLastTapeReorderableList:prerender()
    ISPanel.prerender(self)
end

function MyLastTapeReorderableList:render()
    ISPanel.render(self)
    self:drawRectStatic(0, 0, self.width, self.height, 0.35, 0, 0, 0)
    self:drawRectBorderStatic(0, 0, self.width, self.height, 0.8, 0.55, 0.55, 0.55)
    local mx, my = self:absoluteMouse()
    local contentW = self:contentWidth()
    local first = math.max(1, math.floor(self.scrollY / ROW_HEIGHT) + 1)
    local last = math.min(#self.rows, math.ceil((self.scrollY + self.height) / ROW_HEIGHT))
    for i = first, last do
        local row = self.rows[i]
        local y = (i - 1) * ROW_HEIGHT - self.scrollY
        local hovered = mx >= 0 and mx < contentW and my >= y and my < y + ROW_HEIGHT
        if self:isSelected(row.rowId) then
            self:drawRect(1, y + 1, contentW - 2, ROW_HEIGHT - 1, 0.48, 0.24, 0.45, 0.72)
        elseif hovered then
            self:drawRect(1, y + 1, contentW - 2, ROW_HEIGHT - 1, 0.24, 0.42, 0.42, 0.42)
        elseif i % 2 == 0 then
            self:drawRect(1, y + 1, contentW - 2, ROW_HEIGHT - 1, 0.12, 1, 1, 1)
        end
        self:drawText("=", 7, y + 5, 0.68, 0.68, 0.68, 1, UIFont.Small)
        self:drawText(string.format("%02d", i), HANDLE_WIDTH + 2, y + 5, 0.82, 0.82, 0.82, 1, UIFont.Small)
        local label = tostring(row.track and (row.track.label or row.track.sound) or "Unknown track")
        self:drawText(label, HANDLE_WIDTH + 28, y + 5, 1, 1, 1, 1, UIFont.Small)
        if hovered then
            self:drawText("x", contentW - REMOVE_WIDTH + 8, y + 5, 1, 0.55, 0.55, 1, UIFont.Small)
        end
    end
    if self.dragging and self.dropInsertIndex then
        local y = (self.dropInsertIndex - 1) * ROW_HEIGHT - self.scrollY
        if y >= 0 and y <= self.height then
            self:drawRect(2, y - 1, contentW - 4, 3, 0.95, 0.95, 0.75, 0.2)
        end
    end
    local maximum = self:maxScrollY()
    if maximum > 0 then
        local thumbH = math.max(18, self.height * self.height / (#self.rows * ROW_HEIGHT))
        local thumbY = (self.height - thumbH) * (self.scrollY / maximum)
        self:drawRect(contentW + 2, 2, SCROLLBAR_WIDTH - 4, self.height - 4, 0.35, 0.1, 0.1, 0.1)
        self:drawRect(contentW + 2, thumbY, SCROLLBAR_WIDTH - 4, thumbH, 0.75, 0.62, 0.62, 0.62)
    end
end

function MyLastTapeReorderableList:new(x, y, width, height)
    local o = ISPanel.new(self, x, y, width, height)
    o.rows = {}
    o.selectedRowIds = {}
    o.scrollY = 0
    o.dragging = false
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

MyLastTapeReorderableList.copyRows = copyRows

return MyLastTapeReorderableList
