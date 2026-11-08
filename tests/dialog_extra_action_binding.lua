-- Run with Lua 5.1 from the addon root: lua tests/dialog_extra_action_binding.lua

local module = {}
SlackHacks = setmetatable({ Self = {} }, { __index = _G })
SlackHacks.Self.Dialog = module

--- Return the mocked addon module when Dialog.lua loads.
---@return table
function SlackHacks.Self:NewModule() return module end

local actions, keys, messages, saves = {}, {}, {}, {}
local combat, failedKey, bindingSet = false, nil, 1

--- Return the keys in their current game binding order.
---@param action string
---@return string... keys
function GetBindingKey(action)
  local result = {}
  for _, key in ipairs(keys) do
    if actions[key] == action then result[#result + 1] = key end
  end
  return unpack(result)
end

--- Return a key's saved action, ignoring temporary override bindings.
---@param key string
---@return string action
function GetBindingAction(key) return actions[key] or "" end

--- Change a saved binding unless the test simulates a failure.
---@param key string
---@param action string|nil
---@return boolean|nil success
function SetBinding(key, action)
  if key == failedKey then return nil end
  if not actions[key] and action then keys[#keys + 1] = key end
  actions[key] = action
  return true
end

--- Report whether changes are currently restricted.
---@return boolean
function InCombatLockdown() return combat end

--- Return the active account or character binding set.
---@return number
function GetCurrentBindingSet() return bindingSet end

--- Record which binding set was saved.
---@param set number
function SaveBindings(set) saves[#saves + 1] = set end

--- Capture addon error notifications.
---@param message string
function SlackHacks.prn(message) messages[#messages + 1] = message end

assert(loadfile("Bindings.lua"))()
assert(loadfile("Dialog.lua"))

local EXTRA = "EXTRAACTIONBUTTON1"
--- Read an Extra Action key through the shared binding helper.
---@param slot number
---@return string|nil
local function extraKey(slot) return SlackHacks.getConfiguredBindingKey(EXTRA, slot) end
--- Validate an Extra Action key through the shared binding helper.
---@param slot number
---@param key string|nil
---@param canConfirm boolean
---@return boolean|string
local function validateExtra(slot, key, canConfirm)
  return SlackHacks.validateConfiguredBindingKey(EXTRA, slot, key, canConfirm)
end
--- Set an Extra Action key through the shared binding helper.
---@param slot number
---@param key string|nil
local function setExtra(slot, key) SlackHacks.setConfiguredBindingKey(EXTRA, slot, key) end

assert(extraKey(1) == nil and extraKey(2) == nil)
assert(validateExtra(1, "ALT-E", true) == true)
setExtra(1, "ALT-E")
assert(extraKey(1) == "ALT-E" and saves[#saves] == 1)

bindingSet = 2
setExtra(2, "CTRL-E")
assert(extraKey(2) == "CTRL-E" and saves[#saves] == 2)
assert(type(validateExtra(1, "CTRL-E", true)) == "string")
assert(validateExtra(1, "ALT-E", true) == true)

-- Replacing one key preserves all the other saved bindings, even beyond Blizzard's two displayed slots.
SetBinding("SHIFT-E", EXTRA)
setExtra(1, "F8")
assert(GetBindingAction("ALT-E") == "" and GetBindingAction("F8") == EXTRA)
assert(GetBindingAction("CTRL-E") == EXTRA and GetBindingAction("SHIFT-E") == EXTRA)

-- Existing action conflicts require a dialog; command-line configuration must not overwrite them.
SetBinding("F9", "JUMP")
BINDING_NAME_JUMP = "Jump"
assert(SlackHacks.confirmConfiguredBindingKey(EXTRA, "F9"):find("Jump", 1, true))
assert(type(validateExtra(1, "F9", false)) == "string")
assert(validateExtra(1, "F9", true) == true)
assert(SlackHacks.confirmConfiguredBindingKey(EXTRA, "F8") == nil)
setExtra(1, "F9")
assert(GetBindingAction("F9") == EXTRA and GetBindingAction("CTRL-E") == "")

-- Escape/empty clears only the selected binding; remaining slots may shift up.
local cleared = extraKey(1)
setExtra(1, "")
assert(GetBindingAction(cleared) == "" and extraKey(1) ~= nil)

local savedCount = #saves
combat = true
assert(type(validateExtra(1, "F10", true)) == "string")
setExtra(1, "F10")
assert(GetBindingAction("F10") == "" and #saves == savedCount and #messages == 1)
combat = false

-- Failed assignments and failed removal leave the old and conflicting bindings intact and unsaved.
local old = extraKey(1)
failedKey = "F10"
setExtra(1, "F10")
assert(GetBindingAction(old) == EXTRA and GetBindingAction("F10") == "" and #saves == savedCount)
failedKey = old
SetBinding("F11", "JUMP")
setExtra(1, "F11")
assert(GetBindingAction(old) == EXTRA and GetBindingAction("F11") == "JUMP" and #saves == savedCount)
assert(#messages == 3)

-- Load the real options table and exercise the two controls in their Dialog group.
failedKey = nil
--- Return a version string for the options title.
---@return string
function SlackHacks.getAddonVersion() return "test" end
SlackHacks.Enum = { SelfVendorMode = {
  FLASK = 1, OIL = 2, AUGMENT_RUNES = 3, VANTUS_RUNE = 4, CONSUMABLES = 5, AUGMENTS = 6,
} }
SlackHacks.SELF_VENDOR_MODES = {}
for index = 1, 6 do
  SlackHacks.SELF_VENDOR_MODES[index] = { key = "mode" .. index, name = "Mode", description = "Mode" }
end
SlackHacks.Self.Talents = { MAX_SPECS = 0 }
SlackHacks.db = { profile = { dialog = { enabled = true, questItemButton = false } } }
local retail, forever = false, true
--- Reports the mocked Retail client.
---@return boolean
function SlackHacks.isRetail() return retail end
--- Reports the mocked Forever client.
---@return boolean
function SlackHacks.isForever() return forever end
local supported = true
--- Report whether the mocked client supports the quest item button.
---@return boolean
function module:IsQuestItemButtonSupported() return supported end
assert(loadfile("Options.lua"))()
local args = SlackHacks.options.args.dialog.args
assert(SlackHacks.options.args.dialog.name == "Dialog" and SlackHacks.options.args.quest == nil)
local mythic = args.autoClickGroup.args.autoClickFirstOptionMythicOnly
local vendor = args.autoClickGroup.args.autoClickFirstOptionVendorOnly
assert(vendor.name == "Only when Interacting with Vendor")
assert(vendor.desc == "If talking to a vendor with no extra dialogue options, automatically open their vendor window.")
assert(vendor.order > mythic.order and mythic.hidden() and not vendor.hidden())
retail, forever = true, false
assert(not mythic.hidden() and vendor.hidden())
assert(vendor.disabled())
SlackHacks.db.profile.dialog.autoClickFirstOption = true
assert(not vendor.disabled())
--- Applies options without invoking unrelated secure UI lifecycle work.
---@param key string Setting name.
---@param value boolean Setting value.
function module:SetOption(key, value) SlackHacks.db.profile.dialog[key] = value end
vendor.set({}, true)
assert(vendor.get())
assert(SlackHacks.dbDefaults.profile.dialog.autoClickFirstOptionVendorOnly == false)
assert(SlackHacks.dbDefaults.profile.quest == nil)
local keybindings = SlackHacks.options.args.controls.args.keybindings
local bindingArgs = keybindings.args
local questExtraAction = args.extraActionKey1
local questAutoAccept = args.autoAcceptKey1
local first, second = bindingArgs.dialogBinding5Key1, bindingArgs.dialogBinding5Key2
assert(questExtraAction.type == "keybinding" and questAutoAccept.type == "keybinding")
assert(first.type == "keybinding" and second.type == "keybinding")
assert(first.hidden == nil and second.hidden == nil)
assert(not first.disabled() and first.get() == extraKey(1))
SlackHacks.db.profile.dialog.questItemButton = true
assert(first.hidden == nil and second.hidden == nil and not first.disabled())
supported = false
assert(first.hidden == nil and second.hidden == nil)
supported = true
SlackHacks.db.profile.dialog.enabled = false
assert(first.disabled())
SlackHacks.db.profile.dialog.enabled = true
combat = true
assert(second.disabled())
combat = false
assert(first.get() == extraKey(1) and second.get() == extraKey(2))
SetBinding("F12", "JUMP")
assert(type(first.validate({ uiType = "cmd" }, "F12")) == "string")
assert(first.validate({ uiType = "dialog" }, "F12") == true)
assert(first.confirm({}, "F12"):find("Jump", 1, true))
second.set({}, "F12")
assert(GetBindingAction("F12") == EXTRA)
questExtraAction.set({}, "CTRL-F12")
assert(GetBindingAction("CTRL-F12") == EXTRA)

local toggle = bindingArgs.dialogBinding2Key1
local toggleAction = "SLACKHACKS_TOGGLE_QUEST_AUTO_ACCEPT"
SlackHacks.db.profile.dialog.enabled = false
assert(not toggle.disabled())
toggle.set({}, "CTRL-Q")
assert(GetBindingAction("CTRL-Q") == toggleAction and toggle.get() == "CTRL-Q")
questAutoAccept.set({}, "CTRL-W")
assert(GetBindingAction("CTRL-W") == toggleAction and questAutoAccept.get() == "CTRL-W")
assert(keybindings.name == "Keybindings")
assert(keybindings.inline ~= true)
assert(args.toggleAllKey1.type == "keybinding" and args.toggleAllKey2.type == "keybinding")
assert(args.autoCompleteKey1.type == "keybinding" and args.autoCompleteKey2.type == "keybinding")
assert(args.autoClickGroup.args.autoClickKey1.type == "keybinding" and args.autoClickGroup.args.autoClickKey2.type == "keybinding")
assert(args.dialogKeybindingsGroup.args.numberKeys.type == "toggle")
assert(bindingArgs.convenienceHeader.type == "header")
assert(bindingArgs.specializationHeader.type == "header")
assert(bindingArgs.bestUseItemsHeader.type == "header")
assert(bindingArgs.dialogHeader.type == "header")
assert(bindingArgs.dialogKeybindingsHeader.type == "header")
assert(bindingArgs.numberKeys.type == "toggle" and bindingArgs.spacebar.type == "toggle")

assert(bindingArgs.convenienceBinding1Key1.type == "keybinding" and bindingArgs.convenienceBinding7Key2.type == "keybinding")
assert(bindingArgs.specializationBinding1Key1.type == "keybinding" and bindingArgs.specializationBinding4Key2.type == "keybinding")
assert(bindingArgs.bestUseItemsBinding1Key1.type == "keybinding" and bindingArgs.bestUseItemsBinding3Key2.type == "keybinding")
assert(bindingArgs.dialogBinding1Key1.type == "keybinding" and bindingArgs.dialogBinding4Key2.type == "keybinding")
assert(SlackHacks.options.args.utilities.args.bestUseItemBindings == nil)
local convenienceActions = {
  "SLACKHACKS_RELOADUI", "SLACKHACKS_RESTART_SOUND", "SLACKHACKS_MOUNT", "SLACKHACKS_SETBINDINGS",
  "SLACKHACKS_OPTIONS", "SLACKHACKS_QUICK_KEYBIND_MODE", "SLACKHACKS_CLICK_CASTING"
}
local specializationActions = {
  "SLACKHACKS_SWITCH_SPEC_1", "SLACKHACKS_SWITCH_SPEC_2", "SLACKHACKS_SWITCH_SPEC_3", "SLACKHACKS_SWITCH_SPEC_4",
}
local bestActions = { "SLACKHACKS_BEST_HEALING_POTION", "SLACKHACKS_BEST_MANA_POTION", "SLACKHACKS_BEST_BANDAGE" }
local questActions = {
  "SLACKHACKS_TOGGLE_QUEST_ALL_AUTOMATION", "SLACKHACKS_TOGGLE_QUEST_AUTO_ACCEPT",
  "SLACKHACKS_TOGGLE_QUEST_AUTO_COMPLETE", "SLACKHACKS_TOGGLE_QUEST_AUTO_CLICK_FIRST_OPTION",
}
for _, group in ipairs({
  { "convenienceBinding", convenienceActions },
  { "specializationBinding", specializationActions },
  { "bestUseItemsBinding", bestActions },
  { "dialogBinding", questActions }
}) do
  for index, action in ipairs(group[2]) do
    for slot = 1, 2 do
      local key = "TEST-" .. action .. "-" .. slot
      local control = bindingArgs[group[1] .. index .. "Key" .. slot]
      control.set({}, key)
      assert(GetBindingAction(key) == action)
      SetBinding(key)
    end
  end
end
bindingArgs.convenienceBinding1Key1.set({}, "F5")
assert(GetBindingAction("F5") == "SLACKHACKS_RELOADUI")
bindingArgs.bestUseItemsBinding1Key1.set({}, "F6")
assert(GetBindingAction("F6") == "SLACKHACKS_BEST_HEALING_POTION")
assert(bindingArgs.bestUseItemsBinding1Key1.get() == "F6")
assert(type(bindingArgs.bestUseItemsBinding2Key1.validate({ uiType = "cmd" }, "F6")) == "string")
assert(bindingArgs.bestUseItemsBinding2Key1.confirm({}, "F6"):find("Use Best Healing Potion", 1, true))

-- Override refreshes react to external binding changes but not their own UPDATE_BINDINGS events.
SlackHacks.BEST_ITEMS = {
  healing = { BINDING_NAME = "SLACKHACKS_BEST_HEALING_POTION", [100] = 100 },
  mana = { BINDING_NAME = "SLACKHACKS_BEST_MANA_POTION", [200] = 200 },
}
local refreshes, overrides = 0, {}
SlackHacks.Self.itemBindingFrame = {}
--- Count resets and simulate the update event triggered by changing overrides.
function ClearOverrideBindings()
  refreshes = refreshes + 1
  assert(refreshes < 10, "Override binding refresh loop")
  overrides = {}
  SlackHacks.refreshBestItemBindingsOnChange()
end
--- Capture the override binding that would use the best available item.
---@param _ table
---@param priority boolean
---@param key string
---@param item string
function SetOverrideBindingItem(_, priority, key, item)
  assert(priority)
  overrides[key] = item
  SlackHacks.refreshBestItemBindingsOnChange()
end
--- Return the mock item map's keys.
---@param map table
---@return table
function SlackHacks.keys(map)
  local result = {}
  for key in pairs(map) do result[#result + 1] = key end
  return result
end
--- Find the mocked available item associated with an item map.
---@param ids table
---@return table
function SlackHacks.findItemsByItemIDs(ids)
  local result = {}
  for _, id in ipairs(ids) do
    if type(id) == "number" then result[#result + 1] = { itemID = id, stackCount = 1 } end
  end
  return result
end
--- Group mocked items by the strength selected by the real binding logic.
---@param items table
---@param selector function
---@return table
function SlackHacks.groupBy(items, selector)
  local result = {}
  for _, item in ipairs(items) do
    local strength, value = selector(item)
    result[strength] = result[strength] or {}
    table.insert(result[strength], value)
  end
  return result
end
--- Find the highest mocked item strength.
---@param items table
---@return number|nil
function SlackHacks.findLargestIndex(items)
  local largest
  for value in pairs(items) do if not largest or value > largest then largest = value end end
  return largest
end
--- Disable debug-only item logging in this test.
---@return boolean
function SlackHacks.isDebugging() return false end
--- Accept normal diagnostic messages.
function SlackHacks.log() end
--- Return a dummy item name for binding diagnostics.
---@param id number
---@return string
C_Item = { GetItemNameByID = function(id) return tostring(id) end }
SlackHacks.bindBestUseItems()
assert(refreshes == 1 and overrides.F6 == "item:100")
SlackHacks.refreshBestItemBindingsOnChange()
assert(refreshes == 1)
SetBinding("F7", "SLACKHACKS_BEST_MANA_POTION")
SlackHacks.refreshBestItemBindingsOnChange()
assert(refreshes == 2 and overrides.F6 == "item:100" and overrides.F7 == "item:200")
SetBinding("F7")
SlackHacks.refreshBestItemBindingsOnChange()
assert(refreshes == 3 and overrides.F6 == "item:100" and overrides.F7 == nil)

local pending = {}
--- Capture work deferred until combat ends.
---@param callback function
function SlackHacks.runAfterCombat(callback) pending[#pending + 1] = callback end
combat = true
SetBinding("F7", "SLACKHACKS_BEST_MANA_POTION")
SlackHacks.refreshBestItemBindingsOnChange()
SlackHacks.refreshBestItemBindingsOnChange()
SlackHacks.bindBestUseItems()
assert(#pending == 1 and refreshes == 3)
combat = false
pending[1]()
assert(refreshes == 4 and overrides.F7 == "item:200")

--- Supply the atlas markup needed when Core.lua loads.
---@return string
function CreateAtlasMarkup() return "" end
local mockFindItems = SlackHacks.findItemsByItemIDs
assert(loadfile("Core.lua"))()
SlackHacks.findItemsByItemIDs = mockFindItems
local registeredEvents = {}
--- Capture addon event subscriptions.
---@param event string
function SlackHacks.Self:RegisterEvent(event) registeredEvents[event] = true end
--- Avoid unrelated bag UI initialization in this test.
function SlackHacks.initBagsFrameHiding() end
SlackHacks.Self:OnEnable()
assert(registeredEvents.UPDATE_BINDINGS)
SetBinding("F8", "SLACKHACKS_BEST_MANA_POTION")
SlackHacks.Self:UPDATE_BINDINGS()
assert(refreshes == 5 and overrides.F8 == "item:200")

print("Embedded binding option tests passed")
