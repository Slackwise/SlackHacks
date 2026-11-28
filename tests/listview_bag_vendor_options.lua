-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_vendor_options.lua

local profile = {
  enabled = true, showReagentBagContents = true, autoDepositBankItems = false,
  protectedItems = {}, trashItems = {}, trashItemsOnce = {},
  auctionItems = {}, auctionItemsOnce = {}, bankItems = {}, bankItemsOnce = {},
}
SlackHacks = setmetatable({ db = { profile = { listviewBag = profile } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ItemClass = {}, ItemQuality = { Common = 1 } }
UIParent = {}

--- Supply the bag module.
---@return table module
function SlackHacks:NewModule() return { IsEnabled = function() return true end } end
assert(loadfile("InventoryLog.lua"))()
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
local junkVariantKey = upvalue(collectGroups, "junk").variantKey
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
local exactKey = junkVariantKey(link, 3, 10, nil)
local legacy = { name = "Marked Item", quality = 3, itemLevel = 10 }
profile.trashItems[key] = legacy
local groups = collectGroups()
assert(groups[1].statusInfo.link == link and groups[1].statusInfo.icon == 123)
assert(legacy.link == link and legacy.icon == 123, "Matching legacy entries must recover the exact item")
assert(profile.trashItems[exactKey] == legacy and not profile.trashItems[key],
  "Recovered Junk marks must be moved to their exact item-variant key.")
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
local bagOptions = getOptions().args.inventory.args.listviewBag.args
local tinderOption = bagOptions.essentials.args["item:4471"]
assert(tinderOption and tinderOption.get()
  and not SlackHacks.dbDefaults.profile.listviewBag.essentialItems.arrows
  and not SlackHacks.dbDefaults.profile.listviewBag.essentialItems.soulShards,
  "Built-in Essentials must include Flint and Tinder and keep consumed exceptions disabled by default")
SlackHacks.db.profile.listviewBag.essentialItems[4471] = false
assert(not tinderOption.get(), "The restored Essentials option must preserve an existing saved opt-out")
SlackHacks.db.profile.listviewBag.essentialItems[4471] = nil
assert(not bagOptions.autoAHMode and SlackHacks.dbDefaults.profile.listviewBag.autoAHMode == nil,
  "Selling View's Auction House behavior must not require a saved mode option")
local inventoryOptions = getOptions().args.inventory.args
local logGroup = inventoryOptions.inventoryLog
local logOption = logGroup.args.enabled
SlackHacks.db.profile.inventory = { inventoryLogEnabled = false }
assert(logGroup.name == "Inventory Log" and logGroup.order < inventoryOptions.listviewBag.order
  and logOption.name == "Enable Inventory Log Module" and not logOption.get()
  and SlackHacks.dbDefaults.profile.inventoryLog.enabled == false)
assert(logGroup.args.entriesToKeep.get() == "3000" and logGroup.args.entriesToKeep.validate(nil, "12") == true
  and logGroup.args.entriesToKeep.validate(nil, "1.5") ~= true and logGroup.args.entriesToKeep.disabled())
for _, action in ipairs(SlackHacks.InventoryLog.ACTIONS) do
  assert(logGroup.args.actionsToLog.args[action.id].get())
end
assert(logGroup.args.actionsToLog.args.Purchased.get(), "Vendor purchases must be selectable and enabled by default")
assert(not logGroup.args.actionsToLog.args.Used and not logGroup.args.actionsToLog.args.Unknown
  and logGroup.args.actionsToLog.args.Created.get(),
  "Used and Unknown must not be recording options; Created must remain enabled by default")
logGroup.args.actionsToLog.args.Sold.set(nil, false)
assert(not logGroup.args.actionsToLog.args.Sold.get() and logGroup.args.actionsToLog.args.Looted.get(),
  "Recording checkboxes must capture independent action keys")
local originalRequestClear, requestedClear = SlackHacks.InventoryLog.RequestClearLog, false
--- Capture the clear action without creating native frames.
function SlackHacks.InventoryLog:RequestClearLog() requestedClear = true end
logGroup.args.clearLog.func()
assert(requestedClear and not logGroup.args.clearLog.disabled, "Clear Log must remain available while disabled")
SlackHacks.InventoryLog.RequestClearLog = originalRequestClear
local originalSetLogging = SlackHacks.InventoryLog.SetLoggingEnabled
--- Record the Options toggle's delegation without initializing the inventory fixture.
---@param enabled boolean Logging preference.
function SlackHacks.InventoryLog:SetLoggingEnabled(enabled)
  SlackHacks.InventoryLog:GetSettings().enabled = enabled
end
logOption.set(nil, true)
assert(logOption.get(), "Options must delegate to the same logging preference used by bag menus")
SlackHacks.InventoryLog.SetLoggingEnabled = originalSetLogging
profile.trashItems.old = { name = "Marked Item", quality = 2, itemLevel = 1 }
profile.trashItems.uncached = { name = "Uncached" }
profile.trashItems.clear = true
local variantLink = "|cff0070dd|Hitem:42:123:0:0|h[Marked Item]|h|r"
local variant = junkVariantKey(variantLink, 3, 10, nil)
profile.trashItems[variant] = { name = "Marked Item", link = variantLink, icon = 123 }
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
local row = args[optionKey(exactKey)]
assert(row.type == "group" and row.inline and row.name == "")
assert(row.args.item.type == "description" and row.args.item.dialogControl == "InteractiveLabel"
  and row.args.item.name == "|T123:18:18|t " .. link and row.args.item.tooltipHyperlink == link)
assert(row.args.remove.type == "execute" and row.args.remove.name == "Remove"
  and row.args.item.order < row.args.remove.order
  and row.args.item.width == "relative" and type(row.args.remove.width) == "number"
  and row.args.remove.width * 170 >= 85
  and row.args.item.relWidth * 250 + row.args.remove.width * 170 <= 250,
  "Each item must have a sufficiently wide remove button to its right")
assert(args[optionKey("old")].args.item.name == "|T123:18:18|t " .. baseLink
  and args[optionKey("old")].args.item.tooltipHyperlink == baseLink and args.legacyInfo)
assert(args[optionKey("uncached")].args.item.name == "Uncached"
  and not args[optionKey("uncached")].args.item.tooltipHyperlink)
assert(args[optionKey("clear")].args.item.name == "clear", "Legacy keys must not collide with the clear button")
assert(args[optionKey(variant)].args.item.name == "|T123:18:18|t " .. variantLink
  and args[optionKey(variant)].args.item.tooltipHyperlink == variantLink,
  "Distinct item-link modifiers must have separate Junk entries.")
args[optionKey(variant)].args.remove.func()
assert(not profile.trashItems[variant] and profile.trashItems[exactKey],
  "Removing one copy's flag must not remove the other")
refreshes = 0
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
assert(not profile.trashItems.old and profile.trashItems[exactKey] == legacy and refreshes == 1)
assert(not getOptions().args.inventory.args.listviewBag.args.autoVendorItems.args[optionKey("old")],
  "Deleting an item must remove its row from the options")
args[optionKey(exactKey)].args.remove.func()
assert(not profile.trashItems[key] and profile.trashItems.uncached and profile.protectedItems.keep and refreshes == 2,
  "Deleting a linked item must leave other items and protection flags untouched")

local list = profile.trashItems
args.clear.func()
assert(next(list) == nil and profile.trashItems == list and profile.protectedItems.keep)
assert(refreshes == 3 and getOptions().args.inventory.args.listviewBag.args.autoVendorItems.args.clear.disabled())
assert(getOptions().args.inventory.args.listviewBag.args.autoVendorItemsOnce == nil,
  "One-time Junk marks must not have an options list.")

local auctionKey = "Auction Item\0313\03110\031"
local auctionLink = "|cff0070dd|Hitem:43:0:0:0|h[Auction Item]|h|r"
profile.auctionItems[auctionKey] = {
  name = "Auction Item", link = auctionLink, icon = 124,
}
local auctionGroup = getOptions().args.inventory.args.listviewBag.args.autoAuctionItems
local auctionArgs = auctionGroup.args
assert(auctionGroup.inline and auctionArgs.clear.confirm
  and auctionArgs[optionKey(auctionKey)].args.item.tooltipHyperlink == auctionLink,
  "Auction Always marks must appear in their own options group.")
auctionArgs[optionKey(auctionKey)].args.remove.func()
assert(not profile.auctionItems[auctionKey] and refreshes == 4,
  "Auction Always marks must be removable from Options.")

local bankKey = "Bank Item\0313\03110\031"
local bankLink = "|cff0070dd|Hitem:44:0:0:0|h[Bank Item]|h|r"
profile.bankItems[bankKey] = { name = "Bank Item", link = bankLink, icon = 125 }
local bankGroup = getOptions().args.inventory.args.listviewBag.args.autoBankItems
local bankArgs = bankGroup.args
assert(bankGroup.inline and bankArgs.clear.confirm
  and bankArgs[optionKey(bankKey)].args.item.tooltipHyperlink == bankLink,
  "Bank Always marks must appear in their own options group.")
bankArgs.clear.func()
assert(not next(profile.bankItems) and refreshes == 5,
  "The Bank Always list must support clearing from Options.")

-- Essentials settings preserve the existing defaults and allow inventory-backed custom items.
local bagOptions = getOptions().args.inventory.args.listviewBag.args
local autoDeposit = bagOptions.autoDepositBankItems
assert(autoDeposit.name == "Auto-Deposit Bank Flagged Items" and autoDeposit.get() == false
  and autoDeposit.order < bagOptions.autoSellMarkedItems.order)
autoDeposit.set(nil, true)
assert(profile.autoDepositBankItems)
autoDeposit.set(nil, false)
local essentials = bagOptions.essentials
assert(essentials.inline and essentials.name == '"Essentials" Filter Items'
  and essentials.order > bagOptions.autoBankItems.order)
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
assert(not customArgs.empty.hidden() and customArgs.results.style == "radio" and customArgs.results.hidden(),
  "Custom Essentials must show an empty list and use a search-result list rather than a dropdown")
assert(customArgs.search.dialogControl == "SlackHacksEssentialSearch")

local registerSearchControl = upvalue(SlackHacks.registerOptions, "registerEssentialSearchControl")
local constructors = {}
local fakeGUI = {}
--- Check whether a test widget was registered.
---@param kind string Widget type.
---@return number|nil version Registered version.
function fakeGUI:GetWidgetVersion(kind) return constructors[kind] and 1 end
--- Capture a widget constructor.
---@param kind string Widget type.
---@param constructor function Widget constructor.
function fakeGUI:RegisterWidgetType(kind, constructor) constructors[kind] = constructor end
--- Create a mock AceGUI edit box.
---@return table widget Mock edit box.
function fakeGUI:Create()
  local editbox = { focused = false, cursor = 0 }
  --- Return whether the edit box has focus.
  ---@return boolean focused Focus state.
  function editbox:HasFocus() return self.focused end
  --- Return the cursor position.
  ---@return number position Cursor position.
  function editbox:GetCursorPosition() return self.cursor end
  --- Update the cursor position.
  ---@param value number Cursor position.
  function editbox:SetCursorPosition(value) self.cursor = value end
  local widget = { editbox = editbox, events = {}, userdata = {} }
  --- Reset the mock widget for use.
  function widget:OnAcquire() end
  --- Record whether the confirmation button is disabled.
  ---@param value boolean Disabled state.
  function widget:DisableButton(value) self.buttonDisabled = value end
  --- Register a widget event.
  ---@param event string Event name.
  ---@param callback function Event callback.
  function widget:SetCallback(event, callback) self.events[event] = callback end
  --- Read a widget userdata value.
  ---@param key string Userdata key.
  ---@return any value Stored value.
  function widget:GetUserData(key) return self.userdata[key] end
  --- Give the edit box focus.
  function widget:SetFocus() self.editbox.focused = true end
  --- Fire a registered widget event.
  ---@param event string Event name.
  ---@param ... any Event arguments.
  ---@return any result Callback result.
  function widget:Fire(event, ...) return self.events[event](self, event, ...) end
  return widget
end
SlackHacks.LibStub = function(name)
  assert(name == "AceGUI-3.0")
  return fakeGUI
end
registerSearchControl()
registerSearchControl()
SlackHacks.LibStub = nil
local root = {}
local replacement
local commit
commit = function(widget, _, value)
  customArgs.search.set(nil, value)
  widget.editbox.focused = false
  replacement = constructors.SlackHacksEssentialSearch()
  replacement:OnAcquire()
  replacement.userdata.rootframe = root
  replacement:SetCallback("OnEnterPressed", commit)
end
local live = constructors.SlackHacksEssentialSearch()
live:OnAcquire()
live.userdata.rootframe = root
live:SetCallback("OnEnterPressed", commit)
live.editbox.focused, live.editbox.cursor = true, 3
live:Fire("OnTextChanged", "her")
assert(customArgs.search.get() == "her" and not customArgs.results.hidden()
  and replacement.editbox.focused and replacement.editbox.cursor == 3 and replacement.buttonDisabled,
  "Typing must update results immediately and restore focus and cursor after the panel rebuilds")
replacement.editbox.cursor = 8
replacement:Fire("OnTextChanged", "healing ")
assert(customArgs.search.get() == "healing " and customArgs.results.get() == 100
  and replacement.editbox.focused and replacement.editbox.cursor == 8,
  "Typing must preserve spaces and continue working after a rebuild")
replacement.editbox.focused = false
replacement:Fire("OnTextChanged", "ignored")
assert(customArgs.search.get() == "healing ", "Programmatic text changes must not start a search")

customArgs.search.set(nil, "  HeRb  ")
local values = customArgs.results.values()
local sorting = customArgs.results.sorting()
assert(values[100] and values[101] and values[102] and values[104] and not values[103]
  and #sorting == 4 and sorting[1] == 100 and sorting[2] == 104 and sorting[3] == 102 and sorting[4] == 101)
assert(not customArgs.results.disabled() and not customArgs.results.hidden()
  and customArgs.add.disabled() and not globalSearchChanged,
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
  and customArgs["item:100"].args.item.tooltipHyperlink == "healing-link"
  and customArgs["item:100"].order < customArgs.divider.order
  and customArgs.divider.type == "header" and customArgs.divider.order < customArgs.searchHint.order
  and customArgs["item:100"].args.remove.name == "Remove" and customArgs.empty.hidden(),
  "Saved custom items must appear as removable rows separated from the search controls")
customArgs.results.set(nil, 100)
assert(customArgs.add.disabled(), "Already-added items must not be added twice")
customArgs.search.set(nil, "herb")
customArgs.results.set(nil, 101)
customArgs.add.func()
customArgs = getOptions().args.inventory.args.listviewBag.args.essentials.args.customItems.args
assert(customArgs["item:100"] and customArgs["item:101"], "Each saved custom item must have its own row")
customArgs["item:100"].args.remove.func()
assert(not profile.customEssentialItems[100] and profile.customEssentialItems[101]
  and not getOptions().args.inventory.args.listviewBag.args.essentials.args.customItems.args["item:100"],
  "Removing a custom Essential must remove only its saved rule and options row")
customArgs["item:101"].args.remove.func()
assert(getOptions().args.inventory.args.listviewBag.args.essentials.args.customItems.args.empty.hidden() == false,
  "The empty-list message must return after removing the last item")
customArgs.search.set(nil, "absent")
assert(customArgs.results.disabled() and customArgs.add.disabled())

SlackHacks.db.profile.listviewBag = profile
SlackHacks.db.profile.listviewBag = otherProfile
assert(customArgs.search.get() == "", "Search state must not leak between profiles")
SlackHacks.db.profile.listviewBag = profile
C_Container, C_Item = previousContainer, previousItem

-- Both the portrait menu and Ace options use the same auto-sell confirmation.
SlackHacks.db.profile.inventory = { autoSellGreyItems = true }
profile.autoSellMarkedItems = true
profile.trackCrestCurrencies = true
--- Select the Retail client for the settings menu.
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
        local entry = { select = select }
        function entry:CreateRadio(label, checked, choose)
          menuEntries[label] = { checked = checked, select = choose }
        end
        menuEntries[text] = entry
        return entry
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
openBagSettings({})
assert(menuEntries["Switch back to default bags"] and menuEntries["Auto-Sell Junk"].checked()
  and not menuEntries["Footer Display"] and not menuEntries.Crests and not menuEntries.Supplies)
local depositMenu = menuEntries["Auto-Deposit Bank Items"]
assert(depositMenu and not depositMenu.checked())
depositMenu.select()
assert(profile.autoDepositBankItems and autoDeposit.get(),
  "The menu must enable the existing auto-deposit option.")
local originalBankFrame, originalDeposit = BankFrame, module.DepositBankFlaggedItems
local deposits = 0
BankFrame = { IsShown = function() return true end }
module.DepositBankFlaggedItems = function() deposits = deposits + 1 end
depositMenu.select()
assert(not profile.autoDepositBankItems and deposits == 0)
autoDeposit.set(nil, true)
assert(depositMenu.checked() and deposits == 1,
  "Enabling auto-deposit through Options must update the menu and deposit at an open bank.")
depositMenu.select()
depositMenu.select()
assert(profile.autoDepositBankItems and deposits == 2,
  "Enabling auto-deposit through the menu must also deposit at an open bank.")
autoDeposit.set(nil, false)
BankFrame, module.DepositBankFlaggedItems = originalBankFrame, originalDeposit
menuEntries["Open Settings"].select()
assert(openedGroup[1] == "inventory" and openedGroup[2] == "listviewBag")
menuEntries["Switch back to default bags"].select()
assert(switched == false)
assert(not getOptions().args.inventory.args.listviewBag.args.footerDisplay,
  "Ace options must not expose the removed footer preference")
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
assert(legacy[1].text == "Switch back to default bags"
  and legacy[2].text == "Auto-Deposit Bank Items"
  and legacy[3].text == "Auto-Sell Junk" and legacy[4].text == "Open Inventory Log"
  and legacy[5].text == "Open Settings" and not legacy[6])
assert(legacy[2].isNotRadio and legacy[2].keepShownOnClick and not legacy[2].checked())
legacy[2].func()
assert(profile.autoDepositBankItems and autoDeposit.get(),
  "The legacy menu must toggle the same auto-deposit setting.")
openedGroup = nil
legacy[5].func()
assert(openedGroup[1] == "inventory" and openedGroup[2] == "listviewBag")
profile.enabled = false
openedGroup = nil
legacy[5].func()
legacy[2].func()
assert(not openedGroup, "A disabled module must not open settings from a stale menu")
assert(profile.autoDepositBankItems, "A disabled module must not toggle auto-deposit from a stale menu")
profile.enabled = true
autoDeposit.set(nil, false)
SlackHacks.openOptions = originalOpenOptions
SlackHacks.isRetail = function() return false end
openBagSettings({})
assert(legacy[2].text == "Auto-Deposit Bank Items"
  and legacy[3].text == "Auto-Sell Junk" and legacy[4].text == "Open Inventory Log"
  and legacy[5].text == "Open Settings",
  "Other clients must not offer the removed footer choice")
assert(profile.trackCrestCurrencies, "Removing the footer choice must not alter saved preferences")

local nativeMenus = {}
Menu = { ModifyMenu = function(tag, builder) nativeMenus[tag] = builder end }
local installBagMenuOptions = upvalue(module.OnEnable, "installBagMenuOptions")
installBagMenuOptions()
YES, NO = "Yes", "No"
local originalEnabled, originalEnable, originalNotice = module.IsEnabled, module.Enable, SlackHacks.prn
local active, enableCalls, notices = true, 0, {}
--- Track actual module state independently of saved settings.
---@return boolean enabled Module state.
function module:IsEnabled() return active end
--- Capture confirmed module activation and its normal view-opening lifecycle.
function module:Enable() active = true; enableCalls = enableCalls + 1; switched = true end
--- Capture rejected confirmations and unavailable native popups.
---@param message string Failure message.
function SlackHacks.prn(message) notices[#notices + 1] = message end
for _, tag in ipairs({ "MENU_CONTAINER_FRAME", "MENU_CONTAINER_FRAME_COMBINED" }) do
  local label, actions = nil, {}
  local root = {
    CreateDivider = function() end,
    CreateTitle = function(_, text) assert(text == "|cffffd100SlackHacks|r") end,
    CreateCheckbox = function() error("The Inventory Log menu must not add a checkbox") end,
    --- Capture both bag and ledger entry points.
    ---@param text string Button label.
    ---@param select function Click callback.
    CreateButton = function(_, text, select)
      actions[text] = select
      if text ~= "Open Inventory Log" then label = text end
    end,
  }
  nativeMenus[tag](nil, root)
  assert(label == "Switch to Listview Bag")
  profile.enabled, profile.showListviewBag, active, switched, popup = true, false, true, false, nil
  actions[label]()
  assert(switched and profile.showListviewBag and not popup,
    "An enabled Listview Bag must switch views without an enable confirmation")
  profile.enabled = false
  profile.showListviewBag, active, switched, popup = false, false, false, nil
  label = nil
  nativeMenus[tag](nil, root)
  assert(label == "Switch to Listview Bag", "Blizzard's menu must remain available without replacement bags")
  actions[label]()
  assert(popup.kind == "SLACKHACKS_ENABLE_LISTVIEW_BAG"
    and StaticPopupDialogs[popup.kind].button2 == NO
    and not profile.enabled and not profile.showListviewBag and not active and not switched,
    "Declining an enable offer must leave the module and Blizzard bag view unchanged")
  local callsBefore = enableCalls
  StaticPopupDialogs[popup.kind].OnAccept(nil, popup.data)
  assert(profile.enabled and profile.showListviewBag and active and switched and enableCalls == callsBefore + 1,
    "Accepting must enable Listview Bag and open its view")
  profile.enabled, profile.showListviewBag, switched, popup = false, false, false, nil
  actions[label]()
  assert(popup and not profile.enabled and not switched,
    "A disabled saved setting must require confirmation even if the module is still active")
  StaticPopupDialogs[popup.kind].OnAccept(nil, popup.data)
  assert(profile.enabled and profile.showListviewBag and switched and enableCalls == callsBefore + 1,
    "Confirming an already active module must show its view without restarting it")
  profile.enabled, profile.showListviewBag, active = false, false, false
  actions[label]()
  local offer, oldProfile, noticeCount = popup.data, SlackHacks.db.profile, #notices
  SlackHacks.db.profile = { listviewBag = { enabled = false, showListviewBag = false } }
  StaticPopupDialogs[popup.kind].OnAccept(nil, offer)
  assert(not SlackHacks.db.profile.listviewBag.enabled and enableCalls == callsBefore + 1
    and #notices == noticeCount + 1, "A stale offer must not enable replacement bags in a new profile")
  SlackHacks.db.profile = oldProfile
  oldProfile.listviewBag = { enabled = false, showListviewBag = false }
  noticeCount = #notices
  StaticPopupDialogs[popup.kind].OnAccept(nil, offer)
  assert(not oldProfile.listviewBag.enabled and enableCalls == callsBefore + 1
    and #notices == noticeCount + 1, "Replacing settings within the same profile must invalidate a prior enable offer")
  oldProfile.listviewBag = profile
  local showPopup = StaticPopup_Show
  --- Simulate failure to display the native enable confirmation.
  function StaticPopup_Show() return nil end
  noticeCount = #notices
  actions[label]()
  assert(not profile.enabled and not profile.showListviewBag and enableCalls == callsBefore + 1
    and #notices == noticeCount + 1, "A missing confirmation must report failure without enabling or switching bags")
  StaticPopup_Show = showPopup
  profile.enabled, active = true, true
end
module.IsEnabled, module.Enable, SlackHacks.prn = originalEnabled, originalEnable, originalNotice

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
  and not savedBag.essentialItems.arrows and not savedBag.essentialItems.soulShards
  and not savedBag.autoDepositBankItems,
  "Existing profiles must keep auto-deposit disabled by default")
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

-- Exercise the production startup block before AceDB fills defaults, including already-current v18 saves.
local startupFile = assert(io.open("Init.lua"))
local startupSource = startupFile:read("*a")
startupFile:close()
local startupStart = assert(startupSource:find("function Self:OnInitialize()", 1, true))
local startupEnd = assert(startupSource:find("  -- One-time nudge", startupStart, true))
local initializeSavedSettings = assert(loadstring(startupSource:sub(startupStart, startupEnd - 1) .. "\nend"))
setfenv(initializeSavedSettings, SlackHacks)
initializeSavedSettings()
local oldSaved = _G.SlackHacksDB
_G.SlackHacksDB = {
  global = { configVersion = 18 },
  profiles = {
    Default = { inventory = { inventoryLogEnabled = true, autoRepair = true } },
    Explicit = { inventory = { inventoryLogEnabled = true },
      inventoryLog = { enabled = false, entriesToKeep = 17, actionsToLog = { Sold = false } } },
    Other = { inventory = { inventoryLogEnabled = true } },
  },
}
SlackHacks:OnInitialize()
assert(SlackHacks.InventoryLog:IsLoggingEnabled() and SlackHacks.db.profile.inventory.autoRepair
  and SlackHacks.db.profile.inventory.inventoryLogEnabled == nil,
  "Materialized AceDB defaults must not erase a saved v18 opt-in")
SlackHacks.db:SetProfile("Explicit")
assert(not SlackHacks.InventoryLog:IsLoggingEnabled() and SlackHacks.InventoryLog:GetSettings().entriesToKeep == 17
  and SlackHacks.InventoryLog:GetSettings().actionsToLog.Sold == false
  and SlackHacks.InventoryLog:GetSettings().actionsToLog.Looted == true
  and SlackHacks.InventoryLog:GetSettings().actionsToLog.Purchased == true,
  "Explicit new settings and wildcard action defaults must survive startup")
SlackHacks.db:SetProfile("Other")
assert(SlackHacks.InventoryLog:IsLoggingEnabled(), "Inactive profiles must also preserve legacy opt-in")
dbFrame.scripts.OnEvent(dbFrame, "PLAYER_LOGOUT")
SlackHacks:OnInitialize()
assert(SlackHacks.InventoryLog:IsLoggingEnabled(), "Migrated opt-in must persist across logout/reload")
SlackHacks.db, _G.SlackHacksDB = oldDB, oldSaved
print("Listview bag vendor options tests passed")
