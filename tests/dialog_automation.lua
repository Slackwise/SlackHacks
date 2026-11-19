-- Run with Lua 5.1 from the addon root: lua tests/dialog_automation.lua

local addon = {}
--- Supplies the addon instance required by Init.lua.
---@return table
function addon:NewAddon() return addon end
--- Supplies libraries without initializing the addon.
---@param name string Library name.
---@return table
function LibStub(name) return addon end
--- Supplies the unused initialization frames.
---@return table
function CreateFrame() return {} end
Enum = {}
StaticPopupDialogs = {}
assert(loadfile("Init.lua"))()
assert(addon.CONFIG_VERSION == 15 and addon.CONFIG_VERSION_RELEASES[13] == 27
  and addon.CONFIG_VERSION_RELEASES[14] == 28 and addon.CONFIG_VERSION_RELEASES[15] == 30)

local legacy = { enabled = true, autoAccept = true, autoComplete = false,
  autoClickFirstOption = true, autoClickFirstOptionMythicOnly = true,
  numberKeys = true, spacebar = true, questItemButton = true }
-- AceDB materializes the new defaults before migrations run on the active profile.
local active = { quest = legacy, dialog = { enabled = false, autoAccept = false,
  autoComplete = false, autoClickFirstOption = false, autoClickFirstOptionMythicOnly = false,
  numberKeys = false, spacebar = false, questItemButton = false } }
local other = { quest = { enabled = false, autoAccept = true },
  dialog = { enabled = true, autoClickFirstOptionVendorOnly = true } }
local detached = { quest = { enabled = false, spacebar = true } }
addon.db = { profiles = { Default = active, Other = other }, profile = detached }
addon.CONFIG_MIGRATIONS[13]()
for key, value in pairs(legacy) do assert(active.dialog[key] == value, key) end
assert(rawget(active, "quest") == nil and rawget(other, "quest") == nil)
assert(active.dialog.autoClickFirstOptionVendorOnly == false)
assert(other.dialog.enabled == false and other.dialog.autoAccept == true)
assert(other.dialog.autoClickFirstOptionVendorOnly == true)
assert(detached.dialog.spacebar == true and detached.dialog.enabled == false)
addon.CONFIG_MIGRATIONS[13]()
assert(active.dialog.enabled and other.dialog.autoClickFirstOptionVendorOnly)

-- A saved old value must beat a new default materialized in the active profile.
other.dialog.autoClickFirstOptionServiceNPCOnly = false
detached.dialog.autoClickFirstOptionVendorOnly = true
addon.CONFIG_MIGRATIONS[15]()
assert(active.dialog.autoClickFirstOptionServiceNPCOnly == false)
assert(other.dialog.autoClickFirstOptionServiceNPCOnly == true)
assert(detached.dialog.autoClickFirstOptionServiceNPCOnly == true)
assert(rawget(active.dialog, "autoClickFirstOptionVendorOnly") == nil)
assert(rawget(other.dialog, "autoClickFirstOptionVendorOnly") == nil)
assert(rawget(detached.dialog, "autoClickFirstOptionVendorOnly") == nil)
addon.CONFIG_MIGRATIONS[15]()
assert(other.dialog.autoClickFirstOptionServiceNPCOnly == true)

local module = {}
--- Supplies the renamed dialog module.
---@param name string Module name.
---@return table
function addon:NewModule(name)
  assert(name == "Dialog")
  return module
end
--- Reports an enabled module without initializing secure UI frames.
---@return boolean
function module:IsEnabled() return true end
--- Mimics WoW's table-clear helper.
---@param values table
function wipe(values) for key in pairs(values) do values[key] = nil end end
--- Fails the test if a supported migration path would reset user settings.
---@param reason string Migration failure.
function addon.resetConfig(reason) error(reason) end
for version = 0, 14 do
  local profile = {}
  if version >= 13 then profile.dialog = { autoClickFirstOptionVendorOnly = true } end
  addon.db = { global = { configVersion = version }, profile = profile,
    profiles = { Default = profile } }
  addon.migrateConfig()
  assert(addon.db.global.configVersion == 15)
  assert(type(profile.dialog) == "table" and rawget(profile, "quest") == nil)
  if version >= 13 then
    assert(profile.dialog.autoClickFirstOptionServiceNPCOnly and rawget(profile.dialog, "autoClickFirstOptionVendorOnly") == nil)
  end
end
--- Keeps secure frame binding work inactive in this isolated automation test.
---@return boolean
function InCombatLockdown() return false end

local shifted, forced, retail, forever, running = false, false, false, true, false
local now, selected = 10, nil
local available, activeQuests, options = {}, {}, {}
--- Reports the current Shift state.
---@return boolean
function IsShiftKeyDown() return shifted end
--- Supplies monotonic time for the repeat guard.
---@return number
function GetTime() return now end
--- Reports the mocked game client.
---@return boolean
function addon.isRetail() return retail end
--- Reports the mocked Forever client.
---@return boolean
function addon.isForever() return forever end
Enum.WorldElapsedTimerTypes = { ChallengeMode = 1 }
C_ChallengeMode = {
  --- Reports an active Mythic challenge.
  ---@return boolean
  IsChallengeModeActive = function() return true end,
}
--- Supplies the challenge timer ID.
---@return number
function GetWorldElapsedTimers() return 1 end
--- Supplies countdown or running challenge time.
---@return string, number, number
function GetWorldElapsedTime() return "Mythic", running and 1 or 0, 1 end
C_GossipInfo = {
  --- Supplies available quests.
  ---@return table
  GetAvailableQuests = function() return available end,
  --- Supplies active quests.
  ---@return table
  GetActiveQuests = function() return activeQuests end,
  --- Supplies dialog options.
  ---@return table
  GetOptions = function() return options end,
  --- Reports whether gossip must remain manual.
  ---@return boolean
  ForceGossip = function() return forced end,
  --- Records the selected gossip option.
  ---@param id number
  SelectOption = function(id) selected = id end,
  --- Records selection on clients using option indices.
  ---@param index number
  SelectOptionByIndex = function(index) selected = index end,
}
assert(loadfile("Dialog.lua"))()
assert(addon.Dialog == module and addon.Quest == nil)
local s = { enabled = true, autoClickFirstOption = true,
  autoClickFirstOptionServiceNPCOnly = true, autoClickFirstOptionMythicOnly = true }
addon.db = { profile = { dialog = s } }

--- Opens the mocked dialog and checks whether it advanced.
---@param expected number|nil Expected selected option.
---@param advance boolean|nil Whether to advance beyond the repeat guard.
local function check(expected, advance)
  selected = nil
  if advance ~= false then now = now + 3 end
  module:GOSSIP_SHOW()
  assert(selected == expected, "unexpected selection: " .. tostring(selected))
end

options = { { gossipOptionID = 1, orderIndex = 1, icon = 132060, name = "Localized vendor text" } }
check(1) -- Forever ignores the hidden Mythic restriction.
check(nil, false) -- Reopened gossip cannot loop.
check(1)
shifted = true
check(nil)
shifted = false
forced = true
check(1) -- Explicit service-only mode bypasses forced service gossip.
check(nil, false) -- Forced gossip still cannot loop.
shifted = true
check(nil) -- Shift still suppresses the forced service shortcut.
shifted = false
s.autoClickFirstOptionServiceNPCOnly = false
check(nil) -- General auto-clicking still respects forced gossip.
s.autoClickFirstOptionServiceNPCOnly = true
for _, icon in ipairs({ 132050, 132051, 132056, 132057, 132058, 528409, 1130518, 1673939 }) do
  options[1].icon = icon
  check(1) -- Recognized services work even when forced gossip is enabled.
end
for _, icon in ipairs({ 132052, 132053, 132054, 132055, 132059 }) do
  options[1].icon = icon
  check(nil) -- Generic chat and potentially consequential actions remain manual.
end
options[1].icon = 132050
options[1].status = 1
check(nil)
options[1].status = nil
options[1].spellID = 123
check(nil)
options[1].spellID = nil
options[1].rewards = { {} }
check(nil)
options[1].rewards = nil
options[1].icon = 132053
options[1].name = "I want to browse your goods."
check(1) -- Preserve the existing vendor text match even with a generic icon.
options[1].name = "I need a ride."
check(1) -- A ride with a generic icon is recognized even under forced gossip.
shifted = true
check(nil)
shifted = false
options[1].status = 1
check(nil)
options[1].status = nil
options[2] = { gossipOptionID = 2, orderIndex = 2, name = "Tell me more." }
check(nil)
options[2] = nil
available = { { questID = 10 } }
check(nil)
available = {}
options[1].name = "I need a ride"
check(nil) -- The text match is exact.
options[1].name = "Localized service text"
options[2] = { gossipOptionID = 2, orderIndex = 2, name = "Tell me more." }
check(nil)
options[2] = nil
available = { { questID = 10 } }
check(nil)
available = {}
activeQuests = { { questID = 11 } }
check(nil)
activeQuests = {}
options[1].name = "Tell me more."
options[1].icon = 132053
check(nil)
forced = false
s.autoClickFirstOptionServiceNPCOnly = false
check(1)
s.autoClickFirstOptionServiceNPCOnly = true
retail, forever = true, false
check(nil) -- Retail still honors Mythic countdowns.
running = true
check(1) -- Retail ignores the hidden service restriction.
forced = true
check(nil) -- A hidden service setting must not bypass forced gossip on Retail.
forced = false
running = false
s.autoClickFirstOptionMythicOnly = false
check(1)
s.autoClickFirstOption = false
check(nil)
s.autoClickFirstOption = true
retail, forever = false, true
forced = true
options[1] = { orderIndex = 1, name = "I want to browse your goods." }
check(1) -- Index-only gossip clients are supported.
s.autoClickFirstOption = false
check(nil) -- Service-only mode still requires its parent automation.
s.autoClickFirstOption = true
options = {}
check(nil)

print("dialog automation and migration tests passed")
