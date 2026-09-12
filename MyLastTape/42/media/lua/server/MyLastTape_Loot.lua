require "Items/ProceduralDistributions"
require "MyLastTape_Metadata"

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"
local TARGETS = {
    BedroomDresser = 0.25,
    BedroomSideTable = 0.5,
    LivingRoomShelf = 1.0,
    LivingRoomSideTable = 0.5,
    DeskGeneric = 0.5,
    ShelfGeneric = 0.25,
    GarageTools = 0.15
}

local function hasItem(items, fullType)
    for i = 1, #items, 2 do
        if tostring(items[i] or "") == fullType then
            return true
        end
    end
    return false
end

local injected = 0
for distributionName, weight in pairs(TARGETS) do
    local distribution = ProceduralDistributions
        and ProceduralDistributions.list
        and ProceduralDistributions.list[distributionName]
        or nil
    local items = distribution and distribution.items or nil
    if type(items) == "table" and not hasItem(items, MEDIA_FULL_TYPE) then
        table.insert(items, MEDIA_FULL_TYPE)
        table.insert(items, weight)
        injected = injected + 1
    end
end

print("[MyLastTape] Loot distribution injected into " .. tostring(injected) .. " procedural lists")

local function initializeSpawnedCassettes(_, _, container)
    local items = container and container.getItems and container:getItems() or nil
    if not (items and items.size and items.get) then
        return
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and tostring(item:getFullType() or "") == MEDIA_FULL_TYPE then
            MyLastTapeMetadata.ensureVisual(item)
        end
    end
end

if Events and Events.OnFillContainer and MyLastTapeLootVisualHookRegistered ~= true then
    Events.OnFillContainer.Add(initializeSpawnedCassettes)
    MyLastTapeLootVisualHookRegistered = true
end
