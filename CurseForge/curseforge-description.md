# SlackHacks: Essential Quality of Life Tweaks to Native Blizzard UIs

This is *yet another* quality-of-life addon, focused on making its features look like part of Blizzard's native UI.

Everything is a module.

Everything is optional.

Everything is off by default. (Please read all the options!)

It's similar to Plumber or Leatrix, but may be incompatible with full UI redesigns like Ellesmere UI.

## Is this another "vibecoded" slop addon?!

Well, is it AI generated? Partially. *Assisted*, more precisely. Is it "vibecoded"? **Absolutely not!**

I am a professional developer with over 30 years of programming experience. While I'm not 1000% handwriting every line, I am reading, reviewing, and steering all changes as much as possible, piece-by-piece, and reviewing all impacts on performance and memory. One of my motivations to create this addon was to actually *avoid* all the "vibecoded" addons built by non-developers that have numerous bugs and poor performance.

If you don't believe me, profile this addon yourself. Take a look at the compression algorithm I wrote in `IconNames.lua` to see my commitment to performance and efficiency; it adds icon search functionality to the Macro window where you pick icons so you can search by name. The source library for this metadata (`LibRPMedia`) was over 10MB. I extracted and compressed the data down to 0.7MB. Just an example of my efforts...

## Modules & Features

### Utilities
* **Lootable Object Sparkles (WoW Forever only):** Enables Classic WoW's hidden lootable object sparkles.
* **TomTom `/way` Command:** Creates native waypoints with TomTom-style `/way` commands without requiring or overriding TomTom.
* **Show In-Game Navigation:** Toggles the in-world diamond pointing toward objectives on clients that support it.
* **Add Search to Icon Picker:** Adds icon-name search to the Macro and Equipment Set icon pickers.

### Controls
* **Camera Distance:** Unlocks maximum camera zoom distance (`cameraDistanceMaxZoomFactor = 4`).
* **Dynamic Camera:** Enables ActionCam basic mode with dynamic pitch.
* **Keybindings:** "Open Keybindings" jumps to SlackHacks' extra bindings in Blizzard's Key Bindings menu.
  * **Class Spec Keybinds:** Switch specializations 1–4 in Talents UI order, out of combat.
  * **Consumable Keybinds:** Use the best healing potion, mana potion, or bandage, consuming smaller stacks first.
  * **Dragonriding Overrides:** Apply context-sensitive bindings for Skyward Ascent, Surge Forward, Whirling Surge, and Aerial Halt on Skyriding mounts.
  * **System Keybinds:** Reload UI, restart sound, enter Quick Keybind Mode, or open Click Casting.

### Graphics
Adjust hidden graphics settings not present in the default interface menus:
* **Ground Foliage:** Density, fade distance, and draw distance.
* **Level of Detail (LoD):** Object fade, culling, and terrain distance.
* **Sharpening:** Enforce FSR/CAS spatial sharpening at native resolution.
* **Water Reflections:** Reflection detail.
* **Weather:** Effect density.
* Reset all settings to game defaults with one button.

### Minimap
* **Button Auto-Hide:** Hide tracking, calendar, clock, and addon buttons until hovering over the minimap.
* **Addon Compartment:** Move addon minimap icons into the Addon Compartment.
* **Opacity:** Set separate opacity for idle, moving, and combat.
* **Square Minimap:** Use a square minimap with a title bar.

### Inventory
* **Auto-Sell ALL Grey Items:** Sell every grey item at merchants, including protected items. Listview Bag's Auto-Sell Junk takes precedence when enabled.
* **Hide Bags Frame:** Hide Blizzard's bag bar and backpack icon.

#### Auto Repair
* Automatically repair at merchants using personal funds, guild funds, or guild funds only in raids.

#### Listview Bag
An alternate list-based bag view that can replace the default backpack or be toggled as needed.
* **Columns:** Quantity, Item Name, Item Level, Armor/Weapon Type, Equipment Slot, and Binding Type (BoE, BoP, Warbound).
* **Views:** Selling shows vendor-sellable items, vendor prices, and cached auction prices, refreshed manually or supplied by Auctionator. Opening the Auction House locks Selling View, filters out ineligible or blocked items, and enables Quick Sell for Auction-flagged items at the Auction House's default price (Blizzard requires one click per posting); closing it restores your previous view. Gear compares equipped stats, including Forever relics, with filters for equipment types, slots, client-specific stats, and downgrades. Downgrade Only excludes items with a stat gain against any compared slot.
* **Sorting:** Sort all columns ascending or descending, including flags.
* **Search:** Filter items by text as you type.
* **Filters:** Filter by flag, binding, and category, including reagent-bag items. Essentials includes configurable reusable tools and utility items, plus custom items selected from your inventory. Consumable arrows and Soul Shards are optional and disabled by default. Classification may differ from Blizzard's bag sorting.
* **Item Protection:** Protect items, including greys, from conflicting Listview Bag actions and Auto-Sell Junk. Blizzard's Sell All Junk and Auto-Sell ALL Grey Items ignore protection.
* **Flag Marking:** Left-click flags for Junk, Auction, Bank, Mail, or Protect; Junk, Auction, and Bank offer Once or Always. Right-click toggles the Junk (Once) flag on or off without changing Always or other flags. One-time marks clear when the matching item leaves your bags; Always marks are remembered in their Options lists.
* **Item Flags:** Junk marks distinguish item variants. Grey items can only be protected, Auction requires eligible items, Junk requires a vendor price, and soulbound items cannot be marked for Mail. Flags prevent conflicting Listview Bag actions; Auction does not automatically list items, and normal bags and Blizzard's junk sale are unaffected.
* **Bank Deposits:** Deposit Bank-flagged items from the BankFrame, or enable automatic deposits when opening the bank. One-time Bank marks clear after the item leaves your bags; Always marks are remembered. Items that cannot be deposited remain flagged.
* **Auto-Sell Junk:** Sell unprotected greys and one-time or remembered Junk items at merchants instead of using Blizzard's automatic grey sale. Disabling it offers to disable Auto-Sell ALL Grey Items too.
* **Bag Controls:** Temporarily show Blizzard's bags with the backpack button, or use the portrait or cog menu for settings, default bags, Auto-Deposit Bank Items, and Auto-Sell Junk. Blizzard's Switch to Listview Bag option asks before enabling a disabled module.
* **Bag Slots:** The footer shows used and total slots with a low-space warning. Hover for bag capacity, item categories, and consumable lists; Forever also shows relevant ammo and Soul Shards. An equipped reagent bag counts as one slot, free if it has any room.
* **Inventory Log:** Enable the module under Inventory > Inventory Log, or open its Send Mail-styled ledger from the footer or either bag's menu. When logging is disabled, opening asks for confirmation and waits to show the window until you accept enabling the module; declining keeps it closed without changing saved history. It uses Blizzard's title bar, control header, input borders, stationery, and scrollbar, at roughly 1.5 times MailFrame's height. Compact rows have darker, alternating gradient backgrounds and month/day timestamps. Its columns are Qty., Item, Action, and Timestamp, with item tooltips, search, and Action, Binding, and Category filters. Vendor purchases are recorded as Purchased. Qty. stays blank for unknown or oversized counts and single nonstackable items; hover to read full known quantities. Confirmed mail and trade entries show the recipient or trade partner in smaller text beneath the action; hover for the full name and transfer direction. Choose which actions to record and how many entries to keep (3,000 by default); periodic cleanup permits temporary overflow. History is saved per character, and clearing history requires confirmation. Disabling the module offers to clear existing history too. Logging also works with Blizzard's bags.
  Inventory Log quantities show `+` for gains and `-` for losses, including full quantities in tooltips. Claimed incoming mail attachments show "(Received)" beneath Mailed instead of a recipient name. Categories follow normal item metadata; Essentials applies only to Listview Bag. Crafted items log as Created. Only identified transactions are recorded: unmatched inventory changes, spell reagents such as Soul Shards, and item consumption are omitted. Older Unknown and Used history is preserved, but those actions have no recording options or filters.
* **Footer Supplies:** Forever shows equipped arrows or thrown-weapon durability and Warlock Soul Shards. Retail always shows crests instead.
* **Mail Recipients:** Save recipients with nicknames and searchable icons. Mail's Always choice sets a default recipient; Once adds to the front of the queue, with a recipient and item preview when choosing a stackable item's quantity, defaulting to all matching mail-eligible items in your bags. The Send Mail tab opens the list when assigned items are in your bags; select a recipient to prepare drafts and send each batch yourself, with subsequent batches prepared automatically. Partial stacks require a free compatible bag slot, and soulbound copies are skipped. Unfulfilled quantities remain pending; the Mail flag clears when the queue finishes without a default. Replacing a draft requires confirmation, and deleting a recipient leaves Mail flags intact.

### Info Display
The module has a master switch and individual feature settings. The Guildie, Friends, and Players Online lists work on Retail and WoW Forever.

#### Char Sheet
* **Gear Stats Overlay:** Toggle gear stats from the Character Sheet or minimap menu.
* **Item Level Overlays:** Show item levels on equipment slots, colored by quality or upgrade-track watermark.
* **Upgrade Track Progress:** Show progress below item levels, optionally with a star for fully upgraded items.
* **Watermark & Stat Totals:** Show slot high-watermark item levels and secondary stat ratings and percentages.
* **Enchants & Gems:** Show enchants and gems, with alerts for missing enchants or empty sockets.

#### Weeklies
* **Delves Progression:** Add an Objective Tracker widget with:
  * Weekly Gilded Stash completions and Trovehunter's Bounty status.
  * Companion level and Delve Renown progress.
  * Restored Coffer Keys, Coffer Key Shards, Undercoin, and Untainted Mana-Crystals.
  * A context menu with detailed progress.

#### Guildie List
* **Online Guild Members:** List online members and their zones in a movable, resizable Damage Meter-style window, with Blizzard-style player tooltips.
* **Context Menu:** Click a member for Invite, Whisper, and View Houses options. Invite is hidden when unavailable; View Houses is Retail only.
* **Instance Icons:** Optionally show dungeon, raid, or delve icons.
* **Rank Icons:** Optionally show guild master and officer icons.
* **Faction Icons:** Optionally show faction icons, by default only for the opposite faction.
* **In-Group Indicator:** Optionally show Blizzard's group icon for members already in a group (on by default).
* **Sorting:** Sort the list by name (default) or by location.
* **Fit to Content:** Automatically size the window to its contents.
* **Collapsible:** Minimize to a header that still shows the online count.
* **Settings Cog:** Adjust sizing, background opacity, sorting, and icons from the header.
* **Minimap Toggle:** Toggle the list from the minimap menu.
* **Window Interaction:** Lock its position or make it click-through; the settings cog remains interactive.

#### Friends List
* **Online Friends:** Show online friends and their locations or other Blizzard game activity in a Damage Meter-style window, with Blizzard-style tooltips.
* **Context Menu:** Click a friend for Invite, Whisper, and View Houses options. Invite is hidden for other games or WoW versions; View Houses is Retail only.
* **Filters:** Show only favorites (on by default), WoW players, or players on the same WoW version. Turning off favorites also shows character friends.
* **Game Icons:** Optionally show icons for friends in other Blizzard games or WoW versions.
* **Instance, Faction, and In-Group Icons:** The same optional icons as the Guildie List.
* **Sorting, Fit to Content, Collapsible, Settings Cog, Window Interaction, Minimap Toggle:** Match the Guildie List; filters are also in the cog menu. Name sorting follows Blizzard's Friends list.

#### Players Online
* **Stacked Lists:** Combine Friends and Guildie lists in one window; the online count excludes duplicates.
* **Objective Tracker Sections:** Collapse each list independently and choose their order.
* **Settings Cogs:** Adjust window settings and stacking from the main cog, or each list's sorting, filters, and icons from its section cog.
* **Collapsible:** Same as the individual lists.
* **Window Interaction:** Lock or make the stacked window click-through independently of the standalone windows. The top cog remains interactive.

### Reminders
Retail only, with a master switch and individual feature settings.

#### Talent Loadouts
* **Loadout by Content:** Choose a loadout or "Off" for Questing, Delves, Raids, Dungeons, and PvP per character and specialization.
* **Switch Prompt:** A movable prompt offers your chosen loadout when entering or leaving content. It waits for combat to end, never takes keyboard focus, and stays hidden during an active Mythic+ keystone.
* **Mythics:** Optionally choose loadouts for individual current-season Mythic+ dungeons; others use the Dungeons default.
* **Raid Bosses (Midnight Season 2):** Optionally choose loadouts for The Venomous Abyss bosses and Kith'ix in The Unbinding of Kith'ix (12.1.5). Entering a mapped boss room prompts a switch; bosses set to "Use Default" use the Raids loadout.

#### Consumable Buff Reminders (**WIP!**)
* **Clickable Aura Icons:** Show buttons to apply missing Food, Flask, Weapon Oil, or Augment Rune buffs.
* **Buff Expiration:** Warn when a buff may expire during an active Mythic+ key or raid encounter.
* **Where to Remind:** Optionally restrict reminders to Mythic/Mythic+ dungeons and non-LFR raids.
* **Edit Mode Support:** Position and scale reminders in Blizzard's Edit Mode.

### Mouse Ring
* Show a ring around the cursor with adjustable scale, opacity, and color, optionally only in combat.

### Windows
* **Toast Positioning:** Move Blizzard's achievement, loot, and mount popups in Edit Mode.
* **Zone Map Scaling:** Change scale from the Zone Map's tab menu.
* **Keybinding:** Toggle the module without opening options.

#### Movable Windows
* **Window Dragging:** Drag native Blizzard panels by their title bars.
* **Position Memory:** Remember positions for the session, permanently, or not at all.

#### Window Scaling
* **Mouse-Wheel Scaling:** Scroll over a title bar with an optional modifier key to scale a window from 0.3x to 2.5x.
* **Scale Memory:** Remember scales for the session, permanently, or not at all.

### Dialog
* **Auto-Accept Quests:** Accept quests on interaction.
* **Auto-Complete Quests:** Complete quests without reward choices automatically.
* **NPC Dialog Auto-Click:**
  * **Auto-Click First Dialog Option:** Select the sole NPC dialog option when no quests are listed.
  * **Only During Mythic Runs:** Restrict auto-clicking to timed Mythic+ runs (not available on WoW Forever). An active run also permits non-service dialogs when the Service NPC restriction is enabled.
  * **Only when interacting with Service NPC:** Restrict auto-clicking to recognized services such as vendors, banks, flight paths, and trainers, including forced dialogs.
* **Dialog Keybindings:**
  * **Number Key Dialog Options:** Select quest and NPC dialog options with numbered shortcuts.
  * **Spacebar to Accept/Complete Quest:** Use Spacebar to accept, continue, or complete quests through Blizzard's normal buttons and confirmations.
* **Safe Dialog Shortcuts:** Temporary bindings clear when dialog closes or combat starts. Turn-ins with reward choices remain manual.
* **Quest Item Extra Action Button:** Show a quest item on the Extra Action Button in its quest area; targeted items are excluded.
* **Toggles:** Use keybindings to toggle individual or all automatic interactions, or the minimap menu to toggle all.

### Self Vendor
* **Chat Request Handling:** Listen for consumable requests in party, raid, instance, say, and whisper chat. Optionally accept requests only from guild members.
* **Spec Matching:** Select recommended flasks and oils for the requester's class and specialization using Wowhead or Icy Veins data.
* **Asynchronous Trade Queue:** Queue requests and split stacks to prevent trade conflicts.
* **Automatic Trade Response:** Choose items to offer anyone opening a trade, prioritizing them in the queue. Set the mode with `/slack vend <mode>` and optionally turn it off when leaving the group.
* **Configuration:** Toggle flasks, oils, Augment Runes, and Vantus Runes; configure rune quantities and optional chat prefixes.
* **Combat Safe:** Vending pauses in combat, clears the queue on entering combat, and accepts requests only out of combat.

### Combat
* **Assist Tank Macro:** Generate a macro and keybinding to assist the tank or your Hunter/Warlock pet. Optionally assist your friendly target first, or mark your target with a skull when tanking.

### Nameplates (**WIP!**)
* **Raise Casting Nameplates:** Draws casting enemy nameplates above overlapping nameplates so their cast bars remain visible.

---

## Slash Commands

| Command              | Action                                                |
| :------------------- | :---------------------------------------------------- |
| `/slack`             | Toggle the configuration panel                        |
| `/slack help`        | List available slash commands                         |
| `/slack bugs`        | Open the internal error log and report tool           |
| `/slack debug`       | Toggle verbose debug logging to chat and database     |
| `/slack reset`       | Prompt to reset the active profile to defaults        |
| `/slack wipoff`      | Disable all experimental/WIP modules                  |
| `/slack vend <mode>` | Set Self Vendor's Automatic Trade Response (or `off`) |

---

## Contact Me / Report Issues

Please create issue tickets for bugs on GitHub:

https://github.com/Slackwise/SlackHacks/issues/new?labels=bug

If you are using EllesmereUI or similar whole-UI redesigns, then please do ***not** leave bug reports. Many of my features depend on Blizzard's native UI and will likely not work with it or break your UI.

But, either way, feel free to reach me via `@Slackwise` on Discord.
