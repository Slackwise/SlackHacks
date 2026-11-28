-- Run with Lua 5.1 from the addon root: lua tests/minimap_restore_anchors.lua

local module = {}
SlackHacks = setmetatable({
  Self = {},
  --- Report that this is not the Retail client.
  ---@return boolean
  isRetail = function() return false end,
  --- Report that this is the Forever client.
  ---@return boolean
  isForever = function() return true end,
}, { __index = _G })

--- Return the mocked minimap module.
---@return table
function SlackHacks.Self:NewModule() return module end

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

local disableAllStacking = upvalue(module.OnDisable, "disableAllStacking")
local enableButtonStacking = upvalue(disableAllStacking, "enableButtonStacking")
local registeredButtons = upvalue(disableAllStacking, "registeredButtons")
local registeredButtonsByFrame = upvalue(disableAllStacking, "registeredButtonsByFrame")
--- Ignore unrelated Blizzard border updates in this anchor test.
replaceUpvalue(disableAllStacking, "applyBlizzardIconBorders", function() end)

local frames = {}
--- Create a mock frame that rejects circular anchor dependencies.
---@param name string
---@return table
local function frame(name)
  local result = { name = name, points = {}, scale = 1, strata = "MEDIUM", level = 1, shown = true, scripts = {}, hooks = {} }
  table.insert(frames, result)

  --- Return the frame name.
  ---@return string
  function result:GetName() return self.name end
  --- Identify named icon frames as buttons.
  ---@return string
  function result:GetObjectType() return "Button" end
  --- Return the frame's local visibility.
  ---@return boolean
  function result:IsShown() return self.shown end
  --- Show the frame.
  function result:Show() self.shown = true end
  --- Return the frame's center.
  ---@return number, number
  function result:GetCenter() return 0, 0 end
  --- Return its inherited scale.
  ---@return number
  function result:GetEffectiveScale()
    return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
  end
  --- Return immediate child frames.
  ---@return Frame...
  function result:GetChildren()
    local children = {}
    for _, child in ipairs(frames) do
      if child.parent == self then table.insert(children, child) end
    end
    return unpack(children)
  end
  --- Return the frame's parent.
  ---@return table|nil
  function result:GetParent() return self.parent end
  --- Set the frame's parent.
  ---@param parent table
  function result:SetParent(parent) self.parent = parent end
  --- Return the frame's scale.
  ---@return number
  function result:GetScale() return self.scale end
  --- Set the frame's scale.
  ---@param scale number
  function result:SetScale(scale) self.scale = scale end
  --- Return the frame's strata.
  ---@return string
  function result:GetFrameStrata() return self.strata end
  --- Set the frame's strata.
  ---@param strata string
  function result:SetFrameStrata(strata) self.strata = strata end
  --- Return the frame's level.
  ---@return number
  function result:GetFrameLevel() return self.level end
  --- Set the frame's level.
  ---@param level number
  function result:SetFrameLevel(level) self.level = level end
  --- Return the frame's width.
  ---@return number
  function result:GetWidth() return self.width or 20 end
  --- Return the frame's height.
  ---@return number
  function result:GetHeight() return self.height or 10 end
  --- Set the frame's width.
  ---@param width number
  function result:SetWidth(width) self.width = width end
  --- Set the frame's height.
  ---@param height number
  function result:SetHeight(height) self.height = height end
  --- Return the number of anchors.
  ---@return number
  function result:GetNumPoints() return #self.points end
  --- Return one anchor.
  ---@param index number
  ---@return string, table, string, number, number
  function result:GetPoint(index) return unpack(self.points[index]) end
  --- Return no decorative regions.
  function result:GetRegions() end
  --- Retain additive hooks without replacing the original script.
  ---@param event string
  ---@param hook function
  function result:HookScript(event, hook)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], hook)
  end
  --- Set an original addon script.
  ---@param event string
  ---@param script function|nil
  function result:SetScript(event, script) self.scripts[event] = script end
  --- Accept native drag registration.
  function result:RegisterForDrag() end
  --- Clear the actual anchors.
  function result:ClearAllPoints() self.points = {}; self.clears = (self.clears or 0) + 1 end
  --- Set an anchor, rejecting direct or indirect cycles.
  ---@param point string
  ---@param relativeTo table
  ---@param relativePoint string
  ---@param x number
  ---@param y number
  function result:SetPoint(point, relativeTo, relativePoint, x, y)
    --- Check whether a frame transitively depends on another frame.
    ---@param candidate table
    ---@param target table
    ---@param visited table
    ---@return boolean
    local function dependsOn(candidate, target, visited)
      if candidate == target then return true end
      if visited[candidate] then return false end
      visited[candidate] = true
      for _, anchor in ipairs(candidate.points) do
        if dependsOn(anchor[2], target, visited) then return true end
      end
      return false
    end
    assert(not dependsOn(relativeTo, self, {}), self.name .. " would create a circular anchor")
    table.insert(self.points, { point, relativeTo, relativePoint, x, y })
  end
  return result
end

--- Exercise restoration with both registered and separately discovered native frames.
---@param registerAll boolean
local function testRestore(registerAll)
  local root, clock, zone, diff, untouched = frame("root"), frame("clock"), frame("zone"), frame("difficulty"), frame("untouched")
  MinimapCluster = { ZoneTextButton = zone, InstanceDifficulty = diff }
  clock:SetPoint("TOP", zone, "BOTTOM", 2, -3)
  zone:SetPoint("TOP", root, "TOP", 4, -5)
  diff:SetPoint("RIGHT", root, "RIGHT", -6, 7)
  untouched:SetPoint("LEFT", root, "LEFT", 0, 0)

  for _, button in ipairs({ clock, zone, diff }) do
    enableButtonStacking(button, true)
  end
  clock.slackHacksRealClearAllPoints(clock)
  zone.slackHacksRealClearAllPoints(zone)
  diff.slackHacksRealClearAllPoints(diff)
  clock.slackHacksRealSetPoint(clock, "RIGHT", root, "RIGHT", 0, 0)
  diff.slackHacksRealSetPoint(diff, "RIGHT", clock, "LEFT", 0, 0)
  zone.slackHacksRealSetPoint(zone, "RIGHT", diff, "LEFT", 0, 0)
  clock:ClearAllPoints()
  clock:SetPoint("TOP", zone, "BOTTOM", 12, -3)

  table.insert(registeredButtons, clock)
  registeredButtonsByFrame[clock] = true
  if registerAll then
    table.insert(registeredButtons, diff)
    table.insert(registeredButtons, zone)
    registeredButtonsByFrame[diff] = true
    registeredButtonsByFrame[zone] = true
  end
  table.insert(registeredButtons, untouched)
  registeredButtonsByFrame[untouched] = true
  local untouchedClears = untouched.clears
  disableAllStacking()

  assert(clock.points[1][1] == "TOP" and clock.points[1][2] == zone and clock.points[1][4] == 12 and clock.points[1][5] == -3)
  assert(zone.points[1][2] == root and zone.points[1][4] == 4 and zone.points[1][5] == -5)
  assert(diff.points[1][2] == root and diff.points[1][4] == -6 and diff.points[1][5] == 7)
  assert(not clock.slackHacksSaved and not zone.slackHacksSaved and not diff.slackHacksSaved)
  assert(not clock.slackHacksRealSetPoint and not zone.slackHacksRealSetPoint and not diff.slackHacksRealSetPoint)
  assert(untouched.clears == untouchedClears and untouched.points[1][2] == root)
  disableAllStacking()
  assert(clock.points[1][2] == zone and zone.points[1][2] == root and diff.points[1][2] == root)
end

testRestore(true)
testRestore(false)

SlackHacks.db = { profile = { minimap = { enabled = true, shape = "square" } } }
--- Report the enabled minimap module.
---@return boolean
function module:IsEnabled() return true end
--- Disable Forever border reskinning for the layout tests.
---@return boolean
function SlackHacks.isForever() return false end
--- Report that protected layout can run.
---@return boolean
function InCombatLockdown() return false end
C_Timer = {
  --- Ignore unrelated deferred title-bar work.
  After = function() end,
}
Minimap = frame("Minimap")
Minimap.width, Minimap.height = 200, 200
MinimapCluster = nil
local border = frame("SlackHacksMinimapSquareBorder")
border.width, border.height, border.scale, border.level = 220, 246, 1.5, 600
local applyTitleBarLayout = upvalue(module.ApplyAll, "applyTitleBarLayout")
local layoutIcons = upvalue(applyTitleBarLayout, "layoutTitleBarIcons")
local layoutAddons = upvalue(layoutIcons, "layoutAddonButtonsOnBorder")
local position = upvalue(layoutAddons, "positionAddonButtonOnBorder")
local dimensions = upvalue(position, "getSquareBorderDimensions")
local target = upvalue(dimensions, "getSquareBorderTargetFrame")
replaceUpvalue(target, "squareBorderFrame", border)
local discover = upvalue(applyTitleBarLayout, "discoverAddonButtons")
local addonButtons = upvalue(discover, "addonButtons")
local addonButtonsByFrame = upvalue(discover, "addonButtonsByFrame")
local legacy = frame("LegacyAddonButton")
legacy.parent, legacy.width, legacy.height = Minimap, 32, 32
legacy:SetPoint("CENTER", Minimap, "CENTER", 50, -50)
local child = frame("LegacyAddonTextureFrame")
child.parent = legacy

discover()
assert(addonButtonsByFrame[legacy])
layoutAddons()
assert(legacy.parent == border and legacy.level > border.level and child.level > legacy.level)
discover()
assert(addonButtonsByFrame[legacy] and #addonButtons == 1,
  "Reparented legacy buttons must remain discoverable")

--- Verify a button lies exactly on the rectangular border path.
---@param button Frame
local function assertOnBorder(button)
  local point = button.points[1]
  assert(#button.points == 1 and point[1] == "CENTER" and point[2] == border)
  local scale = button:GetEffectiveScale() / border:GetEffectiveScale()
  local x, y = point[4] * scale, point[5] * scale
  assert(math.abs(x) <= 112.000001 and math.abs(y) <= 125.000001)
  assert(math.abs(math.abs(x) - 112) < 0.000001 or math.abs(math.abs(y) - 125) < 0.000001)
end

for angle = 0, 359, 15 do
  legacy:SetPoint("CENTER", Minimap, math.cos(math.rad(angle)) * 80, math.sin(math.rad(angle)) * 80)
  assertOnBorder(legacy)
  assert(math.abs(legacy.slackHacksAngle - angle) < 0.000001)
end
legacy:SetPoint("CENTER", 0, 80)
assertOnBorder(legacy)
assert(legacy.points[1][5] == 125)
legacy.scale = 0.5
layoutAddons()
assertOnBorder(legacy)
assert(legacy.points[1][5] == 250 and legacy.scale == 0.5,
  "Scaled icons must land on the visible border without changing their native size")
legacy.scale = 1
layoutAddons()
legacy:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -3)
assert(legacy.slackHacksAngle == 90, "Non-center anchors must not be interpreted as radial offsets")
local alternateParent = frame("AlternateParent")
legacy:SetParent(alternateParent)
assert(legacy.parent == border and legacy.slackHacksSaved.parent == alternateParent)
assertOnBorder(legacy)
child.level = 1
legacy:SetFrameLevel(8)
assert(legacy.level > border.level and child.level > legacy.level)
legacy.db = { minimapPos = 180 }
legacy:SetPoint("CENTER", Minimap, "CENTER", 80, 0)
assert(math.abs(legacy.points[1][4] + 112) < 0.000001,
  "Library redraws must use the current saved angle, not a stale cached angle")
border.width, border.height, border.strata = 400, 300, "FULLSCREEN"
layoutAddons()
assert(math.abs(legacy.points[1][4] + 202) < 0.000001 and legacy.strata == "FULLSCREEN",
  "Resizing and raising the minimap must retain icons on its new visible border")
border.width, border.height, border.strata = 220, 246, "MEDIUM"
layoutAddons()

local updates, stopped = 0, false
--- Run a native script before its additive hooks.
---@param button Frame
---@param event string
local function runScript(button, event)
  if button.scripts[event] then button.scripts[event](button) end
  for _, hook in ipairs(button.hooks[event] or {}) do hook(button) end
end
--- Emulate an addon's own position persistence and redraw during dragging.
---@param self Frame
local function nativeUpdate(self)
  updates = updates + 1
  self.db.minimapPos = 0
  self:ClearAllPoints()
  self:SetPoint("CENTER", Minimap, "CENTER", 80, 0)
end
legacy:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", nativeUpdate) end)
legacy:SetScript("OnDragStop", function(self) stopped = true; self:SetScript("OnUpdate", nil) end)
--- Return a cursor position scaled relative to the square border.
---@return number, number
function GetCursorPosition() return 300, 450 end
runScript(legacy, "OnDragStart")
runScript(legacy, "OnUpdate")
assert(updates == 1 and legacy.scripts.OnUpdate == nativeUpdate)
assertOnBorder(legacy)
assert(math.abs(legacy.db.minimapPos - math.deg(math.atan2(300, 200))) < 0.000001)
runScript(legacy, "OnDragStop")
assert(stopped and legacy.scripts.OnUpdate == nil and not legacy.isDraggingOnSquareBorder)
assertOnBorder(legacy)

SlackHacks.db.profile.minimap.shape = "circle"
enableButtonStacking(legacy, false)
assert(legacy.parent == alternateParent and not legacy.slackHacksRealSetParent)
assert(legacy.points[1][2] == Minimap and legacy.points[1][4] == 80)
runScript(legacy, "OnDragStart")
assert(legacy.scripts.OnUpdate == nativeUpdate and not legacy.isDraggingOnSquareBorder,
  "Round-mode dragging must remain owned by the addon")
runScript(legacy, "OnDragStop")
print("Minimap anchor restoration tests passed")
