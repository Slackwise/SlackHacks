-- Run with Lua 5.1 from the addon root: lua tests/slackwise_combat_text.lua

local addon = {}
--- Supplies the addon instance required by Init.lua.
---@return table
function addon:NewAddon() return addon end
--- Supplies libraries without initializing the addon.
---@param name string Library name.
---@return table
function LibStub(name) return addon end
--- Supplies unused initialization frames.
---@return table
function CreateFrame() return {} end
--- Supplies unused group-icon markup when Core.lua loads.
---@return string
function CreateAtlasMarkup() return "" end
Enum = {}
StaticPopupDialogs = {}
WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, WOW_PROJECT_CAMELOT = 1, 2, 3
assert(loadfile("Init.lua"))()
assert(loadfile("Core.lua"))()

addon.CustomConfigs = {}
addon.MOUNT_IDS = {}
addon.BINDING_TYPE = { COMMAND = 1, MACRO = 2, CLICKCAST = 3 }
--- Leaves unrelated macro text unchanged during configuration loading.
---@param text string Macro text.
---@return string
function addon.multilineTrim(text) return text end
assert(loadfile("Slackwise.lua"))()

local personal = true
local values, writes, logging = {}, {}, false
--- Supplies the BattleTag used by the real personal-configuration gate.
---@return nil, string
function BNGetInfo() return nil, personal and addon.SLACKWISE_BATTLETAG or "Other" end
--- Returns nil for CVars unsupported by the mocked client.
---@param name string CVar name.
---@return string?
function GetCVar(name) return values[name] end
--- Records supported numeric CVar writes, rejecting boolean values.
---@param name string CVar name.
---@param value number CVar value.
function SetCVar(name, value)
  assert(values[name] ~= nil, "Unsupported CVar: " .. name)
  assert(type(value) == "number", "Non-numeric CVar: " .. name)
  values[name] = tostring(value)
  writes[name] = value
end
--- Reports or enables combat logging.
---@param enabled boolean? Whether to enable logging.
---@return boolean
function LoggingCombat(enabled)
  if enabled ~= nil then logging = enabled end
  return logging
end

local shared = {
  floatingCombatTextCombatLogPeriodicSpells = 1,
  floatingCombatTextPetMeleeDamage = 1,
  floatingCombatTextPetSpellDamage = 1,
}
local categories = {
  "Auras", "CombatState", "ComboPoints", "DamageReduction", "DodgeParryMiss",
  "EnergyGains", "FriendlyHealers", "HonorGains", "LowManaHealth",
  "PeriodicEnergyGains", "Reactives", "RepChanges",
}

for _, project in ipairs({ WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, WOW_PROJECT_CAMELOT }) do
  -- Cover legacy-only, _v2-only, and clients exposing both CVar generations.
  for _, generation in ipairs({ "legacy", "v2", "both" }) do
    WOW_PROJECT_ID = project
    values, writes, logging = {
      advancedCombatLogging = "0",
      nameplateShowOnlyNameForFriendlyPlayerUnits = "0",
      nameplateUseClassColorForFriendlyPlayerUnitNames = "0",
      nameplateSimplifiedScale = "1",
      enableFloatingCombatText = "0",
      floatingCombatTextFloatMode = "2",
    }, {}, false
    local expected = {}
    for name, value in pairs(shared) do
      values[name], expected[name] = "0", tostring(value)
    end
    for _, category in ipairs({ "CombatDamage", "CombatHealing" }) do
      for _, suffix in ipairs({ "", "_v2" }) do
        if generation == "both" or (generation == "legacy" and suffix == "")
          or (generation == "v2" and suffix == "_v2") then
          local name = "floatingCombatText" .. category .. suffix
          local target = project == WOW_PROJECT_MAINLINE and "0" or "1"
          values[name], expected[name] = target == "0" and "1" or "0", target
        end
      end
    end
    for _, category in ipairs(categories) do
      for _, suffix in ipairs({ "", "_v2" }) do
        if generation == "both" or (generation == "legacy" and suffix == "")
          or (generation == "v2" and suffix == "_v2") then
          local name = "floatingCombatText" .. category .. suffix
          values[name] = "0"
          expected[name] = project == WOW_PROJECT_MAINLINE and "0" or "1"
        end
      end
    end
    addon.setCVars()
    for name, target in pairs(expected) do assert(values[name] == target, name) end
    assert(values.enableFloatingCombatText == (project == WOW_PROJECT_MAINLINE and "0" or "1"))
    assert(values.floatingCombatTextFloatMode == "2", "Scroll mode must remain unchanged")
    assert(values.nameplateShowOnlyNameForFriendlyPlayerUnits == (project == WOW_PROJECT_MAINLINE and "1" or "0"))
    assert(logging)
    if project == WOW_PROJECT_MAINLINE then
      assert(writes.enableFloatingCombatText == nil)
      for _, category in ipairs(categories) do
        assert(writes["floatingCombatText" .. category] == nil)
        assert(writes["floatingCombatText" .. category .. "_v2"] == nil)
      end
    end
    writes = {}
    addon.setCVars()
    assert(next(writes) == nil, "Repeated application must not rewrite unchanged CVars")
    personal = false
    values.enableFloatingCombatText = "0"
    addon.setSlackwiseCvars()
    assert(next(writes) == nil, "Personal preferences must not affect other users")
    personal = true
  end
end

print("Slackwise combat text tests passed")
