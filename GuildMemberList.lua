setfenv(1, _G.SlackHacks)

-- Guild Member List: a movable, resizable, collapsible list of online guild members.
-- The roster logic is the same as the GuildMembersOnline addon (GetGuildRosterInfo -> class-colored name and
-- zone, with a name/level tooltip), shown as two columns and sorted by name or zone. The window recreates Blizzard's
-- DamageMeterSessionWindowTemplate (Blizzard_DamageMeter/DamageMeterSessionWindow.xml) in Lua, including
-- its MinimizeButton, which collapses the window down to its header bar, and its SettingsDropdown cog menu.
local module = Self:NewModule("GuildMemberList", "AceEvent-3.0")
Self.GuildMemberList = module

local HEADER_HEIGHT = 32 -- Explicit header height from the Blizzard template so the scroll box can anchor to it.
local ROW_HEIGHT = 18
local NAME_COLUMN_WIDTH = 90 -- Fits a 12-character name; the zone column takes the rest of the row.
local COLUMN_GAP = 6
local ROW_PADDING = 5 -- Space between a row's edges and its text.
-- Scroll list insets inside the window (from DamageMeterSessionWindowMixin:InitializeScrollBox).
local LIST_TOP_GAP = 2
local LIST_LEFT_INSET = 5
local LIST_RIGHT_INSET = 1
local LIST_BOTTOM_INSET = 6
local SCROLL_BAR_SPACE = 15 -- Extra right inset while the scroll bar is showing.
local HEADER_BUTTONS_WIDTH = 62 -- Header space beside the title: title inset, cog, minimize button and gaps.
local MAX_HEIGHT = 400
local INSTANCE_ICON_SIZE = 12
-- Inline icons from the world map's pins (delves-regular is the Map Legend's delve icon).
local INSTANCE_ICONS = {
  dungeon = CreateAtlasMarkup("Dungeon", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
  raid = CreateAtlasMarkup("Raid", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
  delve = CreateAtlasMarkup("delves-regular", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
}
local OPACITY_STEP = 0.05
local SCROLL_BAR_IDLE_ALPHA = 0.3 -- The scroll bar is dimmed until the window is hovered, like the DamageMeter.
local FADE_DURATION = 0.25
local ROSTER_REQUEST_DELAY = 2 -- GuildMembersOnline waits for roster data to settle after a loading screen.
local SETTINGS_MENU_TAG = "MENU_SLACKHACKS_GUILD_MEMBER_LIST_SETTINGS"
-- Cog atlases per button state, from DamageMeterSettingsDropdownButtonTemplate's KeyValues.
local SETTINGS_ICON_ATLAS = {
  disabled = "common-dropdown-a-button-settings-disabled-shadowless",
  normal = "common-dropdown-a-button-settings-shadowless",
  pressed = "common-dropdown-a-button-settings-pressed-shadowless",
  hover = "common-dropdown-a-button-settings-hover-shadowless",
  hoverPressed = "common-dropdown-a-button-settings-pressedhover-shadowless",
  open = "common-dropdown-a-button-settings-open-shadowless",
}

-- Sort choices in menu order; `key` is the saved `sortBy` value.
local SORT_OPTIONS = {
  { key = "name", text = "Name" },
  { key = "zone", text = "Location" },
}
-- Comparators for table.sort, keyed by `sortBy`. Ties are broken by name so the order is stable across refreshes.
local SORT_COMPARATORS = {
  name = function(a, b) return a.sortName < b.sortName end,
  zone = function(a, b)
    if a.zone ~= b.zone then return a.zone < b.zone end
    return a.sortName < b.sortName
  end,
}

local window
local opacityPanel
local populate
local instanceIcons -- Zone name -> inline icon markup; built once by getInstanceIcons().

--- Returns a lookup from instance name to its inline Dungeon/Raid/Delve icon, built once from local game data
--- (the Encounter Journal), so it costs no server requests.
--- The guild roster only reports a member's zone as text, with no instance flag, but inside a dungeon or raid
--- that text is the instance's name, which is also how the journal names it.
---@return table icons Instance name -> CreateAtlasMarkup() string (empty until journal data is available).
local function getInstanceIcons()
  if instanceIcons then return instanceIcons end
  local icons = {}
  local numTiers = EJ_GetNumTiers and EJ_GetNumTiers() or 0
  if numTiers == 0 then return icons end -- Journal data isn't loaded yet; try again on the next populate.
  -- The roster reports every delve's zone as just "Delves" rather than the delve's name, and delves aren't in
  -- the journal. Hard-coded English, so this won't match on other client languages.
  icons["Delves"] = INSTANCE_ICONS.delve
  -- EJ_SelectTier changes the journal's shared selection, so put it back for the Encounter Journal UI.
  local selectedTier = EJ_GetCurrentTier()
  for tier = 1, numTiers do
    EJ_SelectTier(tier)
    for _, isRaid in ipairs({ false, true }) do
      local icon = isRaid and INSTANCE_ICONS.raid or INSTANCE_ICONS.dungeon
      local index = 1
      local instanceID, name = EJ_GetInstanceByIndex(index, isRaid)
      while instanceID do
        icons[name] = icon
        index = index + 1
        instanceID, name = EJ_GetInstanceByIndex(index, isRaid)
      end
    end
  end
  EJ_SelectTier(selectedTier)
  instanceIcons = icons
  return icons
end

--- Returns this module's saved settings table.
---@return table settings The `infoDisplay.guildMemberList` profile table.
local function getSettings()
  return db.profile.infoDisplay.guildMemberList
end

--- Saves and applies the background opacity. Like the DamageMeter's "Background Transparency" Edit Mode
--- setting, this only fades the background texture, so the header and the member names stay fully readable.
---@param opacity number Background alpha from 0 to 1; rounded to OPACITY_STEP to drop slider float noise.
local function setOpacity(opacity)
  opacity = math.floor(opacity / OPACITY_STEP + 0.5) * OPACITY_STEP
  getSettings().opacity = opacity
  if window then window.Background:SetAlpha(opacity) end
end

--- Opens the opacity slider panel (the same OpacityFrame clone the Zone Map's "Change Scale" uses), anchored
--- to the right of the window: its TOPLEFT at the window's TOPRIGHT.
local function showOpacityPanel()
  opacityPanel = opacityPanel
    or createSliderPanel("SlackHacksGuildMemberListOpacityFrame", OPACITY or "Opacity", 0, 1, OPACITY_STEP, setOpacity)
  opacityPanel:Open(getSettings().opacity, "TOPLEFT", window, "TOPRIGHT", 0, 7)
end

--- Saves the list's sort order and re-sorts the window if it's showing.
---@param sortBy string A SORT_COMPARATORS key: "name" or "zone".
local function setSortBy(sortBy)
  getSettings().sortBy = sortBy
  if window and window:IsVisible() then populate() end
end

--- Saves the window's current anchor and size so it is restored on the next login. The size is skipped while
--- fitting to content, so the manual size comes back when fitting is turned off.
local function saveLayout()
  local settings = getSettings()
  local point, _, relativePoint, x, y = window:GetPoint()
  settings.point, settings.relativePoint, settings.x, settings.y = point, relativePoint, x, y
  if not settings.fitToContent then settings.width, settings.height = window:GetSize() end
end

--- Restores the window's saved anchor and size.
local function applyLayout()
  local settings = getSettings()
  window:ClearAllPoints()
  window:SetPoint(settings.point, UIParent, settings.relativePoint, settings.x, settings.y)
  window:SetSize(settings.width, settings.height)
end

--- Shrinks the mouse hit area to the header while minimized. Like Blizzard, the frame keeps its full size while
--- minimized (so expanding restores it), so this stops the invisible body swallowing clicks meant for the
--- world/UI. Must be re-run whenever the height changes.
local function updateHitRect()
  window:SetHitRectInsets(0, 0, 0, getSettings().minimized and (window:GetHeight() - HEADER_HEIGHT) or 0)
end

--- Collapses or expands the window; mirrors DamageMeterSessionWindowMixin:SetMinimized.
---@param minimized boolean Whether only the header bar should be shown.
local function setMinimized(minimized)
  getSettings().minimized = minimized

  local normalTexture = window.MinimizeButton:GetNormalTexture()
  local pushedTexture = window.MinimizeButton:GetPushedTexture()
  if minimized then
    normalTexture:SetAtlas("ui-questtrackerbutton-expand-all", TextureKitConstants.UseAtlasSize)
    pushedTexture:SetAtlas("ui-questtrackerbutton-expand-all-pressed", TextureKitConstants.UseAtlasSize)
  else
    normalTexture:SetAtlas("ui-questtrackerbutton-collapse-all", TextureKitConstants.UseAtlasSize)
    pushedTexture:SetAtlas("ui-questtrackerbutton-collapse-all-pressed", TextureKitConstants.UseAtlasSize)
  end

  window.MinimizeContainer:SetShown(not minimized)
  updateHitRect()
end

--- OnUpdate handler that runs only while the window is hovered. Once the cursor leaves (and no resize is in
--- progress) it fades the resize handle/scroll bar back out and removes itself.
---@param self Frame The guild member list window.
local function onHoverUpdate(self)
  if self:IsMouseOver() or self.isResizing then return end
  self.hovered = false
  self:SetScript("OnUpdate", nil)
  local reverse = true
  self.MinimizeContainer.ShowResizeButton:Play(reverse)
  self.MinimizeContainer.EmphasizeScrollBar:Play(reverse)
end

--- Fades in the resize handle and scroll bar when the cursor enters the window or any of its children.
--- Like DamageMeterSessionWindowMixin:OnEnter, OnLeave is deliberately not used: it fires whenever the
--- cursor moves onto a child frame, so leaving is detected by polling IsMouseOver() in onHoverUpdate.
local function onWindowEnter()
  if window.hovered then return end
  window.hovered = true
  window:SetScript("OnUpdate", onHoverUpdate)
  window.MinimizeContainer.ShowResizeButton:Play()
  window.MinimizeContainer.EmphasizeScrollBar:Play()
end

--- Creates an alpha animation (the Lua equivalent of the template's `<Alpha>` AnimationGroups).
---@param region Region The region to fade.
---@param fromAlpha number Starting alpha; playing in reverse fades back to this value.
---@return AnimationGroup group The animation group to Play() or Play(true) in reverse.
local function createFade(region, fromAlpha)
  region:SetAlpha(fromAlpha)
  local group = region:CreateAnimationGroup()
  group:SetToFinalAlpha(true)
  local alpha = group:CreateAnimation("Alpha")
  alpha:SetFromAlpha(fromAlpha)
  alpha:SetToAlpha(1)
  alpha:SetDuration(FADE_DURATION)
  return group
end

--- Shows the member's full name (with realm) and level, same as the GuildMembersOnline tooltip.
---@param row Frame The hovered list row.
local function showMemberTooltip(row)
  onWindowEnter()
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(row.member.fullName)
  GameTooltip:AddLine(LEVEL .. ": " .. row.member.level, 1, 1, 1)
  GameTooltip:Show()
end

--- Creates a single-line, left-justified text cell for a row; long text is truncated instead of wrapping.
---@param row Frame The row the cell belongs to.
---@return FontString cell The new text cell.
local function createCell(row)
  local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cell:SetJustifyH("LEFT")
  cell:SetWordWrap(false)
  return cell
end

--- ScrollBox element initializer; builds a row's two columns (name, zone) once and then binds it to a member.
---@param row Frame A pooled row frame from the ScrollBox.
---@param member table Member entry built by populate().
local function initRow(row, member)
  if not row.Name then
    -- A fixed-width name column keeps every zone lined up in a second column that grows with the window.
    row.Name = createCell(row)
    row.Name:SetPoint("LEFT", ROW_PADDING, 0)
    row.Name:SetWidth(NAME_COLUMN_WIDTH)
    row.Zone = createCell(row)
    row.Zone:SetPoint("LEFT", row.Name, "RIGHT", COLUMN_GAP, 0)
    row.Zone:SetPoint("RIGHT", -ROW_PADDING, 0)
    row:SetScript("OnEnter", showMemberTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    -- Rows only need hover for tooltips; letting clicks through means dragging a row moves the window.
    row:SetMouseMotionEnabled(true)
    row:SetMouseClickEnabled(false)
  end
  row.member = member
  row.Name:SetText(member.name)
  row.Zone:SetText(member.zoneText)
end

--- When the `fitToContent` setting is on, sizes the window to fit the title, the widest location and every row.
--- The height stops at MAX_HEIGHT, after which the list scrolls as usual.
---@param members table Member entries from populate(), used to measure the widest location.
local function fitToContent(members)
  if not getSettings().fitToContent then return end
  local zoneWidth = 0
  for _, member in ipairs(members) do
    window.Measure:SetText(member.zoneText)
    zoneWidth = math.max(zoneWidth, window.Measure:GetUnboundedStringWidth())
  end
  -- Show at least one empty row so a guildless/empty window doesn't collapse to just its header.
  local height = HEADER_HEIGHT + LIST_TOP_GAP + math.max(#members, 1) * ROW_HEIGHT + LIST_BOTTOM_INSET
  local scrollBarSpace = height > MAX_HEIGHT and SCROLL_BAR_SPACE or 0
  local listWidth = LIST_LEFT_INSET + ROW_PADDING + NAME_COLUMN_WIDTH + COLUMN_GAP + zoneWidth + ROW_PADDING
    + LIST_RIGHT_INSET + scrollBarSpace
  local titleWidth = window.Title:GetUnboundedStringWidth() + HEADER_BUTTONS_WIDTH

  -- Re-anchor by the top-left corner first so the window grows and shrinks downward/rightward instead of
  -- around its saved anchor (e.g. CENTER), which would make the header jump as members come and go.
  local left, top = window:GetLeft(), window:GetTop()
  if left and top then
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    saveLayout()
  end
  window:SetSize(math.ceil(math.max(listWidth, titleWidth)), math.min(height, MAX_HEIGHT))
  updateHitRect()
end

--- Saves the fit-to-content setting and applies it: fits the window now, or restores the manual size.
--- The resize handle is hidden while fitting since the window sizes itself.
---@param enabled boolean Whether the window should size itself to its content.
local function setFitToContent(enabled)
  local settings = getSettings()
  settings.fitToContent = enabled
  if not window then return end
  window.ResizeButton:SetShown(not enabled)
  if enabled then
    if window:IsVisible() then populate() end
  else
    window:SetSize(settings.width, settings.height)
    updateHitRect()
  end
end

--- Rebuilds the list of online members from the client's guild roster cache (GuildMembersOnline logic),
--- sorted by the saved `sortBy` setting. Assigned to the forward-declared local so setSortBy can call it.
function populate()
  if not IsInGuild() then
    window.Title:SetText("No Guild")
    window.ScrollBox:SetDataProvider(CreateDataProvider())
    fitToContent({})
    return
  end

  local members = {}
  local icons = getInstanceIcons()
  for i = 1, GetNumGuildMembers() do
    local name, _, _, level, _, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
    if online and name then
      local shortName = name:match("[^%-]+") -- Strip the realm.
      local classColor = C_ClassColor.GetClassColor(classFile)
      zone = zone or UNKNOWN
      local icon = icons[zone]
      members[#members + 1] = {
        name = classColor and classColor:WrapTextInColorCode(shortName) or shortName,
        sortName = shortName:lower(),
        zone = zone, -- Plain text for sorting; zoneText is what's displayed.
        zoneText = icon and (zone .. " " .. icon) or zone,
        fullName = name,
        level = level,
      }
    end
  end
  table.sort(members, SORT_COMPARATORS[getSettings().sortBy] or SORT_COMPARATORS.name)

  window.Title:SetText("Guild Members Online: " .. #members)
  window.ScrollBox:SetDataProvider(CreateDataProvider(members), ScrollBoxConstants.RetainScrollPosition)
  fitToContent(members)
end

--- Asks the server for fresh roster data; GUILD_ROSTER_UPDATE fires when it arrives.
--- The client throttles this request, so calling it on every show is cheap.
local function requestRoster()
  if IsInGuild() then C_GuildInfo.GuildRoster() end
end

--- Builds the header's cog button, a Lua copy of Blizzard's DamageMeterSettingsDropdownButtonTemplate
--- (Blizzard_DamageMeter/DamageMeterSettingsDropdownButton.xml/.lua), and fills its settings menu.
---@return DropdownButton button The cog button.
local function createSettingsDropdown()
  -- "DropdownButton" is the intrinsic behind Blizzard's <DropdownButton> XML tag (Blizzard_Menu): it brings
  -- DropdownButtonMixin (SetupMenu, opening/closing the menu on click) plus intrinsic script handlers that
  -- keep running alongside the scripts set below. ButtonStateBehaviorMixin tracks hover/pressed state.
  local button = CreateFrame("DropdownButton", nil, window)
  Mixin(button, ButtonStateBehaviorMixin)
  button:SetSize(27, 27)
  button.Icon = button:CreateTexture(nil, "ARTWORK")
  button.Icon:SetAllPoints()

  --- Shows the cog atlas for the button's current state; copy of DamageMeterSettingsDropdownButton:GetIconAtlas().
  function button:OnButtonStateChanged()
    local atlas
    if not self:IsEnabled() then
      atlas = SETTINGS_ICON_ATLAS.disabled
    elseif self:IsDownOver() then
      atlas = SETTINGS_ICON_ATLAS.hoverPressed
    elseif self:IsOver() then
      atlas = SETTINGS_ICON_ATLAS.hover
    elseif self:IsDown() then
      atlas = SETTINGS_ICON_ATLAS.pressed
    elseif self:IsMenuOpen() then
      atlas = SETTINGS_ICON_ATLAS.open
    else
      atlas = SETTINGS_ICON_ATLAS.normal
    end
    self.Icon:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
  end

  --- Extends DropdownButtonMixin:OnMenuOpened to switch to the "open" cog.
  ---@param menu Frame The opened menu.
  function button:OnMenuOpened(menu)
    DropdownButtonMixin.OnMenuOpened(self, menu)
    self:OnButtonStateChanged()
  end

  --- Extends DropdownButtonMixin:OnMenuClosed to switch back from the "open" cog.
  ---@param menu Frame The closed menu.
  ---@param closeReason number Why the menu closed.
  function button:OnMenuClosed(menu, closeReason)
    DropdownButtonMixin.OnMenuClosed(self, menu, closeReason)
    self:OnButtonStateChanged()
  end

  -- The template's <Scripts> block: all of these are ButtonStateBehaviorMixin methods.
  for _, script in ipairs({ "OnMouseDown", "OnMouseUp", "OnEnter", "OnLeave", "OnEnable", "OnDisable" }) do
    button:SetScript(script, button[script])
  end
  button:OnButtonStateChanged() -- ButtonStateBehaviorMixin:OnLoad()

  button:SetupMenu(function(_, rootDescription)
    rootDescription:SetTag(SETTINGS_MENU_TAG)
    rootDescription:CreateCheckbox("Fit to Content",
      function() return getSettings().fitToContent end,
      function() setFitToContent(not getSettings().fitToContent) end)
    rootDescription:CreateButton(BATTLEFIELDMINIMAP_OPACITY_LABEL or "Change Opacity", showOpacityPanel)
    rootDescription:CreateDivider()
    rootDescription:CreateTitle("Sort By")
    for _, option in ipairs(SORT_OPTIONS) do
      rootDescription:CreateRadio(option.text,
        function(key) return (getSettings().sortBy or "name") == key end,
        setSortBy,
        option.key)
    end
  end)
  return button
end

--- Builds the window, following DamageMeterSessionWindowTemplate: a Header bar holding the title,
--- SettingsDropdown and MinimizeButton, plus a MinimizeContainer (background, scroll list, resize handle) that
--- is hidden when minimized.
local function createWindow()
  window = CreateFrame("Frame", "SlackHacksGuildMemberList", UIParent)
  window:Hide() -- New frames start shown; hiding lets OnEnable's Show() fire OnShow for the first populate.
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:SetResizable(true)
  window:SetResizeBounds(200, 120, 600, MAX_HEIGHT)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveLayout()
  end)
  window:SetScript("OnEnter", onWindowEnter)
  window:SetScript("OnShow", function()
    populate()
    requestRoster()
  end)

  local header = window:CreateTexture(nil, "BACKGROUND")
  header:SetAtlas("ui-damagemeters-header-bar")
  header:SetHeight(HEADER_HEIGHT)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  window.Header = header

  local minimizeButton = CreateFrame("Button", nil, window)
  minimizeButton:SetSize(18, 19)
  minimizeButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -3, -5)
  minimizeButton:SetNormalAtlas("ui-questtrackerbutton-collapse-all")
  minimizeButton:SetPushedAtlas("ui-questtrackerbutton-collapse-all-pressed")
  minimizeButton:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
  minimizeButton:SetScript("OnClick", function() setMinimized(not getSettings().minimized) end)
  window.MinimizeButton = minimizeButton

  local settingsDropdown = createSettingsDropdown()
  settingsDropdown:SetPoint("RIGHT", minimizeButton, "LEFT", -2, -2)
  window.SettingsDropdown = settingsDropdown

  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  title:SetPoint("TOPLEFT", header, "TOPLEFT", 8, -9)
  title:SetPoint("RIGHT", settingsDropdown, "LEFT", -4, 0)
  window.Title = title

  -- Never shown; fitToContent uses it to measure location text in the same font as the zone column.
  local measure = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  measure:Hide()
  window.Measure = measure

  -- Shares the window's frame level (useParentLevel in the template) so it sits underneath the header widgets.
  local container = CreateFrame("Frame", nil, window)
  container:SetAllPoints()
  container:SetUsingParentLevel(true)
  window.MinimizeContainer = container

  local background = container:CreateTexture(nil, "BACKGROUND")
  background:SetAtlas("damagemeters-background")
  background:SetAllPoints()
  window.Background = background

  local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
  local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 0, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 0, 8)
  window.ScrollBox = scrollBox

  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(ROW_HEIGHT)
  view:SetElementInitializer("Frame", initRow)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

  -- Same anchors as DamageMeterSessionWindowMixin:InitializeScrollBox: the list widens to fill the space
  -- when the scroll bar hides itself because everything fits.
  local topLeft = CreateAnchor("TOPLEFT", header, "BOTTOMLEFT", LIST_LEFT_INSET, -LIST_TOP_GAP)
  ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
    { topLeft, CreateAnchor("BOTTOMRIGHT", -LIST_RIGHT_INSET - SCROLL_BAR_SPACE, LIST_BOTTOM_INSET) },
    { topLeft, CreateAnchor("BOTTOMRIGHT", -LIST_RIGHT_INSET, LIST_BOTTOM_INSET) })

  local resizeButton = CreateFrame("Button", nil, container)
  resizeButton:SetSize(60, 60)
  resizeButton:SetPoint("BOTTOMRIGHT", 9, -8)
  resizeButton:SetNormalAtlas("damagemeters-scalehandle")
  resizeButton:SetHighlightAtlas("damagemeters-scalehandle-hover")
  resizeButton:SetPushedAtlas("damagemeters-scalehandle-pressed")
  resizeButton:SetScript("OnEnter", onWindowEnter)
  resizeButton:SetScript("OnMouseDown", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then return end
    -- Hold the pushed look for the whole drag, even when the cursor leaves the handle.
    self:SetButtonState("PUSHED", true)
    self:GetHighlightTexture():Hide()
    window.isResizing = true
    window:StartSizing("BOTTOMRIGHT")
  end)
  resizeButton:SetScript("OnMouseUp", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then return end
    self:SetButtonState("NORMAL", false)
    self:GetHighlightTexture():Show()
    window.isResizing = false
    window:StopMovingOrSizing()
    saveLayout()
  end)
  window.ResizeButton = resizeButton

  container.ShowResizeButton = createFade(resizeButton, 0)
  container.EmphasizeScrollBar = createFade(scrollBar, SCROLL_BAR_IDLE_ALPHA)
end

--- Turns the Guild Member List on or off and saves the choice.
---@param enabled boolean Whether the window should be shown.
function module:SetEnabled(enabled)
  getSettings().enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

--- Saves and applies whether the window sizes itself to its content (used by the options panel).
---@param enabled boolean Whether to fit the window to its content.
function module:SetFitToContent(enabled)
  setFitToContent(enabled)
end

--- Saves and applies the window's background opacity (used by the options panel).
---@param opacity number Background alpha from 0 to 1.
function module:SetOpacity(opacity)
  setOpacity(opacity)
end

--- Saves and applies the list's sort order (used by the options panel).
---@param sortBy string "name" or "zone".
function module:SetSortBy(sortBy)
  setSortBy(sortBy)
end

--- AceAddon initialization hook; keeps the module disabled when turned off or outside Retail, since the
--- DamageMeter atlases and ScrollBox templates the window relies on only exist there.
function module:OnInitialize()
  if not getSettings().enabled or not isRetail() then self:Disable() end
end

--- Shows the window (creating it on first use) and listens for roster changes.
function module:OnEnable()
  -- Addon-wide re-enables (e.g. profile reset) enable every module, so re-check the saved setting.
  if not getSettings().enabled or not isRetail() then
    self:SetEnabledState(false)
    return
  end
  if not window then createWindow() end
  applyLayout()
  setMinimized(getSettings().minimized)
  setOpacity(getSettings().opacity)
  setFitToContent(getSettings().fitToContent) -- Window is still hidden, so the fit itself happens in OnShow.
  self:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(ROSTER_REQUEST_DELAY, requestRoster) end)
  self:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    if window:IsVisible() then populate() end
  end)
  window:Show()
end

--- Stops listening for roster changes and hides the window and its opacity panel.
function module:OnDisable()
  self:UnregisterAllEvents()
  if window then window:Hide() end
  if opacityPanel then opacityPanel:Hide() end
end
