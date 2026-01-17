# For-All

Universal Roblox script collection with smart game detection and organized folder structure.

---

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

---

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

---

## 🎮 Game Scripts

### 🌍 World Zero

A comprehensive script hub for World Zero with anticheat bypass and multiple features.

```lua
loadstring(game:HttpGet("https://api.junkie-development.de/api/v1/luascripts/public/ef2cd821474d60882ccc855716ff1a11c1bcfa0b77cbdffaf96f6a7aa8ffd5a2/download"))()
```

**Features:**
- Autofarm with auto zone selection 
- Kill Aura with configurable range (beta)
- Auto Bank & Auto Sell (beta)
- Tower/Dungeon automation (Atlantis, Grave, Prison, Klaus, Temple of Ruin) (beta)
- World Events automation (beta)
- Pet Aura (beta)
- Auto Doge (beta)
- Auto claim rewards

---

### ⚔️ Ultra Unfair

Comprehensive automation script for Ultra Unfair with GUI.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20Unfair/UU_Main.lua"))()
```

**Features:**
- **Auto Spin** - Automatic ability rolling with level filtering
- **Kill Aura** - Combat automation with hitbox extension
- **Auto Farm** - Zone-based farming with boss priority (beta)
- **Trait Reroll** - Target specific traits (Immortal, The One, etc.) (beta)
- **Smart Roll** - Gene rolling with cycle detection 
- **Auto Stats** - Automatic stat point allocation (beta)
- **Auto Aura** - Aura rolling and duplicate management (beta)
- **Auto Saitama** - Fist rolling and auto-fuse system (beta)

---

### 🐟 Farm A Fish

Advanced fishing automation with extensive customization options.

```lua
-- ═══════════════════════════════════════════════════════════════════════════
-- _G.FAF_SETTINGS & _G.FAF_TOGGLES - Pre-configure before running
-- ═══════════════════════════════════════════════════════════════════════════

_G.FAF_SETTINGS = _G.FAF_SETTINGS or {}
_G.FAF_TOGGLES = _G.FAF_TOGGLES or {}

-- Toggle defaults (set before loadstring to customize)
local FAF_TOGGLE_DEFAULTS = {
    AutoCollectFish = true,      -- Auto collect fish from nets
    AutoSellFish = true,         -- Auto sell fish
    AutoBuyBait = false,         -- Auto buy bait from shop (beta)
    AutoPlaceBait = false,       -- Auto place bait (beta)
    AutoOpenBaitPacks = true,    -- Auto open bait packs
    SmartBaitManagement = false, -- Smart bait optimization (beta)
    AutoCollectCrates = true,    -- Auto collect crates
    AutoCollectPickups = true,   -- Auto collect pickups
    EventAutoFeed = false,       -- Auto feed ALL event NPCs
    AlienScientistFeed = false,  -- Auto feed Alien Scientist ONLY
    AntiStaff = true,            -- Anti-staff protection (beta)
    AntiAFK = true,              -- Anti-AFK protection (beta)
    AutoFeedPets = true,         -- Auto feed pets 
    AutoBestPet = true,          -- Auto swap to best pets (beta)
    AutoEggs = false,            -- Auto egg management (beta)
    AutoUseGear = false,         -- Auto use gear (beta)
    AutoCraft = false,           -- Auto crafting system (beta)
    AutoRedeemCodes = true,      -- Auto redeem codes on startup 
    AutoMerchant = false,        -- Auto buy from travelling merchant (beta)
    RandomizeGUIName = true,     -- Randomize GUI name for security (beta) 
}

for key, defaultValue in pairs(FAF_TOGGLE_DEFAULTS) do
    if _G.FAF_TOGGLES[key] == nil then
        _G.FAF_TOGGLES[key] = defaultValue
    end
end

-- Settings defaults
local FAF_DEFAULTS = {
    -- Mutation filters for auto pickup
    AutoPickupOnlyMutations = {"Alien"},  -- Only pickup these mutations
    AutoPickupExcludeMutations = {},       -- Exclude these mutations
    
    -- Auto sell exclusions
    DontSellMutations = {"Christmas", "Alien"},
    DontSellBaitTypes = {"Christmas", "Robot", "Alien"},
    
    -- Auto craft settings
    AutoCraftEnabled = false,
    AutoCraftItems = {},
    AutoCraftInterval = 10,
    AutoCompleteCrafts = true,
    AutoSubmitIngredients = true,
    
    -- Merchant settings
    MerchantBuyAll = false,
    MerchantBuyItems = {},
    MerchantMaxSpend = 0,
    
    -- Teleport settings
    AutoTeleportToLocations = false,
    AutoReturnToPond = true,
    
    -- Craft protection
    ProtectCraftMaterials = true,
}

for key, defaultValue in pairs(FAF_DEFAULTS) do
    if _G.FAF_SETTINGS[key] == nil then
        _G.FAF_SETTINGS[key] = defaultValue
    end
end

loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Games/FarmAFish/FarmAFish.lua"))()
```

**Features:**
- Auto collect fish, crates, and pickups
- Mutation-based filtering (Golden, Diamond, Alien, etc.)
- Smart sell system with exclusion lists
- Event NPC feeding (Santa, Elf, Robot, Alien)
- Auto crafting with ingredient protection
- Travelling merchant automation
- Anti-staff and Anti-AFK protection

---

### 🎁 Pet Simulator 99 - Present Collector

Automatically collects hidden holiday presents.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Games/PetSim99/PS99Present.lua"))()
```

**Features:**
- Teleports to all hidden presents
- Auto-clicks presents for collection
- Includes special "Present" detection

---

### 🔦 Descent

Visual enhancement script for the Descent game.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Games/Descent/Descent.lua"))()
```

**Features:**
- Item drop highlighting
- Full bright lighting (removes darkness)
- Auto-refresh every 10 seconds

---

### 🎄 HoHo Hub (Miscellaneous)

External hub loader for various games.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Games/Misc/hohohub.lua"))()
```

## 🚧 Upcoming Games

- Soul Eater: Resonance
- Creatures of Sonaria
- Flashpoint
- Death Train
- Shindo Life
- Monster Slayer
- Break Your Bones

---

## 📜 Credits

`Based on Prometheus by Elias Oelschner` - [https://github.com/prometheus-lua/Prometheus](https://github.com/prometheus-lua/Prometheus)

