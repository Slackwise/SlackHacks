-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_status.lua

local profile = { enabled = true, protectedItems = {}, trashItems = {} }
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 } }
UIParent = {}

--- Supply the bag module.
---@return table module
function SlackHacks:NewModule() return { IsEnabled = function() return true end } end
--- Include the modern reagent bag.
---@return boolean modern
function SlackHacks.isRetailOrForever() return true end

--- Construct a minimal UI object that records scripts, text, textures, and visibility.
---@return table widget
local function widget()
  local object = { scripts = {}, hooks = {}, points = {}, shown = true }
  --- Accept irrelevant frame setup.
  local function noop() end
  setmetatable(object, { __index = function(_, key)
    if key ~= "blockedAction" and key ~= "characterText" and key ~= "editingRecipient" and key ~= "mailMode" and key ~= "legacy" then
      return noop
    end
  end })
  function object:SetScript(event, handler) self.scripts[event] = handler end
  function object:HookScript(event, handler) self.hooks[event] = handler end
  function object:GetFrameLevel() return 0 end
  function object:GetNormalTexture() return nil end
  function object:GetHighlightTexture() return nil end
  function object:GetRegions() return end
  function object:GetName() return self.name end
  function object:CreateTexture() return widget() end
  function object:CreateMaskTexture() return widget() end
  function object:CreateFontString(_, _, font)
    local result = widget()
    result.font = font
    return result
  end
  function object:ClearAllPoints() self.points = {} end
  function object:SetPoint(point, ...) self.points[point] = { ... } end
  function object:SetHeight(height) self.height = height end
  function object:SetSize(width, height) self.width, self.height = width, height end
  function object:SetWidth(width) self.width = width end
  function object:GetWidth() return self.width or 0 end
  function object:GetStringWidth() return #(self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * 6 end
  function object:SetTextColor(...) self.textColor = { ... } end
  function object:SetWordWrap(enabled) self.wordWrap = enabled end
  function object:SetEnabled(enabled) self.enabled = enabled end
  function object:SetAlpha(alpha) self.alpha = alpha end
  function object:SetTexture(texture) self.texture = texture; self.atlas = nil end
  function object:SetNormalTexture(texture) self.normalTexture = texture end
  function object:SetPushedTexture(texture) self.pushedTexture = texture end
  function object:SetNormalAtlas(atlas) self.normalAtlas = atlas end
  function object:SetPushedAtlas(atlas) self.pushedAtlas = atlas end
  function object:SetHighlightAtlas(atlas) self.highlightAtlas = atlas end
  function object:SetAtlas(atlas) self.atlas = atlas; self.texture = nil end
  function object:SetRotation(rotation) self.rotation = rotation end
  function object:SetTexCoord(...) self.texCoord = { ... } end
  function object:SetText(text) self.text = text end
  function object:IsShown() return self.shown end
  function object:Show() self.shown = true end
  function object:Hide() self.shown = false end
  function object:SetShown(shown) self.shown = shown end
  function object:RegisterForClicks(...) self.clicks = { ... } end
  return object
end
--- Supply frames used by the bag and legacy menu.
---@param _ string Frame type.
---@param name string|nil Frame name.
---@param parent table|nil Parent frame.
---@param template string|nil Template name.
---@return table frame
function CreateFrame(_, name, parent, template)
  local frame = widget()
  frame.name = name
  if template == "ColumnDisplayTemplate" then
    frame.Background = widget()
    frame.TopTileStreaks = widget()
  end
  return frame
end
--- Capture the split-stack hook for testing.
---@param target table Row.
---@param name string Hooked method.
---@param handler function Hook callback.
function hooksecurefunc(target, name, handler)
  if type(target) == "table" and name == "OnModifiedClick" then target.modifiedClickHook = handler end
end
local notifications = 0
local messages = {}
local cursorType, cursorLink
local cursorClears = 0
local cursorClearFails = false
--- Supply the currently held item.
---@return string|nil kind Cursor content type.
---@return number|nil id Cursor item ID.
---@return string|nil link Cursor item link.
function GetCursorInfo() return cursorType, cursorType == "item" and 1 or nil, cursorLink end
--- Return the held item to its bag.
function ClearCursor()
  cursorClears = cursorClears + 1
  if not cursorClearFails then cursorType, cursorLink = nil, nil end
end
--- Record explanations for blocked actions.
---@param message string Explanation.
function SlackHacks.prn(message) messages[#messages + 1] = message end
--- Supply the options registry notification.
---@return table registry
function LibStub() return { NotifyChange = function() notifications = notifications + 1 end } end
--- Format atlas markup for status menu labels.
---@param atlas string Atlas name.
---@param width number Icon width.
---@param height number Icon height.
---@return string markup
function CreateAtlasMarkup(atlas, width, height)
  return ("|A:%s:%d:%d|a"):format(atlas, width, height)
end
GameTooltip = widget()
function GameTooltip:SetOwner() end
function GameTooltip:SetText(text) self.text = text; self.lines = {} end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end

assert(loadfile("ListviewBag.lua"))()

--- Read or replace a named closure upvalue.
---@param fn function Closure to inspect.
---@param name string Upvalue name.
---@param replacement any|nil Replacement value.
---@return any value Original value.
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

local module = SlackHacks.ListviewBag
local renderRows = upvalue(module.MERCHANT_SHOW, "renderRows")
local createRow = upvalue(upvalue(renderRows, "acquireRow"), "createRow")
local openMenu = upvalue(createRow, "openItemStatusMenu")
local setStatus = upvalue(openMenu, "setItemStatus")
local selectStatus = upvalue(openMenu, "selectItemStatus")
local openPicker = upvalue(selectStatus, "openMailRecipientPicker")
local deleteRecipient = upvalue(openPicker, "deleteMailRecipient")
local getStatus = upvalue(openMenu, "getItemStatus")
local statuses = upvalue(getStatus, "ITEM_STATUSES")
local updateStatusButton = upvalue(renderRows, "updateStatusButton")
local updateInteractionBlocker = upvalue(renderRows, "updateInteractionBlocker")
local blockedItemAction = upvalue(updateInteractionBlocker, "blockedItemAction")
local merchantUpdates = 0
upvalue(setStatus, "renderRows", function() end)
upvalue(setStatus, "updateMerchantJunkButton", function() merchantUpdates = merchantUpdates + 1 end)

local chooseRecipient = true
local openedPicker = 0
upvalue(selectStatus, "openMailRecipientPicker", function(_, key, info)
  openedPicker = openedPicker + 1
  if chooseRecipient then
    setStatus(key, info, statuses[5])
    profile.mailAssignments[key] = 1
  end
end)
profile.mailRecipients = { [1] = { nickname = "Bank Alt", character = "Example" } }

local row = createRow(1)
row.statusKey = "item"
row.statusInfo = { name = "Item", quality = 1 }
local button = row.statusBtn
assert(button.clicks[1] == "LeftButtonUp" and button.clicks[2] == "RightButtonUp")
updateStatusButton(button, getStatus("item"))
assert(button.text.shown and button.text.text == "..." and not button.icon.shown)
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flag item for: None" and #GameTooltip.lines == 1
  and GameTooltip.lines[1] == "Left-click to choose flag.\nRight-click to quick mark as Junk.")

local entries = {}
local menuTitle
MenuUtil = {
  CreateContextMenu = function(_, build)
    entries = {}
    local root = {
      CreateTitle = function(_, title) menuTitle = title end,
      CreateRadio = function(_, label, checked, selectStatus)
        entries[#entries + 1] = { label = label, checked = checked, selectStatus = selectStatus }
      end,
    }
    build(button, root)
  end,
}
button.scripts.OnClick(button, "LeftButton")
assert(menuTitle == "Flag item for:" and #entries == 6 and entries[1].checked())
for index, expected in ipairs({
  { "Junk", "|A:bags-junkcoin:" },
  { "Auction", "|TInterface\\Minimap\\Tracking\\Auctioneer:" },
  { "Protect", "|A:ui-castingbar-shield:" },
  { "Bank", "|TInterface\\Minimap\\Tracking\\Banker:" },
  { "Mail", "|TInterface\\Minimap\\Tracking\\Mailbox:" },
}) do
  local label = entries[index + 1].label
  assert(label:find(expected[1], 1, true) and label:find(expected[2], 1, true))
end
entries[2].selectStatus()
assert(profile.trashItems.item == row.statusInfo and entries[2].checked())
updateStatusButton(button, getStatus("item"))
assert(button.icon.shown and button.icon.atlas == "bags-junkcoin" and not button.text.shown)
button.scripts.OnClick(button, "RightButton")
assert(not getStatus("item"), "Right-click must clear a vendor mark")
button.scripts.OnClick(button, "RightButton")
assert(getStatus("item").id == "vendor", "Right-click must mark an unmarked item for vendor")

for _, case in ipairs({
  { index = 3, field = "auctionItems" },
  { index = 4, field = "protectedItems" },
  { index = 5, field = "bankItems" },
  { index = 6, field = "mailItems" },
}) do
  entries[case.index].selectStatus()
  local previousMessages, previousNotifications = #messages, notifications
  button.scripts.OnClick(button, "RightButton")
  assert(profile[case.field].item == row.statusInfo and not profile.trashItems.item,
    "Right-click must preserve " .. case.field)
  assert(#messages == previousMessages + 1 and notifications == previousNotifications)
  button.scripts.OnEnter(button)
  assert(GameTooltip.lines[1] == "Left-click to choose flag.\nRight-click cannot change this flag.")
  profile.trashItems.item = row.statusInfo
  button.scripts.OnClick(button, "RightButton")
  assert(profile[case.field].item == row.statusInfo and profile.trashItems.item == row.statusInfo,
    "Right-click must preserve overlapping non-junk marks")
end
entries[2].selectStatus()
assert(profile.trashItems.item and not profile.mailItems.item, "The menu must still allow changing a flag to Junk")

entries[4].selectStatus()
assert(profile.protectedItems.item and not profile.trashItems.item)
updateStatusButton(button, getStatus("item"))
assert(button.icon.atlas == "ui-castingbar-shield")
entries[3].selectStatus()
assert(profile.auctionItems.item and not profile.protectedItems.item and not profile.trashItems.item)
updateStatusButton(button, getStatus("item"))
assert(button.icon.texture == "Interface\\Minimap\\Tracking\\Auctioneer"
  and table.concat(button.icon.texCoord, ",") == "0,1,0,1")
entries[5].selectStatus()
assert(profile.bankItems.item and not profile.auctionItems.item)
updateStatusButton(button, getStatus("item"))
assert(button.icon.texture == "Interface\\Minimap\\Tracking\\Banker")
local visitSlots = upvalue(upvalue(module.MERCHANT_SHOW, "sellMarkedTrashItems"), "forEachSellableTrashSlot")
local protected = upvalue(visitSlots, "isProtectedItem")
assert(protected("item"), "Bank marks must use existing protection")
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flag item for: Bank" and #GameTooltip.lines == 1
  and GameTooltip.lines[1] == "Left-click to choose flag.\nRight-click cannot change this flag.")
button.scripts.OnClick(button, "RightButton")
assert(not profile.trashItems.item and profile.bankItems.item and protected("item"))
chooseRecipient = false
entries[6].selectStatus()
assert(profile.bankItems.item and not profile.mailItems.item, "Canceling recipient selection must preserve the flag")
chooseRecipient = true
entries[6].selectStatus()
assert(profile.mailItems.item and not profile.trashItems.item)
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flag item for: Mail (Bank Alt)")
deleteRecipient(profile, 1)
assert(profile.mailItems.item and not profile.mailAssignments.item, "Deleting a recipient must leave Mail unassigned")
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flag item for: Mail")
profile.mailRecipients[1] = { nickname = "Bank Alt", character = "Example" }
entries[6].selectStatus()
updateStatusButton(button, getStatus("item"))
assert(button.icon.texture == "Interface\\Minimap\\Tracking\\Mailbox")
entries[1].selectStatus()
assert(not getStatus("item") and not profile.mailAssignments.item)
assert(notifications == merchantUpdates and notifications > 0)

-- Grey items can only be protected, including against stale menu selections.
local selectJunk = entries[2].selectStatus
row.statusInfo.quality = 0
row.statusInfo.itemLevel = 10
button.scripts.OnClick(button, "LeftButton")
assert(#entries == 2 and entries[2].label:find("Protect", 1, true))
entries[2].selectStatus()
assert(profile.protectedItems.item and getStatus("item", 0).id == "protect")
selectJunk()
button.scripts.OnClick(button, "RightButton")
assert(profile.protectedItems.item and not profile.trashItems.item)
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flag item for: Protect" and GameTooltip.lines[2]:find("ignore protection", 1, true))
entries[1].selectStatus()
assert(not getStatus("item", 0))

-- Uncached items still cannot acquire flags.
row.statusInfo.quality = nil
local previousMessages = #messages
button.scripts.OnClick(button, "RightButton")
button.scripts.OnClick(button, "LeftButton")
selectJunk()
assert(not getStatus("item") and #messages == previousMessages + 3)
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Item quality is not yet available.")
row.statusInfo.quality = 1

-- Check the restriction matrix against interaction state and the click/drag blocker.
local matrix = {
  { field = "auctionItems", blocked = { merchantOpen = "vendoring" } },
  { field = "protectedItems", blocked = { merchantOpen = "vendoring", auctionOpen = "auctioning", mailOpen = "mailing" } },
  { field = "bankItems", blocked = { merchantOpen = "vendoring", auctionOpen = "auctioning", mailOpen = "mailing" } },
  { field = "mailItems", blocked = { merchantOpen = "vendoring", auctionOpen = "auctioning",
    bankOpen = "banking", guildBankOpen = "banking" } },
  { field = "trashItems", blocked = {} },
}
for _, case in ipairs(matrix) do
  for _, field in ipairs({ "trashItems", "protectedItems", "auctionItems", "bankItems", "mailItems" }) do
    profile[field].item = nil
  end
  profile[case.field].item = row.statusInfo
  for _, name in ipairs({ "merchantOpen", "auctionOpen", "mailOpen", "bankOpen", "guildBankOpen" }) do
    upvalue(blockedItemAction, name, true)
    local expected = case.blocked[name]
    assert(blockedItemAction("item", 1) == expected, case.field .. " at " .. name)
    updateInteractionBlocker(row, "item", 1)
    assert(row.actionBlocker.shown == (expected ~= nil))
    if expected then
      local previousMessages = #messages
      row.actionBlocker.scripts.OnClick(row.actionBlocker)
      row.actionBlocker.scripts.OnDragStart(row.actionBlocker)
      assert(#messages == previousMessages + 2 and messages[#messages]:find(expected, 1, true))
    end
    local greyExpected = case.field == "protectedItems" and expected or nil
    assert(blockedItemAction("item", 0) == greyExpected, "Only Protect must guard grey items")
    upvalue(blockedItemAction, name, false)
  end
end
profile.trashItems.item = nil
profile.protectedItems.item = row.statusInfo
upvalue(blockedItemAction, "merchantOpen", true)
profile.enabled = false
assert(not blockedItemAction("item", 0) and not blockedItemAction("item", 1),
  "Disabled modules must not block item interactions")
profile.enabled = true
upvalue(blockedItemAction, "merchantOpen", false)
profile.protectedItems.item = nil

-- Open and close events update guards even before Blizzard's frames become visible.
module.OnNativeBagOpen = function() end
for _, case in ipairs({
  { field = "bankItems", open = "MAIL_SHOW", close = "MAIL_CLOSED", action = "mailing" },
  { field = "protectedItems", open = "AUCTION_HOUSE_SHOW", close = "AUCTION_HOUSE_CLOSED", action = "auctioning" },
  { field = "mailItems", open = "BANKFRAME_OPENED", close = "BANKFRAME_CLOSED", action = "banking" },
  { field = "mailItems", open = "GUILDBANKFRAME_OPENED", close = "GUILDBANKFRAME_CLOSED", action = "banking" },
}) do
  profile[case.field].item = row.statusInfo
  module:OnBagInteractionOpen(case.open)
  assert(blockedItemAction("item", 1) == case.action)
  module:OnBagInteractionClosed(case.close)
  assert(not blockedItemAction("item", 1))
  profile[case.field].item = nil
end

-- Items picked up through the list view are returned on conflicting window opens.
row.hyperlink = "item-link"
for _, case in ipairs({
  { field = "auctionItems", open = "MERCHANT_SHOW", close = "MERCHANT_CLOSED", action = "vendoring" },
  { field = "protectedItems", open = "AUCTION_HOUSE_SHOW", close = "AUCTION_HOUSE_CLOSED", action = "auctioning" },
  { field = "bankItems", open = "MAIL_SHOW", close = "MAIL_CLOSED", action = "mailing" },
  { field = "mailItems", open = "BANKFRAME_OPENED", close = "BANKFRAME_CLOSED", action = "banking" },
  { field = "mailItems", open = "GUILDBANKFRAME_OPENED", close = "GUILDBANKFRAME_CLOSED", action = "banking" },
}) do
  profile[case.field].item = row.statusInfo
  cursorType, cursorLink = "item", row.hyperlink
  row.hooks.OnDragStart(row)
  local previousClears, previousMessages = cursorClears, #messages
  if case.open == "MERCHANT_SHOW" then module:MERCHANT_SHOW() else module:OnBagInteractionOpen(case.open) end
  assert(cursorClears == previousClears + 1 and not cursorType)
  assert(#messages == previousMessages + 1 and messages[#messages]:find(case.action, 1, true))
  if case.close == "MERCHANT_CLOSED" then module:MERCHANT_CLOSED() else module:OnBagInteractionClosed(case.close) end
  profile[case.field].item = nil
end

profile.protectedItems.item = row.statusInfo
cursorType, cursorLink = "item", row.hyperlink
row.hooks.OnClick(row, "LeftButton")
local previousClears = cursorClears
module:OnBagInteractionOpen("BANKFRAME_OPENED")
assert(cursorClears == previousClears and cursorType == "item", "Allowed destinations must not clear the cursor")
module:OnBagInteractionClosed("BANKFRAME_CLOSED")
cursorType, cursorLink = nil, nil
module:OnCursorChanged()
cursorType, cursorLink = "item", row.hyperlink
module:OnBagInteractionOpen("MAIL_SHOW")
assert(cursorClears == previousClears, "A later normal-bag pickup must not inherit list-view tracking")
module:OnBagInteractionClosed("MAIL_CLOSED")
row.hooks.OnDragStart(row)
cursorLink = "another-item"
module:OnBagInteractionOpen("MAIL_SHOW")
assert(cursorClears == previousClears, "A different cursor item must not be returned")
module:OnBagInteractionClosed("MAIL_CLOSED")
profile.protectedItems.item = nil
cursorType, cursorLink = nil, nil

-- A failed cursor return warns instead of claiming success, and remains tracked for a retry.
profile.protectedItems.item = row.statusInfo
cursorType, cursorLink = "item", row.hyperlink
row.hooks.OnClick(row, "LeftButton")
cursorClearFails = true
module:OnBagInteractionOpen("MAIL_SHOW")
assert(cursorType == "item" and messages[#messages]:find("please return", 1, true))
module:OnBagInteractionClosed("MAIL_CLOSED")
cursorClearFails = false
module:OnBagInteractionOpen("MAIL_SHOW")
assert(not cursorType and messages[#messages]:find("returned", 1, true))
module:OnBagInteractionClosed("MAIL_CLOSED")

-- A split-stack dialog retains the original flag key if its row is later reused.
--- Simulate full bags when a split stack is picked up.
---@return nil bagID No empty bag slot.
function SlackHacks.findEmptyBagSlot() return nil end
row.SplitStack = function() cursorType, cursorLink = "item", "item-link" end
row.modifiedClickHook(row)
row.statusKey, row.hyperlink = "other", "other-link"
row:SplitStack(1)
module:OnBagInteractionOpen("MAIL_SHOW")
assert(not cursorType and messages[#messages]:find("mailing", 1, true))
module:OnBagInteractionClosed("MAIL_CLOSED")
row.statusKey, row.hyperlink = "item", "item-link"
profile.protectedItems.item = nil

-- A menu must act on the original item even if the row is recycled before selection.
button.scripts.OnClick(button, "LeftButton")
row.statusKey = "other"
entries[5].selectStatus()
assert(profile.bankItems.item and not profile.bankItems.other)

-- The legacy dropdown exposes the same selectable statuses.
MenuUtil = nil
local legacy
function EasyMenu(menu) legacy = menu end
button.scripts.OnClick(button, "LeftButton")
assert(#legacy == 7 and legacy[1].text == "Flag item for:" and legacy[3].text:find("Junk", 1, true))
assert(legacy[4].text:find("Auction", 1, true) and legacy[5].text:find("Protect", 1, true))
assert(legacy[3].text:find("|A:bags-junkcoin:", 1, true)
  and legacy[6].text:find("|TInterface\\Minimap\\Tracking\\Banker:", 1, true))
legacy[7].func()
assert(profile.mailItems.other and not profile.trashItems.other)
assert(openedPicker > 0 and profile.mailAssignments.other == 1)
legacy[2].func()
assert(not getStatus("other"))

-- Build the actual window as on reload, including its status header atlas.
local buildFrame = upvalue(module.OnEnable, "buildFrame")
local createFooter = upvalue(buildFrame, "createFooter", function() end)
UISpecialFrames, ITEM_SEARCHBAR_LIST, tinsert = {}, {}, table.insert
--- Supply the player name for the window title.
---@return string name
function UnitName() return "Player" end
local headerAtlas
--- Validate the atlas argument passed while building the status header.
---@param atlas string Atlas name.
---@return string markup
function CreateAtlasMarkup(atlas)
  assert(type(atlas) == "string", "The status header must have a valid atlas name")
  headerAtlas = atlas
  return atlas
end
buildFrame()
assert(headerAtlas == "ui-castingbar-shield", "Reload must construct the status header")

-- The pinned flag header sorts grouped items in both directions and reports its direction.
local content = upvalue(buildFrame, "content")
local statusHeader = content.statusHeaderButton
local headerFrame = upvalue(buildFrame, "headerFrame")
local layoutHeaders = upvalue(renderRows, "layoutHeaders")
local scrollChild = upvalue(upvalue(layoutHeaders, "computeLayout"), "scrollChild")
scrollChild.GetWidth = function() return 700 end
headerFrame.LayoutColumns = function() end
headerFrame.columnHeaders = { EnumerateActive = function() return function() end end }
--- Clear a table as the client API does.
---@param values table Table to clear.
function wipe(values) for key in pairs(values) do values[key] = nil end end
profile.columnOrder = { "name", "quantity" }
local sortRefreshes = 0
local selectSortColumn = upvalue(buildFrame, "selectSortColumn")
upvalue(selectSortColumn, "renderRows", function() sortRefreshes = sortRefreshes + 1 end)
local buildDisplayRows = upvalue(renderRows, "buildDisplayRows")
local collectGroups = upvalue(buildDisplayRows, "collectGroups")
local statusKey = upvalue(collectGroups, "itemStatusKey")
upvalue(collectGroups, "getUpgradeTrack", function() return nil end)
upvalue(collectGroups, "getBindInfo", function() return "", nil, false, false end)
local items = {
  { name = "Protect", field = "protectedItems" },
  { name = "Bank", field = "bankItems" },
  { name = "Mail", field = "mailItems" },
  { name = "Auction", field = "auctionItems" },
  { name = "Junk B", field = "trashItems" },
  { name = "Unmarked" },
  { name = "Junk A", field = "trashItems" },
  { name = "Grey", quality = 0, field = "trashItems" },
}
local qualities = {}
for _, item in ipairs(items) do
  item.quality = item.quality or 1
  qualities[item.name] = item.quality
  if item.field then profile[item.field][statusKey(item.name, item.quality, 10, nil)] = {} end
end
-- Older overlapping marks must sort as the same flag displayed on the row.
profile.trashItems[statusKey("Protect", 1, 10, nil)] = {}
C_Container = {
  GetContainerNumSlots = function(bagID) return bagID == 0 and #items or 0 end,
  GetContainerItemInfo = function(_, slot)
    local item = items[slot]
    return { itemID = slot, itemName = item.name, hyperlink = item.name, quality = item.quality, stackCount = 1 }
  end,
}
C_Item = {
  GetItemInfo = function(link) return link, link, qualities[link], 10, nil, nil, nil, nil, "", nil, 1, 15 end,
  GetDetailedItemLevelInfo = function() return 10 end,
}
-- Exercise the mocked callbacks and sort data after garbage collection.
collectgarbage("collect")
--- Return displayed item names in their current order.
---@return string names Comma-separated row names.
local function displayedNames()
  local names = {}
  for _, group in ipairs(buildDisplayRows()) do names[#names + 1] = group.itemName end
  return table.concat(names, ",")
end
assert(not statusHeader.sortIcon.shown)
statusHeader.scripts.OnClick(statusHeader)
layoutHeaders()
assert(sortRefreshes == 1 and statusHeader.sortIcon.shown and statusHeader.sortIcon.rotation == math.pi / 2)
assert(displayedNames() == "Grey,Unmarked,Junk A,Junk B,Auction,Mail,Bank,Protect",
  "Ascending flag sort must put unflagged and grey items first, then flags in the requested order")
statusHeader.scripts.OnClick(statusHeader)
layoutHeaders()
assert(sortRefreshes == 2 and statusHeader.sortIcon.rotation == -math.pi / 2)
assert(displayedNames() == "Protect,Bank,Mail,Auction,Junk A,Junk B,Grey,Unmarked",
  "Descending flag sort must reverse the flag order while retaining name tie-breaks")
headerFrame.sortingFunction(headerFrame, 1)
layoutHeaders()
assert(sortRefreshes == 3 and not statusHeader.sortIcon.shown)
assert(displayedNames() == "Auction,Bank,Grey,Junk A,Junk B,Mail,Protect,Unmarked",
  "Selecting an ordinary column must retain its existing sorting behavior")
statusHeader.scripts.OnClick(statusHeader)
layoutHeaders()
assert(sortRefreshes == 4 and statusHeader.sortIcon.shown and statusHeader.sortIcon.rotation == math.pi / 2
  and displayedNames() == "Grey,Unmarked,Junk A,Junk B,Auction,Mail,Bank,Protect",
  "Returning to the flag column must start in ascending order")
profile.mailItems[statusKey("Unmarked", 1, 10, nil)] = {}
assert(displayedNames() == "Grey,Junk A,Junk B,Auction,Mail,Unmarked,Bank,Protect",
  "Changing a flag must update its position in the active sort")

-- Enable the module with a client-like event registry that rejects removed cursor events.
local registeredEvents = {}
--- Record events registered during module enable.
---@param event string Event name.
---@param handler string|nil Handler method name.
function module:RegisterEvent(event, handler)
  assert(event ~= "CURSOR_UPDATE", "CURSOR_UPDATE is not supported on current clients")
  assert(type(self[handler or event]) == "function", "Registered event must have a handler")
  registeredEvents[event] = handler or event
end
EventRegistry = { RegisterCallback = function() end }
upvalue(module.OnEnable, "installBagMenuOptions", function() end)
local realBuildFrame = upvalue(module.OnEnable, "buildFrame", function() end)
upvalue(module.OnEnable, "hookMerchantJunkButton", function() end)
upvalue(module.OnEnable, "updateMerchantJunkButton", function() end)
module:OnEnable()
assert(registeredEvents.CURSOR_CHANGED == "OnCursorChanged", "Enable must register the supported cursor event")

-- Exercise the real picker callbacks with native widgets replaced by lightweight frames.
local originalCreateFrame = CreateFrame
local picker, inset, scroll, scrollBar, newRecipient, initializeRow, popupOptions, popup, extraRegion, recipientLabel
local viewPadding
--- Emulate Forever's character pane.
---@return boolean forever Whether the Forever client is active.
function SlackHacks.isForever() return true end
--- Create mock picker frames.
---@param kind string Frame type.
---@param name string|nil Frame name.
---@param parent table|nil Parent frame.
---@param template string|nil Template name.
---@return table result Mock frame.
function CreateFrame(kind, name, parent, template)
  local result = originalCreateFrame(kind, name, parent, template)
  result.points = {}
  function result:GetText() return self.text or "" end
  function result:IsShown() return self.shown end
  function result:SetSize(width, height) self.width, self.height = width, height end
  function result:SetPoint(point, ...) self.points[point] = { ... } end
  function result:SetParent(parent) self.parent = parent end
  if name == "SlackHacksMailRecipientPicker" then
    assert(template == "DefaultPanelBaseTemplate")
    result.TitleContainer = { TitleText = widget() }
    function result:Hide()
      self.shown = false
      if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    picker = result
  elseif template == "InsetFrameTemplate" and parent == picker then
    result.Bg = widget()
    result.paneTextures = {}
    function result:CreateTexture()
      local texture = widget()
      self.paneTextures[#self.paneTextures + 1] = texture
      return texture
    end
    inset = result
  elseif template == "WowScrollBoxList" then
    scroll = result
    function result:SetDataProvider(data) self.elements = data end
  elseif template == "MinimalScrollBar" then
    scrollBar = result
  elseif template == "PaperDollTertiaryButtonTemplate" then
    result.label = widget()
    function result.label:GetObjectType() return "FontString" end
    function result:GetRegions() return self.label end
    newRecipient = result
  elseif template == "GearSetButtonTemplate" then
    result.text, result.icon, result.Check = widget(), widget(), widget()
    result.SpecRing, result.SpecIcon = widget(), widget()
    result.SelectedBar, result.HighlightBar = widget(), widget()
    result.DeleteButton, result.EditButton = widget(), widget()
    newRecipient = result
  elseif template == "InputBoxTemplate,AutoCompleteEditBoxTemplate" then
    assert(parent == extraRegion, "The recipient input must not be enclosed in a visible group box")
  end
  return result
end
--- Capture the list initializer.
---@return table view Mock list view.
function CreateScrollBoxListLinearView()
  return {
    SetElementExtent = function() end,
    SetPadding = function(_, ...) viewPadding = { ... } end,
    SetElementInitializer = function(_, _, initializer) initializeRow = initializer end,
  }
end
ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
ScrollBoxConstants = { RetainScrollPosition = 1 }
GREEN_FONT_COLOR = { r = 0, g = 1, b = 0 }
--- Supply a simple list data provider.
---@param elements table List elements.
---@return table elements List elements.
function CreateDataProvider(elements) return elements end
StaticPopupDialogs = {}
DELETE, CANCEL = "Delete", "Cancel"
local deleteDialog
--- Capture the delete confirmation payload.
---@return table dialog Mock confirmation.
function StaticPopup_Show(_, _, _, data) deleteDialog = data; return {} end
C_AutoComplete = { GetAutoCompleteResults = function() end }
AUTOCOMPLETE_LIST = { MAIL = { include = 7, exclude = 9 } }
local autoCompleteSource
--- Capture the recipient autocomplete source.
function AutoCompleteEditBox_SetAutoCompleteSource(_, source, include, exclude)
  autoCompleteSource = { source, include, exclude }
end
--- Capture the popup callbacks and construct the injected controls.
---@param parent table Picker frame.
---@param options table Popup configuration.
---@return table popup Mock popup.
function SlackHacks.CreateIconNamePopupFrame(parent, options)
  popupOptions = options
  popup = widget()
  extraRegion = widget()
  function extraRegion:CreateFontString(_, _, font)
    recipientLabel = widget()
    recipientLabel.font = font
    return recipientLabel
  end
  popup.extraControls = options.createExtraControls(extraRegion)
  --- Open the mock popup with optional existing values.
  ---@param name string|nil Existing nickname.
  ---@param icon number|string|nil Existing icon.
  function popup:Open(name, icon)
    self.openName, self.openIcon = name, icon
    self:Show()
  end
  return popup
end
profile.mailRecipients = {}
profile.mailAssignments = {}
profile.trashItems.pick = row.statusInfo
openPicker(button, "pick", row.statusInfo)
assert(picker.shown and profile.trashItems.pick and not profile.mailItems.pick)
assert(picker.TitleContainer.TitleText.text == "Mail Recipients")
assert(inset.Bg.atlas == "UI-Character-Info-Stat-BG" and #inset.paneTextures == 1)
local innerBorder = inset.paneTextures[1]
assert(innerBorder.atlas == "common-insideframe"
  and innerBorder.points.TOPLEFT[1] == inset and innerBorder.points.TOPLEFT[3] == 1
  and innerBorder.points.TOPLEFT[4] == 1 and innerBorder.points.BOTTOMRIGHT[3] == -4)
assert(picker.width == 245 and picker.height == 560
  and scroll.points.TOPLEFT[1] == 11 and scroll.points.TOPLEFT[2] == -29 and scroll.points.BOTTOMRIGHT[1] == -26)
assert(viewPadding[1] == 0 and viewPadding[2] == 0 and viewPadding[3] == 3
  and viewPadding[4] == 0 and viewPadding[5] == 2)
local scrollWidth = picker.width + scroll.points.BOTTOMRIGHT[1] - scroll.points.TOPLEFT[1]
assert(scrollWidth - viewPadding[3] >= 42 + 152, "Forever outfit cards must fit within the scroll area")
assert(scrollBar.points.TOPLEFT[3] == -5 and scrollBar.points.TOPLEFT[4] == -12)
assert(#scroll.elements == 0 and newRecipient.label.text == "New Mail Recipient")
assert(newRecipient.points.BOTTOM[1] == picker and newRecipient.points.BOTTOM[4] == 12)
assert(picker.height + scroll.points.TOPLEFT[2] - scroll.points.BOTTOMRIGHT[2] >= 10 * 44 + 9 * viewPadding[5] + 5,
  "The list must retain space for ten recipients")
assert(autoCompleteSource[1] == C_AutoComplete.GetAutoCompleteResults
  and autoCompleteSource[2] == 7 and autoCompleteSource[3] == 9)
assert(recipientLabel.text == "Send to Character Name:" and recipientLabel.font == "GameFontHighlightSmall")
local character = popup.extraControls.name
popup:Hide()
character:SetText("stale")
newRecipient.scripts.OnClick()
assert(popup.shown and character:GetText() == "", "The button must open a fresh recipient popup")
character:SetText(" ")
assert(not popupOptions.onConfirm("Alt", 123, popup.extraControls) and not next(profile.mailRecipients))
character:SetText("Example-Realm")
assert(popupOptions.onConfirm("Alt", 123, popup.extraControls))
assert(profile.mailRecipients[1].character == "Example-Realm" and #scroll.elements == 1)

--- Build a mock gear row and initialize it with the requested recipient.
---@param element table List element.
---@return table result Initialized row.
local function pickerRow(element)
  local result = widget()
  result.text, result.icon = widget(), widget()
  result.SpecRing, result.SpecIcon = widget(), widget()
  result.SelectedBar, result.HighlightBar = widget(), widget()
  result.EditButton, result.DeleteButton = widget(), widget()
  initializeRow(result, element)
  return result
end
local recipientRow = pickerRow(scroll.elements[1])
assert(recipientRow.text.text == "Alt" and recipientRow.characterText.text == "Example-Realm")
assert(recipientRow.text.points.TOPLEFT[3] == 55 and recipientRow.text.points.TOPRIGHT[3] == -55,
  "Forever recipient text must match the native icon margin and clear the edit button")
assert(recipientRow.characterText.font == "GameFontHighlightSmall" and recipientRow.characterText.textColor[1] == 1
  and recipientRow.characterText.textColor[2] == 1 and recipientRow.characterText.textColor[3] == 1)
assert(recipientRow.characterText.points.TOPLEFT[1] == recipientRow.text
  and recipientRow.characterText.points.TOPLEFT[2] == "BOTTOMLEFT" and not recipientRow.characterText.wordWrap)
assert(recipientRow.DeleteButton.points.BOTTOMRIGHT[1] == recipientRow
  and recipientRow.DeleteButton.points.BOTTOMRIGHT[2] == "BOTTOMRIGHT"
  and recipientRow.DeleteButton.points.BOTTOMRIGHT[3] == -21
  and recipientRow.DeleteButton.points.BOTTOMRIGHT[4] == 2)
assert(recipientRow.EditButton.shown and recipientRow.EditButton.points.RIGHT[1] == recipientRow.DeleteButton
  and recipientRow.EditButton.points.RIGHT[2] == "LEFT" and not recipientRow.EditButton.scripts.OnMouseDown)
local characterText = recipientRow.characterText
initializeRow(recipientRow, { id = 2, recipient = { nickname = "Second", character = "Other-Realm", icon = 456 } })
assert(recipientRow.characterText == characterText and characterText.text == "Other-Realm")
local otherProfile = { enabled = true }
SlackHacks.db.profile.listviewBag = otherProfile
recipientRow.scripts.OnClick()
assert(not otherProfile.mailItems.pick and not profile.mailItems.pick, "Profile changes must cancel the selection")
SlackHacks.db.profile.listviewBag = profile
openPicker(button, "pick", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
assert(profile.mailItems.pick and not profile.trashItems.pick and profile.mailAssignments.pick == 1)
openPicker(button, "another", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.EditButton.scripts.OnClick()
assert(popup.shown and popup.openName == "Alt" and popup.openIcon == 123 and character:GetText() == "Example-Realm")
local originalRecipient = profile.mailRecipients[1]
assert(popupOptions.onConfirm("Alt", 123, popup.extraControls))
assert(profile.mailRecipients[1] == originalRecipient and profile.mailAssignments.pick == 1)
recipientRow.EditButton.scripts.OnClick()
character:SetText(" ")
assert(not popupOptions.onConfirm("Changed", 456, popup.extraControls))
assert(originalRecipient.nickname == "Alt" and originalRecipient.character == "Example-Realm")
character:SetText("Updated-Realm")
assert(popupOptions.onConfirm("Changed", 456, popup.extraControls))
assert(profile.mailRecipients[1] == originalRecipient and originalRecipient.nickname == "Changed"
  and originalRecipient.character == "Updated-Realm" and originalRecipient.icon == 456
  and profile.mailAssignments.pick == 1 and profile.mailItems.pick)
recipientRow = pickerRow(scroll.elements[1])
assert(recipientRow.text.text == "Changed" and recipientRow.characterText.text == "Updated-Realm"
  and recipientRow.icon.texture == 456)
recipientRow.EditButton.scripts.OnClick()
SlackHacks.db.profile.listviewBag = otherProfile
character:SetText("Wrong-Realm")
assert(not popupOptions.onConfirm("Wrong", 999, popup.extraControls))
assert(originalRecipient.nickname == "Changed" and originalRecipient.character == "Updated-Realm" and not popup.shown)
SlackHacks.db.profile.listviewBag = profile
openPicker(button, "another", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.EditButton.scripts.OnClick()
character:SetText("Canceled")
popup:Hide()
assert(originalRecipient.character == "Updated-Realm", "Canceling an edit must not change the recipient")
recipientRow.EditButton.scripts.OnClick()
newRecipient.scripts.OnClick()
assert(rawget(popup, "openName") == nil and rawget(popup, "openIcon") == nil and character:GetText() == "")
character:SetText("New-Realm")
assert(popupOptions.onConfirm("New", 789, popup.extraControls))
assert(profile.mailRecipients[2].character == "New-Realm" and originalRecipient.character == "Updated-Realm")
recipientRow.EditButton.scripts.OnClick()
profile.mailRecipients[1] = { nickname = "Replacement", character = "Other", icon = 1 }
character:SetText("Stale-Realm")
assert(not popupOptions.onConfirm("Stale", 999, popup.extraControls))
assert(profile.mailRecipients[1].nickname == "Replacement" and profile.mailAssignments.pick == 1)
profile.mailRecipients[1] = originalRecipient
recipientRow.EditButton.scripts.OnClick()
recipientRow.DeleteButton.scripts.OnClick()
StaticPopupDialogs.SLACKHACKS_DELETE_MAIL_RECIPIENT.OnAccept(nil, deleteDialog)
assert(profile.mailItems.pick and not profile.mailAssignments.pick and not profile.mailRecipients[1] and not popup.shown)
profile.mailRecipients[2] = nil
upvalue(openPicker, "recipientPicker", false)
SlackHacks.isForever = function() return false end
openPicker(button, "retail", row.statusInfo)
assert(picker.shown and rawget(inset.Bg, "atlas") == nil and #inset.paneTextures == 0,
  "Retail must retain its native inset background")
assert(picker.width == 220 and picker.height == 560 and scroll.points.TOPLEFT[2] == -29
  and picker.width + scroll.points.BOTTOMRIGHT[1] - scroll.points.TOPLEFT[1] == 172
  and scrollBar.points.TOPLEFT[3] == 8 and scrollBar.points.TOPLEFT[4] == 0)
assert(picker.height + scroll.points.TOPLEFT[2] - scroll.points.BOTTOMRIGHT[2] >= 10 * 44 + 9 * viewPadding[5] + 5)
assert(#scroll.elements == 0 and newRecipient.text.text == "New Mail Recipient")
local retailRow = pickerRow({ id = 1, recipient = { nickname = "Retail", character = "Retail-Realm", icon = 123 } })
assert(retailRow.characterText.text == "Retail-Realm" and retailRow.text.points.TOPLEFT[3] == 44
  and retailRow.DeleteButton.points.BOTTOMRIGHT[1] == retailRow
  and retailRow.DeleteButton.points.BOTTOMRIGHT[3] == -2 and retailRow.DeleteButton.points.BOTTOMRIGHT[4] == 2)
popup:Hide()
newRecipient.scripts.OnClick()
assert(popup.shown, "Retail's new-recipient button must open the popup")

-- Exercise sending, batching, draft replacement, and native send-tab lifecycle.
local timers, globalHooks, bagSlots, reagentBagSlots, attachments = {}, {}, {}, {}, {}
local visibilityDelay, delayNextAttachment = {}, true
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
--- Run queued client callbacks until the mail operation settles.
local function drainMailTimers()
  local count = 0
  while #timers > 0 do
    count = count + 1
    assert(count < 300, "Mail preparation did not settle")
    table.remove(timers, 1)()
  end
end
--- Capture secure hooks used by the mail integration.
function hooksecurefunc(target, callback)
  assert(type(target) == "string")
  globalHooks[target] = callback
end
MailFrame, SendMailFrame = widget(), widget()
function MailFrame:IsShown() return self.shown end
function SendMailFrame:IsShown() return self.shown end
MailFrame.shown, SendMailFrame.shown = true, true
SendMailFrame.previousItem = ""
--- Construct an edit box for the mocked compose frame.
---@return table box Mock edit box.
local function mailEditBox()
  local box = widget()
  box.text = ""
  function box:GetText() return self.text end
  return box
end
SendMailNameEditBox, SendMailSubjectEditBox, SendMailBodyEditBox = mailEditBox(), mailEditBox(), mailEditBox()
SendMailMoney, SendMailCODButton, SendMailMailButton = widget(), widget(), widget()
SendMailMoney.copper = 0
SendMailCODButton.checked = false
function SendMailCODButton:GetChecked() return self.checked end
function SendMailMailButton:Disable() self.enabled = false end
function MoneyInputFrame_GetCopper(money) return money.copper end
function SendMailFrame_CanSend() SendMailMailButton.enabled = true end
function SendMailFrame_Reset()
  SendMailNameEditBox:SetText("")
  SendMailSubjectEditBox:SetText("")
  SendMailBodyEditBox:SetText("")
  SendMailMoney.copper, SendMailCODButton.checked, SendMailFrame.previousItem = 0, false, ""
end
ATTACHMENTS_MAX_SEND = 12
function HasSendMailItem(index)
  if visibilityDelay[index] and visibilityDelay[index] > 0 then
    visibilityDelay[index] = visibilityDelay[index] - 1
    return false
  end
  return attachments[index] ~= nil
end
function GetSendMailItem(index)
  local item = attachments[index]
  if item then return item.itemName, item.itemID, item.iconFileID, item.stackCount, item.quality end
end
function GetSendMailItemLink(index) return attachments[index] and attachments[index].hyperlink end
local moving
function C_Container.GetContainerNumSlots(bagID) return bagID == 0 and 20 or bagID == 5 and 1 or 0 end
function C_Container.GetContainerItemInfo(bagID, slot)
  return bagID == 0 and bagSlots[slot] or bagID == 5 and reagentBagSlots[slot] or nil
end
function C_Container.PickupContainerItem(bagID, slot)
  local slots = bagID == 5 and reagentBagSlots or bagSlots
  moving = slots[slot]
  slots[slot] = nil
  cursorType, cursorLink = "item", moving.hyperlink
end
function C_Item.GetItemInfo(link)
  if link == "unassigned-link" then
    return "Unrelated", link, 1, 10, nil, nil, nil, nil, "", nil, 1, 0, nil, 0, nil, nil, false
  end
  local reagent = link == "reagent-link"
  return reagent and "Herb" or "Sword", link, 1, 10, nil, nil, nil, nil,
    reagent and "" or "INVTYPE_CHEST", nil, 1, reagent and 7 or 4, nil, 0, nil, nil, reagent
end
function C_Item.GetDetailedItemLevelInfo() return 10 end
function ClickSendMailItemButton(index, clear)
  if clear then
    local item = attachments[index]
    for slot = 1, 20 do
      if not bagSlots[slot] then bagSlots[slot] = item; break end
    end
    attachments[index] = nil
    if not next(attachments) then
      if SendMailSubjectEditBox:GetText() == SendMailFrame.previousItem then SendMailSubjectEditBox:SetText("") end
      SendMailFrame.previousItem = ""
      SendMailCODButton.checked = false
    end
  else
    attachments[index] = moving
    if delayNextAttachment then visibilityDelay[index], delayNextAttachment = 2, false end
    cursorType, cursorLink, moving = nil, nil, nil
    if SendMailSubjectEditBox:GetText() == "" then
      SendMailFrame.previousItem = attachments[index].itemName
      SendMailSubjectEditBox:SetText(SendMailFrame.previousItem)
    end
  end
end
local mailDialog
function StaticPopup_Show(kind, _, _, data) mailDialog = { kind = kind, data = data }; return {} end
profile.showListviewBag = false
profile.mailRecipients = {
  [1] = { nickname = "Alt", character = "Alt-Realm", icon = 1 },
  [2] = { nickname = "Empty", character = "Empty-Realm", icon = 2 },
}
profile.mailItems, profile.mailAssignments = {}, {}
local swordKey, herbKey = statusKey("Sword", 1, 10, nil), statusKey("Herb", 1, 10, nil)
profile.mailItems[swordKey], profile.mailItems[herbKey] = {}, {}
profile.mailAssignments[swordKey], profile.mailAssignments[herbKey] = 1, 1
for slot = 1, 13 do
  local reagent = slot == 6 or slot == 7
  bagSlots[slot] = {
    itemID = reagent and 2 or 1, itemName = reagent and "Herb" or "Sword",
    hyperlink = reagent and "reagent-link" or "sword-link", quality = 1, stackCount = 1,
  }
end
local collectMail = upvalue(module.OnMailSendSuccess, "collectRecipientMailItems")
upvalue(collectMail, "getUpgradeTrack", function() return nil end)
profile.showReagentBagContents = false
reagentBagSlots[1] = {
  itemID = 2, itemName = "Herb", hyperlink = "reagent-link", quality = 1, stackCount = 1, isFiltered = true,
}
assert(#collectMail(profile)[1] == 14, "Mail preparation must include filtered reagent-bag items")
profile.bankItems[swordKey] = {}
assert(#collectMail(profile)[1] == 3, "Conflicting protected flags must prevent automatic mailing")
profile.bankItems[swordKey] = nil
reagentBagSlots[1] = nil
upvalue(openPicker, "recipientPicker", false)
upvalue(selectStatus, "openMailRecipientPicker", openPicker)
module:OnBagInteractionOpen("MAIL_SHOW")
SendMailFrame.hooks.OnShow()
assert(picker.shown and picker.parent == UIParent and picker.points.TOPLEFT[1] == MailFrame)
assert(#scroll.elements == 2 and scroll.elements[1].enabled and not scroll.elements[2].enabled)
local disabledRow = pickerRow(scroll.elements[2])
assert(not disabledRow.enabled and disabledRow.alpha < 1)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
assert(SendMailNameEditBox:GetText() == "Alt-Realm" and not SendMailMailButton.enabled)
table.remove(timers, 1)()
assert(bagSlots[2] and not HasSendMailItem(2), "The next stack must wait for attachment confirmation")
drainMailTimers()
assert(SendMailMailButton.enabled and SendMailSubjectEditBox:GetText() == "Equipment (10), Reagents (2)")
assert(HasSendMailItem(12) and bagSlots[13] and not bagSlots[1])
bagSlots[13].isLocked = true
module:OnMailInfoUpdate()
assert(scroll.elements[1].enabled, "A temporarily locked item must not make its recipient look finished")
globalHooks.SendMail("Alt-Realm")
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
StaticPopupDialogs.SLACKHACKS_REPLACE_MAIL_DRAFT.OnAccept(nil, mailDialog.data)
assert(HasSendMailItem(12) and SendMailNameEditBox:GetText() == "Alt-Realm",
  "A pending send must not be replaced while awaiting confirmation")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
table.remove(timers, 1)()
assert(#timers > 0 and not HasSendMailItem(1), "The next batch must wait for locked items")
bagSlots[13].isLocked = false
drainMailTimers()
assert(SendMailNameEditBox:GetText() == "Alt-Realm" and SendMailSubjectEditBox:GetText() == "Sword")
assert(HasSendMailItem(1) and not bagSlots[13])
assert(not scroll.elements[1].enabled, "Recipients without remaining bag items must be disabled")
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(SendMailNameEditBox:GetText() == "" and not scroll.elements[1].enabled)

bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
SendMailNameEditBox:SetText("Someone")
SendMailSubjectEditBox:SetText("Existing")
SendMailBodyEditBox:SetText("Keep until confirmed")
SendMailMoney.copper = 42
attachments[1] = { itemID = 3, itemName = "Unrelated", hyperlink = "unassigned-link", quality = 1, stackCount = 2 }
recipientRow.scripts.OnClick()
assert(mailDialog.kind == "SLACKHACKS_REPLACE_MAIL_DRAFT" and HasSendMailItem(1))
SendMailBodyEditBox:SetText("Changed while confirming")
StaticPopupDialogs.SLACKHACKS_REPLACE_MAIL_DRAFT.OnAccept(nil, mailDialog.data)
assert(SendMailNameEditBox:GetText() == "Someone" and HasSendMailItem(1) and bagSlots[1])
recipientRow.scripts.OnClick()
StaticPopupDialogs.SLACKHACKS_REPLACE_MAIL_DRAFT.OnAccept(nil, mailDialog.data)
drainMailTimers()
assert(SendMailNameEditBox:GetText() == "Alt-Realm" and SendMailSubjectEditBox:GetText() == "Sword"
  and SendMailBodyEditBox:GetText() == "" and SendMailMoney.copper == 0 and attachments[1].itemID == 1)
assert(bagSlots[2] and bagSlots[2].itemID == 3, "Replacing a draft must return its previous attachment")

local startMail = upvalue(module.OnMailSendSuccess, "startRecipientMail")
local advanceMail = upvalue(startMail, "advanceMailJob")
local formatSubject = upvalue(advanceMail, "mailSubject")
assert(formatSubject({ { name = "Single item", count = 20, category = "reagents" } }) == "Single item")
assert(formatSubject({
  { name = "Sword", count = 1, category = "equipment" },
  { name = "Herb", count = 5, category = "reagents" },
}) == "Equipment (1), Reagents (5)")
local abbreviated = formatSubject({
  { count = 1, category = "equipment" }, { count = 1, category = "consumables" },
  { count = 1, category = "professionGoods" }, { count = 1, category = "junk" },
  { count = 1, category = "quest" }, { count = 1, category = "reagents" },
  { count = 1, category = "special" }, { count = 1, category = "other" },
})
assert(#abbreviated <= 64 and abbreviated:find("Equip", 1, true) and abbreviated:find("Reag", 1, true))

attachments = {}
SendMailFrame_Reset()
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
bagSlots[3] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
profile.mailAssignments[swordKey] = nil
drainMailTimers()
assert(HasSendMailItem(1) and not HasSendMailItem(2) and bagSlots[3] and SendMailMailButton.enabled,
  "Changing a flag during preparation must stop before attaching another stack")
profile.mailAssignments[swordKey] = 1
SendMailFrame.hooks.OnHide()
assert(not picker.shown, "Closing the send tab must hide the mail recipient window")

-- A secure mail hook must not disable Blizzard's send button after the module is disabled.
upvalue(startMail, "mailJob", {})
module.IsEnabled = function() return false end
SendMailMailButton.enabled = true
globalHooks.SendMailFrame_CanSend()
assert(SendMailMailButton.enabled, "A disabled module must not block sending mail")
upvalue(startMail, "mailJob", false)
module.IsEnabled = function() return true end

-- Build the actual top controls and verify their click and tooltip behavior.
local constructed = {}
CreateFrame = function(...)
  local result = originalCreateFrame(...)
  constructed[#constructed + 1] = result
  return result
end
UISpecialFrames, ITEM_SEARCHBAR_LIST = {}, {}
tinsert = table.insert
function UnitName() return "Player" end
GameTooltip_Hide = function() end
upvalue(realBuildFrame, "frame", false)
realBuildFrame()
local content = upvalue(realBuildFrame, "content")
local openBags = content.openBagsButton
assert(openBags.normalTexture == "Interface\\Buttons\\Button-Backpack-Up"
  and openBags.pushedTexture == "Interface\\Buttons\\Button-Backpack-Down")
openBags.scripts.OnEnter(openBags)
assert(GameTooltip.text == "Open Bags (Temporarily)"
  and GameTooltip.lines[1] == "Show the Blizzard default bag temporarily. You can toggle it permanently in the top-left icon context menu.")
local opened = false
upvalue(openBags.scripts.OnClick, "openDefaultBagsTemporarily", function() opened = true end)
openBags.scripts.OnClick()
assert(opened, "The backpack button must temporarily open Blizzard's bags")
opened = false
profile.enabled = false
openBags.scripts.OnClick()
assert(not opened, "The backpack button must not act when the module is disabled")
profile.enabled = true
local menuHandler = upvalue(realBuildFrame, "openBagSettingsMenu")
local cog = content.settingsButton
assert(cog.normalAtlas == "common-dropdown-a-button-settings-shadowless"
  and cog.pushedAtlas == "common-dropdown-a-button-settings-pressed-shadowless"
  and cog.highlightAtlas == "common-dropdown-a-button-settings-hover-shadowless")
assert(openBags.points.RIGHT[1] == cog and openBags.points.RIGHT[2] == "LEFT"
  and openBags.points.RIGHT[3] < 0, "The settings cog must sit to the right of the backpack button")
assert(cog.scripts.OnClick == menuHandler and cog.clicks[1] == "LeftButtonUp"
  and cog.clicks[2] == "RightButtonUp", "The cog must open the portrait's settings menu")
cog.scripts.OnEnter(cog)
assert(GameTooltip.text == "Bag Settings")
local portraitButton
for _, frame in ipairs(constructed) do
  if frame ~= cog and frame.scripts.OnClick == menuHandler then portraitButton = frame end
end
assert(portraitButton and portraitButton.clicks[1] == "LeftButtonUp"
  and portraitButton.clicks[2] == "RightButtonUp", "The portrait must open its context menu on either click")

-- Exercise the constructed footer with reagent bags, changing counts, and wide currency strips.
MenuUtil = { CreateContextMenu = function() end }
C_AddOns = { LoadAddOn = function() end }
--- Accept the footer's maximum money-frame width.
function MoneyFrame_SetMaxDisplayWidth() end
--- Supply a balance for the footer.
---@return number money Balance in copper.
function GetMoney() return 0 end
createFooter()
local footer = upvalue(createFooter, "footer")
footer:SetWidth(684)
footer.filtersButton.legacy = false
footer.tokenFrame.Update = function() end
footer.crestFrame.Update = function() end
footer.tokenFrame.Tokens, footer.crestFrame.Tokens = {}, {}
footer.tokenFrame.ShouldShow = function() return false end
footer.crestFrame.ShouldShow = function() return false end
--- Emulate the native money-frame width reset.
function MoneyFrame_Update() footer.moneyFrame:SetWidth(100) end
local sizes = { [0] = 16, 16, 16, 16, 16, 20 }
local free = { [0] = 10, 10, 10, 10, 10, 6 }
C_Container.GetContainerNumSlots = function(bagID) return sizes[bagID] end
C_Container.GetContainerNumFreeSlots = function(bagID) return free[bagID], 0 end
local updateFooter = upvalue(module.Refresh, "updateFooter")
updateFooter()
assert(footer.slotCount.text == "44 / 100 slots used", "Slot counts must include reagent bags")
assert(footer.slotCount.points.BOTTOMLEFT[1] == footer and footer.freeSlotsButton.points.LEFT[1] == footer.slotCount
  and footer.freeSlotsButton.text == "Free-Up Slots" and not footer.freeSlotsButton.scripts.OnClick,
  "The inactive free-slots button must sit to the right of the footer counter")
assert(footer.height == 20 and footer.balances.points.BOTTOMRIGHT[4] == 0)

free = { [0] = 3, 0, 0, 0, 0, 0 }
upvalue(module.Refresh, "renderRows", function() end)
upvalue(module.Refresh, "updateMerchantJunkButton", function() end)
upvalue(realBuildFrame, "frame"):Show()
module:Refresh()
assert(footer.slotCount.text == "|cffff404097 / 100|r slots used",
  "A bag refresh must highlight the count when three slots remain")
free[0] = 4
module:Refresh()
assert(footer.slotCount.text == "96 / 100 slots used", "Four free slots must not be highlighted")
free[0] = 0
updateFooter()
assert(footer.slotCount.text == "|cffff4040100 / 100|r slots used", "A full bag must remain highlighted")
SlackHacks.isRetailOrForever = function() return false end
updateFooter()
assert(footer.slotCount.text == "|cffff404080 / 80|r slots used", "Clients without reagent bags must exclude them")
SlackHacks.isRetailOrForever = function() return true end

--- Create fixed-width currency tokens for the footer layout test.
---@param count number Number of tokens.
---@return table tokens Mock tokens.
local function currencyTokens(count)
  local tokens = {}
  for index = 1, count do tokens[index] = { GetWidth = function() return 50 end } end
  return tokens
end
footer.tokenFrame.Tokens, footer.crestFrame.Tokens = currencyTokens(3), currencyTokens(5)
footer.tokenFrame.ShouldShow = function() return true end
footer.crestFrame.ShouldShow = function() return true end
updateFooter()
local scrollFrame = upvalue(realBuildFrame, "scrollFrame")
assert(footer.height == 40 and footer.balances.points.BOTTOMRIGHT[4] == 20
  and footer.currencyButton.points.BOTTOMRIGHT[4] == 20
  and content.listInset.points.BOTTOMRIGHT[4] == 50 and scrollFrame.points.BOTTOMRIGHT[4] == 54,
  "Wide currency strips must move above the controls without overlapping the item list")
footer.tokenFrame.ShouldShow = function() return false end
footer.crestFrame.ShouldShow = function() return false end
updateFooter()
assert(footer.height == 20 and footer.balances.points.BOTTOMRIGHT[4] == 0
  and content.listInset.points.BOTTOMRIGHT[4] == 30 and scrollFrame.points.BOTTOMRIGHT[4] == 34,
  "The footer and item list must return to one row when currencies fit")

upvalue(startMail, "mailJob", {})
module.IsEnabled = function() return false end
EventRegistry.UnregisterCallback = function() end
module.UpdateListViewBindings = function() end
upvalue(module.OnDisable, "showDefaultBags", function() end)
upvalue(module.OnDisable, "merchantOpen", false)
SendMailMailButton.enabled = false
module:OnDisable()
assert(not upvalue(startMail, "mailJob") and SendMailMailButton.enabled,
  "Disabling the module must stop mail preparation and restore Blizzard's send button")
print("Listview bag status tests passed")
