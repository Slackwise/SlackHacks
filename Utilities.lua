setfenv(1, _G.SlackHacks)

local module = Self:NewModule("Utilities", "AceEvent-3.0", "AceConsole-3.0")
Self.Utilities = module

local commandRegistered = false
local commandHandler
local USAGE = "Usage: /way [#mapID or zone name] x y [description]. Coordinates must be between 0 and 100."

--- Reports whether the client supports native user waypoints.
---@return boolean supported Whether the required native APIs are available.
function module:SupportsWaypoints()
  return C_Map and type(C_Map.SetUserWaypoint) == "function"
    and type(C_Map.CanSetUserWaypointOnMap) == "function"
    and UiMapPoint and type(UiMapPoint.CreateFromCoordinates) == "function"
    and C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" or false
end

--- Converts a coordinate token, accepting decimal commas and a trailing separator.
---@param token string A single command argument.
---@return number|nil coordinate The parsed percentage, or nil for non-numeric text.
local function coordinate(token)
  return tonumber((token:gsub("[,;]$", ""):gsub(",", ".")))
end

--- Resolves a zone name or explicit map ID without silently choosing an ambiguous zone.
---@param zone string|nil Zone name, #mapID, or nil for the player's current map.
---@return number|nil mapID The resolved UI map ID.
---@return string|nil reason An explanation when resolution fails.
local function resolveMap(zone)
  local currentMap = C_Map.GetBestMapForUnit("player")
  if not zone then
    if currentMap then return currentMap end
    return nil, "Your current map is unavailable. Use /way #mapID x y instead."
  end
  local explicitID = zone:match("^#(%d+)$")
  if explicitID then
    local mapID = tonumber(explicitID)
    if C_Map.GetMapInfo(mapID) then return mapID end
    return nil, "Unknown map ID: " .. explicitID .. "."
  end

  local name = zone:lower()
  local exact, partial = {}, {}
  -- The cosmic map includes zones on other continents, not just children of the current continent.
  local maps = C_Map.GetMapChildrenInfo(946, nil, true)
  if not maps then return nil, "Map data is unavailable. Use #mapID instead." end
  for _, map in ipairs(maps) do
    local mapName = map.name:lower()
    if mapName == name then
      exact[map.mapID] = true
    elseif mapName:find(name, 1, true) then
      partial[map.mapID] = true
    end
  end
  local matches = next(exact) and exact or partial
  if exact[currentMap] then return currentMap end
  local mapID = next(matches)
  if not mapID then return nil, "Unknown zone '" .. zone .. "'. Use #mapID instead." end
  if next(matches, mapID) then
    return nil, "Zone '" .. zone .. "' is ambiguous. Use #mapID instead."
  end
  return mapID
end

--- Parses the waypoint-creation subset of TomTom's /way syntax.
---@param input string Command arguments, without /way.
---@return table|nil waypoint Map ID, normalized coordinates, and optional description.
---@return string|nil reason An explanation when the input cannot create a waypoint.
function module:ParseWaypoint(input)
  local tokens = {}
  for token in input:gmatch("%S+") do tokens[#tokens + 1] = token end
  local firstCoordinate
  for index, token in ipairs(tokens) do
    if coordinate(token) then
      firstCoordinate = index
      break
    end
  end
  if not firstCoordinate or not tokens[firstCoordinate + 1] then return nil, USAGE end
  local x, y = coordinate(tokens[firstCoordinate]), coordinate(tokens[firstCoordinate + 1])
  if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then return nil, USAGE end
  local zone = firstCoordinate > 1 and table.concat(tokens, " ", 1, firstCoordinate - 1) or nil
  local mapID, reason = resolveMap(zone)
  if not mapID then return nil, reason end
  return {
    mapID = mapID,
    x = x / 100,
    y = y / 100,
    description = table.concat(tokens, " ", firstCoordinate + 2),
  }
end

--- Creates and tracks a native waypoint, reporting unsupported maps or invalid input.
---@param input string Command arguments, without /way.
function module:HandleWay(input)
  -- The profile can change between command registration and invocation.
  if not self:IsEnabled() or not db.profile.utilities.tomtomWayCommand then
    prn("Enable Utilities > TomTom |cffffd100/way|r Command to use this command.")
    return
  end
  if not self:SupportsWaypoints() then
    prn("Native map pins are not supported by this client.")
    return
  end
  local waypoint, reason = self:ParseWaypoint(input)
  if not waypoint then
    prn(reason)
    return
  end
  if not C_Map.CanSetUserWaypointOnMap(waypoint.mapID) then
    prn("Native map pins cannot be placed on map #" .. waypoint.mapID .. ".")
    return
  end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(waypoint.mapID, waypoint.x, waypoint.y))
  C_SuperTrack.SetSuperTrackedUserWaypoint(true)
  -- Native user waypoints have no custom-title field; retain the guide's label in the confirmation.
  prn("Map pin set on map #" .. waypoint.mapID ..
    (waypoint.description ~= "" and (": " .. waypoint.description) or "."))
end

--- Reports whether another addon has registered /way.
---@return boolean claimed Whether /way belongs to another addon.
local function wayCommandClaimed()
  for key, value in pairs(_G) do
    if type(key) == "string" and key:match("^SLASH_.+%d+$")
      and type(value) == "string" and not (_G.issecretvalue and _G.issecretvalue(value))
      and value:lower() == "/way"
      and not (commandRegistered and key == "SLASH_ACECONSOLE_WAY1"
        and SlashCmdList.ACECONSOLE_WAY == commandHandler) then
      return true
    end
  end
  return false
end

--- Updates command ownership after option, profile, or addon-load changes.
function module:ApplyAll()
  local claimed = wayCommandClaimed()
  local listen = self:IsEnabled() and db.profile.utilities.tomtomWayCommand
    and self:SupportsWaypoints() and not claimed
  if listen and not commandRegistered then
    self:RegisterChatCommand("way", "HandleWay")
    commandRegistered = true
    commandHandler = SlashCmdList.ACECONSOLE_WAY
  elseif not listen and commandRegistered then
    -- Another AceConsole user can replace the same command key; don't unregister their handler.
    if SlashCmdList.ACECONSOLE_WAY == commandHandler then self:UnregisterChatCommand("way") end
    commandRegistered = false
    commandHandler = nil
  end
end

--- Observes profile changes so command registration follows the active profile.
function module:OnInitialize()
  Self.db.RegisterCallback(self, "OnProfileChanged", "ApplyAll")
  Self.db.RegisterCallback(self, "OnProfileCopied", "ApplyAll")
  Self.db.RegisterCallback(self, "OnProfileReset", "ApplyAll")
end

--- Registers the command when opted in, yielding if TomTom or another addon loads later.
function module:OnEnable()
  self:RegisterEvent("ADDON_LOADED", "ApplyAll")
  self:ApplyAll()
end

--- Removes this module's command and addon-load listener.
function module:OnDisable()
  self:UnregisterAllEvents()
  if commandRegistered then
    if SlashCmdList.ACECONSOLE_WAY == commandHandler then self:UnregisterChatCommand("way") end
    commandRegistered = false
    commandHandler = nil
  end
end
