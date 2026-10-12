# ZenX Tester Loader: Supported Games

One loader for every ZenX tester build. It detects the game you're in and loads the right script. Run the same line in every game:

```lua
Script__Key___ = "<your tester key>"
loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/Games/Loader/ZenX%20Tester%20Loader.lua"))()
```

- **No key or a wrong key:** nothing happens. That's intended, and it isn't a bug.
- **Unsupported game:** you get a "This game is not supported" popup and a line in the F9 console.
- **Hops:** for hubs that reload themselves after a teleport (Gorilla Warfare, Hunt Giant Fish, Route 06, Wanted, World // Zero, RIVALS), the loader makes the reload come back as the **tester** build. PS99, Break Your Bones and Watch Number Go Up reload the **public** build after a hop, so re-run the tester loader there. Every other game needs a manual re-execute after a hop or rejoin.
- **Your report:** the loader prints `[ZenX tester V1] <game> | GameId ... | PlaceId ...` in the console. Copy that line into every bug report.
- **Script version:** shown in the hub window title or on its Info/Settings tab.

## Before you report anything

1. **Is it really broken?** Rejoin and re-execute once. Many "bugs" are a stale copy or a half-loaded game.
2. **Is it your config?** Delete the game's config folder in your executor's `workspace` folder (listed per game below). Re-execute to get fresh defaults.
3. **Is it your cache?** Clear the executor's cache, or restart the executor. raw.githubusercontent can serve an old build for ~5 minutes after an update.
4. **Still broken?** Open the F9 console (or the executor console), reproduce it, and copy the **red/yellow lines**. Then report using the template in the tester doc.

## Game list

| # | Game | Script version | Status |
|---|------|----------------|--------|
| 1 | Adopt Me! | V1 | New, needs testing |
| 2 | Anime Card Clash | 2026.08.27 | Stable |
| 3 | Anime Squadron (Anime Squad) | V1 | New, needs testing |
| 4 | Anime Warriors III | V0.4.3 | Stable |
| 5 | Attack on Titan Revolution | V5 | Combat tab experimental |
| 6 | Bee Swarm Simulator | 0.0.19 | Stable |
| 7 | Blade Ball | V0.7.1 | **Needs testing** |
| 8 | Break Your Bones | V1 | Stable |
| 9 | Catch And Tame | V1 | **Needs testing** |
| 10 | Claw Fishing | V6 | **Needs testing** |
| 11 | Creatures of Sonaria | V0.7.6 | Stable |
| 12 | Driving Empire | V4 | **Needs testing** |
| 13 | Farm a Fish | V2.5.0.2 | Stable (public build) |
| 14 | Final Swarm | V3 | Stable |
| 15 | Gorilla Warfare (Survive a Million Monkeys) | V2 | **Needs testing** (new abilities) |
| 16 | Grow a Garden 2 | V0.1.3 | Stable |
| 17 | Hatch 1 Million Chickens | (title only) | Stable |
| 18 | Hunt Giant Fish | V3 | **Needs testing** |
| 19 | Jujutsu: Zero | V3 | Stable |
| 20 | My Cafe | V1 | **Needs testing** |
| 21 | Pay Your Debts! | V1 | **Needs testing** |
| 22 | Pet Simulator 99 | v2.0 | Stable (Season Pass untested) |
| 23 | Pop & Collect (Pop Bubbles) | (none) | Experimental |
| 24 | Reeled | V5 | **Needs testing** |
| 25 | RIVALS | v4.3 | Stable |
| 26 | Route 06 | V1 | **Needs testing** |
| 27 | Soul Eater: Resonance | V2 | Stable |
| 28 | Soul Hero | V4 | **Needs testing** |
| 29 | Steal An Egg | V5 | Stable |
| 30 | The Lost Land | V1 | Stable (no GUI) |
| 31 | Ultra Unfair | V1 | Stable |
| 32 | Wanted | V0.1.1 | **Needs testing** |
| 33 | Watch Number Go Up | V1 | Stable |
| 34 | Wingblade Arena | V1 | Stable |
| 35 | World // Zero | V1 | Stable |

**Status key:**
- **Needs testing:** new or changed builds that haven't been played in-game much yet. Your reports matter most here.
- **Stable:** in use. Still report anything off.

**Common keys** (most SeneX hubs): **RightShift** opens/closes the UI. **End** is PANIC and turns everything off. Most hubs also have a "Stop ALL / Unload" button in Settings. Use it before re-executing.

---

## 1. Adopt Me! (V1)
Farms pet and baby needs with the game's own timers. It also rotates Full Grown pets, can buy eggs with bucks, and claims paychecks, daily login, achievements and battle pass. It never trades, sells or releases.

**Features:**
- Auto pet care (Salon/School/petting tasks)
- Auto switch to the next pet when one is Full Grown
- Auto buy egg with a never-spend-below floor
- Auto Baby (play as a baby, clear your own needs)
- Optional eating, using only the food you pick
- Auto claims
- Anti-AFK and quick travel

**Notes:**
- Needs are timed by the server, so tasks take real time. "Slow" is normal.
- Items are only used up if you turn on Auto Buy Egg or Allow eating.
- When reporting, say which tab, toggle and ailment was active.

## 2. Anime Card Clash (2026.08.27)
Collects world pickups (elixirs, potions, boxes) with priority/exclude filters. It also runs crystal farm, exploration, story progress, Bizarre Dungeon runs, claims and potion crafting on timers.

**Notes:**
- The collector only runs after you press **Start** on the Home tab.
- Config: `workspace/ZenX/ACC_Config.json`. Delete it to reset.
- Leave **Auto Update / Update URL** blank.
- Auto Rejoin doesn't re-run the script. Put the loader in autoexec if you test it.

## 3. Anime Squadron (V1)
Tower-defense farm. It turns on the game's own Autoplay bot, plus auto start/replay/next act, auto upgrade, auto summon, auto ult and a game speed setter.

**Notes:**
- Run it **inside a match**. The lobby isn't supported, and the loader tells you so.
- 3x speed needs the 3x Speed gamepass.
- Re-run the loader after every new match server.

## 4. Anime Warriors III (V0.4.3)
Full hub covering:
- Auto farm, kill aura, priority queue
- Eggs, quests, shop, trait reroller
- Raids and events (Journey's End, Gauntlet, boss raids, Summer Invasion, Infiltration, Guild Boss, Stands)

**Notes:**
- Only loads in the main world place; anywhere else it prints a warning.
- "Auto Hatch - server" needs the game's auto-hatch unlock. Otherwise use "Auto Open - manual loop".
- Panic: "Stop ALL server auto". Use "Unload ZenX" before re-running.

## 5. Attack on Titan Revolution (V5)
Hub economy:
- Host/join missions
- Claim quests, battle pass and titles
- Sell, shop buys, crates, gold upgrades, heal injuries

V5 also adds an in-mission Combat auto farm.

**Notes:**
- Start in the hub. It doesn't follow you into a mission, so run the loader again inside the mission for Combat/ESP.
- Combat needs an executor with actor support (`getactors`/`run_on_actor`). Without it, the tab shows "Engine unavailable" and the rest still works. **Say which executor** if Combat fails.
- Claims are sent blind. "Nothing happened" can be normal if you weren't eligible.
- No config saving, so toggles reset every run.

## 6. Bee Swarm Simulator (0.0.19)
Macro V3 on SeneX. It covers:
- Field farming with auto convert
- Quests, planters, bosses/Vicious Bee
- Hive/royal jelly, blender, stickers, amulets
- Server hop and your own Discord webhook

**Notes:**
- Config: `workspace/macrov3/`. Delete the folder to reset.
- Server hop only resumes if the loader is in **autoexec**.
- Hidden stickers are per account, so hopping won't find new ones on the same account.
- Some travel is detectable and the game has server-side cheater flags. **Use an alt.**

## 7. Blade Ball (V0.7.1)
Auto parry with:
- Pre-parry and clash spam
- Target choice (mouse, farthest, closest, bounty...)
- Curve shots and auto ability
- Lobby auto vote/claim

**Notes:**
- Execute **only in the lobby or while spectating**. Never mid-round.
- Set "Which Block key to press" (F or MouseButton1).
- LOBBY auto vote/claim has kick history. **Alt only.**
- Use the Training place to test parry timing.
- The DEBUG tab has logging/recording for reports.

## 8. Break Your Bones (V1)
Farms bone breaks (slam or slide-push) with auto cash-out. Also automates:
- Spells, upgrades, rebirths
- Quests, pals, forge, free rewards

**Notes:**
- Forge/target modifiers need 1 rebirth.
- Daily Chest needs the game's group joined.
- If quest progress goes negative, press **Restart Quest**.
- After a teleport it reloads the **public** build. Re-run the tester loader instead.

## 9. Catch And Tame (V1)
Covers:
- Auto lasso/catch by rarity, minigames, fishing
- Submarine, farming, fruit/food buying
- Pet ESP and island teleports

**Notes:**
- Everything is OFF at start.
- Hold the paint gun/duster for those features. Enter the submarine yourself.
- Auto Fish: stand at the water, facing it, with the rod in your backpack.
- Settings warns you if the game updated. Report that warning.

## 10. Claw Fishing (V6)
Drives the boat and catches fish by rarity/value filters. It also:
- Docks to deposit and collect cash
- Buys gear, aquarium upgrades and rebirths
- Dodges tsunamis

**Notes:**
- Finish the game tutorial by hand first.
- EXPERIMENTAL options (insta catch, fast claw drop, Ocean Gate) are the risky ones. Report them separately.
- Panic and Unload are in Settings.

## 11. Creatures of Sonaria (V0.7.6)
Covers:
- Infinite stamina/oxygen
- Damage and debuff protection
- ESP
- AFK auto eat/drink with smart movement
- Auto collect and auto buy

**Notes:**
- Spawn in with a creature before turning on survival/farm features.
- Toggles with a warning sign are riskier. **Alt only.**
- Don't spam toggles.

## 12. Driving Empire (V4)
Job farm: it drives your own car to ATMs, deliveries and crime scenes (Criminal, Police and Delivery money). Also has vehicle mods, ESP and teleports.

**Notes:**
- Turning on an auto feature **switches your team** and spawns **your** car.
- Keep Drive Speed at or below **540 km/h**. Faster can tear your wheels off.
- "Instant Catch" and "Teleport-Flag Bypass" are less safe. Test them last and say which was on.

## 13. Farm a Fish (V2.5.0.2, public build)
Autopilot that:
- Farms, buys, crafts
- Feeds and mutates pets
- Sells

Plus shop restock tools, event automation and your own Discord webhook.

**Notes:**
- Workspace folder `MentalHubFAF` holds the cached UI and configs. Delete it to get a fresh UI and config.
- Don't put anything in `SCRIPT_KEY` for tester runs.

## 14. Final Swarm (V3)
Wave survival helper:
- Auto dodge boss attacks and units
- Lava avoid, no knockback/slow
- Heart pickups
- Lobby armor grading minigame

**Notes:**
- No Knockback and lava avoid are on by default. Turn on Auto Dodge yourself.
- Settings aren't saved. Set them again each execute.
- Report damage taken with Auto Dodge + Keep away **on**.

## 15. Gorilla Warfare (V2)
Auto-shoots monkeys and bosses through the game's aim system and dodges telegraphed blasts. It can also shift your hitbox **under** the map. V2 adds:
- Boss dodge while Under
- Auto Satchel (throw + detonate without knockback)
- Auto Short Fuse, with an "only when gun is MAX" option
- Blast Dash capped to a set distance

**Notes:**
- Keep "Reload after teleport" on. With the tester loader, lobby to match reloads the tester build.
- The Abilities tab only works on the **Bomber** class.
- Under hits ~80% over thin floors and almost nothing over thick rock. Turn on Smart depth.
- Keys:
  - **F6:** auto shoot
  - **F7:** dodge
  - **F9:** cycle hitbox
- Executor needs `debug.getupvalue(s)`.

## 16. Grow a Garden 2 (V0.1.3)
Covers:
- Collect fruit by your weight rules
- Sell at NPC Steven (including market boosts)
- Auto-buy seeds/gear in stock
- ESP

**Notes:**
- Config: `workspace/ZenX/GrowAGarden2`. Delete it to reset.
- Say whether "Only sell during market boost" / Double-or-Nothing were on when reporting coin issues.

## 17. Hatch 1 Million Chickens
Full farm:
- Auto click and upgrades, eggs and crates
- Ship, prestige/ascend
- Event quests and rewards

**Notes:**
- Uses the stock Rayfield UI, not SeneX. If the GUI fails, report the console error.
- Config: `workspace/MentalHub`. Delete it to reset.
- **Leave "Auto Gift Items to Player" OFF.** It gives your items away.

## 18. Hunt Giant Fish (V3)
Shoots fish (native or hub-aimed, incl. wallbang on private fish), fights bosses, sells/keeps catches, buys upgrades and claims every free reward.

**Notes:**
- Below tank level 3 it always uses Scripted aim.
- Executor needs `queue_on_teleport`, `readfile`/`writefile` and `debug.getupvalue`.
- If the hub draws over the game's start screen, report it.

## 19. Jujutsu: Zero (V3)
PvE grinder:
- NPC farm with your skills
- Level/story/board quests, auto grade up
- Crates, clan rolls, raids

It never targets players.

**Notes:**
- Start in the Main place.
- No anti-AFK: after ~18 min with no real input the game moves you to the AFK place.
- Clan auto-roll **replaces your clan** and spends rolls.
- After a raid teleport, re-run the loader inside the raid.
- If an old `GUI.lua` / `SeneX.lua` sits in your workspace folder, delete it.

## 20. My Cafe (V1)
Order bot (take, make, serve). It also:
- Restocks and optimizes the menu
- Buys upgrades and expansions
- Manages staff
- Claims rewards

**Notes:**
- Everything starts OFF.
- When reporting, turn on **Settings > Debug log** and copy the `[ZenX]` console lines.
- Say if the game updated.

## 21. Pay Your Debts! (V1)
The game swings for you. The hub steers your aim at the best piggy cluster and automates runs, bills, shopping, perks and rewards.

**Notes:**
- You only need Auto Aim + Auto Start Run.
- **Leave "Unlock destructive actions" OFF.** Rebirth, Bankruptcy and Next Cycle wipe cycle progress, and "All In" is a real gamble.

## 22. Pet Simulator 99 (v2.0)
Covers:
- Zone farm and the Hatch Wars event
- Enchants, potions, pets, items, keys
- Quests, rewards, minigames

**Notes:**
- Re-runs itself after hops, so **don't** re-execute by hand.
  - The hop reload loads the public build, not the tester one. Say so if a bug only shows after a hop.
- Turn on **Settings > Debug Logging** before reporting.
- If the HUD vanishes after a minigame, use **Minigames > Fix HUD**.
- Config folder: `workspace/ZenX`.

## 23. Pop & Collect / Pop Bubbles (experimental)
Small helper with long-range drop collect, rapid fire multiplier, and a Stop & restore button.

**Notes:**
- Wait until your weapon is ready, or you get "Weapon controller is not ready".
- Report whether drops and kills actually **count** server-side.

## 24. Reeled (V5)
Covers:
- Auto-cast fishing
- Silent headshot aim to clear fish zones
- Sell, ammo, upgrades, gear, claims
- World events (Leviathan)

**Notes:**
- Run it in the main game server, not the lobby.
- **Say your executor.** Some executors need a special mode, which the hub picks automatically.
- **Never press the death-screen Revive.** It costs Robux.
- Auto refill ammo only works at the Ammo Box.

## 25. RIVALS (v4.3)
Covers:
- Hold-RMB aimbot
- ESP
- Device spoof for the game's built-in aim assist
- Anti-flash, anti-AFK, staff detection

**Notes:**
- **ESP and Melee Aura are the detected parts. Alts only.**
- If RIVALS updated, a popup asks "Load anyway / Don't load". Report it.
- Needs `Drawing` + `mousemoverel` support.

## 26. Route 06 (V1)
Zombie co-op:
- Silent aim, auto shoot, kill aura
- Objectives, loot/shop at checkpoints
- Full auto-farm loop with lobby requeue

**Notes:**
- The lobby shows only Auto Farm + Settings. The match shows all tabs.
- RISKY toggles (gun aura, fast fire, reach, speed > 1.15x, noclip, car autopilot) are likely kick sources. Test them last.
- **End** = kill switch.

## 27. Soul Eater: Resonance (V2)
Covers:
- Attack aura with smart block
- Auto skills and silent aim
- Paced auto-quest loop
- ESP, stats, codes, souls, spins

**Notes:**
- Main place only. The PvP place does nothing.
- Keep quest pacing at defaults. Quests done too fast give no reward.
- Re-execute after every teleport.
- **"Redeem resetmystats" really resets your stats.**

## 28. Soul Hero (V4)
Idle auto-battler:
- Progress levels, skill tree, rebirth
- Totems, summon/hatch/evolve heroes
- Claims

Robux-prompt killswitch is on by default.

**Notes:**
- It never attacks on purpose. Your heroes do the killing.
- Being in a party blocks rebirth.
- Re-execute after rejoin.

## 29. Steal An Egg (V5)
Covers:
- Place/hatch eggs, sell pets
- Auto-steal with safe-escape prediction
- Base/treadmill upgrades, speed training
- Fuse, mutate, events

**Notes:**
- If the UI fails, the console shows "could not load the SeneX UI library". Wait a minute and re-run.
- Guards can still catch you.
- "Auto trade up + craft essence" is irreversible.

## 30. The Lost Land (V1, no GUI)
Survival auto-farm: chop, mine, hunt weak animals, pick up drops, auto eat/drink/heal. It never touches player buildings.

**Notes:**
- Starts the moment you execute. Your current spot becomes home (350 stud radius).
- Stop it with `_G.TLL_FARM = false`.
- Status prints in F9 as `[TLL]` lines.

## 31. Ultra Unfair (V1)
Covers:
- Auto attack with the game's own input
- Kill aura, float, clone summons
- Auto quests
- Anti-AFK that stops the idle crash

**Notes:**
- Keep Anti-AFK ON. The game crashes you after ~21 min idle.
- Aura range above ~23 or Float can get you kicked. **Alt only.**
- The TEST buttons are measurement tools, not features.

## 32. Wanted (V0.1.1)
Criminal-route auto farm:
- ATMs, safes, stores, jewelry and bank vaults
- Airdrops, cargo jet
- Sell bag, quests, dailies

Plus police-side silent aim/ESP and crate opening.

**Notes:**
- Server hop reloads the tester build automatically.
- Cargo jet, gas station safes and office PCs are beta. Report them separately.
- When reporting, use **"Save incident snapshot now"**. Files go in `workspace/ZenX/Wanted`.

## 33. Watch Number Go Up (V1)
Incremental farmer:
- Runes and every upgrade tier
- Prestige layers on timers
- Gems, challenges, achievements, time tokens, research

**Notes:**
- Rejoin/Server Hop reload the **public** loader, not the tester build. Re-run the tester loader after a hop.
- Use **Unload ZenX** (System tab) before re-executing.

## 34. Wingblade Arena (V1)
PvP spear arena:
- Silent spear aim, aim assist, auto-block
- Movement boosts, anti-knockback
- ESP and threat radar
- Auto-queue and daily claim

**Notes:**
- Keys:
  - **V:** silent aim
  - **B:** auto-block
  - **End:** panic
- Risky features arm a staff guard that panics when the developer joins.
- Re-run the loader in each new server.

## 35. World // Zero (V1)
Covers:
- Kill aura with the game's own attacks and skills
- Dungeon loop (start, clear, chests, repeat/auto-level)
- Quest claiming and gear management

**Notes:**
- Start in a world hub (e.g. Crescent Cove).
- With "Re-run after a dungeon teleport" on, dungeon teleports reload the tester build.
- Gear auto-clear deletes or sells items. Keep **"Preview only" ON** first.
- "Direct wire" attack is UNTESTED. Leave it off unless asked.
