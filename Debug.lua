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

--- Returns whether verbose debug logging is enabled.
---@return boolean - The persisted setting after initialization, or true for Slack during startup.
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

--- Toggles verbose debug logging and refreshes UI consumers of that setting.
---@return boolean - The new enabled state, or false before addon initialization.
function toggleDebugging()
  if not isInitialized() then return false end
  if not Self.db.global.logs then
    Self.db.global.logs = { debug = {}, error = {} }
  end
  Self.db.global.logs.isDebugging = not Self.db.global.logs.isDebugging
  if Self.db.global.logs.isDebugging then
    print("SlackHacks Debugging ON")
  else
    print("SlackHacks Debugging OFF")
  end
  if Self.Buffs and Self.Buffs.Refresh then
    Self.Buffs:Refresh()
  end
  local acr = LibStub("AceConfigRegistry-3.0", true)
  if acr then
    acr:NotifyChange("SlackHacks")
  end
  return Self.db.global.logs.isDebugging
end

--- Prints a timestamped debug message and optionally persists it with its varargs.
---@param message string - The message to print and store.
---@param ... any - Values written as separate argument records while debugging.
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

--- Reports whether persistent error capture is currently enabled.
---@return boolean - True only after initialization and when the saved option is enabled.
local function isErrorLoggingEnabled()
  return isInitialized() and db.global.logs and db.global.logs.errorLoggingEnabled
end

--- Returns the persistent error-log array, creating its containers when necessary.
---@return table|nil - The error entries, or nil before addon initialization.
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

--- Removes debug and error entries older than the configured retention period.
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
    module:UpdateMinimapIcon()
  end
end

--- Schedules log purging and an automatic report attempt after a short delay.
---@param shouldProcess boolean|nil - False suppresses processing for this call.
---@param delay number|nil - Delay in seconds; defaults to ten seconds.
function processLogs(shouldProcess, delay)
  if shouldProcess == false or not isErrorLoggingEnabled() then
    return
  end
  local waitSeconds = delay or 10
  C_Timer.After(waitSeconds, function()
    purgeOldLogs()
    module:AttemptReport(function(success, reason)
      if not success and not isSlackwise() then
        local list = errorLogTable()
        if list and #list > 0 then
          print(grey(icon(14)) .. " SlackHacks: you have " .. #list .. " un-reported error(s). Use " .. grey("/slack bugs") .. " to view and report them.")
        end
      end
    end)
  end)
end
--- Ace3 method adapter for `processLogs`.
---@param self table - The Debug module; accepted for Ace3 method compatibility.
---@param ... any - Forwarded to `processLogs`.
module.ProcessLogs = function(self, ...) processLogs(...) end

--- Deletes all persisted verbose debug entries.
function clearDebugLogs()
  if Self.db.global.logs and Self.db.global.logs.debug then
    wipe(Self.db.global.logs.debug)
  end
end
clearLogs = clearDebugLogs

--- Deletes all persisted captured-error entries.
function clearErrorLogs()
  if Self.db.global.logs and Self.db.global.logs.error then
    wipe(Self.db.global.logs.error)
  end
  module:UpdateMinimapIcon()
end

-----------------------------------------------------------------------
-- Error recording
-----------------------------------------------------------------------

--- Tests whether an error message or stack trace points into SlackHacks.
---@param message string|nil - Error text.
---@param stack string|nil - Captured stack trace.
---@return boolean - True when either value contains a known addon path marker.
local function isOurAddonError(message, stack)
  for _, marker in ipairs(ERROR_LOG_ADDON_PATH_MARKERS) do
    if (message and message:find(marker, 1, true)) or (stack and stack:find(marker, 1, true)) then
      return true
    end
  end
  return false
end

--- Records one local SlackHacks error, coalescing repeated message/character pairs.
---@param message string - Error text.
---@param stack string|nil - Stack trace, when available.
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
      module:UpdateMinimapIcon()
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
  module:UpdateMinimapIcon()

  if module:IsEnabled() then
    module:AttemptReport()
  end
end

--- Merges an error entry received from another player, de-duplicated the same way as `recordError`.
---@param entry table - Serialized remote error entry.
---@param senderName string - Character name used as the de-duplication owner.
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

-- Error capture is deliberately installed in one of two mutually exclusive ways. BugGrabber owns
-- the global handler when present, so listening to its public event avoids fighting it. Without
-- BugGrabber, our wrapper chains to the handler that was already installed and always calls it after
-- recording. This keeps the debugger observational: it adds an error log but does not become the
-- error-reporting system for the rest of the client.

local chainedErrorHandler
local errorCaptureInstalled = false
local listeningToBugGrabber = false

--- Captures an error for SlackHacks, then forwards it to the previously installed handler.
---@param message any - Error value supplied by the WoW error handler.
---@return any - Whatever the chained handler returns.
local function ourErrorHandler(message)
  if isErrorLoggingEnabled() then
    local ok, stack = pcall(debugstack, 2)
    recordError(tostring(message), ok and stack or nil)
  end
  if chainedErrorHandler then
    return chainedErrorHandler(message)
  end
end

--- Installs additive error capture through BugGrabber's event or a chained global handler.
-- The BugGrabber branch is a workaround for its intentional `seterrorhandler` no-op.
local function installErrorCapture()
  if errorCaptureInstalled or not isErrorLoggingEnabled() then return end

  if _G.BugGrabber and EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(_, tableID)
      local err = _G.BugGrabber:GetErrorByID(tableID)
      if err then
        recordError(tostring(err.message), err.stack)
      end
    end, module)
    listeningToBugGrabber = true
  else
    chainedErrorHandler = geterrorhandler()
    seterrorhandler(ourErrorHandler)
  end
  errorCaptureInstalled = true
end

--- Removes our event or chained-handler hook and restores the prior capture state.
local function uninstallErrorCapture()
  if not errorCaptureInstalled then return end

  if listeningToBugGrabber then
    if EventRegistry and EventRegistry.UnregisterCallback then
      EventRegistry:UnregisterCallback("BugGrabber.BugGrabbed", module)
    end
    listeningToBugGrabber = false
  elseif geterrorhandler() == ourErrorHandler then
    seterrorhandler(chainedErrorHandler)
  end

  chainedErrorHandler = nil
  errorCaptureInstalled = false
end

-----------------------------------------------------------------------
-- Who's eligible to report their error log to Slack, and how to reach him
-----------------------------------------------------------------------

--- Returns whether the current client flavor may send error reports.
---@return boolean - True for Retail or Forever clients.
local function isEligibleToReportErrorLogs()
  return isRetail() or isForever()
end

--- Looks for Slack currently online, either as a Battle.net (real-ID) friend playing WoW, or as a
--- character named "Slack" online in our shared guild. Battle.net is checked for both retail and Forever;
--- the guild check only ever matches if the local player is also in "Pulling Aggro IRL".
---@return string|nil, string|number|nil - "bnet" plus game account ID, or "guild" plus character name.
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
-- Reporting (chunked over a hidden addon channel, queued after combat)
-----------------------------------------------------------------------

--- Sends a serialized payload in Battle.net-sized chunks with start/middle/end markers.
---@param gameAccountID number - WoW game account receiving the data.
---@param text string - Serialized report payload.
---@param doneCallback fun(success:boolean) - Called after all chunks have been attempted.
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

--- Sends the local error log to a selected Battle.net or guild target.
---@param kind string - `bnet` or `guild`.
---@param target string|number - Battle.net game account ID or guild character name.
---@param onComplete fun(success:boolean, reason:string|nil)|nil - Completion callback.
function module:ReportErrorLogs(kind, target, onComplete)
  local callback = type(onComplete) == "function" and onComplete or nil
  if not isErrorLoggingEnabled() then
    if callback then callback(false, "logging_disabled") end
    return
  end
  if InCombatLockdown() then
    runAfterCombat(function() module:ReportErrorLogs(kind, target, callback) end)
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
module.SendErrorLogs = module.ReportErrorLogs

--- Finds an eligible target and reports local errors when one is online.
---@param onComplete fun(success:boolean, reason:string|nil)|nil - Completion callback.
function module:AttemptReport(onComplete)
  local callback = type(onComplete) == "function" and onComplete or nil
  if not isErrorLoggingEnabled() then
    if callback then callback(false, "logging_disabled") end
    return
  end
  if isSlackwise() then
    if callback then callback(false, "is_slack") end
    return
  end -- never applicable to Slack's own client
  if not isEligibleToReportErrorLogs() then
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

  module:ReportErrorLogs(kind, target, callback)
end
module.AttemptSend = module.AttemptReport

-----------------------------------------------------------------------
-- Receiving (only ever meaningful on Slack's own client, but harmless otherwise)
-----------------------------------------------------------------------

local toastFrame

--- Creates or updates the clickable notification shown for newly received errors.
---@param title string - Toast heading.
---@param body string - Toast detail text.
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

--- Deserializes and merges a received report, then notifies the player about new entries.
---@param text string - Serialized report payload.
---@param via string - Human-readable transport description.
function module:ProcessReceivedPayload(text, via)
  if not isErrorLoggingEnabled() then return end

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

--- Reassembles a marked Battle.net payload, keeping partial data isolated per sender.
---@param eventName string - AceEvent event name.
---@param prefix string - Addon-message prefix.
---@param text string - Marker-prefixed chunk.
---@param channel string - Transport channel supplied by WoW.
---@param senderID string|number - Sender key for the chunk spool.
function module:BN_CHAT_MSG_ADDON(eventName, prefix, text, channel, senderID)
  if not isErrorLoggingEnabled() then return end
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

--- Receives a guild-whisper report through AceComm and passes it to the merger.
---@param prefix string - Communication prefix.
---@param message string - Serialized report.
---@param distribution string - AceComm distribution.
---@param sender string - Sender name.
function Self:OnErrorLogCommReceived(prefix, message, distribution, sender)
  module:ProcessReceivedPayload(message, shortName(sender) or sender)
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

--- Synchronizes error-capture hooks, report events, and the AceComm receiver with settings.
function module:RefreshErrorLogging()
  if isErrorLoggingEnabled() then
    installErrorCapture()
    self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", "AttemptReport")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "AttemptReport")
    self:RegisterEvent("BN_CHAT_MSG_ADDON")
    Self:RegisterComm(ERROR_LOG_COMM_PREFIX, "OnErrorLogCommReceived")
    self:AttemptReport()
  else
    uninstallErrorCapture()
    self:UnregisterAllEvents()
    Self:UnregisterComm(ERROR_LOG_COMM_PREFIX)
  end
end

--- Persists the error-logging setting and immediately applies its hooks.
---@param enabled boolean - Whether local capture and reporting should be active.
function module:SetErrorLoggingEnabled(enabled)
  if not db.global.logs then db.global.logs = { debug = {}, error = {} } end
  db.global.logs.errorLoggingEnabled = enabled and true or false
  self:RefreshErrorLogging()
end

--- Ace3 lifecycle entry point that enables configured error logging.
function module:OnEnable()
  self:RefreshErrorLogging()
  self:UpdateMinimapIcon()
end

--- Ace3 lifecycle entry point that removes all error hooks and communication handlers.
function module:OnDisable()
  uninstallErrorCapture()
  self:UnregisterAllEvents()
  Self:UnregisterComm(ERROR_LOG_COMM_PREFIX)
  local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
  if ldbi and ldbi:IsRegistered(ERROR_MINIMAP_NAME) then
    ldbi:Hide(ERROR_MINIMAP_NAME)
  end
end

-----------------------------------------------------------------------
-- Markdown export + window (shared by a regular player filing a GitHub issue, and by Slack reviewing
-- everything that's been relayed to him)
-----------------------------------------------------------------------

--- Builds a GitHub-ready Markdown report from all persisted error entries.
---@return string - Markdown document containing client metadata and stack traces.
function module:BuildMarkdown()
  local list = errorLogTable() or {}
  local lines = {}
  table.insert(lines, "### SlackHacks Error Report")
  table.insert(lines, "")
  table.insert(lines, "- **Addon Version**: " .. tostring((C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("SlackHacks", "Version")) or (GetAddOnMetadata and GetAddOnMetadata("SlackHacks", "Version")) or "1"))
  local clientVersion = (GetBuildInfo and select(1, GetBuildInfo())) or (GetBuildInfo and GetBuildInfo()) or "unknown"
  local gameType = (isRetail and isRetail()) and "RETAIL" or "FOREVER"
  table.insert(lines, "- **Client Version**: " .. tostring(clientVersion) .. " (" .. gameType .. ")")
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

CLEAR_ERRORS_CONFIRM_POPUP = "SLACKHACKS_CLEAR_ERRORS_CONFIRM"
StaticPopupDialogs[CLEAR_ERRORS_CONFIRM_POPUP] = {
  text = "Do you want to clear the current error log?",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    clearErrorLogs()
    if module.RefreshMarkdown then
      module:RefreshMarkdown()
    end
    print("SlackHacks: SlackHacks Error Log cleared.")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
}

local function promptClearErrors()
  local list = errorLogTable()
  if list and #list > 0 then
    StaticPopup_Show(CLEAR_ERRORS_CONFIRM_POPUP)
  else
    print("SlackHacks: SlackHacks Error Log is already empty.")
  end
end

-----------------------------------------------------------------------
-- Minimap Error Icon (LibDBIcon)
-----------------------------------------------------------------------

local ERROR_MINIMAP_NAME = "SlackHacksErrorLog"
local errorLDBObj = nil

local function isListviewBagActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.listviewBag and profile.listviewBag.enabled
end

local function toggleListviewBag()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.listviewBag then profile.listviewBag = {} end
  local newState = not profile.listviewBag.enabled
  profile.listviewBag.enabled = newState
  profile.listviewBag.showListviewBag = newState
  if newState then
    if Self.ListviewBag then Self.ListviewBag:Enable() end
    if Self.ListviewBag and Self.ListviewBag.SetShowListviewBag then Self.ListviewBag:SetShowListviewBag(true) end
  else
    if Self.ListviewBag and Self.ListviewBag.SetShowListviewBag then Self.ListviewBag:SetShowListviewBag(false) end
    if Self.ListviewBag then Self.ListviewBag:Disable() end
  end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

local function isSquareMinimapActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.minimap and profile.minimap.enabled and profile.minimap.shape == "square"
end

local function toggleSquareMinimap()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.minimap then profile.minimap = {} end
  local isSquare = profile.minimap.enabled and profile.minimap.shape == "square"
  if isSquare then
    profile.minimap.shape = "circle"
    if Self.Minimap then Self.Minimap:Refresh() end
  else
    profile.minimap.enabled = true
    profile.minimap.shape = "square"
    if Self.Minimap then
      Self.Minimap:Enable()
      Self.Minimap:Refresh()
    end
  end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

local function isGearStatsActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.infoDisplay and profile.infoDisplay.enabled
    and profile.infoDisplay.charSheet and profile.infoDisplay.charSheet.gearStats
end

local function toggleGearStats()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.infoDisplay then profile.infoDisplay = {} end
  if not profile.infoDisplay.charSheet then profile.infoDisplay.charSheet = {} end
  local isGearStats = profile.infoDisplay.enabled and profile.infoDisplay.charSheet.gearStats
  local newState = not isGearStats
  profile.infoDisplay.enabled = newState
  profile.infoDisplay.charSheet.enabled = newState
  profile.infoDisplay.charSheet.gearStats = newState
  if newState then
    if Self.CharSheet and not Self.CharSheet:IsEnabled() then Self.CharSheet:Enable() end
    if Self.CharSheet and Self.CharSheet.SetCharSheetEnabled then Self.CharSheet:SetCharSheetEnabled(true) end
    if Self.InfoDisplay then Self.InfoDisplay:SetEnabled(true) end
  else
    if Self.InfoDisplay then Self.InfoDisplay:SetEnabled(false) end
    if Self.CharSheet and Self.CharSheet.SetCharSheetEnabled then Self.CharSheet:SetCharSheetEnabled(false) end
  end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

local function isMouseRingActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.mouseRing and profile.mouseRing.enabled
end

local function toggleMouseRing()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.mouseRing then profile.mouseRing = {} end
  local newState = not profile.mouseRing.enabled
  profile.mouseRing.enabled = newState
  if Self.MouseRing then Self.MouseRing:SetEnabled(newState) end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

local function isTrackDelvesActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.infoDisplay and profile.infoDisplay.weeklies
    and profile.infoDisplay.weeklies.enabled and profile.infoDisplay.weeklies.trackDelves
end

local function toggleTrackDelves()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.infoDisplay then profile.infoDisplay = {} end
  if not profile.infoDisplay.weeklies then profile.infoDisplay.weeklies = {} end
  local isTracking = profile.infoDisplay.weeklies.enabled and profile.infoDisplay.weeklies.trackDelves
  local newState = not isTracking
  profile.infoDisplay.weeklies.enabled = newState
  profile.infoDisplay.weeklies.trackDelves = newState
  if Self.Weeklies then
    Self.Weeklies:SetEnabled(newState)
    Self.Weeklies:SetTrackDelves(newState)
  end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

local function openMinimapContextMenu(anchor)
  if InCombatLockdown() then return end
  if GameTooltip then GameTooltip:Hide() end

  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
      rootDescription:CreateTitle("SlackHacks")
      rootDescription:CreateButton("Options", function()
        openOptions()
      end)
      rootDescription:CreateCheckbox("Listview Bag", isListviewBagActive, toggleListviewBag)
      rootDescription:CreateCheckbox("Square Minimap", isSquareMinimapActive, toggleSquareMinimap)
      rootDescription:CreateCheckbox("Display Gear Stats", isGearStatsActive, toggleGearStats)
      rootDescription:CreateCheckbox("Mouse Ring", isMouseRingActive, toggleMouseRing)
      rootDescription:CreateCheckbox("Track Delve Weeklies", isTrackDelvesActive, toggleTrackDelves)
    end)
    return
  end

  local menuList = {
    { text = "SlackHacks", isTitle = true, notCheckable = true },
    { text = "Options", func = function() openOptions() end, notCheckable = true },
    { text = "Listview Bag", checked = isListviewBagActive, func = toggleListviewBag, isNotRadio = true, keepShownOnClick = true },
    { text = "Square Minimap", checked = isSquareMinimapActive, func = toggleSquareMinimap, isNotRadio = true, keepShownOnClick = true },
    { text = "Display Gear Stats", checked = isGearStatsActive, func = toggleGearStats, isNotRadio = true, keepShownOnClick = true },
    { text = "Mouse Ring", checked = isMouseRingActive, func = toggleMouseRing, isNotRadio = true, keepShownOnClick = true },
    { text = "Track Delve Weeklies", checked = isTrackDelvesActive, func = toggleTrackDelves, isNotRadio = true, keepShownOnClick = true },
  }
  local menuFrame = CreateFrame("Frame", "SlackHacksMinimapContextMenu", UIParent, "UIDropDownMenuTemplate")
  EasyMenu(menuList, menuFrame, "cursor", 0, 0, "MENU")
end

local function ensureMinimapBadge(button)
  if button.errorBadge then return button.errorBadge end

  local badge = CreateFrame("Frame", nil, button)
  badge:SetFrameLevel(button:GetFrameLevel() + 5)
  badge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
  badge:SetSize(16, 16)

  local bg = badge:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(badge)
  bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  bg:SetVertexColor(0.85, 0.08, 0.08, 0.95)
  badge.bg = bg

  local countText = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  countText:SetFontObject(NumberFontNormalSmall or GameFontHighlightSmall)
  countText:SetPoint("CENTER", badge, "CENTER", 0, 0)
  countText:SetTextColor(1, 1, 1, 1)
  badge.countText = countText

  button.errorBadge = badge
  return badge
end

local function initMinimapIcon()
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
  if not ldb or not ldbi then return end

  if not errorLDBObj then
    errorLDBObj = ldb:NewDataObject(ERROR_MINIMAP_NAME, {
      type = "data source",
      text = "SlackHacks",
      icon = SLACKHACKS_ICON,
      OnClick = function(clickedButton, mouseButton)
        if mouseButton == "RightButton" then
          openMinimapContextMenu(clickedButton)
        else
          local list = errorLogTable() or {}
          if #list > 0 then
            module:ShowWindow()
          else
            openOptions()
          end
        end
      end,
      OnTooltipShow = function(tooltip)
        local list = errorLogTable() or {}
        local count = #list
        tooltip:AddLine("SlackHacks", 1, 0.82, 0)
        if count > 0 then
          tooltip:AddLine(" ")
          if count == 1 then
            tooltip:AddLine("You have 1 un-reported error in SlackHacks.", 1, 0.3, 0.3, true)
          else
            tooltip:AddLine(("You have %d un-reported errors in SlackHacks."):format(count), 1, 0.3, 0.3, true)
          end
          tooltip:AddLine("Left-click: Open error report window", 0.8, 0.8, 0.8)
        else
          tooltip:AddLine("Left-click: Open options", 0.8, 0.8, 0.8)
        end
        tooltip:AddLine("Right-click: Quick toggle menu", 0.8, 0.8, 0.8)
      end,
      OnEnter = function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
        if errorLDBObj.OnTooltipShow then
          errorLDBObj.OnTooltipShow(GameTooltip)
        end
        GameTooltip:Show()
      end,
      OnLeave = function()
        GameTooltip:Hide()
      end,
    })
  end

  if not ldbi:IsRegistered(ERROR_MINIMAP_NAME) then
    local db = (Self.db and Self.db.profile and Self.db.profile.minimapIcon) or { enabled = true, minimapPos = 220 }
    ldbi:Register(ERROR_MINIMAP_NAME, errorLDBObj, db)
  end
end

--- Updates the visibility, badge, and tooltip of the error minimap icon.
function module:UpdateMinimapIcon()
  local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
  if not ldbi then return end

  if not ldbi:IsRegistered(ERROR_MINIMAP_NAME) then
    initMinimapIcon()
  end

  local list = errorLogTable() or {}
  local count = #list
  local button = ldbi:GetMinimapButton(ERROR_MINIMAP_NAME)

  local isIconEnabled = true
  if Self.db and Self.db.profile and Self.db.profile.minimapIcon then
    if Self.db.profile.minimapIcon.enabled ~= nil then
      isIconEnabled = Self.db.profile.minimapIcon.enabled
    end
  end

  local shouldShow = count > 0 or isIconEnabled

  if shouldShow then
    if button then
      if count > 0 then
        local badge = ensureMinimapBadge(button)
        if count > 99 then
          badge.countText:SetText("99+")
          badge:SetSize(22, 16)
        elseif count >= 10 then
          badge.countText:SetText(tostring(count))
          badge:SetSize(18, 16)
        else
          badge.countText:SetText(tostring(count))
          badge:SetSize(16, 16)
        end
        badge:Show()
      elseif button.errorBadge then
        button.errorBadge:Hide()
      end
    end
    ldbi:Show(ERROR_MINIMAP_NAME)
  else
    if button and button.errorBadge then
      button.errorBadge:Hide()
    end
    ldbi:Hide(ERROR_MINIMAP_NAME)
  end
end

local FRAME_NAME = "SlackHacksBugReportFrame"
local WINDOW_WIDTH = 640
local WINDOW_HEIGHT = 540

--- Refreshes the markdown text and status in the error-log window.
function module:RefreshMarkdown()
  if self.markdownBox then
    self.markdownBox:SetText(self:BuildMarkdown())
  end
  if self.statusText then
    local list = errorLogTable() or {}
    self.statusText:SetText(("%d unique error(s) recorded"):format(#list))
  end
end

--- Displays or refreshes the standard Blizzard portrait error-log window.
function module:ShowWindow()
  if self.frame then
    self:RefreshMarkdown()
    self.frame:Show()
    return
  end

  local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "PortraitFrameTemplate")
  frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)

  if frame.SetTitle then
    frame:SetTitle("SlackHacks Error Reporting")
  elseif frame.TitleContainer and frame.TitleContainer.TitleText then
    frame.TitleContainer.TitleText:SetText("SlackHacks Error Reporting")
  elseif frame.TitleText then
    frame.TitleText:SetText("SlackHacks Error Reporting")
  end

  -- Align the portrait frame and icon inside the top-left circle
  if frame.portrait and frame.PortraitContainer then
    frame.portrait:Hide()
  end

  local portraitContainer = frame.PortraitContainer
  if portraitContainer then
    portraitContainer:ClearAllPoints()
    portraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 7)
    portraitContainer:SetSize(60, 60)
  end

  local portrait = (frame.GetPortrait and frame:GetPortrait())
    or (portraitContainer and portraitContainer.portrait)
    or frame.portrait

  if portrait then
    portrait:SetTexture(SLACKHACKS_ICON)
    if SetPortraitToAsset then
      SetPortraitToAsset(portrait, SLACKHACKS_ICON)
    end
    -- SetPortraitToAsset resets points to (0,0); scale and reapply the visual center offset
    -- so the entire icon is exposed cleanly inside the frame's circular aperture without clipping
    portrait:ClearAllPoints()
    portrait:SetSize(48, 48)
    portrait:SetPoint("CENTER", portraitContainer or frame, "CENTER", 0, -1.8)

    if portraitContainer and portraitContainer.CreateMaskTexture and not portraitContainer.mask then
      local mask = portraitContainer:CreateMaskTexture()
      mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(portraitContainer)
      portrait:AddMaskTexture(mask)
      portraitContainer.mask = mask
    end
  else
    local container = CreateFrame("Frame", nil, frame)
    container:SetFrameLevel(frame:GetFrameLevel() + 2)
    container:SetSize(60, 60)
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 7)

    portrait = container:CreateTexture(nil, "OVERLAY")
    portrait:SetSize(48, 48)
    portrait:SetPoint("CENTER", container, "CENTER", 0, -1.8)
    portrait:SetTexture(SLACKHACKS_ICON)

    if container.CreateMaskTexture then
      local mask = container:CreateMaskTexture()
      mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(container)
      portrait:AddMaskTexture(mask)
    end
    frame.portrait = portrait
  end

  if frame.CloseButton then
    frame.CloseButton:SetScript("OnClick", function()
      frame:Hide()
    end)
  else
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function()
      frame:Hide()
    end)
    frame.CloseButton = close
  end

  local inSpecial = false
  for _, name in ipairs(UISpecialFrames) do
    if name == FRAME_NAME then
      inSpecial = true
      break
    end
  end
  if not inSpecial then
    table.insert(UISpecialFrames, FRAME_NAME)
  end

  frame:SetScript("OnHide", function()
    local list = errorLogTable()
    if list and #list > 0 and not (StaticPopup_Visible and StaticPopup_Visible(CLEAR_ERRORS_CONFIRM_POPUP)) then
      StaticPopup_Show(CLEAR_ERRORS_CONFIRM_POPUP)
    end
  end)

  local content = CreateFrame("Frame", nil, frame)
  content:SetAllPoints()
  content:SetFrameLevel(frame:GetFrameLevel() + 500)

  local dragHandle = CreateFrame("Frame", nil, content)
  dragHandle:SetPoint("TOPLEFT", content, "TOPLEFT", 58, 0)
  dragHandle:SetPoint("TOPRIGHT", content, "TOPRIGHT", -30, 0)
  dragHandle:SetHeight(28)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function() frame:StartMoving() end)
  dragHandle:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

  local descLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  descLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -56)
  descLabel:SetPoint("RIGHT", content, "RIGHT", -24, 0)
  descLabel:SetJustifyH("LEFT")
  descLabel:SetWordWrap(true)
  descLabel:SetText("To report errors, please visit the below website and paste the *entire* text in the box below and just hit submit. Thanks!")

  local linkLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  linkLabel:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -10)
  linkLabel:SetText("New issue link (copy into your browser):")

  local linkBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
  linkBox:SetPoint("TOPLEFT", linkLabel, "BOTTOMLEFT", 4, -4)
  linkBox:SetPoint("RIGHT", content, "RIGHT", -24, 0)
  linkBox:SetHeight(20)
  linkBox:SetAutoFocus(false)
  linkBox:SetFontObject(ChatFontNormal or GameFontHighlight)
  linkBox:SetText(GITHUB_NEW_ISSUE_URL)
  linkBox:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
  linkBox:SetScript("OnMouseUp", function(s) s:HighlightText() end)
  linkBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

  local markdownLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  markdownLabel:SetPoint("TOPLEFT", linkBox, "BOTTOMLEFT", -4, -10)
  markdownLabel:SetText("Error Log (Markdown):")

  local hintLabel = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hintLabel:SetPoint("LEFT", markdownLabel, "RIGHT", 8, 0)
  hintLabel:SetText("(Click below and press Ctrl+A, then Ctrl+C to copy)")

  local scrollFrame = CreateFrame("ScrollFrame", "SlackHacksBugReportScrollFrame", content, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", markdownLabel, "BOTTOMLEFT", 4, -6)
  scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -32, 36)

  local scrollBg = CreateFrame("Frame", nil, scrollFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  scrollBg:SetPoint("TOPLEFT", -4, 4)
  scrollBg:SetPoint("BOTTOMRIGHT", 24, -4)
  if scrollBg.SetBackdrop then
    scrollBg:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    scrollBg:SetBackdropColor(0, 0, 0, 0.6)
    scrollBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
  end

  local editBox = CreateFrame("EditBox", "SlackHacksBugReportEditBox", scrollFrame)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  editBox:SetWidth(WINDOW_WIDTH - 68)
  editBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  editBox:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
  editBox:SetScript("OnCursorChanged", function(s, _, y, _, cursorHeight)
    y = -y
    local offset = scrollFrame:GetVerticalScroll()
    if y < offset then
      scrollFrame:SetVerticalScroll(y)
    else
      y = y + cursorHeight - scrollFrame:GetHeight()
      if y > offset then
        scrollFrame:SetVerticalScroll(y)
      end
    end
  end)
  scrollFrame:SetScrollChild(editBox)

  scrollFrame:SetScript("OnMouseDown", function()
    editBox:SetFocus()
  end)

  scrollFrame:SetScript("OnSizeChanged", function(_, width)
    if width and width > 0 then
      editBox:SetWidth(width)
    end
  end)

  local statusText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  statusText:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 20, 10)
  self.statusText = statusText

  local clearButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  clearButton:SetSize(110, 22)
  clearButton:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -16, 6)
  clearButton:SetText("Clear Errors")
  clearButton:SetScript("OnClick", function()
    promptClearErrors()
  end)
  self.clearButton = clearButton

  self.frame = frame
  self.markdownBox = editBox

  self:RefreshMarkdown()
  frame:Show()
end

--- Reports captured errors when possible, otherwise opens the local report window.
function module:ReportErrors()
  local list = errorLogTable()
  if not list or #list == 0 then
    print("SlackHacks: no errors recorded.")
    module:ShowWindow()
    return
  end

  module:AttemptReport(function(success, reason)
    if success then
      print("SlackHacks: bug logs successfully reported to Slack!")
    else
      if reason == "target_offline" then
        print("SlackHacks: Slack is not currently online to receive reported logs directly.")
      elseif reason == "in_combat" then
        print("SlackHacks: in combat; queued to report after combat.")
      end
      module:ShowWindow()
    end
  end)
end
module.HandleBugCommand = module.ReportErrors

-- Secret, undocumented /slack induce-error command for verifying BugGrabber/BugSack capture our errors.
--- Intentionally raises a nil-index error for testing the capture integrations.
function module:InduceError()
  local induceErrorNilValue = nil
  induceErrorNilValue.slackHacksInducedError = true
end
