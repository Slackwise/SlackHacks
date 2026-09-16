setfenv(1, _G.SlackHacks)

local module = Self:NewModule("Weeklies", "AceEvent-3.0")
Self.Weeklies = module

-- Widget backing the "Gilded Stash" counter shown on the Delver's Journey (rank 4 reward). Widget ID and
-- required count confirmed against MidnightRoutine's Delves.lua, which reads the same live tooltip text.
local GILDED_STASH_WIDGET_ID = 7591
local GILDED_STASH_REQUIRED = 4
local TROVEHUNTERS_BOUNTY_QUEST_ID = 86371
-- Same door icons used for delve entrances on the world map (glowing = bountiful, plain = regular).
local DELVES_ICON_ATLAS_PENDING = "delves-bountiful"
local DELVES_ICON_ATLAS_DONE = "delves-regular"
local BUTTON_SIZE = 18

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
  return ok and info and info.renownLevel or nil
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

  local check = button:CreateTexture(nil, "OVERLAY")
  check:SetSize(14, 14)
  check:SetPoint("CENTER", button, "CENTER", 6, -6)
  check:SetAtlas("common-icon-checkmark", true)
  check:Hide()
  button.check = check

  button:SetScript("OnEnter", module.ShowTooltip)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button:SetScript("OnClick", module.OnClick)

  button:Hide()
end

function module.ShowTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("Delves", 1, 1, 1)

  local stash = gildedStashInfo()
  if stash and stash.current and stash.max then
    local remaining = stash.max - stash.current
    GameTooltip:AddLine("Gilded Stashes Remaining: " .. (remaining > 0 and remaining or "Done!"), 1, 0.82, 0)
  else
    GameTooltip:AddLine("Gilded Stashes Remaining: unavailable", 0.6, 0.6, 0.6)
  end

  GameTooltip:AddLine("Trovehunter's Bounty: " .. (trovehuntersBountyCompleted() and "Claimed" or "Available"), 1, 0.82, 0)

  local companion = companionReputation()
  if companion then
    GameTooltip:AddLine(companion.name .. ": " .. companion.level .. " / " .. companion.maxLevel, 1, 0.82, 0)
  else
    GameTooltip:AddLine("Valeera: Unknown", 1, 0.82, 0)
  end

  local renown = delveRenownLevel()
  GameTooltip:AddLine("Delve Renown: " .. (renown and ("Level " .. renown) or "Unknown"), 1, 0.82, 0)

  GameTooltip:Show()
end

function module.OnClick()
  local factionID = delvesSeasonFactionID()
  if not factionID then return end
  if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
  if EncounterJournal_OpenToJourney then
    EncounterJournal_OpenToJourney(factionID)
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
  local allDone = stash and stash.completed and trovehuntersBountyCompleted()
  button.icon:SetAtlas(allDone and DELVES_ICON_ATLAS_DONE or DELVES_ICON_ATLAS_PENDING, false)

  if stash and stash.completed then
    button.check:Show()
    button.count:Hide()
  else
    button.check:Hide()
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
