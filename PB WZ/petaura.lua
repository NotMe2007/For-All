-- ============================================================================
-- Pet Aura - Automated Pet Skill System
-- ============================================================================
-- Intelligent automated pet skill usage with behavior-based activation
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/petaura.lua
--
-- API USAGE:
-- • _G.x8p3q.enable()          - Enable pet aura
-- • _G.x8p3q.disable()         - Disable pet aura
-- • _G.x8p3q.toggle()          - Toggle pet aura state
-- • _G.x8p3q.status()          - Print current status
-- • _G.x8p3q.getStats()        - Get session statistics
-- • _G.x8p3q.setSupportRange(studs) - Set support skill range (default 60)
-- • _G.x8p3q.setHealThreshold(pct)  - Set heal HP threshold (default 0.5)
-- • _G.PetAuraAPI (alias)      - Same as _G.x8p3q
--
-- FEATURES:
-- • Auto-detects pet skill type (Attack, Heal, Support/Buff, Drop)
-- • Attack skills: Auto-use when available and target in range
-- • Heal skills: Tween to lowest HP ally and use skill
-- • Support skills: Use when allies within range (60 studs default) 
-- • Drop skills: Use near allies to benefit party
-- • Respects game cooldowns from PetSkills module
-- • Human-like timing variance for anti-detection
--
-- SKILL CLASSIFICATIONS:
-- • Attack: Has DamageValues AND NeedsTarget = true
-- • Heal: Name contains "Heal" (HealPulse, HealReach, TetheredHeal, etc.)
-- • Support: NeedsTarget = false, provides buffs (defense, speed, cure)
-- • Drop: Spawns items/orbs for party benefit (TurkeyFoodDrop, GlyphAttack, UltRing)
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
-- Uses game's native PetSkills:UseSkill method for safe activation.
-- ============================================================================

-- SERVICES
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local Workspace = game:GetService('Workspace')

-- Player reference
local player = Players.LocalPlayer
if not player then return end

-- Global environment
local _genv = getgenv()

-- ============================================================================
-- MODULE LOADING (Safe)
-- ============================================================================

local PetSkills = nil
local PetSkillsLoaded = false
local Pets = nil
local PetsLoaded = false
local Profile = nil
local ProfileLoaded = false
local Health = nil
local HealthLoaded = false

pcall(function()
    PetSkills = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('PetSkills', 5))
    PetSkillsLoaded = true
end)

pcall(function()
    Pets = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('Pets', 5))
    PetsLoaded = true
end)

pcall(function()
    Profile = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('Profile', 5))
    ProfileLoaded = true
end)

pcall(function()
    Health = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('Health', 5))
    HealthLoaded = true
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Custom wait function using Heartbeat
local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        if task and task.wait then
            task.wait(sec)
        else
            local t0 = os.clock()
            while os.clock() - t0 < sec do
                RunService.Heartbeat:Wait()
            end
        end
    else
        RunService.Heartbeat:Wait()
    end
end

--- Add random variance to a value (anti-detection)
local function addVariance(value, variance)
    variance = variance or 0.15
    local delta = value * variance
    return value + (math.random() * 2 - 1) * delta
end

--- Safe spawn function
local spawn = function(f)
    coroutine.wrap(f)()
end

-- ============================================================================
-- PET SKILL DATABASE (from decompiled PetSkills module)
-- ============================================================================
-- Skill classifications based on actual game data

local SkillData = {
    -- ATTACK SKILLS (NeedsTarget = true, has DamageValues)
    Bite = { type = "Attack", cooldown = 15 },
    Scratch = { type = "Attack", cooldown = 15 },
    Fireball = { type = "Attack", cooldown = 15 },
    FireballGreen = { type = "Attack", cooldown = 15 },
    Iceball = { type = "Attack", cooldown = 15 },
    PoisonSplash = { type = "Attack", cooldown = 15 },
    IcySpikes = { type = "Attack", cooldown = 15 },
    BlackFlame = { type = "Attack", cooldown = 30 },
    LightningStrike = { type = "Attack", cooldown = 25 },
    DireBlast = { type = "Attack", cooldown = 30 },
    DragonBlast = { type = "Attack", cooldown = 30 },
    FrontalFire = { type = "Attack", cooldown = 30 },
    MiseryFire = { type = "Attack", cooldown = 30 },
    CerberusFire = { type = "Attack", cooldown = 30 },
    Wildfire = { type = "Attack", cooldown = 30 },
    SkeletalSlash = { type = "Attack", cooldown = 30 },
    HoodedSlash = { type = "Attack", cooldown = 30 },
    HoodedSlashPoison = { type = "Attack", cooldown = 30 },
    PoisonBreath = { type = "Attack", cooldown = 28 },
    BlackHole = { type = "Attack", cooldown = 30 },
    BlackHolePumpkin = { type = "Attack", cooldown = 30 },
    BlackHoleBlazing = { type = "Attack", cooldown = 30 },
    BlackHoleCabbage = { type = "Attack", cooldown = 30 },
    MeteorStrike = { type = "Attack", cooldown = 35 },
    AlienStrike = { type = "Attack", cooldown = 35 },
    BlackSheepAttack = { type = "Attack", cooldown = 30 },
    PurpleDragonAttack = { type = "Attack", cooldown = 30 },
    RedDragonAttack = { type = "Attack", cooldown = 35 },
    HellhoundAttack = { type = "Attack", cooldown = 35 },
    PumpkinAttack = { type = "Attack", cooldown = 30 },
    CupidPetShockwave = { type = "Attack", cooldown = 25 },
    SkeledileAttack = { type = "Attack", cooldown = 25 },
    Whirlpool = { type = "Attack", cooldown = 30 },
    WhirlpoolIce = { type = "Attack", cooldown = 28 },
    BeeAttack = { type = "Attack", cooldown = 20 },
    BeeAttackPro = { type = "Attack", cooldown = 15 },
    FlameProtection = { type = "Attack", cooldown = 35 },
    FlameProtectionPurple = { type = "Attack", cooldown = 35 },
    AvatarFlameProtection = { type = "Attack", cooldown = 25 },
    PurpleSheepAttack = { type = "Attack", cooldown = 30 },
    MegaBite = { type = "Attack", cooldown = 15 },
    MegaBitePro = { type = "Attack", cooldown = 15 },
    SlimeSplash = { type = "Attack", cooldown = 30 },
    SlimeSplashFire = { type = "Attack", cooldown = 30 },
    SlimeSplashPoison = { type = "Attack", cooldown = 30 },
    SlimeSplashIce = { type = "Attack", cooldown = 30 },
    Snowstorm = { type = "Attack", cooldown = 38 },
    ShadowEssence = { type = "Attack", cooldown = 38 },
    ShiningCrystal = { type = "Attack", cooldown = 22 },
    ShiningCrystalPro = { type = "Attack", cooldown = 25 },
    CharmingHeart = { type = "Attack", cooldown = 22 },
    CharmingBrokenHeart = { type = "Attack", cooldown = 22 },
    CharmingSnowflake = { type = "Attack", cooldown = 22 },
    SpiritBeam = { type = "Attack", cooldown = 20 },
    SpiritBeamFire = { type = "Attack", cooldown = 20 },
    SpiritBeamAether = { type = "Attack", cooldown = 20 },
    SpiritBeamPoison = { type = "Attack", cooldown = 20 },
    PenguinSlide = { type = "Attack", cooldown = 30 },
    PenguinSlide_Aether = { type = "Attack", cooldown = 30 },
    PenguinSlide_Frozen = { type = "Attack", cooldown = 30 },
    PenguinSlide_Burn = { type = "Attack", cooldown = 30 },
    PenguinSlide_Poison = { type = "Attack", cooldown = 30 },
    GMKnoxAttack = { type = "Attack", cooldown = 30 },
    FireballDH = { type = "Attack", cooldown = 15 },
    GargoyleSkill = { type = "Attack", cooldown = 30 },
    PinataParty = { type = "Attack", cooldown = 30 },
    
    -- HEAL SKILLS (heals self or allies)
    HealPulse = { type = "Heal", cooldown = 30 },
    TetheredHeal = { type = "Heal", cooldown = 35 },
    HealReach = { type = "Heal", cooldown = 40 },
    HealReachPro = { type = "Heal", cooldown = 40 },
    CharmingHeartHeal = { type = "Heal", cooldown = 22 },
    
    -- SUPPORT SKILLS (buffs, defense, speed, cure - use near allies)
    Barrier = { type = "Support", cooldown = 50 },
    PinkSheepAttack = { type = "Support", cooldown = 25 },  -- 36% defense
    RockAttack = { type = "Support", cooldown = 25 },       -- 60% defense
    CatAttack = { type = "Support", cooldown = 25 },        -- speed boost
    CatAttackPro = { type = "Support", cooldown = 25 },     -- speed + lifesteal
    Cure = { type = "Support", cooldown = 15 },             -- remove debuffs
    CurePro = { type = "Support", cooldown = 22 },          -- AoE cure
    GMMoAttack = { type = "Support", cooldown = 25 },       -- speed boost
    GMRodAttack = { type = "Support", cooldown = 25 },      -- 60% defense
    NaughtyOrNice = { type = "Support", cooldown = 35 },    -- Christmas buff
    
    -- DROP SKILLS (spawn items/orbs that benefit party)
    GlyphAttack = { type = "Drop", cooldown = 25 },         -- random attack or health drop
    GlyphAttackPro = { type = "Drop", cooldown = 30 },      -- better attacks or health orb
    UltRing = { type = "Drop", cooldown = 50 },             -- charges ult for allies
    UltRingGalactic = { type = "Drop", cooldown = 50 },     -- galactic ult charger
    TurkeyFoodDrop = { type = "Drop", cooldown = 30 },      -- food drops with buffs
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Initialize getgenv flags
if _genv.PetAuraEnabled == nil then _genv.PetAuraEnabled = false end
if _genv.PetAuraSupportRange == nil then _genv.PetAuraSupportRange = 60 end
if _genv.PetAuraHealThreshold == nil then _genv.PetAuraHealThreshold = 0.5 end
if _genv.PetAuraTweenSpeed == nil then _genv.PetAuraTweenSpeed = 0.3 end

-- Anti-Detection Configuration
local AntiDetection = {
    timingVariance = 0.18,
    minDelay = 0.1,
    maxDelay = 0.3,
}

-- Session Statistics
local SessionStats = {
    startTime = os.clock(),
    skillsUsed = 0,
    healsPerformed = 0,
    attacksPerformed = 0,
    supportsPerformed = 0,
}

-- State
local lastSkillUse = 0
local isRunning = false
local mainLoopConnection = nil

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get equipped pet skill name
local function getEquippedPetSkill()
    if not ProfileLoaded or not Profile then return nil end
    if not PetsLoaded or not Pets then return nil end
    
    local success, result = pcall(function()
        local equips = Profile:GetPlayerEquips(player)
        if not equips or not equips.Pet then return nil end
        
        local petChildren = equips.Pet:GetChildren()
        if #petChildren ~= 1 then return nil end
        
        local petItem = petChildren[1]
        return Pets:GetPetSkillFromPetRef(petItem)
    end)
    
    if success then
        return result
    end
    return nil
end

--- Get skill type from database
local function getSkillType(skillName)
    if not skillName then return nil end
    local data = SkillData[skillName]
    if data then
        return data.type
    end
    -- Fallback: check for heal-related names
    if string.find(skillName:lower(), "heal") then
        return "Heal"
    end
    -- Default to Attack for unknown skills
    return "Attack"
end

--- Get skill cooldown
local function getSkillCooldown(skillName)
    if not skillName then return 15 end
    local data = SkillData[skillName]
    if data then
        return data.cooldown
    end
    return 15 -- Default cooldown
end

--- Check if skill is on cooldown (client-side tracking)
local function isSkillReady(skillName)
    local cooldown = getSkillCooldown(skillName)
    local timeSinceUse = os.clock() - lastSkillUse
    return timeSinceUse >= cooldown
end

--- Get all alive players in the game
local function getAlivePlayers()
    local alivePlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local humanoid = p.Character:FindFirstChild("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if humanoid and hrp and humanoid.Health > 0 then
                table.insert(alivePlayers, p)
            end
        end
    end
    return alivePlayers
end

--- Get player with lowest health percentage
local function getLowestHPPlayer()
    local alivePlayers = getAlivePlayers()
    local lowestPlayer = nil
    local lowestHPPercent = 1
    
    for _, p in ipairs(alivePlayers) do
        if p.Character then
            local healthPercent = 1
            
            -- Try using Health module
            if HealthLoaded and Health then
                pcall(function()
                    local currentHP = Health:GetHealth(p.Character)
                    local maxHP = Health:GetMaxHealth(p.Character)
                    if maxHP and maxHP > 0 then
                        healthPercent = currentHP / maxHP
                    end
                end)
            else
                -- Fallback to Humanoid
                local humanoid = p.Character:FindFirstChild("Humanoid")
                if humanoid then
                    healthPercent = humanoid.Health / humanoid.MaxHealth
                end
            end
            
            if healthPercent < lowestHPPercent then
                lowestHPPercent = healthPercent
                lowestPlayer = p
            end
        end
    end
    
    return lowestPlayer, lowestHPPercent
end

--- Check if any ally is within range
local function isAllyInRange(range)
    range = range or _genv.PetAuraSupportRange
    local myChar = player.Character
    if not myChar then return false end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    
    local alivePlayers = getAlivePlayers()
    for _, p in ipairs(alivePlayers) do
        if p.Character then
            local theirHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if theirHRP then
                local dist = (myHRP.Position - theirHRP.Position).Magnitude
                if dist <= range then
                    return true
                end
            end
        end
    end
    return false
end

--- Check if any mob is in range for attack skills
local function isMobInRange(range)
    range = range or 100
    local myChar = player.Character
    if not myChar then return false end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    
    local mobFolder = Workspace:FindFirstChild("Mobs")
    if not mobFolder then return false end
    
    for _, mob in ipairs(mobFolder:GetChildren()) do
        local collider = mob:FindFirstChild("Collider")
        local healthProps = mob:FindFirstChild("HealthProperties")
        
        if collider and healthProps then
            local health = healthProps:FindFirstChild("Health")
            if health and health.Value > 0 then
                local dist = (myHRP.Position - collider.Position).Magnitude
                if dist <= range then
                    return true
                end
            end
        end
    end
    return false
end

--- Tween pet/player towards target position
local function tweenToPosition(targetPos, duration)
    duration = duration or _genv.PetAuraTweenSpeed
    local myChar = player.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    
    -- Use pet position if available, otherwise skip tween
    if PetsLoaded and Pets then
        pcall(function()
            Pets:SetPetPosition(player, targetPos)
        end)
    end
    
    wait(duration)
end

--- Use pet skill safely
local function usePetSkill()
    if not PetSkillsLoaded or not PetSkills then
        return false
    end
    
    local success = pcall(function()
        PetSkills:UseSkill(player)
    end)
    
    if success then
        lastSkillUse = os.clock()
        SessionStats.skillsUsed = SessionStats.skillsUsed + 1
        return true
    end
    return false
end

-- ============================================================================
-- MAIN LOGIC
-- ============================================================================

--- Handle skill usage based on type
local function handleSkillUsage(skillName, skillType)
    if not isSkillReady(skillName) then
        return false
    end
    
    if skillType == "Attack" then
        -- Attack skills: use when mob in range
        if isMobInRange(100) then
            if usePetSkill() then
                SessionStats.attacksPerformed = SessionStats.attacksPerformed + 1
                return true
            end
        end
        
    elseif skillType == "Heal" then
        -- Heal skills: tween to lowest HP player and use
        local lowestPlayer, hpPercent = getLowestHPPlayer()
        
        -- Also check self HP
        local myChar = player.Character
        local selfHPPercent = 1
        if myChar then
            if HealthLoaded and Health then
                pcall(function()
                    local currentHP = Health:GetHealth(myChar)
                    local maxHP = Health:GetMaxHealth(myChar)
                    if maxHP and maxHP > 0 then
                        selfHPPercent = currentHP / maxHP
                    end
                end)
            else
                local humanoid = myChar:FindFirstChild("Humanoid")
                if humanoid then
                    selfHPPercent = humanoid.Health / humanoid.MaxHealth
                end
            end
        end
        
        -- Use heal if self or ally below threshold
        local threshold = _genv.PetAuraHealThreshold
        if selfHPPercent < threshold or (lowestPlayer and hpPercent < threshold) then
            -- Tween to lowest HP player if they exist and are lower than self
            if lowestPlayer and hpPercent < selfHPPercent then
                local theirHRP = lowestPlayer.Character:FindFirstChild("HumanoidRootPart")
                if theirHRP then
                    tweenToPosition(theirHRP.Position, _genv.PetAuraTweenSpeed)
                end
            end
            
            if usePetSkill() then
                SessionStats.healsPerformed = SessionStats.healsPerformed + 1
                return true
            end
        end
        
    elseif skillType == "Support" or skillType == "Drop" then
        -- Support/Drop skills: use when allies within range
        if isAllyInRange(_genv.PetAuraSupportRange) then
            if usePetSkill() then
                SessionStats.supportsPerformed = SessionStats.supportsPerformed + 1
                return true
            end
        else
            -- If no allies nearby, can still use for self-benefit
            -- Use less frequently when solo
            if math.random() < 0.3 then
                if usePetSkill() then
                    SessionStats.supportsPerformed = SessionStats.supportsPerformed + 1
                    return true
                end
            end
        end
    end
    
    return false
end

--- Main loop tick
local function mainLoopTick()
    if not _genv.PetAuraEnabled then return end
    
    -- Get equipped pet skill
    local skillName = getEquippedPetSkill()
    if not skillName then return end
    
    local skillType = getSkillType(skillName)
    handleSkillUsage(skillName, skillType)
end

--- Start the main loop
local function startMainLoop()
    if isRunning then return end
    isRunning = true
    
    spawn(function()
        while isRunning and _genv.PetAuraEnabled do
            mainLoopTick()
            
            -- Variable delay with anti-detection
            local delay = addVariance(0.5, AntiDetection.timingVariance)
            delay = math.max(AntiDetection.minDelay, math.min(delay, 1.0))
            wait(delay)
        end
        isRunning = false
    end)
end

--- Stop the main loop
local function stopMainLoop()
    isRunning = false
    _genv.PetAuraEnabled = false
end

-- ============================================================================
-- API
-- ============================================================================

local API = {}

--- Enable pet aura
function API.enable()
    _genv.PetAuraEnabled = true
    startMainLoop()
end

--- Disable pet aura
function API.disable()
    stopMainLoop()
end

--- Toggle pet aura
function API.toggle()
    if _genv.PetAuraEnabled then
        API.disable()
    else
        API.enable()
    end
end

--- Print current status
function API.status()
    local skillName = getEquippedPetSkill()
    local skillType = skillName and getSkillType(skillName) or "None"
    local isReady = skillName and isSkillReady(skillName) or false
    
    warn(string.format(
        "[PetAura] Enabled: %s | Skill: %s (%s) | Ready: %s | Support Range: %d | Heal Threshold: %.0f%%",
        tostring(_genv.PetAuraEnabled),
        skillName or "None",
        skillType,
        tostring(isReady),
        _genv.PetAuraSupportRange,
        _genv.PetAuraHealThreshold * 100
    ))
end

--- Get session statistics
function API.getStats()
    local elapsed = os.clock() - SessionStats.startTime
    return {
        elapsed = elapsed,
        skillsUsed = SessionStats.skillsUsed,
        healsPerformed = SessionStats.healsPerformed,
        attacksPerformed = SessionStats.attacksPerformed,
        supportsPerformed = SessionStats.supportsPerformed,
        skillsPerMinute = SessionStats.skillsUsed / (elapsed / 60),
    }
end

--- Set support skill range (studs)
function API.setSupportRange(studs)
    studs = tonumber(studs)
    if studs and studs > 0 then
        _genv.PetAuraSupportRange = studs
    end
end

--- Set heal HP threshold (0-1)
function API.setHealThreshold(pct)
    pct = tonumber(pct)
    if pct and pct > 0 and pct <= 1 then
        _genv.PetAuraHealThreshold = pct
    end
end

--- Set tween speed for heal skills
function API.setTweenSpeed(speed)
    speed = tonumber(speed)
    if speed and speed > 0 then
        _genv.PetAuraTweenSpeed = speed
    end
end

--- Check if pet aura is enabled
function API.isEnabled()
    return _genv.PetAuraEnabled
end

--- Get current pet skill info
function API.getSkillInfo()
    local skillName = getEquippedPetSkill()
    if not skillName then
        return nil
    end
    return {
        name = skillName,
        type = getSkillType(skillName),
        cooldown = getSkillCooldown(skillName),
        ready = isSkillReady(skillName),
    }
end

-- ============================================================================
-- GLOBAL EXPORTS
-- ============================================================================

-- Primary obfuscated export
_G.x8p3q = API

-- Internal alias for developer convenience
_G.PetAuraAPI = API

-- Return API for require()
return API
