-- Gamepass Checker - Check if player owns specific gamepasses
-- Gamepass ID 8136250: 1-Item Drop
-- Uses safer method to avoid executor detection
-- https://pastebin.com/raw/44W7VMPv
-- this script is incomplete and may not work as intended

local Players = game:GetService('Players')

local player = Players.LocalPlayer
if not player then
    return
end

-- Gamepass ID for "1-Item Drop"
local ITEM_DROP_PASS_ID = 8136250

-- Configuration
local _genv = getgenv()
if _genv.CheckGamepass == nil then
    _genv.CheckGamepass = true
end

-- Function to check if player owns a gamepass (safer approach)
local function playerOwnsGamepass(userId, gamepassId)
    -- Try to find gamepass info in player's character/profile if available
    pcall(function()
        local playerGui = player:FindFirstChild('PlayerGui')
        if playerGui then
            local profile = playerGui:FindFirstChild('Profile')
            if profile then
                -- Check if gamepass info is stored in profile
                local gamepassInfo = profile:FindFirstChild('Gamepasses')
                if gamepassInfo then
                    for _, pass in ipairs(gamepassInfo:GetChildren()) do
                        if tonumber(pass.Name) == gamepassId then
                            return true
                        end
                    end
                end
            end
        end
    end)
    
    return false
end

-- Check for 1-Item Drop pass on startup (non-blocking)
spawn(function()
    task.wait(2)  -- Give game time to fully load
    
    pcall(function()
        if not player or not player.UserId then
            return
        end
        
        local owns = playerOwnsGamepass(player.UserId, ITEM_DROP_PASS_ID)
        _genv.HasItemDropPass = owns
    end)
end)

-- API for gamepass checking
local GamepassAPI = {}

-- Check 1-Item Drop pass
function GamepassAPI.checkItemDropPass()
    return playerOwnsGamepass(player.UserId, ITEM_DROP_PASS_ID)
end

-- Check any gamepass by ID
function GamepassAPI.checkGamepass(gamepassId)
    return playerOwnsGamepass(player.UserId, gamepassId)
end

-- Get the cached result (from startup check)
function GamepassAPI.hasItemDropPass()
    return _genv.HasItemDropPass or false
end

-- Refresh all checks
function GamepassAPI.refresh()
    pcall(function()
        _genv.HasItemDropPass = GamepassAPI.checkItemDropPass()
    end)
end

_G.k3f7x = GamepassAPI

return GamepassAPI
