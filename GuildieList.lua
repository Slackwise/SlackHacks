setfenv(1, _G.SlackHacks)

-- Guildie List: a movable, resizable, collapsible list of online guild members.
-- The roster logic is the same as the GuildMembersOnline addon (GetGuildRosterInfo -> class-colored name and
-- zone), shown as two columns and sorted by name or zone, with a full player tooltip, optional rank and faction
-- icons after names and instance icons after zones. Left- or right-clicking a member opens the guild roster's
-- context menu (Invite, Whisper, View Houses). The window recreates Blizzard's
-- DamageMeterSessionWindowTemplate (Blizzard_DamageMeter/DamageMeterSessionWindow.xml) in Lua, including
-- its MinimizeButton, which collapses the window down to its header bar, and its SettingsDropdown cog menu.
local module = Self:NewModule("GuildieList", "AceEvent-3.0")
Self.GuildieList = module

local HEADER_HEIGHT = 32 -- Explicit header height from the Blizzard template so the scroll box can anchor to it.
local ROW_HEIGHT = 18
-- When a row is too narrow for both columns, the name column keeps at least this share of the row (or its full
-- width, if smaller) and the zone column is truncated first.
local NAME_COLUMN_MIN_SHARE = 0.6
local COLUMN_GAP = 6
local ROW_PADDING = 5 -- Space between a row's edges and its text.
-- Scroll list insets inside the window (from DamageMeterSessionWindowMixin:InitializeScrollBox).
local LIST_TOP_GAP = 2
local LIST_LEFT_INSET = 5
local LIST_RIGHT_INSET = 1
local LIST_BOTTOM_INSET = 6
local SCROLL_BAR_SPACE = 15 -- Extra right inset while the scroll bar is showing.
local HEADER_BUTTONS_WIDTH = 62 -- Header space beside the title: title inset, cog, minimize button and gaps.
local MIN_WIDTH = 200
local MIN_HEIGHT = 120
local MAX_FIT_HEIGHT = 400 -- Fit to content stops growing here and scrolls; manual resizing can go to full screen.
local INSTANCE_ICON_SIZE = 12
-- Inline icons from the world map's pins (delves-regular is the Map Legend's delve icon).
local INSTANCE_ICONS = {
  dungeon = CreateAtlasMarkup("Dungeon", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
  raid = CreateAtlasMarkup("Raid", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
  delve = CreateAtlasMarkup("delves-regular", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
}
-- Inline faction icons keyed by Enum.PvPFaction (0 = Horde, 1 = Alliance). Blizzard's quest log uses these same
-- atlases inline in text for faction-specific quests (QuestUtils.lua), so they're known to render as markup. The
-- FriendsFrame's travelPassButton faction atlases are button art (friendslist-invitebutton-horde-normal) and too
-- wide for inline text.
local FACTION_ICONS = {
  [0] = CreateAtlasMarkup("questlog-questtypeicon-horde", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
  [1] = CreateAtlasMarkup("questlog-questtypeicon-alliance", INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE),
}
-- Inline rank icons keyed by Enum.ClubRoleIdentifier, the same textures the guild roster
-- (CommunitiesMemberListEntryMixin:UpdateRank) shows: a crown for the Guild Master and an assistant icon for officers.
local RANK_ICONS = {
  [Enum.ClubRoleIdentifier.Owner] = CreateTextureMarkup("Interface\\GroupFrame\\UI-Group-LeaderIcon", 16, 16,
    INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE, 0, 1, 0, 1),
  [Enum.ClubRoleIdentifier.Leader] = CreateTextureMarkup("Interface\\GroupFrame\\UI-Group-LeaderIcon", 16, 16,
    INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE, 0, 1, 0, 1),
  [Enum.ClubRoleIdentifier.Moderator] = CreateTextureMarkup("Interface\\GroupFrame\\UI-Group-AssistantIcon", 16, 16,
    INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE, 0, 1, 0, 1),
}
local OPACITY_STEP = 0.05
local SCROLL_BAR_IDLE_ALPHA = 0.3 -- The scroll bar is dimmed until the window is hovered, like the DamageMeter.
local FADE_DURATION = 0.25
local ROSTER_REQUEST_DELAY = 2 -- GuildMembersOnline waits for roster data to settle after a loading screen.
local SETTINGS_MENU_TAG = "MENU_SLACKHACKS_GUILDIE_LIST_SETTINGS"

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
-- Untruncated widths of the widest name and zone, measured by populate().
local nameColumnWidth, zoneColumnWidth = 0, 0
local memberClubInfo = {} -- Member GUID -> { faction, race, role, timerunningSeasonID }; filled by scanMemberClubInfo().

--- Returns the Enum.PvPFaction for a race, used when club member info omits the faction (it often comes back nil).
--- Neutral races (e.g. Pandaren, Dracthyr) have no fixed faction, so they return nil.
---@param raceID number|nil The member's race ID.
---@return number|nil faction 0 = Horde, 1 = Alliance, or nil if unknown.
local function factionFromRace(raceID)
  local factionInfo = raceID and C_CreatureInfo.GetFactionInfo(raceID)
  return factionInfo and PLAYER_FACTION_GROUP[factionInfo.groupTag]
end

--- Records each guild member's faction, race and Timerunning season, keyed by GUID. The legacy guild roster
--- (GetGuildRosterInfo) has none of these, but cross-faction guilds made the guild a Communities club whose member
--- info does, so this reads it the way Blizzard's Communities member list does. None of these change, so results
--- are cached for the session and this only re-runs when an online member isn't cached yet (e.g. someone joined).
local function scanMemberClubInfo()
  local clubId = C_Club.GetGuildClubId()
  if not clubId then return end
  for _, memberId in ipairs(C_Club.GetClubMembers(clubId) or {}) do
    local info = C_Club.GetMemberInfo(clubId, memberId)
    -- GUIDs can be secret values in restricted (combat) contexts, and secret values can't be used as table keys.
    if info and info.guid and not (_G.issecretvalue and _G.issecretvalue(info.guid)) then
      memberClubInfo[info.guid] = {
        faction = info.faction or factionFromRace(info.race),
        race = info.race,
        role = info.role,
        timerunningSeasonID = info.timerunningSeasonID,
      }
    end
  end
end

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
---@return table settings The `infoDisplay.guildieList` profile table.
local function getSettings()
  return db.profile.infoDisplay.guildieList
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
    or createSliderPanel("SlackHacksGuildieListOpacityFrame", OPACITY or "Opacity", 0, 1, OPACITY_STEP, setOpacity)
  opacityPanel:Open(getSettings().opacity, "TOPLEFT", window, "TOPRIGHT", 0, 7)
end

--- Redraws the list wherever it's showing: this module's own window and the stacked Players Online window.
local function refresh()
  if window and window:IsVisible() then populate() end
  Self.InfoDisplay:RefreshPlayersOnline()
end

--- Saves the list's sort order and re-sorts the list wherever it's showing.
---@param sortBy string A SORT_COMPARATORS key: "name" or "zone".
local function setSortBy(sortBy)
  getSettings().sortBy = sortBy
  refresh()
end

--- Saves a display setting (e.g. an icon toggle) and redraws the list wherever it's showing.
---@param key string The `guildieList` setting to change.
---@param value any The new value.
local function setDisplaySetting(key, value)
  getSettings()[key] = value
  refresh()
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
---@param self Frame The Guildie List window.
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

--- Shows a player tooltip for the member, modeled on Blizzard's default unit tooltip for a player (name with
--- AFK/DND, guild, "Level N Race Class", faction, zone) plus the guild details from the Communities member list
--- tooltip (CommunitiesMemberListEntryMixin:OnEnter: rank, notes, mobile presence, Timerunning icon). The real
--- unit tooltip is built by the game client from a unit token (e.g. "target"), which a guild member elsewhere in
--- the world doesn't have, so the lines are assembled here from the roster and club data instead.
---@param owner Frame The hovered row the tooltip anchors to.
---@param member table Member entry built by buildMembers().
local function showMemberTooltip(owner, member)
  local club = member.clubInfo or {}
  local white = HIGHLIGHT_FONT_COLOR
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")

  local name = member.fullName
  if club.timerunningSeasonID and TimerunningUtil then name = TimerunningUtil.AddSmallIcon(name) end
  if member.status == 1 then
    name = name .. " " .. (CHAT_FLAG_AFK or "<AFK>")
  elseif member.status == 2 then
    name = name .. " " .. (CHAT_FLAG_DND or "<DND>")
  end
  local classColor = C_ClassColor.GetClassColor(member.classFile) or white
  GameTooltip:SetText(name, classColor:GetRGB())

  local guildName = GetGuildInfo("player")
  if guildName then GameTooltip:AddLine("<" .. guildName .. ">", white:GetRGB()) end
  if member.rankName then GameTooltip:AddLine(member.rankName) end

  local raceInfo = club.race and C_CreatureInfo.GetRaceInfo(club.race)
  if raceInfo then
    GameTooltip:AddLine(COMMUNITY_MEMBER_CHARACTER_INFO_FORMAT:format(member.level, raceInfo.raceName,
      member.className), white:GetRGB())
  else
    GameTooltip:AddLine(LEVEL .. " " .. member.level .. " " .. member.className, white:GetRGB())
  end

  if club.faction and FACTION_LABELS[club.faction] then
    GameTooltip:AddLine(FACTION_LABELS[club.faction], white:GetRGB())
  end

  if member.isMobile then
    GameTooltip:AddLine(COMMUNITIES_PRESENCE_MOBILE_CHAT, white:GetRGB())
  else
    GameTooltip:AddLine(member.zone, white:GetRGB())
  end

  if member.note and member.note ~= "" then
    GameTooltip:AddLine(COMMUNITY_MEMBER_NOTE_FORMAT:format(member.note), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
      NORMAL_FONT_COLOR.b, true)
  end
  -- The roster only returns officer notes to ranks allowed to read them.
  if member.officerNote and member.officerNote ~= "" and C_GuildInfo.CanViewOfficerNote() then
    GameTooltip:AddLine("Officer Note: " .. member.officerNote, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
      NORMAL_FONT_COLOR.b, true)
  end
  GameTooltip:Show()
end

--- Opens the member's context menu (Invite, Whisper, View Houses) with the same context data the Communities
--- guild roster passes for a guild member (CommunitiesMemberListMixin:OnClubMemberButtonClicked). Blizzard's
--- invite options hide themselves for mobile members and pick Invite, Suggest Invite or Request Invite.
---@param member table Member entry built by buildMembers().
local function openMemberMenu(member)
  GameTooltip:Hide()
  openPlayerMenu("SLACKHACKS_PLAYER", {
    name = member.fullName,
    guid = member.guid,
    isMobile = member.isMobile,
    isGuildMember = true,
  })
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

--- Sizes a row's name column for the list's current width: the name takes all the width the widest zone doesn't
--- need, so widening the window always widens the names. When the row is too narrow for both, the zone gives up
--- space first, keeping the name at least NAME_COLUMN_MIN_SHARE of the row (or its full measured width, if
--- smaller). Every row gets the same width, so the zones stay lined up in a column.
---@param row Frame A list row created by initRow().
local function layoutRow(row)
  -- Rows stretch to the ScrollBox's width, but a freshly bound row isn't anchored yet and reports a width of 0, so
  -- the ScrollBox's own width is used instead.
  local available = window.ScrollBox:GetWidth() - 2 * ROW_PADDING - COLUMN_GAP
  local width = math.max(available - zoneColumnWidth, math.min(nameColumnWidth, available * NAME_COLUMN_MIN_SHARE))
  -- A FontString width of 0 means "unbounded", which would stop the name truncating in a very narrow row.
  row.Name:SetWidth(math.max(width, 1))
end

--- ScrollBox element initializer; builds a row's two columns (name, zone) once and then binds it to a member.
---@param row Frame A pooled row frame from the ScrollBox.
---@param member table Member entry built by buildMembers().
local function initRow(row, member)
  if not row.Name then
    row.Name = createCell(row)
    row.Name:SetPoint("LEFT", ROW_PADDING, 0)
    row.Zone = createCell(row)
    row.Zone:SetPoint("LEFT", row.Name, "RIGHT", COLUMN_GAP, 0)
    row.Zone:SetPoint("RIGHT", -ROW_PADDING, 0)
    row:SetScript("OnEnter", function(self)
      onWindowEnter()
      showMemberTooltip(self, self.member)
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetMouseMotionEnabled(true)
    enableRowClicks(row, window, function(self) openMemberMenu(self.member) end)
  end
  -- Re-applied on every bind since populate() re-measures the columns.
  layoutRow(row)
  row.member = member
  row.Name:SetText(member.name)
  row.Zone:SetText(member.zoneText)
end

--- Returns the widest rendered width of a field across the member entries, measured in the rows' font.
---@param members table Member entries from populate().
---@param field string The entry field to measure ("name" or "zoneText").
---@return number width The widest width in whole pixels, plus one so rounding never truncates it (0 when empty).
local function measureWidest(members, field)
  local width = 0
  for _, member in ipairs(members) do
    window.Measure:SetText(member[field])
    width = math.max(width, window.Measure:GetUnboundedStringWidth())
  end
  return width > 0 and math.ceil(width) + 1 or 0
end

--- When the `fitToContent` setting is on, sizes the window to fit the title, the widest name and zone, and every
--- row. The height stops at MAX_FIT_HEIGHT, after which the list scrolls as usual, and the width at the screen's
--- width. The window is only moved when its new size would run off the screen.
---@param members table Member entries from populate().
local function fitToContent(members)
  if not getSettings().fitToContent then return end
  -- Show at least one empty row so a guildless/empty window doesn't collapse to just its header.
  local height = HEADER_HEIGHT + LIST_TOP_GAP + math.max(#members, 1) * ROW_HEIGHT + LIST_BOTTOM_INSET
  local scrollBarSpace = height > MAX_FIT_HEIGHT and SCROLL_BAR_SPACE or 0
  local listWidth = LIST_LEFT_INSET + ROW_PADDING + nameColumnWidth + COLUMN_GAP + zoneColumnWidth + ROW_PADDING
    + LIST_RIGHT_INSET + scrollBarSpace
  local titleWidth = window.Title:GetUnboundedStringWidth() + HEADER_BUTTONS_WIDTH

  -- Grow down and to the right from the window's current top-left corner, and only shift the window when the new
  -- size would push it past the right or bottom of the screen, so a window against an edge or in a corner
  -- stays fully on screen. Pinning the top-left also stops the window growing around its saved anchor (e.g.
  -- CENTER), which would make it drift as members come and go.
  local width = math.min(math.ceil(math.max(listWidth, titleWidth, MIN_WIDTH)), UIParent:GetWidth())
  local fitHeight = math.min(height, MAX_FIT_HEIGHT)
  local left, top = window:GetLeft(), window:GetTop()
  if left then
    local newLeft = math.max(math.min(left, UIParent:GetWidth() - width), 0)
    local newTop = math.min(math.max(top, fitHeight), UIParent:GetHeight())
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft, newTop)
    saveLayout()
  end
  window:SetSize(width, fitHeight)
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

--- Builds the sorted list of online members from the client's guild roster cache (GuildMembersOnline logic),
--- ordered by the saved `sortBy` setting. Shared by this window and the stacked Players Online window.
---@return table|nil members Member entries, or nil when the player isn't in a guild.
local function buildMembers()
  if not IsInGuild() then return nil end

  local settings = getSettings()
  local members = {}
  local icons = settings.showInstanceIcons and getInstanceIcons() or {}
  local showFaction = settings.showFactionIcons
  local playerFaction = UnitFactionGroup("player")
  local scannedClubInfo = false
  for i = 1, GetNumGuildMembers() do
    local name, rankName, _, level, className, zone, note, officerNote, online, status, classFile, _, _, isMobile, _,
      _, guid = GetGuildRosterInfo(i)
    if online and name then
      local shortName = name:match("[^%-]+") -- Strip the realm.
      local classColor = C_ClassColor.GetClassColor(classFile)
      local displayName = classColor and classColor:WrapTextInColorCode(shortName) or shortName
      if guid and memberClubInfo[guid] == nil and not scannedClubInfo then
        scanMemberClubInfo() -- At most once per refresh, even if several members are still unknown.
        scannedClubInfo = true
      end
      local clubInfo = guid and memberClubInfo[guid]
      local rankIcon = settings.showRankIcons and clubInfo and RANK_ICONS[clubInfo.role]
      if rankIcon then displayName = displayName .. " " .. rankIcon end
      local faction = clubInfo and clubInfo.faction
      if showFaction and faction and FACTION_ICONS[faction]
        and not (settings.factionIconsOppositeOnly and PLAYER_FACTION_GROUP[faction] == playerFaction) then
        displayName = displayName .. " " .. FACTION_ICONS[faction]
      end
      zone = zone or UNKNOWN
      local icon = icons[zone]
      members[#members + 1] = {
        name = displayName,
        sortName = shortName:lower(),
        zone = zone, -- Plain text for sorting; zoneText is what's displayed.
        zoneText = icon and (zone .. " " .. icon) or zone,
        -- Everything below is only for the tooltip and context menu.
        fullName = name,
        guid = guid,
        level = level,
        rankName = rankName,
        className = className,
        classFile = classFile,
        note = note,
        officerNote = officerNote,
        status = status,
        isMobile = isMobile,
        clubInfo = clubInfo,
      }
    end
  end
  table.sort(members, SORT_COMPARATORS[settings.sortBy] or SORT_COMPARATORS.name)
  return members
end

--- Redraws this module's window from buildMembers(). Assigned to the forward-declared local so refresh() can
--- call it.
function populate()
  local members = buildMembers()
  if not members then
    window.Title:SetText("No Guild")
    window.ScrollBox:SetDataProvider(CreateDataProvider())
    fitToContent({})
    return
  end

  nameColumnWidth = measureWidest(members, "name")
  zoneColumnWidth = measureWidest(members, "zoneText")
  window.Title:SetText("Guildies (" .. #members .. ")")
  window.ScrollBox:SetDataProvider(CreateDataProvider(members), ScrollBoxConstants.RetainScrollPosition)
  fitToContent(members)
end

--- Asks the server for fresh roster data; GUILD_ROSTER_UPDATE fires when it arrives.
--- The client throttles this request, so calling it on every show is cheap.
local function requestRoster()
  if IsInGuild() then C_GuildInfo.GuildRoster() end
end

--- Adds this list's own options to a menu: Sort By and the icon toggles. Shared by this window's cog and the
--- Guildies section cog in the stacked Players Online window.
---@param rootDescription table The menu description to add to.
local function addListOptions(rootDescription)
  rootDescription:CreateTitle("Sort By")
  for _, option in ipairs(SORT_OPTIONS) do
    rootDescription:CreateRadio(option.text,
      function(key) return (getSettings().sortBy or "name") == key end,
      setSortBy,
      option.key)
  end
  rootDescription:CreateDivider()
  rootDescription:CreateTitle("Icons")
  for _, toggle in ipairs({
    { key = "showInstanceIcons", text = "Instance Icons" },
    { key = "showRankIcons", text = "Rank Icons" },
    { key = "showFactionIcons", text = "Faction Icons" },
    { key = "factionIconsOppositeOnly", text = "Opposite Faction Only", requires = "showFactionIcons" },
  }) do
    local checkbox = rootDescription:CreateCheckbox(toggle.text,
      function() return getSettings()[toggle.key] end,
      function() setDisplaySetting(toggle.key, not getSettings()[toggle.key]) end)
    if toggle.requires then
      checkbox:SetEnabled(function() return getSettings()[toggle.requires] end)
    end
  end
end

--- Fills the header cog's settings menu, the Lua equivalent of the DamageMeter's SettingsDropdown menu.
---@param _ Frame The cog button (unused).
---@param rootDescription table The menu's root description.
local function buildSettingsMenu(_, rootDescription)
  rootDescription:SetTag(SETTINGS_MENU_TAG)
  rootDescription:CreateCheckbox("Fit to Content",
    function() return getSettings().fitToContent end,
    function() setFitToContent(not getSettings().fitToContent) end)
  rootDescription:CreateButton(BATTLEFIELDMINIMAP_OPACITY_LABEL or "Change Opacity", showOpacityPanel)
  Self.InfoDisplay:AddStackMenuButton(rootDescription)
  rootDescription:CreateDivider()
  addListOptions(rootDescription)
end

--- Builds the window, following DamageMeterSessionWindowTemplate: a Header bar holding the title,
--- SettingsDropdown and MinimizeButton, plus a MinimizeContainer (background, scroll list, resize handle) that
--- is hidden when minimized.
local function createWindow()
  window = CreateFrame("Frame", "SlackHacksGuildieList", UIParent)
  window:Hide() -- New frames start shown; hiding lets OnEnable's Show() fire OnShow for the first populate.
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

  local settingsDropdown = createSettingsCog(window, buildSettingsMenu)
  settingsDropdown:SetPoint("RIGHT", minimizeButton, "LEFT", -2, -2)
  window.SettingsDropdown = settingsDropdown

  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  title:SetPoint("TOPLEFT", header, "TOPLEFT", 8, -9)
  title:SetPoint("RIGHT", settingsDropdown, "LEFT", -4, 0)
  window.Title = title

  -- Invisible text used to measure name/zone text in the same font as the list's columns. It's anchored and shown
  -- (at zero alpha) rather than hidden, so inline icons are laid out like the rows'.
  local measure = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  measure:SetPoint("TOPLEFT")
  measure:SetAlpha(0)
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
  -- Re-split the columns of every visible row whenever the list changes width (window resizes and the scroll bar
  -- showing or hiding). Hooked, since the ScrollBox uses its own OnSizeChanged to re-layout.
  scrollBox:HookScript("OnSizeChanged", function(self) self:ForEachFrame(layoutRow) end)

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
    -- Let the window grow up to the whole screen, measured now since the UI scale or resolution can change.
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
end

--- Turns the Guildie List on or off and saves the choice.
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

--- Saves an icon/display toggle and redraws the list (used by the options panel).
---@param key string "showInstanceIcons", "showRankIcons", "showFactionIcons" or "factionIconsOppositeOnly".
---@param value boolean The new value.
function module:SetDisplaySetting(key, value)
  setDisplaySetting(key, value)
end

--- Returns the online members for the stacked Players Online window.
---@return table members Sorted member entries (empty when the player isn't in a guild).
---@return string|nil unavailableTitle "No Guild" when there's no roster to show, otherwise nil.
function module:GetEntries()
  local members = buildMembers()
  if not members then return {}, "No Guild" end
  return members
end

--- Shows a member's tooltip (used by the stacked Players Online window's rows).
---@param owner Frame The row the tooltip anchors to.
---@param member table A member entry from GetEntries().
function module:ShowTooltip(owner, member)
  showMemberTooltip(owner, member)
end

--- Opens a member's context menu (used by the stacked Players Online window's rows).
---@param member table A member entry from GetEntries().
function module:OpenMenu(member)
  openMemberMenu(member)
end

--- Adds this list's Sort By and icon options to a menu (used by the Players Online window's Guildies section cog).
---@param rootDescription table The menu description to add to.
function module:AddListOptions(rootDescription)
  addListOptions(rootDescription)
end

--- Asks the server for fresh roster data (used when the stacked Players Online window is shown).
function module:RequestRoster()
  requestRoster()
end

--- Shows this module's own window unless the list is stacked into the Players Online window, in which case the
--- window (and its opacity panel) stay hidden while the module keeps listening for roster changes.
function module:UpdateWindowShown()
  if not window then return end
  local stacked = Self.InfoDisplay:IsPlayersOnlineStacked()
  window:SetShown(not stacked)
  if stacked and opacityPanel then opacityPanel:Hide() end
end

--- AceAddon initialization hook; keeps the module disabled when turned off or outside Retail and Forever, since
--- the DamageMeter atlases and ScrollBox templates the window relies on only exist there.
function module:OnInitialize()
  if not getSettings().enabled or not isRetailOrForever() then self:Disable() end
end

--- Shows the window (creating it on first use) and listens for roster changes.
function module:OnEnable()
  -- Addon-wide re-enables (e.g. profile reset) enable every module, so re-check the saved setting.
  if not getSettings().enabled or not isRetailOrForever() then
    self:SetEnabledState(false)
    return
  end
  if not window then createWindow() end
  applyLayout()
  setMinimized(getSettings().minimized)
  setOpacity(getSettings().opacity)
  setFitToContent(getSettings().fitToContent) -- Window is still hidden, so the fit itself happens in OnShow.
  self:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(ROSTER_REQUEST_DELAY, requestRoster) end)
  self:RegisterEvent("GUILD_ROSTER_UPDATE", refresh)
  self:UpdateWindowShown()
  Self.InfoDisplay:RefreshPlayersOnline()
end

--- Stops listening for roster changes, hides the window and its opacity panel, and drops the Guildies section
--- from the stacked Players Online window.
function module:OnDisable()
  self:UnregisterAllEvents()
  if window then window:Hide() end
  if opacityPanel then opacityPanel:Hide() end
  Self.InfoDisplay:RefreshPlayersOnline()
end
