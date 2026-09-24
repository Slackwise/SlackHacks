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
local HEADER_HEIGHT = 18
local COLLAPSE_WIDTH = 16
local STATUS_WIDTH = 20
local CELL_PAD = 4
local WINDOW_WIDTH = 700 -- must comfortably fit every fixed column + the name column's minimum width,
                         -- or trailing columns (e.g. Bind) get clipped outside the scroll frame's bounds
local WINDOW_HEIGHT = 420

-- Reorderable columns (Collapse/expand and Lock/Trash status are pinned to the far left and are not
-- part of this list -- reordering them away from the row's leading edge would be confusing).
local COLUMN_DEFS = {
  quantity =  { label = "Qty",   width = 36 },
  name =      { label = "Name",  width = 200, flexible = true },
  quality =   { label = "Qual",  width = 24 },
  ilvl =      { label = "iLvl",  width = 100 },
  armorType = { label = "Type",  width = 70 },
  armorSlot = { label = "Slot",  width = 70 },
  bind =      { label = "Bind",  width = 24 },
}
local DEFAULT_COLUMN_ORDER = { "quantity", "name", "quality", "ilvl", "armorType", "armorSlot", "bind" }

-- English-only track-name recognizer used to pull the gear "track" (e.g. "Champion 5/6") out of the
-- tooltip, since there is no direct API exposing it -- this is a deliberate, documented simplification.
local TRACK_NAMES = { Explorer = true, Adventurer = true, Veteran = true, Champion = true, Hero = true, Myth = true, Awakened = true }

local ARMOR_CLASS_ID = (Enum.ItemClass and Enum.ItemClass.Armor) or 4

-- The gold padlock icon subregion of Blizzard's own talent-point-lock art (confirmed via wow-ui-source's
-- SharedXML template definitions), reused here instead of a custom texture for the "Locked" status icon.
local LOCK_ICON_TEXTURE = "Interface\\TalentFrame\\TalentFrame-Parts"
local LOCK_ICON_COORDS = { 0.9296875, 0.99609375, 0.68359375, 0.72460938 }
-- Blizzard's own small gold-coin icon (used throughout money frames), reused for the "Trash/Sell" status icon.
local TRASH_ICON_TEXTURE = "Interface\\MoneyFrame\\UI-GoldIcon"

-- Bind-status swatch colors (same "colored icon" language as the quality swatch, since there's no
-- confirmed native icon set for bind type specifically).
local BIND_ICON_COLORS = {
  Soulbound = { 0.8, 0.2, 0.2 },
  Warbound = { 0.2, 0.5, 0.9 },
  BoE = { 0.2, 0.8, 0.2 },
  BoU = { 0.2, 0.8, 0.2 },
  Quest = { 0.9, 0.8, 0.2 },
}

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

local function settings()
  return db.profile.listviewBag
end

local function isModuleEnabled()
  return settings() and settings().enabled
end

-- Trash items are keyed by itemID normally, but for armor we key by "name|itemLevel" instead (per
-- design) so that only the specific item-level variant the player flagged gets auto-sold -- a fresh,
-- higher-ilvl drop of the same-named piece is left alone until the player re-flags it.
local function trashKey(itemID, itemName, itemLevel, isArmor)
  if isArmor and itemName and itemLevel then
    return itemName .. "|" .. itemLevel
  end
  return itemID
end

local function isLockedItem(itemID)
  return settings().lockedItems[itemID] == true
end

local function isTrashItem(key)
  return settings().trashItems[key] == true
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
local function getBindLabel(bagID, slot, itemLink)
  for _, text in ipairs(scanBagItemLines(bagID, slot)) do
    if text == ITEM_SOULBOUND then
      return "Soulbound"
    elseif text == ITEM_ACCOUNTBOUND or text == ITEM_BIND_TO_ACCOUNT or text == ITEM_BNETACCOUNTBOUND then
      return "Warbound"
    end
  end
  local bindType = select(14, GetItemInfo(itemLink))
  if bindType == 1 then
    return "Soulbound"
  elseif bindType == 2 then
    return "BoE"
  elseif bindType == 3 then
    return "BoU"
  elseif bindType == 4 then
    return "Quest"
  end
  return ""
end

-- Extracts the upgrade-track suffix (e.g. "Champion 5/6") from the tooltip. There's no direct API for
-- this -- every addon that shows it does the same tooltip-line scan.
local function getTrackSuffix(bagID, slot)
  for _, text in ipairs(scanBagItemLines(bagID, slot)) do
    local track, cur, max = text:match("^(%a+)%s+(%d+)/(%d+)$")
    if track and TRACK_NAMES[track] then
      return (" (%s %s/%s)"):format(track, cur, max)
    end
  end
  return ""
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
    group.isArmor = classID == ARMOR_CLASS_ID
    if group.isArmor then
      local detailedLevel = C_Item.GetDetailedItemLevelInfo(group.hyperlink)
      group.itemLevel = detailedLevel or itemLevel
      local first = group.entries[1]
      group.trackSuffix = first and getTrackSuffix(first.bagID, first.slot) or ""
      group.armorType = itemSubType
      group.armorSlot = itemEquipLoc and _G[itemEquipLoc]
    end
    local first = group.entries[1]
    if first then
      group.bindLabel = getBindLabel(first.bagID, first.slot, group.hyperlink)
    end
    group.trashKey = trashKey(group.itemID, group.itemName, group.itemLevel, group.isArmor)
  end

  table.sort(order, function(a, b)
    if a.quality ~= b.quality then return a.quality > b.quality end
    return (a.itemName or "") < (b.itemName or "")
  end)

  return order
end

--=====================================================================
-- Frame construction (declared up front, built lazily the first time the module is enabled)
--=====================================================================

local frame, content, scrollFrame, scrollChild, headerFrame, footer
local headerButtons = {}
local columnLayout = {}
local rowPool = {}
local expandedGroups = {}
local viewToggleButton
local layoutHeaders, renderRows, positionRowCells, layoutFrame

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

  local x = COLLAPSE_WIDTH + STATUS_WIDTH + CELL_PAD
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
  for colID, layout in pairs(columnLayout) do
    local btn = headerButtons[colID]
    if btn then
      btn:ClearAllPoints()
      btn:SetPoint("LEFT", headerFrame, "LEFT", layout.x, 0)
      btn:SetWidth(layout.width)
    end
  end
end

local function createHeaderButtons()
  for colID, def in pairs(COLUMN_DEFS) do
    local btn = CreateFrame("Button", nil, headerFrame)
    btn:SetHeight(HEADER_HEIGHT)
    btn.columnID = colID
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", onHeaderDragStart)
    btn:SetScript("OnDragStop", onHeaderDragStop)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetAllPoints()
    btn.text:SetJustifyH("LEFT")
    btn.text:SetText(def.label)
    headerButtons[colID] = btn
  end
end

--=====================================================================
-- Row widgets
--=====================================================================

-- Cycles this row's combined lock/trash status: None -> Locked -> Trash -> None. Locked and Trash are
-- still stored in their own separate tables (lockedItems by itemID, trashItems by the armor-aware key
-- from trashKey()) -- only the on-screen control is unified into a single click target.
local function cycleStatus(itemID, key)
  if isLockedItem(itemID) then
    settings().lockedItems[itemID] = nil
    settings().trashItems[key] = true
  elseif isTrashItem(key) then
    settings().trashItems[key] = nil
  else
    settings().lockedItems[itemID] = true
  end
  renderRows()
end

local function createRow(index)
  local row = CreateFrame("Button", nil, scrollChild)
  row:SetHeight(ROW_HEIGHT)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp") -- default Button widgets ignore right-click

  row.collapseBtn = CreateFrame("Button", nil, row)
  row.collapseBtn:SetSize(COLLAPSE_WIDTH, ROW_HEIGHT)
  row.collapseBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.collapseBtn.text = row.collapseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.collapseBtn.text:SetAllPoints()
  row.collapseBtn.text:SetJustifyH("CENTER")
  row.collapseBtn:SetScript("OnClick", function()
    local groupKey = row.groupKey
    expandedGroups[groupKey] = not expandedGroups[groupKey]
    renderRows()
  end)

  -- Single icon button cycling None -> Locked -> Trash -> None (instead of two separate checkboxes).
  row.statusBtn = CreateFrame("Button", nil, row)
  row.statusBtn:SetSize(STATUS_WIDTH, STATUS_WIDTH)
  row.statusBtn:SetPoint("LEFT", row, "LEFT", COLLAPSE_WIDTH, 0)
  row.statusBtn.icon = row.statusBtn:CreateTexture(nil, "ARTWORK")
  row.statusBtn.icon:SetAllPoints()
  row.statusBtn:SetScript("OnClick", function() cycleStatus(row.itemID, row.trashKey) end)
  row.statusBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if isLockedItem(row.itemID) then
      GameTooltip:SetText("Locked (click to mark as Trash instead)")
    elseif isTrashItem(row.trashKey) then
      GameTooltip:SetText("Trash - sold automatically at merchants (click to clear)")
    else
      GameTooltip:SetText("Click to lock, click again to mark as Trash")
    end
    GameTooltip:Show()
  end)
  row.statusBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)

  row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.nameText:SetJustifyH("LEFT")

  row.qualitySwatch = row:CreateTexture(nil, "ARTWORK")
  row.qualitySwatch:SetSize(10, 10)

  row.quantityText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.armorTypeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.armorSlotText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.bindIcon = row:CreateTexture(nil, "ARTWORK")
  row.bindIcon:SetSize(10, 10)

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
      C_Container.UseContainerItem(row.primaryEntry.bagID, row.primaryEntry.slot)
    elseif IsModifiedClick("SPLITSTACK") and row.primaryEntry.count and row.primaryEntry.count > 1 then
      row.SplitStack = function(_, split)
        C_Container.SplitContainerItem(row.primaryEntry.bagID, row.primaryEntry.slot, split)
      end
      OpenStackSplitFrame(row.primaryEntry.count, row, "BOTTOMLEFT", "TOPLEFT")
    elseif row.hyperlink and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")) then
      HandleModifiedItemClick(row.hyperlink)
    end
  end)
  row:SetScript("OnEnter", function()
    if row.hyperlink then
      GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(row.hyperlink)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
  row.nameText:SetWidth(math.max(20, nameLayout.width - indent - ROW_HEIGHT))

  for _, colID in ipairs({ "quantity", "ilvl", "armorType", "armorSlot" }) do
    local cell = row[colID .. "Text"]
    cell:ClearAllPoints()
    cell:SetPoint("LEFT", row, "LEFT", columnLayout[colID].x, 0)
    cell:SetWidth(columnLayout[colID].width)
  end

  -- Small centered icon swatches (quality, bind) instead of left-aligned text.
  row.qualitySwatch:SetPoint("LEFT", row, "LEFT", columnLayout.quality.x + (columnLayout.quality.width - 10) / 2, 0)
  row.bindIcon:SetPoint("LEFT", row, "LEFT", columnLayout.bind.x + (columnLayout.bind.width - 10) / 2, 0)
end

--=====================================================================
-- Rendering
--=====================================================================

-- Flattens grouped items into the final display list: one row per group, plus (when expanded) one
-- child row per underlying bag slot so a specific stack can be dragged/split/locked individually.
local function buildDisplayRows()
  local groups = collectGroups()
  local rows = {}
  for _, group in ipairs(groups) do
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
          count = entry.count,
          entries = { entry },
          isArmor = group.isArmor,
          itemLevel = group.itemLevel,
          trackSuffix = group.trackSuffix,
          armorType = group.armorType,
          armorSlot = group.armorSlot,
          bindLabel = group.bindLabel,
          trashKey = group.trashKey,
        }
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

    row.groupKey = data.key or data.groupKey
    row.itemID = data.itemID
    row.hyperlink = data.hyperlink
    row.isChild = data.isChild
    row.trashKey = data.trashKey
    row.primaryEntry = data.entries and data.entries[1]
    row.locked = isLockedItem(data.itemID)

    if data.isGroupHeader then
      row.collapseBtn:Show()
      row.collapseBtn.text:SetText(expandedGroups[data.key] and "-" or "+")
    else
      row.collapseBtn:Hide()
    end

    if isLockedItem(data.itemID) then
      row.statusBtn.icon:SetTexture(LOCK_ICON_TEXTURE)
      row.statusBtn.icon:SetTexCoord(unpack(LOCK_ICON_COORDS))
      row.statusBtn.icon:Show()
    elseif isTrashItem(data.trashKey) then
      row.statusBtn.icon:SetTexture(TRASH_ICON_TEXTURE)
      row.statusBtn.icon:SetTexCoord(0, 1, 0, 1)
      row.statusBtn.icon:Show()
    else
      row.statusBtn.icon:Hide()
    end

    row.icon:SetTexture(data.icon)
    local qualityColor = data.quality and (ITEM_QUALITY_COLORS[data.quality] or ITEM_QUALITY_COLORS[1])
    row.nameText:SetText((data.itemName or "?") .. (data.trackSuffix or ""))
    if qualityColor then
      row.nameText:SetTextColor(qualityColor.color:GetRGB())
      row.qualitySwatch:SetColorTexture(qualityColor.color:GetRGB())
      row.qualitySwatch:Show()
    else
      row.qualitySwatch:Hide()
    end

    row.quantityText:SetText(tostring(data.count or 1))
    row.ilvlText:SetText(data.isArmor and data.itemLevel and tostring(data.itemLevel) or "")
    row.armorTypeText:SetText(data.isArmor and data.armorType or "")
    row.armorSlotText:SetText(data.isArmor and data.armorSlot or "")
    local bindColor = data.bindLabel and BIND_ICON_COLORS[data.bindLabel]
    if bindColor then
      row.bindIcon:SetColorTexture(unpack(bindColor))
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

local currencyWidgets = {}

local function updateFooter()
  footer.moneyText:SetText(GetCoinTextureString(GetMoney()))

  local shown = 0
  local numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
  for i = 1, numCurrencies do
    local info = C_CurrencyInfo.GetCurrencyListInfo(i)
    if info and not info.isHeader and info.isShowInBackpack then
      shown = shown + 1
      local widget = currencyWidgets[shown]
      if not widget then
        widget = CreateFrame("Frame", nil, footer)
        widget.icon = widget:CreateTexture(nil, "ARTWORK")
        widget.icon:SetSize(16, 16)
        widget.icon:SetPoint("LEFT", widget, "LEFT", 0, 0)
        widget.text = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        widget.text:SetPoint("LEFT", widget.icon, "RIGHT", 2, 0)
        currencyWidgets[shown] = widget
      end
      widget.icon:SetTexture(info.iconFileID)
      widget.text:SetText(info.quantity)
      widget:SetSize(16 + 2 + widget.text:GetStringWidth(), 16)
      widget:ClearAllPoints()
      if shown == 1 then
        widget:SetPoint("RIGHT", footer.currencyButton, "LEFT", -10, 0)
      else
        widget:SetPoint("RIGHT", currencyWidgets[shown - 1], "LEFT", -10, 0)
      end
      widget:Show()
    end
  end
  for i = shown + 1, #currencyWidgets do
    currencyWidgets[i]:Hide()
  end
end

local function createFooter()
  footer = CreateFrame("Frame", nil, content)
  footer:SetHeight(20)
  footer:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 8, 6)
  footer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 6)

  footer.moneyText = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  footer.moneyText:SetPoint("LEFT", footer, "LEFT", 0, 0)

  -- A plain text button (rather than a guessed icon atlas) to reliably open Blizzard's own Currency tab.
  footer.currencyButton = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
  footer.currencyButton:SetSize(72, 20)
  footer.currencyButton:SetText("Currency")
  footer.currencyButton:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
  footer.currencyButton:SetScript("OnClick", function() ToggleCharacter("TokenFrame") end)
end

--=====================================================================
-- Toggling the list view vs. the default bag windows
--=====================================================================

-- Best-effort: hides whichever default bag frame(s) Blizzard actually opened. Rather than hardcode a
-- fixed count of "ContainerFrameN" globals (which has changed across expansions -- reagent bag, bank
-- tabs, warbank, etc. all add more), this scans _G for anything matching Blizzard's long-standing
-- ContainerFrame naming convention and hides whichever of those happen to be shown.
local function hideDefaultBags()
  for name, obj in pairs(_G) do
    if type(name) == "string" and type(obj) == "table" and obj.IsShown and obj.Hide
        and (name == "ContainerFrameCombinedBags" or name:match("^ContainerFrame%d+$"))
        and obj:IsShown() then
      obj:Hide()
    end
  end
end

local function showDefaultBags()
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
    frame:Show()
  else
    frame:Hide()
    showDefaultBags()
  end
end

local function onDefaultBagsShown()
  if isModuleEnabled() and settings().listViewActive then
    hideDefaultBags()
    frame:Show()
  end
end

-- Hooked (not overridden) so the default keybinding/bag-bar button still works exactly as before;
-- we just additionally swap in our own window afterward when list view is the player's active choice.
local hookedBagToggleFuncs = {}
local function hookDefaultBagToggles()
  for _, funcName in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag" }) do
    if _G[funcName] and not hookedBagToggleFuncs[funcName] then
      hookedBagToggleFuncs[funcName] = true
      hooksecurefunc(funcName, onDefaultBagsShown)
    end
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

  -- Reuses the exact "book style" default Blizzard panel border/background technique already proven
  -- elsewhere in this addon (see Minimap.lua's square border) instead of guessing at a full XML template.
  frame.layoutType = "ButtonFrameTemplateNoPortrait"

  -- NineSlicePanelTemplate only draws the border art (corners/edges) with nothing behind it, so a
  -- separate opaque backing is needed underneath or the window body would be see-through. This is the
  -- same tiled marble texture Blizzard's own inset text panels (e.g. the Guild/Communities chat pane)
  -- sit on top of, so it's fully opaque and matches native windows instead of a flat color fill.
  -- Insets match Blizzard's own "DefaultPanelTemplate" Bg anchors exactly (confirmed via
  -- wow-ui-source's SharedUIPanelTemplates.xml) for this same "ButtonFrameTemplateNoPortrait" border,
  -- so the fill meets the border art on every side with no gap.
  frame.Background = frame:CreateTexture(nil, "BACKGROUND")
  frame.Background:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", true, true)
  frame.Background:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -20)
  frame.Background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

  frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
  frame.NineSlice:SetAllPoints()

  content = CreateFrame("Frame", nil, frame)
  content:SetAllPoints()
  content:SetFrameLevel(600) -- above the NineSlice border's hardcoded frameLevel of 500

  content.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  content.title:SetPoint("TOP", content, "TOP", 0, -6)
  content.title:SetText("Item List")

  -- The whole top strip is a native move handle (StartMoving/StopMovingOrSizing), matching how every
  -- other Blizzard window is dragged.
  local dragHandle = CreateFrame("Frame", nil, content)
  dragHandle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  dragHandle:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
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

  content.closeButton = CreateFrame("Button", nil, content, "UIPanelCloseButton")
  content.closeButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -2) -- matches Blizzard's own close-button inset for this border
  content.closeButton:SetScript("OnClick", function() frame:Hide() end) -- just closes; doesn't change the view mode

  -- Toggles between this list view and Blizzard's default grid bag windows.
  viewToggleButton = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
  viewToggleButton:SetSize(20, 20)
  viewToggleButton:SetPoint("RIGHT", content.closeButton, "LEFT", -2, 0)
  viewToggleButton:SetScript("OnClick", function(self) setListViewActive(self:GetChecked()) end)
  viewToggleButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Toggle List View")
    GameTooltip:Show()
  end)
  viewToggleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  headerFrame = CreateFrame("Frame", nil, content)
  headerFrame:SetHeight(HEADER_HEIGHT)
  headerFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -26)
  headerFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -26)
  createHeaderButtons()

  scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
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
local function sellMarkedTrashItems()
  for _, bagID in ipairs(bagIDs()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.itemID and not isLockedItem(info.itemID) then
        local itemName, itemLink, _, itemLevel, _, _, _, _, _, _, _, classID = GetItemInfo(info.hyperlink)
        local isArmor = classID == ARMOR_CLASS_ID
        local key = trashKey(info.itemID, itemName, isArmor and (C_Item.GetDetailedItemLevelInfo(info.hyperlink) or itemLevel), isArmor)
        if isTrashItem(key) then
          C_Container.UseContainerItem(bagID, slot)
        end
      end
    end
  end
end

--=====================================================================
-- Lifecycle
--=====================================================================

function module:OnInitialize()
  hookDefaultBagToggles()
  if not isModuleEnabled() then
    self:SetEnabledState(false)
  end
end

function module:OnEnable()
  if not isModuleEnabled() then
    self:SetEnabledState(false)
    return
  end
  buildFrame()
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "Refresh")
  self:RegisterEvent("PLAYER_MONEY", "Refresh")
  self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "Refresh")
  self:RegisterEvent("MERCHANT_SHOW")
  if settings().listViewActive then
    setListViewActive(true)
  end
end

function module:OnDisable()
  -- Only swap back to the default bags if our window was actually open -- doesn't force bags open,
  -- and deliberately leaves the player's list-view preference (settings().listViewActive) untouched
  -- so it's remembered next time the module/feature is re-enabled.
  if frame and frame:IsShown() then
    frame:Hide()
    showDefaultBags()
  end
end

function module:MERCHANT_SHOW()
  sellMarkedTrashItems()
end

-- Shared refresh entry point for every event above; cheap enough to call unconditionally since it
-- no-ops while the window is hidden (see renderRows()'s IsShown guard).
function module:Refresh()
  if not frame then return end
  renderRows()
  if frame:IsShown() then
    updateFooter()
  end
end
