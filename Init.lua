--INITIALIZE
local Self = LibStub("AceAddon-3.0"):NewAddon(
  "SlackHacks",
  "AceConsole-3.0",
  "AceEvent-3.0"
)
Self.config = LibStub("AceConfig-3.0")
Self.frame = CreateFrame("Frame", "SlackHacks")
Self.itemBindingFrame = CreateFrame("Frame", "SlackHacks Item Bindings")
_G.SlackHacks = Self
Self.Self = Self
setmetatable(Self, {__index = _G}) -- The global environment is now checked if a key is not found in addon
setfenv(1, Self) -- Namespace local to addon

addonName, addonTable = ...

dbDefaults = {
  global = {
    isDebugging = false,
    log = {}
  },
  profile = {
    mounts = {
      ["ground"] = nil,
      ["ground-showoff"] = nil,
      ["skyriding"] = nil,
      ["skyriding-showoff"] = nil,
      ["steadyflight"] = nil,
      ["steadyflight-showoff"] = nil,
      ["water"] = nil,
      ["water-showoff"] = nil,
      ["ground-passenger"] = nil,
      ["ground-passenger-showoff"] = nil,
      ["skyriding-passenger"] = nil,
      ["skyriding-passenger-showoff"] = nil,
      ["steadyflight-passenger"] = nil,
      ["steadyflight-passenger-showoff"] = nil,
    }
  }
}

function getBattletag()
  return select(2, BNGetInfo())
end

function isSlackwise()
  return getBattletag() == "Slackwise#1121" or false
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
  elseif isClassic() then
    return "CLASSIC"
  else
    return "UNKNOWN" -- Uh oh
  end
end

function isDebugging()
  if isInitialized() then
    return Self.db.global.isDebugging
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

function log(message, ...)
  if isDebugging() then
    print(grey(date()) .. "  " .. message)
    if isInitialized() then -- we have a DB to save to:
      table.insert(Self.db.global.log, date() .. "  " .. message)
      if arg then
        for i, v in ipairs(arg) do
          print("Arg " .. i .. " = " .. v)
          table.insert(Self.db.global.log, "Arg " .. i .. " = " .. v)
        end
      end
    end
  end
end

--Event Handlers
function Self:OnInitialize()
  Self.db = LibStub("AceDB-3.0"):New("SlackHacksDB", dbDefaults)
  config:RegisterOptionsTable("SlackHacks", options, "slack")
  Self.configDialog = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SlackHacks")

  -- Disabling ActionCam warning/confirmation popup: https://github.com/mpstark/DynamicCam/blob/master/Core.lua#L628C1-L629C68
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

function isInitialized()
  -- Check for presence of last thing loaded at init
  return not not Self["configDialog"]
end