setfenv(1, _G.SlackHacks)

local module = Self:NewModule("Weeklies", "AceEvent-3.0")
Self.Weeklies = module

-- Widget backing the "Gilded Stash" counter shown on the Delver's Journey (rank 4 reward). Widget ID and
-- required count confirmed against MidnightRoutine's Delves.lua, which reads the same live tooltip text.
local GILDED_STASH_WIDGET_ID = 7591
local GILDED_STASH_REQUIRED = 4
local TROVEHUNTERS_BOUNTY_QUEST_ID = 86371
local TROVEHUNTERS_BOUNTY_ICON_ID = 1064187
local TROVEHUNTERS_BOUNTY_ITEM_ID = 274374
local TROVEHUNTERS_BOUNTY_ENGAGED_SPELL_ID = 1254631
local BOUNTY_STATUS_AVAILABLE = "Available"
local BOUNTY_STATUS_ACQUIRED = "Acquired"
local BOUNTY_STATUS_ENGAGED = "Engaged"
local BOUNTY_STATUS_COMPLETED = "Completed"
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
local contextMenu
local contextMenuRows = {}

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

--- Determines this week's Trovehunter's Bounty progress.
--- Checked in priority order: a finished weekly quest always wins; the Engaged buff is looked up by
--- spell ID directly (a single hash-map read via GetPlayerAuraBySpellID, not a full aura-list scan),
--- so this stays cheap even though it can run every time the tracker refreshes; bag possession is the
--- cheapest remaining fallback.
---@return string status One of `BOUNTY_STATUS_AVAILABLE`, `BOUNTY_STATUS_ACQUIRED`, `BOUNTY_STATUS_ENGAGED`, or `BOUNTY_STATUS_COMPLETED`.
local function trovehuntersBountyStatus()
  if trovehuntersBountyCompleted() then return BOUNTY_STATUS_COMPLETED end
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(TROVEHUNTERS_BOUNTY_ENGAGED_SPELL_ID) then
    return BOUNTY_STATUS_ENGAGED
  end
  if C_Item and C_Item.GetItemCount and C_Item.GetItemCount(TROVEHUNTERS_BOUNTY_ITEM_ID) > 0 then
    return BOUNTY_STATUS_ACQUIRED
  end
  return BOUNTY_STATUS_AVAILABLE
end

--- Looks up a currency by ID, falling back to the visible currency list for currencies without an ID.
--- Returns the full record as well as amount and icon so callers can display weekly and total caps.
---@param currencyName string Localized display name used by the currency-list fallback.
---@param currencyID number|nil Stable currency ID when known.
---@return number|nil quantity Current balance, if the currency is known.
---@return number|nil iconFileID Currency icon texture ID.
---@return table|nil info Full `CurrencyInfo` record, including cap fields.
local function currencyAmount(currencyName, currencyID)
  if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local currency = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if currency then return currency.quantity, currency.iconFileID, currency end
  end

  if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize or not C_CurrencyInfo.GetCurrencyListInfo then return nil end

  for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
    local currency = C_CurrencyInfo.GetCurrencyListInfo(index)
    if currency and currency.name == currencyName then return currency.quantity, currency.iconFileID, currency end
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

local function closeContextMenu()
  if contextMenu then contextMenu:Hide() end
end

local function createContextMenuRow(index)
  local row = CreateFrame("Button", "SlackHacksDelvesContextMenuRow" .. index, contextMenu, "BackdropTemplate, SecureActionButtonTemplate")
  row:SetHeight(24)
  row:RegisterForClicks("AnyUp", "AnyDown")

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
  highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 1)
  highlight:SetVertexColor(1, 1, 1, 0.35)
  highlight:SetBlendMode("ADD")

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", row, "LEFT", 4, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.icon = icon

  local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  name:SetJustifyH("LEFT")
  row.name = name

  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.toyID then
      GameTooltip:SetToyByItemID(self.toyID)
    elseif self.itemID then
      GameTooltip:SetItemByID(self.itemID)
    elseif self.spellID then
      GameTooltip:SetSpellByID(self.spellID)
    else
      GameTooltip_Hide()
      return
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("PostClick", function(self)
    closeContextMenu()
    if self.action then self.action() end
  end)

  return row
end

local function openContextMenu(anchor)
  if InCombatLockdown() then return end
  GameTooltip_Hide()

  if not contextMenu then
    contextMenu = CreateFrame("Frame", "SlackHacksDelvesContextMenu", UIParent, "BackdropTemplate")
    contextMenu:SetFrameStrata("DIALOG")
    contextMenu:SetClampedToScreen(true)
    contextMenu:EnableMouse(true)
    local background = contextMenu:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("common-dropdown-c-bg")
    background:SetPoint("TOPLEFT", -17, 12)
    background:SetPoint("BOTTOMRIGHT", 17, -22)
    EventRegistry:RegisterFrameEventAndCallback("GLOBAL_MOUSE_DOWN", function()
      if contextMenu:IsShown() and not contextMenu:IsMouseOver() and not (contextMenu.anchor and contextMenu.anchor:IsMouseOver()) then
        closeContextMenu()
      end
    end)
  end

  if contextMenu:IsShown() then
    closeContextMenu()
    return
  end

  local rowHeight = 24
  local rowGap = 2
  local padding = 6
  local menuWidth = 240
  for index, option in ipairs(CONTEXT_MENU_OPTIONS) do
    local row = contextMenuRows[index] or createContextMenuRow(index)
    contextMenuRows[index] = row
    row:SetSize(menuWidth - (padding * 2), rowHeight)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", padding, -padding - (index - 1) * (rowHeight + rowGap))
    row.itemID = option.itemID
    row.spellID = option.spellID
    row.toyID = option.toyID
    row.action = option.action
    row:SetAttribute("type", option.toyID and "toy" or option.spellID and "spell" or option.itemID and "item" or nil)
    row:SetAttribute("toy", option.toyID)
    row:SetAttribute("spell", option.spellID)
    row:SetAttribute("item", option.itemID and "item:" .. option.itemID or nil)
    row.icon:SetTexture(contextMenuIcon(option))
    row.name:SetText(option.name)
    row:Show()
  end

  contextMenu:SetSize(menuWidth, (rowHeight + rowGap) * #CONTEXT_MENU_OPTIONS + padding * 2 - rowGap)
  contextMenu:ClearAllPoints()
  contextMenu.anchor = anchor
  contextMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
  contextMenu:Show()
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

  GameTooltip:AddDoubleLine(tooltipIconLabel("Trovehunter's Bounty", TROVEHUNTERS_BOUNTY_ICON_ID), COLUMN_GAP .. trovehuntersBountyStatus(), 1, 0.82, 0, 1, 0.82, 0)

  for _, currency in ipairs(DELVE_CURRENCIES) do
    local amount, icon, info = currencyAmount(currency.name, currency.id)
    local displayAmount = amount or "Unknown"
    if currency.id == 3356 and info then
      displayAmount = info.quantity .. " / " .. info.maxWeeklyQuantity .. " (" .. info.maxQuantity .. ")"
    elseif currency.id == 3310 and info then
      displayAmount = info.quantity .. " / " .. info.maxWeeklyQuantity
    end
    GameTooltip:AddDoubleLine(tooltipIconLabel(currency.name, icon), COLUMN_GAP .. displayAmount, 1, 0.82, 0, 1, 0.82, 0)
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

--- Creates/updates the tracker button and hides it when weekly tracking is disabled.
--- The door atlas only goes dark (the plain, non-bountiful world-map door) once BOTH weekly Delve
--- tasks are done; the map marker independently reflects Trovehunter's Bounty status.
function module:Refresh()
  createButton()
  if not button then return end

  local shouldShow = db.profile.weeklies.enabled and db.profile.weeklies.trackDelves
  if not shouldShow then
    button:Hide()
    return
  end

  local stash = gildedStashInfo()
  local bountyStatus = trovehuntersBountyStatus()
  local allTasksDone = stash and stash.completed and bountyStatus == BOUNTY_STATUS_COMPLETED
  button.icon:SetAtlas(allTasksDone and DELVES_ICON_ATLAS_DONE or DELVES_ICON_ATLAS_PENDING, false)
  if bountyStatus == BOUNTY_STATUS_COMPLETED then button.bounty:Hide() else button.bounty:Show() end

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

--- Registers events that can change stash progress or bounty status, then performs an initial refresh.
--- BAG_UPDATE_DELAYED (fired once per batch of bag changes, not per slot) catches the Acquired status
--- picking up/losing the Trovehunter's Bounty item without registering a noisier per-slot bag event.
function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("UPDATE_UI_WIDGET", "Refresh")
  self:RegisterEvent("QUEST_LOG_UPDATE", "Refresh")
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  if button then button:Hide() end
end
