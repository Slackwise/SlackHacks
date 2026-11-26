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
assert(addon.CONFIG_VERSION == 16 and addon.CONFIG_VERSION_RELEASES[13] == 27
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
other.dialog.autoClickFirstOptionServicesOnly = false
detached.dialog.autoClickFirstOptionVendorOnly = true
addon.CONFIG_MIGRATIONS[15]()
assert(active.dialog.autoClickFirstOptionServicesOnly == false)
assert(other.dialog.autoClickFirstOptionServicesOnly == true)
assert(detached.dialog.autoClickFirstOptionServicesOnly == true)
assert(rawget(active.dialog, "autoClickFirstOptionVendorOnly") == nil)
assert(rawget(other.dialog, "autoClickFirstOptionVendorOnly") == nil)
assert(rawget(detached.dialog, "autoClickFirstOptionVendorOnly") == nil)
addon.CONFIG_MIGRATIONS[15]()
assert(other.dialog.autoClickFirstOptionServicesOnly == true)

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
  assert(addon.db.global.configVersion == 16)
  assert(type(profile.dialog) == "table" and rawget(profile, "quest") == nil)
  if version >= 13 then
    assert(profile.dialog.autoClickFirstOptionServicesOnly and rawget(profile.dialog, "autoClickFirstOptionVendorOnly") == nil)
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
  autoClickFirstOptionServicesOnly = true, autoClickFirstOptionMythicOnly = true }
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
check(1) -- Shift-modified interact keys do not suppress auto-clicking.
shifted = false
forced = true
check(1) -- Explicit service-only mode bypasses forced service gossip.
check(nil, false) -- Forced gossip still cannot loop.
shifted = true
check(1) -- Shift-modified interact keys also work for forced service gossip.
shifted = false
s.autoClickFirstOptionServicesOnly = false
check(nil) -- General auto-clicking still respects forced gossip.
s.autoClickFirstOptionServicesOnly = true
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
check(1)
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
options[1].name = "I would like to check my deposit box."
check(1) -- Deposit boxes with a generic icon are recognized under forced gossip.
shifted = true
check(1)
shifted = false
options[1].name = "I would like to check my deposit box"
check(nil) -- The deposit box match is exact.
options[1].name = "Train me."
check(1) -- Trainers with a generic icon are recognized under forced gossip.
options[1].name = "Train me"
check(nil) -- The trainer match is exact.
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
s.autoClickFirstOptionServicesOnly = false
check(1)
s.autoClickFirstOptionServicesOnly = true
retail, forever = true, false
check(nil) -- Neither the Mythic countdown nor Service NPC mode allows generic chat.
running = true
check(1) -- A running Mythic overrides Service NPC mode.
forced = true
check(nil) -- The Mythic override still respects forced gossip for generic chat.
forced = false
running = false
options[1].icon = 132060
check(1) -- Service NPCs still work outside a Mythic run when both restrictions are on.
forced = true
check(1) -- Service NPC mode bypasses forced gossip on Retail too.
forced = false
options[1].icon = 132053
s.autoClickFirstOptionMythicOnly = false
check(nil) -- Service NPC mode is honored on Retail.
running = true
check(nil) -- A running Mythic only overrides Service NPC mode when its option is on.
running = false
s.autoClickFirstOptionServicesOnly = false
check(1)
s.autoClickFirstOptionMythicOnly = true
check(nil) -- Mythic-only mode alone still waits for the run timer.
s.autoClickFirstOptionMythicOnly = false
s.autoClickFirstOptionServicesOnly = true
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

-- Quest automation also remains active for Shift-modified interactions.
local questAction, greetingActive, greetingAvailable, questChoices = nil, 0, 0, 0
--- Record a gossip quest selection.
---@param id number Quest ID.
function C_GossipInfo.SelectAvailableQuest(id) questAction = "available:" .. id end
--- Record a completed gossip quest selection.
---@param id number Quest ID.
function C_GossipInfo.SelectActiveQuest(id) questAction = "active:" .. id end
--- Return the number of active greeting quests.
---@return number
function GetNumActiveQuests() return greetingActive end
--- Return the number of available greeting quests.
---@return number
function GetNumAvailableQuests() return greetingAvailable end
--- Return a completed greeting quest.
---@return string, boolean
function GetActiveTitle() return "Quest", true end
--- Record an active greeting quest selection.
---@param index number Quest index.
function SelectActiveQuest(index) questAction = "greeting-active:" .. index end
--- Record an available greeting quest selection.
---@param index number Quest index.
function SelectAvailableQuest(index) questAction = "greeting-available:" .. index end
--- Record acceptance of a quest.
function AcceptQuest() questAction = "accept" end
--- Return whether a quest can be completed.
---@return boolean
function IsQuestCompletable() return true end
--- Return the money required for a quest.
---@return number
function GetQuestMoneyToGet() return 0 end
--- Record completion of the quest progress page.
function CompleteQuest() questAction = "progress" end
--- Return the number of reward choices.
---@return number
function GetNumQuestChoices() return questChoices end
--- Record claiming a quest reward.
---@param index number Reward index.
function GetQuestReward(index) questAction = "reward:" .. index end

shifted, s.autoAccept, s.autoComplete = true, true, true
available = { { questID = 10 } }
module:GOSSIP_SHOW()
assert(questAction == "available:10")
available, activeQuests = {}, { { questID = 11, isComplete = true } }
module:GOSSIP_SHOW()
assert(questAction == "active:11")
greetingActive, greetingAvailable = 1, 1
module:QUEST_GREETING()
assert(questAction == "greeting-active:1")
greetingActive = 0
module:QUEST_GREETING()
assert(questAction == "greeting-available:1")
module:QUEST_DETAIL()
assert(questAction == "accept")
module:QUEST_PROGRESS()
assert(questAction == "progress")
module:QUEST_COMPLETE()
assert(questAction == "reward:0")
questAction, questChoices = nil, 2
module:QUEST_COMPLETE()
assert(questAction == nil) -- Reward choices still require manual selection.

print("dialog automation and migration tests passed")
