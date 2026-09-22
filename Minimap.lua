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
local SQUARE_CLUSTER_WIDTH_EXTRA = 8
local SQUARE_CLUSTER_HEIGHT_EXTRA = 23
local SQUARE_FOREVER_CLUSTER_HEIGHT_EXTRA = 0
local SQUARE_SELECTION_LEFT_INSET = 4
local SQUARE_SELECTION_TOP_EXTENSION = 0
local SQUARE_FOREVER_SELECTION_TOP_EXTENSION = 3

-- Falls back to Blizzard's untouched defaults whenever the module is disabled.
local DEFAULT_VISUALS = {
  shape = "circle",
  showIconsOnHover = false,
  showAddonIconsOnHover = false,
  hideDiel = false,
  showAllMinimapTracking = false,
  alpha = 100,
  fadeEnabled = false,
  combatAlpha = 100,
  movingAlpha = 100,
  showZoneText = true,
  showClock = true,
  showTracking = true,
  showCalendar = true,
  showInstanceDifficulty = true,
  showGarrison = true,
  showAddonCompartment = true,
  addonsInCompartment = false,
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

function _G.GetMinimapShape()
  if isModuleEnabled() and settings().shape == "square" then
    return "SQUARE"
  end
  return "ROUND"
end

local isInCombat = false
local isMoving = false
local savedCoordsState
local userWantedRotateMinimap
local optionsDialog
local squareBorderFrame
local titleBarFrame
local titleBarZoneFallbackButton
local titleBarIconRow
local addonIconsContainer
local hoverCheckTicker
local applyTitleBarLayout
local setFrameStrataSafe
local setFrameLevelRecursive
local updateHoverVisibility
local isButtonShown
local isBlizzardFrame
local registeredButtons = {}
local registeredButtonsByFrame = {}
local addonButtons = {}
local addonButtonsByFrame = {}
local hoverContainerButtons = {}
local origMinimapClusterLayout
local origMinimapClusterWidth, origMinimapClusterHeight
local origMinimapClusterHitInsets
local origMinimapContainerPoints
local squareMinimapWidth, squareMinimapHeight
local isSquareClusterApplied = false
local origSetHeaderUnderneath
local origSetRotateMinimap
local origShouldShowSetting
local origSetEditModeScale
local layoutPending = false
local addonScanTicker

local function applyMinimapRotation()
  if not isModuleEnabled() then return end
  local isSquare = (settings().shape == "square")
  if isSquare then
    local currentCVar = GetCVar("rotateMinimap")
    if currentCVar == "1" then
      userWantedRotateMinimap = true
      if db and db.profile and db.profile.minimap then
        db.profile.minimap.savedRotateMinimap = true
      end
      SetCVar("rotateMinimap", 0)
    elseif userWantedRotateMinimap == nil and db and db.profile and db.profile.minimap and db.profile.minimap.savedRotateMinimap then
      userWantedRotateMinimap = true
      SetCVar("rotateMinimap", 0)
    end
  else
    if MinimapCluster and MinimapCluster.GetSettingValueBool and Enum and Enum.EditModeMinimapSetting and MinimapCluster.HasSetting and MinimapCluster:HasSetting(Enum.EditModeMinimapSetting.RotateMinimap) then
      local wantRotate = MinimapCluster:GetSettingValueBool(Enum.EditModeMinimapSetting.RotateMinimap)
      SetCVar("rotateMinimap", wantRotate and 1 or 0)
      userWantedRotateMinimap = nil
      if db and db.profile and db.profile.minimap then
        db.profile.minimap.savedRotateMinimap = nil
      end
    elseif userWantedRotateMinimap or (db and db.profile and db.profile.minimap and db.profile.minimap.savedRotateMinimap) then
      SetCVar("rotateMinimap", 1)
      userWantedRotateMinimap = nil
      if db and db.profile and db.profile.minimap then
        db.profile.minimap.savedRotateMinimap = nil
      end
    end
  end
end

local function restoreMinimapRotation()
  if MinimapCluster and MinimapCluster.GetSettingValueBool and Enum and Enum.EditModeMinimapSetting and MinimapCluster.HasSetting and MinimapCluster:HasSetting(Enum.EditModeMinimapSetting.RotateMinimap) then
    local wantRotate = MinimapCluster:GetSettingValueBool(Enum.EditModeMinimapSetting.RotateMinimap)
    SetCVar("rotateMinimap", wantRotate and 1 or 0)
    userWantedRotateMinimap = nil
    if db and db.profile and db.profile.minimap then
      db.profile.minimap.savedRotateMinimap = nil
    end
  elseif userWantedRotateMinimap or (db and db.profile and db.profile.minimap and db.profile.minimap.savedRotateMinimap) then
    SetCVar("rotateMinimap", 1)
    userWantedRotateMinimap = nil
    if db and db.profile and db.profile.minimap then
      db.profile.minimap.savedRotateMinimap = nil
    end
  end
end

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

local function getInstanceDifficultyButton()
  if MinimapCluster and MinimapCluster.InstanceDifficulty then
    return MinimapCluster.InstanceDifficulty
  end
  if GuildInstanceDifficulty then
    return GuildInstanceDifficulty
  end
  return nil
end

local function getGarrisonButton()
  return ExpansionLandingPageMinimapButton or GarrisonLandingPageMinimapButton
end

local function isGarrisonLandingPageAvailable()
  if not isRetail() then return false end
  local btn = getGarrisonButton()
  if not btn then return false end

  -- Newer expansions route through ExpansionOverlay mode (not the legacy Garrison type system) --
  -- trust Blizzard's own resolved title/description as the availability signal there.
  if btn.IsExpansionOverlayMode and btn:IsExpansionOverlayMode() then
    return btn.title ~= nil and btn.title ~= ""
  end

  -- Legacy Garrison mode: mirror Blizzard's own RefreshButton() visibility gate
  -- (C_Garrison.IsLandingPageMinimapButtonVisible) instead of re-deriving availability ourselves.
  -- GetLandingPageGarrisonType() can resolve to a stale/inapplicable type (e.g. Shadowlands Covenant
  -- with no active covenant chosen) whose title Blizzard still populates -- forcing the button
  -- visible/clickable in that state crashes Blizzard's own SetTooltip/ToggleLandingPage/
  -- UpdateButtonTextures (nil title / nil covenantData) since it was never meant to be shown.
  if C_Garrison and C_Garrison.GetLandingPageGarrisonType and C_Garrison.IsLandingPageMinimapButtonVisible then
    local typeOk, gType = pcall(C_Garrison.GetLandingPageGarrisonType)
    if typeOk and gType and gType > 0 then
      local visOk, visible = pcall(C_Garrison.IsLandingPageMinimapButtonVisible, gType)
      if visOk then return visible and true or false end
    end
    return false
  end

  -- Fallback for clients without the modern Garrison API (shouldn't normally be reached on retail).
  if C_PlayerInfo and C_PlayerInfo.CanPlayerUseExpansionLandingPage then
    local ok, canUse = pcall(C_PlayerInfo.CanPlayerUseExpansionLandingPage)
    if ok and canUse then return true end
  end
  if GarrisonLandingPage_HasGarrison then
    local ok, hasGarrison = pcall(GarrisonLandingPage_HasGarrison)
    if ok and hasGarrison then return true end
  end
  return false
end

local function getStandardMinimapIcons()
  local list = {}
  if GameTimeFrame then table.insert(list, GameTimeFrame) end
  if MinimapCluster and MinimapCluster.Tracking then table.insert(list, MinimapCluster.Tracking) end
  if TimeManagerClockButton then table.insert(list, TimeManagerClockButton) end
  local mail = getMailButton()
  if mail then table.insert(list, mail) end
  local crafting = getCraftingOrderButton()
  if crafting then table.insert(list, crafting) end
  local diff = getInstanceDifficultyButton()
  if diff then table.insert(list, diff) end
  local garrison = getGarrisonButton()
  if garrison then table.insert(list, garrison) end
  if AddonCompartmentFrame then table.insert(list, AddonCompartmentFrame) end
  if MinimapCluster and MinimapCluster.DielFrame then table.insert(list, MinimapCluster.DielFrame) end
  return list
end

local function extraButtons()
  local mail = getMailButton()
  local crafting = getCraftingOrderButton()
  local diff = getInstanceDifficultyButton()
  local garrison = getGarrisonButton()
  return {
    mail,
    crafting,
    diff,
    garrison,
    AddonCompartmentFrame,
    MiniMapBattlefieldFrame,
    MiniMapMeetingStoneFrame,
    MiniMapVoiceChatFrame,
    FeedbackUIButton,
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

local function getAllBlizzardIcons()
  local list = getStandardMinimapIcons()
  if AddonCompartmentFrame then table.insert(list, AddonCompartmentFrame) end
  if MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button then
    table.insert(list, MinimapCluster.Tracking.Button)
  end
  return list
end

local function applyBlizzardIconBorders(removeBorders)
  for _, btn in ipairs(getAllBlizzardIcons()) do
    if btn.slackHacksCreatedBorder then
      btn.slackHacksCreatedBorder:Hide()
      btn.slackHacksCreatedBorder:SetTexture(nil)
      btn.slackHacksCreatedBorder = nil
    end

    if btn == TimeManagerClockButton and TimeManagerClockBackground then
      TimeManagerClockBackground:SetAlpha(removeBorders and 0 or 1)
    end

    local ok, regions = pcall(function() return { btn:GetRegions() } end)
    if ok and regions then
      for _, r in ipairs(regions) do
        if r:IsObjectType("Texture") then
          local tex = r:GetTexture()
          local atlas = r.GetAtlas and r:GetAtlas()
          local isBorder = (tex == 136430)
            or (type(tex) == "string" and (tex:find("MiniMap%-TrackingBorder") or tex:find("UI%-Minimap%-Background")))
            or (tex == 136467)
            or (atlas and (atlas:lower():find("frame%-cycle") or atlas:lower():find("tracking%-border") or atlas:lower():find("button%-border")))

          if btn == TimeManagerClockButton then
            isBorder = true
          end

          if isBorder then
            r:SetAlpha(removeBorders and 0 or 1)
          end
        end
      end
    end
  end
end

local function applyClock()
  if not isModuleEnabled() then return end
  local mm = settings()
  setShownSafely(TimeManagerClockButton, mm.showClock)
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
  local isSquare = (settings().shape == "square")
  if not isSquare then return end

  local legacyExtras = {
    MiniMapBattlefieldFrame,
    MiniMapMeetingStoneFrame,
    MiniMapVoiceChatFrame,
    FeedbackUIButton,
  }
  for _, btn in ipairs(legacyExtras) do
    setShownSafely(btn, false)
  end
end

--- Same nine-slice border art used by many Blizzard windows, but the plain rectangular layout (no
--- portrait icon/title notch cut into the top-left corner like the Spellbook's own frame has).
--- Drawn above _G.Minimap so the NineSlice metal corners and beveled edges neatly enclose the map
--- texture without clipping or inner seams, matching how Blizzard's SpellBook and DefaultPanelTemplate work.
--- Also hosts a 2D backing frame behind _G.Minimap using Blizzard's FlatPanelBackgroundTemplate so
--- curved bottom corners (uiframebackground-nineslice-cornerbottom...) fill the perimeter inset without bleeding.
local function createSquareBorder()
  if squareBorderFrame then return squareBorderFrame end
  local frame = CreateFrame("Frame", "SlackHacksMinimapSquareBorder", MinimapCluster or _G.Minimap)
  frame.layoutType = "ButtonFrameTemplateNoPortrait"
  frame:SetFrameStrata(_G.Minimap:GetFrameStrata())
  frame:SetFrameLevel(math.max(500, _G.Minimap:GetFrameLevel() + 5))
  frame:EnableMouse(false)
  frame:SetPoint("TOPLEFT", MinimapCluster or _G.Minimap, "TOPLEFT", 0, 0)
  frame:SetPoint("BOTTOMRIGHT", MinimapCluster or _G.Minimap, "BOTTOMRIGHT", 0, 0)

  -- 2D backing frame sitting behind _G.Minimap to provide a clean dark inset behind the map viewport.
  -- Uses Blizzard's FlatPanelBackgroundTemplate which has curved corner textures matching the nine-slice art.
  local backing = CreateFrame("Frame", "SlackHacksMinimapSquareBacking", frame, "FlatPanelBackgroundTemplate")
  backing:SetFrameStrata(_G.Minimap:GetFrameStrata())
  backing:SetFrameLevel(math.max(1, _G.Minimap:GetFrameLevel() - 1))
  backing:EnableMouse(false)
  backing:ClearAllPoints()
  backing:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -21)
  backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

  local bgColor = PANEL_BACKGROUND_COLOR or (CreateColor and CreateColor(0.08, 0.08, 0.08, 1))
  if bgColor then
    if backing.BottomLeft then backing.BottomLeft:SetVertexColor(bgColor:GetRGBA()) end
    if backing.BottomRight then backing.BottomRight:SetVertexColor(bgColor:GetRGBA()) end
    if backing.BottomEdge then backing.BottomEdge:SetVertexColor(bgColor:GetRGBA()) end
    if backing.TopSection then backing.TopSection:SetVertexColor(bgColor:GetRGBA()) end
  end

  local nineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
  nineSlice:EnableMouse(false)

  -- Re-assert AFTER creating the nine-slice (its OnLoad can flip mouse back on for a draggable-dialog
  -- style frame). Also HookScript OnShow, since Show()/re-layout can retrigger the same behavior later
  -- (confirmed via /framestack: this border kept winning mouse focus over the map/POI pins underneath it
  -- even after the one-time post-creation EnableMouse(false) call).
  frame:EnableMouse(false)
  frame:HookScript("OnShow", function(self) self:EnableMouse(false) end)

  squareBorderFrame = frame
  return frame
end

local function cacheMinimapClusterDefaults()
  if not MinimapCluster then return end
  if not origMinimapClusterWidth and MinimapCluster.GetWidth and MinimapCluster:GetWidth() > 0 then
    origMinimapClusterWidth = MinimapCluster:GetWidth()
    origMinimapClusterHeight = MinimapCluster:GetHeight()
  end
  if not origMinimapClusterHitInsets and MinimapCluster.GetHitRectInsets then
    origMinimapClusterHitInsets = { MinimapCluster:GetHitRectInsets() }
  end
  if not squareMinimapWidth and _G.Minimap and _G.Minimap.GetWidth and _G.Minimap:GetWidth() > 0 then
    squareMinimapWidth = _G.Minimap:GetWidth()
    squareMinimapHeight = _G.Minimap:GetHeight()
  end
  local container = MinimapCluster.MinimapContainer
  if container and not origMinimapContainerPoints and container.GetNumPoints and container:GetNumPoints() > 0 then
    origMinimapContainerPoints = {}
    for i = 1, container:GetNumPoints() do
      local point, relativeTo, relativePoint, offsetX, offsetY = container:GetPoint(i)
      origMinimapContainerPoints[i] = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        offsetX = offsetX,
        offsetY = offsetY,
      }
    end
  end
end

local function getSquareMinimapDimensions()
  local container = MinimapCluster and MinimapCluster.MinimapContainer
  local scale = (container and container:GetScale()) or 1
  if not scale or scale <= 0 then scale = 1 end
  local mmW = squareMinimapWidth or 198
  local mmH = squareMinimapHeight or 198
  local visualW = math.floor((mmW * scale) + 0.5)
  local visualH = math.floor((mmH * scale) + 0.5)
  return visualW, visualH, scale
end

local function applySquareMinimapCluster()
  if not MinimapCluster then return end
  cacheMinimapClusterDefaults()

  -- Disable Blizzard's MinimapCluster layout so it doesn't fight our sizing or points
  if not origMinimapClusterLayout and MinimapCluster.Layout then
    origMinimapClusterLayout = MinimapCluster.Layout
  end
  MinimapCluster.Layout = function() end

  -- Remove/hide the native header (BorderTop) and related elements in square mode
  if MinimapCluster.BorderTop then
    MinimapCluster.BorderTop:SetAlpha(0)
    MinimapCluster.BorderTop:Hide()
    MinimapCluster.BorderTop.ignoreInLayout = true
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

  -- Position MinimapContainer so the map sits cleanly below the title bar and within the borders
  local visualW, visualH, scale = getSquareMinimapDimensions()
  local container = MinimapCluster.MinimapContainer
  if container then
    container:ClearAllPoints()
    container:SetPoint("CENTER", MinimapCluster, "CENTER", 2 / scale, -9 / scale)
  end

  -- Size MinimapCluster to match the visible square minimap + border
  -- NOTE: deliberately NOT forcing MinimapCluster's own hit rect to (0,0,0,0) here -- that made
  -- MinimapCluster's own mouse-interactive area fully overlap the visible map/POI pins underneath it,
  -- which was swallowing hover before it reached quest/vignette icons (no tooltips, square mode only).
  -- Leaving Blizzard's own cached insets in place keeps parity with how round mode already avoids this.
  MinimapCluster:SetSize(visualW + SQUARE_CLUSTER_WIDTH_EXTRA, visualH + SQUARE_CLUSTER_HEIGHT_EXTRA + (isForever() and SQUARE_FOREVER_CLUSTER_HEIGHT_EXTRA or 0))

  -- Snap the square border to MinimapCluster
  local border = createSquareBorder()
  if border then
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", MinimapCluster, "TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", MinimapCluster, "BOTTOMRIGHT", 0, 0)
    border:Show()
    border:EnableMouse(false) -- belt-and-suspenders: re-assert every layout pass, not just at creation
  end

  -- Snap Edit Mode Selection directly to MinimapCluster so its blue drag bounds and snapping match
  if MinimapCluster.Selection then
    MinimapCluster.Selection:ClearAllPoints()
    MinimapCluster.Selection:SetPoint("TOPLEFT", MinimapCluster, "TOPLEFT", SQUARE_SELECTION_LEFT_INSET, SQUARE_SELECTION_TOP_EXTENSION + (isForever() and SQUARE_FOREVER_SELECTION_TOP_EXTENSION or 0))
    MinimapCluster.Selection:SetPoint("BOTTOMRIGHT", MinimapCluster, "BOTTOMRIGHT", 0, 0)
    if MinimapCluster.Selection.SetClipsChildren then
      MinimapCluster.Selection:SetClipsChildren(true)
    end
  end

  if MinimapCluster.UpdateClampOffsets then
    MinimapCluster:UpdateClampOffsets()
  end

  isSquareClusterApplied = true
end

local function restoreRoundMinimapCluster()
  if not MinimapCluster or not isSquareClusterApplied then return end

  -- Restore MinimapContainer points
  local container = MinimapCluster.MinimapContainer
  if container then
    container:ClearAllPoints()
    if origMinimapContainerPoints and #origMinimapContainerPoints > 0 then
      for _, pt in ipairs(origMinimapContainerPoints) do
        container:SetPoint(pt.point, pt.relativeTo, pt.relativePoint, pt.offsetX, pt.offsetY)
      end
    elseif container.defaultFramePoints then
      local scale = container:GetScale() or 1
      for _, value in ipairs(container.defaultFramePoints) do
        container:SetPoint(value.point, value.relativeTo, value.relativePoint, value.offsetX / scale, value.offsetY / scale)
      end
    else
      container:SetPoint("TOP", MinimapCluster, "TOP", 10, -30)
    end
  end

  -- Restore MinimapCluster size and insets
  MinimapCluster:SetSize(origMinimapClusterWidth or 256, origMinimapClusterHeight or 256)
  if MinimapCluster.SetHitRectInsets then
    if origMinimapClusterHitInsets then
      MinimapCluster:SetHitRectInsets(unpack(origMinimapClusterHitInsets))
    else
      MinimapCluster:SetHitRectInsets(30, 10, 0, 30)
    end
  end

  -- Restore native header and indicator frame
  if MinimapCluster.BorderTop then
    MinimapCluster.BorderTop:SetAlpha(1)
    MinimapCluster.BorderTop:Show()
    MinimapCluster.BorderTop.ignoreInLayout = nil
  end
  if MinimapCluster.IndicatorFrame then
    MinimapCluster.IndicatorFrame:Show()
  end
  if MinimapCluster.GamepadButtons then
    MinimapCluster.GamepadButtons:Show()
  end

  -- Restore Edit Mode selection
  if MinimapCluster.Selection then
    MinimapCluster.Selection:ClearAllPoints()
    MinimapCluster.Selection:SetAllPoints(MinimapCluster)
    if MinimapCluster.Selection.SetClipsChildren then
      MinimapCluster.Selection:SetClipsChildren(false)
    end
  end
  if MinimapCluster.UpdateClampOffsets then
    MinimapCluster:UpdateClampOffsets()
  end

  -- Restore Layout
  if origMinimapClusterLayout then
    MinimapCluster.Layout = origMinimapClusterLayout
  end

  -- Re-apply Blizzard's saved HeaderUnderneath and RotateMinimap settings
  local isHeaderUnderneath = false
  if MinimapCluster.GetSettingValueBool and Enum and Enum.EditModeMinimapSetting and MinimapCluster.HasSetting and MinimapCluster:HasSetting(Enum.EditModeMinimapSetting.HeaderUnderneath) then
    isHeaderUnderneath = MinimapCluster:GetSettingValueBool(Enum.EditModeMinimapSetting.HeaderUnderneath)
  end
  if origSetHeaderUnderneath then
    pcall(origSetHeaderUnderneath, MinimapCluster, isHeaderUnderneath)
  elseif MinimapCluster.SetHeaderUnderneath then
    pcall(MinimapCluster.SetHeaderUnderneath, MinimapCluster, isHeaderUnderneath)
  end

  local isRotateMinimap = false
  if MinimapCluster.GetSettingValueBool and Enum and Enum.EditModeMinimapSetting and MinimapCluster.HasSetting and MinimapCluster:HasSetting(Enum.EditModeMinimapSetting.RotateMinimap) then
    isRotateMinimap = MinimapCluster:GetSettingValueBool(Enum.EditModeMinimapSetting.RotateMinimap)
  end
  if origSetRotateMinimap then
    pcall(origSetRotateMinimap, MinimapCluster, isRotateMinimap)
  elseif MinimapCluster.SetRotateMinimap then
    pcall(MinimapCluster.SetRotateMinimap, MinimapCluster, isRotateMinimap)
  end

  if MinimapCluster.Layout then
    pcall(function() MinimapCluster:Layout() end)
  end

  isSquareClusterApplied = false
end

local function updateEditModeSelectionBounds()
  if not (MinimapCluster and MinimapCluster.Selection) then return end
  if not isModuleEnabled() then
    restoreRoundMinimapCluster()
    return
  end
  local mm = settings()
  if mm.shape == "square" then
    applySquareMinimapCluster()
  else
    restoreRoundMinimapCluster()
  end
end

local function applyBorder()
  if not isModuleEnabled() then return end
  local mm = settings()
  local isSquare = (mm.shape == "square")
  if MinimapBackdrop then
    MinimapBackdrop:SetAlpha(isSquare and 0 or 1)
  end
  if isSquare then
    applySquareMinimapCluster()
    applyBlizzardIconBorders(true)
  else
    if squareBorderFrame then
      squareBorderFrame:Hide()
    end
    applyBlizzardIconBorders(false)
    restoreRoundMinimapCluster()
  end
  updateEditModeSelectionBounds()
end

local TITLE_BAR_HEIGHT = 18
local TITLE_BAR_ICON_SCALE = 0.7
local TITLE_BAR_CLOCK_SCALE = 1.1 -- the clock's text/frame proportions read as too small at the icon scale
local TITLE_BAR_GARRISON_SCALE = 0.7
local TITLE_BAR_CALENDAR_TRACKING_SCALE = 1.05
local TITLE_BAR_CALENDAR_Y_OFFSET = -1 -- calendar icon/date art sits slightly higher within its frame than other icons
local TITLE_BAR_TRACKING_Y_OFFSET = 2 -- lifts tracking to vertically align with title bar
local TITLE_BAR_ADDON_COMPARTMENT_Y_OFFSET = 0 -- addon compartment baseline to visually match tracking height
local TITLE_BAR_CLOCK_Y_OFFSET = -1 -- lowers clock to vertically center in title bar
local TITLE_BAR_CLOCK_X_OFFSET = 3 -- shifts clock to the right
local TITLE_BAR_CLOCK_WIDTH_DELTA = -10 -- shorten clock width by 10 pixels

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

--- Purely a positioning/hit-test reference frame -- never a real parent for Blizzard's own buttons.
--- (Blizzard's OnClick handlers for things like AddonCompartmentFrame/Tracking/Calendar rely on their
--- native ancestry (MinimapCluster) and get silently tainted/broken if reparented to a plain addon-created
--- frame, even though tooltips still work fine since those are insecure.) Always shown so `isMinimapHovered()`
--- can treat its rect as "still hovering the icon group", independent of any individual button's visibility.
local function createAddonIconsContainer()
  if addonIconsContainer then return addonIconsContainer end
  local container = CreateFrame("Frame", "SlackHacksMinimapAddonIconsContainer", titleBarFrame or MinimapCluster or UIParent)
  container:SetHeight(TITLE_BAR_HEIGHT)
  container:SetFrameStrata("DIALOG")
  container:SetFrameLevel(525)
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
  for _, icon in ipairs(getStandardMinimapIcons()) do
    if isRegionMouseOver(icon) then return true end
  end
  if isRegionMouseOver(AddonCompartmentFrame) then
    return true
  end
  if addonButtons then
    for _, btn in ipairs(addonButtons) do
      if isRegionMouseOver(btn) then return true end
    end
  end
  return false
end

updateHoverVisibility = function(hovered)
  if not isModuleEnabled() then return end
  if hovered == nil then
    hovered = isMinimapHovered()
  end

  local mm = settings()
  local isSquare = (mm.shape == "square")

  if isSquare then
    if addonIconsContainer then
      addonIconsContainer:Show() -- always shown, purely a hit-test rect; individual buttons fade below
    end

    -- SetAlpha only, never SetShown/Hide -- matches the already-reliable corner-icon technique below,
    -- and keeps every button's OnClick/OnEnter fully live even while faded out, instead of racing
    -- Blizzard's own Show/Hide (protected, and inconsistent across buttons).
    for _, btn in ipairs(hoverContainerButtons) do
      if btn then
        btn:SetAlpha(hovered and 1 or 0)
      end
    end

    if mm.showAddonIconsOnHover and not mm.addonsInCompartment then
      for _, btn in ipairs(addonButtons) do
        if btn then
          btn:SetAlpha(hovered and 1 or 0)
        end
      end
    else
      for _, btn in ipairs(addonButtons) do
        if btn then
          btn:SetAlpha(1)
        end
      end
    end
  else
    -- Round mode -- showIconsOnHover is square-only now, so standard icons always stay fully visible here.
    local stdIcons = getStandardMinimapIcons()
    for _, icon in ipairs(stdIcons) do
      if icon and icon ~= (MinimapCluster and MinimapCluster.DielFrame and mm.hideDiel and MinimapCluster.DielFrame) then
        icon:SetAlpha(1)
      end
    end

    local function setAddonAlpha(btn)
      if btn then
        if mm.showAddonIconsOnHover then
          btn:SetAlpha(hovered and 1 or 0)
        else
          btn:SetAlpha(1)
        end
      end
    end

    for _, btn in ipairs(addonButtons) do
      setAddonAlpha(btn)
    end
  end

  local needsTicker = isSquare and (mm.showIconsOnHover or mm.showAddonIconsOnHover) or (not isSquare and mm.showAddonIconsOnHover)
  if hovered and needsTicker then
    if not hoverCheckTicker then
      hoverCheckTicker = C_Timer.NewTicker(0.1, function()
        if not isMinimapHovered() then
          updateHoverVisibility(false)
        end
      end)
    end
  else
    if hoverCheckTicker then
      hoverCheckTicker:Cancel()
      hoverCheckTicker = nil
    end
  end
end

local function hookHoverFrame(frame)
  if not frame or frame.slackHacksHoverHooked then return end
  frame.slackHacksHoverHooked = true
  if frame.HookScript then
    frame:HookScript("OnEnter", function()
      updateHoverVisibility(true)
    end)
    frame:HookScript("OnLeave", function()
      C_Timer.After(0.05, function()
        if not isMinimapHovered() then
          updateHoverVisibility(false)
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

--- Mappy-style button manipulation: save initial anchors, parent, scale, strata, and level.
local function saveButtonState(button)
  if button.slackHacksSaved then return end
  local saved = {
    anchors = {},
    parent = button:GetParent(),
    scale = button:GetScale(),
    strata = button:GetFrameStrata(),
    level = button:GetFrameLevel(),
    width = button:GetWidth(),
    height = button:GetHeight(),
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
  if saved.width and saved.width > 0 then
    button:SetWidth(saved.width)
  end
  if saved.height and saved.height > 0 then
    button:SetHeight(saved.height)
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
      if saved.border.width and saved.border.height and saved.border.width > 0 and saved.border.height > 0 then
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

--=====================================================================
-- Addon Button Diel Border Reskinning (Forever only)
--=====================================================================

local DIEL_BORDER_ATLAS = "ui-hud-minimap-frame-cycle"

local function getOrCreateButtonBorder(button)
  local border = findButtonBorder(button)
  if border then return border end
  local created = button:CreateTexture(nil, "OVERLAY")
  button.slackHacksCreatedBorder = created
  return created
end

local function applyCycleBorderToAddonButton(button)
  if not button or not isForever() then return end
  saveButtonState(button)
  local border = getOrCreateButtonBorder(button)
  if not border then return end

  if border.SetAtlas then
    border:SetAtlas(DIEL_BORDER_ATLAS)
  end
  border:SetTexCoord(0, 1, 0, 1)

  local btnW = button:GetWidth()
  local size = (btnW and btnW > 10) and btnW or 32

  border:ClearAllPoints()
  border:SetPoint("CENTER", button, "CENTER", 0, 0)
  border:SetSize(size, size)
  border:Show()
end

local function applyAllAddonButtonBorders()
  if not isForever() then return end
  for _, btn in ipairs(addonButtons) do
    if btn and not isBlizzardFrame(btn) then
      applyCycleBorderToAddonButton(btn)
    end
  end
end

local function restoreAllAddonButtonBorders()
  for _, btn in ipairs(addonButtons) do
    if btn and not isBlizzardFrame(btn) then
      restoreButtonState(btn)
    end
  end
end

local function getSquareBorderTargetFrame()
  if squareBorderFrame and squareBorderFrame:IsShown() and squareBorderFrame:GetWidth() > 0 then
    return squareBorderFrame
  end
  if MinimapCluster and MinimapCluster:GetWidth() > 0 then
    return MinimapCluster
  end
  return _G.Minimap
end

local function getSquareBorderDimensions()
  local target = getSquareBorderTargetFrame()
  local tw = target:GetWidth() or 200
  local th = target:GetHeight() or 200
  local radiusX = (tw / 2) + 2
  local radiusY = (th / 2) + 2
  return target, radiusX, radiusY
end

local function getSquarePositionForAngle(angleDeg, radiusX, radiusY)
  local angleRad = math.rad(angleDeg)
  local cosA = math.cos(angleRad)
  local sinA = math.sin(angleRad)
  local absCos = math.abs(cosA)
  local absSin = math.abs(sinA)
  local dist
  if absCos * radiusY > absSin * radiusX then
    dist = radiusX / (absCos > 0.0001 and absCos or 0.0001)
  else
    dist = radiusY / (absSin > 0.0001 and absSin or 0.0001)
  end
  return cosA * dist, sinA * dist
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
    QueueStatusButton = true,
    QueueStatusMinimapButton = true,
    QueueStatusButtonIcon = true,
    GuildInstanceDifficulty = true,
    ExpansionLandingPageMinimapButton = true,
    GarrisonLandingPageMinimapButton = true,
    AddonCompartmentFrame = true,
    CT_RASetsFrame = true,
    SlackHacksMinimapSquareBorder = true,
    SlackHacksMinimapTitleBar = true,
    SlackHacksMinimapTitleBarIcons = true,
    SlackHacksMinimapAddonIconsContainer = true,
    SlackHacksMinimapOptionsDialog = true,
    MiniMapMailFrame = true,
    MiniMapCraftingOrderFrame = true,
  }
  for name in pairs(ignore) do
    if _G[name] then ignore[_G[name]] = true end
  end
  if MinimapCluster then
    ignore[MinimapCluster] = true
    if MinimapCluster.ZoneTextButton then ignore[MinimapCluster.ZoneTextButton] = true end
    if MinimapCluster.Tracking then
      ignore[MinimapCluster.Tracking] = true
      if MinimapCluster.Tracking.Button then ignore[MinimapCluster.Tracking.Button] = true end
    end
    if MinimapCluster.DielFrame then ignore[MinimapCluster.DielFrame] = true end
    if MinimapCluster.InstanceDifficulty then ignore[MinimapCluster.InstanceDifficulty] = true end
    if MinimapCluster.BorderTop then ignore[MinimapCluster.BorderTop] = true end
    if MinimapCluster.MinimapContainer then ignore[MinimapCluster.MinimapContainer] = true end
    if MinimapCluster.IndicatorFrame then
      ignore[MinimapCluster.IndicatorFrame] = true
      if MinimapCluster.IndicatorFrame.MailFrame then ignore[MinimapCluster.IndicatorFrame.MailFrame] = true end
      if MinimapCluster.IndicatorFrame.CraftingOrderFrame then ignore[MinimapCluster.IndicatorFrame.CraftingOrderFrame] = true end
    end
    if MinimapCluster.GamepadButtons then ignore[MinimapCluster.GamepadButtons] = true end
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

isBlizzardFrame = function(frame)
  if not frame then return true end
  local ignore = getIgnoreFramesMap()
  if ignore[frame] then return true end
  local name = frame.GetName and frame:GetName()
  if name and (ignore[name] or name:find("^Minimap") or name:find("^MiniMap") or name:find("^TimeManager") or name:find("^GameTimeFrame")) then
    return true
  end
  return false
end

--- Mappy-style hooks: when Blizzard or third-party addons call SetPoint, ClearAllPoints,
--- SetFrameStrata, or SetFrameLevel while stacked, record their intent into saved state
--- rather than letting them fight or displace the title bar layout.
local function buttonSaveSetPoint(self, point, relativeTo, relativePoint, x, y)
  if not self.slackHacksSaved then return end
  self.slackHacksSaved.anchors[point] = {
    relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y,
  }

  -- In square mode, if this is an addon button anchored to Minimap, snap to square border
  if settings().shape == "square" and not settings().addonsInCompartment and addonButtonsByFrame[self] and not isBlizzardFrame(self) then
    if not self.isDraggingOnSquareBorder and type(x) == "number" and type(y) == "number" then
      local angle = math.deg(math.atan2(y, x)) % 360
      self.slackHacksAngle = angle
      local target, radiusX, radiusY = getSquareBorderDimensions()
      local sqX, sqY = getSquarePositionForAngle(angle, radiusX, radiusY)
      if self.slackHacksRealClearAllPoints and self.slackHacksRealSetPoint then
        self.slackHacksRealClearAllPoints(self)
        self.slackHacksRealSetPoint(self, "CENTER", target, "CENTER", sqX, sqY)
        setFrameStrataSafe(self, "DIALOG")
        setFrameLevelRecursive(self, 525)
        if self.Raise then self:Raise() end
      end
    end
  end
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

local function getAddonButtonDisplayName(button)
  if button.dataObject and type(button.dataObject.label) == "string" and button.dataObject.label ~= "" then
    return button.dataObject.label
  end
  if button.dataObject and type(button.dataObject.text) == "string" and button.dataObject.text ~= "" then
    return button.dataObject.text
  end
  local name = button.GetName and button:GetName()
  if name and type(name) == "string" and name ~= "" then
    local clean = name:gsub("^LibDBIcon%d*_", ""):gsub("^MiniMap", ""):gsub("Button$", ""):gsub("Frame$", ""):gsub("_", " ")
    if clean ~= "" then
      return clean
    end
    return name
  end
  return "Addon"
end

local function getAddonButtonIcon(button)
  if button.icon and button.icon.GetTexture and button.icon:GetTexture() then
    return button.icon:GetTexture()
  end
  if button.dataObject and button.dataObject.icon then
    return button.dataObject.icon
  end
  local name = button.GetName and button:GetName()
  if name and _G[name .. "Icon"] and _G[name .. "Icon"].GetTexture then
    local tex = _G[name .. "Icon"]:GetTexture()
    if tex then return tex end
  end
  local ok, regions = pcall(function() return { button:GetRegions() } end)
  if ok and regions then
    for _, r in ipairs(regions) do
      if r:IsObjectType("Texture") and r ~= button.slackHacksCreatedBorder then
        local tex = r:GetTexture()
        if tex and tex ~= 136430 and tex ~= 136467 then return tex end
      end
    end
  end
  return 134400
end

local function clearAddonCompartmentEntries()
  if not (AddonCompartmentFrame and AddonCompartmentFrame.registeredAddons) then return end
  local changed = false
  for i = #AddonCompartmentFrame.registeredAddons, 1, -1 do
    local entry = AddonCompartmentFrame.registeredAddons[i]
    if entry and entry.isSlackHacks then
      table.remove(AddonCompartmentFrame.registeredAddons, i)
      changed = true
    end
  end
  if changed and AddonCompartmentFrame.UpdateDisplay then
    AddonCompartmentFrame:UpdateDisplay()
  end
end

local function applyAddonCompartmentFontSize(matchClock)
  if not AddonCompartmentFrame then return end
  local fs = AddonCompartmentFrame.Text
    or (AddonCompartmentFrame.GetFontString and AddonCompartmentFrame:GetFontString())
  if not fs then
    local ok, regions = pcall(function() return { AddonCompartmentFrame:GetRegions() } end)
    if ok and regions then
      for _, r in ipairs(regions) do
        if r:IsObjectType("FontString") then
          fs = r
          break
        end
      end
    end
  end
  if not fs or not fs.GetFont or not fs.SetFont then return end

  if not AddonCompartmentFrame.slackHacksOrigFont then
    local fontFile, fontHeight, fontFlags = fs:GetFont()
    if fontHeight and fontHeight > 0 then
      AddonCompartmentFrame.slackHacksOrigFont = {
        fontFile = fontFile,
        fontHeight = fontHeight,
        fontFlags = fontFlags,
      }
    end
  end

  local orig = AddonCompartmentFrame.slackHacksOrigFont
  if not orig then return end

  if matchClock then
    local targetHeight = orig.fontHeight
    local clockFs = (TimeManagerClockButton and TimeManagerClockButton.GetFontString and TimeManagerClockButton:GetFontString())
      or (TimeManagerClockButton and TimeManagerClockButton.Text)
    if not clockFs and TimeManagerClockButton then
      local ok, regions = pcall(function() return { TimeManagerClockButton:GetRegions() } end)
      if ok and regions then
        for _, r in ipairs(regions) do
          if r:IsObjectType("FontString") then
            clockFs = r
            break
          end
        end
      end
    end

    if clockFs and clockFs.GetFont then
      local _, clockHeight = clockFs:GetFont()
      if clockHeight and clockHeight > 0 then
        -- Scale by relative frame scales (clock scale / compartment scale) so effective rendered size matches
        local clockEffectiveScale = TITLE_BAR_CLOCK_SCALE / TITLE_BAR_CALENDAR_TRACKING_SCALE
        targetHeight = math.floor(clockHeight * clockEffectiveScale + 0.5) + 2
      else
        targetHeight = targetHeight + 2
      end
    else
      targetHeight = targetHeight + 2
    end

    fs:SetFont(orig.fontFile, targetHeight, orig.fontFlags)
  else
    fs:SetFont(orig.fontFile, orig.fontHeight, orig.fontFlags)
  end
end

local function syncAddonCompartmentEntries()
  if not (AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon and AddonCompartmentFrame.registeredAddons) then return end
  clearAddonCompartmentEntries()

  if not settings().addonsInCompartment then
    return
  end

  for _, btn in ipairs(addonButtons) do
    if not isBlizzardFrame(btn) then
      local displayName = getAddonButtonDisplayName(btn)
      local iconTex = getAddonButtonIcon(btn)
      local entry = {
        text = displayName,
        icon = iconTex,
        notCheckable = true,
        registerForAnyClick = true,
        isSlackHacks = true,
        sourceButton = btn,
        func = function(menuBtn, menuInputData, menu)
          local mouseBtn = (menuInputData and menuInputData.buttonName) or "LeftButton"
          local script = btn:GetScript("OnClick")
          if script then
            script(btn, mouseBtn, false)
          elseif btn.Click then
            btn:Click(mouseBtn)
          end
        end,
        funcOnEnter = function(menuBtn, menuInputData, menu)
          local script = btn:GetScript("OnEnter")
          if script then
            script(btn)
          end
        end,
        funcOnLeave = function(menuBtn, menuInputData, menu)
          local script = btn:GetScript("OnLeave")
          if script then
            script(btn)
          else
            GameTooltip_Hide()
          end
        end,
      }
      AddonCompartmentFrame:RegisterAddon(entry)
    end
  end
  if AddonCompartmentFrame.UpdateDisplay then
    AddonCompartmentFrame:UpdateDisplay()
  end
end

local function getButtonAngle(button)
  if button.slackHacksAngle then
    return button.slackHacksAngle
  end
  if button.db and button.db.minimapPos then
    return button.db.minimapPos
  end
  if button.minimapPos then
    return button.minimapPos
  end
  local bx, by = button:GetCenter()
  local target = (settings().shape == "square" and getSquareBorderTargetFrame()) or _G.Minimap
  local mx, my = target:GetCenter()
  if bx and by and mx and my then
    return math.deg(math.atan2(by - my, bx - mx)) % 360
  end
  return 225
end

local function onAddonButtonDragUpdate(self)
  local target, radiusX, radiusY = getSquareBorderDimensions()
  local mx, my = target:GetCenter()
  local px, py = GetCursorPosition()
  local scale = target:GetEffectiveScale()
  px, py = px / scale, py / scale
  local angle = math.deg(math.atan2(py - my, px - mx)) % 360
  if self.db then
    self.db.minimapPos = angle
  end
  self.minimapPos = angle
  self.slackHacksAngle = angle

  local x, y = getSquarePositionForAngle(angle, radiusX, radiusY)

  if self.slackHacksRealClearAllPoints and self.slackHacksRealSetPoint then
    self.slackHacksRealClearAllPoints(self)
    self.slackHacksRealSetPoint(self, "CENTER", target, "CENTER", x, y)
  else
    self:ClearAllPoints()
    self:SetPoint("CENTER", target, "CENTER", x, y)
  end
end

local function onAddonButtonDragStart(self)
  if settings().shape ~= "square" or settings().addonsInCompartment then return end
  self.isDraggingOnSquareBorder = true
  if self.LockHighlight then self:LockHighlight() end
  setFrameStrataSafe(self, "DIALOG")
  setFrameLevelRecursive(self, 525)
  if self.Raise then self:Raise() end
  self:SetScript("OnUpdate", onAddonButtonDragUpdate)
  if GameTooltip then GameTooltip:Hide() end
end

local function onAddonButtonDragStop(self)
  self.isDraggingOnSquareBorder = nil
  self:SetScript("OnUpdate", nil)
  if self.UnlockHighlight then self:UnlockHighlight() end
end

local function enableAddonButtonDragging(button)
  if not button.slackHacksDragHooked then
    button.slackHacksDragHooked = true
    button:RegisterForDrag("LeftButton")
    button:HookScript("OnDragStart", onAddonButtonDragStart)
    button:HookScript("OnDragStop", onAddonButtonDragStop)
  end
end

setFrameStrataSafe = function(frame, strata)
  if frame.slackHacksRealSetFrameStrata then
    frame.slackHacksRealSetFrameStrata(frame, strata)
  else
    frame:SetFrameStrata(strata)
  end
end

--- Mappy's recursive frame level setter: ensures child icons/textures shift frame level
--- along with the button so no child elements draw behind the nine-slice border (level 500).
setFrameLevelRecursive = function(frame, level)
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

local function layoutAddonButtonsOnBorder()
  if settings().shape ~= "square" then return end

  if settings().addonsInCompartment then
    for _, btn in ipairs(addonButtons) do
      if not isBlizzardFrame(btn) then
        btn:Hide()
      end
    end
    return
  end

  local target, radiusX, radiusY = getSquareBorderDimensions()

  for _, button in ipairs(addonButtons) do
    if button and not isBlizzardFrame(button) then
      local shouldShow = button:IsShown()
      if button.db and button.db.hide ~= nil then
        shouldShow = not button.db.hide
      end
      if shouldShow then
        saveButtonState(button)
        enableButtonStacking(button, true)
        enableAddonButtonDragging(button)

        button:SetParent(target)
        setFrameStrataSafe(button, "DIALOG")
        setFrameLevelRecursive(button, 525)
        if button.Raise then button:Raise() end

        local angle = getButtonAngle(button)
        button.slackHacksAngle = angle
        local x, y = getSquarePositionForAngle(angle, radiusX, radiusY)

        if button.slackHacksRealClearAllPoints and button.slackHacksRealSetPoint then
          button.slackHacksRealClearAllPoints(button)
          button.slackHacksRealSetPoint(button, "CENTER", target, "CENTER", x, y)
        else
          button:ClearAllPoints()
          button:SetPoint("CENTER", target, "CENTER", x, y)
        end
        button:Show()
      end
    end
  end
end

--- Round-mode counterpart to `layoutAddonButtonsOnBorder`'s addonsInCompartment fold -- round mode never
--- repositions addon buttons (they stay in their native/library-driven spot), so folding is just a plain
--- Hide/Show, tracked per-button so we only ever restore a button that we ourselves hid.
local function applyRoundAddonCompartment()
  if not isModuleEnabled() then return end
  syncAddonCompartmentEntries()
  if settings().shape == "square" then return end

  local fold = settings().addonsInCompartment
  for _, btn in ipairs(addonButtons) do
    if btn and not isBlizzardFrame(btn) then
      if fold then
        if not btn.slackHacksCompartmentFolded then
          btn.slackHacksCompartmentFolded = true
          setShownSafely(btn, false)
        end
      elseif btn.slackHacksCompartmentFolded then
        btn.slackHacksCompartmentFolded = false
        setShownSafely(btn, true)
      end
    end
  end
end

local function disableAllStacking()
  -- These were only ever faded via SetAlpha while hidden-until-hover in square mode (never SetShown),
  -- so just restore full opacity before handing them back to Blizzard's own show/hide logic.
  for _, btn in ipairs(hoverContainerButtons) do
    if btn then btn:SetAlpha(1) end
  end
  wipe(hoverContainerButtons)

  for _, button in ipairs(registeredButtons) do
    enableButtonStacking(button, false)
  end
  wipe(registeredButtons)
  wipe(registeredButtonsByFrame)
  -- Deliberately NOT wiping addonButtons/addonButtonsByFrame here -- round mode still needs the
  -- discovered list for "Show Addon Icons on Hover"/"Move Addon Icons to Addon Compartment".

  local diff = getInstanceDifficultyButton()
  if diff then enableButtonStacking(diff, false) end

  clearAddonCompartmentEntries()
  applyBlizzardIconBorders(false)

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

local function getExistingAddonButtons()
  local buttons = {}
  local seen = {}

  -- 1. LibDBIcon-1.0 registered buttons (covers almost 100% of modern addons)
  local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
  if ldbi and ldbi.objects then
    for name, button in pairs(ldbi.objects) do
      if button and not seen[button] and not isBlizzardFrame(button) then
        local shown = button:IsShown()
        if button.db and button.db.hide ~= nil then
          shown = not button.db.hide
        end
        if shown then
          table.insert(buttons, button)
          seen[button] = true
        end
      end
    end
  end

  -- 2. Direct children of Minimap that are buttons, shown, and not Blizzard.
  -- IMPORTANT: quest POI icons and gathering-node ("Find Herbs"/"Find Minerals") vignette icons are also
  -- pooled Button-type frames parented directly to Minimap, but unlike real addon minimap buttons they are
  -- anonymous (no global name, since they come from a CreateFramePool and are reused/repositioned every
  -- refresh) -- require a real name (and a plausible icon-button size) so we never hijack SetPoint/parent
  -- on Blizzard's own native quest/node icons.
  if _G.Minimap and _G.Minimap.GetChildren then
    local ok, children = pcall(function() return { _G.Minimap:GetChildren() } end)
    if ok and children then
      for _, child in ipairs(children) do
        if child and not seen[child] and not isBlizzardFrame(child) and child:IsShown() then
          local okType, objType = pcall(child.GetObjectType, child)
          local name = child.GetName and child:GetName()
          local w = child.GetWidth and child:GetWidth() or 0
          local h = child.GetHeight and child:GetHeight() or 0
          if okType and objType == "Button" and name and w >= 14 and w <= 64 and h >= 14 and h <= 64 then
            table.insert(buttons, child)
            seen[child] = true
          end
        end
      end
    end
  end

  -- 3. Specific known legacy addon buttons (only if shown)
  local knownLegacy = { "CT_RASets_Button", "MBB_MinimapButtonFrame", "WIM3MinimapButton" }
  for _, name in ipairs(knownLegacy) do
    local btn = _G[name]
    if btn and not seen[btn] and not isBlizzardFrame(btn) and btn:IsShown() then
      table.insert(buttons, btn)
      seen[btn] = true
    end
  end

  return buttons
end

local function discoverAddonButtons()
  wipe(addonButtons)
  wipe(addonButtonsByFrame)
  local found = getExistingAddonButtons()
  for _, btn in ipairs(found) do
    registerAddonButton(btn)
    if isForever() then
      applyCycleBorderToAddonButton(btn)
    end
  end
end

isButtonShown = function(button)
  if not button then return false end
  local mail = getMailButton()
  local crafting = getCraftingOrderButton()
  local diff = getInstanceDifficultyButton()
  local garrison = getGarrisonButton()

  if settings().shape == "square" then
    if button == mail then
      return HasNewMail and HasNewMail() and button:IsShown()
    end
    if button == crafting then
      if not isRetail() then return false end
      return (crafting.countInfos and #crafting.countInfos > 0) and button:IsShown()
    end
    if button == diff then
      return settings().showInstanceDifficulty and true or false
    end
    if button == garrison then
      return settings().showGarrison and isGarrisonLandingPageAvailable()
    end
    if button == TimeManagerClockButton then
      return settings().showClock and true or false
    end
    if button == GameTimeFrame then
      return settings().showCalendar and true or false
    end
    if button == (MinimapCluster and MinimapCluster.Tracking) then
      return settings().showTracking and true or false
    end
    if button == AddonCompartmentFrame then
      return settings().showAddonCompartment and true or false
    end
  end

  if not isRetail() and (button == crafting or button == garrison) then
    return false
  end

  return button:IsShown()
end

local function layoutCornerIcons()
  local mm = settings()
  local isSquare = (mm.shape == "square")

  local diff = getInstanceDifficultyButton()
  if diff then
    if isSquare then
      registerButton(diff)
      enableButtonStacking(diff, true)
      diff:SetParent(MinimapCluster or _G.Minimap)
      diff:SetScale(TITLE_BAR_ICON_SCALE)
      setFrameStrataSafe(diff, "DIALOG")
      setFrameLevelRecursive(diff, 525)
      if diff.Raise then diff:Raise() end
      diff.slackHacksRealClearAllPoints(diff)
      -- Anchored below the title bar (which overlaps the top strip of the map texture in square mode),
      -- not the full _G.Minimap frame rect, so it lands on the visible map surface instead of the bar.
      diff.slackHacksRealSetPoint(diff, "TOPRIGHT", titleBarFrame, "BOTTOMRIGHT", 4, -4)

      -- Not part of the hidden-until-hover group -- always visible unless the user hides it via
      -- the "Show Instance Difficulty" option (native Blizzard visibility/content is otherwise trusted).
      setShownSafely(diff, mm.showInstanceDifficulty)
      diff:SetAlpha(1)
    else
      enableButtonStacking(diff, false)
    end
  end
end

local function getButtonScaledWidth(button)
  local scale = TITLE_BAR_ICON_SCALE
  if button == TimeManagerClockButton then
    scale = TITLE_BAR_CLOCK_SCALE
  elseif button == getGarrisonButton() then
    scale = TITLE_BAR_GARRISON_SCALE
  elseif button == AddonCompartmentFrame or button == GameTimeFrame or button == (MinimapCluster and MinimapCluster.Tracking) then
    scale = TITLE_BAR_CALENDAR_TRACKING_SCALE
  end
  local btnW = button:GetWidth()
  if button == TimeManagerClockButton and button.slackHacksSaved and button.slackHacksSaved.width then
    btnW = math.max(10, button.slackHacksSaved.width + TITLE_BAR_CLOCK_WIDTH_DELTA)
  end
  return (btnW and btnW > 0 and btnW or 32) * scale, scale
end

local function getButtonYOffset(button)
  if button == GameTimeFrame then
    return TITLE_BAR_CALENDAR_Y_OFFSET
  elseif button == (MinimapCluster and MinimapCluster.Tracking) then
    return TITLE_BAR_TRACKING_Y_OFFSET
  elseif button == AddonCompartmentFrame then
    return TITLE_BAR_ADDON_COMPARTMENT_Y_OFFSET
  elseif button == TimeManagerClockButton then
    return TITLE_BAR_CLOCK_Y_OFFSET
  end
  return 0
end

--- Builds the list of buttons for the permanent title bar flow.
--- Right-to-left layout order: Clock, Mail, Crafting Orders, standard icons (if not hover-only),
--- and Addon Compartment / Garrison (if not hover-only).
local function getTitleBarFlowButtons()
  local mm = settings()
  local list = {}

  -- 1. Clock (rightmost)
  if mm.showClock and TimeManagerClockButton then
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

  if not mm.showIconsOnHover then
    if mm.showCalendar and GameTimeFrame then
      table.insert(list, GameTimeFrame)
    end
    if mm.showTracking and MinimapCluster and MinimapCluster.Tracking then
      table.insert(list, MinimapCluster.Tracking)
    end
    if mm.showAddonCompartment and AddonCompartmentFrame then
      table.insert(list, AddonCompartmentFrame)
    end
  end

  return list
end

local function getHoverButtons()
  local mm = settings()
  local list = {}

  if mm.showIconsOnHover then
    if mm.showCalendar and GameTimeFrame then
      table.insert(list, GameTimeFrame)
    end
    if mm.showTracking and MinimapCluster and MinimapCluster.Tracking then
      table.insert(list, MinimapCluster.Tracking)
    end
    -- Second from the left, right after the Campaign/Garrison icon appended below -- it's a Blizzard
    -- icon, not a 3rd-party addon icon, so it's governed by showIconsOnHover like Calendar/Tracking.
    if mm.showAddonCompartment and AddonCompartmentFrame then
      table.insert(list, AddonCompartmentFrame)
    end
  end

  -- Keep the expansion button in the hover container even when Blizzard icons are otherwise persistent.
  -- Appending it last makes it the far-left item because the list is laid out right-to-left.
  local garrison = getGarrisonButton()
  if mm.showGarrison and garrison then
    table.insert(list, garrison)
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

--- Lays out icons hidden without hover in a separate container frame with a HIGH frame strata.
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

  local hoverButtons = getHoverButtons()
  local totalWidth = 0
  local buttonGap = 2
  local previousHover = nil
  wipe(hoverContainerButtons)

  for _, button in ipairs(hoverButtons) do
    registerButton(button)
    if isButtonShown(button) then
      table.insert(hoverContainerButtons, button)
      enableButtonStacking(button, true)
      -- Reparent to MinimapCluster (Blizzard's own expected ancestor for these buttons), never to our
      -- custom `container` -- OnClick handlers for things like AddonCompartmentFrame/Tracking rely on
      -- their native ancestry and silently break (while tooltips keep working) if reparented elsewhere.
      button:SetParent(MinimapCluster or _G.Minimap)
      -- Real Show() here (not alpha) -- the button genuinely belongs in the flow; visibility of the
      -- hidden-until-hover group itself is driven purely by SetAlpha in updateHoverVisibility, same
      -- proven technique already used for the corner Instance Difficulty icon -- never SetShown,
      -- which is what broke Calendar/AddonCompartment/Garrison clicks previously.
      setShownSafely(button, true)
      local scaledW, scale = getButtonScaledWidth(button)
      button:SetScale(scale)
      setFrameStrataSafe(button, "DIALOG")
      setFrameLevelRecursive(button, 525)
      if button.Raise then button:Raise() end
      button.slackHacksRealClearAllPoints(button)
      local isSubsequent = (previousHover ~= nil)
      local yOffset = getButtonYOffset(button)
      if previousHover then
        button.slackHacksRealSetPoint(button, "RIGHT", previousHover, "LEFT", -buttonGap, yOffset)
      else
        button.slackHacksRealSetPoint(button, "RIGHT", container, "RIGHT", 0, yOffset)
      end
      previousHover = button
      totalWidth = totalWidth + scaledW + (isSubsequent and buttonGap or 0)
    else
      setShownSafely(button, false)
    end
  end

  container:SetWidth(math.max(1, totalWidth))
  updateHoverVisibility()
end

--- Shrinks and lines up the minimap buttons along the right side of the title bar,
--- ordered right-to-left: Clock, standard icons, addon compartment.
local function layoutTitleBarIcons()
  local row = titleBarIconRow
  if not row then return end

  local buttons = getTitleBarFlowButtons()
  local previous = nil

  for _, button in ipairs(buttons) do
    registerButton(button)
    if isButtonShown(button) then
      enableButtonStacking(button, true)
      button:SetParent(MinimapCluster or _G.Minimap)
      -- Permanent-flow buttons are always fully visible -- reset Shown/alpha in case this button was
      -- previously managed by the hidden-until-hover container (which hides via SetShown/fades via alpha).
      setShownSafely(button, true)
      button:SetAlpha(1)
      local _, scale = getButtonScaledWidth(button)
      local yOffset = getButtonYOffset(button)
      if button == TimeManagerClockButton and button.slackHacksSaved and button.slackHacksSaved.width then
        button:SetWidth(math.max(10, button.slackHacksSaved.width + TITLE_BAR_CLOCK_WIDTH_DELTA))
      end
      button:SetScale(scale)
      setFrameStrataSafe(button, row:GetFrameStrata())
      setFrameLevelRecursive(button, row:GetFrameLevel() + 1)
      button.slackHacksRealClearAllPoints(button)
      local xOffset = (button == TimeManagerClockButton) and TITLE_BAR_CLOCK_X_OFFSET or 0
      if previous then
        button.slackHacksRealSetPoint(button, "RIGHT", previous, "LEFT", -2 + xOffset, yOffset)
      else
        button.slackHacksRealSetPoint(button, "RIGHT", row, "RIGHT", xOffset, yOffset)
      end
      previous = button
    else
      setShownSafely(button, false)
    end
  end

  layoutTitleBarZoneButton(previous)
  layoutAddonIconsContainer(previous)
  layoutCornerIcons()
  layoutAddonButtonsOnBorder()
end

applyTitleBarLayout = function()
  if not isModuleEnabled() then return end
  local mm = settings()
  discoverAddonButtons()
  if not addonScanTicker then
    addonScanTicker = C_Timer.NewTicker(2, function()
      local prevCount = #addonButtons
      discoverAddonButtons()
      if #addonButtons ~= prevCount then
        scheduleTitleBarLayout()
      end
    end)
  end
  if mm.shape ~= "square" then
    if titleBarFrame then titleBarFrame:Hide() end
    if addonIconsContainer then addonIconsContainer:Hide() end
    if hoverCheckTicker then
      hoverCheckTicker:Cancel()
      hoverCheckTicker = nil
    end
    disableAllStacking()
    restoreRoundMinimapCluster()
    applyAddonCompartmentFontSize(nil)
    updateEditModeSelectionBounds()
    updateHoverVisibility()
    if Minimap_Update then
      pcall(Minimap_Update)
    end
    return
  end

  applySquareMinimapCluster()
  if _G.Minimap.SetClipsChildren then
    _G.Minimap:SetClipsChildren(false)
  end

  local bar = createTitleBar()
  bar:Show()
  -- Deliberately NOT hooking _G.Minimap's own OnEnter/OnLeave here (unlike the other reference frames
  -- below) -- that hook sits directly on the real Blizzard frame hosting quest/vignette POI pins, and
  -- was suspected of interfering with their native tooltip display in square mode. MinimapCluster's own
  -- hover hook (and the polling ticker) already cover the same on-screen area for our hover-reveal feature.
  hookHoverFrame(titleBarFrame)
  hookHoverFrame(squareBorderFrame)
  hookHoverFrame(MinimapCluster)
  local zb = getZoneTextButton()
  if zb then hookHoverFrame(zb) end

  applyBlizzardIconBorders(true)
  applyAddonCompartmentFontSize(true)
  layoutTitleBarIcons()
  updateEditModeSelectionBounds()
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
  applyMinimapRotation()
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
  applyRoundAddonCompartment()
  applyAllAddonButtonBorders()
  updateHoverVisibility()

  if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() and EditModeSystemSettingsDialog.attachedToSystem == MinimapCluster then
    EditModeSystemSettingsDialog:UpdateDialog(MinimapCluster)
  end
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

  local percentFormat = function(v) return math.floor(v + 0.5) .. "%" end

  local curY = -46
  _, curY = addCheckbox("Enable Minimap Enhancements",
    function() return db.profile.minimap.enabled end,
    function(v) db.profile.minimap.enabled = v end,
    curY)

  curY = addDivider(curY - 2)
  _, curY = addCheckbox("Show All Tracking Options",
    function() return db.profile.minimap.showAllMinimapTracking end,
    function(v) db.profile.minimap.showAllMinimapTracking = v end,
    curY)
  _, curY = addCheckbox("Show Addon Icons on Hover Only",
    function() return db.profile.minimap.showAddonIconsOnHover end,
    function(v) db.profile.minimap.showAddonIconsOnHover = v end,
    curY)
  _, curY = addCheckbox("Move Addon Icons to Addon Compartment",
    function() return db.profile.minimap.addonsInCompartment end,
    function(v) db.profile.minimap.addonsInCompartment = v end,
    curY)
  if not isRetail() then
    _, curY = addCheckbox("Hide Day/Night Icon",
      function() return db.profile.minimap.hideDiel end,
      function(v) db.profile.minimap.hideDiel = v end,
      curY)
  end

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
  curY = addHeader("Square Minimap", curY)
  local squareDependents = {}
  local squareCb
  squareCb, curY = addCheckbox("Enable",
    function() return db.profile.minimap.shape == "square" end,
    function(v)
      db.profile.minimap.shape = v and "square" or "circle"
    end,
    curY, squareDependents)
  local cb
  cb, curY = addCheckbox("Show Blizzard Icons On Hover",
    function() return db.profile.minimap.showIconsOnHover end,
    function(v) db.profile.minimap.showIconsOnHover = v end,
    curY)
  table.insert(squareDependents, cb)
  cb, curY = addCheckbox("Show Zone Text",
    function() return db.profile.minimap.showZoneText end,
    function(v) db.profile.minimap.showZoneText = v end,
    curY)
  table.insert(squareDependents, cb)
  cb, curY = addCheckbox("Show Clock",
    function() return db.profile.minimap.showClock end,
    function(v) db.profile.minimap.showClock = v end,
    curY)
  table.insert(squareDependents, cb)
  cb, curY = addCheckbox("Show Tracking",
    function() return db.profile.minimap.showTracking end,
    function(v) db.profile.minimap.showTracking = v end,
    curY)
  table.insert(squareDependents, cb)
  cb, curY = addCheckbox("Show Calendar",
    function() return db.profile.minimap.showCalendar end,
    function(v) db.profile.minimap.showCalendar = v end,
    curY)
  table.insert(squareDependents, cb)
  cb, curY = addCheckbox("Show Instance Difficulty",
    function() return db.profile.minimap.showInstanceDifficulty end,
    function(v) db.profile.minimap.showInstanceDifficulty = v end,
    curY)
  table.insert(squareDependents, cb)
  cb, curY = addCheckbox("Show Garrison/Expansion Landing Page",
    function() return db.profile.minimap.showGarrison end,
    function(v) db.profile.minimap.showGarrison = v end,
    curY)
  table.insert(squareDependents, cb)
  cb, curY = addCheckbox("Show Addon Compartment",
    function() return db.profile.minimap.showAddonCompartment end,
    function(v) db.profile.minimap.showAddonCompartment = v end,
    curY)
  table.insert(squareDependents, cb)

  dialog:SetHeight(math.abs(curY) + 24)

  function dialog:RefreshValues()
    for _, fn in ipairs(controls) do fn() end
    local isSquare = (db.profile.minimap.shape == "square")
    for _, dep in ipairs(squareDependents) do
      dep:SetEnabled(isSquare)
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
  if MinimapCluster and not origSetHeaderUnderneath and MinimapCluster.SetHeaderUnderneath then
    origSetHeaderUnderneath = MinimapCluster.SetHeaderUnderneath
    MinimapCluster.SetHeaderUnderneath = function(self, headerUnderneath)
      if isModuleEnabled() and settings().shape == "square" then
        if self.BorderTop then
          self.BorderTop:SetAlpha(0)
          self.BorderTop:Hide()
          self.BorderTop.ignoreInLayout = true
        end
        applySquareMinimapCluster()
        return
      end
      return origSetHeaderUnderneath(self, headerUnderneath)
    end
  end

  if MinimapCluster and not origSetRotateMinimap and MinimapCluster.SetRotateMinimap then
    origSetRotateMinimap = MinimapCluster.SetRotateMinimap
    MinimapCluster.SetRotateMinimap = function(self, rotateMinimap)
      if isModuleEnabled() and settings().shape == "square" then
        local wantRotate = (rotateMinimap == true or rotateMinimap == 1)
        if wantRotate then
          userWantedRotateMinimap = true
          if db and db.profile and db.profile.minimap then
            db.profile.minimap.savedRotateMinimap = true
          end
        end
        SetCVar("rotateMinimap", 0)
        return
      end
      return origSetRotateMinimap(self, rotateMinimap)
    end
  end

  if MinimapCluster and not origShouldShowSetting and MinimapCluster.ShouldShowSetting then
    origShouldShowSetting = MinimapCluster.ShouldShowSetting
    MinimapCluster.ShouldShowSetting = function(self, setting)
      if isModuleEnabled() and settings().shape == "square" then
        if Enum and Enum.EditModeMinimapSetting then
          if setting == Enum.EditModeMinimapSetting.HeaderUnderneath then
            return false
          elseif setting == Enum.EditModeMinimapSetting.RotateMinimap then
            return false
          end
        end
      end
      if origShouldShowSetting then
        return origShouldShowSetting(self, setting)
      end
      return self.HasSetting and self:HasSetting(setting)
    end
  end

  if MinimapCluster and not origSetEditModeScale and MinimapCluster.SetEditModeScale then
    origSetEditModeScale = MinimapCluster.SetEditModeScale
    hooksecurefunc(MinimapCluster, "SetEditModeScale", function(self, scale)
      if isModuleEnabled() and settings().shape == "square" then
        applySquareMinimapCluster()
        updateEditModeSelectionBounds()
        scheduleTitleBarLayout()
      end
    end)
  end

  if MinimapCluster and MinimapCluster.BorderTop and not MinimapCluster.BorderTop.slackHacksHookedOnShow then
    MinimapCluster.BorderTop.slackHacksHookedOnShow = true
    MinimapCluster.BorderTop:HookScript("OnShow", function(self)
      if isModuleEnabled() and settings().shape == "square" then
        self:Hide()
        self:SetAlpha(0)
        self.ignoreInLayout = true
      end
    end)
  end

  if MinimapCluster and MinimapCluster.AnchorSelectionFrame then
    hooksecurefunc(MinimapCluster, "AnchorSelectionFrame", updateEditModeSelectionBounds)
  end

  if not (EditModeManagerFrame and EditModeSystemSettingsDialog and Enum.EditModeSystem) then return end

  hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(_, systemFrame)
    showOptionsDialog(systemFrame and systemFrame.system == Enum.EditModeSystem.Minimap)
  end)
  EditModeSystemSettingsDialog:HookScript("OnHide", function() showOptionsDialog(false) end)

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
  self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", "ApplyAll")
  self:RegisterEvent("UPDATE_INSTANCE_INFO", "ApplyAll")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "ApplyAll")
  if isRetail() and (not C_EventUtils or C_EventUtils.IsEventValid("GARRISON_LANDING_PAGE_UPDATED")) then
    self:RegisterEvent("GARRISON_LANDING_PAGE_UPDATED", "ApplyAll")
  end
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_STARTED_MOVING")
  self:RegisterEvent("PLAYER_STOPPED_MOVING")
  self:RegisterEvent("CVAR_UPDATE")
  self:ApplyAll()
end

function module:CVAR_UPDATE(event, cvarName)
  if cvarName == "rotateMinimap" then
    if isModuleEnabled() and settings().shape == "square" then
      if GetCVar("rotateMinimap") == "1" then
        userWantedRotateMinimap = true
        if db and db.profile and db.profile.minimap then
          db.profile.minimap.savedRotateMinimap = true
        end
        SetCVar("rotateMinimap", 0)
      end
    end
  end
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
  restoreMinimapRotation()
  restoreCoordinates()
  clearAddonCompartmentEntries()
  applyAddonCompartmentFontSize(nil)
  applyBlizzardIconBorders(false)
  if squareBorderFrame then squareBorderFrame:Hide() end
  if titleBarFrame then titleBarFrame:Hide() end
  if addonIconsContainer then addonIconsContainer:Hide() end
  disableAllStacking()
  restoreRoundMinimapCluster()
  if MinimapCluster then
    MinimapCluster:SetAlpha(1)
  end
  if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() and EditModeSystemSettingsDialog.attachedToSystem == MinimapCluster then
    EditModeSystemSettingsDialog:UpdateDialog(MinimapCluster)
  end
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
    for _, icon in ipairs(getStandardMinimapIcons()) do
      if icon then icon:SetAlpha(1) end
    end
    if AddonCompartmentFrame then AddonCompartmentFrame:SetAlpha(1) end
    for _, btn in ipairs(addonButtons) do
      if btn then
        if btn.slackHacksCompartmentFolded then
          btn.slackHacksCompartmentFolded = false
          setShownSafely(btn, true)
        end
        btn:SetAlpha(1)
      end
    end
    restoreAllAddonButtonBorders()
  end
  wipe(addonButtons)
  wipe(addonButtonsByFrame)
  if MinimapBackdrop then MinimapBackdrop:SetAlpha(1) end
  ensureCVar("minimapTrackingShowAll", GetCVarDefault("minimapTrackingShowAll"))
end
