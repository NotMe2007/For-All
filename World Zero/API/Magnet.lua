-- Magnet Test - Coin magnet functionality isolated for testing
-- This script pulls coins to the player automatically
-- loadstring(game:HttpGet("https://pastebin.com/raw/HZQuvwpQ"))()

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')

-- Configuration
local _genv = getgenv()
if _genv.CoinMagnet == nil then
    _genv.CoinMagnet = true
end

-- Custom wait function using Heartbeat
local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do
            RunService.Heartbeat:Wait()
        end
    else
        RunService.Heartbeat:Wait()
    end
end

-- Get player
local plr = Players.LocalPlayer
if not plr then
    return
end

-- Get player character
local function getPlayerPart()
    if not plr.Character then
        return nil
    end
    return plr.Character:FindFirstChild('HumanoidRootPart') or plr.Character:FindFirstChild('Head')
end

-- Main magnet loop
if Workspace:FindFirstChild('Coins') then
    
    -- Handle coins that already exist
    local coinsFolder = Workspace:FindFirstChild('Coins')
    if coinsFolder then
        for _, coin in ipairs(coinsFolder:GetChildren()) do
            if coin.Name == 'CoinPart' then
                spawn(function()
                    while coin and coin.Parent and _genv.CoinMagnet do
                        pcall(function()
                            local playerPart = getPlayerPart()
                            if playerPart and coin:IsA('BasePart') then
                                coin.CanCollide = false
                                coin.CFrame = playerPart.CFrame
                            end
                        end)
                        wait(0.2)
                    end
                end)
            end
        end
    end
    
    -- Handle new coins as they spawn
    Workspace.Coins.ChildAdded:Connect(function(v)
        if v and v.Name == 'CoinPart' and _genv.CoinMagnet then
            spawn(function()
                while v and v.Parent and _genv.CoinMagnet do
                    pcall(function()
                        local playerPart = getPlayerPart()
                        if playerPart and v:IsA('BasePart') then
                            v.CanCollide = false
                            v.CFrame = playerPart.CFrame
                        end
                    end)
                    wait(0.2)
                end
            end)
        end
    end)
end

-- API for control
local MagnetAPI = {}

function MagnetAPI.enable()
    _genv.CoinMagnet = true
end

function MagnetAPI.disable()
    _genv.CoinMagnet = false
end

function MagnetAPI.toggle()
    _genv.CoinMagnet = not _genv.CoinMagnet
end

_G.x7d2k = MagnetAPI

return MagnetAPI
