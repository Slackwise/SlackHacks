setfenv(1, _G.SlackHacks)

-- Info Display: switches the Char Sheet overlays on and off, and hosts the "Players Online" window, which stacks the
-- Friends and Guildie lists into one window the way Blizzard's Objective Tracker ("All Objectives",
-- Blizzard_ObjectiveTracker) stacks its modules: each list gets a module header (ObjectiveTrackerModuleHeaderTemplate)
-- whose secondary minimize button collapses just that list. The window's header bar copies the tracker's own
-- "All Objectives" header (ObjectiveTrackerContainerHeaderTemplate), and the rest of the window is the same
-- DamageMeterSessionWindowTemplate recreation the lists use on their own (background, cog, resize handle). The
-- list modules still build their entries, tooltips and menus; this window only lays them out. Unlike
-- the Char Sheet, the window doesn't depend on this module's enabled state, since the lists are independent of it.
local module = Self:NewModule("InfoDisplay")
Self.InfoDisplay = module

local HEADER_HEIGHT = 32 -- Window header bar, from ObjectiveTrackerContainerHeaderTemplate.
local SECTION_HEADER_HEIGHT = 26 -- ObjectiveTrackerModuleHeaderTemplate's height.
local SECTION_SPACING = 10 -- The Objective Tracker container's spacing between modules.
local HEADER_TEXT_INSET = 7 -- Both Objective Tracker header templates' Text offset.
local SECTION_BUTTON_SIZE = 16 -- The module header's MinimizeButton size.
local ROW_HEIGHT = 18
-- Column layout, matching the standalone lists so names and zones look the same.
local NAME_COLUMN_MIN_SHARE = 0.6
local COLUMN_GAP = 6
local ROW_PADDING = 5
local LIST_TOP_GAP = 2
local LIST_LEFT_INSET = 5
local LIST_RIGHT_INSET = 1
local LIST_BOTTOM_INSET = 6
local SCROLL_BAR_SPACE = 15
local HEADER_BUTTONS_WIDTH = 62 -- Header space beside the title: title inset, cog, minimize button and gaps.
local MIN_WIDTH = 200
local MIN_HEIGHT = 120
local MAX_FIT_HEIGHT = 600 -- Taller than a single list's limit since it holds both; beyond this the list scrolls.
local BACKGROUND_ALPHA = 0.5 -- Edit Mode's default DamageMeter "Background Transparency".
local SCROLL_BAR_IDLE_ALPHA = 0.3
local FADE_DURATION = 0.25
local SETTINGS_MENU_TAG = "MENU_SLACKHACKS_PLAYERS_ONLINE_SETTINGS"
-- The stacked lists, keyed by section; `module` is the list's AceModule name on Self.
local SECTIONS = {
  friends = { module = "FriendsList", title = "Friends" },
  guildies = { module = "GuildieList", title = "Guildies" },
}
-- Section order for each `stackOrder` setting value.
local STACK_ORDERS = {
  friends = { "friends", "guildies" },
  guildies = { "guildies", "friends" },
}

local window
-- Untruncated widths of the widest name and zone across both lists, so the columns line up between sections.
local nameColumnWidth, zoneColumnWidth = 0, 0

--- Returns the font both Objective Tracker header templates use. It's defined by Blizzard_ObjectiveTracker, which
--- may load after this addon, so it's looked up when a header is built, with a similar stock font as a fallback.
---@return string font A font object name.
local function getHeaderFont()
  return _G.ObjectiveTrackerHeaderFont and "ObjectiveTrackerHeaderFont" or "GameFontNormalMed2"
end

--- Refreshes the Char Sheet overlays.
function module:Refresh()
  if Self.CharSheet then Self.CharSheet:Refresh() end
end

--- Turns the Info Display (Char Sheet overlays) on or off and saves the choice.
---@param enabled boolean Whether the overlays should be shown.
function module:SetEnabled(enabled)
  db.profile.infoDisplay.enabled = enabled
  if Self.CharSheet then Self.CharSheet:SetGearStatsEnabled(enabled) end
  if enabled then self:Enable() else self:Disable() end
  self:Refresh()
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- AceAddon initialization hook; keeps the module disabled when the Info Display is turned off.
function module:OnInitialize()
  if not db.profile.infoDisplay.enabled then self:Disable() end
end

--- Enables the Char Sheet module along with the Info Display.
function module:OnEnable()
  if Self.CharSheet and not Self.CharSheet:IsEnabled() then Self.CharSheet:Enable() end
end

--- Disables the Char Sheet module along with the Info Display.
function module:OnDisable()
  if Self.CharSheet and Self.CharSheet:IsEnabled() then Self.CharSheet:Disable() end
end

--- Returns the Players Online window's saved settings table.
---@return table settings The `infoDisplay.playersOnline` profile table.
local function getSettings()
  return db.profile.infoDisplay.playersOnline
end

--- Saves the window's current anchor and size; the size is skipped while fitting to content, so the manual size
--- comes back when fitting is turned off.
local function saveLayout()
  local settings = getSettings()
  local point, _, relativePoint, x, y = window:GetPoint()
  settings.point, settings.relativePoint, settings.x, settings.y = point, relativePoint, x, y
  if not settings.fitToContent then settings.width, settings.height = window:GetSize() end
end

--- Shrinks the mouse hit area to the header while minimized, so the hidden body doesn't swallow clicks. Must be
--- re-run whenever the height changes.
local function updateHitRect()
  window:SetHitRectInsets(0, 0, 0, getSettings().minimized and (window:GetHeight() - HEADER_HEIGHT) or 0)
end

--- Collapses or expands the whole window to its header bar; mirrors DamageMeterSessionWindowMixin:SetMinimized.
---@param minimized boolean Whether only the header bar should be shown.
local function setMinimized(minimized)
  getSettings().minimized = minimized
  local suffix = minimized and "expand-all" or "collapse-all"
  window.MinimizeButton:GetNormalTexture():SetAtlas("ui-questtrackerbutton-" .. suffix,
    TextureKitConstants.UseAtlasSize)
  window.MinimizeButton:GetPushedTexture():SetAtlas("ui-questtrackerbutton-" .. suffix .. "-pressed",
    TextureKitConstants.UseAtlasSize)
  window.MinimizeContainer:SetShown(not minimized)
  updateHitRect()
end

--- OnUpdate handler that runs only while the window is hovered; once the cursor leaves (and no resize is in
--- progress) it fades the resize handle and scroll bar back out and removes itself.
---@param self Frame The Players Online window.
local function onHoverUpdate(self)
  if self:IsMouseOver() or self.isResizing then return end
  self.hovered = false
  self:SetScript("OnUpdate", nil)
  self.MinimizeContainer.ShowResizeButton:Play(true)
  self.MinimizeContainer.EmphasizeScrollBar:Play(true)
end

--- Fades in the resize handle and scroll bar when the cursor enters the window or any of its children. Like
--- DamageMeterSessionWindowMixin, leaving is detected by polling (onHoverUpdate), since OnLeave fires whenever the
--- cursor moves onto a child frame.
local function onWindowEnter()
  if window.hovered then return end
  window.hovered = true
  window:SetScript("OnUpdate", onHoverUpdate)
  window.MinimizeContainer.ShowResizeButton:Play()
  window.MinimizeContainer.EmphasizeScrollBar:Play()
end

--- Creates an alpha fade from `fromAlpha` to fully visible; playing it in reverse fades back.
---@param region Region The region to fade.
---@param fromAlpha number Starting alpha.
---@return AnimationGroup group The animation group.
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

--- Returns a list entry's character GUID, used to count a person who is both a friend and a guildie only once.
--- Guildies carry `guid`, character friends `friendInfo.guid`, and Battle.net friends the GUID of the WoW
--- character they're playing (nil in other games).
---@param entry table A Friends or Guildie list entry.
---@return string|nil guid The GUID, or nil if unknown or a secret value (which can't be a table key).
local function getGuid(entry)
  local guid = entry.guid or (entry.friendInfo and entry.friendInfo.guid)
    or (entry.accountInfo and entry.accountInfo.gameAccountInfo.playerGuid)
  if guid and not (_G.issecretvalue and _G.issecretvalue(guid)) then return guid end
end

--- Sizes a row's name column like the standalone lists: the name takes whatever the widest zone doesn't need,
--- but keeps at least NAME_COLUMN_MIN_SHARE of the row when both don't fit.
---@param row Button A person row created by initRow().
local function layoutRow(row)
  -- A freshly bound row isn't anchored yet and reports a width of 0, so the ScrollBox's width is used instead.
  local available = window.ScrollBox:GetWidth() - 2 * ROW_PADDING - COLUMN_GAP
  local width = math.max(available - zoneColumnWidth, math.min(nameColumnWidth, available * NAME_COLUMN_MIN_SHARE))
  row.Name:SetWidth(math.max(width, 1)) -- A width of 0 would mean "unbounded" and stop truncation.
end

--- ScrollBox initializer for a person row: builds its name and zone columns once, then binds it to an entry. The
--- tooltip and context menu come from the list module the entry belongs to.
---@param row Button A pooled row from the ScrollBox.
---@param data table Element data: { entry, listModule }.
local function initRow(row, data)
  if not row.Name then
    row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row.Name:SetPoint("LEFT", ROW_PADDING, 0)
    row.Zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Zone:SetJustifyH("LEFT")
    row.Zone:SetWordWrap(false)
    row.Zone:SetPoint("LEFT", row.Name, "RIGHT", COLUMN_GAP, 0)
    row.Zone:SetPoint("RIGHT", -ROW_PADDING, 0)
    row:SetScript("OnEnter", function(self)
      onWindowEnter()
      self.listModule:ShowTooltip(self, self.entry)
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    enableRowClicks(row, window, function(self) self.listModule:OpenMenu(self.entry) end)
  end
  row.entry, row.listModule = data.entry, data.listModule
  layoutRow(row)
  row.Name:SetText(data.entry.name)
  row.Zone:SetText(data.entry.zoneText)
end

local populate

--- Collapses or expands one stacked list, like ObjectiveTrackerModuleHeaderMixin:OnToggle (including its sound).
---@param key string The section key: "friends" or "guildies".
local function toggleSection(key)
  local collapsed = getSettings().collapsed
  collapsed[key] = not collapsed[key]
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  populate()
end

--- ScrollBox initializer for a section header, a Lua copy of ObjectiveTrackerModuleHeaderTemplate
--- (Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.xml): the secondary header art, the list's title
--- and a MinimizeButton whose atlases swap like ObjectiveTrackerModuleHeaderMixin:SetCollapsed. The element is
--- SECTION_SPACING taller above every section but the first, so everything is anchored to its bottom.
---@param header Frame A pooled header frame from the ScrollBox.
---@param data table Element data: { key, text, collapsed, spacing }.
local function initSectionHeader(header, data)
  if not header.Text then
    local center = SECTION_HEADER_HEIGHT / 2
    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("UI-QuestTracker-Secondary-Objective-Header", TextureKitConstants.UseAtlasSize)
    -- Stretched across the list (the template centers it at a fixed size) since this window can be resized.
    background:SetPoint("LEFT", header, "BOTTOMLEFT", 0, center)
    background:SetPoint("RIGHT", header, "BOTTOMRIGHT", 0, center)

    local button = CreateFrame("Button", nil, header)
    button:SetSize(SECTION_BUTTON_SIZE, SECTION_BUTTON_SIZE)
    button:SetPoint("RIGHT", header, "BOTTOMRIGHT", -1, center)
    button:SetHighlightAtlas("ui-questtrackerbutton-yellow-highlight", "ADD")
    button:SetScript("OnClick", function(self) toggleSection(self:GetParent().key) end)
    -- Entering the button skips the window's own OnEnter, so it has to start the hover fades itself.
    button:SetScript("OnEnter", onWindowEnter)
    header.MinimizeButton = button

    header.Text = header:CreateFontString(nil, "ARTWORK", getHeaderFont())
    header.Text:SetJustifyH("LEFT")
    header.Text:SetWordWrap(false)
    header.Text:SetPoint("LEFT", header, "BOTTOMLEFT", HEADER_TEXT_INSET, center)
    header.Text:SetPoint("RIGHT", button, "LEFT", -2, 0)
  end
  header.key = data.key
  header.Text:SetText(data.text)
  local atlas = data.collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse"
  header.MinimizeButton:SetNormalAtlas(atlas)
  header.MinimizeButton:SetPushedAtlas(atlas .. "-pressed")
end

--- Returns the widest rendered width of a field across entries, measured in the rows' font.
---@param entries table List entries.
---@param field string "name" or "zoneText".
---@return number width The widest width in whole pixels plus one so rounding never truncates (0 when empty).
local function measureWidest(entries, field)
  local width = 0
  for _, entry in ipairs(entries) do
    window.Measure:SetText(entry[field])
    width = math.max(width, window.Measure:GetUnboundedStringWidth())
  end
  return width > 0 and math.ceil(width) + 1 or 0
end

--- When `fitToContent` is on, sizes the window to its title, widest name and zone, and every header and row, up
--- to MAX_FIT_HEIGHT (then it scrolls). Like the standalone lists, it grows from its top-left corner and only
--- moves when it would run off the screen.
---@param contentHeight number Total height of the ScrollBox's elements.
local function fitToContent(contentHeight)
  if not getSettings().fitToContent then return end
  local height = HEADER_HEIGHT + LIST_TOP_GAP + contentHeight + LIST_BOTTOM_INSET
  local scrollBarSpace = height > MAX_FIT_HEIGHT and SCROLL_BAR_SPACE or 0
  local listWidth = LIST_LEFT_INSET + ROW_PADDING + nameColumnWidth + COLUMN_GAP + zoneColumnWidth + ROW_PADDING
    + LIST_RIGHT_INSET + scrollBarSpace
  local titleWidth = window.Title:GetUnboundedStringWidth() + HEADER_BUTTONS_WIDTH
  local width = math.min(math.ceil(math.max(listWidth, titleWidth, MIN_WIDTH)), UIParent:GetWidth())
  local fitHeight = math.min(height, MAX_FIT_HEIGHT)
  local left, top = window:GetLeft(), window:GetTop()
  if left then
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", math.max(math.min(left, UIParent:GetWidth() - width), 0),
      math.min(math.max(top, fitHeight), UIParent:GetHeight()))
    saveLayout()
  end
  window:SetSize(width, fitHeight)
  updateHitRect()
end

--- Rebuilds the stacked list: a header per enabled list module in the saved `stackOrder`, followed by that list's
--- rows unless the section is collapsed. The title counts everyone online in either list, counting a person who
--- is both a friend and a guildie once.
function populate()
  local settings = getSettings()
  local elements, visibleEntries, seen = {}, {}, {}
  local total, contentHeight = 0, 0
  for _, key in ipairs(STACK_ORDERS[settings.stackOrder] or STACK_ORDERS.friends) do
    local section = SECTIONS[key]
    local listModule = Self[section.module]
    if listModule:IsEnabled() then
      local entries, unavailableTitle = listModule:GetEntries()
      for _, entry in ipairs(entries) do
        local guid = getGuid(entry)
        if not (guid and seen[guid]) then total = total + 1 end
        if guid then seen[guid] = true end
      end
      local spacing = #elements > 0 and SECTION_SPACING or 0
      local collapsed = settings.collapsed[key]
      elements[#elements + 1] = {
        key = key,
        text = unavailableTitle or (section.title .. " (" .. #entries .. ")"),
        collapsed = collapsed,
        spacing = spacing,
      }
      contentHeight = contentHeight + SECTION_HEADER_HEIGHT + spacing
      if not collapsed then
        for _, entry in ipairs(entries) do
          elements[#elements + 1] = { entry = entry, listModule = listModule }
          visibleEntries[#visibleEntries + 1] = entry
        end
        contentHeight = contentHeight + #entries * ROW_HEIGHT
      end
    end
  end

  nameColumnWidth = measureWidest(visibleEntries, "name")
  zoneColumnWidth = measureWidest(visibleEntries, "zoneText")
  window.Title:SetText("Players Online (" .. total .. ")")
  window.ScrollBox:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants.RetainScrollPosition)
  fitToContent(contentHeight)
end

--- Saves the fit-to-content setting and applies it: fits the window now, or restores the manual size. The resize
--- handle is hidden while fitting since the window sizes itself.
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

--- Builds the Players Online window: an Objective Tracker container header (title, cog and MinimizeButton) over the
--- DamageMeterSessionWindowTemplate body the standalone lists use (a MinimizeContainer with the background, scroll
--- list and resize handle), with a ScrollBox that mixes section headers and person rows.
local function createWindow()
  window = CreateFrame("Frame", "SlackHacksPlayersOnline", UIParent)
  window:Hide() -- New frames start shown; hiding lets the first Show() fire OnShow.
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:SetResizable(true)
  window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
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
    -- Ask for fresh data like the standalone windows do when shown; the list modules' events then refresh this.
    if Self.GuildieList:IsEnabled() then Self.GuildieList:RequestRoster() end
    if Self.FriendsList:IsEnabled() then Self.FriendsList:RequestFriends() end
  end)

  -- The header bar is a Lua copy of ObjectiveTrackerContainerHeaderTemplate, the "All Objectives" header
  -- (ObjectiveTrackerFrame.Header, Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.xml). Its
  -- background is stretched across the window rather than centered at a fixed size, since the window resizes.
  local header = window:CreateTexture(nil, "BACKGROUND")
  header:SetAtlas("ui-questtracker-primary-objective-header")
  header:SetHeight(HEADER_HEIGHT)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")

  local minimizeButton = CreateFrame("Button", nil, window)
  minimizeButton:SetSize(18, 19)
  minimizeButton:SetPoint("RIGHT", header, "RIGHT", -1, 0)
  minimizeButton:SetNormalAtlas("ui-questtrackerbutton-collapse-all")
  minimizeButton:SetPushedAtlas("ui-questtrackerbutton-collapse-all-pressed")
  minimizeButton:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
  minimizeButton:SetScript("OnClick", function() setMinimized(not getSettings().minimized) end)
  window.MinimizeButton = minimizeButton

  local settingsDropdown = createSettingsCog(window, function(_, rootDescription)
    rootDescription:SetTag(SETTINGS_MENU_TAG)
    rootDescription:CreateCheckbox("Fit to Content",
      function() return getSettings().fitToContent end,
      function() setFitToContent(not getSettings().fitToContent) end)
  end)
  -- Where the container header's (hidden) FilterButton sits: just left of the MinimizeButton.
  settingsDropdown:SetPoint("RIGHT", minimizeButton, "LEFT", -2, 0)

  local title = window:CreateFontString(nil, "ARTWORK", getHeaderFont())
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  title:SetPoint("LEFT", header, "LEFT", HEADER_TEXT_INSET, 0)
  title:SetPoint("RIGHT", settingsDropdown, "LEFT", -4, 0)
  window.Title = title

  -- Invisible text for measuring names/zones in the rows' font; shown at zero alpha so inline icons lay out.
  local measure = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  measure:SetPoint("TOPLEFT")
  measure:SetAlpha(0)
  window.Measure = measure

  local container = CreateFrame("Frame", nil, window)
  container:SetAllPoints()
  container:SetUsingParentLevel(true)
  window.MinimizeContainer = container

  local background = container:CreateTexture(nil, "BACKGROUND")
  background:SetAtlas("damagemeters-background")
  background:SetAllPoints()
  background:SetAlpha(BACKGROUND_ALPHA)

  local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
  local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 0, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 0, 8)
  window.ScrollBox = scrollBox

  -- Headers and rows are different frame types, so the ScrollBox's frame factory pools them separately.
  local view = CreateScrollBoxListLinearView()
  view:SetElementFactory(function(factory, data)
    if data.entry then factory("Button", initRow) else factory("Frame", initSectionHeader) end
  end)
  view:SetElementExtentCalculator(function(_, data)
    return data.entry and ROW_HEIGHT or SECTION_HEADER_HEIGHT + data.spacing
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
  -- Re-split the row columns whenever the list's width changes (resizing, scroll bar showing or hiding).
  scrollBox:HookScript("OnSizeChanged", function(self)
    self:ForEachFrame(function(frame) if frame.Name then layoutRow(frame) end end)
  end)

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
    window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, UIParent:GetWidth(), UIParent:GetHeight())
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

  local settings = getSettings()
  window:SetPoint(settings.point, UIParent, settings.relativePoint, settings.x, settings.y)
  window:SetSize(settings.width, settings.height)
  setMinimized(settings.minimized)
  setFitToContent(settings.fitToContent)
end

--- Returns whether the Friends and Guildie lists are stacked into the Players Online window (Retail only, like the
--- lists themselves).
---@return boolean stacked
function module:IsPlayersOnlineStacked()
  return isRetail() and getSettings().stacked
end

--- Shows, redraws or hides the Players Online window: it shows while stacking is on and at least one of the lists
--- is enabled. Called by the list modules whenever their data or settings change.
function module:RefreshPlayersOnline()
  if not (self:IsPlayersOnlineStacked() and (Self.GuildieList:IsEnabled() or Self.FriendsList:IsEnabled())) then
    if window then window:Hide() end
    return
  end
  if not window then createWindow() end
  if window:IsShown() then populate() else window:Show() end -- OnShow populates.
end

--- Saves whether the lists are stacked, then swaps the lists' own windows for the Players Online window (or back).
---@param stacked boolean Whether to stack the Friends and Guildie lists.
function module:SetStackPeopleLists(stacked)
  getSettings().stacked = stacked
  for _, section in pairs(SECTIONS) do
    local listModule = Self[section.module]
    if listModule:IsEnabled() then listModule:UpdateWindowShown() end
  end
  self:RefreshPlayersOnline()
end

--- Saves which list is stacked on top and redraws the Players Online window.
---@param order string A STACK_ORDERS key: "friends" (Friends, Guildies) or "guildies" (Guildies, Friends).
function module:SetStackOrder(order)
  getSettings().stackOrder = order
  if window and window:IsShown() then populate() end
end
