# For-All

Load the main script:

## 🚀 World Zero

```lua
loadstring(game:HttpGet("https://api.junkie-development.de/api/v1/luascripts/public/ef2cd821474d60882ccc855716ff1a11c1bcfa0b77cbdffaf96f6a7aa8ffd5a2/download"))()
```

## 🚀 Ultra Unfair

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20Unfair/UU_Main.lua"))()
```

## 🚀 Farm A Fish

```lua
- ═══════════════════════════════════════════════════════════════════════════
-- _G.FAF_SETTINGS - PUBLIC SETTINGS (Set BEFORE running script or modify anytime)
-- Users can share these settings easily by copying/pasting this table
-- ═══════════════════════════════════════════════════════════════════════════
if not _G.FAF_SETTINGS then
    _G.FAF_SETTINGS = {
        -- ═══════════════════════════════════════════════════════════════
        -- AUTO PICKUP FISH MUTATION FILTERS
        -- Control which fish to pick up based on mutations
        -- ═══════════════════════════════════════════════════════════════
        
        -- Only pickup fish with THESE mutations (leave empty {} to pickup all)
        -- Example: {"Golden", "Diamond"} will ONLY pickup Golden/Diamond fish
        AutoPickupOnlyMutations = {},
        
        -- EXCLUDE fish with these mutations from pickup (ignored if AutoPickupOnlyMutations is set)
        -- Example: {"Tiny"} will pickup all fish EXCEPT Tiny mutation
        AutoPickupExcludeMutations = {},
        
        -- ═══════════════════════════════════════════════════════════════
        -- AUTO SELL MUTATION EXCLUSIONS
        -- Fish with these mutations will NEVER be sold
        -- ═══════════════════════════════════════════════════════════════
        
        -- Don't sell fish with these mutations (add your own!)
        DontSellMutations = {
            "Christmas",  -- Keep for Santa NPC
            "Alien",      -- Keep for Alien NPC
            "Golden",     -- Valuable mutations
            "Diamond",
            "Void",
            "Cosmic",
            "Rainbow",
        },
        
        -- Don't sell fish from these bait types
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
        -- Example: {"DiamondCookie", "YolkBreaker", "AdvancedAutoFeeder"}
        AutoCraftItems = {},
        
        -- Interval between craft attempts (seconds)
        AutoCraftInterval = 10,
        
        -- ═══════════════════════════════════════════════════════════════
        -- CRAFT PROTECTION
        -- Don't sell items that are needed for crafting
        -- ═══════════════════════════════════════════════════════════════
        
        -- Protect items needed for crafting from being sold
        ProtectCraftMaterials = true,
    }
end
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/refs/heads/main/Random%20Scripts/FarmAFish.lua"))()
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
