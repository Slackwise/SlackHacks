-- Run with Lua 5.1 from the addon root: lua tests/combat_assist_tank.lua

local addon, module = {}, {}
--- Supply the addon without initializing the game UI.
---@return table addon
function addon:NewAddon() return addon end
--- Supply libraries for loading Init.lua.
---@param name string Library name.
---@return table library
function LibStub(name) return addon end
--- Supply unused initialization frames.
---@return table frame
function CreateFrame() return {} end
Enum, StaticPopupDialogs = {}, {}
assert(loadfile("Init.lua"))()

local foreverClient = false
--- Report whether the test is simulating WoW Forever.
---@return boolean forever
function addon.isForever() return foreverClient end

--- Copy a plain saved configuration for independent test cases.
---@param value any Original value.
---@return any copy
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end
--- Mimic WoW's table-clear helper.
---@param values table Table to clear.
function wipe(values) for key in pairs(values) do values[key] = nil end end
--- Reject unexpected config resets.
---@param reason string Reset reason.
function addon.resetConfig(reason) error(reason) end

for version = 0, 13 do
  local active = { combat = { raiseCastingNameplates = true,
    paladin = { trackHolyShockCharges = true, onlyInCombat = true, x = 42 } },
    nameplates = { raiseCastingNameplates = false } }
  local other = { combat = { raiseCastingNameplates = false,
    assistTankMacro = { enabled = true, macroName = "KEEP" } } }
  local detached = { combat = { raiseCastingNameplates = true } }
  addon.db = { global = { configVersion = version },
    profiles = { Default = active, Other = other }, profile = detached }
  addon.migrateConfig()
  assert(addon.db.global.configVersion == 14 and addon.CONFIG_VERSION_RELEASES[14] == 28)
  assert(active.nameplates.raiseCastingNameplates and detached.nameplates.raiseCastingNameplates)
  assert(other.nameplates.raiseCastingNameplates == false)
  assert(active.combat.raiseCastingNameplates == nil)
  assert(active.combat.paladin.trackHolyShockCharges and active.combat.paladin.x == 42)
  assert(other.combat.assistTankMacro.macroName == "KEEP" and other.combat.assistTankMacro.enabled)
  addon.CONFIG_MIGRATIONS[14]()
  assert(active.nameplates.raiseCastingNameplates and other.nameplates.raiseCastingNameplates == false)
end

local DEFAULT = "#showtooltip\n/assist [group] TANK\n/startattack"
local FOCUS = "#showtooltip\n/assist [@focus,help,nodead] focus; [group] TANK\n/startattack"
local playerClass = "WARRIOR"
--- Report the class used to select the generated tooltip.
---@return string class
function addon.getClassName() return playerClass end
--- Resolve expected bare tooltip directives for the current class.
---@param commands string Template.
---@return string commands
local function render(commands)
  local name
  if playerClass == "MAGE" then
    name = "Shoot"
  elseif playerClass == "HUNTER" then
    name = "Auto Shot"
  else
    name = "Attack"
  end
  local tooltip = name and (" " .. name) or ""
  return (commands:gsub("#showtooltip\n", "#showtooltip" .. tooltip .. "\n"))
end
--- Substitute a tank's name into a standard template.
---@param commands string Macro template.
---@param name string Tank name.
---@return string body Expanded macro.
local function renderTank(commands, name)
  return (render(commands):gsub("TANK", function() return name end))
end
local p = { enabled = false, macroName = "ASSIST_TANK", macroCommands = DEFAULT,
  useCustomMacro = false, addFocusAssist = false }
local callbacks, events, messages = {}, {}, {}
addon.db = { profile = { combat = { assistTankMacro = p } } }
--- Capture profile callbacks.
---@param event string Callback event.
---@param handler function Handler.
---@param owner table Handler owner.
function addon.db:RegisterCallback(event, handler, owner)
  callbacks[event] = function() handler(owner) end
end
--- Supply the new Combat module.
---@param name string Module name.
---@return table module
function addon:NewModule(name) assert(name == "Combat"); return module end
local moduleEnabled, combat = true, false
--- Report the addon's lifecycle state.
---@return boolean enabled
function module:IsEnabled() return moduleEnabled end
--- Capture registered event handlers.
---@param event string Event name.
---@param handler string|nil Handler method.
function module:RegisterEvent(event, handler) events[event] = handler or event end
--- Remove all event subscriptions.
function module:UnregisterAllEvents() events = {} end
--- Report combat lockdown.
---@return boolean inCombat
function InCombatLockdown() return combat end
--- Capture user-visible notifications.
---@param message string Notification.
function addon.prn(message) messages[#messages + 1] = message end

local grouped, raid, units = false, false, {}
--- Report group membership.
---@return boolean grouped
function IsInGroup() return grouped end
--- Report raid membership.
---@return boolean raid
function IsInRaid() return raid end
--- Count raid members.
---@return number count
function GetNumGroupMembers() return #units end
--- Count party members other than the player.
---@return number count
function GetNumSubgroupMembers() return #units end
--- Resolve a test unit token.
---@param token string Unit token.
---@return table|nil unit
local function unit(token) return units[tonumber(token:match("%d+$"))] end
--- Report a member's assigned role.
---@param token string Unit token.
---@return string role
function UnitGroupRolesAssigned(token) return unit(token).role end
--- Identify the player in a raid roster.
---@param token string Unit token.
---@param other string Comparison token.
---@return boolean same
function UnitIsUnit(token, other) return unit(token).player or false end
--- Return a tank's name and realm.
---@param token string Unit token.
---@return string|nil name
---@return string|nil realm
function UnitFullName(token) return unit(token).name, unit(token).realm end

MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS = 120, 3
local account = { { name = "ASSIST_TANK", body = "/say account untouched", icon = 1 } }
local macros, creates, edits, fail, truncate = {}, 0, 0, false, false
local resolvedIcon
--- Report account and character macro counts.
---@return number accountCount
---@return number characterCount
function GetNumMacros() return #account, #macros end
--- Read a macro by its account/character slot.
---@param index number Macro index.
---@return string|nil name
---@return number|nil icon
---@return string|nil body
function GetMacroInfo(index)
  local macro = index > MAX_ACCOUNT_MACROS and macros[index - MAX_ACCOUNT_MACROS] or account[index]
  if macro then return macro.name, resolvedIcon or macro.icon, macro.body end
end
--- Create a character macro, simulating API errors and truncation.
---@param name string Macro name.
---@param icon number|string Icon ID or texture name.
---@param body string Macro body.
---@param perCharacter boolean Character-only flag.
---@return number index
function CreateMacro(name, icon, body, perCharacter)
  assert(not combat and perCharacter and #macros < MAX_CHARACTER_MACROS)
  if fail then error("simulated macro error") end
  creates = creates + 1
  macros[#macros + 1] = { name = name, icon = icon, body = truncate and body:sub(1, 10) or body }
  return MAX_ACCOUNT_MACROS + #macros
end
--- Edit only a character macro, simulating API errors.
---@param index number Character macro index.
---@param name string Macro name.
---@param icon number|string Icon ID or texture name.
---@param body string Macro body.
---@return number index
function EditMacro(index, name, icon, body)
  assert(not combat and index > MAX_ACCOUNT_MACROS)
  if fail then error("simulated macro error") end
  edits = edits + 1
  macros[index - MAX_ACCOUNT_MACROS] = { name = name, icon = icon, body = body }
  return index
end

assert(loadfile("Combat.lua"))()
module:OnInitialize()
module:OnEnable()
for _, event in ipairs({ "GROUP_JOINED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
  "ROLE_CHANGED_INFORM", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do assert(events[event]) end
assert(creates == 0 and module:GetCommands() == DEFAULT)
module:SetOption("enabled", true)
assert(creates == 1 and macros[1].body == "#showtooltip Attack\n/startattack")
assert(macros[1].icon == "inv_misc_questionmark")
assert(messages[#messages] == "Assist Tank Macro recreated targeting: (no tank/pet)")
for _, class in ipairs({ "MAGE", "PRIEST", "WARLOCK" }) do
  playerClass = class
  module:Refresh()
  local assist = class == "WARLOCK" and "/assist [@pet,exists,nodead] pet\n" or ""
  assert(macros[1].body == "#showtooltip Shoot\n" .. assist .. "/cast !Shoot")
end
playerClass = "HUNTER"
module:Refresh()
assert(macros[1].body == "#showtooltip Auto Shot\n/assist [@pet,exists,nodead] pet\n/startattack")
assert(messages[#messages] == "Assist Tank Macro recreated targeting: Pet")
playerClass = "WARRIOR"
--- Simulate a wand equipped by a character outside the usual wand classes.
---@return number itemID
function GetInventoryItemID() return 123 end
--- Report the equipped item's weapon class and wand subclass.
---@return nil, nil, nil, nil, nil, number, number
function GetItemInfoInstant() return nil, nil, nil, nil, nil, 2, 19 end
module:Refresh()
assert(macros[1].body == "#showtooltip Shoot\n/cast !Shoot")
C_Spell = {
  --- Supply a localized Shoot name.
  ---@param spellID number Spell identifier.
  ---@return string name
  GetSpellName = function(spellID) assert(spellID == 5019); return "Localized Shoot" end,
}
module:Refresh()
assert(macros[1].body == "#showtooltip Localized Shoot\n/cast !Localized Shoot")
C_Spell, GetInventoryItemID, GetItemInfoInstant = nil, nil, nil
macros[1].icon = 1
module:SaveMacro()
assert(macros[1].body == "#showtooltip Attack\n/startattack" and macros[1].icon == "inv_misc_questionmark")
assert(macros[1].name == "ASSIST_TANK" and account[1].body == "/say account untouched")
grouped = true
units = { { name = "Tank", role = "TANK" } }
module:SetOption("enabled", true)
assert(creates == 1 and macros[1].name == "ASSIST_TANK")
assert(macros[1].body == renderTank(DEFAULT, "Tank"))
for _, class in ipairs({ "HUNTER", "WARLOCK" }) do
  playerClass = class
  module:Refresh()
  assert(macros[1].body:find("/assist [group] Tank", 1, true))
  assert(not macros[1].body:find("[group,exists,nodead]", 1, true))
  assert(not macros[1].body:find("@pet", 1, true))
end
playerClass = "WARRIOR"
module:Refresh()
macros[1].icon = 999
local iconEdits = edits
module:SaveMacro()
assert(edits == iconEdits + 1 and macros[1].icon == "inv_misc_questionmark")
resolvedIcon = 132220
local previousMessages = #messages
assert(module:SaveMacro())
assert(messages[#messages] == "Assist Tank Macro recreated targeting: Tank")
assert(#messages == previousMessages + 1)
local resolvedEdits = edits
module:Refresh()
assert(edits == resolvedEdits and #messages == previousMessages + 1)
resolvedIcon = nil
assert(account[1].body == "/say account untouched")
module:Refresh()
local unchangedEdits = edits
module:Refresh()
assert(creates == 1 and edits == unchangedEdits)
units[1] = { name = "Other", realm = "Other Realm", role = "TANK" }
module[events.ROLE_CHANGED_INFORM](module)
assert(macros[1].body == renderTank(DEFAULT, "Other-OtherRealm") and edits == unchangedEdits + 1)
foreverClient = true
module:Refresh()
assert(macros[1].body == renderTank(DEFAULT, "Other Other Realm"))
assert(messages[#messages] == "Assist Tank Macro recreated targeting: Other Other Realm")
foreverClient = false
module:Refresh()
assert(macros[1].body == renderTank(DEFAULT, "Other-OtherRealm"))
module:SetOption("addFocusAssist", true)
assert(module:GetCommands() == FOCUS and macros[1].body == renderTank(FOCUS, "Other-OtherRealm"))
assert(messages[#messages] == "Assist Tank Macro recreated targeting: Other-OtherRealm")
module:SetOption("useCustomMacro", true)
module:SetDraft("macroCommands", "/assist TANK\n/target TANK")
local before = macros[1].body
module:Refresh()
assert(macros[1].body == "/assist Other-OtherRealm\n/target Other-OtherRealm")
assert(module:SaveMacro())
assert(macros[1].body == "/assist Other-OtherRealm\n/target Other-OtherRealm")
assert(p.macroCommands == "/assist TANK\n/target TANK")
module:SetDraft("macroCommands", "#showtooltip Custom Spell\n/assist TANK\n/startattack")
assert(macros[1].body == "#showtooltip Custom Spell\n/assist Other-OtherRealm\n/startattack")
module:SetDraft("macroCommands", "/assist TANK\n/target TANK")

-- Validate exact boundaries before and after name substitution, without saving rejected drafts.
assert(module:ValidateMacro("OK", "TANK" .. string.rep("x", 251), "Tank") == true)
assert(type(module:ValidateMacro("OK", "TANK" .. string.rep("x", 252))) == "string")
assert(type(module:ValidateMacro("OK", "TANK" .. string.rep("x", 251), "Longer")) == "string")
assert(type(module:ValidateMacro("OK", "TANK TANK" .. string.rep("x", 244), "Longer")) == "string")
assert(module:ValidateMacro("OK", "TANK" .. string.rep("\195\169", 125) .. "x", "Tank") == true)
assert(type(module:ValidateMacro("OK", "TANK" .. string.rep("\195\169", 126))) == "string")
assert(type(module:ValidateMacro("", DEFAULT)) == "string")
assert(type(module:ValidateMacro(string.rep("x", 17), DEFAULT)) == "string")
assert(type(module:ValidateMacro("line\nbreak", DEFAULT)) == "string")
module:SetDraft("macroCommands", "/assist focus")
before = macros[1].body
assert(not module:SaveMacro() and macros[1].body == before and p.macroCommands:find("TANK"))
module:SetDraft("macroCommands", "TANK" .. string.rep("x", 251))
assert(not module:SaveMacro() and macros[1].body == before)
module:ResetCommands()
assert(module:GetDraft("macroCommands") == FOCUS and macros[1].body == renderTank(FOCUS, "Other-OtherRealm"))
assert(module:SaveMacro() and macros[1].body == renderTank(FOCUS, "Other-OtherRealm"))
module:SetOption("useCustomMacro", false)

-- Combat changes coalesce and resolve the latest tank, not a stale event's name.
combat = true
units[1].name = "CombatTank"
before = macros[1].body
module:Refresh()
module:SaveMacro()
module:SetOption("useCustomMacro", true)
module:SetDraft("macroCommands", "/assist TANK\n/startattack")
assert(p.macroCommands == "/assist TANK\n/startattack")
assert(macros[1].body == before)
units[1].name = "Latest"
combat = false
module:PLAYER_REGEN_ENABLED()
assert(macros[1].body == "/assist Latest-OtherRealm\n/startattack")
module:SetOption("useCustomMacro", false)
assert(macros[1].body == renderTank(FOCUS, "Latest-OtherRealm"))
combat = true
units[1].name = "Disabled"
module:Refresh()
module:SetOption("enabled", false)
before = macros[1].body
combat = false
module:PLAYER_REGEN_ENABLED()
assert(macros[1].body == before)
module:SetOption("enabled", true)

-- No group/tank uses current-target attack; raid selection skips the player and picks the first other tank.
before = macros[1].body
grouped = false
module:Refresh()
assert(macros[1].body == "#showtooltip Attack\n/startattack")
module:SetOption("useCustomMacro", true)
assert(macros[1].body == "#showtooltip Attack\n/startattack")
module:SetOption("useCustomMacro", false)
grouped, raid = true, true
units = { { player = true, name = "Self", role = "TANK" },
  { name = "Dps", role = "DAMAGER" }, { name = "RaidTank", role = "TANK" } }
module:Refresh()
assert(macros[1].body == renderTank(FOCUS, "RaidTank"))
combat, grouped = true, false
module:Refresh()
assert(macros[1].body == renderTank(FOCUS, "RaidTank"))
combat = false
module:PLAYER_REGEN_ENABLED()
assert(macros[1].body == "#showtooltip Attack\n/startattack")
grouped = true
module:Refresh()
assert(macros[1].body == renderTank(FOCUS, "RaidTank"))
units[3].role = "HEALER"
before = macros[1].body
assert(module:SaveMacro() and macros[1].body == "#showtooltip Attack\n/startattack")
units[3].role = "TANK"

-- Renaming creates another character macro; full slots do not prevent editing an existing one.
module:SetDraft("macroName", "SECOND")
assert(#macros == 2 and macros[2].name == "SECOND")
assert(module:SaveMacro() and #macros == 2 and macros[1].name == "ASSIST_TANK")
macros[3] = { name = "FULL", icon = 1, body = "/say full" }
module:SetDraft("macroName", "NO_SLOT")
module:SaveMacro()
assert(#macros == 3 and messages[#messages]:find("No free", 1, true))
module:SetDraft("macroName", "SECOND")
units[3].name = "NewTank"
assert(module:SaveMacro() and macros[2].body == renderTank(FOCUS, "NewTank"))
fail = true
units[3].name = "ErrorTank"
module:Refresh()
assert(messages[#messages]:find("simulated macro error", 1, true))
local messageCount = #messages
module:Refresh()
assert(#messages == messageCount)
fail = false
macros[3] = nil
truncate = true
module:SetDraft("macroName", "TRUNCATED")
assert(messages[#messages]:find("did not save the complete", 1, true))
macros[3] = nil
module:SaveMacro()
assert(messages[#messages]:find("did not save the complete", 1, true))
truncate = false

-- Profile callbacks reload editor values and cancel updates when the new profile is disabled.
module:SetDraft("macroName", "UNSAVED")
p = copy(p)
p.enabled, p.macroName = false, "PROFILE_TWO"
addon.db.profile = { combat = { assistTankMacro = p } }
callbacks.OnProfileChanged()
assert(module:GetDraft("macroName") == "PROFILE_TWO")
module:SetDraft("macroName", "DISCARD")
p.macroName = "PROFILE_TWO" -- Simulate the persisted name restored by a profile reset.
callbacks.OnProfileReset()
assert(module:GetDraft("macroName") == "PROFILE_TWO")
module:OnDisable()
assert(next(events) == nil)

-- Load the actual options and decorators, verifying Paladin's nested WIP and tester-only gates.
addon.Talents = { MAX_SPECS = 0 }
addon.Enum.SelfVendorMode = {
  FLASK = 1, OIL = 2, AUGMENT_RUNES = 3, VANTUS_RUNE = 4, CONSUMABLES = 5, AUGMENTS = 6,
}
addon.SELF_VENDOR_MODES = {}
for index = 1, 6 do
  addon.SELF_VENDOR_MODES[index] = { key = "mode" .. index, name = "Mode", description = "Mode" }
end
local retail, tester = true, true
--- Report the test client.
---@return boolean retail
function addon.isRetail() return retail end
--- Report the current tester gate.
---@return boolean tester
function addon.isSlackwise() return tester end
--- Supply a version for the options heading.
---@return string version
function addon.getAddonVersion() return "28" end
assert(loadfile("Options.lua"))()
assert(addon.dbDefaults.profile.combat.raiseCastingNameplates == nil)
assert(addon.dbDefaults.profile.nameplates.raiseCastingNameplates == false)
assert(addon.dbDefaults.profile.combat.assistTankMacro.enabled == false)
assert(addon.dbDefaults.profile.combat.assistTankMacro.macroCommands == DEFAULT)
assert(addon.options.args.nameplates.args.paladin == nil)
local group = addon.options.args.combat.args.assistTankMacro
assert(group.args.enabled.order < group.args.addFocusAssist.order
  and group.args.addFocusAssist.order < group.args.macroName.order)
local customGroup = group.args.customMacro
local custom = customGroup.args
assert(customGroup.name == "Custom Macro" and customGroup.type == "group" and customGroup.inline)
assert(group.args.useCustomMacro == nil and group.args.macroCommands == nil)
assert(group.get({ "macroName" }) == "PROFILE_TWO")
assert(custom.macroCommands.multiline == 5 and custom.macroCommands.disabled())
assert(custom.resetCommands.disabled() and custom.saveMacro.disabled())
assert(not group.args.addFocusAssist.disabled())
group.set({ "customMacro", "useCustomMacro" }, true)
assert(not custom.macroCommands.disabled() and group.args.addFocusAssist.disabled())
assert(not custom.resetCommands.disabled() and not custom.saveMacro.disabled())
group.set({ "customMacro", "macroCommands" }, "/assist TANK")
assert(group.get({ "customMacro", "macroCommands" }) == "/assist TANK")
custom.resetCommands.func()
assert(group.get({ "customMacro", "macroCommands" }) == FOCUS)
custom.saveMacro.func()
assert(p.macroCommands == FOCUS)
group.set({ "customMacro", "useCustomMacro" }, false)
assert(custom.macroCommands.disabled() and custom.resetCommands.disabled() and custom.saveMacro.disabled())
local recreate = group.args.recreateMacroNow
assert(recreate.name == "Recreate Macro Now" and recreate.type == "execute")
assert(group.args.macroName.order < recreate.order and recreate.order < customGroup.order)
assert(recreate.disabled())
p.enabled, grouped = true, false
macros = {}
assert(not recreate.disabled() and not p.useCustomMacro)
recreate.func()
assert(#macros == 1 and macros[1].name == "PROFILE_TWO")
assert(macros[1].body == "#showtooltip Attack\n/startattack" and macros[1].icon == "inv_misc_questionmark")
macros[1].body = "/say outdated"
recreate.func()
assert(macros[1].body == "#showtooltip Attack\n/startattack")

--- Supply the profile options expected during registration.
---@return table options
function addon:GetOptionsTable() return { args = {} } end
--- Suppress unrelated library/UI registration.
function addon:RegisterOptionsTable() end
--- Supply a mock Settings category.
---@return table category
function addon:AddToBlizOptions() return {} end
--- Suppress unrelated minimap UI work.
function addon.updateMinimapIcon() end
--- Supply an anonymous test lookup key.
---@return string key
function addon.getBattletag() return "test" end
addon.db.global = { configVersion = 14, addonVersion = "28" }
addon.registerOptions()
local paladin = addon.options.args.combat.args.paladin
assert(paladin.name == "(WIP) Paladin" and paladin.args.wipWarning)
assert(type(paladin.args.trackHolyShockCharges.confirm({}, true)) == "string")
assert(paladin.args.trackHolyShockCharges.confirm({}, false) == nil)
assert(not paladin.hidden())
tester = false
assert(paladin.hidden())
tester, retail = true, false
assert(paladin.hidden())
assert(addon.options.args.combat.name == "Combat" and not group.args.enabled.confirm)
assert(addon.options.args.nameplates.name == "(WIP) Nameplates")

-- The renamed settings still enable casting-nameplate lifts and disabling still stops them.
addon.db.profile.nameplates = { raiseCastingNameplates = true }
local casterFrame, otherFrame = { level = 5 }, { level = 10 }
--- Report an unprotected mock nameplate frame.
---@return boolean forbidden
function casterFrame:IsForbidden() return false end
otherFrame.IsForbidden = casterFrame.IsForbidden
--- Return the mock frame's current level.
---@return number level
function casterFrame:GetFrameLevel() return self.level end
otherFrame.GetFrameLevel = casterFrame.GetFrameLevel
--- Apply a caster's lifted level.
---@param level number Desired level.
function casterFrame:SetFrameLevel(level) self.level = level end
local casterPlate, otherPlate = { UnitFrame = casterFrame }, { UnitFrame = otherFrame }
C_NamePlate = {
  --- Return the casting unit's nameplate.
  ---@param token string Unit token.
  ---@return table nameplate
  GetNamePlateForUnit = function(token) return casterPlate end,
  --- Return all visible plates for overlap reconciliation.
  ---@return table plates
  GetNamePlates = function() return { casterPlate, otherPlate } end,
}
local tickerCancelled = false
C_Timer = {
  --- Supply a cancellable level-reapplication ticker.
  ---@param interval number Tick interval.
  ---@param handler function Tick callback.
  ---@return table ticker
  NewTicker = function(interval, handler)
    return {
      --- Record ticker cleanup.
      Cancel = function() tickerCancelled = true end,
    }
  end,
}
--- Report the test casting unit as attackable.
---@param attacker string Attacker token.
---@param target string Target token.
---@return boolean hostile
function UnitCanAttack(attacker, target) return true end
--- Suppress debug-only frame-level messages.
---@param message string Debug message.
function addon.log(message) end
assert(loadfile("Nameplates.lua"))()
addon.handleCasts(addon, "UNIT_SPELLCAST_START", "nameplate1")
assert(casterFrame.level > otherFrame.level)
addon.db.profile.nameplates.raiseCastingNameplates = false
before = casterFrame.level
addon.handleCasts(addon, "UNIT_SPELLCAST_START", "nameplate2")
assert(casterFrame.level == before)
addon.resetNameplateCastLift()
assert(tickerCancelled and addon.lastNameplateLevel == 0)

print("Combat assist macro, migration, and options tests passed")
