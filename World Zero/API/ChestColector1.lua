-- Chest Collection - Auto-collects chests from Tower and world events
-- Handles chest teleportation only
-- https://pastebin.com/raw/9282RzYC

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

-- Configuration via getgenv
local _genv = getgenv()
if _genv.ChestCollectionEnabled == nil then
    _genv.ChestCollectionEnabled = true
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

-- Get HumanoidRootPart
local function getHRP()
    if not plr.Character then
        return nil
    end
    return plr.Character:FindFirstChild('HumanoidRootPart')
end

-- Main chest collection loop (TOWER only)
spawn(function()
    while true do
        wait(1)
        
        if not _genv.ChestCollectionEnabled then
            wait(1)
        else
            pcall(function()
                local hrp = getHRP()
                if not hrp then return end
                
                -- Search in Workspace (Tower)
                for _, v in ipairs(Workspace:GetChildren()) do
                    if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
                        pcall(function()
                            local primaryPart = v.PrimaryPart
                            if primaryPart then
                                primaryPart.CFrame = hrp.CFrame
                            end
                        end)
                    end
                end
            end)
        end
    end
end)

-- Listen for new chests in Workspace (Tower)
Workspace.ChildAdded:Connect(function(v)
    if not _genv.ChestCollectionEnabled then return end
    
    if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
        spawn(function()
            task.wait(0.1)
            pcall(function()
                local hrp = getHRP()
                if hrp and v.PrimaryPart then
                    v.PrimaryPart.CFrame = hrp.CFrame
                end
            end)
        end)
    end
end)

-- API for control
local ChestAPI = {}

function ChestAPI.enable()
    _genv.ChestCollectionEnabled = true
end

function ChestAPI.disable()
    _genv.ChestCollectionEnabled = false
end

function ChestAPI.toggle()
    _genv.ChestCollectionEnabled = not _genv.ChestCollectionEnabled
end

-- Manually collect all visible chests right now
function ChestAPI.collectAll()
    pcall(function()
        local hrp = getHRP()
        if not hrp then return end
        
        local count = 0
        for _, v in ipairs(Workspace:GetChildren()) do
            if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
                pcall(function()
                    if v.PrimaryPart then
                        v.PrimaryPart.CFrame = hrp.CFrame
                        count = count + 1
                    end
                end)
            end
        end
    end)
end

_G.x2m8q = ChestAPI
getgenv().x2m8q = ChestAPI

return ChestAPI
