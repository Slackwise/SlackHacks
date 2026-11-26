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
  armorType = { label = "Type",  width = 70 },
  armorSlot = { label = "Slot",  width = 70 },
  bind =      { label = "|TInterface\\AddOns\\SlackHacks\\Assets\\bind-icons-texture:18:18:0:0:128:64:6:26:7:28|t", width = 24 },
}
local DEFAULT_COLUMN_ORDER = { "quantity", "name", "ilvl", "armorType", "armorSlot", "bind" }

-- English-only track-name recognizer used to pull the gear "track" (e.g. "Champion 5/6") out of the
-- tooltip, since there is no direct API exposing it -- this is a deliberate, documented simplification.
local TRACK_NAMES = { Explorer = true, Adventurer = true, Veteran = true, Champion = true, Hero = true, Myth = true, Awakened = true }

local ARMOR_CLASS_ID = (Enum.ItemClass and Enum.ItemClass.Armor) or 4
local sortColumn
local sortAscending = true

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
local ESSENTIAL_ITEM_IDS = {
  [6948] = true, -- Hearthstone
  [211527] = true, -- Cozy Sleeping Bag
  [280612] = true, -- Night Watchman's Torch
  [2901] = true, -- Mining Pick
  [7005] = true, -- Skinning Knife
  [5956] = true, -- Blacksmith Hammer
  [6219] = true, -- Arclight Spanner
  [10498] = true, -- Gyromatic Micro-Adjustor
  [4471] = true, -- Flint and Tinder
  [6256] = true, -- Fishing Pole
  [20815] = true, -- Jeweler's Toolset
  [20824] = true, -- Simple Grinder
  [40892] = true, -- Hammer Pick
  [40893] = true, -- Bladed Pickaxe
  [40772] = true, -- Gnomish Army Knife
  [6218] = true, -- Runed Copper Rod
  [6339] = true, -- Runed Silver Rod
  [11130] = true, -- Runed Golden Rod
  [11145] = true, -- Runed Truesilver Rod
  [16207] = true, -- Runed Arcanite Rod
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

--- Return bag settings, initializing optional status lists in older profiles.
---@return table settings Current profile's bag settings.
local function settings()
  local listviewSettings = db.profile.listviewBag
  for _, status in ipairs(ITEM_STATUSES) do
    listviewSettings[status.field] = listviewSettings[status.field] or {}
  end
  listviewSettings.flagFilters = listviewSettings.flagFilters or {}
  listviewSettings.categoryFilters = listviewSettings.categoryFilters or {}
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

--- Return the item's selected status, prioritizing non-junk flags for older overlapping marks.
---@param key string Item status key.
---@return table|nil status Selected status definition.
local function getItemStatus(key)
  local listviewSettings = settings()
  if listviewSettings.protectedItems[key] ~= nil then return PROTECT_STATUS end
  for index = 2, #ITEM_STATUSES do
    local status = ITEM_STATUSES[index]
    if listviewSettings[status.field][key] ~= nil then return status end
  end
  if listviewSettings.trashItems[key] ~= nil then return ITEM_STATUSES[1] end
end

local function isModuleEnabled()
  return settings() and settings().enabled
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
    elseif text == ITEM_ACCOUNTBOUND or text == ITEM_BIND_TO_ACCOUNT or text == ITEM_BNETACCOUNTBOUND then
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

--- Group items from visible bags, excluding the reagent bag when its checkbox is unchecked.
---@return table groups Combined item rows and their underlying bag slots.
-- Walks every tracked bag slot and groups identical items (same hyperlink) into one combined row, the
-- same way the default UI's "combined bags" view merges stacks together. Each group remembers every
-- underlying bagID/slot ("entries") so actions (locking, dragging, splitting) can still reach the real
-- item(s) once expanded.
local function collectGroups()
  local groups, order = {}, {}
  for _, bagID in ipairs(bagIDs()) do
    if bagID ~= REAGENT_BAG_ID or settings().showReagentBagContents then
      local numSlots = C_Container.GetContainerNumSlots(bagID)
      for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID and not info.isFiltered then
          local key = info.hyperlink or info.itemID
          local group = groups[key]
          if not group then
            group = {
              key = key,
              itemID = info.itemID,
              hyperlink = info.hyperlink,
              itemName = info.itemName,
              icon = info.iconFileID,
              quality = info.quality,
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
  end

  -- Decorate each group with the details that need a slower lookup (GetItemInfo/tooltip), using the
  -- group's first entry as the representative bag slot for bind/track text.
  for _, group in ipairs(order) do
    local itemName, itemLink, quality, itemLevel, _, itemType, itemSubType, _, itemEquipLoc, _, sellPrice,
      classID, _, _, _, _, isCraftingReagent = C_Item.GetItemInfo(group.hyperlink)
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
    group.classID, group.equipLoc, group.sellPrice, group.isCraftingReagent =
      classID, itemEquipLoc, sellPrice, isCraftingReagent
    if group.isArmor then
      group.armorType = itemSubType
      group.armorSlot = itemEquipLoc and _G[itemEquipLoc]
    end
    if first then
      group.bindLabel, group.bindType, group.accountBound, group.isBound = getBindInfo(first.bagID, first.slot, group.hyperlink)
    end
    group.statusKey = itemStatusKey(group.itemName, group.quality, group.itemLevel, group.upgradeTrack)
    if sortColumn == "flag" then
      local status = group.quality ~= 0 and getItemStatus(group.statusKey) or nil
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
local viewToggleButton
local bagKeyBindingButton
local layoutHeaders, renderRows, positionRowCells, layoutFrame
local sellMarkedTrashItems, updateMerchantJunkButton
-- Tracked from MERCHANT_SHOW/MERCHANT_CLOSED rather than MerchantFrame:IsShown(), because Blizzard's
-- frame may not have shown/hidden yet when our handler for the same event runs.
local merchantOpen = false
local mailOpen = false
local auctionOpen = false
local bankOpen = false
local guildBankOpen = false
local trackedCursorItem

-- Distributes the header/row widths for the currently reorderable columns, giving the "name" column
-- whatever space is left over. Non-reorderable cells (collapse arrow, lock/trash status) are pinned.
local function computeLayout()
  local contentWidth = scrollChild:GetWidth()
  local fixedWidth = 0
  for _, colID in ipairs(settings().columnOrder) do
    local def = COLUMN_DEFS[colID]
    if not def.flexible then
      fixedWidth = fixedWidth + def.width + CELL_PAD
    end
  end
  local flexWidth = math.max(COLUMN_DEFS.name.width, contentWidth - COLLAPSE_WIDTH - STATUS_WIDTH - fixedWidth - CELL_PAD)

  local x = COLLAPSE_WIDTH + CELL_PAD
  columnLayout = {}
  for _, colID in ipairs(settings().columnOrder) do
    local def = COLUMN_DEFS[colID]
    local width = def.flexible and flexWidth or def.width
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
  local order = settings().columnOrder
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
    local colID = settings().columnOrder[header:GetID()]
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

--- Check an item against the selected flag and item-category filters.
---@param group table Collected item and its metadata.
---@return boolean matches Whether the item is visible.
local function matchesFilters(group)
  local bag = settings()
  local status = group.quality ~= 0 and getItemStatus(group.statusKey) or nil
  if bag.flagFilters[status and status.id or "unflagged"] == false then return false end

  -- The game does not expose its sorter classification. Resolve overlapping item properties
  -- in priority order, independently of which filters are enabled.
  local category
  if ESSENTIAL_ITEM_IDS[group.itemID] then
    category = "special"
  elseif group.classID == 12 or group.bindType == 4 then
    category = "quest"
  elseif group.quality == 0 and group.sellPrice ~= nil then
    category = "junk"
  elseif group.isCraftingReagent then
    category = "reagents"
  elseif EQUIPMENT_SLOTS[group.equipLoc] or (group.equipLoc == "INVTYPE_RELIC" and not isRetailOrForever()) then
    category = "equipment"
  elseif group.classID == 0 then
    category = "consumables"
  elseif group.classID == 7 then
    category = "professionGoods"
  else
    category = "other"
  end
  return bag.categoryFilters[category] ~= false
end

--- Replace an item's status while retaining the metadata used by vendor matching.
---@param key string Item status key.
---@param statusInfo table Item metadata to save.
---@param selected table|nil Status definition, or nil to clear.
local function setItemStatus(key, statusInfo, selected)
  if selected and (statusInfo.quality == nil or statusInfo.quality == 0) then
    prn(statusInfo.quality == 0 and "grey items cannot be flagged." or "item quality is not yet available.")
    return
  end
  local listviewSettings = settings()
  for _, status in ipairs(ITEM_STATUSES) do
    listviewSettings[status.field][key] = nil
  end
  if selected then listviewSettings[selected.field][key] = statusInfo end
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
  if quality == 0 then return nil end
  local bag = settings()
  local protected = bag.protectedItems[key] ~= nil or bag.bankItems[key] ~= nil
  local auction = bag.auctionItems[key] ~= nil
  local mail = bag.mailItems[key] ~= nil
  if merchantOpen and (protected or auction or mail) then
    return "vendoring"
  end
  if auctionOpen and (protected or mail) then
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
  local cursorType, _, link = GetCursorInfo()
  if cursorType == "item" and link and link == row.hyperlink then
    trackedCursorItem = { key = row.statusKey, quality = row.statusInfo.quality, link = link }
  else
    trackedCursorItem = nil
  end
end

--- Return a tracked cursor item if the newly opened destination conflicts with its flag.
local function returnBlockedCursorItem()
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

--- Open a menu for selecting or clearing the item's single status.
---@param anchor table Status button.
---@param key string Item status key.
---@param statusInfo table Item metadata to save.
local function openItemStatusMenu(anchor, key, statusInfo)
  GameTooltip:Hide()
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(anchor, function(_, root)
      root:CreateTitle("Flag item for:")
      root:CreateRadio("None", function() return not getItemStatus(key) end,
        function() setItemStatus(key, statusInfo, nil) end)
      for _, entry in ipairs(ITEM_STATUSES) do
        local status = entry
        local label = statusMenuLabel(status)
        root:CreateRadio(label, function() return getItemStatus(key) == status end,
          function() setItemStatus(key, statusInfo, status) end)
      end
    end)
  else
    local menu = {
      { text = "Flag item for:", isTitle = true, notCheckable = true },
      { text = "None", checked = function() return not getItemStatus(key) end,
        func = function() setItemStatus(key, statusInfo, nil) end },
    }
    for _, entry in ipairs(ITEM_STATUSES) do
      local status = entry
      menu[#menu + 1] = {
        text = statusMenuLabel(status),
        checked = function() return getItemStatus(key) == status end,
        func = function() setItemStatus(key, statusInfo, status) end,
      }
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
    if row.statusInfo.quality == nil or row.statusInfo.quality == 0 then
      prn(row.statusInfo.quality == 0 and "grey items cannot be flagged." or "item quality is not yet available.")
      return
    end
    if button == "RightButton" then
      local status = getItemStatus(row.statusKey)
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
    local status = getItemStatus(row.statusKey)
    if row.statusInfo.quality == 0 then
      GameTooltip:SetText("Grey items cannot be flagged.")
    elseif row.statusInfo.quality == nil then
      GameTooltip:SetText("Item quality is not yet available.")
    else
      GameTooltip:SetText("Flag item for: " .. (status and status.name or "None"))
      local rightClick = status and status ~= ITEM_STATUSES[1] and "Right-click cannot change this flag."
        or "Right-click to quick mark as Junk."
      GameTooltip:AddLine("Left-click to choose flag.\n" .. rightClick, 1, 1, 1, true)
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
  row.quantityText:SetJustifyH("RIGHT")
  row.ilvlText:SetJustifyH("LEFT")
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

  for _, colID in ipairs({ "quantity", "ilvl", "armorType", "armorSlot" }) do
    local cell = row[colID .. "Text"]
    cell:ClearAllPoints()
    cell:SetPoint("LEFT", row, "LEFT", columnLayout[colID].x, 0)
    cell:SetWidth(columnLayout[colID].width)
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
  for _, group in ipairs(groups) do
    if matchesFilters(group) then
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
            itemLevel = group.itemLevel,
            upgradeTrack = group.upgradeTrack,
            armorType = group.armorType,
            armorSlot = group.armorSlot,
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
  scrollChild:SetHeight(math.max(scrollFrame:GetHeight(), #rows * ROW_HEIGHT))

  for i, data in ipairs(rows) do
    local row = acquireRow(i)
    row.holder:ClearAllPoints()
    row.holder:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
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

    updateStatusButton(row.statusBtn, data.quality ~= 0 and getItemStatus(data.statusKey) or nil)

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
    if data.isArmor and data.itemLevel then
      local upgradeTrack = data.upgradeTrack and (" |cff9d9d9d" .. data.upgradeTrack .. "|r") or ""
      row.ilvlText:SetText(tostring(data.itemLevel) .. upgradeTrack)
    else
      row.ilvlText:SetText("")
    end
    row.armorTypeText:SetText(data.isArmor and data.armorType or "")
    row.armorSlotText:SetText(data.isArmor and data.armorSlot or "")
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
  end

  for i = #rows + 1, #rowPool do
    rowPool[i].holder:Hide()
  end
end

--=====================================================================
-- Footer: gold + tracked currencies + a shortcut to open the Currency panel
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

local function updateCrestFrame(self)
  self.tokenPool:ReleaseAll()
  self.Tokens = {}
  self.numWatchedTokens = 0
  if not isRetail() or not settings().trackCrestCurrencies then return end
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

local function sizeCurrencyFrame(currencyFrame)
  local width = 26
  for _, token in ipairs(currencyFrame.Tokens or {}) do
    width = width + token:GetWidth()
  end
  currencyFrame:SetWidth(width)
  local shown = currencyFrame:ShouldShow()
  currencyFrame:SetShown(shown)
  return shown and width or 0
end

local function updateFooter()
  MoneyFrame_Update(footer.moneyFrame:GetName(), GetMoney())
  footer.moneyFrame:SetWidth(footer.moneyFrame:GetWidth() + 13)
  footer.tokenFrame:Update()
  local tokenWidth = sizeCurrencyFrame(footer.tokenFrame)
  footer.crestFrame:Update()
  local crestWidth = sizeCurrencyFrame(footer.crestFrame)
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
  footer.balances:SetWidth(width)
end

--- Open the list-view filters using the available native menu API.
---@param anchor table Filters button.
local function openFiltersMenu(anchor)
  local bag = settings()
  --- Enable every visible filter without changing other bag settings.
  local function checkAll()
    if isRetailOrForever() then bag.showReagentBagContents = true end
    bag.flagFilters.unflagged = true
    for _, status in ipairs(ITEM_STATUSES) do bag.flagFilters[status.id] = true end
    for _, category in ipairs(ITEM_CATEGORIES) do bag.categoryFilters[category.id] = true end
    renderRows()
  end
  --- Toggle a filter and refresh the displayed rows.
  ---@param filters table Saved filter values.
  ---@param key string Filter key.
  local function toggle(filters, key)
    filters[key] = filters[key] == false
    renderRows()
  end
  --- Toggle whether reagent-bag slots are collected.
  local function toggleReagentBag()
    bag.showReagentBagContents = not bag.showReagentBagContents
    renderRows()
  end
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(anchor, function(_, root)
      local checkAllButton = root:CreateButton("Check All", checkAll)
      checkAllButton:SetResponse(MenuResponse.Refresh)
      if isRetailOrForever() then
        root:CreateCheckbox("Reagent Bag", function() return bag.showReagentBagContents end, toggleReagentBag)
      end
      root:CreateDivider()
      root:CreateTitle("Flags")
      root:CreateCheckbox("Unflagged", function() return bag.flagFilters.unflagged ~= false end,
        function() toggle(bag.flagFilters, "unflagged") end)
      for _, entry in ipairs(ITEM_STATUSES) do
        local status = entry
        root:CreateCheckbox(status.name, function() return bag.flagFilters[status.id] ~= false end,
          function() toggle(bag.flagFilters, status.id) end)
      end
      root:CreateDivider()
      root:CreateTitle("Categories")
      for _, entry in ipairs(ITEM_CATEGORIES) do
        local category = entry
        root:CreateCheckbox(category.name, function() return bag.categoryFilters[category.id] ~= false end,
          function() toggle(bag.categoryFilters, category.id) end)
      end
    end)
  else
    local menu = {
      { text = "Check All", notCheckable = true, keepShownOnClick = true, func = checkAll },
    }
    if isRetailOrForever() then
      menu[#menu + 1] = { text = "Reagent Bag", isNotRadio = true, keepShownOnClick = true,
        checked = function() return bag.showReagentBagContents end, func = toggleReagentBag }
    end
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

  footer.balances = CreateFrame("Frame", nil, footer)
  footer.balances:SetSize(168, 20)
  footer.balances:SetPoint("RIGHT", footer, "RIGHT", -24, 0)

  footer.moneyFrame = CreateFrame("Frame", "SlackHacksListviewBagMoneyFrame", footer.balances, "ContainerMoneyFrameTemplate")
  footer.moneyFrame:SetSize(168, 16)
  footer.moneyFrame:SetPoint("RIGHT", footer.balances, "RIGHT", 0, 0)
  MoneyFrame_SetMaxDisplayWidth(footer.moneyFrame, 168)

  footer.filtersButton = CreateFrame("Button", "SlackHacksListviewBagFiltersButton", content, "UIPanelButtonTemplate")
  footer.filtersButton:SetFrameLevel(content:GetFrameLevel() + 1)
  footer.filtersButton:SetSize(80, 20)
  footer.filtersButton:SetPoint("RIGHT", content.openBagsButton, "LEFT", -4, 0)
  footer.filtersButton:SetText("Filters")
  footer.filtersButton:SetScript("OnClick", openFiltersMenu)

  footer.currencyButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
  footer.currencyButton:SetSize(20, 20)
  footer.currencyButton:SetNormalTexture(133784)
  footer.currencyButton:SetPushedTexture(133784)
  footer.currencyButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  footer.currencyButton:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
  footer.currencyButton:SetScript("OnClick", function() ToggleCharacter("TokenFrame") end)
  footer.currencyButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Open Currencies Window")
    GameTooltip:Show()
  end)
  footer.currencyButton:SetScript("OnLeave", GameTooltip_Hide)

  if C_AddOns and C_AddOns.LoadAddOn then
    C_AddOns.LoadAddOn("Blizzard_TokenUI")
  else
    UIParentLoadAddOn("Blizzard_TokenUI")
  end
  footer.tokenFrame = CreateFrame("Frame", nil, footer.balances, "BackpackTokenFrameTemplate")
  footer.tokenFrame:SetIsCombinedInventory(true)
  footer.tokenFrame.GetMaxTokensWatched = function() return 3 end
  footer.tokenFrame:SetWidth(150)
  footer.tokenFrame:SetPoint("RIGHT", footer.moneyFrame, "LEFT", -4, 0)

  footer.crestFrame = CreateFrame("Frame", nil, footer.balances, "BackpackTokenFrameTemplate")
  footer.crestFrame:SetIsCombinedInventory(true)
  footer.crestFrame.Update = updateCrestFrame
  footer.crestFrame:SetWidth(276)
  footer.crestFrame:SetPoint("RIGHT", footer.tokenFrame, "LEFT", -4, 0)
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
  if viewToggleButton then
    viewToggleButton:SetChecked(show)
  end
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

function module:SetShowListviewBag(show)
  if not isModuleEnabled() then return end
  setShowListviewBag(show)
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
      rootDescription:CreateButton("Show SlackHacks's Listview Bag", function()
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

  -- Invisible click target for the view-toggle, above the border so it's always clickable; the actual
  -- portrait icon underneath (see portraitContainer above) is what's visually framed by the border ring.
  viewToggleButton = CreateFrame("CheckButton", nil, content)
  viewToggleButton:SetAllPoints(content.portrait)
  viewToggleButton:SetScript("OnClick", function(self) setShowListviewBag(self:GetChecked()) end)
  viewToggleButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Toggle List View")
    GameTooltip:Show()
  end)
  viewToggleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Matches PortraitFrameBaseTemplate's own TitleContainer anchors/frame level exactly.
  content.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  content.title:SetPoint("TOP", content, "TOP", 0, -6)
  content.title:SetPoint("LEFT", content, "TOPLEFT", 58, 0)
  content.title:SetPoint("RIGHT", content, "TOPRIGHT", -24, 0)
  content.title:SetText((UnitName("player") or "Character") .. "'s Inventory")

  -- The whole top strip is a native move handle (StartMoving/StopMovingOrSizing), matching how every
  -- other Blizzard window is dragged. Starts right of the portrait icon so it doesn't steal clicks
  -- from the view-toggle button sitting on top of that icon.
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

  content.openBagsButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  content.openBagsButton:SetSize(82, 20)
  content.openBagsButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -28, -32)
  content.openBagsButton:SetText("Open Bags")
  content.openBagsButton:SetScript("OnClick", function()
    openDefaultBagsTemporarily()
  end)

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
    selectSortColumn(settings().columnOrder[columnIndex])
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

--- Visit every bag slot holding a marked-trash item that a merchant would actually buy right now.
-- Skip items without vendor value and locked items already being sold or otherwise in use.
-- @param callback function|nil called as callback(bagID, slot) for each sellable slot.
-- @return number count of sellable trash slots found.
local function forEachSellableTrashSlot(callback)
  local count = 0
  for _, bagID in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID and not info.hasNoValue and not info.isLocked then
        local itemName, itemLink, quality, itemLevel = C_Item.GetItemInfo(info.hyperlink)
        local itemQuality = info.quality or quality
        local upgradeTrack = getUpgradeTrack(bagID, slot)
        local key = itemStatusKey(itemName or info.itemName, itemQuality, C_Item.GetDetailedItemLevelInfo(info.hyperlink) or itemLevel, upgradeTrack)
        if itemQuality ~= nil and itemQuality ~= 0 and isTrashItem(key) and not isProtectedItem(key) then
          count = count + 1
          if callback then callback(bagID, slot) end
        end
      end
    end
  end
  return count
end

--- Extend the native junk button's enabled state to include sellable marked items.
updateMerchantJunkButton = function()
  if not merchantOpen or not isModuleEnabled() or not _G.MerchantSellAllJunkButton
    or not C_MerchantFrame or not C_MerchantFrame.GetNumJunkItems then return end
  local hasItems = C_MerchantFrame.GetNumJunkItems() > 0 or forEachSellableTrashSlot() > 0
  MerchantSellAllJunkButton.Icon:SetDesaturated(not hasItems)
  MerchantSellAllJunkButton:SetEnabled(hasItems)
end

--- Sell every marked-trash item a merchant will buy, then refresh the native button state.
sellMarkedTrashItems = function()
  forEachSellableTrashSlot(C_Container.UseContainerItem)
  updateMerchantJunkButton()
end

local merchantJunkHooked = false
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
    if merchantOpen and isModuleEnabled() then
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
  bankOpen = BankFrame and BankFrame:IsShown() or false
  guildBankOpen = GuildBankFrame and GuildBankFrame:IsShown() or false
  hookMerchantJunkButton()
  updateMerchantJunkButton()
  self:RegisterEvent("BAG_OPEN", "OnNativeBagOpen")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateListViewBindings")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:RegisterEvent("INVENTORY_SEARCH_UPDATE", "Refresh")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "Refresh")
  self:RegisterEvent("PLAYER_MONEY", "RefreshFooter")
  self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "RefreshFooter")
  self:RegisterEvent("CURSOR_CHANGED", "OnCursorChanged")
  self:RegisterEvent("MERCHANT_SHOW")
  self:RegisterEvent("MERCHANT_CLOSED")
  self:RegisterEvent("MAIL_SHOW", "OnBagInteractionOpen")
  self:RegisterEvent("MAIL_CLOSED", "OnBagInteractionClosed")
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
  trackedCursorItem = nil
  if frame then frame:Hide() end
  self:UpdateListViewBindings()
  showDefaultBags()
  EventRegistry:UnregisterCallback("TokenFrame.OnTokenWatchChanged", self)
  if merchantOpen and merchantJunkHooked then MerchantFrame_Update() end
end

function module:MERCHANT_SHOW()
  merchantOpen = true
  returnBlockedCursorItem()
  hookMerchantJunkButton()
  if settings().showListviewBag then
    hideDefaultBags()
    frame:Show()
  end
  if settings().autoSellMarkedItems then
    sellMarkedTrashItems()
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
  if event == "MAIL_SHOW" then mailOpen = true end
  if event == "AUCTION_HOUSE_SHOW" then auctionOpen = true end
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
  if event == "MAIL_CLOSED" then mailOpen = false end
  if event == "AUCTION_HOUSE_CLOSED" then auctionOpen = false end
  if event == "BANKFRAME_CLOSED" then bankOpen = false end
  if event == "GUILDBANKFRAME_CLOSED" then guildBankOpen = false end
  renderRows()
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

function module:Refresh()
  if not frame then return end
  renderRows()
  updateMerchantJunkButton()
  if frame:IsShown() then
    updateFooter()
  end
end
