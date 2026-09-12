setfenv(1, _G.SlackHacks)

--[[
  Reminds the player to keep up raid/dungeon consumables (food, flask, oil, augment rune) by showing
  clickable icons, similar in spirit to the "ClickableRaidBuffs" addon -- but event-driven instead of
  polling aura events constantly. Auras/bags are only rescanned on: PLAYER_ENTERING_WORLD (login/zoning
  into an instance), entering/leaving combat, joining/leaving a group, and bag changes (using an item).
]]--

local module = Self:NewModule("Buffs", "AceEvent-3.0")
Self.Buffs = module

local ICON_SIZE = 45 -- Native 30px aura button scaled by 150%.
local AURA_BUTTON_WIDTH = 30
local ICON_GAP = 6
local TOP_OFFSET = 130 -- Rough approximation of "2 inches" from the top of a typical display.
local ANCHOR_GAP = 8

local MYTHIC_DUNGEON_DIFFICULTY_IDS = { [8] = true, [23] = true } -- Mythic Keystone, Mythic (non-keystone)
local RAID_DIFFICULTY_IDS = { [14] = true, [15] = true, [16] = true } -- Normal, Heroic, Mythic raid (excludes LFR = 17)

local MYTHIC_DUNGEON_THRESHOLD_SECONDS = 40 * 60
local RAID_THRESHOLD_SECONDS = 15 * 60
local runeBuffIDSet = {}

-- Buff categories, in display order. `itemNames` key into StaticData's ITEM_NAMES table.
local BUFF_CATEGORIES = {
  {
    dbKey = "wellFed",
    label = "Food",
    icon = 133943,
    itemNames = FOOD_ITEM_NAMES,
    itemIDs = FOOD_ITEM_IDS,
    matchAura = function(auraName) return auraName == "Well Fed" end,
  },
  {
    dbKey = "flask",
    label = "Flask",
    icon = 132380,
    itemNames = FLASK_ITEM_NAMES,
    itemIDs = FLASK_ITEM_IDS,
    matchAura = function(auraName, _, itemNameSet) return itemNameSet[auraName] == true end,
  },
  {
    dbKey = "oil",
    label = "Oil",
    icon = 7548987,
    itemNames = OIL_ITEM_NAMES,
    itemIDs = OIL_ITEM_IDS,
    matchAura = function(_, spellID) return spellID == 1237006 end,
  },
  {
    dbKey = "rune",
    label = "Augment Rune",
    icon = 4549099,
    itemNames = RUNE_ITEM_NAMES,
    itemIDs = RUNE_ITEM_IDS,
    matchAura = function(_, spellID) return runeBuffIDSet[spellID] == true end,
  },
}

for _, category in ipairs(BUFF_CATEGORIES) do
  local itemNameSet = {}
  for _, itemName in ipairs(category.itemNames) do
    itemNameSet[itemName] = true
  end
  category.itemNameSet = itemNameSet
end

for _, spellID in ipairs(RUNE_BUFF_IDS) do
  runeBuffIDSet[spellID] = true
end

local container
local iconButtons = {}
local menuFrame
local menuRows = {}
local menuCloseTimer
local auraEventRegistered = false
local combatHideTimer
local trackedAuras = {}
local cachedAuraExpirations = {}
local auraCacheInitialized = false

local function closeContextMenu()
  if InCombatLockdown() then return end
  if menuCloseTimer then
    menuCloseTimer:Cancel()
    menuCloseTimer = nil
  end
  if menuFrame then
    menuFrame:Hide()
    menuFrame.anchorButton = nil
    menuFrame.category = nil
  end
end

--- Closes the menu shortly after the mouse leaves both the anchor icon and the menu panel.
local function scheduleMenuClose()
  if menuCloseTimer then
    menuCloseTimer:Cancel()
  end
  menuCloseTimer = C_Timer.NewTimer(0.25, function()
    menuCloseTimer = nil
    if not menuFrame then return end
    if menuFrame:IsMouseOver() then return end
    local anchor = menuFrame.anchorButton
    if anchor and anchor:IsMouseOver() then return end
    closeContextMenu()
  end)
end

local function cancelMenuClose()
  if menuCloseTimer then
    menuCloseTimer:Cancel()
    menuCloseTimer = nil
  end
end

local QUALITY_ATLAS_BY_ITEM_ID = {
  [241320] = "Professions-Icon-Quality-12-Tier2-Inv",
  [241321] = "Professions-Icon-Quality-12-Tier1-Inv",
  [241322] = "Professions-Icon-Quality-12-Tier2-Inv",
  [241323] = "Professions-Icon-Quality-12-Tier1-Inv",
  [241324] = "Professions-Icon-Quality-12-Tier2-Inv",
  [241325] = "Professions-Icon-Quality-12-Tier1-Inv",
  [241326] = "Professions-Icon-Quality-12-Tier2-Inv",
  [241327] = "Professions-Icon-Quality-12-Tier1-Inv",
  [243733] = "Professions-Icon-Quality-12-Tier1-Inv",
  [243734] = "Professions-Icon-Quality-12-Tier2-Inv",
}

local function setNativeOverlayGlow(button, enabled)
  if ActionButtonSpellAlertManager then
    if enabled then
      ActionButtonSpellAlertManager:ShowAlert(button)
    else
      ActionButtonSpellAlertManager:HideAlert(button)
    end
  elseif enabled and ActionButton_ShowOverlayGlow then
    ActionButton_ShowOverlayGlow(button)
  elseif not enabled and ActionButton_HideOverlayGlow then
    ActionButton_HideOverlayGlow(button)
  end
end

local function categoryItemIDs(category)
  local ids, seen = {}, {}
  for _, itemName in ipairs(category.itemNames) do
    local itemID = ITEM_NAMES and ITEM_NAMES[itemName]
    if itemID and not seen[itemID] then
      seen[itemID] = true
      table.insert(ids, itemID)
    end
  end
  for _, itemID in ipairs(category.itemIDs or {}) do
    if not seen[itemID] then
      seen[itemID] = true
      table.insert(ids, itemID)
    end
  end
  return ids
end

local function categoryIcon(category)
  return category.icon or SLACKHACKS_ICON
end

local function forEachPlayerBuff(callback)
  for i = 1, 40 do
    local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not aura then break end
    callback(aura)
  end
end

local function recalculateAuraExpirations()
  wipe(cachedAuraExpirations)
  for _, aura in pairs(trackedAuras) do
    local current = cachedAuraExpirations[aura.categoryKey]
    if aura.expiration == 0 then
      cachedAuraExpirations[aura.categoryKey] = 0
    elseif current ~= 0 and (not current or aura.expiration > current) then
      cachedAuraExpirations[aura.categoryKey] = aura.expiration
    end
  end
end

local function trackAura(aura)
  local auraInstanceID = aura and aura.auraInstanceID
  if not auraInstanceID then return end

  local previous = trackedAuras[auraInstanceID]
  trackedAuras[auraInstanceID] = nil
  for _, category in ipairs(BUFF_CATEGORIES) do
    if category.dbKey ~= "oil" and category.matchAura(aura.name, aura.spellId, category.itemNameSet) then
      trackedAuras[auraInstanceID] = {
        categoryKey = category.dbKey,
        expiration = aura.expirationTime or 0,
      }
      local current = trackedAuras[auraInstanceID]
      return not previous
        or previous.categoryKey ~= current.categoryKey
        or previous.expiration ~= current.expiration
    end
  end
  return previous ~= nil
end

local function rebuildAuraCache()
  wipe(trackedAuras)
  forEachPlayerBuff(trackAura)
  recalculateAuraExpirations()
  auraCacheInitialized = true
end

local function updateAuraCache(updateInfo)
  if not auraCacheInitialized or not updateInfo or updateInfo.isFullUpdate then
    rebuildAuraCache()
    return true
  end

  local changed = false
  for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs or {}) do
    if trackedAuras[auraInstanceID] then
      trackedAuras[auraInstanceID] = nil
      changed = true
    end
  end
  for _, aura in ipairs(updateInfo.addedAuras or {}) do
    changed = trackAura(aura) or changed
  end
  for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
    changed = trackAura(C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID)) or changed
  end
  if changed then recalculateAuraExpirations() end
  return changed
end

local function oilBuffExpiration()
  if not GetWeaponEnchantInfo then return nil end
  local hasMainHandEnchant, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
  if hasMainHandEnchant or hasOffHandEnchant then return 0 end
  return nil
end

--- Returns the latest expiration time (seconds, epoch-relative via GetTime()) for a matching buff on the
--- player, `0` if a matching permanent buff is found, or `nil` if the buff isn't active at all.
local function categoryBuffExpiration(category)
  if category.dbKey == "oil" then
    return oilBuffExpiration()
  end
  return cachedAuraExpirations[category.dbKey]
end

--- Which items in the player's bags can currently fulfill this category, with their bag/slot/count.
local function categoryBagItems(category)
  local items = {}
  for _, itemID in ipairs(categoryItemIDs(category)) do
    local count = bagItemCount(itemID)
    if count > 0 then
      local bag, slot = findBagItem(itemID)
      local itemName = C_Item.GetItemNameByID(itemID) or ITEM_NAMES_BY_ID and ITEM_NAMES_BY_ID[itemID] or tostring(itemID)
      local qualityInfo = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo and C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
      local qualityAtlas = qualityInfo and qualityInfo.iconChat or QUALITY_ATLAS_BY_ITEM_ID[itemID]
      table.insert(items, {
        itemID = itemID,
        itemName = itemName,
        count = count,
        bag = bag,
        slot = slot,
        icon = C_Item.GetItemIconByID(itemID),
        qualityAtlas = qualityAtlas,
        qualityMarkup = qualityAtlas and CreateAtlasMarkup(qualityAtlas, 24, 24, 0, 0) or "",
      })
    end
  end
  return items
end

local function currentContentContext()
  local inInstance, instanceType = IsInInstance()
  if not inInstance then return nil end
  local _, _, difficultyID = GetInstanceInfo()
  if instanceType == "party" and MYTHIC_DUNGEON_DIFFICULTY_IDS[difficultyID] then
    return "mythicDungeon"
  elseif instanceType == "raid" and RAID_DIFFICULTY_IDS[difficultyID] then
    return "raid"
  end
  return nil
end

local function shouldTrackAuras()
  local debugging = isDebugging()
  return (debugging or currentContentContext()) and (debugging or IsInGroup() or IsInRaid())
end

local function contextIsEnabled(context)
  if context == "mythicDungeon" then return db.profile.buffs.contentTypes.mythicDungeons end
  if context == "raid" then return db.profile.buffs.contentTypes.nonLfrRaids end
  return false
end

local function thresholdSecondsForContext(context)
  if context == "mythicDungeon" then return MYTHIC_DUNGEON_THRESHOLD_SECONDS end
  if context == "raid" then return RAID_THRESHOLD_SECONDS end
end

--- Whether a category should currently be shown: always if the buff is entirely missing, otherwise
--- only once its remaining duration drops to/under the content's threshold.
local function categoryShouldShow(category, context)
  if not db.profile.buffs.categories[category.dbKey] then return false end
  local expiration = categoryBuffExpiration(category)
  if not expiration then return true end -- buff missing entirely
  if expiration == 0 then return false end -- permanent buff present, nothing to remind about
  local threshold = thresholdSecondsForContext(context)
  if not threshold then return false end
  return (expiration - GetTime()) <= threshold
end

local function activeCategories()
  if InCombatLockdown() then return {} end
  local debugging = isDebugging()
  local context = currentContentContext()
  if not debugging and (not context or not contextIsEnabled(context)) then return {} end
  if not debugging and not (IsInGroup() or IsInRaid()) then return {} end

  local active = {}
  for _, category in ipairs(BUFF_CATEGORIES) do
    if categoryShouldShow(category, context) then table.insert(active, category) end
  end
  return active
end

local function updateAuraEventRegistration()
  local shouldRegister = not InCombatLockdown() and shouldTrackAuras()
  if shouldRegister and not auraEventRegistered then
    rebuildAuraCache()
    module:RegisterEvent("UNIT_AURA")
    auraEventRegistered = true
    log("Buffs: registered UNIT_AURA")
  elseif not shouldRegister and auraEventRegistered then
    module:UnregisterEvent("UNIT_AURA")
    auraEventRegistered = false
    auraCacheInitialized = false
    log("Buffs: deregistered UNIT_AURA")
  end
end

function module:UNIT_AURA(_, unit, updateInfo)
  if unit ~= "player" or InCombatLockdown() then return end
  if updateAuraCache(updateInfo) then self:Refresh() end
end

local function hideBuffs()
  if not container then return end
  closeContextMenu()
  container:Hide()
  for _, button in pairs(iconButtons) do
    button:Hide()
  end
end

local function createContainer()
  if container then return end
  container = CreateFrame("Frame", "SlackHacksBuffReminders", UIParent)
  container:SetSize(ICON_SIZE, ICON_SIZE)
  container:Hide()
end

local function setButtonAction(button, category, item, onlyLeftClick)
  if not button or InCombatLockdown() then return end

  button:SetAttribute("type", nil)
  button:SetAttribute("item", nil)
  button:SetAttribute("macrotext", nil)
  button:SetAttribute("unit", nil)
  button:SetAttribute("type1", nil)
  button:SetAttribute("item1", nil)
  button:SetAttribute("macrotext1", nil)
  button:SetAttribute("unit1", nil)

  if not item or not category then return end

  local typeAttr = onlyLeftClick and "type1" or "type"
  local itemAttr = onlyLeftClick and "item1" or "item"
  local macroAttr = onlyLeftClick and "macrotext1" or "macrotext"
  local unitAttr = onlyLeftClick and "unit1" or "unit"

  if category.dbKey == "oil" then
    button:SetAttribute(typeAttr, "macro")
    button:SetAttribute(macroAttr, "/use item:" .. item.itemID .. "\n/use 16")
  else
    button:SetAttribute(typeAttr, "item")
    button:SetAttribute(itemAttr, "item:" .. item.itemID)
    button:SetAttribute(unitAttr, "player")
  end
end

local function createMenuRow(index)
  local row = CreateFrame("Button", "SlackHacksBuffMenuRow" .. index, menuFrame, "BackdropTemplate, SecureActionButtonTemplate")
  row:SetHeight(24)
  row:RegisterForClicks("AnyUp", "AnyDown") -- secure item/macro click only fires reliably with both registered

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
  highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 1)
  highlight:SetVertexColor(1, 1, 1, 0.35)
  highlight:SetBlendMode("ADD")
  row.highlight = highlight

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", row, "LEFT", 4, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.icon = icon

  local count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  count:SetJustifyH("RIGHT")
  row.count = count

  local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  name:SetPoint("RIGHT", count, "LEFT", -26, 0) -- leaves room for the quality icon after the name
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  row.name = name

  local quality = row:CreateTexture(nil, "OVERLAY")
  quality:SetSize(16, 16)
  row.quality = quality

  row:SetScript("OnEnter", function(self)
    cancelMenuClose()
    if self.itemID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(self.itemID)
      GameTooltip:Show()
    end
  end)

  row:SetScript("OnLeave", function(self)
    GameTooltip_Hide()
    scheduleMenuClose()
  end)

  row:SetScript("PostClick", function()
    closeContextMenu()
    C_Timer.After(0.2, function() module:Refresh() end)
  end)

  return row
end

local function getMenuRow(index)
  menuRows[index] = menuRows[index] or createMenuRow(index)
  return menuRows[index]
end

local function createContextMenu()
  if menuFrame then return end

  menuFrame = CreateFrame("Frame", "SlackHacksBuffContextMenu", UIParent, "BackdropTemplate")
  menuFrame:SetFrameStrata("DIALOG")
  menuFrame:SetClampedToScreen(true)
  menuFrame:EnableMouse(true)
  menuFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  menuFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  menuFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
  menuFrame:SetScript("OnEnter", cancelMenuClose)
  menuFrame:SetScript("OnLeave", scheduleMenuClose)
  menuFrame:Hide()
end

local function openContextMenu(anchorButton, category, items)
  if InCombatLockdown() then return end
  createContextMenu()

  if menuFrame:IsShown() and menuFrame.anchorButton == anchorButton then
    closeContextMenu()
    return
  end

  if not items or #items == 0 then
    closeContextMenu()
    return
  end

  menuFrame.anchorButton = anchorButton
  menuFrame.category = category

  local rowHeight = 24
  local rowGap = 2
  local padding = 6
  local menuWidth = 240

  for index, item in ipairs(items) do
    local row = getMenuRow(index)
    row.itemID = item.itemID
    row:SetWidth(menuWidth - (padding * 2))
    row:SetHeight(rowHeight)
    row.icon:SetTexture(item.icon or SLACKHACKS_ICON)
    row.name:SetText(item.itemName or "")
    row.count:SetText("(" .. (item.count or 0) .. ")")

    row.quality:ClearAllPoints()
    if item.qualityAtlas then
      row.quality:SetAtlas(item.qualityAtlas)
      row.quality:SetPoint("LEFT", row.name, "LEFT", (row.name:GetStringWidth() or 0) + 4, 0)
      row.quality:Show()
    else
      row.quality:Hide()
    end

    setButtonAction(row, category, item, false)
    row:ClearAllPoints()
    local offsetY = -padding - ((index - 1) * (rowHeight + rowGap))
    row:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", padding, offsetY)
    row:Show()
  end

  for index = #items + 1, #menuRows do
    local row = menuRows[index]
    row:Hide()
    setButtonAction(row, nil, nil, false)
  end

  local totalHeight = (padding * 2) + (#items * rowHeight) + ((#items - 1) * rowGap)
  menuFrame:SetSize(menuWidth, totalHeight)

  menuFrame:ClearAllPoints()
  local top = anchorButton:GetTop() or 0
  if top > (GetScreenHeight() / 2) then
    menuFrame:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -4)
  else
    menuFrame:SetPoint("BOTTOMLEFT", anchorButton, "TOPLEFT", 0, 4)
  end

  menuFrame:Show()
end

local function createIconButton(index)
  local button = CreateFrame("Button", "SlackHacksBuffReminder" .. index, container, "AuraButtonTemplate, SecureActionButtonTemplate")
  button:SetSize(AURA_BUTTON_WIDTH, AURA_BUTTON_WIDTH)
  button:SetScale(1.5)
  button:RegisterForClicks("AnyUp")

  local icon = button.Icon
  button.icon = icon
  button.TempEnchantBorder:Hide()

  button:SetScript("OnHide", function(self)
    setNativeOverlayGlow(self, false)
  end)

  button:SetScript("OnEnter", function(self)
    cancelMenuClose()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.category.label)
    if self.hasMultipleItems then
      GameTooltip:AddLine("Click to select a " .. self.category.label .. " item to use.", 1, 1, 1)
    elseif self.activeItem then
      GameTooltip:AddLine("Click to use " .. self.activeItem.itemName .. " (" .. self.activeItem.count .. ").", 1, 1, 1)
    elseif self.hasItems then
      GameTooltip:AddLine("Click to use an item.", 1, 1, 1)
    else
      GameTooltip:AddLine("No " .. self.category.label .. " items in inventory.", 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function(self)
    GameTooltip_Hide()
    if menuFrame and menuFrame:IsShown() and menuFrame.anchorButton == self then
      scheduleMenuClose()
    end
  end)

  button:SetScript("PreClick", function(self, mouseButton)
    if InCombatLockdown() then return end
    local items = categoryBagItems(self.category)
    if #items == 0 then
      if mouseButton == "LeftButton" or mouseButton == "RightButton" then
        print("SlackHacks: No " .. self.category.label .. " items in inventory.")
      end
      return
    end

    if #items > 1 or mouseButton == "RightButton" or self.category.dbKey == "oil" then
      openContextMenu(self, self.category, items)
    end
  end)

  button:SetScript("PostClick", function(self, mouseButton)
    if mouseButton == "LeftButton" and self.category.dbKey ~= "oil" and (not self.hasMultipleItems) and self.hasItems then
      C_Timer.After(0.2, function() module:Refresh() end)
    end
  end)

  return button
end

local function iconButton(index)
  iconButtons[index] = iconButtons[index] or createIconButton(index)
  return iconButtons[index]
end

local function updatePosition()
  container:ClearAllPoints()
  local position = db.profile.buffs.position
  if position == "aboveBuffs" and _G.BuffFrame then
    container:SetPoint("BOTTOM", _G.BuffFrame, "TOP", 0, ANCHOR_GAP)
  elseif position == "belowBuffs" and _G.BuffFrame then
    container:SetPoint("TOP", _G.BuffFrame, "BOTTOM", 0, -ANCHOR_GAP)
  elseif position == "abovePlayerFrame" and _G.PlayerFrame then
    container:SetPoint("BOTTOM", _G.PlayerFrame, "TOP", 0, ANCHOR_GAP)
  elseif position == "belowPlayerFrame" and _G.PlayerFrame then
    container:SetPoint("TOP", _G.PlayerFrame, "BOTTOM", 0, -ANCHOR_GAP)
  else
    container:SetPoint("TOP", UIParent, "TOP", 0, -TOP_OFFSET)
  end
end

local function layoutIcons(active, allowCombatDisplay)
  if InCombatLockdown() and not allowCombatDisplay then return end

  local count = #active
  if count == 0 then
    closeContextMenu()
    container:Hide()
    for _, button in pairs(iconButtons) do
      button:Hide()
      setButtonAction(button, nil, nil, false)
    end
    return
  end

  local totalWidth = (count * ICON_SIZE) + ((count - 1) * ICON_GAP)
  container:SetWidth(totalWidth)
  updatePosition()

  for index, category in ipairs(active) do
    local button = iconButton(index)
    button.category = category
    button.icon:SetTexture(categoryIcon(category))
    button:Show()

    local bagItems = categoryBagItems(category)
    local countItems = #bagItems
    button.hasItems = countItems > 0
    button.hasMultipleItems = countItems > 1
    button.activeItem = bagItems[1]

    if countItems == 1 and category.dbKey ~= "oil" and not InCombatLockdown() then
      setButtonAction(button, category, bagItems[1], true)
    elseif not InCombatLockdown() then
      setButtonAction(button, nil, nil, false)
    end

    setNativeOverlayGlow(button, button.hasItems)

    button:ClearAllPoints()
    local offsetX = (index - 1) * (ICON_SIZE + ICON_GAP)
    button:SetPoint("LEFT", container, "LEFT", offsetX, 0)
  end

  for index, button in pairs(iconButtons) do
    if index > count then
      button:Hide()
      setButtonAction(button, nil, nil, false)
    end
  end

  container:Show()
end

function module:Refresh()
  updateAuraEventRegistration()
  if InCombatLockdown() then return end
  createContainer()
  layoutIcons(activeCategories())
end

function module:PLAYER_ALIVE()
  if not InCombatLockdown() or not shouldTrackAuras() then return end
  rebuildAuraCache()
  local runeCategory = BUFF_CATEGORIES[4]
  if not db.profile.buffs.categories[runeCategory.dbKey] then return end
  if categoryBuffExpiration(runeCategory) then return end
  layoutIcons({ runeCategory }, true)
end

function module:OnInitialize()
  createContainer()
  for index in ipairs(BUFF_CATEGORIES) do
    iconButton(index)
  end
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "Refresh")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_ALIVE")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:Refresh()
end

function module:PLAYER_REGEN_DISABLED()
  updateAuraEventRegistration()
  hideBuffs()
  if combatHideTimer then combatHideTimer:Cancel() end
  combatHideTimer = C_Timer.NewTimer(30, function()
    combatHideTimer = nil
    if InCombatLockdown() then hideBuffs() end
  end)
end

function module:PLAYER_REGEN_ENABLED()
  if combatHideTimer then combatHideTimer:Cancel() end
  combatHideTimer = nil
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  auraEventRegistered = false
  if combatHideTimer then combatHideTimer:Cancel() end
  combatHideTimer = nil
  closeContextMenu()
  if container then container:Hide() end
end
