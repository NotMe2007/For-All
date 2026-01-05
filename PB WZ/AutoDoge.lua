-- ============================================================================
-- Auto Dodge API v2.0 - Optimized World-Aware Attack Evasion System
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/AutoDoge.lua
-- Completely rewritten for performance:
-- • World-specific scanning (only scans attacks relevant to current world)
-- • Tower mode: scans all boss attacks but skips ground-only/melee attacks
-- • Flying-aware: won't dodge attacks that can't hit airborne players
-- • No more 3-second freeze after dodging
-- • 180 stud detection radius for towers
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
--
-- Key protections implemented:
-- • Uses TweenService for smooth movement (not instant teleport)
-- • DOES NOT fire DidDodge remote (avoids 4-second rate limit detection)
-- • Client-side only movement detection avoidance
-- • Per-dodge cooldown (0.15s default) prevents spam detection
-- • TeleportAntiCheat note: The game's DidDodge remote grants a 2-second
--   immunity window from position validation. However, this module uses
--   TweenService directly and doesn't need the remote since movements
--   are smooth and gradual, not instant teleports.
-- ============================================================================

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')
local TweenService = game:GetService('TweenService')

local _genv = getgenv()

-- ============================================================================
-- WORLD & ATTACK DATABASE
-- ============================================================================
-- Each world has specific mobs/attacks. We only scan for what exists in that world.
-- canHitAir = false means the attack CANNOT hit flying players (ground-only/melee)

local WORLD_ATTACKS = {
    -- World 1: Forest/Starter area
    [1] = {
        attacks = {"RadialIndicator", "ConeIndicator"},
        bosses = {},
        description = "Forest",
    },
    -- World 2: Desert
    [2] = {
        attacks = {"RadialIndicator", "ConeIndicator", "AnubisRing"},
        bosses = {"Anubis"},
        description = "Desert",
    },
    -- World 3: Ice/Snow
    [3] = {
        attacks = {"RadialIndicator", "ConeIndicator", "IcePatch"},
        bosses = {},
        description = "Ice",
    },
    -- World 4: Volcano
    [4] = {
        attacks = {"RadialIndicator", "ConeIndicator", "GroundFire", "CerberusFireball", "CerberusMeteor"},
        bosses = {"Cerberus"},
        description = "Volcano",
    },
    -- World 5: Ocean/Atlantis
    [5] = {
        attacks = {"RadialIndicator", "ConeIndicator", "BubbleBall"},
        bosses = {},
        description = "Ocean",
    },
    -- World 6: Sky/Floating Islands
    [6] = {
        attacks = {"RadialIndicator", "ConeIndicator", "ArcaneOrb", "ArcaneBlast", "ArcaneWave"},
        bosses = {},
        description = "Sky",
    },
    -- World 7: Undead/Graveyard
    [7] = {
        attacks = {"RadialIndicator", "ConeIndicator", "BoneGroundSpike", "BloodBinding"},
        bosses = {},
        description = "Undead",
    },
    -- World 8: Alien/Space
    [8] = {
        attacks = {"RadialIndicator", "ConeIndicator", "AlienErupt", "AlienEruptBall", "AlienShockwave"},
        bosses = {},
        description = "Alien",
    },
    -- World 9: Crystal/Kandrix
    [9] = {
        attacks = {"RadialIndicator", "ConeIndicator", "KandrixSkyBeam", "KandrixRay", "KandrixFlyingRay"},
        bosses = {"Kandrix"},
        description = "Crystal",
    },
    -- World 10: Dragon/Aether
    [10] = {
        attacks = {"RadialIndicator", "ConeIndicator", "AetherDragonBeam", "DarkCylinder"},
        bosses = {"AetherDragon"},
        description = "Dragon",
    },
    -- Tower/Dungeon mode - all boss attacks enabled
    tower = {
        attacks = {"all"},
        bosses = {"all"},
        description = "Tower",
    },
}

-- Attack properties database
-- canHitAir: true = can hit flying players, false = ground-only (skip when flying)
-- radius: detection/danger radius
-- priority: 1 = instant kill, 2 = high damage, 3 = normal
local ATTACK_DATA = {
    -- === INDICATORS (always dodge) ===
    RadialIndicator = { radius = 0, canHitAir = true, priority = 2, isDynamic = true },
    ConeIndicator = { radius = 25, canHitAir = true, priority = 2 },
    
    -- === KLAUS (Christmas Boss) ===
    KlausGigaBeam = { radius = 100, canHitAir = true, priority = 1 },
    KlausBeam = { radius = 40, canHitAir = true, priority = 2 },
    KlausIceSpikeRing = { radius = 30, canHitAir = false, priority = 2 }, -- Ground spikes
    KlausIceWall = { radius = 20, canHitAir = false, priority = 2 }, -- Ground wall
    KlausPureIce = { radius = 10, canHitAir = true, priority = 3 },
    KlausPresent = { radius = 12, canHitAir = true, priority = 3 },
    
    -- === KANDRIX ===
    KandrixSkyBeam = { radius = 20, canHitAir = true, priority = 2 },
    KandrixRay = { radius = 15, canHitAir = true, priority = 2 },
    KandrixFlyingRay = { radius = 18, canHitAir = true, priority = 2 },
    
    -- === AETHER DRAGON ===
    AetherDragonBeam = { radius = 25, canHitAir = true, priority = 2 },
    DarkCylinder = { radius = 25, canHitAir = true, priority = 2 },
    
    -- === IGNIS FIRE DRAGON (Winterfall) ===
    Winterfall = { radius = 150, canHitAir = true, priority = 1, hasSafeZone = true }, -- INSTANT KILL
    IgnisShield = { radius = 25, canHitAir = false, priority = 0, isSafe = true },
    IgnisIceBeam = { radius = 50, canHitAir = true, priority = 2 },
    IgnisMeteor = { radius = 25, canHitAir = true, priority = 2 },
    IgnisDownwardFire = { radius = 45, canHitAir = true, priority = 2 },
    IgnisTailWhip = { radius = 30, canHitAir = false, priority = 2 }, -- Melee swipe
    IgnisUltimate = { radius = 225, canHitAir = true, priority = 1 },
    IgnisBite = { radius = 10, canHitAir = false, priority = 3 }, -- Melee bite
    
    -- === CERBERUS ===
    CerberusFireball = { radius = 8, canHitAir = true, priority = 3 },
    CerberusMeteor = { radius = 15, canHitAir = true, priority = 2 },
    
    -- === BLACK HOLES ===
    BlackHole = { radius = 25, canHitAir = true, priority = 2 },
    BlackHoleBlazing = { radius = 25, canHitAir = true, priority = 2 },
    BlackHolePumpkin = { radius = 25, canHitAir = true, priority = 2 },
    
    -- === ELEMENTAL ===
    AlienErupt = { radius = 18, canHitAir = false, priority = 2 }, -- Ground eruption
    AlienEruptBall = { radius = 10, canHitAir = true, priority = 3 },
    AlienShockwave = { radius = 22, canHitAir = false, priority = 2 }, -- Ground wave
    BigFireSpikeRing = { radius = 20, canHitAir = false, priority = 2 }, -- Ground spikes
    BoneGroundSpike = { radius = 12, canHitAir = false, priority = 2 }, -- Ground spikes
    
    -- === GROUND HAZARDS ===
    GroundFire = { radius = 10, canHitAir = false, priority = 3 },
    IcePatch = { radius = 10, canHitAir = false, priority = 3 },
    PoisonPool = { radius = 10, canHitAir = false, priority = 3 },
    
    -- === SPECIAL ===
    AnubisRing = { radius = 20, canHitAir = false, priority = 2 }, -- Ground ring
    BearTrap = { radius = 8, canHitAir = false, priority = 3 }, -- Ground trap
    BloodBinding = { radius = 10, canHitAir = true, priority = 2 },
    
    -- === MAGICAL ===
    ArcaneOrb = { radius = 8, canHitAir = true, priority = 3 },
    ArcaneBlast = { radius = 10, canHitAir = true, priority = 3 },
    ArcaneWave = { radius = 20, canHitAir = false, priority = 2 }, -- Ground wave
    ArcaneAscension = { radius = 15, canHitAir = false, priority = 2 }, -- Ground effect
    
    -- === PROJECTILES ===
    Cannonball = { radius = 10, canHitAir = true, priority = 3 },
    Boulder = { radius = 12, canHitAir = true, priority = 3 },
    BoulderErupt = { radius = 18, canHitAir = false, priority = 2 }, -- Ground eruption
    BoulderEruptBall = { radius = 10, canHitAir = true, priority = 3 },
    ArrowShoot = { radius = 6, canHitAir = true, priority = 3 },
    BubbleBall = { radius = 8, canHitAir = true, priority = 3 },
    CabbageHead = { radius = 7, canHitAir = true, priority = 3 },
    BigBlossomBulletBurst = { radius = 10, canHitAir = true, priority = 3 },
    ArcherHeavenlySword = { radius = 12, canHitAir = true, priority = 3 },
    BlackSheepAttack = { radius = 15, canHitAir = false, priority = 2 }, -- Ground charge
    BindedRadialIndicator = { radius = 15, canHitAir = true, priority = 2 },
}

-- ============================================================================
-- AUTO DODGE API
-- ============================================================================

local AutoDodgeAPI = {}
AutoDodgeAPI.__index = AutoDodgeAPI

-- Configuration
AutoDodgeAPI.config = {
    enabled = false,
    debugMode = false,
    
    -- Detection settings
    detectionRadius = 180,       -- Max scan distance (180 studs for towers)
    normalWorldRadius = 80,      -- Smaller radius for normal worlds
    
    -- Dodge settings
    dodgeCooldown = 0.15,        -- Cooldown between dodges
    safeDistance = 35,           -- Distance to dodge away
    tweenDuration = 0.12,        -- Fast tween for responsive dodge
    tweenStyle = Enum.EasingStyle.Quad,
    tweenDirection = Enum.EasingDirection.Out,
    
    -- Optimization settings
    scanInterval = 0.08,         -- How often to scan (seconds)
    idleScanInterval = 0.5,      -- Slow scan when no threats
    
    -- What to dodge
    autoDodgeIndicators = true,
    autoDodgeBossAttacks = true,
    skipGroundAttacksWhenFlying = true, -- Skip ground-only attacks when airborne
    
    -- Flying detection
    flyingHeightThreshold = 8,   -- Consider "flying" if this high above ground
}

-- State
AutoDodgeAPI.state = {
    lastDodgeTime = 0,
    isDodging = false,
    currentWorld = nil,
    isInTower = false,
    isFlying = false,
    lastScanTime = 0,
    actionsModule = nil,
    _loopConnection = nil,
}

-- Getgenv flags
if _genv.AutoDodgePauseFarm == nil then _genv.AutoDodgePauseFarm = false end
if _genv.AutoDodgeEnabled == nil then _genv.AutoDodgeEnabled = false end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function safeRequire(mod)
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    return ok and res or nil
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

-- Check if player is flying (high above ground)
function AutoDodgeAPI:CheckIfFlying()
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return false end
    
    -- Raycast down to find ground
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {Players.LocalPlayer.Character}
    
    local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -50, 0), rayParams)
    if result then
        local heightAboveGround = (hrp.Position.Y - result.Position.Y)
        self.state.isFlying = heightAboveGround > self.config.flyingHeightThreshold
    else
        -- No ground found within 50 studs = definitely flying
        self.state.isFlying = true
    end
    
    return self.state.isFlying
end

-- Detect current world number from place or map markers
function AutoDodgeAPI:DetectWorld()
    local plr = Players.LocalPlayer
    if not plr or not plr.Character then return nil end
    
    -- Check if in a tower/dungeon
    self.state.isInTower = false
    
    -- Method 1: Check for tower/dungeon markers in workspace
    pcall(function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            local name = obj.Name:lower()
            if name:find("tower") or name:find("dungeon") or name:find("boss") or
               name:find("prison") or name:find("atlantis") or name:find("crabby") or
               name:find("scarecrow") or name:find("gravetower") or name:find("kingslayer") then
                self.state.isInTower = true
                self.state.currentWorld = "tower"
                return
            end
        end
    end)
    
    if self.state.isInTower then
        return "tower"
    end
    
    -- Method 2: Check PlaceId for world detection
    local placeId = game.PlaceId
    
    -- World // Zero place IDs (approximate - adjust as needed)
    local worldPlaces = {
        [2727067538] = 1,  -- Main hub/World 1
        -- Add more place IDs as discovered
    }
    
    if worldPlaces[placeId] then
        self.state.currentWorld = worldPlaces[placeId]
        return self.state.currentWorld
    end
    
    -- Method 3: Check player's level/zone attribute
    pcall(function()
        local profile = plr.Character:FindFirstChild('Profile')
        if profile then
            local worldVal = profile:FindFirstChild('World') or profile:FindFirstChild('Zone')
            if worldVal then
                local num = tonumber(worldVal.Value)
                if num then
                    self.state.currentWorld = num
                end
            end
        end
    end)
    
    -- Method 4: Scan workspace for world-specific mobs to determine world
    pcall(function()
        local mobsFolder = Workspace:FindFirstChild('Mobs')
        if mobsFolder and #mobsFolder:GetChildren() > 0 then
            for _, mob in ipairs(mobsFolder:GetChildren()) do
                local mobName = mob.Name:lower()
                -- World 10 mobs
                if mobName:find("dragon") or mobName:find("aether") or mobName:find("wyrm") then
                    self.state.currentWorld = 10
                    return
                -- World 9 mobs
                elseif mobName:find("crystal") or mobName:find("kandrix") then
                    self.state.currentWorld = 9
                    return
                -- World 8 mobs
                elseif mobName:find("alien") or mobName:find("space") then
                    self.state.currentWorld = 8
                    return
                -- World 4 mobs
                elseif mobName:find("cerberus") or mobName:find("lava") or mobName:find("fire") then
                    self.state.currentWorld = 4
                    return
                end
            end
        end
    end)
    
    -- Default to tower mode if can't detect (safest option)
    if not self.state.currentWorld then
        self.state.currentWorld = "tower"
        self.state.isInTower = true
    end
    
    return self.state.currentWorld
end

-- Check if an attack type is relevant for current world
function AutoDodgeAPI:IsAttackRelevant(attackType)
    local world = self.state.currentWorld
    if not world then
        self:DetectWorld()
        world = self.state.currentWorld
    end
    
    -- Tower mode: all attacks relevant
    if world == "tower" or self.state.isInTower then
        return true
    end
    
    -- Check world-specific attacks
    local worldData = WORLD_ATTACKS[world]
    if not worldData then return true end -- Unknown world, scan all
    
    -- RadialIndicator and ConeIndicator always relevant
    if attackType == "RadialIndicator" or attackType == "ConeIndicator" then
        return true
    end
    
    -- Check if attack is in this world's list
    for _, attack in ipairs(worldData.attacks) do
        if attack == "all" or attackType:find(attack) then
            return true
        end
    end
    
    return false
end

-- Check if should skip attack because flying
function AutoDodgeAPI:ShouldSkipBecauseFlying(attackType)
    if not self.config.skipGroundAttacksWhenFlying then return false end
    if not self.state.isFlying then return false end
    
    local data = ATTACK_DATA[attackType]
    if data and data.canHitAir == false then
        return true
    end
    
    return false
end

-- Get attack radius from database
function AutoDodgeAPI:GetAttackRadius(attackType)
    local data = ATTACK_DATA[attackType]
    return data and data.radius or 15
end

-- Get attack priority
function AutoDodgeAPI:GetAttackPriority(attackType)
    local data = ATTACK_DATA[attackType]
    return data and data.priority or 3
end

-- ============================================================================
-- THREAT SCANNING (Optimized)
-- ============================================================================

function AutoDodgeAPI:ScanForThreats()
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return {} end
    
    local threats = {}
    local playerPos = hrp.Position
    local detectionRadius = self.state.isInTower and self.config.detectionRadius or self.config.normalWorldRadius
    
    -- Update flying status
    self:CheckIfFlying()
    
    -- SCAN 1: RadialIndicator models (ground circles) - ALWAYS scan these
    pcall(function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Name == "RadialIndicator" then
                local circleIndicator = obj:FindFirstChild("CircleIndicator")
                if circleIndicator then
                    local dist = (playerPos - circleIndicator.Position).Magnitude
                    if dist <= detectionRadius then
                        local size = circleIndicator.Size.X / 2
                        table.insert(threats, {
                            type = "RadialIndicator",
                            position = circleIndicator.Position,
                            radius = size,
                            distance = dist,
                            priority = 2,
                        })
                    end
                end
            -- Cone indicators
            elseif obj:IsA("Model") and obj.Name == "ConeIndicator" then
                local conePart = obj:FindFirstChild("ConeIndicator")
                if conePart then
                    local dist = (playerPos - conePart.Position).Magnitude
                    if dist <= detectionRadius then
                        table.insert(threats, {
                            type = "ConeIndicator",
                            position = conePart.Position,
                            radius = 25,
                            distance = dist,
                            priority = 2,
                            conePart = conePart,
                        })
                    end
                end
            end
        end
    end)
    
    -- SCAN 2: Boss attack models (only if relevant to current world)
    if self.config.autoDodgeBossAttacks then
        pcall(function()
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") then
                    local name = obj.Name
                    local attackType = nil
                    local radius = 15
                    local priority = 3
                    local safeZone = nil
                    
                    -- Match attack patterns
                    if name:find("KlausGiga") then
                        attackType = "KlausGigaBeam"
                    elseif name:find("KlausBeam") then
                        attackType = "KlausBeam"
                    elseif name:find("KlausIceSpike") then
                        attackType = "KlausIceSpikeRing"
                    elseif name:find("KlausIceWall") then
                        attackType = "KlausIceWall"
                    elseif name:find("KlausPureIce") then
                        attackType = "KlausPureIce"
                    elseif name:find("KlausPresent") then
                        attackType = "KlausPresent"
                    elseif name:find("KandrixSkyBeam") then
                        attackType = "KandrixSkyBeam"
                    elseif name:find("KandrixFlyingRay") then
                        attackType = "KandrixFlyingRay"
                    elseif name:find("KandrixRay") then
                        attackType = "KandrixRay"
                    elseif name:find("DarkCylinder") or name:find("AetherDragon") then
                        attackType = "AetherDragonBeam"
                    elseif name:find("Winterfall") then
                        attackType = "Winterfall"
                        -- Find shield safe zone
                        for _, shield in ipairs(Workspace:GetChildren()) do
                            if shield.Name:find("IgnisShield") then
                                local part = shield.PrimaryPart or shield:FindFirstChildOfClass("BasePart")
                                if part then safeZone = part.Position end
                                break
                            end
                        end
                    elseif name:find("IgnisIceBeam") or (name:find("Ignis") and name:find("Beam")) then
                        attackType = "IgnisIceBeam"
                    elseif name:find("IgnisMeteor") then
                        attackType = "IgnisMeteor"
                    elseif name:find("IgnisDownward") or name:find("IgnisFire") then
                        attackType = "IgnisDownwardFire"
                    elseif name:find("IgnisTail") then
                        attackType = "IgnisTailWhip"
                    elseif name:find("IgnisUltimate") then
                        attackType = "IgnisUltimate"
                    elseif name:find("IgnisBite") or (name == "Bite") then
                        attackType = "IgnisBite"
                    elseif name:find("CerberusFireball") then
                        attackType = "CerberusFireball"
                    elseif name:find("CerberusMeteor") then
                        attackType = "CerberusMeteor"
                    elseif name:find("BlackHoleBlazing") then
                        attackType = "BlackHoleBlazing"
                    elseif name:find("BlackHolePumpkin") then
                        attackType = "BlackHolePumpkin"
                    elseif name:find("BlackHole") then
                        attackType = "BlackHole"
                    elseif name:find("AlienEruptBall") then
                        attackType = "AlienEruptBall"
                    elseif name:find("AlienErupt") then
                        attackType = "AlienErupt"
                    elseif name:find("AlienShockwave") then
                        attackType = "AlienShockwave"
                    elseif name:find("BoneGroundSpike") then
                        attackType = "BoneGroundSpike"
                    elseif name:find("AnubisRing") then
                        attackType = "AnubisRing"
                    elseif name:find("ArcaneWave") then
                        attackType = "ArcaneWave"
                    elseif name:find("ArcaneOrb") then
                        attackType = "ArcaneOrb"
                    elseif name:find("ArcaneBlast") then
                        attackType = "ArcaneBlast"
                    elseif name:find("BoulderErupt") then
                        attackType = "BoulderErupt"
                    elseif name:find("Boulder") then
                        attackType = "Boulder"
                    end
                    
                    -- Process if attack type identified
                    if attackType then
                        local shouldProcess = true
                        
                        -- Check world relevance
                        if not self:IsAttackRelevant(attackType) then
                            -- Skip attack not in this world
                            shouldProcess = false
                        end
                        
                        -- Check if flying and should skip ground attacks
                        if shouldProcess and self:ShouldSkipBecauseFlying(attackType) then
                            shouldProcess = false
                        end
                        
                        if shouldProcess then
                            -- Get attack position
                            local pivot = obj.PrimaryPart or obj:FindFirstChild("End") or 
                                          obj:FindFirstChild("Beam") or obj:FindFirstChild("Base") or
                                          obj:FindFirstChildOfClass("BasePart")
                            
                            if pivot then
                                local dist = (playerPos - pivot.Position).Magnitude
                                if dist <= detectionRadius then
                                    radius = self:GetAttackRadius(attackType)
                                    priority = self:GetAttackPriority(attackType)
                                    
                                    table.insert(threats, {
                                        type = attackType,
                                        position = pivot.Position,
                                        radius = radius,
                                        distance = dist,
                                        priority = priority,
                                        safeZone = safeZone,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
    
    return threats
end

-- ============================================================================
-- DODGE EXECUTION
-- ============================================================================

function AutoDodgeAPI:IsOnCooldown()
    return (tick() - self.state.lastDodgeTime) < self.config.dodgeCooldown
end

function AutoDodgeAPI:IsInDanger(threat)
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return false end
    
    local dist = (hrp.Position - threat.position).Magnitude
    -- Dodge if inside or about to enter danger zone (5 stud buffer)
    return dist <= (threat.radius + 5)
end

function AutoDodgeAPI:GetDodgePosition(threat, allThreats)
    local _, _, _, hrp = self:GetPlayerData()
    if not hrp then return nil end
    
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    
    local dodgeVector
    
    if threat then
        -- WINTERFALL: Dodge TO shield
        if threat.type == "Winterfall" and threat.safeZone then
            local toShield = (threat.safeZone - hrp.Position).Unit
            local distToShield = (threat.safeZone - hrp.Position).Magnitude
            if distToShield < 20 then return nil end -- Already safe
            dodgeVector = toShield * (distToShield - 10)
            
        -- CONE: Dodge perpendicular
        elseif threat.type == "ConeIndicator" and threat.conePart then
            local coneDir = threat.conePart.CFrame.LookVector
            local perpRight = Vector3.new(-coneDir.Z, 0, coneDir.X).Unit
            local toPlayer = (hrp.Position - threat.conePart.Position)
            toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z).Unit
            local dot = toPlayer:Dot(perpRight)
            dodgeVector = (dot > 0 and perpRight or -perpRight) * 5
            
        -- CIRCULAR: Dodge away from center
        else
            local awayDir = (hrp.Position - threat.position).Unit
            local currentDist = (hrp.Position - threat.position).Magnitude
            local escapeDistance = math.max(threat.radius - currentDist + 10, self.config.safeDistance)
            dodgeVector = awayDir * escapeDistance
        end
    else
        -- Default: backward dodge
        local camLook = camera.CFrame.LookVector
        dodgeVector = -camLook * self.config.safeDistance
    end
    
    -- Keep horizontal, maintain height
    dodgeVector = Vector3.new(dodgeVector.X, 0, dodgeVector.Z)
    local targetPos = hrp.Position + dodgeVector
    
    return targetPos
end

function AutoDodgeAPI:PerformDodge(threat)
    if self.state.isDodging then return false end
    if self:IsOnCooldown() then return false end
    
    local _, char, humanoid, hrp = self:GetPlayerData()
    if not char or not humanoid or not hrp then return false end
    
    self.state.isDodging = true
    _genv.AutoDodgePauseFarm = true
    
    local success = false
    
    pcall(function()
        local targetPos = self:GetDodgePosition(threat)
        if targetPos then
            -- Tween to safety
            local tweenInfo = TweenInfo.new(
                self.config.tweenDuration,
                self.config.tweenStyle,
                self.config.tweenDirection
            )
            local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
            tween:Play()
            success = true
        end
    end)
    
    if success then
        self.state.lastDodgeTime = tick()
    end
    
    -- Quick reset - NO MORE 3 SECOND DELAY!
    task.delay(self.config.tweenDuration + 0.1, function()
        self.state.isDodging = false
        _genv.AutoDodgePauseFarm = false
    end)
    
    return success
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

function AutoDodgeAPI:CheckAndDodge()
    if not self.config.enabled then return end
    if self.state.isDodging then return end
    
    local threats = self:ScanForThreats()
    if #threats == 0 then return end
    
    -- Sort by priority then distance
    table.sort(threats, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.distance < b.distance
    end)
    
    local threat = threats[1]
    
    -- Only dodge if actually in danger
    if self:IsInDanger(threat) then
        self:PerformDodge(threat)
    end
end

function AutoDodgeAPI:StartAutoLoop()
    if self.state._loopConnection then return end
    
    -- Detect world once at start
    self:DetectWorld()
    
    local lastCheck = 0
    
    self.state._loopConnection = RunService.Heartbeat:Connect(function()
        if not self.config.enabled then return end
        
        local now = tick()
        local interval = self.config.scanInterval
        
        if now - lastCheck >= interval then
            lastCheck = now
            self:CheckAndDodge()
        end
    end)
end

function AutoDodgeAPI:StopAutoLoop()
    if self.state._loopConnection then
        self.state._loopConnection:Disconnect()
        self.state._loopConnection = nil
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function AutoDodgeAPI:EnableAutoDodge()
    self.config.enabled = true
    _genv.AutoDodgeEnabled = true
    self:StartAutoLoop()
end

function AutoDodgeAPI:DisableAutoDodge()
    self.config.enabled = false
    _genv.AutoDodgeEnabled = false
    _genv.AutoDodgePauseFarm = false
    self.state.isDodging = false
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

function AutoDodgeAPI:SetTweenDuration(seconds)
    self.config.tweenDuration = math.max(0.05, tonumber(seconds) or 0.12)
end

function AutoDodgeAPI:SetCooldown(seconds)
    self.config.dodgeCooldown = math.max(0.1, tonumber(seconds) or 0.15)
end

function AutoDodgeAPI:SetDebugMode(enabled)
    self.config.debugMode = enabled
end

function AutoDodgeAPI:GetStatus()
    return {
        enabled = self.config.enabled,
        currentWorld = self.state.currentWorld,
        isInTower = self.state.isInTower,
        isFlying = self.state.isFlying,
        isDodging = self.state.isDodging,
        onCooldown = self:IsOnCooldown(),
    }
end

function AutoDodgeAPI:PrintStatus()
    -- Prints removed for anti-cheat
    return self:GetStatus()
end

-- Force tower mode (scan all attacks)
function AutoDodgeAPI:SetTowerMode(enabled)
    if enabled then
        self.state.currentWorld = "tower"
        self.state.isInTower = true
    else
        self:DetectWorld()
    end
end

-- Force specific world
function AutoDodgeAPI:SetWorld(worldNum)
    self.state.currentWorld = worldNum
    self.state.isInTower = (worldNum == "tower")
end

-- Aliases for compatibility
function AutoDodgeAPI.enable() return AutoDodgeAPI:EnableAutoDodge() end
function AutoDodgeAPI.disable() return AutoDodgeAPI:DisableAutoDodge() end
function AutoDodgeAPI.toggle() return AutoDodgeAPI:ToggleAutoDodge() end

-- ============================================================================
-- INITIALIZE
-- ============================================================================

-- Store globally
_G.AutoDodgeAPI = AutoDodgeAPI
_G.x6p9t = AutoDodgeAPI
getgenv().x6p9t = AutoDodgeAPI

return AutoDodgeAPI
