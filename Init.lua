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
if _G.ColorMixin then Self.ColorMixin = _G.ColorMixin end
setfenv(1, Self) -- Namespace local to addon

addonName, addonTable = ...

SLACKHACKS_ICON = "Interface\\AddOns\\SlackHacks\\Assets\\SlackHacks.png"

CONFIG_VERSION = 7

function getAddonVersion()
  return tostring((C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("SlackHacks", "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata("SlackHacks", "Version"))
    or "1")
end

Enum.SelfVendorMode = {
  CONSUMABLES = 1,
  OIL = 4,
  AUGMENT_RUNES = 5,
  VANTUS_RUNE = 6,
  AUGMENTS = 7,
  FLASK = 8,
  CRIT_FLASK = 9,
  MASTERY_FLASK = 10,
  HASTE_FLASK = 11,
  VERSATILITY_FLASK = 12,
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
  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    return true
  else
    return false
  end
end

function isForever()
  -- Official way Blizzard distinguishes between game clients: https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID
  if WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
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

-- Maps a target config version to the function that migrates from (target - 1) to it.
CONFIG_MIGRATIONS = {
  [2] = function()
    local function migrateProfile(p)
      if not p or type(p) ~= "table" then return end

      p.listviewBag = p.listviewBag or {}
      if p.listviewBag.trackCrestCurrencies == nil then
        p.listviewBag.trackCrestCurrencies = true
      end

      if type(p.minimapIcon) == "boolean" then
        p.minimapIcon = {
          enabled = p.minimapIcon,
          minimapPos = 220,
        }
      elseif p.minimapIcon == nil then
        p.minimapIcon = {
          enabled = true,
          minimapPos = 220,
        }
      elseif type(p.minimapIcon) == "table" then
        if p.minimapIcon.enabled == nil then
          p.minimapIcon.enabled = true
        end
        if p.minimapIcon.minimapPos == nil then
          p.minimapIcon.minimapPos = 220
        end
      end
    end

    if Self.db.profiles then
      for _, p in pairs(Self.db.profiles) do
        migrateProfile(p)
      end
    end
    if Self.db.profile then
      migrateProfile(Self.db.profile)
    end

    -- Default error logging to true in version 2
    local g = Self.db.global
    if g then
      g.errorMinimap = nil
      g.logs = g.logs or {}
      g.logs.errorLoggingEnabled = true
      if Self.Debug and Self.Debug.RefreshErrorLogging then
        Self.Debug:RefreshErrorLogging()
      end
      if updateMinimapIcon then
        updateMinimapIcon()
      elseif Self.UpdateMinimapIcon then
        Self.UpdateMinimapIcon()
      end
    end
  end,
  [3] = function()
    -- Purge previous error logs for version 3
    local g = Self.db.global
    if g and g.logs and g.logs.error then
      wipe(g.logs.error)
    end
  end,
  [4] = function()
    -- Add the Quest / NPC module settings, all off by default.
    local QUEST_DEFAULTS = {
      enabled = false,
      autoAccept = false,
      autoComplete = false,
      autoClickFirstOption = false,
      numberKeys = false,
      questItemButton = false,
    }
    local function migrateProfile(p)
      if not p or type(p) ~= "table" then return end
      if type(p.quest) ~= "table" then
        p.quest = {}
      end
      for key, value in pairs(QUEST_DEFAULTS) do
        if p.quest[key] == nil then
          p.quest[key] = value
        end
      end
    end

    if Self.db.profiles then
      for _, p in pairs(Self.db.profiles) do
        migrateProfile(p)
      end
    end
    if Self.db.profile then
      migrateProfile(Self.db.profile)
    end
  end,
  [5] = function()
    -- Rename movableWindows -> windows and split it into nested `movable` and `scaling` tables. The old
    -- single `enabled` switch becomes both the overall Windows switch and the Movable Windows switch, so
    -- existing users keep the exact behavior they had.
    local function migrateProfile(p)
      if not p or type(p) ~= "table" then return end
      local old = p.movableWindows
      if type(old) ~= "table" then return end
      local enabled = old.enabled == true
      -- Merge into any existing `windows` table (AceDB may already have filled defaults into the current
      -- profile) and only copy values that were actually saved: AceDB strips default values on logout, so
      -- old fields are often nil, and every table the module indexes must exist afterwards.
      local w = type(p.windows) == "table" and p.windows or {}
      p.windows = w
      w.enabled = enabled
      w.movable = type(w.movable) == "table" and w.movable or {}
      w.scaling = type(w.scaling) == "table" and w.scaling or {}
      local function copy(dst, key, value)
        if value ~= nil then dst[key] = value end
      end
      w.movable.enabled = enabled
      copy(w.movable, "moveToasts", old.moveToasts)
      copy(w.movable, "modifierKey", old.modifierKey)
      copy(w.movable, "savePositionStrategy", old.savePositionStrategy)
      copy(w.movable, "toastPoints", old.toastPoints)
      w.movable.points = old.points or w.movable.points or {}
      copy(w.scaling, "enabled", old.enableScaling)
      copy(w.scaling, "modifierKey", old.scaleModifierKey)
      copy(w.scaling, "saveStrategy", old.saveScaleStrategy)
      w.scaling.scales = old.scales or w.scaling.scales or {}
      p.movableWindows = nil
    end

    if Self.db.profiles then
      for _, p in pairs(Self.db.profiles) do
        migrateProfile(p)
      end
    end
    if Self.db.profile then
      migrateProfile(Self.db.profile)
    end
  end,
  [6] = function()
    -- Toast moving and its saved position move up from windows.movable to the Windows level, and Zone Map
    -- scaling gets its own switch (defaulting on, since it was previously always active).
    local function migrateProfile(p)
      if not p or type(p) ~= "table" or type(p.windows) ~= "table" then return end
      local w = p.windows
      if type(w.movable) == "table" then
        -- A value saved under movable always wins: AceDB may already have copied a default into `windows`.
        if w.movable.moveToasts ~= nil then w.moveToasts = w.movable.moveToasts end
        if w.movable.toastPoints ~= nil then w.toastPoints = w.movable.toastPoints end
        w.movable.moveToasts = nil
        w.movable.toastPoints = nil
      end
      if rawget(w, "zoneMapScaling") == nil then w.zoneMapScaling = true end
      w.movable = type(w.movable) == "table" and w.movable or {}
      w.movable.points = w.movable.points or {}
      w.scaling = type(w.scaling) == "table" and w.scaling or {}
      w.scaling.scales = w.scaling.scales or {}
    end

    if Self.db.profiles then
      for _, p in pairs(Self.db.profiles) do
        migrateProfile(p)
      end
    end
    if Self.db.profile then
      migrateProfile(Self.db.profile)
    end
  end,
  [7] = function()
    -- Rename windows.moveToasts -> windows.movableToasts and windows.zoneMapScaling -> windows.scalingZoneMap.
    -- Only saved (raw) values are moved, so AceDB defaults never overwrite a user's choice.
    local function migrateProfile(p)
      if not p or type(p) ~= "table" or type(p.windows) ~= "table" then return end
      local w = p.windows
      if rawget(w, "moveToasts") ~= nil then
        w.movableToasts = rawget(w, "moveToasts")
        w.moveToasts = nil
      end
      if rawget(w, "zoneMapScaling") ~= nil then
        w.scalingZoneMap = rawget(w, "zoneMapScaling")
        w.zoneMapScaling = nil
      end
    end

    if Self.db.profiles then
      for _, p in pairs(Self.db.profiles) do
        migrateProfile(p)
      end
    end
    if Self.db.profile then
      migrateProfile(Self.db.profile)
    end
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

RESET_PROFILE_CONFIRM_POPUP = "SLACKHACKS_RESET_PROFILE_CONFIRM"
StaticPopupDialogs[RESET_PROFILE_CONFIRM_POPUP] = {
  text = "Are you sure you want to reset all SlackHacks settings for the current profile? This will wipe your profile settings and reset the addon (and may reload your UI).",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    resetCurrentProfileAndAddon()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
}

function notifyConfigReset()
  StaticPopup_Show(CONFIG_RESET_POPUP)
end

function promptResetProfile()
  StaticPopup_Show(RESET_PROFILE_CONFIRM_POPUP)
end

-- Resets the current profile and reinitializes the entire addon state.
-- If an error occurs during reinitialization, it falls back to reloading the UI.
function resetCurrentProfileAndAddon()
  local ok, err = pcall(function()
    if Self.db then
      Self.db:ResetProfile()
      Self.db.global.configVersion = CONFIG_VERSION
      Self.db.global.addonVersion = getAddonVersion()
    end

    -- Reset addon state by disabling and re-enabling the addon and its modules
    Self:Disable()
    Self:Enable()

    local acr = LibStub("AceConfigRegistry-3.0", true)
    if acr then
      acr:NotifyChange("SlackHacks")
    end

    prn("profile and addon state have been reset to defaults.")
  end)

  if not ok then
    prn("error resetting addon (" .. tostring(err) .. "). Reloading UI...")
    ReloadUI()
  end
end

function hookResetProfileOption()
  if not (options and options.args and options.args.profiles and options.args.profiles.args) then
    return
  end
  local resetOpt = options.args.profiles.args.reset
  if resetOpt then
    resetOpt.func = function()
      promptResetProfile()
    end
    resetOpt.confirm = nil
  end
end

-- Resets the current profile back to defaults (leaves other profiles/characters alone, same as the
-- native AceDBOptions "Reset Profile" button) and informs the user via a popup.
function resetConfig(reason)
  log("Resetting SlackHacks config: " .. tostring(reason))
  if Self.db then
    Self.db:ResetProfile()
    Self.db.global.configVersion = CONFIG_VERSION
    Self.db.global.addonVersion = getAddonVersion()
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
    -- Purge all previous errors during a config migration
    if Self.db.global and Self.db.global.logs and Self.db.global.logs.error then
      wipe(Self.db.global.logs.error)
    end
    if updateMinimapIcon then
      updateMinimapIcon()
    elseif Self.UpdateMinimapIcon then
      Self.UpdateMinimapIcon()
    end
  end)
  if not ok then
    resetConfig(err)
  end
end

-- Checks if the addon version has changed since the last load.
-- If updated, purges all previous errors and updates the stored addon version for maintenance.
function checkAddonVersionUpdate()
  if not Self.db or not Self.db.global then return end
  local currentVersion = getAddonVersion()
  local lastVersion = Self.db.global.addonVersion

  if lastVersion ~= currentVersion then
    if Self.db.global.logs and Self.db.global.logs.error then
      wipe(Self.db.global.logs.error)
    end
    if updateMinimapIcon then
      updateMinimapIcon()
    elseif Self.UpdateMinimapIcon then
      Self.UpdateMinimapIcon()
    end
  end

  Self.db.global.addonVersion = currentVersion
end

--Event Handlers
function Self:OnInitialize()
  -- true = share one "Default" profile across all characters instead of a per-character profile
  local ok, err = pcall(function()
    Self.db = LibStub("AceDB-3.0"):New("SlackHacksDB", dbDefaults, true)
  end)
  if not ok or not Self.db then
    -- Saved variables were corrupted/unreadable: wipe and recreate from defaults rather than erroring out.
    prn("failed to load saved settings (" .. tostring(err) .. "), resetting to defaults.")
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
  Self:RegisterChatCommand("slackhacks", handleSlashCommand)

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