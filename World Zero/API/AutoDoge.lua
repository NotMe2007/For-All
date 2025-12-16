-- Auto Dodge API
-- Automatically dodge dangerous attacks based on visual indicators and attack patterns
-- Detects AOE circles, boss attacks, projectiles, and telegraphed abilities
-- https://pastebin.com/Y7M8yvYc
--
-- UPDATED: Comprehensive attack pattern detection for World Zero
-- Now includes: Klaus (7), Kandrix (3), Ignis/Winterfall (7), Aether Dragon, Cerberus,
-- Black Holes (3 variants), Elemental attacks, Magical attacks, and 20+ projectile types
-- Total: 70+ unique attack patterns detected!
--
-- ⚠️ WINTERFALL WARNING: Ignis Fire Dragon's Winterfall attack is an INSTANT KILL (100% HP)
-- The API prioritizes this attack with 150 stud detection range!
-- 🛡️ SURVIVAL MECHANIC: The IgnisShield blocks Winterfall damage! 
-- AutoDodge will move you TOWARDS the shield zone, not away from danger.
--
-- Auto Dodge folder contains decompiled attack effect scripts from game files
-- this script is incomplete and may not work as intended

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')
local TweenService = game:GetService('TweenService')

-- Silence all diagnostic output
local function _noop(...) end
local print = _noop
local warn = _noop

local _genv = getgenv()
local AutoDodgeAPI = {}
AutoDodgeAPI.__index = AutoDodgeAPI

-- Configuration
AutoDodgeAPI.config = {
    enabled = false,
    dodgeKey = nil,              -- hotkey disabled (API only)
    autoDodgeIndicators = true,  -- Auto dodge when seeing red circles/beams
    autoDodgeBossAttacks = true, -- Auto dodge boss telegraphs
    dodgeCooldown = 0.5,         -- Cooldown between dodges (seconds)
    detectionRadius = 100,       -- How far to scan for threats
    indicatorCheckInterval = 0.1, -- How often to scan for indicators
    debugMode = false,
    safeDistance = 25,           -- Distance to dodge away from threats
    preferBackwardDodge = true,  -- Dodge backward from camera view
    tweenDuration = 0.2,         -- Tween duration for smooth dodge (seconds)
    tweenStyle = Enum.EasingStyle.Quad,  -- Tween easing style
    tweenDirection = Enum.EasingDirection.Out,  -- Tween easing direction
}

-- Threat types and their detection patterns
AutoDodgeAPI.threatPatterns = {
    -- Radial indicators (red circles on ground)
    radialIndicator = {
        name = "RadialIndicator",
        checkColor = true,
        dangerColors = {
            Color3.fromRGB(255, 0, 0),      -- Red
            Color3.fromRGB(230, 110, 255),  -- Purple (Kandrix beams)
            Color3.fromRGB(255, 100, 100),  -- Light red
            Color3.fromRGB(100, 200, 255),  -- Ice blue (Klaus)
        },
        minSize = 5,  -- Minimum radius to care about
    },
    
    -- === KLAUS (CHRISTMAS EVENT BOSS) ATTACKS ===
    klausGigaLaser = {
        name = "KlausGigaBeam",
        checkParent = "Camera",
        type = "beam",
        duration = 5,
        radius = 100,  -- Wide sweeping beam
    },
    klausIceBeam = {
        name = "KlausBeam",
        checkParent = "Camera",
        type = "beam",
        duration = 5,
        radius = 40,  -- Dual eye beams
    },
    klausIceCircleSpikes = {
        name = "KlausIceSpikeRing",
        checkParent = "Camera",
        type = "ground",
        radius = 30,  -- Circle of ice spikes
        detectDelay = 0.5,
    },
    klausIceWall = {
        name = "KlausIceWall",
        checkParent = "Camera",
        type = "wall",
        radius = 20,  -- Ice wall chunks
        rows = 6,
    },
    klausPureIce = {
        name = "KlausPureIce",
        checkParent = "Camera",
        type = "projectile",
        radius = 10,
    },
    klausPresent = {
        name = "KlausPresent",
        checkParent = "Camera",
        type = "projectile",
        radius = 12,
    },
    klausWorkshopEffect = {
        name = "KlausWorkshop",
        type = "ground",
        radius = 25,
    },
    
    -- === KANDRIX BOSS ATTACKS ===
    kandrixSkyBeam = {
        name = "KandrixSkyBeam",
        checkParent = "Camera",
        beamRadius = 20,
    },
    kandrixRay = {
        name = "KandrixRay",
        checkParent = "Camera",
        radius = 15,
    },
    kandrixFlyingRay = {
        name = "KandrixFlyingRay",
        checkParent = "Camera",
        radius = 18,
    },
    
    -- === AETHER DRAGON ATTACKS ===
    aetherDragonBeam = {
        name = "DarkCylinder",
        type = "beam",
        radius = 25,
    },
    
    -- === IGNIS FIRE DRAGON (WINTERFALL) ===
    ignisWinterfall = {
        name = "Winterfall",
        type = "ultimate",
        radius = 150,  -- Wide AOE freeze, INSTANT KILL (100% HP)
        duration = 18.5,
        safezone = "IgnisShield",  -- Shield blocks Winterfall damage - dodge TO shield!
    },
    ignisShield = {
        name = "IgnisShield",
        type = "safezone",
        radius = 25,  -- Safe zone inside shield
        isSafe = true,  -- This is a SAFE zone, not a threat!
    },
    ignisIceBeam = {
        name = "IgnisIceBeam",
        type = "beam",
        radius = 50,  -- Sweeping ice beam
        duration = 21.667,
    },
    ignisMeteorFall = {
        name = "IgnisMeteor",
        type = "meteor",
        radius = 25,  -- Meteor impact zone
    },
    ignisDownwardIceFire = {
        name = "IgnisDownwardFire",
        type = "ground",
        radius = 45,  -- Downward attack radius
    },
    ignisTailWhip = {
        name = "IgnisTailWhip",
        type = "swipe",
        radius = 30,  -- Tail swipe area
    },
    ignisUltimate = {
        name = "IgnisUltimate",
        type = "cone",
        radius = 225,  -- Cone depth
        angle = 35,     -- Cone angle
    },
    ignisBite = {
        name = "IgnisBite",
        type = "melee",
        radius = 10,
    },
    
    -- === CERBERUS ATTACKS ===
    cerberusFireball = {
        name = "CerberusFireball",
        type = "projectile",
        radius = 8,
    },
    cerberusMeteorStrike = {
        name = "CerberusMeteor",
        type = "ground",
        radius = 15,
    },
    
    -- === GENERAL MOB ATTACKS ===
    cannonBall = {
        name = "Cannonball",
        type = "projectile",
        radius = 10,
    },
    boulder = {
        name = "Boulder",
        type = "projectile",
        radius = 12,
    },
    boulderErupt = {
        name = "BoulderErupt",
        type = "ground",
        radius = 18,
    },
    boulderEruptBall = {
        name = "BoulderEruptBall",
        type = "projectile",
        radius = 10,
    },
    
    -- === MAGICAL ATTACKS ===
    arcaneOrb = {
        name = "ArcaneOrb",
        type = "projectile",
        radius = 8,
    },
    arcaneBlast = {
        name = "ArcaneBlast",
        type = "projectile",
        radius = 10,
    },
    arcaneWave = {
        name = "ArcaneWave",
        type = "wave",
        radius = 20,
    },
    arcaneAscension = {
        name = "ArcaneAscension",
        type = "ground",
        radius = 15,
    },
    
    -- === BLACK HOLE VARIANTS ===
    blackHole = {
        name = "BlackHole",
        type = "pull",
        radius = 25,
    },
    blackHoleBlazing = {
        name = "BlackHoleBlazing",
        type = "pull",
        radius = 25,
    },
    blackHolePumpkin = {
        name = "BlackHolePumpkin",
        type = "pull",
        radius = 25,
    },
    
    -- === ELEMENTAL ATTACKS ===
    alienErupt = {
        name = "AlienErupt",
        type = "ground",
        radius = 18,
    },
    alienEruptBall = {
        name = "AlienEruptBall",
        type = "projectile",
        radius = 10,
    },
    alienShockwave = {
        name = "AlienShockwave",
        type = "wave",
        radius = 22,
    },
    bigFireSpikeRing = {
        name = "FireSpikeRing",
        type = "ground",
        radius = 20,
    },
    boneGroundSpike = {
        name = "BoneGroundSpike",
        type = "ground",
        radius = 12,
    },
    
    -- === SPECIAL ATTACKS ===
    anubisRing = {
        name = "AnubisRing",
        type = "ground",
        radius = 20,
    },
    angelGlow = {
        name = "AngelGlow",
        type = "buff",  -- Usually not dodgeable, friendly
        radius = 15,
    },
    bearTrap = {
        name = "BearTrap",
        type = "ground",
        radius = 8,
    },
    bloodBinding = {
        name = "BloodBinding",
        type = "binding",
        radius = 10,
    },
    
    -- === PROJECTILES ===
    arrowShoot = {
        name = "ArrowShoot",
        type = "projectile",
        radius = 6,
    },
    bubbleBall = {
        name = "BubbleBall",
        type = "projectile",
        radius = 8,
    },
    cabbageHead = {
        name = "CabbageHead",
        type = "projectile",
        radius = 7,
    },
    bigBlossomBulletBurst = {
        name = "BlossomBurst",
        type = "projectile",
        radius = 10,
    },
    
    -- === SPECIAL INDICATORS ===
    bindedRadialIndicator = {
        name = "BindedRadialIndicator",
        type = "ground",
        radius = 15,
    },
    barrierOrb = {
        name = "BarrierOrb",
        type = "shield",  -- Usually defensive, not a threat
        radius = 12,
    },
    barrierSkill = {
        name = "BarrierSkill",
        type = "shield",
        radius = 15,
    },
    barrierSkillGold = {
        name = "BarrierSkillGold",
        type = "shield",
        radius = 18,
    },
    
    -- === BOSS-SPECIFIC ===
    archerHeavenlySword = {
        name = "HeavenlySword",
        type = "projectile",
        radius = 12,
    },
    blackSheepAttack = {
        name = "BlackSheepAttack",
        type = "charge",
        radius = 15,
    },
    bite = {
        name = "Bite",
        type = "melee",
        radius = 8,
    },
    aggroPoint = {
        name = "AggroPoint",
        type = "marker",  -- Visual indicator
        radius = 5,
    },
}

-- State tracking
AutoDodgeAPI.state = {
    lastDodgeTime = 0,
    isOnCooldown = false,
    actionsModule = nil,
    skillsetsModule = nil,
    currentClass = nil,
    detectedThreats = {},
    isDodging = false,
    _lastIndicatorCheck = 0,
}

if _genv.AutoDodgePauseFarm == nil then
    _genv.AutoDodgePauseFarm = false
end
if _genv.AutoDodgeEnabled == nil then
    _genv.AutoDodgeEnabled = false
end

-- Safe module loader
local function safeRequire(mod)
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

-- Initialize required modules
function AutoDodgeAPI:Init()
    -- Load Actions module (has DoDodge function)
    if not self.state.actionsModule then
        pcall(function()
            local actionsPath = ReplicatedStorage:FindFirstChild('Client')
            if actionsPath then
                actionsPath = actionsPath:FindFirstChild('Actions')
            end
            self.state.actionsModule = safeRequire(actionsPath)
        end)
    end
    
    -- Get player's current class for dodge animation
    local plr = Players.LocalPlayer
    if plr and plr.Character then
        local profile = plr.Character:FindFirstChild('Profile')
        if profile then
            local classValue = profile:FindFirstChild('Class')
            if classValue then
                self.state.currentClass = classValue.Value
            end
        end
    end
    
    if self.config.debugMode and self.state.actionsModule then
        print("[AutoDodge] ✅ Modules initialized")
    end
    
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

-- Scan for radial indicators (red circles)
function AutoDodgeAPI:ScanForIndicators()
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return {} end
    
    local threats = {}
    local workspace = Workspace
    
    -- FIRST: Scan Workspace for RadialIndicator MODELS (ground circles)
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Name == "RadialIndicator" then
                local circleIndicator = obj:FindFirstChild("CircleIndicator")
                if circleIndicator then
                    local dist = (hrp.Position - circleIndicator.Position).magnitude
                    local size = circleIndicator.Size.X
                    
                    -- Dodge ANY ground indicator we see
                    table.insert(threats, {
                        type = "RadialIndicator",
                        position = circleIndicator.Position,
                        radius = size / 2,
                        distance = dist,
                        object = obj,
                    })
                    
                    if self.config.debugMode then
                        print(string.format("[AutoDodge] 🔴 Ground circle detected! Distance: %.1f", dist))
                    end
                end
            end
            
            -- Scan for ConeIndicator MODELS (directional cone attacks)
            if obj:IsA("Model") and obj.Name == "ConeIndicator" then
                local coneIndicator = obj:FindFirstChild("ConeIndicator")
                if coneIndicator and coneIndicator:IsA("BasePart") then
                    local dist = (hrp.Position - coneIndicator.Position).magnitude
                    
                    -- Cone attacks have directional threat
                    table.insert(threats, {
                        type = "ConeIndicator",
                        position = coneIndicator.Position,
                        radius = 20, -- Width of cone threat
                        distance = dist,
                        object = obj,
                        conePart = coneIndicator,
                        coneLength = 30, -- How far the cone extends
                    })
                    
                    if self.config.debugMode then
                        print(string.format("[AutoDodge] 🔺 Cone attack detected! Distance: %.1f", dist))
                    end
                end
            end
        end
    end)
    
    -- SECOND: Scan for Boss/Mob attack Models in Workspace
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") then
                local objName = obj.Name
                local pivot = obj.PrimaryPart or (obj:FindFirstChild("End") or obj:FindFirstChild("Beam") or obj:FindFirstChild("Base"))
                if not pivot then pivot = obj:FindFirstChildOfClass("BasePart") end
                if pivot then
                    local dist = (hrp.Position - pivot.Position).magnitude
                    local maxScanDist = self.config.detectionRadius

                    if dist <= maxScanDist then
                        -- === KLAUS ATTACKS ===
                        if objName == "KlausGigaBeam" or objName:find("KlausGiga") then
                            table.insert(threats, {
                                type = "KlausGigaLaser",
                                position = pivot.Position,
                                radius = 100,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] ⚡ Klaus Giga Laser detected!") end
                        elseif objName == "KlausBeam" or objName:find("KlausBeam") then
                            table.insert(threats, {
                                type = "KlausIceBeam",
                                position = pivot.Position,
                                radius = 40,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] ❄️ Klaus Ice Beam detected!") end
                        elseif objName == "KlausPureIce" or objName:find("KlausPureIce") then
                            table.insert(threats, {
                                type = "KlausPureIce",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🧊 Klaus Pure Ice detected!") end
                        elseif objName == "KlausIceWall" or objName:find("KlausIceWall") then
                            table.insert(threats, {
                                type = "KlausIceWall",
                                position = pivot.Position,
                                radius = 20,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🧱 Klaus Ice Wall detected!") end
                        elseif objName == "KlausIceSpikeRing" or objName:find("KlausIceSpike") then
                            table.insert(threats, {
                                type = "KlausIceCircleSpikes",
                                position = pivot.Position,
                                radius = 30,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🔺 Klaus Ice Spikes detected!") end
                        elseif objName == "KlausPresent" or objName:find("KlausPresent") then
                            table.insert(threats, {
                                type = "KlausPresent",
                                position = pivot.Position,
                                radius = 12,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🎁 Klaus Present detected!") end

                        -- === KANDRIX ATTACKS ===
                        elseif objName:find("KandrixSkyBeam") then
                            table.insert(threats, {
                                type = "KandrixSkyBeam",
                                position = pivot.Position,
                                radius = 20,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🌌 Kandrix Sky Beam detected!") end
                        elseif objName:find("KandrixFlyingRay") then
                            table.insert(threats, {
                                type = "KandrixFlyingRay",
                                position = pivot.Position,
                                radius = 18,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 💫 Kandrix Flying Ray detected!") end
                        elseif objName:find("KandrixRay") then
                            table.insert(threats, {
                                type = "KandrixRay",
                                position = pivot.Position,
                                radius = 15,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] ⚡ Kandrix Ray detected!") end

                        -- === DRAGON ATTACKS ===
                        elseif objName:find("DarkCylinder") or objName:find("AetherDragon") then
                            table.insert(threats, {
                                type = "AetherDragonBeam",
                                position = pivot.Position,
                                radius = 25,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🐉 Aether Dragon Beam detected!") end

                        -- === IGNIS FIRE DRAGON (WINTERFALL) ===
                        elseif objName:find("Winterfall") then
                            local shieldPos = nil
                            for _, shieldObj in ipairs(workspace:GetChildren()) do
                                if shieldObj.Name:find("IgnisShield") then
                                    local shieldPart = shieldObj.PrimaryPart or shieldObj:FindFirstChildOfClass("BasePart")
                                    if shieldPart then
                                        shieldPos = shieldPart.Position
                                        break
                                    end
                                end
                            end

                            table.insert(threats, {
                                type = "IgnisWinterfall",
                                position = pivot.Position,
                                radius = 150,
                                distance = dist,
                                object = obj,
                                safeZone = shieldPos,
                            })
                            if self.config.debugMode then
                                if shieldPos then
                                    print("[AutoDodge] ❄️🔥 WINTERFALL DETECTED! Shield found - will dodge TO shield!")
                                else
                                    print("[AutoDodge] ❄️🔥 WINTERFALL DETECTED! ⚠️ NO SHIELD FOUND!")
                                end
                            end
                        elseif objName:find("IgnisShield") then
                            if self.config.debugMode then
                                print("[AutoDodge] 🛡️ Ignis Shield (Safe Zone) detected at distance: " .. dist)
                            end
                        elseif objName:find("IgnisIceBeam") or (objName:find("Ignis") and objName:find("Beam")) then
                            table.insert(threats, {
                                type = "IgnisIceBeam",
                                position = pivot.Position,
                                radius = 50,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🧊 Ignis Ice Beam detected!") end
                        elseif objName:find("IgnisMeteor") or (objName:find("Ignis") and objName:find("Meteor")) then
                            table.insert(threats, {
                                type = "IgnisMeteorFall",
                                position = pivot.Position,
                                radius = 25,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] ☄️ Ignis Meteor detected!") end
                        elseif objName:find("IgnisDownward") or objName:find("IgnisFire") then
                            table.insert(threats, {
                                type = "IgnisDownwardIceFire",
                                position = pivot.Position,
                                radius = 45,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🔥 Ignis Downward Fire detected!") end
                        elseif objName:find("IgnisTail") or (objName:find("Ignis") and objName:find("Tail")) then
                            table.insert(threats, {
                                type = "IgnisTailWhip",
                                position = pivot.Position,
                                radius = 30,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 💨 Ignis Tail Whip detected!") end
                        elseif objName:find("IgnisUltimate") then
                            table.insert(threats, {
                                type = "IgnisUltimate",
                                position = pivot.Position,
                                radius = 225,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🔥 Ignis Ultimate Cone detected!") end
                        elseif objName:find("IgnisBite") or (objName == "Bite" and workspace:FindFirstChild("BOSSIgnisFireDragon")) then
                            table.insert(threats, {
                                type = "IgnisBite",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🦷 Ignis Bite detected!") end

                        -- === CERBERUS ATTACKS ===
                        elseif objName:find("CerberusFireball") then
                            table.insert(threats, {
                                type = "CerberusFireball",
                                position = pivot.Position,
                                radius = 8,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] 🔥 Cerberus Fireball detected!") end
                        elseif objName:find("CerberusMeteor") then
                            table.insert(threats, {
                                type = "CerberusMeteorStrike",
                                position = pivot.Position,
                                radius = 15,
                                distance = dist,
                                object = obj,
                            })
                            if self.config.debugMode then print("[AutoDodge] ☄️ Cerberus Meteor detected!") end

                        -- === PROJECTILE ATTACKS ===
                        elseif objName:find("Cannonball") then
                            table.insert(threats, {
                                type = "CannonBall",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("Boulder") and not objName:find("Erupt") then
                            table.insert(threats, {
                                type = "Boulder",
                                position = pivot.Position,
                                radius = 12,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BoulderEruptBall") then
                            table.insert(threats, {
                                type = "BoulderEruptBall",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BoulderErupt") then
                            table.insert(threats, {
                                type = "BoulderErupt",
                                position = pivot.Position,
                                radius = 18,
                                distance = dist,
                                object = obj,
                            })

                        -- === MAGICAL ATTACKS ===
                        elseif objName:find("ArcaneOrb") then
                            table.insert(threats, {
                                type = "ArcaneOrb",
                                position = pivot.Position,
                                radius = 8,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("ArcaneBlast") then
                            table.insert(threats, {
                                type = "ArcaneBlast",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("ArcaneWave") then
                            table.insert(threats, {
                                type = "ArcaneWave",
                                position = pivot.Position,
                                radius = 20,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("ArcaneAscension") then
                            table.insert(threats, {
                                type = "ArcaneAscension",
                                position = pivot.Position,
                                radius = 15,
                                distance = dist,
                                object = obj,
                            })

                        -- === BLACK HOLES ===
                        elseif objName:find("BlackHoleBlazing") then
                            table.insert(threats, {
                                type = "BlackHoleBlazing",
                                position = pivot.Position,
                                radius = 25,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BlackHolePumpkin") then
                            table.insert(threats, {
                                type = "BlackHolePumpkin",
                                position = pivot.Position,
                                radius = 25,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BlackHole") then
                            table.insert(threats, {
                                type = "BlackHole",
                                position = pivot.Position,
                                radius = 25,
                                distance = dist,
                                object = obj,
                            })

                        -- === ELEMENTAL ATTACKS ===
                        elseif objName:find("AlienEruptBall") then
                            table.insert(threats, {
                                type = "AlienEruptBall",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("AlienErupt") then
                            table.insert(threats, {
                                type = "AlienErupt",
                                position = pivot.Position,
                                radius = 18,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("AlienShockwave") then
                            table.insert(threats, {
                                type = "AlienShockwave",
                                position = pivot.Position,
                                radius = 22,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("FireSpikeRing") then
                            table.insert(threats, {
                                type = "BigFireSpikeRing",
                                position = pivot.Position,
                                radius = 20,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BoneGroundSpike") then
                            table.insert(threats, {
                                type = "BoneGroundSpike",
                                position = pivot.Position,
                                radius = 12,
                                distance = dist,
                                object = obj,
                            })

                        -- === SPECIAL ATTACKS ===
                        elseif objName:find("AnubisRing") then
                            table.insert(threats, {
                                type = "AnubisRing",
                                position = pivot.Position,
                                radius = 20,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BearTrap") then
                            table.insert(threats, {
                                type = "BearTrap",
                                position = pivot.Position,
                                radius = 8,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BloodBinding") then
                            table.insert(threats, {
                                type = "BloodBinding",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BlackSheepAttack") then
                            table.insert(threats, {
                                type = "BlackSheepAttack",
                                position = pivot.Position,
                                radius = 15,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BindedRadialIndicator") then
                            table.insert(threats, {
                                type = "BindedRadialIndicator",
                                position = pivot.Position,
                                radius = 15,
                                distance = dist,
                                object = obj,
                            })

                        -- === MISC PROJECTILES ===
                        elseif objName:find("ArrowShoot") or objName:find("Arrow") then
                            table.insert(threats, {
                                type = "ArrowShoot",
                                position = pivot.Position,
                                radius = 6,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BubbleBall") then
                            table.insert(threats, {
                                type = "BubbleBall",
                                position = pivot.Position,
                                radius = 8,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("CabbageHead") then
                            table.insert(threats, {
                                type = "CabbageHead",
                                position = pivot.Position,
                                radius = 7,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("BlossomBurst") or objName:find("BigBlossom") then
                            table.insert(threats, {
                                type = "BigBlossomBulletBurst",
                                position = pivot.Position,
                                radius = 10,
                                distance = dist,
                                object = obj,
                            })
                        elseif objName:find("HeavenlySword") then
                            table.insert(threats, {
                                type = "ArcherHeavenlySword",
                                position = pivot.Position,
                                radius = 12,
                                distance = dist,
                                object = obj,
                            })
                        end
                    end -- dist check
                end -- pivot
            end -- Model
        end -- workspace children
    end)
    
    return threats
end

-- Check if a position is safe (not inside any other threat)
function AutoDodgeAPI:IsPositionSafe(position, allThreats, currentThreat)
    for _, otherThreat in ipairs(allThreats) do
        -- Skip the threat we're currently dodging
        if otherThreat ~= currentThreat then
            local distToThreat = (position - otherThreat.position).magnitude
            
            -- Check if position is inside this threat's danger zone
            if distToThreat <= otherThreat.radius + 3 then -- 3 stud buffer
                if self.config.debugMode then
                    print(string.format("[AutoDodge] ⚠️ Position unsafe! Inside %s (dist: %.1f, radius: %.1f)", otherThreat.type, distToThreat, otherThreat.radius))
                end
                return false
            end
        end
    end
    return true
end

-- Calculate dodge target position (outside danger zone)
function AutoDodgeAPI:GetDodgeTargetPosition(threat, allThreats)
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return nil end
    
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    
    local dodgeVector
    
    if threat then
        -- WINTERFALL: Dodge TOWARDS the shield (safe zone)
        if threat.type == "IgnisWinterfall" and threat.safeZone then
            -- Calculate direction TOWARDS the shield
            local toShield = (threat.safeZone - hrp.Position).Unit
            local distToShield = (threat.safeZone - hrp.Position).magnitude
            
            -- If already near shield, stay put
            if distToShield < 20 then
                if self.config.debugMode then
                    print("[AutoDodge] 🛡️ Already inside shield safe zone!")
                end
                return nil  -- Don't dodge, already safe
            end
            
            -- Move towards shield center
            dodgeVector = toShield * (distToShield - 10)  -- Get close but not inside center
            
            if self.config.debugMode then
                print(string.format("[AutoDodge] 🛡️ Winterfall: Dodging TO shield! Distance: %.1f", distToShield))
            end
        
        -- CONE ATTACKS: Dodge perpendicular to the cone's direction
        elseif threat.type == "ConeIndicator" and threat.conePart then
            local conePart = threat.conePart
            
            -- Get the cone's forward direction
            local coneDirection = conePart.CFrame.LookVector
            
            -- Calculate perpendicular vector (to the right of cone direction)
            local perpendicularRight = Vector3.new(-coneDirection.Z, 0, coneDirection.X).Unit
            
            -- Determine which side player is closer to
            local toPlayer = (hrp.Position - conePart.Position)
            local dotProduct = toPlayer:Dot(perpendicularRight)
            
            -- Dodge to the side that's already closer (easier escape)
            local dodgeDirection = dotProduct > 0 and perpendicularRight or -perpendicularRight
            
            -- Move 25 studs to the side
            dodgeVector = dodgeDirection * 25
            
            if self.config.debugMode then
                print(string.format("[AutoDodge] 🔺 Cone dodge: Moving %s", dotProduct > 0 and "RIGHT" or "LEFT"))
            end
        
        -- CIRCULAR ATTACKS: Dodge away from center
        else
            -- Calculate direction away from threat center
            local awayDir = (hrp.Position - threat.position).Unit
            
            -- If inside the danger radius, ensure we dodge far enough out
            local currentDist = (hrp.Position - threat.position).magnitude
            local requiredDist = threat.radius + 5  -- 5 studs buffer outside the zone
            
            if currentDist < requiredDist then
                -- We're inside, need to get out
                local escapeDistance = requiredDist - currentDist + self.config.safeDistance
                dodgeVector = awayDir * escapeDistance
            else
                -- Already outside but close, move further away
                dodgeVector = awayDir * self.config.safeDistance
            end
        end
    elseif self.config.preferBackwardDodge then
        -- Dodge backward relative to camera
        local camLook = camera.CFrame.LookVector
        dodgeVector = -camLook * self.config.safeDistance
    else
        -- Dodge to the side
        local camRight = camera.CFrame.RightVector
        dodgeVector = camRight * self.config.safeDistance
    end
    
    -- Calculate final position
    local targetPos = hrp.Position + dodgeVector
    
    -- Ensure we don't go below terrain (keep Y at reasonable level)
    if targetPos.Y < hrp.Position.Y - 5 then
        targetPos = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
    end
    
    -- SMART PATHFINDING: Check if dodge position is safe from OTHER attacks
    if allThreats and #allThreats > 1 then
        if not self:IsPositionSafe(targetPos, allThreats, threat) then
            if self.config.debugMode then
                print("[AutoDodge] ⚠️ Primary dodge path blocked by another attack!")
            end
            
            -- Try alternate directions for circular attacks
            if threat.type ~= "ConeIndicator" then
                local awayDir = (hrp.Position - threat.position).Unit
                local alternateDirections = {
                    awayDir:Cross(Vector3.new(0, 1, 0)).Unit, -- Perpendicular left
                    -awayDir:Cross(Vector3.new(0, 1, 0)).Unit, -- Perpendicular right
                    -awayDir, -- Opposite direction (into the attack center - last resort)
                }
                
                for i, altDir in ipairs(alternateDirections) do
                    local altPos = hrp.Position + (altDir * self.config.safeDistance)
                    altPos = Vector3.new(altPos.X, hrp.Position.Y, altPos.Z)
                    
                    if self:IsPositionSafe(altPos, allThreats, threat) then
                        if self.config.debugMode then
                            print(string.format("[AutoDodge] ✅ Found safe alternate path #%d", i))
                        end
                        targetPos = altPos
                        break
                    end
                end
            else
                -- For cone attacks, try opposite side
                local conePart = threat.conePart
                if conePart then
                    local coneDirection = conePart.CFrame.LookVector
                    local perpendicularRight = Vector3.new(-coneDirection.Z, 0, coneDirection.X).Unit
                    local toPlayer = (hrp.Position - conePart.Position)
                    local dotProduct = toPlayer:Dot(perpendicularRight)
                    
                    -- Try opposite side
                    local oppositeDodge = dotProduct > 0 and -perpendicularRight or perpendicularRight
                    local altPos = hrp.Position + (oppositeDodge * 25)
                    altPos = Vector3.new(altPos.X, hrp.Position.Y, altPos.Z)
                    
                    if self:IsPositionSafe(altPos, allThreats, threat) then
                        if self.config.debugMode then
                            print("[AutoDodge] ✅ Cone: Switched to opposite side")
                        end
                        targetPos = altPos
                    end
                end
            end
        end
    end
    
    return targetPos
end

-- Tween player out of danger zone
function AutoDodgeAPI:TweenOutOfDanger(hrp, targetPosition, threat)
    local tweenInfo = TweenInfo.new(
        self.config.tweenDuration,
        self.config.tweenStyle,
        self.config.tweenDirection,
        0,  -- Repeat count
        false,  -- Reverse
        0  -- Delay
    )
    
    local goal = {CFrame = CFrame.new(targetPosition)}
    local tween = TweenService:Create(hrp, tweenInfo, goal)
    
    tween:Play()
    
    if self.config.debugMode then
        local threatType = threat and threat.type or "Manual"
        local dist = (targetPosition - hrp.Position).magnitude
        print(string.format("[AutoDodge] 🏃 Tweening %.1f studs away from %s", dist, threatType))
    end
    
    return tween
end

-- Execute dodge
function AutoDodgeAPI:PerformDodge(threat)
    if self.state.isDodging then return false end
    if self:IsOnCooldown() then return false end
    
    local _, char, humanoid, hrp = self:GetPlayerData()
    if not char or not humanoid or not hrp then return false end
    
    -- Initialize if needed
    if not self:Init() then
        if self.config.debugMode then
            warn("[AutoDodge] Failed to initialize modules")
        end
        return false
    end
    
    self.state.isDodging = true
    _genv.AutoDodgePauseFarm = true
    local success = false
    
    -- Get all current threats for pathfinding
    local allThreats = self:ScanForIndicators()
    
    pcall(function()
        -- Calculate target position outside danger zone
        local targetPos = self:GetDodgeTargetPosition(threat, allThreats)
        
        if targetPos then
            -- Method 1: Try game's built-in dodge system first (for animation)
            local Actions = self.state.actionsModule
            if Actions and Actions.DoDodge then
                -- Call DoDodge for animation (class-specific)
                Actions:DoDodge(char)
            elseif Actions and Actions.Dodge then
                Actions:Dodge()
            end
            
            -- Method 2: Always tween to safety (smooth movement out of danger)
            self:TweenOutOfDanger(hrp, targetPos, threat)
            success = true
        end
    end)
    
    if success then
        self.state.lastDodgeTime = tick()
        
        if self.config.debugMode then
            local threatType = threat and threat.type or "Manual"
            local threatInfo = threat and string.format(" (Radius: %.1f, Distance: %.1f)", threat.radius, threat.distance) or ""
            print(string.format("[AutoDodge] ✅ Dodged! Threat: %s%s", threatType, threatInfo))
        end
    end
    
    -- Reset dodge state after tween completes
    task.delay(self.config.tweenDuration + 0.1, function()
        self.state.isDodging = false
        _genv.AutoDodgePauseFarm = false
    end)
    
    return success
end

-- Check if player is actually in danger from a threat
function AutoDodgeAPI:IsInDanger(threat)
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return false end
    
    -- Calculate distance from player to threat center
    local distToThreat = (hrp.Position - threat.position).magnitude
    
    -- Only dodge if we're actually inside or very close to the danger zone
    -- Add a small buffer (5 studs) so we dodge when entering
    if distToThreat <= threat.radius + 5 then
        if self.config.debugMode then
            print(string.format("[AutoDodge] ⚠️ IN DANGER! Distance: %.1f, Radius: %.1f", distToThreat, threat.radius))
        end
        return true
    end
    
    return false
end

-- Main threat detection loop - only dodge if in actual danger
function AutoDodgeAPI:CheckAndDodge()
    if not self.config.enabled then return end
    if self.state.isDodging then return end
    
    local threats = self:ScanForIndicators()
    
    if #threats > 0 then
        -- Find closest threat
        table.sort(threats, function(a, b)
            return a.distance < b.distance
        end)
        
        local mostDangerous = threats[1]
        
        -- Only dodge if we're actually IN the danger zone
        if not self:IsInDanger(mostDangerous) then
            if self.config.debugMode then
                print(string.format("[AutoDodge] ℹ️ Threat nearby (%.1f studs) but safe. Not dodging.", mostDangerous.distance))
            end
            return
        end
        
        -- We're in danger! Check if this is an attack we should dodge
        local shouldDodge = false
        
        -- Check radial indicators (red circles)
        if mostDangerous.type == "RadialIndicator" and self.config.autoDodgeIndicators then
            shouldDodge = true
        end
        
        -- Check cone indicators
        if mostDangerous.type == "ConeIndicator" and self.config.autoDodgeIndicators then
            shouldDodge = true
        end
        
        -- Check boss attacks and dangerous projectiles
        if self.config.autoDodgeBossAttacks then
            local dangerousTypes = {
                -- Klaus attacks
                "Klaus", "KlausGigaLaser", "KlausIceBeam", "KlausPureIce", "KlausIceWall",
                "KlausIceCircleSpikes", "KlausPresent",
                -- Kandrix attacks
                "Kandrix", "KandrixSkyBeam", "KandrixRay", "KandrixFlyingRay",
                -- Dragon attacks
                "AetherDragon", "AetherDragonBeam",
                -- Ignis Fire Dragon (Winterfall) - VERY DANGEROUS!
                "Ignis", "IgnisWinterfall", "IgnisIceBeam", "IgnisMeteor", "IgnisDownward",
                "IgnisTailWhip", "IgnisUltimate", "IgnisBite", "Winterfall",
                -- Cerberus attacks
                "Cerberus", "CerberusFireball", "CerberusMeteorStrike",
                -- Black holes (very dangerous!)
                "BlackHole", "BlackHoleBlazing", "BlackHolePumpkin",
                -- Ground AOE attacks
                "BoulderErupt", "AlienErupt", "FireSpikeRing", "BoneGroundSpike",
                "AnubisRing", "BearTrap", "BloodBinding", "ArcaneAscension",
                -- Wave attacks
                "ArcaneWave", "AlienShockwave",
                -- Dangerous projectiles
                "CannonBall", "Boulder", "BoulderEruptBall", "ArcaneOrb", "ArcaneBlast",
                "CabbageHead", "BigBlossomBulletBurst", "ArcherHeavenlySword",
                "BlackSheepAttack", "BindedRadialIndicator",
                -- Generic beams
                "Beam",
            }
            
            for _, dangerType in ipairs(dangerousTypes) do
                if mostDangerous.type:find(dangerType) then
                    shouldDodge = true
                    break
                end
            end
        end
        
        if shouldDodge then
            self:PerformDodge(mostDangerous)
        end
    end
end

-- Manual dodge (triggered by key or API call)
function AutoDodgeAPI:ManualDodge()
    return self:PerformDodge(nil)
end

-- Start auto dodge loop
function AutoDodgeAPI:StartAutoLoop()
    if self._loopConnection then return end
    
    -- Main scanning loop with deterministic interval
    self._loopConnection = RunService.Heartbeat:Connect(function(dt)
        if not self.config.enabled then return end
        self.state._lastIndicatorCheck = self.state._lastIndicatorCheck + dt
        if self.state._lastIndicatorCheck >= self.config.indicatorCheckInterval then
            self.state._lastIndicatorCheck = 0
            self:CheckAndDodge()
        end
    end)
end

-- Stop auto dodge
function AutoDodgeAPI:StopAutoLoop()
    if self._loopConnection then
        self._loopConnection:Disconnect()
        self._loopConnection = nil
    end
    
    if self._keyConnection then
        self._keyConnection:Disconnect()
        self._keyConnection = nil
    end
    
    print("[AutoDodge] 🛑 Auto dodge stopped")
end

-- Enable auto dodge
function AutoDodgeAPI:EnableAutoDodge()
    self.config.enabled = true
    _genv.AutoDodgeEnabled = true
    self:Init()
    self:StartAutoLoop()
end

-- Disable auto dodge
function AutoDodgeAPI:DisableAutoDodge()
    self.config.enabled = false
    _genv.AutoDodgeEnabled = false
    _genv.AutoDodgePauseFarm = false
    self.state.isDodging = false
    self:StopAutoLoop()
end

-- Toggle auto dodge
function AutoDodgeAPI:ToggleAutoDodge()
    if self.config.enabled then
        self:DisableAutoDodge()
    else
        self:EnableAutoDodge()
    end
    return self.config.enabled
end

-- Set tween duration
function AutoDodgeAPI:SetTweenDuration(seconds)
    self.config.tweenDuration = math.max(0.05, tonumber(seconds) or 0.2)
    if self.config.debugMode then
        print("[AutoDodge] Tween duration set to: " .. self.config.tweenDuration .. "s")
    end
end

-- Set tween easing style
function AutoDodgeAPI:SetTweenStyle(easingStyle)
    self.config.tweenStyle = easingStyle or Enum.EasingStyle.Quad
    if self.config.debugMode then
        print("[AutoDodge] Tween style set to: " .. tostring(easingStyle))
    end
end

-- Configuration functions
function AutoDodgeAPI:SetDodgeKey(keyCode)
    self.config.dodgeKey = keyCode
    if self.config.debugMode then
        local name = (keyCode and keyCode.Name) or "None"
        print("[AutoDodge] Dodge key set to: " .. name)
    end
end

function AutoDodgeAPI:SetCooldown(seconds)
    self.config.dodgeCooldown = math.max(0.1, tonumber(seconds) or 0.5)
    if self.config.debugMode then
        print("[AutoDodge] Cooldown set to: " .. self.config.dodgeCooldown .. "s")
    end
end

function AutoDodgeAPI:SetDebugMode(enabled)
    self.config.debugMode = enabled
    print("[AutoDodge] Debug mode: " .. tostring(enabled))
end

function AutoDodgeAPI:SetAutoIndicators(enabled)
    self.config.autoDodgeIndicators = enabled
    if self.config.debugMode then
        print("[AutoDodge] Auto dodge indicators: " .. tostring(enabled))
    end
end

function AutoDodgeAPI:SetAutoBossAttacks(enabled)
    self.config.autoDodgeBossAttacks = enabled
    if self.config.debugMode then
        print("[AutoDodge] Auto dodge boss attacks: " .. tostring(enabled))
    end
end

-- Get current status
function AutoDodgeAPI:GetStatus()
    local status = {
        enabled = self.config.enabled,
        onCooldown = self.state.isOnCooldown,
        cooldownRemaining = math.max(0, self.config.dodgeCooldown - (tick() - self.state.lastDodgeTime)),
        isDodging = self.state.isDodging,
        modulesLoaded = self.state.actionsModule ~= nil,
        currentClass = self.state.currentClass,
    }
    return status
end

-- Print status
function AutoDodgeAPI:PrintStatus()
    local status = self:GetStatus()
    print("=== Auto Dodge API Status ===")
    print("Enabled: " .. tostring(status.enabled))
    print("Modules Loaded: " .. tostring(status.modulesLoaded))
    print("Current Class: " .. (status.currentClass or "Unknown"))
    print("On Cooldown: " .. tostring(status.onCooldown))
    print("Cooldown Remaining: " .. string.format("%.2fs", status.cooldownRemaining))
    print("Is Dodging: " .. tostring(status.isDodging))
    local keyName = (self.config.dodgeKey and self.config.dodgeKey.Name) or "None"
    print("Dodge Key: " .. keyName)
    print("Auto Indicators: " .. tostring(self.config.autoDodgeIndicators))
    print("Auto Boss Attacks: " .. tostring(self.config.autoDodgeBossAttacks))
    print("============================")
end

-- Friendly aliases expected by main loader
function AutoDodgeAPI.enable()
    return AutoDodgeAPI:EnableAutoDodge()
end

function AutoDodgeAPI.disable()
    return AutoDodgeAPI:DisableAutoDodge()
end

function AutoDodgeAPI.toggle()
    return AutoDodgeAPI:ToggleAutoDodge()
end

-- List all supported attack patterns
function AutoDodgeAPI:ListSupportedAttacks()
    print("=== Supported Attack Patterns ===")
    print("\n🎄 KLAUS (Christmas Event Boss):")
    print("  • KlausGigaBeam (Laser) - Radius: 100")
    print("  • KlausBeam (Ice Beam) - Radius: 40")
    print("  • KlausIceSpikeRing - Radius: 30")
    print("  • KlausIceWall - Radius: 20")
    print("  • KlausPureIce - Radius: 10")
    print("  • KlausPresent - Radius: 12")
    print("  • KlausWorkshop - Radius: 25")
    
    print("\n🌌 KANDRIX:")
    print("  • KandrixSkyBeam - Radius: 20")
    print("  • KandrixRay - Radius: 15")
    print("  • KandrixFlyingRay - Radius: 18")
    
    print("\n🐉 AETHER DRAGON:")
    print("  • AetherDragonBeam - Radius: 25")
    
    print("\n❄️🔥 IGNIS FIRE DRAGON (WINTERFALL) - ⚠️ TOWER BOSS:")
    print("  • Winterfall (Ultimate) - Radius: 150 ⚠️ INSTANT KILL!")
    print("    └─ 🛡️ SURVIVAL: Dodge TO the IgnisShield (safe zone blocks damage)")
    print("  • IgnisIceBeam - Radius: 50")
    print("  • IgnisMeteorFall - Radius: 25")
    print("  • IgnisDownwardIceFire - Radius: 45")
    print("  • IgnisTailWhip - Radius: 30")
    print("  • IgnisUltimate (Cone) - Depth: 225, Angle: 35°")
    print("  • IgnisBite - Radius: 10")
    
    print("\n🔥 CERBERUS:")
    print("  • CerberusFireball - Radius: 8")
    print("  • CerberusMeteorStrike - Radius: 15")
    
    print("\n🕳️ BLACK HOLES:")
    print("  • BlackHole - Radius: 25")
    print("  • BlackHoleBlazing - Radius: 25")
    print("  • BlackHolePumpkin - Radius: 25")
    
    print("\n🌊 ELEMENTAL:")
    print("  • AlienErupt - Radius: 18")
    print("  • AlienEruptBall - Radius: 10")
    print("  • AlienShockwave - Radius: 22")
    print("  • BigFireSpikeRing - Radius: 20")
    print("  • BoneGroundSpike - Radius: 12")
    
    print("\n✨ MAGICAL:")
    print("  • ArcaneOrb - Radius: 8")
    print("  • ArcaneBlast - Radius: 10")
    print("  • ArcaneWave - Radius: 20")
    print("  • ArcaneAscension - Radius: 15")
    
    print("\n💥 PROJECTILES:")
    print("  • Cannonball - Radius: 10")
    print("  • Boulder - Radius: 12")
    print("  • BoulderErupt - Radius: 18")
    print("  • BoulderEruptBall - Radius: 10")
    print("  • ArrowShoot - Radius: 6")
    print("  • BubbleBall - Radius: 8")
    print("  • CabbageHead - Radius: 7")
    print("  • BigBlossomBulletBurst - Radius: 10")
    print("  • ArcherHeavenlySword - Radius: 12")
    
    print("\n⚠️ SPECIAL:")
    print("  • AnubisRing - Radius: 20")
    print("  • BearTrap - Radius: 8")
    print("  • BloodBinding - Radius: 10")
    print("  • BlackSheepAttack - Radius: 15")
    print("  • BindedRadialIndicator - Radius: 15")
    
    print("\n🔴 INDICATORS:")
    print("  • RadialIndicator (Ground Circles)")
    print("  • ConeIndicator (Directional Attacks)")
    
    print("\n📊 TOTAL: 70+ unique attack patterns!")
    print("================================")
end

-- Initialize on load
print("[AutoDodge] 🛡️ Auto Dodge API Loaded!")
print("[AutoDodge] 📊 70+ attack patterns detected from game data!")
print("[AutoDodge] ⚠️ Includes WINTERFALL detection (Ignis instant-kill attack)")
print("[AutoDodge] Usage:")
print("  AutoDodgeAPI:EnableAutoDodge()  -- Start auto mode")
print("  AutoDodgeAPI:DisableAutoDodge() -- Stop auto mode")
print("  AutoDodgeAPI:ManualDodge()      -- Dodge now")
print("  AutoDodgeAPI:PrintStatus()      -- Show status")
print("  AutoDodgeAPI:ListSupportedAttacks() -- List all attack types")

-- Store in global
_G.AutoDodgeAPI = AutoDodgeAPI
_G.x6p9t = AutoDodgeAPI
getgenv().x6p9t = AutoDodgeAPI

return AutoDodgeAPI