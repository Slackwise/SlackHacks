setfenv(1, _G.SlackHacks)

local module = Self:NewModule("Weeklies", "AceEvent-3.0")
Self.Weeklies = module

-- Widget backing the "Gilded Stash" counter shown on the Delver's Journey (rank 4 reward). Verified against
-- the live tooltip text via C_UIWidgetManager.GetSpellDisplayVisualizationInfo; the tooltip is parsed instead
-- of hardcoding the weekly cap since Blizzard has changed that number between seasons.
local GILDED_STASH_WIDGET_ID = 6659
local TROVEHUNTERS_BOUNTY_QUEST_ID = 86371
local DELVES_ICON_FALLBACK = 132320 -- INV_Misc_Chest_02; used until the Gilded Stash spell icon is available
local BUTTON_SIZE = 18

local button

local function delvesSeasonFactionID()
  return C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason and C_DelvesUI.GetDelvesFactionForSeason()
end

local function gildedStashInfo()
  if not C_UIWidgetManager or not C_UIWidgetManager.GetSpellDisplayVisualizationInfo then return nil end
  local ok, widgetInfo = pcall(C_UIWidgetManager.GetSpellDisplayVisualizationInfo, GILDED_STASH_WIDGET_ID)
  if not ok or not widgetInfo or not widgetInfo.spellInfo then return nil end
  local tooltip = widgetInfo.spellInfo.tooltip
  local current, max = tooltip and tooltip:match("(%d+)%s-/%s-(%d+)")
  current, max = tonumber(current), tonumber(max)
  return {
    current = current,
    max = max,
    spellID = widgetInfo.spellInfo.spellID,
    completed = current and max and current >= max
  }
end

local function trovehuntersBountyCompleted()
  return C_QuestLog.IsQuestFlaggedCompleted(TROVEHUNTERS_BOUNTY_QUEST_ID)
end

-- Valeera/Brann's own companion level; distinct from the seasonal Delver's Journey renown below.
local function companionLevel()
  local seasonFactionID = delvesSeasonFactionID()
  if not seasonFactionID or not C_MajorFactions or not C_DelvesUI then return nil end
  local ok, majorFactionData = pcall(C_MajorFactions.GetMajorFactionData, seasonFactionID)
  local companionID = ok and majorFactionData and majorFactionData.playerCompanionID
  if not companionID or not C_DelvesUI.GetFactionForCompanion then return nil end
  local ok2, companionFactionID = pcall(C_DelvesUI.GetFactionForCompanion, companionID)
  if not ok2 or not companionFactionID then return nil end
  local ok3, level = pcall(C_MajorFactions.GetCurrentRenownLevel, companionFactionID)
  return ok3 and level or nil
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
    GameTooltip:AddLine(("Gilded Stash: %d/%d"):format(stash.current, stash.max), 1, 0.82, 0)
  else
    GameTooltip:AddLine("Gilded Stash: unavailable", 0.6, 0.6, 0.6)
  end

  GameTooltip:AddLine("Trovehunter's Bounty: " .. (trovehuntersBountyCompleted() and "Claimed" or "Available"), 1, 0.82, 0)

  local companion = companionLevel()
  GameTooltip:AddLine("Valeera: " .. (companion and ("Level " .. companion) or "Unknown"), 1, 0.82, 0)

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
  local iconTexture = stash and stash.spellID and C_Spell.GetSpellTexture(stash.spellID)
  button.icon:SetTexture(iconTexture or DELVES_ICON_FALLBACK)

  if stash and stash.completed then
    button.check:Show()
    button.count:Hide()
  else
    button.check:Hide()
    if stash and stash.current and stash.max then
      button.count:SetText(stash.current)
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
