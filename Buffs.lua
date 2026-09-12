setfenv(1, _G.SlackHacks)

--[[
  Reminds the player to keep up raid/dungeon consumables (food, flask, oil, augment rune) by showing
  clickable icons, similar in spirit to the "ClickableRaidBuffs" addon -- but event-driven instead of
  polling aura events constantly. Auras/bags are only rescanned on: PLAYER_ENTERING_WORLD (login/zoning
  into an instance), entering/leaving combat, joining/leaving a group, and bag changes (using an item).
]]--

local module = Self:NewModule("Buffs", "AceEvent-3.0")
Self.Buffs = module

local ICON_SIZE = 36 -- Blizzard's default buff icon is ~24px; this is 50% bigger.
local ICON_GAP = 6
local TOP_OFFSET = 130 -- Rough approximation of "2 inches" from the top of a typical display.
local ANCHOR_GAP = 8

local MYTHIC_DUNGEON_DIFFICULTY_IDS = { [8] = true, [23] = true } -- Mythic Keystone, Mythic (non-keystone)
local RAID_DIFFICULTY_IDS = { [14] = true, [15] = true, [16] = true } -- Normal, Heroic, Mythic raid (excludes LFR = 17)

local MYTHIC_DUNGEON_THRESHOLD_SECONDS = 40 * 60
local RAID_THRESHOLD_SECONDS = 15 * 60

-- Buff categories, in display order. `itemNames` key into StaticData's ITEM_NAMES table.
local BUFF_CATEGORIES = {
  {
    dbKey = "wellFed",
    label = "Well Fed",
    itemNames = { "Royal Roast" },
    matchAura = function(auraName) return auraName == "Well Fed" end,
  },
  {
    dbKey = "flask",
    label = "Flask",
    itemNames = {
      "Flask of the Magisters",
      "Flask of the Blood Knights",
      "Flask of the Shattered Sun",
      "Flask of Thalassian Resistance",
    },
    matchAura = function(auraName, _, itemNameSet) return itemNameSet[auraName] == true end,
  },
  {
    dbKey = "oil",
    label = "Oil",
    itemNames = { "Thalassian Phoenix Oil" },
    matchAura = function(_, spellID) return spellID == 1237006 end,
  },
  {
    dbKey = "augmentRune",
    label = "Augment Rune",
    itemNames = { "Void-Touched Augment Rune" },
    matchAura = function(_, spellID) return spellID == 1264426 end,
  },
}

for _, category in ipairs(BUFF_CATEGORIES) do
  local itemNameSet = {}
  for _, itemName in ipairs(category.itemNames) do
    itemNameSet[itemName] = true
  end
  category.itemNameSet = itemNameSet
end

local container
local iconButtons = {}

local function categoryItemIDs(category)
  local ids = {}
  for _, itemName in ipairs(category.itemNames) do
    local itemID = ITEM_NAMES and ITEM_NAMES[itemName]
    if itemID then table.insert(ids, itemID) end
  end
  return ids
end

local function categoryIcon(category)
  for _, itemID in ipairs(categoryItemIDs(category)) do
    local icon = C_Item.GetItemIconByID(itemID)
    if icon then return icon end
  end
  return SLACKHACKS_ICON
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
  for _, itemName in ipairs(category.itemNames) do
    local itemID = ITEM_NAMES and ITEM_NAMES[itemName]
    if itemID then
      local count = bagItemCount(itemID)
      if count > 0 then
        local bag, slot = findBagItem(itemID)
        table.insert(items, { itemID = itemID, itemName = itemName, count = count, bag = bag, slot = slot })
      end
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
  local context = currentContentContext()
  if not context or not contextIsEnabled(context) then return {} end
  if not (IsInGroup() or IsInRaid()) then return {} end

  if InCombatLockdown() then
    -- Only the augment rune reminder is useful mid-fight, and only while it's actually missing.
    for _, category in ipairs(BUFF_CATEGORIES) do
      if category.dbKey == "augmentRune" and db.profile.buffs.categories.augmentRune then
        if categoryBuffExpiration(category) == nil then return { category } end
      end
    end
    return {}
  end

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

local function createIconButton(index)
  local button = CreateFrame("Button", "SlackHacksBuffReminder" .. index, container)
  button:SetSize(ICON_SIZE, ICON_SIZE)

  local border = button:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("CENTER")
  border:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
  border:SetColorTexture(1, 0.82, 0)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(button)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Matches Blizzard's default buff icon cropping.

  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  local glow = button:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\WHITE8x8")
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER")
  glow:SetSize(ICON_SIZE + 14, ICON_SIZE + 14)
  glow:SetVertexColor(1, 0.82, 0, 0.5)

  local glowAnimation = glow:CreateAnimationGroup()
  glowAnimation:SetLooping("REPEAT")
  local fadeOut = glowAnimation:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(0.6)
  fadeOut:SetToAlpha(0.15)
  fadeOut:SetDuration(0.8)
  fadeOut:SetOrder(1)
  fadeOut:SetSmoothing("IN_OUT")
  local fadeIn = glowAnimation:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0.15)
  fadeIn:SetToAlpha(0.6)
  fadeIn:SetDuration(0.8)
  fadeIn:SetOrder(2)
  fadeIn:SetSmoothing("IN_OUT")
  glowAnimation:Play()

  button.border = border
  button.icon = icon
  button.glow = glow
  button.glowAnimation = glowAnimation

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.category.label)
    if self.hasItems then
      GameTooltip:AddLine("Click to use an item.", 1, 1, 1)
    else
      GameTooltip:AddLine("No " .. self.category.label .. " items in inventory.", 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)

  button:SetScript("OnClick", function(self)
    local items = categoryBagItems(self.category)
    if #items == 0 then
      print("SlackHacks: No " .. self.category.label .. " items in inventory.")
      return
    end
    MenuUtil.CreateContextMenu(self, function(_, rootDescription)
      rootDescription:SetTag("SLACKHACKS_BUFF_" .. self.category.dbKey)
      for _, item in ipairs(items) do
        rootDescription:CreateButton(item.itemName .. " (" .. item.count .. ")", function()
          if item.bag and item.slot then
            C_Container.UseContainerItem(item.bag, item.slot)
          end
        end)
      end
    end)
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
  local count = #active
  if count == 0 then
    container:Hide()
    for _, button in pairs(iconButtons) do button:Hide() end
    return
  end

  local totalWidth = (count * ICON_SIZE) + ((count - 1) * ICON_GAP)
  container:SetWidth(totalWidth)
  updatePosition()

  for index, category in ipairs(active) do
    local button = iconButton(index)
    button.category = category
    button.icon:SetTexture(categoryIcon(category))

    local bagItems = categoryBagItems(category)
    button.hasItems = #bagItems > 0
    local highlight = button:GetHighlightTexture()
    if button.hasItems then
      highlight:SetVertexColor(1, 0.82, 0) -- Gold: fulfillable via click.
    else
      highlight:SetVertexColor(1, 0, 0) -- Red: nothing in bags to fulfill it.
    end

    button:ClearAllPoints()
    local offsetX = (index - 1) * (ICON_SIZE + ICON_GAP)
    button:SetPoint("LEFT", container, "LEFT", offsetX, 0)
    button:Show()
  end

  for index, button in pairs(iconButtons) do
    if index > count then button:Hide() end
  end

  container:Show()
end

function module:Refresh()
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
