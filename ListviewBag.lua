setfenv(1, _G.SlackHacks)

--[[
  ListviewBag: a simplified, sortable list-view alternative to the default grid-style bag window.
  Reuses Blizzard's own bag data APIs (C_Container) and as many native widgets/templates as possible
  (NineSlicePanelTemplate border, UIPanelCloseButton, UICheckButtonTemplate, UIPanelScrollFrameTemplate,
  StackSplitFrame) so the window looks/feels like a first-party Blizzard panel. Row buttons use
  Blizzard's ContainerFrameItemButtonTemplate for native item click/use behavior; custom row visuals
  sit around that button while its Blizzard click handler remains intact.
]]--

local module = Self:NewModule("ListviewBag", "AceEvent-3.0")
Self.ListviewBag = module
local gear = Self.ListviewBagGear

--=====================================================================
-- Constants
--=====================================================================

local FRAME_NAME = "SlackHacksListviewBagFrame"
-- Blizzard's ContainerFrame_IsReagentBag uses container ID 5; Enum.BagIndex has no ReagentBag field.
local REAGENT_BAG_ID = 5
local ROW_HEIGHT = 20
local COLLAPSE_WIDTH = ROW_HEIGHT
local STATUS_WIDTH = 20
local CELL_PAD = 4
local WINDOW_WIDTH = 700 -- must comfortably fit every fixed column + the name column's minimum width,
                         -- or trailing columns (e.g. Bind) get clipped outside the scroll frame's bounds
local WINDOW_HEIGHT = 460 -- a bit taller than before to make room for the search box row
local SORT_ARROW_TEXTURE = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"

-- Reorderable columns (Collapse/expand and Lock/Trash status are pinned to the far left and are not
-- part of this list -- reordering them away from the row's leading edge would be confusing).
local COLUMN_DEFS = {
  quantity =  { label = "Qty",   width = 36 },
  name =      { label = "Name",  width = 200, flexible = true },
  ilvl =      { label = "iLvl",  width = 60 },
  upgrade =   { label = "Upgrade", width = 185 },
  vendor =    { label = "Vendor", width = 52 },
  auction =   { label = "Auction", width = 105 },
  armorType = { label = "Type",  width = 70 },
  armorSlot = { label = "Slot",  width = 70 },
  bind =      { label = "|TInterface\\AddOns\\SlackHacks\\Assets\\bind-icons-texture:18:18:0:0:128:64:6:26:7:28|t", width = 24 },
}
local DEFAULT_COLUMN_ORDER = { "quantity", "name", "ilvl", "armorType", "armorSlot", "bind" }
local VIEWS = {
  { id = "default", name = "Default View" },
  { id = "selling", name = "Selling View" },
  { id = "gear", name = "Gear View" },
}

-- English-only track-name recognizer used to pull the gear "track" (e.g. "Champion 5/6") out of the
-- tooltip, since there is no direct API exposing it -- this is a deliberate, documented simplification.
local TRACK_NAMES = { Explorer = true, Adventurer = true, Veteran = true, Champion = true, Hero = true, Myth = true, Awakened = true }

local ARMOR_CLASS_ID = (Enum.ItemClass and Enum.ItemClass.Armor) or 4
local PROJECTILE_CLASS_ID = (Enum.ItemClass and Enum.ItemClass.Projectile) or 6
local ARROW_SUBCLASS_ID = 2
local SHOT_SUBCLASS_ID = 3
-- These Forever classes can learn both bows and guns, even before training the individual skill.
local RANGED_AMMO_CLASSES = { HUNTER = true, ROGUE = true, WARRIOR = true }
-- Monks can use mana as Mistweavers; hunters use mana in Forever but focus on Retail.
local MANA_CLASSES = {
  DRUID = true, EVOKER = true, MAGE = true, MONK = true, PALADIN = true,
  PRIEST = true, SHAMAN = true, WARLOCK = true,
}
local sortColumn
local sortAscending = true
local temporaryView
local ahMode = false
local ahModeBeforeAuction

local function sortValueBefore(left, right)
  if left == right then return nil end
  if sortAscending then return left < right end
  return left > right
end

local PROTECT_ICON_ATLAS = "ui-castingbar-shield"
local PROTECT_STATUS = { id = "protect", name = "Protect", field = "protectedItems", atlas = PROTECT_ICON_ATLAS, sortOrder = 5 }
local ITEM_STATUSES = {
  { id = "vendor", name = "Junk", field = "trashItems", atlas = "bags-junkcoin", sortOrder = 1 },
  { id = "auction", name = "Auction", field = "auctionItems", icon = "Interface\\Minimap\\Tracking\\Auctioneer", sortOrder = 2 },
  PROTECT_STATUS,
  { id = "bank", name = "Bank", field = "bankItems", icon = "Interface\\Minimap\\Tracking\\Banker", sortOrder = 4 },
  { id = "mail", name = "Mail", field = "mailItems", icon = "Interface\\Minimap\\Tracking\\Mailbox", sortOrder = 3 },
}
local ITEM_CATEGORIES = {
  { id = "equipment", name = "Equipment" },
  { id = "consumables", name = "Consumables" },
  { id = "professionGoods", name = "Profession Goods" },
  { id = "junk", name = "Junk" },
  { id = "quest", name = "Quest Items" },
  { id = "reagents", name = "Reagents" },
  -- Preserve the saved key when changing the displayed name.
  { id = "special", name = "Essentials" },
  { id = "other", name = "Other" },
}
local BINDING_FILTERS = {
  { id = "unbound", name = "Unbound" },
  { id = "soulbound", name = "Soulbound" },
  { id = "warbound", name = "Warbound", retailOnly = true },
}
-- These edible Forever fish can also be crafting reagents; item class alone cannot distinguish them
-- from inedible fish. Keep the IDs independent of localized item names.
local FOREVER_EDIBLE_RAW_FISH_IDS = {
  [4603] = true, -- Raw Spotted Yellowtail
  [6289] = true, -- Raw Longjaw Mud Snapper
  [6291] = true, -- Raw Brilliant Smallfish
  [6299] = true, -- Sickly Looking Fish
  [6303] = true, -- Raw Slitherskin Mackerel
  [6308] = true, -- Raw Bristle Whisker Catfish
  [6317] = true, -- Raw Loch Frenzy
  [6361] = true, -- Raw Rainbow Fin Albacore
  [6362] = true, -- Raw Rockscale Cod
  [6458] = true, -- Oil Covered Fish
  [6522] = true, -- Deviate Fish
  [8365] = true, -- Raw Mithril Head Trout
  [12238] = true, -- Darkshore Grouper
  [13754] = true, -- Raw Glossy Mightfish
  [13755] = true, -- Raw Winter Squid
  [13756] = true, -- Raw Summer Bass
  [13758] = true, -- Raw Redgill
  [13759] = true, -- Raw Nightfin Snapper
  [13760] = true, -- Raw Sunscale Salmon
  [13888] = true, -- Darkclaw Lobster
  [13889] = true, -- Raw Whitescale Salmon
  [13893] = true, -- Large Raw Mightfish
  [21071] = true, -- Raw Sagefish
  [21153] = true, -- Raw Greater Sagefish
}
module.ESSENTIAL_ITEMS = {
  { id = 6948, name = "Hearthstone" },
  { id = 211527, name = "Cozy Sleeping Bag" },
  { id = 280612, name = "Night Watchman's Torch" },
  { id = 2901, name = "Mining Pick" },
  { id = 7005, name = "Skinning Knife" },
  { id = 5956, name = "Blacksmith Hammer" },
  { id = 6219, name = "Arclight Spanner" },
  { id = 10498, name = "Gyromatic Micro-Adjustor" },
  { id = 4471, name = "Flint and Tinder" },
  { id = 6256, name = "Fishing Pole" },
  { id = 20815, name = "Jeweler's Toolset" },
  { id = 20824, name = "Simple Grinder" },
  { id = 40892, name = "Hammer Pick" },
  { id = 40893, name = "Bladed Pickaxe" },
  { id = 40772, name = "Gnomish Army Knife" },
  { id = 6218, name = "Runed Copper Rod" },
  { id = 6339, name = "Runed Silver Rod" },
  { id = 11130, name = "Runed Golden Rod" },
  { id = 11145, name = "Runed Truesilver Rod" },
  { id = 16207, name = "Runed Arcanite Rod" },
}
local ESSENTIAL_ITEM_IDS = {}
for _, item in ipairs(module.ESSENTIAL_ITEMS) do ESSENTIAL_ITEM_IDS[item.id] = true end
local SOUL_SHARD_ITEM_ID = 6265
-- Potion subclasses do not distinguish health from mana. Supplement the shared best-use lists
-- without changing the potions selected by those bindings; rejuvenation potions belong to both.
-- Item IDs are maintained from Warcraft Wiki's healing, mana, and rejuvenation potion categories.
local ADDITIONAL_HEALTH_POTIONS = {
  [4596] = true, -- Discolored / Minor Discolored Healing Potion
  [247239] = true, [247240] = true, [247241] = true, [247242] = true, [241650] = true, -- Forever discolored potions
  [169451] = true, [136569] = true, [127834] = true, -- Abyssal, Aged, Ancient
  [43531] = true, [32947] = true, [32905] = true, -- Argent, Auchenai, Nethergon Vapor
  [142325] = true, [167917] = true, [18839] = true, -- Brawler's Ancient/Coastal, Combat
  [187802] = true, [33934] = true, [124660] = true, -- Cosmic, Crystal, Darkmoon
  [43569] = true, [175241] = true, [124661] = true, -- Endless, Expedition, Gladiator's
  [33092] = true, [109223] = true, [64994] = true, -- Injector, Healing Tonic, Hellscream's
  [180317] = true, [144396] = true, -- Soulful, Valorous
  [241298] = true, [241299] = true, -- Amani Extract
  [244835] = true, [244838] = true, [244839] = true, -- Invigorating
  [241304] = true, [241305] = true, -- Silvermoon
  [271883] = true, [271884] = true, -- Concentrated Silvermoon
}
local ADDITIONAL_MANA_POTIONS = {
  [43530] = true, [32948] = true, [63145] = true, -- Argent, Auchenai, Baradin's
  [32783] = true, [32909] = true, [32902] = true, -- Blue Ogre Brew, Special, Nethergon Energy
  [18841] = true, [109226] = true, [43570] = true, -- Combat, Draenic Channeled, Endless
  [64993] = true, [40067] = true, [31855] = true, -- Hellscream's, Icy, Major Combat
  [152495] = true, [57194] = true, [168502] = true, -- Coastal, Concentration, Reconstitution
  [180318] = true, [28101] = true, -- Soulful, Unstable
  [212245] = true, [212246] = true, [212247] = true, -- Slumbering Soul Serum
  [241300] = true, [241301] = true, [245916] = true, [245917] = true, -- Lightfused and Fleeting
  [241294] = true, [241295] = true, [245904] = true, [245905] = true, -- Devoured Dreams and Fleeting
}
local REJUVENATION_POTIONS = {
  [2456] = true, [9144] = true, -- Minor Rejuvenation, Wildvine
  [12190] = true, [20002] = true, [22836] = true, -- Dreamless Sleep potions
  [22850] = true, [34440] = true, [40077] = true, -- Super Rejuvenation, Mad and Crazy Alchemist's
  [40081] = true, [40087] = true, [44698] = true, -- Nightmares, Powerful Rejuvenation, Intravenous
  [57099] = true, [57193] = true, [67415] = true, -- Mysterious, Mighty Rejuvenation, Draught of War
  [76094] = true, [113585] = true, [163082] = true, -- Alchemist's, Iron Horde, Coastal
  [171269] = true, [241306] = true, [241307] = true, -- Spiritual, Refreshing Serum
}
-- Forever may report older bandages as generic consumables rather than the Retail subclass.
local ADDITIONAL_BANDAGES = {
  [19307] = true, -- Alterac Heavy Runecloth Bandage
  [20065] = true, [20066] = true, [20067] = true, -- Arathi Basin bandages
  [20232] = true, [20234] = true, [20235] = true, -- Defiler's bandages
  [20237] = true, [20243] = true, [20244] = true, -- Highlander's bandages
  [19066] = true, [19067] = true, [19068] = true, -- Warsong Gulch bandages
  [232433] = true, -- Dense Runecloth Bandage
}
local EQUIPMENT_SLOTS = {
  INVTYPE_HEAD = true, INVTYPE_NECK = true, INVTYPE_SHOULDER = true, INVTYPE_BODY = true,
  INVTYPE_CHEST = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
  INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
  INVTYPE_WEAPON = true, INVTYPE_SHIELD = true, INVTYPE_RANGED = true, INVTYPE_CLOAK = true,
  INVTYPE_2HWEAPON = true, INVTYPE_TABARD = true, INVTYPE_ROBE = true, INVTYPE_WEAPONMAINHAND = true,
  INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true, INVTYPE_THROWN = true, INVTYPE_RANGEDRIGHT = true,
}

local BIND_ICON_TEXTURE = "Interface\\AddOns\\SlackHacks\\Assets\\bind-icons-texture"
local CREST_CURRENCY_IDS = { 3446, 3445, 3444, 3443, 3442 }
local SUPPLY_MARGIN = 8
local FOOTER_ICON_SIZE = 16
local FOOTER_ICON_GAP = 2

--=====================================================================
-- Small helpers
--=====================================================================

-- Tracks which SplitStack closures are already our own auto-place wrapper, so re-hooking
-- OnModifiedClick on every click doesn't wrap an already-wrapped function again.
local autoPlaceSplitStacks = setmetatable({}, { __mode = "k" })

--- Return the backpack, equipped bags, and the modern client's reagent bag.
---@return table bagIDs Container IDs used for display and bag actions.
local function bagIDs()
  local ids = { 0, 1, 2, 3, 4 }
  if isRetailOrForever() then
    ids[#ids + 1] = REAGENT_BAG_ID
  end
  return ids
end

--- Find distinct inventory items whose names contain the entered text.
---@param query string Search text.
---@return table items Matching item metadata, keyed by item ID.
---@return boolean incomplete Whether any item names are still unavailable.
function module:SearchInventoryItems(query)
  local items, incomplete = {}, false
  local search = query:lower()
  if search == "" then return items, incomplete end
  for _, bagID in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID and not items[info.itemID] then
        local name, link, icon = info.itemName, info.hyperlink, info.iconFileID
        if not name or not link or not icon then
          local cachedName, cachedLink, _, _, _, _, _, _, _, cachedIcon = C_Item.GetItemInfo(link or info.itemID)
          name, link, icon = name or cachedName, link or cachedLink, icon or cachedIcon
        end
        if not name then
          incomplete = true
        elseif name:lower():find(search, 1, true) then
          items[info.itemID] = { name = name, link = link, icon = icon }
        end
      end
    end
  end
  return items, incomplete
end

local legacyMailWarnings = setmetatable({}, { __mode = "k" })

--- Convert the earlier single one-time amount into a queue without creating a default recipient.
---@param bag table Saved profile bag settings.
function module:MigrateLegacyMailAmounts(bag)
  local amounts = rawget(bag, "mailAmounts")
  if type(amounts) ~= "table" then return end
  local assignments = rawget(bag, "mailAssignments")
  local queues = rawget(bag, "mailQueues")
  for key, amount in pairs(amounts) do
    local recipient = type(assignments) == "table" and assignments[key]
    if recipient and type(amount) == "table" and type(amount.remaining) == "number" and amount.remaining > 0 then
      if not queues then queues = {}; bag.mailQueues = queues end
      queues[key] = queues[key] or {}
      table.insert(queues[key], 1, { recipient = recipient, remaining = amount.remaining })
      assignments[key], amounts[key] = nil, nil
    elseif not legacyMailWarnings[bag] then
      legacyMailWarnings[bag] = true
      prn("a saved one-time mail assignment could not be migrated; its original data was retained.")
    end
  end
  if not next(amounts) then bag.mailAmounts = nil end
end

--- Return bag settings, initializing optional status lists in older profiles.
---@return table settings Current profile's bag settings.
local function settings()
  local listviewSettings = db.profile.listviewBag
  for _, status in ipairs(ITEM_STATUSES) do
    listviewSettings[status.field] = listviewSettings[status.field] or {}
  end
  listviewSettings.flagFilters = listviewSettings.flagFilters or {}
  listviewSettings.bindingFilters = listviewSettings.bindingFilters or {}
  listviewSettings.categoryFilters = listviewSettings.categoryFilters or {}
  listviewSettings.mailRecipients = listviewSettings.mailRecipients or {}
  listviewSettings.mailAssignments = listviewSettings.mailAssignments or {}
  -- Development builds may already have config v16, so also migrate on profile access.
  module:MigrateLegacyMailAmounts(listviewSettings)
  listviewSettings.mailQueues = listviewSettings.mailQueues or {}
  listviewSettings.essentialItems = listviewSettings.essentialItems or {}
  listviewSettings.customEssentialItems = listviewSettings.customEssentialItems or {}
  local columnOrder = listviewSettings and listviewSettings.columnOrder
  if columnOrder then
    for index = #columnOrder, 1, -1 do
      if columnOrder[index] == "quality" then
        table.remove(columnOrder, index)
      end
    end
  end
  return listviewSettings
end

--- Return the selected view, treating older profiles as the default view.
---@return string view View identifier.
local function selectedView()
  local view = temporaryView or settings().view
  for _, entry in ipairs(VIEWS) do
    if entry.id == view then return view end
  end
  return "default"
end

--- Derive view-specific columns without changing the saved default column order.
---@return table columns Active column identifiers.
local function activeColumns()
  local columns = {}
  local view = selectedView()
  for _, id in ipairs(settings().columnOrder or DEFAULT_COLUMN_ORDER) do
    if id == "ilvl" and view == "selling" then
      columns[#columns + 1] = "vendor"
      columns[#columns + 1] = "auction"
    else
      if id == "ilvl" and view == "gear" then columns[#columns + 1] = "upgrade" end
      columns[#columns + 1] = id
    end
  end
  return columns
end

--- Return the item's selected status, prioritizing non-junk flags for older overlapping marks.
---@param key string Item status key.
---@param quality number|nil Item quality, if known.
---@return table|nil status Selected status definition.
local function getItemStatus(key, quality)
  local listviewSettings = settings()
  if listviewSettings.protectedItems[key] ~= nil then return PROTECT_STATUS end
  if quality == 0 then return nil end
  for index = 2, #ITEM_STATUSES do
    local status = ITEM_STATUSES[index]
    if listviewSettings[status.field][key] ~= nil then return status end
  end
  if listviewSettings.trashItems[key] ~= nil then return ITEM_STATUSES[1] end
end

--- Check both the saved setting and the actual Ace module state.
---@return boolean enabled Whether Listview Bag behavior is active.
local function isModuleEnabled()
  return settings().enabled and module:IsEnabled()
end

local function itemStatusKey(itemName, quality, itemLevel, upgradeTrack)
  return table.concat({ itemName or "", quality or 0, itemLevel or 0, upgradeTrack or "" }, "\031")
end

--- Check whether a flag prevents vendor sales.
---@param key string Item status key.
---@return boolean protected Whether the item is protected.
local function isProtectedItem(key)
  local listviewSettings = settings()
  return listviewSettings.protectedItems[key] ~= nil or listviewSettings.bankItems[key] ~= nil
    or listviewSettings.auctionItems[key] ~= nil or listviewSettings.mailItems[key] ~= nil
end

local function isTrashItem(key)
  return settings().trashItems[key] ~= nil
end

--=====================================================================
-- Item inspection (bind label + gear track use the tooltip since neither is exposed by a direct API)
--=====================================================================

-- A hidden GameTooltip used purely to read text lines off a bag item -- the classic, universally-
-- compatible scanning technique (SetBagItem + numbered TextLeft FontStrings) instead of the newer
-- C_TooltipInfo API, since that one's availability/shape can't be confirmed on this bleeding-edge
-- interface version and silently returning nothing would make every bind/track lookup go blank.
local scanTooltip = CreateFrame("GameTooltip", "SlackHacksListviewBagScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function scanBagItemLines(bagID, slot)
  local lines = {}
  local ok = pcall(function()
    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bagID, slot)
    for i = 1, scanTooltip:NumLines() do
      local fs = _G["SlackHacksListviewBagScanTooltipTextLeft" .. i]
      if fs then
        lines[#lines + 1] = fs:GetText()
      end
    end
  end)
  if not ok then
    return {}
  end
  return lines
end

-- Reads the bag item's tooltip and looks for one of Blizzard's own localized bind-status lines. This
-- is more reliable than guessing at Enum.ItemBind values (which vary by bind type/expansion) since it
-- reuses the exact strings the tooltip itself would show, and is automatically correct for any locale.
local function getBindInfo(bagID, slot, itemLink)
  local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
  local bindType = select(14, C_Item.GetItemInfo(itemLink))
  local accountBound = false
  for _, text in ipairs(scanBagItemLines(bagID, slot)) do
    if text == ITEM_SOULBOUND then
      return "Soulbound", bindType, false, itemInfo and itemInfo.isBound
    elseif text == ITEM_ACCOUNTBOUND or text == ITEM_BIND_TO_ACCOUNT or text == ITEM_BNETACCOUNTBOUND
      or text == ITEM_BIND_TO_BNETACCOUNT or text == ITEM_ACCOUNTBOUND_UNTIL_EQUIP
      or text == ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP or text == ITEM_BNETACCOUNTBOUND_UNTIL_EQUIP then
      accountBound = true
    end
  end
  if accountBound then
    return "Warbound", bindType, true, itemInfo and itemInfo.isBound
  end
  if bindType == 1 then
    return "Soulbound", bindType, false, itemInfo and itemInfo.isBound
  elseif bindType == 2 then
    return "BoE", bindType, false, itemInfo and itemInfo.isBound
  elseif bindType == 3 then
    return "BoU", bindType, false, itemInfo and itemInfo.isBound
  elseif bindType == 4 then
    return "Quest", bindType, false, itemInfo and itemInfo.isBound
  end
  return "", bindType, false, itemInfo and itemInfo.isBound
end

-- Extracts the upgrade track (e.g. "Champion 5/6") from the tooltip. There's no direct API for
-- this -- every addon that shows it does the same tooltip-line scan.
local function getUpgradeTrack(bagID, slot)
  for _, text in ipairs(scanBagItemLines(bagID, slot)) do
    local plainText = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local track, cur, max = plainText:match("(%a+)%s+(%d+)%s*/%s*(%d+)")
    if track and TRACK_NAMES[track] then
      return track:sub(1, 1):upper() .. cur
    end
  end
  return nil
end

--=====================================================================
-- Row data collection
--=====================================================================

--- Group items from all available bags, including the reagent bag.
---@return table groups Combined item rows and their underlying bag slots.
-- Walks every tracked bag slot and groups identical items (same hyperlink) into one combined row, the
-- same way the default UI's "combined bags" view merges stacks together. Each group remembers every
-- underlying bagID/slot ("entries") so actions (locking, dragging, splitting) can still reach the real
-- item(s) once expanded.
local function collectGroups()
  local groups, order = {}, {}
  for _, bagID in ipairs(bagIDs()) do
    local numSlots = C_Container.GetContainerNumSlots(bagID)
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID and not info.isFiltered then
        local bindLabel, bindType, accountBound, isBound = getBindInfo(bagID, slot, info.hyperlink)
        local binding = accountBound and isRetail() and "warbound"
          or (isBound or accountBound) and "soulbound" or "unbound"
        -- Copies with the same link can have different binding states and filter eligibility.
        local key = tostring(info.hyperlink or info.itemID) .. "\031" .. binding
          .. (info.isBound and "\031bound" or "\031unbound")
        local group = groups[key]
        if not group then
          group = {
            key = key,
            itemID = info.itemID,
            hyperlink = info.hyperlink,
            itemName = info.itemName,
            icon = info.iconFileID,
            quality = info.quality,
            bindLabel = bindLabel,
            bindType = bindType,
            accountBound = accountBound,
            isBound = isBound,
            binding = binding,
            count = 0,
            entries = {},
          }
          groups[key] = group
          order[#order + 1] = group
        end
        group.count = group.count + (info.stackCount or 1)
        group.entries[#group.entries + 1] = { bagID = bagID, slot = slot, count = info.stackCount or 1, isBound = info.isBound }
      end
    end
  end

  -- Decorate each group with the details that need a slower lookup (GetItemInfo/tooltip), using the
  -- group's first entry as the representative bag slot for bind/track text.
  for _, group in ipairs(order) do
    local itemName, itemLink, quality, itemLevel, _, itemType, itemSubType, _, itemEquipLoc, _, sellPrice,
      classID, subclassID, _, _, _, isCraftingReagent = C_Item.GetItemInfo(group.hyperlink)
    group.itemName = itemName or group.itemName
    group.quality = group.quality or quality
    if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
      local ok, craftedQuality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, group.hyperlink)
      group.craftedQuality = ok and craftedQuality or nil
    end
    local qualityInfo = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo
      and C_TradeSkillUI.GetItemReagentQualityInfo(group.itemID)
    group.qualityAtlas = qualityInfo and qualityInfo.iconChat
      or group.craftedQuality and group.craftedQuality > 0
      and "Professions-Icon-Quality-12-Tier" .. group.craftedQuality .. "-Inv"
    local first = group.entries[1]
    group.itemLevel = C_Item.GetDetailedItemLevelInfo(group.hyperlink) or itemLevel
    group.upgradeTrack = first and getUpgradeTrack(first.bagID, first.slot) or nil
    group.isArmor = classID == ARMOR_CLASS_ID
    group.isEquipment = (classID == ARMOR_CLASS_ID or classID == 2) and EQUIPMENT_SLOTS[itemEquipLoc]
    group.classID, group.subclassID, group.equipLoc, group.sellPrice, group.isCraftingReagent =
      classID, subclassID, itemEquipLoc, sellPrice, isCraftingReagent
    if group.isArmor or (selectedView() == "gear" and group.isEquipment) then
      group.armorType = itemSubType
      group.armorSlot = itemEquipLoc and _G[itemEquipLoc]
    end
    if selectedView() == "gear" and gear then
      group.comparisons, group.itemStats = gear.CompareItem(group.hyperlink, itemEquipLoc)
    elseif selectedView() == "selling" and Self.ListviewBagAuction and not group.isBound and not group.accountBound then
      group.auction = Self.ListviewBagAuction.GetQuote(group.hyperlink, function()
        if module.Refresh then module:Refresh() end
      end)
    end
    group.statusKey = itemStatusKey(group.itemName, group.quality, group.itemLevel, group.upgradeTrack)
    if sortColumn == "flag" then
      local status = getItemStatus(group.statusKey, group.quality)
      group.flagSortOrder = status and status.sortOrder or 0
    end
    group.statusInfo = {
      name = group.itemName,
      quality = group.quality,
      itemLevel = group.itemLevel,
      upgradeTrack = group.upgradeTrack,
      link = group.hyperlink,
      icon = group.icon,
    }
    -- Older saved entries lack links; recover the exact variant when it is seen in a bag.
    local savedTrash = settings().trashItems[group.statusKey]
    if type(savedTrash) == "table" and not savedTrash.link and group.hyperlink then
      savedTrash.link = group.hyperlink
      savedTrash.icon = group.icon
    end
  end

  table.sort(order, function(a, b)
    if not a or not b then return a ~= nil end
    local result
    if sortColumn == "quantity" then
      result = sortValueBefore(a.count, b.count)
    elseif sortColumn == "name" then
      result = sortValueBefore((a.itemName or ""):lower(), (b.itemName or ""):lower())
    elseif sortColumn == "ilvl" then
      result = sortValueBefore(a.itemLevel or 0, b.itemLevel or 0)
    elseif sortColumn == "armorType" then
      result = sortValueBefore(a.armorType or "", b.armorType or "")
    elseif sortColumn == "armorSlot" then
      result = sortValueBefore(a.armorSlot or "", b.armorSlot or "")
    elseif sortColumn == "bind" then
      result = sortValueBefore(a.bindLabel or "", b.bindLabel or "")
    elseif sortColumn == "vendor" then
      result = sortValueBefore(a.sellPrice or 0, b.sellPrice or 0)
    elseif sortColumn == "auction" then
      result = sortValueBefore(a.auction and a.auction.minimum or 0, b.auction and b.auction.minimum or 0)
    elseif sortColumn == "upgrade" then
      local ap, as, bp, bs = 0, 0, 0, 0
      for _, comparison in ipairs(a.comparisons or {}) do
        ap, as = ap + comparison.primary, as + comparison.secondary
      end
      for _, comparison in ipairs(b.comparisons or {}) do
        bp, bs = bp + comparison.primary, bs + comparison.secondary
      end
      result = sortValueBefore(ap, bp) or (ap == bp and sortValueBefore(as, bs))
    elseif sortColumn == "flag" then
      result = sortValueBefore(a.flagSortOrder, b.flagSortOrder)
    else
      if a.quality ~= b.quality then return (a.quality or -1) > (b.quality or -1) end
    end
    if result ~= nil then return result end
    return (a.itemName or "") < (b.itemName or "")
  end)

  return order
end

--=====================================================================
-- Frame construction (declared up front, built lazily the first time the module is enabled)
--=====================================================================

local frame, content, scrollFrame, scrollChild, headerFrame, footer, searchBox
local headerButtons = {}
local columnLayout = {}
local rowPool = {}
local expandedGroups = {}
local bagKeyBindingButton
local layoutHeaders, renderRows, positionRowCells, layoutFrame
local updateAuctionView
local sellMarkedTrashItems, updateMerchantJunkButton
-- Tracked from MERCHANT_SHOW/MERCHANT_CLOSED rather than MerchantFrame:IsShown(), because Blizzard's
-- frame may not have shown/hidden yet when our handler for the same event runs.
local merchantOpen = false
local mailOpen = false
local auctionOpen = false
local bankOpen = false
local guildBankOpen = false
local trackedCursorItem

--- Return the fixed width for a column in the selected client and view.
---@param colID string Column identifier.
---@param view string View identifier.
---@param forever boolean Whether the Forever client is active.
---@param retail boolean Whether the Retail client is active.
---@return number width Column width.
local function fixedColumnWidth(colID, view, forever, retail)
  local width = COLUMN_DEFS[colID].width
  if view == "gear" and (colID == "armorType" or colID == "armorSlot") then width = 52 end
  if forever then
    local reclaimed = COLUMN_DEFS.ilvl.width / 2
    if colID == "ilvl" then return reclaimed end
    if view == "gear" and colID == "upgrade" or view == "selling" and colID == "vendor" then
      return width + reclaimed
    end
  elseif retail and view == "gear" then
    local reclaimed = COLUMN_DEFS.ilvl.width * 0.3
    if colID == "ilvl" then return width - reclaimed end
    if colID == "upgrade" then return width + reclaimed end
  end
  return width
end

--- Distribute column widths, giving the name column the remaining space.
local function computeLayout()
  local contentWidth = scrollChild:GetWidth()
  local fixedWidth = 0
  local columns = activeColumns()
  local view = selectedView()
  local forever = isForever()
  local retail = isRetail()
  for _, colID in ipairs(columns) do
    local def = COLUMN_DEFS[colID]
    if not def.flexible then
      local width = fixedColumnWidth(colID, view, forever, retail)
      fixedWidth = fixedWidth + width + CELL_PAD
    end
  end
  local minimumName = view == "gear" and 115 or COLUMN_DEFS.name.width
  local flexWidth = math.max(minimumName, contentWidth - COLLAPSE_WIDTH - STATUS_WIDTH - fixedWidth - CELL_PAD)

  local x = COLLAPSE_WIDTH + CELL_PAD
  columnLayout = {}
  for _, colID in ipairs(columns) do
    local def = COLUMN_DEFS[colID]
    local width = def.flexible and flexWidth or fixedColumnWidth(colID, view, forever, retail)
    columnLayout[colID] = { x = x, width = width }
    x = x + width + CELL_PAD
  end
end

-- Column headers are draggable buttons; dropping one near another header swaps their order. This is a
-- simple "closest header wins" reorder (no drag ghost) rather than a fully animated reflow, per the
-- "simplest implementation" guidance.
local draggingColumn

--- Select a sort column or reverse its current direction.
---@param colID string Column identifier.
local function selectSortColumn(colID)
  if sortColumn == colID then
    sortAscending = not sortAscending
  else
    sortColumn = colID
    sortAscending = true
  end
  renderRows()
end

local function onHeaderDragStart(self)
  if selectedView() ~= "default" then return end
  draggingColumn = self.columnID
end

local function onHeaderDragStop(self)
  if not draggingColumn then return end
  local order = settings().columnOrder
  local myIndex
  for i, id in ipairs(order) do
    if id == draggingColumn then myIndex = i end
  end
  if myIndex then
    local cursorX = GetCursorPosition() / (self:GetEffectiveScale())
    local bestIndex, bestDist = myIndex, nil
    for i, id in ipairs(order) do
      local btn = headerButtons[id]
      local left = btn:GetLeft()
      if left then
        local center = left + btn:GetWidth() / 2
        local dist = math.abs(center - cursorX)
        if not bestDist or dist < bestDist then
          bestDist, bestIndex = dist, i
        end
      end
    end
    if bestIndex ~= myIndex then
      table.remove(order, myIndex)
      table.insert(order, bestIndex, draggingColumn)
      layoutHeaders()
      renderRows()
    end
  end
  draggingColumn = nil
end

layoutHeaders = function()
  computeLayout()

  -- Blizzard's own ColumnDisplayMixin:LayoutColumns() (confirmed via SharedUIPanelTemplates.lua) builds
  -- and positions the header buttons itself (BOTTOMLEFT-chained, real "ColumnDisplayButtonTemplate" art)
  -- -- reused directly instead of hand-positioning plain buttons, which is what didn't look right before.
  local columnInfo = {}
  local order = activeColumns()
  for index, colID in ipairs(order) do
    local width = columnLayout[colID].width
    if index < #order then
      width = width + CELL_PAD + 2
    end
    columnInfo[#columnInfo + 1] = { title = COLUMN_DEFS[colID].label, width = width }
  end
  headerFrame:LayoutColumns(columnInfo)

  -- LayoutColumns sets each header's ID to its 1-based position in columnInfo -- used here (rather than
  -- relying on the FramePool's active-object iteration order, which isn't guaranteed) to reattach our
  -- own column identity and drag-to-reorder scripts on top of Blizzard's real header buttons.
  wipe(headerButtons)
  for header in headerFrame.columnHeaders:EnumerateActive() do
    local colID = order[header:GetID()]
    header.columnID = colID
    if not header.sortIcon then
      header.sortIcon = header:CreateTexture(nil, "OVERLAY")
      header.sortIcon:SetTexture(SORT_ARROW_TEXTURE)
      header.sortIcon:SetSize(10, 10)
      header.sortIcon:SetPoint("RIGHT", header, "RIGHT", -3, 0)
    end
    header.sortIcon:SetShown(sortColumn == colID)
    if sortColumn == colID then
      header.sortIcon:SetRotation(sortAscending and math.pi / 2 or -math.pi / 2)
    end
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", onHeaderDragStart)
    header:SetScript("OnDragStop", onHeaderDragStop)
    headerButtons[colID] = header
  end
  local flagSortIcon = content.statusHeaderButton.sortIcon
  flagSortIcon:SetShown(sortColumn == "flag")
  if sortColumn == "flag" then
    flagSortIcon:SetRotation(sortAscending and math.pi / 2 or -math.pi / 2)
  end
end

--=====================================================================
-- Row widgets
--=====================================================================

--- Classify an item for the bag filters and mail summaries.
---@param group table Collected item and its metadata.
---@param bag table|nil Current bag settings, if already available.
---@return string category Item category identifier.
local function itemCategory(group, bag)
  -- The game does not expose its sorter classification. Resolve overlapping item properties
  -- in priority order, independently of which filters are enabled.
  bag = bag or settings()
  if bag.customEssentialItems[group.itemID]
    or (ESSENTIAL_ITEM_IDS[group.itemID] and bag.essentialItems[group.itemID] ~= false)
    or (group.itemID == SOUL_SHARD_ITEM_ID and bag.essentialItems.soulShards)
    or (group.classID == PROJECTILE_CLASS_ID and group.subclassID == ARROW_SUBCLASS_ID and bag.essentialItems.arrows) then
    return "special"
  elseif (FOREVER_EDIBLE_RAW_FISH_IDS[group.itemID]
    or (group.classID == PROJECTILE_CLASS_ID and group.subclassID == ARROW_SUBCLASS_ID)) and isForever() then
    return "consumables"
  elseif group.classID == 12 or group.bindType == 4 then
    return "quest"
  elseif group.quality == 0 and group.sellPrice ~= nil then
    return "junk"
  elseif group.isCraftingReagent then
    return "reagents"
  elseif EQUIPMENT_SLOTS[group.equipLoc] or (group.equipLoc == "INVTYPE_RELIC" and not isRetailOrForever()) then
    return "equipment"
  elseif group.classID == 0 then
    return "consumables"
  elseif group.classID == 7 then
    return "professionGoods"
  end
  return "other"
end

--- Check an item against the selected flag, binding, and item-category filters.
---@param group table Collected item and its metadata.
---@return boolean matches Whether the item is visible.
local function matchesFilters(group)
  local bag = settings()
  local status = getItemStatus(group.statusKey, group.quality)
  if bag.flagFilters[status and status.id or "unflagged"] == false then return false end
  local binding = group.binding or (group.accountBound and isRetail() and "warbound")
    or (group.isBound or group.accountBound) and "soulbound" or "unbound"
  if bag.bindingFilters[binding] == false then return false end
  local category = itemCategory(group, bag)
  if category == "consumables" and FOREVER_EDIBLE_RAW_FISH_IDS[group.itemID] and isForever() then
    return bag.categoryFilters.consumables ~= false or bag.categoryFilters.reagents ~= false
  end
  return bag.categoryFilters[category] ~= false
end

--- Check whether a flag prevents auctioning through the list view.
---@param key string Item status key.
---@param quality number|nil Item quality.
---@param bag table Current bag settings.
---@return boolean blocked Whether an auction is blocked.
local function isAuctionBlocked(key, quality, bag)
  return bag.protectedItems[key] ~= nil
    or quality ~= 0 and (bag.bankItems[key] ~= nil or bag.mailItems[key] ~= nil)
end

--- Check whether the client can validate individual auction items.
---@return boolean available Whether auction eligibility can be checked.
local function auctionEligibilityAvailable()
  return C_AuctionHouse and type(C_AuctionHouse.IsSellItemValid) == "function"
    and ItemLocation and type(ItemLocation.CreateFromBagAndSlot) == "function" or false
end

--- Keep only bag slots that Blizzard considers eligible for auction.
---@param group table Collected item and its bag entries.
---@return boolean eligible Whether the group has any sellable entries.
local function filterAuctionEntries(group)
  if group.isBound or group.accountBound or type(group.sellPrice) ~= "number" or group.sellPrice <= 0
    or isAuctionBlocked(group.statusKey, group.quality, settings()) then return false end
  local entries, count = {}, 0
  for _, entry in ipairs(group.entries) do
    local location = ItemLocation:CreateFromBagAndSlot(entry.bagID, entry.slot)
    if location:IsValid() and C_AuctionHouse.IsSellItemValid(location, false) then
      entries[#entries + 1] = entry
      count = count + entry.count
    end
  end
  group.entries, group.count = entries, count
  return #entries > 0
end

--- Initialize the additive gear-filter settings for existing profiles.
---@return table filters Gear filter settings.
local function gearFilters()
  local bag = settings()
  bag.gearFilters = bag.gearFilters or {}
  local filters = bag.gearFilters
  filters.types = filters.types or {}
  filters.slots = filters.slots or {}
  filters.stats = filters.stats or {}
  return filters
end

--- Check a gear item against its type, slot, stat, and downgrade filters.
---@param group table Collected item and comparisons.
---@return boolean matches Whether the item is visible in Gear view.
local function matchesGearFilters(group)
  if not gear or not gear.GetSlots(group.equipLoc) then return false end
  local filters = gearFilters()
  local typeKey = tostring(group.classID) .. ":" .. tostring(group.subclassID)
  if filters.types[typeKey] == false or filters.slots[group.equipLoc] == false then return false end
  if filters.downgradeOnly and not gear.IsDowngrade(group.comparisons) then return false end
  if next(filters.stats) then
    local anySelected = false
    for key, value in pairs(group.itemStats or {}) do
      if type(value) == "number" and value ~= 0 and filters.stats[key] ~= false then
        anySelected = true
        break
      end
    end
    if not anySelected then return false end
  end
  return true
end

local refreshMailSendButton

--- Replace an item's status while retaining the metadata used by vendor matching.
---@param key string Item status key.
---@param statusInfo table Item metadata to save.
---@param selected table|nil Status definition, or nil to clear.
local function setItemStatus(key, statusInfo, selected)
  if not isModuleEnabled() then return end
  if selected and (statusInfo.quality == nil or (statusInfo.quality == 0 and selected ~= PROTECT_STATUS)) then
    prn(statusInfo.quality == 0 and "grey items can only be protected." or "item quality is not yet available.")
    return
  end
  if selected == PROTECT_STATUS and statusInfo.quality == 0
    and (not statusInfo.name or statusInfo.itemLevel == nil) then
    prn("item information is not yet available; try protecting it again.")
    return
  end
  local listviewSettings = settings()
  for _, status in ipairs(ITEM_STATUSES) do
    listviewSettings[status.field][key] = nil
  end
  listviewSettings.mailAssignments[key] = nil
  listviewSettings.mailQueues[key] = nil
  local legacy = rawget(listviewSettings, "mailAmounts")
  if type(legacy) == "table" then legacy[key] = nil end
  if selected then listviewSettings[selected.field][key] = statusInfo end
  if refreshMailSendButton then refreshMailSendButton() end
  renderRows()
  updateMerchantJunkButton()
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- Return the blocked interaction for this flag and the currently open windows.
---@param key string Item status key.
---@param quality number|nil Item quality.
---@return string|nil action Blocked action, or nil if interaction is allowed.
local function blockedItemAction(key, quality)
  if not isModuleEnabled() then return nil end
  local bag = settings()
  local protected = bag.protectedItems[key] ~= nil or (quality ~= 0 and bag.bankItems[key] ~= nil)
  local auction = quality ~= 0 and bag.auctionItems[key] ~= nil
  local mail = quality ~= 0 and bag.mailItems[key] ~= nil
  if merchantOpen and (protected or auction or mail) then
    return "vendoring"
  end
  if auctionOpen and isAuctionBlocked(key, quality, bag) then
    return "auctioning"
  end
  if mailOpen and protected then
    return "mailing"
  end
  if (bankOpen or guildBankOpen) and mail then
    return "banking"
  end
end

--- Remember an item picked up through a list-view row.
---@param row table Item row at the time of pickup.
local function rememberPickedUpItem(row)
  if not isModuleEnabled() then return end
  local cursorType, _, link = GetCursorInfo()
  if cursorType == "item" and link and link == row.hyperlink then
    trackedCursorItem = { key = row.statusKey, quality = row.statusInfo.quality, link = link }
  else
    trackedCursorItem = nil
  end
end

--- Return a tracked cursor item if the newly opened destination conflicts with its flag.
local function returnBlockedCursorItem()
  if not isModuleEnabled() then return end
  if not trackedCursorItem then return end
  local cursorType, _, link = GetCursorInfo()
  if cursorType ~= "item" or link ~= trackedCursorItem.link then
    trackedCursorItem = nil
    return
  end
  local action = blockedItemAction(trackedCursorItem.key, trackedCursorItem.quality)
  if action then
    ClearCursor()
    local remainingType, _, remainingLink = GetCursorInfo()
    if remainingType == "item" and remainingLink == link then
      prn("this item's flag prevents " .. action .. "; please return it to your bags.")
    else
      trackedCursorItem = nil
      prn("this item's flag prevents " .. action .. "; the item was returned to your bags.")
    end
  end
end

--- Update a row's interaction blocker for the currently open windows.
---@param row table Item row.
---@param key string Item status key.
---@param quality number|nil Item quality.
local function updateInteractionBlocker(row, key, quality)
  row.actionBlocker.blockedAction = blockedItemAction(key, quality)
  row.actionBlocker:SetShown(row.actionBlocker.blockedAction ~= nil)
end

--- Format a status icon and label for either context-menu implementation.
---@param status table Item status definition.
---@return string label Icon markup followed by the status name.
local function statusMenuLabel(status)
  local icon = status.atlas and CreateAtlasMarkup(status.atlas, 16, 16)
    or "|T" .. status.icon .. ":16:16|t"
  return icon .. " " .. status.name
end

local recipientPicker, mailAmountPrompt
local mailSelection, pendingMail, mailJob
local mailSendPending = false
local mailHooksInstalled = false
local pendingMailEvents

--- Return the first queued recipient, or the default once the queue is empty.
---@param bag table Profile bag settings.
---@param key string Item status key.
---@return number|nil id Active recipient identifier.
---@return table|nil entry Active one-time queue entry.
local function activeMailRecipient(bag, key)
  local queue = bag.mailQueues[key]
  local entry = queue and queue[1]
  if entry then return entry.recipient, entry end
  return bag.mailAssignments[key], nil
end

--- Check whether a prepared attachment conflicts with the current queue or default.
---@return boolean stale Whether the draft must be changed before sending.
local function hasStaleMailAttachments()
  if not mailSelection then return false end
  for slot = 1, ATTACHMENTS_MAX_SEND do
    if HasSendMailItem(slot) then
      local _, itemID, _, count = GetSendMailItem(slot)
      local link = GetSendMailItemLink(slot)
      local expected = mailSelection.attachments[slot]
      if expected and expected.itemID == itemID and expected.link == link then
        local recipient, amount = activeMailRecipient(mailSelection.bag, expected.statusKey)
        if settings() ~= mailSelection.bag or recipient ~= mailSelection.id or amount ~= expected.amount
          or getItemStatus(expected.statusKey) ~= ITEM_STATUSES[5]
          or (expected.amount and count ~= expected.count) then
          return true
        end
      else
        -- A moved or extra matching stack cannot safely be credited to a one-time queue.
        for _, item in pairs(mailSelection.attachments) do
          if item.itemID == itemID and item.link == link then
            local recipient, amount = activeMailRecipient(mailSelection.bag, item.statusKey)
            if item.amount or settings() ~= mailSelection.bag or recipient ~= mailSelection.id
              or amount ~= item.amount or getItemStatus(item.statusKey) ~= ITEM_STATUSES[5] then return true end
          end
        end
      end
    end
  end
  return false
end

--- Update the send button when a flag or recipient changes an already-prepared draft.
refreshMailSendButton = function()
  if SendMailFrame and SendMailFrame:IsShown() and mailSelection then
    if hasStaleMailAttachments() then
      prn("the mail queue changed; remove the affected attachments or prepare the draft again.")
    end
    SendMailFrame_CanSend()
  end
end

--- Collect bag stacks assigned to each mail recipient, regardless of display filters.
---@param bag table Current profile bag settings.
---@return table items Recipient IDs mapped to bag stacks.
local function collectRecipientMailItems(bag)
  local items = {}
  for _, bagID in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID and info.hyperlink then
        local name, _, quality, level, _, _, _, _, equipLoc, _, sellPrice, classID, subclassID, bindType, _, _, reagent =
          C_Item.GetItemInfo(info.hyperlink)
        name = name or info.itemName
        quality = info.quality or quality
        if name and classID ~= nil and quality and quality ~= 0 then
          local track = getUpgradeTrack(bagID, slot)
          local key = itemStatusKey(name, quality,
            C_Item.GetDetailedItemLevelInfo(info.hyperlink) or level, track)
          local id, amount = activeMailRecipient(bag, key)
          if id and bag.mailRecipients[id] and getItemStatus(key) == ITEM_STATUSES[5] then
            items[id] = items[id] or {}
            items[id][#items[id] + 1] = {
              bagID = bagID, slot = slot, itemID = info.itemID, link = info.hyperlink,
              name = name, count = info.stackCount or 1, locked = info.isLocked, statusKey = key, amount = amount,
              category = itemCategory({
                itemID = info.itemID, quality = quality, classID = classID, subclassID = subclassID, bindType = bindType,
                equipLoc = equipLoc, sellPrice = sellPrice, isCraftingReagent = reagent,
              }),
            }
          end
        end
      end
    end
  end
  return items
end

--- Select stacks that are currently available to attach.
---@param items table Recipient's bag stacks.
---@return table available Unlocked stacks.
local function unlockedMailItems(items)
  local available, reserved = {}, {}
  for _, item in ipairs(items or {}) do
    if not item.locked then
      local amount = item.amount
      local remaining = amount and amount.remaining - (reserved[item.statusKey] or 0)
      local count = remaining and math.min(item.count, remaining) or item.count
      if count > 0 then
        item.sendCount, item.amount = count, amount
        reserved[item.statusKey] = (reserved[item.statusKey] or 0) + count
        available[#available + 1] = item
      end
    end
  end
  return available
end

local MAIL_CATEGORY_SHORT = {
  equipment = "Equip.", consumables = "Cons.", professionGoods = "Prof. Goods",
  junk = "Junk", quest = "Quest", reagents = "Reag.", special = "Ess.", other = "Other",
}
local MAIL_CATEGORY_TINY = {
  equipment = "Equip", consumables = "Cons", professionGoods = "Prof",
  junk = "Junk", quest = "Quest", reagents = "Reag", special = "Ess", other = "Other",
}

--- Summarize attached stacks within the native 64-character subject limit.
---@param items table Confirmed attachments and their categories.
---@return string subject Mail subject.
local function mailSubject(items)
  if #items == 1 then return items[1].name end
  local counts, total = {}, 0
  for _, item in ipairs(items) do
    counts[item.category] = (counts[item.category] or 0) + item.count
    total = total + item.count
  end
  for style = 1, 3 do
    local parts = {}
    for _, category in ipairs(ITEM_CATEGORIES) do
      if counts[category.id] then
        local label = style == 1 and category.name
          or style == 2 and MAIL_CATEGORY_SHORT[category.id] or MAIL_CATEGORY_TINY[category.id]
        parts[#parts + 1] = style == 3 and (label .. ":" .. counts[category.id])
          or (label .. " (" .. counts[category.id] .. ")")
      end
    end
    local subject = table.concat(parts, style == 3 and " " or ", ")
    if #subject <= 64 then return subject end
  end
  return "Items (" .. total .. ")"
end

--- Capture the compose fields and attachments before asking to replace a draft.
---@return table draft Current draft state.
local function captureMailDraft()
  local draft = {
    name = SendMailNameEditBox:GetText(), subject = SendMailSubjectEditBox:GetText(),
    body = SendMailBodyEditBox:GetText(), money = MoneyInputFrame_GetCopper(SendMailMoney),
    cod = SendMailCODButton:GetChecked(), previousItem = SendMailFrame.previousItem, attachments = {},
  }
  for index = 1, ATTACHMENTS_MAX_SEND do
    if HasSendMailItem(index) then
      local _, itemID, _, count = GetSendMailItem(index)
      draft.attachments[index] = { itemID = itemID, count = count, link = GetSendMailItemLink(index) }
    end
  end
  return draft
end

--- Determine whether a captured draft contains anything the player could lose.
---@param draft table Captured compose state.
---@return boolean occupied Whether the draft contains data.
local function mailDraftOccupied(draft)
  return draft.name ~= "" or draft.subject ~= "" or draft.body ~= "" or draft.money > 0
    or next(draft.attachments) ~= nil
end

--- Compare a draft with the state shown in a replacement confirmation.
---@param original table Confirmed draft state.
---@param current table Current draft state.
---@return boolean matches Whether the draft is unchanged.
local function sameMailDraft(original, current)
  if original.name ~= current.name or original.subject ~= current.subject or original.body ~= current.body
    or original.money ~= current.money or original.cod ~= current.cod then return false end
  for index = 1, ATTACHMENTS_MAX_SEND do
    local a, b = original.attachments[index], current.attachments[index]
    if (a == nil) ~= (b == nil) or (a and (a.itemID ~= b.itemID or a.count ~= b.count or a.link ~= b.link)) then
      return false
    end
  end
  return true
end

--- Stop an attachment operation and restore Blizzard's normal send-button state.
---@param message string|nil Failure explanation.
local function stopMailJob(message)
  if message and mailJob and mailJob.selection then mailJob.selection.uncertain = true end
  mailJob = nil
  if SendMailFrame and SendMailFrame:IsShown() then SendMailFrame_CanSend() end
  if message then prn(message) end
  if recipientPicker and recipientPicker:IsShown() and recipientPicker.mailMode then
    if recipientPicker.bag ~= settings() then recipientPicker:Hide() else recipientPicker.refreshRecipients() end
  end
end

--- Continue clearing or attaching one stack after the client confirms the preceding operation.
---@param job table Active operation.
local function advanceMailJob(job)
  if mailJob ~= job then return end
  if not isModuleEnabled() or settings() ~= job.bag or not SendMailFrame:IsShown()
    or job.bag.mailRecipients[job.id] ~= job.recipient then
    stopMailJob("mail preparation stopped because the recipient or mail window changed.")
    return
  end
  if job.waiting then
    local present = HasSendMailItem(job.waiting.slot)
    if (job.phase == "clearing" and not present) or (job.phase == "attaching" and present) then
      if job.phase == "attaching" then
        local _, itemID, _, count = GetSendMailItem(job.waiting.slot)
        if itemID ~= job.waiting.item.itemID or count ~= job.waiting.item.sendCount
          or GetSendMailItemLink(job.waiting.slot) ~= job.waiting.item.link then
          stopMailJob("mail preparation stopped because an attachment changed.")
          return
        end
        local item = job.waiting.item
        local attached = {
          itemID = item.itemID, link = item.link, name = item.name, count = item.sendCount,
          category = item.category, statusKey = item.statusKey, amount = item.amount,
        }
        job.attached[#job.attached + 1] = attached
        job.selection.attachments[job.waiting.slot] = attached
      end
      job.waiting = nil
      job.attempts = 0
      job.index = job.index + 1
    else
      job.attempts = job.attempts + 1
      if job.attempts >= 200 then
        stopMailJob("mail preparation timed out; check the attachments and any confirmation dialogs.")
        return
      end
      C_Timer.After(0.1, function() advanceMailJob(job) end)
      return
    end
  end
  if job.phase == "clearing" then
    local current = captureMailDraft()
    local allRemoved = not next(current.attachments)
    for index = 1, job.index - 1 do
      if job.draft.attachments[index] then
        if current.attachments[index] then
          stopMailJob("the mail attachments changed; select the recipient again.")
          return
        end
        current.attachments[index] = job.draft.attachments[index]
      end
    end
    -- Blizzard updates its automatic subject and COD mode as attachments are removed.
    if job.draft.subject == job.draft.previousItem and current.subject == current.previousItem then
      current.subject = job.draft.subject
    end
    if job.index > 1 and allRemoved then current.cod = job.draft.cod end
    if not sameMailDraft(job.draft, current) then
      stopMailJob("the mail draft changed; select the recipient again.")
      return
    end
    while job.index <= ATTACHMENTS_MAX_SEND and not job.draft.attachments[job.index] do
      job.index = job.index + 1
    end
    if job.index <= ATTACHMENTS_MAX_SEND then
      ClickSendMailItemButton(job.index, true)
      job.waiting = { slot = job.index }
    else
      SendMailFrame_Reset()
      job.phase, job.index = "attaching", 1
      job.items = unlockedMailItems(collectRecipientMailItems(job.bag)[job.id])
      SendMailNameEditBox:SetText(job.recipient.character)
    end
  end
  if job.phase == "attaching" and not job.waiting then
    if SendMailNameEditBox:GetText() ~= job.recipient.character then
      stopMailJob("the mail recipient changed; attachment preparation stopped.")
      return
    end
    local item = job.items[job.index]
    if not item or job.index > ATTACHMENTS_MAX_SEND then
      if #job.attached > 0 then
        local subject = SendMailSubjectEditBox:GetText()
        if subject == "" or subject == SendMailFrame.previousItem then
          SendMailSubjectEditBox:SetText(mailSubject(job.attached))
        else
          prn("the mail subject was changed, so it was left unchanged.")
        end
      else
        prn("no available items are marked for this recipient.")
      end
      stopMailJob()
      return
    end
    local current = C_Container.GetContainerItemInfo(item.bagID, item.slot)
    local recipient, amount = activeMailRecipient(job.bag, item.statusKey)
    if not current or current.isLocked or current.itemID ~= item.itemID or current.hyperlink ~= item.link
      or (current.stackCount or 1) ~= item.count or recipient ~= job.id or amount ~= item.amount
      or getItemStatus(item.statusKey) ~= ITEM_STATUSES[5] or GetCursorInfo() then
      stopMailJob("a bag item or the cursor changed; select the recipient again.")
      return
    end
    if item.sendCount < item.count then
      C_Container.SplitContainerItem(item.bagID, item.slot, item.sendCount)
    else
      C_Container.PickupContainerItem(item.bagID, item.slot)
    end
    local cursorType, _, cursorLink = GetCursorInfo()
    if cursorType ~= "item" or cursorLink ~= item.link then
      stopMailJob("unable to pick up " .. (item.name or "the item") .. " for mailing.")
      return
    end
    ClickSendMailItemButton(job.index)
    if GetCursorInfo() then
      ClearCursor()
      stopMailJob("unable to attach " .. (item.name or "the item") .. "; check whether it can be mailed.")
      return
    end
    job.waiting = { slot = job.index, item = item }
  end
  C_Timer.After(0.1, function() advanceMailJob(job) end)
end

--- Start preparing a recipient's mail after any replacement has been confirmed.
---@param bag table Current profile bag settings.
---@param id number Recipient identifier.
---@param recipient table Recipient data.
---@param draft table Confirmed current draft.
local function startRecipientMail(bag, id, recipient, draft)
  if mailJob then prn("wait for the current mail preparation to finish."); return end
  if mailSendPending then prn("wait for the current mail to finish sending."); return end
  if not SendMailFrame:IsShown() or bag ~= settings() or bag.mailRecipients[id] ~= recipient then
    prn("the mail window or recipient changed; select the recipient again.")
    return
  end
  if GetCursorInfo() then prn("put down the item on your cursor before preparing mail."); return end
  if not sameMailDraft(draft, captureMailDraft()) then
    prn("the mail draft changed; select the recipient again.")
    return
  end
  local items = unlockedMailItems(collectRecipientMailItems(bag)[id])
  if #items == 0 then prn("no unlocked items are available for this recipient."); return end
  mailSelection = { bag = bag, id = id, recipient = recipient, attachments = {} }
  mailJob = {
    bag = bag, id = id, recipient = recipient, draft = draft, items = items, attached = {},
    selection = mailSelection,
    phase = mailDraftOccupied(draft) and "clearing" or "attaching", index = 1, attempts = 0,
  }
  if mailJob.phase == "attaching" then SendMailNameEditBox:SetText(recipient.character) end
  SendMailMailButton:Disable()
  advanceMailJob(mailJob)
end

--- Remove a recipient and unassign its items without clearing their Mail flags.
---@param bag table Profile bag settings.
---@param id number Recipient identifier.
local function deleteMailRecipient(bag, id)
  bag.mailRecipients[id] = nil
  for key, recipientID in pairs(bag.mailAssignments) do
    if recipientID == id then bag.mailAssignments[key] = nil end
  end
  for key, queue in pairs(bag.mailQueues) do
    for index = #queue, 1, -1 do
      if queue[index].recipient == id then table.remove(queue, index) end
    end
    refreshMailSendButton()
    if #queue == 0 then bag.mailQueues[key] = nil end
  end
end

--- Apply a recipient and optional one-time quantity after validating the open selection.
---@param picker table Recipient picker.
---@param choice table Recipient and original flag state.
---@param amount number|nil One-time quantity, or nil to remember all.
local function applyMailChoice(picker, choice, amount)
  local bag, key = choice.bag, choice.key
  local status = getItemStatus(key, choice.statusInfo.quality)
  if not isModuleEnabled() or not picker:IsShown() or picker.bag ~= bag or bag ~= settings()
    or bag.mailRecipients[choice.id] ~= choice.recipient or status ~= choice.previousStatus
    or (status and bag[status.field][key] ~= choice.previousValue)
    or bag.mailAssignments[key] ~= choice.previousRecipient
    or (bag.mailQueues[key] and bag.mailQueues[key][1]) ~= choice.previousHead then
    prn("the item, recipient, or profile changed; select the recipient again.")
    if mailAmountPrompt then mailAmountPrompt:Hide() end
    return
  end
  if status ~= ITEM_STATUSES[5] then setItemStatus(key, choice.statusInfo, ITEM_STATUSES[5]) end
  if amount then
    bag.mailQueues[key] = bag.mailQueues[key] or {}
    table.insert(bag.mailQueues[key], { recipient = choice.id, remaining = amount })
  else
    bag.mailAssignments[key] = choice.id
  end
  refreshMailSendButton()
  renderRows()
  picker:Hide()
end

--- Show the one-time quantity or remembered-recipient choice.
---@param picker table Recipient picker.
---@param choice table Recipient and original flag state.
local function openMailAmountPrompt(picker, choice)
  if not mailAmountPrompt then
    local prompt = CreateFrame("Frame", "SlackHacksMailAmountPrompt", picker, "SimplePanelTemplate")
    prompt:SetSize(310, 232)
    prompt:SetFrameStrata("DIALOG")
    prompt:SetToplevel(true)
    prompt:SetClampedToScreen(true)
    prompt.Inset:Hide()
    prompt.Bg:SetHorizTile(false)
    prompt.Bg:SetVertTile(false)
    prompt.Bg:SetTexture("Interface\\MailFrame\\UI-MailFrameBG")
    -- The inbox artwork is 512 square; crop its occupied upper-left area to fit this smaller panel.
    prompt.Bg:SetTexCoord(0, 320 / 512, 0, 224 / 512)
    prompt.Bg:SetVertexColor(1, 1, 1, 1)
    prompt.Bg:ClearAllPoints()
    prompt.Bg:SetPoint("TOPLEFT", 0, -6)
    prompt.Bg:SetPoint("BOTTOMRIGHT", -4, 3)
    local headline = prompt:CreateTexture(nil, "BACKGROUND")
    headline:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    headline:SetBlendMode("ADD")
    headline:SetVertexColor(0.1, 0.1, 0.1, 1)
    headline:SetHeight(26)
    headline:SetPoint("TOPLEFT", 40, -21)
    headline:SetPoint("TOPRIGHT", -40, -21)
    local title = prompt:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -21)
    title:SetPoint("TOPRIGHT", -14, -21)
    title:SetHeight(26)
    title:SetJustifyH("CENTER")
    title:SetText("Mail Item")
    local onceLabel = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    onceLabel:SetPoint("TOP", 0, -56)
    onceLabel:SetText("Send only a specific amount one time?")
    prompt.amount = CreateFrame("EditBox", nil, prompt, "InputBoxTemplate")
    prompt.amount:SetSize(100, 20)
    prompt.amount:SetPoint("TOP", onceLabel, "BOTTOM", 0, -8)
    prompt.amount:SetAutoFocus(false)
    prompt.amount:SetNumeric(true)
    local once = CreateFrame("Button", nil, prompt, "SharedButtonSmallTemplate")
    once:SetSize(120, 22)
    once:SetPoint("TOP", prompt.amount, "BOTTOM", 0, -8)
    once:SetText("Send Once")
    --- Validate and save the requested one-time quantity.
    once:SetScript("OnClick", function()
      local text = prompt.amount:GetText()
      local value = text:match("^%d+$") and tonumber(text)
      if not value or value < 1 or value > 9007199254740991 then
        prn("enter a positive whole number for the mail amount.")
        prompt.amount:SetFocus()
        return
      end
      applyMailChoice(prompt.picker, prompt.choice, value)
    end)
    local rememberLabel = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rememberLabel:SetPoint("TOP", once, "BOTTOM", 0, -13)
    rememberLabel:SetText("Or, send all and remember this recipient?")
    local remember = CreateFrame("Button", nil, prompt, "SharedButtonSmallTemplate")
    remember:SetSize(120, 22)
    remember:SetPoint("TOP", rememberLabel, "BOTTOM", 0, -8)
    remember:SetText("Remember")
    --- Save the recipient for all matching items.
    remember:SetScript("OnClick", function() applyMailChoice(prompt.picker, prompt.choice) end)
    CreateFrame("Button", nil, prompt, "UIPanelCloseButtonDefaultAnchors")
    mailAmountPrompt = prompt
  end
  mailAmountPrompt:Hide()
  mailAmountPrompt:SetParent(picker)
  mailAmountPrompt.picker = picker
  mailAmountPrompt.choice = choice
  mailAmountPrompt:ClearAllPoints()
  mailAmountPrompt:SetPoint("TOPLEFT", picker, "TOPRIGHT", 4, 0)
  mailAmountPrompt.amount:SetText("")
  mailAmountPrompt:Show()
end

--- Open the recipient picker without changing the item's existing flag.
---@param anchor table Flag button.
---@param key string Item status key.
---@param statusInfo table Item metadata.
---@param mailMode boolean|nil Whether the picker is opened from the Send Mail tab.
local function openMailRecipientPicker(anchor, key, statusInfo, mailMode)
  if mailMode and not next(collectRecipientMailItems(settings())) then return end
  if not recipientPicker then
    local forever = isForever()
    -- Retail's base template has no background behind the inset and exposes the world around its edges.
    local picker = CreateFrame("Frame", "SlackHacksMailRecipientPicker", frame,
      forever and "DefaultPanelBaseTemplate" or "DefaultPanelTemplate")
    picker:Hide()
    -- Forever's outfit-card artwork extends to 194 pixels despite the 169-pixel row template.
    picker:SetSize(forever and 245 or 220, forever and 459 or 451)
    picker:SetFrameStrata("DIALOG")
    picker:SetClampedToScreen(true)
    picker.TitleContainer.TitleText:SetText("Mail Recipients")
    local inset = CreateFrame("Frame", nil, picker, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 6, -21)
    inset:SetPoint("BOTTOMRIGHT", -6, 4)
    if forever then
      -- Match Forever's CharacterFrameRightPaneHost; Retail uses the inset itself.
      inset.Bg:SetHorizTile(false)
      inset.Bg:SetVertTile(false)
      inset.Bg:SetAtlas("UI-Character-Info-Stat-BG")
      local border = inset:CreateTexture(nil, "BORDER")
      border:SetAtlas("common-insideframe", true)
      border:SetPoint("TOPLEFT", inset, "TOPLEFT", 1, 1)
      border:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -4, 2)
    else
      -- Keep the tiled marble inside the Retail inset's nine-slice border.
      inset.Bg:ClearAllPoints()
      inset.Bg:SetPoint("TOPLEFT", inset, "TOPLEFT", 3, -3)
      inset.Bg:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -3, 3)
    end
    CreateFrame("Button", nil, picker, "UIPanelCloseButtonDefaultAnchors")

    local scrollBox = CreateFrame("Frame", nil, picker, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", forever and 11 or 12, -29)
    scrollBox:SetPoint("BOTTOMRIGHT", forever and -26 or -36, forever and 64 or 56)
    local scrollBar = CreateFrame("EventFrame", nil, picker, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", forever and -5 or 8, forever and -12 or 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", forever and 0 or 8, forever and 0 or 30)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(44)
    view:SetPadding(0, 0, 3, 0, 2)

    local newRecipient
    --- Refresh the list from the profile that opened the picker.
    local function refreshRecipients()
      local elements = {}
      local available = picker.mailMode and collectRecipientMailItems(picker.bag) or nil
      for id, recipient in pairs(picker.bag.mailRecipients) do
        elements[#elements + 1] = { id = id, recipient = recipient, enabled = not available or available[id] ~= nil }
      end
      table.sort(elements, function(a, b)
        return a.recipient.nickname:lower() < b.recipient.nickname:lower()
      end)
      if not forever then
        for index, element in ipairs(elements) do element.index = index end
        newRecipient.BgTop:SetShown(#elements == 0)
        if #elements == 0 then newRecipient.BgMiddle:SetPoint("TOP", newRecipient.BgTop, "BOTTOM")
        else newRecipient.BgMiddle:SetPoint("TOP") end
      end
      scrollBox:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants.RetainScrollPosition)
    end

    --- Create the mail autocomplete field inside the icon picker.
    ---@param region table Space reserved by the reusable popup.
    ---@return table controls Recipient controls.
    local function createRecipientControls(region)
      local label = region:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint("TOPLEFT", 0, -5)
      label:SetText("Send to Character Name:")
      local box = CreateFrame("EditBox", nil, region, "InputBoxTemplate,AutoCompleteEditBoxTemplate")
      box:SetSize(250, 20)
      box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -5)
      box:SetAutoFocus(false)
      box:SetMaxLetters(77)
      AutoCompleteEditBox_SetAutoCompleteSource(box, C_AutoComplete.GetAutoCompleteResults,
        AUTOCOMPLETE_LIST.MAIL.include, AUTOCOMPLETE_LIST.MAIL.exclude)
      box.addHighlightedText = true
      box.autoCompleteContext = "mail"
      box:SetScript("OnTextChanged", function(self, userInput) AutoCompleteEditBox_OnTextChanged(self, userInput) end)
      box:SetScript("OnTabPressed", function(self)
        if not AutoCompleteEditBox_OnTabPressed(self) then self:ClearFocus() end
      end)
      box:SetScript("OnEnterPressed", function(self)
        if not AutoCompleteEditBox_OnEnterPressed(self) then self:ClearFocus() end
      end)
      box:SetScript("OnEscapePressed", function(self)
        if not AutoCompleteEditBox_OnEscapePressed(self) then self:ClearFocus() end
      end)
      box:SetScript("OnEditFocusLost", function(self)
        AutoCompleteEditBox_OnEditFocusLost(self)
        EditBox_ClearHighlight(self)
      end)
      return { name = box }
    end

    picker.popup = CreateIconNamePopupFrame(picker, {
      nameLabel = "Nickname:",
      createExtraControls = createRecipientControls,
      onConfirm = function(nickname, icon, controls)
        if picker.bag ~= settings() then picker:Hide(); return false end
        local character = controls.name:GetText():match("^%s*(.-)%s*$")
        if character == "" then
          prn("enter a character name for the mail recipient.")
          controls.name:SetFocus()
          return false
        end
        local editing = picker.editingRecipient
        if editing then
          if picker.bag.mailRecipients[editing.id] ~= editing.recipient then
            prn("the mail recipient no longer exists; please reopen the recipient list.")
            return false
          end
          editing.recipient.nickname = nickname
          editing.recipient.character = character
          editing.recipient.icon = icon
          picker.editingRecipient = nil
          renderRows()
        else
          local id = 1
          while picker.bag.mailRecipients[id] do id = id + 1 end
          picker.bag.mailRecipients[id] = { nickname = nickname, character = character, icon = icon }
        end
        controls.name:SetText("")
        refreshRecipients()
        return true
      end,
    })
    picker:SetScript("OnHide", function(self)
      self.popup:Hide()
      if mailAmountPrompt then mailAmountPrompt:Hide() end
      self.editingRecipient = nil
      if self.mailMode then
        if mailJob then stopMailJob("mail preparation stopped because the recipient window was closed.") end
      end
    end)

    if forever then
      newRecipient = CreateFrame("Button", nil, picker, "PaperDollTertiaryButtonTemplate")
      newRecipient:SetSize(180, 34)
      -- The native template's label has no parentKey or ButtonText, so update its font string directly.
      local label
      for _, region in ipairs({ newRecipient:GetRegions() }) do
        if region:GetObjectType() == "FontString" then label = region; break end
      end
      assert(label, "PaperDollTertiaryButtonTemplate is missing its label")
      label:ClearAllPoints()
      label:SetPoint("LEFT", 35, 0)
      label:SetPoint("RIGHT", -6, 0)
      label:SetJustifyH("LEFT")
      label:SetWordWrap(false)
      label:SetText("New Mail Recipient")
      local plus = newRecipient:CreateTexture(nil, "ARTWORK")
      plus:SetAtlas("UI-Character-Info-Icon-Add", true)
      plus:SetPoint("LEFT", 13, 0)
      local divider = picker:CreateTexture(nil, "BORDER")
      divider:SetAtlas("UI-Character-Info-ScrollLine", true)
      divider:SetPoint("TOP", scrollBox, "BOTTOM")
    else
      -- Retail renders its new-set control as a gear-set row; keep it outside our scrolling list.
      newRecipient = CreateFrame("Button", nil, picker, "GearSetButtonTemplate")
      newRecipient:SetSize(191, 44)
      -- The native row background has fixed-width textures that do not resize with the button.
      newRecipient.BgTop:SetWidth(191)
      newRecipient.BgMiddle:SetWidth(190)
      newRecipient.BgBottom:SetWidth(191)
      newRecipient.text:ClearAllPoints()
      newRecipient.text:SetPoint("LEFT", newRecipient, "LEFT", 44, 0)
      newRecipient.text:SetPoint("RIGHT", newRecipient, "RIGHT", -5, 0)
      newRecipient.text:SetWordWrap(false)
      newRecipient.text:SetText("New Mail Recipient")
      newRecipient.text:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
      newRecipient.icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
      newRecipient.icon:SetSize(30, 30)
      newRecipient.icon:ClearAllPoints()
      newRecipient.icon:SetPoint("LEFT", 7, 0)
      newRecipient.Check:Hide()
      newRecipient.SpecRing:Hide()
      newRecipient.SpecIcon:Hide()
      newRecipient.SelectedBar:Hide()
      newRecipient.HighlightBar:Hide()
      newRecipient.Stripe:Hide()
      newRecipient.BgBottom:Show()
      newRecipient.BgMiddle:SetPoint("BOTTOM", newRecipient.BgBottom, "TOP")
      newRecipient.DeleteButton:Hide()
      newRecipient.EditButton:Hide()
      newRecipient:SetScript("OnDoubleClick", nil)
      newRecipient:SetScript("OnDragStart", nil)
      newRecipient:SetScript("OnEnter", function(self) self.HighlightBar:Show() end)
      newRecipient:SetScript("OnLeave", function(self) self.HighlightBar:Hide() end)
    end
    if forever then newRecipient:SetPoint("BOTTOM", picker, "BOTTOM", 0, 12)
    else
      newRecipient:ClearAllPoints()
      newRecipient:SetPoint("TOPLEFT", scrollBox, "BOTTOMLEFT", 3, 0)
    end
    newRecipient:SetScript("OnClick", function()
      if picker.bag ~= settings() then picker:Hide(); return end
      picker.editingRecipient = nil
      picker.popup.extraControls.name:SetText("")
      picker.popup:Open()
    end)

    StaticPopupDialogs.SLACKHACKS_DELETE_MAIL_RECIPIENT = {
      text = "Delete mail recipient %s?",
      button1 = DELETE,
      button2 = CANCEL,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      OnAccept = function(_, data)
        if data.bag ~= settings() or data.bag.mailRecipients[data.id] ~= data.recipient then return end
        if picker.bag == data.bag and picker.editingRecipient
          and picker.editingRecipient.recipient == data.recipient then
          picker.popup:Hide()
          picker.editingRecipient = nil
        end
        deleteMailRecipient(data.bag, data.id)
        if picker:IsShown() and picker.bag == data.bag then refreshRecipients() end
        renderRows()
      end,
    }

    StaticPopupDialogs.SLACKHACKS_REPLACE_MAIL_DRAFT = {
      text = "Replace the current mail draft? Attached items will be returned to your bags.",
      button1 = ACCEPT,
      button2 = CANCEL,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      OnAccept = function(_, data)
        if not picker:IsShown() or not picker.mailMode or picker.bag ~= data.bag then
          prn("the mail recipient window changed; select the recipient again.")
          return
        end
        startRecipientMail(data.bag, data.id, data.recipient, data.draft)
      end,
    }

    view:SetElementInitializer("GearSetButtonTemplate", function(row, element)
      row:SetEnabled(element.enabled)
      row:SetAlpha(element.enabled and 1 or 0.45)
      if not forever then
        row.BgTop:SetShown(element.index == 1)
        if element.index == 1 then row.BgMiddle:SetPoint("TOP", row.BgTop, "BOTTOM")
        else row.BgMiddle:SetPoint("TOP") end
        row.BgBottom:Hide()
        row.BgMiddle:SetPoint("BOTTOM")
        if element.index % 2 == 0 then
          -- Match the equipment manager's locally scoped stripe color.
          row.Stripe:SetColorTexture(0.9, 0.9, 1)
          row.Stripe:SetAlpha(0.1)
          row.Stripe:Show()
        else
          row.Stripe:Hide()
        end
      end
      row.text:ClearAllPoints()
      row.text:SetPoint("TOPLEFT", row, "TOPLEFT", forever and 55 or 44, -7)
      row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", forever and -55 or -36, -7)
      row.text:SetHeight(14)
      row.text:SetWordWrap(false)
      row.text:SetText(element.recipient.nickname)
      if not row.characterText then
        row.characterText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.characterText:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -1)
        row.characterText:SetPoint("TOPRIGHT", row.text, "BOTTOMRIGHT", 0, -1)
        row.characterText:SetHeight(12)
        row.characterText:SetJustifyH("LEFT")
        row.characterText:SetWordWrap(false)
        row.characterText:SetTextColor(1, 1, 1)
      end
      row.characterText:SetText(element.recipient.character)
      row.icon:SetTexture(element.recipient.icon)
      row.SpecRing:Hide()
      row.SpecIcon:Hide()
      row.SelectedBar:Hide()
      row.HighlightBar:Hide()
      row.DeleteButton:ClearAllPoints()
      row.DeleteButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", forever and -21 or -2, 2)
      row.DeleteButton:Show()
      row.EditButton:ClearAllPoints()
      row.EditButton:SetPoint("RIGHT", row.DeleteButton, "LEFT", -1, 0)
      row.EditButton:Show()
      row.EditButton:SetScript("OnMouseDown", nil)
      row.EditButton:SetScript("OnEnter", function(self)
        self.texture:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Edit mail recipient")
      end)
      row.EditButton:SetScript("OnClick", function()
        if picker.bag ~= settings() then picker:Hide(); return end
        if picker.bag.mailRecipients[element.id] ~= element.recipient then
          prn("the mail recipient no longer exists; please reopen the recipient list.")
          refreshRecipients()
          return
        end
        picker.editingRecipient = element
        picker.popup:Open(element.recipient.nickname, element.recipient.icon)
        picker.popup.extraControls.name:SetText(element.recipient.character)
      end)
      -- The native template operates on equipment sets, so replace every equipment action.
      row:SetScript("OnDoubleClick", nil)
      row:SetScript("OnDragStart", nil)
      row:SetScript("OnEnter", function(self) self.HighlightBar:Show() end)
      row:SetScript("OnLeave", function(self) self.HighlightBar:Hide(); GameTooltip:Hide() end)
      row:SetScript("OnClick", function()
        if picker.bag ~= settings() then picker:Hide(); return end
        if picker.mailMode then
          if not element.enabled then return end
          if picker.bag.mailRecipients[element.id] ~= element.recipient then
            prn("the mail recipient no longer exists; please reopen the recipient list.")
            refreshRecipients()
            return
          end
          if mailJob then prn("wait for the current mail preparation to finish."); return end
          local draft = captureMailDraft()
          if mailDraftOccupied(draft) then
            local dialog = StaticPopup_Show("SLACKHACKS_REPLACE_MAIL_DRAFT", nil, nil,
              { bag = picker.bag, id = element.id, recipient = element.recipient, draft = draft })
            if not dialog then prn("unable to show the mail draft replacement confirmation.") end
          else
            startRecipientMail(picker.bag, element.id, element.recipient, draft)
          end
          return
        end
        if picker.bag.mailRecipients[element.id] ~= element.recipient then
          prn("the mail recipient no longer exists; please reopen the recipient list.")
          refreshRecipients()
        else
          local info = picker.statusInfo
          local status = getItemStatus(picker.key, info.quality)
          local choice = {
            bag = picker.bag, key = picker.key, statusInfo = info, id = element.id, recipient = element.recipient,
            previousStatus = status, previousValue = status and picker.bag[status.field][picker.key],
            previousRecipient = picker.bag.mailAssignments[picker.key],
            previousHead = picker.bag.mailQueues[picker.key] and picker.bag.mailQueues[picker.key][1],
          }
          openMailAmountPrompt(picker, choice)
        end
      end)
      row.DeleteButton:SetScript("OnClick", function()
        local dialog = StaticPopup_Show("SLACKHACKS_DELETE_MAIL_RECIPIENT", element.recipient.nickname, nil,
          { bag = picker.bag, id = element.id, recipient = element.recipient })
        if not dialog then prn("unable to show the mail recipient deletion confirmation.") end
      end)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    picker.refreshRecipients = refreshRecipients
    recipientPicker = picker
  end
  recipientPicker:Hide()
  recipientPicker:SetParent(mailMode and UIParent or frame)
  recipientPicker.bag = settings()
  recipientPicker.mailMode = mailMode
  recipientPicker.key = key
  recipientPicker.statusInfo = statusInfo
  recipientPicker:ClearAllPoints()
  recipientPicker:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
  recipientPicker.refreshRecipients()
  recipientPicker:Show()
end

--- Install send-tab hooks once Blizzard's mail UI has loaded.
local function installMailHooks()
  if mailHooksInstalled or not MailFrame or not SendMailFrame then return end
  mailHooksInstalled = true
  -- AceEvent unregisters a disabled module, but an in-flight send still needs to settle its quota.
  pendingMailEvents = CreateFrame("Frame")
  --- Settle a tracked send even if Listview Bag was disabled while it was in flight.
  ---@param _ table Event frame.
  ---@param event string Mail result event.
  pendingMailEvents:SetScript("OnEvent", function(_, event)
    if event == "MAIL_SEND_SUCCESS" then module:OnMailSendSuccess() else module:OnMailSendFailed() end
  end)
  SendMailFrame:HookScript("OnShow", function()
    if isModuleEnabled() and MailFrame:IsShown() then openMailRecipientPicker(MailFrame, nil, nil, true) end
  end)
  SendMailFrame:HookScript("OnHide", function()
    if recipientPicker and recipientPicker.mailMode then recipientPicker:Hide() end
    mailSelection = nil
  end)
  hooksecurefunc("SendMailFrame_CanSend", function()
    if isModuleEnabled() and (mailJob or hasStaleMailAttachments()) then SendMailMailButton:Disable() end
  end)
  hooksecurefunc("SendMail", function(name)
    pendingMail = nil
    if isModuleEnabled() and SendMailFrame:IsShown() then mailSendPending = true end
    if isModuleEnabled() and mailSelection and not mailJob and SendMailFrame:IsShown()
      and type(name) == "string" and name:lower() == mailSelection.recipient.character:lower() then
      local sent, uncertain = {}, mailSelection.uncertain
      for slot, item in pairs(mailSelection.attachments) do
        if item.amount then
          local _, itemID, _, count = GetSendMailItem(slot)
          if itemID == item.itemID and count == item.count and GetSendMailItemLink(slot) == item.link then
            sent[#sent + 1] = item
          else
            -- A manually changed attachment cannot safely be credited to a one-time quota.
            uncertain = true
          end
        else
          sent[#sent + 1] = item
        end
      end
      for slot = 1, ATTACHMENTS_MAX_SEND do
        if not mailSelection.attachments[slot] and HasSendMailItem(slot) then
          local _, itemID = GetSendMailItem(slot)
          local link = GetSendMailItemLink(slot)
          for _, item in pairs(mailSelection.attachments) do
            if item.amount and item.itemID == itemID and item.link == link then uncertain = true end
          end
        end
      end
      pendingMail = { selection = mailSelection, character = name, items = sent, uncertain = uncertain }
      pendingMailEvents:RegisterEvent("MAIL_SEND_SUCCESS")
      pendingMailEvents:RegisterEvent("MAIL_FAILED")
    end
  end)
end

--- Select a flag, requesting a recipient before applying Mail.
---@param anchor table Flag button.
---@param key string Item status key.
---@param statusInfo table Item metadata.
---@param status table Selected flag.
local function selectItemStatus(anchor, key, statusInfo, status)
  if status.id == "mail" then
    if statusInfo.quality == nil or statusInfo.quality == 0 then
      setItemStatus(key, statusInfo, status)
    else
      openMailRecipientPicker(anchor, key, statusInfo)
    end
  else
    setItemStatus(key, statusInfo, status)
  end
end

--- Open a menu for selecting or clearing the item's single status.
---@param anchor table Status button.
---@param key string Item status key.
---@param statusInfo table Item metadata to save.
local function openItemStatusMenu(anchor, key, statusInfo)
  GameTooltip:Hide()
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(anchor, function(_, root)
      root:CreateTitle("Flag item for:")
      root:CreateRadio("None", function() return not getItemStatus(key, statusInfo.quality) end,
        function() setItemStatus(key, statusInfo, nil) end)
      for _, entry in ipairs(ITEM_STATUSES) do
        local status = entry
        if statusInfo.quality ~= 0 or status == PROTECT_STATUS then
          local label = statusMenuLabel(status)
          root:CreateRadio(label, function() return getItemStatus(key, statusInfo.quality) == status end,
            function() selectItemStatus(anchor, key, statusInfo, status) end)
        end
      end
    end)
  else
    local menu = {
      { text = "Flag item for:", isTitle = true, notCheckable = true },
      { text = "None", checked = function() return not getItemStatus(key, statusInfo.quality) end,
        func = function() setItemStatus(key, statusInfo, nil) end },
    }
    for _, entry in ipairs(ITEM_STATUSES) do
      local status = entry
      if statusInfo.quality ~= 0 or status == PROTECT_STATUS then
        menu[#menu + 1] = {
          text = statusMenuLabel(status),
          checked = function() return getItemStatus(key, statusInfo.quality) == status end,
          func = function() selectItemStatus(anchor, key, statusInfo, status) end,
        }
      end
    end
    if not module.statusMenu then
      module.statusMenu = CreateFrame("Frame", "SlackHacksListviewBagStatusMenu", UIParent, "UIDropDownMenuTemplate")
    end
    EasyMenu(menu, module.statusMenu, "cursor", 0, 0, "MENU")
  end
end

--- Show the selected status icon, or an ellipsis for an unmarked item.
---@param button table Item status button.
---@param status table|nil Selected status definition.
local function updateStatusButton(button, status)
  if status then
    if status.atlas then
      button.icon:SetAtlas(status.atlas)
    else
      button.icon:SetTexture(status.icon)
      -- A previous atlas may have left cropped texture coordinates on this reused row.
      button.icon:SetTexCoord(0, 1, 0, 1)
    end
    button.icon:Show()
    button.text:Hide()
  else
    button.icon:Hide()
    button.text:Show()
  end
end

--- Create a bag row and its status controls.
---@param index number Row index.
---@return table row Bag row.
local function createRow(index)
  local holder = CreateFrame("Frame", nil, scrollChild)
  holder:SetHeight(ROW_HEIGHT)

  local row = CreateFrame("Button", "SlackHacksListviewBagRow" .. index, holder, "ContainerFrameItemButtonTemplate")
  row.holder = holder
  row:SetFrameLevel(holder:GetFrameLevel() + 1)
  row:ClearAllPoints()
  row:SetAllPoints(holder)
  row:SetHeight(ROW_HEIGHT)

  if row:GetNormalTexture() then row:SetNormalTexture(nil) end
  if row:GetHighlightTexture() then row:SetHighlightTexture(nil) end
  for _, region in ipairs({ row:GetRegions() }) do
    if region.Hide and region ~= row then
      region:Hide()
    end
  end

  -- Same row hover-highlight bar and alternating-row background strip the Guild/Community roster list
  -- uses (CommunitiesMemberListEntryTemplate), reused here instead of a custom highlight color.
  row:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar", "ADD")
  row.stripe = row:CreateTexture(nil, "BACKGROUND")
  row.stripe:SetAllPoints()
  row.stripe:SetTexture("Interface\\GuildFrame\\GuildFrame")
  row.stripe:SetTexCoord(0.36230469, 0.38183594, 0.95898438, 0.99804688)

  row.collapseBtn = CreateFrame("Button", nil, row)
  row.collapseBtn:SetSize(COLLAPSE_WIDTH, ROW_HEIGHT)
  row.collapseBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.collapseBtn:SetFrameLevel(row:GetFrameLevel() + 2)
  row.collapseBtn.text = row.collapseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  row.collapseBtn.text:SetAllPoints()
  row.collapseBtn.text:SetJustifyH("CENTER")
  row.collapseBtn:SetScript("OnClick", function()
    local groupKey = row.groupKey
    expandedGroups[groupKey] = not expandedGroups[groupKey]
    renderRows()
  end)
  row.collapseBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(expandedGroups[row.groupKey] and "Combine Stacks" or "Show Stacks")
    GameTooltip:Show()
  end)
  row.collapseBtn:SetScript("OnLeave", GameTooltip_Hide)

  row.statusBtn = CreateFrame("Button", nil, row)
  row.statusBtn:SetSize(STATUS_WIDTH, STATUS_WIDTH)
  row.statusBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.statusBtn:SetFrameLevel(row:GetFrameLevel() + 2)
  row.statusBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.statusBtn.icon = row.statusBtn:CreateTexture(nil, "ARTWORK")
  row.statusBtn.icon:SetSize(14, 14)
  row.statusBtn.icon:SetPoint("CENTER")
  row.statusBtn.text = row.statusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  row.statusBtn.text:SetAllPoints()
  row.statusBtn.text:SetJustifyH("CENTER")
  row.statusBtn.text:SetText("...")
  row.statusBtn:SetScript("OnClick", function(self, button)
    if not isModuleEnabled() then return end
    if row.statusInfo.quality == nil then
      prn("item quality is not yet available.")
      return
    end
    if button == "RightButton" then
      if row.statusInfo.quality == 0 then
        prn("grey items can only be protected using the flag menu.")
        return
      end
      local status = getItemStatus(row.statusKey, row.statusInfo.quality)
      if status == ITEM_STATUSES[1] then
        setItemStatus(row.statusKey, row.statusInfo, nil)
      elseif not status then
        setItemStatus(row.statusKey, row.statusInfo, ITEM_STATUSES[1])
      else
        prn("use the flag menu to change this item's " .. status.name .. " flag.")
      end
    elseif button == "LeftButton" then
      openItemStatusMenu(self, row.statusKey, row.statusInfo)
    end
  end)
  row.statusBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local status = getItemStatus(row.statusKey, row.statusInfo.quality)
    if row.statusInfo.quality == nil then
      GameTooltip:SetText("Item quality is not yet available.")
    else
      local label = status and status.name
      GameTooltip:SetText(status and ("Flagged for: " .. label) or "Click to Flag:")
      if status and status.id == "mail" then
        local bag = settings()
        local queue = bag.mailQueues[row.statusKey]
        GameTooltip:AddLine("Mail Queue:", 1, 1, 1)
        if queue and #queue > 0 then
          for _, entry in ipairs(queue) do
            local recipient = bag.mailRecipients[entry.recipient]
            local name = recipient and (recipient.nickname .. " (" .. recipient.character .. ")") or "Unavailable"
            GameTooltip:AddLine(name .. ": " .. entry.remaining .. " remaining", 1, 1, 1)
          end
        else
          GameTooltip:AddLine("None", 1, 1, 1)
        end
        local recipient = bag.mailRecipients[bag.mailAssignments[row.statusKey]]
        local name = recipient and (recipient.nickname .. " (" .. recipient.character .. ")") or "None"
        GameTooltip:AddLine("Default Recipient: " .. name, 1, 1, 1)
      end
      local rightClick = row.statusInfo.quality == 0 and "Grey items can only be protected."
        or status and status ~= ITEM_STATUSES[1] and "Right-click cannot change this flag."
        or "Right-click to quick mark as Junk."
      GameTooltip:AddLine("Left-click to choose flag.\n" .. rightClick, 1, 1, 1, true)
      if row.statusInfo.quality == 0 then
        GameTooltip:AddLine("Blizzard's Sell All Junk and Auto-Sell ALL Grey Items ignore protection.", 1, 0.8, 0, true)
      end
    end
    GameTooltip:Show()
  end)
  row.statusBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Block pickup as well as right-click while a conflicting destination is open; the flag remains clickable.
  row.actionBlocker = CreateFrame("Button", nil, row)
  row.actionBlocker:SetPoint("TOPLEFT", row, "TOPLEFT", COLLAPSE_WIDTH, 0)
  row.actionBlocker:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -STATUS_WIDTH, 0)
  row.actionBlocker:SetFrameLevel(row:GetFrameLevel() + 1)
  row.actionBlocker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.actionBlocker:RegisterForDrag("LeftButton")
  row.actionBlocker:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if row.hyperlink then GameTooltip:SetHyperlink(row.hyperlink) else GameTooltip:SetText(row.itemName or "Item") end
    GameTooltip:AddLine("This item's flag prevents " .. self.blockedAction .. ".", 1, 0.3, 0.3, true)
    GameTooltip:Show()
  end)
  row.actionBlocker:SetScript("OnLeave", GameTooltip_Hide)
  --- Explain why a click or drag is blocked.
  ---@param self table Interaction-blocking button.
  local function reportBlockedAction(self)
    prn("this item's flag prevents " .. self.blockedAction .. ".")
  end
  row.actionBlocker:SetScript("OnClick", reportBlockedAction)
  row.actionBlocker:SetScript("OnDragStart", reportBlockedAction)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)

  row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.nameText:SetJustifyH("LEFT")

  row.qualitySwatch = row:CreateTexture(nil, "ARTWORK")
  row.qualitySwatch:SetSize(16, 16)

  row.quantityText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.upgradeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  local upgradeFont, upgradeSize, upgradeFlags = row.upgradeText:GetFont()
  if upgradeFont and upgradeSize then row.upgradeText:SetFont(upgradeFont, math.max(6, upgradeSize - 2), upgradeFlags) end
  row.upgradeText:SetWordWrap(true)
  row.vendorText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.auctionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.quantityText:SetJustifyH("RIGHT")
  row.ilvlText:SetJustifyH("LEFT")
  row.vendorText:SetJustifyH("RIGHT")
  row.auctionText:SetJustifyH("RIGHT")
  row.armorTypeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.armorSlotText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.bindIcon = row:CreateTexture(nil, "ARTWORK")
  row.bindIcon:SetSize(18, 18)

  row:HookScript("OnEnter", function(self)
    if not row.primaryEntry and row.hyperlink then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(row.hyperlink)
      GameTooltip:Show()
    end
    if selectedView() == "selling" and row.auctionData and GameTooltip:IsOwned(self) then
      local quote = row.auctionData
      GameTooltip:AddLine("Auction price (" .. quote.source .. ")", 1, 1, 1)
      if quote.minimum then GameTooltip:AddDoubleLine("Lowest per item", GetMoneyString(quote.minimum, true)) end
      if quote.average then GameTooltip:AddDoubleLine("Average per item", GetMoneyString(quote.average, true)) end
      if quote.source == "Auctionator" and not quote.average then
        GameTooltip:AddLine("Listing average unavailable in Auctionator's cache.", 0.7, 0.7, 0.7)
      end
      if quote.timestamp then
        GameTooltip:AddLine("Cached: " .. date("%Y-%m-%d %H:%M", quote.timestamp), 0.7, 0.7, 0.7)
      elseif quote.ageDays then
        GameTooltip:AddLine(("Last scan: %d day(s) ago"):format(quote.ageDays), 0.7, 0.7, 0.7)
      end
      GameTooltip:Show()
    elseif selectedView() == "gear" and row.comparisons and gear and GameTooltip:IsOwned(self) then
      GameTooltip:AddLine("Compared with equipped gear:", 1, 1, 1)
      for _, comparison in ipairs(row.comparisons) do
        GameTooltip:AddLine(gear.FormatComparison(comparison, #row.comparisons > 1), 1, 1, 1, true)
      end
      GameTooltip:Show()
    end
  end)

  -- Keep the flag key while the item is on the cursor, even if its row is later recycled.
  row:HookScript("OnClick", function(self, button)
    if button == "LeftButton" then rememberPickedUpItem(self) end
  end)
  row:HookScript("OnDragStart", rememberPickedUpItem)

  -- Blizzard's own split dialog (opened by its inherited OnModifiedClick) leaves the split stack on
  -- the cursor, requiring the player to click a bag slot to place it. Hooking (not replacing)
  -- OnModifiedClick lets us wrap the SplitStack closure it just set -- after Blizzard's own split
  -- call -- so the split amount gets auto-placed into a free slot instead.
  hooksecurefunc(row, "OnModifiedClick", function(self)
    local splitStack = self.SplitStack
    if type(splitStack) == "function" and not autoPlaceSplitStacks[splitStack] then
      local splitItem = { hyperlink = self.hyperlink, statusKey = self.statusKey, statusInfo = self.statusInfo }
      local wrapped = function(splitSelf, split)
        splitStack(splitSelf, split)
        rememberPickedUpItem(splitItem)
        if GetCursorInfo() then
          local emptyBagID, emptySlot = findEmptyBagSlot()
          if emptyBagID then
            C_Container.PickupContainerItem(emptyBagID, emptySlot)
          end
        end
      end
      autoPlaceSplitStacks[wrapped] = true
      self.SplitStack = wrapped
    end
  end)
  return row
end

local function acquireRow(index)
  local row = rowPool[index]
  if not row then
    row = createRow(index)
    rowPool[index] = row
  end
  return row
end

positionRowCells = function(row)
  row.icon:ClearAllPoints()
  row.nameText:ClearAllPoints()
  row.qualitySwatch:ClearAllPoints()
  row.bindIcon:ClearAllPoints()
  local nameLayout = columnLayout.name
  local indent = row.isChild and 14 or 0
  row.icon:SetPoint("LEFT", row, "LEFT", nameLayout.x + indent, 0)
  row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
  row.nameText:SetWidth(math.max(20, nameLayout.width - indent - ROW_HEIGHT - 19))

  for _, colID in ipairs({ "quantity", "ilvl", "upgrade", "vendor", "auction", "armorType", "armorSlot" }) do
    local cell = row[colID .. "Text"]
    cell:ClearAllPoints()
    local layout = columnLayout[colID]
    cell:SetShown(layout ~= nil)
    if layout then
      cell:SetPoint("LEFT", row, "LEFT", layout.x, 0)
      cell:SetWidth(layout.width)
    end
  end

  local qualityOffset = math.min(row.nameText:GetStringWidth(), row.nameText:GetWidth())
  row.qualitySwatch:SetPoint("LEFT", row.nameText, "LEFT", qualityOffset + 4, 0)
  row.bindIcon:SetPoint("LEFT", row, "LEFT", columnLayout.bind.x + (columnLayout.bind.width - 10) / 2, 0)
end

--=====================================================================
-- Rendering
--=====================================================================

-- Flattens grouped items into the final display list: one row per group, plus (when expanded) one
-- child row per underlying bag slot so a specific stack can be dragged/split/locked individually.
--- Build display rows for groups that match the selected filters.
---@return table rows Visible item rows.
local function buildDisplayRows()
  local groups = collectGroups()
  local rows = {}
  local filterAuction = selectedView() == "selling" and ahMode and auctionEligibilityAvailable()
  for _, group in ipairs(groups) do
    if matchesFilters(group) and (selectedView() ~= "gear" or matchesGearFilters(group))
      and (not filterAuction or filterAuctionEntries(group)) then
      group.isGroupHeader = #group.entries > 1
      rows[#rows + 1] = group
      if group.isGroupHeader and expandedGroups[group.key] then
        for _, entry in ipairs(group.entries) do
          rows[#rows + 1] = {
            isChild = true,
            groupKey = group.key,
            itemID = group.itemID,
            hyperlink = group.hyperlink,
            itemName = group.itemName,
            icon = group.icon,
            quality = group.quality,
            craftedQuality = group.craftedQuality,
            qualityAtlas = group.qualityAtlas,
            count = entry.count,
            entries = { entry },
            isArmor = group.isArmor,
            isEquipment = group.isEquipment,
            itemLevel = group.itemLevel,
            upgradeTrack = group.upgradeTrack,
            armorType = group.armorType,
            armorSlot = group.armorSlot,
            comparisons = group.comparisons,
            itemStats = group.itemStats,
            sellPrice = group.sellPrice,
            auction = group.auction,
            bindLabel = group.bindLabel,
            bindType = group.bindType,
            accountBound = group.accountBound,
            isBound = entry.isBound,
            statusKey = group.statusKey,
            statusInfo = group.statusInfo,
          }
        end
      end
    end
  end
  return rows
end

renderRows = function()
  if not frame or not frame:IsShown() then return end
  layoutHeaders()

  local rows = buildDisplayRows()
  local y = 0
  for i, data in ipairs(rows) do
    local row = acquireRow(i)
    row.holder:SetHeight(ROW_HEIGHT)
    row:SetHeight(ROW_HEIGHT)
    row.holder:ClearAllPoints()
    row.holder:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
    row.holder:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    row.holder:Show()
    row:Show()
    row.stripe:SetShown(i % 2 == 0) -- alternating-row banding, same look as the guild roster list
    row.itemID = data.itemID
    row.itemName = data.itemName
    row.hyperlink = data.hyperlink
    row.isChild = data.isChild
    row.groupKey = data.isGroupHeader and data.key or nil
    row.statusKey = data.statusKey
    row.statusInfo = data.statusInfo
    row.comparisons = data.comparisons
    row.auctionData = not data.isBound and not data.accountBound and data.auction or nil
    row.primaryEntry = data.entries and data.entries[1]
    row.locked = isProtectedItem(data.statusKey)
    row.holder:SetID(row.primaryEntry and row.primaryEntry.bagID or 0)
    row:SetID(row.primaryEntry and row.primaryEntry.slot or 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    updateInteractionBlocker(row, data.statusKey, data.quality)

    if data.isGroupHeader then
      row.collapseBtn:Show()
      row.collapseBtn.text:SetText(expandedGroups[data.key] and "-" or "+")
    else
      row.collapseBtn:Hide()
    end

    updateStatusButton(row.statusBtn, getItemStatus(data.statusKey, data.quality))

    row.icon:SetTexture(data.icon)
    local qualityColor = ITEM_QUALITY_COLORS[data.quality or 1] or ITEM_QUALITY_COLORS[1]
    row.nameText:SetText(data.itemName or "?")
    if qualityColor then
      row.nameText:SetTextColor(qualityColor.color:GetRGB())
    end
    if data.qualityAtlas then
      row.qualitySwatch:SetAtlas(data.qualityAtlas)
      row.qualitySwatch:Show()
    else
      row.qualitySwatch:Hide()
    end

    row.quantityText:SetText((data.count or 1) > 1 and tostring(data.count) or "")
    row.vendorText:SetText(selectedView() == "selling" and data.sellPrice and data.sellPrice > 0
      and GetMoneyString(data.sellPrice, true) or "")
    if selectedView() ~= "selling" then
      row.auctionText:SetText("")
    elseif data.accountBound then
      row.auctionText:SetText("|cff9d9d9dWarbound|r")
    elseif data.isBound then
      row.auctionText:SetText("|cff9d9d9dSoulbound|r")
    elseif data.auction and data.auction.minimum then
      local trend = data.auction.trend
      local suffix = trend and (" |c%s%s%%|r"):format(
        trend.direction == "up" and "ff40ff40" or trend.direction == "down" and "ffff4040" or "ffbfbfbf",
        trend.percent > 0 and ("+" .. trend.percent) or tostring(trend.percent)) or ""
      row.auctionText:SetText(GetMoneyString(data.auction.minimum, true) .. suffix)
    elseif data.auction and data.auction.timestamp then
      row.auctionText:SetText("|cff9d9d9dNo listings|r")
    else
      row.auctionText:SetText("|cff9d9d9dUnavailable|r")
    end
    if data.comparisons then
      local text = {}
      for _, comparison in ipairs(data.comparisons) do
        text[#text + 1] = gear.FormatComparison(comparison, #data.comparisons > 1)
      end
      row.upgradeText:SetText(table.concat(text, "\n"))
    else
      row.upgradeText:SetText("")
    end
    if (data.isArmor or selectedView() == "gear" and data.isEquipment) and data.itemLevel then
      local upgradeTrack = data.upgradeTrack and (" |cff9d9d9d" .. data.upgradeTrack .. "|r") or ""
      row.ilvlText:SetText(tostring(data.itemLevel) .. upgradeTrack)
    else
      row.ilvlText:SetText("")
    end
    local showEquipment = data.isArmor or selectedView() == "gear" and data.isEquipment
    row.armorTypeText:SetText(showEquipment and data.armorType or "")
    row.armorSlotText:SetText(showEquipment and data.armorSlot or "")
    if data.bindType and data.bindType > 0 then
      local bindType = data.bindType == 4 and 1 or data.bindType
      local x = (bindType - 1) / 4
      local y = data.isBound and 0 or 0.5
      if data.accountBound then
        if bindType == 1 then
          x = 0.75
        elseif bindType == 2 then
          x = data.isBound and 0 or 0.75
        end
      end
      row.bindIcon:SetTexture(BIND_ICON_TEXTURE)
      row.bindIcon:SetTexCoord(x, x + 0.25, y, y + 0.5)
      row.bindIcon:Show()
    else
      row.bindIcon:Hide()
    end

    positionRowCells(row)
    local height = ROW_HEIGHT
    if selectedView() == "gear" and data.comparisons then
      local textHeight = row.upgradeText:GetStringHeight()
      if textHeight then height = math.max(height, math.ceil(textHeight) + 4) end
    end
    row.holder:SetHeight(height)
    row:SetHeight(height)
    y = y + height
  end
  scrollChild:SetHeight(math.max(scrollFrame:GetHeight(), y))

  for i = #rows + 1, #rowPool do
    rowPool[i].holder:Hide()
  end
end

--=====================================================================
-- Footer: bag slots, gold, tracked currencies, and a Currency panel shortcut
--=====================================================================

local function crestTokenOnEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetCurrencyByID(self.currencyID)
  GameTooltip:Show()
end

local function crestTokenOnClick(self)
  if IsModifiedClick("CHATLINK") and HandleModifiedItemClick(C_CurrencyInfo.GetCurrencyLink(self.currencyID)) then
    return
  end
  ToggleCharacter("TokenFrame")
end

--- Refresh current-season crest buttons on Retail.
---@param self table Crest currency frame.
local function updateCrestFrame(self)
  self.tokenPool:ReleaseAll()
  self.Tokens = {}
  self.numWatchedTokens = 0
  if not isRetail() then return end
  for _, currencyID in ipairs(CREST_CURRENCY_IDS) do
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info then
      local token = self.tokenPool:Acquire()
      token.currencyID = currencyID
      token.Icon:SetTexture(info.iconFileID)
      local quantity = info.quantity or 0
      local text = BreakUpLargeNumbers(quantity)
      if strlenutf8(text) > 5 then text = AbbreviateNumbers(quantity) end
      token.Count:SetText(text)
      token:SetScript("OnEnter", crestTokenOnEnter)
      token:SetScript("OnClick", crestTokenOnClick)
      token:ClearAllPoints()
      token:SetPoint("LEFT", self, "LEFT", 13 + #self.Tokens * token:GetWidth(), -1)
      token:Show()
      self.Tokens[#self.Tokens + 1] = token
    end
  end
  self.numWatchedTokens = #self.Tokens
end

--- Size a token frame to its native currency buttons.
---@param currencyFrame table Currency token frame.
---@return number width Total frame width.
local function resizeCurrencyFrame(currencyFrame)
  local width = 26
  for _, token in ipairs(currencyFrame.Tokens or {}) do
    width = width + token:GetWidth()
  end
  currencyFrame:SetWidth(width)
  return width
end

--- Size the currency frame and return its visible width.
---@param currencyFrame table Currency token frame.
---@return number width Visible frame width, or zero when hidden.
local function sizeCurrencyFrame(currencyFrame)
  local width = resizeCurrencyFrame(currencyFrame)
  local shown = currencyFrame:ShouldShow()
  currencyFrame:SetShown(shown)
  return shown and width or 0
end

--- Update the dropdown label to count filters that restrict the displayed items.
local function updateFiltersLabel()
  local bag = settings()
  local count = 0
  if bag.flagFilters.unflagged == false then count = count + 1 end
  for _, status in ipairs(ITEM_STATUSES) do
    if bag.flagFilters[status.id] == false then count = count + 1 end
  end
  for _, binding in ipairs(BINDING_FILTERS) do
    if (not binding.retailOnly or isRetail()) and bag.bindingFilters[binding.id] == false then count = count + 1 end
  end
  for _, category in ipairs(ITEM_CATEGORIES) do
    if bag.categoryFilters[category.id] == false then count = count + 1 end
  end
  local label = ("Filters (%s)"):format(count == 0 and "None" or count)
  if footer.filtersButton.legacy then
    UIDropDownMenu_SetText(footer.filtersButton, label)
  else
    footer.filtersButton:OverrideText(label)
  end
end

--- Choose a white-to-red color based on the proportion of remaining warning-range slots.
---@param totalSlots number Counted bag capacity.
---@param freeSlots number Available counted slots.
---@return string color Color-code prefix for the slot count.
local function slotCountColor(totalSlots, freeSlots)
  -- Start warning at roughly 7.5% free, bounded from three slots for a backpack to six for large bags.
  local warningSlots = math.min(6, math.max(3, math.ceil(totalSlots * 0.075)))
  local pressure = math.max(0, math.min(1, (warningSlots + 1 - freeSlots) / (warningSlots + 1)))
  local green, blue
  if pressure <= 1 / 3 then
    green, blue = 1, 1 - pressure * 3
  elseif pressure <= 2 / 3 then
    green, blue = 1 - (pressure * 3 - 1) / 2, 0
  else
    green, blue = (3 - pressure * 3) / 2, 0
  end
  return ("|cffff%02x%02x"):format(math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
end

--- Add an item stack to a named tooltip breakdown.
---@param breakdown table Item variants keyed by link or item ID.
---@param info table Container item information.
---@param name string|nil Item name.
---@param link string|nil Item link.
---@param itemLevel number|nil Base item level.
---@param icon number|string|nil Item icon.
---@param quality number|nil Item quality.
---@param bagID number|nil Bag containing the item.
---@param slot number|nil Slot containing the item.
local function addSlotBreakdown(breakdown, info, name, link, itemLevel, icon, quality, bagID, slot)
  local key = link or info.itemID
  local entry = breakdown[key]
  if not entry then
    entry = { label = link or name or ("Item #" .. info.itemID), name = name or "", count = 0, icon = icon,
      itemID = info.itemID, link = link, quality = quality or info.quality, bagID = bagID, slot = slot,
      itemLevel = C_Item.GetDetailedItemLevelInfo(link or info.itemID) or itemLevel }
    breakdown[key] = entry
  else
    entry.icon = entry.icon or icon
    entry.itemLevel = entry.itemLevel or itemLevel
    entry.quality = entry.quality or quality or info.quality
  end
  entry.count = entry.count + (info.stackCount or 1)
end

--- Add a bag item to the consumable categories it belongs to.
---@param lists table Bandage, health, and mana breakdowns.
---@param info table Container item information.
---@param name string|nil Item name.
---@param link string|nil Item hyperlink.
---@param itemLevel number|nil Item level.
---@param icon number|string|nil Item icon.
---@param quality number|nil Item quality.
---@param classID number|nil Item class.
---@param subclassID number|nil Item subclass.
---@param showMana boolean Whether the player's class can use mana.
---@param bagID number Bag identifier.
---@param slot number Bag slot.
local function addConsumableBreakdowns(lists, info, name, link, itemLevel, icon, quality, classID, subclassID, showMana, bagID, slot)
  local id = info.itemID
  if (BEST_ITEMS and BEST_ITEMS.BEST_BANDAGES[id]) or ADDITIONAL_BANDAGES[id]
    or (classID == 0 and subclassID == ((Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Bandage) or 7)) then
    addSlotBreakdown(lists.bandages, info, name, link, itemLevel, icon, quality, bagID, slot)
  end
  if (BEST_ITEMS and BEST_ITEMS.BEST_HEALING_POTIONS[id])
    or ADDITIONAL_HEALTH_POTIONS[id] or REJUVENATION_POTIONS[id] then
    addSlotBreakdown(lists.health, info, name, link, itemLevel, icon, quality, bagID, slot)
  end
  if showMana and ((BEST_ITEMS and BEST_ITEMS.BEST_MANA_POTIONS[id])
    or ADDITIONAL_MANA_POTIONS[id] or REJUVENATION_POTIONS[id]) then
    addSlotBreakdown(lists.mana, info, name, link, itemLevel, icon, quality, bagID, slot)
  end
end

--- Add an inline item icon when its texture is available.
---@param label string Item label.
---@param icon number|string|nil Item icon.
---@return string text Label with icon markup.
local function slotItemLabel(label, icon)
  return icon and ("|T%s:18:18|t %s"):format(icon, label) or label
end

local slotItemLoads = {}
local tooltipFonts = {}
local tooltipFontHooked = false

--- Restore the shared tooltip's modified line fonts before it is reused.
local function restoreTooltipFonts()
  for _, saved in ipairs(tooltipFonts) do
    saved.text:SetFont(saved.path, saved.size, saved.flags)
  end
  wipe(tooltipFonts)
end

--- Shrink both columns of the current tooltip line.
local function shrinkTooltipLine()
  local line = GameTooltip:NumLines()
  for _, side in ipairs({ "Left", "Right" }) do
    local text = _G["GameTooltipText" .. side .. line]
    if text then
      local path, size, flags = text:GetFont()
      if path and size then
        tooltipFonts[#tooltipFonts + 1] = { text = text, path = path, size = size, flags = flags }
        text:SetFont(path, math.max(6, size - 2), flags)
      end
    end
  end
end

--- Display individual item variants and, optionally, their total in the inventory tooltip.
---@param title string Breakdown heading.
---@param breakdown table Item variants keyed by link or item ID.
---@param showTotal boolean Whether to display the combined quantity.
---@param hideHeading boolean|nil Hide the heading when entries are present.
local function showSlotBreakdown(title, breakdown, showTotal, hideHeading)
  local entries, total = {}, 0
  for _, entry in pairs(breakdown) do
    entries[#entries + 1] = entry
    if showTotal then total = total + entry.count end
  end
  table.sort(entries, function(a, b)
    if (a.itemLevel or -1) ~= (b.itemLevel or -1) then return (a.itemLevel or -1) > (b.itemLevel or -1) end
    if a.name ~= b.name then return a.name < b.name end
    return a.label < b.label
  end)
  if #entries == 0 then
    GameTooltip:AddDoubleLine(title, "(None)", 1, 1, 1, 1, 1, 1)
  elseif showTotal then
    GameTooltip:AddDoubleLine(title, tostring(total), 1, 1, 1, 1, 1, 1)
  elseif not hideHeading then
    GameTooltip:AddLine(title, 1, 1, 1)
  end
  for _, entry in ipairs(entries) do
    GameTooltip:AddDoubleLine(slotItemLabel(entry.label, entry.icon), tostring(entry.count), 1, 1, 1, 1, 1, 1)
    shrinkTooltipLine()
  end
end

--- Record an item whose tooltip data is incomplete.
---@param missing table Items with incomplete data, keyed by item ID.
---@param itemID number Item identifier.
---@param label string Item link or fallback label.
---@param required boolean Whether visible or classification data is missing.
local function markSlotItemMissing(missing, itemID, label, required)
  local entry = missing[itemID]
  if not entry then
    entry = { label = label }
    missing[itemID] = entry
  end
  entry.required = entry.required or required
end

--- Show physical capacity and inventory statistics, independent of active bag filters.
---@param owner table Mouse-enabled slot-count frame.
local function showSlotTooltip(owner)
  if not isModuleEnabled() then return end
  local totalSlots, freeSlots, reagentSlots, reagentFree = 0, 0, 0, 0
  local ammoSlots, ammoFree, ammoBagName = 0, 0, nil
  local categories, ammo, bandages, health, mana = {}, {}, {}, {}, {}
  local consumables = { bandages = bandages, health = health, mana = mana }
  local shards, shardIcon, missing = 0, nil, {}
  local bag = settings()
  local forever = isForever()
  local class = select(2, UnitClass("player"))
  local showAmmo = forever and RANGED_AMMO_CLASSES[class]
  local showMana = MANA_CLASSES[class] or (forever and class == "HUNTER")
  for _, bagID in ipairs(bagIDs()) do
    local slots = C_Container.GetContainerNumSlots(bagID)
    local free, family = C_Container.GetContainerNumFreeSlots(bagID)
    if bagID == REAGENT_BAG_ID then
      reagentSlots, reagentFree = slots, free
    elseif forever and family and family % 4 ~= 0 and slots > 0 then
      -- Bag family bits 1 and 2 identify quivers and ammunition pouches.
      local name = family % 4 == 1 and "Quiver" or family % 4 == 2 and "Shot bag" or "Ammo bag"
      ammoBagName = ammoBagName and ammoBagName ~= name and "Ammo bag" or ammoBagName or name
      ammoSlots, ammoFree = ammoSlots + slots, ammoFree + free
    else
      totalSlots, freeSlots = totalSlots + slots, freeSlots + free
    end
    for slot = 1, slots do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID then
        local name, link, quality, itemLevel, _, _, _, _, equipLoc, itemIcon, sellPrice, classID, subclassID,
          bindType, _, _, isCraftingReagent = C_Item.GetItemInfo(info.hyperlink or info.itemID)
        if not name and info.hyperlink then
          name, link, quality, itemLevel, _, _, _, _, equipLoc, itemIcon, sellPrice, classID, subclassID,
            bindType, _, _, isCraftingReagent = C_Item.GetItemInfo(info.itemID)
          link = info.hyperlink
        end
        name, link, quality = name or info.itemName, link or info.hyperlink, quality or info.quality
        itemIcon = info.iconFileID or itemIcon
        local count = info.stackCount or 1
        if classID == nil or quality == nil or sellPrice == nil then
          markSlotItemMissing(missing, info.itemID, link or name or ("Item #" .. info.itemID), true)
        else
          local group = { itemID = info.itemID, classID = classID, subclassID = subclassID,
            quality = quality, equipLoc = equipLoc, sellPrice = sellPrice, bindType = bindType,
            isCraftingReagent = isCraftingReagent }
          local category = itemCategory(group, bag)
          categories[category] = (categories[category] or 0) + count
          -- Match the filters: edible Forever fish belong to both categories unless Essential.
          if category == "consumables" and forever and FOREVER_EDIBLE_RAW_FISH_IDS[info.itemID] then
            categories.reagents = (categories.reagents or 0) + count
          end
        end
        if showAmmo and classID == PROJECTILE_CLASS_ID
          and (subclassID == ARROW_SUBCLASS_ID or subclassID == SHOT_SUBCLASS_ID) then
          addSlotBreakdown(ammo, info, name, link, itemLevel, itemIcon)
        end
        if forever and class == "WARLOCK" and info.itemID == SOUL_SHARD_ITEM_ID then
          shards, shardIcon = shards + count, shardIcon or itemIcon
        end
        addConsumableBreakdowns(consumables, info, name, link, itemLevel, itemIcon, quality,
          classID, subclassID, showMana, bagID, slot)
        if not name then
          markSlotItemMissing(missing, info.itemID, link or ("Item #" .. info.itemID), true)
        end
      end
    end
  end

  if shards > 0 and not shardIcon then
    markSlotItemMissing(missing, SOUL_SHARD_ITEM_ID, "Soul Shards", true)
  end
  for _, breakdown in ipairs({ ammo, bandages, health, mana }) do
    for _, entry in pairs(breakdown) do
      if entry.itemLevel == nil or not entry.icon then
        markSlotItemMissing(missing, entry.itemID, entry.label, not entry.icon)
      end
    end
  end

  local loading, unavailable = {}, {}
  for itemID, entry in pairs(missing) do
    local cached = C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(itemID)
    if cached then
      -- Non-equipment may lack an item level even after its data has loaded.
      if entry.required then unavailable[#unavailable + 1] = entry.label end
    elseif slotItemLoads[itemID] == "failed" then
      unavailable[#unavailable + 1] = entry.label
    else
      if C_Item.RequestLoadItemDataByID and not slotItemLoads[itemID] then
        slotItemLoads[itemID] = "pending"
        C_Item.RequestLoadItemDataByID(itemID)
      end
      loading[#loading + 1] = entry.label
    end
  end
  table.sort(loading)
  table.sort(unavailable)
  -- GameTooltip reuses its font strings for unrelated tooltips, so restore them on clear.
  if not tooltipFontHooked then
    GameTooltip:HookScript("OnTooltipCleared", restoreTooltipFonts)
    tooltipFontHooked = true
  end
  restoreTooltipFonts()
  GameTooltip:SetOwner(owner, "ANCHOR_TOPLEFT")
  GameTooltip:SetText("Inventory Summary")
  GameTooltip:AddDoubleLine("Normal bags", ("%d / %d (%d free)"):format(totalSlots - freeSlots, totalSlots, freeSlots),
    1, 1, 1, 1, 1, 1)
  if isRetailOrForever() then
    GameTooltip:AddDoubleLine("Reagent bag", ("%d / %d (%d free)"):format(
      reagentSlots - reagentFree, reagentSlots, reagentFree), 1, 1, 1, 1, 1, 1)
  end
  if ammoBagName then
    GameTooltip:AddDoubleLine(ammoBagName, ("%d / %d (%d free)"):format(
      ammoSlots - ammoFree, ammoSlots, ammoFree), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine("Categories", 1, 0.82, 0)
  for _, category in ipairs(ITEM_CATEGORIES) do
    GameTooltip:AddDoubleLine(category.name, tostring(categories[category.id] or 0), 1, 1, 1, 1, 1, 1)
    shrinkTooltipLine()
  end
  if showAmmo then
    GameTooltip:AddLine("Ammo", 1, 0.82, 0)
    if next(ammo) then
      showSlotBreakdown("Ammo", ammo, false, true)
    else
      GameTooltip:AddLine("(None)", 1, 1, 1)
    end
  end
  GameTooltip:AddLine("Consumables", 1, 0.82, 0)
  if forever and class == "WARLOCK" then
    GameTooltip:AddDoubleLine(slotItemLabel("Soul Shards", shardIcon),
      shards > 0 and tostring(shards) or "(None)", 1, 1, 1, 1, 1, 1)
  end
  showSlotBreakdown("Bandages", bandages, true)
  showSlotBreakdown("Health Potions", health, true)
  if showMana then
    showSlotBreakdown("Mana Potions", mana, true)
  end
  if #loading > 0 then
    GameTooltip:AddLine("Item information is still loading:", 1, 0.82, 0)
    for index = 1, math.min(5, #loading) do GameTooltip:AddLine(loading[index], 1, 0.82, 0) end
    if #loading > 5 then GameTooltip:AddLine(("%d more..."):format(#loading - 5), 1, 0.82, 0) end
  end
  if #unavailable > 0 then
    GameTooltip:AddLine("Item information is unavailable:", 1, 0.82, 0)
    for index = 1, math.min(5, #unavailable) do GameTooltip:AddLine(unavailable[index], 1, 0.82, 0) end
    if #unavailable > 5 then GameTooltip:AddLine(("%d more..."):format(#unavailable - 5), 1, 0.82, 0) end
  end
  GameTooltip:Show()
end

--- Collect equipped arrows or thrown durability and Warlock Soul Shards.
---@return table supplies Ordered available footer entries.
local function collectFooterSupplies()
  local result = {}
  local class = select(2, UnitClass("player"))
  local rangedSlot = GetInventorySlotInfo("RangedSlot")
  local rangedItem = rangedSlot and (GetInventoryItemLink("player", rangedSlot) or GetInventoryItemID("player", rangedSlot))
  local equipLoc = rangedItem and select(4, C_Item.GetItemInfoInstant(rangedItem))
  if equipLoc == "INVTYPE_THROWN" then
    local current, maximum = GetInventoryItemDurability(rangedSlot)
    local available = current and maximum and maximum > 0
    result[#result + 1] = { inventorySlot = rangedSlot, icon = GetInventoryItemTexture("player", rangedSlot),
      text = available and (current .. "/" .. maximum) or "?",
      unavailable = not available and "Durability unavailable." or nil }
  else
    local ammoSlot = GetInventorySlotInfo("AmmoSlot")
    local ammoID = ammoSlot and GetInventoryItemID("player", ammoSlot)
    local ammoIcon, classID, subclassID
    if ammoID then ammoIcon, classID, subclassID = select(5, C_Item.GetItemInfoInstant(ammoID)) end
    if classID == PROJECTILE_CLASS_ID and subclassID == ARROW_SUBCLASS_ID then
      local count = GetInventoryItemCount("player", ammoSlot)
      result[#result + 1] = { inventorySlot = ammoSlot, icon = GetInventoryItemTexture("player", ammoSlot) or ammoIcon,
        text = count and tostring(count) or "?", unavailable = not count and "Ammunition count unavailable." or nil }
    end
  end
  local shard
  if class == "WARLOCK" then
    for _, bagID in ipairs(bagIDs()) do
      for slot = 1, C_Container.GetContainerNumSlots(bagID) do
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID == SOUL_SHARD_ITEM_ID then
          local icon = info.iconFileID or select(10, C_Item.GetItemInfo(info.hyperlink or info.itemID))
          if not shard then shard = { bagID = bagID, slot = slot, itemID = info.itemID, icon = icon, count = 0 } end
          shard.icon = shard.icon or icon
          shard.count = shard.count + (info.stackCount or 1)
        end
      end
    end
  end
  if shard then
    shard.text = tostring(shard.count)
    result[#result + 1] = shard
  end
  return result
end

--- Show the native tooltip for a footer item.
---@param button table Supply button.
local function supplyOnEnter(button)
  GameTooltip:SetOwner(button, "ANCHOR_TOPLEFT")
  if button.supply.inventorySlot then
    GameTooltip:SetInventoryItem("player", button.supply.inventorySlot)
  else
    GameTooltip:SetBagItem(button.supply.bagID, button.supply.slot)
  end
  if button.supply.unavailable then GameTooltip:AddLine(button.supply.unavailable, 1, 0.82, 0) end
  GameTooltip:Show()
end

--- Update the compact item strip and return its measured width.
---@param supplyFrame table Frame containing the supply buttons.
---@return number width Strip width, or zero when not shown.
local function updateSupplyFrame(supplyFrame)
  local items = isForever() and collectFooterSupplies() or {}
  local width = 0
  for index, item in ipairs(items) do
    local button = supplyFrame.buttons[index]
    if not button then
      button = CreateFrame("Frame", nil, supplyFrame)
      button:SetHeight(20)
      button:EnableMouse(true)
      button.Icon = button:CreateTexture(nil, "ARTWORK")
      button.Icon:SetSize(FOOTER_ICON_SIZE, FOOTER_ICON_SIZE)
      button.Count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      button.Count:SetPoint("LEFT", button, "LEFT")
      button.Icon:SetPoint("LEFT", button.Count, "RIGHT", FOOTER_ICON_GAP, 0)
      button:SetScript("OnEnter", supplyOnEnter)
      button:SetScript("OnLeave", GameTooltip_Hide)
      supplyFrame.buttons[index] = button
    end
    button.supply = item
    button.Icon:SetTexture(item.icon or 134400)
    button.Count:SetText(item.text)
    button:ClearAllPoints()
    button:SetPoint("LEFT", supplyFrame, "LEFT", width, 0)
    button:SetWidth(FOOTER_ICON_SIZE + FOOTER_ICON_GAP + button.Count:GetStringWidth())
    button:Show()
    width = width + button:GetWidth() + 4
    if GameTooltip:IsOwned(button) then supplyOnEnter(button) end
  end
  for index = #items + 1, #supplyFrame.buttons do
    local button = supplyFrame.buttons[index]
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    button:Hide()
  end
  if width > 0 then width = width - 4 end
  supplyFrame:SetWidth(math.max(1, width))
  supplyFrame:SetShown(width > 0)
  return width
end

--- Refresh the footer slots, balances, and filter summary.
local function updateFooter()
  updateFiltersLabel()
  local totalSlots, freeSlots = 0, 0
  for _, bagID in ipairs(bagIDs()) do
    local slots = C_Container.GetContainerNumSlots(bagID)
    local free = C_Container.GetContainerNumFreeSlots(bagID)
    if bagID == REAGENT_BAG_ID then
      -- Reagent-only space counts as one slot at most, since it cannot hold general items.
      free = slots > 0 and free > 0 and 1 or 0
      slots = slots > 0 and 1 or 0
    end
    totalSlots = totalSlots + slots
    freeSlots = freeSlots + free
  end
  footer.slotCount:SetText(("%s%d / %d|r"):format(
    slotCountColor(totalSlots, freeSlots), totalSlots - freeSlots, totalSlots))
  MoneyFrame_Update(footer.moneyFrame:GetName(), GetMoney())
  footer.moneyFrame:SetWidth(footer.moneyFrame:GetWidth() + 13)
  footer.tokenFrame:Update()
  local tokenWidth = sizeCurrencyFrame(footer.tokenFrame)
  footer.crestFrame:Update()
  local crestWidth = sizeCurrencyFrame(footer.crestFrame)
  local supplyWidth = updateSupplyFrame(footer.supplyFrame)
  local width = footer.moneyFrame:GetWidth()
  footer.tokenFrame:ClearAllPoints()
  footer.tokenFrame:SetPoint("RIGHT", footer.moneyFrame, "LEFT", -4, 0)
  if tokenWidth > 0 then width = width + tokenWidth + 4 end
  footer.crestFrame:ClearAllPoints()
  if tokenWidth > 0 then
    footer.crestFrame:SetPoint("RIGHT", footer.tokenFrame, "LEFT", -4, 0)
  else
    footer.crestFrame:SetPoint("RIGHT", footer.moneyFrame, "LEFT", -4, 0)
  end
  if crestWidth > 0 then width = width + crestWidth + 4 end

  footer.slotCount:SetFont(footer.slotFont, footer.slotFontSize, footer.slotFontFlags)
  local available = footer:GetWidth() - 12 - (supplyWidth > 0 and SUPPLY_MARGIN or 0)
  local combinedWidth = width + supplyWidth
  local textWidth = footer.slotCount:GetStringWidth()
  local iconWidth = FOOTER_ICON_SIZE + FOOTER_ICON_GAP
  local slotWidth = textWidth + iconWidth
  local scale
  local iconScale = 1
  if supplyWidth > 0 then
    -- Keep the slot text and the supply text at the same effective size when the footer is crowded.
    scale = math.min(1, math.max(0.01, available / (combinedWidth + slotWidth)))
    footer.slotCount:SetFont(footer.slotFont, footer.slotFontSize * scale, footer.slotFontFlags)
    iconScale = scale
  else
    if combinedWidth + slotWidth > available and textWidth > 0 then
      local fontSize = math.max(math.min(7, footer.slotFontSize),
        math.floor(footer.slotFontSize * (available - combinedWidth - iconWidth) / textWidth))
      footer.slotCount:SetFont(footer.slotFont, fontSize, footer.slotFontFlags)
    end
    slotWidth = footer.slotCount:GetStringWidth() + iconWidth
    scale = math.min(1, math.max(0.01, (available - slotWidth) / combinedWidth))
  end
  footer.slotIcon:SetSize(FOOTER_ICON_SIZE * iconScale, FOOTER_ICON_SIZE * iconScale)
  footer.slotIcon:ClearAllPoints()
  footer.slotIcon:SetPoint("LEFT", footer.slotCount, "RIGHT", FOOTER_ICON_GAP * iconScale, 0)
  slotWidth = footer.slotCount:GetStringWidth() + iconWidth * iconScale
  footer.balanceContents:SetWidth(width)
  footer.balanceContents:SetScale(scale)
  footer.balances:SetWidth(width * scale)
  footer.supplyFrame:SetScale(scale)
  footer.supplies:SetWidth(math.max(1, supplyWidth * scale))
  footer.slotHover:SetWidth(slotWidth)
  if GameTooltip:IsOwned(footer.slotHover) then showSlotTooltip(footer.slotHover) end
end

--- Populate the native filters dropdown or open its legacy menu.
---@param anchor table Filters dropdown.
---@param root table|nil Modern menu description, absent for the legacy menu.
local function openFiltersMenu(anchor, root)
  local bag = settings()
  --- Enable every visible filter without changing other bag settings.
  local function checkAll()
    bag.flagFilters.unflagged = true
    for _, status in ipairs(ITEM_STATUSES) do bag.flagFilters[status.id] = true end
    for _, binding in ipairs(BINDING_FILTERS) do
      if not binding.retailOnly or isRetail() then bag.bindingFilters[binding.id] = true end
    end
    for _, category in ipairs(ITEM_CATEGORIES) do bag.categoryFilters[category.id] = true end
    updateFiltersLabel()
    renderRows()
  end
  --- Toggle a filter and refresh the displayed rows.
  ---@param filters table Saved filter values.
  ---@param key string Filter key.
  local function toggle(filters, key)
    filters[key] = filters[key] == false
    updateFiltersLabel()
    renderRows()
  end
  if root then
    local checkAllButton = root:CreateButton("Show All", checkAll)
    checkAllButton:SetResponse(MenuResponse.Refresh)
    root:CreateTitle("Flags")
    root:CreateCheckbox("Unflagged", function() return bag.flagFilters.unflagged ~= false end,
      function() toggle(bag.flagFilters, "unflagged") end)
    for _, entry in ipairs(ITEM_STATUSES) do
      local status = entry
      root:CreateCheckbox(status.name, function() return bag.flagFilters[status.id] ~= false end,
        function() toggle(bag.flagFilters, status.id) end)
    end
    root:CreateDivider()
    root:CreateTitle("Binding")
    for _, entry in ipairs(BINDING_FILTERS) do
      local binding = entry
      if not binding.retailOnly or isRetail() then
        root:CreateCheckbox(binding.name, function() return bag.bindingFilters[binding.id] ~= false end,
          function() toggle(bag.bindingFilters, binding.id) end)
      end
    end
    root:CreateDivider()
    root:CreateTitle("Categories")
    for _, entry in ipairs(ITEM_CATEGORIES) do
      local category = entry
      root:CreateCheckbox(category.name, function() return bag.categoryFilters[category.id] ~= false end,
        function() toggle(bag.categoryFilters, category.id) end)
    end
  else
    local menu = {
      { text = "Show All", notCheckable = true, keepShownOnClick = true, func = checkAll },
    }
    menu[#menu + 1] = { text = "Flags", isTitle = true, notCheckable = true }
    menu[#menu + 1] = { text = "Unflagged", isNotRadio = true, keepShownOnClick = true,
      checked = function() return bag.flagFilters.unflagged ~= false end,
      func = function() toggle(bag.flagFilters, "unflagged") end }
    for _, entry in ipairs(ITEM_STATUSES) do
      local status = entry
      menu[#menu + 1] = { text = status.name, isNotRadio = true, keepShownOnClick = true,
        checked = function() return bag.flagFilters[status.id] ~= false end,
        func = function() toggle(bag.flagFilters, status.id) end }
    end
    menu[#menu + 1] = { text = "Binding", isTitle = true, notCheckable = true }
    for _, entry in ipairs(BINDING_FILTERS) do
      local binding = entry
      if not binding.retailOnly or isRetail() then
        menu[#menu + 1] = { text = binding.name, isNotRadio = true, keepShownOnClick = true,
          checked = function() return bag.bindingFilters[binding.id] ~= false end,
          func = function() toggle(bag.bindingFilters, binding.id) end }
      end
    end
    menu[#menu + 1] = { text = "Categories", isTitle = true, notCheckable = true }
    for _, entry in ipairs(ITEM_CATEGORIES) do
      local category = entry
      menu[#menu + 1] = { text = category.name, isNotRadio = true, keepShownOnClick = true,
        checked = function() return bag.categoryFilters[category.id] ~= false end,
        func = function() toggle(bag.categoryFilters, category.id) end }
    end
    if not module.filtersMenu then
      module.filtersMenu = CreateFrame("Frame", "SlackHacksListviewBagFiltersMenu", UIParent, "UIDropDownMenuTemplate")
    end
    EasyMenu(menu, module.filtersMenu, "cursor", 0, 0, "MENU")
  end
end

--- Temporarily enable AH Mode without changing the user's previous choice.
local function beginAuctionMode()
  if ahModeBeforeAuction ~= nil then return end
  ahModeBeforeAuction = ahMode
  if not auctionEligibilityAvailable() then
    ahMode = false
    prn("AH Mode is unavailable because auction eligibility cannot be checked.")
    return
  end
  ahMode = true
end

--- Restore the AH Mode choice from before the auction house opened.
local function endAuctionMode()
  if ahModeBeforeAuction == nil then return end
  ahMode = ahModeBeforeAuction
  ahModeBeforeAuction = nil
end

--- Update view controls and the space available to the search box.
local function updateViewControls()
  if not footer then return end
  local view = selectedView()
  local label = VIEWS[1].name
  for _, entry in ipairs(VIEWS) do
    if entry.id == view then label = entry.name; break end
  end
  if footer.viewsButton.legacy then UIDropDownMenu_SetText(footer.viewsButton, label)
  else footer.viewsButton:OverrideText(label) end
  footer.gearFiltersButton:SetShown(view == "gear")
  local showAuctionRefresh = view == "selling"
    and not (Self.ListviewBagAuction and Self.ListviewBagAuction.HasAuctionator())
  footer.auctionRefresh:SetShown(showAuctionRefresh)
  footer.auctionRefresh:SetEnabled(auctionOpen)
  footer.ahMode:SetShown(view == "selling")
  footer.ahMode:ClearAllPoints()
  footer.ahMode:SetPoint("RIGHT", showAuctionRefresh and footer.auctionRefresh or footer.viewsButton,
    "LEFT", showAuctionRefresh and -60 or -64, 0)
  footer.ahMode:SetChecked(ahMode)
  footer.ahMode:SetEnabled(auctionEligibilityAvailable())
  if searchBox then searchBox:SetWidth(view == "gear" and 90 or 180) end
end

--- Select a view without modifying the default column order or existing filters.
---@param view string View identifier.
---@param temporary boolean|nil Whether to leave the saved view unchanged.
local function selectView(view, temporary)
  if temporary then temporaryView = view else temporaryView = nil; settings().view = view end
  sortColumn = nil
  sortAscending = true
  updateViewControls()
  renderRows()
  if Self.ListviewBagAuction then Self.ListviewBagAuction.Cancel() end
end

--- Populate the native view selector or its legacy equivalent.
---@param anchor table Dropdown frame.
---@param root table|nil Modern menu description.
local function openViewsMenu(anchor, root)
  if root then
    for _, entry in ipairs(VIEWS) do
      local view = entry
      root:CreateRadio(view.name, function() return selectedView() == view.id end,
        function() selectView(view.id) end)
    end
  else
    local menu = {}
    for _, entry in ipairs(VIEWS) do
      local view = entry
      menu[#menu + 1] = { text = view.name, checked = function() return selectedView() == view.id end,
        func = function() selectView(view.id) end }
    end
    if not module.viewsMenu then
      module.viewsMenu = CreateFrame("Frame", "SlackHacksListviewBagViewsMenu", UIParent, "UIDropDownMenuTemplate")
    end
    EasyMenu(menu, module.viewsMenu, "cursor", 0, 0, "MENU")
  end
end

--- Collect localized filter choices from the client's item-class and stat definitions.
---@return table groups Ordered filter groups and their choices.
local function gearFilterChoices()
  local groups = { { name = "Armor and Weapons", key = "types", entries = {} },
    { name = "Equipment Slots", key = "slots", entries = {} },
    { name = "Stats", key = "stats", entries = {} } }
  if C_Item and C_Item.GetItemSubClassInfo then
    for _, classID in ipairs({ 4, 2 }) do
      for subclassID = 0, 30 do
        local label = C_Item.GetItemSubClassInfo(classID, subclassID)
        if label and label ~= "" then
          groups[1].entries[#groups[1].entries + 1] =
            { key = classID .. ":" .. subclassID, name = label }
        end
      end
    end
  end
  for key in pairs(EQUIPMENT_SLOTS) do
    if gear.GetSlots(key) then
      groups[2].entries[#groups[2].entries + 1] = { key = key, name = _G[key] or key }
    end
  end
  for key, value in pairs(_G) do
    if type(key) == "string" and key:match("^ITEM_MOD_") and type(value) == "string" then
      groups[3].entries[#groups[3].entries + 1] = { key = key, name = gear.StatLabel(key) }
    end
  end
  for _, group in ipairs(groups) do
    table.sort(group.entries, function(a, b)
      return a.name == b.name and a.key < b.key or a.name < b.name
    end)
  end
  return groups
end

--- Populate the Gear view's grouped filters.
---@param anchor table Dropdown frame.
---@param root table|nil Modern menu description.
local function openGearFiltersMenu(anchor, root)
  local filters = gearFilters()
  local groups = gearFilterChoices()
  --- Restore all gear filters.
  local function showAll()
    filters.types, filters.slots, filters.stats = {}, {}, {}
    filters.downgradeOnly = false
    renderRows()
  end
  --- Uncheck all available gear filters.
  local function uncheckAll()
    for _, group in ipairs(groups) do
      for _, choice in ipairs(group.entries) do
        filters[group.key][choice.key] = false
      end
    end
    filters.downgradeOnly = false
    renderRows()
  end
  --- Toggle a filter and refresh the view.
  ---@param group string Filter group.
  ---@param key string Filter identifier.
  local function toggle(group, key)
    if filters[group][key] == false then filters[group][key] = nil
    else filters[group][key] = false end
    renderRows()
  end
  --- Toggle the strict downgrade filter.
  local function toggleDowngrade()
    filters.downgradeOnly = not filters.downgradeOnly
    renderRows()
  end
  if root then
    root:CreateButton("Show All", showAll):SetResponse(MenuResponse.Refresh)
    root:CreateButton("Uncheck All", uncheckAll):SetResponse(MenuResponse.Refresh)
    root:CreateCheckbox("Downgrade Only", function() return filters.downgradeOnly end, toggleDowngrade)
    for _, entry in ipairs(groups) do
      local group = entry
      local submenu = root:CreateButton(group.name)
      if submenu.SetScrollMode then submenu:SetScrollMode(350) end
      for _, value in ipairs(group.entries) do
        local choice = value
        submenu:CreateCheckbox(choice.name, function() return filters[group.key][choice.key] ~= false end,
          function() toggle(group.key, choice.key) end)
      end
    end
  else
    local menu = {
      { text = "Show All", notCheckable = true, keepShownOnClick = true, func = showAll },
      { text = "Uncheck All", notCheckable = true, keepShownOnClick = true, func = uncheckAll },
      { text = "Downgrade Only", isNotRadio = true, keepShownOnClick = true,
        checked = function() return filters.downgradeOnly end, func = toggleDowngrade },
    }
    for _, entry in ipairs(groups) do
      local group = entry
      local submenu = {}
      for _, value in ipairs(group.entries) do
        local choice = value
        submenu[#submenu + 1] = { text = choice.name, isNotRadio = true, keepShownOnClick = true,
          checked = function() return filters[group.key][choice.key] ~= false end,
          func = function() toggle(group.key, choice.key) end }
      end
      menu[#menu + 1] = { text = group.name, notCheckable = true, hasArrow = true, menuList = submenu }
    end
    if not module.gearFiltersMenu then
      module.gearFiltersMenu = CreateFrame("Frame", "SlackHacksListviewBagGearFiltersMenu", UIParent, "UIDropDownMenuTemplate")
    end
    EasyMenu(menu, module.gearFiltersMenu, "cursor", 0, 0, "MENU")
  end
end

--- Refresh auction prices only on explicit request while the auction house is open.
updateAuctionView = function()
  local prices = Self.ListviewBagAuction
  if not prices then return end
  prices.Cancel()
  if selectedView() ~= "selling" or not auctionOpen or not frame or not frame:IsShown() then return end
  if prices.HasAuctionator() then renderRows(); return end
  local items = {}
  for _, group in ipairs(collectGroups()) do
    local entry = group.entries[1]
    if entry and group.hyperlink and not group.isBound and not group.accountBound then
      items[#items + 1] = { link = group.hyperlink, bagID = entry.bagID, slot = entry.slot }
    end
  end
  prices.Start(items, renderRows)
end

--- Create the window footer and its filter controls.
local function createFooter()
  footer = CreateFrame("Frame", nil, content)
  footer:SetHeight(20)
  footer:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 8, 8)
  footer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)

  -- Same tiled background bar as the column header (and Blizzard's own ColumnDisplayTemplate), so the
  -- footer reads as a matching bar rather than plain floating text.
  footer.Bg = footer:CreateTexture(nil, "BACKGROUND")
  footer.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", true, true)
  footer.Bg:SetAllPoints()

  footer.slotCount = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  footer.slotCount:SetPoint("LEFT", footer, "LEFT", 4, 0)
  footer.slotFont, footer.slotFontSize, footer.slotFontFlags = footer.slotCount:GetFont()
  footer.slotIcon = footer:CreateTexture(nil, "ARTWORK")
  footer.slotIcon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")

  footer.slotHover = CreateFrame("Frame", nil, footer)
  footer.slotHover:SetPoint("LEFT", footer.slotCount, "LEFT")
  footer.slotHover:SetHeight(20)
  footer.slotHover:EnableMouse(true)
  footer.slotHover:SetScript("OnEnter", showSlotTooltip)
  footer.slotHover:SetScript("OnLeave", GameTooltip_Hide)

  footer.balances = CreateFrame("Frame", nil, footer)
  footer.balances:SetSize(168, 20)
  footer.balances:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -4, 0)

  footer.balanceContents = CreateFrame("Frame", nil, footer.balances)
  footer.balanceContents:SetSize(168, 20)
  footer.balanceContents:SetPoint("RIGHT", footer.balances, "RIGHT")

  footer.moneyFrame = CreateFrame("Frame", "SlackHacksListviewBagMoneyFrame", footer.balanceContents, "ContainerMoneyFrameTemplate")
  footer.moneyFrame:SetSize(168, 16)
  footer.moneyFrame:SetPoint("RIGHT", footer.balanceContents, "RIGHT", 0, 0)
  MoneyFrame_SetMaxDisplayWidth(footer.moneyFrame, 168)

  if MenuUtil and MenuUtil.CreateContextMenu then
    footer.filtersButton = CreateFrame("DropdownButton", "SlackHacksListviewBagFiltersButton", content, "WowStyle1DropdownTemplate")
    footer.filtersButton:SetWidth(130)
    footer.filtersButton:SetupMenu(openFiltersMenu)
  else
    footer.filtersButton = CreateFrame("Frame", "SlackHacksListviewBagFiltersButton", content, "UIDropDownMenuTemplate")
    footer.filtersButton.legacy = true
    UIDropDownMenu_SetWidth(footer.filtersButton, 130)
    _G[footer.filtersButton:GetName() .. "Button"]:SetScript("OnClick", function()
      openFiltersMenu(footer.filtersButton)
    end)
  end
  footer.filtersButton:SetFrameLevel(content:GetFrameLevel() + 1)
  footer.filtersButton:SetPoint("RIGHT", content.openBagsButton, "LEFT", -4, 0)
  updateFiltersLabel()

  if MenuUtil and MenuUtil.CreateContextMenu then
    footer.viewsButton = CreateFrame("DropdownButton", "SlackHacksListviewBagViewsButton", content, "WowStyle1DropdownTemplate")
    footer.viewsButton:SetWidth(110)
    footer.viewsButton:SetupMenu(openViewsMenu)
    footer.gearFiltersButton = CreateFrame("DropdownButton", "SlackHacksListviewBagGearFiltersButton", content, "WowStyle1DropdownTemplate")
    footer.gearFiltersButton:SetWidth(110)
    footer.gearFiltersButton:SetupMenu(openGearFiltersMenu)
    footer.gearFiltersButton:OverrideText("Gear Filters")
  else
    footer.viewsButton = CreateFrame("Frame", "SlackHacksListviewBagViewsButton", content, "UIDropDownMenuTemplate")
    footer.viewsButton.legacy = true
    UIDropDownMenu_SetWidth(footer.viewsButton, 110)
    _G[footer.viewsButton:GetName() .. "Button"]:SetScript("OnClick", function() openViewsMenu(footer.viewsButton) end)
    footer.gearFiltersButton = CreateFrame("Frame", "SlackHacksListviewBagGearFiltersButton", content, "UIDropDownMenuTemplate")
    footer.gearFiltersButton.legacy = true
    UIDropDownMenu_SetWidth(footer.gearFiltersButton, 110)
    UIDropDownMenu_SetText(footer.gearFiltersButton, "Gear Filters")
    _G[footer.gearFiltersButton:GetName() .. "Button"]:SetScript("OnClick", function() openGearFiltersMenu(footer.gearFiltersButton) end)
  end
  footer.viewsButton:SetFrameLevel(content:GetFrameLevel() + 1)
  footer.viewsButton:SetPoint("RIGHT", footer.filtersButton, "LEFT", -4, 0)
  footer.gearFiltersButton:SetFrameLevel(content:GetFrameLevel() + 1)
  footer.gearFiltersButton:SetPoint("RIGHT", footer.viewsButton, "LEFT", -4, 0)
  footer.auctionRefresh = CreateFrame("Button", "SlackHacksListviewBagAuctionRefresh", content)
  footer.auctionRefresh:SetSize(14, 14)
  footer.auctionRefresh:SetPoint("RIGHT", footer.viewsButton, "LEFT", -4, 0)
  footer.auctionRefresh:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
  footer.auctionRefresh:SetDisabledTexture("Interface\\Buttons\\UI-RefreshButton")
  footer.auctionRefresh:GetDisabledTexture():SetDesaturated(true)
  footer.auctionRefresh:GetDisabledTexture():SetVertexColor(0.5, 0.5, 0.5)
  footer.auctionRefresh:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  footer.auctionRefresh:SetMotionScriptsWhileDisabled(true)
  footer.auctionRefresh:SetScript("OnClick", updateAuctionView)
  footer.auctionRefresh:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Refresh Auction Prices")
    local hint = not auctionOpen and "Open the Auction House to refresh prices."
      or "Check auction prices for items in your bags."
    GameTooltip:AddLine(hint, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  footer.auctionRefresh:SetScript("OnLeave", GameTooltip_Hide)
  footer.ahMode = CreateFrame("CheckButton", "SlackHacksListviewBagAHMode", content, "UICheckButtonTemplate")
  footer.ahMode:SetSize(20, 20)
  footer.ahMode:SetPoint("RIGHT", footer.auctionRefresh, "LEFT", -60, 0)
  footer.ahMode.text:SetText("AH Mode")
  footer.ahMode:SetMotionScriptsWhileDisabled(true)
  footer.ahMode:SetScript("OnClick", function(self)
    ahMode = not not self:GetChecked()
    renderRows()
  end)
  footer.ahMode:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("AH Mode")
    GameTooltip:AddLine("Show only items eligible for auction that have a vendor price and aren't blocked by flags.", 1, 1, 1, true)
    if not auctionEligibilityAvailable() then
      GameTooltip:AddLine("Auction eligibility is unavailable on this client.", 1, 0.2, 0.2, true)
    end
    GameTooltip:Show()
  end)
  footer.ahMode:SetScript("OnLeave", GameTooltip_Hide)
  updateViewControls()

  if C_AddOns and C_AddOns.LoadAddOn then
    C_AddOns.LoadAddOn("Blizzard_TokenUI")
  else
    UIParentLoadAddOn("Blizzard_TokenUI")
  end
  footer.tokenFrame = CreateFrame("Frame", nil, footer.balanceContents, "BackpackTokenFrameTemplate")
  footer.tokenFrame:SetIsCombinedInventory(true)
  footer.tokenFrame.GetMaxTokensWatched = function() return 3 end
  local nativeAnchorTokens = footer.tokenFrame.UpdateTokenAnchoring
  --- Size the frame before Blizzard positions its native currency buttons.
  ---@param self table Watched currency frame.
  footer.tokenFrame.UpdateTokenAnchoring = function(self)
    resizeCurrencyFrame(self)
    nativeAnchorTokens(self)
  end
  footer.tokenFrame:SetWidth(150)
  footer.tokenFrame:SetPoint("RIGHT", footer.moneyFrame, "LEFT", -4, 0)

  footer.crestFrame = CreateFrame("Frame", nil, footer.balanceContents, "BackpackTokenFrameTemplate")
  footer.crestFrame:SetIsCombinedInventory(true)
  footer.crestFrame.Update = updateCrestFrame
  footer.crestFrame:SetWidth(276)
  footer.crestFrame:SetPoint("RIGHT", footer.tokenFrame, "LEFT", -4, 0)
  footer.supplies = CreateFrame("Frame", nil, footer)
  footer.supplies:SetHeight(20)
  footer.supplies:SetPoint("LEFT", footer.slotIcon, "RIGHT", SUPPLY_MARGIN, 0)
  footer.supplyFrame = CreateFrame("Frame", nil, footer.supplies)
  footer.supplyFrame:SetPoint("LEFT", footer.supplies, "LEFT")
  footer.supplyFrame.buttons = {}
  footer.supplyFrame:SetHeight(20)
end

--=====================================================================
-- Toggling the list view vs. the default bag windows
--=====================================================================

local function forEachDefaultBagFrame(callback)
  for name, obj in pairs(_G) do
    if type(name) == "string" and type(obj) == "table" and obj.IsShown
        and (name == "ContainerFrameCombinedBags" or name:match("^ContainerFrame%d+$")) then
      callback(obj)
    end
  end
end

-- Calling CloseAllBags/OpenAllBags/ToggleAllBags from addon code makes Blizzard reinitialize its pooled
-- bag item buttons while tainted, which later blames SlackHacks for UseContainerItem in the default bags.
-- Like Sorted, the default bag frames are instead reparented under a hidden frame; Blizzard still opens
-- and closes them itself, they just aren't visible while the list view is active.
local suppressedBagsParent = CreateFrame("Frame", nil, UIParent)
suppressedBagsParent:SetAllPoints()
suppressedBagsParent:Hide()
local originalBagParents = {}

local function setDefaultBagsSuppressed(suppressed)
  forEachDefaultBagFrame(function(defaultFrame)
    if suppressed then
      if defaultFrame:GetParent() ~= suppressedBagsParent then
        originalBagParents[defaultFrame] = defaultFrame:GetParent()
        defaultFrame:SetParent(suppressedBagsParent)
      end
    elseif originalBagParents[defaultFrame] then
      defaultFrame:SetParent(originalBagParents[defaultFrame])
      originalBagParents[defaultFrame] = nil
    end
  end)
end

local function hideDefaultBags()
  setDefaultBagsSuppressed(true)
end

local function showDefaultBags()
  setDefaultBagsSuppressed(false)
end

local openingDefaultBags = false
local function openDefaultBagsTemporarily()
  frame:Hide()
  showDefaultBags()
  openingDefaultBags = true
  local success, message = pcall(function()
    for _, bagID in ipairs(bagIDs()) do
      OpenBag(bagID)
    end
  end)
  openingDefaultBags = false
  if not success then error(message, 0) end
end

local function setShowListviewBag(show)
  settings().showListviewBag = show
  if show then
    hideDefaultBags()
    module:UpdateListViewBindings()
    frame:Show()
  else
    frame:Hide()
    module:UpdateListViewBindings()
    showDefaultBags()
  end
end

--- Switch between the list view and Blizzard's default bags.
---@param show boolean Whether the list view replaces the default bags.
function module:SetShowListviewBag(show)
  if not isModuleEnabled() then return end
  setShowListviewBag(show)
end

--- Set automatic junk selling and offer to disable Blizzard's separate grey-item option.
---@param enabled boolean Whether to automatically sell unprotected junk.
function module:SetAutoSellJunk(enabled)
  local profile = db.profile
  local bag = settings()
  local wasEnabled = bag.autoSellMarkedItems
  bag.autoSellMarkedItems = enabled
  if wasEnabled and not enabled and profile.inventory.autoSellGreyItems then
    StaticPopupDialogs.SLACKHACKS_DISABLE_AUTO_SELL_GREYS = {
      text = "Also disable Auto-Sell ALL Grey Items? Otherwise Blizzard will sell every grey item, including protected items.",
      button1 = YES,
      button2 = NO,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      OnAccept = function(_, data)
        if db.profile ~= data or data.listviewBag.autoSellMarkedItems then
          prn("the profile or auto-sell setting changed; Auto-Sell ALL Grey Items was not changed.")
          return
        end
        data.inventory.autoSellGreyItems = false
        local registry = LibStub("AceConfigRegistry-3.0", true)
        if registry then registry:NotifyChange("SlackHacks") end
      end,
    }
    if not StaticPopup_Show("SLACKHACKS_DISABLE_AUTO_SELL_GREYS", nil, nil, profile) then
      prn("Auto-Sell ALL Grey Items is still enabled and will sell protected grey items.")
    end
  end
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- Open settings for the list-view bag from its portrait.
---@param anchor table Portrait button.
local function openBagSettingsMenu(anchor)
  if not isModuleEnabled() then return end
  GameTooltip:Hide()
  --- Permanently switch to Blizzard's bags.
  local function switchToDefault()
    if isModuleEnabled() then setShowListviewBag(false) end
  end
  --- Report whether automatic junk selling is enabled.
  ---@return boolean enabled Whether automatic junk selling is enabled.
  local function autoSell() return settings().autoSellMarkedItems end
  --- Toggle automatic junk selling.
  local function toggleAutoSell()
    if isModuleEnabled() then module:SetAutoSellJunk(not settings().autoSellMarkedItems) end
  end
  --- Open the Listview Bag options.
  local function openBagOptions()
    if isModuleEnabled() then openOptions("inventory", "listviewBag") end
  end
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(anchor, function(_, root)
      root:CreateButton("Switch back to default bags", switchToDefault)
      root:CreateCheckbox("Auto-Sell Junk", autoSell, toggleAutoSell)
      root:CreateButton("Open Settings", openBagOptions)
    end)
  else
    local menu = {
      { text = "Switch back to default bags", notCheckable = true, func = switchToDefault },
    }
    menu[#menu + 1] = { text = "Auto-Sell Junk", isNotRadio = true, keepShownOnClick = true,
      checked = autoSell, func = toggleAutoSell }
    menu[#menu + 1] = { text = "Open Settings", notCheckable = true, func = openBagOptions }
    if not module.bagSettingsMenu then
      module.bagSettingsMenu = CreateFrame("Frame", "SlackHacksListviewBagSettingsMenu", UIParent, "UIDropDownMenuTemplate")
    end
    EasyMenu(menu, module.bagSettingsMenu, "cursor", 0, 0, "MENU")
  end
end

local function updateListViewBindings()
  if not bagKeyBindingButton or InCombatLockdown() then return end
  ClearOverrideBindings(bagKeyBindingButton)
  if not isModuleEnabled() or not settings().showListviewBag then return end
  for _, command in ipairs({ "TOGGLEBACKPACK", "OPENALLBAGS" }) do
    for _, key in ipairs({ GetBindingKey(command) }) do
      if key then
        SetOverrideBindingClick(bagKeyBindingButton, true, key, bagKeyBindingButton:GetName())
      end
    end
  end
end

local lastNativeBagToggle = 0
--- Return whether an interaction window currently needs access to bag contents.
---@return boolean interacting Whether an item-interaction window is open.
local function isBagInteractionOpen()
  return merchantOpen or mailOpen or auctionOpen or bankOpen or guildBankOpen
    or (MerchantFrame and MerchantFrame:IsShown())
    or (MailFrame and MailFrame:IsShown())
    or (AuctionHouseFrame and AuctionHouseFrame:IsShown())
    or (AuctionFrame and AuctionFrame:IsShown())
    or (BankFrame and BankFrame:IsShown())
    or (GuildBankFrame and GuildBankFrame:IsShown())
    or false
end

--- Toggle the list view for a native bag toggle, keeping interaction-driven requests open.
local function toggleListViewFromNativeBagAction()
  if openingDefaultBags then return end
  if not frame or not isModuleEnabled() or not settings().showListviewBag then return end
  if isBagInteractionOpen() then
    hideDefaultBags()
    frame:Show()
    return
  end
  local now = GetTime()
  if now - lastNativeBagToggle < 0.01 then return end
  lastNativeBagToggle = now
  hideDefaultBags()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end

local bagMenuHooksInstalled = false
local function installBagMenuOptions()
  if bagMenuHooksInstalled or not isModuleEnabled() or not Menu or not Menu.ModifyMenu then return end
  bagMenuHooksInstalled = true
  for _, menuTag in ipairs({ "MENU_CONTAINER_FRAME", "MENU_CONTAINER_FRAME_COMBINED" }) do
    Menu.ModifyMenu(menuTag, function(_, rootDescription)
      if not isModuleEnabled() then return end
      rootDescription:CreateDivider()
      rootDescription:CreateButton("Switch to SlackHacks' Listview Bag", function()
        settings().enabled = true
        settings().showListviewBag = true
        if module:IsEnabled() then
          setShowListviewBag(true)
        else
          module:Enable()
        end
      end)
    end)
  end
end

local hookedBagToggleFuncs = {}
--- Hook native open, toggle, and close requests without treating an open request as a toggle.
local function hookDefaultBagToggles()
  for _, funcName in ipairs({ "ToggleBackpack", "ToggleBag" }) do
    if _G[funcName] and not hookedBagToggleFuncs[funcName] then
      hookedBagToggleFuncs[funcName] = true
      hooksecurefunc(funcName, toggleListViewFromNativeBagAction)
    end
  end
  for _, funcName in ipairs({ "OpenBackpack", "OpenBag" }) do
    if _G[funcName] and not hookedBagToggleFuncs[funcName] then
      hookedBagToggleFuncs[funcName] = true
      hooksecurefunc(funcName, function() module:OnNativeBagOpen() end)
    end
  end
  if _G.CloseBackpack and not hookedBagToggleFuncs.CloseBackpack then
    hookedBagToggleFuncs.CloseBackpack = true
    hooksecurefunc("CloseBackpack", function()
      if frame and isModuleEnabled() and settings().showListviewBag and not isBagInteractionOpen() then
        frame:Hide()
      end
    end)
  end
end

local function refreshFooter()
  if frame and frame:IsShown() then
    updateFooter()
  end
end

--=====================================================================
-- Frame construction
--=====================================================================

--- Build the list-view bag window and its controls.
local function buildFrame()
  if frame then return end

  frame = CreateFrame("Frame", FRAME_NAME, UIParent)
  frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:Hide()
  tinsert(UISpecialFrames, FRAME_NAME) -- lets Escape close it, like every other Blizzard panel

  -- Reuses Blizzard's own portrait-window chrome exactly (confirmed via wow-ui-source's
  -- SharedUIPanelTemplates.xml): a portrait-style border with a round icon in the top-left corner.
  frame.layoutType = "PortraitFrameTemplate"

  -- PortraitFrameTexturedBaseTemplate's own Bg/TopTileStreaks -- the same Rock tile + streak art used
  -- by ColumnDisplayTemplate below, so the window body and the column header bar match instead of
  -- clashing (a flat solid fill next to a tiled header looked mismatched).
  frame.Background = CreateFrame("Frame", nil, frame)
  frame.Background:SetFrameLevel(1) -- must stay below the NineSlice's hardcoded frameLevel of 500
  frame.Bg = frame.Background:CreateTexture(nil, "BACKGROUND")
  frame.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", true, true)
  frame.Bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
  frame.Bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.TopTileStreaks = frame.Background:CreateTexture(nil, "BORDER")
  frame.TopTileStreaks:SetAtlas("_UI-Frame-TopTileStreaks", true)
  frame.TopTileStreaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -21)
  frame.TopTileStreaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -21)

  frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
  frame.NineSlice:SetAllPoints()

  content = CreateFrame("Frame", nil, frame)
  content:SetAllPoints()
  content:SetFrameLevel(600) -- above the NineSlice border's hardcoded frameLevel of 500

  -- Blizzard's own PortraitContainer sits BELOW the NineSlice border (frame level base+400 vs.
  -- base+500) so the border's decorative ring art draws on top of/around the portrait icon instead of
  -- covering it -- a plain child of `content` (level 600) would render over the ring and hide it.
  local portraitContainer = CreateFrame("Frame", nil, frame)
  content.portrait = portraitContainer:CreateTexture(nil, "OVERLAY")
  content.portrait:SetSize(62, 62)
  content.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 7)
  content.portrait:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
  local portraitMask = portraitContainer:CreateMaskTexture()
  portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  portraitMask:SetAllPoints(content.portrait)
  content.portrait:AddMaskTexture(portraitMask)

  -- Invisible click target for the settings menu, above the border so it's always clickable; the actual
  -- portrait icon underneath (see portraitContainer above) is what's visually framed by the border ring.
  local portraitButton = CreateFrame("Button", nil, content)
  portraitButton:SetAllPoints(content.portrait)
  portraitButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  portraitButton:SetScript("OnClick", openBagSettingsMenu)
  portraitButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Bag Settings")
    GameTooltip:Show()
  end)
  portraitButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Matches PortraitFrameBaseTemplate's own TitleContainer anchors/frame level exactly.
  content.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  content.title:SetPoint("TOP", content, "TOP", 0, -6)
  content.title:SetPoint("LEFT", content, "TOPLEFT", 58, 0)
  content.title:SetPoint("RIGHT", content, "TOPRIGHT", -24, 0)
  content.title:SetText((UnitName("player") or "Character") .. "'s Inventory")

  -- The whole top strip is a native move handle (StartMoving/StopMovingOrSizing), matching how every
  -- other Blizzard window is dragged. Starts right of the portrait icon so it doesn't steal clicks
  -- from the settings button sitting on top of that icon.
  local dragHandle = CreateFrame("Frame", nil, content)
  dragHandle:SetPoint("TOPLEFT", content, "TOPLEFT", 58, 0)
  dragHandle:SetPoint("TOPRIGHT", content, "TOPRIGHT", -28, 0)
  dragHandle:SetHeight(20)
  dragHandle:EnableMouse(true)
  frame:SetMovable(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function() frame:StartMoving() end)
  dragHandle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint()
    settings().point = { point, relPoint, x, y }
  end)

  content.closeButton = CreateFrame("Button", nil, content, "UIPanelCloseButtonDefaultAnchors")
  content.closeButton:SetScript("OnClick", function() frame:Hide() end) -- just closes; doesn't change the view mode

  content.settingsButton = CreateFrame("Button", nil, content)
  content.settingsButton:SetSize(24, 24)
  content.settingsButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -32)
  content.settingsButton:SetNormalAtlas("common-dropdown-a-button-settings-shadowless")
  content.settingsButton:SetPushedAtlas("common-dropdown-a-button-settings-pressed-shadowless")
  content.settingsButton:SetHighlightAtlas("common-dropdown-a-button-settings-hover-shadowless")
  -- The cog atlas has transparent padding, mostly below the artwork; enlarge and lower it to match the backpack.
  for _, texture in ipairs({ content.settingsButton:GetNormalTexture(), content.settingsButton:GetPushedTexture(),
    content.settingsButton:GetHighlightTexture() }) do
    texture:ClearAllPoints()
    texture:SetSize(33, 33)
    texture:SetPoint("CENTER", content.settingsButton, "CENTER", 0, -3)
  end
  content.settingsButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  content.settingsButton:SetScript("OnClick", openBagSettingsMenu)
  content.settingsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Bag Settings")
    GameTooltip:Show()
  end)
  content.settingsButton:SetScript("OnLeave", GameTooltip_Hide)

  content.openBagsButton = CreateFrame("Button", nil, content)
  content.openBagsButton:SetSize(24, 24)
  content.openBagsButton:SetPoint("RIGHT", content.settingsButton, "LEFT", -4, 0)
  content.openBagsButton:SetNormalTexture("Interface\\Buttons\\Button-Backpack-Up")
  content.openBagsButton:SetPushedTexture("Interface\\Buttons\\Button-Backpack-Down")
  content.openBagsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  content.openBagsButton:SetScript("OnClick", function()
    if isModuleEnabled() then openDefaultBagsTemporarily() end
  end)
  content.openBagsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Open Bags (Temporarily)")
    GameTooltip:AddLine("Show the Blizzard default bag temporarily. You can toggle it permanently in the cog menu.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  content.openBagsButton:SetScript("OnLeave", GameTooltip_Hide)

  bagKeyBindingButton = CreateFrame("Button", "SlackHacksListviewBagToggleButton", UIParent)
  bagKeyBindingButton:SetSize(1, 1)
  bagKeyBindingButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
  bagKeyBindingButton:SetAlpha(0)
  bagKeyBindingButton:SetScript("OnClick", function()
    if isModuleEnabled() and settings().showListviewBag then
      hideDefaultBags()
      if frame:IsShown() then frame:Hide() else frame:Show() end
    end
  end)

  searchBox = CreateFrame("EditBox", "SlackHacksListviewBagSearchBox", content, "BagSearchBoxTemplate")
  table.insert(ITEM_SEARCHBAR_LIST, searchBox:GetName())
  searchBox:SetSize(200, 20)
  searchBox:SetPoint("TOPLEFT", content, "TOPLEFT", 62, -32)

  -- Keep the native column buttons, but let the window's own header texture show behind them.
  -- Inset by COLLAPSE_WIDTH so its first column aligns with the row cells after the pinned expand cell.
  headerFrame = CreateFrame("Frame", nil, content, "ColumnDisplayTemplate")
  headerFrame:SetHeight(30)
  headerFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10 + COLLAPSE_WIDTH, -56)
  headerFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -56)
  headerFrame.Background:Hide()
  headerFrame.TopTileStreaks:Hide()
  headerFrame.sortingFunction = function(_, columnIndex)
    selectSortColumn(activeColumns()[columnIndex])
  end
  content.statusHeaderButton = CreateFrame("Button", nil, headerFrame, "ColumnDisplayButtonNoScriptsTemplate")
  content.statusHeaderButton:SetSize(24, 24)
  content.statusHeaderButton:SetPoint("BOTTOM", headerFrame, "BOTTOMRIGHT", -30, 1)
  content.statusHeaderButton:SetText(CreateAtlasMarkup(PROTECT_ICON_ATLAS, 14, 14))
  content.statusHeaderButton.sortIcon = content.statusHeaderButton:CreateTexture(nil, "OVERLAY")
  content.statusHeaderButton.sortIcon:SetTexture(SORT_ARROW_TEXTURE)
  content.statusHeaderButton.sortIcon:SetSize(8, 8)
  content.statusHeaderButton.sortIcon:SetPoint("LEFT", content.statusHeaderButton, "RIGHT", 0, 0)
  content.statusHeaderButton.sortIcon:Hide()
  content.statusHeaderButton:SetScript("OnClick", function() selectSortColumn("flag") end)

  -- Recessed marble list panel behind the rows, matching the guild roster's own InsetFrameTemplate look.
  local listInset = CreateFrame("Frame", nil, content, "InsetFrameTemplate")
  content.listInset = listInset
  listInset:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", -4 - COLLAPSE_WIDTH, 0)
  listInset:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -4, 30)

  scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", -COLLAPSE_WIDTH - 2, -4)
  scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -30, 34)

  scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetWidth(1) -- resized in layoutFrame()
  scrollFrame:SetScrollChild(scrollChild)

  createFooter()

  frame:SetScript("OnShow", function()
    layoutFrame()
    renderRows()
    updateFooter()
    updateViewControls()
  end)
  frame:SetScript("OnHide", function()
    if Self.ListviewBagAuction then Self.ListviewBagAuction.Cancel() end
  end)

  if settings().point then
    local point, relPoint, x, y = unpack(settings().point)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relPoint, x, y)
  end
end

layoutFrame = function()
  scrollChild:SetWidth(scrollFrame:GetWidth())
  layoutHeaders()
end

--=====================================================================
-- Selling marked "trash" items at a merchant
--=====================================================================

-- Mirrors sellGreyItems()'s existing pattern in Core.lua (C_Container.UseContainerItem at a merchant
-- sells the item) but drives off the player's own per-item/per-armor-piece "trash" flags instead of
-- quality.

--- Visit sellable marked items and, when requested, unprotected grey items.
-- Skip items without vendor value and locked items already being sold or otherwise in use.
---@param callback function|nil Called with bag ID and slot for each sellable item.
---@param includeGrey boolean|nil Whether to include unprotected grey items.
---@return number count Number of sellable slots found.
---@return number unavailable Number of slots whose item information is incomplete.
local function forEachSellableTrashSlot(callback, includeGrey)
  local count, unavailable = 0, 0
  for _, bagID in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID and not info.hasNoValue and not info.isLocked then
        local itemName, itemLink, quality, itemLevel
        if info.hyperlink then
          itemName, itemLink, quality, itemLevel = C_Item.GetItemInfo(info.hyperlink)
        end
        local itemQuality = info.quality or quality
        local level = info.hyperlink and C_Item.GetDetailedItemLevelInfo(info.hyperlink) or itemLevel
        -- An incomplete status key cannot reliably match a saved protection flag.
        if itemName and itemQuality ~= nil and level ~= nil then
          local upgradeTrack = getUpgradeTrack(bagID, slot)
          local key = itemStatusKey(itemName, itemQuality, level, upgradeTrack)
          local grey = itemQuality == 0 and includeGrey and settings().protectedItems[key] == nil
          local marked = itemQuality ~= 0 and isTrashItem(key) and not isProtectedItem(key)
          if grey or marked then
            count = count + 1
            if callback then callback(bagID, slot) end
          end
        else
          unavailable = unavailable + 1
        end
      end
    end
  end
  return count, unavailable
end

--- Extend the native junk button's enabled state to include sellable marked items.
updateMerchantJunkButton = function()
  if not merchantOpen or not isModuleEnabled() or not _G.MerchantSellAllJunkButton
    or not C_MerchantFrame or not C_MerchantFrame.GetNumJunkItems then return end
  local hasItems = C_MerchantFrame.GetNumJunkItems() > 0 or forEachSellableTrashSlot() > 0
  MerchantSellAllJunkButton.Icon:SetDesaturated(not hasItems)
  MerchantSellAllJunkButton:SetEnabled(hasItems)
end

--- Sell marked items and optionally unprotected greys, then refresh the native button state.
---@param includeGrey boolean|nil Whether to sell unprotected grey items too.
sellMarkedTrashItems = function(includeGrey)
  if not isModuleEnabled() then return end
  local _, unavailable = forEachSellableTrashSlot(C_Container.UseContainerItem, includeGrey)
  if unavailable > 0 then
    prn("some item details are not loaded, so those items could not be checked for sale. Try again when they are available.")
  end
  updateMerchantJunkButton()
end

local merchantJunkHooked = false
local sellingNativeGreys = false

--- Invoke Blizzard's grey-only sale without adding Listview Bag's marked items.
function module:SellBlizzardGreyItems()
  sellingNativeGreys = true
  local ok, message = pcall(C_MerchantFrame.SellAllJunkItems)
  sellingNativeGreys = false
  if not ok then error(message, 0) end
end

--- Hook Blizzard's merchant updates and its actual sale, including the stored confirmation callback.
local function hookMerchantJunkButton()
  if merchantJunkHooked or not _G.MerchantFrame_Update or not _G.MerchantSellAllJunkButton
    or not C_MerchantFrame or not C_MerchantFrame.SellAllJunkItems
    or not C_MerchantFrame.GetNumJunkItems then return end
  merchantJunkHooked = true
  hooksecurefunc("MerchantFrame_Update", updateMerchantJunkButton)
  -- Blizzard stores the original confirmation function in popup data, so hooking its global name
  -- misses confirmation. Hook the API it calls instead, after Blizzard has started its sale.
  hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", function()
    if merchantOpen and isModuleEnabled() and not sellingNativeGreys then
      sellMarkedTrashItems()
    end
  end)
end

--=====================================================================
-- Lifecycle
--=====================================================================

function module:OnInitialize()
  hookDefaultBagToggles()
  installBagMenuOptions()
  if not isModuleEnabled() then
    self:SetEnabledState(false)
  end
end

function module:OnEnable()
  if not isModuleEnabled() then
    self:SetEnabledState(false)
    return
  end
  installBagMenuOptions()
  buildFrame()
  merchantOpen = MerchantFrame and MerchantFrame:IsShown() or false
  mailOpen = MailFrame and MailFrame:IsShown() or false
  auctionOpen = (AuctionHouseFrame and AuctionHouseFrame:IsShown())
    or (AuctionFrame and AuctionFrame:IsShown()) or false
  if auctionOpen then
    beginAuctionMode()
    selectView("selling", true)
  else
    updateViewControls()
  end
  bankOpen = BankFrame and BankFrame:IsShown() or false
  guildBankOpen = GuildBankFrame and GuildBankFrame:IsShown() or false
  hookMerchantJunkButton()
  installMailHooks()
  if MailFrame and SendMailFrame and SendMailFrame:IsShown() then
    openMailRecipientPicker(MailFrame, nil, nil, true)
  end
  updateMerchantJunkButton()
  self:RegisterEvent("BAG_OPEN", "OnNativeBagOpen")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateListViewBindings")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:RegisterEvent("INVENTORY_SEARCH_UPDATE", "Refresh")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "Refresh")
  self:RegisterEvent("ITEM_DATA_LOAD_RESULT", "OnSlotItemDataLoaded")
  self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "Refresh")
  self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnSupplyInventoryChanged")
  self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "RefreshFooter")
  self:RegisterEvent("PLAYER_MONEY", "RefreshFooter")
  self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "RefreshFooter")
  self:RegisterEvent("CURSOR_CHANGED", "OnCursorChanged")
  self:RegisterEvent("MERCHANT_SHOW")
  self:RegisterEvent("MERCHANT_CLOSED")
  self:RegisterEvent("MAIL_SHOW", "OnBagInteractionOpen")
  self:RegisterEvent("MAIL_CLOSED", "OnBagInteractionClosed")
  self:RegisterEvent("MAIL_SEND_SUCCESS", "OnMailSendSuccess")
  self:RegisterEvent("MAIL_FAILED", "OnMailSendFailed")
  self:RegisterEvent("MAIL_SEND_INFO_UPDATE", "OnMailInfoUpdate")
  self:RegisterEvent("ADDON_LOADED", "OnMailAddonLoaded")
  self:RegisterEvent("AUCTION_HOUSE_SHOW", "OnBagInteractionOpen")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED", "OnBagInteractionClosed")
  self:RegisterEvent("BANKFRAME_OPENED", "OnBagInteractionOpen")
  self:RegisterEvent("BANKFRAME_CLOSED", "OnBagInteractionClosed")
  self:RegisterEvent("GUILDBANKFRAME_OPENED", "OnBagInteractionOpen")
  self:RegisterEvent("GUILDBANKFRAME_CLOSED", "OnBagInteractionClosed")
  EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", self.RefreshFooter, self)
  if settings().showListviewBag then
    setShowListviewBag(true)
  end
end

function module:OnDisable()
  slotItemLoads = {}
  trackedCursorItem = nil
  if Self.ListviewBagAuction then Self.ListviewBagAuction.Cancel() end
  endAuctionMode()
  auctionOpen = false
  if temporaryView then temporaryView = nil; sortColumn = nil; sortAscending = true end
  if recipientPicker and recipientPicker.mailMode then recipientPicker:Hide() end
  if mailJob then stopMailJob("mail preparation stopped because Listview Bag was disabled.") end
  mailSelection = nil
  if not pendingMail then mailSendPending = false end
  if frame then frame:Hide() end
  self:UpdateListViewBindings()
  showDefaultBags()
  EventRegistry:UnregisterCallback("TokenFrame.OnTokenWatchChanged", self)
  if merchantOpen and merchantJunkHooked then MerchantFrame_Update() end
end

function module:MERCHANT_SHOW()
  if not isModuleEnabled() then return end
  merchantOpen = true
  returnBlockedCursorItem()
  hookMerchantJunkButton()
  if settings().showListviewBag then
    hideDefaultBags()
    frame:Show()
  end
  if settings().autoSellMarkedItems then
    sellMarkedTrashItems(true)
  end
  updateMerchantJunkButton()
  renderRows()
end

function module:MERCHANT_CLOSED()
  merchantOpen = false
  renderRows()
end

--- Keep the list view open and refresh guards when an item-interaction window opens.
---@param event string Interaction-open event.
function module:OnBagInteractionOpen(event)
  if not isModuleEnabled() then return end
  if event == "MAIL_SHOW" then
    mailOpen = true
    installMailHooks()
    if MailFrame and SendMailFrame and SendMailFrame:IsShown() then
      openMailRecipientPicker(MailFrame, nil, nil, true)
    end
  end
  if event == "AUCTION_HOUSE_SHOW" and not auctionOpen then
    auctionOpen = true
    beginAuctionMode()
    selectView("selling", true)
  end
  if event == "BANKFRAME_OPENED" then bankOpen = true end
  if event == "GUILDBANKFRAME_OPENED" then guildBankOpen = true end
  returnBlockedCursorItem()
  self:OnNativeBagOpen()
  renderRows()
end

--- Forget the list-view pickup when the cursor no longer holds that item.
function module:OnCursorChanged()
  if not trackedCursorItem then return end
  local cursorType, _, link = GetCursorInfo()
  if cursorType ~= "item" or link ~= trackedCursorItem.link then
    trackedCursorItem = nil
  end
end

--- Clear interaction state and refresh item guards when a window closes.
---@param event string Interaction-close event.
function module:OnBagInteractionClosed(event)
  if event == "MAIL_CLOSED" then
    mailOpen = false
    if recipientPicker and recipientPicker.mailMode then recipientPicker:Hide() end
  end
  if event == "AUCTION_HOUSE_CLOSED" then
    auctionOpen = false
    endAuctionMode()
    if Self.ListviewBagAuction then Self.ListviewBagAuction.Cancel() end
    if temporaryView then temporaryView = nil; sortColumn = nil; sortAscending = true end
    updateViewControls()
  end
  if event == "BANKFRAME_CLOSED" then bankOpen = false end
  if event == "GUILDBANKFRAME_CLOSED" then guildBankOpen = false end
  renderRows()
end

--- Update controls or install mail hooks when a relevant addon loads.
---@param _ string Event name.
---@param addonName string Loaded addon.
function module:OnMailAddonLoaded(_, addonName)
  if addonName == "Auctionator" then
    if Self.ListviewBagAuction and Self.ListviewBagAuction.HasAuctionator() then Self.ListviewBagAuction.Cancel() end
    updateViewControls()
    return
  end
  if addonName ~= "Blizzard_MailFrame" then return end
  installMailHooks()
  if mailOpen and MailFrame and SendMailFrame and SendMailFrame:IsShown() then
    openMailRecipientPicker(MailFrame, nil, nil, true)
  end
end

--- Refill the same recipient after Blizzard has reset the successfully sent draft.
function module:OnMailSendSuccess()
  local sent = pendingMail
  pendingMail = nil
  mailSendPending = false
  if pendingMailEvents then pendingMailEvents:UnregisterAllEvents() end
  if not sent then return end
  local selected = sent.selection
  local changed, stale = false, false
  for _, item in ipairs(sent.items) do
    local bag = selected.bag
    local recipient, amount = activeMailRecipient(bag, item.statusKey)
    if amount == item.amount and recipient == selected.id
      and bag.mailRecipients[selected.id] == selected.recipient and bag.mailItems[item.statusKey]
      and selected.recipient.character:lower() == sent.character:lower() then
      if item.amount then
        item.amount.remaining = item.amount.remaining - item.count
        if item.amount.remaining <= 0 then
          local queue = bag.mailQueues[item.statusKey]
          table.remove(queue, 1)
          if #queue == 0 then bag.mailQueues[item.statusKey] = nil end
        end
        changed = true
      end
    else
      stale = true
    end
  end
  if changed and isModuleEnabled() and settings() == selected.bag then
    renderRows()
    updateMerchantJunkButton()
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then registry:NotifyChange("SlackHacks") end
  end
  if sent.uncertain then
    prn("a one-time mail attachment changed; check the remaining amount before preparing more mail.")
    if recipientPicker and recipientPicker:IsShown() and recipientPicker.mailMode
      and recipientPicker.bag == selected.bag then recipientPicker.refreshRecipients() end
    return
  end
  if stale then
    prn("a one-time mail flag or recipient changed; select the recipient again.")
    if recipientPicker and recipientPicker:IsShown() and recipientPicker.mailMode
      and recipientPicker.bag == selected.bag then recipientPicker.refreshRecipients() end
    return
  end
  --- Wait for transient bag locks before preparing the next batch.
  ---@param attempts number Number of lock checks.
  local function prepareNextBatch(attempts)
    if not isModuleEnabled() or mailSelection ~= selected or settings() ~= selected.bag
      or not recipientPicker or not recipientPicker:IsShown() or not recipientPicker.mailMode
      or not SendMailFrame:IsShown() or selected.bag.mailRecipients[selected.id] ~= selected.recipient
      or selected.recipient.character:lower() ~= sent.character:lower() then return end
    local items = collectRecipientMailItems(selected.bag)[selected.id]
    if not items or #items == 0 then
      recipientPicker.refreshRecipients()
      return
    end
    if #unlockedMailItems(items) == 0 then
      if attempts < 20 then
        C_Timer.After(0.1, function() prepareNextBatch(attempts + 1) end)
      else
        prn("the remaining items are locked; select the recipient when they become available.")
        recipientPicker.refreshRecipients()
      end
      return
    end
    local draft = captureMailDraft()
    if mailDraftOccupied(draft) then
      prn("the mail draft changed after sending; select the recipient to prepare the next batch.")
      recipientPicker.refreshRecipients()
      return
    end
    startRecipientMail(selected.bag, selected.id, selected.recipient, draft)
  end
  C_Timer.After(0, function() prepareNextBatch(0) end)
end

--- Forget a failed send without preparing another batch.
function module:OnMailSendFailed()
  pendingMail = nil
  mailSendPending = false
  if pendingMailEvents then pendingMailEvents:UnregisterAllEvents() end
end

--- Refresh recipient availability after the compose attachments change.
function module:OnMailInfoUpdate()
  if not mailJob and recipientPicker and recipientPicker:IsShown() and recipientPicker.mailMode then
    recipientPicker.refreshRecipients()
  end
end

--- Show the list view for a native open request without toggling an already-open window closed.
function module:OnNativeBagOpen()
  if openingDefaultBags then return end
  if isModuleEnabled() and settings().showListviewBag then
    hideDefaultBags()
    frame:Show()
  end
end

function module:UpdateListViewBindings()
  updateListViewBindings()
end

function module:RefreshFooter()
  refreshFooter()
end

--- Update an outstanding inventory-summary item request.
---@param event string Event name.
---@param itemID number Requested item identifier.
---@param success boolean Whether item data loaded successfully.
function module:OnSlotItemDataLoaded(event, itemID, success)
  if not slotItemLoads[itemID] then return end
  if success then slotItemLoads[itemID] = nil else slotItemLoads[itemID] = "failed" end
  refreshFooter()
end

--- Refresh equipped ammunition when the player's inventory changes.
---@param event string Event name.
---@param unit string Unit whose inventory changed.
function module:OnSupplyInventoryChanged(event, unit)
  if unit == "player" then refreshFooter() end
end

function module:Refresh()
  if not frame then return end
  renderRows()
  updateMerchantJunkButton()
  if not mailJob and recipientPicker and recipientPicker:IsShown() and recipientPicker.mailMode then
    recipientPicker.refreshRecipients()
  end
  if frame:IsShown() then
    updateFooter()
  end
end
