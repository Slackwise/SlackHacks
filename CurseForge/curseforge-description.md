# SlackHacks --  Essential Quality of Life Tweaks to Native Blizzard UIs

This is *yet another* "Quality of Life" addon with various small features and tweaks, but my focus is on making my changes look like they're part of the native Blizzard UI.

Everything is a module.

Everything is optional.

Everything is off by default. (Please read all the options!)

If you've used Plumber or Leatrix, this is similar, but I'm trying *very* hard to make it look like Blizzard wrote all the features I'm providing. (Because of this, it is probably incompatible with full UI redesigns like Ellesmere UI.) 

## Modules & Features

### Inventory & Bags
* **Listview Bag:** An alternate list-based view for player bags that can replace the default grid backpack or be toggled as needed.
  * Columns: Quantity, Item Name, Item Level, Armor/Weapon Type, Equipment Slot, and Binding Type (BoE, BoP, Warbound).
  * Ascending and descending sort support on all columns.
  * Real-time text search filter.
  * Item Protection: Lock items to prevent them from being vendored or deleted.
  * Junk Marking: Mark specific items to be automatically sold at merchants or vendored with Blizzard's "Sell All Junk" button.
* **Auto-Sell Greys:** Automatically sells poor-quality (grey) items when opening a merchant window.
* **Auto-Repair:** Automatically repairs equipment upon opening a merchant window using Personal Funds, Guild Funds, or Guild Funds restricted to raid groups.
* **Hide Bags Frame:** Hides the Blizzard bag bar buttons and backpack container icon for players using keybinds.

### Character Sheet ("Info Display")
* **Gear Stats Overlay:** Adds a "Gear Stats" checkbox directly inside the Blizzard Character Sheet.
* **Item Level Overlays:** Displays item level on each equipment slot, with coloring based on item quality or upgrade track watermark tiers.
* **Upgrade Track Progress:** Displays current track progression (e.g., `6/6 C`) below the item level, with an option to display a star icon when fully upgraded.
* **Watermark & Stat Totals:** Displays slot high-watermark item levels alongside aggregate Critical Strike, Haste, Mastery, and Versatility ratings and percentages.
* **Enchants & Gems:** Displays current enchants and gem statuses on equipment, with alert icons for empty sockets or un-enchanted items.

### Objective Tracker & Weeklies
* **Delves Progression:** Integrates a Delves tracking widget into the Objective Tracker.
  * Tracks weekly Gilded Stash completions (4 total).
  * Tracks Trovehunter's Bounty status (Available, Acquired, Engaged, Completed).
  * Displays companion level and Delve Renown progress.
  * Displays currency totals for Restored Coffer Keys, Coffer Key Shards, Undercoin, and Untainted Mana-Crystals.
  * Context menu for detailed progress breakdowns.

### Group Trade Automation ("Self Vendor")
* **Chat Request Handling:** Listens in party, raid, and instance chat for consumable keywords (e.g., `crit oil rune`, `need flask`, `!flask`).
* **Spec Matching:** Selects the recommended Flask and Weapon Oil for the requesting player's class and specialization using data from Wowhead or Icy Veins.
* **Asynchronous Trade Queue:** Enqueues requests and handles item stack splitting via a FIFO queue to prevent trade window conflicts.
* **Configuration:** Granular toggles for Flasks, Oils, Augment Runes, and Vantus Runes, with configurable rune stack counts and optional chat prefix enforcement.

### Consumable Buff Reminders (**WIP!**)
* **Clickable Aura Icons:** Shows on-screen buttons to apply Food, Flask, Weapon Oil, or Augment Runes when buffs are missing.
* **Instance Filtering:** Options to restrict reminders to Mythic/Mythic+ dungeons and non-LFR raids (Normal, Heroic, Mythic).
* **Expiration Thresholds:** Triggers warnings if a buff is projected to expire during an active Mythic+ key or raid encounter.
* **Edit Mode Support:** Registered with Blizzard's Edit Mode for positioning and scaling.

### Movable Windows & Scaling
* **Window Dragging:** Left-click drag native Blizzard panels (Character Frame, Merchant, Quest Log, Spellbook, etc.) by their title bars.
* **Mouse-Wheel Scaling:** Hold a designated modifier key (`None`, `Shift`, `Ctrl`, or `Alt`) and scroll over a title bar to scale the window (0.3x to 2.5x).
* **Position & Scale Memory:** Configurable persistence (Do Not Remember, In Session Only, or Remember Permanently).
* **Toast Positioning:** Registers Blizzard's AlertFrame (achievement, loot, and mount popups) as a movable frame in Edit Mode.
* **Keybinding:** Includes a dedicated keybind to toggle the module on or off without opening options.

### Minimap
* **Square Minimap:** Changes the minimap shape from circular to square with a top title bar.
* **Button Auto-Hide:** Hides tracking, calendar, clock, and addon buttons until the cursor hovers over the minimap.
* **Addon Compartment:** Moves third-party addon minimap icons into the Addon Compartment dropdown.
* **Dynamic Fading:** Configurable opacity values for idle, moving, and combat states.

### Combat & Nameplates (**WIP!**)
* **Raise Casting Nameplates:** Temporarily increases the frame level of enemy nameplates while casting so cast bars remain visible in overlapping packs.
* **Mouse Ring:** Centers a circular overlay on the mouse cursor with adjustable scale, opacity, and color. Can be set to only display during combat.
* **Paladin Holy Shock Tracker:** HUD element displaying Holy Shock charge count and recharge progress, with Edit Mode positioning and an in-combat-only display setting.

### Graphics Overrides
Directly applies and restores hidden client CVars not present in default interface menus:
* **Ground Foliage:** Density (`groundEffectDensity`), fade distance (`groundEffectFade`), and draw distance (`groundEffectDist`).
* **Level of Detail (LoD):** Object fade scale (`lodObjectFadeScale`), cull threshold size (`lodObjectCullSize`), and terrain LoD distance (`terrainLodDist`).
* **Sharpening:** Enforces FSR/CAS spatial sharpening at native resolution (`ResampleAlwaysSharpen`).
* **Water Reflections:** Water reflection detail level (`reflectionMode`, 0–3).
* **Weather:** Weather effect density (`weatherDensity`, 0–3).
* Includes a one-click button to reset all CVars to game defaults.

### Controls & Keybindings
* **Camera Distance:** Unlocks maximum camera zoom distance (`cameraDistanceMaxZoomFactor = 4`).
* **Dynamic Camera:** Enables ActionCam basic mode with dynamic pitch.
* **Consumable Keybinds:** Keybinds to use the best healing potion, mana potion, or bandage in your bags, consuming smaller stacks first to conserve inventory space.
* **Dragonriding Overrides:** Applies context-sensitive keybinds for Skyward Ascent, Surge Forward, Whirling Surge, and Aerial Halt when mounting a Skyriding mount.
* **System Keybinds:** Keybinds for Reload UI, Sound System Restart, Quick Keybind Mode, and Click Casting.

---

## Slash Commands

| Command         | Action                                            |
| :-------------- | :------------------------------------------------ |
| `/slack`        | Toggle the configuration panel                    |
| `/slack help`   | List available slash commands                     |
| `/slack bugs`   | Open the internal error log and report tool       |
| `/slack debug`  | Toggle verbose debug logging to chat and database |
| `/slack reset`  | Prompt to reset the active profile to defaults    |
| `/slack wipoff` | Disable all experimental/WIP modules              |

---

## Contact Me / Report Issues

Please create issue tickets for bugs on GitHub:

https://github.com/Slackwise/SlackHacks/issues/new?labels=bug

If you are using EllesmereUI or similar whole-UI redesigns, then please do ***not** leave bug reports. Many of my features depend on Blizzard's native UI and will likely not work with it or break your UI.

But, either way, feel free to reach me via `@Slackwise` on Discord.
