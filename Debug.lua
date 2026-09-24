setfenv(1, _G.SlackHacks)

local module = Self:NewModule("Debug", "AceEvent-3.0")
Self.Debug = module
Self.ErrorLog = module -- backwards-compatibility alias

--[[
  Reference addons for this feature (both installed locally, readable via read_file/run_in_terminal):
    Interface\AddOns\!BugGrabber\BugGrabber.lua
    Interface\AddOns\BugSack\core.lua

  BugGrabber installs itself as THE global error handler (`real_seterrorhandler(grabError)`) and then makes
  `seterrorhandler` a permanent no-op, so nothing else can ever replace the handler again. BugSack doesn't
  fight over that either -- it just listens to BugGrabber's own public event
  (`EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", ...)`) and pulls the parsed error object via
  `BugGrabber:GetErrorByID(id)`.

  We copy that same additive pattern so BugSack/BugGrabber (or Blizzard's own default error handling, if
  neither is installed) keep working completely unmodified:
    - If BugGrabber is present, we only ever listen to its "BugGrabber.BugGrabbed" event.
    - Otherwise, we chain onto whatever error handler is currently installed (`geterrorhandler()`), the same
      technique BugGrabber itself uses -- our wrapper always calls through to it after recording.
  Either way we only ever RECORD errors whose message/stack point at our own addon's files -- every other
  addon's errors pass through completely untouched.
]]--

ERROR_LOG_COMM_PREFIX = "SlackHacksBug"
ERROR_LOG_ADDON_PATH_MARKERS = { "AddOns\\SlackHacks\\", "AddOns/SlackHacks/" }
GITHUB_NEW_ISSUE_URL = "https://github.com/Slackwise/SlackHacks/issues/new?labels=bug"
TARGET_GUILD_NAME = "Pulling Aggro IRL"
TARGET_CHARACTER_NAME = "Slack"
BNET_CHUNK_SIZE = 200

LOG_PURGE_MIN_HOURS = 1
LOG_PURGE_MAX_HOURS = 24 * 30 -- 30 days

-----------------------------------------------------------------------
-- Debug mode & general logging
-----------------------------------------------------------------------

function isDebugging()
  if isInitialized() then
    return Self.db.global.logs and Self.db.global.logs.isDebugging
  end
  if isSlackwise() then
    return true
  else
    return false
  end
end

function log(message, ...)
  if isDebugging() then
    local timestamp = date("%Y-%m-%dT%H:%M:%S") -- ISO form
    print(grey(timestamp) .. "  " .. message)
    if isInitialized() and Self.db.global.logs and Self.db.global.logs.debug then
      table.insert(Self.db.global.logs.debug, { timestamp, message })
      if arg then
        for i, v in ipairs(arg) do
          print("Arg " .. i .. " = " .. v)
          table.insert(Self.db.global.logs.debug, { timestamp, "Arg " .. i .. " = " .. v })
        end
      end
    end
  end
end

-----------------------------------------------------------------------
-- Storage & Purging
-----------------------------------------------------------------------

local function isErrorLoggingEnabled()
  return isInitialized() and db.global.logs and db.global.logs.errorLoggingEnabled
end

local function errorLogTable()
  if not isInitialized() then return nil end
  if not db.global.logs then
    db.global.logs = { debug = {}, error = {} }
  end
  if not db.global.logs.error then
    db.global.logs.error = {}
  end
  return db.global.logs.error
end

--- Shared by debug logs (`{timestamp, message}` array-form entries) and error logs (`{timestamp = ...}`
--- named-field entries) -- both are pruned by the same "Log Purging" settings.
---@param logTable table - Array of log entries to filter.
---@param cutoff number - Unix timestamp; entries older than this are dropped.
---@return table - Entries at or after `cutoff` (an unparseable timestamp is kept defensively).
function purgeLogTable(logTable, cutoff)
  local kept = {}
  for _, entry in ipairs(logTable) do
    local timestamp = entry.timestamp or entry[1]
    local year, month, day, hour, min, sec = timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    local entryTime = year and time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
    if not entryTime or entryTime >= cutoff then
      table.insert(kept, entry)
    end
  end
  return kept
end

function purgeOldLogs()
  if not Self.db.global.logs or not Self.db.global.logs.logPurgeEnabled then
    return
  end
  local purgeHours = Self.db.global.logs.logPurgeHours or 48
  local cutoff = time() - (purgeHours * 60 * 60)
  if Self.db.global.logs.debug then
    Self.db.global.logs.debug = purgeLogTable(Self.db.global.logs.debug, cutoff)
  end
  if Self.db.global.logs.error then
    Self.db.global.logs.error = purgeLogTable(Self.db.global.logs.error, cutoff)
  end
end

function processLogs(shouldProcess, delay)
  if shouldProcess == false then
    return
  end
  local waitSeconds = delay or 10
  C_Timer.After(waitSeconds, function()
    purgeOldLogs()
    module:AttemptSend()
  end)
end
module.ProcessLogs = function(self, ...) processLogs(...) end

function clearDebugLogs()
  if Self.db.global.logs and Self.db.global.logs.debug then
    wipe(Self.db.global.logs.debug)
  end
end
clearLogs = clearDebugLogs

function clearErrorLogs()
  if Self.db.global.logs and Self.db.global.logs.error then
    wipe(Self.db.global.logs.error)
  end
end

-----------------------------------------------------------------------
-- Error recording
-----------------------------------------------------------------------

local function isOurAddonError(message, stack)
  for _, marker in ipairs(ERROR_LOG_ADDON_PATH_MARKERS) do
    if (message and message:find(marker, 1, true)) or (stack and stack:find(marker, 1, true)) then
      return true
    end
  end
  return false
end

local function recordError(message, stack)
  if not isErrorLoggingEnabled() then return end
  if not isOurAddonError(message, stack) then return end

  local list = errorLogTable()
  if not list then return end

  local timestamp = date("%Y-%m-%dT%H:%M:%S") -- ISO form, matches the regular debug logs
  local senderName = characterFullName(UnitName("player"), GetRealmName()) or UnitName("player")

  for _, entry in ipairs(list) do
    if entry.message == message and entry.senderName == senderName then
      entry.timestamp = timestamp
      entry.count = (entry.count or 1) + 1
      return
    end
  end

  table.insert(list, {
    timestamp = timestamp,
    message = message,
    stack = stack,
    count = 1,
    senderName = senderName, -- the character/player this error happened to
  })
end

--- Merges an error entry received from another player, de-duplicated the same way as `recordError`.
---@return boolean - True if this was a new entry (not just a counter bump on an existing one).
local function recordReceivedEntry(entry, senderName)
  local list = errorLogTable()
  if not list then return false end

  for _, existing in ipairs(list) do
    if existing.message == entry.message and existing.senderName == senderName then
      existing.timestamp = entry.timestamp or existing.timestamp
      existing.count = math.max(existing.count or 1, entry.count or 1)
      return false
    end
  end
  table.insert(list, {
    timestamp = entry.timestamp,
    message = entry.message,
    stack = entry.stack,
    count = entry.count or 1,
    senderName = senderName,
  })
  return true
end

-----------------------------------------------------------------------
-- Error capture (additive -- never disables BugSack/BugGrabber/Blizzard's own error handling)
-----------------------------------------------------------------------

local chainedErrorHandler

local function ourErrorHandler(message)
  local ok, stack = pcall(debugstack, 2)
  recordError(tostring(message), ok and stack or nil)
  if chainedErrorHandler then
    return chainedErrorHandler(message)
  end
end

local function installErrorCapture()
  if _G.BugGrabber and EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(_, tableID)
      local err = _G.BugGrabber:GetErrorByID(tableID)
      if err then
        recordError(tostring(err.message), err.stack)
      end
    end, module)
  else
    chainedErrorHandler = geterrorhandler()
    seterrorhandler(ourErrorHandler)
  end
end

installErrorCapture() -- run immediately (file load time) to start capturing as early as possible

-----------------------------------------------------------------------
-- Who's eligible to relay their error log to Slack, and how to reach him
-----------------------------------------------------------------------

local function isEligibleToSendErrorLogs()
  return isRetail() or isForever()
end

--- Looks for Slack currently online, either as a Battle.net (real-ID) friend playing WoW, or as a
--- character named "Slack" online in our shared guild. Battle.net is checked for both retail and Forever;
--- the guild check only ever matches if the local player is also in "Pulling Aggro IRL".
---@return string|nil, string|number|nil - "bnet"+gameAccountID, or "guild"+full character name, or nil.
local function resolveSlackTarget()
  if BNGetNumFriends and BNGetFriendInfo and C_BattleNet and C_BattleNet.GetAccountInfoByID then
    for index = 1, BNGetNumFriends() do
      local bnetIDAccount = BNGetFriendInfo(index)
      local accountInfo = bnetIDAccount and C_BattleNet.GetAccountInfoByID(bnetIDAccount)
      if accountInfo and accountInfo.battleTag == SLACKWISE_BATTLETAG then
        local gameAccountInfo = accountInfo.gameAccountInfo
        if gameAccountInfo and gameAccountInfo.isOnline
            and gameAccountInfo.clientProgram == (BNET_CLIENT_WOW or "WoW")
            and gameAccountInfo.gameAccountID then
          return "bnet", gameAccountInfo.gameAccountID
        end
      end
    end
  end

  if IsInGuild() and GetGuildInfo("player") == TARGET_GUILD_NAME then
    for index = 1, GetNumGuildMembers() do
      local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(index)
      if name and online and sameName(name, TARGET_CHARACTER_NAME) then
        return "guild", name
      end
    end
  end

  return nil
end

-----------------------------------------------------------------------
-- Sending (chunked over a hidden addon channel, queued after combat)
-----------------------------------------------------------------------

local function sendBattleNetChunked(gameAccountID, text, doneCallback)
  if not (C_BattleNet and C_BattleNet.SendGameData) then
    doneCallback(false)
    return
  end
  local SUCCESS = (Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success) or 0
  local total, pos, allOk = #text, 1, true
  repeat
    local endPos = math.min(pos + BNET_CHUNK_SIZE - 1, total)
    local isFirst, isLast = pos == 1, endPos >= total
    local marker = (isFirst and "\001") or "\002"
    if isLast then marker = "\003" end
    local result = C_BattleNet.SendGameData(gameAccountID, ERROR_LOG_COMM_PREFIX, marker .. text:sub(pos, endPos))
    if result ~= SUCCESS then allOk = false end
    pos = endPos + 1
  until pos > total
  doneCallback(allOk)
end

function module:SendErrorLogs(kind, target, onComplete)
  local callback = type(onComplete) == "function" and onComplete or nil
  if InCombatLockdown() then
    runAfterCombat(function() module:SendErrorLogs(kind, target, callback) end)
    if callback then callback(false, "in_combat") end
    return
  end
  local list = errorLogTable()
  if not list or #list == 0 then
    if callback then callback(false, "no_logs") end
    return
  end

  local payload = Self:Serialize({
    sender = characterFullName(UnitName("player"), GetRealmName()) or UnitName("player"),
    entries = list,
  })

  if kind == "bnet" then
    sendBattleNetChunked(target, payload, function(success)
      if success then clearErrorLogs() end
      if callback then callback(success) end
    end)
  elseif kind == "guild" then
    Self:SendCommMessage(ERROR_LOG_COMM_PREFIX, payload, "WHISPER", target, "BULK", function(_, sent, total)
      if sent and total and sent >= total then
        clearErrorLogs()
        if callback then callback(true) end
      end
    end)
  else
    if callback then callback(false, "unknown_kind") end
  end
end

function module:AttemptSend(onComplete)
  local callback = type(onComplete) == "function" and onComplete or nil
  if not isErrorLoggingEnabled() then
    if callback then callback(false, "logging_disabled") end
    return
  end
  if isSlackwise() then
    if callback then callback(false, "is_slack") end
    return
  end -- never applicable to Slack's own client
  if not isEligibleToSendErrorLogs() then
    if callback then callback(false, "ineligible") end
    return
  end
  local list = errorLogTable()
  if not list or #list == 0 then
    if callback then callback(false, "no_logs") end
    return
  end

  local kind, target = resolveSlackTarget()
  if not kind then
    if callback then callback(false, "target_offline") end
    return
  end

  module:SendErrorLogs(kind, target, callback)
end

-----------------------------------------------------------------------
-- Receiving (only ever meaningful on Slack's own client, but harmless otherwise)
-----------------------------------------------------------------------

local toastFrame

local function showToast(title, body)
  if not toastFrame then
    toastFrame = CreateFrame("Frame", "SlackHacksErrorToast", UIParent, "BackdropTemplate")
    toastFrame:SetSize(280, 60)
    toastFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 60)
    toastFrame:SetFrameStrata("DIALOG")
    toastFrame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    local icon = toastFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", toastFrame, "LEFT", 10, 0)
    icon:SetTexture(SLACKHACKS_ICON)

    local titleText = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
    titleText:SetPoint("TOPRIGHT", toastFrame, "TOPRIGHT", -10, -2)
    titleText:SetJustifyH("LEFT")
    toastFrame.titleText = titleText

    local bodyText = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bodyText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    bodyText:SetPoint("BOTTOMRIGHT", toastFrame, "BOTTOMRIGHT", -10, 6)
    bodyText:SetJustifyH("LEFT")
    toastFrame.bodyText = bodyText

    toastFrame:EnableMouse(true)
    toastFrame:SetScript("OnMouseDown", function()
      module:ShowWindow()
      toastFrame:Hide()
    end)
  end

  toastFrame.titleText:SetText(title)
  toastFrame.bodyText:SetText(body)
  toastFrame:Show()
  C_Timer.After(6, function()
    if toastFrame and toastFrame:IsShown() then
      toastFrame:Hide()
    end
  end)
end

function module:ProcessReceivedPayload(text, via)
  local ok, data = Self:Deserialize(text)
  if not ok or type(data) ~= "table" or type(data.entries) ~= "table" then return end

  local senderName = data.sender or via or "Unknown"
  local newCount = 0
  for _, entry in ipairs(data.entries) do
    if type(entry) == "table" and entry.message and recordReceivedEntry(entry, senderName) then
      newCount = newCount + 1
    end
  end

  if newCount > 0 then
    print(("SlackHacks: received %d error log %s from %s (via %s)."):format(
      newCount, newCount == 1 and "entry" or "entries", senderName, via))
    showToast("SlackHacks Error Received", ("%d new error(s) from %s"):format(newCount, senderName))
    if RaidNotice_AddMessage and RaidWarningFrame then
      RaidNotice_AddMessage(RaidWarningFrame, "SlackHacks: Error log received from " .. senderName .. "!",
        { r = 1, g = 0.3, b = 0.1 })
    end
  end
end

local bnetSpool = {}

function module:BN_CHAT_MSG_ADDON(eventName, prefix, text, channel, senderID)
  if prefix ~= ERROR_LOG_COMM_PREFIX then return end
  local marker, chunk = text:sub(1, 1), text:sub(2)
  if marker == "\001" then
    bnetSpool[senderID] = chunk
  elseif marker == "\002" then
    bnetSpool[senderID] = (bnetSpool[senderID] or "") .. chunk
  elseif marker == "\003" then
    local full = (bnetSpool[senderID] or "") .. chunk
    bnetSpool[senderID] = nil
    module:ProcessReceivedPayload(full, "Battle.net friend")
  end
end

function Self:OnErrorLogCommReceived(prefix, message, distribution, sender)
  module:ProcessReceivedPayload(message, shortName(sender) or sender)
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

function module:OnEnable()
  self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", "AttemptSend")
  self:RegisterEvent("GUILD_ROSTER_UPDATE", "AttemptSend")
  self:RegisterEvent("BN_CHAT_MSG_ADDON")
  Self:RegisterComm(ERROR_LOG_COMM_PREFIX, "OnErrorLogCommReceived")

  -- Guild roster online-status is only ever as fresh as the last request; BN_FRIEND_ACCOUNT_ONLINE already
  -- reacts instantly on its own, so this ticker mainly exists to catch a guild login and as a safety net.
  self.refreshTicker = C_Timer.NewTicker(60, function()
    if IsInGuild() then
      if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
      elseif GuildRoster then
        GuildRoster()
      end
    end
    module:AttemptSend()
  end)
end

function module:OnDisable()
  if self.refreshTicker then
    self.refreshTicker:Cancel()
    self.refreshTicker = nil
  end
end

-----------------------------------------------------------------------
-- Markdown export + window (shared by a regular player filing a GitHub issue, and by Slack reviewing
-- everything that's been relayed to him)
-----------------------------------------------------------------------

function module:BuildMarkdown()
  local list = errorLogTable() or {}
  local lines = {}
  table.insert(lines, "### SlackHacks Error Report")
  table.insert(lines, "")
  table.insert(lines, "- **Addon Version**: " .. tostring(GetAddOnMetadata and (GetAddOnMetadata("SlackHacks", "Version") or "") or "0.5"))
  table.insert(lines, "- **Client Flavor**: " .. tostring(gameClientFlavor and gameClientFlavor() or "unknown"))
  table.insert(lines, "- **Date**: " .. date("%Y-%m-%d %H:%M:%S"))
  table.insert(lines, "- **Player**: " .. (characterFullName(UnitName("player"), GetRealmName()) or UnitName("player") or "Unknown"))
  table.insert(lines, "")

  if #list == 0 then
    table.insert(lines, "_No errors currently recorded in SlackHacks._")
  else
    table.insert(lines, ("**Total unique errors**: %d"):format(#list))
    table.insert(lines, "")
    for index, entry in ipairs(list) do
      table.insert(lines, ("#### %d. %s"):format(index, (entry.message or "Unknown error"):gsub("[\r\n].*", "")))
      table.insert(lines, ("- **Occurred**: %s"):format(entry.timestamp or "Unknown"))
      table.insert(lines, ("- **Count**: %d"):format(entry.count or 1))
      if entry.senderName then
        table.insert(lines, ("- **Reporter**: %s"):format(entry.senderName))
      end
      table.insert(lines, "")
      table.insert(lines, "```text")
      table.insert(lines, entry.message or "")
      if entry.stack and #entry.stack > 0 then
        table.insert(lines, "")
        table.insert(lines, entry.stack)
      end
      table.insert(lines, "```")
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

function module:ShowWindow()
  local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
  if not AceGUI then
    print("SlackHacks: AceGUI-3.0 not available to display error log.")
    return
  end

  if self.frame then
    self.markdownBox:SetText(self:BuildMarkdown())
    self.frame:Show()
    return
  end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("SlackHacks Error Log")
  frame:SetStatusText("Copy the markdown below and paste it into a new GitHub issue.")
  frame:SetLayout("Flow")
  frame:SetWidth(650)
  frame:SetHeight(500)
  frame:EnableResize(true)
  frame:SetCallback("OnClose", function(widget)
    widget:Hide()
  end)
  self.frame = frame

  local linkLabel = AceGUI:Create("Label")
  linkLabel:SetText("New issue link (copy into your browser):")
  linkLabel:SetFullWidth(true)
  frame:AddChild(linkLabel)

  local linkBox = AceGUI:Create("EditBox")
  linkBox:SetFullWidth(true)
  linkBox:SetText(GITHUB_NEW_ISSUE_URL)
  linkBox:DisableButton(true)
  frame:AddChild(linkBox)

  local markdownBox = AceGUI:Create("MultiLineEditBox")
  markdownBox:SetLabel("Error Log (Markdown)")
  markdownBox:SetFullWidth(true)
  markdownBox:SetNumLines(22)
  markdownBox:DisableButton(true)
  frame:AddChild(markdownBox)
  self.markdownBox = markdownBox

  markdownBox:SetText(self:BuildMarkdown())
end

function module:HandleBugCommand()
  local list = errorLogTable()
  if not list or #list == 0 then
    print("SlackHacks: no errors recorded.")
    module:ShowWindow()
    return
  end

  module:AttemptSend(function(success, reason)
    if success then
      print("SlackHacks: bug logs successfully sent to Slack!")
    else
      if reason == "target_offline" then
        print("SlackHacks: Slack is not currently online to receive logs directly.")
      elseif reason == "in_combat" then
        print("SlackHacks: in combat; queued to send after combat.")
      end
      module:ShowWindow()
    end
  end)
end
