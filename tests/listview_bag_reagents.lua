-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_reagents.lua

local retail = true
local forever = false
local profile = { showReagentBagContents = true, protectedItems = {}, trashItems = {} }
local frames = {}
local refreshes = 0
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 }, BagIndex = { Backpack = 0 } }
UIParent = {}
C_AddOns = { LoadAddOn = function() end }

--- Supply the addon module required to load the bag implementation.
---@return table module
function SlackHacks:NewModule() return {} end

--- Select the mocked client type.
---@return boolean retailClient
function SlackHacks.isRetail() return retail end

--- Select clients with the modern bag container.
---@return boolean modernClient
function SlackHacks.isRetailOrForever() return retail or forever end

--- Build a UI mock that records visibility, checked state, anchors, labels, and scripts.
---@param frameType string Widget type.
---@param name string|nil Widget name.
---@param parent table|nil Parent container.
---@return table frame Mocked widget.
function CreateFrame(frameType, name, parent)
  local widget = { name = name, parent = parent, scripts = {}, shown = true, frameLevel = 0 }
  widget.Text = {}
  widget.text = widget.Text
  --- Record UI mutations and accept irrelevant template setup.
  ---@param self table Widget or label.
  ---@param ... any Method arguments.
  local function record(self, ...)
    self.value = select(1, ...)
  end
  setmetatable(widget.Text, { __index = function() return record end })
  --- Keep the label separate from subsequent font and anchor setup.
  ---@param text string Label text.
  function widget.Text:SetText(text) self.label = text end
  --- Supply the frame methods used during footer construction.
  ---@param self table Widget.
  ---@param ... any Method arguments.
  local function noop(self, ...) end
  setmetatable(widget, { __index = function(_, key) return noop end })
  --- Store an event handler.
  ---@param event string Script name.
  ---@param handler function Callback.
  function widget:SetScript(event, handler) self.scripts[event] = handler end
  --- Record visibility.
  ---@param shown boolean Whether the widget should be visible.
  function widget:SetShown(shown) self.shown = shown end
  --- Record the widget's drawing level.
  ---@param level number Drawing level.
  function widget:SetFrameLevel(level) self.frameLevel = level end
  --- Return the widget's drawing level.
  ---@return number level
  function widget:GetFrameLevel() return self.frameLevel end
  --- Record checked state.
  ---@param checked boolean Whether the checkbox is checked.
  function widget:SetChecked(checked) self.checked = checked end
  --- Return checked state.
  ---@return boolean checked
  function widget:GetChecked() return self.checked end
  --- Return the widget name.
  ---@return string|nil name
  function widget:GetName() return self.name end
  --- Record the widget anchor.
  ---@param ... any Anchor arguments.
  function widget:SetPoint(...) self.anchor = { ... } end
  --- Create a mocked texture.
  ---@return table texture
  function widget:CreateTexture() return CreateFrame("Texture") end
  if name then frames[name] = widget end
  return widget
end

--- Accept money-frame configuration.
---@param ... any Money-frame arguments.
function MoneyFrame_SetMaxDisplayWidth(...) end

assert(loadfile("ListviewBag.lua"))()

--- Read or replace a closure's named upvalue.
---@param fn function Closure to inspect.
---@param name string Upvalue name.
---@param replacement any|nil Optional replacement.
---@return any value Original upvalue value.
local function upvalue(fn, name, replacement)
  for index = 1, math.huge do
    local key, value = debug.getupvalue(fn, index)
    if not key then break end
    if key == name then
      if replacement ~= nil then debug.setupvalue(fn, index, replacement) end
      return value
    end
  end
  error("Missing upvalue: " .. name)
end

local buildFrame = upvalue(SlackHacks.ListviewBag.OnEnable, "buildFrame")
local createFooter = upvalue(buildFrame, "createFooter")
local renderRows = upvalue(createFooter, "renderRows", function() refreshes = refreshes + 1 end)
local collectGroups = upvalue(upvalue(renderRows, "buildDisplayRows"), "collectGroups")
local bagIDs = upvalue(collectGroups, "bagIDs")
local content = CreateFrame("Frame")
content.openBagsButton = {}
content:SetFrameLevel(600)
upvalue(createFooter, "content", content)

assert(#bagIDs() == 6 and bagIDs()[6] == 5, "Retail must include reagent bag without a ReagentBag enum")
createFooter()
local checkbox = frames.SlackHacksListviewBagReagentToggle
local footer = upvalue(createFooter, "footer")
assert(checkbox.shown and checkbox.checked, "Retail checkbox must be visible and initially checked")
assert(checkbox.parent == content, "Checkbox must be a child of the bag container's content frame")
assert(checkbox.frameLevel > content.frameLevel, "Checkbox must render above the container border")
assert(checkbox.Text.label == "Reagent Bag", "Checkbox label must match")
assert(checkbox.anchor[2] == footer.sellTrashButton and checkbox.anchor[3] == "LEFT", "Checkbox must be left of Sell Trash")
checkbox.checked = false
checkbox.scripts.OnClick(checkbox)
assert(profile.showReagentBagContents == false and refreshes == 1, "Unchecking must persist and refresh rows")
checkbox.checked = true
checkbox.scripts.OnClick(checkbox)
assert(profile.showReagentBagContents == true and refreshes == 2, "Checking must persist and refresh rows")

local visited = {}
C_Container = {
  GetContainerNumSlots = function(bagID) visited[#visited + 1] = bagID; return 0 end,
}
collectGroups()
assert(#visited == 6 and visited[6] == 5, "Checked collector must scan reagent bag")
visited = {}
profile.showReagentBagContents = false
collectGroups()
assert(#visited == 5 and visited[5] == 4, "Unchecked collector must only scan ordinary bags")
assert(#bagIDs() == 6, "Display filter must not change bag actions")

retail = false
forever = true
assert(#bagIDs() == 6 and bagIDs()[6] == 5, "Forever must include the reagent bag")
createFooter()
assert(frames.SlackHacksListviewBagReagentToggle.shown, "Forever checkbox must be visible")
assert(frames.SlackHacksListviewBagReagentToggle.parent == content, "Forever checkbox must belong to the container")

forever = false
assert(#bagIDs() == 5, "Classic must not include reagent bag")
createFooter()
assert(not frames.SlackHacksListviewBagReagentToggle.shown, "Classic checkbox must be hidden")
print("Listview bag reagent checkbox tests passed")
