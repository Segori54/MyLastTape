require "MyLastTape_Metadata"
require "MyLastTape_RenameWindow"
require "MyLastTape_PlaylistWindow"
require "ISUI/ISModalDialog"

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

local function getLiveTape(player, id)
    local item = findLivePlayerItem(player, id)
    return isMyLastTape(item) and item or nil
end

local function showMessage(text)
    local core = getCore and getCore() or nil
    local screenWidth = core and core.getScreenWidth and core:getScreenWidth() or 800
    local screenHeight = core and core.getScreenHeight and core:getScreenHeight() or 600
    local dialog = ISModalDialog:new(
        math.floor((screenWidth - 360) / 2),
        math.floor((screenHeight - 140) / 2),
        360,
        140,
        tostring(text or ""),
        false,
        nil,
        nil
    )
    dialog:initialise()
    dialog:addToUIManager()
end

local function saveRename(player, id, rawName)
    local item = getLiveTape(player, id)
    if not item then
        print("[MyLastTape] Rename failed: cassette is no longer in player inventory")
        return
    end
    local state = MyLastTapeMetadata.readState(item)
    state.name = MyLastTapeMetadata.normalizeName(rawName)
    MyLastTapeMetadata.writeState(item, state)
    print("[MyLastTape] Cassette renamed: id=" .. itemId(item))
end

local function recordPlaylist(player, id)
    local item = getLiveTape(player, id)
    if not item then
        showMessage("This My Last Tape is no longer in your inventory.")
        return
    end
    if not (MyLastTapeAutoDJ and MyLastTapeAutoDJ.buildPlaylist) then
        showMessage("My Last Tape could not build a playlist.")
        return
    end

    local built, count, playlist, recorded = MyLastTapeAutoDJ.buildPlaylist(player, "context_record", false)
    if built ~= true or recorded ~= true or type(playlist) ~= "table" or #playlist < 1 then
        showMessage("No cassette tracks are available. Keep source cassettes in your inventory or an open loot container.")
        return
    end

    local state = MyLastTapeMetadata.readState(item)
    state.playlist = MyLastTapeMetadata.clonePlaylist(playlist)
    state.recorded = true
    MyLastTapeMetadata.writeState(item, state)
    print("[MyLastTape] Cassette recorded: id=" .. itemId(item) .. " tracks=" .. tostring(count))
    showMessage("Recorded " .. tostring(count) .. " tracks on My Last Tape.")
end

-- The editor supplies a working-copy playlist.  Resolve the item again here:
-- an inventory action may have moved or destroyed the cassette while its UI
-- was open.  Do not register NMTrackCatalog here; its entry is global by type
-- and is refreshed by the existing insert flow for the physical cassette.
local function saveEditedPlaylist(player, id, playlist)
    local item = getLiveTape(player, id)
    if not item then
        return false, "This My Last Tape is no longer in your inventory."
    end
    local savedPlaylist = MyLastTapeMetadata.clonePlaylist(playlist)
    local state = MyLastTapeMetadata.readState(item)
    state.playlist = #savedPlaylist > 0 and savedPlaylist or nil
    state.recorded = #savedPlaylist > 0
    if MyLastTapeMetadata.writeState(item, state) ~= true then
        return false, "Could not save this cassette."
    end
    print("[MyLastTape] Cassette playlist edited: id=" .. itemId(item)
        .. " tracks=" .. tostring(#savedPlaylist))
    return true
end

local function viewPlaylist(player, id)
    local item = getLiveTape(player, id)
    if not item then
        return
    end
    local state = MyLastTapeMetadata.readState(item)
    if state.recorded ~= true or type(state.playlist) ~= "table" or #state.playlist < 1 then
        showMessage("This cassette has no recorded playlist.")
        return
    end
    MyLastTapePlaylistEditorWindow.open(
        player,
        id,
        MyLastTapeMetadata.getDisplayName(item),
        state.playlist,
        state,
        saveEditedPlaylist
    )
end

local function erasePlaylist(player, id)
    local item = getLiveTape(player, id)
    if not item then
        return
    end
    local state = MyLastTapeMetadata.readState(item)
    state.playlist = nil
    state.recorded = false
    MyLastTapeMetadata.writeState(item, state)
    if MyLastTapeAutoDJ and MyLastTapeAutoDJ.clearRegisteredPlaylist then
        MyLastTapeAutoDJ.clearRegisteredPlaylist()
    end
    print("[MyLastTape] Cassette erased: id=" .. itemId(item))
end

local function confirmErase(player, id)
    local core = getCore and getCore() or nil
    local screenWidth = core and core.getScreenWidth and core:getScreenWidth() or 800
    local screenHeight = core and core.getScreenHeight and core:getScreenHeight() or 600
    local dialog = ISModalDialog:new(
        math.floor((screenWidth - 400) / 2),
        math.floor((screenHeight - 150) / 2),
        400,
        150,
        "Erase this cassette's recorded playlist? This cannot be undone.",
        true,
        nil,
        function(_, button)
            if button and button.internal == "YES" then
                erasePlaylist(player, id)
            end
        end
    )
    dialog:initialise()
    dialog:addToUIManager()
end

local function addTapeActions(menu, player, mediaItem)
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

    if state.recorded == true then
        menu:addOption("View Playlist", player, viewPlaylist, itemId(mediaItem))
        menu:addOption("Re-record", player, recordPlaylist, itemId(mediaItem))
        menu:addOption("Erase", player, confirmErase, itemId(mediaItem))
    else
        menu:addOption("Record", player, recordPlaylist, itemId(mediaItem))
    end
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
        addTapeActions(subMenu, player, mediaItem)
    end
    env._myLastTapeRenameWrapped = true
    print("[MyLastTape] Cassette actions added to Tali cassette menu")
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
