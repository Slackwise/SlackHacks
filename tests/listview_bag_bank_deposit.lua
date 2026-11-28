-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_bank_deposit.lua

local profile = {
  enabled = true, bankItems = {}, bankItemsOnce = {}, protectedItems = {}, trashItems = {},
}
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 }, BankType = { Character = 1, Account = 2 } }
UIParent = {}
C_AuctionHouse = {}
C_Bank = {
  CanUseBank = function() return true end,
  IsItemAllowedInBankType = function() return true end,
}
ItemLocation = {}
--- Supply valid locations for bag items in the deposit tests.
---@return table location Mock item location.
function ItemLocation:CreateFromBagAndSlot()
  return { IsValid = function() return true end }
end
--- Supply the Listview Bag module.
---@return table module
function SlackHacks:NewModule() return { IsEnabled = function() return true end } end
--- Include the reagent bag in inventory scans.
---@return boolean modern
function SlackHacks.isRetailOrForever() return true end
--- Use the Retail-style client behavior for item metadata.
---@return boolean retail
function SlackHacks.isRetail() return true end
--- Disable Forever-only behavior in this test.
---@return boolean forever
function SlackHacks.isForever() return false end
--- Return a lightweight frame for module-load-time UI objects.
---@return table frame Mock frame.
function CreateFrame()
  local function noop() end
  local frame = setmetatable({}, { __index = function() return noop end })
  frame.SetOwner = noop
  frame.SetAllPoints = noop
  frame.RegisterEvent = noop
  frame.SetScript = noop
  return frame
end
--- Make the optional AceConfig registry unavailable.
---@return nil registry
function LibStub() return nil end

assert(loadfile("ListviewBag.lua"))()

local module = SlackHacks.ListviewBag
local messages = {}
--- Record user-facing messages raised by deposit edge cases.
---@param message string Message to capture.
function SlackHacks.prn(message) messages[#messages + 1] = message end
--- Read or replace a named closure upvalue.
---@param fn function Closure to inspect.
---@param name string Upvalue name.
---@param replacement function|nil Optional replacement value.
---@return any value Original upvalue.
local function upvalue(fn, name, replacement)
  for index = 1, math.huge do
    local key, value = debug.getupvalue(fn, index)
    if not key then break end
    if key == name then
      if replacement then debug.setupvalue(fn, index, replacement) end
      return value
    end
  end
  error("Missing upvalue: " .. name)
end

local collectGroups = upvalue(module.DepositBankFlaggedItems, "collectGroups")
local statusKey = upvalue(collectGroups, "itemStatusKey")
upvalue(collectGroups, "getUpgradeTrack", function() return nil end)
upvalue(collectGroups, "getBindInfo", function() return "", nil, false, false end)

local bankLink = "|cff0070dd|Hitem:105|h[Bank Item]|h|r"
local slots = {
  [1] = { itemID = 105, itemName = "Bank Item", hyperlink = bankLink, iconFileID = 1050, quality = 3 },
  [2] = { itemID = 106, itemName = "Keep Item", hyperlink = "keep-link", iconFileID = 1060, quality = 3 },
}
local deposits = {}
C_Container = {
  GetContainerNumSlots = function(bagID) return bagID == 0 and 2 or 0 end,
  GetContainerItemInfo = function(bagID, slot) return bagID == 0 and slots[slot] end,
  UseContainerItem = function(bagID, slot, _, bankType)
    deposits[#deposits + 1] = { bagID = bagID, slot = slot, bankType = bankType }
    slots[slot] = nil
  end,
}
C_Item = {
  GetItemInfo = function(link)
    if link == bankLink then return "Bank Item", bankLink, 3, 10 end
    if link == "keep-link" then return "Keep Item", "keep-link", 3, 10 end
  end,
  GetDetailedItemLevelInfo = function() return 10 end,
}
BankFrame = {
  IsShown = function() return true end,
  GetActiveBankType = function() return Enum.BankType.Character end,
}
local now = 0
GetTime = function() return now end
C_Timer = { After = function(delay, callback) now = now + delay; callback() end }

local key = statusKey("Bank Item", 3, 10, nil)
local groups = collectGroups(true)
assert(#groups == 2 and groups[1].statusKey == key,
  "Banked item metadata must resolve to the saved flag key")
profile.bankItems[key] = { name = "Bank Item" }
module:DepositBankFlaggedItems()
assert(#deposits == 1 and deposits[1].bagID == 0 and deposits[1].slot == 1
  and deposits[1].bankType == Enum.BankType.Character and slots[2] ~= nil
  and profile.bankItems[key] == nil,
  "Only flagged items should deposit, and the flag clears after the item leaves the bags")

slots[1] = { itemID = 105, itemName = "Bank Item", hyperlink = bankLink, iconFileID = 1050, quality = 3 }
profile.bankItemsOnce[key] = { name = "Bank Item", link = bankLink, quality = 3, itemLevel = 10 }
module:DepositBankFlaggedItems()
assert(#deposits == 2 and profile.bankItemsOnce[key] == nil,
  "A one-time Bank mark must deposit its item and clear after it leaves the bags.")

slots[1] = { itemID = 105, itemName = "Bank Item", hyperlink = bankLink, iconFileID = 1050, quality = 3 }
profile.bankItems[key] = { name = "Bank Item" }
C_Bank.IsItemAllowedInBankType = function() return false end
module:DepositBankFlaggedItems()
assert(#deposits == 2 and profile.bankItems[key],
  "Items disallowed by the selected bank must remain flagged")

C_Bank.IsItemAllowedInBankType = function() return true end
C_Item.CanBeRefunded = function() return true end
module:DepositBankFlaggedItems(Enum.BankType.Account)
assert(#deposits == 2 and profile.bankItems[key],
  "Refundable items must remain flagged rather than bypass Blizzard's account-bank confirmation")

C_Item.CanBeRefunded = nil
C_Container.UseContainerItem = function(bagID, slot, _, bankType)
  deposits[#deposits + 1] = { bagID = bagID, slot = slot, bankType = bankType }
end
module:DepositBankFlaggedItems()
assert(#deposits == 3 and profile.bankItems[key],
  "A Bank flag must remain when the attempted deposit is not reflected in inventory")

print("Listview bag bank deposit tests passed")
