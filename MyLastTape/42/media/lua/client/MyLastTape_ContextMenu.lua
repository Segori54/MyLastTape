require "MyLastTape_Metadata"
require "MyLastTape_RenameWindow"

MyLastTapeContextMenu = MyLastTapeContextMenu or {}

local MEDIA_FULL_TYPE = "MyLastTape.LastTape"

local function itemId(item)
    return item and item.getID and tostring(item:getID() or "") or ""
end

local function findLivePlayerItem(player, id)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not (inventory and NMInventoryHelpers and NMInventoryHelpers.findItemById) then
        return nil
    end
    return NMInventoryHelpers.findItemById(inventory, id)
end

local function isMyLastTape(item)
    return item and item.getFullType
        and tostring(item:getFullType() or "") == MEDIA_FULL_TYPE
end

local function saveRename(player, id, rawName)
    local item = findLivePlayerItem(player, id)
    if not isMyLastTape(item) then
        print("[MyLastTape] Rename failed: cassette is no longer in player inventory")
        return
    end
    local state = MyLastTapeMetadata.readState(item)
    state.name = MyLastTapeMetadata.normalizeName(rawName)
    MyLastTapeMetadata.writeState(item, state)
    print("[MyLastTape] Cassette renamed: id=" .. itemId(item))
end

local function addRenameAction(menu, player, mediaItem)
    if not (menu and player and isMyLastTape(mediaItem)) then
        return
    end
    if not findLivePlayerItem(player, itemId(mediaItem)) then
        return
    end
    local state = MyLastTapeMetadata.readState(mediaItem)
    menu:addOption("Rename", player, function(p, id, initialName)
        MyLastTapeRenameWindow.open(p, id, initialName, saveRename)
    end, itemId(mediaItem), state.name or "")
end

function MyLastTapeContextMenu.installTaliLooseMediaHook()
    local env = _G and _G.NMContextMenusEnv or nil
    if not env or env._myLastTapeRenameWrapped == true then
        return env and env._myLastTapeRenameWrapped == true
    end

    local originalAddLooseMediaActions = env.addLooseMediaActions
    if type(originalAddLooseMediaActions) ~= "function" then
        return false
    end

    env.addLooseMediaActions = function(subMenu, player, mediaItem)
        originalAddLooseMediaActions(subMenu, player, mediaItem)
        addRenameAction(subMenu, player, mediaItem)
    end
    env._myLastTapeRenameWrapped = true
    print("[MyLastTape] Rename action added to Tali cassette menu")
    return true
end

-- New Music is a required dependency, so this normally succeeds at load. The
-- game-start retry only covers an unusual Lua load order without registering a
-- separate inventory-context listener.
if not MyLastTapeContextMenu.installTaliLooseMediaHook()
    and Events and Events.OnGameStart
    and MyLastTapeContextMenu._gameStartRetryRegistered ~= true
then
    Events.OnGameStart.Add(MyLastTapeContextMenu.installTaliLooseMediaHook)
    MyLastTapeContextMenu._gameStartRetryRegistered = true
end
