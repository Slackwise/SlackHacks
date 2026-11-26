-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_merchant.lua

local profile = { enabled = true, protectedItems = {}, trashItems = {} }
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 } }
UIParent = {}

--- Supply the module used by the bag implementation.
---@return table module
function SlackHacks:NewModule() return {} end

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
}
for _, item in ipairs(slots) do profile.trashItems[statusKey(item.itemName, 1, 10, nil)] = true end
profile.protectedItems[statusKey("Protected", 1, 10, nil)] = true
local actions = {}
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and #slots or 0 end,
  GetContainerItemInfo = function(_, slot) return slots[slot] end,
  UseContainerItem = function(_, slot)
    actions[#actions + 1] = slots[slot].itemName
    slots[slot].isLocked = true
  end,
}
C_Item = {
  GetItemInfo = function(link) return link, link, 1, 10 end,
  GetDetailedItemLevelInfo = function() return 10 end,
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
  "Locked, protected, and worthless items must not keep the button enabled")

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
assert(#actions == 7 and actions[7] == "Marked", "Auto-sell must still run when a merchant opens")
print("Listview bag merchant tests passed")
