# For-All

Universal Roblox script collection with smart game detection and organized folder structure.

## 📁 Repository Structure

```
For-All/
├── Universal/           # Tools that work with ALL games
│   └── dex.lua          # Universal Dex++ with smart game detection
├── Games/               # Game-specific scripts
│   ├── WorldZero/       # World Zero scripts
│   ├── UltraUnfair/     # Ultra Unfair scripts
│   ├── FarmAFish/       # Farm A Fish scripts
│   ├── PetSim99/        # Pet Simulator 99 scripts
│   ├── Descent/         # Descent scripts
│   └── Misc/            # Miscellaneous scripts
└── README.md
```

## 🔧 Universal Tools

### Dex++ (Universal Edition)
Smart debugging tool that auto-detects the current game and organizes output accordingly.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Universal/dex.lua"))()
```

**Features:**
- Auto-detects game name from PlaceId
- Organizes decompiled scripts by game name
- Works with ANY Roblox game

## 🎮 Game Scripts

### 🚀 World Zero

```lua
loadstring(game:HttpGet("https://api.junkie-development.de/api/v1/luascripts/public/ef2cd821474d60882ccc855716ff1a11c1bcfa0b77cbdffaf96f6a7aa8ffd5a2/download"))()
```

### 🚀 Ultra Unfair

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Games/UltraUnfair/UU_Main.lua"))()
```

### 🚀 Farm A Fish

```lua

-- ═══════════════════════════════════════════════════════════════════════════
-- _G.FAF_SETTINGS - PUBLIC SETTINGS (Set BEFORE running script or modify anytime)
-- Users can share these settings easily by copying/pasting this table
-- Pre-set your settings BEFORE the loadstring, they will be saved yey
-- ═══════════════════════════════════════════════════════════════════════════

-- Initialize table if not exists (preserves user settings from loadstring)
_G.FAF_SETTINGS = _G.FAF_SETTINGS or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- _G.FAF_TOGGLES - EXTERNAL FEATURE TOGGLES (Anti-detection friendly)
-- Set these BEFORE or AFTER running script to enable/disable features externally
-- All toggles are checked in real-time by their respective modules
-- ═══════════════════════════════════════════════════════════════════════════

_G.FAF_TOGGLES = _G.FAF_TOGGLES or {}

-- Default toggle states (only applied if not already set)
local FAF_TOGGLE_DEFAULTS = {
    -- ═══════════════════════════════════════════════════════════════
    -- MASTER TOGGLES - Control all features externally
    -- Set any of these to false to instantly disable that module
    -- These defaults are used when script first runs
    -- ═══════════════════════════════════════════════════════════════
    
    AutoCollectFish = true,      -- Auto collect fish from nets
    AutoSellFish = true,         -- Auto sell fish
    AutoBuyBait = false,         -- Auto buy bait from shop
    AutoPlaceBait = false,       -- Auto place bait
    AutoOpenBaitPacks = true,    -- Auto open bait packs
    SmartBaitManagement = false, -- Smart bait optimization
    AutoCollectCrates = true,    -- Auto collect crates
    AutoCollectPickups = true,   -- Auto collect pickups
    EventAutoFeed = false,       -- Auto feed ALL event NPCs (Santa, Elf, Robot, Alien)
    AlienScientistFeed = false,  -- Auto feed Alien Scientist ONLY (protects alien fish from selling)
    AntiStaff = true,            -- Anti-staff protection
    AntiAFK = true,              -- Anti-AFK protection
    AutoFeedPets = true,         -- Auto feed pets
    AutoBestPet = true,          -- Auto swap to best pets
    AutoEggs = false,            -- Auto egg management
    AutoUseGear = false,         -- Auto use gear
    AutoCraft = false,           -- Auto crafting system
    AutoRedeemCodes = true,      -- Auto redeem codes on startup
    AutoMerchant = false,        -- Auto buy from travelling merchant
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECURITY - GUI Name Randomization
    -- ═══════════════════════════════════════════════════════════════
    RandomizeGUIName = true,    -- Randomize GUI name to avoid detection
}

-- Apply toggle defaults only for toggles not already defined by user
for key, defaultValue in pairs(FAF_TOGGLE_DEFAULTS) do
    if _G.FAF_TOGGLES[key] == nil then
        _G.FAF_TOGGLES[key] = defaultValue
    end
end

-- Default settings (only applied if user hasn't set them)
local FAF_DEFAULTS = {
    -- ═══════════════════════════════════════════════════════════════
    -- AUTO PICKUP FISH MUTATION FILTERS
    -- Control which fish to pick up based on mutations
    -- ═══════════════════════════════════════════════════════════════
    
    -- Only pickup fish with THESE mutations (leave empty {} to pickup all)
    -- Special option: {"All"} will pickup ALL mutations but still respect exclude filter
    -- Available mutations:
    --   "All" (special: keeps all but still checks exclude filter)
    --   "Golden", "Diamond", "Void", "Rainbow", "Albino", "Colossal",
    --   "Tiny", "Electric", "Frozen", "Fiery", "Spectral", "Cosmic",
    --   "Christmas", "Alien"
    -- Example: {"Golden", "Diamond"} will ONLY pickup Golden/Diamond fish
    -- Example: {"All"} will pickup all fish, but exclude filter still applies
    AutoPickupOnlyMutations = {"Alien"},
    
    -- EXCLUDE fish with these mutations from pickup
    -- This filter is ALWAYS checked, even when AutoPickupOnlyMutations = {"All"}
    -- Available mutations:
    --   "Golden", "Diamond", "Void", "Rainbow", "Albino", "Colossal",
    --   "Tiny", "Electric", "Frozen", "Fiery", "Spectral", "Cosmic",
    --   "Christmas", "Alien"
    -- Example: {"Tiny"} will pickup all fish EXCEPT Tiny mutation
    AutoPickupExcludeMutations = {},
    
    -- ═══════════════════════════════════════════════════════════════
    -- AUTO SELL MUTATION EXCLUSIONS
    -- Fish with these mutations will NEVER be sold
    -- ═══════════════════════════════════════════════════════════════
    
    -- Don't sell fish with these mutations (add your own!)
    -- Available mutations:
    --   "Golden", "Diamond", "Void", "Rainbow", "Albino", "Colossal",
    --   "Tiny", "Electric", "Frozen", "Fiery", "Spectral", "Cosmic",
    --   "Christmas", "Alien"
    DontSellMutations = {
        "Christmas",  -- Keep for Santa NPC
        "Alien",      -- Keep for Alien NPC
    },
    
    -- Don't sell fish from these bait types
    -- Available bait types:
    --   Regular: "Starter", "Novice", "Reef", "DeepSea", "Koi", "River",
    --            "Puffer", "Seal", "Glo", "Ray", "Octopus", "Axolotl",
    --            "Jelly", "Whale", "Shark"
    --   Event:   "Christmas", "Robot", "Alien"
    DontSellBaitTypes = {
        "Christmas",
        "Robot",
        "Alien",
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- AUTO CRAFT SYSTEM
    -- Items to automatically craft (will craft dependencies first!)
    -- ═══════════════════════════════════════════════════════════════
    
    -- Enable/disable auto crafting
    AutoCraftEnabled = false,
    
    -- Items to auto craft (priority order - first item has highest priority)
    -- Use exact item names from the game
    -- Available craftable items:
    --   Gears: "AdvancedAutoFeeder", "DiamondCookie", "YolkBreaker", 
    --          "EggHatcher", "TimeJumper", "NetRetractor", "ShieldLock",
    --          "FoodTray"
    -- Example: {"DiamondCookie", "YolkBreaker", "AdvancedAutoFeeder"}
    AutoCraftItems = {},
    
    -- Interval between craft attempts (seconds)
    AutoCraftInterval = 10,
    
    -- Auto-complete existing crafts before starting new ones
    AutoCompleteCrafts = true,
    
    -- Auto-submit items when correct ingredients are equipped
    AutoSubmitIngredients = true,
    
    -- ═══════════════════════════════════════════════════════════════
    -- TRAVELLING MERCHANT
    -- Auto-buy items from travelling merchant when available
    -- ═══════════════════════════════════════════════════════════════
    
    -- Buy all available merchant items
    MerchantBuyAll = false,
    
    -- Specific items to buy (empty = buy nothing unless BuyAll is true)
    -- Use item stock IDs like: "bait_Octopus", "egg_Golden", etc.
    MerchantBuyItems = {},
    
    -- Maximum coins to spend per merchant visit (0 = unlimited)
    MerchantMaxSpend = 0,
    
    -- ═══════════════════════════════════════════════════════════════
    -- AUTO TELEPORT TO LOCATIONS
    -- Automatically teleport to relevant locations before actions
    -- ═══════════════════════════════════════════════════════════════
    
    -- Enable automatic teleportation to locations
    AutoTeleportToLocations = false,
    
    -- Automatically return to pond after completing actions
    AutoReturnToPond = true,
    
    -- ═══════════════════════════════════════════════════════════════
    -- CRAFT PROTECTION
    -- Don't sell items that are needed for crafting
    -- ═══════════════════════════════════════════════════════════════
    
    -- Protect items needed for crafting from being sold
    ProtectCraftMaterials = true,
}

-- Apply defaults only for settings not already defined by user
for key, defaultValue in pairs(FAF_DEFAULTS) do
    if _G.FAF_SETTINGS[key] == nil then
        _G.FAF_SETTINGS[key] = defaultValue
    end
end
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Games/FarmAFish/FarmAFish.lua"))()
```

### 😎 Upcoming

- Soul Eater: Resonance
- Creatures of Senaria
- Flashpoint
- Death Train
- Shindo Life
- Monster Slayer
- Break your bones

`Based on Prometheus by Elias Oelschner, https://github.com/prometheus-lua/Prometheus`
