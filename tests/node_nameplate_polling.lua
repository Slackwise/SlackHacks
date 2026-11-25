-- Run with Lua 5.1 from the addon root: lua tests/node_nameplate_polling.lua

local frames = {}
local forever, resting, combat = true, false, false
local addon = setmetatable({}, { __index = _G })
SlackHacks = addon
addon.Self = addon

--- Supplies the Utilities module.
---@return table module
function addon:NewModule() return {} end

--- Reports the mocked client type.
---@return boolean isForeverClient
function addon.isForever() return forever end

--- Reports the mocked rested state.
---@return boolean isRested
function IsResting() return resting end

--- Reports the mocked combat state.
---@return boolean inCombat
function InCombatLockdown() return combat end

--- Creates a frame that records its visibility, events, and scripts.
---@return table frame
function CreateFrame()
  local frame = { shown = true, events = {}, scripts = {} }
  --- Stores a frame script.
  ---@param script string Script name.
  ---@param handler function Handler.
  function frame:SetScript(script, handler) self.scripts[script] = handler end
  --- Records an event registration.
  ---@param event string Event name.
  function frame:RegisterEvent(event) self.events[event] = true end
  --- Sets whether the frame receives updates.
  ---@param shown boolean Visibility.
  function frame:SetShown(shown) self.shown = shown end
  --- Hides the frame.
  function frame:Hide() self.shown = false end
  frames[#frames + 1] = frame
  return frame
end

UIParent = {}
--- Creates the unused cursor probe texture.
---@return table texture
function UIParent:CreateTexture()
  return {
    --- Hides the cursor probe.
    Hide = function() end,
  }
end

assert(loadfile("Utilities.lua"))()
local module = addon.Utilities
local events, poller = frames[1], module.nodeNameplatePoller
local settings = { enabled = true, ore = true, herbs = false, quest = false }
module:InitializeNodeNameplates(settings, {})

local evaluations = 0
--- Counts evaluations without invoking client APIs.
function module:EvaluateNodeNameplate() evaluations = evaluations + 1 end

--- Dispatches an event that the addon registered.
---@param event string Event name.
local function fire(event)
  assert(events.events[event], "Event not registered: " .. event)
  events.scripts.OnEvent(events, event)
end

--- Advances the poller as WoW does only while the frame is shown.
---@param elapsed number Seconds elapsed.
local function tick(elapsed)
  if poller.shown then poller.scripts.OnUpdate(poller, elapsed) end
end

module:UpdateNodeNameplatePoller()
assert(poller.shown)
tick(0.49)
assert(evaluations == 0)
tick(0.02)
assert(evaluations == 1, "The active poller must evaluate after 0.5 seconds")

resting = true
fire("PLAYER_UPDATE_RESTING")
assert(not poller.shown, "Resting must pause polling")
fire("PLAYER_ENTERING_WORLD")
assert(not poller.shown, "Entering the world while resting must not resume polling")
local whileResting = evaluations
tick(1)
assert(evaluations == whileResting)
fire("PLAYER_SOFT_INTERACT_CHANGED")
assert(evaluations == whileResting + 1, "Event-driven updates must remain active while resting")

combat = true
fire("PLAYER_REGEN_DISABLED")
resting = false
fire("PLAYER_UPDATE_RESTING")
assert(not poller.shown, "Leaving a rested area in combat must not resume polling")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(poller.shown, "Leaving combat outside a rested area must resume polling")
local afterCombat = evaluations
tick(0.5)
assert(evaluations == afterCombat + 1)

resting = true
fire("PLAYER_UPDATE_RESTING")
combat = true
fire("PLAYER_REGEN_DISABLED")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(not poller.shown, "Leaving combat while resting must not resume polling")
resting = false
fire("PLAYER_UPDATE_RESTING")
assert(poller.shown, "Leaving a rested area outside combat must resume polling")

module:SetNodeNameplateOption("ore", false)
assert(not poller.shown, "Polling requires an enabled category")
module:SetNodeNameplateOption("ore", true)
assert(poller.shown, "Enabling a category must resume polling")
module:SetNodeNameplateOption("enabled", false)
assert(not poller.shown, "Polling requires the master option")
module:SetNodeNameplateOption("enabled", true)
assert(poller.shown, "Enabling the master option must resume polling")
forever = false
module:UpdateNodeNameplatePoller()
assert(not poller.shown, "Polling is exclusive to Forever")

print("Node nameplate polling tests passed")
