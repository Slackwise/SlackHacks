setfenv(1, _G.SlackHacks)

--[[
  ListviewBag: a simplified, sortable list-view alternative to the default grid-style bag window.
  Reuses Blizzard's own bag data APIs (C_Container) and as many native widgets/templates as possible
  (NineSlicePanelTemplate border, UIPanelCloseButton, UICheckButtonTemplate, UIPanelScrollFrameTemplate,
  StackSplitFrame) so the window looks/feels like a first-party Blizzard panel and behaves correctly
  in combat (no custom secure wrappers -- every click/drag script calls the same unprotected Container
  APIs the default UI itself uses, straight from a real hardware OnClick/OnDrag event).
]]--

local module = Self:NewModule("ListviewBag", "AceEvent-3.0")
Self.ListviewBag = module

--=====================================================================
-- Constants
--=====================================================================

local FRAME_NAME = "SlackHacksListviewBagFrame"
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
local VENDOR_ICON_ATLAS = "bags-junkcoin"

local BIND_ICON_TEXTURE = "Interface\\AddOns\\SlackHacks\\Assets\\bind-icons-texture"

--=====================================================================
-- Small helpers
--=====================================================================

-- The bags this window displays: the backpack, the 4 equipped bags, and (retail only) the reagent bag.
local function bagIDs()
  local ids = { 0, 1, 2, 3, 4 }
  if isRetail() and Enum.BagIndex and Enum.BagIndex.ReagentBag then
    ids[#ids + 1] = Enum.BagIndex.ReagentBag
  end
  return ids
end

local function findEmptyBagSlot()
  for _, bagID in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      if not C_Container.GetContainerItemInfo(bagID, slot) then
        return bagID, slot
      end
    end
  end
end

local function settings()
  local listviewSettings = db.profile.listviewBag
  listviewSettings.protectedItems = listviewSettings.protectedItems or {}
  listviewSettings.trashItems = listviewSettings.trashItems or {}
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

local function isModuleEnabled()
  return settings() and settings().enabled
end

local function itemStatusKey(itemName, quality, itemLevel, upgradeTrack)
  return table.concat({ itemName or "", quality or 0, itemLevel or 0, upgradeTrack or "" }, "\031")
end

local function isProtectedItem(key)
  return settings().protectedItems[key] ~= nil
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
  local bindType = select(14, GetItemInfo(itemLink))
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
      if info and info.itemID then
        local key = info.hyperlink or info.itemID
        local group = groups[key]
        if not group then
          group = {
            key = key,
            itemID = info.itemID,
            hyperlink = info.hyperlink,
            itemName = info.itemName,
            icon = info.iconFileID,
            quality = info.quality or Enum.ItemQuality.Common or 1,
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
    local itemName, itemLink, quality, itemLevel, _, itemType, itemSubType, _, itemEquipLoc, _, _, classID = GetItemInfo(group.hyperlink)
    group.itemName = itemName or group.itemName
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
    if group.isArmor then
      group.armorType = itemSubType
      group.armorSlot = itemEquipLoc and _G[itemEquipLoc]
    end
    if first then
      group.bindLabel, group.bindType, group.accountBound, group.isBound = getBindInfo(first.bagID, first.slot, group.hyperlink)
    end
    group.statusKey = itemStatusKey(group.itemName, group.quality, group.itemLevel, group.upgradeTrack)
    group.statusInfo = {
      name = group.itemName,
      quality = group.quality,
      itemLevel = group.itemLevel,
      upgradeTrack = group.upgradeTrack,
    }
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
    else
      if a.quality ~= b.quality then return a.quality > b.quality end
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
local searchText = ""
local layoutHeaders, renderRows, positionRowCells, layoutFrame
local sellMarkedTrashItems

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
end

--=====================================================================
-- Row widgets
--=====================================================================

local function cycleStatus(key, statusInfo)
  if isProtectedItem(key) then
    settings().protectedItems[key] = nil
    settings().trashItems[key] = statusInfo
  elseif isTrashItem(key) then
    settings().trashItems[key] = nil
  else
    settings().protectedItems[key] = statusInfo
  end
  renderRows()
end

local function createRow(index)
  local row = CreateFrame("Button", nil, scrollChild)
  row:SetHeight(ROW_HEIGHT)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp") -- default Button widgets ignore right-click

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

  -- Single icon button cycling None -> Locked -> Trash -> None (instead of two separate checkboxes).
  row.statusBtn = CreateFrame("Button", nil, row)
  row.statusBtn:SetSize(STATUS_WIDTH, STATUS_WIDTH)
  row.statusBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.statusBtn.icon = row.statusBtn:CreateTexture(nil, "ARTWORK")
  row.statusBtn.icon:SetSize(14, 14)
  row.statusBtn.icon:SetPoint("CENTER")
  row.statusBtn:SetScript("OnClick", function() cycleStatus(row.statusKey, row.statusInfo) end)
  row.statusBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if isProtectedItem(row.statusKey) then
      GameTooltip:SetText("Protected (click to mark for Vendor instead)")
    elseif isTrashItem(row.statusKey) then
      GameTooltip:SetText("Marked for Vendor (click to clear)")
    else
      GameTooltip:SetText("Click to Protect, click again to mark for Vendor")
    end
    GameTooltip:Show()
  end)
  row.statusBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

  -- The item tooltip lives on the row itself (rather than a separate overlay frame covering the
  -- icon/name) so the row's own native highlight -- driven by SetHighlightTexture based on mouse focus
  -- -- keeps working while hovering the item instead of being stolen by a mouse-enabled child frame.
  row:SetScript("OnEnter", function(self)
    -- Mirrors ContainerFrameItemButton_OnEnter: SetBagItem (not SetHyperlink) so the tooltip reflects
    -- the item's real in-bag state (e.g. actual Soulbound status) instead of a hypothetical "not yet
    -- acquired" copy of the item.
    if row.primaryEntry then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetBagItem(row.primaryEntry.bagID, row.primaryEntry.slot)
      GameTooltip:Show()
    elseif row.hyperlink then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(row.hyperlink)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)

  -- Dragging/using/splitting the item reuses the exact unprotected Container APIs the default bags
  -- use, called directly from a real hardware click/drag event -- this is what keeps right-click "use"
  -- and drag-pickup reliable in combat (no macro/secure-frame indirection to fight with).
  row:RegisterForDrag("LeftButton")
  row:SetScript("OnDragStart", function()
    if row.locked or not row.primaryEntry then return end
    C_Container.PickupContainerItem(row.primaryEntry.bagID, row.primaryEntry.slot)
  end)
  row:SetScript("OnReceiveDrag", function()
    if row.locked or not row.primaryEntry then return end
    C_Container.PickupContainerItem(row.primaryEntry.bagID, row.primaryEntry.slot)
  end)
  row:SetScript("OnClick", function(_, button)
    if not row.primaryEntry then return end
    if button == "RightButton" then
      if row.locked and MerchantFrame and MerchantFrame:IsShown() then return end
      C_Container.UseContainerItem(row.primaryEntry.bagID, row.primaryEntry.slot)
    elseif IsModifiedClick("SPLITSTACK") and row.primaryEntry.count and row.primaryEntry.count > 1 then
      row.SplitStack = function(_, split)
        C_Container.SplitContainerItem(row.primaryEntry.bagID, row.primaryEntry.slot, split)
        local bagID, slot = findEmptyBagSlot()
        if bagID and slot then
          C_Container.PickupContainerItem(bagID, slot)
        end
      end
      StackSplitFrame:OpenStackSplitFrame(row.primaryEntry.count, row, "BOTTOMLEFT", "TOPLEFT")
    elseif row.hyperlink and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")) then
      HandleModifiedItemClick(row.hyperlink)
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
-- Groups not matching the search box's text (an item-name substring match) are dropped entirely.
local function buildDisplayRows()
  local groups = collectGroups()
  local rows = {}
  for _, group in ipairs(groups) do
    if searchText == "" or (group.itemName and group.itemName:lower():find(searchText, 1, true)) then
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
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    row:Show()
    row.stripe:SetShown(i % 2 == 0) -- alternating-row banding, same look as the guild roster list
    row.itemID = data.itemID
    row.hyperlink = data.hyperlink
    row.isChild = data.isChild
    row.groupKey = data.isGroupHeader and data.key or nil
    row.statusKey = data.statusKey
    row.statusInfo = data.statusInfo
    row.primaryEntry = data.entries and data.entries[1]
    row.locked = isProtectedItem(data.statusKey)

    if data.isGroupHeader then
      row.collapseBtn:Show()
      row.collapseBtn.text:SetText(expandedGroups[data.key] and "-" or "+")
    else
      row.collapseBtn:Hide()
    end

    if isProtectedItem(data.statusKey) then
      row.statusBtn.icon:SetAtlas(PROTECT_ICON_ATLAS)
      row.statusBtn.icon:Show()
    elseif isTrashItem(data.statusKey) then
      row.statusBtn.icon:SetAtlas(VENDOR_ICON_ATLAS)
      row.statusBtn.icon:Show()
    else
      row.statusBtn.icon:Hide()
    end

    row.icon:SetTexture(data.icon)
    local qualityColor = data.quality and (ITEM_QUALITY_COLORS[data.quality] or ITEM_QUALITY_COLORS[1])
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
    rowPool[i]:Hide()
  end
end

--=====================================================================
-- Footer: gold + tracked currencies + a shortcut to open the Currency panel
--=====================================================================

local function updateFooter()
  MoneyFrame_Update(footer.moneyFrame:GetName(), GetMoney())
  footer.tokenFrame:Show()
  footer.tokenFrame:Update()
  footer.tokenFrame:SetShown(footer.tokenFrame:ShouldShow())
end

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

  footer.moneyFrame = CreateFrame("Frame", "SlackHacksListviewBagMoneyFrame", footer, "ContainerMoneyFrameTemplate")
  footer.moneyFrame:SetSize(168, 16)
  footer.moneyFrame:SetPoint("LEFT", footer, "LEFT", 88, 0)
  MoneyFrame_SetMaxDisplayWidth(footer.moneyFrame, 168)

  footer.sellTrashButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
  footer.sellTrashButton:SetSize(80, 20)
  footer.sellTrashButton:SetPoint("LEFT", footer, "LEFT", 0, 0)
  footer.sellTrashButton:SetText("Sell Trash")
  footer.sellTrashButton:SetEnabled(MerchantFrame and MerchantFrame:IsShown())
  footer.sellTrashButton:SetScript("OnClick", function() sellMarkedTrashItems() end)

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
  footer.tokenFrame = CreateFrame("Frame", nil, footer, "BackpackTokenFrameTemplate")
  footer.tokenFrame:SetIsCombinedInventory(true)
  footer.tokenFrame:SetWidth(150)
  footer.tokenFrame:SetPoint("RIGHT", footer.currencyButton, "LEFT", -4, 0)
  footer.moneyFrame:SetPoint("RIGHT", footer.tokenFrame, "LEFT", -4, 0)
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

-- Closes via Blizzard's own CloseAllBags() -- the same call the default UI's close button/ESC use --
-- instead of reaching in and calling :Hide() on each ContainerFrame ourselves. Hiding the container
-- frames directly never told Blizzard's own "which bags are open" bookkeeping that they'd closed, and
-- left sibling elements anchored to them (e.g. the tracked-currency display, which isn't actually a
-- child of the container) stranded at stale positions instead of being hidden/repositioned with them.
local function hideDefaultBags()
  if _G.CloseAllBags then
    CloseAllBags()
  end
end

local function areDefaultBagsShown()
  local shown = false
  forEachDefaultBagFrame(function(defaultFrame)
    shown = shown or defaultFrame:IsShown()
  end)
  return shown
end

-- Reopens via the same native entry points the default UI uses so Blizzard recomputes each frame's
-- anchor/position itself, instead of us calling :Show() directly on stale frames.
local function showDefaultBags()
  if areDefaultBagsShown() then return end
  if _G.ToggleAllBags then
    ToggleAllBags()
  elseif _G.OpenAllBags then
    OpenAllBags()
  end
end

local function setListViewActive(active)
  settings().listViewActive = active
  if viewToggleButton then
    viewToggleButton:SetChecked(active)
  end
  if active then
    hideDefaultBags()
    module:UpdateListViewBindings()
    frame:Show()
  else
    frame:Hide()
    module:UpdateListViewBindings()
    showDefaultBags()
  end
end

local function updateListViewBindings()
  if not bagKeyBindingButton or InCombatLockdown() then return end
  ClearOverrideBindings(bagKeyBindingButton)
  if not isModuleEnabled() or not settings().listViewActive then return end
  for _, command in ipairs({ "TOGGLEBACKPACK", "OPENALLBAGS" }) do
    for _, key in ipairs({ GetBindingKey(command) }) do
      if key then
        SetOverrideBindingClick(bagKeyBindingButton, true, key, bagKeyBindingButton:GetName())
      end
    end
  end
end

local lastNativeBagToggle = 0
local function toggleListViewFromNativeBagAction()
  if not frame or not isModuleEnabled() or not settings().listViewActive then return end
  if MerchantFrame and MerchantFrame:IsShown() then
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
  if bagMenuHooksInstalled or not Menu or not Menu.ModifyMenu then return end
  bagMenuHooksInstalled = true
  for _, menuTag in ipairs({ "MENU_CONTAINER_FRAME", "MENU_CONTAINER_FRAME_COMBINED" }) do
    Menu.ModifyMenu(menuTag, function(_, rootDescription)
      rootDescription:CreateDivider()
      rootDescription:CreateButton("Show SlackHacks's Listview Bag", function()
        settings().enabled = true
        settings().listViewActive = true
        if module:IsEnabled() then
          setListViewActive(true)
        else
          module:Enable()
        end
      end)
    end)
  end
end

local hookedBagToggleFuncs = {}
local function hookDefaultBagToggles()
  for _, funcName in ipairs({ "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
    if _G[funcName] and not hookedBagToggleFuncs[funcName] then
      hookedBagToggleFuncs[funcName] = true
      hooksecurefunc(funcName, toggleListViewFromNativeBagAction)
    end
  end
  if _G.CloseBackpack and not hookedBagToggleFuncs.CloseBackpack then
    hookedBagToggleFuncs.CloseBackpack = true
    hooksecurefunc("CloseBackpack", function()
      if frame and isModuleEnabled() and settings().listViewActive then
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
  viewToggleButton:SetScript("OnClick", function(self) setListViewActive(self:GetChecked()) end)
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
    setListViewActive(false)
    settings().enabled = false
    module:Disable()
  end)

  bagKeyBindingButton = CreateFrame("Button", "SlackHacksListviewBagToggleButton", UIParent)
  bagKeyBindingButton:SetSize(1, 1)
  bagKeyBindingButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
  bagKeyBindingButton:SetAlpha(0)
  bagKeyBindingButton:SetScript("OnClick", function()
    if isModuleEnabled() and settings().listViewActive then
      if frame:IsShown() then frame:Hide() else frame:Show() end
    end
  end)

  -- Same search box Blizzard's own combined bags window has, filtering rows by item name substring.
  searchBox = CreateFrame("EditBox", nil, content, "SearchBoxTemplate")
  searchBox:SetSize(200, 20)
  searchBox:SetPoint("TOPLEFT", content, "TOPLEFT", 62, -32)
  searchBox:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    searchText = self:GetText():lower()
    renderRows()
  end)

  -- Keep the native column buttons, but let the window's own header texture show behind them.
  -- Inset by COLLAPSE_WIDTH so its first column aligns with the row cells after the pinned expand cell.
  headerFrame = CreateFrame("Frame", nil, content, "ColumnDisplayTemplate")
  headerFrame:SetHeight(30)
  headerFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10 + COLLAPSE_WIDTH, -56)
  headerFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -56)
  headerFrame.Background:Hide()
  headerFrame.TopTileStreaks:Hide()
  headerFrame.sortingFunction = function(_, columnIndex)
    local colID = settings().columnOrder[columnIndex]
    if sortColumn == colID then
      sortAscending = not sortAscending
    else
      sortColumn = colID
      sortAscending = true
    end
    renderRows()
  end
  content.statusHeaderButton = CreateFrame("Button", nil, headerFrame, "ColumnDisplayButtonNoScriptsTemplate")
  content.statusHeaderButton:SetSize(24, 24)
  content.statusHeaderButton:SetPoint("BOTTOM", headerFrame, "BOTTOMRIGHT", -30, 1)
  content.statusHeaderButton:SetText(CreateAtlasMarkup(PROTECT_ICON_ATLAS, 14, 14))

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
sellMarkedTrashItems = function()
  for _, bagID in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID then
        local itemName, itemLink, _, itemLevel = GetItemInfo(info.hyperlink)
        local upgradeTrack = getUpgradeTrack(bagID, slot)
        local key = itemStatusKey(itemName or info.itemName, info.quality, C_Item.GetDetailedItemLevelInfo(info.hyperlink) or itemLevel, upgradeTrack)
        if isTrashItem(key) and not isProtectedItem(key) then
          C_Container.UseContainerItem(bagID, slot)
        end
      end
    end
  end
end

local merchantJunkHooked = false
local function hookMerchantJunkButton()
  if merchantJunkHooked or not _G.MerchantFrame_OnSellAllJunkButtonConfirmed then return end
  merchantJunkHooked = true
  hooksecurefunc("MerchantFrame_OnSellAllJunkButtonConfirmed", function()
    if isModuleEnabled() and not settings().autoSellMarkedItems then
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
  hookMerchantJunkButton()
  self:RegisterEvent("BAG_OPEN", "OnNativeBagOpen")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateListViewBindings")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "Refresh")
  self:RegisterEvent("PLAYER_MONEY", "RefreshFooter")
  self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "RefreshFooter")
  self:RegisterEvent("MERCHANT_SHOW")
  self:RegisterEvent("MERCHANT_CLOSED")
  EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", self.RefreshFooter, self)
  if settings().listViewActive then
    setListViewActive(true)
  end
end

function module:OnDisable()
  -- Only swap back to the default bags if our window was actually open -- doesn't force bags open,
  -- and deliberately leaves the player's list-view preference (settings().listViewActive) untouched
  -- so it's remembered next time the module/feature is re-enabled.
  local wasShown = frame and frame:IsShown()
  if frame then frame:Hide() end
  self:UpdateListViewBindings()
  if wasShown then
    showDefaultBags()
  end
  EventRegistry:UnregisterCallback("TokenFrame.OnTokenWatchChanged", self)
end

function module:MERCHANT_SHOW()
  hideDefaultBags()
  if settings().listViewActive then
    frame:Show()
  end
  if settings().autoSellMarkedItems then
    sellMarkedTrashItems()
  end
  if footer and footer.sellTrashButton then
    footer.sellTrashButton:SetEnabled(true)
  end
end

function module:MERCHANT_CLOSED()
  if footer and footer.sellTrashButton then
    footer.sellTrashButton:SetEnabled(false)
  end
end

function module:OnNativeBagOpen()
  if isModuleEnabled() and settings().listViewActive then
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
  if frame:IsShown() then
    updateFooter()
  end
end
