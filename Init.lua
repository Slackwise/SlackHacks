--INITIALIZE
local Self = LibStub("AceAddon-3.0"):NewAddon(
  "SlackHacks",
  "AceConsole-3.0",
  "AceEvent-3.0",
  "AceComm-3.0",
  "AceSerializer-3.0"
)
Self.config = LibStub("AceConfig-3.0")
Self.frame = CreateFrame("Frame", "SlackHacks")
Self.itemBindingFrame = CreateFrame("Frame", "SlackHacks Item Bindings")
_G.SlackHacks = Self
Self.Self = Self
setmetatable(Self, {__index = _G}) -- The global environment is now checked if a key is not found in addon
setfenv(1, Self) -- Namespace local to addon

addonName, addonTable = ...

SLACKHACKS_ICON = "Interface\\Icons\\inv_12_profession_blacksmithing_blacksmithstoolkit_green"

CONFIG_VERSION = 6

Enum.SelfVendorMode = {
  CONSUMABLES_MISSING = 1,
  CONSUMABLES_ALL = 2,
  CONSUMABLES_PERSISTENT = 3,
  OIL = 4,
  AUGMENT_RUNES = 5,
  AUGMENTS = 6,
  VANTUS_RUNE = 7,
}

function getBattletag()
  return select(2, BNGetInfo())
end

SLACKWISE_BATTLETAG = "Slackwise#1121"

function isSlackwise()
  return getBattletag() == SLACKWISE_BATTLETAG or false
end

-- Gatekeeping new features with no UI
function isTester()
  -- Use a checkbox in settings later, probably, but right now it's just me
  return isSlackwise()
end

function isRetail()
  -- Official way Blizzard distinguishes between game clients: https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID
  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT ~= LE_EXPANSION_CLASSIC then
    return true
  else
    return false
  end
end

function isForever()
  -- Official way Blizzard distinguishes between game clients: https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID
  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_CLASSIC then
    return true
  else
    return false
  end
end

function isClassic()
  -- Official way Blizzard distinguishes between game clients: https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID
  if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
    return true
  else
    return false
  end
end

function getGameType()
  if isRetail() then
    return "RETAIL"
  elseif isForever() then
    return "FOREVER"
  elseif isClassic() then
    return "CLASSIC"
  else
    return "UNKNOWN" -- Uh oh
  end
end

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

COLOR_START = "\124c"
COLOR_END   = "\124r"

function color(color)
  return function(text)
    return COLOR_START .. "FF" .. color .. text .. COLOR_END
  end
end

grey = color("AAAAAA")

function icon(size)
  return "\124T" .. SLACKHACKS_ICON .. ":" .. (size or 16) .. "\124t"
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

LOG_PURGE_MIN_HOURS = 1
LOG_PURGE_MAX_HOURS = 24 * 30 -- 30 days

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

-- Maps a target config version to the function that migrates from (target - 1) to it.
CONFIG_MIGRATIONS = {
  [2] = function()
    local categories = Self.db.profile.buffs and Self.db.profile.buffs.categories
    if categories and categories.rune == nil then
      categories.rune = categories.augmentRune == true
    end
    if categories then
      categories.augmentRune = nil
    end
  end,
  [3] = function()
    local general = Self.db.profile.general
    if general and general.showAllMinimapTracking ~= nil then
      Self.db.profile.minimap.showAllMinimapTracking = general.showAllMinimapTracking
      general.showAllMinimapTracking = nil
    end
  end,
  [4] = function()
    local general = Self.db.profile.general
    if general and general.maximumCameraZoom ~= nil then
      Self.db.profile.controls.maximumCameraZoom = general.maximumCameraZoom
      general.maximumCameraZoom = nil
    end
    if general and general.enableDynamicCamera ~= nil then
      Self.db.profile.controls.enableDynamicCamera = general.enableDynamicCamera
      general.enableDynamicCamera = nil
    end
  end,
  [5] = function()
    local general = Self.db.profile.general
    if not general then return end
    if general.autoSellGreyItems ~= nil then
      Self.db.profile.inventory.autoSellGreyItems = general.autoSellGreyItems
    end
    if general.autoRepair ~= nil then
      Self.db.profile.inventory.autoRepair = general.autoRepair
    end
    if general.autoRepairMode ~= nil then
      Self.db.profile.inventory.autoRepairMode = general.autoRepairMode
    end
    Self.db.profile.general = nil
  end,
  [6] = function()
    local g = Self.db.global
    if not g then return end
    local debugTable = g.debugLogs or (type(g.logs) == "table" and not g.logs.debug and g.logs) or (type(g.logs) == "table" and g.logs.debug) or {}
    local errorTable = g.errorLogs or (type(g.logs) == "table" and g.logs.error) or {}
    local isDebugging = (type(g.logs) == "table" and g.logs.isDebugging ~= nil and g.logs.isDebugging) or (g.isDebugging ~= nil and g.isDebugging) or false
    local errorLoggingEnabled = true
    if type(g.logs) == "table" and g.logs.errorLoggingEnabled ~= nil then
      errorLoggingEnabled = g.logs.errorLoggingEnabled
    elseif g.errorLoggingEnabled ~= nil then
      errorLoggingEnabled = g.errorLoggingEnabled
    end
    local logPurgeEnabled = true
    if type(g.logs) == "table" and g.logs.logPurgeEnabled ~= nil then
      logPurgeEnabled = g.logs.logPurgeEnabled
    elseif g.logPurgeEnabled ~= nil then
      logPurgeEnabled = g.logPurgeEnabled
    end
    local logPurgeHours = (type(g.logs) == "table" and g.logs.logPurgeHours) or g.logPurgeHours or 48

    g.logs = {
      debug = debugTable,
      error = errorTable,
      isDebugging = isDebugging,
      errorLoggingEnabled = errorLoggingEnabled,
      logPurgeEnabled = logPurgeEnabled,
      logPurgeHours = logPurgeHours,
    }
    g.debugLogs = nil
    g.errorLogs = nil
    g.isDebugging = nil
    g.errorLoggingEnabled = nil
    g.logPurgeEnabled = nil
    g.logPurgeHours = nil
  end,
}

-- Version 1 predates this migration system entirely (no data shape changed getting to it), so it's the
-- only version allowed to have no migration function without being treated as unrecoverable.
CONFIG_RESET_POPUP = "SLACKHACKS_CONFIG_RESET"
StaticPopupDialogs[CONFIG_RESET_POPUP] = {
  text = "SlackHacks: your saved settings were reset to defaults because they were out of date or could not be loaded. Please review your settings.",
  button1 = OKAY,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
}

function notifyConfigReset()
  StaticPopup_Show(CONFIG_RESET_POPUP)
end

-- Resets the current profile back to defaults (leaves other profiles/characters alone, same as the
-- native AceDBOptions "Reset Profile" button) and informs the user via a popup.
function resetConfig(reason)
  log("Resetting SlackHacks config: " .. tostring(reason))
  if Self.db then
    Self.db:ResetProfile()
    Self.db.global.configVersion = CONFIG_VERSION
  end
  notifyConfigReset()
end

function migrateConfig()
  local version = Self.db.global.configVersion or 0
  if version == CONFIG_VERSION then
    return
  end
  if version > CONFIG_VERSION then
    -- Saved data is newer than this build of the addon (e.g. a downgrade/rollback) and can't be trusted.
    resetConfig("saved config version " .. version .. " is newer than CONFIG_VERSION " .. CONFIG_VERSION)
    return
  end
  local ok, err = pcall(function()
    while version < CONFIG_VERSION do
      version = version + 1
      local migrate = CONFIG_MIGRATIONS[version]
      if migrate then
        migrate()
      elseif version > 1 then
        error("no migration function defined for config version " .. version)
      end
      Self.db.global.configVersion = version
    end
  end)
  if not ok then
    resetConfig(err)
  end
end

--Event Handlers
function Self:OnInitialize()
  -- true = share one "Default" profile across all characters instead of a per-character profile
  local ok, err = pcall(function()
    Self.db = LibStub("AceDB-3.0"):New("SlackHacksDB", dbDefaults, true)
  end)
  if not ok or not Self.db then
    -- Saved variables were corrupted/unreadable: wipe and recreate from defaults rather than erroring out.
    print("SlackHacks: failed to load saved settings (" .. tostring(err) .. "), resetting to defaults.")
    _G.SlackHacksDB = nil
    Self.db = LibStub("AceDB-3.0"):New("SlackHacksDB", dbDefaults, true)
    notifyConfigReset()
  end

  -- One-time nudge for anyone still parked on an old auto-generated per-character profile (e.g. from
  -- before "Reset All Data" explicitly forced "Default", or a stale account predating this convention).
  local autoCharacterProfile = UnitName("player") .. " - " .. GetRealmName()
  if Self.db:GetCurrentProfile() == autoCharacterProfile then
    Self.db:SetProfile("Default")
  end

  registerOptions()
  Self:RegisterChatCommand("slack", handleSlashCommand)

  -- Disabling ActionCam warning/confirmation popup: https://github.com/mpstark/DynamicCam/blob/master/Core.lua#L628C1-L629C68
  -- As of a recent client update, this event is no longer dispatched to UIParent (or any other
  -- addon-visible frame) -- it's consumed internally by Blizzard_Game's own event dispatcher
  -- (Interface/AddOns/Blizzard_Game/Shared/EventRouting.lua), so UnregisterEvent on UIParent is a no-op.
  -- `GameEvent` is the (non-local, addon-accessible) table that owns that dispatcher.
  if GameEvent and GameEvent.UnregisterInternalEvent then
    GameEvent.UnregisterInternalEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
  else
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
  end
end

function isInitialized()
  -- Check for presence of last thing loaded at init
  return not not Self["configDialog"]
end