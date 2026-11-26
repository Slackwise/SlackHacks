-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_flag_migration.lua

local addon = {}
--- Supply the addon used during initialization.
---@return table addon
function addon:NewAddon() return addon end
--- Supply the unused initialization libraries.
---@return table library
function LibStub() return addon end
--- Supply the unused initialization frames.
---@return table frame
function CreateFrame() return {} end
Enum, StaticPopupDialogs = {}, {}
assert(loadfile("Init.lua"))()
--- Reject any migration that resets the user's configuration.
---@param reason string Reset reason.
function addon.resetConfig(reason) error(reason) end
--- Clear an optional migrated log table.
---@param values table Table to clear.
function wipe(values) for key in pairs(values) do values[key] = nil end end

local grey = "Grey\0310\03110\031"
local common = "Common\0311\03110\031"
local fields = { "trashItems", "protectedItems", "auctionItems", "bankItems", "mailItems" }
--- Create a profile with legacy, current, and unknown-quality flags.
---@return table profile
local function makeProfile()
  local bag = { enabled = true }
  for _, field in ipairs(fields) do
    bag[field] = {
      [grey] = true,
      [common] = { quality = 1 },
      legacyGrey = { name = "Grey", quality = 0 },
      unknown = { name = "Unknown" },
    }
  end
  return { listviewBag = bag }
end
--- Confirm that only identifiable grey flags were removed.
---@param profile table Profile to check.
local function checkProfile(profile)
  assert(profile.listviewBag.enabled)
  for _, field in ipairs(fields) do
    local items = profile.listviewBag[field]
    assert(items[grey] == nil and items.legacyGrey == nil, field .. " must remove grey flags")
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
  assert(addon.db.global.configVersion == 16)
  checkProfile(active)
  checkProfile(other)
  checkProfile(detached)
  addon.CONFIG_MIGRATIONS[16]()
  checkProfile(active)
end
print("Listview bag flag migration tests passed")
