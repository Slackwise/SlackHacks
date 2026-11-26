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
  local object = { scripts = {}, shown = true }
  --- Accept irrelevant frame setup.
  local function noop() end
  setmetatable(object, { __index = function() return noop end })
  function object:SetScript(event, handler) self.scripts[event] = handler end
  function object:HookScript() end
  function object:GetFrameLevel() return 0 end
  function object:GetNormalTexture() return nil end
  function object:GetHighlightTexture() return nil end
  function object:GetRegions() return end
  function object:GetName() return self.name end
  function object:CreateTexture() return widget() end
  function object:CreateMaskTexture() return widget() end
  function object:CreateFontString() return widget() end
  function object:SetTexture(texture) self.texture = texture end
  function object:SetText(text) self.text = text end
  function object:Show() self.shown = true end
  function object:Hide() self.shown = false end
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
--- Accept the unrelated split-stack hook.
function hooksecurefunc() end
local notifications = 0
--- Supply the options registry notification.
---@return table registry
function LibStub() return { NotifyChange = function() notifications = notifications + 1 end } end
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
local merchantUpdates = 0
upvalue(setStatus, "renderRows", function() end)
upvalue(setStatus, "updateMerchantJunkButton", function() merchantUpdates = merchantUpdates + 1 end)

local row = createRow(1)
row.statusKey = "item"
row.statusInfo = { name = "Item" }
local button = row.statusBtn
assert(button.clicks[1] == "LeftButtonUp" and button.clicks[2] == "RightButtonUp")
updateStatusButton(button, getStatus("item"))
assert(button.text.shown and button.text.text == "..." and not button.icon.shown)
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Item Status: None" and GameTooltip.lines[1]:find("Left%-click")
  and GameTooltip.lines[1]:find("Right%-click") and GameTooltip.lines[2]:find("marks only"))

local entries = {}
MenuUtil = {
  CreateContextMenu = function(_, build)
    entries = {}
    local root = {
      CreateTitle = function() end,
      CreateRadio = function(_, label, checked, selectStatus)
        entries[#entries + 1] = { label = label, checked = checked, selectStatus = selectStatus }
      end,
    }
    build(button, root)
  end,
}
button.scripts.OnClick(button, "LeftButton")
assert(#entries == 6 and entries[1].checked())
for index, label in ipairs({ "Vendor", "Protect", "Auction", "Bank", "Mail" }) do
  assert(entries[index + 1].label:find("|T", 1, true) and entries[index + 1].label:find(label, 1, true))
end
entries[2].selectStatus()
assert(profile.trashItems.item == row.statusInfo and entries[2].checked())
updateStatusButton(button, getStatus("item"))
assert(button.icon.shown and button.icon.texture and not button.text.shown)
button.scripts.OnClick(button, "RightButton")
assert(not getStatus("item"), "Right-click must clear a vendor mark")
button.scripts.OnClick(button, "RightButton")
assert(getStatus("item").id == "vendor", "Right-click must mark an unmarked item for vendor")

entries[3].selectStatus()
assert(profile.protectedItems.item and not profile.trashItems.item)
entries[4].selectStatus()
assert(profile.auctionItems.item and not profile.protectedItems.item and not profile.trashItems.item)
entries[5].selectStatus()
assert(profile.bankItems.item and not profile.auctionItems.item)
local visitSlots = upvalue(upvalue(module.MERCHANT_SHOW, "sellMarkedTrashItems"), "forEachSellableTrashSlot")
local protected = upvalue(visitSlots, "isProtectedItem")
assert(protected("item"), "Bank marks must use existing protection")
button.scripts.OnEnter(button)
assert(GameTooltip.text == "Item Status: Bank" and GameTooltip.lines[3]:find("grey items"))
button.scripts.OnClick(button, "RightButton")
assert(profile.trashItems.item and not profile.bankItems.item and not protected("item"))
entries[6].selectStatus()
assert(profile.mailItems.item and not profile.trashItems.item)
entries[1].selectStatus()
assert(not getStatus("item"))
assert(notifications == merchantUpdates and notifications > 0)

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
assert(#legacy == 7 and legacy[3].text:find("Vendor", 1, true))
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
print("Listview bag status tests passed")
