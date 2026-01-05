-- ============================================================================
-- Kill Aura - Automated Combat System (API Module)
-- ============================================================================
-- Intelligent automated combat with class-specific skill rotation
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/killaura.lua
--
-- API USAGE:
-- • _G.x9m1n:start()     - Enable automated combat
-- • _G.x9m1n:stop()      - Disable automated combat
-- • _G.x9m1n:toggle()    - Toggle combat state
-- • _G.x9m1n:setClass()  - Force a specific class rotation
--
-- FEATURES:
-- • Class-specific skill rotations (all classes supported)
-- • Accurate cooldowns from decompiled game data
-- • Randomized timing for anti-detection
-- • Ultimate ability management
-- • Melee-optimized attack chains with combo support
-- • Human-like behavior patterns (variable delays, pauses)
--
-- PERFORMANCE:
-- • Optimized skill cooldown tracking
-- • Efficient target validation
-- • Minimal CPU overhead
--
-- SECURITY:
-- • Protected remote calls
-- • Randomized attack patterns with variance
-- • Safe service access with pcall wrapping
-- • Variable timing to avoid pattern detection
-- • Simulated input delays
--
-- ANTI-CHEAT COMPLIANCE:
-- See Tests/anticheat.lua for full documentation of detection systems.
-- This module uses Combat.AttackTargets(nil, mobTable, posTable, skillName) which is
-- the game's native skill execution method used by all working scripts.
--
-- Key protections implemented:
-- • Uses game's native Combat.AttackTargets (same as working autofarm scripts)
-- • Timing variance (18%) prevents pattern detection
-- • Randomized pauses and combo breaks simulate human behavior
-- • Respects game cooldowns from decompiled Shared_Skills.lua
-- • NEVER calls AttackTarget remote (honeypot trap)
-- ============================================================================

-- SERVICES
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

-- Combat module (required for AttackWithSkill)
local Combat = nil
local CombatLoaded = false
pcall(function()
    Combat = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('Combat', 5))
    CombatLoaded = true
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Safely execute a function in a coroutine
local spawn = function(f)
    coroutine.wrap(f)()
end

--- Custom wait function that respects game heartbeat
--- Uses task.wait for efficiency when available, with fallback to Heartbeat
--- @param sec number: Duration to wait in seconds
local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        -- Use task.wait if available (more efficient, doesn't block)
        if task and task.wait then
            task.wait(sec)
        else
            -- Fallback: use single Heartbeat wait for short durations
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
--- @param value number: Base value
--- @param variance number: Variance percentage (0-1), default 0.15
--- @return number: Value with random variance applied
local function addVariance(value, variance)
    variance = variance or 0.15
    local delta = value * variance
    return value + (math.random() * 2 - 1) * delta
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

-- Energy Configuration for Ultimate Abilities (defined early for use in utility functions)
local MAX_ENERGY = 350                 -- Maximum energy capacity
local ULTIMATE_ENERGY_THRESHOLD = 0.98 -- Require 98% energy to use ultimate - feels more natural

--- Get the player's current energy value
--- Energy is required for Ultimate abilities (max 350)
--- @return number: Current energy value (0-350) or 0 if unavailable
local function getEnergy()
    local plr = Players.LocalPlayer
    if not plr or not plr.Character then
        return 0
    end
    
    local energyProps = plr.Character:FindFirstChild('EnergyProperties')
    if not energyProps then
        return 0
    end
    
    local energyVal = energyProps:FindFirstChild('Energy')
    if not energyVal then
        return 0
    end
    
    return energyVal.Value or 0
end

--- Get the player's current energy ratio (0-1)
--- @return number: Energy ratio (current/max) or 0 if unavailable
local function getEnergyRatio()
    return getEnergy() / MAX_ENERGY
end

--- Check if player has enough energy to use Ultimate ability
--- @return boolean: True if energy is at or above threshold
local function hasEnergyForUltimate()
    return getEnergyRatio() >= ULTIMATE_ENERGY_THRESHOLD
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Global environment reference
local _genv = getgenv()
if _genv.killAuraEnabled == nil then
    _genv.killAuraEnabled = false
end

-- Combat Cooldowns (base values from decompiled data)
local PRIMARY_DEFAULT_COOLDOWN = 0.32   -- Primary attack cooldown - tuned for melee
local DEFAULT_SKILL_COOLDOWN = 4        -- Regular skill cooldown
local ULTIMATE_COOLDOWN = 35            -- Ultimate ability cooldown

-- Primary hold timing (simulate holding M1 instead of spamming)
local PRIMARY_HOLD_MIN_INTERVAL = 0.16   -- Minimum interval between held primary triggers
local PRIMARY_HOLD_MAX_INTERVAL = 0.26   -- Maximum interval between held primary triggers

-- Anti-Detection Configuration
local AntiDetection = {
    -- Timing variance (adds randomness to all delays)
    timingVariance = 0.18,              -- 18% variance on all timings
    
    -- Attack delays
    minAttackDelay = 0.02,              -- Minimum delay between attacks
    maxAttackDelay = 0.12,              -- Maximum delay between attacks
    
    -- Human-like behavior
    pauseChance = 0.02,                 -- 2% chance to pause
    pauseMinDuration = 0.6,             -- Minimum pause duration
    pauseMaxDuration = 1.8,             -- Maximum pause duration
    
    -- Combo behavior
    comboBreakChance = 0.06,            -- 6% chance to break combo early
    skillSwitchInterval = 22,           -- Switch attack pattern every ~22 seconds
    
    -- Burst behavior (simulates player excitement)
    burstChance = 0.04,                 -- 4% chance to enter "burst mode"
    burstDuration = 1.5,                -- Burst mode lasts ~1.5 seconds
    burstSpeedMultiplier = 0.75,        -- During burst, delays are 75% of normal
}

-- Melee Reach Configuration
-- ⚠️ DISABLED BY DEFAULT - Anti-cheat monitors BodyVelocity for impossible speeds
-- The game's velocity monitoring flags sudden/unnatural movement velocities.
-- Using this feature will result in detection. Keep disabled for safety.
local MeleeReach = {
    enabled = false,                    -- DISABLED: BodyVelocity monitored by anti-cheat
    maxReach = 10,                      -- Max distance (must match game melee ~10 studs)
    idealDistance = 5,                  -- Ideal distance to stop at (inside melee range)
    moveSpeed = 24,                     -- REDUCED: Normal walkspeed is 16-20 studs/sec
    smoothing = 0.3,                    -- Smoothing factor (0-1, lower = smoother)
    onlyWhenAttacking = true,           -- Only move when actually attacking
    useBodyVelocity = true,             -- Use BodyVelocity (monitored by anti-cheat!)
}

-- Melee class configuration (optimized attack speeds based on decompiled data)
-- primaryCD: Primary attack cooldown in seconds
-- comboWindow: Time window to continue combo before reset
-- maxCombo: Maximum combo count before reset
local MeleeClassConfig = {
    Swordmaster = { primaryCD = 0.22, comboWindow = 0.75, maxCombo = 6 },
    Defender = { primaryCD = 0.35, comboWindow = 1.0, maxCombo = 5 },
    DualWielder = { primaryCD = 0.14, comboWindow = 0.5, maxCombo = 10, hasSpeedRamp = true },
    Guardian = { primaryCD = 0.28, comboWindow = 0.8, maxCombo = 4 },
    Paladin = { primaryCD = 0.26, comboWindow = 0.7, maxCombo = 4, hasLightMode = true },
    Berserker = { primaryCD = 0.30, comboWindow = 0.9, maxCombo = 6, hasRageMode = true },
    Dragoon = { primaryCD = 0.23, comboWindow = 0.6, maxCombo = 7, hasChainSystem = true },
    Demon = { primaryCD = 0.18, comboWindow = 0.5, maxCombo = 25, hasDemonMode = true },
    Necromancer = { primaryCD = 0.20, comboWindow = 0.6, maxCombo = 9 },
    Assassin = { primaryCD = 0.16, comboWindow = 0.4, maxCombo = 8, hasShadowMode = true },
    Warlord = { primaryCD = 0.28, comboWindow = 0.8, maxCombo = 5 },
    Leviathan = { primaryCD = 0.22, comboWindow = 0.6, maxCombo = 6, hasBubbleSystem = true },
}

-- Primary hold overrides (for ranged/mage classes with slower attack patterns)
local PrimaryHoldOverrides = {
    Mage = { min = 0.75, max = 0.90 },
    IcefireMage = { min = 0.75, max = 0.88 },
    MageOfLight = { min = 0.80, max = 0.92 },
    MageOfShadows = { min = 0.70, max = 0.85 },
    Stormcaller = { min = 0.55, max = 0.68 },
    Summoner = { min = 0.60, max = 0.72 },
    Archer = { min = 0.35, max = 0.42 },
    Hunter = { min = 0.34, max = 0.40 },
}

-- Primary skill aliases (FunctionName from Skills module)
-- These map to the actual skill function names in the game
local PrimaryAlias = {
    Archer = 'Archer',
    Hunter = 'Attack',
}

-- ============================================================================
-- CLASS SKILLS CONFIGURATION
-- ============================================================================
-- Skills are mapped using FunctionNames from the game's Skills module
-- Primary attacks use "Attack" function, skills use their FunctionName
-- Skill names here are the internal IDs used by _G.UseSkill
--
-- FORMAT: ClassName = { skills with cooldowns managed }
-- Primary attacks are handled separately via MeleeClassConfig

local Classes = {
    -- ========================================================================
    -- MELEE CLASSES (Optimized for combo attacks)
    -- ========================================================================
    
    ['Swordmaster'] = {
        -- Primary: Sword Slash (Attack) - 6 hit combo
        -- FunctionName: CrescentStrike, LeapSlash, Ultimate (SwordCyclone)
        'Swordmaster1', 'Swordmaster2', 'Swordmaster3', 'Swordmaster4', 'Swordmaster5', 'Swordmaster6',
        'CrescentStrike1', 'CrescentStrike2', 'CrescentStrike3',
        'Leap', -- LeapSlash
    },
    
    ['Defender'] = {
        -- Primary: Axe Swing (Attack) - 5 hit combo
        -- FunctionName: Groundbreaker, Spin, Ultimate
        'Defender1', 'Defender2', 'Defender3', 'Defender4', 'Defender5',
        'Groundbreaker',
        'Spin1', 'Spin2', 'Spin3', 'Spin4', 'Spin5',
    },
    
    ['DualWielder'] = {
        -- Primary: Sword Flurry (Attack) - 10 hit combo with speed ramp
        -- FunctionName: AttackBuff (Combat Rhythm), LeapStrikes (Dash Strike), CrossSlash
        'DualWield1', 'DualWield2', 'DualWield3', 'DualWield4', 'DualWield5',
        'DualWield6', 'DualWield7', 'DualWield8', 'DualWield9', 'DualWield10',
        'AttackBuff', -- Combat Rhythm - attack speed boost
        'DashStrike',
        'CrossSlash1', 'CrossSlash2', 'CrossSlash3', 'CrossSlash4',
    },
    
    ['Guardian'] = {
        -- Primary: Great Slash (Attack) - 4 hit combo
        -- FunctionName: AggroDraw, RockSpikes, SlashFury, Ultimate (SwordPrison)
        'Guardian1', 'Guardian2', 'Guardian3', 'Guardian4',
        'AggroDraw', -- Skill1: Aggro Draw with 70% damage resistance
        'RockSpikes1', 'RockSpikes2', 'RockSpikes3',
        'SlashFury1', 'SlashFury2', 'SlashFury3', 'SlashFury4',
        'SlashFury5', 'SlashFury6', 'SlashFury7', 'SlashFury8',
        'SlashFury9', 'SlashFury10', 'SlashFury11', 'SlashFury12', 'SlashFury13',
    },
    
    ['Paladin'] = {
        -- Primary: Noble Slash (Attack) - 4 hit combo, enhanced with Paladin Light
        -- FunctionName: Block (Gilded Block), GuildedLight (Divine Retribution), LightThrust, Ultimate
        'Paladin1', 'Paladin2', 'Paladin3', 'Paladin4',
        'Block', -- Gilded Block - 80% damage negation
        'GuildedLight', -- Divine Retribution - damage + heal + defense
        'LightThrust1', 'LightThrust2',
        'LightPaladin1', 'LightPaladin2', -- Light mode attacks
    },
    
    ['Berserker'] = {
        -- Primary: Heavy Slice (Attack) - 6 hit combo
        -- FunctionName: AggroSlam, GigaSpin, Fissure, Ultimate (Rage)
        'Berserker1', 'Berserker2', 'Berserker3', 'Berserker4', 'Berserker5', 'Berserker6',
        'AggroSlam', -- Leap slam with aggro
        'GigaSpin1', 'GigaSpin2', 'GigaSpin3', 'GigaSpin4',
        'GigaSpin5', 'GigaSpin6', 'GigaSpin7', 'GigaSpin8',
        'Fissure1', 'Fissure2',
        'FissureErupt1', 'FissureErupt2', 'FissureErupt3', 'FissureErupt4', 'FissureErupt5', -- Rage mode
    },
    
    ['Dragoon'] = {
        -- Primary: Dragon's Claw (Attack) - 7 hit combo with mark system
        -- FunctionName: InfinityStrike, MultiStrike (Dragon Wrath), DragonSlam, Ultimate (Dragon Dance)
        'Dragoon1', 'Dragoon2', 'Dragoon3', 'Dragoon4', 'Dragoon5', 'Dragoon6', 'Dragoon7',
        'InfinityStrike', -- Dash attack, starts Dragon Chain
        'MultiStrike1', 'MultiStrike2', 'MultiStrike3', 'MultiStrike4', 'MultiStrike5',
        'MultiStrikeDragon1', 'MultiStrikeDragon2', 'MultiStrikeDragon3', -- Dragon mode
        'DragonSlam', -- Completes Dragon Chain
        'DragoonFall',
    },
    
    ['Demon'] = {
        -- Primary: Monster Slash (Attack) - 25 hit combo!
        -- FunctionName: BloodBinding (Dark Binding), Throw (Scythe Throw), LifeSteal, Ultimate
        'Demon1', 'Demon4', 'Demon7', 'Demon10', 'Demon13',
        'Demon16', 'Demon19', 'Demon22', 'Demon25',
        'DemonDPS1', 'DemonDPS2', 'DemonDPS3', 'DemonDPS4', 'DemonDPS5',
        'DemonDPS6', 'DemonDPS7', 'DemonDPS8', 'DemonDPS9',
        'BloodBinding', -- Dark Binding - 25% damage boost at 30% health cost
        'ScytheThrowDPS1', 'ScytheThrowDPS2', 'ScytheThrowDPS3',
        'LifeSteal', -- Life Steal - drains health from up to 3 enemies
        'DemonSoulDPS1', 'DemonSoulDPS2', 'DemonSoulDPS3',
    },
    
    ['Necromancer'] = {
        -- Primary: Deadly Gash (Attack) - 9 hit combo
        -- FunctionName: Tombstones, SpiritExplosion, SpiritCavern, Ultimate (Undead Army)
        'NecroDPS1', 'NecroDPS2', 'NecroDPS3', 'NecroDPS4', 'NecroDPS5',
        'NecroDPS6', 'NecroDPS7', 'NecroDPS8', 'NecroDPS9',
        'TombstoneRise1', 'TombstoneRise2', 'TombstoneRise3', 'TombstoneRise4', 'TombstoneRise5',
        'SpiritExplosion0', 'SpiritExplosion1', 'SpiritExplosion2', 'SpiritExplosion3', 'SpiritExplosion4',
        'SpiritCavern1', 'SpiritCavern2', 'SpiritCavern3', 'SpiritCavern4', 'SpiritCavern5', 'SpiritCavern6',
    },
    
    ['Assassin'] = {
        -- Primary: Shadow Slash (Attack) - 8 hit combo, crits in Shadow Mode
        -- FunctionName: StealthWalk (Shadow Cloak), ShadowLeap, ShadowSlash (Shadow Strike), Ultimate
        'Assassin1', 'Assassin2', 'Assassin3', 'Assassin4',
        'Assassin5', 'Assassin6', 'Assassin7', 'Assassin8',
        'StealthWalk', -- Shadow Cloak - +60% speed, guaranteed crits
        'ShadowLeap', -- Teleport behind enemy
        'ShadowSlash1', 'ShadowSlash2', -- Shadow Strike - spin attack
    },
    
    ['Warlord'] = {
        -- Primary: Warlord's Rage (Attack) - 5 hit combo
        -- FunctionName: Piledriver, Block (Charged Block), ChainsOfWar, Ultimate (Yggdrasil)
        'Warlord1', 'Warlord2', 'Warlord3', 'Warlord4', 'Warlord5',
        'Piledriver1', 'Piledriver2', 'Piledriver3', -- Up to 3 hits, each stronger
        'Block', -- Charged Block - 80% damage negation + shock
        'ChainsOfWar', -- Shield slam, -50% enemy defense
    },
    
    ['Leviathan'] = {
        -- Primary: Serpent's Fang (Attack) - 6 hit combo with bubble system
        -- FunctionName: Riptide (Water Cyclone), Hydrosurge, Mealstrom (Maelstrom Spin), Ultimate
        'Leviathan1', 'Leviathan2', 'Leviathan3', 'Leviathan4', 'Leviathan5', 'Leviathan6',
        'Riptide1', 'Riptide2', 'Riptide3', -- Water Cyclone
        'Hydrosurge1', 'Hydrosurge2', 'Hydrosurge3', -- Piercing water strike
        'Maelstrom1', 'Maelstrom2', 'Maelstrom3', -- Spin attack with defense bubble
    },
    
    -- ========================================================================
    -- RANGED/MAGE CLASSES
    -- ========================================================================
    
    ['Mage'] = {
        -- Primary: Arcane Orbs (Attack) - free movement while casting
        -- FunctionName: ArcaneBlast, ArcaneWave, Ultimate (Arcane Ascension)
        'Mage1',
        'ArcaneBlast', 'ArcaneBlastAOE',
        'ArcaneWave1', 'ArcaneWave2', 'ArcaneWave3', 'ArcaneWave4',
        'ArcaneWave5', 'ArcaneWave6', 'ArcaneWave7', 'ArcaneWave8', 'ArcaneWave9',
    },
    
    ['IcefireMage'] = {
        -- Primary: Ice Needle (Attack) - inflicts Frost
        -- FunctionName: IcySpikes, Fireball, LightningStrike, Ultimate (Meteor Crash)
        'IcefireMage1',
        'IcySpikes1', 'IcySpikes2', 'IcySpikes3', 'IcySpikes4',
        'IcefireMageFireballBlast', 'IcefireMageFireball',
        'LightningStrike1', 'LightningStrike2', 'LightningStrike3', 'LightningStrike4', 'LightningStrike5',
    },
    
    ['MageOfLight'] = {
        -- Primary: Light Seeker (Attack)
        -- FunctionName: HealCircle, InfusedLight, Barrier, Ultimate (Grace)
        'MageOfLight1',
        'HealCircle', -- Healing circle for party
        'InfusedLight', -- Infuse orbs (costs health)
        'Barrier', -- Shield for allies
        'MageOfLightBlast',
    },
    
    ['MageOfShadows'] = {
        -- Primary: Shadow Seeker (Attack)
        -- FunctionName: MageOfShadowsDamageCircle, ConsumeDarkOrbs, ShadowChains, Ultimate
        'MageOfShadows1',
        'ShadowExplosion', -- Damage circle
        'ShadowMerge', -- Merge orbs
        'ShadowChains', -- Chain enemies
    },
    
    ['Stormcaller'] = {
        -- Primary: Shock Bolts (Attack)
        -- FunctionName: Supercharge, ChainLightning, StormSurge, Ultimate (Thunder God)
        'Stormcaller1', 'Stormcaller2', 'Stormcaller3', 'Stormcaller4',
        'Supercharge', -- Sacrifice 20% health for supercharge
        'ChainLightning1', 'ChainLightning2',
        'StormSurgeInit', 'StormSurge1', 'StormSurge2',
        'ShockDashBall', 'ShockDash1', 'ShockDash2', 'ShockDash3',
        -- Thunder God mode attacks
        'StormcallerThunderGod1', 'StormcallerThunderGod2', 'StormcallerThunderGod3',
        'StormcallerThunderGod4', 'StormcallerThunderGod5', 'StormcallerThunderGod6', 'StormcallerThunderGod7',
    },
    
    ['Summoner'] = {
        -- Primary: Rift Rifle (Attack) - 25% chance to release soul
        -- FunctionName: Summon, ExplodeSummons, SoulHarvest, Ultimate (Super Summon)
        'Summoner1', 'Summoner2', 'Summoner3', 'Summoner4',
        'Summon', -- Summon Lesser Soul Being
        'ExplodeSummons', -- Rift Explosion
        'SoulHarvest1', 'SoulHarvest2', 'SoulHarvest3',
    },
    
    ['Archer'] = {
        -- Primary: Archer's Arrow (Attack) - charges ultimate
        -- FunctionName: PiercingArrow, SpiritBomb, MortarStrike, Ultimate (Paracausal Wings)
        'Archer',
        'PiercingArrow1', 'PiercingArrow2', 'PiercingArrow3', 'PiercingArrow4', 'PiercingArrow5',
        'PiercingArrow6', 'PiercingArrow7', 'PiercingArrow8', 'PiercingArrow9', 'PiercingArrow10',
        'SpiritBomb',
        'MortarStrike1', 'MortarStrike2', 'MortarStrike3', 'MortarStrike4',
        'MortarStrike5', 'MortarStrike6', 'MortarStrike7',
        'HeavenlySword1', 'HeavenlySword2', 'HeavenlySword3',
        'HeavenlySword4', 'HeavenlySword5', 'HeavenlySword6',
    },
    
    ['Hunter'] = {
        -- Primary: Hunter's Arrow (FunctionName = 'Attack')
        -- Skill1: Blazing Shot (FunctionName = 'HuntersMark')
        -- Skill2/Summon/Frenzy: All use FunctionName = 'Familiar'
        -- Skill3: Venom Trap (FunctionName = 'BearTrap')
        -- Ultimate: Divine Arrow (FunctionName = 'Ultimate')
        'Attack', -- Primary attack
        'Familiar', -- Summon/Tame/Frenzy Familiar - priority skill for summoning pet
        'HuntersMark', -- Blazing Shot - fire arrow with burn
        'BearTrap', -- Venom Trap - slows and damages enemies
        'HunterExplosiveArrow1', 'HunterExplosiveArrow2', 'HunterExplosiveArrow3', 'HunterExplosiveArrow4',
        'DivineArrow1', 'DivineArrow2', 'DivineArrow3', 'DivineArrow4', 'DivineArrow5',
        'DivineArrow6', 'DivineArrow7', 'DivineArrow8', 'DivineArrow9', 'DivineArrow10',
    },
}

-- ============================================================================
-- CUSTOM COOLDOWNS (Based on decompiled game data)
-- ============================================================================
-- Accurate cooldowns per skill based on analyzing the Skillset modules
-- Format: ClassName = { SkillName = cooldownInSeconds }
-- Skills not listed here will use DEFAULT_SKILL_COOLDOWN

local CustomCooldowns = {
    -- ========================================================================
    -- MELEE CLASSES
    -- ========================================================================
    
    Swordmaster = {
        -- Primary combo: 6 hits, 0.75s combo window
        Swordmaster1 = 0.22, Swordmaster2 = 0.22, Swordmaster3 = 0.22,
        Swordmaster4 = 0.22, Swordmaster5 = 0.22, Swordmaster6 = 0.22,
        -- Skills
        CrescentStrike1 = 5, CrescentStrike2 = 0.4, CrescentStrike3 = 0.4,
        Leap = 8, -- LeapSlash
    },
    
    Defender = {
        -- Primary combo: 5 hits, 1.0s combo window
        Defender1 = 0.35, Defender2 = 0.35, Defender3 = 0.35,
        Defender4 = 0.35, Defender5 = 0.35,
        -- Skills
        Groundbreaker = 6,
        Spin1 = 8, Spin2 = 0.4, Spin3 = 0.4, Spin4 = 0.4, Spin5 = 0.4,
    },
    
    DualWielder = {
        -- Primary combo: 10 hits with speed ramp (1.05x to 1.5x)
        DualWield1 = 0.14, DualWield2 = 0.13, DualWield3 = 0.12, DualWield4 = 0.11, DualWield5 = 0.10,
        DualWield6 = 0.10, DualWield7 = 0.09, DualWield8 = 0.09, DualWield9 = 0.08, DualWield10 = 0.08,
        -- Skills
        AttackBuff = 0, -- Combat Rhythm - instant use, 6s buff
        DashStrike = 6,
        CrossSlash1 = 7, CrossSlash2 = 0.3, CrossSlash3 = 0.3, CrossSlash4 = 0.3,
    },
    
    Guardian = {
        -- Primary combo: 4 hits
        Guardian1 = 0.28, Guardian2 = 0.28, Guardian3 = 0.28, Guardian4 = 0.28,
        -- Skills
        AggroDraw = 8, -- 70% damage resistance for 8s, aggro
        RockSpikes1 = 7, RockSpikes2 = 0.3, RockSpikes3 = 0.3,
        SlashFury1 = 9, -- 13 hits total
    },
    
    Paladin = {
        -- Primary combo: 4 hits
        Paladin1 = 0.26, Paladin2 = 0.26, Paladin3 = 0.26, Paladin4 = 0.26,
        LightPaladin1 = 0.24, LightPaladin2 = 0.24, -- Light mode faster
        -- Skills
        Block = 1, -- Gilded Block - can spam for defense
        GuildedLight = 12, -- Divine Retribution - heal + damage + defense
        LightThrust1 = 11, LightThrust2 = 0.3, -- Grants 9s Paladin Light
    },
    
    Berserker = {
        -- Primary combo: 6 hits
        Berserker1 = 0.30, Berserker2 = 0.30, Berserker3 = 0.30,
        Berserker4 = 0.30, Berserker5 = 0.30, Berserker6 = 0.30,
        -- Skills
        AggroSlam = 6, -- Leap + aggro
        GigaSpin1 = 8, -- Spinning attack
        Fissure1 = 10, Fissure2 = 0.3,
        FissureErupt1 = 10, -- Only in Rage mode
    },
    
    Dragoon = {
        -- Primary combo: 7 hits with mark system
        Dragoon1 = 0.23, Dragoon2 = 0.23, Dragoon3 = 0.23, Dragoon4 = 0.23,
        Dragoon5 = 0.23, Dragoon6 = 0.23, Dragoon7 = 0.23,
        -- Skills (Dragon Chain system)
        InfinityStrike = 8, -- Starts chain
        MultiStrike1 = 7, -- Dragon Wrath (continues chain)
        DragonSlam = 10, -- Completes chain, activates Dragon Mode
        DragoonFall = 10,
    },
    
    Demon = {
        -- Primary combo: 25 hits! Very fast
        Demon1 = 0.18, Demon4 = 0.18, Demon7 = 0.18, Demon10 = 0.18, Demon13 = 0.18,
        Demon16 = 0.18, Demon19 = 0.18, Demon22 = 0.18, Demon25 = 0.18,
        DemonDPS1 = 0.18,
        -- Skills
        BloodBinding = 15, -- 30% health cost, 25% damage boost
        ScytheThrowDPS1 = 6,
        LifeSteal = 10, -- Drains 3 enemies
        DemonSoulDPS1 = 8,
    },
    
    Necromancer = {
        -- Primary combo: 9 hits
        NecroDPS1 = 0.20, NecroDPS2 = 0.20, NecroDPS3 = 0.20,
        NecroDPS4 = 0.20, NecroDPS5 = 0.20, NecroDPS6 = 0.20,
        NecroDPS7 = 0.20, NecroDPS8 = 0.20, NecroDPS9 = 0.20,
        -- Skills
        TombstoneRise1 = 6,
        SpiritExplosion0 = 4, SpiritExplosion1 = 4, -- Spirit count based
        SpiritCavern1 = 12, -- Creates damage zone + Hexed
    },
    
    Assassin = {
        -- Primary combo: 8 hits (crits in Shadow Mode)
        Assassin1 = 0.16, Assassin2 = 0.16, Assassin3 = 0.16, Assassin4 = 0.16,
        Assassin5 = 0.16, Assassin6 = 0.16, Assassin7 = 0.16, Assassin8 = 0.16,
        -- Skills
        StealthWalk = 12, -- Shadow Cloak - +60% speed, guaranteed crits
        ShadowLeap = 8, -- Teleport behind
        ShadowSlash1 = 7, ShadowSlash2 = 0.3, -- Spin attack
    },
    
    Warlord = {
        -- Primary combo: 5 hits
        Warlord1 = 0.28, Warlord2 = 0.28, Warlord3 = 0.28, Warlord4 = 0.28, Warlord5 = 0.28,
        -- Skills
        Piledriver1 = 8, Piledriver2 = 0.5, Piledriver3 = 0.5, -- 3 hits, each stronger
        Block = 6, -- Charged Block
        ChainsOfWar = 10, -- -50% enemy defense
    },
    
    Leviathan = {
        -- Primary combo: 6 hits with bubble system
        Leviathan1 = 0.22, Leviathan2 = 0.22, Leviathan3 = 0.22,
        Leviathan4 = 0.22, Leviathan5 = 0.22, Leviathan6 = 0.22,
        -- Skills
        Riptide1 = 7, -- Water Cyclone
        Hydrosurge1 = 8, -- Piercing strike
        Maelstrom1 = 10, -- Spin with defense bubble
    },
    
    -- ========================================================================
    -- RANGED/MAGE CLASSES
    -- ========================================================================
    
    Mage = {
        Mage1 = 0.75, -- Arcane Orbs - slower but free movement
        ArcaneBlast = 9, ArcaneBlastAOE = 9,
        ArcaneWave1 = 7,
    },
    
    IcefireMage = {
        IcefireMage1 = 0.75, -- Ice Needle
        IcySpikes1 = 7, -- Inflicts Super Frost
        IcefireMageFireballBlast = 8, IcefireMageFireball = 8, -- Inflicts Burn
        LightningStrike1 = 10, -- Inflicts Shock
    },
    
    MageOfLight = {
        MageOfLight1 = 0.80,
        HealCircle = 10, -- Party heal
        InfusedLight = 8, -- 4-40% health cost based on orbs
        Barrier = 12, -- Shield for party
        MageOfLightBlast = 6,
    },
    
    MageOfShadows = {
        MageOfShadows1 = 0.70,
        ShadowExplosion = 6,
        ShadowMerge = 5,
        ShadowChains = 10,
    },
    
    Stormcaller = {
        Stormcaller1 = 0.55, Stormcaller2 = 0.55, Stormcaller3 = 0.55, Stormcaller4 = 0.55,
        Supercharge = 15, -- 20% health cost
        ChainLightning1 = 8, -- Hits up to 8 enemies
        StormSurgeInit = 10, StormSurge1 = 10,
        ShockDashBall = 10,
        -- Thunder God mode
        StormcallerThunderGod1 = 0.35, -- Much faster in Thunder God
    },
    
    Summoner = {
        Summoner1 = 0.60,
        Summon = 3, -- Summon costs souls
        ExplodeSummons = 8,
        SoulHarvest1 = 12,
    },
    
    Archer = {
        Archer = 0.36, -- Archer's Arrow
        PiercingArrow1 = 6, -- -30% enemy defense
        SpiritBomb = 10, -- -65% enemy speed
        MortarStrike1 = 12,
        HeavenlySword1 = 8,
    },
    
    Hunter = {
        Attack = 0.34, -- Hunter's Arrow (primary)
        Familiar = 12, -- Summon/Tame/Frenzy Familiar - reduced CD to ensure pet is summoned often
        HuntersMark = 8, -- Blazing Shot - burn
        BearTrap = 10, -- Venom Trap
        HunterExplosiveArrow1 = 9, -- Explosive arrow combo starter
        DivineArrow1 = 12, -- Ultimate follow-up hits
    },
}

-- ============================================================================
-- SKILL EXECUTION
-- ============================================================================

--- Use a skill via the game's Combat.AttackTargets function
--- This is the correct way to cast skills in World Zero
--- @param skillName string: The name of the skill to use
--- @param targetPos Vector3|nil: Target position for the skill
--- @param targetMob Instance|nil: Target mob for the skill
local function useSkill(skillName, targetPos, targetMob)
    -- Add small random delay for anti-detection (0-30ms)
    if math.random() < 0.3 then
        wait(math.random() * 0.03)
    end
    
    if Combat then
        pcall(function()
            local pos = targetPos or Vector3.new(0, 0, 0)
            local mobTable = targetMob and { targetMob } or {}
            local posTable = { pos }
            
            -- Method 1: Combat.AttackTargets (used by all working autofarm scripts)
            -- This is a CLIENT-SIDE module function, NOT the AttackTarget remote honeypot
            if Combat.AttackTargets then
                Combat.AttackTargets(nil, mobTable, posTable, skillName)
            -- Method 2: Combat:AttackWithSkill with magic number 67
            elseif Combat.AttackWithSkill then
                Combat:AttackWithSkill(67, skillName, pos, Vector3.new(0, 0, 0))
            end
            
            -- WARNING: NEVER call the AttackTarget REMOTE EVENT directly
            -- That is a honeypot trap that instantly flags you as "autofarmer"
        end)
    end
end

--- Check if the game's skill system is ready
--- @return boolean: True if Combat module is loaded
local function isGameReady()
    return CombatLoaded and Combat ~= nil and (Combat.AttackTargets ~= nil or Combat.AttackWithSkill ~= nil)
end

-- ============================================================================
-- MELEE REACH SYSTEM
-- ============================================================================
-- ⚠️ WARNING: This system is DISABLED by default because:
-- • Anti-cheat monitors BodyVelocity for impossible/sudden velocities
-- • Speed above normal walkspeed (~16-20 studs/sec) can trigger detection
-- • Extended reach beyond game's ~10 stud melee range is flagged
--
-- If you enable this, use at your own risk. Recommended to leave disabled.
-- ============================================================================

-- Store BodyVelocity reference for cleanup
local reachBodyVelocity = nil

--- Move player smoothly towards a target position using BodyVelocity
--- ⚠️ RISKY: BodyVelocity is monitored by anti-cheat for abnormal velocities
--- @param targetPos Vector3: Target position to move towards
--- @param currentPos Vector3: Current player position
--- @return boolean: True if movement was applied
local function moveTowardsTarget(targetPos, currentPos)
    if not MeleeReach.enabled then return false end
    
    local plr = Players.LocalPlayer
    if not plr or not plr.Character then return false end
    
    local hrp = plr.Character:FindFirstChild('HumanoidRootPart')
    if not hrp then return false end
    
    local distance = (targetPos - currentPos).Magnitude
    
    -- Only move if within reach range but outside ideal distance
    if distance > MeleeReach.maxReach or distance < MeleeReach.idealDistance then
        -- Cleanup existing BodyVelocity if we're in range
        if reachBodyVelocity then
            pcall(function() reachBodyVelocity:Destroy() end)
            reachBodyVelocity = nil
        end
        return false
    end
    
    -- Calculate direction towards target (horizontal only for safety)
    local direction = (targetPos - currentPos)
    direction = Vector3.new(direction.X, 0, direction.Z).Unit
    
    -- Add slight variance to direction for anti-detection
    local variance = AntiDetection.timingVariance * 0.5
    direction = direction + Vector3.new(
        (math.random() - 0.5) * variance,
        0,
        (math.random() - 0.5) * variance
    )
    direction = direction.Unit
    
    if MeleeReach.useBodyVelocity then
        -- BodyVelocity method - safer, looks like normal movement
        pcall(function()
            if not reachBodyVelocity or not reachBodyVelocity.Parent then
                reachBodyVelocity = Instance.new('BodyVelocity')
                reachBodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
                reachBodyVelocity.P = 10000
                reachBodyVelocity.Parent = hrp
            end
            
            -- Calculate velocity based on speed and distance
            local speed = math.min(MeleeReach.moveSpeed, distance * 5)
            reachBodyVelocity.Velocity = direction * speed
        end)
    else
        -- CFrame method - faster but more risky
        pcall(function()
            local moveAmount = math.min(distance - MeleeReach.idealDistance, MeleeReach.moveSpeed * 0.016)
            hrp.CFrame = hrp.CFrame + (direction * moveAmount)
        end)
    end
    
    -- Update humanoid state to avoid falling animation detection
    pcall(function()
        local humanoid = plr.Character:FindFirstChild('Humanoid')
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
    
    return true
end

--- Stop melee reach movement and cleanup
local function stopReachMovement()
    if reachBodyVelocity then
        pcall(function()
            reachBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            reachBodyVelocity:Destroy()
        end)
        reachBodyVelocity = nil
    end
end

-- ============================================================================
-- COOLDOWN MANAGEMENT
-- ============================================================================

-- Make CustomCooldowns accessible globally for KillAuraSettingsAPI
_genv.KillAuraCustomCooldowns = CustomCooldowns
_genv.KillAuraMeleeConfig = MeleeClassConfig
_genv.KillAuraAntiDetection = AntiDetection
_genv.KillAuraMeleeReach = MeleeReach

--- Check if a class is a melee class (uses MeleeClassConfig)
--- @param className string: The class to check
--- @return boolean: True if class is melee
local function isMeleeClass(className)
    return MeleeClassConfig[className] ~= nil
end

--- Get primary attack cooldown for a class
--- Uses MeleeClassConfig for melee classes, PrimaryHoldOverrides for ranged
--- @param className string: The player's current class
--- @return number: Primary attack cooldown in seconds
local function getPrimaryCooldown(className)
    -- Check melee config first
    local meleeConfig = MeleeClassConfig[className]
    if meleeConfig then
        return addVariance(meleeConfig.primaryCD, AntiDetection.timingVariance)
    end
    
    -- Check ranged/mage overrides
    local override = PrimaryHoldOverrides[className]
    if override then
        local base = override.min + math.random() * (override.max - override.min)
        return addVariance(base, AntiDetection.timingVariance * 0.5)
    end
    
    -- Default
    return addVariance(PRIMARY_DEFAULT_COOLDOWN, AntiDetection.timingVariance)
end

--- Get the cooldown duration for a specific skill
--- Checks KillAuraSettingsAPI first, then falls back to CustomCooldowns
--- @param className string: The player's current class
--- @param skillName string: The skill to check
--- @return number|nil: The cooldown in seconds, or nil if skill should be skipped
local function getSkillCooldown(className, skillName)
    -- Try to get cooldown from KillAuraSettingsAPI first (user-customized)
    local settingsAPI = _G.KillAuraSettingsAPI
    if settingsAPI and settingsAPI.getSkillCooldown then
        local customCooldown = settingsAPI.getSkillCooldown(className, skillName)
        if customCooldown and customCooldown > 0 then
            -- Skip primary alias skills in rotation; they are handled by hold logic
            if PrimaryAlias[className] and skillName == PrimaryAlias[className] then
                return nil
            end
            -- Add variance for anti-detection
            return addVariance(customCooldown, AntiDetection.timingVariance)
        end
    end
    
    -- Fallback: Check local CustomCooldowns
    if CustomCooldowns[className] then
        -- If class has custom cooldowns, ONLY fire skills in that list
        if CustomCooldowns[className][skillName] then
            -- Skip primary alias skills in rotation; they are handled by hold logic
            if PrimaryAlias[className] and skillName == PrimaryAlias[className] then
                return nil
            end
            -- Add variance for anti-detection
            return addVariance(CustomCooldowns[className][skillName], AntiDetection.timingVariance)
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
    return addVariance(DEFAULT_SKILL_COOLDOWN, AntiDetection.timingVariance)
end

-- ============================================================================
-- API INITIALIZATION (Must be before combatLoop)
-- ============================================================================

local API = {}
API.running = false
API.forcedClass = nil -- Override detected class
API.stats = {
    attacksThisSession = 0,
    skillsUsed = {},
    lastAttackTime = 0,
    sessionStart = 0,
}

-- ============================================================================
-- COMBAT LOGIC
-- ============================================================================

--- Check if the BOSSTreeEnt boss is invincible (cage/pillars present)
--- When cage or pillars are up, players must destroy them first
--- @return boolean: True if boss is invincible and should be skipped
local function isTreeEntInvincible()
    local result = false
    pcall(function()
        local workspace = game:GetService('Workspace')
        
        -- Check for TreeEntCage (the shield/cage around the boss)
        local cage = workspace:FindFirstChild('TreeEntCage')
        if cage then
            result = true
            return
        end
        
        -- Also check for pillars - boss spawns Pillar1, Pillar2, Pillar3 when invincible
        local pillar1 = workspace:FindFirstChild('Pillar1')
        local pillar2 = workspace:FindFirstChild('Pillar2')
        local pillar3 = workspace:FindFirstChild('Pillar3')
        
        if pillar1 or pillar2 or pillar3 then
            result = true
            return
        end
    end)
    return result
end

--- Check if a mob is a familiar/summon and should be skipped
--- @param mob Instance: The mob to check
--- @return boolean: True if mob is a familiar (should skip)
local function isFamiliar(mob)
    if not mob then return true end
    
    -- Check for common familiar indicators
    local mobName = mob.Name
    if not mobName then return true end
    
    -- Skip if mob has "Familiar" in the name
    if string.find(mobName, "Familiar") then
        return true
    end
    
    -- Skip if mob has "Summon" in the name
    if string.find(mobName, "Summon") then
        return true
    end
    
    -- Skip if mob has "Pet" in the name
    if string.find(mobName, "Pet") then
        return true
    end
    
    -- Skip Spirit-related summons (Necromancer/Summoner)
    -- Be specific to avoid skipping real enemies like SpiritHorse
    if mobName == "Spirit" or mobName == "SoulSpirit" or mobName == "SkeletonMinion" or mobName == "SkeletonSummon" then
        return true
    end
    
    -- Skip generic summon patterns but NOT compound names like SpiritHorse
    if string.match(mobName, "^Spirit%d*$") or string.match(mobName, "^Soul%d*$") or string.match(mobName, "^Skeleton%d*$") then
        return true
    end
    
    -- Check if mob has an Owner property (player-owned familiar)
    local hasOwner = false
    pcall(function()
        if mob:FindFirstChild("Owner") or mob:FindFirstChild("PlayerOwner") then
            hasOwner = true
        end
    end)
    
    return hasOwner
end

--- Check if a mob is owned by another player (not us)
--- @param mob Instance: The mob to check
--- @return boolean: True if owned by another player
local function isOwnedByOtherPlayer(mob)
    local plr = Players.LocalPlayer
    if not plr then return false end
    
    local isOtherOwned = false
    pcall(function()
        local mobProps = mob:FindFirstChild('MobProperties')
        if mobProps then
            local ownerVal = mobProps:FindFirstChild('Owner')
            if ownerVal and ownerVal.Value then
                -- Has an owner - check if it's not us
                if ownerVal.Value ~= plr then
                    isOtherOwned = true
                end
            end
        end
    end)
    
    return isOtherOwned
end

--- Check if there are any enemies nearby (mobs folder has alive mobs)
--- This is a quick check to avoid heavy processing when no enemies exist
--- @return boolean: True if enemies exist in the workspace
local function hasEnemiesNearby()
    local workspace = game:GetService('Workspace')
    local mobFolder = workspace:FindFirstChild('Mobs')
    if not mobFolder then
        return false
    end
    
    -- Quick check: if folder is empty, no enemies
    local children = mobFolder:GetChildren()
    if #children == 0 then
        return false
    end
    
    -- Check if any mob is alive (has health > 0)
    for _, mob in ipairs(children) do
        -- Skip familiars/summons quickly using name check
        if not isFamiliar(mob) and not isOwnedByOtherPlayer(mob) then
            local health = mob:FindFirstChild('HealthProperties')
            if health then
                local healthVal = health:FindFirstChild('Health')
                if healthVal and healthVal.Value and healthVal.Value > 0 then
                    return true
                end
            end
        end
    end
    
    return false
end

--- Check if the player is in a dungeon/tower (where combat should be active)
--- @return boolean: True if in a dungeon or tower
local function isInCombatArea()
    local result = false
    pcall(function()
        -- Check if PlaceAPI is available
        local placeApi = _G.x5n3d or getgenv().x5n3d
        if placeApi and placeApi.getCurrent then
            local current = placeApi.getCurrent()
            if current then
                -- In dungeon = combat area
                if current.isDungeon then
                    result = true
                    return
                end
                -- In tower = combat area
                if current.isTower then
                    result = true
                    return
                end
            end
        end
        
        -- Fallback: Check workspace for mission objects (indicates dungeon/tower)
        local workspace = game:GetService('Workspace')
        local missionObjects = workspace:FindFirstChild('MissionObjects')
        if missionObjects then
            -- Has mission objects = likely in dungeon
            result = true
            return
        end
    end)
    return result
end

--- Main combat loop - continuously attacks the closest mob
--- Optimized for melee classes with combo support and anti-detection
local function combatLoop()
    local plr = Players.LocalPlayer
    if not plr then
        API.running = false
        return
    end

    -- Track skill cooldowns
    local skillCooldowns = {}         -- {skillName = lastUsedTime}
    local ultimateCooldown = 0        -- Last time ultimate was used
    local lastClassName = nil         -- Previous class (detect class changes)
    local lastSkillSwitchTime = time()
    local lastPrimaryFire = 0         -- Last time primary was fired
    local lastAttackTime = 0          -- Prevent loop from running too fast
    local comboCount = 0              -- Track current combo for melee classes
    local lastComboTime = 0           -- Track combo window
    local inBurstMode = false         -- Anti-detection burst mode
    local burstEndTime = 0            -- When burst mode ends
    
    -- Session stats
    API.stats.sessionStart = time()

    while API.running do
        -- ALWAYS yield at the start of each loop iteration to prevent crash
        -- Use variable timing for anti-detection
        local baseWait = 0.08 + math.random() * 0.04 -- 80-120ms
        wait(baseWait)
        
        -- Skip if not running (check again after wait)
        if not API.running then break end
        
        -- Wrap entire loop body in pcall so errors don't stop the loop
        local success, err = pcall(function()
            -- Get player's current class (or use forced class)
            local className = API.forcedClass
            if not className then
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
            end

            if not className or not Classes[className] then
                return -- Will continue to next loop iteration
            end

            -- Reset cooldowns if class changed
            if lastClassName ~= className then
                skillCooldowns = {}
                comboCount = 0
                lastClassName = className
            end

            -- Get character and head
            local character = plr.Character
            if not character then return end

            local head = character:FindFirstChild('Head')
            if not head then return end

            -- Find mobs
            local workspace = game:GetService('Workspace')
            local mobFolder = workspace:FindFirstChild('Mobs')
            if not mobFolder then return end

            -- Find closest valid mob
            local closestMob = nil
            local closestDist = 10000

            for _, mob in ipairs(mobFolder:GetChildren()) do
                -- Use repeat-until false pattern instead of continue (Lua 5.1 compatible)
                repeat
                    -- Skip invalid mobs
                    if not mob or not mob.Parent then break end
                    if isFamiliar(mob) then break end
                    if isOwnedByOtherPlayer(mob) then break end
                    
                    -- Skip TreeEnt when invincible
                    if (mob.Name == 'BOSSTreeEnt' or mob.Name == 'CorruptedGreaterTree') and isTreeEntInvincible() then
                        break
                    end
                    
                    -- Skip Dire Problem boss unless enabled
                    if mob.Name == 'BOSSDireBoarwolf' then
                        local allowBoss = _genv.DireProblemBossTarget == true
                        if not allowBoss then break end
                    end

                    local collider = mob:FindFirstChild('Collider')
                    if not collider then break end

                    local health = mob:FindFirstChild('HealthProperties')
                    if not health then break end
                    
                    local healthVal = health:FindFirstChild('Health')
                    if not healthVal or not healthVal.Value or healthVal.Value <= 0 then break end

                    local dist = (collider.Position - head.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestMob = mob
                    end
                until true
            end

            -- No valid mob found
            if not closestMob then 
                comboCount = 0 -- Reset combo when no target
                stopReachMovement() -- Stop any active reach movement
                return 
            end
            
            local collider = closestMob:FindFirstChild('Collider')
            if not collider then return end

            local currentTime = time()
            
            -- Check burst mode
            if inBurstMode and currentTime > burstEndTime then
                inBurstMode = false
            end
            
            -- Random chance to enter burst mode (anti-detection)
            if not inBurstMode and math.random() < AntiDetection.burstChance then
                inBurstMode = true
                burstEndTime = currentTime + addVariance(AntiDetection.burstDuration, 0.3)
            end

            -- Get melee class config if applicable
            local meleeConfig = MeleeClassConfig[className]
            local isMelee = meleeConfig ~= nil
            
            -- Check combo window for melee classes
            if isMelee and meleeConfig.comboWindow then
                if currentTime - lastComboTime > meleeConfig.comboWindow then
                    comboCount = 0 -- Reset combo if window expired
                end
                -- Random combo break for anti-detection
                if comboCount > 2 and math.random() < AntiDetection.comboBreakChance then
                    comboCount = 0
                    wait(addVariance(0.2, 0.5))
                end
            end

            -- Determine primary skill name
            local primarySkillName = PrimaryAlias[className]
            if not primarySkillName then
                for _, s in ipairs(Classes[className]) do
                    if string.match(s, '1$') and not string.match(s, '%d%d') then
                        primarySkillName = s
                        break
                    end
                end
            end

            -- Get primary cooldown using new system
            local primaryCooldown = getPrimaryCooldown(className)
            
            -- Apply burst mode speed multiplier
            if inBurstMode then
                primaryCooldown = primaryCooldown * AntiDetection.burstSpeedMultiplier
            end

            -- Check if Ultimate is ready
            if currentTime - ultimateCooldown >= ULTIMATE_COOLDOWN and hasEnergyForUltimate() then
                if closestMob and closestMob.Parent then
                    local currentCollider = closestMob:FindFirstChild('Collider')
                    if currentCollider then
                        local player = Players.LocalPlayer
                        local targetPos = currentCollider.Position
                        if player and player.Character then
                            local hrp = player.Character:FindFirstChild('HumanoidRootPart')
                            if hrp then
                                targetPos = hrp.Position
                            end
                        end
                        useSkill('Ultimate', targetPos, closestMob)
                        ultimateCooldown = currentTime
                        skillCooldowns = {}
                        comboCount = 0
                        API.stats.attacksThisSession = API.stats.attacksThisSession + 1
                    end
                end
                return
            end

            -- Find available skills
            local availableSkills = {}
            local primarySkills = {} -- Track primaries separately for melee
            
            -- Check primary
            if primarySkillName and (currentTime - lastPrimaryFire >= primaryCooldown) then
                table.insert(primarySkills, { name = primarySkillName, isPrimary = true })
            end
            
            -- Check other skills
            for _, skillName in ipairs(Classes[className]) do
                local skillCD = getSkillCooldown(className, skillName)
                if skillCD then
                    local lastUsed = skillCooldowns[skillName] or 0
                    local actualCD = skillCD
                    if inBurstMode then
                        actualCD = skillCD * AntiDetection.burstSpeedMultiplier
                    end
                    if currentTime - lastUsed >= actualCD then
                        table.insert(availableSkills, { name = skillName, cooldown = skillCD })
                    end
                end
            end

            -- Melee classes: prioritize primary attacks in combo, use skills between combos
            local skillToUse = nil
            if isMelee then
                -- In a combo: prefer primary attacks
                if comboCount < (meleeConfig.maxCombo or 5) and #primarySkills > 0 then
                    -- Get the base primary name (e.g., "Swordmaster1" -> "Swordmaster")
                    local basePrimary = primarySkillName and string.gsub(primarySkillName, '%d+$', '') or className
                    -- Calculate current combo index (1-based, wraps around maxCombo)
                    local comboIndex = (comboCount % (meleeConfig.maxCombo or 6)) + 1
                    -- Build the combo skill name (e.g., "Swordmaster1", "Swordmaster2", etc.)
                    local comboSkillName = basePrimary .. tostring(comboIndex)
                    skillToUse = { name = comboSkillName, isPrimary = true }
                elseif #availableSkills > 0 then
                    -- Use a skill at end of combo or if no primary ready
                    skillToUse = availableSkills[math.random(1, #availableSkills)]
                    comboCount = 0 -- Reset combo after skill
                elseif #primarySkills > 0 then
                    -- Fallback: use first primary with combo variant
                    local basePrimary = primarySkillName and string.gsub(primarySkillName, '%d+$', '') or className
                    local comboIndex = (comboCount % (meleeConfig.maxCombo or 6)) + 1
                    skillToUse = { name = basePrimary .. tostring(comboIndex), isPrimary = true }
                end
            else
                -- Ranged classes: mixed skill usage
                local allSkills = {}
                for _, s in ipairs(primarySkills) do table.insert(allSkills, s) end
                for _, s in ipairs(availableSkills) do table.insert(allSkills, s) end
                
                if #allSkills > 0 then
                    skillToUse = allSkills[math.random(1, #allSkills)]
                end
            end

            -- Use a skill if available
            if skillToUse then
                -- Validate mob still exists
                if closestMob and closestMob.Parent then
                    local currentCollider = closestMob:FindFirstChild('Collider')
                    
                    if currentCollider then
                        -- Get positions
                        local player = Players.LocalPlayer
                        local mobPos = currentCollider.Position
                        local playerPos = mobPos -- fallback
                        local hrp = nil
                        
                        if player and player.Character then
                            hrp = player.Character:FindFirstChild('HumanoidRootPart')
                            if hrp then
                                playerPos = hrp.Position
                            end
                        end
                        
                        -- MELEE REACH: Move towards target if melee class and out of range
                        if isMelee and hrp and MeleeReach.enabled then
                            local distanceToMob = (mobPos - playerPos).Magnitude
                            if distanceToMob > MeleeReach.idealDistance and distanceToMob <= MeleeReach.maxReach then
                                moveTowardsTarget(mobPos, playerPos)
                            elseif distanceToMob <= MeleeReach.idealDistance then
                                -- In range, stop any active reach movement
                                stopReachMovement()
                            end
                        end
                        
                        -- Use the game's Combat.AttackTargets
                        useSkill(skillToUse.name, playerPos, closestMob)
                        
                        -- Track cooldown
                        if skillToUse.isPrimary then
                            lastPrimaryFire = currentTime
                            comboCount = comboCount + 1
                            lastComboTime = currentTime
                        else
                            skillCooldowns[skillToUse.name] = currentTime
                        end
                        
                        lastAttackTime = currentTime
                        API.stats.attacksThisSession = API.stats.attacksThisSession + 1
                        API.stats.lastAttackTime = currentTime
                        
                        -- Track skill usage
                        API.stats.skillsUsed[skillToUse.name] = (API.stats.skillsUsed[skillToUse.name] or 0) + 1
                    end
                end

                -- Random delay between attacks (anti-detection)
                local minDelay = AntiDetection.minAttackDelay
                local maxDelay = AntiDetection.maxAttackDelay
                if inBurstMode then
                    minDelay = minDelay * AntiDetection.burstSpeedMultiplier
                    maxDelay = maxDelay * AntiDetection.burstSpeedMultiplier
                end
                local randomDelay = minDelay + math.random() * (maxDelay - minDelay)
                if randomDelay > 0.01 then
                    wait(randomDelay)
                end

                -- Occasional pause (simulates player looking around)
                if math.random() < AntiDetection.pauseChance then
                    local pauseDuration = AntiDetection.pauseMinDuration + 
                        math.random() * (AntiDetection.pauseMaxDuration - AntiDetection.pauseMinDuration)
                    wait(pauseDuration)
                    comboCount = 0 -- Reset combo after pause
                end
            end
        end)
        
        -- Log errors but don't stop
        if not success and err then
            warn('[KillAura] Loop error:', err)
        end
    end

    API.running = false
end

-- ============================================================================
-- API FUNCTIONS
-- ============================================================================

--- Start the kill aura
--- @return boolean: True if started successfully
function API.start()
    if API.running then
        return false
    end

    -- Check if the game's skill system is ready
    if not isGameReady() then
        warn('[KillAura] Game skill system not ready - Combat module not loaded')
        return false
    end
    
    -- Reset stats
    API.stats = {
        attacksThisSession = 0,
        skillsUsed = {},
        lastAttackTime = 0,
        sessionStart = time(),
    }

    API.running = true
    _genv.killAuraEnabled = true
    spawn(combatLoop)
    return true
end

--- Stop the kill aura
--- @return boolean: Always returns true
function API.stop()
    API.running = false
    _genv.killAuraEnabled = false
    
    -- Cleanup melee reach movement
    stopReachMovement()
    
    return true
end

--- Toggle the kill aura on/off
--- @return boolean: New running state
function API.toggle()
    if API.running then
        API.stop()
        return false
    else
        API.start()
        return true
    end
end

--- Force a specific class rotation (useful for testing)
--- @param className string|nil: Class name to force, or nil to auto-detect
function API.setClass(className)
    if className and Classes[className] then
        API.forcedClass = className
    else
        API.forcedClass = nil
    end
end

--- Get session statistics
--- @return table: Stats table with attacksThisSession, skillsUsed, etc.
function API.getStats()
    return API.stats
end

--- Adjust anti-detection settings
--- @param setting string: Setting name (pauseChance, timingVariance, etc.)
--- @param value number: New value for the setting
function API.setAntiDetection(setting, value)
    if AntiDetection[setting] ~= nil and type(value) == 'number' then
        AntiDetection[setting] = value
    end
end

--- Get current anti-detection settings
--- @return table: Current AntiDetection configuration
function API.getAntiDetection()
    return AntiDetection
end

--- Enable/disable melee reach
--- @param enabled boolean: Whether to enable melee reach
function API.setMeleeReach(enabled)
    MeleeReach.enabled = enabled
    if not enabled then
        stopReachMovement()
    end
end

--- Configure melee reach settings
--- @param setting string: Setting name (maxReach, idealDistance, moveSpeed)
--- @param value number: New value for the setting
function API.setMeleeReachSetting(setting, value)
    if MeleeReach[setting] ~= nil and type(value) == 'number' then
        MeleeReach[setting] = value
    end
end

--- Get current melee reach settings
--- @return table: Current MeleeReach configuration
function API.getMeleeReach()
    return MeleeReach
end

--- Print current status (returns table instead - anti-cheat safe)
function API.status()
    local duration = API.running and (time() - (API.stats.sessionStart or time())) or 0
    return {
        running = API.running,
        forcedClass = API.forcedClass,
        meleeReachEnabled = MeleeReach.enabled,
        maxReach = MeleeReach.maxReach,
        idealDistance = MeleeReach.idealDistance,
        moveSpeed = MeleeReach.moveSpeed,
        sessionDuration = duration,
        attacks = API.stats.attacksThisSession,
        attackRate = duration > 0 and (API.stats.attacksThisSession / duration) or 0
    }
end

-- Make API available globally for console testing
_G.x9m1n = API
getgenv().x9m1n = API  -- Also set in global environment

-- Also expose with friendly name for easy access
_G.killAura = API
getgenv().killAura = API

-- ============================================================================
-- EXPORT
-- ============================================================================

return API