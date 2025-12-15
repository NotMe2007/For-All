-- Auto Farm - Complete farming script with mob attacking and flying
-- Combines: NoClip/Flying, Mob Detection, Auto-Attack, and Utility Features
-- loadstring(game:HttpGet("https://pastebin.com/raw/AsGJ0SDU"))()

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

-- Trigger floor transitions in towers
local function existDoor()
    if Workspace and Workspace:FindFirstChild('Map') then
        for _, a in ipairs(Workspace.Map:GetChildren()) do
            -- Touch the BoundingBox to trigger floor transition
            if a:FindFirstChild('BoundingBox') then 
                firetouchinterest(plr.Character, a.BoundingBox, 0)
                wait(.25)
                firetouchinterest(plr.Character, a.BoundingBox, 1)
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

-- Fly towards mobs (attack handled by Kill Aura)
spawn(function()
    local retreating = false
    local lastDoorCheck = 0
    
    while true do
        wait(0.1)
        
        if not _genv.AutoFarmEnabled then
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
            wait(1)
        else
            pcall(function()
                noClip()
                
                -- Pause movement if AutoDodge is actively dodging
                if _genv.AutoDodgePauseFarm then
                    -- Just skip AutoFarm movement, let AutoDodge move the character freely
                    return
                end
                
                local healthPercent = getHealthPercent()
                
                -- Check if we need to retreat
                if healthPercent <= 30 and not retreating then
                    retreating = true
                end
                
                -- If retreating, fly up and wait for HP to recover
                if retreating then
                    local character, hrp = getPlayerParts()
                    if hrp then
                        -- Fly up 120 studs
                        local targetPos = hrp.Position + Vector3.new(0, 120, 0)
                        local bv = hrp:FindFirstChild('BodyVelocity')
                        if bv then
                            local direction = (targetPos - hrp.Position).Unit
                            local distance = (targetPos - hrp.Position).Magnitude
                            
                            -- If we're high enough, stop moving
                            if distance < 10 then
                                bv.Velocity = Vector3.new(0, 0, 0)
                            else
                                bv.Velocity = direction * tweenSpeed
                            end
                        end
                    end
                    
                    -- Wait for HP to recover to 93%
                    if healthPercent >= 93 then
                        retreating = false
                    end
                    
                    return -- Skip mob targeting while retreating
                end
                
                -- Check for floor transitions every 5 seconds
                local currentTime = os.clock()
                if currentTime - lastDoorCheck >= 5 then
                    existDoor()
                    lastDoorCheck = currentTime
                end
                
                -- Normal farming behavior
                local mobs = getMobs()
                
                if #mobs > 0 then
                    -- Find closest mob
                    local character, hrp = getPlayerParts()
                    if not hrp then return end
                    
                    local closest = mobs[1]
                    local closestDist = (closest.Collider.Position - hrp.Position).Magnitude
                    
                    for _, mob in ipairs(mobs) do
                        local dist = (mob.Collider.Position - hrp.Position).Magnitude
                        if dist < closestDist then
                            closest = mob
                            closestDist = dist
                        end
                    end
                    
                    -- Fly above the mob
                    if closest and closest:FindFirstChild('Collider') then
                        moveTo(closest.Collider, 0, 20, 0)
                    end
                    
                    -- Attack is handled by Kill Aura module
                else
                    -- No mobs detected - stay still in air
                    local character, hrp = getPlayerParts()
                    if hrp then
                        local bv = hrp:FindFirstChild('BodyVelocity')
                        if bv then
                            bv.Velocity = Vector3.new(0, 0, 0)
                        end
                    end
                end
            end)
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
end

function AutoFarmAPI.disable()
    _genv.AutoFarmEnabled = false
    
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

_G.x4k7p = AutoFarmAPI
getgenv().x4k7p = AutoFarmAPI

return AutoFarmAPI
