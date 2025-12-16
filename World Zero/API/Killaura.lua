-- ============================================================================
-- Kill Aura - Automated Combat System (API Module)
-- https://pastebin.com/VfQixNh3
-- ============================================================================
-- This module exports the Kill Aura API for use with external GUI systems.
-- Use via: _G.killAura:start(), _G.killAura:stop(), _G.killAura:toggle()
-- ============================================================================

-- SERVICES
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Safely execute a function in a coroutine
local spawn = function(f)
    coroutine.wrap(f)()
end

--- Custom wait function that respects game heartbeat
--- @param sec number: Duration to wait in seconds
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

--- Safely require a module with error handling
--- @param mod ModuleScript: The module to require
--- @return any: The required module or nil if failed
local function safeRequire(mod)
    if not mod then
        return nil
    end
    local ok, res = pcall(require, mod)
    if ok then
        return res
    end
    return nil
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Global environment reference
local _genv = getgenv()
if _genv.killAuraEnabled == nil then
    _genv.killAuraEnabled = false
end

-- Combat Cooldowns
local PRIMARY_DEFAULT_COOLDOWN = 0.0   -- Primary attack cooldown (fast attacks)
local DEFAULT_SKILL_COOLDOWN = 4       -- Regular skill cooldown
local ULTIMATE_COOLDOWN = 35           -- Ultimate ability cooldown

-- Primary hold timing (simulate holding M1 instead of spamming)
local PRIMARY_HOLD_MIN_INTERVAL = 0.6  -- Minimum interval between held primary triggers
local PRIMARY_HOLD_MAX_INTERVAL = 20  -- Maximum interval between held primary triggers

-- Anti-Detection Timing (randomizes behavior to avoid detection)
local MIN_ATTACK_DELAY = 0.0           -- Minimum delay between attacks (seconds)
local MAX_ATTACK_DELAY = 0.4           -- Maximum delay between attacks (seconds)
local PAUSE_CHANCE = 0.05              -- 5% chance to pause for 1-3 seconds between attacks
local SKILL_SWITCH_INTERVAL = 30       -- Switch attack pattern every 30 seconds

-- ============================================================================
-- CLASS SKILLS CONFIGURATION
-- ============================================================================
-- Map attack skills by class key (internal name, not display name)
-- Format: ['ClassName'] = { 'Skill1', 'Skill2', ... }

local Classes = {
    ['Swordmaster'] = { --this class is not fully tested 
        'CrescentStrike1',
        'CrescentStrike2',
        'CrescentStrike3',
        'Leap',
        'SwordCyclone1',
    },
    ['Mage'] = { -- this class is is recomended as it was tested
        'Mage1',
        'ArcaneBlastAOE',
        'ArcaneBlast',
        'ArcaneWave1',
        'ArcaneWave2',
        'ArcaneWave3',
        'ArcaneWave4',
        'ArcaneWave5',
        'ArcaneWave6',
        'ArcaneWave7',
        'ArcaneWave8',
        'ArcaneWave9',
    },
    ['Defender'] = { -- this class is not fully tested
        'Defender1',
        'Defender2',
        'Defender3',
        'Defender4',
        'Defender5',
        'Groundbreaker',
        'Spin1',
        'Spin2',
        'Spin3',
        'Spin4',
        'Spin5',
    },
    ['DualWielder'] = { -- this class is not fully tested
        'DualWield1',
        'DualWield2',
        'DualWield3',
        'DualWield4',
        'DualWield5',
        'DualWield6',
        'DualWield7',
        'DualWield8',
        'DualWield9',
        'DualWield10',
        'DashStrike',
        'CrossSlash1',
        'CrossSlash2',
        'CrossSlash3',
        'CrossSlash4',
    },
    ['Guardian'] = { -- this class is not fully tested
        'Guardian1',
        'Guardian2',
        'Guardian3',
        'Guardian4',
        'SlashFury1',
        'SlashFury2',
        'SlashFury3',
        'SlashFury4',
        'SlashFury5',
        'SlashFury6',
        'SlashFury7',
        'SlashFury8',
        'SlashFury9',
        'SlashFury10',
        'SlashFury11',
        'SlashFury12',
        'SlashFury13',
        'RockSpikes1',
        'RockSpikes2',
        'RockSpikes3',
    },
    ['IcefireMage'] = { -- this class is recomended as it was tested
        'IcefireMage1',
        'IcySpikes1',
        'IcySpikes2',
        'IcySpikes3',
        'IcySpikes4',
        'IcefireMageFireballBlast',
        'IcefireMageFireball',
        'LightningStrike1',
        'LightningStrike2',
        'LightningStrike3',
        'LightningStrike4',
        'LightningStrike5',
        'IcefireMageUltimateFrost',
        'IcefireMageUltimateMeteor1',
    },
    ['Berserker'] = { -- this class is not fully tested
        'Berserker1',
        'Berserker2',
        'Berserker3',
        'Berserker4',
        'Berserker5',
        'Berserker6',
        'AggroSlam',
        'GigaSpin1',
        'GigaSpin2',
        'GigaSpin3',
        'GigaSpin4',
        'GigaSpin5',
        'GigaSpin6',
        'GigaSpin7',
        'GigaSpin8',
        'Fissure1',
        'Fissure2',
        'FissureErupt1',
        'FissureErupt2',
        'FissureErupt3',
        'FissureErupt4',
        'FissureErupt5',
    },
    ['Paladin'] = { -- this class is not fully tested
        'Paladin1',
        'Paladin2',
        'Paladin3',
        'Paladin4',
        'LightThrust1',
        'LightThrust2',
        'LightPaladin1',
        'LightPaladin2',
    },
    ['MageOfLight'] = { 'MageOfLight', 'MageOfLightBlast' }, -- this class is not fully tested
    ['Demon'] = {
        'Demon1',
        'Demon4',
        'Demon7',
        'Demon10',
        'Demon13',
        'Demon16',
        'Demon19',
        'Demon22',
        'Demon25',
        'DemonDPS1',
        'DemonDPS2',
        'DemonDPS3',
        'DemonDPS4',
        'DemonDPS5',
        'DemonDPS6',
        'DemonDPS7',
        'DemonDPS8',
        'DemonDPS9',
        'ScytheThrowDPS1',
        'ScytheThrowDPS2',
        'ScytheThrowDPS3',
        'DemonLifeStealDPS',
        'DemonSoulDPS1',
        'DemonSoulDPS2',
        'DemonSoulDPS3',
    },
    ['Dragoon'] = { -- this class is not fully tested
        'Dragoon1',
        'Dragoon2',
        'Dragoon3',
        'Dragoon4',
        'Dragoon5',
        'Dragoon6',
        'Dragoon7',
        'DragoonDash',
        'DragoonCross1',
        'DragoonCross2',
        'DragoonCross3',
        'DragoonCross4',
        'DragoonCross5',
        'DragoonCross6',
        'DragoonCross7',
        'DragoonCross8',
        'DragoonCross9',
        'DragoonCross10',
        'MultiStrike1',
        'MultiStrike2',
        'MultiStrike3',
        'MultiStrike4',
        'MultiStrike5',
        'MultiStrikeDragon1',
        'MultiStrikeDragon2',
        'MultiStrikeDragon3',
        'DragoonFall',
    },
    ['Archer'] = { -- This calss is recomended as it was tested
        'Archer',
        'PiercingArrow1',
        'PiercingArrow2',
        'PiercingArrow3',
        'PiercingArrow4',
        'PiercingArrow5',
        'PiercingArrow6',
        'PiercingArrow7',
        'PiercingArrow8',
        'PiercingArrow9',
        'PiercingArrow10',
        'SpiritBomb',
        'MortarStrike1',
        'MortarStrike2',
        'MortarStrike3',
        'MortarStrike4',
        'MortarStrike5',
        'MortarStrike6',
        'MortarStrike7',
        'HeavenlySword1',
        'HeavenlySword2',
        'HeavenlySword3',
        'HeavenlySword4',
        'HeavenlySword5',
        'HeavenlySword6',
    },
    ['Stormcaller'] = { -- this class is not fully tested
        'StormcallerThunderGod1',
        'StormcallerThunderGod2',
        'StormcallerThunderGod3',
        'StormcallerThunderGod4',
        'StormcallerThunderGod5',
        'StormcallerThunderGod6',
        'StormcallerThunderGod7',
        'UltimateDischarge',
        'Stormcaller1',
        'Stormcaller2',
        'Stormcaller3',
        'Stormcaller4',
        'ChainLightning1',
        'ChainLightning2',
        'StormSurgeInit',
        'StormSurge1',
        'StormSurge2',
        'ShockDashBall',
        'ShockDash1',
        'ShockDash2',
        'ShockDash3',
        'StormcallerUltBlast',
    },
    ['Summoner'] = { -- this class is not fully tested
        'Summoner1',
        'Summoner2',
        'Summoner3',
        'Summoner4',
        'SoulHarvest1',
    },
    ['Necromancer'] = { -- this class is not fully tested
        'NecroDPS1',
        'NecroDPS2',
        'NecroDPS3',
        'NecroDPS4',
        'NecroDPS5',
        'NecroDPS6',
        'NecroDPS7',
        'NecroDPS8',
        'NecroDPS9',
        'TombstoneRise1',
        'TombstoneRise2',
        'TombstoneRise3',
        'TombstoneRise4',
        'TombstoneRise5',
        'SpiritExplosion0',
        'SpiritExplosion1',
        'SpiritExplosion2',
        'SpiritExplosion3',
        'SpiritExplosion4',
        'SpiritCavern1',
        'SpiritCavern2',
        'SpiritCavern3',
        'SpiritCavern4',
        'SpiritCavern5',
        'SpiritCavern6',
        'UltScytheDrop',
    },
    ['Hunter'] = { -- this class is not fully tested
        'HunterExplosiveArrow1',
        'HunterExplosiveArrow2',
        'HunterExplosiveArrow3',
        'HunterExplosiveArrow4',
        'DivineArrow1',
        'DivineArrow2',
        'DivineArrow3',
        'DivineArrow4',
        'DivineArrow5',
        'DivineArrow6',
        'DivineArrow7',
        'DivineArrow8',
        'DivineArrow9',
        'DivineArrow10',
    },
}

-- Custom cooldowns per class (add skill-specific cooldowns here)
-- Example: ["IcefireMage"] = { ["IcefireMage1"] = 0.5, ["IcySpikes1"] = 3 }
-- Leave empty to use ALL skills with default cooldowns
local CustomCooldowns = {
    -- Cooldowns derived from ManualAURAv1 animation-based timings
    Mage = {
        ArcaneBlast = 5,
        ArcaneBlastAOE = 5,
        ArcaneWave1 = 8,
        ArcaneWave2 = 8,
        ArcaneWave3 = 8,
        ArcaneWave4 = 8,
        ArcaneWave5 = 8,
        ArcaneWave6 = 8,
        ArcaneWave7 = 8,
        ArcaneWave8 = 8,
        ArcaneWave9 = 8,
    },
    IcefireMage = {
        IcySpikes1 = 6,
        IcySpikes2 = 6,
        IcySpikes3 = 6,
        IcySpikes4 = 6,
        IcefireMageFireball = 7,
        IcefireMageFireballBlast = 7,
        LightningStrike1 = 10,
        LightningStrike2 = 10,
        LightningStrike3 = 10,
        LightningStrike4 = 10,
        LightningStrike5 = 10,
    },
    Archer = {
        SpiritBomb = 10,
        MortarStrike1 = 12,
        MortarStrike2 = 12,
        MortarStrike3 = 12,
        MortarStrike4 = 12,
        MortarStrike5 = 12,
        MortarStrike6 = 12,
        MortarStrike7 = 12,
        PiercingArrow1 = 5,
        PiercingArrow2 = 5,
        PiercingArrow3 = 5,
        PiercingArrow4 = 5,
        PiercingArrow5 = 5,
        PiercingArrow6 = 5,
        PiercingArrow7 = 5,
        PiercingArrow8 = 5,
        PiercingArrow9 = 5,
        PiercingArrow10 = 5,
    },
    Swordmaster = {
        -- Animation config uses CrescentStrike (5s) and LeapSlash (8s)
        -- Map to available remotes in Killaura
        SwordCyclone1 = 5,
        Leap = 8,
    },
    Defender = {
        Groundbreaker = 5,
        Spin1 = 8,
        Spin2 = 8,
        Spin3 = 8,
        Spin4 = 8,
        Spin5 = 8,
    },
    Guardian = {
        RockSpikes1 = 6,
        RockSpikes2 = 6,
        RockSpikes3 = 6,
        SlashFury1 = 8,
        SlashFury2 = 8,
        SlashFury3 = 8,
        SlashFury4 = 8,
        SlashFury5 = 8,
        SlashFury6 = 8,
        SlashFury7 = 8,
        SlashFury8 = 8,
        SlashFury9 = 8,
        SlashFury10 = 8,
        SlashFury11 = 8,
        SlashFury12 = 8,
        SlashFury13 = 8,
    },
    Berserker = {
        AggroSlam = 5,
        GigaSpin1 = 7,
        GigaSpin2 = 7,
        GigaSpin3 = 7,
        GigaSpin4 = 7,
        GigaSpin5 = 7,
        GigaSpin6 = 7,
        GigaSpin7 = 7,
        GigaSpin8 = 7,
        Fissure1 = 10,
        Fissure2 = 10,
        FissureErupt1 = 10,
        FissureErupt2 = 10,
        FissureErupt3 = 10,
        FissureErupt4 = 10,
        FissureErupt5 = 10,
    },
    Paladin = {
        LightThrust1 = 11,
        LightThrust2 = 11,
    },
    Demon = {
        ScytheThrowDPS1 = 5,
        ScytheThrowDPS2 = 5,
        ScytheThrowDPS3 = 5,
        DemonLifeStealDPS = 8,
        DemonSoulDPS1 = 8,
        DemonSoulDPS2 = 8,
        DemonSoulDPS3 = 8,
    },
    Dragoon = {
        MultiStrike1 = 6,
        MultiStrike2 = 6,
        MultiStrike3 = 6,
        MultiStrike4 = 6,
        MultiStrike5 = 6,
        MultiStrikeDragon1 = 6,
        MultiStrikeDragon2 = 6,
        MultiStrikeDragon3 = 6,
        DragoonFall = 8,
    },
    Necromancer = {
        TombstoneRise1 = 5,
        TombstoneRise2 = 5,
        TombstoneRise3 = 5,
        TombstoneRise4 = 5,
        TombstoneRise5 = 5,
        SpiritExplosion0 = 3,
        SpiritExplosion1 = 3,
        SpiritExplosion2 = 3,
        SpiritExplosion3 = 3,
        SpiritExplosion4 = 3,
        SpiritCavern1 = 10,
        SpiritCavern2 = 10,
        SpiritCavern3 = 10,
        SpiritCavern4 = 10,
        SpiritCavern5 = 10,
        SpiritCavern6 = 10,
    },
    Stormcaller = {
        ChainLightning1 = 7,
        ChainLightning2 = 7,
        StormSurgeInit = 10,
        StormSurge1 = 10,
        StormSurge2 = 10,
        ShockDashBall = 10,
    },
    Summoner = {
        Summoner1 = 5,
        Summoner2 = 5,
        Summoner3 = 5,
        Summoner4 = 5,
        SoulHarvest1 = 10,
    },
    DualWielder = {
        DashStrike = 6,
        CrossSlash1 = 8,
        CrossSlash2 = 8,
        CrossSlash3 = 8,
        CrossSlash4 = 8,
    },
    Hunter = {
        -- Manual lists Blazing Shot/HuntersMark ~8s; map where possible
        HunterExplosiveArrow1 = 8,
        HunterExplosiveArrow2 = 8,
        HunterExplosiveArrow3 = 8,
        HunterExplosiveArrow4 = 8,
        DivineArrow1 = 8,
        DivineArrow2 = 8,
        DivineArrow3 = 8,
        DivineArrow4 = 8,
        DivineArrow5 = 8,
        DivineArrow6 = 8,
        DivineArrow7 = 8,
        DivineArrow8 = 8,
        DivineArrow9 = 8,
        DivineArrow10 = 8,
    },
}

-- ============================================================================
-- MODULE MANAGEMENT
-- ============================================================================

local Combat = nil
local Skills = nil
local AttackEvent = nil

--- Load the Combat module from ReplicatedStorage
local function loadCombat()
    if Combat then
        return Combat
    end
    pcall(function()
        Combat = safeRequire(
            ReplicatedStorage:FindFirstChild('Shared')
                    and ReplicatedStorage.Shared:FindFirstChild('Combat')
                or nil
        )
        if not AttackEvent then
            local combatScript = ReplicatedStorage.Shared:FindFirstChild('Combat')
            if combatScript and combatScript:FindFirstChild('Attack') then
                AttackEvent = combatScript.Attack
            end
        end
    end)
    return Combat
end

--- Load the Skills module from ReplicatedStorage
local function loadSkills()
    if Skills then
        return Skills
    end
    pcall(function()
        Skills = safeRequire(
            ReplicatedStorage:FindFirstChild('Shared')
                    and ReplicatedStorage.Shared:FindFirstChild('Skills')
                or nil
        )
    end)
    return Skills
end

-- ============================================================================
-- COOLDOWN MANAGEMENT
-- ============================================================================

--- Get the cooldown duration for a specific skill
--- @param className string: The player's current class
--- @param skillName string: The skill to check
--- @return number|nil: The cooldown in seconds, or nil if skill should be skipped
local function getSkillCooldown(className, skillName)
    -- Check custom overrides first
    if CustomCooldowns[className] then
        -- If class has custom cooldowns, ONLY fire skills in that list
        if CustomCooldowns[className][skillName] then
            return CustomCooldowns[className][skillName]
        else
            -- Skill not in custom list, return nil to skip it
            return nil
        end
    end

    -- No custom cooldowns for this class, use defaults
    -- Check if it's a primary attack (usually ends with single digit like "Skill1")
    if string.match(skillName, '1$') and not string.match(skillName, '%d%d') then
        -- Primary handled by hold logic; exclude from rotation
        return nil
    end
    return DEFAULT_SKILL_COOLDOWN
end

-- ============================================================================
-- API INITIALIZATION (Must be before combatLoop)
-- ============================================================================

local API = {}
API.running = false

-- ============================================================================
-- COMBAT LOGIC
-- ============================================================================

--- Main combat loop - continuously attacks the closest mob
local function combatLoop()
    local plr = Players.LocalPlayer
    if not plr then
        return
    end

    -- Load Skills module for cooldown tracking
    loadSkills()

    -- Track skill cooldowns
    local skillCooldowns = {}         -- {skillName = lastUsedTime}
    local ultimateCooldown = 0        -- Last time ultimate was used
    local lastClassName = nil         -- Previous class (detect class changes)
    local lastSkillType = nil         -- Track last skill type for pause timing
    local lastSkillSwitchTime = time()
    local lastPrimaryFire = 0         -- Last time primary was fired (held simulation)
    local nextPrimaryInterval = 0.7   -- Next interval for primary fire

    while API.running do
        pcall(function()
            -- Get player's current class
            local className = nil

            pcall(function()
                local playerGui = plr:FindFirstChild('PlayerGui')
                if playerGui then
                    local profile = playerGui:FindFirstChild('Profile')
                    if profile then
                        local classVal = profile:FindFirstChild('Class')
                        if classVal and classVal.Value then
                            className = classVal.Value
                        end
                    end
                end
            end)

            if not className or not Classes[className] then
                return
            end

            -- Reset cooldowns if class changed
            if lastClassName ~= className then
                skillCooldowns = {}
                lastClassName = className
            end

            -- Get character and head - check both exist
            local character = plr.Character
            if not character then
                wait(0.5)
                return
            end

            local head = character:FindFirstChild('Head')
            if not head then
                wait(0.5)
                return
            end

            -- Find closest mob
            local mobs = {}
            local workspace = game:GetService('Workspace')
            local mobFolder = workspace:FindFirstChild('Mobs')
            if not mobFolder then
                return
            end

            -- Iterate through all mobs and calculate distances
            for _, mob in ipairs(mobFolder:GetChildren()) do
                pcall(function()
                    -- Validate mob exists and has parent
                    if not mob or not mob.Parent then
                        return
                    end
                    
                    local collider = mob:FindFirstChild('Collider')
                    if not collider then
                        return
                    end

                    local health = mob:FindFirstChild('HealthProperties')
                    if not health or not health:FindFirstChild('Health') then
                        return
                    end

                    -- Extra validation before accessing Value
                    local healthVal = health.Health
                    if not healthVal or not healthVal.Value then
                        return
                    end

                    if healthVal.Value > 0 then
                        local dist = (collider.Position - head.Position).magnitude
                        if dist < 10000 then
                            table.insert(mobs, { mob = mob, distance = dist })
                        end
                    end
                end)
            end

            if #mobs == 0 then
                wait(3) -- Wait for mobs to spawn
                return
            end

            -- Sort by distance to find closest mob
            table.sort(mobs, function(a, b)
                return a.distance < b.distance
            end)
            local closestMob = mobs[1].mob
            local collider = closestMob:FindFirstChild('Collider')
            if not collider then
                return
            end

            local mobPos = collider.Position
            local currentTime = time()

            -- Determine primary skill name for this class (first skill ending in single '1')
            local primarySkillName = nil
            for _, s in ipairs(Classes[className]) do
                if string.match(s, '1$') and not string.match(s, '%d%d') then
                    primarySkillName = s
                    break
                end
            end

            -- Simulate holding primary attack (not spamming)
            if primarySkillName and Combat then
                if currentTime - lastPrimaryFire >= nextPrimaryInterval then
                    pcall(function()
                        -- Validate mob still exists
                        if not closestMob or not closestMob.Parent then return end
                        local currentCollider = closestMob:FindFirstChild('Collider')
                        if not currentCollider then return end
                        
                        local currentHead = character:FindFirstChild('Head')
                        if not currentHead then return end
                        local attackDir = (currentCollider.Position - currentHead.Position).Unit
                        Combat:AttackWithSkill(67, primarySkillName, currentCollider.Position, attackDir)
                        lastPrimaryFire = currentTime
                        nextPrimaryInterval = PRIMARY_HOLD_MIN_INTERVAL + math.random() * (PRIMARY_HOLD_MAX_INTERVAL - PRIMARY_HOLD_MIN_INTERVAL)
                    end)
                end
            end

            -- Check if Ultimate is ready
            if currentTime - ultimateCooldown >= ULTIMATE_COOLDOWN then
                if Combat then
                    pcall(function()
                        -- Validate mob still exists
                        if not closestMob or not closestMob.Parent then return end
                        local currentCollider = closestMob:FindFirstChild('Collider')
                        if not currentCollider then return end
                        
                        Combat:AttackWithSkill(
                            67,
                            'Ultimate',
                            currentCollider.Position,
                            Vector3.new(0, 0, 0)
                        )
                        ultimateCooldown = currentTime
                        skillCooldowns = {} -- Reset other cooldowns after ult
                    end)
                end
                return -- Wait a bit before next attack
            end

            -- Find next available skill to use
            local availableSkills = {}
            for _, skillName in ipairs(Classes[className]) do
                local skillCD = getSkillCooldown(className, skillName)

                -- Skip skills with nil cooldown (not in CustomCooldowns)
                if skillCD then
                    local lastUsed = skillCooldowns[skillName] or 0

                    -- Check if skill cooldown has elapsed
                    if currentTime - lastUsed >= skillCD then
                        table.insert(
                            availableSkills,
                            { name = skillName, cd = skillCD }
                        )
                    end
                end
            end

            if #availableSkills > 0 then
                -- Pick random available skill
                local skill = availableSkills[math.random(1, #availableSkills)]

                -- Determine skill type (primary vs secondary)
                local skillType = nil
                if string.match(skill.name, '1$') and not string.match(skill.name, '%d%d') then
                    skillType = 'primary'
                else
                    skillType = 'default'
                end

                if Combat then
                    pcall(function()
                        -- Validate mob still exists
                        if not closestMob or not closestMob.Parent then return end
                        local currentCollider = closestMob:FindFirstChild('Collider')
                        if not currentCollider then return end
                        
                        -- Re-check head exists before using it
                        local currentHead = character:FindFirstChild('Head')
                        if not currentHead then
                            return
                        end
                        -- Calculate direction vector towards mob for skills that need it
                        local attackDir = (currentCollider.Position - currentHead.Position).Unit
                        Combat:AttackWithSkill(
                            67,
                            skill.name,
                            currentCollider.Position,
                            attackDir
                        )
                        skillCooldowns[skill.name] = currentTime
                        lastSkillType = skillType
                    end)
                end

                -- Randomized delay between attacks for anti-detection
                local randomDelay = MIN_ATTACK_DELAY + math.random() * (MAX_ATTACK_DELAY - MIN_ATTACK_DELAY)
                wait(randomDelay)

                -- Occasional random pause to break up patterns
                if math.random() < PAUSE_CHANCE then
                    local pauseDuration = 1 + math.random() * 2  -- 1-3 second pause
                    wait(pauseDuration)
                end

                -- Switch attack strategy periodically
                if currentTime - lastSkillSwitchTime > SKILL_SWITCH_INTERVAL then
                    lastSkillSwitchTime = currentTime
                    wait(0.5 + math.random())  -- Extra pause when switching strategy
                end
            else
                -- All skills on cooldown, wait a bit
                wait(0.5 + math.random() * 0.5)
            end
        end)
    end

    API.running = false
end

-- ============================================================================
-- API FUNCTIONS
-- ============================================================================

--- Start the kill aura
function API.start()
    if API.running then
        return
    end

    -- Try to load Combat - if it fails, script isn't ready
    if not loadCombat() then
        return
    end

    API.running = true
    spawn(combatLoop)
    return true
end

--- Stop the kill aura
function API.stop()
    API.running = false
    _genv.killAuraEnabled = false
    return true
end

--- Toggle the kill aura on/off
function API.toggle()
    if API.running then
        API.stop()
    else
        API.start()
    end
end

-- Make API available globally for console testing
_G.x9m1n = API
getgenv().x9m1n = API  -- Also set in global environment

-- ============================================================================
-- EXPORT
-- ============================================================================

return API
