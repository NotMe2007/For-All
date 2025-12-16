-- Infinite Tower Auto Floor Progression
-- Automatically moves to next floor when all mobs are cleared
-- loadstring(game:HttpGet("https://pastebin.com/6f9cH4ta"))()
-- this script is incomplete and may not work as intended

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')

local _genv = getgenv()
if _genv.InfTowerAutoProgress == nil then
    _genv.InfTowerAutoProgress = false
end

-- Custom wait using Heartbeat
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

local plr = Players.LocalPlayer
if not plr then
    return
end

-- Get player components
local function getPlayerParts()
    if not plr.Character then
        return nil, nil
    end
    
    local character = plr.Character
    local hrp = character:FindFirstChild('HumanoidRootPart')
    
    return character, hrp
end

-- Check if all mobs are dead
local function areAllMobsDead()
    local mobsAlive = 0
    
    pcall(function()
        local mobFolder = Workspace:FindFirstChild('Mobs')
        if not mobFolder then
            return
        end
        
        for _, mob in ipairs(mobFolder:GetChildren()) do
            pcall(function()
                -- Skip player familiars/owned mobs
                local mobProps = mob:FindFirstChild('MobProperties')
                if mobProps and mobProps:FindFirstChild('Owner') and mobProps.Owner.Value == plr then
                    return
                end
                
                local health = mob:FindFirstChild('HealthProperties')
                if health and health:FindFirstChild('Health') then
                    local healthVal = health.Health
                    if healthVal and healthVal.Value and healthVal.Value > 0 then
                        mobsAlive = mobsAlive + 1
                    end
                end
            end)
        end
    end)
    
    return mobsAlive == 0
end

-- Find and trigger the floor transition
local function triggerFloorTransition()
    local success = false
    
    pcall(function()
        local lobbyTeleport = Workspace:FindFirstChild('LobbyTeleport')
        if not lobbyTeleport then
            return
        end
        
        local interaction = lobbyTeleport:FindFirstChild('Interaction')
        if not interaction then
            return
        end
        
        local character, hrp = getPlayerParts()
        if not character or not hrp then
            return
        end
        
        -- Move character to the interaction part
        if interaction:IsA('BasePart') then
            -- Store original position for safety
            local originalPos = hrp.CFrame
            
            -- Teleport to interaction
            hrp.CFrame = interaction.CFrame
            wait(0.1)
            
            -- Fire touch interest
            if interaction:FindFirstChild('TouchInterest') then
                firetouchinterest(hrp, interaction, 0)
                wait(0.1)
                firetouchinterest(hrp, interaction, 1)
                success = true
            end
        end
    end)
    
    -- Also trigger boss gate if available
    pcall(function()
        local bossGate = Workspace:FindFirstChild('Boss_Gate')
        if bossGate then
            local interactions = bossGate:FindFirstChild('Interactions')
            if interactions then
                local children = interactions:GetChildren()
                if children and #children >= 5 then
                    local bossInteraction = children[5]
                    
                    local character, hrp = getPlayerParts()
                    if character and hrp then
                        if bossInteraction:IsA('BasePart') then
                            hrp.CFrame = bossInteraction.CFrame
                            wait(0.1)
                            
                            if bossInteraction:FindFirstChild('TouchInterest') then
                                firetouchinterest(hrp, bossInteraction, 0)
                                wait(0.1)
                                firetouchinterest(hrp, bossInteraction, 1)
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return success
end

-- Main auto-progression loop
spawn(function()
    local lastCheckTime = 0
    local waitingForTransition = false
    
    while true do
        wait(0.5)
        
        if not _genv.InfTowerAutoProgress then
            waitingForTransition = false
            wait(1)
        else
            local currentTime = os.clock()
            
            -- Check every 2 seconds
            if currentTime - lastCheckTime >= 2 then
                lastCheckTime = currentTime
                
                if areAllMobsDead() and not waitingForTransition then
                    waitingForTransition = true
                    
                    -- Wait a moment to ensure all mob deaths registered
                    wait(1)
                    
                    -- Double-check mobs are still dead
                    if areAllMobsDead() then
                        triggerFloorTransition()
                    end
                    
                    waitingForTransition = false
                elseif not areAllMobsDead() then
                    -- Reset if mobs are alive
                    waitingForTransition = false
                end
            end
        end
    end
end)

-- API for control
local InfTowerAPI = {}

function InfTowerAPI.enable()
    _genv.InfTowerAutoProgress = true
end

function InfTowerAPI.disable()
    _genv.InfTowerAutoProgress = false
end

function InfTowerAPI.toggle()
    _genv.InfTowerAutoProgress = not _genv.InfTowerAutoProgress
end

function InfTowerAPI.triggerNow()
    return triggerFloorTransition()
end

_G.InfTowerAPI = InfTowerAPI
getgenv().InfTowerAPI = InfTowerAPI

return InfTowerAPI