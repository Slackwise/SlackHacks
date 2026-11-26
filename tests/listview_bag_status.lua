-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_status.lua

local profile = { enabled = true, protectedItems = {}, trashItems = {} }
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 } }
UIParent = {}

--- Supply the bag module.
---@return table module
function SlackHacks:NewModule() return {} end
--- Include the modern reagent bag.
---@return boolean modern
function SlackHacks.isRetailOrForever() return true end

--- Construct a minimal UI object that records scripts, text, textures, and visibility.
---@return table widget
local function widget()
  local object = { scripts = {}, hooks = {}, shown = true }
  --- Accept irrelevant frame setup.
  local function noop() end
  setmetatable(object, { __index = function(_, key) if key ~= "blockedAction" then return noop end end })
  function object:SetScript(event, handler) self.scripts[event] = handler end
  function object:HookScript(event, handler) self.hooks[event] = handler end
  function object:GetFrameLevel() return 0 end
  function object:GetNormalTexture() return nil end
  function object:GetHighlightTexture() return nil end
  function object:GetRegions() return end
  function object:GetName() return self.name end
  function object:CreateTexture() return widget() end
  function object:CreateMaskTexture() return widget() end
  function object:CreateFontString() return widget() end
  function object:SetTexture(texture) self.texture = texture; self.atlas = nil end
  function object:SetAtlas(atlas) self.atlas = atlas; self.texture = nil end
  function object:SetTexCoord(...) self.texCoord = { ... } end
  function object:SetText(text) self.text = text end
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
local getStatus = upvalue(openMenu, "getItemStatus")
local updateStatusButton = upvalue(renderRows, "updateStatusButton")
local updateInteractionBlocker = upvalue(renderRows, "updateInteractionBlocker")
local blockedItemAction = upvalue(updateInteractionBlocker, "blockedItemAction")
local merchantUpdates = 0
upvalue(setStatus, "renderRows", function() end)
upvalue(setStatus, "updateMerchantJunkButton", function() merchantUpdates = merchantUpdates + 1 end)

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
  and GameTooltip.lines[1] == "Left-click to choose flag.\nRight-click to quick mark as Junk.")
button.scripts.OnClick(button, "RightButton")
assert(profile.trashItems.item and not profile.bankItems.item and not protected("item"))
entries[6].selectStatus()
assert(profile.mailItems.item and not profile.trashItems.item)
updateStatusButton(button, getStatus("item"))
assert(button.icon.texture == "Interface\\Minimap\\Tracking\\Mailbox")
entries[1].selectStatus()
assert(not getStatus("item"))
assert(notifications == merchantUpdates and notifications > 0)

-- Grey and uncached items cannot acquire flags, even from a previously opened menu.
for _, quality in ipairs({ 0, -1 }) do
  row.statusInfo.quality = quality ~= -1 and quality or nil
  local previousMessages = #messages
  button.scripts.OnClick(button, "RightButton")
  button.scripts.OnClick(button, "LeftButton")
  entries[2].selectStatus()
  assert(not getStatus("item") and #messages == previousMessages + 3)
  button.scripts.OnEnter(button)
  assert(GameTooltip.text == (quality == 0 and "Grey items cannot be flagged."
    or "Item quality is not yet available."))
end
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
    assert(not blockedItemAction("item", 0), "Grey items must not be protected by legacy marks")
    upvalue(blockedItemAction, name, false)
  end
end
profile.trashItems.item = nil

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
legacy[2].func()
assert(not getStatus("other"))

-- Build the actual window as on reload, including its status header atlas.
local buildFrame = upvalue(module.OnEnable, "buildFrame")
upvalue(buildFrame, "createFooter", function() end)
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
upvalue(module.OnEnable, "buildFrame", function() end)
upvalue(module.OnEnable, "hookMerchantJunkButton", function() end)
upvalue(module.OnEnable, "updateMerchantJunkButton", function() end)
module:OnEnable()
assert(registeredEvents.CURSOR_CHANGED == "OnCursorChanged", "Enable must register the supported cursor event")
print("Listview bag status tests passed")
