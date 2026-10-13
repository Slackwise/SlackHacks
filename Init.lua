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

CONFIG_VERSION = 2

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
    end

    -- Reset addon state by disabling and re-enabling the addon and its modules
    Self:Disable()
    Self:Enable()

    local acr = LibStub("AceConfigRegistry-3.0", true)
    if acr then
      acr:NotifyChange("SlackHacks")
    end

    print("SlackHacks: profile and addon state have been reset to defaults.")
  end)

  if not ok then
    print("SlackHacks: error resetting addon (" .. tostring(err) .. "). Reloading UI...")
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