-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_merchant.lua

local profile = { enabled = true, protectedItems = {}, trashItems = {} }
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 } }
UIParent = {}

--- Supply the module used by the bag implementation.
---@return table module
function SlackHacks:NewModule() return { IsEnabled = function() return true end } end

--- Include the reagent bag in bag actions.
---@return boolean modern
function SlackHacks.isRetailOrForever() return true end

--- Supply hidden frames created while loading the module.
---@return table frame
function CreateFrame()
  return { SetOwner = function() end, SetAllPoints = function() end, Hide = function() end }
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
local hookMerchant = upvalue(module.MERCHANT_SHOW, "hookMerchantJunkButton")
local updateButton = upvalue(module.MERCHANT_SHOW, "updateMerchantJunkButton")
local sellMarked = upvalue(module.MERCHANT_SHOW, "sellMarkedTrashItems")
local visitSlots = upvalue(sellMarked, "forEachSellableTrashSlot")
local statusKey = upvalue(visitSlots, "itemStatusKey")
upvalue(visitSlots, "getUpgradeTrack", function() return nil end)
upvalue(module.MERCHANT_SHOW, "renderRows", function() end)
hookMerchant()

local slots = {
  { itemID = 1, itemName = "Marked", hyperlink = "Marked", quality = 1 },
  { itemID = 2, itemName = "Protected", hyperlink = "Protected", quality = 1 },
  { itemID = 3, itemName = "Worthless", hyperlink = "Worthless", quality = 1, hasNoValue = true },
  { itemID = 4, itemName = "Locked", hyperlink = "Locked", quality = 1, isLocked = true },
  { itemID = 5, itemName = "Banked", hyperlink = "Banked", quality = 1 },
  { itemID = 6, itemName = "Auction", hyperlink = "Auction", quality = 1 },
  { itemID = 7, itemName = "Mail", hyperlink = "Mail", quality = 1 },
  { itemID = 8, itemName = "Grey", hyperlink = "Grey", quality = 0 },
  { itemID = 9, itemName = "Protected Grey", hyperlink = "Protected Grey", quality = 0 },
  { itemID = 10, itemName = "Uncached Grey", hyperlink = "Uncached Grey", quality = 0 },
}
for _, item in ipairs(slots) do profile.trashItems[statusKey(item.itemName, item.quality, 10, nil)] = true end
profile.protectedItems[statusKey("Protected", 1, 10, nil)] = true
profile.protectedItems[statusKey("Protected Grey", 0, 10, nil)] = true
profile.bankItems = { [statusKey("Banked", 1, 10, nil)] = true }
profile.auctionItems = { [statusKey("Auction", 1, 10, nil)] = true }
profile.mailItems = { [statusKey("Mail", 1, 10, nil)] = true }
slots[#slots + 1] = { itemID = 11, quality = 0 }
local actions = {}
local warnings = {}
--- Record messages about unavailable item information.
---@param message string Message shown to the player.
function prn(message) warnings[#warnings + 1] = message end
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and #slots or 0 end,
  GetContainerItemInfo = function(_, slot) return slots[slot] end,
  UseContainerItem = function(_, slot)
    actions[#actions + 1] = slots[slot].itemName
    slots[slot].isLocked = true
  end,
}
C_Item = {
  GetItemInfo = function(link)
    assert(link, "Item lookup must not receive an unavailable link")
    if link == "Uncached Grey" then return nil end
    return link, link, 1, 10
  end,
  GetDetailedItemLevelInfo = function(link)
    assert(link, "Item-level lookup must not receive an unavailable link")
    return link ~= "Uncached Grey" and 10 or nil
  end,
}
local nativeJunk = 0
C_MerchantFrame = {
  GetNumJunkItems = function() return nativeJunk end,
  SellAllJunkItems = function()
    actions[#actions + 1] = "native"
    nativeJunk = 0
  end,
}
MerchantSellAllJunkButton = {
  Icon = { SetDesaturated = function(self, value) self.desaturated = value end },
  SetEnabled = function(self, value) self.enabled = value end,
}
--- Simulate Blizzard resetting button state on every merchant update.
function MerchantFrame_Update()
  MerchantSellAllJunkButton:SetEnabled(nativeJunk > 0)
  MerchantSellAllJunkButton.Icon:SetDesaturated(nativeJunk == 0)
end
--- Simulate secure post-hooks on a global or table method.
---@param target string|table Global function name or table.
---@param name string|function Method name or callback.
---@param callback function|nil Table method callback.
function hooksecurefunc(target, name, callback)
  local owner, key, hook = _G, target, name
  if type(target) == "table" then owner, key, hook = target, name, callback end
  local original = owner[key]
  owner[key] = function(...)
    original(...)
    hook(...)
  end
end

-- Blizzard stores this callback before the hooks are installed.
local confirmation = function() C_MerchantFrame.SellAllJunkItems() end
module:MERCHANT_SHOW()
hookMerchant()
assert(MerchantSellAllJunkButton.enabled and not MerchantSellAllJunkButton.Icon.desaturated,
  "Marked items must enable the button without native junk")
MerchantFrame_Update()
assert(MerchantSellAllJunkButton.enabled, "Blizzard's updates must retain marked-item availability")
assert(#actions == 0, "Opening or cancelling confirmation must not sell anything")
confirmation()
assert(table.concat(actions, ",") == "native,Marked", "Confirmation must sell native junk first, then eligible marked items")
assert(not MerchantSellAllJunkButton.enabled and MerchantSellAllJunkButton.Icon.desaturated,
  "Locked, protected, bank-marked, and worthless items must not keep the button enabled")

slots[1].isLocked = false
profile.autoSellMarkedItems = true
confirmation()
assert(table.concat(actions, ",") == "native,Marked,native,Marked",
  "Manual confirmation must still sell newly marked items when auto-sell is enabled")
nativeJunk = 1
MerchantFrame_Update()
assert(MerchantSellAllJunkButton.enabled, "Native junk must still enable the button")
profile.enabled = false
nativeJunk = 0
MerchantFrame_Update()
assert(not MerchantSellAllJunkButton.enabled, "Disabling the module must restore Blizzard's state")
slots[1].isLocked = false
confirmation()
assert(#actions == 5 and actions[5] == "native", "Disabled module must not sell marked items")
profile.enabled = true
module:MERCHANT_CLOSED()
updateButton()
confirmation()
assert(#actions == 6 and actions[6] == "native", "A closed merchant must not sell marked items")
module:MERCHANT_SHOW()
assert(#actions == 8 and actions[7] == "Marked" and actions[8] == "Grey",
  "Auto-sell must sell marked and unprotected grey items only")
assert(#warnings > 0 and warnings[#warnings]:find("could not be checked for sale", 1, true),
  "Skipping uncached items must be reported to the player")
slots[1].isLocked = false
module:SellBlizzardGreyItems()
assert(#actions == 9 and actions[9] == "native", "Grey-only native sales must not sell marked items")
module.IsEnabled = function() return false end
module:MERCHANT_SHOW()
confirmation()
assert(#actions == 10 and actions[10] == "native", "A disabled Ace module must not sell or extend native sales")

-- Exercise both merchant event handlers: the two settings must never trigger competing sales.
--- Supply the atlas markup initialized by Core.
---@return string markup Placeholder markup.
function CreateAtlasMarkup() return "" end
assert(loadfile("Core.lua"))()
SlackHacks.db.profile.inventory = { autoSellGreyItems = true, autoRepair = false }
module.IsEnabled = function() return true end
slots[1].isLocked, slots[8].isLocked = false, false
actions = {}
profile.autoSellMarkedItems = true
SlackHacks:MERCHANT_SHOW("MERCHANT_SHOW")
module:MERCHANT_SHOW()
assert(table.concat(actions, ",") == "Marked,Grey", "Auto-Sell Junk must override Blizzard's grey sale")
slots[1].isLocked, slots[8].isLocked = false, false
actions = {}
profile.autoSellMarkedItems = false
SlackHacks:MERCHANT_SHOW("MERCHANT_SHOW")
module:MERCHANT_SHOW()
assert(table.concat(actions, ",") == "native", "Auto-Sell ALL Grey Items alone must use only Blizzard's sale")
actions = {}
SlackHacks.db.profile.inventory.autoSellGreyItems = false
SlackHacks:MERCHANT_SHOW("MERCHANT_SHOW")
module:MERCHANT_SHOW()
assert(#actions == 0, "Neither option enabled must not sell automatically")
actions = {}
SlackHacks.db.profile.inventory.autoSellGreyItems = true
profile.autoSellMarkedItems = true
module.IsEnabled = function() return false end
SlackHacks:MERCHANT_SHOW("MERCHANT_SHOW")
module:MERCHANT_SHOW()
assert(table.concat(actions, ",") == "native", "The independent grey option must work when the bag module is disabled")

-- A separately protected soulbound copy must not be sold with an identical marked copy.
do
  local key = statusKey("Marked", 1, 10, nil)
  local variant = key .. "\031auction-ineligible\031soulbound"
  slots = {
    { itemID = 1, itemName = "Marked", hyperlink = "Marked", quality = 1 },
    { itemID = 1, itemName = "Marked", hyperlink = "Marked", quality = 1, isBound = true },
  }
  profile.trashItems = { [key] = true }
  profile.protectedItems = { [variant] = true }
  profile.auctionItems, profile.bankItems, profile.mailItems = {}, {}, {}
  profile.auctionIneligibleOverrides = { [variant] = true }
  C_AuctionHouse = { IsSellItemValid = function() return true end }
  ItemLocation = { CreateFromBagAndSlot = function()
    return { IsValid = function() return true end }
  end }
  local visited = {}
  visitSlots(function(_, slot) visited[#visited + 1] = slot end)
  assert(#visited == 1 and visited[1] == 1,
    "Merchant scanning must respect a separately protected soulbound copy")
  profile.auctionIneligibleOverrides = {}
  profile.protectedItems = { [key] = true }
  profile.auctionItems = { [key] = true }
  assert(visitSlots() == 0 and profile.protectedItems[variant],
    "Legacy overlapping Auction and Protect flags must retain protection for soulbound copies")
  slots[2] = nil
  profile.protectedItems = { [key .. "\031auction-ineligible"] = true }
  profile.auctionItems = {}
  profile.auctionIneligibleOverrides = { [key .. "\031auction-ineligible"] = true }
  C_AuctionHouse = nil
  local count, unavailable = visitSlots()
  assert(count == 0 and unavailable == 1,
    "An unvalidated copy must not be sold when its separate flag might protect it")
end
print("Listview bag merchant tests passed")
