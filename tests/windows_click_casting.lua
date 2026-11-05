-- Run with Lua 5.1 from the addon root: lua tests/windows_click_casting.lua

local frames = {}
UIParent = {}
SlackHacks = setmetatable({ db = { profile = { windows = {
  enabled = true, movable = { savePositionStrategy = "session" },
} } } }, { __index = _G })
SlackHacks.Self = SlackHacks

--- Supply the module object needed when Windows.lua loads.
---@return table module
function SlackHacks:NewModule()
  return {}
end

--- Supply the minimal frame methods needed by the position watchdog.
---@return table frame
function CreateFrame()
  local frame = { scripts = {}, positions = 0 }
  --- Accept the fake UI parent's anchors.
  function frame:SetAllPoints() end
  --- Store a frame script for explicit execution by the test.
  ---@param name string
  ---@param callback function?
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  --- Return the protection and forbidden states.
  ---@return boolean, boolean
  function frame:IsProtected() return false, false end
  --- Accept clearing the mocked frame's anchors.
  function frame:ClearAllPoints() end
  --- Return the mocked frame's scale.
  ---@return number
  function frame:GetScale() return 1 end
  --- Count saved-position applications.
  function frame:SetPoint() self.positions = self.positions + 1 end
  table.insert(frames, frame)
  return frame
end

--- Mimic the client table-clear helper.
---@param value table
function wipe(value)
  for key in pairs(value) do value[key] = nil end
end

--- Report that the mocked client is not in combat.
---@return boolean locked
function InCombatLockdown() return false end

assert(loadfile("Windows.lua"))()

--- Find a named closure upvalue.
---@param fn function
---@param name string
---@return any value
local function upvalue(fn, name)
  for index = 1, math.huge do
    local key, value = debug.getupvalue(fn, index)
    if not key then break end
    if key == name then return value end
  end
  error("Missing upvalue: " .. name)
end

local processFrame = upvalue(SlackHacks.Windows.RegisterFrame, "processFrame")
local makeFrameMovable = upvalue(processFrame, "makeFrameMovable")
local onSetPoint = upvalue(makeFrameMovable, "onSetPoint")
local registry = upvalue(onSetPoint, "frameRegistry")
local savedPoints = { { anchorPoint = "TOP", relativeFrame = "UIParent", relativePoint = "TOP", offX = 0, offY = 0 } }

PlayerSpellsFrame = CreateFrame()
MacroFrame = CreateFrame()
local other = CreateFrame()
for _, frame in ipairs({ PlayerSpellsFrame, MacroFrame, other }) do
  registry[frame] = { storage = { points = { dragged = true, dragPoints = savedPoints } } }
end

local shown = false
--- Return whether the mocked Click Casting panel is visible.
---@return boolean
ClickBindingFrame = { IsShown = function() return shown end }

-- Session positions still restore normally, but not over the active Click Casting picker.
onSetPoint(PlayerSpellsFrame)
assert(PlayerSpellsFrame.positions == 1)
shown = true
onSetPoint(PlayerSpellsFrame)
onSetPoint(MacroFrame)
onSetPoint(other)
assert(PlayerSpellsFrame.positions == 1 and MacroFrame.positions == 0 and other.positions == 1)
shown = false
onSetPoint(PlayerSpellsFrame)
onSetPoint(MacroFrame)
assert(PlayerSpellsFrame.positions == 2 and MacroFrame.positions == 1)
ClickBindingFrame = nil
onSetPoint(PlayerSpellsFrame)
assert(PlayerSpellsFrame.positions == 3)
ClickBindingFrame = { IsShown = function() return shown end }

-- Permanent positions are deferred; an update queued before Click Casting opens must also be suppressed.
SlackHacks.db.profile.windows.movable.savePositionStrategy = "permanent"
onSetPoint(PlayerSpellsFrame)
local queueFrame = frames[#frames]
assert(queueFrame.scripts.OnUpdate)
shown = true
queueFrame.scripts.OnUpdate(queueFrame)
assert(PlayerSpellsFrame.positions == 3)
onSetPoint(MacroFrame)
assert(not queueFrame.scripts.OnUpdate)
onSetPoint(other)
queueFrame.scripts.OnUpdate(queueFrame)
assert(other.positions == 2)
shown = false
onSetPoint(PlayerSpellsFrame)
queueFrame.scripts.OnUpdate(queueFrame)
assert(PlayerSpellsFrame.positions == 4)

print("Click Casting window-position tests passed")
