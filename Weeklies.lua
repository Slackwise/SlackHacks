setfenv(1, _G.SlackHacks)

local module = Self:NewModule("Weeklies", "AceEvent-3.0")
Self.Weeklies = module

-- Widget backing the "Gilded Stash" counter shown on the Delver's Journey (rank 4 reward). Widget ID and
-- required count confirmed against MidnightRoutine's Delves.lua, which reads the same live tooltip text.
local GILDED_STASH_WIDGET_ID = 7591
local GILDED_STASH_REQUIRED = 4
local TROVEHUNTERS_BOUNTY_QUEST_ID = 86371
local TROVEHUNTERS_BOUNTY_ICON_ID = 1064187
local DELVE_RENOWN_ICON_ID = 6025441
local VALEERA_ICON_ID = 236439
local DELVE_CURRENCIES = {
  { name = "Restored Coffer Keys", id = 3028 },
  { name = "Coffer Key Shards", id = 3310 },
  { name = "Untainted Mana-Crystals", id = 3356 },
  { name = "Undercoin", id = 2803 },
}
-- Same door icons used for delve entrances on the world map (glowing = bountiful, plain = regular).
local DELVES_ICON_ATLAS_PENDING = "delves-bountiful"
local DELVES_ICON_ATLAS_DONE = "delves-regular"
local BUTTON_SIZE = 18
local TROVEHUNTERS_BOUNTY_ICON = "Interface\\Icons\\INV_Misc_Map_01"

-- The Gilded Stash reward icon already has its ornate gold border baked into the art; a circular mask
-- just crops the square texture down to that coin shape, used to render the 4 weekly stash slots.
local GILDED_STASH_ICON_ID = 5872049
local STASH_ICON_MASK_ATLAS = "CircleMaskScalable"
local STASH_ICON_SIZE = 14
local STASH_ICON_GAP = 2
local STASH_ICON_COUNT = 4

local button

local function delvesSeasonFactionID()
  return C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason and C_DelvesUI.GetDelvesFactionForSeason()
end

local function gildedStashInfo()
  if C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve() then
    -- The widget goes blank while inside a delve, so fall back to the last value we saw outside one.
    local remaining = db.char.cache.lastKnownGildedStashesRemaining
    if remaining == nil then return nil end
    local current = GILDED_STASH_REQUIRED - remaining
    return { current = current, max = GILDED_STASH_REQUIRED, completed = remaining <= 0 }
  end

  if not C_UIWidgetManager or not C_UIWidgetManager.GetSpellDisplayVisualizationInfo then return nil end
  local ok, widgetInfo = pcall(C_UIWidgetManager.GetSpellDisplayVisualizationInfo, GILDED_STASH_WIDGET_ID)
  if not ok or not widgetInfo or not widgetInfo.spellInfo then return nil end
  local tooltip = widgetInfo.spellInfo.tooltip
  if type(tooltip) ~= "string" or tooltip == "" then return nil end

  -- Prefer the number pair matching the known weekly cap, in case the tooltip mentions other counts too.
  local current, max
  for foundCurrent, foundMax in tooltip:gmatch("(%d+)%s*/%s*(%d+)") do
    foundCurrent, foundMax = tonumber(foundCurrent), tonumber(foundMax)
    if foundCurrent and foundMax == GILDED_STASH_REQUIRED then
      current, max = foundCurrent, foundMax
      break
    elseif not current and foundCurrent and foundMax then
      current, max = foundCurrent, foundMax
    end
  end
  max = max or GILDED_STASH_REQUIRED

  if current then
    db.char.cache.lastKnownGildedStashesRemaining = max - current
  end

  return {
    current = current,
    max = max,
    completed = current and current >= max
  }
end

local function trovehuntersBountyCompleted()
  return C_QuestLog.IsQuestFlaggedCompleted(TROVEHUNTERS_BOUNTY_QUEST_ID)
end

local function currencyAmount(currencyName, currencyID)
  if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local currency = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if currency then return currency.quantity, currency.iconFileID end
  end

  if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize or not C_CurrencyInfo.GetCurrencyListInfo then return nil end

  for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
    local currency = C_CurrencyInfo.GetCurrencyListInfo(index)
    if currency and currency.name == currencyName then return currency.quantity, currency.iconFileID end
  end
end

local function tooltipIconLabel(label, icon)
  if not icon then return label end
  return ("|T%s:14:14:0:0|t %s"):format(icon, label)
end

-- Valeera/Brann's own companion level; a Friendship-style reputation, distinct from the seasonal
-- Delver's Journey renown below (its rank/max come from GetFriendshipReputationRanks, not renown levels).
-- Calling GetFactionForCompanion with no argument defaults to the player's active companion, same as
-- Blizzard's own DelvesCompanionConfigurationFrameMixin:Refresh (avoids relying on playerCompanionID).
local function companionReputation()
  if not C_DelvesUI or not C_DelvesUI.GetFactionForCompanion then return nil end
  local ok, companionFactionID = pcall(C_DelvesUI.GetFactionForCompanion)
  if not ok or not companionFactionID or companionFactionID == 0 then return nil end

  if not C_GossipInfo or not C_GossipInfo.GetFriendshipReputationRanks then return nil end
  local ok3, rankInfo = pcall(C_GossipInfo.GetFriendshipReputationRanks, companionFactionID)
  if not ok3 or not rankInfo or not rankInfo.maxLevel then return nil end

  local name
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok4, factionData = pcall(C_Reputation.GetFactionDataByID, companionFactionID)
    name = ok4 and factionData and factionData.name
  end

  return { name = name or "Valeera", level = rankInfo.currentLevel, maxLevel = rankInfo.maxLevel }
end

local function delveRenownLevel()
  local seasonFactionID = delvesSeasonFactionID()
  if not seasonFactionID or not C_MajorFactions then return nil end
  local ok, info = pcall(C_MajorFactions.GetMajorFactionRenownInfo, seasonFactionID)
  if not ok or not info or not info.renownLevel then return nil end

  local maxLevel
  if C_MajorFactions.GetRenownLevels then
    local ok2, levels = pcall(C_MajorFactions.GetRenownLevels, seasonFactionID)
    if ok2 and type(levels) == "table" and #levels > 0 then
      maxLevel = #levels
    end
  end

  return { level = info.renownLevel, maxLevel = maxLevel }
end

local function createStashIcon(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(STASH_ICON_SIZE, STASH_ICON_SIZE)

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(GILDED_STASH_ICON_ID)

  local mask = frame:CreateMaskTexture(nil, "ARTWORK")
  mask:SetAllPoints(icon)
  mask:SetAtlas(STASH_ICON_MASK_ATLAS, false)
  icon:AddMaskTexture(mask)

  frame.icon = icon
  return frame
end

local function openDelveRenownJourney()
  local factionID = delvesSeasonFactionID()
  if not factionID then return end
  if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
  if EncounterJournal_OpenToJourney then EncounterJournal_OpenToJourney(factionID) end
end

local function openDelveCompanionPanel()
  if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_DelvesCompanionConfiguration") end
  if DelvesCompanionConfigurationFrame then ShowUIPanel(DelvesCompanionConfigurationFrame) end
end

local CONTEXT_MENU_OPTIONS = {
  { name = "Open Delve Renown Journey", icon = DELVE_RENOWN_ICON_ID, action = openDelveRenownJourney },
  { name = "See Valeera Sanguinar's Loadout", icon = VALEERA_ICON_ID, action = openDelveCompanionPanel },
  { name = "Use Coffer Key Glue", toyID = 267291 },
  { name = "Use Delve-O-Bot 7001", toyID = 230850 },
  { name = "Use L00T RAID-R Mini", itemID = 244193 },
}

local function contextMenuIcon(option)
  if option.icon then return option.icon end
  if option.toyID and C_ToyBox and C_ToyBox.GetToyInfo then
    local _, _, icon = C_ToyBox.GetToyInfo(option.toyID)
    if icon then return icon end
  end
  if option.spellID and C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(option.spellID) end
  if option.itemID and C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(option.itemID) end
end

local function addContextMenuOption(rootDescription, option)
  local description = rootDescription:CreateButton(tooltipIconLabel(option.name, contextMenuIcon(option)), function()
    if option.action then option.action() end
    return MenuResponse.CloseAll
  end)

  if option.itemID or option.spellID or option.toyID then
    description:AddInitializer(function(frame, elementDescription)
      if not frame.secureActionButton then
        frame.secureActionButton = frame:AttachTemplate("SecureActionButtonTemplate")
        frame.secureActionButton:SetAllPoints()
        frame.secureActionButton:SetFrameLevel(frame:GetFrameLevel() + 1)
        frame.secureActionButton:SetPropagateMouseMotion(true)
      end

      local actionButton = frame.secureActionButton
      actionButton:EnableMouse(true)
      actionButton:SetMouseClickEnabled(true)
      actionButton:SetMouseMotionEnabled(true)
      actionButton:RegisterForClicks("AnyUp", "AnyDown")
      actionButton:SetAttribute("type", nil)
      actionButton:SetAttribute("spell", nil)
      actionButton:SetAttribute("item", nil)
      actionButton:SetAttribute("toy", nil)
      actionButton:SetAttribute("type", option.toyID and "toy" or option.spellID and "spell" or "item")
      actionButton:SetAttribute("spell", option.spellID)
      actionButton:SetAttribute("item", option.itemID and "item:" .. option.itemID or nil)
      actionButton:SetAttribute("toy", option.toyID)
      actionButton:SetScript("PostClick", function(_, mouseButton)
        elementDescription:Pick(MenuInputContext.MouseButton, mouseButton)
      end)
    end)
  end

  if option.itemID or option.spellID or option.toyID then
    description:SetTooltip(function(tooltip)
      if option.toyID then
        tooltip:SetToyByItemID(option.toyID)
      elseif option.itemID then
        tooltip:SetItemByID(option.itemID)
      else
        tooltip:SetSpellByID(option.spellID)
      end
    end)
  end
end

local function openContextMenu(anchor)
  if InCombatLockdown() or not MenuUtil then return end
  GameTooltip_Hide()
  MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
    for _, option in ipairs(CONTEXT_MENU_OPTIONS) do
      addContextMenuOption(rootDescription, option)
    end
  end)
end

local function createButton()
  if button then return end
  local header = ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header
  local anchor = header and header.MinimizeButton
  if not anchor then return end

  button = CreateFrame("Button", "SlackHacksDelvesTrackerButton", header)
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetPoint("RIGHT", anchor, "LEFT", -4, 0)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetAtlas(DELVES_ICON_ATLAS_PENDING, false)
  button.icon = icon

  local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
  button.count = count

  local bounty = button:CreateTexture(nil, "OVERLAY")
  bounty:SetSize(10, 10)
  bounty:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -2, -2)
  bounty:SetTexture(TROVEHUNTERS_BOUNTY_ICON)
  bounty:Hide()
  button.bounty = bounty

  button:SetScript("OnEnter", module.ShowTooltip)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button:SetScript("OnClick", function(self) openContextMenu(self) end)

  button:Hide()
end

-- Created lazily and parented directly to GameTooltip so it hides along with it; anchored over the
-- right column of the "Gilded Stashes Remaining" double line since GameTooltip has no native slot for
-- custom textures within a line.
local tooltipStashIcons

local function getTooltipStashIcons()
  if tooltipStashIcons then return tooltipStashIcons end
  local container = CreateFrame("Frame", nil, GameTooltip)
  container:SetSize(STASH_ICON_COUNT * STASH_ICON_SIZE + (STASH_ICON_COUNT - 1) * STASH_ICON_GAP, STASH_ICON_SIZE)

  local icons = {}
  local previous
  for index = 1, STASH_ICON_COUNT do
    local stashIcon = createStashIcon(container)
    if previous then
      stashIcon:SetPoint("LEFT", previous, "RIGHT", STASH_ICON_GAP, 0)
    else
      stashIcon:SetPoint("LEFT", container, "LEFT", 0, 0)
    end
    icons[index] = stashIcon
    previous = stashIcon
  end
  container.icons = icons

  -- GameTooltip is shared by every tooltip in the game; without this the icons would keep showing
  -- (still parented/anchored from our last use) whenever the tooltip is reused for something else.
  GameTooltip:HookScript("OnTooltipCleared", function() container:Hide() end)

  tooltipStashIcons = container
  return container
end

function module.ShowTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("Delves", 1, 1, 1)

  -- Leading spaces on the right column widen the tooltip without shifting the right-justified text,
  -- which opens up a gap between the two columns.
  local COLUMN_GAP = "   "

  local stash = gildedStashInfo()
  local iconLineIndex
  if stash and stash.current and stash.max then
    GameTooltip:AddDoubleLine(tooltipIconLabel("Gilded Stashes Remaining", GILDED_STASH_ICON_ID), COLUMN_GAP .. " ", 1, 0.82, 0, 1, 0.82, 0)
    iconLineIndex = GameTooltip:NumLines()
  else
    GameTooltip:AddDoubleLine(tooltipIconLabel("Gilded Stashes Remaining", GILDED_STASH_ICON_ID), COLUMN_GAP .. "unavailable", 1, 0.82, 0, 0.6, 0.6, 0.6)
  end

  GameTooltip:AddDoubleLine(tooltipIconLabel("Trovehunter's Bounty", TROVEHUNTERS_BOUNTY_ICON_ID), COLUMN_GAP .. (trovehuntersBountyCompleted() and "Claimed" or "Available"), 1, 0.82, 0, 1, 0.82, 0)

  for _, currency in ipairs(DELVE_CURRENCIES) do
    local amount, icon = currencyAmount(currency.name, currency.id)
    GameTooltip:AddDoubleLine(tooltipIconLabel(currency.name, icon), COLUMN_GAP .. (amount or "Unknown"), 1, 0.82, 0, 1, 0.82, 0)
  end

  local companion = companionReputation()
  if companion then
    GameTooltip:AddDoubleLine(tooltipIconLabel(companion.name or "Valeera", VALEERA_ICON_ID), COLUMN_GAP .. companion.level .. " / " .. companion.maxLevel, 1, 0.82, 0, 1, 0.82, 0)
  else
    GameTooltip:AddDoubleLine(tooltipIconLabel("Valeera", VALEERA_ICON_ID), COLUMN_GAP .. "Unknown", 1, 0.82, 0, 1, 0.82, 0)
  end

  local renown = delveRenownLevel()
  if renown and renown.maxLevel then
    GameTooltip:AddDoubleLine(tooltipIconLabel("Delve Renown", DELVE_RENOWN_ICON_ID), COLUMN_GAP .. renown.level .. " / " .. renown.maxLevel, 1, 0.82, 0, 1, 0.82, 0)
  elseif renown then
    GameTooltip:AddDoubleLine(tooltipIconLabel("Delve Renown", DELVE_RENOWN_ICON_ID), COLUMN_GAP .. "Level " .. renown.level, 1, 0.82, 0, 1, 0.82, 0)
  else
    GameTooltip:AddDoubleLine(tooltipIconLabel("Delve Renown", DELVE_RENOWN_ICON_ID), COLUMN_GAP .. "Unknown", 1, 0.82, 0, 1, 0.82, 0)
  end

  GameTooltip:Show()

  if iconLineIndex then
    local container = getTooltipStashIcons()
    local lineFrame = _G["GameTooltipTextRight" .. iconLineIndex]
    container:ClearAllPoints()
    container:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0)
    container:Show()

    for index, stashIcon in ipairs(container.icons) do
      local isClaimed = index <= stash.current
      stashIcon.icon:SetDesaturated(isClaimed)
      stashIcon.icon:SetVertexColor(isClaimed and 0.4 or 1, isClaimed and 0.4 or 1, isClaimed and 0.4 or 1)
    end
  elseif tooltipStashIcons then
    tooltipStashIcons:Hide()
  end
end

function module:Refresh()
  createButton()
  if not button then return end

  local shouldShow = db.profile.weeklies.enabled and db.profile.weeklies.trackDelves
  if not shouldShow then
    button:Hide()
    return
  end

  local stash = gildedStashInfo()
  button.icon:SetAtlas(stash and stash.completed and DELVES_ICON_ATLAS_DONE or DELVES_ICON_ATLAS_PENDING, false)
  if trovehuntersBountyCompleted() then button.bounty:Hide() else button.bounty:Show() end

  if stash and stash.completed then
    button.count:Hide()
  else
    if stash and stash.current and stash.max then
      button.count:SetText(stash.max - stash.current)
      button.count:Show()
    else
      button.count:Hide()
    end
  end

  button:Show()
end

function module:SetEnabled(enabled)
  db.profile.weeklies.enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

function module:SetTrackDelves(enabled)
  db.profile.weeklies.trackDelves = enabled
  self:Refresh()
end

function module:OnInitialize()
  createButton()
  if not db.profile.weeklies.enabled then self:Disable() end
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("UPDATE_UI_WIDGET", "Refresh")
  self:RegisterEvent("QUEST_LOG_UPDATE", "Refresh")
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  if button then button:Hide() end
end
