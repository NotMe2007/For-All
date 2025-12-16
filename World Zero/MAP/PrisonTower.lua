-- Prison Tower Auto Floor Progression
-- Automatically progresses through floors by triggering mission gates and spawns
-- Waits for mobs to be cleared before moving to next floor
-- https://pastebin.com/79pjMFtr
-- this script is incomplete and may not work as intended

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')

local _genv = getgenv()
if _genv.PrisonTowerAutoProgress == nil then
    _genv.PrisonTowerAutoProgress = false
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

-- NoClip/Flying setup for tweening
local function setupFlight()
    local character, hrp = getPlayerParts()
    if not character or not hrp then return false end
    
    pcall(function()
        local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')
        
        -- Create BodyVelocity for flying
        if not hrp:FindFirstChild('BodyVelocity') then
            local bv = Instance.new('BodyVelocity')
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = 9000
            bv.Parent = hrp
        end

        -- Keep character upright
        if not hrp:FindFirstChild('BodyGyro') then
            local bg = Instance.new('BodyGyro')
            bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            bg.P = 1e5
            bg.D = 500
            bg.CFrame = hrp.CFrame
            bg.Parent = hrp
        end
        
        -- Disable collision
        hrp.CanCollide = false
        if collider then collider.CanCollide = false end
    end)
    
    return true
end

-- Tween to a target position (smooth fly)
local tweenSpeed = 76
local function tweenToPosition(targetPos)
    local character, hrp = getPlayerParts()
    if not character or not hrp then return false end
    
    setupFlight()
    
    local maxTime = 15 -- timeout
    local startTime = os.clock()
    
    while true do
        character, hrp = getPlayerParts()
        if not character or not hrp then return false end
        
        local bv = hrp:FindFirstChild('BodyVelocity')
        if not bv then
            setupFlight()
            bv = hrp:FindFirstChild('BodyVelocity')
            if not bv then return false end
        end
        
        local toTarget = targetPos - hrp.Position
        local distance = toTarget.Magnitude
        
        -- Arrived or timeout
        if distance < 8 then
            bv.Velocity = Vector3.new(0, 0, 0)
            return true
        end
        
        if os.clock() - startTime > maxTime then
            bv.Velocity = Vector3.new(0, 0, 0)
            return false
        end
        
        -- Keep moving toward target
        local direction = toTarget.Unit
        bv.Velocity = direction * tweenSpeed
        
        wait(0.1)
    end
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

-- Fire touch interest on a part (handles both BasePart and Model)
local function touchPart(part)
    if not part then
        return false
    end
    
    local character, hrp = getPlayerParts()
    if not character or not hrp then
        return false
    end
    
    local success = false
    pcall(function()
        local targetPart = part
        
        -- If it's a Model, find a BasePart inside it
        if part:IsA('Model') then
            targetPart = part:FindFirstChild('Collider') or part:FindFirstChildWhichIsA('BasePart') or part.PrimaryPart
        end
        
        if targetPart and targetPart:IsA('BasePart') then
            -- Teleport to part
            hrp.CFrame = targetPart.CFrame
            wait(0.1)
            
            -- Fire touch interest if it exists (check both the target and original part)
            local touchInterest = targetPart:FindFirstChild('TouchInterest') or part:FindFirstChild('TouchInterest')
            if touchInterest then
                local touchTarget = touchInterest.Parent
                firetouchinterest(hrp, touchTarget, 0)
                wait(0.1)
                firetouchinterest(hrp, touchTarget, 1)
                success = true
            else
                -- Even if no TouchInterest, still count as success (for open gates)
                success = true
            end
        end
    end)
    
    return success
end

-- Start a new floor/wave
local function startFloor()
    local success = false
    
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if not missionObjects then
            return
        end
        
        -- Step 1: Go to MissionStart.Collider.TouchInterest (if it exists)
        local missionStart = missionObjects:FindFirstChild('MissionStart')
        if missionStart then
            local collider = missionStart:FindFirstChild('Collider')
            if collider then
                touchPart(collider)
                success = true
            end
        end
        
        -- Step 2: Wait 3 seconds (always wait, regardless of MissionStart result)
        wait(3)
        
        -- Step 3: TWEEN down to MinibossSpawn to trigger mob spawning (always do this)
        local minibossSpawn = missionObjects:FindFirstChild('MinibossSpawn')
        if minibossSpawn then
            -- Get the position to tween to
            local targetPos
            if minibossSpawn:IsA('BasePart') then
                targetPos = minibossSpawn.Position
            elseif minibossSpawn:IsA('Model') then
                local part = minibossSpawn:FindFirstChild('Collider') or minibossSpawn:FindFirstChildWhichIsA('BasePart') or minibossSpawn.PrimaryPart
                if part then targetPos = part.Position end
            end
            
            if targetPos then
                -- Tween to MinibossSpawn (smooth fly down)
                tweenToPosition(targetPos)
                -- Then touch it
                touchPart(minibossSpawn)
                success = true
            end
        end
    end)
    
    return success
end

-- Complete a floor and move to next
local function completeFloor()
    local success = false
    
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if not missionObjects then
            return
        end
        
        -- Step 1: Go to WaveExit.TouchInterest
        local waveExit = missionObjects:FindFirstChild('WaveExit')
        if waveExit then
            if touchPart(waveExit) then
                -- Step 2: Wait 1 second
                wait(1)
                
                -- Step 3: Go to WaveStartGate.Collider (gate is already open, no TouchInterest)
                local waveStartGate = missionObjects:FindFirstChild('WaveStartGate')
                if waveStartGate then
                    local collider = waveStartGate:FindFirstChild('Collider')
                    if collider then
                        touchPart(collider)
                        success = true
                    end
                end
            end
        end
    end)
    
    return success
end

-- Main auto-progression loop
spawn(function()
    local lastDeadCheckTime = 0
    local consecutiveDeadTime = 0
    local waitingForTransition = false
    local currentFloor = 1  -- Start at floor 1
    
    while true do
        wait(0.5)
        
        if not _genv.PrisonTowerAutoProgress then
            waitingForTransition = false
            consecutiveDeadTime = 0
            wait(1)
        else
            local currentTime = os.clock()
            
            -- Check if mobs are dead
            if areAllMobsDead() then
                -- Track how long mobs have been dead
                if consecutiveDeadTime == 0 then
                    consecutiveDeadTime = currentTime
                end
                
                -- If mobs have been dead for more than 5 seconds, proceed to next floor
                if currentTime - consecutiveDeadTime >= 5 and not waitingForTransition then
                    waitingForTransition = true
                    
                    -- Complete current floor
                    if completeFloor() then
                        currentFloor = currentFloor + 1
                        
                        -- Wait a moment for transition
                        wait(1)
                        
                        -- Check if it's boss floor (floor 5 - after incrementing, currentFloor is now 5)
                        if currentFloor < 5 then
                            -- Start next floor (floors 2, 3, 4)
                            startFloor()
                        elseif currentFloor == 5 then
                            -- Floor 5 is boss floor - do MissionStart then BossDoorTrigger instead of MinibossSpawn
                            local missionObjects = Workspace:FindFirstChild('MissionObjects')
                            if missionObjects then
                                -- Step 1: Touch MissionStart.Collider (like normal)
                                local missionStart = missionObjects:FindFirstChild('MissionStart')
                                if missionStart then
                                    local collider = missionStart:FindFirstChild('Collider')
                                    if collider then
                                        touchPart(collider)
                                    end
                                end
                                
                                -- Step 2: Wait 3 seconds
                                wait(3)
                                
                                -- Step 3: Tween to and trigger BossDoorTrigger (instead of MinibossSpawn)
                                local bossDoorTrigger = missionObjects:FindFirstChild('BossDoorTrigger')
                                if bossDoorTrigger then
                                    -- Get the position to tween to
                                    local targetPos
                                    if bossDoorTrigger:IsA('BasePart') then
                                        targetPos = bossDoorTrigger.Position
                                    elseif bossDoorTrigger:IsA('Model') then
                                        local part = bossDoorTrigger:FindFirstChild('Collider') or bossDoorTrigger:FindFirstChildWhichIsA('BasePart') or bossDoorTrigger.PrimaryPart
                                        if part then targetPos = part.Position end
                                    end
                                    
                                    if targetPos then
                                        tweenToPosition(targetPos)
                                    end
                                    touchPart(bossDoorTrigger)
                                end
                            end
                        end
                    end
                    
                    consecutiveDeadTime = 0
                    waitingForTransition = false
                end
            else
                -- Mobs are alive, reset timer
                consecutiveDeadTime = 0
                waitingForTransition = false
            end
        end
    end
end)

-- API for control
local PrisonTowerAPI = {}

function PrisonTowerAPI.enable()
    _genv.PrisonTowerAutoProgress = true
end

function PrisonTowerAPI.disable()
    _genv.PrisonTowerAutoProgress = false
end

function PrisonTowerAPI.toggle()
    _genv.PrisonTowerAutoProgress = not _genv.PrisonTowerAutoProgress
end

function PrisonTowerAPI.startFloor()
    return startFloor()
end

function PrisonTowerAPI.completeFloor()
    return completeFloor()
end

_G.PrisonTowerAPI = PrisonTowerAPI
getgenv().PrisonTowerAPI = PrisonTowerAPI

return PrisonTowerAPI
