# SlackHacks Changelog

## v18

### Utilities
- Added opt-in TomTom-style `/way` commands for native map pins, without overriding TomTom.

### SelfVendor
- Fixed an error message that might pop up mid combat.

## v17

### Reminders
- Talents: added per-raid-boss reminders.
- Talents: added first version

### Bindings
- Renamed Class Spec keybindings
- Added Class Spec keybindings

### Controls
- Added some description text for the Open Keybindings button.

### EllesmereUI
- Added detection/confirmation.

### WIP
- Added a confirmation popup for WIP modules

### Quest
- I groupbox'd the Options
- Added an auto-click first option for only mythic runs

### SelfVendor
- Fixed distance check bug and disabled checkbox bug.
- Disabled in combat.
- Fixed error in combat.

## v16

### Friends and Guildie Lists
- Added "Lock Position" to settings and window cog menus to prevent dragging.
- Added "Make Non-Interactive" to let mouse input pass through to the world, leaving only the settings cog interactive.
- When stacked, these settings control the entire Players Online window. Only its topmost cog offers these options and remains interactive in non-interactive mode; standalone windows retain their own settings.

## v15

### Friends List
- Disabled "Show Only Favorite Friends" by default

### Self Vendor
- Requests are now also accepted from `/say` and whispers, not just party, raid, and instance chat.
- Added an "Only Vend to Fellow Guildies" option (just above the mode checkboxes) to ignore requests from anyone outside your guild.
- The queue window now opens as soon as any request starts being handled, even with nobody else waiting, and shows who is currently being vended to above the waiting list.
- Every queue window row, including the player currently being vended to, now has a remove button and a vend button. The vend button vends to a waiting player immediately (the interrupted player goes back to the front of the queue) or retries the player currently being vended to.
- Closing the queue window now clears the entire queue, including the player currently being vended to.
- Saying a stat flask followed by "flask" (e.g. "crit flask", "mastery flask") now requests just that one flask instead of also adding a second, generic flask.
- Added an "Automatic Trade Response" dropdown. Set it to any Self Vendor mode and anyone who opens a trade with you is automatically traded those items, whether or not that mode's checkbox is enabled, and even while chat requests are turned off. The Flask mode picks the partner's flask from the selected Wowhead/Icy Veins source. They jump to the front of the queue; whoever was being vended to is put back at #1. Trades you open yourself are left alone, and Only Vend to Fellow Guildies still applies.
- Added "Turn Off Automatic Trade Response After Leaving Group" to set Automatic Trade Response back to Off when you leave a party or raid.
- Added `/slack vend <mode>` to set Automatic Trade Response from chat, e.g. `/slack vend vantus`, `/slack vend flask`, or `/slack vend off`.
- If a requester opens the trade with you before their items are ready, their items are now added to that trade window once prepared instead of failing.

## v14

### Players Online
- Replaced "Split Friend/Guildie Lists" with a "Stack Friend/Guildie List" checkbox, grouped directly above the Friends List/Guildies List visibility toggles in the window's cog menu. Uncheck it to split the lists into standalone windows.
- The standalone Friends and Guildie list cogs now use the same stacking checkbox and label.

### Self Vendor
- Requests are now also accepted from `/say` and whispers, not just party, raid, and instance chat.
- Added an "Only Serve to Fellow Guildies" option (below the Flask and Augments Source dropdown) to ignore requests from anyone outside your guild.
- The queue window now opens as soon as any request starts being handled, even with nobody else waiting, and shows who is currently being served above the waiting list.
- Saying a stat flask followed by "flask" (e.g. "crit flask", "mastery flask") now requests just that one flask instead of also adding a second, generic flask.

### Listview Bag
- The "Sell Trash" button is now only enabled while a merchant is open and you have marked trash a merchant will actually buy, and it disables itself once everything has been sold.

## v13

### Info Display
- "Enable Info Display Module" is now a master switch that turns all Info Display features on or off: Char Sheet, Weeklies, the Guildie and Friends lists, and Players Online. It's on by default.
- Gear Stats has its own setting now. Profiles that had the Info Display off keep Gear Stats hidden.

### Guildie List
- Renamed from "Guild Member List" (existing settings are migrated)
- Window title is now "Guildies (N)"
- Added a left/right-click context menu with Invite, Whisper, and View Houses (View Houses is Retail only)
- Names now use all of the window's width when it's resized, and windows can be resized up to full screen height
- Now available in WoW Forever as well as Retail

### Friends List
- New Info Display window listing online friends, titled "Friends (N)", with Only Favorite Friends, Only Playing WoW, and Only Same WoW Version filters
- Left/right-click context menu with Invite, Whisper, and View Houses
- Available in Retail and WoW Forever, as are the Guildie List and Players Online
- The Friends and Guildie lists can be turned on/off from the minimap button's menu ("Friends List" and "Guildies List" under "Display Gear Stats")
- Friends and guildies who are already in a group get Quick Join's group icon after their name ("Show In-Group Indicator Icon" option, on by default)

### Players Online
- New "Stack Friends and Guildie Lists" Info Display option that stacks both lists in one "Players Online (N)" window, with Objective Tracker-style collapsible section headers, a "List Stack Order" choice, and a Fit to Content cog option
- Players Online's cog also has "Change Opacity", "Split Friend/Guildie Lists", and Friends List/Guildies List checkboxes to turn each list on or off (turning both off also turns stacking off); each section header has a cog with its list's sort, filter, and icon options
- The Friends and Guildie list cogs offer "Stack Friend/Guildie Lists" when both lists are enabled

## v12

### Quest
- Added keybind number labels
- Added spacebar keybinding option

### Config
- Fixed defaults for movable windows

## v11

### GuildMemberList
- Added
- Includes collapsing and opacity controls

### Controls
- Fixed max camera zoom (turns out Retail doesn't let you set it to 4.0)

## v10

Mostly just reorganization and polish.

### Windows
- Renamed the Movable Windows module to "Windows" as it will have more Window features.
- Reorganized Options so they're more logically organized.
- Rewrote Options descriptions.
- Added checkbox to enable Zone Map scaling.
- Removed keybind as it doesn't seem useful.

### Minimap
- Pixel-perfect positioned the WoW Retail titlebar icons
- Renamed "Open Visual Settings" button to "Open Edit Mode".

## v9

Bug fixes and working around WoW Forever's latest UI changes:

### Quest
- Fixed accidental regression

### Minimap
- Fixed #WF zone text appearance for square map
- Pixel-perfected the height/position of the addon compartment for #WF

## v8

Just bug fixes:

### CharSheet
- Fixed enchant values

### MovableWindows
- Fixed Character window titlebar handle

### SelfVendor
- Fixed name-server parsing bug

## v7

Added a new Quest module:

### Quest / NPC
* **Auto-Accept Quests:** Automatically accepts quests on interact.
* **Auto-Complete Quests:** Automatically completes quests that have no choices in reward.
* **Auto-Click First Dialog Option:** Automatically clicks an interact option in an NPC dialog if it's the only option.
* **Number Key Dialog Options:** Maps NPC dialog options to the number keys (1–9, 0) while the dialog is open, using temporary override bindings that are cleared when the dialog closes or combat starts.
* **Quest Item Extra Action Button:** Shows an Extra Action Button for a quest item while you're inside that quest's area, bound to your Extra Action Button key. Items that must be used on a target are left out.
* **Toggles:** Keybindings to toggle each auto option or all of them at once (with a chat message and on-screen notice), plus an "All NPC Auto-Interacts" checkbox in the minimap icon menu.
* Hold `Shift` while interacting to skip all automation.

## v6

### Minimap
- Pixel-perfected the anchoring to the blue box in Edit Mode
- Pixel-perfected the positions of the icons in the square map header for #WR
- Pixel-perfected the clock and zone text on #WR

### Options
- Put the version number into a few places for quick reference
- `/slack` now also prints slash command help alongside opening Options

## v5

### Weeklies
- Delves: fixed gilded stash display/caching in all instance types

### SelfVendor
- Fixed a regression that broke triggering

### ListviewBag
- Fixed mailbox/merchant window opening closing the bag

## v4

### Error Log
- Filtering out more addon errors
- Added unfixable error fingerprinting to ignore
- Changed error report information and formatting

## v3

### Error Log
- Filtering out other addon errors

## v2

### Listview Bag
- Resized gold display width
- Added current season crest tracking
- Moved "Sell Trash" to header with "Open Bags"
- Search now functions same as default Backpack

### Minimap Icon
- Added optional minimap icon

### Error Log
- Enabled Error Logging (exception intercept) by default
- Updated Error Log window
- Added minimap notification for errors
