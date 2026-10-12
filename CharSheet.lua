setfenv(1, _G.SlackHacks)

local module = Self:NewModule("CharSheet")
Self.CharSheet = module

local gearStatsCheckbox

local function charSheetSettings()
  local infoDisplay = db and db.profile and db.profile.infoDisplay
  if infoDisplay and infoDisplay.charSheet then
    return infoDisplay.charSheet
  end
  return { enabled = true, gearStats = false }
end

local function getForeverScrollArea()
  local scrollBox = _G["CharacterStatsPaneScrollBox"]
  if scrollBox then
    return scrollBox.ScrollBox or scrollBox
  end
  if CharacterStatsPane then
    if CharacterStatsPane.ScrollBox then
      return CharacterStatsPane.ScrollBox
    end
    if CharacterStatsPane.ScrollBar then
      return CharacterStatsPane.ScrollBar
    end
  end
  if _G["CharacterStatsPaneScrollBar"] then
    return _G["CharacterStatsPaneScrollBar"]
  end
  if PaperDollFrame then
    if PaperDollFrame.ScrollBox then
      return PaperDollFrame.ScrollBox
    end
    if PaperDollFrame.StatsPane then
      return PaperDollFrame.StatsPane.ScrollBox or PaperDollFrame.StatsPane
    end
  end
  if CharacterFrame and CharacterFrame.ScrollBox then
    return CharacterFrame.ScrollBox
  end
  return CharacterAttributesFrame or PaperDollFrame or CharacterFrame
end

local function checkboxParentAndAnchor(textWidth)
  textWidth = textWidth or 58
  if isRetail() then
    local relativeText = CharacterLevelText
      or (CharacterFrame and (CharacterFrame.LevelText or CharacterFrame.TitleText))
      or CharacterNameText
    local parent = (relativeText and relativeText.GetParent and relativeText:GetParent())
      or PaperDollFrame
      or CharacterFrame
    if relativeText then
      return parent, "RIGHT", relativeText, "LEFT", -(textWidth + 8), 0
    else
      return parent, "TOPLEFT", parent, "TOPLEFT", 60, -30
    end
  end
  local scrollArea = getForeverScrollArea()
  local parent = PaperDollFrame or (scrollArea and scrollArea:GetParent()) or CharacterFrame
  local offsetX = -math.floor((textWidth + 4) / 2)
  if scrollArea and scrollArea ~= PaperDollFrame and scrollArea ~= CharacterFrame then
    return parent, "TOP", scrollArea, "BOTTOM", offsetX, -5
  end
  return parent, "BOTTOM", parent, "BOTTOM", offsetX, 72
end

function module:UpdateCheckbox()
  if not gearStatsCheckbox then return end
  local settings = charSheetSettings()
  if not settings.enabled then
    gearStatsCheckbox:Hide()
    return
  end
  gearStatsCheckbox:SetChecked(settings.gearStats == true)
end

local function updateCheckboxPosition()
  if not gearStatsCheckbox then return end
  local text = gearStatsCheckbox.text or gearStatsCheckbox.Text or _G[gearStatsCheckbox:GetName() .. "Text"]
  local textWidth = text and text:GetStringWidth() or 0
  if textWidth == 0 then textWidth = 58 end

  local parent, point, relativeFrame, relativePoint, xOffset, yOffset = checkboxParentAndAnchor(textWidth)
  if not parent or not relativeFrame then return end
  if gearStatsCheckbox:GetParent() ~= parent then
    gearStatsCheckbox:SetParent(parent)
    local statsLevel = relativeFrame.GetFrameLevel and relativeFrame:GetFrameLevel() or 0
    local parentLevel = parent.GetFrameLevel and parent:GetFrameLevel() or 0
    gearStatsCheckbox:SetFrameLevel(math.max(statsLevel, parentLevel) + 15)
  end
  gearStatsCheckbox:SetSize(18, 18)
  gearStatsCheckbox:ClearAllPoints()
  gearStatsCheckbox:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset)
  gearStatsCheckbox:SetHitRectInsets(0, -textWidth - 4, 0, 0)
end

local function getOrCreateGearStatsCheckbox()
  if not charSheetSettings().enabled then
    if gearStatsCheckbox then gearStatsCheckbox:Hide() end
    return nil
  end
  if gearStatsCheckbox then return gearStatsCheckbox end
  if not CharacterFrame then return nil end

  local parent, point, relativeFrame, relativePoint, xOffset, yOffset = checkboxParentAndAnchor(58)
  if not parent or not relativeFrame then return nil end
  local checkbox = CreateFrame("CheckButton", "SlackHacksInfoDisplayGearStatsToggle", parent, "UICheckButtonTemplate")
  gearStatsCheckbox = checkbox
  checkbox:SetSize(18, 18)
  local statsLevel = relativeFrame.GetFrameLevel and relativeFrame:GetFrameLevel() or 0
  local parentLevel = parent.GetFrameLevel and parent:GetFrameLevel() or 0
  checkbox:SetFrameLevel(math.max(statsLevel, parentLevel) + 15)

  local text = checkbox.text or checkbox.Text or _G[checkbox:GetName() .. "Text"]
  if text then
    text:SetText("Gear Stats")
    text:SetFontObject("GameFontHighlightSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
  end

  updateCheckboxPosition()
  module:UpdateCheckbox()
  checkbox:SetScript("OnClick", function(self)
    local checked = self:GetChecked() and true or false
    local sound = checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
    PlaySound(sound or (checked and 856 or 857))
    Self.InfoDisplay:SetEnabled(checked)
  end)
  checkbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Gear Stats", 1, 1, 1)
    GameTooltip:AddLine("Toggle equipment stat overlays on your character sheet.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  checkbox:SetScript("OnLeave", GameTooltip_Hide)

  if CharacterStatsPane and not isRetail() then
    CharacterStatsPane:HookScript("OnShow", function()
      if gearStatsCheckbox then
        gearStatsCheckbox:Show()
        updateCheckboxPosition()
        module:UpdateCheckbox()
      end
    end)
  end
  if PaperDollFrame then
    PaperDollFrame:HookScript("OnShow", function()
      if gearStatsCheckbox then
        gearStatsCheckbox:Show()
        updateCheckboxPosition()
        module:UpdateCheckbox()
      end
    end)
  end
  return checkbox
end

function module:SetCharSheetEnabled(enabled)
  local settings = charSheetSettings()
  settings.enabled = enabled
  if enabled then
    local checkbox = getOrCreateGearStatsCheckbox()
    if checkbox then
      checkbox:Show()
      updateCheckboxPosition()
      self:UpdateCheckbox()
    end
  elseif gearStatsCheckbox then
    gearStatsCheckbox:Hide()
  end
  if Self.InfoDisplay then Self.InfoDisplay:Refresh() end
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

function module:OnInitialize()
  getOrCreateGearStatsCheckbox()
  if CharacterFrame then
    CharacterFrame:HookScript("OnShow", function()
      local checkbox = getOrCreateGearStatsCheckbox()
      if checkbox then
        checkbox:Show()
        updateCheckboxPosition()
        module:UpdateCheckbox()
      end
    end)
  end
end
