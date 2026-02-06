--[[
    Tank Simulator Script
    Using Rayfield UI Library
    Game ID: 89048211727318
    
    Features:
    - Auto Fire
    - Auto Spin
    - Tank/Player ESP
    - Auto Respawn
    - Teleport Features
    - Stats Display
    - Level Dupe
    - Gems Dupe
    - Auto Claim XP/Rewards
    - Damage Aura
    - Bullet Speed Manipulator
    - Fixed Walk Speed (Continuous)
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Player
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

-- Wait for game to load
repeat task.wait() until ReplicatedStorage:FindFirstChild("Modules")

-- Game Modules (safely load)
local Network, ClientData, ClientTankHandler, Formulas, Tanks, Buffs

pcall(function()
    Network = require(ReplicatedStorage.Modules.Network)
    ClientData = require(ReplicatedStorage.Modules.ClientData)
    Formulas = require(ReplicatedStorage.Data.Formulas)
    Tanks = require(ReplicatedStorage.Data.Tanks)
    Buffs = require(ReplicatedStorage.Data.Buffs)
end)

-- Try to get ClientTankHandler from Services
pcall(function()
    ClientTankHandler = require(ReplicatedStorage.Services.ClientTankHandler)
end)

-- Try to get SharedTankHandler for enemy tank data
local SharedTankHandler
pcall(function()
    SharedTankHandler = require(ReplicatedStorage.Services.SharedTankHandler)
end)

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Variables
local AutoFireEnabled = false
local AutoSpinEnabled = false
local PlayerESPEnabled = false
local TankESPEnabled = false
local AutoRespawnEnabled = false
local AutoSpawnEnabled = false
local InfiniteYieldLoaded = false
local ShowHealthBars = true
local ShowDistance = true
local ShowLevel = true
local ESPColor = Color3.fromRGB(255, 0, 0)
local TeamCheck = false
local SpinSpeed = 5
local CurrentFOV = 70

-- Kill Aura Variables
local KillAuraEnabled = false
local KillAuraRange = 100
local KillAuraPriority = "Closest" -- "Closest", "LowestHealth", "HighestLevel"
local KillAuraAutoFire = true
local SilentAimEnabled = false
local AimPrediction = true
local PredictionAmount = 0.1
local ShowTargetESP = true
local CurrentTarget = nil
local TargetHighlight = nil
local LockOnTarget = false -- When true, keeps targeting same enemy until dead
local LockedTarget = nil

-- XP Magnet Variables
local XPMagnetEnabled = false
local XPMagnetRange = 200 -- How far to search for food
local XPMagnetSpeed = 0.1 -- How often to pull food (seconds)
local XPMagnetTeleportDistance = 5 -- How close to teleport food to player
local XPMagnetLastPull = 0
local CollectCratesEnabled = false

-- Exploit Variables
local DupeLevelEnabled = false
local DupeGemsEnabled = false
local AutoClaimXPEnabled = false
local DupeAmount = 1000
local DupeSpeed = 0.5
local LastDupeTime = 0

-- Damage Aura Variables
local DamageAuraEnabled = false
local DamageAuraRange = 50
local DamageAuraMultiplier = 2
local DamageAuraSpeed = 0.1
local LastDamageAuraTime = 0

-- Bullet Speed Variables
local BulletSpeedEnabled = false
local BulletSpeedMultiplier = 2
local CustomBulletSpeed = 160

-- Speed Fix Variables
local SpeedBoostEnabled = false
local TargetWalkSpeed = 16
local TargetJumpPower = 50

-- Connections
local Connections = {}
local ESPObjects = {}

-- Helper Functions
local function GetCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function GetHumanoidRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetTank()
    if ClientTankHandler and ClientTankHandler.Tank then
        return ClientTankHandler.Tank
    end
    local char = GetCharacter()
    return char and char:FindFirstChild("Tank")
end

local function GetPlayerData()
    if ClientData and ClientData.Value then
        return ClientData.Value
    end
    return nil
end

local function IsPlaying()
    return Player:GetAttribute("Playing") == true
end

local function GetAllTanks()
    local tanks = {}
    
    -- Method 1: Use SharedTankHandler.Cache (most accurate - contains all tank data)
    if SharedTankHandler and SharedTankHandler.Cache then
        for controller, tankData in pairs(SharedTankHandler.Cache) do
            if tankData and tankData.RootPart and tankData.Health and tankData.Health > 0 then
                local plr = nil
                if type(controller) == "userdata" and controller:IsA("Player") then
                    plr = controller
                elseif type(controller) == "number" then
                    plr = Players:GetPlayerByUserId(controller)
                end
                
                table.insert(tanks, {
                    Model = tankData.Model,
                    Character = tankData.Character,
                    RootPart = tankData.RootPart,
                    Player = plr,
                    Controller = controller,
                    Name = tankData.Character and tankData.Character.Name or tostring(controller),
                    Health = tankData.Health,
                    MaxHealth = tankData.MaxHealth,
                    Level = tankData.Level or 1,
                    Team = tankData.Team or 0,
                    Playing = tankData.Playing,
                    TankData = tankData -- Store full tank data reference
                })
            end
        end
    end
    
    -- Method 2: Fallback to workspace.Live folder
    if #tanks == 0 then
        local liveFolder = workspace:FindFirstChild("Live")
        if liveFolder then
            for _, playerFolder in pairs(liveFolder:GetChildren()) do
                local tank = playerFolder:FindFirstChild("Tank") or playerFolder:FindFirstChildOfClass("Model")
                local rootPart = playerFolder:FindFirstChild("HumanoidRootPart")
                if tank and rootPart then
                    local plr = Players:FindFirstChild(playerFolder.Name) or Players:GetPlayerByUserId(tonumber(playerFolder.Name) or 0)
                    table.insert(tanks, {
                        Model = tank,
                        Character = playerFolder,
                        RootPart = rootPart,
                        Player = plr,
                        Controller = plr or playerFolder.Name,
                        Name = playerFolder.Name,
                        Health = plr and plr:GetAttribute("Health") or 100,
                        MaxHealth = plr and plr:GetAttribute("MaxHealth") or 100,
                        Level = plr and plr:GetAttribute("Level") or 1,
                        Team = plr and plr:GetAttribute("Team") or 0,
                        Playing = plr and plr:GetAttribute("Playing")
                    })
                end
            end
        end
    end
    
    return tanks
end

local function GetPlayerTeam(plr)
    if plr and plr:GetAttribute("Team") then
        return plr:GetAttribute("Team")
    end
    return 0
end

local function IsSameTeam(plr)
    if not TeamCheck then return false end
    return GetPlayerTeam(Player) == GetPlayerTeam(plr) and GetPlayerTeam(Player) ~= 0
end

-- Kill Aura Helper Functions
local function GetEnemyTanks()
    local enemies = {}
    local hrp = GetHumanoidRootPart()
    if not hrp then return enemies end
    
    local myTeam = Player:GetAttribute("Team") or 0
    local tanks = GetAllTanks()
    
    for _, tankData in pairs(tanks) do
        -- Skip our own tank
        local isOurTank = false
        if tankData.Player and tankData.Player == Player then
            isOurTank = true
        elseif tankData.Controller == Player then
            isOurTank = true
        elseif tankData.Name == Player.Name or tankData.Name == tostring(Player.UserId) then
            isOurTank = true
        end
        
        if not isOurTank then
            -- Team check
            local enemyTeam = tankData.Team or 0
            local isSameTeam = TeamCheck and myTeam ~= 0 and myTeam == enemyTeam
            
            if not isSameTeam then
                -- Get position from RootPart, Hitbox, or Model
                local targetPart = tankData.RootPart 
                    or (tankData.Model and tankData.Model:FindFirstChild("Hitbox"))
                    or (tankData.Model and tankData.Model.PrimaryPart)
                    or (tankData.Character and tankData.Character:FindFirstChild("HumanoidRootPart"))
                
                if targetPart then
                    local distance = (hrp.Position - targetPart.Position).Magnitude
                    
                    -- Only include if in range and alive
                    local health = tankData.Health or 100
                    local isPlaying = tankData.Playing ~= false
                    
                    if distance <= KillAuraRange and health > 0 and isPlaying then
                        table.insert(enemies, {
                            Model = tankData.Model,
                            Character = tankData.Character,
                            Player = tankData.Player,
                            Controller = tankData.Controller,
                            Name = tankData.Name,
                            Part = targetPart,
                            Distance = distance,
                            Health = health,
                            MaxHealth = tankData.MaxHealth or 100,
                            Level = tankData.Level or 1,
                            Team = enemyTeam,
                            TankData = tankData.TankData -- Full tank data if available
                        })
                    end
                end
            end
        end
    end
    
    return enemies
end

local function GetBestTarget()
    local enemies = GetEnemyTanks()
    if #enemies == 0 then 
        LockedTarget = nil
        return nil 
    end
    
    -- Lock-on mode: keep targeting same enemy if still valid
    if LockOnTarget and LockedTarget then
        for _, enemy in pairs(enemies) do
            if enemy.Name == LockedTarget and enemy.Health > 0 then
                return enemy
            end
        end
        -- Locked target no longer valid, clear it
        LockedTarget = nil
    end
    
    -- Sort by priority
    if KillAuraPriority == "Closest" then
        table.sort(enemies, function(a, b)
            return a.Distance < b.Distance
        end)
    elseif KillAuraPriority == "LowestHealth" then
        table.sort(enemies, function(a, b)
            return a.Health < b.Health
        end)
    elseif KillAuraPriority == "HighestLevel" then
        table.sort(enemies, function(a, b)
            return a.Level > b.Level
        end)
    end
    
    local target = enemies[1]
    
    -- Set locked target for lock-on mode
    if LockOnTarget and target then
        LockedTarget = target.Name
    end
    
    return target
end

-- Calculate angle using the game's actual formula: math.atan2(x, z) + π
local function GetAngleToTarget(targetPosition)
    local hrp = GetHumanoidRootPart()
    if not hrp then return 0 end
    
    local direction = (targetPosition - hrp.Position)
    local dirX = direction.X
    local dirZ = direction.Z
    
    -- Game uses: math.atan2(x, z) + π for LookDirection
    local angle = math.atan2(dirX, dirZ) + math.pi
    
    -- Normalize the angle (game's normalize function)
    while angle > math.pi do
        angle = angle - 2 * math.pi
    end
    while angle < -math.pi do
        angle = angle + 2 * math.pi
    end
    
    return angle
end

local function PredictTargetPosition(target)
    if not AimPrediction then
        return target.Part.Position
    end
    
    local velocity = Vector3.new(0, 0, 0)
    pcall(function()
        -- Try multiple ways to get velocity
        if target.Part:IsA("BasePart") then
            velocity = target.Part.AssemblyLinearVelocity or target.Part.Velocity or Vector3.new(0, 0, 0)
        end
        
        -- Also check parent character's rootpart
        if velocity.Magnitude < 0.1 and target.Character then
            local charRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if charRoot then
                velocity = charRoot.AssemblyLinearVelocity or charRoot.Velocity or Vector3.new(0, 0, 0)
            end
        end
    end)
    
    -- Calculate prediction based on distance and bullet speed
    local hrp = GetHumanoidRootPart()
    if hrp then
        local distance = (hrp.Position - target.Part.Position).Magnitude
        local bulletSpeed = 80 -- Approximate bullet speed
        local travelTime = distance / bulletSpeed
        local predictionTime = math.clamp(travelTime * PredictionAmount * 10, 0, 0.5)
        return target.Part.Position + (velocity * predictionTime)
    end
    
    return target.Part.Position + (velocity * PredictionAmount)
end

local function UpdateTargetHighlight(target)
    -- Remove old highlight if target changed
    if TargetHighlight then
        pcall(function()
            TargetHighlight:Destroy()
        end)
        TargetHighlight = nil
    end
    
    if not target or not ShowTargetESP then return end
    
    pcall(function()
        local highlightParent = target.Model or target.Character
        if highlightParent then
            local highlight = Instance.new("Highlight")
            highlight.Name = "KillAuraTarget"
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
            highlight.FillTransparency = 0.3
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = highlightParent
            highlight.Parent = highlightParent
            TargetHighlight = highlight
        end
    end)
end

local lastTargetName = nil
local function DoKillAura()
    if not KillAuraEnabled then 
        if TargetHighlight then
            pcall(function()
                TargetHighlight:Destroy()
            end)
            TargetHighlight = nil
        end
        CurrentTarget = nil
        lastTargetName = nil
        return 
    end
    if not IsPlaying() then return end
    
    local target = GetBestTarget()
    
    -- Update highlight if target changed
    local targetName = target and target.Name or nil
    if targetName ~= lastTargetName then
        lastTargetName = targetName
        CurrentTarget = target
        UpdateTargetHighlight(target)
    end
    
    if not target then return end
    
    pcall(function()
        if ClientTankHandler then
            -- Predict target position for better accuracy
            local predictedPos = PredictTargetPosition(target)
            
            -- Calculate angle using the game's actual formula
            local angle = GetAngleToTarget(predictedPos)
            
            -- Set tank look direction using the game's method
            -- The game uses SetLookAngle or direct LookDirection assignment
            if ClientTankHandler.SetLookAngle then
                ClientTankHandler.SetLookAngle(angle)
            else
                ClientTankHandler.LookDirection = angle
            end
            
            -- Also update the tank's AlignOrientation directly for immediate response
            local tank = ClientTankHandler.Tank
            if tank and tank.AlignOrientation then
                tank.AlignOrientation.CFrame = CFrame.Angles(0, -angle + math.pi, 0)
                tank.LastDirection = CFrame.Angles(0, -angle + math.pi, 0).LookVector
            end
            
            -- Auto fire if enabled
            if KillAuraAutoFire then
                if ClientTankHandler.Firing and ClientTankHandler.Firing.Set then
                    ClientTankHandler.Firing:Set(true)
                elseif ClientTankHandler.Firing then
                    ClientTankHandler.Firing.Value = true
                end
            end
        end
    end)
end

-- Channel Helper (matches game's Network system)
local function FireChannel(channelName, ...)
    local args = {...}
    pcall(function()
        if Network and Network.Channel then
            Network.Channel(channelName):FireServer(unpack(args))
        end
    end)
end

local function InvokeChannel(channelName, ...)
    local args = {...}
    local result = nil
    pcall(function()
        if Network and Network.Channel then
            result = Network.Channel(channelName):InvokeServer(unpack(args))
        end
    end)
    return result
end

-- ESP Functions
local function RemoveESP(name)
    if ESPObjects[name] then
        pcall(function()
            if ESPObjects[name].Highlight then
                ESPObjects[name].Highlight:Destroy()
            end
            if ESPObjects[name].Billboard then
                ESPObjects[name].Billboard:Destroy()
            end
        end)
        ESPObjects[name] = nil
    end
end

local function CreateESP(target, name, color)
    if ESPObjects[name] then
        RemoveESP(name)
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. name
    highlight.FillColor = color or ESPColor
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = target
    highlight.Parent = target
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard_" .. name
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = target:FindFirstChild("Hitbox") or target.PrimaryPart or target:FindFirstChildOfClass("BasePart")
    billboard.Parent = target
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = color or ESPColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Text = name
    nameLabel.Parent = billboard
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Color3.new(1, 1, 1)
    infoLabel.TextStrokeTransparency = 0
    infoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.Text = ""
    infoLabel.Parent = billboard
    
    ESPObjects[name] = {
        Highlight = highlight,
        Billboard = billboard,
        Target = target
    }
    
    return ESPObjects[name]
end

local function ClearAllESP()
    for name, _ in pairs(ESPObjects) do
        RemoveESP(name)
    end
end

local function UpdateESP()
    if not PlayerESPEnabled and not TankESPEnabled then
        ClearAllESP()
        return
    end
    
    local hrp = GetHumanoidRootPart()
    if not hrp then return end
    
    local tanks = GetAllTanks()
    local currentNames = {}
    
    for _, tankData in pairs(tanks) do
        if tankData.Player and tankData.Player ~= Player then
            if not IsSameTeam(tankData.Player) then
                local name = tankData.Name
                currentNames[name] = true
                
                local espTarget = tankData.Model
                if not ESPObjects[name] and espTarget then
                    local color = ESPColor
                    if tankData.Player:GetAttribute("Team") == 1 then
                        color = Color3.fromRGB(255, 100, 100) -- Red team
                    elseif tankData.Player:GetAttribute("Team") == 2 then
                        color = Color3.fromRGB(100, 100, 255) -- Blue team
                    end
                    CreateESP(espTarget, name, color)
                end
                
                -- Update info
                if ESPObjects[name] and ESPObjects[name].Billboard then
                    local billboard = ESPObjects[name].Billboard
                    local infoLabel = billboard:FindFirstChild("InfoLabel")
                    if infoLabel then
                        local info = {}
                        
                        if ShowDistance then
                            local targetPart = espTarget:FindFirstChild("Hitbox") or espTarget.PrimaryPart or espTarget:FindFirstChildOfClass("BasePart")
                            if targetPart and hrp then
                                local dist = math.floor((hrp.Position - targetPart.Position).Magnitude)
                                table.insert(info, dist .. " studs")
                            end
                        end
                        
                        if ShowLevel and tankData.Player then
                            local level = tankData.Player:GetAttribute("Level")
                            if level then
                                table.insert(info, "Lv." .. level)
                            end
                        end
                        
                        infoLabel.Text = table.concat(info, " | ")
                    end
                end
            end
        end
    end
    
    -- Remove ESP for players who left
    for name, _ in pairs(ESPObjects) do
        if not currentNames[name] then
            RemoveESP(name)
        end
    end
end

-- Auto Fire Function
local function DoAutoFire()
    if not AutoFireEnabled then return end
    
    pcall(function()
        if ClientTankHandler then
            ClientTankHandler.Firing:Set(true)
        end
    end)
end

-- Auto Spin Function
local spinAngle = 0
local function DoAutoSpin()
    if not AutoSpinEnabled then return end
    
    pcall(function()
        if ClientTankHandler then
            spinAngle = spinAngle + (SpinSpeed * 0.1)
            ClientTankHandler.LookDirection = spinAngle
        end
    end)
end

-- Auto Respawn Function
local function DoAutoRespawn()
    if not AutoRespawnEnabled then return end
    
    pcall(function()
        if not IsPlaying() then
            FireChannel("Tank", "Spawn")
        end
    end)
end

-- Get Stats Display
local function GetStatsText()
    local data = GetPlayerData()
    if not data then return "Loading..." end
    
    local lines = {}
    
    pcall(function()
        if data.XP then
            local level = Formulas and Formulas.XPToLevel and Formulas.XPToLevel(data.XP) or "?"
            table.insert(lines, "Level: " .. tostring(level))
            table.insert(lines, "XP: " .. tostring(data.XP))
        end
        
        if data.Gems then
            table.insert(lines, "Gems: " .. tostring(data.Gems))
        end
        
        if data.RankPoints then
            table.insert(lines, "Rank Points: " .. tostring(data.RankPoints))
        end
        
        if data.Bounty then
            table.insert(lines, "Bounty: " .. tostring(data.Bounty))
        end
        
        if data.Doubloons then
            table.insert(lines, "Doubloons: " .. tostring(data.Doubloons))
        end
    end)
    
    return #lines > 0 and table.concat(lines, "\n") or "No data available"
end

-- Get Tank List for Dropdown
local function GetTankList()
    local tankList = {}
    if Tanks and Tanks.fromName then
        for tankName, _ in pairs(Tanks.fromName) do
            table.insert(tankList, tankName)
        end
        table.sort(tankList)
    else
        tankList = {"Default", "Double", "Scout", "Spammer", "Titan"}
    end
    return tankList
end

-- XP Magnet Function - Teleports food/XP items to player
local function DoXPMagnet()
    if not XPMagnetEnabled then return end
    if not IsPlaying() then return end
    
    local currentTime = tick()
    if currentTime - XPMagnetLastPull < XPMagnetSpeed then return end
    XPMagnetLastPull = currentTime
    
    local hrp = GetHumanoidRootPart()
    if not hrp then return end
    
    local playerPos = hrp.Position
    local foodFolder = workspace:FindFirstChild("Food")
    local cratesFolder = workspace:FindFirstChild("Crates")
    
    -- Pull all food items to player
    if foodFolder then
        pcall(function()
            for _, food in pairs(foodFolder:GetChildren()) do
                if food:IsA("Model") or food:IsA("BasePart") then
                    local foodPart = food:IsA("Model") and (food:FindFirstChild("Hitbox") or food.PrimaryPart) or food
                    if foodPart then
                        local distance = (playerPos - foodPart.Position).Magnitude
                        if distance <= XPMagnetRange and distance > XPMagnetTeleportDistance then
                            -- Teleport food close to player
                            local offset = Vector3.new(
                                math.random(-3, 3),
                                0,
                                math.random(-3, 3)
                            )
                            local targetPos = playerPos + offset
                            
                            if food:IsA("Model") then
                                food:PivotTo(CFrame.new(targetPos))
                            else
                                food.CFrame = CFrame.new(targetPos)
                            end
                        end
                    end
                end
            end
        end)
    end
    
    -- Optionally pull crates too
    if CollectCratesEnabled and cratesFolder then
        pcall(function()
            for _, crate in pairs(cratesFolder:GetChildren()) do
                if crate:IsA("Model") then
                    local cratePart = crate:FindFirstChild("Hitbox") or crate.PrimaryPart
                    if cratePart then
                        local distance = (playerPos - cratePart.Position).Magnitude
                        if distance <= XPMagnetRange and distance > XPMagnetTeleportDistance then
                            local offset = Vector3.new(
                                math.random(-5, 5),
                                0,
                                math.random(-5, 5)
                            )
                            local targetPos = playerPos + offset
                            crate:PivotTo(CFrame.new(targetPos))
                        end
                    end
                end
            end
        end)
    end
end

-- Get Food Count in Range
local function GetFoodCount()
    local count = 0
    local hrp = GetHumanoidRootPart()
    if not hrp then return 0 end
    
    local playerPos = hrp.Position
    local foodFolder = workspace:FindFirstChild("Food")
    
    if foodFolder then
        for _, food in pairs(foodFolder:GetChildren()) do
            local foodPart = food:IsA("Model") and (food:FindFirstChild("Hitbox") or food.PrimaryPart) or food
            if foodPart then
                local distance = (playerPos - foodPart.Position).Magnitude
                if distance <= XPMagnetRange then
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

-- Safe Zone Teleport
local function TeleportToLobby()
    pcall(function()
        InvokeChannel("Tank", "Lobby")
    end)
end

-- Spawn into Game
local function SpawnIntoGame()
    pcall(function()
        FireChannel("Tank", "Spawn")
    end)
end

-- Level Dupe Function - Attempts to exploit level system
-- Valid stat names in Tank Simulator
local StatNames = {"BulletDamage", "BulletPenetration", "BulletSpeed", "ReloadSpeed", "MaxHealth", "HealthRegen", "Speed", "BodyDamage"}
local SelectedStatToUpgrade = "BulletDamage"
local AutoGemStatEnabled = false

local function DoDupeLevel()
    if not DupeLevelEnabled then return end
    if not IsPlaying() then return end
    
    local currentTime = tick()
    if currentTime - LastDupeTime < DupeSpeed then return end
    LastDupeTime = currentTime
    
    pcall(function()
        -- Tank Simulator: Level comes from in-game XP (kills)
        -- We can try to upgrade tank tier which requires gems
        if Network and Network.Channel then
            for i = 1, DupeAmount do
                -- Try to upgrade to next tank tier
                local playerData = GetPlayerData()
                local currentTank = playerData and playerData.Tank or 1
                pcall(function()
                    Network.Channel("Tank"):InvokeServer("UpgradeTank", currentTank + i)
                end)
            end
        end
    end)
end

-- Gems Dupe Function - Uses gems to auto-upgrade stats
local function DoDupeGems()
    if not DupeGemsEnabled then return end
    
    local currentTime = tick()
    if currentTime - LastDupeTime < DupeSpeed then return end
    LastDupeTime = currentTime
    
    pcall(function()
        -- In Tank Simulator, gems are used to buy stat upgrades and tanks
        -- Channel("Stats"):FireServer("Gems", statName) - buy stat with gems
        -- Channel("Tanks"):FireServer("Gems", tankId) - buy tank with gems
        
        if Network and Network.Channel then
            -- Auto-upgrade the selected stat using gems
            for i = 1, math.min(DupeAmount, 10) do
                pcall(function()
                    Network.Channel("Stats"):FireServer("Gems", SelectedStatToUpgrade)
                end)
            end
            
            -- Try buying buffs with gems
            pcall(function()
                Network.Channel("Buffs"):FireServer("Buy", "Damage Potion")
                Network.Channel("Buffs"):FireServer("Buy", "Speed Potion")
                Network.Channel("Buffs"):FireServer("Buy", "Shield Potion")
            end)
        end
    end)
end

-- Auto Gem Stat Upgrade Function - Continuously spends gems on stats
local function DoAutoGemStat()
    if not AutoGemStatEnabled then return end
    
    pcall(function()
        if Network and Network.Channel then
            -- Upgrade selected stat with gems
            pcall(function()
                Network.Channel("Stats"):FireServer("Gems", SelectedStatToUpgrade)
            end)
        end
    end)
end

-- Auto Claim XP Function - Automatically claims all available XP/rewards
local function DoAutoClaimXP()
    if not AutoClaimXPEnabled then return end
    if not IsPlaying() then return end
    
    pcall(function()
        -- Tank Simulator XP comes from killing enemies
        -- We can auto-collect food/pickups which give XP
        local hrp = GetHumanoidRootPart()
        if hrp then
            -- Food folder contains XP pickups
            local foodFolder = workspace:FindFirstChild("Food")
            if foodFolder then
                for _, food in pairs(foodFolder:GetChildren()) do
                    pcall(function()
                        local foodPart = food:IsA("Model") and (food:FindFirstChild("Hitbox") or food.PrimaryPart or food:FindFirstChildWhichIsA("BasePart")) or food
                        if foodPart and foodPart:IsA("BasePart") then
                            local distance = (hrp.Position - foodPart.Position).Magnitude
                            if distance <= 100 then
                                -- Teleport to collect (then back)
                                local originalPos = hrp.CFrame
                                hrp.CFrame = foodPart.CFrame
                                task.wait(0.05)
                                hrp.CFrame = originalPos
                            end
                        end
                    end)
                end
            end
            
            -- Also try to collect any other pickup items in map
            local mapFolder = workspace:FindFirstChild("Map")
            if mapFolder then
                local pickupsFolder = mapFolder:FindFirstChild("Pickups") or mapFolder:FindFirstChild("Items")
                if pickupsFolder then
                    for _, pickup in pairs(pickupsFolder:GetChildren()) do
                        pcall(function()
                            local pickupPart = pickup:IsA("Model") and (pickup:FindFirstChild("Hitbox") or pickup.PrimaryPart or pickup:FindFirstChildWhichIsA("BasePart")) or pickup
                            if pickupPart and pickupPart:IsA("BasePart") then
                                local distance = (hrp.Position - pickupPart.Position).Magnitude
                                if distance <= 100 then
                                    -- Fire touch to collect
                                    local args = {pickupPart}
                                    game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
                                end
                            end
                        end)
                    end
                end
            end
        end
        
        -- Auto use free revive if available
        if Network and Network.Channel then
            pcall(function()
                Network.Channel("Tank"):InvokeServer("FreeRevive")
            end)
        end
    end)
end

-- Damage Aura Function - Fires bullets at nearby enemies (uses auto-aim to rapidly shoot at all nearby targets)
local function DoDamageAura()
    if not DamageAuraEnabled then return end
    if not IsPlaying() then return end
    
    local currentTime = tick()
    if currentTime - LastDamageAuraTime < DamageAuraSpeed then return end
    LastDamageAuraTime = currentTime
    
    local hrp = GetHumanoidRootPart()
    if not hrp then return end
    
    local enemies = GetEnemyTanks()
    
    for _, enemy in pairs(enemies) do
        if enemy.Distance <= DamageAuraRange then
            pcall(function()
                -- Method 1: Rapid-fire aim at enemy and shoot
                if ClientTankHandler then
                    -- Set look direction toward enemy
                    local direction = (enemy.Position - hrp.Position).Unit
                    local angle = math.atan2(direction.X, direction.Z) + math.pi
                    ClientTankHandler.LookDirection = angle
                    
                    -- Force firing
                    if ClientTankHandler.Firing then
                        ClientTankHandler.Firing:Set(true)
                    end
                end
                
                -- Method 2: Modify enemy health in cache (client visual only)
                if SharedTankHandler and SharedTankHandler.Cache then
                    for controller, tankData in pairs(SharedTankHandler.Cache) do
                        if tankData.Character and tankData.Character.Name == enemy.Name then
                            -- Client-side visualization only
                            if tankData.Health then
                                tankData.Health = math.max(0, tankData.Health - (10 * DamageAuraMultiplier))
                            end
                        end
                    end
                end
            end)
        end
    end
end

-- Bullet Speed Manipulation - Modifies bullet speed through game modules
local function DoBulletSpeedManipulation()
    if not BulletSpeedEnabled then return end
    
    pcall(function()
        -- Method 1: Modify Tanks module projectile data
        if Tanks then
            for tankId, tankData in pairs(Tanks.fromId or {}) do
                pcall(function()
                    if tankData.Cannons then
                        for _, cannon in pairs(tankData.Cannons) do
                            if cannon.Projectile and cannon.Projectile.Speed then
                                cannon.Projectile.Speed = cannon.Projectile.Speed * BulletSpeedMultiplier
                            end
                        end
                    end
                end)
            end
            for tankName, tankData in pairs(Tanks.fromName or {}) do
                pcall(function()
                    if tankData.Cannons then
                        for _, cannon in pairs(tankData.Cannons) do
                            if cannon.Projectile and cannon.Projectile.Speed then
                                cannon.Projectile.Speed = BulletSpeedMultiplier
                            end
                        end
                    end
                end)
            end
        end
        
        -- Method 2: Modify current tank's cannon data
        if ClientTankHandler and ClientTankHandler.Tank then
            local tank = ClientTankHandler.Tank
            if tank.Cannons then
                for _, cannon in pairs(tank.Cannons) do
                    if cannon.Projectile and cannon.Projectile.Speed then
                        cannon.Projectile.Speed = CustomBulletSpeed
                    end
                end
            end
        end
        
        -- Method 3: Modify the BaseValues in Cannons module
        local Cannons = nil
        pcall(function()
            Cannons = require(game:GetService("ReplicatedStorage").Data.Cannons)
        end)
        if Cannons and Cannons.BaseValues then
            if Cannons.BaseValues.Speed then
                Cannons.BaseValues.Speed = CustomBulletSpeed
            end
        end
    end)
end

-- Speed Fix Function - Modifies tank speed through LinearVelocity and stats
local function DoSpeedFix()
    if not SpeedBoostEnabled then return end
    
    pcall(function()
        local char = GetCharacter()
        if char then
            -- Method 1: Modify LinearVelocity (tank game uses this for movement)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local linearVelocity = hrp:FindFirstChild("LinearVelocity")
                if linearVelocity then
                    -- Increase max force for faster movement
                    linearVelocity.MaxForce = 100000
                end
            end
            
            -- Method 2: Also set humanoid walk speed as backup
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                if hum.WalkSpeed ~= TargetWalkSpeed then
                    hum.WalkSpeed = TargetWalkSpeed
                end
                if hum.JumpPower ~= TargetJumpPower then
                    hum.JumpPower = TargetJumpPower
                end
            end
            
            -- Method 3: Modify tank handler speed stats
            if ClientTankHandler and ClientTankHandler.Tank then
                local tank = ClientTankHandler.Tank
                -- Remove slowdown flags
                if tank.Flags then
                    tank.Flags.Frozen = false
                    tank.Flags.Slowdown = 1
                end
                -- Increase tank speed stat
                if tank.Stats then
                    tank.Stats.Speed = (tank.Stats.Speed or 0) + 10
                end
            end
        end
    end)
end

-- Create UI Window
local Window = Rayfield:CreateWindow({
    Name = "Tank Simulator",
    LoadingTitle = "Tank Simulator Script",
    LoadingSubtitle = "by Script Hub",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TankSimulator",
        FileName = "Config"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- Main Tab
local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateSection("Combat")

MainTab:CreateToggle({
    Name = "Auto Fire",
    CurrentValue = false,
    Flag = "AutoFire",
    Callback = function(Value)
        AutoFireEnabled = Value
        if not Value and ClientTankHandler then
            pcall(function()
                ClientTankHandler.Firing:Set(false)
            end)
        end
    end
})

MainTab:CreateToggle({
    Name = "Auto Spin",
    CurrentValue = false,
    Flag = "AutoSpin",
    Callback = function(Value)
        AutoSpinEnabled = Value
    end
})

MainTab:CreateSlider({
    Name = "Spin Speed",
    Range = {1, 20},
    Increment = 1,
    Suffix = "x",
    CurrentValue = 5,
    Flag = "SpinSpeed",
    Callback = function(Value)
        SpinSpeed = Value
    end
})

MainTab:CreateSection("Spawning")

MainTab:CreateToggle({
    Name = "Auto Respawn",
    CurrentValue = false,
    Flag = "AutoRespawn",
    Callback = function(Value)
        AutoRespawnEnabled = Value
    end
})

MainTab:CreateButton({
    Name = "Spawn Into Game",
    Callback = function()
        SpawnIntoGame()
    end
})

MainTab:CreateButton({
    Name = "Return to Lobby",
    Callback = function()
        TeleportToLobby()
    end
})

-- Kill Aura Tab
local KillAuraTab = Window:CreateTab("Kill Aura", 4483362458)

KillAuraTab:CreateSection("Auto Aim")

KillAuraTab:CreateToggle({
    Name = "Enable Kill Aura",
    CurrentValue = false,
    Flag = "KillAura",
    Callback = function(Value)
        KillAuraEnabled = Value
        if not Value and ClientTankHandler then
            pcall(function()
                ClientTankHandler.Firing:Set(false)
            end)
        end
    end
})

KillAuraTab:CreateToggle({
    Name = "Auto Fire",
    CurrentValue = true,
    Flag = "KillAuraAutoFire",
    Callback = function(Value)
        KillAuraAutoFire = Value
    end
})

KillAuraTab:CreateSlider({
    Name = "Aura Range",
    Range = {25, 500},
    Increment = 25,
    Suffix = " studs",
    CurrentValue = 100,
    Flag = "KillAuraRange",
    Callback = function(Value)
        KillAuraRange = Value
    end
})

KillAuraTab:CreateDropdown({
    Name = "Target Priority",
    Options = {"Closest", "LowestHealth", "HighestLevel"},
    CurrentOption = {"Closest"},
    Flag = "KillAuraPriority",
    Callback = function(Option)
        KillAuraPriority = Option[1] or "Closest"
        LockedTarget = nil -- Reset locked target when priority changes
    end
})

KillAuraTab:CreateToggle({
    Name = "Lock-On Mode",
    CurrentValue = false,
    Flag = "LockOnTarget",
    Callback = function(Value)
        LockOnTarget = Value
        if not Value then
            LockedTarget = nil
        end
    end
})

KillAuraTab:CreateButton({
    Name = "Clear Locked Target",
    Callback = function()
        LockedTarget = nil
        Rayfield:Notify({
            Title = "Kill Aura",
            Content = "Locked target cleared",
            Duration = 2
        })
    end
})

KillAuraTab:CreateSection("Aim Settings")

KillAuraTab:CreateToggle({
    Name = "Aim Prediction",
    CurrentValue = true,
    Flag = "AimPrediction",
    Callback = function(Value)
        AimPrediction = Value
    end
})

KillAuraTab:CreateSlider({
    Name = "Prediction Amount",
    Range = {0, 0.5},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.1,
    Flag = "PredictionAmount",
    Callback = function(Value)
        PredictionAmount = Value
    end
})

KillAuraTab:CreateSection("Visualization")

KillAuraTab:CreateToggle({
    Name = "Highlight Target",
    CurrentValue = true,
    Flag = "ShowTargetESP",
    Callback = function(Value)
        ShowTargetESP = Value
        if not Value and TargetHighlight then
            pcall(function()
                TargetHighlight:Destroy()
            end)
            TargetHighlight = nil
        end
    end
})

local targetInfoLabel = KillAuraTab:CreateParagraph({
    Title = "Current Target",
    Content = "No target"
})

KillAuraTab:CreateButton({
    Name = "Refresh Target Info",
    Callback = function()
        local target = GetBestTarget()
        if target then
            local healthPercent = math.floor((target.Health / target.MaxHealth) * 100)
            targetInfoLabel:Set({
                Title = "Current Target",
                Content = "Name: " .. target.Name .. 
                    "\nDistance: " .. math.floor(target.Distance) .. " studs" ..
                    "\nHealth: " .. math.floor(target.Health) .. "/" .. math.floor(target.MaxHealth) .. " (" .. healthPercent .. "%)" ..
                    "\nLevel: " .. tostring(target.Level) ..
                    "\nTeam: " .. tostring(target.Team)
            })
        else
            targetInfoLabel:Set({
                Title = "Current Target", 
                Content = "No target in range"
            })
        end
    end
})

KillAuraTab:CreateSection("Enemy Counter")

local enemyCountLabel = KillAuraTab:CreateParagraph({
    Title = "Enemies in Range",
    Content = "0 enemies"
})

KillAuraTab:CreateButton({
    Name = "Count Enemies",
    Callback = function()
        local enemies = GetEnemyTanks()
        local content = #enemies .. " enemies in range"
        if #enemies > 0 then
            content = content .. "\n\nNearest 5:"
            for i = 1, math.min(5, #enemies) do
                local e = enemies[i]
                content = content .. "\n" .. i .. ". " .. e.Name .. " (" .. math.floor(e.Distance) .. "m, Lv." .. e.Level .. ")"
            end
        end
        enemyCountLabel:Set({
            Title = "Enemies in Range",
            Content = content
        })
    end
})

-- ESP Tab
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateSection("Player ESP")

ESPTab:CreateToggle({
    Name = "Enable Player ESP",
    CurrentValue = false,
    Flag = "PlayerESP",
    Callback = function(Value)
        PlayerESPEnabled = Value
        TankESPEnabled = Value
        if not Value then
            ClearAllESP()
        end
    end
})

ESPTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "TeamCheck",
    Callback = function(Value)
        TeamCheck = Value
    end
})

ESPTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = true,
    Flag = "ShowDistance",
    Callback = function(Value)
        ShowDistance = Value
    end
})

ESPTab:CreateToggle({
    Name = "Show Level",
    CurrentValue = true,
    Flag = "ShowLevel",
    Callback = function(Value)
        ShowLevel = Value
    end
})

ESPTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "ESPColor",
    Callback = function(Value)
        ESPColor = Value
    end
})

-- Teleport Tab
local TeleportTab = Window:CreateTab("Teleport", 4483362458)

TeleportTab:CreateSection("Quick Teleports")

TeleportTab:CreateButton({
    Name = "Teleport to Lobby",
    Callback = function()
        TeleportToLobby()
    end
})

TeleportTab:CreateButton({
    Name = "Teleport to Map Center",
    Callback = function()
        pcall(function()
            local hrp = GetHumanoidRootPart()
            if hrp then
                local map = workspace:FindFirstChild("Map")
                if map and map:FindFirstChild("Floor") then
                    hrp.CFrame = map.Floor.CFrame + Vector3.new(0, 5, 0)
                else
                    hrp.CFrame = CFrame.new(0, 50, 0)
                end
            end
        end)
    end
})

TeleportTab:CreateSection("Player Teleport")

local playerDropdown
local function UpdatePlayerList()
    local playerList = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= Player then
            table.insert(playerList, plr.Name)
        end
    end
    return playerList
end

local SelectedPlayer = ""
TeleportTab:CreateDropdown({
    Name = "Select Player",
    Options = UpdatePlayerList(),
    CurrentOption = {},
    Flag = "SelectedPlayer",
    Callback = function(Option)
        SelectedPlayer = Option[1] or ""
    end
})

TeleportTab:CreateButton({
    Name = "Teleport to Selected Player",
    Callback = function()
        pcall(function()
            local targetPlayer = Players:FindFirstChild(SelectedPlayer)
            if targetPlayer and targetPlayer.Character then
                local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                local myHRP = GetHumanoidRootPart()
                if targetHRP and myHRP then
                    myHRP.CFrame = targetHRP.CFrame + Vector3.new(10, 0, 0)
                end
            end
        end)
    end
})

-- Tank Tab
local TankTab = Window:CreateTab("Tank", 4483362458)

TankTab:CreateSection("Tank Upgrades")

local selectedTank = "Default"
TankTab:CreateDropdown({
    Name = "Select Tank",
    Options = GetTankList(),
    CurrentOption = {"Default"},
    Flag = "SelectedTank",
    Callback = function(Option)
        selectedTank = Option[1] or "Default"
    end
})

TankTab:CreateButton({
    Name = "Upgrade to Selected Tank",
    Callback = function()
        pcall(function()
            if Tanks and Tanks.fromName and Tanks.fromName[selectedTank] then
                local tankId = Tanks.fromName[selectedTank].Id
                InvokeChannel("Tank", "UpgradeTank", tankId)
            end
        end)
    end
})

TankTab:CreateSection("Quick Upgrades")

TankTab:CreateButton({
    Name = "Max Stats (Uses available points)",
    Callback = function()
        pcall(function()
            -- This attempts to use upgrade points on stats
            local stats = {"MaxHealth", "Speed", "ReloadSpeed", "Damage", "Penetration", "BulletSpeed"}
            for _, stat in pairs(stats) do
                for i = 1, 10 do
                    FireChannel("Tank", "SetUpgrade", stat)
                    task.wait(0.05)
                end
            end
        end)
    end
})

-- Visual Tab
local VisualTab = Window:CreateTab("Visual", 4483362458)

VisualTab:CreateSection("Camera")

VisualTab:CreateSlider({
    Name = "Field of View",
    Range = {30, 120},
    Increment = 5,
    Suffix = "°",
    CurrentValue = 70,
    Flag = "FOV",
    Callback = function(Value)
        CurrentFOV = Value
        pcall(function()
            workspace.CurrentCamera.FieldOfView = Value
        end)
    end
})

VisualTab:CreateSection("Lighting")

VisualTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "Fullbright",
    Callback = function(Value)
        pcall(function()
            if Value then
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.FogEnd = 100000
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.new(1, 1, 1)
            else
                Lighting.Brightness = 1
                Lighting.ClockTime = 14
                Lighting.FogEnd = 10000
                Lighting.GlobalShadows = true
                Lighting.Ambient = Color3.fromRGB(127, 127, 127)
            end
        end)
    end
})

-- Misc Tab
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Player Speed (Fixed)")

MiscTab:CreateToggle({
    Name = "Enable Speed Boost",
    CurrentValue = false,
    Flag = "SpeedBoost",
    Callback = function(Value)
        SpeedBoostEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Speed Boost",
                Content = "Speed will now be continuously applied",
                Duration = 2
            })
        end
    end
})

MiscTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 500},
    Increment = 5,
    Suffix = " speed",
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(Value)
        TargetWalkSpeed = Value
        pcall(function()
            local hum = GetCharacter():FindFirstChild("Humanoid")
            if hum then
                hum.WalkSpeed = Value
            end
        end)
    end
})

MiscTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 500},
    Increment = 10,
    Suffix = " power",
    CurrentValue = 50,
    Flag = "JumpPower",
    Callback = function(Value)
        TargetJumpPower = Value
        pcall(function()
            local hum = GetCharacter():FindFirstChild("Humanoid")
            if hum then
                hum.JumpPower = Value
            end
        end)
    end
})

MiscTab:CreateSection("Codes")

local codeInput = ""
MiscTab:CreateInput({
    Name = "Redeem Code",
    PlaceholderText = "Enter code here",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        codeInput = Text
    end
})

MiscTab:CreateButton({
    Name = "Redeem",
    Callback = function()
        if codeInput ~= "" then
            pcall(function()
                FireChannel("Codes", "Redeem", string.lower(codeInput))
                Rayfield:Notify({
                    Title = "Code Redeemed",
                    Content = "Attempted to redeem: " .. codeInput,
                    Duration = 3
                })
            end)
        end
    end
})

MiscTab:CreateSection("Utilities")

MiscTab:CreateButton({
    Name = "Load Infinite Yield",
    Callback = function()
        if not InfiniteYieldLoaded then
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
                InfiniteYieldLoaded = true
            end)
        end
    end
})

MiscTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, Player)
        end)
    end
})

-- Info Tab
local InfoTab = Window:CreateTab("Info", 4483362458)

InfoTab:CreateSection("Player Stats")

local statsLabel = InfoTab:CreateParagraph({
    Title = "Your Stats",
    Content = "Loading..."
})

InfoTab:CreateButton({
    Name = "Refresh Stats",
    Callback = function()
        statsLabel:Set({
            Title = "Your Stats",
            Content = GetStatsText()
        })
    end
})

InfoTab:CreateSection("Credits")

InfoTab:CreateParagraph({
    Title = "Tank Simulator Script",
    Content = "Game ID: 89048211727318\nUI: Rayfield\nCreated for educational purposes"
})

-- XP Magnet Tab
local XPTab = Window:CreateTab("XP Magnet", 4483362458)

XPTab:CreateSection("XP Collection")

XPTab:CreateToggle({
    Name = "Enable XP Magnet",
    CurrentValue = false,
    Flag = "XPMagnet",
    Callback = function(Value)
        XPMagnetEnabled = Value
    end
})

XPTab:CreateSlider({
    Name = "Magnet Range",
    Range = {50, 500},
    Increment = 25,
    Suffix = " studs",
    CurrentValue = 200,
    Flag = "XPMagnetRange",
    Callback = function(Value)
        XPMagnetRange = Value
    end
})

XPTab:CreateSlider({
    Name = "Pull Speed",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.1,
    Flag = "XPMagnetSpeed",
    Callback = function(Value)
        XPMagnetSpeed = Value
    end
})

XPTab:CreateSection("Crates")

XPTab:CreateToggle({
    Name = "Also Collect Crates",
    CurrentValue = false,
    Flag = "CollectCrates",
    Callback = function(Value)
        CollectCratesEnabled = Value
    end
})

XPTab:CreateSection("Stats")

local foodCountLabel = XPTab:CreateParagraph({
    Title = "Food Nearby",
    Content = "0 food items"
})

XPTab:CreateButton({
    Name = "Count Food in Range",
    Callback = function()
        local count = GetFoodCount()
        foodCountLabel:Set({
            Title = "Food Nearby",
            Content = count .. " food items in range"
        })
    end
})

XPTab:CreateButton({
    Name = "Teleport All Food Now",
    Callback = function()
        local hrp = GetHumanoidRootPart()
        if not hrp then return end
        
        local playerPos = hrp.Position
        local foodFolder = workspace:FindFirstChild("Food")
        local count = 0
        
        if foodFolder then
            for _, food in pairs(foodFolder:GetChildren()) do
                pcall(function()
                    local foodPart = food:IsA("Model") and (food:FindFirstChild("Hitbox") or food.PrimaryPart) or food
                    if foodPart then
                        local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
                        if food:IsA("Model") then
                            food:PivotTo(CFrame.new(playerPos + offset))
                        else
                            food.CFrame = CFrame.new(playerPos + offset)
                        end
                        count = count + 1
                    end
                end)
            end
        end
        
        Rayfield:Notify({
            Title = "XP Magnet",
            Content = "Teleported " .. count .. " food items!",
            Duration = 3
        })
    end
})

-- Exploits Tab
local ExploitsTab = Window:CreateTab("Exploits", 4483362458)

ExploitsTab:CreateSection("Level Dupe")

ExploitsTab:CreateToggle({
    Name = "Enable Level Dupe",
    CurrentValue = false,
    Flag = "DupeLevel",
    Callback = function(Value)
        DupeLevelEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Level Dupe",
                Content = "Attempting to dupe levels...",
                Duration = 2
            })
        end
    end
})

ExploitsTab:CreateSection("Gems Dupe")

ExploitsTab:CreateToggle({
    Name = "Enable Gems Dupe",
    CurrentValue = false,
    Flag = "DupeGems",
    Callback = function(Value)
        DupeGemsEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Gems Dupe",
                Content = "Attempting to dupe gems...",
                Duration = 2
            })
        end
    end
})

ExploitsTab:CreateSection("Dupe Settings")

ExploitsTab:CreateSlider({
    Name = "Dupe Amount",
    Range = {100, 10000},
    Increment = 100,
    Suffix = " units",
    CurrentValue = 1000,
    Flag = "DupeAmount",
    Callback = function(Value)
        DupeAmount = Value
    end
})

ExploitsTab:CreateSlider({
    Name = "Dupe Speed",
    Range = {0.1, 2},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 0.5,
    Flag = "DupeSpeed",
    Callback = function(Value)
        DupeSpeed = Value
    end
})

ExploitsTab:CreateSection("Gem Stat Upgrades")

ExploitsTab:CreateDropdown({
    Name = "Stat to Upgrade",
    Options = {"BulletDamage", "BulletPenetration", "BulletSpeed", "ReloadSpeed", "MaxHealth", "HealthRegen", "Speed", "BodyDamage"},
    CurrentOption = {"BulletDamage"},
    MultipleOptions = false,
    Flag = "SelectedStat",
    Callback = function(Options)
        SelectedStatToUpgrade = Options[1] or "BulletDamage"
    end
})

ExploitsTab:CreateToggle({
    Name = "Auto Upgrade Stat (Uses Gems)",
    CurrentValue = false,
    Flag = "AutoGemStat",
    Callback = function(Value)
        AutoGemStatEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Auto Gem Stats",
                Content = "Will automatically spend gems on " .. SelectedStatToUpgrade,
                Duration = 2
            })
        end
    end
})

ExploitsTab:CreateButton({
    Name = "Upgrade All Stats Once",
    Callback = function()
        pcall(function()
            if Network and Network.Channel then
                for _, stat in ipairs(StatNames) do
                    pcall(function()
                        Network.Channel("Stats"):FireServer("Gems", stat)
                    end)
                    task.wait(0.1)
                end
                Rayfield:Notify({
                    Title = "Stats Upgraded",
                    Content = "Attempted to upgrade all stats!",
                    Duration = 2
                })
            end
        end)
    end
})

ExploitsTab:CreateSection("Auto Claim")

ExploitsTab:CreateToggle({
    Name = "Auto Claim XP/Rewards",
    CurrentValue = false,
    Flag = "AutoClaimXP",
    Callback = function(Value)
        AutoClaimXPEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Auto Claim",
                Content = "Will automatically claim all available rewards",
                Duration = 2
            })
        end
    end
})

ExploitsTab:CreateButton({
    Name = "Force Claim All Now",
    Callback = function()
        pcall(function()
            -- Try free revive
            if Network and Network.Channel then
                pcall(function()
                    Network.Channel("Tank"):InvokeServer("FreeRevive")
                end)
            end
            
            -- Teleport to collect food/XP
            local hrp = GetHumanoidRootPart()
            if hrp then
                local foodFolder = workspace:FindFirstChild("Food")
                if foodFolder then
                    for _, food in pairs(foodFolder:GetChildren()) do
                        pcall(function()
                            local foodPart = food:IsA("Model") and (food:FindFirstChild("Hitbox") or food.PrimaryPart) or food
                            if foodPart and foodPart:IsA("BasePart") then
                                local originalPos = hrp.CFrame
                                hrp.CFrame = foodPart.CFrame
                                task.wait(0.05)
                                hrp.CFrame = originalPos
                            end
                        end)
                    end
                end
            end
            
            Rayfield:Notify({
                Title = "Force Claim",
                Content = "Attempted to collect all XP/rewards!",
                Duration = 2
            })
        end)
    end
})

-- Damage Aura Tab
local DamageTab = Window:CreateTab("Damage Aura", 4483362458)

DamageTab:CreateSection("Damage Aura")

DamageTab:CreateToggle({
    Name = "Enable Damage Aura",
    CurrentValue = false,
    Flag = "DamageAura",
    Callback = function(Value)
        DamageAuraEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Damage Aura",
                Content = "Damage aura activated!",
                Duration = 2
            })
        end
    end
})

DamageTab:CreateSlider({
    Name = "Aura Range",
    Range = {10, 200},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = 50,
    Flag = "DamageAuraRange",
    Callback = function(Value)
        DamageAuraRange = Value
    end
})

DamageTab:CreateSlider({
    Name = "Damage Multiplier",
    Range = {1, 10},
    Increment = 1,
    Suffix = "x",
    CurrentValue = 2,
    Flag = "DamageAuraMultiplier",
    Callback = function(Value)
        DamageAuraMultiplier = Value
    end
})

DamageTab:CreateSlider({
    Name = "Aura Speed",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.1,
    Flag = "DamageAuraSpeed",
    Callback = function(Value)
        DamageAuraSpeed = Value
    end
})

DamageTab:CreateSection("Bullet Speed")

DamageTab:CreateToggle({
    Name = "Enable Bullet Speed Mod",
    CurrentValue = false,
    Flag = "BulletSpeed",
    Callback = function(Value)
        BulletSpeedEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Bullet Speed",
                Content = "Bullet speed modification enabled!",
                Duration = 2
            })
        end
    end
})

DamageTab:CreateSlider({
    Name = "Bullet Speed Multiplier",
    Range = {1, 10},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = 2,
    Flag = "BulletSpeedMultiplier",
    Callback = function(Value)
        BulletSpeedMultiplier = Value
    end
})

DamageTab:CreateSlider({
    Name = "Custom Bullet Speed",
    Range = {80, 500},
    Increment = 20,
    Suffix = " studs/s",
    CurrentValue = 160,
    Flag = "CustomBulletSpeed",
    Callback = function(Value)
        CustomBulletSpeed = Value
    end
})

-- Main Loop
Connections["MainLoop"] = RunService.Heartbeat:Connect(function()
    DoAutoFire()
    DoAutoSpin()
    DoAutoRespawn()
    DoKillAura()
    DoXPMagnet()
    DoDupeLevel()
    DoDupeGems()
    DoAutoClaimXP()
    DoDamageAura()
    DoBulletSpeedManipulation()
    DoSpeedFix()
    DoAutoGemStat()
end)

-- ESP Update Loop (slower rate)
Connections["ESPLoop"] = RunService.Heartbeat:Connect(function()
    if PlayerESPEnabled or TankESPEnabled then
        UpdateESP()
    end
end)

-- Character added handler
Player.CharacterAdded:Connect(function(char)
    Character = char
    task.wait(1)
    
    -- Re-apply walk speed/jump power if speed boost is enabled
    local hum = char:FindFirstChild("Humanoid")
    if hum and SpeedBoostEnabled then
        pcall(function()
            hum.WalkSpeed = TargetWalkSpeed
            hum.JumpPower = TargetJumpPower
        end)
    end
end)

-- Initial stats load
task.spawn(function()
    task.wait(2)
    if ClientData then
        ClientData.WaitForValue()
    end
    statsLabel:Set({
        Title = "Your Stats",
        Content = GetStatsText()
    })
end)

-- Cleanup on script end
Rayfield:Notify({
    Title = "Tank Simulator",
    Content = "Script loaded successfully!",
    Duration = 3
})

print("[Tank Simulator] Script loaded successfully!")
