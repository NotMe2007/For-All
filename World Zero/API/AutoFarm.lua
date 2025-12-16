-- Auto Farm - Complete farming script with mob attacking and flying
-- Combines: NoClip/Flying, Mob Detection, Auto-Attack, and Utility Features
-- loadstring(game:HttpGet("https://pastebin.com/raw/AsGJ0SDU"))()
-- this script is incomplete and may not work as intended

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local VirtualUser = game:GetService('VirtualUser')

-- Configuration via getgenv
local _genv = getgenv()
if _genv.AutoFarmEnabled == nil then
    _genv.AutoFarmEnabled = false
end
if _genv.AutoFarmClass == nil then
    _genv.AutoFarmClass = 'Mage'  -- Default class
end
if _genv.AutoDodgePauseFarm == nil then
    _genv.AutoDodgePauseFarm = false
end

-- Prison Tower integration
local PrisonTowerAPI = nil
local isPrisonTowerLoaded = false
local prisonStartPending = false
local prisonStartAttempts = 0
local prisonStartInProgress = false

-- Atlantis Tower integration
local AtlantisTowerAPI = nil
local isAtlantisTowerLoaded = false
local atlantisStartPending = false
local atlantisStartAttempts = 0
local atlantisStartInProgress = false

-- Movement/positioning tuning
if _genv.AutoFarmHoverHeight == nil then _genv.AutoFarmHoverHeight = 7 end           -- target hover height above ground/target
if _genv.AutoFarmBehindDistance == nil then _genv.AutoFarmBehindDistance = 14 end    -- distance to stay behind target (slightly closer)
if _genv.AutoFarmMaxSpeed == nil then _genv.AutoFarmMaxSpeed = 60 end                -- horizontal speed cap
if _genv.AutoFarmVerticalSpeed == nil then _genv.AutoFarmVerticalSpeed = 35 end      -- vertical speed cap
if _genv.AutoFarmGroundClearance == nil then _genv.AutoFarmGroundClearance = 4 end   -- extra clearance above ground
if _genv.AutoFarmSwitchTargetDistance == nil then _genv.AutoFarmSwitchTargetDistance = 100 end -- drop/retarget beyond this
if _genv.AutoFarmSmoothing == nil then _genv.AutoFarmSmoothing = 0.25 end            -- 0..1 smoothing for target position
-- Avoidance/cluster settings
if _genv.AutoFarmOutsidePadding == nil then _genv.AutoFarmOutsidePadding = 6 end    -- extra outward padding beyond behind distance (closer)
if _genv.AutoFarmAvoidRadius == nil then _genv.AutoFarmAvoidRadius = 9 end           -- radius to avoid other mobs (horizontal)
if _genv.AutoFarmAvoidStrength == nil then _genv.AutoFarmAvoidStrength = 45 end      -- repulsion strength
if _genv.AutoFarmNearbyClusterRadius == nil then _genv.AutoFarmNearbyClusterRadius = 40 end -- cluster radius around target

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

-- Get player
local plr = Players.LocalPlayer
if not plr then
    return
end

-- Detect if player is in Atlantis Tower
-- Atlantis Tower has NextFloorTeleporter
local function isInAtlantisTower()
    local inAtlantis = false
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if missionObjects then
            -- Atlantis Tower: has NextFloorTeleporter
            if missionObjects:FindFirstChild('NextFloorTeleporter') then
                inAtlantis = true
            end
        end
    end)
    return inAtlantis
end

-- Detect if player is in Prison Tower
-- Prison Tower has MissionStart but NOT NextFloorTeleporter
local function isInPrisonTower()
    local inPrison = false
    pcall(function()
        local missionObjects = Workspace:FindFirstChild('MissionObjects')
        if missionObjects then
            -- Prison Tower: has MissionStart + WaveStartGate, but NO NextFloorTeleporter
            if missionObjects:FindFirstChild('MissionStart') and 
               missionObjects:FindFirstChild('WaveStartGate') and
               not missionObjects:FindFirstChild('NextFloorTeleporter') then
                inPrison = true
            end
        end
    end)
    return inPrison
end

-- Load Prison Tower automation script
local function loadPrisonTower()
    if not isPrisonTowerLoaded then
        pcall(function()
            PrisonTowerAPI = loadstring(game:HttpGet('https://pastebin.com/raw/79pjMFtr'))()
            isPrisonTowerLoaded = true
        end)
    end
    return PrisonTowerAPI
end

-- Load Atlantis Tower automation script
local function loadAtlantisTower()
    if not isAtlantisTowerLoaded then
        pcall(function()
            AtlantisTowerAPI = loadstring(game:HttpGet('https://pastebin.com/raw/LBhD6jhw'))()
            isAtlantisTowerLoaded = true
        end)
    end
    return AtlantisTowerAPI
end

-- Trigger floor transitions in towers
local function existDoor()
    if Workspace and Workspace:FindFirstChild('Map') then
        for _, a in ipairs(Workspace.Map:GetChildren()) do
            -- Touch the BoundingBox to trigger floor transition
            if a:FindFirstChild('BoundingBox') then 
                local _, hrp = getPlayerParts()
                if hrp then
                    -- Extra safety: only trigger if no mobs nearby (avoid mid-wave)
                    local mobsContainer = Workspace:FindFirstChild('Mobs')
                    local nearbyMobs = 0
                    if mobsContainer then
                        for _, m in ipairs(mobsContainer:GetChildren()) do
                            local col = m:FindFirstChild('Collider')
                            local hp = m:FindFirstChild('HealthProperties')
                            local h = hp and hp:FindFirstChild('Health')
                            if col and h and h.Value > 0 then
                                if (col.Position - hrp.Position).Magnitude <= 60 then
                                    nearbyMobs = nearbyMobs + 1
                                end
                            end
                        end
                    end
                    if nearbyMobs > 0 then
                        return
                    end
                    firetouchinterest(hrp, a.BoundingBox, 0)
                    wait(.25)
                    firetouchinterest(hrp, a.BoundingBox, 1)
                end
            end
            
            -- Clean up visual obstacles
            pcall(function()
                if a:FindFirstChild('Model') then a.Model:Destroy() end
                if a:FindFirstChild('Tiles') then a.Tiles:Destroy() end
                if a:FindFirstChild('Gate') then a.Gate:Destroy() end
            end)
        end
    end
end

-- Get player components (character, HRP, etc)
local function getPlayerParts()
    if not plr.Character then
        return nil, nil, nil
    end
    
    local character = plr.Character
    local hrp = character:FindFirstChild('HumanoidRootPart')
    local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')
    
    return character, hrp, collider
end

-- NoClip/Flying implementation
local function noClip()
    pcall(function()
        local character, hrp, collider = getPlayerParts()
        if not character or not hrp or not collider then return end
        
        -- Create BodyVelocity for flying
        if not hrp:FindFirstChild('BodyVelocity') then
            local bv = Instance.new('BodyVelocity')
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = 9000
            bv.Parent = hrp
        end

        -- Keep character upright and allow facing target
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
        collider.CanCollide = false
    end)
end

-- Find all alive mobs (excluding player's familiar)
local function getMobs()
    local mobs = {}
    local positions = {}
    
    -- Get player's familiar if they have one
    local familiar = nil
    pcall(function()
        if plr.Character then
            local props = plr.Character:FindFirstChild('Properties')
            if props then
                local famVal = props:FindFirstChild('Familiar')
                if famVal and famVal.Value then
                    familiar = famVal.Value
                end
            end
        end
    end)
    
    pcall(function()
        if Workspace:FindFirstChild('Mobs') then
            for _, mob in ipairs(Workspace.Mobs:GetChildren()) do
                if mob == familiar then
                    -- Skip player's familiar
                elseif mob:FindFirstChild('Collider') and mob:FindFirstChild('HealthProperties') then
                    -- Check if owned by player
                    local mobProps = mob:FindFirstChild('MobProperties')
                    if mobProps and mobProps:FindFirstChild('Owner') and mobProps.Owner.Value == plr then
                        -- Skip owned/tamed mobs
                    else
                        local health = mob.HealthProperties:FindFirstChild('Health')
                        if health and health.Value > 0 then
                            table.insert(mobs, mob)
                            local character, hrp = getPlayerParts()
                            if hrp then
                                table.insert(positions, hrp.Position)
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return mobs, positions
end

-- Move object to specific position using smooth tweening
local tweenSpeed = 76  -- Adjust this value (lower = slower, safer for anti-cheat)
local function moveTo(obj, x, y, z)
    pcall(function()
        local character, hrp = getPlayerParts()
        if not hrp or not obj then return end
        
        local targetCFrame
        if x and y and z then
            targetCFrame = obj.CFrame * CFrame.new(x, y, z)
        else
            targetCFrame = obj.CFrame
        end
        
        -- Calculate distance and time needed
        local distance = (targetCFrame.Position - hrp.Position).Magnitude
        local timeNeeded = distance / tweenSpeed
        
        -- Don't tween if already very close
        if distance < 5 then
            hrp.CFrame = targetCFrame
            return
        end
        
        -- Smooth interpolation using BodyVelocity
        local bv = hrp:FindFirstChild('BodyVelocity')
        if bv then
            local direction = (targetCFrame.Position - hrp.Position).Unit
            bv.Velocity = direction * tweenSpeed
        end
    end)
end

-- Tween to a target position and wait until arrival (blocking)
local function tweenToPosition(targetPos, speed)
    speed = speed or tweenSpeed
    local character, hrp = getPlayerParts()
    if not character or not hrp then return false end
    
    -- Ensure noClip is active for movement
    noClip()
    
    local maxTime = 10 -- timeout after 10 seconds
    local startTime = os.clock()
    
    while true do
        character, hrp = getPlayerParts()
        if not character or not hrp then return false end
        
        local bv = hrp:FindFirstChild('BodyVelocity')
        if not bv then
            noClip()
            bv = hrp:FindFirstChild('BodyVelocity')
            if not bv then return false end
        end
        
        local toTarget = targetPos - hrp.Position
        local distance = toTarget.Magnitude
        
        -- Arrived or timeout
        if distance < 5 then
            bv.Velocity = Vector3.new(0, 0, 0)
            return true
        end
        
        if os.clock() - startTime > maxTime then
            bv.Velocity = Vector3.new(0, 0, 0)
            return false
        end
        
        -- Keep moving toward target
        local direction = toTarget.Unit
        bv.Velocity = direction * speed
        
        wait(0.1)
    end
end

-- Tween + touch helper for tower parts (handles both BasePart and Model)
local function touchWithMove(part)
    local character, hrp = getPlayerParts()
    if not character or not hrp or not part then
        return false
    end
    
    -- Find the actual BasePart to use
    local targetPart = part
    if part:IsA('Model') then
        targetPart = part:FindFirstChild('Collider') or part:FindFirstChildWhichIsA('BasePart') or part.PrimaryPart
    end
    
    if not targetPart or not targetPart:IsA('BasePart') then
        return false
    end

    -- Tween to slightly above the part
    local targetPos = targetPart.Position + Vector3.new(0, 3, 0)
    tweenToPosition(targetPos, tweenSpeed)
    
    -- Now teleport exactly to part and touch
    character, hrp = getPlayerParts()
    if hrp then
        hrp.CFrame = targetPart.CFrame
        wait(0.1)
        
        -- Check for TouchInterest on both the target part and original part
        local touchInterest = targetPart:FindFirstChild('TouchInterest') or part:FindFirstChild('TouchInterest')
        if touchInterest then
            local touchTarget = touchInterest.Parent
            firetouchinterest(hrp, touchTarget, 0)
            wait(0.1)
            firetouchinterest(hrp, touchTarget, 1)
        end
    end

    return true
end

-- Local fallback start for Prison Tower using tweened movement
local function prisonLocalStart()
    local missionObjects = Workspace:FindFirstChild('MissionObjects')
    if not missionObjects then return false end

    -- Step 1: Tween to MissionStart.Collider and touch it
    local missionStart = missionObjects:FindFirstChild('MissionStart')
    if missionStart then
        local collider = missionStart:FindFirstChild('Collider')
        if collider then
            touchWithMove(collider)
        else
            touchWithMove(missionStart)
        end
    end
    
    -- Wait 3 seconds for mission to start
    wait(3)

    -- Step 2: Tween to MinibossSpawn to trigger mob spawning
    local minibossSpawn = missionObjects:FindFirstChild('MinibossSpawn')
    if minibossSpawn then
        touchWithMove(minibossSpawn)
    end

    return true
end

-- Local start for Atlantis Tower using tweened movement
local function atlantisLocalStart()
    local missionObjects = Workspace:FindFirstChild('MissionObjects')
    if not missionObjects then return false end

    -- Step 1: Tween to NextFloorTeleporter and touch it
    local nextTele = missionObjects:FindFirstChild('NextFloorTeleporter')
    if nextTele then
        touchWithMove(nextTele)
    end

    -- Wait 3 seconds for mission to start (same as Prison Tower)
    wait(3)

    -- Step 2: Tween to MinibossSpawn to trigger mob spawning
    local miniboss = missionObjects:FindFirstChild('MinibossSpawn')
    if miniboss then
        touchWithMove(miniboss)
    end

    return true
end

-- Attack mobs with skills (using Kill Aura separately)
local function attackMobs()
    -- Attack is handled by Kill Aura module
    -- This function is a placeholder for future use
end

-- Get player health percentage
local function getHealthPercent()
    -- Prefer server-provided HealthProperties path in Workspace
    local percent = 100
    pcall(function()
        local chars = Workspace:FindFirstChild('Characters')
        if chars and plr and plr.Name then
            local myChar = chars:FindFirstChild(plr.Name)
            if myChar then
                local hpProps = myChar:FindFirstChild('HealthProperties')
                if hpProps then
                    local healthVal = hpProps:FindFirstChild('Health')
                    local maxHealthVal = hpProps:FindFirstChild('MaxHealth')
                    if healthVal and maxHealthVal and maxHealthVal.Value > 0 then
                        percent = (healthVal.Value / maxHealthVal.Value) * 100
                        return
                    end
                end
            end
        end
        -- Fallback to Humanoid if custom path not found
        local character = plr.Character
        if character then
            local humanoid = character:FindFirstChild('Humanoid')
            if humanoid and humanoid.MaxHealth > 0 then
                percent = (humanoid.Health / humanoid.MaxHealth) * 100
            end
        end
    end)
    return percent
end



-- Raycast helpers to find ground and enforce altitude
local _rayParams = RaycastParams.new()
_rayParams.FilterType = Enum.RaycastFilterType.Exclude
_rayParams.IgnoreWater = false

local function getGroundY(originPos, maxDrop)
    local character = plr.Character
    local ignore = {}
    if character then table.insert(ignore, character) end
    _rayParams.FilterDescendantsInstances = ignore
    local start = originPos + Vector3.new(0, 50, 0)
    local dir = Vector3.new(0, -(maxDrop or 600), 0)
    local result = Workspace:Raycast(start, dir, _rayParams)
    if result then return result.Position.Y end
    return nil
end

-- Simple target selection, state, and smoothing
local _state = {
    currentTarget = nil,
    smoothedTargetPos = nil,
    lastTargetChange = 0,
    lastTargetLost = 0,
}

local function isMobAlive(mob)
    if not mob then return false end
    local hpProps = mob:FindFirstChild('HealthProperties')
    local hp = hpProps and hpProps:FindFirstChild('Health')
    return hp and hp.Value and hp.Value > 0
end

local function pickTarget()
    local mobs = getMobs()
    local _, hrp = getPlayerParts()
    if not hrp or #mobs == 0 then return nil end
    local best, bestDist = nil, math.huge
    for _, mob in ipairs(mobs) do
        if isMobAlive(mob) and mob:FindFirstChild('Collider') then
            local d = (mob.Collider.Position - hrp.Position).Magnitude
            if d < bestDist then
                best = mob
                bestDist = d
            end
        end
    end
    return best
end

-- Fly towards mobs (attack handled by Kill Aura)
spawn(function()
    local retreating = false
    local lastDoorCheck = 0
    local lastTowerCheck = 0
    local prisonTowerActive = false
    local atlantisTowerActive = false
    
    while true do
        wait(0.1)
        
        if not _genv.AutoFarmEnabled then
            -- Disable Prison Tower if it was active
            if prisonTowerActive and PrisonTowerAPI then
                PrisonTowerAPI.disable()
                prisonTowerActive = false
            end
            -- Disable Atlantis Tower if it was active
            if atlantisTowerActive and AtlantisTowerAPI then
                AtlantisTowerAPI.disable()
                atlantisTowerActive = false
            end
            -- When disabled, clean up physics immediately
            pcall(function()
                local character, hrp = getPlayerParts()
                if character and hrp then
                    -- Stop BodyVelocity
                    local bv = hrp:FindFirstChild('BodyVelocity')
                    if bv then
                        bv.Velocity = Vector3.new(0, 0, 0)
                    end
                    
                    -- Re-enable collision
                    hrp.CanCollide = true
                    local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')
                    if collider then
                        collider.CanCollide = true
                    end
                end
            end)
            retreating = false
            _state.currentTarget = nil
            _state.smoothedTargetPos = nil
            wait(1)
        else
            -- Skip entire loop iteration if prison start sequence is running
            if prisonStartInProgress or atlantisStartInProgress then
                wait(0.1)
            else
            pcall(function()
                noClip()
                
                -- Pause movement if AutoDodge is active
                if _genv.AutoDodgePauseFarm then
                    -- Just skip AutoFarm movement, let AutoDodge move the character
                    return
                end

                local healthPercent = getHealthPercent()

                -- Check if we need to retreat
                if healthPercent <= 36 and not retreating then
                    retreating = true
                end
                -- If retreating, fly up and wait for HP to recover
                if retreating then
                    local character, hrp = getPlayerParts()
                    if hrp then
                        -- Fly to a safe, fixed altitude above ground
                        local groundY = getGroundY(hrp.Position, 800) or (hrp.Position.Y - 50)
                        local targetHeight = math.max(groundY + _genv.AutoFarmHoverHeight + 30, hrp.Position.Y + 25)
                        local targetPos = Vector3.new(hrp.Position.X, targetHeight, hrp.Position.Z)
                        local bv = hrp:FindFirstChild('BodyVelocity')
                        if bv then
                            local direction = (targetPos - hrp.Position).Unit
                            local distance = (targetPos - hrp.Position).Magnitude
                            
                            -- If we're high enough, stop moving
                            if distance < 5 then
                                bv.Velocity = Vector3.new(0, 0, 0)
                            else
                                -- Vertical rise primarily, minimal horizontal drift
                                local vSign = (targetPos.Y > hrp.Position.Y) and 1 or -1
                                bv.Velocity = Vector3.new(0, _genv.AutoFarmVerticalSpeed * vSign, 0)
                            end
                        end
                        local bg = hrp:FindFirstChild('BodyGyro')
                        if bg then bg.CFrame = CFrame.new(hrp.Position) end
                    end
                    
                    -- Wait for HP to recover to 93%
                    if healthPercent >= 93 then
                        retreating = false
                    end
                    
                    return -- Skip mob targeting while retreating
                end
                
                -- Check tower state every 3 seconds
                local currentTime = os.clock()
                if currentTime - lastTowerCheck >= 3 then
                    -- Check Atlantis FIRST (it has NextFloorTeleporter)
                    local inAtlantis = isInAtlantisTower()
                    local inPrison = (not inAtlantis) and isInPrisonTower()

                    if inAtlantis then
                        -- Disable Prison if it was active
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end

                        -- Load and enable Atlantis Tower
                        if loadAtlantisTower() and not atlantisTowerActive then
                            AtlantisTowerAPI.enable()
                            atlantisTowerActive = true
                            atlantisStartPending = true
                            atlantisStartAttempts = 0
                        end

                        -- Run Atlantis start sequence
                        if AtlantisTowerAPI and atlantisStartPending and not atlantisStartInProgress then
                            atlantisStartPending = false
                            atlantisStartAttempts = atlantisStartAttempts + 1
                            atlantisStartInProgress = true

                            spawn(function()
                                atlantisLocalStart()
                                atlantisStartInProgress = false
                            end)
                        end
                    elseif inPrison then
                        -- Disable Atlantis if it was active
                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end

                        -- Load and enable Prison Tower
                        if loadPrisonTower() and not prisonTowerActive then
                            PrisonTowerAPI.enable()
                            prisonTowerActive = true
                            prisonStartPending = true
                            prisonStartAttempts = 0
                        end

                        -- Run Prison start sequence
                        if PrisonTowerAPI and prisonStartPending and not prisonStartInProgress then
                            prisonStartPending = false
                            prisonStartAttempts = prisonStartAttempts + 1
                            prisonStartInProgress = true

                            spawn(function()
                                prisonLocalStart()
                                prisonStartInProgress = false
                            end)
                        end
                    else
                        if prisonTowerActive and PrisonTowerAPI then
                            PrisonTowerAPI.disable()
                            prisonTowerActive = false
                            prisonStartPending = false
                            prisonStartAttempts = 0
                        end

                        if atlantisTowerActive and AtlantisTowerAPI then
                            AtlantisTowerAPI.disable()
                            atlantisTowerActive = false
                            atlantisStartPending = false
                            atlantisStartAttempts = 0
                        end

                        if currentTime - lastDoorCheck >= 5 then
                            existDoor()
                            lastDoorCheck = currentTime
                        end
                    end

                    lastTowerCheck = currentTime
                end
                
                -- Normal farming behavior
                local character, hrp = getPlayerParts()
                if not hrp then return end

                -- Maintain/choose target with lock to reduce jitter
                local current = _state.currentTarget
                local needNew = false
                if not current or not isMobAlive(current) or not current:FindFirstChild('Collider') then
                    needNew = true
                else
                    local dist = (current.Collider.Position - hrp.Position).Magnitude
                    if dist > _genv.AutoFarmSwitchTargetDistance then
                        needNew = true
                    end
                end
                if needNew then
                    current = pickTarget()
                    _state.currentTarget = current
                    if not current then
                        _state.lastTargetLost = os.clock()
                    end
                    _state.lastTargetChange = os.clock()
                end

                if current and current:FindFirstChild('Collider') then
                    local col = current.Collider

                    -- Compute desired point: bias to mob's back and away from clusters
                    local mobs = getMobs()
                    local center = nil
                    local count = 0
                    for _, m in ipairs(mobs) do
                        if m ~= current and m:FindFirstChild('Collider') then
                            if (m.Collider.Position - col.Position).Magnitude <= _genv.AutoFarmNearbyClusterRadius then
                                if not center then center = Vector3.new(0, 0, 0) end
                                center = center + m.Collider.Position
                                count = count + 1
                            end
                        end
                    end
                    if count > 0 then center = center / count end

                    local behindDir = -(col.CFrame.LookVector) -- stay behind the mob's facing
                    if behindDir.Magnitude < 0.1 then
                        behindDir = Vector3.new(0, 0, -1)
                    end

                    local clusterBias = Vector3.new(0, 0, 0)
                    if center then
                        clusterBias = (col.Position - center)
                        if clusterBias.Magnitude > 0.1 then
                            clusterBias = clusterBias.Unit
                        else
                            clusterBias = Vector3.new(0, 0, 0)
                        end
                    end

                    -- Blend the "behind" offset with a small push away from clustered mobs
                    local blended = (behindDir * 1.35) + (clusterBias * 0.65)
                    if blended.Magnitude < 0.15 then
                        blended = behindDir
                    else
                        blended = blended.Unit
                    end

                    local baseGroundY = getGroundY(col.Position, 600) or col.Position.Y
                    local targetY = math.max(baseGroundY + _genv.AutoFarmHoverHeight + _genv.AutoFarmGroundClearance,
                                              col.Position.Y + _genv.AutoFarmHoverHeight)
                    local behind = math.max(8, _genv.AutoFarmBehindDistance) -- prevent getting too close
                    local desired = col.Position + blended * (behind + _genv.AutoFarmOutsidePadding)
                    desired = Vector3.new(desired.X, targetY, desired.Z)

                    -- Smooth the target to reduce micro-oscillation
                    if not _state.smoothedTargetPos then
                        _state.smoothedTargetPos = desired
                    else
                        _state.smoothedTargetPos = _state.smoothedTargetPos + (desired - _state.smoothedTargetPos) * _genv.AutoFarmSmoothing
                    end
                    local targetPos = _state.smoothedTargetPos

                    -- Move with separated horizontal/vertical components
                    local toTarget = targetPos - hrp.Position
                    local horizontal = Vector3.new(toTarget.X, 0, toTarget.Z)
                    local hDist = horizontal.Magnitude
                    local vDist = toTarget.Y
                    local hTol, vTol = 2.0, 1.5

                    local bv = hrp:FindFirstChild('BodyVelocity')
                    if bv then
                        local vel = Vector3.new(0, 0, 0)
                        local horizDir = nil
                        if hDist > hTol then
                            horizDir = horizontal.Unit
                        end

                        -- Obstacle avoidance: repulse from nearby non-target mobs around our current position
                        local repel = Vector3.new(0,0,0)
                        for _, m in ipairs(mobs) do
                            if m ~= current and m:FindFirstChild('Collider') then
                                local delta = hrp.Position - m.Collider.Position
                                local deltaH = Vector3.new(delta.X, 0, delta.Z)
                                local d = deltaH.Magnitude
                                if d > 0.01 and d < _genv.AutoFarmAvoidRadius then
                                    local strength = (_genv.AutoFarmAvoidRadius - d) / _genv.AutoFarmAvoidRadius
                                    repel = repel + (deltaH.Unit * (strength * _genv.AutoFarmAvoidStrength))
                                end
                            end
                        end

                        local finalH = Vector3.new(0,0,0)
                        if horizDir and repel.Magnitude > 0.1 then
                            finalH = (horizDir * _genv.AutoFarmMaxSpeed + repel)
                            -- limit final horizontal speed
                            local fhm = Vector3.new(finalH.X,0,finalH.Z).Magnitude
                            if fhm > _genv.AutoFarmMaxSpeed then
                                finalH = finalH.Unit * _genv.AutoFarmMaxSpeed
                            end
                        elseif horizDir then
                            finalH = horizDir * _genv.AutoFarmMaxSpeed
                        elseif repel.Magnitude > 0.1 then
                            finalH = repel
                        end

                        vel = vel + Vector3.new(finalH.X, 0, finalH.Z)
                        if math.abs(vDist) > vTol then
                            local vSign = (vDist > 0) and 1 or -1
                            vel = Vector3.new(vel.X, _genv.AutoFarmVerticalSpeed * vSign, vel.Z)
                        end
                        if vel.Magnitude < 1 then
                            vel = Vector3.new(0, 0, 0)
                        end
                        bv.Velocity = vel
                    end

                    -- Keep facing the target (yaw only)
                    local bg = hrp:FindFirstChild('BodyGyro')
                    if bg then
                        local lookAt = Vector3.new(col.Position.X, hrp.Position.Y, col.Position.Z)
                        bg.CFrame = CFrame.new(hrp.Position, lookAt)
                    end

                    -- Attack is handled by Kill Aura module
                else
                    -- No target available - hold position
                    local bv = hrp:FindFirstChild('BodyVelocity')
                    if bv then bv.Velocity = Vector3.new(0, 0, 0) end
                end
            end)
            end -- end of prisonStartInProgress else
        end
    end
end)

-- Utility: Remove damage numbers
if Workspace then
    Workspace.ChildAdded:Connect(function(v)
        if v and v.Name == 'DamageNumber' and _genv.AutoFarmEnabled then
            pcall(function() v:Destroy() end)
        end
    end)
end

-- Utility: Anti-AFK
if plr and plr.Idled then
    plr.Idled:Connect(function()
        if _genv.AutoFarmEnabled then
            pcall(function()
                local camera = Workspace.CurrentCamera
                VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
            end)
        end
    end)
end

-- API for control
local AutoFarmAPI = {}

function AutoFarmAPI.enable()
    _genv.AutoFarmEnabled = true
    -- Prison Tower will auto-enable when detected
end

function AutoFarmAPI.disable()
    _genv.AutoFarmEnabled = false
    -- Disable Prison Tower if active
    if PrisonTowerAPI then
        pcall(function() PrisonTowerAPI.disable() end)
    end
    -- Disable Atlantis Tower if active
    if AtlantisTowerAPI then
        pcall(function() AtlantisTowerAPI.disable() end)
    end
    
    -- Wait a moment for the main loop to stop
    wait(0.2)
    
    -- Clean up physics to prevent stuck state
    pcall(function()
        local character, hrp = getPlayerParts()
        if not character or not hrp then return end
        
        -- Stop and remove BodyVelocity
        local bv = hrp:FindFirstChild('BodyVelocity')
        if bv then
            bv.Velocity = Vector3.new(0, 0, 0)
            wait(0.1)
            bv:Destroy()
        end
        local bg = hrp:FindFirstChild('BodyGyro')
        if bg then
            wait(0.05)
            bg:Destroy()
        end
        
        -- Remove any other physics constraints
        for _, desc in ipairs(character:GetDescendants()) do
            if desc:IsA('BodyVelocity') or desc:IsA('BodyGyro') or desc:IsA('BodyPosition') then
                desc:Destroy()
            end
        end
        
        -- Re-enable collision
        hrp.CanCollide = true
        local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')
        if collider then
            collider.CanCollide = true
        end
        
        -- Reset velocity to zero
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        -- Reset humanoid state
        local humanoid = character:FindFirstChild('Humanoid')
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            wait(0.1)
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

function AutoFarmAPI.toggle()
    _genv.AutoFarmEnabled = not _genv.AutoFarmEnabled
end

function AutoFarmAPI.setClass(className)
    _genv.AutoFarmClass = className
end

-- Manual trigger for tower start sequence (for debugging)
function AutoFarmAPI.startTower()
    if isInAtlantisTower() then
        return atlantisLocalStart()
    elseif isInPrisonTower() then
        return prisonLocalStart()
    end
    return false
end

-- Check which tower is detected
function AutoFarmAPI.detectTower()
    if isInAtlantisTower() then
        return "Atlantis"
    elseif isInPrisonTower() then
        return "Prison"
    end
    return "None"
end

_G.x4k7p = AutoFarmAPI
getgenv().x4k7p = AutoFarmAPI

return AutoFarmAPI
