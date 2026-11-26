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

--- Create a mock frame that rejects circular anchor dependencies.
---@param name string
---@return table
local function frame(name)
  local result = { name = name, points = {}, scale = 1, strata = "MEDIUM", level = 1 }

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
  function result:GetWidth() return 20 end
  --- Return the frame's height.
  ---@return number
  function result:GetHeight() return 10 end
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
  --- Accept a visibility hook.
  function result:HookScript() end
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
print("Minimap anchor restoration tests passed")
