-- Auto Dodge API (Clean - No Debug Output)
-- Automatically dodge dangerous attacks based on visual indicators and attack patterns

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')

local _genv = getgenv()
local AutoDodgeAPI = {}
AutoDodgeAPI.__index = AutoDodgeAPI

-- Configuration
AutoDodgeAPI.config = {
    enabled = false,
    autoDodgeIndicators = true,
    autoDodgeBossAttacks = true,
    dodgeCooldown = 0.1,
    detectionRadius = 100,
    indicatorCheckInterval = 0.02,
    safeDistance = 40,
    preferBackwardDodge = true,
    tweenDuration = 0.15,
    tweenStyle = Enum.EasingStyle.Quad,
    tweenDirection = Enum.EasingDirection.Out,
}

-- State tracking
AutoDodgeAPI.state = {
    lastDodgeTime = 0,
    isDodging = false,
    isOnCooldown = false,
    actionsModule = nil,
    currentClass = nil,
}

if _genv.AutoDodgePauseFarm == nil then
    _genv.AutoDodgePauseFarm = false
end

-- Initialize modules
function AutoDodgeAPI:Init()
    if self.state.actionsModule then return true end
    
    local success, result = pcall(function()
        local modules = ReplicatedStorage:WaitForChild('Shared', 5):WaitForChild('Modules', 5)
        self.state.actionsModule = require(modules:WaitForChild('Actions', 5))
        
        local plr = Players.LocalPlayer
        if plr and plr.Character then
            local classValue = plr.Character:FindFirstChild('ClassValue')
            if classValue and classValue:IsA('StringValue') then
                self.state.currentClass = classValue.Value
            end
        end
    end)
    
    return self.state.actionsModule ~= nil
end

-- Get player data
function AutoDodgeAPI:GetPlayerData()
    local plr = Players.LocalPlayer
    if not plr then return nil, nil, nil, nil end
    
    local char = plr.Character
    if not char then return plr, nil, nil, nil end
    
    local humanoid = char:FindFirstChild('Humanoid')
    local hrp = char:FindFirstChild('HumanoidRootPart')
    
    return plr, char, humanoid, hrp
end

-- Check if on cooldown
function AutoDodgeAPI:IsOnCooldown()
    local currentTime = tick()
    local timeSinceLastDodge = currentTime - self.state.lastDodgeTime
    
    if timeSinceLastDodge >= self.config.dodgeCooldown then
        self.state.isOnCooldown = false
        return false
    else
        self.state.isOnCooldown = true
        return true
    end
end

-- Scan for attack indicators
function AutoDodgeAPI:ScanForIndicators()
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return {} end
    
    local threats = {}
    local workspace = Workspace
    
    -- Scan for RadialIndicator (circular ground attacks)
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Name == "RadialIndicator" then
                local circleIndicator = obj:FindFirstChild("CircleIndicator")
                if circleIndicator then
                    local dist = (hrp.Position - circleIndicator.Position).magnitude
                    local size = circleIndicator.Size.X
                    
                    table.insert(threats, {
                        type = "RadialIndicator",
                        position = circleIndicator.Position,
                        radius = size / 2,
                        distance = dist,
                        object = obj,
                    })
                end
            end
            
            -- Scan for ConeIndicator (directional cone attacks)
            if obj:IsA("Model") and obj.Name == "ConeIndicator" then
                local coneIndicator = obj:FindFirstChild("ConeIndicator")
                if coneIndicator and coneIndicator:IsA("BasePart") then
                    local dist = (hrp.Position - coneIndicator.Position).magnitude
                    
                    table.insert(threats, {
                        type = "ConeIndicator",
                        position = coneIndicator.Position,
                        radius = 20,
                        distance = dist,
                        object = obj,
                        conePart = coneIndicator,
                        coneLength = 30,
                    })
                end
            end
        end
    end)
    
    -- Scan for Klaus/Kandrix boss attacks
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") then
                local objName = obj.Name
                local pivot = obj.PrimaryPart or (obj:FindFirstChild("End") or obj:FindFirstChild("Beam") or obj:FindFirstChild("Base"))
                
                if not pivot then pivot = obj:FindFirstChildOfClass("BasePart") end
                if not pivot then return end
                
                local dist = (hrp.Position - pivot.Position).magnitude
                
                if objName == "KlausBeam" or objName:find("KlausBeam") then
                    if dist < 60 then
                        table.insert(threats, {
                            type = "KlausIceBeam",
                            position = pivot.Position,
                            radius = 40,
                            distance = dist,
                            object = obj,
                        })
                    end
                end
                
                if objName == "KlausPureIce" or objName:find("KlausPureIce") then
                    if dist < 40 then
                        table.insert(threats, {
                            type = "KlausPureIce",
                            position = pivot.Position,
                            radius = 15,
                            distance = dist,
                            object = obj,
                        })
                    end
                end
                
                if objName:find("Kandrix") or (objName:find("Beam") and not objName:find("Klaus")) then
                    if dist < 50 then
                        table.insert(threats, {
                            type = "Beam",
                            position = pivot.Position,
                            radius = 20,
                            distance = dist,
                            object = obj,
                        })
                    end
                end
            end
        end
    end)
    
    return threats
end

-- Check if position is safe from other threats
function AutoDodgeAPI:IsPositionSafe(position, allThreats, currentThreat)
    for _, otherThreat in ipairs(allThreats) do
        if otherThreat ~= currentThreat then
            local distToThreat = (position - otherThreat.position).magnitude
            if distToThreat <= otherThreat.radius + 3 then
                return false
            end
        end
    end
    return true
end

-- Calculate safe dodge position
function AutoDodgeAPI:GetDodgeTargetPosition(threat, allThreats)
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return nil end
    
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    
    local dodgeVector
    
    if threat then
        -- Cone attacks: dodge perpendicular
        if threat.type == "ConeIndicator" and threat.conePart then
            local conePart = threat.conePart
            local coneDirection = conePart.CFrame.LookVector
            local perpendicularRight = Vector3.new(-coneDirection.Z, 0, coneDirection.X).Unit
            local toPlayer = (hrp.Position - conePart.Position)
            local dotProduct = toPlayer:Dot(perpendicularRight)
            local dodgeDirection = dotProduct > 0 and perpendicularRight or -perpendicularRight
            dodgeVector = dodgeDirection * 25
        
        -- Circular attacks: dodge away from center
        else
            local awayDir = (hrp.Position - threat.position).Unit
            local currentDist = (hrp.Position - threat.position).magnitude
            local requiredDist = threat.radius + 5
            
            if currentDist < requiredDist then
                local escapeDistance = requiredDist - currentDist + self.config.safeDistance
                dodgeVector = awayDir * escapeDistance
            else
                dodgeVector = awayDir * self.config.safeDistance
            end
        end
    elseif self.config.preferBackwardDodge then
        local camLook = camera.CFrame.LookVector
        dodgeVector = -camLook * self.config.safeDistance
    else
        local camRight = camera.CFrame.RightVector
        dodgeVector = camRight * self.config.safeDistance
    end
    
    local targetPos = hrp.Position + dodgeVector
    
    if targetPos.Y < hrp.Position.Y - 5 then
        targetPos = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
    end
    
    -- Smart pathfinding: avoid dodging into other attacks
    if allThreats and #allThreats > 1 then
        if not self:IsPositionSafe(targetPos, allThreats, threat) then
            if threat.type ~= "ConeIndicator" then
                local awayDir = (hrp.Position - threat.position).Unit
                local alternateDirections = {
                    awayDir:Cross(Vector3.new(0, 1, 0)).Unit,
                    -awayDir:Cross(Vector3.new(0, 1, 0)).Unit,
                    -awayDir,
                }
                
                for i, altDir in ipairs(alternateDirections) do
                    local altPos = hrp.Position + (altDir * self.config.safeDistance)
                    altPos = Vector3.new(altPos.X, hrp.Position.Y, altPos.Z)
                    
                    if self:IsPositionSafe(altPos, allThreats, threat) then
                        targetPos = altPos
                        break
                    end
                end
            else
                local conePart = threat.conePart
                if conePart then
                    local coneDirection = conePart.CFrame.LookVector
                    local perpendicularRight = Vector3.new(-coneDirection.Z, 0, coneDirection.X).Unit
                    local toPlayer = (hrp.Position - conePart.Position)
                    local dotProduct = toPlayer:Dot(perpendicularRight)
                    local oppositeDodge = dotProduct > 0 and -perpendicularRight or perpendicularRight
                    local altPos = hrp.Position + (oppositeDodge * 25)
                    altPos = Vector3.new(altPos.X, hrp.Position.Y, altPos.Z)
                    
                    if self:IsPositionSafe(altPos, allThreats, threat) then
                        targetPos = altPos
                    end
                end
            end
        end
    end
    
    return targetPos
end

-- Tween to safety
function AutoDodgeAPI:TweenOutOfDanger(hrp, targetPosition, threat)
    local tweenInfo = TweenInfo.new(
        self.config.tweenDuration,
        self.config.tweenStyle,
        self.config.tweenDirection,
        0,
        false,
        0
    )
    
    local goal = {CFrame = CFrame.new(targetPosition)}
    local tween = TweenService:Create(hrp, tweenInfo, goal)
    tween:Play()
    
    return tween
end

-- Execute dodge
function AutoDodgeAPI:PerformDodge(threat)
    if self.state.isDodging then return false end
    if self:IsOnCooldown() then return false end
    
    local _, char, humanoid, hrp = self:GetPlayerData()
    if not char or not humanoid or not hrp then return false end
    
    if not self:Init() then return false end
    
    self.state.isDodging = true
    _genv.AutoDodgePauseFarm = true
    local success = false
    local allThreats = self:ScanForIndicators()
    
    pcall(function()
        local targetPos = self:GetDodgeTargetPosition(threat, allThreats)
        
        if targetPos then
            local Actions = self.state.actionsModule
            if Actions and Actions.DoDodge then
                Actions:DoDodge(char)
            elseif Actions and Actions.Dodge then
                Actions:Dodge()
            end
            
            self:TweenOutOfDanger(hrp, targetPos, threat)
            success = true
        end
    end)
    
    if success then
        self.state.lastDodgeTime = tick()
    end
    
    task.delay(self.config.tweenDuration + 0.1, function()
        self.state.isDodging = false
        _genv.AutoDodgePauseFarm = false
    end)
    
    return success
end

-- Check if in danger
function AutoDodgeAPI:IsInDanger(threat)
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return false end
    
    local distToThreat = (hrp.Position - threat.position).magnitude
    return distToThreat <= threat.radius + 5
end

-- Main threat detection loop
function AutoDodgeAPI:CheckAndDodge()
    if not self.config.enabled then return end
    if self.state.isDodging then return end
    
    local threats = self:ScanForIndicators()
    
    if #threats > 0 then
        table.sort(threats, function(a, b)
            return a.distance < b.distance
        end)
        
        local mostDangerous = threats[1]
        
        if not self:IsInDanger(mostDangerous) then
            return
        end
        
        local shouldDodge = false
        
        if mostDangerous.type == "RadialIndicator" and self.config.autoDodgeIndicators then
            shouldDodge = true
        end
        
        if self.config.autoDodgeBossAttacks then
            if mostDangerous.type == "Beam" or
               mostDangerous.type:find("Klaus") or
               mostDangerous.type:find("Kandrix") or
               mostDangerous.type == "ConeIndicator" then
                shouldDodge = true
            end
        end
        
        if shouldDodge then
            self:PerformDodge(mostDangerous)
        end
    end
end

-- Manual dodge
function AutoDodgeAPI:ManualDodge()
    return self:PerformDodge(nil)
end

-- Start auto loop
function AutoDodgeAPI:StartAutoLoop()
    if self._loopConnection then return end
    
    self._loopConnection = RunService.Heartbeat:Connect(function()
        if self.config.enabled then
            if tick() % self.config.indicatorCheckInterval < 0.02 then
                self:CheckAndDodge()
            end
        end
    end)
end

-- Stop auto loop
function AutoDodgeAPI:StopAutoLoop()
    if self._loopConnection then
        self._loopConnection:Disconnect()
        self._loopConnection = nil
    end
    
end

-- Enable/Disable
function AutoDodgeAPI:EnableAutoDodge()
    self.config.enabled = true
    self:Init()
    self:StartAutoLoop()
end

function AutoDodgeAPI:DisableAutoDodge()
    self.config.enabled = false
    self:StopAutoLoop()
end

function AutoDodgeAPI:ToggleAutoDodge()
    if self.config.enabled then
        self:DisableAutoDodge()
    else
        self:EnableAutoDodge()
    end
    return self.config.enabled
end

-- Configuration setters
function AutoDodgeAPI:SetTweenDuration(seconds)
    self.config.tweenDuration = math.max(0.05, tonumber(seconds) or 0.2)
end

function AutoDodgeAPI:SetTweenStyle(easingStyle)
    self.config.tweenStyle = easingStyle or Enum.EasingStyle.Quad
end

function AutoDodgeAPI:SetDodgeKey(keyCode)
    self.config.dodgeKey = keyCode
end

function AutoDodgeAPI:SetCooldown(seconds)
    self.config.dodgeCooldown = math.max(0.1, tonumber(seconds) or 0.5)
end

function AutoDodgeAPI:SetAutoIndicators(enabled)
    self.config.autoDodgeIndicators = enabled
end

function AutoDodgeAPI:SetAutoBossAttacks(enabled)
    self.config.autoDodgeBossAttacks = enabled
end

-- Get status
function AutoDodgeAPI:GetStatus()
    return {
        enabled = self.config.enabled,
        onCooldown = self.state.isOnCooldown,
        cooldownRemaining = math.max(0, self.config.dodgeCooldown - (tick() - self.state.lastDodgeTime)),
        isDodging = self.state.isDodging,
        modulesLoaded = self.state.actionsModule ~= nil,
        currentClass = self.state.currentClass,
    }
end

-- Store in global
_G.AutoDodgeAPI = AutoDodgeAPI

return AutoDodgeAPI
