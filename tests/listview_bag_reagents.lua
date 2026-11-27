-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_reagents.lua

local retail = true
local forever = false
local profile = { showReagentBagContents = false, protectedItems = {}, trashItems = {} }
local frames = {}
local refreshes = 0
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
local notices = {}
--- Record user-facing warnings.
---@param message string Warning message.
function SlackHacks.prn(message) notices[#notices + 1] = message end
Enum = { ItemClass = {}, ItemQuality = { Common = 1 }, BagIndex = { Backpack = 0 } }
UIParent = {}
C_AddOns = { LoadAddOn = function() end }

--- Supply the addon module required to load the bag implementation.
---@return table module
function SlackHacks:NewModule() return { IsEnabled = function() return true end } end

--- Select the mocked client type.
---@return boolean retailClient
function SlackHacks.isRetail() return retail end

--- Select the mocked Forever client.
---@return boolean foreverClient
function SlackHacks.isForever() return forever end

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
  --- Return whether the widget is visible.
  ---@return boolean shown Whether the widget is visible.
  function widget:IsShown() return self.shown end
  --- Record whether a control can be clicked.
  ---@param enabled boolean Whether the control is enabled.
  function widget:SetEnabled(enabled) self.enabled = enabled end
  --- Record widget dimensions.
  ---@param width number Width.
  ---@param height number Height.
  function widget:SetSize(width, height) self.width, self.height = width, height end
  --- Return a mock disabled texture for icon buttons.
  ---@return table texture Disabled texture.
  function widget:GetDisabledTexture()
    local texture = rawget(self, "disabledTexture")
    if not texture then texture = CreateFrame("Texture"); self.disabledTexture = texture end
    return texture
  end
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
  --- Create a mocked font string.
  ---@return table fontString
  function widget:CreateFontString() return CreateFrame("FontString") end
  --- Supply the inherited font used by the footer.
  ---@return string path Font path.
  ---@return number size Font size.
  ---@return string flags Font flags.
  function widget:GetFont() return "mock-font", 10, "" end
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

assert(loadfile("ListviewBagGear.lua"))()
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
      function entry:CreateCheckbox(label, checked, select)
        menuEntries[#menuEntries + 1] = { text = label, section = text, checked = checked, select = select }
      end
      menuEntries[#menuEntries + 1] = entry
      return entry
    end,
    CreateDivider = function() end,
    CreateTitle = function(_, title) section = title end,
    CreateCheckbox = function(_, text, checked, select)
      menuEntries[#menuEntries + 1] = { text = text, section = section, checked = checked, select = select }
    end,
    CreateRadio = function(_, text, checked, select)
      menuEntries[#menuEntries + 1] = { text = text, checked = checked, select = select }
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
assert(menuEntries[1].text == "Show All" and menuEntries[1].response == MenuResponse.Refresh)
assert(not entry("Reagent Bag") and entry("Unflagged", "Flags").checked())
assert(entry("Junk", "Flags").checked() and entry("Junk", "Categories").checked())
assert(entry("Unbound", "Binding").checked() and entry("Soulbound", "Binding").checked()
  and entry("Warbound", "Binding").checked(), "Retail must expose all binding filters")
local bindingIndex, categoriesIndex
for index, value in ipairs(menuEntries) do
  if value.text == "Unbound" and value.section == "Binding" then bindingIndex = index end
  if value.text == "Equipment" and value.section == "Categories" then categoriesIndex = index end
end
assert(bindingIndex and categoriesIndex and bindingIndex < categoriesIndex,
  "Binding filters must follow Flags and precede Categories")
profile.categoryFilters.special = false
assert(not entry("Essentials", "Categories").checked(), "Renaming must retain the saved Special filter")
profile.categoryFilters.special = true
local expectedCategories = "Equipment,Consumables,Profession Goods,Junk,Quest Items,Reagents,Essentials,Other"
local categoryLabels = {}
for _, value in ipairs(menuEntries) do
  if value.section == "Categories" then categoryLabels[#categoryLabels + 1] = value.text end
end
assert(table.concat(categoryLabels, ",") == expectedCategories, "Modern menu must use the requested category order")
entry("Auction", "Flags").select()
entry("Equipment", "Categories").select()
assert(profile.flagFilters.auction == false and profile.categoryFilters.equipment == false and filtersButton.label == "Filters (2)")
entry("Show All").select()
assert(entry("Auction", "Flags").checked() and entry("Equipment", "Categories").checked()
  and profile.showReagentBagContents == false and refreshes == 3 and filtersButton.label == "Filters (None)")
for _, value in ipairs(menuEntries) do
  if value.checked then value.select() end
end
assert(filtersButton.label == "Filters (17)", "Count every visible unchecked filter")
entry("Show All").select()
assert(filtersButton.label == "Filters (None)", "Show All must clear the filter count")
local updateFiltersLabel = upvalue(createFooter, "updateFiltersLabel")
local originalProfile = SlackHacks.db.profile.listviewBag
SlackHacks.db.profile.listviewBag = { flagFilters = { mail = false }, categoryFilters = {}, showReagentBagContents = false }
updateFiltersLabel()
assert(filtersButton.label == "Filters (1)", "The label must reflect a changed profile")
SlackHacks.db.profile.listviewBag = originalProfile
updateFiltersLabel()
assert(filtersButton.label == "Filters (None)")

local viewsButton = frames.SlackHacksListviewBagViewsButton
local gearButton = frames.SlackHacksListviewBagGearFiltersButton
assert(viewsButton.anchor[2] == filtersButton and gearButton.anchor[2] == viewsButton)
assert(viewsButton.label == "Default View" and not gearButton.shown)
openModernFilters(viewsButton)
assert(entry("Default View").checked() and entry("Selling View") and entry("Gear View"))
local activeColumns = upvalue(upvalue(renderRows, "layoutHeaders"), "computeLayout")
activeColumns = upvalue(activeColumns, "activeColumns")
profile.columnOrder = { "quantity", "name", "ilvl", "armorType", "armorSlot", "bind" }
entry("Selling View").select()
assert(viewsButton.label == "Selling View")
assert(table.concat(activeColumns(), ",") == "quantity,name,vendor,auction,armorType,armorSlot,bind")
assert(table.concat(profile.columnOrder, ",") == "quantity,name,ilvl,armorType,armorSlot,bind",
  "view changes must preserve the user's default column order")
openModernFilters(viewsButton)
entry("Gear View").select()
assert(profile.view == "gear" and gearButton.shown and viewsButton.label == "Gear View")
assert(table.concat(activeColumns(), ",") == "quantity,name,upgrade,ilvl,armorType,armorSlot,bind")
C_Item = { GetItemSubClassInfo = function(class, subclass)
  if class == 4 and subclass == 1 then return "Cloth" end
end }
ITEM_MOD_AGILITY_SHORT = "Agility"
INVTYPE_HEAD = "Head"
openModernFilters(gearButton)
assert(menuEntries[1].text == "Show All" and menuEntries[2].text == "Uncheck All"
  and menuEntries[2].response == MenuResponse.Refresh
  and entry("Downgrade Only") and entry("Cloth", "Armor and Weapons")
  and entry("Head", "Equipment Slots") and entry("Agi", "Stats"))
local matchesGearFilters = upvalue(buildDisplayRows, "matchesGearFilters")
local gearItem = { classID = 4, subclassID = 1, equipLoc = "INVTYPE_HEAD",
  itemStats = { ITEM_MOD_AGILITY_SHORT = 2 },
  comparisons = { SlackHacks.ListviewBagGear.CompareStats({ ITEM_MOD_AGILITY_SHORT = 2 },
    { ITEM_MOD_AGILITY_SHORT = 3 }, 1) } }
assert(matchesGearFilters(gearItem), "gear is initially shown")
entry("Cloth", "Armor and Weapons").select()
assert(not matchesGearFilters(gearItem), "unchecked armor types are hidden")
entry("Cloth", "Armor and Weapons").select()
entry("Agi", "Stats").select()
assert(not matchesGearFilters(gearItem), "unchecked stats are hidden")
entry("Cloth", "Armor and Weapons").select()
entry("Downgrade Only").select()
assert(profile.gearFilters.types["4:1"] == false and profile.gearFilters.stats.ITEM_MOD_AGILITY_SHORT == false
  and profile.gearFilters.downgradeOnly)
entry("Show All").select()
assert(not next(profile.gearFilters.types) and not next(profile.gearFilters.stats)
  and not profile.gearFilters.downgradeOnly)
entry("Downgrade Only").select()
local loss = gearItem.comparisons[1]
gearItem.comparisons[2] = SlackHacks.ListviewBagGear.CompareStats({ ITEM_MOD_AGILITY_SHORT = 2 },
  { ITEM_MOD_AGILITY_SHORT = 1 }, 2)
assert(not matchesGearFilters(gearItem), "A gain in any comparison must exclude an item from Downgrade Only")
gearItem.comparisons[2] = nil
assert(matchesGearFilters(gearItem) and loss.hasLoss, "Pure stat losses must remain visible")
entry("Uncheck All").select()
assert(not entry("Downgrade Only").checked() and not entry("Cloth", "Armor and Weapons").checked()
  and not entry("Head", "Equipment Slots").checked() and not entry("Agi", "Stats").checked()
  and not matchesGearFilters(gearItem), "Uncheck All must disable every gear filter")
entry("Cloth", "Armor and Weapons").select()
entry("Head", "Equipment Slots").select()
entry("Agi", "Stats").select()
assert(matchesGearFilters(gearItem), "Individual filters must be selectable after Uncheck All")
entry("Show All").select()
assert(entry("Cloth", "Armor and Weapons").checked() and entry("Head", "Equipment Slots").checked()
  and entry("Agi", "Stats").checked(), "Show All must restore the unchecked filters")
do
  local legacyGear
  EasyMenu = function(menu) legacyGear = menu end
  local openGearFiltersMenu = upvalue(createFooter, "openGearFiltersMenu")
  openGearFiltersMenu(gearButton)
  assert(legacyGear[1].text == "Show All" and legacyGear[2].text == "Uncheck All"
    and legacyGear[2].keepShownOnClick)
  legacyGear[2].func()
  assert(not legacyGear[3].checked() and not legacyGear[4].menuList[1].checked()
    and not legacyGear[5].menuList[1].checked() and not legacyGear[6].menuList[1].checked(),
    "The legacy menu must uncheck the same gear filters")
  legacyGear[1].func()
  assert(legacyGear[4].menuList[1].checked() and legacyGear[5].menuList[1].checked()
    and legacyGear[6].menuList[1].checked())
end
openModernFilters(viewsButton)
entry("Default View").select()
assert(not gearButton.shown and viewsButton.label == "Default View")
profile.view = nil
ITEM_MOD_AGILITY_SHORT = nil
INVTYPE_HEAD = nil

-- Auction interactions select Selling temporarily and only query after an explicit refresh.
local auctionRefresh = frames.SlackHacksListviewBagAuctionRefresh
local ahCheckbox = frames.SlackHacksListviewBagAHMode
assert(auctionRefresh.width == 14 and auctionRefresh.height == 14,
  "The auction refresh button must use the reduced icon size")
local selectView = upvalue(upvalue(createFooter, "openViewsMenu"), "selectView")
local startAuction = upvalue(createFooter, "updateAuctionView")
local bagWindow = CreateFrame("Frame")
local previousFrame = upvalue(startAuction, "frame", bagWindow)
local previousGroups = upvalue(startAuction, "collectGroups", function()
  return { { hyperlink = "item:42", entries = { { bagID = 0, slot = 1 } } } }
end)
local scans, scannedItems, auctionator, cancellations = 0, nil, false, 0
SlackHacks.ListviewBagAuction = {
  Cancel = function() cancellations = cancellations + 1 end,
  HasAuctionator = function() return auctionator end,
  Start = function(items) scans = scans + 1; scannedItems = items end,
}
C_AuctionHouse = {
  IsSellItemValid = function(location, displayError)
    assert(displayError == false)
    return location.slot ~= 2
  end,
}
ItemLocation = {
  CreateFromBagAndSlot = function(_, bag, slot)
    return { bag = bag, slot = slot, IsValid = function() return slot ~= 3 end }
  end,
}
local originalNativeBagOpen = SlackHacks.ListviewBag.OnNativeBagOpen
SlackHacks.ListviewBag.OnNativeBagOpen = function() end
profile.enabled = true
selectView("gear")
assert(not auctionRefresh.shown and not ahCheckbox.shown)
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
assert(profile.view == "gear" and viewsButton.label == "Selling View" and scans == 0
  and auctionRefresh.shown and auctionRefresh.enabled and ahCheckbox.shown and ahCheckbox.enabled and ahCheckbox.checked,
  "Opening the auction house must temporarily select Selling without starting a scan")
ahCheckbox:SetChecked(false)
ahCheckbox.scripts.OnClick(ahCheckbox)
assert(not ahCheckbox.checked, "AH Mode must remain manually toggleable while the auction house is open")
ahCheckbox:SetChecked(true)
ahCheckbox.scripts.OnClick(ahCheckbox)
auctionRefresh.scripts.OnClick()
assert(scans == 1 and #scannedItems == 1, "The refresh button must explicitly start the scan")
assert(ahCheckbox.anchor[2] == auctionRefresh, "AH Mode must be positioned beside the refresh button")
auctionator = true
local previousCancellations = cancellations
SlackHacks.ListviewBag:OnMailAddonLoaded("ADDON_LOADED", "Auctionator")
assert(not auctionRefresh.shown and ahCheckbox.shown and ahCheckbox.anchor[2] == viewsButton
  and cancellations == previousCancellations + 1,
  "Loading Auctionator must stop scanning, hide refresh, and keep AH Mode next to Views")
SlackHacks.ListviewBag:OnBagInteractionClosed("AUCTION_HOUSE_CLOSED")
assert(profile.view == "gear" and viewsButton.label == "Gear View" and not auctionRefresh.shown
  and not auctionRefresh.enabled and not ahCheckbox.checked,
  "Closing the auction house must restore the saved view and turn AH Mode off")
selectView("selling")
assert(not auctionRefresh.shown and ahCheckbox.shown and scans == 1,
  "Auctionator must hide refresh even when the auction house is closed")
auctionator = false
selectView("selling")
assert(auctionRefresh.shown and not auctionRefresh.enabled and ahCheckbox.shown and scans == 1,
  "The refresh button must be disabled outside the auction house")
local auctionApi = C_AuctionHouse
C_AuctionHouse = nil
selectView("selling")
assert(not ahCheckbox.enabled, "AH Mode must be disabled if auction eligibility cannot be checked")
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
assert(not ahCheckbox.checked and notices[#notices]:find("eligibility cannot be checked", 1, true),
  "Automatic mode must report unavailable auction eligibility")
SlackHacks.ListviewBag:OnBagInteractionClosed("AUCTION_HOUSE_CLOSED")
C_AuctionHouse = auctionApi
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
selectView("default")
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
assert(viewsButton.label == "Default View", "Duplicate open events must not override a manually selected view")
SlackHacks.ListviewBag:OnBagInteractionClosed("AUCTION_HOUSE_CLOSED")
assert(profile.view == "default" and viewsButton.label == "Default View",
  "A manually selected view must remain saved after the auction house closes")

selectView("selling")
ahCheckbox:SetChecked(true)
ahCheckbox.scripts.OnClick(ahCheckbox)
profile.autoAHMode = false
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
assert(ahCheckbox.checked, "A removed automatic-mode preference must not prevent AH Mode")
ahCheckbox:SetChecked(false)
ahCheckbox.scripts.OnClick(ahCheckbox)
assert(not ahCheckbox.checked, "AH Mode must remain manually toggleable during the visit")
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
assert(not ahCheckbox.checked, "Duplicate open events must not reset the temporary choice")
SlackHacks.ListviewBag:OnBagInteractionClosed("AUCTION_HOUSE_CLOSED")
assert(ahCheckbox.checked, "Closing must restore AH Mode when it was enabled before the visit")
ahCheckbox:SetChecked(false)
ahCheckbox.scripts.OnClick(ahCheckbox)
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
assert(ahCheckbox.checked, "Opening must enable AH Mode even when it was previously off")
ahCheckbox:SetChecked(false)
ahCheckbox.scripts.OnClick(ahCheckbox)
ahCheckbox:SetChecked(true)
ahCheckbox.scripts.OnClick(ahCheckbox)
SlackHacks.ListviewBag:OnBagInteractionClosed("AUCTION_HOUSE_CLOSED")
assert(not ahCheckbox.checked, "Closing must restore AH Mode when it was disabled before the visit")

ahCheckbox:SetChecked(true)
ahCheckbox.scripts.OnClick(ahCheckbox)
C_AuctionHouse = nil
SlackHacks.ListviewBag:OnBagInteractionOpen("AUCTION_HOUSE_SHOW")
assert(not ahCheckbox.checked and not ahCheckbox.enabled, "Unavailable eligibility must not activate AH Mode")
SlackHacks.ListviewBag:OnBagInteractionClosed("AUCTION_HOUSE_CLOSED")
assert(ahCheckbox.checked, "An unavailable temporary mode must still restore the prior choice")
local scanGroups = upvalue(startAuction, "collectGroups", function()
  return { { itemID = 301, quality = 1, classID = 15, statusKey = "301", sellPrice = 5,
    entries = { { bagID = 0, slot = 1, count = 1 } } } }
end)
assert(#buildDisplayRows() == 1, "An unavailable eligibility API must not filter or crash after restoring AH Mode")
upvalue(startAuction, "collectGroups", scanGroups)
C_AuctionHouse = auctionApi
ahCheckbox:SetChecked(false)
ahCheckbox.scripts.OnClick(ahCheckbox)

-- AH Mode checks each stack and leaves the saved Filters settings alone.
selectView("selling")
local auctionGroups = {
  { itemID = 301, quality = 1, classID = 15, statusKey = "301", sellPrice = 5, count = 6,
    entries = { { bagID = 0, slot = 1, count = 2 }, { bagID = 0, slot = 2, count = 4 } } },
  { itemID = 302, quality = 1, classID = 15, statusKey = "302", sellPrice = 5, isBound = true,
    entries = { { bagID = 0, slot = 1, count = 1 } } },
  { itemID = 303, quality = 1, classID = 15, statusKey = "303", sellPrice = 5, accountBound = true,
    entries = { { bagID = 0, slot = 1, count = 1 } } },
  { itemID = 304, quality = 1, classID = 15, statusKey = "304", sellPrice = 0,
    entries = { { bagID = 0, slot = 1, count = 1 } } },
  { itemID = 305, quality = 1, classID = 15, statusKey = "305", sellPrice = 5,
    entries = { { bagID = 0, slot = 3, count = 1 } } },
  { itemID = 306, quality = 1, classID = 15, statusKey = "306",
    entries = { { bagID = 0, slot = 1, count = 1 } } },
  { itemID = 307, quality = 1, classID = 15, statusKey = "307", sellPrice = 5,
    entries = { { bagID = 0, slot = 1, count = 1 } } },
}
profile.protectedItems["307"] = {}
upvalue(startAuction, "collectGroups", function() return auctionGroups end)
local vendorRows = buildDisplayRows()
assert(#vendorRows == 5 and vendorRows[2].isBound and vendorRows[3].accountBound
  and vendorRows[4].itemID == 305 and vendorRows[5].itemID == 307,
  "Selling View without AH Mode must retain vendor-sellable bound, auction-ineligible, and protected items")
ahCheckbox:SetChecked(true)
ahCheckbox.scripts.OnClick(ahCheckbox)
local eligibleRows = buildDisplayRows()
assert(#eligibleRows == 1 and eligibleRows[1].itemID == 301 and eligibleRows[1].count == 2
  and #eligibleRows[1].entries == 1, "AH Mode must exclude bound, unpriced, and invalid items and stacks")
assert(profile.bindingFilters.unbound ~= false and profile.bindingFilters.soulbound ~= false
  and profile.bindingFilters.warbound ~= false, "AH Mode must not change saved binding filters")
selectView("default")
assert(#buildDisplayRows() == 7, "AH Mode must not filter other views")
ahCheckbox:SetChecked(false)
ahCheckbox.scripts.OnClick(ahCheckbox)
upvalue(startAuction, "collectGroups", previousGroups)
upvalue(startAuction, "frame", previousFrame or false)
SlackHacks.ListviewBagAuction = nil
SlackHacks.ListviewBag.OnNativeBagOpen = originalNativeBagOpen
profile.protectedItems["307"] = nil
profile.view, profile.enabled, profile.autoAHMode = nil, nil, nil

local visited = {}
C_Container = {
  GetContainerNumSlots = function(bagID) visited[#visited + 1] = bagID; return 0 end,
}
collectGroups()
assert(#visited == 6 and visited[6] == 5, "A previously unchecked reagent-bag filter must be ignored")
visited = {}
profile.showReagentBagContents = true
collectGroups()
assert(#visited == 6 and visited[6] == 5, "A previously checked reagent-bag filter must also be ignored")

retail = false
forever = true
profile.showReagentBagContents = false
assert(#bagIDs() == 6 and bagIDs()[6] == 5, "Forever must include the reagent bag")
visited = {}
collectGroups()
assert(#visited == 6 and visited[6] == 5, "Forever must scan the reagent bag")
createFooter()
filtersButton = frames.SlackHacksListviewBagFiltersButton
assert(filtersButton.label == "Filters (None)", "A saved reagent-bag filter must not be counted")
openModernFilters(filtersButton)
assert(not entry("Reagent Bag") and entry("Unbound", "Binding") and entry("Soulbound", "Binding")
  and not entry("Warbound", "Binding"), "Forever must offer binding filters without Warbound")

forever = false
assert(#bagIDs() == 5, "Classic must not include reagent bag")
visited = {}
collectGroups()
assert(#visited == 5 and visited[5] == 4, "Classic must scan only its available bags")
createFooter()
filtersButton = frames.SlackHacksListviewBagFiltersButton
assert(filtersButton.label == "Filters (None)", "Unavailable reagent-bag filters must not be counted")
openModernFilters(filtersButton)
assert(not entry("Reagent Bag") and entry("Other", "Categories"), "Classic must show filters without a reagent-bag option")

-- The legacy dropdown provides the same flag and category filters.
MenuUtil = nil
forever = true
local legacy
--- Capture the legacy dropdown entries.
---@param menu table Menu entries.
function EasyMenu(menu) legacy = menu end
createFooter()
filtersButton = frames.SlackHacksListviewBagFiltersButton
assert(filtersButton.template == "UIDropDownMenuTemplate" and filtersButton.label == "Filters (None)")
local legacyButton = _G[filtersButton:GetName() .. "Button"]
legacyButton.scripts.OnClick(legacyButton)
assert(legacy[1].text == "Show All")
categoryLabels = {}
local inCategories = false
for _, value in ipairs(legacy) do
  assert(value.text ~= "Reagent Bag", "Legacy menus must not offer a reagent-bag filter")
  if inCategories then categoryLabels[#categoryLabels + 1] = value.text end
  if value.isTitle and value.text == "Categories" then inCategories = true end
  if value.text == "Unflagged" then
    assert(value.checked())
    value.func()
    assert(not value.checked() and filtersButton.label == "Filters (1)")
  end
  if value.text == "Unbound" then
    assert(value.checked())
    value.func()
    assert(not value.checked() and filtersButton.label == "Filters (2)")
  end
  assert(value.text ~= "Warbound", "Forever's legacy menu must not offer Warbound")
end
assert(table.concat(categoryLabels, ",") == expectedCategories, "Legacy menu must use the requested category order")
legacy[1].func()
assert(profile.flagFilters.unflagged and filtersButton.label == "Filters (None)")
forever = false

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
retail = true
local unbound, soulbound, warbound = makeItem(90, 15, "", 1), makeItem(91, 15, "", 1), makeItem(92, 15, "", 1)
soulbound.isBound = true
warbound.accountBound = true
profile.bindingFilters.unbound = false
assert(not matchesFilters(unbound) and matchesFilters(soulbound) and matchesFilters(warbound),
  "Binding filters must distinguish unbound, soulbound, and warbound items")
profile.bindingFilters.unbound, profile.bindingFilters.soulbound = true, false
assert(matchesFilters(unbound) and not matchesFilters(soulbound) and matchesFilters(warbound))
profile.bindingFilters.soulbound, profile.bindingFilters.warbound = true, false
assert(matchesFilters(unbound) and matchesFilters(soulbound) and not matchesFilters(warbound))
profile.bindingFilters.warbound = true
retail = false
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
local classify = upvalue(matchesFilters, "itemCategory")
for _, item in ipairs(SlackHacks.ListviewBag.ESSENTIAL_ITEMS) do
  assert(classify(makeItem(item.id, 15, "", 1)) == "special",
    item.name .. " must remain an Essential by default")
end
profile.essentialItems[2901] = false
assert(classify(makeItem(2901, 2, "INVTYPE_WEAPONMAINHAND", 1)) == "equipment",
  "Unchecking a built-in Essential must restore its normal category")
profile.essentialItems[2901] = nil
local shard = makeItem(6265, 7, "", 1, true)
assert(classify(shard) == "reagents", "Soul Shards must not be Essentials by default")
profile.essentialItems.soulShards = true
assert(classify(shard) == "special", "Opted-in Soul Shards must be Essentials")
profile.essentialItems.soulShards = false
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

-- Real group collection must merge stacks across bags and apply categories to reagent-bag items.
retail = true
profile.flagFilters.unflagged = true
profile.categoryFilters.professionGoods = true
C_Container = {
  --- Return the number of mocked slots in each bag.
  ---@param bagID number Bag identifier.
  ---@return number count Slot count.
  GetContainerNumSlots = function(bagID) return bagID == 5 and 2 or bagID == 0 and 1 or 0 end,
  --- Return a shared reagent or reagent-bag-only profession good.
  ---@param bagID number Bag identifier.
  ---@param slot number Slot identifier.
  ---@return table info Item information.
  GetContainerItemInfo = function(bagID, slot)
    if bagID == 5 and slot == 2 then
      return { itemID = 35, itemName = "Goods", hyperlink = "goods-link", quality = 1, stackCount = 1 }
    end
    return { itemID = 30, itemName = "Material", hyperlink = "material-link", quality = 1, stackCount = 1,
      hasNoValue = bagID == 5 }
  end,
}
C_Item = {
  --- Return metadata used to classify the mocked items.
  ---@param link string Item hyperlink.
  ---@return string name Item name.
  ---@return any ... Remaining item metadata.
  GetItemInfo = function(link)
    return link == "material-link" and "Material" or "Goods", link, 1, 10, nil, nil, nil, nil, "", nil,
      1, 7, nil, 0, nil, nil, link == "material-link"
  end,
  GetDetailedItemLevelInfo = function() return 10 end,
}
do
  local bindInfo = upvalue(collectGroups, "getBindInfo")
  ITEM_ACCOUNTBOUND_UNTIL_EQUIP = "Warbound until equipped"
  local originalScan = upvalue(bindInfo, "scanBagItemLines", function() return { ITEM_ACCOUNTBOUND_UNTIL_EQUIP } end)
  local label, _, accountBound = bindInfo(0, 1, "material-link")
  assert(label == "Warbound" and accountBound, "Warbound-until-equipped tooltip text must count as Warbound")
  upvalue(bindInfo, "scanBagItemLines", originalScan)
  ITEM_ACCOUNTBOUND_UNTIL_EQUIP = nil
end
upvalue(collectGroups, "getBindInfo", function() return "", 0, false, false end)
upvalue(collectGroups, "getUpgradeTrack", function() return nil end)
local rows = buildDisplayRows()
assert(#rows == 2)
local material = rows[1].itemName == "Material" and rows[1] or rows[2]
assert(material.itemName == "Material" and material.count == 2 and #material.entries == 2)
selectView("selling")
rows = buildDisplayRows()
material = rows[1].itemName == "Material" and rows[1] or rows[2]
assert(#rows == 2 and material.count == 1 and #material.entries == 1 and material.entries[1].bagID == 0,
  "Selling View must exclude unsellable stacks even when another copy of the item can be sold")
local originalContainerInfo = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function(bagID, slot)
  local info = originalContainerInfo(bagID, slot)
  info.stackCount = info.itemID == 35 and 2 or bagID == 5 and 10 or 1
  return info
end
upvalue(collectGroups, "sortColumn", "quantity")
rows = buildDisplayRows()
assert(rows[1].itemName == "Material" and rows[1].count == 1 and rows[2].itemName == "Goods",
  "Quantity sorting must use sellable stack counts")
selectView("selling")
C_Container.GetContainerItemInfo = function(bagID, slot)
  local info = originalContainerInfo(bagID, slot)
  if info.itemID == 30 then info.hasNoValue = true end
  return info
end
rows = buildDisplayRows()
assert(#rows == 1 and rows[1].itemName == "Goods",
  "Selling View must hide a group when no stack is sellable despite a vendor price")
C_Container.GetContainerItemInfo = originalContainerInfo
local originalItemInfo = C_Item.GetItemInfo
for _, price in ipairs({ 0, -1 }) do
  C_Item.GetItemInfo = function(link)
    return "Material", link, 1, 10, nil, nil, nil, nil, "", nil, price, 7, nil, 0, nil, nil, true
  end
  assert(#buildDisplayRows() == 0, "Selling View must exclude zero or negative vendor prices")
end
C_Item.GetItemInfo = function(link)
  return "Material", link, 1, 10, nil, nil, nil, nil, "", nil, nil, 7, nil, 0, nil, nil, true
end
assert(#buildDisplayRows() == 0, "Selling View must exclude items while vendor prices are unavailable")
C_Item.GetItemInfo = originalItemInfo
selectView("default")
rows = buildDisplayRows()
material = rows[1].itemName == "Material" and rows[1] or rows[2]
assert(#rows == 2 and material.count == 2, "Other views must continue showing unsellable stacks")
do
  local originalContainer = C_Container
  local originalBind = upvalue(collectGroups, "getBindInfo", function(_, slot)
    if slot == 2 then return "Soulbound", 0, false, true end
    if slot == 3 then return "Warbound", 0, true, true end
    return "", 0, false, false
  end)
  C_Container = {
    GetContainerNumSlots = function(bagID) return bagID == 0 and 3 or 0 end,
    GetContainerItemInfo = function(_, slot)
      return { itemID = 30, itemName = "Material", hyperlink = "material-link", quality = 1,
        stackCount = 1, isBound = slot > 1 }
    end,
  }
  local differentBindings = collectGroups()
  assert(#differentBindings == 3, "Copies of the same item with different bindings must not merge")
  local base = differentBindings[1].statusBaseKey
  profile.mailItems[base] = { name = "Material", quality = 1 }
  differentBindings = collectGroups()
  for _, copy in ipairs(differentBindings) do
    assert((copy.statusKey ~= base) == copy.soulbound,
      "A shared Mail flag must not appear on the soulbound copy")
  end
  profile.mailItems[base] = nil
  profile.bindingFilters.soulbound = false
  local visible = buildDisplayRows()
  assert(#visible == 2, "Binding filters must only hide the matching copies of a shared item")
  profile.bindingFilters.soulbound = true
  C_Container = originalContainer
  upvalue(collectGroups, "getBindInfo", originalBind)
end
do
  local originalContainer = C_Container
  C_Container = {
    GetContainerNumSlots = function(bagID) return bagID == 0 and 2 or 0 end,
    GetContainerItemInfo = function(_, slot)
      return { itemID = 30, itemName = "Material", hyperlink = "material-link", quality = 1, stackCount = 1 }
    end,
  }
  local copies = collectGroups()
  assert(#copies == 2 and copies[1].auctionEligible ~= copies[2].auctionEligible,
    "Identical links with different auction eligibility must have separate rows")
  local base = copies[1].statusBaseKey
  local variant = base .. "\031auction-ineligible"
  profile.auctionItems[base] = { name = "Material", quality = 1 }
  profile.auctionIneligibleOverrides[variant] = true
  profile.protectedItems[variant] = { name = "Material", quality = 1 }
  copies = collectGroups()
  for _, copy in ipairs(copies) do
    assert(copy.statusKey == (copy.auctionEligible and base or variant)
      and copy.statusContext.bag == profile and #copy.statusContext.entries == 1,
      "Each copy must carry its own effective flag and live location")
  end
  profile.auctionItems[base], profile.protectedItems[variant], profile.auctionIneligibleOverrides[variant] = nil, nil, nil
  C_Container = originalContainer
end
profile.showReagentBagContents = true
rows = buildDisplayRows()
assert(#rows == 2, "Old reagent-bag settings must not affect displayed items")
profile.categoryFilters.reagents = false
rows = buildDisplayRows()
assert(#rows == 1 and rows[1].itemName == "Goods" and rows[1].entries[1].bagID == 5,
  "Hiding Reagents must not hide Profession Goods from the reagent bag")
profile.categoryFilters.reagents = true
profile.categoryFilters.professionGoods = false
rows = buildDisplayRows()
assert(#rows == 1 and rows[1].itemName == "Material" and rows[1].count == 2,
  "Hiding Profession Goods must not hide Reagents from the reagent bag")
profile.flagFilters.unflagged = false
assert(#buildDisplayRows() == 0, "Flag filters must also apply to reagent-bag items")
profile.flagFilters.unflagged = true

-- Exercise real item-info collection as well as overlapping categories and other clients.
retail, forever = false, true
profile.categoryFilters.consumables = true
C_Container = {
  --- Return a single backpack slot.
  ---@param bagID number Bag identifier.
  ---@return number count Slot count.
  GetContainerNumSlots = function(bagID) return bagID == 0 and 1 or 0 end,
  --- Return an arrow stack.
  ---@return table info Item information.
  GetContainerItemInfo = function()
    return { itemID = 2512, itemName = "Rough Arrow", hyperlink = "arrow-link", quality = 1, stackCount = 200 }
  end,
}
--- Return metadata for the arrow stack.
---@param link string Item hyperlink.
---@return string name Item name.
---@return any ... Remaining item metadata.
C_Item.GetItemInfo = function(link)
  return "Rough Arrow", link, 1, 5, nil, nil, nil, nil, "INVTYPE_AMMO", nil, 0, 6, 2, 0, nil, nil, false
end
rows = buildDisplayRows()
assert(#rows == 1 and rows[1].itemID == 2512, "Forever arrows must appear as Consumables")
local arrowKey = rows[1].statusKey
profile.mailRecipients = { [1] = { nickname = "Alt" } }
profile.mailAssignments = { [arrowKey] = 1 }
profile.mailItems[arrowKey] = {}
local collectRecipientMailItems = upvalue(SlackHacks.ListviewBag.OnMailSendSuccess, "collectRecipientMailItems")
upvalue(collectRecipientMailItems, "getUpgradeTrack", function() return nil end)
local mailItems = collectRecipientMailItems(profile)
assert(mailItems[1] and mailItems[1][1].category == "consumables",
  "Mail summaries must classify Forever arrows as Consumables")
profile.mailRecipients, profile.mailAssignments, profile.mailItems = {}, {}, {}
profile.categoryFilters.consumables = false
profile.categoryFilters.other = true
assert(#buildDisplayRows() == 0, "Forever arrows must not appear under Other")
local itemCategory = upvalue(matchesFilters, "itemCategory")
local arrow = makeItem(2512, 6, "INVTYPE_AMMO", 0, true, 4)
arrow.subclassID = 2
assert(itemCategory(arrow) == "consumables", "All Forever arrows must be consumables even with overlapping properties")
profile.essentialItems.arrows = true
assert(itemCategory(arrow) == "special", "Opted-in arrows must be classified as Essentials")
profile.categoryFilters.special, profile.categoryFilters.consumables = false, true
assert(not matchesFilters(arrow), "Essentials must override Consumables for opted-in arrows")
profile.categoryFilters.special = true
assert(matchesFilters(arrow), "The Essentials filter must control opted-in arrows")
profile.essentialItems.arrows = false
arrow.subclassID = 3
assert(itemCategory(arrow) == "quest", "Other projectile subtypes must retain normal classification")
arrow.quality, arrow.isCraftingReagent, arrow.bindType = 1, false, 0
assert(itemCategory(arrow) == "other", "Bullets must remain in Other")
arrow.subclassID = 2
retail, forever = true, false
assert(itemCategory(arrow) == "other", "Retail must retain its existing arrow classification")
retail, forever = false, false
assert(itemCategory(arrow) == "other", "Classic must retain its existing arrow classification")

retail, forever = false, true
for _, id in ipairs({ 6291, 21071, 13755, 6522, 13893 }) do
  local fish = makeItem(id, 7, "", 1, true)
  assert(itemCategory(fish) == "consumables", "Edible raw fish must take priority over Reagents")
end
local inedibleFish = makeItem(6358, 7, "", 1, true)
assert(itemCategory(inedibleFish) == "reagents", "Inedible fish must remain Reagents")
local fish = makeItem(6291, 7, "", 1, true)
profile.customEssentialItems[6291] = { name = "Raw Brilliant Smallfish" }
profile.categoryFilters.special, profile.categoryFilters.consumables, profile.categoryFilters.reagents = false, true, true
assert(itemCategory(fish) == "special" and not matchesFilters(fish),
  "Custom Essentials must override the raw-fish Consumables/Reagents overlap")
profile.customEssentialItems[6291] = nil
retail, forever = true, false
assert(itemCategory(fish) == "reagents", "Retail fish classification must be unchanged")
retail, forever = false, false
assert(itemCategory(fish) == "reagents", "Classic fish classification must be unchanged")

retail, forever = false, true
--- Return an edible fish stack.
---@return table info Item information.
C_Container.GetContainerItemInfo = function()
  return { itemID = 6291, itemName = "Raw Brilliant Smallfish", hyperlink = "fish-link", quality = 1, stackCount = 20 }
end
--- Return fish metadata, including its crafting-reagent status.
---@param link string Item hyperlink.
---@return string name Item name.
---@return any ... Remaining item metadata.
C_Item.GetItemInfo = function(link)
  return "Raw Brilliant Smallfish", link, 1, 5, nil, nil, nil, nil, "", nil, 1, 7, 8, 0, nil, nil, true
end
profile.categoryFilters.consumables = true
profile.categoryFilters.reagents = false
rows = buildDisplayRows()
assert(#rows == 1 and rows[1].itemID == 6291, "Edible fish must appear when Consumables is selected")
local fishKey = rows[1].statusKey
profile.mailRecipients = { [1] = { nickname = "Alt" } }
profile.mailAssignments = { [fishKey] = 1 }
profile.mailItems[fishKey] = {}
mailItems = collectRecipientMailItems(profile)
assert(mailItems[1] and mailItems[1][1].category == "consumables",
  "Mail summaries must classify edible fish as Consumables")
profile.mailRecipients, profile.mailAssignments, profile.mailItems = {}, {}, {}
profile.categoryFilters.consumables = false
profile.categoryFilters.reagents = true
assert(#buildDisplayRows() == 1, "Edible fish must also appear when Reagents is selected")
profile.categoryFilters.reagents = false
assert(#buildDisplayRows() == 0, "Edible fish must be hidden when both of their categories are disabled")
profile.categoryFilters.reagents = true
profile.flagFilters.unflagged = false
assert(#buildDisplayRows() == 0, "Flag filters must still apply to edible fish")
profile.flagFilters.unflagged = true
forever = false
retail = true
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
