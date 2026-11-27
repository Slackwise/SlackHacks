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

assert(addon.CONFIG_VERSION == 16 and addon.CONFIG_VERSION_RELEASES[16] == 34)
for _, version in ipairs({ 0, 15 }) do
  local active, other, detached = makeProfile(), makeProfile(), makeProfile()
  addon.db = {
    global = { configVersion = version },
    profiles = { Default = active, Other = other },
    profile = detached,
  }
  addon.migrateConfig()
  -- Profiles written by an earlier v16 development build are converted on access.
  for _, profile in ipairs({ active, other, detached }) do
    addon.ListviewBag:MigrateLegacyMailAmounts(profile.listviewBag)
  end
  assert(addon.db.global.configVersion == 16)
  checkProfile(active)
  checkProfile(other)
  checkProfile(detached)
  addon.CONFIG_MIGRATIONS[16]()
  checkProfile(active)
end
local existing = makeProfile()
existing.listviewBag.auctionIneligibleOverrides = { existing = true }
addon.db = { global = { configVersion = 15 }, profile = existing }
addon.migrateConfig()
assert(existing.listviewBag.auctionIneligibleOverrides.existing,
  "Repeating migration must preserve existing overrides")
local alreadyCurrent = makeProfile()
addon.db = { global = { configVersion = 16 }, profile = alreadyCurrent }
addon.migrateConfig()
assert(alreadyCurrent.listviewBag.mailAmounts[pending])
addon.ListviewBag:MigrateLegacyMailAmounts(alreadyCurrent.listviewBag)
assert(alreadyCurrent.listviewBag.mailAssignments[common] == 3
  and alreadyCurrent.listviewBag.mailQueues[pending][1].remaining == 17
  and not alreadyCurrent.listviewBag.mailAssignments[pending])
local warnings = 0
--- Count migration warnings without discarding malformed saved data.
function addon.prn() warnings = warnings + 1 end
local incomplete = { mailAssignments = {}, mailAmounts = { missing = { remaining = 2 } } }
addon.ListviewBag:MigrateLegacyMailAmounts(incomplete)
addon.ListviewBag:MigrateLegacyMailAmounts(incomplete)
assert(incomplete.mailAmounts.missing.remaining == 2 and warnings == 1,
  "Unmigratable legacy assignments must be retained and reported once")
print("Listview bag flag migration tests passed")
