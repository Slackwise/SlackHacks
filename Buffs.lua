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

--- Returns the latest expiration time (seconds, epoch-relative via GetTime()) for a matching buff on the
--- player, `0` if a matching permanent buff is found, or `nil` if the buff isn't active at all.
local function categoryBuffExpiration(category)
  local expiration
  forEachPlayerBuff(function(aura)
    if category.matchAura(aura.name, aura.spellId, category.itemNameSet) then
      if aura.expirationTime == 0 then
        expiration = 0
      elseif not expiration or (expiration ~= 0 and aura.expirationTime > expiration) then
        expiration = aura.expirationTime
      end
    end
  end)
  return expiration
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
  return (expiration - GetTime()) <= threshold
end

local function activeCategories()
  if InCombatLockdown() then return {} end
  local context = currentContentContext()
  if not context or not contextIsEnabled(context) then return {} end
  if not (IsInGroup() or IsInRaid()) then return {} end

  local active = {}
  for _, category in ipairs(BUFF_CATEGORIES) do
    if categoryShouldShow(category, context) then table.insert(active, category) end
  end
  return active
end

local function createContainer()
  if container then return end
  container = CreateFrame("Frame", "SlackHacksBuffReminders", UIParent)
  container:SetSize(ICON_SIZE, ICON_SIZE)
  container:Hide()
end

local function setButtonAction(button, category, item)
  if not button or InCombatLockdown() then return end
  if not item or not category then
    button:SetAttribute("type", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macrotext", nil)
    button:SetAttribute("unit", nil)
    return
  end

  if category.dbKey == "oil" then
    button:SetAttribute("item", nil)
    button:SetAttribute("unit", nil)
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "/use item:" .. item.itemID .. "\n/use 16")
  else
    button:SetAttribute("macrotext", nil)
    button:SetAttribute("type", "item")
    button:SetAttribute("item", "item:" .. item.itemID)
    button:SetAttribute("unit", "player")
  end
end

local function createIconButton(index)
  local button = CreateFrame("Button", "SlackHacksBuffReminder" .. index, container, "AuraButtonTemplate, SecureActionButtonTemplate")
  button:SetSize(AURA_BUTTON_WIDTH, AURA_BUTTON_WIDTH)
  button:SetScale(1.5)
  button:RegisterForClicks("AnyUp", "AnyDown")

  local icon = button.Icon
  button.icon = icon
  button.TempEnchantBorder:Hide()

  button:SetScript("OnHide", function(self)
    setNativeOverlayGlow(self, false)
  end)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.category.label)
    if self.activeItem then
      GameTooltip:AddLine("Click to use " .. self.activeItem.itemName .. " (" .. self.activeItem.count .. ").", 1, 1, 1)
    elseif self.hasItems then
      GameTooltip:AddLine("Click to use an item.", 1, 1, 1)
    else
      GameTooltip:AddLine("No " .. self.category.label .. " items in inventory.", 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)

  button:SetScript("PostClick", function(self)
    C_Timer.After(0.2, function() module:Refresh() end)
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

local function layoutIcons(active)
  if InCombatLockdown() then return end

  local count = #active
  if count == 0 then
    container:Hide()
    for _, button in pairs(iconButtons) do
      button:Hide()
      setButtonAction(button, nil, nil)
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
    local bestItem = bagItems[1]
    button.activeItem = bestItem
    button.hasItems = bestItem ~= nil
    setButtonAction(button, category, bestItem)
    setNativeOverlayGlow(button, button.hasItems)

    button:ClearAllPoints()
    local offsetX = (index - 1) * (ICON_SIZE + ICON_GAP)
    button:SetPoint("LEFT", container, "LEFT", offsetX, 0)
  end

  for index, button in pairs(iconButtons) do
    if index > count then
      button:Hide()
      setButtonAction(button, nil, nil)
    end
  end

  container:Show()
end

function module:Refresh()
  if InCombatLockdown() then return end
  createContainer()
  layoutIcons(activeCategories())
end

function module:OnInitialize()
  createContainer()
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "Refresh")
  self:RegisterEvent("PLAYER_REGEN_DISABLED", "Refresh")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  if container then container:Hide() end
end
