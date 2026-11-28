-- Run with Lua 5.1 from the addon root: lua tests/self_vendor_forever_realm.lua
local forever, personal = false, true
SlackHacks = setmetatable({ db = { profile = { selfVendor = { source = "wowhead" } } } }, { __index = _G })
SlackHacks.Self = SlackHacks
--- Create the Self Vendor module without the game UI.
---@return table module
function SlackHacks:NewModule() return {} end
--- Report the simulated client flavor.
---@return boolean forever
function SlackHacks.isForever() return forever end
--- Enable the personal-override path for this test.
---@return boolean enabled
function SlackHacks.isSlackwise() return personal end
--- Supply unused group-icon markup when Core.lua loads.
---@return string markup
function CreateAtlasMarkup() return "" end
--- Discard debug output.
function SlackHacks.log() end
--- Supply the requesting player's class.
---@return string, string className, classFile
function UnitClass() return "Mage", "MAGE" end
local unitNames = { player = { "Owner", "Person" }, target = { "Aster", "Realm" } }
--- Supply the two name parts exposed for a resolved unit.
---@param unit string Unit token.
---@return string|nil name
---@return string|nil secondPart
function UnitFullName(unit)
  local parts = unitNames[unit]
  if parts then return parts[1], parts[2] end
end
strlower, strupper = string.lower, string.upper
Enum = { SelfVendorMode = { FLASK = 1, CONSUMABLES = 2, AUGMENTS = 3, OIL = 4,
  AUGMENT_RUNES = 5, VANTUS_RUNE = 6 } }
SlackHacks.SELF_VENDOR_MODES = { [1] = {} }
SlackHacks.ENHANCEMENTS_BIS = { wowhead = { MAGE = { TEST = { Flask = "Default Flask" } } } }
SlackHacks.ENHANCEMENTS_BIS_OVERRIDES = {
  ["Aster-Realm"] = { Flask = "Custom Flask" },
  ["Aster Dawn"] = { Flask = "Forever Flask" },
  ["Owner Person"] = { Flask = "Owner Flask" },
}
SlackHacks.ITEM_NAMES = { ["Default Flask"] = 1, ["Custom Flask"] = 2,
  ["Forever Flask"] = 3, ["Owner Flask"] = 4 }
SlackHacks.ITEM_NAMES_BY_ID = { [1] = "Default Flask", [2] = "Custom Flask",
  [3] = "Forever Flask", [4] = "Owner Flask" }
SlackHacks.SLOT_IDS = {}
SlackHacks.RUNE_ITEM_NAMES, SlackHacks.RUNE_ITEM_IDS = { "Rune" }, { 3 }
SlackHacks.CURRENT_VANTUS_RUNE_NAME = "Vantus Rune"

assert(loadfile("Core.lua"))()
--- Supply the active specialization.
---@return string spec
function SlackHacks.getSpecName() return "Test" end
assert(SlackHacks.characterFullName("Aster", "Other Realm") == "Aster-OtherRealm")
assert(SlackHacks.characterFullName("Aster", nil) == nil)
assert(SlackHacks.characterFullName(nil, "Realm") == nil)
unitNames.target = { "Aster", "Other Realm" }
local name, complete = SlackHacks.unitFullName("target")
assert(name == "Aster-OtherRealm" and complete)
unitNames.target = { "Aster", "" }
name, complete = SlackHacks.unitFullName("target")
assert(name == "Aster" and complete == false)
unitNames.target = { "", "Realm" }
assert(SlackHacks.unitFullName("target") == nil)
local secret = newproxy()
--- Identify the restricted name stand-in.
---@param value any Value to inspect.
---@return boolean secretValue
function issecretvalue(value) return value == secret end
assert(SlackHacks.characterFullName(secret, "Realm") == nil)
assert(SlackHacks.characterFullName("Aster", secret) == nil)
unitNames.target = { secret, "Realm" }
assert(SlackHacks.unitFullName("target") == nil)
unitNames.target = { "Aster", secret }
assert(SlackHacks.unitFullName("target") == nil)
issecretvalue = nil
unitNames.target = { "Aster", "Realm" }

assert(loadfile("SelfVendor.lua"))()
local vendor = SlackHacks.SelfVendor
vendor.pendingMode, vendor.pendingName = 1, "aStEr-ReAlM"
local items = vendor:GetRequiredItems()
assert(items[2] == 1 and not items[1])
vendor.pendingUnit, vendor.pendingName = "target", "Other-Realm"
items = vendor:GetRequiredItems()
assert(items[2] == 1 and not items[1], "Retail resolves the unit's character and realm")
unitNames.target, vendor.pendingName = { "Aster" }, "Aster-Realm"
items = vendor:GetRequiredItems()
assert(items[2] == 1 and not items[1], "Retail falls back when a unit has no realm")

forever = true
assert(SlackHacks.characterFullName("Aster", "Dawn") == "Aster Dawn")
assert(SlackHacks.characterFullName("Aster", "Dawn Wind") == "Aster Dawn Wind")
unitNames.target = { "Aster", "Dawn" }
name, complete = SlackHacks.unitFullName("target")
assert(name == "Aster Dawn" and complete)
vendor.pendingUnit, vendor.pendingName = nil, "aStEr dAwN"
items = vendor:GetRequiredItems()
assert(items[3] == 1 and not items[1], "Forever matches the full pending name case-insensitively")
vendor.pendingUnit, vendor.pendingName = "target", "Aster"
items = vendor:GetRequiredItems()
assert(items[3] == 1 and not items[1], "Forever resolves both parts of a unit name before a fallback")
unitNames.target = { "Aster Dawn" }
items = vendor:GetRequiredItems()
assert(items[3] == 1 and not items[1], "Forever also accepts a unit's already-complete name")
unitNames.target, vendor.pendingName = { "Aster" }, "Aster Dawn"
items = vendor:GetRequiredItems()
assert(items[3] == 1 and not items[1], "A partial unit name falls back to the full pending name")
vendor.pendingUnit, vendor.pendingName = nil, "Unrelated Person"
items = vendor:GetRequiredItems()
assert(items[1] == 1 and not items[4], "An unresolved trade must not use the player's override")
vendor.pendingName = nil
items = vendor:GetRequiredItems()
assert(items[4] == 1 and not items[1], "The player's override remains available without a trade partner")
personal = false
vendor.pendingName = "Aster Dawn"
items = vendor:GetRequiredItems()
assert(items[1] == 1 and not items[3], "Personal overrides remain gated")
personal = true

local message
--- Capture the mail command's status.
---@param text string Status message.
function SlackHacks.prn(text) message = text end
--- Report that the client is out of combat.
---@return boolean combat
function InCombatLockdown() return false end
vendor:SendAugsForClassSpec("aster dawn wowhead")
assert(message == "open the mail compose window first.", "Forever mail command must resolve the full name")
forever = false
vendor:SendAugsForClassSpec("aster realm wowhead")
assert(message == "open the mail compose window first.", "Retail mail command must retain realm matching")

local enabled, tradeHook, nameReads = false, nil, 0
--- Report whether Self Vendor is active.
---@return boolean active
function vendor:IsEnabled() return enabled end
--- Disable the mocked module.
function vendor:Disable() enabled = false end
--- Capture the permanent trade hook.
---@param name string Hooked function name.
---@param callback function Hook callback.
function hooksecurefunc(name, callback)
  assert(name == "InitiateTrade")
  tradeHook = callback
end
--- Resolve a trade partner while counting lookups.
---@param unit string Unit token.
---@return string name
function UnitName(unit)
  nameReads = nameReads + 1
  return "Aster Dawn"
end
vendor:OnInitialize()
tradeHook("target")
assert(nameReads == 0 and not vendor.selfInitiatedTradeName)
enabled = true
tradeHook("target")
assert(nameReads == 1 and vendor.selfInitiatedTradeName == "Aster Dawn")

print("Self Vendor Forever realm tests passed")
