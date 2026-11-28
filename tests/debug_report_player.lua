-- Run with Lua 5.1 from the addon root: lua tests/debug_report_player.lua
local forever = false
SlackHacks = setmetatable({ db = { global = { logs = {
  errorLoggingEnabled = true, error = { { message = "test" } },
} } } }, { __index = _G })
SlackHacks.Self = SlackHacks
--- Create the Debug module without the game UI.
---@return table module
function SlackHacks:NewModule() return {} end
--- Report whether addon initialization has completed.
---@return boolean initialized
function SlackHacks.isInitialized() return true end
--- Report the simulated client flavor.
---@return boolean forever
function SlackHacks.isForever() return forever end
--- Report whether this is the Retail client.
---@return boolean retail
function SlackHacks.isRetail() return not forever end
--- Supply unused group-icon markup when Core.lua loads.
---@return string markup
function CreateAtlasMarkup() return "" end
--- Supply the addon version.
---@return string version
function SlackHacks.getAddonVersion() return "test" end
--- Supply the reporting character name.
---@return string name
function UnitName() return "Aster" end
--- Supply the first and last name returned by Forever.
---@param unit string Unit token.
---@return string first, string last
function UnitFullName(unit)
  assert(unit == "player")
  return "Aster", "Dawn"
end
--- Supply a Retail realm and reject realm access on Forever.
---@return string realm
function GetRealmName()
  assert(not forever, "Forever reports must not read the player's realm")
  return "Realm"
end
--- Report that secure actions are not locked down.
---@return boolean combat
function InCombatLockdown() return false end
date = os.date
StaticPopupDialogs = {}
local sentPayload
--- Capture the structured report before transmission.
---@param payload table Report data.
---@return string serialized
function SlackHacks:Serialize(payload) sentPayload = payload; return "payload" end
--- Accept the report without completing the queued send.
function SlackHacks:SendCommMessage() end

assert(loadfile("Core.lua"))()
assert(loadfile("Debug.lua"))()
local debugModule = SlackHacks.Debug
debugModule:ReportErrorLogs("guild", "Target")
assert(sentPayload.sender == "Aster-Realm")
assert(debugModule:BuildMarkdown():find("**Player**: `Aster-Realm`", 1, true))
forever = true
debugModule:ReportErrorLogs("guild", "Target")
assert(sentPayload.sender == "Aster Dawn")
assert(debugModule:BuildMarkdown():find("**Player**: `Aster Dawn`", 1, true))

print("Debug report player tests passed")
