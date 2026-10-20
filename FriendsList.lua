setfenv(1, _G.SlackHacks)

-- Friends List: a movable, resizable, collapsible list of online friends.
-- A copy of the Guildie List window (GuildieList.lua) fed by the FriendsFrame's friends list instead
-- of the guild roster: Battle.net friends (C_BattleNet) plus character-only WoW friends (C_FriendList), filtered
-- by the "Only Favorite Friends", "Only Playing WoW" and "Only Same WoW Version" settings. Favorites are a
-- Battle.net-only feature (accountInfo.isFavorite), so character friends only appear when that filter is off.
-- Battle.net rows show the Battle.net name with the class-colored character name (like Blizzard_FriendsFrame's
-- FriendsFrame_GetBNetAccountNameAndStatus) and their location, with optional game, faction and instance icons
-- and a tooltip modeled on the FriendsFrame's (FriendsListButtonMixin:OnEnter). Left- or right-clicking a friend
-- opens a context menu with Invite, Whisper and View Houses.
-- The window recreates Blizzard's DamageMeterSessionWindowTemplate
-- (Blizzard_DamageMeter/DamageMeterSessionWindow.xml) in Lua, including its MinimizeButton, which collapses the
-- window down to its header bar, and its SettingsDropdown cog menu.
local module = Self:NewModule("FriendsList", "AceEvent-3.0")
Self.FriendsList = module

local HEADER_HEIGHT = 32 -- Explicit header height from the Blizzard template so the scroll box can anchor to it.
local ROW_HEIGHT = 18
-- When a row is too narrow for both columns, the name column keeps at least this share of the row (or its full
-- width, if smaller) and the location column is truncated first.
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
local ICON_SIZE = 12
-- Inline icons from the world map's pins (delves-regular is the Map Legend's delve icon).
local INSTANCE_ICONS = {
  dungeon = CreateAtlasMarkup("Dungeon", ICON_SIZE, ICON_SIZE),
  raid = CreateAtlasMarkup("Raid", ICON_SIZE, ICON_SIZE),
  delve = CreateAtlasMarkup("delves-regular", ICON_SIZE, ICON_SIZE),
}
-- Inline faction icons keyed by faction group. Same quest log atlases as the Guildie List.
local FACTION_ICONS = {
  Horde = CreateAtlasMarkup("questlog-questtypeicon-horde", ICON_SIZE, ICON_SIZE),
  Alliance = CreateAtlasMarkup("questlog-questtypeicon-alliance", ICON_SIZE, ICON_SIZE),
}
-- Battle.net region names for friends in another region, copied from FriendsFrame.lua's local regionNames.
local REGION_NAMES = {
  [1] = NORTH_AMERICA,
  [2] = KOREA,
  [3] = EUROPE,
  [4] = TAIWAN,
  [5] = CHINA,
}
-- Character friends sort after Battle.net friends in the "name" (friends list) order, like the FriendsFrame.
local CHARACTER_FRIEND_SORT_OFFSET = 10000
local OPACITY_STEP = 0.05
local SCROLL_BAR_IDLE_ALPHA = 0.3 -- The scroll bar is dimmed until the window is hovered, like the DamageMeter.
local FADE_DURATION = 0.25
-- BN_FRIEND_INFO_CHANGED fires for every friend's zone/status change, so refreshes are batched to at most one
-- per this many seconds.
local REFRESH_DELAY = 0.2
local SETTINGS_MENU_TAG = "MENU_SLACKHACKS_FRIENDS_LIST_SETTINGS"

-- Sort choices in menu order; `key` is the saved `sortBy` value.
local SORT_OPTIONS = {
  { key = "name", text = "Name" },
  { key = "zone", text = "Location" },
}
-- Comparators for table.sort, keyed by `sortBy`. Battle.net names are protected strings ("|K...|k") that only
-- render as names, so Lua can't compare them; "name" keeps the client's own friend list order instead (the
-- FriendsFrame's order), which also breaks location ties so the order is stable across refreshes.
local SORT_COMPARATORS = {
  name = function(a, b) return a.sortIndex < b.sortIndex end,
  zone = function(a, b)
    if a.zone ~= b.zone then return a.zone < b.zone end
    return a.sortIndex < b.sortIndex
  end,
}

local window
local opacityPanel
local populate
local instanceIcons -- Zone name -> inline icon markup; built once by getInstanceIcons().
-- Untruncated widths of the widest name and location, measured by populate().
local nameColumnWidth, zoneColumnWidth = 0, 0
local refreshPending = false

--- Returns a lookup from instance name to its inline Dungeon/Raid/Delve icon, built once from local game data
--- (the Encounter Journal), so it costs no server requests.
--- Friends' locations are only reported as text, with no instance flag, but inside a dungeon or raid that text
--- is the instance's name, which is also how the journal names it.
---@return table icons Instance name -> CreateAtlasMarkup() string (empty until journal data is available).
local function getInstanceIcons()
  if instanceIcons then return instanceIcons end
  local icons = {}
  local numTiers = EJ_GetNumTiers and EJ_GetNumTiers() or 0
  if numTiers == 0 then return icons end -- Journal data isn't loaded yet; try again on the next populate.
  -- Every delve's location is reported as just "Delves" rather than the delve's name, and delves aren't in the
  -- journal. Hard-coded English, so this won't match on other client languages.
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
---@return table settings The `infoDisplay.friendsList` profile table.
local function getSettings()
  return db.profile.infoDisplay.friendsList
end

--- Saves and applies the background opacity. Like the DamageMeter's "Background Transparency" Edit Mode
--- setting, this only fades the background texture, so the header and the friend names stay fully readable.
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
    or createSliderPanel("SlackHacksFriendsListOpacityFrame", OPACITY or "Opacity", 0, 1, OPACITY_STEP, setOpacity)
  opacityPanel:Open(getSettings().opacity, "TOPLEFT", window, "TOPRIGHT", 0, 7)
end

--- Redraws the list wherever it's showing: this module's own window and the stacked Players Online window.
local function refresh()
  refreshPending = false
  if window and window:IsVisible() then populate() end
  Self.InfoDisplay:RefreshPlayersOnline()
end

--- Saves the list's sort order and re-sorts the list wherever it's showing.
---@param sortBy string A SORT_COMPARATORS key: "name" or "zone".
local function setSortBy(sortBy)
  getSettings().sortBy = sortBy
  refresh()
end

--- Saves a display or filter setting (e.g. an icon toggle) and redraws the list wherever it's showing.
---@param key string The `friendsList` setting to change.
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
---@param self Frame The friends list window.
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

--- Adds the friend's AFK/DND flag to a name, like the default unit tooltip.
---@param name string The name to append to.
---@param status number 0 = available, 1 = AFK, 2 = DND.
---@return string name The name with any flag appended.
local function addStatusFlag(name, status)
  if status == 1 then return name .. " " .. (CHAT_FLAG_AFK or "<AFK>") end
  if status == 2 then return name .. " " .. (CHAT_FLAG_DND or "<DND>") end
  return name
end

--- Adds a white tooltip line naming a faction group ("Horde"/"Alliance"), if known.
---@param factionGroup string|nil The faction group.
local function addFactionLine(factionGroup)
  local faction = PLAYER_FACTION_GROUP[factionGroup]
  if faction and FACTION_LABELS[faction] then GameTooltip:AddLine(FACTION_LABELS[faction], 1, 1, 1) end
end

--- Shows the friend's tooltip, modeled on the FriendsFrame's (FriendsListButtonMixin:OnEnter).
--- Battle.net friends: Battle.net name with AFK/DND, then for a WoW character in this game version
--- "Name, Level N Race Class", faction and "zone - realm" (or region), otherwise their character/game name and
--- rich presence (e.g. "In Menus"), followed by the friend's note and broadcast message.
--- Character friends: name with AFK/DND, "Level N Race Class", faction, zone and note.
---@param owner Frame The hovered row the tooltip anchors to.
---@param friend table Friend entry built by buildFriends().
local function showFriendTooltip(owner, friend)
  local white = HIGHLIGHT_FONT_COLOR
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")

  local account = friend.accountInfo
  if account then
    local game = account.gameAccountInfo
    GameTooltip:SetText(addStatusFlag(BNet_GetBNetAccountName(account), friend.status),
      FRIENDS_BNET_NAME_COLOR:GetRGB())
    if friend.inThisGame then
      local character = FRIENDS_TOOLTIP_WOW_TOON_TEMPLATE:format(game.characterName or UNKNOWN,
        game.characterLevel or 0, game.raceName or UNKNOWN, game.className or UNKNOWN)
      if game.timerunningSeasonID and TimerunningUtil then character = TimerunningUtil.AddSmallIcon(character) end
      GameTooltip:AddLine(character, (friend.classColor or white):GetRGB())
      addFactionLine(game.factionName)
      if game.isInCurrentRegion then
        GameTooltip:AddLine(BNET_FRIEND_TOOLTIP_ZONE_AND_REALM:format(friend.zone, game.realmDisplayName or UNKNOWN),
          white:GetRGB())
      else
        GameTooltip:AddLine(BNET_FRIEND_TOOLTIP_ZONE_AND_REGION:format(friend.zone,
          REGION_NAMES[game.regionID] or UNKNOWN), white:GetRGB())
      end
    else
      GameTooltip:AddLine(BNet_GetValidatedCharacterName(game.characterName, account.battleTag, game.clientProgram),
        white:GetRGB())
      GameTooltip:AddLine(friend.zone, white:GetRGB())
    end
  else
    local info = friend.friendInfo
    GameTooltip:SetText(addStatusFlag(info.name, friend.status), (friend.classColor or white):GetRGB())
    if friend.raceName then
      GameTooltip:AddLine(COMMUNITY_MEMBER_CHARACTER_INFO_FORMAT:format(info.level, friend.raceName,
        info.className or UNKNOWN), white:GetRGB())
    else
      GameTooltip:AddLine(FRIENDS_LEVEL_TEMPLATE:format(info.level, info.className or UNKNOWN), white:GetRGB())
    end
    -- Character friends are always on the player's faction (cross-faction friends need Battle.net).
    addFactionLine(friend.factionGroup)
    GameTooltip:AddLine(friend.zone, white:GetRGB())
  end

  local note = account and account.note or (friend.friendInfo and friend.friendInfo.notes)
  if note and note ~= "" then
    GameTooltip:AddLine(COMMUNITY_MEMBER_NOTE_FORMAT:format(note), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
      NORMAL_FONT_COLOR.b, true)
  end
  if account and account.customMessage and account.customMessage ~= "" then
    GameTooltip:AddLine(account.customMessage, FRIENDS_BNET_NAME_COLOR.r, FRIENDS_BNET_NAME_COLOR.g,
      FRIENDS_BNET_NAME_COLOR.b, true)
  end
  GameTooltip:Show()
end

--- Opens the friend's context menu (Invite, Whisper, View Houses) with the same context data the FriendsFrame
--- passes (FriendsFrame_ShowBNDropdown / FriendsFrame_ShowDropdown). Battle.net friends who can't be grouped
--- with, e.g. because they're in another game or WoW version, get a menu without the invite buttons.
---@param friend table Friend entry built by buildFriends().
local function openFriendMenu(friend)
  local account, info = friend.accountInfo, friend.friendInfo
  GameTooltip:Hide()
  if account then
    local canInvite = CanGroupWithAccount(account.bnetAccountID)
    openPlayerMenu(canInvite and "SLACKHACKS_BN_FRIEND" or "SLACKHACKS_BN_FRIEND_NO_INVITE", {
      name = account.accountName,
      bnetIDAccount = account.bnetAccountID,
      battleTag = account.battleTag,
    })
  else
    openPlayerMenu("SLACKHACKS_PLAYER", { name = info.name, guid = info.guid })
  end
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

--- Sizes a row's name column for the list's current width: the name takes all the width the widest location
--- doesn't need, so widening the window always widens the names. When the row is too narrow for both, the location
--- gives up space first, keeping the name at least NAME_COLUMN_MIN_SHARE of the row (or its full measured width,
--- if smaller). Every row gets the same width, so the locations stay lined up in a column.
---@param row Frame A list row created by initRow().
local function layoutRow(row)
  -- Rows stretch to the ScrollBox's width, but a freshly bound row isn't anchored yet and reports a width of 0, so
  -- the ScrollBox's own width is used instead.
  local available = window.ScrollBox:GetWidth() - 2 * ROW_PADDING - COLUMN_GAP
  local width = math.max(available - zoneColumnWidth, math.min(nameColumnWidth, available * NAME_COLUMN_MIN_SHARE))
  -- A FontString width of 0 means "unbounded", which would stop the name truncating in a very narrow row.
  row.Name:SetWidth(math.max(width, 1))
end

--- ScrollBox element initializer; builds a row's two columns (name, location) once and then binds it to a friend.
---@param row Frame A pooled row frame from the ScrollBox.
---@param friend table Friend entry built by buildFriends().
local function initRow(row, friend)
  -- Restore pooled input state before binding, so newly initialized handlers become the restoration baseline.
  setListMouseInteraction(row, false)
  if not row.Name then
    row.Name = createCell(row)
    row.Name:SetPoint("LEFT", ROW_PADDING, 0)
    row.Zone = createCell(row)
    row.Zone:SetPoint("LEFT", row.Name, "RIGHT", COLUMN_GAP, 0)
    row.Zone:SetPoint("RIGHT", -ROW_PADDING, 0)
    row:SetScript("OnEnter", function(self)
      onWindowEnter()
      showFriendTooltip(self, self.friend)
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetMouseMotionEnabled(true)
    enableRowClicks(row, window, function(self) openFriendMenu(self.friend) end)
  end
  -- Re-applied on every bind since populate() re-measures the columns.
  layoutRow(row)
  row.friend = friend
  row.Name:SetText(friend.name)
  row.Zone:SetText(friend.zoneText)
  -- ScrollBox can initialize pooled rows after populate() returns, including while click-through is on.
  setListMouseInteraction(row, getSettings().nonInteractive)
end

--- Returns the widest rendered width of a field across the friend entries, measured in the rows' font. Names are
--- measured both as displayed and as their `measureName` stand-in, since protected Battle.net names measure short.
---@param friends table Friend entries from populate().
---@param field string The entry field to measure ("name" or "zoneText").
---@return number width The widest width in whole pixels, plus one so rounding never truncates it (0 when empty).
local function measureWidest(friends, field)
  local width = 0
  for _, friend in ipairs(friends) do
    window.Measure:SetText(friend[field])
    width = math.max(width, window.Measure:GetUnboundedStringWidth())
    if field == "name" and friend.measureName then
      window.Measure:SetText(friend.measureName)
      width = math.max(width, window.Measure:GetUnboundedStringWidth())
    end
  end
  return width > 0 and math.ceil(width) + 1 or 0
end

--- When the `fitToContent` setting is on, sizes the window to fit the title, the widest name and location, and
--- every row. The height stops at MAX_FIT_HEIGHT, after which the list scrolls as usual, and the width at the
--- screen's width. The window is only moved when its new size would run off the screen.
---@param friends table Friend entries from populate().
local function fitToContent(friends)
  if not getSettings().fitToContent then return end
  -- Show at least one empty row so an empty window doesn't collapse to just its header.
  local height = HEADER_HEIGHT + LIST_TOP_GAP + math.max(#friends, 1) * ROW_HEIGHT + LIST_BOTTOM_INSET
  local scrollBarSpace = height > MAX_FIT_HEIGHT and SCROLL_BAR_SPACE or 0
  local listWidth = LIST_LEFT_INSET + ROW_PADDING + nameColumnWidth + COLUMN_GAP + zoneColumnWidth + ROW_PADDING
    + LIST_RIGHT_INSET + scrollBarSpace
  local titleWidth = window.Title:GetUnboundedStringWidth() + HEADER_BUTTONS_WIDTH

  -- Grow down and to the right from the window's current top-left corner, and only shift the window when the new
  -- size would push it past the right or bottom of the screen, so a window against an edge or in a corner
  -- stays fully on screen. Pinning the top-left also stops the window growing around its saved anchor (e.g.
  -- CENTER), which would make it drift as friends come and go.
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

--- Appends the enabled faction icon to a name, honoring the "opposite faction only" setting.
---@param name string The name text.
---@param factionGroup string|nil The friend's faction group ("Horde"/"Alliance").
---@param settings table This module's saved settings.
---@param playerFaction string|nil The player's faction group.
---@return string name The name with any faction icon appended.
local function addFactionIcon(name, factionGroup, settings, playerFaction)
  local icon = settings.showFactionIcons and FACTION_ICONS[factionGroup]
  if icon and not (settings.factionIconsOppositeOnly and factionGroup == playerFaction) then
    return name .. " " .. icon
  end
  return name
end

--- Returns the location text and instance icon for an entry: a zone with its instance icon when available.
---@param zone string|nil The reported zone or rich presence text.
---@param icons table Instance name -> icon markup (empty when instance icons are off).
---@return string zone Plain location text, for sorting.
---@return string zoneText Location text with any instance icon, for display.
local function formatZone(zone, icons)
  if not zone or zone == "" then zone = UNKNOWN end
  local icon = icons[zone]
  return zone, icon and (zone .. " " .. icon) or zone
end

--- Builds a Battle.net friend's name column text the way the FriendsFrame does
--- (FriendsFrame_GetBNetAccountNameAndStatus): the Battle.net name, then the WoW character's name in parentheses
--- (class-colored here), then the enabled game and faction icons. The game icon is left off for friends in the
--- same game and WoW version as the player, so it only marks friends somewhere else (including other WoW versions).
---@param account table The friend's BNetAccountInfo.
---@param classColor ColorMixin|nil The WoW character's class color, if they're on a WoW character.
---@param settings table This module's saved settings.
---@param playerFaction string|nil The player's faction group ("Horde"/"Alliance").
---@return string name The display text.
---@return string measureName The same text with the protected Battle.net name swapped for the plain BattleTag,
---for measuring the column width.
local function formatAccountName(account, classColor, settings, playerFaction)
  local game = account.gameAccountInfo
  local isWoW = game.clientProgram == BNET_CLIENT_WOW
  local suffix = ""
  if isWoW and game.characterName and game.characterName ~= "" then
    local characterName = classColor and classColor:WrapTextInColorCode(game.characterName) or game.characterName
    suffix = " (" .. characterName .. ")"
  end
  if settings.showGameIcons and not (isWoW and game.wowProjectID == WOW_PROJECT_ID) then
    suffix = suffix .. " " .. BNet_GetClientEmbeddedAtlas(game.clientProgram, ICON_SIZE, ICON_SIZE)
  end
  if isWoW then
    suffix = addFactionIcon(suffix, game.factionName, settings, playerFaction)
    if settings.showGroupIcons then suffix = addGroupIcon(suffix, game.playerGuid) end
  end
  -- The account name is a protected "|K...|k" string that only the renderer can resolve, and string width
  -- measurement doesn't see the resolved name, so the window was sized as if it were much shorter. The BattleTag
  -- is a plain string with the same name for BattleTag friends (a Real ID name may still differ).
  local battleTag = BNet_GetTruncatedBattleTag(account.battleTag)
  return FRIENDS_BNET_NAME_COLOR:WrapTextInColorCode(BNet_GetBNetAccountName(account)) .. suffix,
    FRIENDS_BNET_NAME_COLOR:WrapTextInColorCode(battleTag) .. suffix
end

--- Returns 0, 1 or 2 for available, AFK or DND.
---@param isAFK boolean|nil Whether the friend is AFK.
---@param isDND boolean|nil Whether the friend is DND/busy.
---@return number status The status code used by addStatusFlag.
local function getStatus(isAFK, isDND)
  return isAFK and 1 or isDND and 2 or 0
end

--- Adds the online Battle.net friends that pass the filter settings to `friends`.
---@param friends table Entry list to append to.
---@param settings table This module's saved settings.
---@param icons table Instance name -> icon markup.
---@param playerFaction string|nil The player's faction group.
local function addAccountFriends(friends, settings, icons, playerFaction)
  -- The client lists online friends first, so only those indexes need checking.
  local _, numOnline = BNGetNumFriends()
  for i = 1, numOnline do
    local account = C_BattleNet.GetFriendAccountInfo(i)
    local game = account and account.gameAccountInfo
    local isWoW = game and game.clientProgram == BNET_CLIENT_WOW
    local isThisVersion = isWoW and game.wowProjectID == WOW_PROJECT_ID
    if game and game.isOnline and (account.isFavorite or not settings.onlyFavorites)
      and (isWoW or not settings.onlyWoW)
      and (isThisVersion or not (settings.onlyWoW and settings.onlySameWoWVersion)) then
      -- Like the FriendsFrame (ShowRichPresenceOnly), only a WoW character in this game version (e.g. not
      -- Classic) has a real zone; everything else shows rich presence such as "In Menus" or the game mode.
      local inThisGame = isThisVersion and game.areaName ~= nil and game.areaName ~= ""
      local zone, zoneText = formatZone(inThisGame and game.areaName or game.richPresence, inThisGame and icons or {})
      local classInfo = isWoW and game.classID and C_CreatureInfo.GetClassInfo(game.classID)
      local classColor = classInfo and C_ClassColor.GetClassColor(classInfo.classFile)
      local name, measureName = formatAccountName(account, classColor, settings, playerFaction)
      friends[#friends + 1] = {
        name = name,
        measureName = measureName, -- Measurable stand-in for `name`; see formatAccountName.
        sortIndex = i,
        zone = zone, -- Plain text for sorting; zoneText is what's displayed.
        zoneText = zoneText,
        -- Everything below is only for the tooltip.
        accountInfo = account,
        inThisGame = inThisGame,
        classColor = classColor,
        status = getStatus(account.isAFK or game.isGameAFK, account.isDND or game.isGameBusy),
      }
    end
  end
end

--- Adds online character-only WoW friends (the FriendsFrame's non-Battle.net entries) to `friends`. They can't
--- be favorites and are always in this WoW version, so they're skipped only by the favorites filter.
---@param friends table Entry list to append to.
---@param settings table This module's saved settings.
---@param icons table Instance name -> icon markup.
---@param playerFaction string|nil The player's faction group.
local function addCharacterFriends(friends, settings, icons, playerFaction)
  if settings.onlyFavorites then return end
  -- Like Battle.net friends, online character friends are listed first.
  for i = 1, C_FriendList.GetNumOnlineFriends() do
    local info = C_FriendList.GetFriendInfoByIndex(i)
    if info and info.connected then
      -- The friend list has no race or class token, but the GUID's cached player info does. (Not written as
      -- `guid and GetPlayerInfoByGUID(guid)`, since `and` would keep only the first return value.)
      local _, classFile, raceName
      if info.guid then _, classFile, _, raceName = GetPlayerInfoByGUID(info.guid) end
      local classColor = classFile and C_ClassColor.GetClassColor(classFile)
      local shortName = info.name:match("[^%-]+") -- Strip the realm.
      local name = addFactionIcon(classColor and classColor:WrapTextInColorCode(shortName) or shortName,
        playerFaction, settings, playerFaction)
      if settings.showGroupIcons then name = addGroupIcon(name, info.guid) end
      -- No game icon: character friends are always in this game and WoW version.
      local zone, zoneText = formatZone(info.area, icons)
      friends[#friends + 1] = {
        name = name,
        sortIndex = CHARACTER_FRIEND_SORT_OFFSET + i,
        zone = zone,
        zoneText = zoneText,
        friendInfo = info,
        classColor = classColor,
        raceName = raceName,
        factionGroup = playerFaction,
        status = getStatus(info.afk, info.dnd),
      }
    end
  end
end

--- Builds the list of online friends from the client's friend lists (no server request), filtered and sorted by
--- the saved settings. Shared by this window and the stacked Players Online window.
---@return table friends Friend entries.
local function buildFriends()
  local settings = getSettings()
  local friends = {}
  local icons = settings.showInstanceIcons and getInstanceIcons() or {}
  local playerFaction = UnitFactionGroup("player")
  if BNConnected() then addAccountFriends(friends, settings, icons, playerFaction) end
  addCharacterFriends(friends, settings, icons, playerFaction)
  table.sort(friends, SORT_COMPARATORS[settings.sortBy] or SORT_COMPARATORS.name)
  return friends
end

--- Returns the list's title when it has no count to show, e.g. while favorites can't be read without Battle.net.
---@return string|nil title The replacement title, or nil to show the friend count.
local function getUnavailableTitle()
  if getSettings().onlyFavorites and not BNConnected() then
    return BATTLENET_UNAVAILABLE or "Battle.net Unavailable"
  end
end

--- Redraws this module's window from buildFriends(). Assigned to the forward-declared local so refresh() can
--- call it.
function populate()
  local friends = buildFriends()
  nameColumnWidth = measureWidest(friends, "name")
  zoneColumnWidth = measureWidest(friends, "zoneText")
  window.Title:SetText(getUnavailableTitle() or ("Friends (" .. #friends .. ")"))
  window.ScrollBox:SetDataProvider(CreateDataProvider(friends), ScrollBoxConstants.RetainScrollPosition)
  fitToContent(friends)
  applyListWindowInteraction(window, getSettings())
end

--- Queues a refresh() for REFRESH_DELAY seconds from now, so a burst of friend events causes one refresh. Runs
--- even while this module's own window is hidden, since the list may be showing in the Players Online window.
local function scheduleRefresh()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(REFRESH_DELAY, function()
    if refreshPending then refresh() end
  end)
end

--- Adds a titled group of setting checkboxes to the settings menu; `requires` names a setting that must be on
--- to enable one.
---@param rootDescription table The menu's root description.
---@param title string The group's title.
---@param toggles table List of { key, text, requires? }.
local function addCheckboxes(rootDescription, title, toggles)
  rootDescription:CreateDivider()
  rootDescription:CreateTitle(title)
  for _, toggle in ipairs(toggles) do
    local checkbox = rootDescription:CreateCheckbox(toggle.text,
      function() return getSettings()[toggle.key] end,
      function() setDisplaySetting(toggle.key, not getSettings()[toggle.key]) end)
    if toggle.requires then
      checkbox:SetEnabled(function() return getSettings()[toggle.requires] end)
    end
  end
end

--- Adds this list's own options to a menu: Sort By plus the Show filters and icon toggles. Shared by this window's
--- cog and the Friends section cog in the stacked Players Online window.
---@param rootDescription table The menu description to add to.
local function addListOptions(rootDescription)
  rootDescription:CreateTitle("Sort By")
  for _, option in ipairs(SORT_OPTIONS) do
    rootDescription:CreateRadio(option.text,
      function(key) return (getSettings().sortBy or "name") == key end,
      setSortBy,
      option.key)
  end
  addCheckboxes(rootDescription, "Show", {
    { key = "onlyFavorites", text = "Only Favorite Friends" },
    { key = "onlyWoW", text = "Only Playing WoW" },
    { key = "onlySameWoWVersion", text = "Only Same WoW Version", requires = "onlyWoW" },
  })
  addCheckboxes(rootDescription, "Icons", {
    { key = "showInstanceIcons", text = "Instance Icons" },
    { key = "showGameIcons", text = "Game Icons" },
    { key = "showFactionIcons", text = "Faction Icons" },
    { key = "factionIconsOppositeOnly", text = "Opposite Faction Only", requires = "showFactionIcons" },
    { key = "showGroupIcons", text = "In-Group Indicator" },
  })
end

--- Fills the header cog's settings menu, the Lua equivalent of the DamageMeter's SettingsDropdown menu.
---@param _ Frame The cog button (unused).
---@param rootDescription table The menu's root description.
local function buildSettingsMenu(_, rootDescription)
  rootDescription:SetTag(SETTINGS_MENU_TAG)
  Self.InfoDisplay:AddListWindowOptions(rootDescription, "friendsList")
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
  window = CreateFrame("Frame", "SlackHacksFriendsList", UIParent)
  window:Hide() -- New frames start shown; hiding lets OnEnable's Show() fire OnShow for the first populate.
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
    -- Character friends' zones/status only update after the server sends the list (FRIENDLIST_UPDATE). The
    -- FriendsFrame asks for it the same way when shown; Battle.net friends update on their own.
    C_FriendList.ShowFriends()
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

  -- Invisible text used to measure name/location text in the same font as the list's columns. It's anchored and
  -- shown (at zero alpha) rather than hidden, so inline icons and Battle.net names are laid out like the rows'.
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

--- Turns the Friends List on or off and saves the choice. Also used by the Players Online cog and minimap menus,
--- so the options panel is told to redraw, and stacking is turned off once neither list is left to stack.
---@param enabled boolean Whether the window should be shown.
function module:SetEnabled(enabled)
  getSettings().enabled = enabled
  if enabled then self:Enable() else self:Disable() end
  Self.InfoDisplay:OnListEnabledChanged()
end

--- Applies the standalone window's interaction settings, if it has been created.
function module:RefreshWindowInteraction()
  if window then applyListWindowInteraction(window, getSettings()) end
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

--- Saves a filter or icon toggle and redraws the list (used by the options panel).
---@param key string "onlyFavorites", "onlyWoW", "onlySameWoWVersion", "showInstanceIcons", "showGameIcons",
--- "showFactionIcons", "factionIconsOppositeOnly" or "showGroupIcons".
---@param value boolean The new value.
function module:SetDisplaySetting(key, value)
  setDisplaySetting(key, value)
end

--- Returns the online friends for the stacked Players Online window.
---@return table friends Filtered, sorted friend entries.
---@return string|nil unavailableTitle A title to show instead of the count (e.g. "Battle.net Unavailable").
function module:GetEntries()
  return buildFriends(), getUnavailableTitle()
end

--- Shows a friend's tooltip (used by the stacked Players Online window's rows).
---@param owner Frame The row the tooltip anchors to.
---@param friend table A friend entry from GetEntries().
function module:ShowTooltip(owner, friend)
  showFriendTooltip(owner, friend)
end

--- Opens a friend's context menu (used by the stacked Players Online window's rows).
---@param friend table A friend entry from GetEntries().
function module:OpenMenu(friend)
  openFriendMenu(friend)
end

--- Adds this list's Sort By, Show and icon options to a menu (used by the Players Online window's Friends section
--- cog).
---@param rootDescription table The menu description to add to.
function module:AddListOptions(rootDescription)
  addListOptions(rootDescription)
end

--- Asks the server for character friends' latest zones/status (used when the Players Online window is shown).
function module:RequestFriends()
  C_FriendList.ShowFriends()
end

--- Shows this module's own window unless the list is stacked into the Players Online window, in which case the
--- window (and its opacity panel) stay hidden while the module keeps listening for friend changes.
function module:UpdateWindowShown()
  if not window then return end
  local stacked = Self.InfoDisplay:IsPlayersOnlineStacked()
  window:SetShown(not stacked)
  if stacked and opacityPanel then opacityPanel:Hide() end
end

--- Returns whether the Friends List may run: its own setting and the Info Display's master switch are on, on a
--- client with the DamageMeter atlases and ScrollBox templates the window relies on (Retail and Forever).
---@return boolean allowed
local function isAllowed()
  return getSettings().enabled and db.profile.infoDisplay.enabled and isRetailOrForever()
end

--- AceAddon initialization hook; keeps the module disabled when it isn't allowed to run (see isAllowed).
function module:OnInitialize()
  if not isAllowed() then self:Disable() end
end

--- Shows the window (creating it on first use) and listens for friend list changes.
function module:OnEnable()
  -- Addon-wide re-enables (e.g. profile reset) and the Info Display switch enable every module, so re-check.
  if not isAllowed() then
    self:SetEnabledState(false)
    return
  end
  if not window then createWindow() end
  applyLayout()
  setMinimized(getSettings().minimized)
  setOpacity(getSettings().opacity)
  setFitToContent(getSettings().fitToContent) -- Window is still hidden, so the fit itself happens in OnShow.
  applyListWindowInteraction(window, getSettings())
  -- The same events the FriendsFrame refreshes its list on; favoriting/unfavoriting a friend fires
  -- BN_FRIEND_INFO_CHANGED, and FRIENDLIST_UPDATE covers character friends. SOCIAL_QUEUE_UPDATE updates the group
  -- icons (addGroupIcon) when a friend joins or leaves a group.
  for _, event in ipairs({ "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
    "BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED", "FRIENDLIST_UPDATE", "SOCIAL_QUEUE_UPDATE" }) do
    self:RegisterEvent(event, scheduleRefresh)
  end
  self:UpdateWindowShown()
  Self.InfoDisplay:RefreshPlayersOnline()
end

--- Stops listening for friend changes, hides the window and its opacity panel, and drops the Friends section
--- from the stacked Players Online window.
function module:OnDisable()
  self:UnregisterAllEvents()
  if window then window:Hide() end
  if opacityPanel then opacityPanel:Hide() end
  Self.InfoDisplay:RefreshPlayersOnline()
end
