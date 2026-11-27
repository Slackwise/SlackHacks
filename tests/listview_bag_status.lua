-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_status.lua

local profile = { enabled = true, protectedItems = {}, trashItems = {} }
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 } }
UIParent = {}
C_AuctionHouse = {}
--- Allow auction eligibility checks in interaction tests.
---@return boolean valid Whether the item can be auctioned.
function C_AuctionHouse.IsSellItemValid() return true end
ItemLocation = {}
--- Supply a valid mock item location.
---@return table location Item location.
function ItemLocation:CreateFromBagAndSlot()
  return {
    ---@return boolean valid Whether the location is valid.
    IsValid = function() return true end,
  }
end

--- Supply the bag module.
---@return table module
function SlackHacks:NewModule() return { IsEnabled = function() return true end } end
--- Include the modern reagent bag.
---@return boolean modern
function SlackHacks.isRetailOrForever() return true end
--- Emulate Retail availability for client-specific footer behavior.
---@return boolean retail Whether the Retail client is active.
function SlackHacks.isRetail() return false end
--- Emulate Retail until client-specific tests override it.
---@return boolean forever Whether the Forever client is active.
function SlackHacks.isForever() return false end

--- Construct a minimal UI object that records scripts, text, textures, and visibility.
---@return table widget
local function widget()
  local object = { scripts = {}, hooks = {}, points = {}, shown = true, fontSize = 10 }
  --- Accept irrelevant frame setup.
  local function noop() end
  setmetatable(object, { __index = function(_, key)
    if key ~= "blockedAction" and key ~= "characterText" and key ~= "editingRecipient" and key ~= "mailMode"
      and key ~= "legacy" and key ~= "statusContext" then
      return noop
    end
  end })
  function object:SetScript(event, handler) self.scripts[event] = handler end
  function object:HookScript(event, handler) self.hooks[event] = handler end
  function object:RegisterEvent(event) self.events = rawget(self, "events") or {}; self.events[event] = true end
  function object:UnregisterAllEvents() self.events = {} end
  function object:GetFrameLevel() return 0 end
  function object:GetNormalTexture() return rawget(self, "normalAtlasTexture") end
  function object:GetPushedTexture() return rawget(self, "pushedAtlasTexture") end
  function object:GetHighlightTexture() return rawget(self, "highlightAtlasTexture") end
  --- Return the mock disabled texture.
  ---@return table|nil texture Disabled texture.
  function object:GetDisabledTexture() return rawget(self, "disabledTexture") end
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
  function object:SetAllPoints(relative) self.allPoints = relative end
  function object:SetPoint(point, ...) self.points[point] = { ... } end
  function object:SetHeight(height) self.height = height end
  function object:SetSize(width, height) self.width, self.height = width, height end
  function object:SetWidth(width) self.width = width end
  function object:GetWidth() return self.width or 0 end
  function object:GetFont() return "mock-font", self.fontSize or 10, "" end
  function object:SetFont(_, size) self.fontSize = size end
  function object:SetScale(scale) self.scale = scale end
  function object:GetStringWidth()
    return #(self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * 6 * (self.fontSize or 10) / 10
  end
  function object:SetTextColor(...) self.textColor = { ... } end
  function object:SetJustifyH(justify) self.justifyH = justify end
  function object:SetWordWrap(enabled) self.wordWrap = enabled end
  function object:SetEnabled(enabled) self.enabled = enabled end
  function object:SetAlpha(alpha) self.alpha = alpha end
  --- Record a solid texture's color.
  ---@param ... number Color components.
  function object:SetColorTexture(...) self.colorTexture = { ... } end
  function object:SetTexture(texture) self.texture = texture; self.atlas = nil end
  function object:SetNormalTexture(texture) self.normalTexture = texture end
  --- Record the disabled texture.
  ---@param texture string Texture path.
  function object:SetDisabledTexture(texture) self.disabledTexture = widget(); self.disabledTexture.texture = texture end
  function object:SetPushedTexture(texture) self.pushedTexture = texture end
  function object:SetNormalAtlas(atlas) self.normalAtlas = atlas; self.normalAtlasTexture = widget() end
  function object:SetPushedAtlas(atlas) self.pushedAtlas = atlas; self.pushedAtlasTexture = widget() end
  function object:SetHighlightAtlas(atlas) self.highlightAtlas = atlas; self.highlightAtlasTexture = widget() end
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
  if template == "UICheckButtonTemplate" then frame.text = widget() end
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
--- Clear a tooltip font restoration table.
---@param values table Table to clear.
function wipe(values) for key in pairs(values) do values[key] = nil end end
--- Emulate the shared tooltip's reusable font strings.
local function ensureTooltipFonts()
  local line = GameTooltip:NumLines()
  for _, side in ipairs({ "Left", "Right" }) do
    local name = "GameTooltipText" .. side .. line
    _G[name] = _G[name] or widget()
  end
end
function GameTooltip:NumLines() return 1 + #self.lineOrder end
function GameTooltip:SetText(text)
  if self.hooks.OnTooltipCleared then self.hooks.OnTooltipCleared(self) end
  self.text = text; self.lines = {}; self.lineColors = {}; self.doubleLines = {}; self.lineOrder = {}
  ensureTooltipFonts()
end
function GameTooltip:AddLine(text, r, g, b)
  self.lines[#self.lines + 1] = text; self.lineOrder[#self.lineOrder + 1] = text
  self.lineColors[#self.lineColors + 1] = { r, g, b }
  ensureTooltipFonts()
end
--- Record left and right columns of a tooltip line.
---@param left string Left-column text.
---@param right string Right-column text.
function GameTooltip:AddDoubleLine(left, right)
  self.doubleLines[#self.doubleLines + 1] = { left, right }
  self.lineOrder[#self.lineOrder + 1] = left
  ensureTooltipFonts()
end

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
local validateStatus = upvalue(setStatus, "validateStatusContext", function() return true end)
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
assert(row.upgradeText.fontSize == 8, "Upgrade text must use a smaller font than the normal 10-point row text")
assert(row.vendorText.justifyH == "RIGHT" and row.auctionText.justifyH == "RIGHT",
  "Vendor and auction prices must be right aligned")
row.statusKey = "item"
row.statusInfo = { name = "Item", quality = 1 }
local button = row.statusBtn
assert(button.clicks[1] == "LeftButtonUp" and button.clicks[2] == "RightButtonUp")
updateStatusButton(button, getStatus("item"))
assert(button.text.shown and button.text.text == "..." and not button.icon.shown)
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Click to Flag:" and #GameTooltip.lines == 1
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
  assert(GameTooltip.lines[#GameTooltip.lines] == "Left-click to choose flag.\nRight-click cannot change this flag.")
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
assert(GameTooltip.text == "Flagged for: Bank" and #GameTooltip.lines == 1
  and GameTooltip.lines[1] == "Left-click to choose flag.\nRight-click cannot change this flag.")
assert(GameTooltip.lineColors[1][1] == 1 and GameTooltip.lineColors[1][2] == 1
  and GameTooltip.lineColors[1][3] == 1, "Other flag instructions should remain white")
button.scripts.OnClick(button, "RightButton")
assert(not profile.trashItems.item and profile.bankItems.item and protected("item"))
chooseRecipient = false
entries[6].selectStatus()
assert(profile.bankItems.item and not profile.mailItems.item, "Canceling recipient selection must preserve the flag")
chooseRecipient = true
entries[6].selectStatus()
assert(profile.mailItems.item and not profile.trashItems.item)
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flagged for: Mail" and GameTooltip.lines[1] == "Mail Queue:"
  and GameTooltip.lines[2] == "  - Bank Alt (default)")
assert(_G.GameTooltipTextLeft3.fontSize == 8
  and GameTooltip.lineColors[3][1] == 0.6 and GameTooltip.lineColors[3][2] == 0.6
  and GameTooltip.lineColors[3][3] == 0.6)
GameTooltip:SetText("Unrelated tooltip")
assert(_G.GameTooltipTextLeft3.fontSize == 10,
  "Mail tooltip fonts must be restored before another tooltip uses them")
deleteRecipient(profile, 1)
assert(profile.mailItems.item and not profile.mailAssignments.item, "Deleting a recipient must leave Mail unassigned")
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flagged for: Mail" and GameTooltip.lines[2] == "  None")
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
assert(GameTooltip.text == "Flagged for: Protect" and GameTooltip.lines[2]:find("ignore protection", 1, true))
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
do
  local computeLayout = upvalue(layoutHeaders, "computeLayout")
  local originalOrder, originalView = profile.columnOrder, profile.view
  local originalForever, originalRetail = SlackHacks.isForever, SlackHacks.isRetail
  profile.columnOrder = { "quantity", "name", "ilvl", "armorType", "armorSlot", "bind" }
  for _, view in ipairs({ "default", "gear", "selling" }) do
    profile.view = view
    SlackHacks.isForever = function() return false end
    SlackHacks.isRetail = function() return false end
    computeLayout()
    local otherLayout = upvalue(computeLayout, "columnLayout")
    SlackHacks.isRetail = function() return true end
    computeLayout()
    local retailLayout = upvalue(computeLayout, "columnLayout")
    SlackHacks.isRetail = function() return false end
    SlackHacks.isForever = function() return true end
    computeLayout()
    local foreverLayout = upvalue(computeLayout, "columnLayout")
    if view == "default" then
      assert(retailLayout.ilvl.width == otherLayout.ilvl.width and retailLayout.name.width == otherLayout.name.width
        and foreverLayout.ilvl.width == otherLayout.ilvl.width / 2
        and foreverLayout.name.width == otherLayout.name.width + otherLayout.ilvl.width / 2)
    elseif view == "gear" then
      assert(retailLayout.ilvl.width == 42 and retailLayout.upgrade.width == otherLayout.upgrade.width + 18
        and retailLayout.name.width == otherLayout.name.width
        and foreverLayout.ilvl.width == otherLayout.ilvl.width / 2
        and foreverLayout.upgrade.width == otherLayout.upgrade.width + otherLayout.ilvl.width / 2
        and foreverLayout.name.width == otherLayout.name.width)
    else
      assert(retailLayout.vendor.width == otherLayout.vendor.width and retailLayout.name.width == otherLayout.name.width
        and foreverLayout.vendor.width == otherLayout.vendor.width + 30
        and foreverLayout.name.width == otherLayout.name.width - 30
        and foreverLayout.auction.width == otherLayout.auction.width)
    end
  end
  profile.columnOrder, profile.view, SlackHacks.isForever, SlackHacks.isRetail =
    originalOrder, originalView, originalForever, originalRetail
end
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
local pickerStackSize = 1
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
  GetItemInfo = function(link) return link, link, qualities[link], 10, nil, nil, nil, pickerStackSize, "", nil, 1, 15 end,
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

-- Exercise real selling-row and tooltip rendering without the removed coin-texture API.
do
  local saleRow = createRow(2)
  local originalRows = upvalue(renderRows, "buildDisplayRows", function()
    return { { itemName = "Sale item", statusKey = "sale", statusInfo = {}, quality = 1,
      count = 1, sellPrice = 1717, entries = { { bagID = 0, slot = 1 } },
      auction = { minimum = 3000, average = 4000, source = "Auction House" } } }
  end)
  local originalAcquire = upvalue(renderRows, "acquireRow", function() return saleRow end)
  local originalLayout = upvalue(renderRows, "layoutHeaders", function() end)
  local originalPosition = upvalue(renderRows, "positionRowCells", function() end)
  local bagFrame = upvalue(renderRows, "frame")
  local scrollFrame = upvalue(renderRows, "scrollFrame")
  local wasShown, previousView = bagFrame.shown, profile.view
  local originalGetHeight, originalColors = scrollFrame.GetHeight, ITEM_QUALITY_COLORS
  local originalIsOwned = GameTooltip.IsOwned
  function scrollFrame:GetHeight() return 100 end
  function GameTooltip:IsOwned(owner) return owner == saleRow end
  --- Format a price using the supported client API.
  ---@param copper number Price in copper.
  ---@param showIcons boolean Whether coin icons are requested.
  ---@return string price Formatted price.
  function GetMoneyString(copper, showIcons)
    assert(showIcons, "Prices must retain coin icons")
    return "coins:" .. copper
  end
  ITEM_QUALITY_COLORS = {}
  profile.view = "selling"
  bagFrame:Show()
  renderRows()
  assert(saleRow.vendorText.text == "coins:1717" and saleRow.auctionText.text == "coins:3000",
    "Selling rows must render vendor and auction prices using the supported money formatter")
  GameTooltip:SetText("Sale item")
  saleRow.hooks.OnEnter(saleRow)
  assert(GameTooltip.doubleLines[1][2] == "coins:3000" and GameTooltip.doubleLines[2][2] == "coins:4000",
    "Auction tooltip prices must use the same supported formatter")
  upvalue(renderRows, "buildDisplayRows", originalRows)
  upvalue(renderRows, "acquireRow", originalAcquire)
  upvalue(renderRows, "layoutHeaders", originalLayout)
  upvalue(renderRows, "positionRowCells", originalPosition)
  scrollFrame.GetHeight, ITEM_QUALITY_COLORS, GameTooltip.IsOwned = originalGetHeight, originalColors, originalIsOwned
  profile.view, bagFrame.shown, GetMoneyString = previousView, wasShown, nil
end

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
assert(registeredEvents.UNIT_INVENTORY_CHANGED == "OnSupplyInventoryChanged"
  and registeredEvents.UPDATE_INVENTORY_DURABILITY == "RefreshFooter",
  "Equipped ammunition and thrown durability must refresh")
local beginAuctionMode = upvalue(module.OnEnable, "beginAuctionMode")
AuctionHouseFrame = {}
--- Simulate enabling the module while the auction house is already open.
---@return boolean shown Whether the auction house is open.
function AuctionHouseFrame:IsShown() return true end
local openAuctionHouseFrame = AuctionHouseFrame
upvalue(beginAuctionMode, "ahMode", false)
module:OnEnable()
assert(upvalue(beginAuctionMode, "ahMode"), "Enabling the module at an open auction house must turn on AH Mode")
AuctionHouseFrame = nil
module:OnBagInteractionClosed("AUCTION_HOUSE_CLOSED")
assert(not upvalue(beginAuctionMode, "ahMode"), "Closing must restore the prior AH Mode choice")
AuctionHouseFrame = openAuctionHouseFrame
module:OnEnable()
local previousShowDefaultBags = upvalue(module.OnDisable, "showDefaultBags", function() end)
local previousUpdateBindings = module.UpdateListViewBindings
module.UpdateListViewBindings = function() end
EventRegistry.UnregisterCallback = function() end
module:OnDisable()
assert(not upvalue(beginAuctionMode, "ahMode") and not upvalue(module.OnDisable, "temporaryView"),
  "Disabling during an auction visit must restore AH Mode and clear the temporary view")
AuctionHouseFrame = nil
module:OnEnable()
assert(not upvalue(beginAuctionMode, "ahMode"), "Re-enabling after the auction closes must retain the previous mode")
upvalue(module.OnDisable, "showDefaultBags", previousShowDefaultBags)
module.UpdateListViewBindings = previousUpdateBindings
do
  local refreshes = 0
  local original = upvalue(module.OnSupplyInventoryChanged, "refreshFooter", function() refreshes = refreshes + 1 end)
  module:OnSupplyInventoryChanged("UNIT_INVENTORY_CHANGED", "target")
  module:OnSupplyInventoryChanged("UNIT_INVENTORY_CHANGED", "player")
  assert(refreshes == 1, "Only the player's inventory changes should refresh supplies")
  upvalue(module.OnSupplyInventoryChanged, "refreshFooter", original)
end

-- Exercise the real picker callbacks with native widgets replaced by lightweight frames.
local originalCreateFrame = CreateFrame
local picker, inset, scroll, scrollBar, newRecipient, initializeRow, popupOptions, popup, extraRegion, recipientLabel
local amountPrompt, amountButtons, amountLabels
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
  if name == "SlackHacksMailAmountPrompt" then
    amountPrompt, amountButtons, amountLabels = result, {}, {}
    result.Inset, result.Bg = widget(), widget()
    function result:CreateFontString()
      local label = widget()
      amountLabels[#amountLabels + 1] = label
      return label
    end
  elseif parent == amountPrompt and template == "SharedButtonSmallTemplate" then
    amountButtons[#amountButtons + 1] = result
  elseif name == "SlackHacksMailRecipientPicker" then
    assert(template == (SlackHacks.isForever() and "DefaultPanelBaseTemplate" or "DefaultPanelTemplate"))
    result.template = template
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
    result.BgTop, result.BgMiddle, result.BgBottom, result.Stripe = widget(), widget(), widget(), widget()
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
row.statusInfo.link = "pick-link"
profile.trashItems.pick = row.statusInfo
openPicker(button, "pick", row.statusInfo)
assert(picker.shown and profile.trashItems.pick and not profile.mailItems.pick)
assert(picker.TitleContainer.TitleText.text == "Mail Recipients")
assert(inset.Bg.atlas == "UI-Character-Info-Stat-BG" and #inset.paneTextures == 1)
local innerBorder = inset.paneTextures[1]
assert(innerBorder.atlas == "common-insideframe"
  and innerBorder.points.TOPLEFT[1] == inset and innerBorder.points.TOPLEFT[3] == 1
  and innerBorder.points.TOPLEFT[4] == 1 and innerBorder.points.BOTTOMRIGHT[3] == -4)
assert(picker.width == 245 and picker.height == 459
  and scroll.points.TOPLEFT[1] == 11 and scroll.points.TOPLEFT[2] == -29 and scroll.points.BOTTOMRIGHT[1] == -26)
assert(viewPadding[1] == 0 and viewPadding[2] == 0 and viewPadding[3] == 3
  and viewPadding[4] == 0 and viewPadding[5] == 2)
local scrollWidth = picker.width + scroll.points.BOTTOMRIGHT[1] - scroll.points.TOPLEFT[1]
assert(scrollWidth - viewPadding[3] >= 42 + 152, "Forever outfit cards must fit within the scroll area")
assert(scrollBar.points.TOPLEFT[3] == -5 and scrollBar.points.TOPLEFT[4] == -12)
assert(#scroll.elements == 0 and newRecipient.label.text == "New Mail Recipient")
assert(newRecipient.points.BOTTOM[1] == picker and newRecipient.points.BOTTOM[4] == 12)
local scrollHeight = picker.height + scroll.points.TOPLEFT[2] - scroll.points.BOTTOMRIGHT[2]
assert(scrollHeight >= 8 * 44 + 7 * viewPadding[5] and scrollHeight < 9 * 44 + 8 * viewPadding[5],
  "Forever must fit eight complete recipients, but not nine")
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
  result.BgTop, result.BgMiddle, result.BgBottom, result.Stripe = widget(), widget(), widget(), widget()
  result.EditButton, result.DeleteButton = widget(), widget()
  element.index = element.index or 1
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
initializeRow(recipientRow, { id = 2, index = 2, recipient = { nickname = "Second", character = "Other-Realm", icon = 456 } })
assert(recipientRow.characterText == characterText and characterText.text == "Other-Realm")
local otherProfile = { enabled = true }
SlackHacks.db.profile.listviewBag = otherProfile
recipientRow.scripts.OnClick()
assert(not otherProfile.mailItems.pick and not profile.mailItems.pick, "Profile changes must cancel the selection")
SlackHacks.db.profile.listviewBag = profile
openPicker(button, "pick", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
assert(amountPrompt.shown and not profile.mailItems.pick,
  "Non-stackable items must also show the amount prompt")
assert(amountPrompt.Bg.texture == "Interface\\MailFrame\\UI-MailFrameBG"
  and amountPrompt.Bg.texCoord[2] == 320 / 512 and amountPrompt.Bg.texCoord[4] == 224 / 512,
  "The mail prompt must use the cropped inbox background")
amountButtons[2].scripts.OnClick()
assert(profile.mailItems.pick and not profile.trashItems.pick and profile.mailAssignments.pick == 1
  and not profile.mailQueues.pick, "Remember must assign a default recipient")

pickerStackSize = 20
profile.trashItems.stack = row.statusInfo
openPicker(button, "stack", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
assert(amountPrompt.shown and profile.trashItems.stack and not profile.mailItems.stack)
assert(amountLabels[2].text == "Send only a specific amount one time?"
  and amountLabels[3].text == "Or, send all and remember this recipient?"
  and amountButtons[1].text == "Send Once" and amountButtons[2].text == "Remember")
amountPrompt.amount:SetText("0")
amountButtons[1].scripts.OnClick()
assert(amountPrompt.shown and not profile.mailItems.stack, "Invalid amounts must not change the flag")
amountPrompt:Hide()
assert(profile.trashItems.stack and not profile.mailItems.stack, "Canceling must preserve the previous flag")
recipientRow.scripts.OnClick()
amountPrompt.amount:SetText("25")
amountButtons[1].scripts.OnClick()
assert(profile.mailItems.stack and not profile.mailAssignments.stack
  and profile.mailQueues.stack[1].recipient == 1 and profile.mailQueues.stack[1].remaining == 25)
row.statusKey = "stack"
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Flagged for: Mail" and GameTooltip.lines[1] == "Mail Queue:"
  and GameTooltip.lines[2] == "  - Alt (25 pending)"
  and GameTooltip.lines[3] == "Left-click to choose flag.\nRight-click cannot change this flag.")
profile.mailQueues.stack[1].remaining = 1
profile.mailAssignments.stack = 999
button.scripts.OnEnter(button)
assert(GameTooltip.lines[2] == "  - Alt (1 pending)" and GameTooltip.lines[3] == "  - Unavailable (default)")
profile.mailQueues.stack[1].remaining, profile.mailAssignments.stack = 25, nil
row.statusKey = "item"
profile.mailRecipients[2] = { nickname = "Other", character = "Other-Realm", icon = 1 }
openPicker(button, "stack", row.statusInfo)
recipientRow = pickerRow({ id = 2, recipient = profile.mailRecipients[2], enabled = true })
recipientRow.scripts.OnClick()
amountPrompt.amount:SetText("4")
amountButtons[1].scripts.OnClick()
openPicker(button, "stack", row.statusInfo)
recipientRow = pickerRow({ id = 2, recipient = profile.mailRecipients[2], enabled = true })
recipientRow.scripts.OnClick()
amountButtons[2].scripts.OnClick()
assert(profile.mailAssignments.stack == 2 and #profile.mailQueues.stack == 2
  and profile.mailQueues.stack[1].recipient == 1 and profile.mailQueues.stack[2].recipient == 2,
  "Remember must preserve the FIFO queue")
row.statusKey = "stack"
button.scripts.OnEnter(button)
assert(GameTooltip.lines[2] == "  - Alt (25 pending)"
  and GameTooltip.lines[3] == "  - Other (4 pending)"
  and GameTooltip.lines[4] == "  - Other (default)")
row.statusKey = "item"
setStatus("stack", row.statusInfo, statuses[2])
assert(not profile.mailQueues.stack and not profile.mailAssignments.stack,
  "Changing the flag must discard the queue and default recipient")
profile.mailRecipients[2] = nil
openPicker(button, "stack", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
setStatus("stack", row.statusInfo, statuses[4])
amountPrompt.amount:SetText("5")
amountButtons[1].scripts.OnClick()
assert(profile.bankItems.stack and not profile.mailItems.stack and not profile.mailQueues.stack,
  "A stale quantity prompt must not overwrite a changed flag")
openPicker(button, "stack", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
local previousRecipient = profile.mailRecipients[1]
profile.mailRecipients[1] = { nickname = "Replacement", character = "Other" }
amountButtons[2].scripts.OnClick()
assert(profile.bankItems.stack and not profile.mailItems.stack, "A stale prompt must not use a replaced recipient")
profile.mailRecipients[1] = previousRecipient
pickerStackSize = nil
openPicker(button, "stack", row.statusInfo)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
assert(amountPrompt.shown and profile.bankItems.stack,
  "The amount prompt must not depend on stack metadata being cached")
amountPrompt:Hide()
pickerStackSize = 1
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
profile.mailQueues.pick = { { recipient = 1, remaining = 5 }, { recipient = 2, remaining = 7 } }
StaticPopupDialogs.SLACKHACKS_DELETE_MAIL_RECIPIENT.OnAccept(nil, deleteDialog)
assert(profile.mailItems.pick and not profile.mailAssignments.pick and #profile.mailQueues.pick == 1
  and profile.mailQueues.pick[1].recipient == 2 and not profile.mailRecipients[1] and not popup.shown)
profile.mailRecipients[2] = nil
upvalue(openPicker, "recipientPicker", false)
SlackHacks.isForever = function() return false end
openPicker(button, "retail", row.statusInfo)
assert(picker.shown and picker.template == "DefaultPanelTemplate"
  and rawget(inset.Bg, "atlas") == nil and #inset.paneTextures == 0
  and inset.Bg.points.TOPLEFT[1] == inset and inset.Bg.points.TOPLEFT[3] == 3
  and inset.Bg.points.TOPLEFT[4] == -3 and inset.Bg.points.BOTTOMRIGHT[3] == -3
  and inset.Bg.points.BOTTOMRIGHT[4] == 3,
  "Retail must contain its native marble background within the inset border")
assert(picker.width == 220 and picker.height == 451 and scroll.points.TOPLEFT[2] == -29
  and picker.width + scroll.points.BOTTOMRIGHT[1] - scroll.points.TOPLEFT[1] == 172
  and scrollBar.points.TOPLEFT[3] == 8 and scrollBar.points.TOPLEFT[4] == 0)
scrollHeight = picker.height + scroll.points.TOPLEFT[2] - scroll.points.BOTTOMRIGHT[2]
assert(scrollHeight >= 8 * 44 + 7 * viewPadding[5] and scrollHeight < 9 * 44 + 8 * viewPadding[5],
  "Retail must fit eight complete recipients, but not nine")
assert(#scroll.elements == 0 and newRecipient.text.text == "New Mail Recipient")
assert(newRecipient.width == 191 and newRecipient.height == 44
  and newRecipient.points.TOPLEFT[1] == scroll and newRecipient.points.TOPLEFT[2] == "BOTTOMLEFT"
  and newRecipient.points.TOPLEFT[3] == 3 and newRecipient.points.TOPLEFT[4] == 0
  and scroll.points.TOPLEFT[1] + newRecipient.points.TOPLEFT[3] + newRecipient.width
    == picker.width + inset.points.BOTTOMRIGHT[1] - 8
  and newRecipient.BgTop.width == 191 and newRecipient.BgMiddle.width == 190
  and newRecipient.BgBottom.width == 191
  and not newRecipient.points.LEFT and newRecipient.text.points.RIGHT[3] == -5
  and newRecipient.BgTop.shown and newRecipient.BgBottom.shown,
  "Retail's new recipient row and background must fit inside the inset without a gap above")
local retailRow = pickerRow({ id = 1, recipient = { nickname = "Retail", character = "Retail-Realm", icon = 123 } })
assert(retailRow.characterText.text == "Retail-Realm" and retailRow.text.points.TOPLEFT[3] == 44
  and retailRow.DeleteButton.points.BOTTOMRIGHT[1] == retailRow
  and retailRow.DeleteButton.points.BOTTOMRIGHT[3] == -2 and retailRow.DeleteButton.points.BOTTOMRIGHT[4] == 2)
assert(retailRow.BgTop.shown and not retailRow.BgBottom.shown and not retailRow.Stripe.shown)
initializeRow(retailRow, { id = 2, index = 2,
  recipient = { nickname = "Second", character = "Second-Realm", icon = 123 }, enabled = true })
assert(not retailRow.BgTop.shown and not retailRow.BgBottom.shown and retailRow.Stripe.shown
  and retailRow.Stripe.colorTexture[1] == 0.9 and retailRow.Stripe.colorTexture[2] == 0.9
  and retailRow.Stripe.colorTexture[3] == 1 and retailRow.Stripe.alpha == 0.1,
  "Reused Retail rows must update their native top and alternating stripe")
profile.mailRecipients[1] = { nickname = "Retail", character = "Retail-Realm", icon = 123 }
picker.refreshRecipients()
assert(not newRecipient.BgTop.shown and newRecipient.BgBottom.shown,
  "The bottom row must only show its top cap when the list is empty")
profile.mailRecipients[1] = nil
picker.refreshRecipients()
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
function SendMailFrame_CanSend()
  SendMailMailButton.enabled = true
  if globalHooks.SendMailFrame_CanSend then globalHooks.SendMailFrame_CanSend() end
end
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
function C_Container.GetContainerNumFreeSlots(bagID) return 1, bagID == 5 and 1 or 0 end
function C_Container.GetContainerItemInfo(bagID, slot)
  return bagID == 0 and bagSlots[slot] or bagID == 5 and reagentBagSlots[slot] or nil
end
function C_Container.PickupContainerItem(bagID, slot)
  local slots = bagID == 5 and reagentBagSlots or bagSlots
  if cursorType == "item" then
    assert(not slots[slot], "The mocked split destination must be empty")
    slots[slot] = moving
    cursorType, cursorLink, moving = nil, nil, nil
  else
    moving = slots[slot]
    slots[slot] = nil
    cursorType, cursorLink = "item", moving.hyperlink
  end
end
--- Split the requested quantity onto the mocked cursor.
---@param bagID number Container ID.
---@param slot number Container slot.
---@param count number Quantity to split.
function C_Container.SplitContainerItem(bagID, slot, count)
  local slots = bagID == 5 and reagentBagSlots or bagSlots
  local source = slots[slot]
  assert(count > 0 and count < source.stackCount)
  moving = {}
  for key, value in pairs(source) do moving[key] = value end
  moving.stackCount = count
  source.stackCount = source.stackCount - count
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
local originalBindInfo = upvalue(collectMail, "getBindInfo", function(_, slot)
  return nil, nil, slot == 2, true
end)
bagSlots[1].isBound, bagSlots[2].isBound = true, true
local mixedMail = collectMail(profile)[1]
assert(#mixedMail == 13, "Soulbound copies must not be collected for automatic mailing")
local sawAccountBound = false
for _, item in ipairs(mixedMail) do
  assert(item.slot ~= 1 or item.bagID ~= 0, "A soulbound copy must not be prepared for mail")
  if item.slot == 2 and item.bagID == 0 then sawAccountBound = true end
end
assert(sawAccountBound, "Account-bound copies must remain available for mailing")
bagSlots[1].isBound, bagSlots[2].isBound = nil, nil
upvalue(collectMail, "getBindInfo", originalBindInfo)
profile.bankItems[swordKey] = {}
assert(#collectMail(profile)[1] == 3, "Conflicting protected flags must prevent automatic mailing")
profile.bankItems[swordKey] = nil
reagentBagSlots[1] = nil
upvalue(openPicker, "recipientPicker", false)
upvalue(selectStatus, "openMailRecipientPicker", openPicker)
local savedBagSlots = bagSlots
bagSlots = {}
module:OnBagInteractionOpen("MAIL_SHOW")
SendMailFrame.hooks.OnShow()
module:OnMailAddonLoaded("ADDON_LOADED", "Blizzard_MailFrame")
assert(not upvalue(openPicker, "recipientPicker"),
  "Opening the mail window or Send Mail tab with no assigned items must not create the picker")

bagSlots[1] = savedBagSlots[1]
profile.mailAssignments[swordKey] = nil
SendMailFrame.hooks.OnShow()
assert(not upvalue(openPicker, "recipientPicker"), "Unassigned Mail flags must not open the send picker")
openPicker(button, "pick", row.statusInfo)
assert(picker.shown and not picker.mailMode, "Choosing a recipient for a flag must still open an empty picker")
picker:Hide()
upvalue(openPicker, "recipientPicker", false)

profile.mailAssignments[swordKey] = 1
bagSlots[1].isLocked = true
SendMailFrame.hooks.OnShow()
assert(picker.shown and picker.mailMode and scroll.elements[1].enabled,
  "Temporarily locked assigned items must still open the send picker")
picker:Hide()
bagSlots[1].isLocked = false
bagSlots = savedBagSlots
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
local unlockedMail = upvalue(startMail, "unlockedMailItems")
local lockedAmount = { recipient = 1, remaining = 3 }
local available = unlockedMail({
  { statusKey = "locked", count = 10, locked = true, amount = lockedAmount },
  { statusKey = "locked", count = 8, locked = false, amount = lockedAmount },
})
assert(#available == 1 and available[1].sendCount == 3,
  "Locked stacks must not reserve the amount needed by available stacks")
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
assert(HasSendMailItem(1) and not HasSendMailItem(2) and bagSlots[3] and not SendMailMailButton.enabled,
  "Changing a flag during preparation must stop and prevent sending stale attachments")
profile.mailAssignments[swordKey] = 1
SendMailFrame_CanSend()
assert(SendMailMailButton.enabled)
SendMailFrame.hooks.OnHide()
assert(not picker.shown, "Closing the send tab must hide the mail recipient window")

-- A failed split must not leave the full stack sendable as a one-item attachment.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems, profile.mailAssignments, profile.mailQueues = { [swordKey] = {} }, {},
  { [swordKey] = { { recipient = 1, remaining = 1 } } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
local originalSplit = C_Container.SplitContainerItem
local originalMailClick = ClickSendMailItemButton
ClickSendMailItemButton = function(index, clear)
  if not clear then moving.stackCount = 10 end
  originalMailClick(index, clear)
end
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 10 and not SendMailMailButton.enabled
  and profile.mailQueues[swordKey][1].remaining == 1
  and messages[#messages]:find("remove it before sending", 1, true),
  "An unexpected full-stack attachment must remain blocked until removed")
ClickSendMailItemButton = originalMailClick
ClickSendMailItemButton(1, true)
SendMailFrame_CanSend()
assert(SendMailMailButton.enabled, "Removing the unexpected attachment must unblock the draft")
C_Container.SplitContainerItem = originalSplit
SendMailFrame.hooks.OnHide()

-- A placed split can take time to reach the requested quantity in the bag.
do
  attachments, bagSlots = {}, {}
  SendMailFrame_Reset()
  profile.mailItems, profile.mailAssignments, profile.mailQueues = { [swordKey] = {} }, {},
    { [swordKey] = { { recipient = 1, remaining = 1 } } }
  bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
  local completeSplit
  local delays, originalAfter = {}, C_Timer.After
  C_Timer.After = function(delay, callback)
    delays[#delays + 1] = delay
    originalAfter(delay, callback)
  end
  C_Container.SplitContainerItem = function(_, slot, count)
    local source = bagSlots[slot]
    moving = {}
    for key, value in pairs(source) do moving[key] = value end
    local staged = moving
    staged.isLocked = true
    cursorType, cursorLink = "item", source.hyperlink
    completeSplit = function()
      source.stackCount, staged.isLocked, staged.stackCount = source.stackCount - count, false, count
    end
  end
  SendMailFrame.hooks.OnShow()
  recipientRow = pickerRow(scroll.elements[1])
  recipientRow.scripts.OnClick()
  table.remove(timers, 1)()
  table.remove(timers, 1)()
  assert(not attachments[1] and not cursorType and bagSlots[2] and not SendMailMailButton.enabled
    and math.abs(delays[1] - 0.1) < 0.001 and math.abs(delays[2] - 0.2) < 0.001
    and math.abs(delays[3] - 0.3) < 0.001,
    "Mail preparation must wait and progressively poll the staged stack")
  completeSplit()
  drainMailTimers()
  assert(attachments[1].stackCount == 1 and bagSlots[1].stackCount == 9 and SendMailMailButton.enabled,
    "The confirmed split must attach only the requested item")
  SendMailFrame.hooks.OnHide()
  attachments, bagSlots = {}, {}
  SendMailFrame_Reset()
  profile.mailQueues[swordKey] = { { recipient = 1, remaining = 1 } }
  bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
  SendMailFrame.hooks.OnShow()
  recipientRow = pickerRow(scroll.elements[1])
  recipientRow.scripts.OnClick()
  profile.mailQueues[swordKey] = { { recipient = 2, remaining = 1 } }
  drainMailTimers()
  assert(not attachments[1] and not cursorType and bagSlots[2]
    and messages[#messages]:find("mail queue changed", 1, true),
    "A changed queue must stop without attaching the staged item")
  SendMailFrame.hooks.OnHide()
  attachments, bagSlots = {}, {}
  SendMailFrame_Reset()
  profile.mailQueues[swordKey] = { { recipient = 1, remaining = 1 } }
  bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
  SendMailFrame.hooks.OnShow()
  recipientRow = pickerRow(scroll.elements[1])
  recipientRow.scripts.OnClick()
  drainMailTimers()
  assert(not attachments[1] and not cursorType and bagSlots[2]
    and messages[#messages]:find("split did not finish", 1, true),
    "A stalled split must time out without attaching an unconfirmed quantity")
  C_Timer.After = originalAfter
  C_Container.SplitContainerItem = originalSplit
  SendMailFrame.hooks.OnHide()
end

-- Splitting must leave the original stack alone when no compatible empty slot exists.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems, profile.mailAssignments, profile.mailQueues = { [swordKey] = {} }, {},
  { [swordKey] = { { recipient = 1, remaining = 1 } } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
for slot = 2, 20 do
  bagSlots[slot] = { itemID = 3, itemName = "Unrelated", hyperlink = "unassigned-link", quality = 1, stackCount = 1 }
end
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(not attachments[1] and bagSlots[1].stackCount == 10 and not cursorType
  and profile.mailQueues[swordKey][1].remaining == 1
  and messages[#messages]:find("make room in a compatible bag", 1, true),
  "A full bag must stop partial-stack preparation without moving or attaching the item")
SendMailFrame.hooks.OnHide()

attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems, profile.mailAssignments, profile.mailQueues = { [swordKey] = {} }, {},
  { [swordKey] = { { recipient = 1, remaining = 1 } } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 1 and not attachments[2] and bagSlots[1].stackCount == 9,
  "A one-item queue must attach exactly one item from a larger stack")
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(not profile.mailQueues[swordKey] and not profile.mailItems[swordKey]
  and bagSlots[1].stackCount == 9 and not attachments[1],
  "Completing the one-item queue must clear the flag without preparing the rest of the stack")
SendMailFrame.hooks.OnHide()

-- A one-time quantity must split stacks, survive a failed send, and clear only after success.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems, profile.mailAssignments, profile.mailQueues = { [swordKey] = {} }, {},
  { [swordKey] = { { recipient = 1, remaining = 12 } } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 8 }
bagSlots[2] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 7 }
bagSlots[3] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 8 and attachments[2].stackCount == 4 and not attachments[3]
  and bagSlots[2].stackCount == 3 and bagSlots[3].stackCount == 10 and SendMailMailButton.enabled,
  "One-time amounts must cap the total across stacks and split the final stack")
globalHooks.SendMail("Alt-Realm")
module:OnMailSendFailed()
assert(profile.mailQueues[swordKey][1].remaining == 12 and profile.mailItems[swordKey],
  "Failed sends must not consume the quantity or clear the flag")
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(not profile.mailQueues[swordKey] and not profile.mailAssignments[swordKey] and not profile.mailItems[swordKey]
  and bagSlots[2].stackCount == 3 and bagSlots[3].stackCount == 10,
  "A completed one-time send must clear the Mail flag without preparing excess items")

-- A shortage remains pending until more matching items are obtained.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, nil
profile.mailQueues[swordKey] = { { recipient = 1, remaining = 20 } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 7 }
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
picker:Hide()
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(profile.mailQueues[swordKey][1].remaining == 13 and profile.mailItems[swordKey],
  "Unavailable quantities must remain pending even when the recipient picker was closed before sending")
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 20 }
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 13 and bagSlots[1].stackCount == 7)
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(not profile.mailItems[swordKey] and not profile.mailQueues[swordKey] and bagSlots[1].stackCount == 7)

-- The remaining amount must carry across attachment-limited batches.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, nil
profile.mailQueues[swordKey] = { { recipient = 1, remaining = 13 } }
for slot = 1, 13 do
  bagSlots[slot] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
end
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[12] and bagSlots[13] and SendMailMailButton.enabled)
globalHooks.SendMail("Alt-ReRealm")
module:OnMailSendFailed()
assert(profile.mailQueues[swordKey][1].remaining == 13)
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(profile.mailQueues[swordKey][1].remaining == 1 and attachments[1] and not attachments[2])
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(not profile.mailItems[swordKey] and not profile.mailQueues[swordKey])

-- A later recipient keeps the flag until the final queued quantity is sent.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, nil
profile.mailQueues[swordKey] = { { recipient = 1, remaining = 1 }, { recipient = 2, remaining = 1 } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 3 }
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(profile.mailItems[swordKey] and #profile.mailQueues[swordKey] == 1
  and profile.mailQueues[swordKey][1].recipient == 2,
  "Finishing one recipient must retain the flag while another remains queued")
recipientRow = pickerRow(scroll.elements[2])
recipientRow.scripts.OnClick()
drainMailTimers()
globalHooks.SendMail("Empty-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(not profile.mailItems[swordKey] and not profile.mailQueues[swordKey] and bagSlots[1].stackCount == 1,
  "Finishing the last recipient without a default must clear the flag")

-- A queue is strictly FIFO per item, with the remembered recipient used only after it is empty.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, 2
profile.mailQueues[swordKey] = {
  { recipient = 1, remaining = 3 }, { recipient = 2, remaining = 4 }, { recipient = 1, remaining = 2 },
}
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 12 }
module:OnMailInfoUpdate()
assert(scroll.elements[1].enabled and not scroll.elements[2].enabled,
  "A later queued recipient and the default must not bypass the first recipient")
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 3 and bagSlots[1].stackCount == 9)
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(#profile.mailQueues[swordKey] == 2 and profile.mailQueues[swordKey][1].recipient == 2
  and not attachments[1] and not scroll.elements[1].enabled and scroll.elements[2].enabled,
  "The next recipient must become eligible only after the first succeeds")
recipientRow = pickerRow(scroll.elements[2])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 4 and bagSlots[1].stackCount == 5)
globalHooks.SendMail("Empty-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(#profile.mailQueues[swordKey] == 1 and profile.mailQueues[swordKey][1].recipient == 1
  and scroll.elements[1].enabled and not scroll.elements[2].enabled)
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 2 and bagSlots[1].stackCount == 3)
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(not profile.mailQueues[swordKey] and profile.mailAssignments[swordKey] == 2
  and profile.mailItems[swordKey] and scroll.elements[2].enabled,
  "The default must become eligible after the queue is exhausted")
recipientRow = pickerRow(scroll.elements[2])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 3 and not bagSlots[1])
globalHooks.SendMail("Empty-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(profile.mailAssignments[swordKey] == 2 and profile.mailItems[swordKey],
  "The default recipient must remain remembered after sending")

-- Separate non-stackable items and consecutive entries for one recipient also respect the queue.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, 1
profile.mailQueues[swordKey] = { { recipient = 1, remaining = 2 }, { recipient = 1, remaining = 2 } }
for slot = 1, 5 do
  bagSlots[slot] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
end
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1] and attachments[2] and not attachments[3] and SendMailMailButton.enabled)
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(#profile.mailQueues[swordKey] == 1 and attachments[1] and attachments[2] and not attachments[3],
  "A consecutive queue entry for the same recipient must be prepared next")
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(not profile.mailQueues[swordKey] and attachments[1] and not attachments[2]
  and profile.mailAssignments[swordKey] == 1,
  "The default may prepare the remaining item only after both queue entries")
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()

-- A newly queued recipient takes precedence over an already-prepared default draft.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey], profile.mailQueues[swordKey] = {}, 1, nil
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 10 }
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
assert(attachments[1].stackCount == 10 and SendMailMailButton.enabled)
openPicker(button, swordKey, { name = "Sword", quality = 1, itemLevel = 10, link = "sword-link" })
recipientRow = pickerRow(scroll.elements[2])
recipientRow.scripts.OnClick()
amountPrompt.amount:SetText("2")
amountButtons[1].scripts.OnClick()
assert(not SendMailMailButton.enabled, "A stale default draft must not bypass the new queue")
attachments = {}
SendMailFrame_CanSend()
assert(SendMailMailButton.enabled, "Removing stale attachments must restore normal sending")
SendMailFrame.hooks.OnHide()
SendMailFrame.hooks.OnShow()

-- Manual attachment edits do not consume a quota or trigger an automatic refill.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, nil
profile.mailQueues[swordKey] = { { recipient = 1, remaining = 3 } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 3 }
bagSlots[2] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
SendMailFrame.hooks.OnShow()
module:OnMailInfoUpdate()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
attachments[1].stackCount = 2
SendMailFrame_CanSend()
assert(not SendMailMailButton.enabled, "Editing a queued attachment must block an inaccurate send")
local beforeUncertain = #messages
globalHooks.SendMail("Alt-Realm")
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(profile.mailQueues[swordKey][1].remaining == 3 and bagSlots[2] and #messages == beforeUncertain + 1,
  "Changed attachments must not be credited or automatically refilled")
SendMailFrame.hooks.OnHide()

-- A newer one-time assignment must not be consumed by an earlier in-flight send.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, nil
profile.mailQueues[swordKey] = { { recipient = 1, remaining = 3 } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 3 }
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
globalHooks.SendMail("Alt-Realm")
local newerAmount = { recipient = 1, remaining = 8 }
profile.mailQueues[swordKey] = { newerAmount }
bagSlots[2] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 8 }
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(profile.mailQueues[swordKey][1] == newerAmount and newerAmount.remaining == 8 and bagSlots[2]
  and not attachments[1], "An older send must not consume or refill a replacement assignment")
SendMailFrame.hooks.OnHide()

-- A queue added after a default mail is sent must not trigger another default batch.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey], profile.mailQueues[swordKey] = {}, 1, nil
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
globalHooks.SendMail("Alt-Realm")
profile.mailQueues[swordKey] = { { recipient = 2, remaining = 1 } }
bagSlots[2] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 1 }
attachments = {}
SendMailFrame_Reset()
module:OnMailSendSuccess()
drainMailTimers()
assert(profile.mailQueues[swordKey][1].remaining == 1 and bagSlots[2] and not attachments[1],
  "An in-flight default mail must not refill past a newly queued recipient")
SendMailFrame.hooks.OnHide()

-- A send still settles its quota after the mail window closes and the module is disabled.
attachments, bagSlots = {}, {}
SendMailFrame_Reset()
profile.mailItems[swordKey], profile.mailAssignments[swordKey] = {}, nil
profile.mailQueues[swordKey] = { { recipient = 1, remaining = 5 } }
bagSlots[1] = { itemID = 1, itemName = "Sword", hyperlink = "sword-link", quality = 1, stackCount = 3 }
SendMailFrame.hooks.OnShow()
recipientRow = pickerRow(scroll.elements[1])
recipientRow.scripts.OnClick()
drainMailTimers()
globalHooks.SendMail("Alt-Realm")
local pendingEvents = upvalue(module.OnMailSendSuccess, "pendingMailEvents")
assert(pendingEvents.events.MAIL_SEND_SUCCESS and pendingEvents.events.MAIL_FAILED)
SendMailFrame.hooks.OnHide()
module:OnBagInteractionClosed("MAIL_CLOSED")
local originalFrame = upvalue(module.OnDisable, "frame", false)
local originalShowBags = upvalue(module.OnDisable, "showDefaultBags", function() end)
local originalMerchantOpen = upvalue(module.OnDisable, "merchantOpen", false)
local originalBindings = module.UpdateListViewBindings
module.UpdateListViewBindings = function() end
EventRegistry.UnregisterCallback = function() end
module.IsEnabled = function() return false end
module:OnDisable()
attachments = {}
SendMailFrame_Reset()
pendingEvents.scripts.OnEvent(pendingEvents, "MAIL_SEND_SUCCESS")
assert(profile.mailQueues[swordKey][1].remaining == 2 and profile.mailItems[swordKey]
  and not next(pendingEvents.events), "A late successful send must settle the pending amount")
module.IsEnabled = function() return true end
module.UpdateListViewBindings = originalBindings
upvalue(module.OnDisable, "frame", originalFrame)
upvalue(module.OnDisable, "showDefaultBags", originalShowBags)
upvalue(module.OnDisable, "merchantOpen", originalMerchantOpen)

-- A secure mail hook must not disable Blizzard's send button after the module is disabled.
-- Validate live flag choices, including stale menus and independently flagged copies.
do
  upvalue(setStatus, "validateStatusContext", validateStatus)
  upvalue(validateStatus, "getBindInfo", function(bagID, slot)
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    return "", 0, info.accountBound, info.isBound
  end)
  profile.enabled = true
  profile.protectedItems, profile.trashItems, profile.auctionItems = {}, {}, {}
  profile.bankItems, profile.mailItems, profile.mailAssignments, profile.mailQueues = {}, {}, {}, {}
  profile.auctionIneligibleOverrides = {}
  bagSlots = {
    { itemID = 1, hyperlink = "sword-link", isBound = true },
    { itemID = 1, hyperlink = "sword-link" },
  }
  local base = statusKey("Sword", 1, 10, nil)
  local variant = base .. "\031auction-ineligible"
  local info = { name = "Sword", quality = 1, itemLevel = 10, link = "sword-link" }
  local bound = { bag = profile, baseKey = base, eligible = false, soulbound = true, itemID = 1, link = "sword-link",
    entries = { { bagID = 0, slot = 1 } } }
  local unbound = { bag = profile, baseKey = base, eligible = true, soulbound = false, itemID = 1, link = "sword-link",
    entries = { { bagID = 0, slot = 2 } } }
  C_AuctionHouse.IsSellItemValid = function() return true end
  profile.protectedItems[base] = info
  row.statusKey, row.statusInfo, row.statusContext = base, info, bound
  MenuUtil = {
    CreateContextMenu = function(_, build)
      entries = {}
      build(button, {
        CreateTitle = function() end,
        CreateRadio = function(_, label, checked, select)
          entries[#entries + 1] = { label = label, checked = checked, selectStatus = select }
        end,
      })
    end,
  }
  button.scripts.OnClick(button, "LeftButton")
  entries[3].selectStatus()
  assert(profile.protectedItems[base] and not profile.auctionItems[base],
    "A soulbound Auction choice must leave the existing flag untouched")
  MenuUtil = nil
  button.scripts.OnClick(button, "LeftButton")
  legacy[4].func()
  assert(profile.protectedItems[base] and not profile.auctionItems[base],
    "The legacy menu must reject soulbound Auction choices too")
  assert(not setStatus(base, info, statuses[5], bound) and profile.protectedItems[base],
    "Soulbound items must not be flagged for Mail")

  bagSlots[1].accountBound = true
  bound.soulbound = false
  assert(setStatus(base, info, statuses[5], bound) == variant and profile.mailItems[variant]
    and profile.protectedItems[base], "Account-bound copies may be mailed independently")
  assert(not setStatus(variant, info, statuses[2], bound) and profile.mailItems[variant],
    "Account-bound items must not be flagged for Auction")

  profile.mailItems[base], profile.protectedItems[base] = info, nil
  profile.mailQueues[base] = { { recipient = 1, remaining = 3 } }
  profile.mailAssignments[base] = 1
  profile.auctionIneligibleOverrides[variant], profile.mailItems[variant] = nil, nil
  profile.mailAssignments[variant], profile.mailQueues[variant] = nil, nil
  assert(setStatus(base, info, statuses[2], unbound) == base and profile.auctionItems[base]
    and profile.mailItems[variant] and profile.mailAssignments[variant] == 1
    and profile.mailQueues[variant][1].remaining == 3 and not profile.mailQueues[base],
    "Separating an Auction flag must preserve, not duplicate, an inherited Mail queue")

  local applyChoice = upvalue(upvalue(openPicker, "openMailAmountPrompt"), "applyMailChoice")
  profile.auctionItems[base], profile.mailItems[base] = nil, info
  profile.auctionIneligibleOverrides[variant], profile.mailItems[variant] = nil, nil
  profile.mailAssignments[base], profile.mailAssignments[variant] = 1, nil
  profile.mailQueues[base], profile.mailQueues[variant] = { { recipient = 1, remaining = 3 } }, nil
  local choice = {
    bag = profile, key = base, statusInfo = info, context = bound, id = 1,
    recipient = profile.mailRecipients[1], previousStatus = statuses[5], previousValue = info,
    previousRecipient = 1, previousHead = profile.mailQueues[base][1],
  }
  picker.bag, picker.shown = profile, true
  bagSlots[1].accountBound = false
  applyChoice(picker, choice, 2)
  assert(profile.mailQueues[base][1].remaining == 3 and not profile.mailQueues[variant],
    "A stale Mail choice must not change its queue when the item becomes soulbound")
  bagSlots[1].accountBound = true
  applyChoice(picker, choice, 2)
  assert(not profile.mailQueues[base] and profile.mailQueues[variant][1].remaining == 3
    and profile.mailQueues[variant][2].remaining == 2 and profile.mailAssignments[variant] == 1
    and profile.mailItems[base] and profile.mailItems[variant],
    "Separating a Mail flag must move its existing queue before appending")
  profile.auctionItems[base], profile.mailItems[base] = info, nil

  row.statusKey, row.statusContext = base, unbound
  button.scripts.OnClick(button, "LeftButton")
  bagSlots[2].isBound = true
  legacy[4].func()
  assert(profile.auctionItems[base] and profile.mailQueues[variant][1].remaining == 3,
    "A stale menu must not replace flags or queues after binding changes")
  bagSlots[2].isBound = nil
  C_AuctionHouse.IsSellItemValid = function() return false end
  assert(not setStatus(base, info, statuses[2], unbound) and profile.auctionItems[base],
    "Blizzard-invalid items must not acquire an Auction flag")
  C_AuctionHouse.IsSellItemValid = nil
  assert(not setStatus(base, info, statuses[2], unbound) and profile.auctionItems[base],
    "Unavailable auction validation must not overwrite flags")
  C_AuctionHouse.IsSellItemValid = function() return true end
  bagSlots[2].itemID = 2
  assert(not setStatus(base, info, statuses[2], unbound) and profile.auctionItems[base],
    "A moved or replaced item must invalidate a menu")
  bagSlots[2].itemID = 1
  local itemInfo = C_Item.GetItemInfo
  for _, price in ipairs({ 0, -1 }) do
    C_Item.GetItemInfo = function() return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, price end
    assert(not setStatus(base, info, statuses[1], unbound) and profile.auctionItems[base],
      "Items without vendor value must not be marked Junk")
  end
  C_Item.GetItemInfo = function() return nil end
  assert(not setStatus(base, info, statuses[1], unbound) and profile.auctionItems[base],
    "An unavailable vendor price must not replace the flag")
  C_Item.GetItemInfo = itemInfo
  bagSlots[2].hasNoValue = true
  assert(not setStatus(base, info, statuses[1], unbound) and profile.auctionItems[base],
    "Unsellable stacks must not be marked Junk")
  assert(setStatus(base, info, statuses[2], unbound) == base,
    "A lack of vendor value must not prevent Blizzard-approved auctioning")
end

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
assert(cog.width == openBags.width and cog.height == openBags.height)
for _, texture in ipairs({ cog:GetNormalTexture(), cog:GetPushedTexture(), cog:GetHighlightTexture() }) do
  assert(texture.width == 33 and texture.height == 33 and texture.points.CENTER[1] == cog
    and texture.points.CENTER[2] == "CENTER" and texture.points.CENTER[3] == 0
    and texture.points.CENTER[4] == -3,
    "Each cog state must compensate for the atlas padding and vertical offset")
end
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
local families = {}
C_Container.GetContainerNumSlots = function(bagID) return sizes[bagID] end
C_Container.GetContainerNumFreeSlots = function(bagID) return free[bagID], families[bagID] or 0 end
local updateFooter = upvalue(module.Refresh, "updateFooter")
updateFooter()
assert(footer.slotCount.text == "|cffffffff30 / 81|r",
  "An equipped reagent bag with free space must count as one free slot")
assert(footer.slotCount.points.LEFT[1] == footer and footer.slotCount.points.LEFT[2] == "LEFT"
  and footer.slotCount.points.LEFT[3] == 4 and footer.slotCount.points.LEFT[4] == 0
  and footer.slotIcon.texture == "Interface\\Buttons\\Button-Backpack-Up"
  and footer.slotIcon.width == 16 and footer.slotIcon.height == 16
  and footer.slotIcon.points.LEFT[1] == footer.slotCount and footer.slotIcon.points.LEFT[2] == "RIGHT"
  and footer.slotIcon.points.LEFT[3] == 2
  and not rawget(footer, "freeSlotsButton")
  and not rawget(footer, "currencyButton") and footer.balances.points.BOTTOMRIGHT[3] == -4
  and footer.slotCount.fontSize == 10 and footer.height == 20 and footer.balanceContents.scale == 1,
  "The compact footer must show slots and currencies without the removed buttons")

free[5] = 1
updateFooter()
assert(footer.slotCount.text == "|cffffffff30 / 81|r",
  "One and many free reagent slots must count identically")
free[5] = 0
updateFooter()
assert(footer.slotCount.text == "|cffffffff31 / 81|r",
  "A full reagent bag must count as one used slot")
sizes[5] = 0
updateFooter()
assert(footer.slotCount.text == "|cffffffff30 / 80|r",
  "An unequipped reagent bag must not count as a slot")
sizes[5] = 20

--- Read the displayed RGB color of the slot count.
---@return number red Red component.
---@return number green Green component.
---@return number blue Blue component.
local function displayedSlotColor()
  local red, green, blue = footer.slotCount.text:match("^|cff(%x%x)(%x%x)(%x%x)")
  assert(red and green and blue, "The slot count must have a color")
  return tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16)
end

free = { [0] = 6, 0, 0, 0, 0, 0 }
upvalue(module.Refresh, "renderRows", function() end)
upvalue(module.Refresh, "updateMerchantJunkButton", function() end)
upvalue(realBuildFrame, "frame"):Show()
module:Refresh()
local red, green, blue = displayedSlotColor()
assert(red == 255 and green == 255 and blue < 255,
  "With large bags, a bag refresh must start warning at six free slots")
local previousGreen, previousBlue = green, blue
for remaining = 5, 0, -1 do
  free[0] = remaining
  updateFooter()
  red, green, blue = displayedSlotColor()
  assert(red == 255 and (green < previousGreen or green == previousGreen and blue < previousBlue),
    "Each lost slot within the warning range must advance the gradient toward red")
  previousGreen, previousBlue = green, blue
end
free[5] = 15
updateFooter()
red, green, blue = displayedSlotColor()
assert(footer.slotCount.text:find("80 / 81", 1, true) and green > 0 and blue == 0,
  "Many free reagent slots must count as only one remaining slot")
free[5] = 0
free[0] = 7
module:Refresh()
red, green, blue = displayedSlotColor()
assert(red == 255 and green == 255 and blue == 255, "Seven free slots must be white")
sizes = { [0] = 16, 0, 0, 0, 0, 0 }
free = { [0] = 4, 0, 0, 0, 0, 0 }
updateFooter()
red, green, blue = displayedSlotColor()
assert(red == 255 and green == 255 and blue == 255, "A backpack with four free slots must be white")
free[0] = 3
updateFooter()
red, green, blue = displayedSlotColor()
assert(red == 255 and green == 255 and blue > 0 and blue < 255,
  "A backpack with three free slots must start turning yellow")
free[0] = 2
updateFooter()
red, green, blue = displayedSlotColor()
assert(red == 255 and green > 128 and green < 255 and blue == 0,
  "The warning must transition through orange as space falls")
free[0] = 0
updateFooter()
assert(footer.slotCount.text == "|cffff000016 / 16|r", "A full backpack must be red")
sizes = { [0] = 16, 16, 16, 16, 16, 20 }
free = { [0] = 10, 10, 10, 10, 10, 6 }
SlackHacks.isRetailOrForever = function() return false end
updateFooter()
assert(footer.slotCount.text == "|cffffffff30 / 80|r", "Clients without reagent bags must exclude them")
SlackHacks.isRetailOrForever = function() return true end

--- Create fixed-width currency tokens for the footer layout test.
---@param count number Number of tokens.
---@return table tokens Mock tokens.
local function currencyTokens(count)
  local tokens = {}
  for index = 1, count do
    local token = { width = 50 }
    --- Get the mock token width.
    ---@return number width Mock token width.
    function token:GetWidth() return self.width end
    --- Set the mock token width.
    ---@param width number New mock token width.
    function token:SetWidth(width) self.width = width end
    tokens[index] = token
  end
  return tokens
end
footer.tokenFrame.Tokens, footer.crestFrame.Tokens = currencyTokens(3), currencyTokens(5)
footer.tokenFrame.ShouldShow = function() return true end
footer.crestFrame.ShouldShow = function() return true end
updateFooter()
local tokenWidth = 50
for _, frame in ipairs({ footer.tokenFrame, footer.crestFrame }) do
  for _, token in ipairs(frame.Tokens) do
    assert(token:GetWidth() == tokenWidth,
      "Each watched currency and crest must retain its native width")
  end
end
footer.tokenFrame:UpdateTokenAnchoring()
updateFooter()
assert(footer.tokenFrame.Tokens[1]:GetWidth() == tokenWidth,
  "Repeated native and addon updates must preserve pooled button widths")
footer.tokenFrame.Tokens[2]:SetWidth(64)
updateFooter()
assert(footer.tokenFrame.Tokens[2]:GetWidth() == 64
  and footer.tokenFrame:GetWidth() == 26 + 2 * tokenWidth + 64,
  "The footer must measure native token widths rather than replacing them")
footer.tokenFrame.Tokens[2]:SetWidth(tokenWidth)
updateFooter()
do
  local anchor = footer.tokenFrame.UpdateTokenAnchoring
  --- Verify that native anchoring receives the correctly sized frame.
  ---@param frame table Mock watched-currency frame.
  local previousAnchor = upvalue(anchor, "nativeAnchorTokens", function(frame)
    assert(frame.Tokens[1]:GetWidth() == tokenWidth
      and frame:GetWidth() == 26 + 3 * tokenWidth,
      "Blizzard must anchor its native tokens using the correctly sized frame")
    frame.anchored = true
  end)
  footer.tokenFrame:UpdateTokenAnchoring()
  assert(footer.tokenFrame.anchored)
  upvalue(anchor, "nativeAnchorTokens", previousAnchor)

  local originalRetail, originalCurrencies = SlackHacks.isRetail, C_CurrencyInfo
  local originalBreakUp, originalUtf8 = BreakUpLargeNumbers, strlenutf8
  local previousPreference = profile.trackCrestCurrencies
  local tokens, nextToken = currencyTokens(2), 0
  for _, token in ipairs(tokens) do
    token.Icon, token.Count = widget(), widget()
    --- Accept a mock script registration.
    function token:SetScript() end
    --- Accept a mock anchor reset.
    function token:ClearAllPoints() end
    --- Record the mock token's horizontal anchor offset.
    ---@param x number Horizontal anchor offset.
    function token:SetPoint(_, _, _, x) self.x = x end
    --- Accept a mock visibility update.
    function token:Show() end
  end
  local crest = { tokenPool = {
    --- Reset the mock pool.
    ReleaseAll = function() nextToken = 0 end,
    --- Acquire the next mock token.
    ---@return table token Next mock token.
    Acquire = function() nextToken = nextToken + 1; return tokens[nextToken] end,
  } }
  --- Report the mocked client flavor.
  ---@return boolean retail Whether the mocked client is Retail.
  SlackHacks.isRetail = function() return true end
  profile.trackCrestCurrencies = true
  --- Return information for two mocked crests.
  ---@param id number Currency identifier.
  ---@return table|nil info Mock information for two crests.
  C_CurrencyInfo = { GetCurrencyInfo = function(id)
    if id == 3446 or id == 3445 then return { iconFileID = id, quantity = 42 } end
  end }
  --- Format a mock quantity.
  ---@param value number Currency quantity.
  ---@return string text Mock formatted quantity.
  BreakUpLargeNumbers = function(value) return tostring(value) end
  strlenutf8 = string.len
  local updateCrests = upvalue(createFooter, "updateCrestFrame")
  updateCrests(crest)
  updateCrests(crest)
  assert(#crest.Tokens == 2 and tokens[1]:GetWidth() == tokenWidth
    and tokens[2].x == 13 + tokenWidth,
    "Crest buttons must keep their native width and spacing after pool reuse")
  SlackHacks.isRetail, C_CurrencyInfo = originalRetail, originalCurrencies
  BreakUpLargeNumbers, strlenutf8, profile.trackCrestCurrencies = originalBreakUp, originalUtf8, previousPreference
end
local scrollFrame = upvalue(realBuildFrame, "scrollFrame")
assert(footer.height == 20 and footer.balanceContents.scale == 1
  and footer.slotHover:GetWidth() + footer.balances:GetWidth() + 12 <= footer:GetWidth(),
  "All tracked currencies and the slot count must fit in the original footer")
footer:SetWidth(638)
updateFooter()
assert(footer.slotCount.fontSize == 8 and footer.balanceContents.scale == 1
  and footer.slotHover:GetWidth() + footer.balances:GetWidth() + 12 <= footer:GetWidth(),
  "The slot font must shrink before the currency strip when that is enough to fit")
footer:SetWidth(621)
updateFooter()
assert(footer.height == 20 and footer.balanceContents.scale < 1 and footer.slotCount.fontSize == 7
  and footer.slotHover:GetWidth() + footer.balances:GetWidth() + 12 <= footer:GetWidth() + 0.001,
  "An oversized currency strip must scale down instead of overlapping or increasing the footer height")
footer:SetWidth(684)
footer.tokenFrame.ShouldShow = function() return false end
footer.crestFrame.ShouldShow = function() return false end
updateFooter()
assert(footer.height == 20 and footer.balanceContents.scale == 1 and footer.slotCount.fontSize == 10
  and footer.balances.points.BOTTOMRIGHT[4] == 0
  and content.listInset.points.BOTTOMRIGHT[4] == 30 and scrollFrame.points.BOTTOMRIGHT[4] == 34,
  "The footer must restore normal sizes when currencies fit")

-- Slot statistics use all physical slots and all items, even when filters hide them.
SlackHacks.BEST_ITEMS = {
  BEST_BANDAGES = { [1251] = 66 },
  BEST_HEALING_POTIONS = { [118] = 90 },
  BEST_MANA_POTIONS = {},
}
local tooltipItems = {
  [0] = {
    { itemID = 2512, itemName = "Rough Arrow", hyperlink = "arrow", iconFileID = 1001, stackCount = 100, isFiltered = true },
    { itemID = 2512, itemName = "Rough Arrow", hyperlink = "arrow", stackCount = 20 },
    { itemID = 6289, itemName = "Raw Fish", hyperlink = "fish", stackCount = 2 },
    { itemID = 6265, itemName = "Soul Shard", hyperlink = "shard", iconFileID = 1002, stackCount = 3 },
    { itemID = 118, itemName = "Minor Healing Potion", hyperlink = "heal", stackCount = 2 },
    { itemID = 2456, itemName = "Minor Rejuvenation Potion", hyperlink = "both", stackCount = 3 },
    { itemID = 1251, itemName = "Linen Bandage", hyperlink = "bandage", stackCount = 4 },
    { itemID = 241300, itemName = "Lightfused Mana Potion", hyperlink = "mana", stackCount = 8 },
    { itemID = 2516, itemName = "Light Shot", hyperlink = "shot", stackCount = 40, isFiltered = true },
    { itemID = 2519, itemName = "Heavy Shot", hyperlink = "heavy", stackCount = 50 },
    { itemID = 2515, itemName = "Sharp Arrow", hyperlink = "sharp", stackCount = 70 },
  },
  [5] = {
    { itemID = 9999, stackCount = 1 },
    { itemID = 1234, itemName = "Herb", hyperlink = "herb", stackCount = 7 },
  },
}
local tooltipMetadata = {
  arrow = { "Rough Arrow", 6, 2, false, 5 }, sharp = { "Sharp Arrow", 6, 2, false, 20 },
  fish = { "Raw Fish", 7, 0 }, shard = { "Soul Shard", 7, 0 },
  heal = { "Minor Healing Potion", 0, 0, false, 5 },
  both = { "Minor Rejuvenation Potion", 0, 0, false, 20 },
  bandage = { "Linen Bandage", 0, 0, false, 5 },
  mana = { "Lightfused Mana Potion", 0, 1, false, 30 }, herb = { "Herb", 7, 0, true },
  shot = { "Light Shot", 6, 3, false, 5 }, heavy = { "Heavy Shot", 6, 3, false, 20 },
}
local itemRequests = {}
--- Report whether the test item's data has loaded.
---@param itemID number Item identifier.
---@return boolean cached Whether item data is cached.
function C_Item.IsItemDataCachedByID(itemID) return itemID ~= 9999 or tooltipMetadata[9999] ~= nil end
--- Record asynchronous item-data requests.
---@param itemID number Item identifier.
function C_Item.RequestLoadItemDataByID(itemID) itemRequests[itemID] = (itemRequests[itemID] or 0) + 1 end
--- Supply all inventory items, including those hidden by search.
---@param bagID number Container ID.
---@param slot number Slot index.
---@return table|nil info Container item information.
C_Container.GetContainerItemInfo = function(bagID, slot)
  return tooltipItems[bagID] and tooltipItems[bagID][slot]
end
--- Supply item metadata or simulate an uncached item.
---@param key string|number Item link or ID.
---@return string|nil name Item name.
C_Item.GetItemInfo = function(key)
  local item = tooltipMetadata[key]
  if not item then return nil end
  local level = item[5]
  if level == nil then level = 1 elseif level == false then level = nil end
  local icon = item[6]
  if icon == nil then icon = 7000 elseif icon == false then icon = nil end
  return item[1], type(key) == "string" and key or nil, item[7] or 1, level, nil, nil, nil, nil, "", icon, 1,
    item[2], item[3], 0, nil, nil, item[4]
end
--- Supply the variant-specific item level.
---@param key string|number Item link or ID.
---@return number|nil level Detailed item level, if available.
C_Item.GetDetailedItemLevelInfo = function(key)
  local item = tooltipMetadata[key]
  return item and item[5] or nil
end
sizes = { [0] = 12, 0, 0, 0, 0, 20 }
free = { [0] = 1, 0, 0, 0, 0, 18 }
profile.categoryFilters.consumables = false
SlackHacks.isForever = function() return true end
local playerClass = "WARLOCK"
--- Supply the player class for tooltip gating.
---@return string name Localized class name.
---@return string token Class token.
function UnitClass() return playerClass, playerClass end
local equippedThrown, ammoEquipped, rangedLinkCached, ammoIsShot = false, true, true, false
--- Supply the equipment slot identifiers.
---@param name string Slot name.
---@return number slot Slot identifier.
function GetInventorySlotInfo(name) return name == "RangedSlot" and 18 or 0 end
--- Supply the ranged weapon hyperlink.
---@param unit string Unit token.
---@param slot number Equipment slot.
---@return string|nil link Equipped weapon.
function GetInventoryItemLink(unit, slot)
  return rangedLinkCached and slot == 18 and (playerClass == "HUNTER" or playerClass == "ROGUE" or playerClass == "WARRIOR")
    and "ranged" or nil
end
--- Supply the equipped ranged item's ID while its link is uncached.
---@param unit string Unit token.
---@param slot number Equipment slot.
---@return number|nil id Equipped item ID.
function GetInventoryItemID(unit, slot)
  if slot == 0 then
    return ammoEquipped and (playerClass == "HUNTER" or playerClass == "ROGUE" or playerClass == "WARRIOR")
      and (ammoIsShot and 2516 or 2512) or nil
  end
  return not rangedLinkCached and 123 or nil
end
--- Identify the mocked ranged weapon.
---@param item string|number Item link or ID.
---@return number id Item ID.
---@return nil itemType Unused.
---@return nil subtype Unused.
---@return string equipLoc Equipment type.
---@return number|nil icon Icon.
---@return number|nil class Item class.
---@return number|nil subclass Item subclass.
function C_Item.GetItemInfoInstant(item)
  if item == 2512 or item == 2516 then return item, nil, nil, "", 1001, 6, item == 2512 and 2 or 3 end
  return 1, nil, nil, equippedThrown and "INVTYPE_THROWN" or "INVTYPE_RANGED"
end
--- Supply icons for the ammunition and ranged weapon.
---@param unit string Unit token.
---@param slot number Equipment slot.
---@return number icon Texture ID.
function GetInventoryItemTexture(unit, slot)
  if playerClass ~= "HUNTER" and playerClass ~= "ROGUE" and playerClass ~= "WARRIOR" then return nil end
  if slot == 0 and not ammoEquipped then return nil end
  return slot == 0 and 1001 or 1004
end
--- Supply the amount of equipped ammunition.
---@return number count Ammunition count.
function GetInventoryItemCount() return 120 end
--- Supply thrown weapon durability.
---@return number current Current durability.
---@return number maximum Maximum durability.
function GetInventoryItemDurability() return 80, 200 end
--- Record the tooltip owner.
---@param owner table Tooltip anchor.
function GameTooltip:SetOwner(owner) self.owner = owner end
--- Check the current tooltip owner.
---@param owner table Tooltip anchor.
---@return boolean owned Whether the tooltip belongs to the anchor.
function GameTooltip:IsOwned(owner) return self.owner == owner end
--- Record a bag-item tooltip.
---@param bag number Bag ID.
---@param slot number Bag slot.
function GameTooltip:SetBagItem(bag, slot) self.bagItem = { bag, slot }; self:SetText("Bag item") end
--- Record an equipped-item tooltip.
---@param unit string Unit token.
---@param slot number Equipment slot.
function GameTooltip:SetInventoryItem(unit, slot) self.inventoryItem = { unit, slot }; self:SetText("Equipped item") end
--- Hide the tooltip and release its owner.
GameTooltip_Hide = function() GameTooltip.owner = nil; GameTooltip:Hide() end
footer.slotHover:SetScript("OnLeave", GameTooltip_Hide)
updateFooter()
assert(#footer.supplyFrame.buttons == 1 and footer.supplyFrame.buttons[1].supply.itemID == 6265
  and footer.supplyFrame.buttons[1].Count.text == "3"
  and footer.slotCount.fontSize == footer.supplyFrame.buttons[1].Count.fontSize,
  "Forever Warlocks must see only Soul Shards, not bandages or potions")
assert(footer.supplies.points.LEFT[1] == footer.slotIcon and footer.supplies.points.LEFT[2] == "RIGHT"
  and footer.supplies.points.LEFT[3] == 8 and footer.supplyFrame.points.LEFT[1] == footer.supplies,
  "The supply strip must have a margin to the right of the bag slot count")
for _, button in ipairs(footer.supplyFrame.buttons) do
  assert(button.Count.points.LEFT[1] == button and button.Count.points.LEFT[2] == "LEFT"
    and button.Icon.points.LEFT[1] == button.Count and button.Icon.points.LEFT[2] == "RIGHT"
    and button.Icon.points.LEFT[3] == 2,
    "Each supply icon must appear to the right of its count")
end
footer.supplyFrame.buttons[1].scripts.OnEnter(footer.supplyFrame.buttons[1])
assert(GameTooltip.bagItem[1] == 0 and GameTooltip.bagItem[2] == 4,
  "Hovering a supply must show the selected bag item's native tooltip")
footer.supplyFrame.buttons[1].scripts.OnLeave()
tooltipItems[0][12] = { itemID = 6265, itemName = "Soul Shard", hyperlink = "shard", stackCount = 7 }
updateFooter()
assert(footer.supplyFrame.buttons[1].Count.text == "10", "Soul Shard stacks must be combined")
tooltipItems[0][12] = nil
updateFooter()
assert(footer.slotHover:GetWidth() == footer.slotCount:GetStringWidth() + 18
  and footer.slotHover.points.LEFT[1] == footer.slotCount)
footer.slotHover.scripts.OnEnter(footer.slotHover)
--- Return the right-column value and number of occurrences for a left-column label.
---@param label string Left-column text.
---@return string|nil value Right-column text.
---@return number count Number of matching lines.
local function tooltipValue(label)
  local value, count = nil, 0
  for _, line in ipairs(GameTooltip.doubleLines) do
    if line[1]:gsub("^|T.-|t ", "") == label then value, count = line[2], count + 1 end
  end
  return value, count
end
--- Find a tooltip line by its left-column text.
---@param label string Line label.
---@param after number|nil Ignore lines up to this position.
---@return number|nil index Position in the tooltip.
local function tooltipIndex(label, after)
  for index, value in ipairs(GameTooltip.lineOrder) do
    if value:gsub("^|T.-|t ", "") == label and index > (after or 0) then return index end
  end
end
--- Return the actual left-column text, including any icon markup.
---@param label string Label without icon markup.
---@return string|nil text Actual tooltip text.
local function tooltipRawLabel(label)
  for _, line in ipairs(GameTooltip.doubleLines) do
    if line[1]:gsub("^|T.-|t ", "") == label then return line[1] end
  end
end
local tooltipText = table.concat(GameTooltip.lines, "\n")
assert(GameTooltip.text == "Inventory Summary"
  and tooltipValue("Normal bags") == "11 / 12 (1 free)"
  and tooltipValue("Reagent bag") == "2 / 20 (18 free)"
  and not tooltipValue("All physical slots"))
assert(tooltipIndex("Categories") and tooltipIndex("Consumables")
  and not tooltipText:find("Categories:", 1, true))
assert(tooltipValue("Consumables") == "209" and tooltipValue("Reagents") == "9"
  and not tooltipValue("  Consumables"),
  "Categories must match filters and include hidden stacks")
local categoryLine = tooltipIndex("Equipment") + 1
assert(_G["GameTooltipTextLeft" .. categoryLine].fontSize == 8
  and _G["GameTooltipTextRight" .. categoryLine].fontSize == 8
  and _G.GameTooltipTextLeft2.fontSize == 10,
  "Category rows should use smaller text than the slot summary")
assert(not tooltipIndex("Ammo") and not tooltipValue("Arrows") and not tooltipValue("Shots")
  and tooltipValue("Soul Shards") == "3",
  "Warlocks must see shards but not ranged ammunition")
assert(tooltipRawLabel("Soul Shards") == "|T1002:18:18|t Soul Shards"
  and tooltipRawLabel("heal") == "|T7000:18:18|t heal"
  and tooltipRawLabel("bandage") == "|T7000:18:18|t bandage"
  and tooltipRawLabel("mana") == "|T7000:18:18|t mana",
  "Consumable rows must include bag icons or cached item icons")
local _, rejuvenationLines = tooltipValue("both")
assert(tooltipValue("Bandages") == "4" and tooltipValue("bandage") == "4"
  and tooltipValue("Health Potions") == "5" and tooltipValue("Mana Potions") == "11"
  and tooltipValue("heal") == "2" and tooltipValue("both") == "3" and rejuvenationLines == 2
  and tooltipValue("mana") == "8"
  and tooltipText:find("still loading", 1, true))
for _, label in ipairs({ "bandage", "heal", "mana" }) do
  local line = tooltipIndex(label) + 1
  assert(_G["GameTooltipTextLeft" .. line].fontSize == 8 and _G["GameTooltipTextRight" .. line].fontSize == 8,
    "Individual consumables must use smaller text in both columns")
end
assert(_G["GameTooltipTextLeft" .. (tooltipIndex("Mana Potions") + 1)].fontSize == 10,
  "Consumable totals must retain the normal font size")
do
  local rejuvenation, manaPotion = tooltipItems[0][6], tooltipItems[0][8]
  tooltipItems[0][6], tooltipItems[0][8] = nil, nil
  updateFooter()
  assert(tooltipValue("Mana Potions") == "(None)" and tooltipValue("Health Potions") == "2",
    "An empty mana breakdown must not affect health potion totals")
  tooltipItems[0][6], tooltipItems[0][8] = rejuvenation, manaPotion
  updateFooter()
end
assert(itemRequests[9999] == 1 and tooltipText:find("Item #9999", 1, true),
  "Uncached item data must be requested and identified in the loading message")
updateFooter()
assert(itemRequests[9999] == 1, "Refreshing the tooltip must not repeat a pending item request")
module:OnSlotItemDataLoaded("ITEM_DATA_LOAD_RESULT", 9999, false)
assert(table.concat(GameTooltip.lines, "\n"):find("unavailable", 1, true)
  and not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true),
  "A failed item request must be identified as unavailable, not loading indefinitely")
updateFooter()
assert(itemRequests[9999] == 1, "A failed item request must not be retried on every tooltip refresh")
assert(tooltipIndex("Soul Shards") < tooltipIndex("Bandages")
  and tooltipIndex("Bandages") < tooltipIndex("Health Potions")
  and tooltipIndex("Health Potions") < tooltipIndex("Mana Potions")
  and tooltipIndex("Mana Potions") < tooltipIndex("mana")
  and tooltipIndex("both") < tooltipIndex("heal")
  and tooltipIndex("mana") < tooltipIndex("both", tooltipIndex("Mana Potions")),
  "Sections and item variants must follow the requested order")
sizes[1], free[1], families[1] = 8, 3, 1
updateFooter()
assert(tooltipValue("Normal bags") == "11 / 12 (1 free)" and tooltipValue("Quiver") == "5 / 8 (3 free)"
  and tooltipIndex("Reagent bag") < tooltipIndex("Quiver") and tooltipIndex("Quiver") < tooltipIndex("Categories"),
  "Quiver capacity must be separate from normal bags and follow the reagent bag")
families[1], free[1] = 2, 0
updateFooter()
assert(tooltipValue("Shot bag") == "8 / 8 (0 free)" and not tooltipValue("Quiver"),
  "A full ammunition pouch must be labeled and counted correctly")
sizes[2], free[2], families[2] = 6, 2, 1
updateFooter()
assert(tooltipValue("Ammo bag") == "12 / 14 (2 free)" and not tooltipValue("Shot bag"),
  "Multiple ammo bags must have their capacities combined")
sizes[1], free[1], families[1] = 0, 0, nil
sizes[2], free[2], families[2] = 0, 0, nil
updateFooter()
assert(not tooltipValue("Quiver") and not tooltipValue("Shot bag") and not tooltipValue("Ammo bag"),
  "An unequipped ammo bag must not be listed")
tooltipItems[0][1].stackCount = 90
tooltipItems[0][4].stackCount = 4
updateFooter()
assert(tooltipValue("Soul Shards") == "4", "An open tooltip must refresh when bag contents change")
tooltipMetadata[9999] = { "Loaded item", 15, 0 }
module:OnSlotItemDataLoaded("ITEM_DATA_LOAD_RESULT", 9999, true)
assert(not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true)
  and not table.concat(GameTooltip.lines, "\n"):find("unavailable", 1, true)
  and tooltipValue("Other") == "91",
  "An item-info refresh must replace incomplete category totals")
tooltipMetadata[1234] = tooltipMetadata.herb
tooltipItems[0][12] = { itemID = 1234, hyperlink = "uncached-variant", stackCount = 1 }
updateFooter()
assert(tooltipValue("Reagents") == "10"
  and not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true)
  and not table.concat(GameTooltip.lines, "\n"):find("unavailable", 1, true),
  "A missing variant link must fall back to cached item-ID data without losing its category")
tooltipItems[0][12], tooltipMetadata[1234] = nil, nil
updateFooter()
tooltipMetadata[9999] = { "Loaded bandage", 0, 7, false, 20 }
updateFooter()
assert(tooltipValue("Bandages") == "5" and tooltipIndex("Loaded bandage") < tooltipIndex("bandage"),
  "Bandages must be counted by subclass and sorted by item level")
profile.customEssentialItems[6289] = true
updateFooter()
assert(tooltipValue("Essentials") == "2" and tooltipValue("Reagents") == "7",
  "Essential fish must not also count as reagents")
profile.customEssentialItems[6289] = nil
playerClass = "HUNTER"
updateFooter()
assert(footer.supplyFrame.buttons[1].supply.inventorySlot == 0
  and footer.supplyFrame.buttons[1].Icon.texture == 1001 and footer.supplyFrame.buttons[1].Count.text == "120",
  "The footer must show equipped ammunition, not the highest-level arrow stack")
footer:SetWidth(160)
updateFooter()
assert(footer.supplyFrame.scale == footer.balanceContents.scale and footer.balanceContents.scale < 1
  and math.abs(footer.slotCount.fontSize - footer.supplyFrame.buttons[1].Count.fontSize * footer.supplyFrame.scale) < 0.001
  and math.abs(footer.slotIcon.width - 16 * footer.supplyFrame.scale) < 0.001
  and math.abs(footer.slotHover:GetWidth()
    - footer.slotCount:GetStringWidth() - 18 * footer.supplyFrame.scale) < 0.001
  and footer.slotHover:GetWidth() + 8 + footer.supplies:GetWidth() + 4 + footer.balances:GetWidth()
    <= footer:GetWidth() - 8 + 0.001,
  "The supply margin must be included when scaling the footer to prevent overlap")
footer:SetWidth(684)
updateFooter()
assert(footer.slotIcon.width == 16 and footer.slotIcon.height == 16
  and footer.slotIcon.points.LEFT[3] == 2 and footer.slotCount.fontSize == footer.supplyFrame.buttons[1].Count.fontSize,
  "The slot icon and text must return to their normal size when space is available")
footer.supplyFrame.buttons[1].scripts.OnEnter(footer.supplyFrame.buttons[1])
assert(GameTooltip.inventoryItem[2] == 0, "Hovering ammunition must show its equipment tooltip")
footer.supplyFrame.buttons[1].scripts.OnLeave()
ammoEquipped = false
updateFooter()
assert(not footer.supplyFrame.shown, "Missing ammunition must not be replaced by an unequipped arrow stack")
ammoEquipped = true
ammoIsShot = true
updateFooter()
assert(not footer.supplyFrame.shown, "Equipped bullets must not be displayed as arrows")
ammoIsShot = false
equippedThrown = true
updateFooter()
assert(footer.supplyFrame.buttons[1].supply.inventorySlot == 18
  and footer.supplyFrame.buttons[1].Icon.texture == 1004 and footer.supplyFrame.buttons[1].Count.text == "80/200",
  "A thrown weapon must replace ammunition with its durability")
rangedLinkCached = false
updateFooter()
assert(footer.supplyFrame.buttons[1].supply.inventorySlot == 18,
  "An uncached thrown weapon link must still be identified by item ID")
rangedLinkCached = true
local originalDurability = GetInventoryItemDurability
GetInventoryItemDurability = function() return nil, nil end
updateFooter()
assert(footer.supplyFrame.buttons[1].Count.text == "?", "Unavailable thrown durability must not hide the weapon")
footer.supplyFrame.buttons[1].scripts.OnEnter(footer.supplyFrame.buttons[1])
assert(GameTooltip.lines[1] == "Durability unavailable.")
footer.supplyFrame.buttons[1].scripts.OnLeave()
GetInventoryItemDurability = originalDurability
equippedThrown = false
updateFooter()
footer.slotHover.scripts.OnEnter(footer.slotHover)
assert(not tooltipIndex("Arrows") and not tooltipIndex("Shots")
  and tooltipValue("arrow") == "110" and tooltipValue("sharp") == "70" and tooltipValue("shot") == "40"
  and tooltipValue("heavy") == "50" and not tooltipValue("Soul Shards")
  and tooltipIndex("sharp") < tooltipIndex("arrow") and tooltipIndex("heavy") < tooltipIndex("shot")
  and tooltipIndex("Categories") < tooltipIndex("Ammo") and tooltipIndex("Ammo") < tooltipIndex("sharp")
  and tooltipIndex("shot") < tooltipIndex("Consumables", tooltipIndex("Ammo"))
  and tooltipIndex("Bandages") < tooltipIndex("Health Potions")
  and tooltipIndex("Health Potions") < tooltipIndex("Mana Potions") and tooltipIndex("Mana Potions") < tooltipIndex("mana")
  and not tooltipIndex("(None)", tooltipIndex("Ammo")),
  "Hunters must see all ammunition variants between categories and consumables")
for _, label in ipairs({ "arrow", "shot" }) do
  local line = tooltipIndex(label) + 1
  assert(_G["GameTooltipTextLeft" .. line].fontSize == 8 and _G["GameTooltipTextRight" .. line].fontSize == 8,
    "Individual ammunition rows must use smaller text in both columns")
end
assert(_G["GameTooltipTextLeft" .. (tooltipIndex("Ammo") + 1)].fontSize == 10,
  "The Ammo heading must retain the normal font size")
local shot, heavy = tooltipItems[0][9], tooltipItems[0][10]
tooltipItems[0][9], tooltipItems[0][10] = nil, nil
updateFooter()
assert(tooltipValue("arrow") == "110" and not tooltipIndex("Shots") and not tooltipIndex("shot")
  and not tooltipIndex("(None)", tooltipIndex("Ammo")),
  "An absent ammunition type must not produce an empty row")
tooltipItems[0][9], tooltipItems[0][10] = shot, heavy
updateFooter()
local arrow, arrowStack, sharp = tooltipItems[0][1], tooltipItems[0][2], tooltipItems[0][11]
tooltipItems[0][1], tooltipItems[0][2], tooltipItems[0][11] = nil, nil, nil
updateFooter()
assert(tooltipValue("shot") == "40" and not tooltipIndex("Arrows") and not tooltipIndex("arrow")
  and not tooltipIndex("(None)", tooltipIndex("Ammo")),
  "Shot-only inventories must show their ammo without an empty arrow row")
tooltipItems[0][1], tooltipItems[0][2], tooltipItems[0][11] = arrow, arrowStack, sharp
sizes[1], free[1], families[1] = 8, 7, 1
tooltipItems[1] = { { itemID = 2512, itemName = "Rough Arrow", hyperlink = "arrow", stackCount = 25 } }
updateFooter()
assert(tooltipValue("arrow") == "135" and tooltipValue("Quiver") == "1 / 8 (7 free)",
  "Ammo counts must include stacks in equipped quivers")
tooltipItems[1], sizes[1], free[1], families[1] = nil, 0, 0, nil
updateFooter()
assert(tooltipRawLabel("arrow") == "|T1001:18:18|t arrow"
  and tooltipRawLabel("shot") == "|T7000:18:18|t shot",
  "Ammunition variants must include their item icons")
tooltipItems[0][1].iconFileID, tooltipItems[0][2].iconFileID = nil, 1003
tooltipMetadata.arrow[6] = false
updateFooter()
assert(tooltipRawLabel("arrow") == "|T1003:18:18|t arrow"
  and not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true),
  "An icon from a later stack must complete the grouped item")
tooltipItems[0][1].iconFileID, tooltipItems[0][2].iconFileID = 1001, nil
tooltipMetadata.arrow[6] = nil
tooltipMetadata.heal[6] = false
updateFooter()
assert(tooltipRawLabel("heal") == "heal" and table.concat(GameTooltip.lines, "\n"):find("unavailable", 1, true)
  and not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true),
  "A missing cached icon must be reported as unavailable rather than indefinitely loading")
tooltipMetadata.heal[6] = nil
updateFooter()
assert(tooltipRawLabel("heal") == "|T7000:18:18|t heal"
  and not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true),
  "The icon must appear after item information becomes available")
tooltipMetadata.sharp[5] = false
updateFooter()
assert(tooltipIndex("arrow") < tooltipIndex("sharp")
  and not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true)
  and not table.concat(GameTooltip.lines, "\n"):find("unavailable", 1, true),
  "Missing levels for cached items must sort last without implying that they are still loading")
tooltipMetadata.sharp[5] = 20
updateFooter()
assert(tooltipIndex("sharp") < tooltipIndex("arrow")
  and not table.concat(GameTooltip.lines, "\n"):find("still loading", 1, true),
  "The item-info refresh must restore level ordering and clear the loading message")
for _, class in ipairs({ "ROGUE", "WARRIOR" }) do
  playerClass = class
  updateFooter()
  assert(tooltipIndex("Ammo") and tooltipValue("arrow") == "110" and tooltipValue("shot") == "40"
    and not tooltipValue("mana") and not tooltipIndex("Mana Potions"),
    class .. " must see both ammunition types")
  assert(footer.supplyFrame.buttons[1].shown and not footer.supplyFrame.buttons[2],
    class .. " must see only equipped arrows in the footer")
end
playerClass = "MAGE"
updateFooter()
assert(not tooltipIndex("Ammo") and not tooltipValue("arrow") and not tooltipValue("shot")
  and not tooltipValue("Soul Shards")
  and tooltipValue("mana") == "8" and tooltipValue("Mana Potions") == "11",
  "Classes unable to use ranged ammunition must not see its breakdown")
local manaLine = tooltipIndex("mana") + 1
footer.slotHover.scripts.OnLeave()
assert(not rawget(GameTooltip, "owner") and not GameTooltip.shown)
GameTooltip:SetText("Another tooltip")
assert(_G["GameTooltipTextLeft" .. categoryLine].fontSize == 10
  and _G["GameTooltipTextRight" .. categoryLine].fontSize == 10
  and _G["GameTooltipTextLeft" .. manaLine].fontSize == 10
  and _G["GameTooltipTextRight" .. manaLine].fontSize == 10,
  "Clearing the summary must restore shared tooltip fonts")
SlackHacks.isForever = function() return false end
SlackHacks.isRetail = function() return true end
profile.trackCrestCurrencies = false
playerClass = "HUNTER"
footer.slotHover.scripts.OnEnter(footer.slotHover)
updateFooter()
assert(not footer.supplyFrame.shown, "Retail must not show the supply strip")
do
  local originalCurrencies, originalBreakUp, originalUtf8 = C_CurrencyInfo, BreakUpLargeNumbers, strlenutf8
  local oldTokens, oldTokenShouldShow = footer.tokenFrame.Tokens, footer.tokenFrame.ShouldShow
  local oldCrestUpdate, oldCrestShouldShow, oldPool = footer.crestFrame.Update, footer.crestFrame.ShouldShow,
    footer.crestFrame.tokenPool
  local crests, nextCrest = currencyTokens(2), 0
  for _, token in ipairs(crests) do
    token.Icon, token.Count = widget(), widget()
    --- Accept a mock script registration.
    function token:SetScript() end
    --- Accept a mock anchor reset.
    function token:ClearAllPoints() end
    --- Accept a mock anchor.
    function token:SetPoint() end
    --- Accept a mock visibility update.
    function token:Show() end
  end
  footer.crestFrame.tokenPool = {
    --- Reset the mock crest pool.
    ReleaseAll = function() nextCrest = 0 end,
    --- Acquire the next mock crest.
    ---@return table token Mock crest token.
    Acquire = function() nextCrest = nextCrest + 1; return crests[nextCrest] end,
  }
  footer.crestFrame.Update = upvalue(createFooter, "updateCrestFrame")
  --- Report whether the mock crest frame has tokens.
  ---@return boolean shown Whether any crests are visible.
  footer.crestFrame.ShouldShow = function(self) return self.numWatchedTokens > 0 end
  --- Report whether the mock currency frame has tokens.
  ---@return boolean shown Whether any currencies are tracked.
  footer.tokenFrame.ShouldShow = function(self) return #self.Tokens > 0 end
  --- Provide two current-season crest currencies.
  ---@param id number Currency identifier.
  ---@return table|nil info Mock crest information.
  C_CurrencyInfo = { GetCurrencyInfo = function(id)
    if id == 3446 or id == 3445 then return { iconFileID = id, quantity = 42 } end
  end }
  --- Format a mock quantity.
  ---@param value number Currency quantity.
  ---@return string text Mock formatted quantity.
  BreakUpLargeNumbers = function(value) return tostring(value) end
  strlenutf8 = string.len
  for _, oldPreference in ipairs({ true, false }) do
    profile.trackCrestCurrencies = oldPreference
    for _, tracked in ipairs({ 0, 1 }) do
      footer.tokenFrame.Tokens = currencyTokens(tracked)
      updateFooter()
      assert(not footer.supplyFrame.shown and footer.crestFrame.shown and #footer.crestFrame.Tokens == 2
        and profile.trackCrestCurrencies == oldPreference,
        "Retail must show crests and no supplies regardless of tracked currencies or the old preference")
    end
  end
  footer.tokenFrame.Tokens, footer.tokenFrame.ShouldShow = oldTokens, oldTokenShouldShow
  footer.crestFrame.Update, footer.crestFrame.ShouldShow, footer.crestFrame.tokenPool =
    oldCrestUpdate, oldCrestShouldShow, oldPool
  C_CurrencyInfo, BreakUpLargeNumbers, strlenutf8 = originalCurrencies, originalBreakUp, originalUtf8
  profile.trackCrestCurrencies = false
  footer.slotHover.scripts.OnEnter(footer.slotHover)
  updateFooter()
end
assert(not tooltipIndex("Ammo") and not tooltipValue("arrow") and not tooltipValue("shot")
  and not tooltipValue("Soul Shards"))
assert(not tooltipValue("mana") and not tooltipIndex("Mana Potions"), "Retail Hunters must not see mana potions")
for _, class in ipairs({ "DEATHKNIGHT", "DEMONHUNTER" }) do
  playerClass = class
  updateFooter()
  assert(not tooltipValue("mana") and not tooltipIndex("Mana Potions"), class .. " must not see mana potions")
end
playerClass = "MONK"
updateFooter()
assert(tooltipValue("mana") == "8" and tooltipValue("Mana Potions") == "11",
  "Monks can use mana as Mistweavers and must see the mana potion total")
playerClass = "HUNTER"
footer.slotHover.scripts.OnLeave()
sizes = { [0] = 0, 0, 0, 0, 0, 0 }
free = { [0] = 0, 0, 0, 0, 0, 0 }
footer.slotHover.scripts.OnEnter(footer.slotHover)
assert(tooltipValue("Normal bags") == "0 / 0 (0 free)"
  and tooltipValue("Reagent bag") == "0 / 0 (0 free)",
  "Empty bag slots must use the same summary format")
assert(tooltipValue("Bandages") == "(None)" and tooltipValue("Health Potions") == "(None)"
  and not tooltipIndex("Mana Potions"))
SlackHacks.isForever = function() return true end
footer.slotHover.scripts.OnEnter(footer.slotHover)
assert(tooltipIndex("Ammo") < tooltipIndex("(None)", tooltipIndex("Ammo"))
  and tooltipIndex("(None)", tooltipIndex("Ammo")) < tooltipIndex("Consumables", tooltipIndex("Ammo"))
  and not tooltipIndex("Arrows") and not tooltipIndex("Shots")
  and tooltipValue("Mana Potions") == "(None)")
playerClass = "WARLOCK"
footer.slotHover.scripts.OnEnter(footer.slotHover)
assert(tooltipValue("Soul Shards") == "(None)" and not tooltipValue("Arrows") and not tooltipValue("Shots"))
footer.slotHover.scripts.OnLeave()

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
