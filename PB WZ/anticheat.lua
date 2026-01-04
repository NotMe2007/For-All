-- ============================================================================
-- World // Zero Anti-Cheat Analysis & Documentation
-- ============================================================================
-- This file documents the anti-cheat systems found in World // Zero's
-- decompiled code, detection methods, and bypass strategies used in this project.
--
-- DISCLAIMER: This is for educational/research purposes only.
-- Use responsibly and understand the risks of violating game ToS.
--
-- Last Updated: 2026-01-04
-- Sources: Decompiled game modules from World Zero/decompiled_data/
-- ============================================================================

-- ============================================================================
-- TABLE OF CONTENTS
-- ============================================================================
-- 1. OVERVIEW OF ANTI-CHEAT SYSTEMS
-- 2. SERVER-SIDE DETECTION (Combat Module)
-- 3. CLIENT-SIDE DETECTION (Animation/State)
-- 4. DATA VALIDATION (Profile Module)
-- 5. TELEPORT ANTI-CHEAT
-- 6. EXPLOITER FLAGGING SYSTEM
-- 7. BYPASS STRATEGIES (Current Implementations)
-- 8. SAFE PRACTICES & GUIDELINES
-- ============================================================================

local AntiCheatDocs = {}

-- ============================================================================
-- 1. OVERVIEW OF ANTI-CHEAT SYSTEMS
-- ============================================================================
--[[
World // Zero uses a HYBRID anti-cheat approach:
- Server-side validation for combat actions
- Client-side state monitoring for animations/movement
- DataStore flagging for persistent exploit tracking
- Remote event parameter validation

KEY MODULES INVOLVED:
├─ ReplicatedStorage.Shared.Combat         → Combat validation, kill aura detection
├─ ReplicatedStorage.Shared.Profile        → Data exploit detection, prestige exploits
├─ Server.TeleportAntiCheat               → Position/teleport validation
├─ Client.Actions                          → Cooldown tracking, state validation
├─ Client.Animations                       → Humanoid state monitoring

DETECTION CATEGORIES:
1. KillAura Detection - Automated attack pattern detection
2. AutoFarmer Detection - Suspicious targeting behavior
3. PrestigeExploit - Prestige manipulation attempts
4. DataExploit - Character data tampering
5. TeleportAntiCheat - Position/movement anomalies
]]

AntiCheatDocs.Overview = {
    DetectionTypes = {
        "KillAura",           -- Detected via Combat module
        "AutoFarmer",         -- Detected via AttackTarget remote
        "PrestigeExploit",    -- Detected via Profile module
        "DataExploit",        -- Detected via Profile module (character creation)
        "TeleportAntiCheat",  -- Detected via Server.TeleportAntiCheat
    },
    
    ConsequenceChain = {
        [1] = "AddCollectionFlag (persistent flag on account)",
        [2] = "Kick with warning ('Next time it's a ban!')",
        [3] = "DataStore logging to 'AllExploiters'",
        [4] = "Potential IP ban (Admin command exists)",
    }
}

-- ============================================================================
-- 2. SERVER-SIDE DETECTION (Combat Module)
-- ============================================================================
--[[
SOURCE: ReplicatedStorage_Shared_Combat_ModuleScript.lua (Lines 235-290)

The Combat module validates attacks on the server. Key detections:

A) KILL AURA DETECTION (Lines 268-275)
   The Attack.OnServerEvent has a 5th parameter check:
   
   ```lua
   function var214(arg1_30, arg2, arg3, arg4, arg5)
       if arg5 ~= 67 then  -- MAGIC NUMBER CHECK
           if not tbl_7_upvr[arg1_30] then
               var17_upvw:AddCollectionFlag(arg1_30, "killaura")
               tbl_7_upvr[arg1_30] = true
               task.delay(math.random(2, 10), function()
                   -- Log to DataStore "AllExploiters"
                   arg1_30:Kick("Next time it's a ban!")
               end)
           end
       end
   end
   ```
   
   The game expects a specific 5th parameter (67) to be passed with attack remotes.
   If this parameter is missing or incorrect, it flags as "killaura".

B) AUTOFARMER DETECTION (Lines 276-286)
   The AttackTarget remote has NO valid parameter - ANY call is flagged:
   
   ```lua
   function var214(arg1_32)
       if not tbl_7_upvr[arg1_32] then
           var17_upvw:AddCollectionFlag(arg1_32, "autofarmer")
           tbl_7_upvr[arg1_32] = true
           task.delay(math.random(2, 10), function()
               arg1_30:Kick("Next time it's a ban!")
           end)
       end
   end
   script.AttackTarget.OnServerEvent:connect(var214)
   ```
   
   The AttackTarget remote appears to be a HONEYPOT - any script that calls it
   is immediately flagged. Real game attacks use the Attack remote, not AttackTarget.

C) EXPLOITER RECORDING SYSTEM
   Detected exploiters are logged to DataStore "Expl2" with:
   - UserId, Name, DisplayName
   - Timestamp
   - Guild tag
   - Type of exploit
   - Times caught counter
]]

AntiCheatDocs.CombatDetection = {
    -- The magic number expected by the server
    AttackMagicNumber = 67,
    
    -- Honeypot remotes - DO NOT USE
    HoneypotRemotes = {
        "AttackTarget",  -- Any call = instant flag
    },
    
    -- Safe remotes (with proper parameters)
    SafeRemotes = {
        Attack = {
            -- arg1: player (auto-filled)
            -- arg2: skill id
            -- arg3: skill name
            -- arg4: target position
            -- arg5: 67 (magic number)
        },
        DidDodge = {
            -- Rate limited to once per 4 seconds
            -- Sets TeleportAntiCheat ignore for 2 seconds
        },
    },
    
    -- Detection delay is randomized (2-10 seconds)
    -- This makes it harder to pinpoint exactly what triggered detection
    DetectionDelayRange = { min = 2, max = 10 },
}

-- ============================================================================
-- 3. CLIENT-SIDE DETECTION (Animation/State)
-- ============================================================================
--[[
SOURCE: Client_Actions.lua, Client_Anamations.lua

The client monitors Humanoid states that could indicate flight/noclip:

A) HUMANOID STATE DISABLING (Client_Actions.lua Lines 192-198)
   The game disables certain humanoid states on spawn:
   
   ```lua
   u27.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
   u27.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
   u27.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
   u27.Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
   u27.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
   u27.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
   ```

B) ANIMATION STATE MONITORING (Client_Anamations.lua Lines 806-820)
   The game tracks Running, RunningNoPhysics, and Freefall states:
   
   ```lua
   local Running = Enum.HumanoidStateType.Running
   elseif Running == Enum.HumanoidStateType.Running or 
          Running == Enum.HumanoidStateType.RunningNoPhysics or 
          Running == Enum.HumanoidStateType.Freefall then
   ```

   Extended Freefall time could trigger detection.

C) VELOCITY MONITORING
   BodyVelocity objects are created/monitored:
   ```lua
   local BodyVelocity_upvr = Instance.new("BodyVelocity")
   BodyVelocity_upvr.maxForce = Vector3.new(999999, 0, 999999)
   ```
   
   The game uses BodyVelocity for legitimate movement - BUT sudden/impossible
   velocities could be flagged.
]]

AntiCheatDocs.ClientStateDetection = {
    -- States that are monitored or could be flagged
    MonitoredStates = {
        "Freefall",      -- Extended freefall = suspicious
        "Running",       -- Expected during normal movement
        "Jumping",       -- Normal during jump/flight
    },
    
    -- Bypass strategy: Manage humanoid state during flight
    StateManagememt = {
        -- When flying UP: Set to Jumping
        -- When moving HORIZONTAL: Set to Running  
        -- NEVER stay in Freefall for extended periods
    },
}

-- ============================================================================
-- 4. DATA VALIDATION (Profile Module)
-- ============================================================================
--[[
SOURCE: Profile.lua (Lines 1460-1480)

The Profile module validates character data during creation:

A) UTF-8 VALIDATION FOR EXPLOITS
   ```lua
   for _, v318 in pairs(v317) do
       if typeof(v318) == "string" and utf8.len(v318) == nil then
           require(game.ReplicatedStorage.Shared.Profile):AddCollectionFlag(p310, "DataExploit")
           p310:Kick("I got you now!")
           return
       end
   end
   ```
   
   Invalid UTF-8 strings in character customization = instant kick + flag

B) PRESTIGE EXPLOIT DETECTION (Lines 510-545)
   The Prestige event has server-side validation:
   
   ```lua
   script.Prestige.OnServerEvent:Connect(function(u119, p120)
       if p120 then  -- If invalid prestige attempt
           local u121 = {
               ["Type"] = "PrestigeExploit",
               ["TimesCaught"] = 1
           }
           u47:UpdateAsync("AllExploiters", ...)
           u140:GetProfile(u119).Prestige.Value = 0  -- Reset prestige
           u140:AddCollectionFlag(u119, "PrestigeExploiter")
           u119:Kick("Next time it's a ban!")
       end
   end)
   ```
]]

AntiCheatDocs.DataValidation = {
    -- Flagging types in Profile module
    FlagTypes = {
        "DataExploit",         -- Invalid character data
        "PrestigeExploiter",   -- Prestige manipulation
        "killaura",            -- Automated attacks
        "autofarmer",          -- Automated targeting
    },
    
    -- Collection flags (persistent on account)
    -- These are stored in player profile and persist across sessions
}

-- ============================================================================
-- 5. TELEPORT ANTI-CHEAT
-- ============================================================================
--[[
SOURCE: Combat module references Server.TeleportAntiCheat

The TeleportAntiCheat module tracks player positions and validates teleports:

A) DODGE IMMUNITY SYSTEM (Lines 211-222)
   ```lua
   script.DidDodge.OnServerEvent:Connect(function(arg1_25)
       if tbl_11_upvr[arg1_25.Name] and time() - tbl_11_upvr[arg1_25.Name] < 4 then
           -- Rate limited - can only dodge once per 4 seconds
       else
           tbl_11_upvr[arg1_25.Name] = time()
           var13_upvw:SetIgnorePlayer(arg1_25, true)  -- Ignore for 2 seconds
           task.delay(2, function()
               var13_upvw:SetIgnorePlayer(arg1_25)   -- Re-enable checking
           end)
       end
   end)
   ```
   
   When a player dodges, the TeleportAntiCheat ignores them for 2 seconds.
   This creates a window for legitimate rapid movement.

B) POSITION VALIDATION
   The game likely checks:
   - Distance traveled per tick
   - Position relative to ground
   - Sudden position changes
]]

AntiCheatDocs.TeleportAntiCheat = {
    -- Dodge provides 2-second immunity from position checks
    DodgeImmunityDuration = 2,
    
    -- Rate limit on dodge remote
    DodgeRateLimit = 4,  -- seconds
    
    -- Bypass strategy: Trigger DidDodge before rapid position changes
    -- But be aware of the rate limit!
}

-- ============================================================================
-- 6. EXPLOITER FLAGGING SYSTEM
-- ============================================================================
--[[
The game maintains a persistent exploit tracking system:

A) DATASTORE: "Expl2" / "AllExploiters"
   All detected exploiters are logged with:
   ```lua
   {
       Id = player.UserId,
       Name = player.Name,
       DisplayName = player.DisplayName,
       Time = DateTime.now().UnixTimestamp,
       Guild = player:GetAttribute("GuildTag"),
       Type = "KillAura",  -- or other type
       TimesCaught = 1     -- Increments each detection
   }
   ```

B) COLLECTION FLAGS
   AddCollectionFlag() adds persistent flags to player profile:
   - "killaura"
   - "autofarmer"
   - "PrestigeExploiter"
   - "DataExploit"
   
   These may be checked on login or used for banning decisions.

C) ADMIN COMMANDS
   The game has admin commands for:
   - Ban / Unban
   - IpBan / IpUnBan
   - Kick
   These suggest staff review of flagged accounts.
]]

AntiCheatDocs.FlaggingSystem = {
    DataStores = {
        "Expl2",           -- Exploiter tracking
        "AllExploiters",   -- Legacy/additional tracking
    },
    
    -- Flags are PERSISTENT - they don't go away
    -- Multiple catches increment TimesCaught
}

-- ============================================================================
-- 7. BYPASS STRATEGIES (Current Implementations)
-- ============================================================================
--[[
This section documents how our scripts avoid detection:

A) KILL AURA BYPASS (Tests/killaura.lua)
   - Uses legitimate Combat module via pcall require
   - Calls Combat:AttackWithSkill() which is the proper API
   - Does NOT use raw remote events directly
   - Adds timing variance to appear human-like
   
   ```lua
   -- SAFE: Using the game's own Combat module
   local ok, Combat = pcall(function() 
       return require(ReplicatedStorage.Shared.Combat) 
   end)
   if ok then
       Combat:AttackWithSkill(skillId, skillName, targetPosition, direction)
   end
   ```

B) AUTO FARM BYPASS (Tests/autofarm.lua)
   - Manages humanoid state during flight (updateMovementAnimation)
   - Uses gradual movement with velocity interpolation
   - Adds random variance to speed and positioning
   - Wobble/micro-pause for human-like behavior
   
   ```lua
   -- Prevent falling detection during flying
   local function updateMovementAnimation(velocity)
       local humanoid = character:FindFirstChild('Humanoid')
       if velocity.Y > 5 then
           humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
       elseif Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 3 then
           humanoid:ChangeState(Enum.HumanoidStateType.Running)
       end
   end
   ```

C) ANTI-DETECTION TIMING PATTERNS
   Both scripts implement:
   - Timing variance (15-25% random adjustment)
   - Pause chances (random brief stops)
   - Burst behavior (occasional speed bursts)
   - Combo breaking (don't always complete full combos)
   
D) COOLDOWN RESPECT
   Our scripts track and respect skill cooldowns:
   - Using decompiled cooldown values
   - Adding slight buffer to ensure validity
   - Never firing faster than game expects
]]

AntiCheatDocs.BypassStrategies = {
    -- DO use the Combat module API, not raw remotes
    UseCombatModule = true,
    
    -- DO manage humanoid state during flight
    ManageHumanoidState = true,
    
    -- DO add timing variance to all actions
    TimingVariance = {
        minVariance = 0.15,  -- 15% minimum
        maxVariance = 0.25,  -- 25% maximum
    },
    
    -- DO NOT use AttackTarget remote (honeypot)
    AvoidHoneypots = { "AttackTarget" },
    
    -- DO NOT stay in Freefall state for extended periods
    MaxFreefallDuration = 2.0,  -- seconds before state change
    
    -- DO NOT use BodyVelocity with speeds above normal walkspeed
    -- The game monitors BodyVelocity for impossible/sudden velocities
    -- Normal walkspeed is ~16-20 studs/sec, anything above is suspicious
    AvoidMeleeReach = {
        reason = "BodyVelocity monitored for abnormal speeds",
        maxSafeSpeed = 20,  -- studs/sec, normal walkspeed
        detectedAt = 80,    -- Original melee reach speed - DETECTED
    },
}

-- ============================================================================
-- 8. SAFE PRACTICES & GUIDELINES
-- ============================================================================

AntiCheatDocs.SafePractices = {
    -- GENERAL RULES
    Rules = {
        "1. Always use pcall when accessing game modules",
        "2. Never call remotes directly - use game's API modules",
        "3. Add variance to ALL timing-based actions",
        "4. Manage humanoid state during unnatural movement",
        "5. Respect cooldowns - never fire faster than the game",
        "6. Use gradual movement, not instant teleports",
        "7. Avoid known honeypot remotes (AttackTarget)",
        "8. Add random pauses to simulate human behavior",
        "9. Never use BodyVelocity with speeds above walkspeed (~20 studs/sec)",
        "10. Don't extend melee reach beyond game's ~10 stud limit",
    },
    
    -- RECOMMENDED VARIANCE VALUES
    VarianceConfig = {
        attackTiming = 0.18,      -- 18% variance on attacks
        movementSpeed = 0.20,     -- 20% variance on movement
        positionOffset = 0.10,    -- 10% variance on positions
        cooldownBuffer = 0.05,    -- 5% extra buffer on cooldowns
    },
    
    -- STATE MANAGEMENT
    HumanoidStateManagement = {
        -- During upward movement
        movingUp = "Jumping",
        
        -- During horizontal movement
        movingHorizontal = "Running",
        
        -- While stationary in air (brief only)
        hovering = "Jumping",  -- NOT Freefall
        
        -- Avoid extended Freefall
        maxFreefallTime = 1.5,  -- seconds
    },
}

-- ============================================================================
-- DETECTION RISK LEVELS
-- ============================================================================

AntiCheatDocs.RiskLevels = {
    -- LOW RISK (Our implementations)
    LowRisk = {
        "Using Combat module API (not raw remotes)",
        "Respecting cooldowns with buffer",
        "Adding timing variance",
        "Managing humanoid states",
    },
    
    -- MEDIUM RISK (Use with caution)
    MediumRisk = {
        "Extended air time without state management",
        "Perfectly consistent attack timing",
        "Always completing full combos",
        "Speed slightly above normal walkspeed",
    },
    
    -- HIGH RISK (Will likely trigger detection)
    HighRisk = {
        "Using AttackTarget remote",
        "Missing magic number (67) on Attack remote",
        "Extended Freefall state",
        "Invalid UTF-8 in character data",
        "Prestige value manipulation",
        "Instant teleportation without DidDodge",
    },
}

-- ============================================================================
-- QUICK REFERENCE
-- ============================================================================

AntiCheatDocs.QuickReference = {
    -- Combat magic number
    ATTACK_MAGIC_NUMBER = 67,
    
    -- Dodge immunity window
    DODGE_IMMUNITY = 2,  -- seconds
    
    -- Max safe freefall
    MAX_FREEFALL = 1.5,  -- seconds
    
    -- Honeypot remotes
    HONEYPOTS = { "AttackTarget" },
    
    -- Safe states during flight
    SAFE_STATES = { "Jumping", "Running" },
    
    -- Timing variance range
    VARIANCE = { 0.15, 0.25 },
}

-- ============================================================================
-- EXPORT FOR DOCUMENTATION
-- ============================================================================

-- This module is documentation-only and provides no runtime functionality
-- It serves as a reference for understanding and working with World // Zero's
-- anti-cheat systems.

_G.AntiCheatDocs = AntiCheatDocs

return AntiCheatDocs
