-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_vendor_options.lua

local profile = { enabled = true, showReagentBagContents = true, protectedItems = {}, trashItems = {} }
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
--- Supply the hidden tooltip created at load time.
---@return table frame
function CreateFrame()
  return { SetOwner = function() end, SetAllPoints = function() end, Hide = function() end }
end
--- Clear a saved list in place.
---@param values table List to clear.
function wipe(values) for key in pairs(values) do values[key] = nil end end

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
local buildDisplayRows = upvalue(renderRows, "buildDisplayRows")
local collectGroups = upvalue(buildDisplayRows, "collectGroups")
local statusKey = upvalue(collectGroups, "itemStatusKey")
upvalue(collectGroups, "getUpgradeTrack", function() return nil end)
upvalue(collectGroups, "getBindInfo", function() return "", nil, false, false end)

local link = "|cff0070dd|Hitem:42:0:0:0|h[Marked Item]|h|r"
local baseLink = "|cff0070dd|Hitem:42|h[Marked Item]|h|r"
local slot = { itemID = 42, itemName = "Marked Item", hyperlink = link, iconFileID = 123, quality = 3, stackCount = 1 }
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
  GetContainerItemInfo = function() return slot end,
}
C_Item = {
  GetItemInfo = function(item)
    if item == "Uncached" then return nil end
    local resultLink = item == "Marked Item" and baseLink or item
    return "Marked Item", resultLink, 3, 10, nil, nil, nil, nil, nil, 123
  end,
  GetDetailedItemLevelInfo = function() return 10 end,
}

local key = statusKey("Marked Item", 3, 10, nil)
local legacy = { name = "Marked Item", quality = 3, itemLevel = 10 }
profile.trashItems[key] = legacy
local groups = collectGroups()
assert(groups[1].statusInfo.link == link and groups[1].statusInfo.icon == 123)
assert(legacy.link == link and legacy.icon == 123, "Matching legacy entries must recover the exact item")
assert(legacy.quality == 3 and legacy.itemLevel == 10, "Recovery must preserve the selling rule")

local refreshes = 0
--- Record a bag refresh after editing marked items.
function module:Refresh() refreshes = refreshes + 1 end
--- Supply the options heading version.
---@return string version
function SlackHacks.getAddonVersion() return "test" end
SlackHacks.Talents = { MAX_SPECS = 0 }
SlackHacks.Enum = { SelfVendorMode = {
  FLASK = 1, OIL = 2, AUGMENT_RUNES = 3, VANTUS_RUNE = 4, CONSUMABLES = 5, AUGMENTS = 6,
} }
SlackHacks.SELF_VENDOR_MODES = {}
for index = 1, 6 do
  SlackHacks.SELF_VENDOR_MODES[index] = { key = "mode" .. index, name = "Mode", description = "Mode" }
end
assert(loadfile("Options.lua"))()
local getOptions = upvalue(SlackHacks.registerOptions, "getOptions")
profile.trashItems.old = { name = "Marked Item", quality = 2, itemLevel = 1 }
profile.trashItems.uncached = { name = "Uncached" }
profile.trashItems.clear = true
profile.protectedItems.keep = true

local group = getOptions().args.inventory.args.listviewBag.args.autoVendorItems
local args = group.args
--- Encode a status key as an AceConfig-safe option key.
---@param value string Status key.
---@return string optionKey Encoded option key.
local function optionKey(value)
  return "item:" .. value:gsub(".", function(char) return ("%02x"):format(char:byte()) end)
end
assert(group.inline and args.clear.confirm and not args.clear.disabled())
assert(args[optionKey(key)].name == link and args[optionKey(key)].tooltipHyperlink == link)
assert(args[optionKey(key)].image == 123 and args[optionKey(key)].get())
assert(args[optionKey("old")].name == baseLink and args[optionKey("old")].image == 123 and args.legacyInfo)
assert(args[optionKey("uncached")].name == "Uncached" and not args[optionKey("uncached")].tooltipHyperlink)
assert(args[optionKey("clear")].name == "clear", "Legacy keys must not collide with the clear button")
assert(loadfile("Libs/Ace3/LibStub/LibStub.lua"))()
assert(loadfile("Libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua"))()
assert(loadfile("Libs/Ace3/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua"))()
local registry = LibStub("AceConfigRegistry-3.0")
registry:RegisterOptionsTable("VendorItems", function()
  return getOptions().args.inventory.args.listviewBag.args.autoVendorItems
end)
registry:GetOptionsTable("VendorItems", "dialog", "Test-1.0")
local otherProfile = { trashItems = { other = { name = "Uncached" } } }
SlackHacks.db.profile.listviewBag = otherProfile
local otherArgs = registry:GetOptionsTable("VendorItems", "dialog", "Test-1.0").args
assert(otherArgs[optionKey("other")] and not otherArgs[optionKey(key)], "Options must follow profile changes")
SlackHacks.db.profile.listviewBag = profile
args = registry:GetOptionsTable("VendorItems", "dialog", "Test-1.0").args
args[optionKey("old")].set(nil, false)
assert(not profile.trashItems.old and profile.trashItems[key] == legacy and refreshes == 1)

local list = profile.trashItems
args.clear.func()
assert(next(list) == nil and profile.trashItems == list and profile.protectedItems.keep)
assert(refreshes == 2 and getOptions().args.inventory.args.listviewBag.args.autoVendorItems.args.clear.disabled())
print("Listview bag vendor options tests passed")
