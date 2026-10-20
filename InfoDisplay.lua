setfenv(1, _G.SlackHacks)

-- Info Display: switches the Char Sheet overlays on and off, and hosts the "Players Online" window, which stacks the
-- Friends and Guildie lists into one window the way Blizzard's Objective Tracker ("All Objectives",
-- Blizzard_ObjectiveTracker) stacks its modules: each list gets a module header (ObjectiveTrackerModuleHeaderTemplate)
-- whose secondary minimize button collapses just that list, with a cog for that list's own options beside it. The
-- window's header bar copies the tracker's own
-- "All Objectives" header (ObjectiveTrackerContainerHeaderTemplate), and the rest of the window is the same
-- DamageMeterSessionWindowTemplate recreation the lists use on their own (background, cog, resize handle). The
-- list modules still build their entries, tooltips and menus; this window only lays them out. This module's enable
-- switch is the master switch for all Info Display sub-modules (SUBMODULES); the window follows the lists' state.
local module = Self:NewModule("InfoDisplay")
Self.InfoDisplay = module

local HEADER_HEIGHT = 32 -- Window header bar, from ObjectiveTrackerContainerHeaderTemplate.
local HEADER_TEMPLATE_WIDTH = 260 -- ObjectiveTrackerContainerHeaderTemplate's width, which its art overhangs.
local HEADER_ATLAS = "ui-questtracker-primary-objective-header"
local SECTION_HEADER_HEIGHT = 26 -- ObjectiveTrackerModuleHeaderTemplate's height.
local SECTION_SPACING = 10 -- The Objective Tracker container's spacing between modules.
local HEADER_TEXT_INSET = 7 -- Both Objective Tracker header templates' Text offset.
local SECTION_BUTTON_SIZE = 16 -- The module header's MinimizeButton size.
local COG_SIZE = 27 -- DamageMeterSettingsDropdownButtonTemplate's size.
local COG_Y_OFFSET = -2 -- The DamageMeter's SettingsDropdown offset from its MinimizeButton.
-- Section cogs are scaled down to suit the smaller section header and button, like the tracker's own buttons.
local SECTION_COG_SIZE = 22
local ROW_HEIGHT = 18
-- Column layout, matching the standalone lists so names and zones look the same.
local NAME_COLUMN_MIN_SHARE = 0.6
local COLUMN_GAP = 6
local ROW_PADDING = 5
local LIST_TOP_GAP = 2
local LIST_LEFT_INSET = 5
local LIST_RIGHT_INSET = 1
local LIST_BOTTOM_INSET = 6
-- The ScrollBox spans the window's full width so the section headers line up with the window header like the
-- tracker's module headers do; the list insets move into the rows. It's also widened past both window edges by
-- `sectionOverhang`, since it clips its contents and the section header art overhangs like the window header's.
local ROW_LEFT_INSET = LIST_LEFT_INSET + ROW_PADDING
local ROW_RIGHT_INSET = LIST_RIGHT_INSET + ROW_PADDING
local SECTION_ATLAS = "UI-QuestTracker-Secondary-Objective-Header"
local SCROLL_BAR_SPACE = 15
local HEADER_BUTTONS_WIDTH = 62 -- Header space beside the title: title inset, cog, minimize button and gaps.
local MIN_WIDTH = 200
local MIN_HEIGHT = 120
local MAX_FIT_HEIGHT = 600 -- Taller than a single list's limit since it holds both; beyond this the list scrolls.
local OPACITY_STEP = 0.05
local SCROLL_BAR_IDLE_ALPHA = 0.3
local FADE_DURATION = 0.25
local SETTINGS_MENU_TAG = "MENU_SLACKHACKS_PLAYERS_ONLINE_SETTINGS"
-- AceModule names on Self that the Info Display's enable switch turns on and off.
local SUBMODULES = { "CharSheet", "Weeklies", "GuildieList", "FriendsList" }
-- The stacked lists, keyed by section; `module` is the list's AceModule name on Self.
local SECTIONS = {
  friends = { module = "FriendsList", title = "Friends", listName = "Friends List" },
  guildies = { module = "GuildieList", title = "Guildies", listName = "Guildies List" },
}
-- Section order for each `stackOrder` setting value.
local STACK_ORDERS = {
  friends = { "friends", "guildies" },
  guildies = { "guildies", "friends" },
}

local window
local opacityPanel
-- Untruncated widths of the widest name and zone across both lists, so the columns line up between sections.
local nameColumnWidth, zoneColumnWidth = 0, 0
-- How far the section header art overhangs each side of the window, measured from the atlas in createWindow.
local sectionOverhang = 0

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

--- Turns the whole Info Display on or off and saves the choice. It's the master switch for every sub-module:
--- each one also checks `infoDisplay.enabled` when it initializes and enables, so turning this on only starts the
--- sub-modules whose own settings are on, and the Players Online window goes away with the lists.
---@param enabled boolean Whether the Info Display sub-modules may run.
function module:SetEnabled(enabled)
  db.profile.infoDisplay.enabled = enabled
  if enabled then self:Enable() else self:Disable() end
  for _, name in ipairs(SUBMODULES) do
    local submodule = Self[name]
    if submodule then
      if enabled then submodule:Enable() else submodule:Disable() end
    end
  end
  self:Refresh()
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- AceAddon initialization hook; keeps the module disabled when the Info Display is turned off.
function module:OnInitialize()
  if not db.profile.infoDisplay.enabled then self:Disable() end
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
  local available = window.ScrollBox:GetWidth() - 2 * sectionOverhang - ROW_LEFT_INSET - ROW_RIGHT_INSET
    - COLUMN_GAP
  local width = math.max(available - zoneColumnWidth, math.min(nameColumnWidth, available * NAME_COLUMN_MIN_SHARE))
  row.Name:SetWidth(math.max(width, 1)) -- A width of 0 would mean "unbounded" and stop truncation.
end

--- ScrollBox initializer for a person row: builds its name and zone columns once, then binds it to an entry. The
--- tooltip and context menu come from the list module the entry belongs to.
---@param row Button A pooled row from the ScrollBox.
---@param data table Element data: { entry, listModule }.
local function initRow(row, data)
  setListMouseInteraction(row, false)
  if not row.Name then
    row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row.Name:SetPoint("LEFT", sectionOverhang + ROW_LEFT_INSET, 0)
    row.Zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Zone:SetJustifyH("LEFT")
    row.Zone:SetWordWrap(false)
    row.Zone:SetPoint("LEFT", row.Name, "RIGHT", COLUMN_GAP, 0)
    row.Zone:SetPoint("RIGHT", -sectionOverhang - ROW_RIGHT_INSET, 0)
    -- Rows span the widened ScrollBox; keep their mouse area inside the window.
    row:SetHitRectInsets(sectionOverhang, sectionOverhang, 0, 0)
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
  -- Initializers also run on pooled frames after deferred ScrollBox layout.
  setListMouseInteraction(row, getSettings().nonInteractive)
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

--- Fills a section header cog's menu with its list's own options (sorting, filters, icons), the same ones the
--- list's standalone cog has apart from the window-wide Fit to Content and opacity.
---@param cog DropdownButton The section's cog; its parent header knows which section it belongs to.
---@param rootDescription table The menu's root description.
local function buildSectionMenu(cog, rootDescription)
  local key = cog:GetParent().key
  rootDescription:SetTag(SETTINGS_MENU_TAG .. "_" .. key:upper())
  Self[SECTIONS[key].module]:AddListOptions(rootDescription)
end

--- ScrollBox initializer for a section header, a Lua copy of ObjectiveTrackerModuleHeaderTemplate
--- (Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerModule.xml): the secondary header art, the list's title
--- and a MinimizeButton whose atlases swap like ObjectiveTrackerModuleHeaderMixin:SetCollapsed. The element is
--- SECTION_SPACING taller above every section but the first, so everything is anchored to its bottom.
---@param header Frame A pooled header frame from the ScrollBox.
---@param data table Element data: { key, text, collapsed, spacing }.
local function initSectionHeader(header, data)
  setListMouseInteraction(header, false)
  -- Set before the cog is created: DropdownButtonMixin:SetupMenu runs buildSectionMenu right away when the cog is
  -- shown (Retail and Forever alike), and the menu reads the section from its header's key.
  header.key = data.key
  if not header.Text then
    local center = SECTION_HEADER_HEIGHT / 2
    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas(SECTION_ATLAS, TextureKitConstants.UseAtlasSize)
    -- Spans the widened header, so it overhangs the window by `sectionOverhang` on each side like the template's
    -- centered, fixed-size art overhangs its 260-wide header; stretched since this window can be resized.
    background:SetPoint("LEFT", header, "BOTTOMLEFT", 0, center)
    background:SetPoint("RIGHT", header, "BOTTOMRIGHT", 0, center)

    local button = CreateFrame("Button", nil, header)
    button:SetSize(SECTION_BUTTON_SIZE, SECTION_BUTTON_SIZE)
    -- Centered under the window header's 18px MinimizeButton (at -1), as the tracker's module buttons sit under
    -- its "All Objectives" button.
    button:SetPoint("RIGHT", header, "BOTTOMRIGHT", -sectionOverhang - 2, center)
    button:SetHighlightAtlas("ui-questtrackerbutton-yellow-highlight", "ADD")
    button:SetScript("OnClick", function(self) toggleSection(self:GetParent().key) end)
    -- Entering the button skips the window's own OnEnter, so it has to start the hover fades itself.
    button:SetScript("OnEnter", onWindowEnter)
    header.MinimizeButton = button

    -- The list's settings cog, placed and nudged like the window header's, scaled to the smaller section button.
    local cog = createSettingsCog(header, buildSectionMenu)
    cog:SetSize(SECTION_COG_SIZE, SECTION_COG_SIZE)
    cog:SetPoint("RIGHT", button, "LEFT", -2, COG_Y_OFFSET * SECTION_COG_SIZE / COG_SIZE)
    cog:HookScript("OnEnter", onWindowEnter)

    header.Text = header:CreateFontString(nil, "ARTWORK", getHeaderFont())
    header.Text:SetJustifyH("LEFT")
    header.Text:SetWordWrap(false)
    header.Text:SetPoint("LEFT", header, "BOTTOMLEFT", sectionOverhang + HEADER_TEXT_INSET, center)
    header.Text:SetPoint("RIGHT", cog, "LEFT", -2, 0)
  end
  header.Text:SetText(data.text)
  local atlas = data.collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse"
  header.MinimizeButton:SetNormalAtlas(atlas)
  header.MinimizeButton:SetPushedAtlas(atlas .. "-pressed")
  setListMouseInteraction(header, getSettings().nonInteractive)
end

--- Returns the widest rendered width of a field across entries, measured in the rows' font. Friends' names are
--- measured both as displayed and as their `measureName` stand-in, since protected Battle.net names measure short.
---@param entries table List entries.
---@param field string "name" or "zoneText".
---@return number width The widest width in whole pixels plus one so rounding never truncates (0 when empty).
local function measureWidest(entries, field)
  local width = 0
  for _, entry in ipairs(entries) do
    window.Measure:SetText(entry[field])
    width = math.max(width, window.Measure:GetUnboundedStringWidth())
    if field == "name" and entry.measureName then
      window.Measure:SetText(entry.measureName)
      width = math.max(width, window.Measure:GetUnboundedStringWidth())
    end
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
  applyListWindowInteraction(window, settings)
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

--- Saves and applies the background opacity; like the standalone lists, only the background fades, so the
--- headers and names stay readable.
---@param opacity number Background alpha from 0 to 1; rounded to OPACITY_STEP to drop slider float noise.
local function setOpacity(opacity)
  opacity = math.floor(opacity / OPACITY_STEP + 0.5) * OPACITY_STEP
  getSettings().opacity = opacity
  if window then window.Background:SetAlpha(opacity) end
end

--- Opens the same opacity slider panel the standalone lists use, to the right of the window.
local function showOpacityPanel()
  opacityPanel = opacityPanel
    or createSliderPanel("SlackHacksPlayersOnlineOpacityFrame", OPACITY or "Opacity", 0, 1, OPACITY_STEP, setOpacity)
  opacityPanel:Open(getSettings().opacity, "TOPLEFT", window, "TOPRIGHT", 0, 7)
end

--- Fills the window header cog's menu with the settings that apply to the whole window, plus a checkbox per list
--- to turn it on or off (unchecking both also turns stacking off; see OnListEnabledChanged). Each list's own
--- options are in its section header's cog instead.
---@param _ Frame The cog button (unused).
---@param rootDescription table The menu's root description.
local function buildSettingsMenu(_, rootDescription)
  rootDescription:SetTag(SETTINGS_MENU_TAG)
  module:AddListWindowOptions(rootDescription, "playersOnline")
  rootDescription:CreateCheckbox("Fit to Content",
    function() return getSettings().fitToContent end,
    function() setFitToContent(not getSettings().fitToContent) end)
  rootDescription:CreateButton(BATTLEFIELDMINIMAP_OPACITY_LABEL or "Change Opacity", showOpacityPanel)
  rootDescription:CreateDivider()
  rootDescription:CreateCheckbox("Stack Friend/Guildie List",
    function() return getSettings().stacked end,
    function() module:SetStackLists(not getSettings().stacked) end)
  for _, key in ipairs(STACK_ORDERS[getSettings().stackOrder] or STACK_ORDERS.friends) do
    local listModule = Self[SECTIONS[key].module]
    rootDescription:CreateCheckbox(SECTIONS[key].listName,
      function() return listModule:IsEnabled() end,
      function() listModule:SetEnabled(not listModule:IsEnabled()) end)
  end
end

--- Publishes a fully built window to the module-level `window` upvalue, which createWindow's local shadows.
---@param frame Frame The finished Players Online window.
local function setWindow(frame)
  window = frame
end

--- Builds the Players Online window: an Objective Tracker container header (title, cog and MinimizeButton) over the
--- DamageMeterSessionWindowTemplate body the standalone lists use (a MinimizeContainer with the background, scroll
--- list and resize handle), with a ScrollBox that mixes section headers and person rows.
local function createWindow()
  -- Built in a local that shadows the module's `window`, which is only set once construction finishes: if a build
  -- step errors, the next refresh retries (and shows the real error) instead of using a half-built window, whose
  -- missing fields would otherwise surface as misleading errors elsewhere.
  local window = CreateFrame("Frame", "SlackHacksPlayersOnline", UIParent)
  window:Hide() -- New frames start shown; hiding lets the first Show() fire OnShow.
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:SetResizable(true)
  window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", function(self)
    if self:IsMovable() then self:StartMoving() end
  end)
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
  -- (ObjectiveTrackerFrame.Header, Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.xml): an invisible
  -- HEADER_HEIGHT frame holding the text and buttons, with a Background drawn at the atlas's own size, centered on
  -- it, so the art overhangs the frame on every side. Here the header spans the resizable window, so the art keeps
  -- the template's overhang (atlas size minus the 260x32 frame) instead of its fixed size.
  local header = CreateFrame("Frame", nil, window)
  header:SetHeight(HEADER_HEIGHT)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetUsingParentLevel(true)
  local headerBackground = window:CreateTexture(nil, "BACKGROUND")
  -- The atlas's native size comes from drawing it at that size, not C_Texture.GetAtlasInfo: that API resolves
  -- Vector2DMixin from the caller's environment, which is SlackHacks (setfenv) rather than _G, and errors.
  headerBackground:SetAtlas(HEADER_ATLAS, TextureKitConstants.UseAtlasSize)
  local atlasWidth, atlasHeight = headerBackground:GetSize()
  local overhangX = (atlasWidth - HEADER_TEMPLATE_WIDTH) / 2
  local overhangY = (atlasHeight - HEADER_HEIGHT) / 2
  headerBackground:SetPoint("TOPLEFT", header, "TOPLEFT", -overhangX, overhangY)
  headerBackground:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", overhangX, -overhangY)

  local minimizeButton = CreateFrame("Button", nil, header)
  minimizeButton:SetSize(18, 19)
  minimizeButton:SetPoint("RIGHT", header, "RIGHT", -1, 0)
  minimizeButton:SetNormalAtlas("ui-questtrackerbutton-collapse-all")
  minimizeButton:SetPushedAtlas("ui-questtrackerbutton-collapse-all-pressed")
  minimizeButton:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
  minimizeButton:SetScript("OnClick", function() setMinimized(not getSettings().minimized) end)
  window.MinimizeButton = minimizeButton

  local settingsDropdown = createSettingsCog(header, buildSettingsMenu)
  -- Where the container header's (hidden) FilterButton sits, just left of the MinimizeButton. The cog art sits
  -- high inside its 27x27 button, so it's nudged down by the same 2px the DamageMeter uses to line it up with the
  -- MinimizeButton (DamageMeterSessionWindowTemplate's SettingsDropdown anchor).
  settingsDropdown:SetPoint("RIGHT", minimizeButton, "LEFT", -2, COG_Y_OFFSET)
  settingsDropdown:HookScript("OnEnter", onWindowEnter)
  window.SettingsDropdown = settingsDropdown

  local title = header:CreateFontString(nil, "ARTWORK", getHeaderFont())
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
  window.Background = background

  -- Measures the section header art the same way as the window header's, before any section header is built.
  local sectionBackground = container:CreateTexture()
  sectionBackground:SetAtlas(SECTION_ATLAS, TextureKitConstants.UseAtlasSize)
  sectionOverhang = math.max((sectionBackground:GetWidth() - HEADER_TEMPLATE_WIDTH) / 2, 0)
  sectionBackground:Hide()

  local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
  local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
  -- Pulled back over the ScrollBox's overhang so the bar sits inside the window.
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", -sectionOverhang, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", -sectionOverhang, 8)
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

  local topLeft = CreateAnchor("TOPLEFT", header, "BOTTOMLEFT", -sectionOverhang, -LIST_TOP_GAP)
  ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
    { topLeft, CreateAnchor("BOTTOMRIGHT", sectionOverhang - SCROLL_BAR_SPACE, LIST_BOTTOM_INSET) },
    { topLeft, CreateAnchor("BOTTOMRIGHT", sectionOverhang, LIST_BOTTOM_INSET) })

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
  setWindow(window)

  local settings = getSettings()
  window:SetPoint(settings.point, UIParent, settings.relativePoint, settings.x, settings.y)
  window:SetSize(settings.width, settings.height)
  setMinimized(settings.minimized)
  setOpacity(settings.opacity)
  setFitToContent(settings.fitToContent)
  applyListWindowInteraction(window, settings)
end

--- Returns whether the Friends and Guildie lists are stacked into the Players Online window (Retail and Forever
--- only, like the lists themselves).
---@return boolean stacked
function module:IsPlayersOnlineStacked()
  return isRetailOrForever() and getSettings().stacked
end

--- Returns interaction settings for a standalone list, or the whole Players Online window while stacked.
---@param key string "friendsList", "guildieList", or "playersOnline".
---@return table settings The profile table controlling the visible window.
local function interactionSettings(key)
  if module:IsPlayersOnlineStacked() then key = "playersOnline" end
  return db.profile.infoDisplay[key]
end

--- Reads a window interaction option, using the shared window's value while stacked.
---@param key string The list's profile key.
---@param option string "lockPosition" or "nonInteractive".
---@return boolean enabled Whether the option is on.
function module:GetListWindowOption(key, option)
  return interactionSettings(key)[option]
end

--- Saves and immediately applies a window interaction option, keeping settings and cog menus synchronized.
---@param key string The list's profile key.
---@param option string "lockPosition" or "nonInteractive".
---@param enabled boolean Whether to enable the option.
function module:SetListWindowOption(key, option, enabled)
  interactionSettings(key)[option] = enabled
  if key == "playersOnline" or self:IsPlayersOnlineStacked() then
    self:RefreshPlayersOnline()
  else
    local listModule = key == "friendsList" and Self.FriendsList or Self.GuildieList
    listModule:RefreshWindowInteraction()
  end
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- Adds window-wide interaction settings to a standalone cog or the stacked window's topmost cog only.
---@param rootDescription table The cog menu description.
---@param key string The window's profile key.
function module:AddListWindowOptions(rootDescription, key)
  for _, option in ipairs({
    { key = "lockPosition", name = "Lock Position" },
    { key = "nonInteractive", name = "Make Non-Interactive" },
  }) do
    rootDescription:CreateCheckbox(option.name,
      function() return self:GetListWindowOption(key, option.key) end,
      function() self:SetListWindowOption(key, option.key, not self:GetListWindowOption(key, option.key)) end)
  end
end

--- Shows, redraws or hides the Players Online window: it shows while stacking is on and at least one of the lists
--- is enabled. Called by the list modules whenever their data or settings change.
function module:RefreshPlayersOnline()
  if not (self:IsPlayersOnlineStacked() and (Self.GuildieList:IsEnabled() or Self.FriendsList:IsEnabled())) then
    if window then window:Hide() end
    if opacityPanel then opacityPanel:Hide() end
    return
  end
  if not window then createWindow() end
  if window:IsShown() then populate() else window:Show() end -- OnShow populates.
end

--- Saves whether the lists are stacked, then swaps the lists' own windows for the Players Online window (or back).
--- Also called from the cog menus, so the options panel is told to redraw its checkbox.
---@param stacked boolean Whether to stack the Friends and Guildie lists.
function module:SetStackLists(stacked)
  getSettings().stacked = stacked
  for _, section in pairs(SECTIONS) do
    local listModule = Self[section.module]
    if listModule:IsEnabled() then listModule:UpdateWindowShown() end
  end
  self:RefreshPlayersOnline()
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- Adds a "Stack Friend/Guildie List" checkbox to a standalone list's cog menu, only when both lists are enabled
--- (with just one there's nothing to stack).
---@param rootDescription table The list's cog menu description.
function module:AddStackMenuButton(rootDescription)
  if isRetailOrForever() and Self.GuildieList:IsEnabled() and Self.FriendsList:IsEnabled() then
    rootDescription:CreateCheckbox("Stack Friend/Guildie List",
      function() return getSettings().stacked end,
      function() self:SetStackLists(not getSettings().stacked) end)
  end
end

--- Called after the user turns the Friends or Guildie List on or off. The Players Online window's visibility belongs
--- to the stacking option, so once neither list is enabled stacking is turned off too; otherwise the window would
--- vanish with its cog (the only in-window way back) while stacking stayed on. Uses the saved settings rather than
--- IsEnabled() so the Info Display master switch, which disables the modules without touching them, doesn't count.
function module:OnListEnabledChanged()
  local infoDisplay = db.profile.infoDisplay
  if getSettings().stacked and not infoDisplay.friendsList.enabled and not infoDisplay.guildieList.enabled then
    self:SetStackLists(false) -- Also notifies the options panel.
    return
  end
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- Saves which list is stacked on top and redraws the Players Online window.
---@param order string A STACK_ORDERS key: "friends" (Friends, Guildies) or "guildies" (Guildies, Friends).
function module:SetStackOrder(order)
  getSettings().stackOrder = order
  if window and window:IsShown() then populate() end
end
