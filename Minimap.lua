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

local COORD_ANCHOR_INFO = {
  BOTTOMLEFT = { x = 5, y = 4 },
  BOTTOM = { x = 0, y = 4 },
  BOTTOMRIGHT = { x = -5, y = 4 },
}

-- Falls back to Blizzard's untouched defaults whenever the module is disabled.
local DEFAULT_VISUALS = {
  shape = "circle",
  alpha = 100,
  fadeEnabled = false,
  combatAlpha = 100,
  movingAlpha = 100,
  showCoordinates = false,
  coordinatesAnchor = "BOTTOMLEFT",
  coordinatesScale = 100,
  showZoneText = true,
  showClock = true,
  showCalendar = true,
  showTracking = true,
  showAllMinimapTracking = false,
  hideExtraButtons = false,
  hideDiel = false,
  addonButtonsPosition = "right",
  showBorder = true,
  mouseWheelZoom = true,
}

local function settings()
  if db.profile.minimap.enabled then return db.profile.minimap end
  return DEFAULT_VISUALS
end

local isInCombat = false
local isMoving = false
local coordText
local coordTicker
local optionsDialog
local squareBorderFrame
local titleBarFrame
local titleBarZoneText
local titleBarIconRow
local savedIconAnchors = {}

local function extraButtons()
  local indicatorFrame = MinimapCluster and MinimapCluster.IndicatorFrame
  return {
    indicatorFrame and indicatorFrame.MailFrame,
    indicatorFrame and indicatorFrame.CraftingOrderFrame,
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

--- Every minimap icon button we know how to shrink/reposition into the square mode's title bar, ordered
--- right-to-left (first entry ends up rightmost): clock, calendar/tracking/other buttons, addon compartment.
local function iconBarFrames()
  local frames = {}
  if TimeManagerClockButton then table.insert(frames, TimeManagerClockButton) end
  if GameTimeFrame then table.insert(frames, GameTimeFrame) end
  if MinimapCluster and MinimapCluster.Tracking then table.insert(frames, MinimapCluster.Tracking) end
  for _, button in ipairs(extraButtons()) do
    if button then table.insert(frames, button) end
  end
  return frames
end

--- Show/hide is deferred (skipped, not queued) while in combat; PLAYER_REGEN_ENABLED re-applies everything.
local function setShownSafely(frame, shown)
  if not frame or InCombatLockdown() then return end
  frame:SetShown(shown)
end

local function applyShape()
  if not _G.Minimap.SetMaskTexture then return end -- not available on this client build; shape stays default
  _G.Minimap:SetMaskTexture(settings().shape == "square" and SQUARE_MASK_TEXTURE or ROUND_MASK_TEXTURE)
end

local function applyAlpha()
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
  _G.Minimap:SetAlpha(clampedPercent / 100)
end

local function updateCoordinatesText()
  if not coordText then return end
  local mapID = C_Map.GetBestMapForUnit("player")
  local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  if position then
    local x, y = position:GetXY()
    coordText:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
  else
    coordText:SetText("")
  end
end

local function createCoordinatesText()
  if not coordText then
    coordText = _G.Minimap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  end
  return coordText
end

local function applyCoordinates()
  local mm = settings()
  if not mm.showCoordinates then
    if coordText then coordText:Hide() end
    if coordTicker then
      coordTicker:Cancel()
      coordTicker = nil
    end
    return
  end

  createCoordinatesText()
  local anchorPoint = mm.coordinatesAnchor or "BOTTOMLEFT"
  local anchor = COORD_ANCHOR_INFO[anchorPoint] or COORD_ANCHOR_INFO.BOTTOMLEFT
  coordText:ClearAllPoints()
  coordText:SetPoint(anchorPoint, _G.Minimap, anchorPoint, anchor.x, anchor.y)
  local fontFile, fontSize, fontFlags = GameFontHighlightSmall:GetFont()
  coordText:SetFont(fontFile, fontSize * ((mm.coordinatesScale or 100) / 100), fontFlags)
  coordText:Show()
  updateCoordinatesText()

  if not coordTicker then
    coordTicker = C_Timer.NewTicker(0.2, updateCoordinatesText)
  end
end

local function applyZoneText()
  -- In square mode our own title-bar label (see applyTitleBarLayout) replaces the native zone text.
  local mm = settings()
  setShownSafely(MinimapCluster and MinimapCluster.ZoneTextButton, mm.showZoneText and mm.shape ~= "square")
end

local function applyClock()
  setShownSafely(TimeManagerClockButton, settings().showClock)
end

local function applyCalendar()
  setShownSafely(GameTimeFrame, settings().showCalendar)
end

--- MinimapCluster.DielFrame is the oversized day/night ("diel" = 24-hour cycle) sun/moon icon shown on
--- Classic/Forever's minimap; it has no counterpart shown on Retail's minimap.
local function applyDielFrame()
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
  setShownSafely(MinimapCluster and MinimapCluster.Tracking, settings().showTracking)
end

local function applyTrackingCVar()
  if settings().showAllMinimapTracking then
    ensureCVar("minimapTrackingShowAll", 1) -- Show all minimap tracking options (including turning off target tracking!)
  else
    ensureCVar("minimapTrackingShowAll", GetCVarDefault("minimapTrackingShowAll"))
  end
end

local function applyExtraButtons()
  local shown = not settings().hideExtraButtons
  for _, button in ipairs(extraButtons()) do
    setShownSafely(button, shown)
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
  frame:SetPoint("TOPLEFT", _G.Minimap, "TOPLEFT", -9, 9)
  frame:SetPoint("BOTTOMRIGHT", _G.Minimap, "BOTTOMRIGHT", 9, -9)
  CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
  squareBorderFrame = frame
  return frame
end

local function applyBorder()
  local mm = settings()
  local isSquare = mm.shape == "square"
  if MinimapBackdrop then
    MinimapBackdrop:SetAlpha((not isSquare and mm.showBorder) and 1 or 0)
  end
  if isSquare then
    createSquareBorder():SetShown(mm.showBorder)
  elseif squareBorderFrame then
    squareBorderFrame:Hide()
  end
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

  -- GameFontNormalSmall = same NORMAL_FONT_COLOR gold used by Blizzard's own window titles (e.g. the
  -- Spellbook), just at a size that fits our compact title bar.
  local zoneText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  zoneText:SetPoint("LEFT", frame, "LEFT", 0, 0)
  zoneText:SetJustifyH("LEFT")
  titleBarZoneText = zoneText

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

local function updateTitleBarZoneText()
  if titleBarZoneText and GetMinimapZoneText then
    titleBarZoneText:SetText(GetMinimapZoneText() or "")
  end
end

--- Blizzard's own layout code (or the button's own library) re-anchors AND re-strata/re-levels these
--- icons on its own, which would otherwise silently undo our positioning/layering a moment later;
--- swallow those calls and drive everything ourselves via the real underlying methods.
local function hijackPositioning(frame)
  if frame.slackHacksRealSetPoint then return end
  frame.slackHacksRealSetPoint = frame.SetPoint
  frame.slackHacksRealClearAllPoints = frame.ClearAllPoints
  frame.slackHacksRealSetFrameStrata = frame.SetFrameStrata
  frame.slackHacksRealSetFrameLevel = frame.SetFrameLevel
  frame.SetPoint = function() end
  frame.ClearAllPoints = function() end
  frame.SetFrameStrata = function() end
  frame.SetFrameLevel = function() end
end

local function releasePositioning(frame)
  if not frame.slackHacksRealSetPoint then return end
  frame.SetPoint = frame.slackHacksRealSetPoint
  frame.ClearAllPoints = frame.slackHacksRealClearAllPoints
  frame.SetFrameStrata = frame.slackHacksRealSetFrameStrata
  frame.SetFrameLevel = frame.slackHacksRealSetFrameLevel
  frame.slackHacksRealSetPoint = nil
  frame.slackHacksRealClearAllPoints = nil
  frame.slackHacksRealSetFrameStrata = nil
  frame.slackHacksRealSetFrameLevel = nil
end

local function saveIconAnchor(frame)
  if savedIconAnchors[frame] then return end
  local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
  savedIconAnchors[frame] = {
    point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y,
    scale = frame:GetScale(), frameLevel = frame:GetFrameLevel(), strata = frame:GetFrameStrata(),
  }
end

local function restoreIconAnchor(frame)
  local saved = savedIconAnchors[frame]
  if not saved then return end
  releasePositioning(frame) -- give Blizzard back control before calling these methods ourselves
  frame:SetScale(saved.scale)
  frame:SetFrameLevel(saved.frameLevel)
  frame:SetFrameStrata(saved.strata)
  frame:ClearAllPoints()
  if saved.point then
    frame:SetPoint(saved.point, saved.relativeTo, saved.relativePoint, saved.x, saved.y)
  end
  savedIconAnchors[frame] = nil
end

--- Shrinks and lines up the minimap's icon buttons along the right side of the title bar, all anchored
--- to the shared `titleBarIconRow` wrapper so they line up on the exact same strata/level/edge.
local function layoutTitleBarIcons(row)
  local previous
  for _, frame in ipairs(iconBarFrames()) do
    if frame:IsShown() then
      saveIconAnchor(frame)
      hijackPositioning(frame)
      frame:SetScale(frame == TimeManagerClockButton and TITLE_BAR_CLOCK_SCALE or TITLE_BAR_ICON_SCALE)
      frame.slackHacksRealSetFrameStrata(frame, row:GetFrameStrata())
      frame.slackHacksRealSetFrameLevel(frame, row:GetFrameLevel() + 1)
      frame.slackHacksRealClearAllPoints(frame)
      if previous then
        frame.slackHacksRealSetPoint(frame, "RIGHT", previous, "LEFT", -2, 0)
      else
        frame.slackHacksRealSetPoint(frame, "RIGHT", row, "RIGHT", 0, 0)
      end
      previous = frame
    end
  end
end

local function applyTitleBarLayout()
  local mm = settings()
  if mm.shape ~= "square" then
    if titleBarFrame then titleBarFrame:Hide() end
    for _, frame in ipairs(iconBarFrames()) do
      restoreIconAnchor(frame)
    end
    return
  end

  local bar = createTitleBar()
  bar:Show()
  titleBarZoneText:SetShown(mm.showZoneText)
  updateTitleBarZoneText()
  layoutTitleBarIcons(titleBarIconRow)
end

local ADDON_BUTTON_GAP = 4
local ADDON_BUTTON_INSET = 8 -- overlap the border/map by this much instead of sitting flush outside it
local addonButtonRescanTicker
local lastAddonButtonCount

--- Third-party addon minimap buttons aren't in our known `extraButtons()` list, so find them the same
--- way Mappy does: any small, roughly-square frame parented directly to the minimap/cluster/backdrop,
--- OR (many libraries, e.g. LibDBIcon, do this instead) parented elsewhere but anchored directly to one
--- of those frames. Mappy wraps `GetPoint` in `pcall` since some frames are "secret"-tainted and error
--- when queried -- do the same so one bad frame can't abort the whole scan.
local function isCandidateAddonButton(frame)
  if not frame then return false end
  local ok, forbidden = pcall(frame.IsForbidden, frame)
  if not ok or forbidden then return false end
  if frame.GetObjectType and frame:GetObjectType() == "Model" then return false end
  local okSize, width, height = pcall(function() return frame:GetWidth(), frame:GetHeight() end)
  if not okSize or not width or not height then return false end
  if width < 14 or width > 64 or math.abs(width - height) > 4 then return false end
  return true
end

local function managedFrameSet()
  local managed = { [_G.Minimap] = true }
  if MinimapCluster then
    managed[MinimapCluster] = true
    managed[MinimapCluster.ZoneTextButton] = true
    managed[MinimapCluster.Tracking] = true
    managed[MinimapCluster.DielFrame] = true
  end
  if MinimapBackdrop then managed[MinimapBackdrop] = true end
  if squareBorderFrame then managed[squareBorderFrame] = true end
  if titleBarFrame then managed[titleBarFrame] = true end
  if TimeManagerClockButton then managed[TimeManagerClockButton] = true end
  if _G.Minimap.ZoomIn then managed[_G.Minimap.ZoomIn] = true end
  if _G.Minimap.ZoomOut then managed[_G.Minimap.ZoomOut] = true end
  if _G.Minimap.ZoomHitArea then managed[_G.Minimap.ZoomHitArea] = true end
  if MinimapToggleButton then managed[MinimapToggleButton] = true end
  for _, frame in ipairs(iconBarFrames()) do
    managed[frame] = true
  end
  return managed
end

local function isAnchoredToMinimap(frame)
  local ok, numPoints = pcall(frame.GetNumPoints, frame)
  if not ok then return false end
  for pointIndex = 1, (numPoints or 0) do
    local pointOk, _, relativeTo = pcall(frame.GetPoint, frame, pointIndex)
    if pointOk and (relativeTo == _G.Minimap or relativeTo == MinimapCluster or relativeTo == MinimapBackdrop) then
      return true
    end
  end
  return false
end

--- Covers both buttons parented directly to the minimap/cluster/backdrop AND ones parented elsewhere
--- (commonly UIParent, e.g. LibDBIcon-1.0) but anchored directly to one of those frames.
local function discoverAddonButtons()
  local managed = managedFrameSet()
  local found = {}
  local function scan(parent, requireAnchoredToMinimap)
    if not parent or not parent.GetChildren then return end
    -- GetChildren() returns multiple values (not a table), so pack them inside the protected call itself.
    local ok, children = pcall(function() return { parent:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do
      if not managed[child] and isCandidateAddonButton(child) then
        if not requireAnchoredToMinimap or isAnchoredToMinimap(child) then
          table.insert(found, child)
        end
      end
    end
  end
  scan(MinimapCluster)
  scan(MinimapBackdrop)
  scan(_G.Minimap)
  scan(UIParent, true)
  return found
end

--- Lines up other addons' minimap buttons along one outside edge of the square border (never the top,
--- since that's where our title bar lives).
local function layoutAddonButtons(border, position, buttons)
  local previous
  for _, frame in ipairs(buttons) do
    if frame:IsShown() then
      saveIconAnchor(frame)
      hijackPositioning(frame)
      -- NineSlicePanelTemplate's border art is hardcoded to frame level 500 (see createSquareBorder).
      -- Minimap's own native strata may already be "HIGH" (it's an always-on-top HUD element), in which
      -- case matching border's strata alone just ties with it and falls back to frame level -- so bump
      -- both the strata (in case Minimap's native strata is lower than that) AND the level above 500.
      frame.slackHacksRealSetFrameStrata(frame, "HIGH")
      frame.slackHacksRealSetFrameLevel(frame, 511)
      frame.slackHacksRealClearAllPoints(frame)
      if position == "left" then
        if previous then
          frame.slackHacksRealSetPoint(frame, "TOP", previous, "BOTTOM", 0, -ADDON_BUTTON_GAP)
        else
          frame.slackHacksRealSetPoint(frame, "TOPRIGHT", border, "TOPLEFT", ADDON_BUTTON_INSET, -(TITLE_BAR_HEIGHT + 8))
        end
      elseif position == "bottom" then
        if previous then
          frame.slackHacksRealSetPoint(frame, "LEFT", previous, "RIGHT", ADDON_BUTTON_GAP, 0)
        else
          frame.slackHacksRealSetPoint(frame, "TOPLEFT", border, "BOTTOMLEFT", 6, ADDON_BUTTON_INSET)
        end
      else -- "right"
        if previous then
          frame.slackHacksRealSetPoint(frame, "TOP", previous, "BOTTOM", 0, -ADDON_BUTTON_GAP)
        else
          frame.slackHacksRealSetPoint(frame, "TOPLEFT", border, "TOPRIGHT", -ADDON_BUTTON_INSET, -(TITLE_BAR_HEIGHT + 8))
        end
      end
      previous = frame
    end
  end
end

local function applyAddonButtonsLayout()
  local mm = settings()
  if mm.shape ~= "square" then
    for _, frame in ipairs(discoverAddonButtons()) do
      restoreIconAnchor(frame)
    end
    if addonButtonRescanTicker then
      addonButtonRescanTicker:Cancel()
      addonButtonRescanTicker = nil
    end
    lastAddonButtonCount = nil
    return
  end
  local position = mm.addonButtonsPosition
  if position ~= "left" and position ~= "right" and position ~= "bottom" then
    position = "right"
  end
  local buttons = discoverAddonButtons()
  if #buttons ~= lastAddonButtonCount then
    lastAddonButtonCount = #buttons
    print("SlackHacks: found " .. #buttons .. " other addon minimap button(s) to reposition.")
  end
  layoutAddonButtons(createSquareBorder(), position, buttons)
  -- Some addons register their minimap button well after login/zoning; keep re-checking periodically
  -- instead of only on the handful of events ApplyAll is already wired to.
  if not addonButtonRescanTicker then
    addonButtonRescanTicker = C_Timer.NewTicker(2, function()
      local currentMm = settings()
      if currentMm.shape ~= "square" then return end
      local currentPosition = currentMm.addonButtonsPosition
      if currentPosition ~= "left" and currentPosition ~= "right" and currentPosition ~= "bottom" then
        currentPosition = "right"
      end
      local rescanned = discoverAddonButtons()
      if #rescanned ~= lastAddonButtonCount then
        lastAddonButtonCount = #rescanned
        print("SlackHacks: found " .. #rescanned .. " other addon minimap button(s) to reposition.")
      end
      layoutAddonButtons(createSquareBorder(), currentPosition, rescanned)
    end)
  end
end

local function applyMouseWheelZoom()
  _G.Minimap:EnableMouseWheel(settings().mouseWheelZoom ~= false)
end

function module:ApplyAll()
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
  applyAddonButtonsLayout()
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
  curY = addHeader("Coordinates", curY)
  local coordDependents = {}
  local coordCb
  coordCb, curY = addCheckbox("Show Player Coordinates",
    function() return db.profile.minimap.showCoordinates end,
    function(v) db.profile.minimap.showCoordinates = v end,
    curY, coordDependents)
  local coordAnchorDropdown
  coordAnchorDropdown, curY = addDropdown("Position",
    { BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" },
    { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
    function() return db.profile.minimap.coordinatesAnchor end,
    function(v) db.profile.minimap.coordinatesAnchor = v end,
    curY)
  table.insert(coordDependents, coordAnchorDropdown)
  local coordScaleSlider
  coordScaleSlider, curY = addSlider("Text Size", 50, 200, 5,
    function() return db.profile.minimap.coordinatesScale end,
    function(v) db.profile.minimap.coordinatesScale = v end,
    curY, percentFormat)
  table.insert(coordDependents, coordScaleSlider)

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
  _, curY = addCheckbox("Hide Extra Minimap Buttons",
    function() return db.profile.minimap.hideExtraButtons end,
    function(v) db.profile.minimap.hideExtraButtons = v end,
    curY)
  _, curY = addDropdown("Other Addon Icons Position",
    { left = "Left", right = "Right", bottom = "Bottom" },
    { "left", "right", "bottom" },
    function() return db.profile.minimap.addonButtonsPosition end,
    function(v) db.profile.minimap.addonButtonsPosition = v end,
    curY)
  _, curY = addCheckbox("Mouse Wheel Zoom",
    function() return db.profile.minimap.mouseWheelZoom end,
    function(v) db.profile.minimap.mouseWheelZoom = v end,
    curY)

  dialog:SetHeight(math.abs(curY) + 24)

  function dialog:RefreshValues()
    for _, fn in ipairs(controls) do fn() end
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

  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Exit", function() showOptionsDialog(false) end, module)
  end
end

--=====================================================================
-- Lifecycle
--=====================================================================

function module:OnInitialize()
  registerEditModeHooks()
  db:RegisterCallback("OnDatabaseReset", module.ApplyAll, module)
end

function module:OnEnable()
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
  isInCombat = true
  applyAlpha()
end

function module:PLAYER_REGEN_ENABLED()
  isInCombat = false
  self:ApplyAll() -- catch up any show/hide changes that were skipped while in combat
end

function module:PLAYER_STARTED_MOVING()
  isMoving = true
  applyAlpha()
end

function module:PLAYER_STOPPED_MOVING()
  isMoving = false
  applyAlpha()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  if coordTicker then
    coordTicker:Cancel()
    coordTicker = nil
  end
  if addonButtonRescanTicker then
    addonButtonRescanTicker:Cancel()
    addonButtonRescanTicker = nil
  end
  if coordText then coordText:Hide() end
  if squareBorderFrame then squareBorderFrame:Hide() end
  if titleBarFrame then titleBarFrame:Hide() end
  for _, frame in ipairs(iconBarFrames()) do
    restoreIconAnchor(frame)
  end
  for _, frame in ipairs(discoverAddonButtons()) do
    restoreIconAnchor(frame)
  end
  if _G.Minimap.SetMaskTexture then _G.Minimap:SetMaskTexture(ROUND_MASK_TEXTURE) end
  _G.Minimap:SetAlpha(1)
  if not InCombatLockdown() then
    if MinimapCluster and MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:Show() end
    if TimeManagerClockButton then TimeManagerClockButton:Show() end
    if GameTimeFrame then GameTimeFrame:Show() end
    if MinimapCluster and MinimapCluster.DielFrame then MinimapCluster.DielFrame:Show() end
    if MinimapCluster and MinimapCluster.Tracking then MinimapCluster.Tracking:Show() end
    for _, button in ipairs(extraButtons()) do
      if button then button:Show() end
    end
  end
  if MinimapBackdrop then MinimapBackdrop:SetAlpha(1) end
  ensureCVar("minimapTrackingShowAll", GetCVarDefault("minimapTrackingShowAll"))
end
