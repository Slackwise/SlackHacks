-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_flag_migration.lua

local addon = {}
--- Supply the addon used during initialization.
---@return table addon
function addon:NewAddon() return addon end
--- Supply the Listview Bag module during migration tests.
---@return table module
function addon:NewModule() return {} end
--- Supply the unused initialization libraries.
---@return table library
function LibStub() return addon end
--- Supply the unused initialization frames.
---@return table frame
function CreateFrame() return { SetOwner = function() end, SetAllPoints = function() end, Hide = function() end } end
Enum, StaticPopupDialogs = { ItemClass = {} }, {}
assert(loadfile("Init.lua"))()
assert(loadfile("ListviewBag.lua"))()
assert(loadfile("InventoryLog.lua"))()
--- Reject any migration that resets the user's configuration.
---@param reason string Reset reason.
function addon.resetConfig(reason) error(reason) end
--- Clear an optional migrated log table.
---@param values table Table to clear.
function wipe(values) for key in pairs(values) do values[key] = nil end end

local grey = "Grey\0310\03110\031"
local common = "Common\0311\03110\031"
local pending = "Pending\0311\03110\031"
local fields = { "trashItems", "protectedItems", "auctionItems", "bankItems", "mailItems" }
--- Create a profile with legacy, current, and unknown-quality flags.
---@return table profile
local function makeProfile()
  local bag = { enabled = true }
  bag.trackCrestCurrencies = false
  for _, field in ipairs(fields) do
    bag[field] = {
      [grey] = true,
      [common] = { quality = 1 },
      legacyGrey = { name = "Grey", quality = 0 },
      unknown = { name = "Unknown" },
    }
  end
  bag.mailRecipients = { [3] = { nickname = "Alt", character = "Alt-Realm" } }
  bag.mailAssignments = { [common] = 3, [pending] = 3 }
  bag.mailAmounts = { [pending] = { remaining = 17 } }
  return { listviewBag = bag }
end
--- Confirm that grey protection and unrelated flags survive migration.
---@param profile table Profile to check.
local function checkProfile(profile)
  assert(profile.listviewBag.enabled)
  assert(type(profile.listviewBag.auctionIneligibleOverrides) == "table",
    "Migrated profiles must support separate flags for auction-ineligible copies")
  assert(profile.listviewBag.trackCrestCurrencies == false,
    "An existing disabled crest preference must remain available as the supplies selection")
  assert(profile.listviewBag.mailAssignments[common] == 3
    and profile.listviewBag.mailRecipients[3].character == "Alt-Realm"
    and profile.listviewBag.mailAmounts == nil
    and profile.listviewBag.mailAssignments[pending] == nil
    and profile.listviewBag.mailQueues[pending][1].recipient == 3
    and profile.listviewBag.mailQueues[pending][1].remaining == 17,
    "Existing recipient assignments must remain remembered without a one-time amount")
  for _, field in ipairs(fields) do
    local items = profile.listviewBag[field]
    if field == "protectedItems" then
      assert(items[grey] and items.legacyGrey, "Grey protection must survive migration")
    else
      assert(items[grey] == nil and items.legacyGrey == nil, field .. " must remove unsupported grey flags")
    end
    assert(items[common].quality == 1 and items.unknown.name == "Unknown", field .. " must preserve other flags")
  end
end

assert(addon.CONFIG_VERSION == 18 and addon.CONFIG_VERSION_RELEASES[18] == 38)
for _, version in ipairs({ 0, 15 }) do
  local active, other, detached = makeProfile(), makeProfile(), makeProfile()
  addon.db = {
    char = {},
    global = { configVersion = version },
    profiles = { Default = active, Other = other },
    profile = detached,
  }
  addon.migrateConfig()
  -- Profiles written by an earlier development build are converted on access.
  for _, profile in ipairs({ active, other, detached }) do
    addon.ListviewBag:MigrateLegacyMailAmounts(profile.listviewBag)
  end
  assert(addon.db.global.configVersion == 18)
  assert(detached.inventoryLog.enabled == false and detached.inventoryLog.entriesToKeep == 3000
    and #addon.db.char.inventoryLog.entries == 0)
  checkProfile(active)
  checkProfile(other)
  checkProfile(detached)
  addon.CONFIG_MIGRATIONS[16]()
  checkProfile(active)
end
local existing = makeProfile()
existing.listviewBag.auctionIneligibleOverrides = { existing = true }
addon.db = { global = { configVersion = 15 }, profile = existing, char = {} }
addon.migrateConfig()
assert(existing.listviewBag.auctionIneligibleOverrides.existing,
  "Repeating migration must preserve existing overrides")
local alreadyCurrent = makeProfile()
addon.db = { global = { configVersion = 16 }, profile = alreadyCurrent, char = {} }
addon.migrateConfig()
assert(alreadyCurrent.listviewBag.mailAmounts[pending])
addon.ListviewBag:MigrateLegacyMailAmounts(alreadyCurrent.listviewBag)
assert(alreadyCurrent.listviewBag.mailAssignments[common] == 3
  and alreadyCurrent.listviewBag.mailQueues[pending][1].remaining == 17
  and not alreadyCurrent.listviewBag.mailAssignments[pending])
assert(type(alreadyCurrent.listviewBag.trashItemsOnce) == "table",
  "Config v17 must initialize the one-time Junk list.")

local history = { { link = "item:101", action = "Sold", quantity = 2, category = "special" },
  { link = "item:102", action = "Looted", quantity = 1, category = "equipment" },
  { link = "item:103", action = "Unknown", quantity = 3 },
  { link = "item:104", action = "Used", quantity = 1 } }
local activeCharacter = { inventoryLog = { entries = history, actions = { Sold = false },
  categories = { special = false, consumables = false } } }
activeCharacter.inventoryLog.actions.Unknown, activeCharacter.inventoryLog.actions.Used = false, false
local otherCharacter = { reminders = { keep = true } }
local oldProfile = { inventory = { autoRepair = true, autoSellGreyItems = true } }
local optedIn = { inventory = { inventoryLogEnabled = true },
  inventoryLog = { actionsToLog = { Unknown = true, Used = false, Sold = false } } }
addon.db = { global = { configVersion = 17 }, char = activeCharacter, profile = oldProfile,
  profiles = { Default = oldProfile, Other = optedIn }, sv = { char = { One = activeCharacter, Two = otherCharacter } } }
addon.migrateConfig()
assert(addon.db.global.configVersion == 18 and oldProfile.inventoryLog.enabled == false
  and oldProfile.inventory.autoRepair and oldProfile.inventory.autoSellGreyItems and optedIn.inventoryLog.enabled
  and optedIn.inventory.inventoryLogEnabled == nil,
  "The ledger migration must preserve existing inventory preferences and explicit opt-in")
assert(activeCharacter.inventoryLog.entries == history and activeCharacter.inventoryLog.actions.Sold == false
  and type(activeCharacter.inventoryLog.bindings) == "table" and #otherCharacter.inventoryLog.entries == 0
  and otherCharacter.reminders.keep, "Ledger initialization must preserve every character's existing data")
assert(history[1].category == nil and history[2].category == "equipment"
  and activeCharacter.inventoryLog.categories.special == nil
  and activeCharacter.inventoryLog.categories.consumables == false,
  "Migration must retire only the ledger's Essentials category and preserve unrelated categories and selections")
assert(activeCharacter.inventoryLog.actions.Unknown == nil and activeCharacter.inventoryLog.actions.Used == nil
  and optedIn.inventoryLog.actionsToLog.Unknown == nil and optedIn.inventoryLog.actionsToLog.Used == nil
  and optedIn.inventoryLog.actionsToLog.Sold == false
  and #history == 4 and history[3].action == "Unknown" and history[4].action == "Used",
  "Retiring actions must preserve historical entries and unrelated recording preferences")
local developmentProfile = {
  inventory = { inventoryLogEnabled = true, autoRepair = true },
  inventoryLog = setmetatable({}, { __index = { enabled = false, entriesToKeep = 3000 } }),
}
addon.db.profile, addon.db.global.configVersion = developmentProfile, 18
addon.migrateConfig()
assert(developmentProfile.inventory.inventoryLogEnabled, "An already-current config does not rerun migration 18")
history[1].category, activeCharacter.inventoryLog.categories.special = "special", false
activeCharacter.inventoryLog.actions.Unknown, activeCharacter.inventoryLog.actions.Used = false, false
addon.InventoryLog:MigrateCharacterSettings(activeCharacter)
assert(history[1].category == nil and activeCharacter.inventoryLog.categories.special == nil
  and activeCharacter.inventoryLog.categories.consumables == false
  and activeCharacter.inventoryLog.actions.Unknown == nil and activeCharacter.inventoryLog.actions.Used == nil,
  "Already-current development characters must also retire the ledger-only Essentials filter")
assert(addon.InventoryLog:GetSettings().enabled and developmentProfile.inventory.inventoryLogEnabled == nil
  and developmentProfile.inventory.autoRepair,
  "Runtime migration must preserve v18 opt-in even when AceDB inherits a disabled default")
developmentProfile.inventory.inventoryLogEnabled = true
developmentProfile.inventoryLog.enabled = false
developmentProfile.inventoryLog.entriesToKeep = 17
developmentProfile.inventoryLog.actionsToLog = { Sold = false }
local recording = developmentProfile.inventoryLog.actionsToLog
assert(not addon.InventoryLog:GetSettings().enabled and developmentProfile.inventoryLog.entriesToKeep == 17
  and developmentProfile.inventoryLog.actionsToLog == recording,
  "Explicit standalone module choices must win over legacy settings")
assert(type(alreadyCurrent.listviewBag.auctionItemsOnce) == "table"
  and type(alreadyCurrent.listviewBag.bankItemsOnce) == "table",
  "Config v17 must initialize the one-time Auction and Bank lists.")
local legacyVariantKey = "Marked\0312\03130\031Champion"
local variantLink = "|cff0070dd|Hitem:42:123:4:5:6:7|h[Marked]|h|r"
alreadyCurrent.listviewBag.trashItems[legacyVariantKey] = {
  name = "Marked", link = variantLink, quality = 2, itemLevel = 30, upgradeTrack = "Champion",
}
addon.ListviewBag:MigrateLegacyJunkFlags(alreadyCurrent.listviewBag)
local migratedVariantKey = table.concat({ "item", "42:123:4:5:6:7", 2, 30, "Champion" }, "\031")
assert(alreadyCurrent.listviewBag.trashItems[migratedVariantKey]
  and not alreadyCurrent.listviewBag.trashItems[legacyVariantKey],
  "Remembered Junk marks with saved links must migrate to exact variant keys.")
local warnings = 0
--- Count migration warnings without discarding malformed saved data.
function addon.prn() warnings = warnings + 1 end
local incomplete = { mailAssignments = {}, mailAmounts = { missing = { remaining = 2 } } }
addon.ListviewBag:MigrateLegacyMailAmounts(incomplete)
addon.ListviewBag:MigrateLegacyMailAmounts(incomplete)
assert(incomplete.mailAmounts.missing.remaining == 2 and warnings == 1,
  "Unmigratable legacy assignments must be retained and reported once")
print("Listview bag flag migration tests passed")
