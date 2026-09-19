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
  setShownSafely(MinimapCluster and MinimapCluster.ZoneTextButton, settings().showZoneText)
end

local function applyClock()
  setShownSafely(TimeManagerClockButton, settings().showClock)
end

local function applyCalendar()
  setShownSafely(GameTimeFrame, settings().showCalendar)
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
  applyTracking()
  applyTrackingCVar()
  applyExtraButtons()
  applyBorder()
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
  if coordText then coordText:Hide() end
  if squareBorderFrame then squareBorderFrame:Hide() end
  if _G.Minimap.SetMaskTexture then _G.Minimap:SetMaskTexture(ROUND_MASK_TEXTURE) end
  _G.Minimap:SetAlpha(1)
  if not InCombatLockdown() then
    if MinimapCluster and MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:Show() end
    if TimeManagerClockButton then TimeManagerClockButton:Show() end
    if GameTimeFrame then GameTimeFrame:Show() end
    if MinimapCluster and MinimapCluster.Tracking then MinimapCluster.Tracking:Show() end
    for _, button in ipairs(extraButtons()) do
      if button then button:Show() end
    end
  end
  if MinimapBackdrop then MinimapBackdrop:SetAlpha(1) end
  ensureCVar("minimapTrackingShowAll", GetCVarDefault("minimapTrackingShowAll"))
end
