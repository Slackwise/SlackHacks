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
---@param template string|nil Frame template.
---@return table frame Mocked widget.
function CreateFrame(frameType, name, parent, template)
  local widget = { name = name, parent = parent, template = template, frameType = frameType,
    scripts = {}, shown = true, frameLevel = 0 }
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
  setmetatable(widget, { __index = function(_, key) if key ~= "legacy" then return noop end end })
  --- Store an event handler.
  ---@param event string Script name.
  ---@param handler function Callback.
  function widget:SetScript(event, handler) self.scripts[event] = handler end
  --- Record button text.
  ---@param text string Button label.
  function widget:SetText(text) self.label = text end
  --- Record a modern dropdown's fixed label.
  ---@param text string Dropdown label.
  function widget:OverrideText(text) self.label = text end
  --- Store the native dropdown's menu generator.
  ---@param generator function Menu generator.
  function widget:SetupMenu(generator) self.menuGenerator = generator end
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
  if template == "UIDropDownMenuTemplate" and name then
    _G[name .. "Button"] = CreateFrame("Button", nil, widget)
  end
  return widget
end

--- Set the width of a legacy dropdown.
---@param dropdown table Dropdown frame.
---@param width number Dropdown width.
function UIDropDownMenu_SetWidth(dropdown, width) dropdown.width = width end
--- Set the label of a legacy dropdown.
---@param dropdown table Dropdown frame.
---@param text string Dropdown label.
function UIDropDownMenu_SetText(dropdown, text) dropdown.label = text end

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
local openFiltersMenu = upvalue(createFooter, "openFiltersMenu")
local renderRows = upvalue(openFiltersMenu, "renderRows", function() refreshes = refreshes + 1 end)
local buildDisplayRows = upvalue(renderRows, "buildDisplayRows")
local collectGroups = upvalue(buildDisplayRows, "collectGroups")
local bagIDs = upvalue(collectGroups, "bagIDs")
local content = CreateFrame("Frame")
content.openBagsButton = {}
content:SetFrameLevel(600)
upvalue(createFooter, "content", content)
MenuUtil = { CreateContextMenu = function() end }

assert(#bagIDs() == 6 and bagIDs()[6] == 5, "Retail must include reagent bag without a ReagentBag enum")
createFooter()
local filtersButton = frames.SlackHacksListviewBagFiltersButton
assert(filtersButton.shown and filtersButton.label == "Filters (None)")
assert(filtersButton.frameType == "DropdownButton" and filtersButton.template == "WowStyle1DropdownTemplate")
assert(filtersButton.parent == content and filtersButton.frameLevel > content.frameLevel)
assert(filtersButton.anchor[2] == content.openBagsButton and filtersButton.anchor[3] == "LEFT")

local menuEntries
MenuResponse = { Refresh = "refresh" }
--- Generate a modern dropdown menu as Blizzard does when it opens.
---@param dropdown table Filters dropdown.
local function openModernFilters(dropdown)
  menuEntries = {}
  local section = ""
  local root = {
    CreateButton = function(_, text, select)
      local entry = { text = text, select = select, kind = "button" }
      function entry:SetResponse(response) self.response = response end
      menuEntries[#menuEntries + 1] = entry
      return entry
    end,
    CreateDivider = function() end,
    CreateTitle = function(_, title) section = title end,
    CreateCheckbox = function(_, text, checked, select)
      menuEntries[#menuEntries + 1] = { text = text, section = section, checked = checked, select = select }
    end,
  }
  dropdown.menuGenerator(dropdown, root)
end
--- Find a menu entry by label and optional section.
---@param text string Entry label.
---@param section string|nil Section label.
---@return table|nil entry Matching entry.
local function entry(text, section)
  for _, value in ipairs(menuEntries) do
    if value.text == text and (not section or value.section == section) then return value end
  end
end
openModernFilters(filtersButton)
assert(menuEntries[1].text == "Check All" and menuEntries[1].response == MenuResponse.Refresh)
assert(entry("Reagent Bag").checked() and entry("Unflagged", "Flags").checked())
assert(entry("Junk", "Flags").checked() and entry("Junk", "Categories").checked())
profile.categoryFilters.special = false
assert(not entry("Essentials", "Categories").checked(), "Renaming must retain the saved Special filter")
profile.categoryFilters.special = true
local expectedCategories = "Equipment,Consumables,Profession Goods,Junk,Quest Items,Reagents,Essentials,Other"
local categoryLabels = {}
for _, value in ipairs(menuEntries) do
  if value.section == "Categories" then categoryLabels[#categoryLabels + 1] = value.text end
end
assert(table.concat(categoryLabels, ",") == expectedCategories, "Modern menu must use the requested category order")
entry("Reagent Bag").select()
assert(profile.showReagentBagContents == false and refreshes == 1 and filtersButton.label == "Filters (1)")
entry("Reagent Bag").select()
assert(profile.showReagentBagContents == true and refreshes == 2 and filtersButton.label == "Filters (None)")
entry("Auction", "Flags").select()
entry("Equipment", "Categories").select()
assert(profile.flagFilters.auction == false and profile.categoryFilters.equipment == false and filtersButton.label == "Filters (2)")
entry("Reagent Bag").select()
assert(filtersButton.label == "Filters (3)")
entry("Check All").select()
assert(entry("Auction", "Flags").checked() and entry("Equipment", "Categories").checked()
  and profile.showReagentBagContents and refreshes == 6 and filtersButton.label == "Filters (None)")
for _, value in ipairs(menuEntries) do
  if value.checked then value.select() end
end
assert(filtersButton.label == "Filters (15)", "Count every visible unchecked filter")
entry("Check All").select()
assert(filtersButton.label == "Filters (None)", "Check All must clear the filter count")
local updateFiltersLabel = upvalue(createFooter, "updateFiltersLabel")
local originalProfile = SlackHacks.db.profile.listviewBag
SlackHacks.db.profile.listviewBag = { flagFilters = { mail = false }, categoryFilters = {}, showReagentBagContents = true }
updateFiltersLabel()
assert(filtersButton.label == "Filters (1)", "The label must reflect a changed profile")
SlackHacks.db.profile.listviewBag = originalProfile
updateFiltersLabel()
assert(filtersButton.label == "Filters (None)")

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
filtersButton = frames.SlackHacksListviewBagFiltersButton
assert(filtersButton.label == "Filters (1)", "A saved reagent-bag filter must be counted")
openModernFilters(filtersButton)
assert(entry("Reagent Bag"), "Forever must offer the reagent-bag filter")

forever = false
assert(#bagIDs() == 5, "Classic must not include reagent bag")
createFooter()
filtersButton = frames.SlackHacksListviewBagFiltersButton
assert(filtersButton.label == "Filters (None)", "Unavailable reagent-bag filters must not be counted")
openModernFilters(filtersButton)
assert(not entry("Reagent Bag") and entry("Other", "Categories"), "Classic must show filters without a reagent-bag option")

-- The legacy dropdown provides the same toggle behavior.
MenuUtil = nil
local legacy
--- Capture the legacy dropdown entries.
---@param menu table Menu entries.
function EasyMenu(menu) legacy = menu end
createFooter()
filtersButton = frames.SlackHacksListviewBagFiltersButton
assert(filtersButton.template == "UIDropDownMenuTemplate" and filtersButton.label == "Filters (None)")
local legacyButton = _G[filtersButton:GetName() .. "Button"]
legacyButton.scripts.OnClick(legacyButton)
assert(legacy[1].text == "Check All")
categoryLabels = {}
local inCategories = false
for _, value in ipairs(legacy) do
  if inCategories then categoryLabels[#categoryLabels + 1] = value.text end
  if value.isTitle and value.text == "Categories" then inCategories = true end
  if value.text == "Unflagged" then
    assert(value.checked())
    value.func()
    assert(not value.checked() and filtersButton.label == "Filters (1)")
  end
end
assert(table.concat(categoryLabels, ",") == expectedCategories, "Legacy menu must use the requested category order")
legacy[1].func()
assert(profile.flagFilters.unflagged and filtersButton.label == "Filters (None)")

-- Each item matches one checked category and its checked flag.
local matchesFilters = upvalue(buildDisplayRows, "matchesFilters")
--- Build a collected item with the metadata relevant to the filters.
---@param id number Item ID and status key.
---@param classID number Item class.
---@param equipLoc string Equipment slot.
---@param quality number Item quality.
---@param isReagent boolean|nil Crafting reagent status.
---@param bindType number|nil Item bind type.
---@return table item Collected item.
local function makeItem(id, classID, equipLoc, quality, isReagent, bindType)
  return { itemID = id, classID = classID, equipLoc = equipLoc, quality = quality,
    isCraftingReagent = isReagent, bindType = bindType, sellPrice = 1, statusKey = tostring(id),
    entries = { { bagID = 0, slot = 1 } } }
end
local cases = {
  { "equipment", makeItem(1, 4, "INVTYPE_HEAD", 1) },
  { "consumables", makeItem(2, 0, "", 1) },
  { "reagents", makeItem(3, 7, "", 1, true) },
  { "professionGoods", makeItem(4, 7, "", 1) },
  { "junk", makeItem(5, 15, "", 0) },
  { "quest", makeItem(6, 12, "", 1) },
  { "quest", makeItem(7, 15, "", 1, false, 4) },
  { "other", makeItem(8, 15, "", 1) },
  { "special", makeItem(6948, 15, "", 1) },
  { "special", makeItem(211527, 15, "", 1) },
  { "special", makeItem(280612, 15, "", 1) },
  { "special", makeItem(2901, 2, "INVTYPE_WEAPONMAINHAND", 1) },
  { "special", makeItem(7005, 2, "INVTYPE_WEAPON", 1) },
  { "special", makeItem(5956, 2, "INVTYPE_WEAPONMAINHAND", 1) },
  { "special", makeItem(4471, 7, "", 1) },
  { "special", makeItem(6218, 15, "", 1) },
  { "special", makeItem(16207, 15, "", 1) },
  { "special", makeItem(7005, 12, "INVTYPE_WEAPON", 0, true, 4) },
  { "quest", makeItem(31, 7, "INVTYPE_HEAD", 0, true, 4) },
  { "junk", makeItem(32, 7, "INVTYPE_HEAD", 0, true) },
  { "reagents", makeItem(33, 0, "INVTYPE_HEAD", 1, true) },
  { "equipment", makeItem(34, 0, "INVTYPE_HEAD", 1) },
}
local categoryNames = { "equipment", "consumables", "special", "reagents", "professionGoods", "junk", "quest", "other" }
for _, case in ipairs(cases) do
  for _, selected in ipairs(categoryNames) do
    for _, name in ipairs(categoryNames) do
      profile.categoryFilters[name] = name == selected
    end
    assert(matchesFilters(case[2]) == (selected == case[1]),
      case[1] .. " item must only match its own category, not " .. selected)
  end
end
for _, name in ipairs(categoryNames) do profile.categoryFilters[name] = false end
local reagent = makeItem(20, 7, "", 1, true)
assert(not matchesFilters(reagent), "No checked categories must hide every item")
profile.categoryFilters.reagents = true
profile.categoryFilters.equipment = true
assert(matchesFilters(reagent) and matchesFilters(makeItem(23, 4, "INVTYPE_HEAD", 1)),
  "Multiple checked categories must each include matching items")
profile.flagFilters.unflagged = false
assert(not matchesFilters(reagent), "Flag and category groups must both match")
profile.auctionItems = { ["20"] = true }
assert(matchesFilters(reagent), "A checked flag and category must include the item")
local vendorReagent = makeItem(21, 7, "", 1, true)
profile.trashItems["21"] = {}
assert(matchesFilters(vendorReagent), "Multiple checked flags must each include matching items")
profile.flagFilters.vendor = false
assert(not matchesFilters(vendorReagent) and matchesFilters(reagent), "Each flag must be filtered independently")
profile.flagFilters.auction = false
assert(not matchesFilters(reagent) and not matchesFilters(vendorReagent),
  "No matching checked flags must hide items even when their category is checked")
profile.flagFilters.vendor = true
profile.flagFilters.auction = true
upvalue(buildDisplayRows, "collectGroups", function() return { reagent, makeItem(22, 15, "", 1) } end)
assert(#buildDisplayRows() == 1, "Display rows must apply category and flag filters")
upvalue(buildDisplayRows, "collectGroups", collectGroups)

-- Real group collection must retain metadata and exclude reagent-bag stacks before grouping.
retail = true
profile.flagFilters.unflagged = true
profile.showReagentBagContents = true
C_Container = {
  GetContainerNumSlots = function(bagID) return (bagID == 0 or bagID == 5) and 1 or 0 end,
  GetContainerItemInfo = function()
    return { itemID = 30, itemName = "Material", hyperlink = "material-link", quality = 1, stackCount = 1 }
  end,
}
C_Item = {
  GetItemInfo = function(link) return "Material", link, 1, 10, nil, nil, nil, nil, "", nil, 1, 7, nil, 0, nil, nil, true end,
  GetDetailedItemLevelInfo = function() return 10 end,
}
upvalue(collectGroups, "getBindInfo", function() return "", 0, false, false end)
upvalue(collectGroups, "getUpgradeTrack", function() return nil end)
local rows = buildDisplayRows()
assert(#rows == 1 and rows[1].count == 2 and #rows[1].entries == 2)
profile.showReagentBagContents = false
rows = buildDisplayRows()
assert(#rows == 1 and rows[1].count == 1 and rows[1].entries[1].bagID == 0)
profile.categoryFilters.reagents = false
assert(#buildDisplayRows() == 0, "Collected item metadata must drive category filtering")
print("Listview bag filter tests passed")

local module = SlackHacks.ListviewBag
local bagFrame = { shown = true }
--- Report whether the mocked bag is open.
---@return boolean shown
function bagFrame:IsShown() return self.shown end
--- Open the mocked bag.
function bagFrame:Show() self.shown = true end
--- Close the mocked bag.
function bagFrame:Hide() self.shown = false end
upvalue(module.OnNativeBagOpen, "frame", bagFrame)
upvalue(module.OnNativeBagOpen, "hideDefaultBags", function() end)
upvalue(module.MERCHANT_SHOW, "updateMerchantJunkButton", function() end)
profile.enabled = true
profile.showListviewBag = true
local hooks = {}
--- Capture native bag hooks for explicit execution.
---@param name string Native function name.
---@param callback function Hook callback.
function hooksecurefunc(name, callback) hooks[name] = callback end
for _, name in ipairs({ "OpenBackpack", "OpenBag", "ToggleBackpack", "ToggleBag", "CloseBackpack" }) do
  _G[name] = function() end
end
local now = 0
--- Supply distinct timestamps for native toggles.
---@return number time
function GetTime() now = now + 1; return now end
upvalue(module.OnInitialize, "hookDefaultBagToggles")()
for _, name in ipairs({ "OpenBackpack", "OpenBag" }) do
  bagFrame.shown = true
  hooks[name]()
  assert(bagFrame.shown, name .. " must not close an already-open bag")
  bagFrame.shown = false
  hooks[name]()
  assert(bagFrame.shown, name .. " must open a closed bag")
end
hooks.ToggleBackpack()
assert(not bagFrame.shown, "Ordinary toggles must still close the bag")
hooks.ToggleBackpack()
assert(bagFrame.shown, "Ordinary toggles must still open the bag")
hooks.CloseBackpack()
assert(not bagFrame.shown, "Ordinary native close must still close the bag")

for _, interaction in ipairs({
  { open = "MAIL_SHOW", close = "MAIL_CLOSED" },
  { open = "AUCTION_HOUSE_SHOW", close = "AUCTION_HOUSE_CLOSED" },
  { open = "BANKFRAME_OPENED", close = "BANKFRAME_CLOSED" },
  { open = "GUILDBANKFRAME_OPENED", close = "GUILDBANKFRAME_CLOSED" },
  { open = "MERCHANT_SHOW", close = "MERCHANT_CLOSED" },
}) do
  bagFrame.shown = true
  if interaction.open == "MERCHANT_SHOW" then
    module:MERCHANT_SHOW()
  else
    module:OnBagInteractionOpen(interaction.open)
  end
  for _, name in ipairs({ "OpenBackpack", "OpenBag", "ToggleBackpack", "ToggleBag", "CloseBackpack" }) do
    hooks[name]()
    assert(bagFrame.shown, interaction.open .. ": " .. name .. " must keep the bag open before the interaction frame is shown")
  end
  if interaction.close == "MERCHANT_CLOSED" then
    module:MERCHANT_CLOSED()
  else
    module:OnBagInteractionClosed(interaction.close)
  end
  hooks.CloseBackpack()
  assert(not bagFrame.shown, interaction.close .. " must release the close guard")
end
for _, name in ipairs({ "MailFrame", "MerchantFrame", "AuctionHouseFrame", "AuctionFrame", "BankFrame", "GuildBankFrame" }) do
  _G[name] = { IsShown = function() return true end }
  bagFrame.shown = true
  hooks.ToggleBackpack()
  hooks.CloseBackpack()
  assert(bagFrame.shown, name .. " must protect the bag before the addon receives the open event")
  _G[name] = nil
end
print("Listview bag interaction visibility tests passed")
