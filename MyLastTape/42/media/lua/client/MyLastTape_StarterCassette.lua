local MEDIA_FULL_TYPE = "MyLastTape.LastTape"
local STARTER_KEY = "MyLastTapeStarter"

local function isMultiplayerClient()
    return isClient and isClient() == true
end

local function grantStarterCassette()
    if isMultiplayerClient() then
        return
    end

    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not (player and inventory and player.getModData) then
        return
    end

    local playerModData = player:getModData()
    local starter = type(playerModData[STARTER_KEY]) == "table" and playerModData[STARTER_KEY] or nil
    if starter and starter.given == true then
        return
    end

    local cassette = inventory:AddItem(MEDIA_FULL_TYPE)
    if cassette then
        playerModData[STARTER_KEY] = {
            version = 1,
            given = true
        }
        print("[MyLastTape] Granted one blank starter cassette")
    else
        print("[MyLastTape] Starter cassette was not granted; inventory add failed")
    end
end

if Events and Events.OnGameStart and MyLastTapeStarterCassetteRegistered ~= true then
    Events.OnGameStart.Add(grantStarterCassette)
    MyLastTapeStarterCassetteRegistered = true
end
