setfenv(1, _G.SlackHacks)

--[[
  Reminds the player to keep up raid/dungeon consumables (food, flask, oil, augment rune) by showing
  clickable icons, similar in spirit to the "ClickableRaidBuffs" addon -- but event-driven instead of
  polling aura events constantly. Auras/bags are only rescanned on: PLAYER_ENTERING_WORLD (login/zoning
  into an instance), entering/leaving combat, joining/leaving a group, and bag changes (using an item).
]]--

local module = Self:NewModule("Buffs", "AceEvent-3.0")
Self.Buffs = module

local AURA_BUTTON_WIDTH = 30

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
local selection
local editModeDialog
local isEditing = false
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
  local hasMainHandEnchant, mainHandExpiration, _, _, hasOffHandEnchant, offHandExpiration = GetWeaponEnchantInfo()
  local expiration
  if hasMainHandEnchant and mainHandExpiration then
    expiration = GetTime() + (mainHandExpiration / 1000)
  end
  if hasOffHandEnchant and offHandExpiration then
    local offHandEnd = GetTime() + (offHandExpiration / 1000)
    expiration = not expiration and offHandEnd or math.max(expiration, offHandEnd)
  end
  if expiration then return expiration end
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
  if not db.profile.buffs.enabled then return false end
  local debugging = isDebugging()
  return (debugging or currentContentContext()) and (debugging or IsInGroup() or IsInRaid())
end

local function contextIsEnabled(context)
  if context == "mythicDungeon" then return db.profile.buffs.contentTypes.mythicDungeons end
  if context == "raid" then return db.profile.buffs.contentTypes.nonLfrRaids end
  return false
end

local function thresholdSecondsForContext(context)
  if context == "mythicDungeon" then
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
      local mapChallengeModeID = C_ChallengeMode.GetActiveChallengeMapID()
      if mapChallengeModeID then
        local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
        if timeLimit then return timeLimit end
      end
    end
    return MYTHIC_DUNGEON_THRESHOLD_SECONDS
  end
  if context == "raid" then return RAID_THRESHOLD_SECONDS end
end

--- Whether a category should currently be shown: always if the buff is entirely missing, otherwise
--- only once its remaining duration drops to/under the content's threshold.
local function categoryShouldShow(category, context)
  if not db.profile.buffs.categories[category.dbKey] then return false end
  local expiration = categoryBuffExpiration(category)
  if not expiration then return true end -- buff missing entirely
  if expiration == 0 then return false end -- permanent buff present, nothing to remind about
  if not db.profile.buffs.showIfExpiring then return false end
  local threshold = thresholdSecondsForContext(context)
  if not threshold then return false end
  return (expiration - GetTime()) <= threshold
end

local function activeCategories()
  if InCombatLockdown() then return {} end
  if not db.profile.buffs.enabled then return {} end
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

local function updateDuration(button)
  if GetCVarBool and not GetCVarBool("buffDurations") then
    button.duration:Hide()
    return
  end

  local expiration = button.expirationTime
  if not expiration or expiration <= 0 then
    button.duration:Hide()
    return
  end

  local timeLeft = math.max(expiration - GetTime(), 0)
  if timeLeft <= 0 then
    button.duration:Hide()
    return
  end

  button.duration:SetFormattedText(SecondsToTimeAbbrev(timeLeft))
  if timeLeft < (BUFF_DURATION_WARNING_TIME or 90) then
    button.duration:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
  else
    button.duration:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
  end
  button.duration:Show()
end

local function updatePosition()
  if not container then return end
  container:ClearAllPoints()
  local buffsDb = db.profile.buffs
  local point = buffsDb.point or "TOP"
  local relativePoint = buffsDb.relativePoint or point
  local x = buffsDb.x or 0
  local y = buffsDb.y or -130
  container:SetPoint(point, UIParent, relativePoint, x, y)
end

local function createContainer()
  if container then return end
  container = CreateFrame("Frame", "SlackHacksBuffReminders", UIParent)
  container:SetMovable(true)
  container:SetClampedToScreen(true)
  container:SetDontSavePosition(true)
  local scale = (db.profile.buffs.iconSize or 100) / 100
  container:SetScale(scale)
  container:SetSize(AURA_BUTTON_WIDTH, AURA_BUTTON_WIDTH)
  updatePosition()
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
  local background = menuFrame:CreateTexture(nil, "BACKGROUND")
  background:SetAtlas("common-dropdown-c-bg")
  background:SetPoint("TOPLEFT", -17, 12)
  background:SetPoint("BOTTOMRIGHT", 17, -22)
  menuFrame.background = background
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
  button:RegisterForClicks("AnyUp")

  local icon = button.Icon
  button.icon = icon
  button.TempEnchantBorder:Hide()

  local duration = button:CreateFontString(nil, "OVERLAY", DEFAULT_AURA_DURATION_FONT or "GameFontNormalSmall")
  duration:SetPoint("BOTTOM", button, "TOP", 0, 2)
  duration:SetJustifyH("CENTER")
  duration:Hide()
  button.duration = duration
  button.durationElapsed = 0
  button:SetScript("OnUpdate", function(self, elapsed)
    self.durationElapsed = self.durationElapsed + elapsed
    if self.durationElapsed < 1 then return end
    self.durationElapsed = self.durationElapsed - math.floor(self.durationElapsed)
    updateDuration(self)
  end)

  button:SetScript("OnHide", function(self)
    setNativeOverlayGlow(self, false)
    self.duration:Hide()
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

local function layoutIcons(active, allowCombatDisplay)
  if InCombatLockdown() and not allowCombatDisplay then return end

  local count = #active
  if count == 0 and not isEditing then
    closeContextMenu()
    container:Hide()
    for _, button in pairs(iconButtons) do
      button:Hide()
      setButtonAction(button, nil, nil, false)
    end
    return
  end

  local scale = (db.profile.buffs.iconSize or 100) / 100
  container:SetScale(scale)
  local totalWidth = (count * AURA_BUTTON_WIDTH) + ((count - 1) * db.profile.buffs.iconGap)
  container:SetSize(math.max(totalWidth, AURA_BUTTON_WIDTH), AURA_BUTTON_WIDTH)
  updatePosition()

  for index, category in ipairs(active) do
    local button = iconButton(index)
    button.category = category
    button.expirationTime = categoryBuffExpiration(category)
    button.durationElapsed = 1
    if not isEditing then
      updateDuration(button)
    else
      button.duration:Hide()
    end
    button.icon:SetTexture(categoryIcon(category))
    button:Show()

    local bagItems = categoryBagItems(category)
    local countItems = #bagItems
    button.hasItems = countItems > 0
    button.hasMultipleItems = countItems > 1
    button.activeItem = bagItems[1]

    if not isEditing and countItems == 1 and category.dbKey ~= "oil" and not InCombatLockdown() then
      setButtonAction(button, category, bagItems[1], true)
    elseif not InCombatLockdown() then
      setButtonAction(button, nil, nil, false)
    end

    setNativeOverlayGlow(button, (not isEditing) and db.profile.buffs.showGlow and button.hasItems)

    button:ClearAllPoints()
    local offsetX = (index - 1) * (AURA_BUTTON_WIDTH + db.profile.buffs.iconGap)
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

local function onDragStart()
  if InCombatLockdown() then return end
  if container then
    container:StartMoving()
  end
end

local function onDragStop()
  if InCombatLockdown() then return end
  if not container then return end
  container:StopMovingOrSizing()

  local point, relativeTo, relativePoint, x, y = container:GetPoint(1)
  if point then
    db.profile.buffs.point = point
    db.profile.buffs.relativePoint = relativePoint or point
    db.profile.buffs.x = math.floor(x + 0.5)
    db.profile.buffs.y = math.floor(y + 0.5)
  end
  updatePosition()
end

local function createEditModeDialog()
  if editModeDialog then return editModeDialog end

  local dialog = CreateFrame("Frame", "SlackHacksBuffsEditModeDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(340, 470)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
  dialog:SetMovable(true)
  dialog:SetClampedToScreen(true)
  dialog:SetDontSavePosition(true)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetFrameLevel(200)
  dialog:EnableMouse(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:Hide()

  local border = CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate")

  local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  title:SetPoint("TOP", dialog, "TOP", 0, -16)
  title:SetText("Buff Reminders")
  dialog.Title = title

  local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -2, -2)
  closeButton:SetScript("OnClick", function()
    dialog:Hide()
    if selection and selection.ShowHighlighted then
      selection:ShowHighlighted()
    end
  end)

  local controls = {}

  local function addDivider(yOffset)
    local divider = dialog:CreateTexture(nil, "ARTWORK")
    divider:SetSize(300, 8)
    divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
    divider:SetPoint("TOP", dialog, "TOP", 0, yOffset)
    return yOffset - 12
  end

  local function addHeader(text, yOffset)
    local header = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, yOffset)
    header:SetText(text)
    return yOffset - 22
  end

  local function addCheckbox(label, getFunc, setFunc, yOffset, tooltip)
    local cb = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, yOffset)
    cb.text:SetText(label)
    cb.text:SetFontObject("GameFontHighlight")
    cb:SetScript("OnClick", function(self)
      local isChecked = self:GetChecked()
      setFunc(isChecked)
      if isEditing then
        layoutIcons(BUFF_CATEGORIES, true)
      else
        module:Refresh()
      end
    end)
    if tooltip then
      cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
      end)
      cb:SetScript("OnLeave", function()
        GameTooltip_Hide()
      end)
    end
    table.insert(controls, function() cb:SetChecked(getFunc()) end)
    return yOffset - 24
  end

  local function addSlider(label, minVal, maxVal, step, getFunc, setFunc, yOffset, formatFunc)
    local frame = CreateFrame("Frame", nil, dialog)
    frame:SetSize(300, 36)
    frame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, yOffset)

    local lbl = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    lbl:SetText(label)

    local valText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    valText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)

    local slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
    slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -4)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    local function updateValue(val)
      if formatFunc then
        valText:SetText(formatFunc(val))
      else
        valText:SetText(tostring(math.floor(val + 0.5)))
      end
    end

    slider:SetScript("OnValueChanged", function(self, val)
      updateValue(val)
      setFunc(val)
      if isEditing then
        layoutIcons(BUFF_CATEGORIES, true)
      else
        module:Refresh()
      end
    end)

    table.insert(controls, function()
      local cur = getFunc() or minVal
      slider:SetValue(cur)
      updateValue(cur)
    end)

    return yOffset - 44
  end

  local curY = -46
  curY = addCheckbox("Enable Consumables Reminders",
    function() return db.profile.buffs.enabled end,
    function(v) db.profile.buffs.enabled = v end,
    curY, "Enable or disable all consumable buff reminder icons.")
  curY = addCheckbox("Show Item Proc Glow",
    function() return db.profile.buffs.showGlow end,
    function(v) db.profile.buffs.showGlow = v end,
    curY, "Show the golden animated alert glow around items ready to use.")
  curY = addCheckbox("Show Expiring Before Boss / Timer",
    function() return db.profile.buffs.showIfExpiring end,
    function(v) db.profile.buffs.showIfExpiring = v end,
    curY, "Show reminders when a timed buff will expire before the instance/encounter ends.")

  curY = addDivider(curY - 2)
  curY = addHeader("Where to Remind", curY)
  curY = addCheckbox("In Mythic Dungeons",
    function() return db.profile.buffs.contentTypes.mythicDungeons end,
    function(v) db.profile.buffs.contentTypes.mythicDungeons = v end,
    curY)
  curY = addCheckbox("In (Non-LFR) Raids",
    function() return db.profile.buffs.contentTypes.nonLfrRaids end,
    function(v) db.profile.buffs.contentTypes.nonLfrRaids = v end,
    curY)

  curY = addDivider(curY - 2)
  curY = addHeader("Buffs to Track", curY)
  curY = addCheckbox("Food Buff",
    function() return db.profile.buffs.categories.wellFed end,
    function(v) db.profile.buffs.categories.wellFed = v end,
    curY)
  curY = addCheckbox("Flask Buff",
    function() return db.profile.buffs.categories.flask end,
    function(v) db.profile.buffs.categories.flask = v end,
    curY)
  curY = addCheckbox("Oil Buff",
    function() return db.profile.buffs.categories.oil end,
    function(v) db.profile.buffs.categories.oil = v end,
    curY)
  curY = addCheckbox("Augment Rune Buff",
    function() return db.profile.buffs.categories.rune end,
    function(v) db.profile.buffs.categories.rune = v end,
    curY)

  curY = addDivider(curY - 2)
  curY = addSlider("Icon Size", 50, 300, 5,
    function() return db.profile.buffs.iconSize end,
    function(v) db.profile.buffs.iconSize = v end,
    curY, function(v) return math.floor(v + 0.5) .. "%" end)
  curY = addSlider("Icon Gap", 0, 100, 1,
    function() return db.profile.buffs.iconGap end,
    function(v) db.profile.buffs.iconGap = v end,
    curY, function(v) return math.floor(v + 0.5) .. "px" end)

  dialog:SetHeight(math.abs(curY) + 24)

  function dialog:RefreshValues()
    for _, fn in ipairs(controls) do
      fn()
    end
  end

  editModeDialog = dialog
  return dialog
end

local function showEditModeDialog(show)
  local dlg = createEditModeDialog()
  if show then
    dlg:RefreshValues()
    dlg:Show()
  else
    dlg:Hide()
  end
end

local function createSelection()
  if selection then return selection end
  if not container then createContainer() end

  local success, sel = pcall(CreateFrame, "Frame", "SlackHacksBuffsEditModeSelection", container, "EditModeSystemSelectionTemplate")
  if success and sel then
    selection = sel
    selection:SetAllPoints(container)
    selection:SetFrameStrata(container:GetFrameStrata())
    selection:SetFrameLevel(container:GetFrameLevel() + 20)
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    selection:SetScript("OnDragStart", onDragStart)
    selection:SetScript("OnDragStop", onDragStop)
    selection.system = {
      GetSystemName = function()
        return "Buff Reminders"
      end
    }
    if selection.SetSelectionText then
      selection:SetSelectionText("Buff Reminders")
    elseif selection.Label then
      selection.Label:SetText("Buff Reminders")
    end
    selection:SetScript("OnMouseDown", function(self)
      if InCombatLockdown() then return end
      if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
        EditModeManagerFrame:ClearSelectedSystem()
      end
      if self.ShowSelected then
        self:ShowSelected(true)
      end
      showEditModeDialog(true)
    end)
  else
    local f = CreateFrame("Frame", "SlackHacksBuffsEditModeSelection", container, "BackdropTemplate")
    f:SetAllPoints(container)
    f:SetFrameStrata(container:GetFrameStrata())
    f:SetFrameLevel(container:GetFrameLevel() + 20)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    f:SetBackdropBorderColor(0.2, 0.6, 1.0, 0.8)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", f, "CENTER", 0, 0)
    label:SetText("Buff Reminders")
    f.Label = label
    f.ShowHighlighted = function(self)
      self:SetBackdropBorderColor(0.2, 0.6, 1.0, 0.8)
      self:Show()
    end
    f.ShowSelected = function(self)
      self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
      self:Show()
    end
    f:SetScript("OnDragStart", onDragStart)
    f:SetScript("OnDragStop", onDragStop)
    f:SetScript("OnMouseDown", function(self)
      self:ShowSelected()
      showEditModeDialog(true)
    end)
    selection = f
  end

  return selection
end

local function enterEditMode()
  if isEditing or InCombatLockdown() then return end
  isEditing = true
  createContainer()
  layoutIcons(BUFF_CATEGORIES, true)
  local sel = createSelection()
  if sel then
    sel:Show()
    if sel.ShowHighlighted then
      sel:ShowHighlighted()
    end
  end
end

local function exitEditMode()
  if not isEditing then return end
  isEditing = false
  showEditModeDialog(false)
  if selection then
    selection:Hide()
  end
  module:Refresh()
end

function module:Refresh()
  if isEditing then
    createContainer()
    layoutIcons(BUFF_CATEGORIES, true)
    return
  end
  updateAuraEventRegistration()
  if InCombatLockdown() then return end
  createContainer()
  layoutIcons(activeCategories())
end

function module:OnDatabaseReset()
  wipe(trackedAuras)
  wipe(cachedAuraExpirations)
  auraCacheInitialized = false
  if combatHideTimer then combatHideTimer:Cancel() end
  combatHideTimer = nil
  isEditing = false
  hideBuffs()
  self:Refresh()
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
  db:RegisterCallback("OnDatabaseReset", module.OnDatabaseReset, module)

  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", enterEditMode, module)
    EventRegistry:RegisterCallback("EditMode.Exit", exitEditMode, module)
  end

  if EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", enterEditMode)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", exitEditMode)
    if EditModeManagerFrame.SelectSystem then
      hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
        showEditModeDialog(false)
        if selection and selection.ShowHighlighted then
          selection:ShowHighlighted()
        end
      end)
    end
  end

  if EditModeSystemSettingsDialog then
    EditModeSystemSettingsDialog:HookScript("OnShow", function()
      showEditModeDialog(false)
      if selection and selection.ShowHighlighted then
        selection:ShowHighlighted()
      end
    end)
  end
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "Refresh")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_ALIVE")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
    enterEditMode()
  else
    self:Refresh()
  end
end

function module:PLAYER_REGEN_DISABLED()
  if isEditing then
    exitEditMode()
  end
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
  if isEditing then
    exitEditMode()
  elseif container then
    container:Hide()
  end
end
