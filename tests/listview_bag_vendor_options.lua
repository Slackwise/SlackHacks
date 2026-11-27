-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_vendor_options.lua

local profile = { enabled = true, showReagentBagContents = true, protectedItems = {}, trashItems = {} }
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
local row = args[optionKey(key)]
assert(row.type == "group" and row.inline and row.name == "")
assert(row.args.item.type == "description" and row.args.item.dialogControl == "InteractiveLabel"
  and row.args.item.name == "|T123:18:18|t " .. link and row.args.item.tooltipHyperlink == link)
assert(row.args.remove.type == "execute" and row.args.remove.name == "Remove"
  and row.args.item.order < row.args.remove.order
  and row.args.item.width == "relative" and row.args.remove.width == "relative"
  and row.args.item.relWidth + row.args.remove.relWidth <= 1,
  "Each item must have a remove button to its right")
assert(args[optionKey("old")].args.item.name == "|T123:18:18|t " .. baseLink
  and args[optionKey("old")].args.item.tooltipHyperlink == baseLink and args.legacyInfo)
assert(args[optionKey("uncached")].args.item.name == "Uncached"
  and not args[optionKey("uncached")].args.item.tooltipHyperlink)
assert(args[optionKey("clear")].args.item.name == "clear", "Legacy keys must not collide with the clear button")
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
args[optionKey("old")].args.remove.func()
assert(not profile.trashItems.old and profile.trashItems[key] == legacy and refreshes == 1)
assert(not getOptions().args.inventory.args.listviewBag.args.autoVendorItems.args[optionKey("old")],
  "Deleting an item must remove its row from the options")
args[optionKey(key)].args.remove.func()
assert(not profile.trashItems[key] and profile.trashItems.uncached and profile.protectedItems.keep and refreshes == 2,
  "Deleting a linked item must leave other items and protection flags untouched")

local list = profile.trashItems
args.clear.func()
assert(next(list) == nil and profile.trashItems == list and profile.protectedItems.keep)
assert(refreshes == 3 and getOptions().args.inventory.args.listviewBag.args.autoVendorItems.args.clear.disabled())

-- Essentials settings preserve the existing defaults and allow inventory-backed custom items.
local bagOptions = getOptions().args.inventory.args.listviewBag.args
local essentials = bagOptions.essentials
assert(essentials.inline and essentials.name == '"Essentials" Filter Items'
  and essentials.order < bagOptions.autoSellMarkedItems.order)
assert(essentials.args.description.name == "These items are common to all players but you usually don't interact with them directly.")
for _, item in ipairs(module.ESSENTIAL_ITEMS) do
  assert(essentials.args["item:" .. item.id].get(), item.name .. " must be checked by default")
end
assert(not essentials.args.arrows.get() and not essentials.args.soulShards.get())
essentials.args["item:6948"].set(nil, false)
assert(not essentials.args["item:6948"].get())
essentials.args["item:6948"].set(nil, true)
essentials.args.arrows.set(nil, true)
assert(essentials.args.arrows.get())
essentials.args.arrows.set(nil, false)

local previousContainer, previousItem = C_Container, C_Item
local searchSlots = {
  [0] = {
    { itemID = 100, itemName = "Healing Herb", hyperlink = "healing-link", iconFileID = 1000, isFiltered = true },
    { itemID = 100, itemName = "Healing Herb", hyperlink = "healing-link", iconFileID = 1000 },
    { itemID = 101, itemName = "Silver Herb", hyperlink = "silver-link", iconFileID = 1001 },
    { itemID = 103 },
    { itemID = 104 },
  },
  [5] = { { itemID = 102, itemName = "Rare Herb", hyperlink = "rare-link", iconFileID = 1002 } },
}
local stalePresent = true
local globalSearchChanged = false
C_Container = {
  GetContainerNumSlots = function(bagID) return searchSlots[bagID] and #searchSlots[bagID] or 0 end,
  GetContainerItemInfo = function(bagID, slot)
    local item = searchSlots[bagID][slot]
    if item.itemID == 102 and not stalePresent then return nil end
    return item
  end,
  SetItemSearch = function() globalSearchChanged = true end,
}
C_Item = { GetItemInfo = function(id)
  if id == 104 then return "Hidden Herb", "hidden-link", 1, 1, nil, nil, nil, nil, nil, 1004 end
end }
local messages = {}
SlackHacks.prn = function(message) messages[#messages + 1] = message end
local custom = getOptions().args.inventory.args.listviewBag.args.essentials.args.customItems
assert(custom.inline and custom.name == "Custom Essential Items")
registry:RegisterOptionsTable("Essentials", function()
  return getOptions().args.inventory.args.listviewBag.args.essentials
end)
registry:GetOptionsTable("Essentials", "dialog", "Test-1.0")
local customArgs = custom.args
customArgs.search.set(nil, "  HeRb  ")
local values = customArgs.results.values()
local sorting = customArgs.results.sorting()
assert(values[100] and values[101] and values[102] and values[104] and not values[103]
  and #sorting == 4 and sorting[1] == 100 and sorting[2] == 104 and sorting[3] == 102 and sorting[4] == 101)
assert(not customArgs.results.disabled() and customArgs.add.disabled() and not globalSearchChanged,
  "Search must include filtered and reagent-bag items without changing Blizzard's bag search")
assert(customArgs.searchStatus.name():find("still loading", 1, true),
  "Uncached item names must be reported")
customArgs.results.set(nil, 102)
assert(not customArgs.add.disabled())
stalePresent = false
customArgs.add.func()
assert(not profile.customEssentialItems[102] and messages[#messages]:find("no longer in your bags", 1, true),
  "A stale result must not add an item that left the inventory")
stalePresent = true
customArgs.search.set(nil, "healing")
assert(customArgs.results.get() == 100, "A single distinct match must be selected automatically")
customArgs.add.func()
assert(profile.customEssentialItems[100].link == "healing-link" and profile.customEssentialItems[100].icon == 1000)
customArgs = getOptions().args.inventory.args.listviewBag.args.essentials.args.customItems.args
assert(customArgs["item:100"].args.item.name == "|T1000:18:18|t healing-link"
  and customArgs["item:100"].args.item.tooltipHyperlink == "healing-link")
customArgs.results.set(nil, 100)
assert(customArgs.add.disabled(), "Already-added items must not be added twice")
customArgs["item:100"].args.remove.func()
assert(not profile.customEssentialItems[100]
  and not getOptions().args.inventory.args.listviewBag.args.essentials.args.customItems.args["item:100"],
  "Removing a custom Essential must remove its saved rule and options row")
customArgs.search.set(nil, "absent")
assert(customArgs.results.disabled() and customArgs.add.disabled())
SlackHacks.db.profile.listviewBag = otherProfile
assert(customArgs.search.get() == "", "Search state must not leak between profiles")
SlackHacks.db.profile.listviewBag = profile
C_Container, C_Item = previousContainer, previousItem

-- Both the portrait menu and Ace options use the same auto-sell confirmation.
SlackHacks.db.profile.inventory = { autoSellGreyItems = true }
profile.autoSellMarkedItems = true
profile.trackCrestCurrencies = true
--- Select the Retail client for the crest checkbox.
---@return boolean retailClient
function SlackHacks.isRetail() return true end
GameTooltip = { Hide = function() end }
StaticPopupDialogs = {}
local popup
--- Capture the confirmation and its profile.
---@param kind string Popup identifier.
---@param _ any Unused text argument.
---@param __ any Unused text argument.
---@param data table Profile captured by the popup.
---@return table dialog Mock dialog.
function StaticPopup_Show(kind, _, __, data) popup = { kind = kind, data = data }; return popup end
local menuEntries = {}
MenuUtil = {
  CreateContextMenu = function(anchor, build)
    menuEntries = {}
    local root = {
      CreateButton = function(_, text, select)
        menuEntries[text] = { select = select }
      end,
      CreateCheckbox = function(_, text, checked, select)
        local entry = { checked = checked, select = select }
        function entry:SetEnabled(value) self.enabled = value end
        menuEntries[text] = entry
        return entry
      end,
    }
    build(anchor, root)
  end,
}
local buildFrame = upvalue(module.OnEnable, "buildFrame")
local openBagSettings = upvalue(buildFrame, "openBagSettingsMenu")
local originalOpenOptions = SlackHacks.openOptions
local openedGroup
SlackHacks.openOptions = function(...) openedGroup = { ... } end
local switched
upvalue(openBagSettings, "setShowListviewBag", function(value) switched = value end)
local footerRefreshes = 0
function module:RefreshFooter() footerRefreshes = footerRefreshes + 1 end
openBagSettings({})
assert(menuEntries["Switch back to default bags"] and menuEntries["Track Crest Currencies"].checked()
  and menuEntries["Auto-Sell Junk"].checked())
menuEntries["Open Settings"].select()
assert(openedGroup[1] == "inventory" and openedGroup[2] == "listviewBag")
menuEntries["Switch back to default bags"].select()
assert(switched == false)
menuEntries["Track Crest Currencies"].select()
assert(not profile.trackCrestCurrencies and footerRefreshes == 1)
menuEntries["Auto-Sell Junk"].select()
assert(not profile.autoSellMarkedItems and SlackHacks.db.profile.inventory.autoSellGreyItems)
assert(popup.kind == "SLACKHACKS_DISABLE_AUTO_SELL_GREYS", "Disabling must ask about the separate grey option")
-- Dismissing the prompt leaves the independent grey option enabled.
profile.autoSellMarkedItems = true
local autoOption = getOptions().args.inventory.args.listviewBag.args.autoSellMarkedItems
autoOption.set(nil, false)
StaticPopupDialogs.SLACKHACKS_DISABLE_AUTO_SELL_GREYS.OnAccept(nil, popup.data)
assert(not profile.autoSellMarkedItems and not SlackHacks.db.profile.inventory.autoSellGreyItems)

profile.autoSellMarkedItems = true
SlackHacks.db.profile.inventory.autoSellGreyItems = true
autoOption.set(nil, false)
profile.autoSellMarkedItems = true
SlackHacks.prn = function() end
StaticPopupDialogs.SLACKHACKS_DISABLE_AUTO_SELL_GREYS.OnAccept(nil, popup.data)
assert(SlackHacks.db.profile.inventory.autoSellGreyItems, "A stale prompt must not change a re-enabled setting")

local legacy
MenuUtil = nil
--- Capture the legacy settings menu.
---@param entries table Menu entries.
function EasyMenu(entries) legacy = entries end
openBagSettings({})
assert(legacy[1].text == "Switch back to default bags" and legacy[2].text == "Track Crest Currencies"
  and legacy[3].text == "Auto-Sell Junk" and legacy[4].text == "Open Settings")
openedGroup = nil
legacy[4].func()
assert(openedGroup[1] == "inventory" and openedGroup[2] == "listviewBag")
profile.enabled = false
openedGroup = nil
legacy[4].func()
assert(not openedGroup, "A disabled module must not open settings from a stale menu")
profile.enabled = true
SlackHacks.openOptions = originalOpenOptions
legacy[2].func()
assert(profile.trackCrestCurrencies and footerRefreshes == 2)
SlackHacks.isRetail = function() return false end
openBagSettings({})
assert(legacy[2].disabled, "Crest tracking must be unavailable outside Retail")
legacy[2].func()
assert(profile.trackCrestCurrencies and footerRefreshes == 2)

local nativeMenus = {}
Menu = { ModifyMenu = function(tag, builder) nativeMenus[tag] = builder end }
local installBagMenuOptions = upvalue(module.OnEnable, "installBagMenuOptions")
installBagMenuOptions()
for _, tag in ipairs({ "MENU_CONTAINER_FRAME", "MENU_CONTAINER_FRAME_COMBINED" }) do
  local label
  local root = {
    CreateDivider = function() end,
    CreateButton = function(_, text) label = text end,
  }
  nativeMenus[tag](nil, root)
  assert(label == "Switch to SlackHacks' Listview Bag")
  profile.enabled = false
  label = nil
  nativeMenus[tag](nil, root)
  assert(not label, "Disabled modules must not add native bag menu actions")
  profile.enabled = true
end

-- Group navigation must open rather than toggle closed on every settings backend.
local selected, openedCategory, hiddenPanel, openedDialog, closedDialog
local dialog = {
  OpenFrames = { SlackHacks = { IsShown = function() return true end } },
  SelectGroup = function(_, ...) selected = { ... } end,
  Open = function(_, name) openedDialog = name end,
  Close = function(_, name) closedDialog = name end,
}
SlackHacks.LibStub = function(name)
  assert(name == "AceConfigDialog-3.0")
  return dialog
end
local inCombat = false
--- Supply the combat state for settings-panel fallback.
---@return boolean locked Whether the player is in combat.
function InCombatLockdown() return inCombat end
SettingsPanel = { IsShown = function() return true end }
--- Record a request to hide the modern settings panel.
---@param panel table Panel to hide.
function HideUIPanel(panel) hiddenPanel = panel end
Settings = { OpenToCategory = function(category) openedCategory = category end }
SlackHacks.configCategoryID = 19
SlackHacks.openOptions("inventory", "listviewBag")
assert(selected[1] == "SlackHacks" and selected[2] == "inventory" and selected[3] == "listviewBag"
  and openedCategory == 19 and not hiddenPanel)
SlackHacks.openOptions()
assert(hiddenPanel == SettingsPanel, "The existing settings toggle must still close an open panel")

SettingsPanel, Settings = nil, nil
SlackHacks.configDialog = {}
InterfaceOptionsFrame = { IsShown = function() return true end, Hide = function() hiddenPanel = "legacy" end }
--- Record the legacy settings category opened.
---@param category table Category to open.
function InterfaceOptionsFrame_OpenToCategory(category) openedCategory = category end
openedCategory, hiddenPanel = nil, nil
SlackHacks.openOptions("inventory", "listviewBag")
assert(openedCategory == SlackHacks.configDialog and not hiddenPanel)
SlackHacks.openOptions()
assert(hiddenPanel == "legacy", "The legacy settings toggle must still close an open panel")

inCombat = true
SlackHacks.openOptions("inventory", "listviewBag")
assert(openedDialog == "SlackHacks", "Group navigation in combat must open the standalone dialog")
SlackHacks.openOptions()
assert(closedDialog == "SlackHacks", "The standalone settings toggle must still close an open dialog")

-- Exercise real AceDB defaults and logout/reload with a pre-existing profile.
UnitFactionGroup = function() return "Alliance" end
GetLocale = function() return "enUS" end
UnitClass = function() return "Mage", "MAGE" end
UnitRace = function() return "Human", "Human" end
GetRealmName = function() return "Realm" end
UnitNameUnmodified = function() return "Player" end
GetCurrentRegionName = function() return "US" end
GetCurrentRegion = function() return 1 end
strlenutf8 = string.len
local dbFrame = { scripts = {}, RegisterEvent = function() end }
--- Capture AceDB's logout handler.
---@param event string Script name.
---@param handler function Script callback.
function dbFrame:SetScript(event, handler) self.scripts[event] = handler end
CreateFrame = function() return dbFrame end
assert(loadfile("Libs/Ace3/AceDB-3.0/AceDB-3.0.lua"))()
local saved = { profiles = { Default = { listviewBag = {
  enabled = true, categoryFilters = { special = false }, trashItems = { retained = true },
} } } }
local aceDB = LibStub("AceDB-3.0")
local oldDB = SlackHacks.db
SlackHacks.db = aceDB:New(saved, SlackHacks.dbDefaults, true)
local savedBag = SlackHacks.db.profile.listviewBag
assert(not savedBag.categoryFilters.special and savedBag.trashItems.retained
  and not savedBag.essentialItems.arrows and not savedBag.essentialItems.soulShards)
local persistedOptions = getOptions().args.inventory.args.listviewBag.args.essentials.args
assert(persistedOptions["item:6948"].get(), "Existing profiles must keep built-in Essentials enabled")
persistedOptions["item:6948"].set(nil, false)
persistedOptions.arrows.set(nil, true)
savedBag.customEssentialItems[100] = { name = "Healing Herb", link = "healing-link", icon = 1000 }
dbFrame.scripts.OnEvent(dbFrame, "PLAYER_LOGOUT")
SlackHacks.db = aceDB:New(saved, SlackHacks.dbDefaults, true)
savedBag = SlackHacks.db.profile.listviewBag
assert(savedBag.essentialItems[6948] == false and savedBag.essentialItems.arrows
  and savedBag.customEssentialItems[100].link == "healing-link"
  and not savedBag.categoryFilters.special and savedBag.trashItems.retained,
  "Custom settings must persist across logout without changing existing profile settings")
SlackHacks.db = oldDB
print("Listview bag vendor options tests passed")
