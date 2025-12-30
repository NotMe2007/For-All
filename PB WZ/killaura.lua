-- ============================================================================
-- Kill Aura - Automated Combat System (API Module)
-- ============================================================================
-- Intelligent automated combat with class-specific skill rotation
-- https://github.com/NotMe2007/For-All/blob/main/PB%20WZ/killaura.lua
--
-- API USAGE:
-- • _G.killAura:start()  - Enable automated combat
-- • _G.killAura:stop()   - Disable automated combat
-- • _G.killAura:toggle() - Toggle combat state
--
-- FEATURES:
-- • Class-specific skill rotations
-- • Randomized timing for anti-detection
-- • Ultimate ability management
-- • Primary hold simulation (no spamming)
--
-- PERFORMANCE:
-- • Optimized skill cooldown tracking
-- • Efficient target validation
-- • Minimal CPU overhead
--
-- SECURITY:
-- • Protected remote calls
-- • Randomized attack patterns
-- • Safe service access
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

-- Combat Cooldowns
local PRIMARY_DEFAULT_COOLDOWN = 0.39   -- Primary attack cooldown (fast attacks)
local DEFAULT_SKILL_COOLDOWN = 4        -- Regular skill cooldown
local ULTIMATE_COOLDOWN = 35            -- Ultimate ability cooldown

-- Primary holdk timing (simulate holding M1 instead of spamming)
local PRIMARY_HOLD_MIN_INTERVAL = 0.2   -- Minimum interval between held primary triggers
local PRIMARY_HOLD_MAX_INTERVAL = 0.25  -- Maximum interval between held primary triggers

-- Slow down primary holds for mage-style classes
local PrimaryHoldOverrides = {
    Mage = { min = 0.85, max = 0.95 },
    IcefireMage = { min = 0.85, max = 0.95 },
    MageOfLight = { min = 0.85, max = 0.95 },
    Stormcaller = { min = 0.6, max = 0.72 },
    Summoner = { min = 0.65, max = 0.75 },
    Necromancer = { min = 0.65, max = 0.75 },
}

-- Primary skill aliases for classes whose M1 is a named base skill
local PrimaryAlias = {
    Archer = 'Archer',
    Hunter = 'Hunter',
}

-- Anti-Detection Timing (randomizes behavior to avoid detection)
local MIN_ATTACK_DELAY = 0.0           -- Minimum delay between attacks (seconds)
local MAX_ATTACK_DELAY = 0.3           -- Maximum delay between attacks (seconds)
local PAUSE_CHANCE = 0.03              -- 3% chance to pause for 1-3 seconds between attacks
local SKILL_SWITCH_INTERVAL = 30       -- Switch attack pattern every 30 seconds

-- Energy Configuration for Ultimate Abilities
local MAX_ENERGY = 350                 -- Maximum energy capacity
local ULTIMATE_ENERGY_THRESHOLD = 0.95 -- Require 95% energy to use ultimate (332.5/350)

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
    -- Cooldowns incomplete
    Mage = {
        Mage1 = 0.85,
        ArcaneBlast = 9,
        ArcaneWave1 = 6,

    },
    IcefireMage = {
        IcefireMage1 = 0.85,
        IcySpikes1 = 6,
        IcefireMageFireballBlast = 7,
        LightningStrike1 = 10,
        IcefireMageUltimateMeteor1 = 35,

    },
    Archer = {
        Archer = 0.38,
        SpiritBomb = 10,
        MortarStrike1 = 12,
        PiercingArrow1 = 5,

    },
    Swordmaster = {
        SwordCyclone1 = 5,
        Leap = 8,
    },
    Defender = {
        Groundbreaker = 5,
        Spin1 = 8,
    },
    Guardian = {
        RockSpikes1 = 6,
        SlashFury1 = 8,

    },
    Berserker = {
        AggroSlam = 5,
        GigaSpin1 = 7,
        Fissure1 = 10,
        FissureErupt1 = 10,

    },
    Paladin = {
        LightThrust1 = 11,
    },
    Demon = {
        ScytheThrowDPS1 = 5,
        DemonLifeStealDPS = 8,
        DemonSoulDPS1 = 8,
    },
    Dragoon = {
        MultiStrike1 = 6,
        MultiStrikeDragon1 = 6,
        DragoonFall = 8,
    },
    Necromancer = {
        TombstoneRise1 = 5,
        SpiritExplosion1 = 3,
        SpiritCavern1 = 10,
    },
    Stormcaller = {
        Stormcaller1 = 0.6,
        ChainLightning1 = 7,
        StormSurgeInit = 10,
        StormSurge1 = 10,
        ShockDashBall = 10,
    },
    Summoner = {
        Summoner1 = 5,
        SoulHarvest1 = 10,
    },
    DualWielder = {
        DashStrike = 6,

    },
    Hunter = {
        Hunter = 0.37,
        HunterExplosiveArrow1 = 9,
        BearTrap = 8,
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
            -- Skip primary alias skills in rotation; they are handled by hold logic
            if PrimaryAlias[className] and skillName == PrimaryAlias[className] then
                return nil
            end
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
local function combatLoop()
    local plr = Players.LocalPlayer
    if not plr then
        API.running = false
        return
    end

    -- Load Skills module for cooldown tracking
    loadSkills()

    -- Track skill cooldowns
    local skillCooldowns = {}         -- {skillName = lastUsedTime}
    local ultimateCooldown = 0        -- Last time ultimate was used
    local lastClassName = nil         -- Previous class (detect class changes)
    local lastSkillSwitchTime = time()
    local lastPrimaryFire = 0         -- Last time primary was fired
    local lastAttackTime = 0          -- Prevent loop from running too fast

    while API.running do
        -- ALWAYS yield at the start of each loop iteration to prevent crash
        wait(0.1)
        
        -- Skip if not running (check again after wait)
        if not API.running then break end
        
        -- Wrap entire loop body in pcall so errors don't stop the loop
        local success, err = pcall(function()
            -- Get player's current class
            local className = nil
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

            if not className or not Classes[className] then
                return -- Will continue to next loop iteration
            end

            -- Reset cooldowns if class changed
            if lastClassName ~= className then
                skillCooldowns = {}
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
                -- Skip invalid mobs
                if not mob or not mob.Parent then continue end
                if isFamiliar(mob) then continue end
                if isOwnedByOtherPlayer(mob) then continue end
                
                -- Skip TreeEnt when invincible
                if (mob.Name == 'BOSSTreeEnt' or mob.Name == 'CorruptedGreaterTree') and isTreeEntInvincible() then
                    continue
                end
                
                -- Skip Dire Problem boss unless enabled
                if mob.Name == 'BOSSDireBoarwolf' then
                    local allowBoss = _genv.DireProblemBossTarget == true
                    if not allowBoss then continue end
                end

                local collider = mob:FindFirstChild('Collider')
                if not collider then continue end

                local health = mob:FindFirstChild('HealthProperties')
                if not health then continue end
                
                local healthVal = health:FindFirstChild('Health')
                if not healthVal or not healthVal.Value or healthVal.Value <= 0 then continue end

                local dist = (collider.Position - head.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestMob = mob
                end
            end

            -- No valid mob found
            if not closestMob then return end
            
            local collider = closestMob:FindFirstChild('Collider')
            if not collider then return end

            local mobPos = collider.Position
            local currentTime = time()

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

            -- Get primary cooldown
            local primaryCooldown = PRIMARY_HOLD_MIN_INTERVAL
            local override = PrimaryHoldOverrides[className]
            if override then
                primaryCooldown = override.min or primaryCooldown
            end
            if CustomCooldowns[className] and primarySkillName and CustomCooldowns[className][primarySkillName] then
                primaryCooldown = CustomCooldowns[className][primarySkillName]
            end

            -- Check if Ultimate is ready
            if currentTime - ultimateCooldown >= ULTIMATE_COOLDOWN and hasEnergyForUltimate() then
                if Combat and closestMob and closestMob.Parent then
                    local currentCollider = closestMob:FindFirstChild('Collider')
                    if currentCollider then
                        pcall(function()
                            Combat:AttackWithSkill(67, 'Ultimate', currentCollider.Position, Vector3.new(0, 0, 0))
                        end)
                        ultimateCooldown = currentTime
                        skillCooldowns = {}
                    end
                end
                return
            end

            -- Find available skills
            local availableSkills = {}
            
            -- Check primary
            if primarySkillName and (currentTime - lastPrimaryFire >= primaryCooldown) then
                table.insert(availableSkills, { name = primarySkillName, isPrimary = true })
            end
            
            -- Check other skills
            for _, skillName in ipairs(Classes[className]) do
                local skillCD = getSkillCooldown(className, skillName)
                if skillCD then
                    local lastUsed = skillCooldowns[skillName] or 0
                    if currentTime - lastUsed >= skillCD then
                        table.insert(availableSkills, { name = skillName })
                    end
                end
            end

            -- Use a skill if available
            if #availableSkills > 0 and Combat then
                local skill = availableSkills[math.random(1, #availableSkills)]
                
                -- Validate mob still exists
                if closestMob and closestMob.Parent then
                    local currentCollider = closestMob:FindFirstChild('Collider')
                    local currentHead = character:FindFirstChild('Head')
                    
                    if currentCollider and currentHead then
                        local attackDir = (currentCollider.Position - currentHead.Position).Unit
                        
                        pcall(function()
                            Combat:AttackWithSkill(67, skill.name, currentCollider.Position, attackDir)
                        end)
                        
                        -- Track cooldown
                        if skill.isPrimary then
                            lastPrimaryFire = currentTime
                        else
                            skillCooldowns[skill.name] = currentTime
                        end
                        
                        lastAttackTime = currentTime
                    end
                end

                -- Random delay between attacks
                local randomDelay = MIN_ATTACK_DELAY + math.random() * (MAX_ATTACK_DELAY - MIN_ATTACK_DELAY)
                if randomDelay > 0 then
                    wait(randomDelay)
                end

                -- Occasional pause
                if math.random() < PAUSE_CHANCE then
                    wait(1 + math.random() * 2)
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
