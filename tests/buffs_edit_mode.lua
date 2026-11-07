-- Run with Lua 5.1 from the addon root: lua tests/buffs_edit_mode.lua

local module = {}
local reminders = { enabled = true, buffs = { enabled = true } }
SlackHacks = setmetatable({
  Self = {},
  db = { profile = { reminders = reminders } },
  FOOD_ITEM_NAMES = {}, FLASK_ITEM_NAMES = {}, OIL_ITEM_NAMES = {}, RUNE_ITEM_NAMES = {},
  RUNE_BUFF_IDS = {},
}, { __index = _G })

--- Return the mocked Buffs module.
---@return table
function SlackHacks.Self:NewModule() return module end
--- Accept registration of the database reset callback.
function SlackHacks.db:RegisterCallback() end
--- Report that the player is not in combat.
---@return boolean
function InCombatLockdown() return false end
--- Clear a table like the client helper.
---@param value table
function wipe(value) for key in pairs(value) do value[key] = nil end end

local callbacks, hooks = {}, {}
EventRegistry = {}
--- Capture Edit Mode callbacks.
---@param event string
---@param callback function
function EventRegistry:RegisterCallback(event, callback) callbacks[event] = callback end
EditModeManagerFrame = { SelectSystem = function() end }
EditModeSystemSettingsDialog = {}
--- Capture the native settings dialog's show hook.
---@param event string
---@param callback function
function EditModeSystemSettingsDialog:HookScript(event, callback) hooks[event] = callback end
--- Capture hooks installed on the Edit Mode manager.
---@param target table
---@param method string
---@param callback function
function hooksecurefunc(target, method, callback) hooks[method] = callback end

assert(loadfile("Reminders_Buffs.lua"))()

--- Replace a named closure upvalue.
---@param fn function
---@param name string
---@param value any
local function replaceUpvalue(fn, name, value)
  for index = 1, math.huge do
    local key = debug.getupvalue(fn, index)
    if not key then break end
    if key == name then debug.setupvalue(fn, index, value); return end
  end
  error("Missing upvalue: " .. name)
end

local visible, dialogVisible, highlights, auraUpdates = false, false, 0, 0
local selection = { shown = false }
--- Show the mocked selection.
function selection:Show() self.shown = true end
--- Hide the mocked selection.
function selection:Hide() self.shown = false end
--- Return the mocked selection's visibility.
---@return boolean
function selection:IsShown() return self.shown end
--- Highlight the mocked selection.
function selection:ShowHighlighted() highlights = highlights + 1; self.shown = true end

replaceUpvalue(module.Refresh, "createContainer", function() end)
replaceUpvalue(module.OnInitialize, "iconButton", function() end)
replaceUpvalue(module.Refresh, "layoutIcons", function(categories) visible = #categories > 0 end)
replaceUpvalue(module.Refresh, "activeCategories", function() return {} end)
replaceUpvalue(module.Refresh, "hideBuffs", function() visible = false end)
replaceUpvalue(module.Refresh, "updateAuraEventRegistration", function() auraUpdates = auraUpdates + 1 end)
replaceUpvalue(module.Refresh, "showEditModeDialog", function(show) dialogVisible = show end)
replaceUpvalue(module.Refresh, "createSelection", function()
  replaceUpvalue(module.Refresh, "selection", selection)
  return selection
end)

module:OnInitialize()
callbacks["EditMode.Enter"]()
assert(visible and selection.shown and highlights == 1)
module:Refresh()
assert(highlights == 1, "refresh must not reset an existing selection")

dialogVisible = true
reminders.buffs.enabled = false
module:Refresh()
assert(not visible and not selection.shown and not dialogVisible and auraUpdates == 1)
hooks.SelectSystem()
hooks.OnShow()
assert(not selection.shown, "native selection hooks must not resurrect the disabled preview")

reminders.buffs.enabled = true
module:Refresh()
assert(visible and selection.shown and highlights == 2)
reminders.enabled = false
module:Refresh()
assert(not visible and not selection.shown and auraUpdates == 2)
reminders.enabled = true
module:Refresh()
assert(visible and selection.shown)

module:OnDatabaseReset()
assert(visible and selection.shown, "reset must retain the active Edit Mode preview")
callbacks["EditMode.Exit"]()
assert(not visible and not selection.shown)

reminders.enabled = false
callbacks["EditMode.Enter"]()
assert(not visible and not selection.shown)
reminders.enabled = true
module:Refresh()
assert(visible and selection.shown, "enabling while editing must restore the preview")
callbacks["EditMode.Exit"]()

reminders.buffs.enabled = false
callbacks["EditMode.Enter"]()
assert(not visible and not selection.shown)
callbacks["EditMode.Exit"]()

print("Buffs Edit Mode enablement tests passed")
