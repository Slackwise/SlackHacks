-- Run with Lua 5.1 from the addon root: lua tests/minimap_compartment.lua

local module = {}
local combat = false
SlackHacks = setmetatable({
  Self = {},
  db = { profile = { minimap = { enabled = true, shape = "circle", addonsInCompartment = true } } },
  --- Report a non-Forever client.
  ---@return boolean
  isForever = function() return false end,
  --- Report a non-Retail client.
  ---@return boolean
  isRetail = function() return false end,
}, { __index = _G })

--- Return the mocked module.
---@return table
function SlackHacks.Self:NewModule() return module end
--- Report whether the module is active.
---@return boolean
function module:IsEnabled() return true end
--- Report mocked combat lockdown.
---@return boolean
function InCombatLockdown() return combat end
--- Clear a table like the client helper.
---@param value table
function wipe(value) for key in pairs(value) do value[key] = nil end end

assert(loadfile("Minimap.lua"))()

--- Retrieve a named closure upvalue.
---@param fn function
---@param name string
---@return any
local function upvalue(fn, name)
  for index = 1, math.huge do
    local key, value = debug.getupvalue(fn, index)
    if not key then break end
    if key == name then return value end
  end
  error("Missing upvalue: " .. name)
end

local layout = upvalue(module.ApplyAll, "applyTitleBarLayout")
local apply = upvalue(layout, "applyAddonCompartment")
local discover = upvalue(layout, "discoverAddonButtons")
local buttons = upvalue(apply, "addonButtons")
local hidden = upvalue(apply, "compartmentHiddenButtons")
local options = SlackHacks.db.profile.minimap

--- Create a minimal addon button.
---@param name string
---@param label string
---@return table
local function button(name, label)
  local result = { name = name, dataObject = { label = label, icon = 123 }, shown = true }
  --- Return the frame name.
  ---@return string
  function result:GetName() return self.name end
  --- Return the local visibility.
  ---@return boolean
  function result:IsShown() return self.shown end
  --- Hide the button.
  function result:Hide() self.shown = false end
  --- Show the button.
  function result:Show() self.shown = true end
  --- Return the button's click handler.
  ---@param script string
  ---@return function|nil
  function result:GetScript(script)
    if script == "OnClick" then return function(_, mouseButton) self.clicked = mouseButton end end
  end
  --- Accept lifecycle hooks.
  function result:HookScript() end
  return result
end

local existing = button("LibDBIcon10_Example", "Example v35")
local mirrored = button("LegacyButton", "Other")
local hiddenByAddon = button("LibDBIcon10_Hidden", "Hidden")
hiddenByAddon.shown = false
hiddenByAddon.db = { hide = true }
local lib = { objects = { Example = existing, Hidden = hiddenByAddon } }
C_AddOns = {
  --- Resolve the library name to its differently formatted addon title.
  ---@param name string
  ---@return string|nil, string|nil
  GetAddOnInfo = function(name)
    if name == "Example" then return name, "Example Addon" end
  end,
}
--- Return the mocked icon library.
---@return table
function LibStub() return lib end
Minimap = {
  --- Return legacy minimap children.
  ---@return table
  GetChildren = function() return mirrored end,
}
--- Describe the legacy child.
---@return string
function mirrored:GetObjectType() return "Button" end
--- Return the legacy child's width.
---@return number
function mirrored:GetWidth() return 32 end
--- Return the legacy child's height.
---@return number
function mirrored:GetHeight() return 32 end

AddonCompartmentFrame = { registeredAddons = { { text = "|cffffffffEXAMPLE ADDON|r" } } }
--- Register a compartment entry.
---@param entry table
function AddonCompartmentFrame:RegisterAddon(entry) table.insert(self.registeredAddons, entry) end
--- Accept a display refresh.
function AddonCompartmentFrame:UpdateDisplay() end

for _, shape in ipairs({ "circle", "square" }) do
  options.shape = shape
  options.addonsInCompartment = true
  discover()
  apply()
  assert(not existing.shown and not mirrored.shown and not hiddenByAddon.shown)
  assert(#AddonCompartmentFrame.registeredAddons == 2)
  assert(AddonCompartmentFrame.registeredAddons[2].sourceButton == mirrored)
  AddonCompartmentFrame.registeredAddons[2].func(nil, { buttonName = "RightButton" })
  assert(mirrored.clicked == "RightButton")

  discover()
  assert(#buttons == 2 and hidden[existing] and hidden[mirrored])
  apply()
  assert(#AddonCompartmentFrame.registeredAddons == 2)

  table.insert(AddonCompartmentFrame.registeredAddons, { text = "Other" })
  apply()
  assert(#AddonCompartmentFrame.registeredAddons == 2)
  assert(not AddonCompartmentFrame.registeredAddons[2].isSlackHacks)
  table.remove(AddonCompartmentFrame.registeredAddons, 2)

  options.addonsInCompartment = false
  apply()
  assert(existing.shown and mirrored.shown and not hiddenByAddon.shown)
  assert(#AddonCompartmentFrame.registeredAddons == 1)
end

local sync = upvalue(apply, "syncAddonCompartmentEntries")
existing.name = "LibDBIcon10_Unrelated"
options.addonsInCompartment = true
existing.dataObject.label = "Example Addon v35"
sync()
assert(#AddonCompartmentFrame.registeredAddons == 2)

-- A suffix that is not solely a version must not merge distinct addon names.
existing.dataObject.label = "Example Addon v35 Helper"
sync()
assert(#AddonCompartmentFrame.registeredAddons == 3)
existing.dataObject.label = "Example v35"
existing.name = "LibDBIcon10_Example"

options.addonsInCompartment = true
discover()
apply()
existing.db = { hide = true }
options.addonsInCompartment = false
combat = true
apply()
assert(not existing.shown and not mirrored.shown and hidden[existing] and hidden[mirrored])
combat = false
apply()
assert(not existing.shown and mirrored.shown and not hidden[existing] and not hidden[mirrored])

existing.db.hide = false
existing:Show()
options.addonsInCompartment = true
discover()
apply()
options.enabled = false
local restoreAfterCombat = upvalue(module.OnDisable, "onCompartmentRestoreAfterCombat")
local eventFrame = {}
--- Record one-shot event unregistration.
---@param event string
function eventFrame:UnregisterEvent(event) self.unregistered = event end
restoreAfterCombat(eventFrame)
assert(eventFrame.unregistered == "PLAYER_REGEN_ENABLED" and existing.shown and mirrored.shown)

options.enabled = true
local queued = 0
C_Timer = {
  --- Count scheduled refreshes without running the full layout.
  ---@param delay number
  ---@param callback function
  After = function(delay, callback) queued = queued + 1 end,
}
local onRegistered = upvalue(module.OnEnable, "onCompartmentAddonRegistered")
onRegistered(AddonCompartmentFrame, { isSlackHacks = true })
assert(queued == 0)
onRegistered(AddonCompartmentFrame, { text = "Late addon" })
assert(queued == 1)

SlackHacks.Self = SlackHacks
SlackHacks.Talents = { MAX_SPECS = 0 }
SlackHacks.Enum = { SelfVendorMode = {
  FLASK = 1, OIL = 2, AUGMENT_RUNES = 3, VANTUS_RUNE = 4, CONSUMABLES = 5, AUGMENTS = 6,
} }
SlackHacks.SELF_VENDOR_MODES = {}
for index = 1, 6 do
  SlackHacks.SELF_VENDOR_MODES[index] = { key = "mode" .. index, name = "Mode", description = "Mode" }
end
--- Supply the addon version for options and tooltips.
---@return string
function SlackHacks.getAddonVersion() return "35" end
assert(loadfile("Options.lua"))()

local callbacks = {}
for line in io.lines("SlackHacks.toc") do
  local key, name = line:match("^## (AddonCompartment%w*):%s*(%S+)")
  if key then
    callbacks[key] = assert(_G[name], "Missing global callback: " .. name)
  end
end
local openedOptions, openedErrors = 0, 0
--- Record the normal left-click action.
function SlackHacks.openOptions() openedOptions = openedOptions + 1 end
local errors = {}
SlackHacks.Debug = {
  --- Return the current error log.
  ---@return table
  GetErrorLog = function() return errors end,
  --- Record the error-report action.
  ShowWindow = function() openedErrors = openedErrors + 1 end,
}
callbacks.AddonCompartmentFunc("SlackHacks", "LeftButton")
assert(openedOptions == 1 and openedErrors == 0)
errors = { "error" }
callbacks.AddonCompartmentFunc("SlackHacks", "LeftButton")
assert(openedOptions == 1 and openedErrors == 1)

local menuAnchor
MenuUtil = {
  --- Record the anchor of the quick-toggle menu.
  ---@param anchor table
  ---@param generator function
  CreateContextMenu = function(anchor, generator) menuAnchor = anchor end,
}
GameTooltip = { lines = {} }
--- Record the tooltip owner.
---@param owner table
---@param anchor string
function GameTooltip:SetOwner(owner, anchor) self.owner = owner end
--- Record tooltip content.
---@param text string
function GameTooltip:AddLine(text) table.insert(self.lines, text) end
--- Record tooltip visibility.
function GameTooltip:Show() self.shown = true end
--- Clear tooltip visibility.
function GameTooltip:Hide() self.shown = false end
callbacks.AddonCompartmentFunc("SlackHacks", "RightButton")
assert(menuAnchor == AddonCompartmentFrame and openedOptions == 1 and openedErrors == 1)
local menuButton = {}
callbacks.AddonCompartmentFuncOnEnter("SlackHacks", menuButton)
assert(GameTooltip.owner == menuButton and GameTooltip.shown)
assert(GameTooltip.lines[1] == "SlackHacks v35")
assert(GameTooltip.lines[3] == "You have 1 un-reported error in SlackHacks.")
callbacks.AddonCompartmentFuncOnLeave("SlackHacks", menuButton)
assert(not GameTooltip.shown)

local broker
local ldb = {}
--- Capture the broker handlers for regression checks.
---@param name string
---@param object table
---@return table
function ldb:NewDataObject(name, object) broker = object; return object end
local ldbi = {}
--- Report that registration is unnecessary for this handler test.
---@return boolean
function ldbi:IsRegistered() return true end
--- Return the appropriate mock broker library.
---@param name string
---@return table
function LibStub(name) return name == "LibDataBroker-1.1" and ldb or ldbi end
upvalue(SlackHacks.updateMinimapIcon, "initMinimapIcon")()
errors = {}
broker.OnClick(existing, "LeftButton")
assert(openedOptions == 2 and openedErrors == 1)
broker.OnClick(existing, "RightButton")
assert(menuAnchor == existing)
GameTooltip.lines = {}
broker.OnEnter(existing)
assert(GameTooltip.owner == existing and GameTooltip.shown)
assert(GameTooltip.lines[2] == "Left-click: Open options")
broker.OnLeave(existing)
assert(not GameTooltip.shown)
print("Minimap compartment tests passed")
