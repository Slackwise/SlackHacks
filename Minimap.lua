setfenv(1, _G.SlackHacks)

--[[
  Recreates the core feature set of the "Mappy" minimap addon (shape, opacity/fading, coordinates, and
  visibility toggles for the zone text/clock/calendar/tracking/extra minimap buttons/border) with simpler
  code and no multi-profile system. Minimap's position, size, icon scale, and rotation are left entirely
  to Blizzard's own Edit Mode, since Minimap (unlike our custom Buffs container) is already a native Edit
  Mode system -- we just attach our own options window to it when it's selected there.
]]--

local module = Self:NewModule("Minimap", "AceEvent-3.0")
Self.Minimap = module

local ROUND_MASK_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SQUARE_MASK_TEXTURE = "Interface\\BUTTONS\\WHITE8X8"

-- Falls back to Blizzard's untouched defaults whenever the module is disabled.
local DEFAULT_VISUALS = {
  shape = "circle",
  alpha = 100,
  fadeEnabled = false,
  combatAlpha = 100,
  movingAlpha = 100,
  showZoneText = true,
  showClock = true,
  showCalendar = true,
  showTracking = true,
  showAllMinimapTracking = false,
  hideExtraButtons = false,
  hideDiel = false,
  showBorder = true,
  mouseWheelZoom = true,
}

local function isModuleEnabled()
  return (db and db.profile and db.profile.minimap and db.profile.minimap.enabled) and module:IsEnabled()
end

local function settings()
  if db and db.profile and db.profile.minimap then
    return db.profile.minimap
  end
  return DEFAULT_VISUALS
end

local isInCombat = false
local isMoving = false
local savedCoordsState
local optionsDialog
local squareBorderFrame
local titleBarFrame
local titleBarZoneFallbackButton
local titleBarIconRow
local addonIconsContainer
local hoverCheckTicker
local applyTitleBarLayout
local registeredButtons = {}
local registeredButtonsByFrame = {}
local addonButtons = {}
local addonButtonsByFrame = {}
local origMinimapClusterLayout
local layoutPending = false
local addonScanTicker

local function getMailButton()
  if MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame then
    return MinimapCluster.IndicatorFrame.MailFrame
  end
  if MiniMapMailFrame then
    return MiniMapMailFrame
  end
  return nil
end

local function getCraftingOrderButton()
  if not isRetail() then return nil end
  if MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.CraftingOrderFrame then
    return MinimapCluster.IndicatorFrame.CraftingOrderFrame
  end
  if MiniMapCraftingOrderFrame then
    return MiniMapCraftingOrderFrame
  end
  return nil
end

local function extraButtons()
  local mail = getMailButton()
  local crafting = getCraftingOrderButton()
  return {
    mail,
    crafting,
    MinimapCluster and MinimapCluster.InstanceDifficulty,
    MiniMapBattlefieldFrame,
    MiniMapMeetingStoneFrame,
    MiniMapVoiceChatFrame,
    FeedbackUIButton,
    MiniMapLFGFrame,
    GuildInstanceDifficulty,
    ExpansionLandingPageMinimapButton,
    AddonCompartmentFrame,
  }
end

--- Show/hide is deferred (skipped, not queued) while in combat; PLAYER_REGEN_ENABLED re-applies everything.
local function setShownSafely(frame, shown)
  if not frame or InCombatLockdown() then return end
  frame:SetShown(shown)
end

local function applyShape()
  if not isModuleEnabled() then return end
  if not _G.Minimap.SetMaskTexture then return end -- not available on this client build; shape stays default
  _G.Minimap:SetMaskTexture(settings().shape == "square" and SQUARE_MASK_TEXTURE or ROUND_MASK_TEXTURE)
end

local function applyAlpha()
  if not isModuleEnabled() then return end
  local mm = settings()
  local alphaPercent = mm.alpha or 100
  if mm.fadeEnabled then
    if isInCombat then
      alphaPercent = mm.combatAlpha or alphaPercent
    elseif isMoving then
      alphaPercent = mm.movingAlpha or alphaPercent
    end
  end
  if alphaPercent > 0 and IsIndoors() then
    alphaPercent = 100 -- avoid a solid-black minimap indoors at less than full alpha
  end
  local clampedPercent = math.max(0, math.min(100, alphaPercent)) -- avoid relying on the global `Clamp`
  local alpha = clampedPercent / 100

  if MinimapCluster then
    MinimapCluster:SetAlpha(alpha)
  end

  -- If Minimap is not a child of MinimapCluster, set its alpha directly;
  -- otherwise, it inherits MinimapCluster's alpha (keep its own local alpha at 1 to prevent double-fading).
  if not MinimapCluster or (_G.Minimap:GetParent() ~= MinimapCluster and _G.Minimap:GetParent() ~= (MinimapCluster and MinimapCluster.MinimapContainer)) then
    _G.Minimap:SetAlpha(alpha)
  else
    _G.Minimap:SetAlpha(1)
  end

  if squareBorderFrame and squareBorderFrame:GetParent() ~= MinimapCluster then
    squareBorderFrame:SetAlpha(alpha)
  end
  if titleBarFrame and titleBarFrame:GetParent() ~= MinimapCluster then
    titleBarFrame:SetAlpha(alpha)
  end
  if addonIconsContainer and addonIconsContainer:GetParent() ~= MinimapCluster and addonIconsContainer:GetParent() ~= titleBarFrame then
    addonIconsContainer:SetAlpha(alpha)
  end
end

local function getBlizzardPlayerCoords()
  if MinimapCluster and MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords then
    return MinimapCluster.MinimapContainer.PlayerCoords
  end
  if MinimapCluster and MinimapCluster.PlayerCoords then
    return MinimapCluster.PlayerCoords
  end
  if _G.Minimap and _G.Minimap.PlayerCoords then
    return _G.Minimap.PlayerCoords
  end
  if _G.PlayerCoords then
    return _G.PlayerCoords
  end
  return nil
end

local function restoreCoordinates()
  local coords = getBlizzardPlayerCoords()
  if not coords then return end

  if coords.slackHacksRealSetPoint then
    coords.SetPoint = coords.slackHacksRealSetPoint
    coords.ClearAllPoints = coords.slackHacksRealClearAllPoints
    coords.slackHacksRealSetPoint = nil
    coords.slackHacksRealClearAllPoints = nil
  end

  if savedCoordsState then
    if savedCoordsState.parent then
      coords:SetParent(savedCoordsState.parent)
    end
    coords:SetFrameStrata(savedCoordsState.strata)
    coords:SetFrameLevel(savedCoordsState.level)
    coords:ClearAllPoints()
    for _, a in ipairs(savedCoordsState.anchors) do
      coords:SetPoint(a.point, a.relativeTo, a.relativePoint, a.x, a.y)
    end
    savedCoordsState = nil
  end
end

local function applyCoordinates()
  if not isModuleEnabled() then return end
  local coords = getBlizzardPlayerCoords()
  if not coords then return end

  if settings().shape == "square" then
    if not savedCoordsState then
      local ok, numPoints = pcall(coords.GetNumPoints, coords)
      local anchors = {}
      if ok and numPoints then
        for i = 1, numPoints do
          local pOk, point, relativeTo, relativePoint, x, y = pcall(coords.GetPoint, coords, i)
          if pOk and point then
            table.insert(anchors, { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y })
          end
        end
      end
      savedCoordsState = {
        parent = coords:GetParent(),
        level = coords:GetFrameLevel(),
        strata = coords:GetFrameStrata(),
        anchors = anchors,
      }
    end

    if not coords.slackHacksRealSetPoint then
      coords.slackHacksRealSetPoint = coords.SetPoint
      coords.slackHacksRealClearAllPoints = coords.ClearAllPoints
      coords.SetPoint = function() end
      coords.ClearAllPoints = function() end
    end

    coords:SetParent(_G.Minimap)
    coords:SetFrameStrata(_G.Minimap:GetFrameStrata())
    coords:SetFrameLevel(_G.Minimap:GetFrameLevel() + 5)
    coords.slackHacksRealClearAllPoints(coords)
    coords.slackHacksRealSetPoint(coords, "BOTTOM", _G.Minimap, "BOTTOM", 0, 4)
  else
    restoreCoordinates()
  end
end

local function getZoneTextButton()
  return (MinimapCluster and MinimapCluster.ZoneTextButton) or _G.MinimapZoneTextButton
end

local function applyZoneText()
  if not isModuleEnabled() then return end
  local mm = settings()
  local zoneButton = getZoneTextButton()
  setShownSafely(zoneButton, mm.showZoneText)
end

local function applyClock()
  if not isModuleEnabled() then return end
  setShownSafely(TimeManagerClockButton, settings().showClock)
end

local function applyCalendar()
  if not isModuleEnabled() then return end
  setShownSafely(GameTimeFrame, settings().showCalendar)
end

--- MinimapCluster.DielFrame is the oversized day/night ("diel" = 24-hour cycle) sun/moon icon shown on
--- Classic/Forever's minimap; it has no counterpart shown on Retail's minimap.
local function applyDielFrame()
  if not isModuleEnabled() then return end
  local mm = settings()
  local shown = true
  if mm.shape == "square" then
    shown = false -- doesn't fit the title bar; always hidden there
  elseif not isRetail() and mm.hideDiel then
    shown = false
  end
  setShownSafely(MinimapCluster and MinimapCluster.DielFrame, shown)
end

local function applyTracking()
  if not isModuleEnabled() then return end
  setShownSafely(MinimapCluster and MinimapCluster.Tracking, settings().showTracking)
end

local function applyTrackingCVar()
  if not isModuleEnabled() then return end
  if settings().showAllMinimapTracking then
    ensureCVar("minimapTrackingShowAll", 1) -- Show all minimap tracking options (including turning off target tracking!)
  else
    ensureCVar("minimapTrackingShowAll", GetCVarDefault("minimapTrackingShowAll"))
  end
end

local function applyExtraButtons()
  if not isModuleEnabled() then return end
  local isSquare = settings().shape == "square"
  local hideExtra = isSquare or settings().hideExtraButtons
  local mail = getMailButton()
  local crafting = getCraftingOrderButton()

  for _, button in ipairs(extraButtons()) do
    if button == mail or button == crafting then
      if hideExtra and not isSquare then
        setShownSafely(button, false)
      end
      -- In square mode, mail & crafting order show dynamically when they have active mail/orders
    elseif hideExtra then
      setShownSafely(button, false)
    else
      setShownSafely(button, true)
    end
  end
end

--- Same nine-slice border art used by many Blizzard windows, but the plain rectangular layout (no
--- portrait icon/title notch cut into the top-left corner like the Spellbook's own frame has).
local function createSquareBorder()
  if squareBorderFrame then return squareBorderFrame end
  local frame = CreateFrame("Frame", "SlackHacksMinimapSquareBorder", MinimapCluster or _G.Minimap)
  frame.layoutType = "ButtonFrameTemplateNoPortrait"
  frame:SetFrameStrata(_G.Minimap:GetFrameStrata())
  frame:SetFrameLevel(math.max(1, _G.Minimap:GetFrameLevel() - 1))
  frame:SetPoint("TOPLEFT", _G.Minimap, "TOPLEFT", -4, 4)
  frame:SetPoint("BOTTOMRIGHT", _G.Minimap, "BOTTOMRIGHT", 4, -4)
  CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
  squareBorderFrame = frame
  return frame
end

local function updateEditModeSelectionBounds()
  if not (MinimapCluster and MinimapCluster.Selection) then return end
  if not isModuleEnabled() then return end
  local mm = settings()
  if mm.shape == "square" then
    local border = createSquareBorder()
    if border then
      MinimapCluster.Selection:ClearAllPoints()
      MinimapCluster.Selection:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
      MinimapCluster.Selection:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    end
  else
    MinimapCluster.Selection:ClearAllPoints()
    MinimapCluster.Selection:SetAllPoints(MinimapCluster)
  end
end

local function applyBorder()
  if not isModuleEnabled() then return end
  local mm = settings()
  local isSquare = mm.shape == "square"
  if MinimapBackdrop then
    MinimapBackdrop:SetAlpha((not isSquare and mm.showBorder) and 1 or 0)
  end
  if isSquare then
    local border = createSquareBorder()
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", _G.Minimap, "TOPLEFT", -4, 4)
    border:SetPoint("BOTTOMRIGHT", _G.Minimap, "BOTTOMRIGHT", 4, -4)
    border:SetShown(mm.showBorder)
  elseif squareBorderFrame then
    squareBorderFrame:Hide()
  end
  updateEditModeSelectionBounds()
end

local TITLE_BAR_HEIGHT = 18
local TITLE_BAR_ICON_SCALE = 0.7
local TITLE_BAR_CLOCK_SCALE = 1.1 -- the clock's text/frame proportions read as too small at the icon scale

--- Sits in the visual banner area of the square border, hosting the zone text (left) and shrunk
--- minimap icons (right) in square mode. Parented to the minimap itself (not the border) so it isn't
--- hidden when "Show Border" is off. Anchored just inside the border's own box near its top edge --
--- matching Blizzard's own TitleContainer convention (PortraitFrameBaseTemplate/DefaultPanelBaseTemplate
--- anchor their title text at y=-1 relative to the frame box; the banner artwork itself bleeds upward
--- past that box via the nine-slice corner atlas's own y offset, so the box's top edge is already where
--- the readable part of the banner sits, not further above it).
--- Frame level 510 matches Blizzard's own PortraitFrameTemplate TitleContainer convention: the
--- NineSlicePanelTemplate border art is hardcoded to level 500, so 510 is what actually draws above it.
local function createTitleBar()
  if titleBarFrame then return titleBarFrame end
  local border = createSquareBorder()
  local frame = CreateFrame("Frame", "SlackHacksMinimapTitleBar", MinimapCluster or _G.Minimap)
  frame:SetHeight(TITLE_BAR_HEIGHT)
  frame:SetPoint("TOPLEFT", border, "TOPLEFT", 12, -2)
  frame:SetPoint("TOPRIGHT", border, "TOPRIGHT", -12, -2)
  frame:SetFrameStrata(_G.Minimap:GetFrameStrata())
  frame:SetFrameLevel(510)

  -- A shared wrapper so every repositioned icon anchors to the same reference frame (same strata/level
  -- as the bar itself) instead of each one separately guessing at the bar's own edge.
  local iconRow = CreateFrame("Frame", "SlackHacksMinimapTitleBarIcons", frame)
  iconRow:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  iconRow:SetSize(1, TITLE_BAR_HEIGHT)
  iconRow:SetFrameStrata(frame:GetFrameStrata())
  iconRow:SetFrameLevel(510)
  titleBarIconRow = iconRow

  titleBarFrame = frame
  return frame
end

local function createAddonIconsContainer()
  if addonIconsContainer then return addonIconsContainer end
  local container = CreateFrame("Frame", "SlackHacksMinimapAddonIconsContainer", titleBarFrame or MinimapCluster or UIParent)
  container:SetHeight(TITLE_BAR_HEIGHT)
  container:SetFrameStrata("HIGH")
  container:SetFrameLevel(520)
  container:Hide()
  addonIconsContainer = container
  return container
end

local function isRegionMouseOver(region)
  if not region or not region.IsShown or not region:IsShown() then return false end
  local ok, result = pcall(function()
    if region.IsMouseOver then
      return region:IsMouseOver()
    elseif MouseIsOver then
      return MouseIsOver(region)
    end
    return false
  end)
  return ok and (result == true)
end

local function isMinimapHovered()
  if isRegionMouseOver(_G.Minimap)
     or isRegionMouseOver(titleBarFrame)
     or isRegionMouseOver(squareBorderFrame)
     or isRegionMouseOver(addonIconsContainer)
     or isRegionMouseOver(MinimapCluster) then
    return true
  end
  local zoneButton = getZoneTextButton()
  if isRegionMouseOver(zoneButton) or isRegionMouseOver(titleBarZoneFallbackButton) then
    return true
  end
  if isRegionMouseOver(GameTimeFrame)
     or isRegionMouseOver(MinimapCluster and MinimapCluster.Tracking)
     or isRegionMouseOver(AddonCompartmentFrame) then
    return true
  end
  if addonButtons then
    for _, btn in ipairs(addonButtons) do
      if isRegionMouseOver(btn) then return true end
    end
  end
  return false
end

local function setAddonContainerHovered(hovered)
  if not addonIconsContainer then return end
  local mm = settings()
  if mm.shape ~= "square" then
    addonIconsContainer:Hide()
    if hoverCheckTicker then
      hoverCheckTicker:Cancel()
      hoverCheckTicker = nil
    end
    return
  end

  if hovered then
    addonIconsContainer:Show()
    if not hoverCheckTicker then
      hoverCheckTicker = C_Timer.NewTicker(0.1, function()
        if not isMinimapHovered() then
          setAddonContainerHovered(false)
        end
      end)
    end
  else
    addonIconsContainer:Hide()
    if hoverCheckTicker then
      hoverCheckTicker:Cancel()
      hoverCheckTicker = nil
    end
  end
end

local function updateAddonContainerVisibility()
  if isMinimapHovered() then
    setAddonContainerHovered(true)
  else
    setAddonContainerHovered(false)
  end
end

local function hookHoverFrame(frame)
  if not frame or frame.slackHacksHoverHooked then return end
  frame.slackHacksHoverHooked = true
  if frame.HookScript then
    frame:HookScript("OnEnter", function()
      setAddonContainerHovered(true)
    end)
    frame:HookScript("OnLeave", function()
      C_Timer.After(0.05, function()
        if not isMinimapHovered() then
          setAddonContainerHovered(false)
        end
      end)
    end)
  end
end

local function getOrCreateZoneButton(parent)
  local btn = getZoneTextButton()
  if btn then return btn end
  if not titleBarZoneFallbackButton then
    local fallback = CreateFrame("Button", "SlackHacksMinimapZoneButtonFallback", parent)
    local text = fallback:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", fallback, "LEFT", 0, 0)
    text:SetPoint("RIGHT", fallback, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    fallback.Text = text
    fallback:SetScript("OnClick", function()
      if ToggleWorldMap then ToggleWorldMap() end
    end)
    fallback:SetScript("OnEnter", function(self)
      if C_GameRules and C_GameRules.IsGameRuleActive and C_GameRules.IsGameRuleActive(Enum.GameRule.WorldMapDisabled) then
        return
      end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      local pvpType, isSubZonePvP, factionName = C_PvP and C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo()
      if Minimap_SetTooltip then
        Minimap_SetTooltip(pvpType, factionName)
      end
      if MicroButtonTooltipText and WORLDMAP_BUTTON then
        GameTooltip:AddLine(MicroButtonTooltipText(WORLDMAP_BUTTON, "TOGGLEWORLDMAP"))
      elseif WORLDMAP_BUTTON then
        GameTooltip:AddLine(WORLDMAP_BUTTON)
      end
      GameTooltip:Show()
    end)
    fallback:SetScript("OnLeave", function()
      GameTooltip_Hide()
    end)
    titleBarZoneFallbackButton = fallback
  end
  return titleBarZoneFallbackButton
end

local function updateZoneText()
  local fs = _G.MinimapZoneText or (titleBarZoneFallbackButton and titleBarZoneFallbackButton.Text)
  if fs and GetMinimapZoneText then
    fs:SetText(GetMinimapZoneText() or "")
  end
  if Minimap_Update then
    pcall(Minimap_Update)
  end
end

local CYCLE_BORDER_ATLASES = {
  "UI-HUD-Minimap-Frame-Cycle",
  "ui-hud-minimap-frame-cycle",
  "UI-HUD-Minimap-Frame-Cycle-c60",
  "ui-hud-minimap-frame-cycle-c60",
}

local function getCycleBorderAtlas()
  if MinimapCluster and MinimapCluster.DielFrame then
    local ok, regions = pcall(function() return { MinimapCluster.DielFrame:GetRegions() } end)
    if ok and regions then
      for _, r in ipairs(regions) do
        if r:IsObjectType("Texture") and r.GetAtlas then
          local a = r:GetAtlas()
          if a and a ~= "" and not a:lower():find("daycycle") and not a:lower():find("nightcycle") then
            return a
          end
        end
      end
    end
  end

  if C_Texture and C_Texture.GetAtlasInfo then
    for _, name in ipairs(CYCLE_BORDER_ATLASES) do
      if C_Texture.GetAtlasInfo(name) then
        return name
      end
    end
    if C_Texture.GetAtlasInfo("ui-hud-minimap-button") then
      return "ui-hud-minimap-button"
    end
  end

  return "UI-HUD-Minimap-Frame-Cycle"
end

local function findButtonBorder(button)
  if not button then return nil end
  if button.border and button.border.SetAtlas then
    return button.border
  end
  if button.Border and button.Border.SetAtlas then
    return button.Border
  end
  local name = button.GetName and button:GetName()
  if name and _G[name .. "Border"] and _G[name .. "Border"].SetAtlas then
    return _G[name .. "Border"]
  end
  local ok, regions = pcall(function() return { button:GetRegions() } end)
  if ok and regions then
    for _, region in ipairs(regions) do
      if region:IsObjectType("Texture") then
        local tex = region:GetTexture()
        if tex == 136430 or (type(tex) == "string" and tex:find("MiniMap%-TrackingBorder")) then
          return region
        end
      end
    end
  end
  return nil
end

local function getOrCreateButtonBorder(button)
  local border = findButtonBorder(button)
  if border then return border end
  local created = button:CreateTexture(nil, "OVERLAY")
  button.slackHacksCreatedBorder = created
  return created
end

local function applyCycleBorder(button)
  if settings().shape ~= "square" then return end
  local border = getOrCreateButtonBorder(button)
  if not border then return end

  local atlas = getCycleBorderAtlas()
  if border.SetAtlas then
    border:SetAtlas(atlas)
  end
  border:SetTexCoord(0, 1, 0, 1)

  local btnW = button:GetWidth()
  local size = (btnW and btnW > 10) and btnW or 32

  border:ClearAllPoints()
  border:SetPoint("CENTER", button, "CENTER", 0, 0)
  border:SetSize(size, size)
  border:Show()
end

--- Mappy-style button manipulation: save initial anchors, parent, scale, strata, and level.
local function saveButtonState(button)
  if button.slackHacksSaved then return end
  local saved = {
    anchors = {},
    parent = button:GetParent(),
    scale = button:GetScale(),
    strata = button:GetFrameStrata(),
    level = button:GetFrameLevel(),
  }
  local ok, numPoints = pcall(button.GetNumPoints, button)
  if ok and numPoints then
    for i = 1, numPoints do
      local pOk, point, relativeTo, relativePoint, x, y = pcall(button.GetPoint, button, i)
      if pOk and point then
        saved.anchors[point] = { relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
      end
    end
  end

  local border = findButtonBorder(button)
  if border then
    local borderSaved = {
      frame = border,
      texture = border:GetTexture(),
      atlas = border.GetAtlas and border:GetAtlas(),
      width = border:GetWidth(),
      height = border:GetHeight(),
      points = {},
    }
    local bOk, bNumPoints = pcall(border.GetNumPoints, border)
    if bOk and bNumPoints then
      for i = 1, bNumPoints do
        local pOk, point, relativeTo, relativePoint, x, y = pcall(border.GetPoint, border, i)
        if pOk and point then
          table.insert(borderSaved.points, { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y })
        end
      end
    end
    saved.border = borderSaved
  end

  if button == getZoneTextButton() then
    local fs = (button.GetFontString and button:GetFontString()) or _G.MinimapZoneText
    if fs then
      local fsSaved = {
        frame = fs,
        fontObject = fs:GetFontObject(),
        justifyH = fs:GetJustifyH(),
        points = {},
      }
      if fs.CanWordWrap then
        fsSaved.wordWrap = fs:CanWordWrap()
      end
      local fsOk, fsNumPoints = pcall(fs.GetNumPoints, fs)
      if fsOk and fsNumPoints then
        for i = 1, fsNumPoints do
          local pOk, point, relativeTo, relativePoint, x, y = pcall(fs.GetPoint, fs, i)
          if pOk and point then
            table.insert(fsSaved.points, { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y })
          end
        end
      end
      saved.fontString = fsSaved
    end
  end

  button.slackHacksSaved = saved
end

local function restoreButtonState(button)
  local saved = button.slackHacksSaved
  if not saved then return end

  if saved.parent then
    button:SetParent(saved.parent)
  end
  if saved.scale then
    button:SetScale(saved.scale)
  end
  if saved.strata then
    button:SetFrameStrata(saved.strata)
  end
  if saved.level then
    button:SetFrameLevel(saved.level)
  end
  button:ClearAllPoints()
  for point, info in pairs(saved.anchors) do
    if info.relativeTo then
      button:SetPoint(point, info.relativeTo, info.relativePoint, info.x, info.y)
    else
      button:SetPoint(point, info.x, info.y)
    end
  end

  if saved.fontString and saved.fontString.frame then
    local fs = saved.fontString.frame
    fs:ClearAllPoints()
    for _, p in ipairs(saved.fontString.points) do
      if p.relativeTo then
        fs:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
      else
        fs:SetPoint(p.point, p.x, p.y)
      end
    end
    if saved.fontString.fontObject then
      fs:SetFontObject(saved.fontString.fontObject)
    end
    if saved.fontString.justifyH then
      fs:SetJustifyH(saved.fontString.justifyH)
    end
    if saved.fontString.wordWrap ~= nil and fs.SetWordWrap then
      fs:SetWordWrap(saved.fontString.wordWrap)
    end
  end

  if saved.border then
    local border = saved.border.frame or findButtonBorder(button)
    if border then
      border:ClearAllPoints()
      for _, p in ipairs(saved.border.points) do
        if p.relativeTo then
          border:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
        else
          border:SetPoint(p.point, p.x, p.y)
        end
      end
      if saved.border.width and saved.border.height then
        border:SetSize(saved.border.width, saved.border.height)
      end
      if saved.border.atlas and saved.border.atlas ~= "" and border.SetAtlas then
        border:SetAtlas(saved.border.atlas)
      elseif saved.border.texture then
        border:SetTexture(saved.border.texture)
      end
      border:SetTexCoord(0, 1, 0, 1)
    end
  end

  if button.slackHacksCreatedBorder then
    button.slackHacksCreatedBorder:Hide()
    button.slackHacksCreatedBorder:SetTexture(nil)
    button.slackHacksCreatedBorder = nil
  end

  button.slackHacksSaved = nil
end

--- Mappy-style hooks: when Blizzard or third-party addons call SetPoint, ClearAllPoints,
--- SetFrameStrata, or SetFrameLevel while stacked, record their intent into saved state
--- rather than letting them fight or displace the title bar layout.
local function buttonSaveSetPoint(self, point, relativeTo, relativePoint, x, y)
  if not self.slackHacksSaved then return end
  self.slackHacksSaved.anchors[point] = {
    relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y,
  }
end

local function buttonSaveClearAllPoints(self)
  if not self.slackHacksSaved then return end
  wipe(self.slackHacksSaved.anchors)
end

local function buttonSaveSetFrameStrata(self, strata)
  if not self.slackHacksSaved then return end
  self.slackHacksSaved.strata = strata
end

local function buttonSaveSetFrameLevel(self, level)
  if not self.slackHacksSaved then return end
  self.slackHacksSaved.level = level
end

local function scheduleTitleBarLayout()
  if layoutPending then return end
  layoutPending = true
  C_Timer.After(0, function()
    layoutPending = false
    if applyTitleBarLayout then applyTitleBarLayout() end
  end)
end

local function onButtonVisibilityChanged()
  if settings().shape == "square" then
    scheduleTitleBarLayout()
  end
end

local function enableButtonStacking(button, enable)
  if enable then
    if not button.slackHacksRealSetPoint then
      saveButtonState(button)

      button.slackHacksRealSetPoint = button.SetPoint
      button.slackHacksRealClearAllPoints = button.ClearAllPoints
      button.slackHacksRealSetFrameStrata = button.SetFrameStrata
      button.slackHacksRealSetFrameLevel = button.SetFrameLevel

      button.SetPoint = buttonSaveSetPoint
      button.ClearAllPoints = buttonSaveClearAllPoints
      button.SetFrameStrata = buttonSaveSetFrameStrata
      button.SetFrameLevel = buttonSaveSetFrameLevel

      if not button.slackHacksHooksInstalled then
        button:HookScript("OnHide", onButtonVisibilityChanged)
        button:HookScript("OnShow", onButtonVisibilityChanged)
        button.slackHacksHooksInstalled = true
      end
    end
    button.slackHacksStackingActive = true
  else
    if button.slackHacksRealSetPoint then
      button.SetPoint = button.slackHacksRealSetPoint
      button.ClearAllPoints = button.slackHacksRealClearAllPoints
      button.SetFrameStrata = button.slackHacksRealSetFrameStrata
      button.SetFrameLevel = button.slackHacksRealSetFrameLevel

      button.slackHacksRealSetPoint = nil
      button.slackHacksRealClearAllPoints = nil
      button.slackHacksRealSetFrameStrata = nil
      button.slackHacksRealSetFrameLevel = nil
      button.slackHacksStackingActive = false

      restoreButtonState(button)
    end
  end
end

local function registerButton(button)
  if not button or registeredButtonsByFrame[button] then return end
  registeredButtonsByFrame[button] = true
  table.insert(registeredButtons, button)
  if not button.slackHacksHooksInstalled then
    button:HookScript("OnHide", onButtonVisibilityChanged)
    button:HookScript("OnShow", onButtonVisibilityChanged)
    button.slackHacksHooksInstalled = true
  end
  hookHoverFrame(button)
end

local function registerAddonButton(button)
  if not button or addonButtonsByFrame[button] then return end
  addonButtonsByFrame[button] = true
  table.insert(addonButtons, button)
  registerButton(button)
end

local function disableAllStacking()
  for _, button in ipairs(registeredButtons) do
    enableButtonStacking(button, false)
  end
  wipe(registeredButtons)
  wipe(registeredButtonsByFrame)
  wipe(addonButtons)
  wipe(addonButtonsByFrame)

  local zoneButton = getZoneTextButton()
  if zoneButton then
    enableButtonStacking(zoneButton, false)
  end
  if titleBarZoneFallbackButton then
    titleBarZoneFallbackButton:Hide()
  end
  if addonIconsContainer then
    addonIconsContainer:Hide()
  end
  if hoverCheckTicker then
    hoverCheckTicker:Cancel()
    hoverCheckTicker = nil
  end
end

--- Mappy's recursive frame level setter: ensures child icons/textures shift frame level
--- along with the button so no child elements draw behind the nine-slice border (level 500).
local function setFrameLevelRecursive(frame, level)
  local oldLevel = frame:GetFrameLevel()
  local offset = level - oldLevel
  if offset == 0 then return end

  if frame.slackHacksRealSetFrameLevel then
    frame.slackHacksRealSetFrameLevel(frame, level)
  else
    frame:SetFrameLevel(level)
  end

  local ok, children = pcall(function() return { frame:GetChildren() } end)
  if ok and children then
    for _, child in ipairs(children) do
      local childLevel = child:GetFrameLevel() + offset
      if childLevel < 1 then childLevel = 1 end
      setFrameLevelRecursive(child, childLevel)
    end
  end
end

local function setFrameStrataSafe(frame, strata)
  if frame.slackHacksRealSetFrameStrata then
    frame.slackHacksRealSetFrameStrata(frame, strata)
  else
    frame:SetFrameStrata(strata)
  end
end

local function isAnchoredToFrame(frame, target)
  if not frame or not target then return false end
  local ok, numPoints = pcall(frame.GetNumPoints, frame)
  if not ok or not numPoints then return false end
  for i = 1, numPoints do
    local pOk, _, relativeTo = pcall(frame.GetPoint, frame, i)
    if pOk and (relativeTo == target or (type(relativeTo) == "string" and target.GetName and relativeTo == target:GetName())) then
      return true
    end
  end
  return false
end

local function getIgnoreFramesMap()
  local ignore = {
    Minimap = true,
    MinimapBackdrop = true,
    MinimapCluster = true,
    MiniMapPing = true,
    MinimapToggleButton = true,
    MinimapZoneTextButton = true,
    TimeManagerClockButton = true,
    GameTimeFrame = true,
    MiniMapBattlefieldFrame = true,
    MiniMapMeetingStoneFrame = true,
    MiniMapVoiceChatFrame = true,
    FeedbackUIButton = true,
    MiniMapLFGFrame = true,
    GuildInstanceDifficulty = true,
    ExpansionLandingPageMinimapButton = true,
    AddonCompartmentFrame = true,
    CT_RASetsFrame = true,
    SlackHacksMinimapSquareBorder = true,
    SlackHacksMinimapTitleBar = true,
    SlackHacksMinimapTitleBarIcons = true,
    SlackHacksMinimapAddonIconsContainer = true,
    SlackHacksMinimapOptionsDialog = true,
  }
  for name in pairs(ignore) do
    if _G[name] then ignore[_G[name]] = true end
  end
  if MinimapCluster then
    ignore[MinimapCluster] = true
    if MinimapCluster.ZoneTextButton then ignore[MinimapCluster.ZoneTextButton] = true end
    if MinimapCluster.Tracking then ignore[MinimapCluster.Tracking] = true end
    if MinimapCluster.DielFrame then ignore[MinimapCluster.DielFrame] = true end
    if MinimapCluster.InstanceDifficulty then ignore[MinimapCluster.InstanceDifficulty] = true end
    if MinimapCluster.BorderTop then ignore[MinimapCluster.BorderTop] = true end
    if MinimapCluster.MinimapContainer then ignore[MinimapCluster.MinimapContainer] = true end
    if MinimapCluster.IndicatorFrame then
      ignore[MinimapCluster.IndicatorFrame] = true
      if MinimapCluster.IndicatorFrame.MailFrame then ignore[MinimapCluster.IndicatorFrame.MailFrame] = true end
      if MinimapCluster.IndicatorFrame.CraftingOrderFrame then ignore[MinimapCluster.IndicatorFrame.CraftingOrderFrame] = true end
    end
  end
  if _G.Minimap then
    ignore[_G.Minimap] = true
    if _G.Minimap.ZoomIn then ignore[_G.Minimap.ZoomIn] = true end
    if _G.Minimap.ZoomOut then ignore[_G.Minimap.ZoomOut] = true end
    if _G.Minimap.ZoomHitArea then ignore[_G.Minimap.ZoomHitArea] = true end
  end
  if squareBorderFrame then ignore[squareBorderFrame] = true end
  if titleBarFrame then ignore[titleBarFrame] = true end
  if titleBarIconRow then ignore[titleBarIconRow] = true end
  if addonIconsContainer then ignore[addonIconsContainer] = true end
  local blizzCoords = getBlizzardPlayerCoords()
  if blizzCoords then ignore[blizzCoords] = true end
  return ignore
end

local function isCandidateAddonButton(frame, anchoredTo, ignoreMap)
  if not frame then return false end
  local ok, forbidden = pcall(frame.IsForbidden, frame)
  if not ok or forbidden then return false end
  if frame.GetObjectType and frame:GetObjectType() == "Model" then return false end
  local okW, width = pcall(frame.GetWidth, frame)
  local okH, height = pcall(frame.GetHeight, frame)
  if not okW or not okH or not width or not height then return false end
  if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then return false end
  if width < 14 or width > 64 or math.abs(width - height) > 4 then return false end
  local name = frame:GetName()
  if name and ignoreMap[name] then return false end
  if ignoreMap[frame] or registeredButtonsByFrame[frame] then return false end
  if anchoredTo and not isAnchoredToFrame(frame, anchoredTo) then return false end
  return true
end

local function scanAddonButtons(parent, anchoredTo, ignoreMap)
  if not parent or not parent.GetChildren then return end
  local ok, children = pcall(function() return { parent:GetChildren() } end)
  if not ok or not children then return end
  for _, child in ipairs(children) do
    if isCandidateAddonButton(child, anchoredTo, ignoreMap) then
      registerAddonButton(child)
    end
  end
  if not anchoredTo then
    scanAddonButtons(UIParent, parent, ignoreMap)
  end
end

local function discoverAddonButtons()
  local ignoreMap = getIgnoreFramesMap()
  local otherAddons = { "CT_RASets_Button", "MBB_MinimapButtonFrame" }
  for _, name in ipairs(otherAddons) do
    local btn = _G[name]
    if btn and not registeredButtonsByFrame[btn] then
      registerAddonButton(btn)
    end
  end
  scanAddonButtons(MinimapCluster, nil, ignoreMap)
  scanAddonButtons(MinimapBackdrop, nil, ignoreMap)
  scanAddonButtons(_G.Minimap, nil, ignoreMap)
  if MinimapCluster and MinimapCluster.MinimapContainer then
    scanAddonButtons(MinimapCluster.MinimapContainer, nil, ignoreMap)
  end
end

local function isButtonShown(button)
  if not button then return false end
  local mail = getMailButton()
  local crafting = getCraftingOrderButton()
  if settings().shape == "square" then
    if button == mail or button == crafting then
      return button:IsShown()
    end
  else
    if settings().hideExtraButtons and (button == mail or button == crafting) then
      return false
    end
  end
  if not isRetail() and button == crafting then
    return false
  end
  if button == (MinimapCluster and MinimapCluster.InstanceDifficulty) then
    local _, instanceType, difficulty = GetInstanceInfo()
    if not difficulty or not (instanceType == "raid" or instanceType == "party" or instanceType == "scenario") then
      return false
    end
  end
  return button:IsShown()
end

--- Builds the list of buttons for the permanent title bar flow.
--- Right-to-left layout order: Clock, Mail, Crafting Orders. All other standard icons are in the hover container.
local function getTitleBarFlowButtons()
  local list = {}

  -- 1. Clock (rightmost)
  if TimeManagerClockButton then
    table.insert(list, TimeManagerClockButton)
  end

  -- 2. Mail (left of Clock, only shown when mail exists)
  local mail = getMailButton()
  if mail then
    table.insert(list, mail)
  end

  -- 3. Crafting Orders (left of Mail, only shown when orders exist)
  local crafting = getCraftingOrderButton()
  if crafting then
    table.insert(list, crafting)
  end

  return list
end

--- Positions the unified zone text button on the left side of the title bar, stretching
--- from the left edge up to the right-side icons, preserving world map click and tooltip details.
local function layoutTitleBarZoneButton(previous)
  if not titleBarFrame then return end
  local mm = settings()
  local zoneButton = getOrCreateZoneButton(titleBarFrame)
  if not zoneButton then return end

  if not mm.showZoneText then
    zoneButton:Hide()
    return
  end

  registerButton(zoneButton)
  enableButtonStacking(zoneButton, true)
  zoneButton:SetParent(MinimapCluster or _G.Minimap)
  zoneButton:SetScale(1)
  setFrameStrataSafe(zoneButton, titleBarFrame:GetFrameStrata())
  setFrameLevelRecursive(zoneButton, titleBarFrame:GetFrameLevel() + 2)

  if not zoneButton.tooltipText and MicroButtonTooltipText and WORLDMAP_BUTTON then
    zoneButton.tooltipText = MicroButtonTooltipText(WORLDMAP_BUTTON, "TOGGLEWORLDMAP")
  end

  local fs = (zoneButton.GetFontString and zoneButton:GetFontString()) or _G.MinimapZoneText or zoneButton.Text
  if fs then
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", zoneButton, "LEFT", 0, 0)
    fs:SetPoint("RIGHT", zoneButton, "RIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then
      fs:SetWordWrap(false)
    end
    fs:SetFontObject("GameFontNormalSmall")
  end

  zoneButton.slackHacksRealClearAllPoints(zoneButton)
  zoneButton.slackHacksRealSetPoint(zoneButton, "LEFT", titleBarFrame, "LEFT", 0, 0)
  zoneButton.slackHacksRealSetPoint(zoneButton, "TOP", titleBarFrame, "TOP", 0, 0)
  zoneButton.slackHacksRealSetPoint(zoneButton, "BOTTOM", titleBarFrame, "BOTTOM", 0, 0)
  if previous then
    zoneButton.slackHacksRealSetPoint(zoneButton, "RIGHT", previous, "LEFT", -4, 0)
  else
    zoneButton.slackHacksRealSetPoint(zoneButton, "RIGHT", titleBarFrame, "RIGHT", 0, 0)
  end
  zoneButton:Show()
  updateZoneText()
end

--- Lays out icons hidden without hover (Addon Compartment, then third-party addon icons)
--- in a separate container frame with a HIGH frame strata.
--- Taken out of the title bar flow so it never clips or constrains the zone text button.
--- Only visible when hovering over the minimap.
local function layoutAddonIconsContainer(anchorRightTo)
  if not titleBarFrame then return end
  local container = createAddonIconsContainer()
  hookHoverFrame(container)

  container:ClearAllPoints()
  if anchorRightTo then
    container:SetPoint("RIGHT", anchorRightTo, "LEFT", -2, 0)
  else
    container:SetPoint("RIGHT", titleBarFrame, "RIGHT", 0, 0)
  end
  container:SetPoint("TOP", titleBarFrame, "TOP", 0, 0)
  container:SetPoint("BOTTOM", titleBarFrame, "BOTTOM", 0, 0)

  local hoverButtons = {}
  -- 1. Calendar (rightmost inside hover container)
  if GameTimeFrame then
    table.insert(hoverButtons, GameTimeFrame)
  end
  -- 2. Tracking (to the left of Calendar)
  if MinimapCluster and MinimapCluster.Tracking then
    table.insert(hoverButtons, MinimapCluster.Tracking)
  end
  -- 3. Addon Compartment (to the left of Tracking)
  if AddonCompartmentFrame then
    table.insert(hoverButtons, AddonCompartmentFrame)
  end
  -- 4. Various addon icons (to the left of Addon Compartment)
  for _, btn in ipairs(addonButtons) do
    if btn then table.insert(hoverButtons, btn) end
  end

  local totalWidth = 0
  local buttonGap = 2
  local previousHover = nil

  for _, button in ipairs(hoverButtons) do
    registerButton(button)
    if isButtonShown(button) then
      enableButtonStacking(button, true)
      button:SetParent(container)
      button:SetScale(TITLE_BAR_ICON_SCALE)
      setFrameStrataSafe(button, "HIGH")
      setFrameLevelRecursive(button, 521)
      button.slackHacksRealClearAllPoints(button)
      local isSubsequent = (previousHover ~= nil)
      if previousHover then
        button.slackHacksRealSetPoint(button, "RIGHT", previousHover, "LEFT", -buttonGap, 0)
      else
        button.slackHacksRealSetPoint(button, "RIGHT", container, "RIGHT", 0, 0)
      end
      previousHover = button

      local btnW = button:GetWidth()
      local scaledW = (btnW and btnW > 0 and btnW or 32) * TITLE_BAR_ICON_SCALE
      totalWidth = totalWidth + scaledW + (isSubsequent and buttonGap or 0)

      if addonButtonsByFrame[button] then
        applyCycleBorder(button)
      end
    end
  end

  container:SetWidth(math.max(1, totalWidth))

  updateAddonContainerVisibility()
end

--- Shrinks and lines up the minimap buttons along the right side of the title bar,
--- ordered right-to-left: Clock, standard icons, addon compartment. Third-party addon icons
--- are placed in the separate hover container.
local function layoutTitleBarIcons()
  local row = titleBarIconRow
  if not row then return end
  local buttons = getTitleBarFlowButtons()
  local previous = nil

  for _, button in ipairs(buttons) do
    registerButton(button)
    if isButtonShown(button) then
      enableButtonStacking(button, true)
      -- Mappy reparents to MinimapCluster so Blizzard internals (e.g. AddonCompartmentFrame) find their expected parent
      button:SetParent(MinimapCluster or _G.Minimap)
      button:SetScale(button == TimeManagerClockButton and TITLE_BAR_CLOCK_SCALE or TITLE_BAR_ICON_SCALE)
      setFrameStrataSafe(button, row:GetFrameStrata())
      setFrameLevelRecursive(button, row:GetFrameLevel() + 1)
      button.slackHacksRealClearAllPoints(button)
      if previous then
        button.slackHacksRealSetPoint(button, "RIGHT", previous, "LEFT", -2, 0)
      else
        button.slackHacksRealSetPoint(button, "RIGHT", row, "RIGHT", 0, 0)
      end
      previous = button
    end
  end

  layoutTitleBarZoneButton(previous)
  layoutAddonIconsContainer(previous)
end

applyTitleBarLayout = function()
  if not isModuleEnabled() then return end
  local mm = settings()
  if mm.shape ~= "square" then
    if titleBarFrame then titleBarFrame:Hide() end
    if addonIconsContainer then addonIconsContainer:Hide() end
    if hoverCheckTicker then
      hoverCheckTicker:Cancel()
      hoverCheckTicker = nil
    end
    if MinimapCluster then
      if origMinimapClusterLayout then
        MinimapCluster.Layout = origMinimapClusterLayout
      end
      if MinimapCluster.BorderTop then
        MinimapCluster.BorderTop:SetAlpha(1)
        MinimapCluster.BorderTop:Show()
      end
      if MinimapCluster.IndicatorFrame then
        MinimapCluster.IndicatorFrame:Show()
      end
      if MinimapCluster.GamepadButtons then
        MinimapCluster.GamepadButtons:Show()
      end
    end
    disableAllStacking()
    if addonScanTicker then
      addonScanTicker:Cancel()
      addonScanTicker = nil
    end
    updateEditModeSelectionBounds()
    return
  end

  -- Workaround from Mappy: disable MinimapCluster.Layout so Blizzard's layout code
  -- doesn't fight our button positions or error when children move.
  if MinimapCluster then
    if not origMinimapClusterLayout and MinimapCluster.Layout then
      origMinimapClusterLayout = MinimapCluster.Layout
    end
    MinimapCluster.Layout = function() end
    if MinimapCluster.BorderTop then
      MinimapCluster.BorderTop:SetAlpha(0)
      MinimapCluster.BorderTop:Hide()
    end
    if MinimapCluster.IndicatorFrame then
      MinimapCluster.IndicatorFrame:Hide()
    end
    if MinimapCluster.GamepadButtons then
      MinimapCluster.GamepadButtons:Hide()
    end
    if MinimapCluster.SetClipsChildren then
      MinimapCluster:SetClipsChildren(false)
    end
  end
  if _G.Minimap.SetClipsChildren then
    _G.Minimap:SetClipsChildren(false)
  end

  local bar = createTitleBar()
  bar:Show()
  hookHoverFrame(_G.Minimap)
  hookHoverFrame(titleBarFrame)
  hookHoverFrame(squareBorderFrame)
  hookHoverFrame(MinimapCluster)
  local zb = getZoneTextButton()
  if zb then hookHoverFrame(zb) end

  discoverAddonButtons()
  layoutTitleBarIcons()
  updateEditModeSelectionBounds()

  if not addonScanTicker then
    addonScanTicker = C_Timer.NewTicker(2, function()
      local currentMm = settings()
      if currentMm.shape ~= "square" then return end
      local prevCount = #addonButtons
      discoverAddonButtons()
      if #addonButtons ~= prevCount then
        scheduleTitleBarLayout()
      end
    end)
  end
end

local function applyMouseWheelZoom()
  if not isModuleEnabled() then return end
  _G.Minimap:EnableMouseWheel(settings().mouseWheelZoom ~= false)
end

function module:ApplyAll()
  if not (db and db.profile and db.profile.minimap and db.profile.minimap.enabled) then
    if self:IsEnabled() then
      self:Disable()
    end
    return
  end
  if not self:IsEnabled() then
    self:Enable()
    return
  end

  applyShape()
  applyAlpha()
  applyCoordinates()
  applyZoneText()
  applyClock()
  applyCalendar()
  applyDielFrame()
  applyTracking()
  applyTrackingCVar()
  applyExtraButtons()
  applyBorder()
  applyTitleBarLayout()
  applyMouseWheelZoom()
end
module.Refresh = module.ApplyAll

--=====================================================================
-- "SlackHacks Minimap Options" window, opened via Blizzard's Edit Mode
--=====================================================================

local function createOptionsDialog()
  local dialog = CreateFrame("Frame", "SlackHacksMinimapOptionsDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(320, 100) -- height is recalculated below once all controls are laid out
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

  CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate")

  local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  title:SetPoint("TOP", dialog, "TOP", 0, -16)
  title:SetText("SlackHacks Minimap Options")

  local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -2, -2)
  closeButton:SetScript("OnClick", function() dialog:Hide() end)

  local controls = {}

  local function addHeader(text, yOffset)
    local header = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, yOffset)
    header:SetText(text)
    return yOffset - 22
  end

  local function addDivider(yOffset)
    local divider = dialog:CreateTexture(nil, "ARTWORK")
    divider:SetSize(280, 8)
    divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
    divider:SetPoint("TOP", dialog, "TOP", 0, yOffset)
    return yOffset - 12
  end

  local function addCheckbox(label, getFunc, setFunc, yOffset, dependents)
    local cb = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, yOffset)
    cb.text:SetText(label)
    cb.text:SetFontObject("GameFontHighlight")
    local function updateDependents(checked)
      if dependents then
        for _, dep in ipairs(dependents) do dep:SetEnabled(checked) end
      end
    end
    cb:SetScript("OnClick", function(self)
      local checked = self:GetChecked()
      setFunc(checked)
      updateDependents(checked)
      module:ApplyAll()
    end)
    table.insert(controls, function()
      local checked = getFunc()
      cb:SetChecked(checked)
      updateDependents(checked)
    end)
    return cb, yOffset - 24
  end

  local function addSlider(label, minVal, maxVal, step, getFunc, setFunc, yOffset, formatFunc)
    local frame = CreateFrame("Frame", nil, dialog)
    frame:SetSize(280, 36)
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
      valText:SetText(formatFunc and formatFunc(val) or tostring(math.floor(val + 0.5)))
    end

    slider:SetScript("OnValueChanged", function(_, val)
      updateValue(val)
      setFunc(val)
      module:ApplyAll()
    end)

    table.insert(controls, function()
      local cur = getFunc() or minVal
      slider:SetValue(cur)
      updateValue(cur)
    end)

    frame.SetEnabled = function(_, enable) slider:SetEnabled(enable) end

    return frame, yOffset - 44
  end

  local dropdownCounter = 0
  local function addDropdown(label, options, order, getFunc, setFunc, yOffset)
    local frame = CreateFrame("Frame", nil, dialog)
    frame:SetSize(280, 46)
    frame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 4, yOffset)

    local lbl = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, 0)
    lbl:SetText(label)

    dropdownCounter = dropdownCounter + 1
    local dropdown = CreateFrame("Frame", "SlackHacksMinimapOptionsDropdown" .. dropdownCounter, frame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(dropdown, 240)

    local function onSelect(_, value)
      setFunc(value)
      UIDropDownMenu_SetSelectedValue(dropdown, value)
      UIDropDownMenu_SetText(dropdown, options[value])
      module:ApplyAll()
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
      for _, value in ipairs(order) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = options[value]
        info.value = value
        info.func = onSelect
        info.checked = (getFunc() == value)
        UIDropDownMenu_AddButton(info, level)
      end
    end)

    frame.SetEnabled = function(_, enable)
      if enable then UIDropDownMenu_EnableDropDown(dropdown) else UIDropDownMenu_DisableDropDown(dropdown) end
    end

    table.insert(controls, function()
      local cur = getFunc()
      UIDropDownMenu_SetSelectedValue(dropdown, cur)
      UIDropDownMenu_SetText(dropdown, options[cur] or cur)
    end)

    return frame, yOffset - 46
  end

  local percentFormat = function(v) return math.floor(v + 0.5) .. "%" end

  local curY = -46
  _, curY = addCheckbox("Enable Minimap Enhancements",
    function() return db.profile.minimap.enabled end,
    function(v) db.profile.minimap.enabled = v end,
    curY)

  curY = addDivider(curY - 2)
  curY = addHeader("Appearance", curY)
  _, curY = addDropdown("Shape", { circle = "Round", square = "Square" }, { "circle", "square" },
    function() return db.profile.minimap.shape end,
    function(v) db.profile.minimap.shape = v end,
    curY)
  _, curY = addCheckbox("Show Border",
    function() return db.profile.minimap.showBorder end,
    function(v) db.profile.minimap.showBorder = v end,
    curY)

  curY = addDivider(curY - 2)
  curY = addHeader("Opacity", curY)
  curY = select(2, addSlider("Opacity", 0, 100, 1,
    function() return db.profile.minimap.alpha end,
    function(v) db.profile.minimap.alpha = v end,
    curY, percentFormat))
  local fadeDependents = {}
  local fadeCb
  fadeCb, curY = addCheckbox("Fade Based on Combat / Movement",
    function() return db.profile.minimap.fadeEnabled end,
    function(v) db.profile.minimap.fadeEnabled = v end,
    curY, fadeDependents)
  local combatSlider
  combatSlider, curY = addSlider("Combat Opacity", 0, 100, 1,
    function() return db.profile.minimap.combatAlpha end,
    function(v) db.profile.minimap.combatAlpha = v end,
    curY, percentFormat)
  table.insert(fadeDependents, combatSlider)
  local movingSlider
  movingSlider, curY = addSlider("Moving Opacity", 0, 100, 1,
    function() return db.profile.minimap.movingAlpha end,
    function(v) db.profile.minimap.movingAlpha = v end,
    curY, percentFormat)
  table.insert(fadeDependents, movingSlider)

  curY = addDivider(curY - 2)
  curY = addHeader("Buttons", curY)
  _, curY = addCheckbox("Show Zone Text",
    function() return db.profile.minimap.showZoneText end,
    function(v) db.profile.minimap.showZoneText = v end,
    curY)
  _, curY = addCheckbox("Show Clock",
    function() return db.profile.minimap.showClock end,
    function(v) db.profile.minimap.showClock = v end,
    curY)
  _, curY = addCheckbox("Show Calendar Button",
    function() return db.profile.minimap.showCalendar end,
    function(v) db.profile.minimap.showCalendar = v end,
    curY)
  if not isRetail() then
    _, curY = addCheckbox("Hide Day/Night Icon",
      function() return db.profile.minimap.hideDiel end,
      function(v) db.profile.minimap.hideDiel = v end,
      curY)
  end
  _, curY = addCheckbox("Show Tracking Button",
    function() return db.profile.minimap.showTracking end,
    function(v) db.profile.minimap.showTracking = v end,
    curY)
  _, curY = addCheckbox("Show All Minimap Tracking Options",
    function() return db.profile.minimap.showAllMinimapTracking end,
    function(v) db.profile.minimap.showAllMinimapTracking = v end,
    curY)
  local hideExtraCb
  hideExtraCb, curY = addCheckbox("Hide Extra Minimap Buttons",
    function()
      if db.profile.minimap.shape == "square" then return true end
      return db.profile.minimap.hideExtraButtons
    end,
    function(v)
      db.profile.minimap.hideExtraButtons = v
    end,
    curY)
  _, curY = addCheckbox("Mouse Wheel Zoom",
    function() return db.profile.minimap.mouseWheelZoom end,
    function(v) db.profile.minimap.mouseWheelZoom = v end,
    curY)

  dialog:SetHeight(math.abs(curY) + 24)

  function dialog:RefreshValues()
    for _, fn in ipairs(controls) do fn() end
    if hideExtraCb then
      local isSquare = (db.profile.minimap.shape == "square")
      hideExtraCb:SetEnabled(not isSquare)
      if isSquare then
        hideExtraCb:SetChecked(true)
      end
    end
  end

  return dialog
end

local function showOptionsDialog(show)
  if not optionsDialog then
    if not show then return end
    optionsDialog = createOptionsDialog()
  end
  if not show then
    optionsDialog:Hide()
    return
  end
  optionsDialog:RefreshValues()
  optionsDialog:ClearAllPoints()
  if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
    optionsDialog:SetPoint("TOPLEFT", EditModeSystemSettingsDialog, "TOPRIGHT", 10, 0)
  else
    optionsDialog:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
  end
  optionsDialog:Show()
end

--- Attaches our options window to Blizzard's own Edit Mode settings dialog whenever the Minimap
--- system (a native Edit Mode system, unlike our custom Buffs container) is the one selected.
local function registerEditModeHooks()
  if not (EditModeManagerFrame and EditModeSystemSettingsDialog and Enum.EditModeSystem) then return end

  hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(_, systemFrame)
    showOptionsDialog(systemFrame and systemFrame.system == Enum.EditModeSystem.Minimap)
  end)
  EditModeSystemSettingsDialog:HookScript("OnHide", function() showOptionsDialog(false) end)

  if MinimapCluster and MinimapCluster.AnchorSelectionFrame then
    hooksecurefunc(MinimapCluster, "AnchorSelectionFrame", updateEditModeSelectionBounds)
  end

  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", updateEditModeSelectionBounds, module)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
      showOptionsDialog(false)
      updateEditModeSelectionBounds()
    end, module)
  end
end

--=====================================================================
-- Lifecycle
--=====================================================================

function module:OnInitialize()
  registerEditModeHooks()
  db:RegisterCallback("OnDatabaseReset", module.ApplyAll, module)
  if not (db and db.profile and db.profile.minimap and db.profile.minimap.enabled) then
    self:SetEnabledState(false)
  end
end

function module:OnEnable()
  if not (db and db.profile and db.profile.minimap and db.profile.minimap.enabled) then
    self:SetEnabledState(false)
    return
  end
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyAll")
  self:RegisterEvent("ZONE_CHANGED_INDOORS", "ApplyAll")
  self:RegisterEvent("ZONE_CHANGED", "ApplyAll")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ApplyAll")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_STARTED_MOVING")
  self:RegisterEvent("PLAYER_STOPPED_MOVING")
  self:ApplyAll()
end

function module:PLAYER_REGEN_DISABLED()
  if not isModuleEnabled() then return end
  isInCombat = true
  applyAlpha()
end

function module:PLAYER_REGEN_ENABLED()
  if not isModuleEnabled() then return end
  isInCombat = false
  self:ApplyAll() -- catch up any show/hide changes that were skipped while in combat
end

function module:PLAYER_STARTED_MOVING()
  if not isModuleEnabled() then return end
  isMoving = true
  applyAlpha()
end

function module:PLAYER_STOPPED_MOVING()
  if not isModuleEnabled() then return end
  isMoving = false
  applyAlpha()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  if addonScanTicker then
    addonScanTicker:Cancel()
    addonScanTicker = nil
  end
  if hoverCheckTicker then
    hoverCheckTicker:Cancel()
    hoverCheckTicker = nil
  end
  restoreCoordinates()
  if squareBorderFrame then squareBorderFrame:Hide() end
  if titleBarFrame then titleBarFrame:Hide() end
  if addonIconsContainer then addonIconsContainer:Hide() end
  if MinimapCluster then
    if origMinimapClusterLayout then
      MinimapCluster.Layout = origMinimapClusterLayout
    end
    if MinimapCluster.BorderTop then
      MinimapCluster.BorderTop:SetAlpha(1)
      MinimapCluster.BorderTop:Show()
    end
    if MinimapCluster.IndicatorFrame then
      MinimapCluster.IndicatorFrame:Show()
    end
    if MinimapCluster.GamepadButtons then
      MinimapCluster.GamepadButtons:Show()
    end
    MinimapCluster:SetAlpha(1)
    if MinimapCluster.Selection then
      MinimapCluster.Selection:ClearAllPoints()
      MinimapCluster.Selection:SetAllPoints(MinimapCluster)
    end
  end
  disableAllStacking()
  if _G.Minimap.SetMaskTexture then _G.Minimap:SetMaskTexture(ROUND_MASK_TEXTURE) end
  _G.Minimap:SetAlpha(1)
  if not InCombatLockdown() then
    if MinimapCluster and MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:Show() end
    if TimeManagerClockButton then TimeManagerClockButton:Show() end
    if GameTimeFrame then GameTimeFrame:Show() end
    if MinimapCluster and MinimapCluster.DielFrame then MinimapCluster.DielFrame:Show() end
    if MinimapCluster and MinimapCluster.Tracking then MinimapCluster.Tracking:Show() end
    local mail = getMailButton()
    local crafting = getCraftingOrderButton()
    for _, button in ipairs(extraButtons()) do
      if button and button ~= mail and button ~= crafting then button:Show() end
    end
    if mail and HasNewMail and HasNewMail() then
      mail:Show()
    end
    if crafting and crafting.countInfos and #crafting.countInfos > 0 then
      crafting:Show()
    end
  end
  if MinimapBackdrop then MinimapBackdrop:SetAlpha(1) end
  ensureCVar("minimapTrackingShowAll", GetCVarDefault("minimapTrackingShowAll"))
end
