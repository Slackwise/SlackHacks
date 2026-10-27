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

--- Normalizes zone names for TomTom-compatible case- and whitespace-insensitive matching.
---@param name string Zone name or search pattern.
---@return string normalized Lowercase text without whitespace.
local function normalizeZoneName(name)
  return (name:lower():gsub("%s", ""))
end

--- Returns the map category used by TomTom's named-zone lookup.
---@param map table Blizzard UI map metadata.
---@return number mapType The effective UIMapType.
local function namedMapType(map)
  -- Some legacy city, garrison, and world maps have misleading native categories.
  local types = Enum.UIMapType
  local corrections = {
    [101] = types.World, [572] = types.World, [625] = types.Orphan,
    [125] = types.Zone, [501] = types.Zone, [582] = types.Zone,
    [590] = types.Zone, [627] = types.Zone,
    [126] = types.Micro, [502] = types.Micro, [626] = types.Micro,
    [628] = types.Micro, [629] = types.Micro,
  }
  return corrections[map.mapID] or map.mapType
end

--- Returns a localized zone name with compatibility suffixes for legacy map variants.
---@param map table Blizzard UI map metadata.
---@return string name The name accepted by TomTom's zone lookup.
local function namedMapLabel(map)
  local id = map.mapID
  local suffix
  if id >= 195 and id <= 197 then suffix = tostring(id - 194)
  elseif id >= 579 and id <= 581 then suffix = tostring(id - 578)
  elseif id >= 585 and id <= 587 then suffix = tostring(id - 584)
  elseif id == 943 then suffix = FACTION_HORDE
  elseif id == 1044 then suffix = FACTION_ALLIANCE end
  return suffix and (map.name .. " " .. suffix) or map.name
end

--- Builds TomTom-compatible named maps, including legacy maps missing from the cosmic tree.
---@return table|nil names Map names (including Zone:Parent qualifiers) indexed to map IDs.
---@return string|nil reason Why map discovery failed.
local function namedMaps()
  local children = C_Map.GetMapChildrenInfo(946, nil, true)
  if not children then return nil, "Map data is unavailable. Use #mapID instead." end
  local maps = {}
  for _, map in ipairs(children) do maps[map.mapID] = map end
  local pending = {}
  for id in pairs(maps) do pending[#pending + 1] = id end
  local index = 1
  while index <= #pending do
    local id = pending[index]
    index = index + 1
    local groupID = C_Map.GetMapGroupID(id)
    if groupID then
      for _, member in ipairs(C_Map.GetMapGroupMembersInfo(groupID) or {}) do
        if not maps[member.mapID] then
          local map = C_Map.GetMapInfo(member.mapID)
          if map then
            maps[member.mapID] = map
            pending[#pending + 1] = member.mapID
            -- Group siblings can have floors/subzones missing from the original cosmic traversal.
            for _, child in ipairs(C_Map.GetMapChildrenInfo(member.mapID, nil, true) or {}) do
              if not maps[child.mapID] then
                maps[child.mapID] = child
                pending[#pending + 1] = child.mapID
              end
            end
          end
        end
      end
    end
  end
  -- HereBeDragons also probes IDs through 3000 to find maps omitted from the hierarchy.
  -- Keep that compatibility range, while the tree supplies newer maps above it.
  for id = 1, 3000 do
    if not maps[id] then maps[id] = C_Map.GetMapInfo(id) end
  end
  local groups = {}
  for _, map in pairs(maps) do
    local category = namedMapType(map)
    if map.name and (category == Enum.UIMapType.Zone or category == Enum.UIMapType.Continent
      or category == Enum.UIMapType.Micro) then
      local parent, visited = map, {}
      local hasWorld = false
      while parent and not visited[parent.mapID] do
        visited[parent.mapID] = true
        local parentType = namedMapType(parent)
        if parentType == Enum.UIMapType.World or parentType == Enum.UIMapType.Cosmic then
          hasWorld = true
        end
        parent = maps[parent.parentMapID] or C_Map.GetMapInfo(parent.parentMapID or 0)
      end
      if hasWorld then
        local name = namedMapLabel(map)
        groups[name] = groups[name] or {}
        groups[name][#groups[name] + 1] = map.mapID
      end
    end
  end
  local names = {}
  for name, ids in pairs(groups) do
    table.sort(ids)
    if #ids == 1 then
      names[name] = ids[1]
    else
      for _, id in ipairs(ids) do
        local parent = maps[maps[id].parentMapID] or C_Map.GetMapInfo(maps[id].parentMapID or 0)
        if parent and parent.name then
          local qualified = name .. ":" .. parent.name
          -- The lowest ID owns Zone:Parent; subsequent copies use Zone:mapID.
          if names[qualified] then qualified = name .. ":" .. id end
          names[qualified] = id
        end
      end
    end
  end
  return names
end

--- Resolves a zone name, partial Lua pattern, or explicit map ID using TomTom's lookup rules.
---@param zone string|nil Zone name, #mapID, or nil for the player's current map.
---@return number|nil mapID The resolved UI map ID.
---@return string|nil reason An explanation when resolution fails.
local function resolveMap(zone)
  if not zone then
    local currentMap = C_Map.GetBestMapForUnit("player")
    if currentMap then return currentMap end
    return nil, "Your current map is unavailable. Use /way #mapID x y instead."
  end
  local explicitID = zone:match("^#(%d+)$")
  if explicitID then
    local mapID = tonumber(explicitID)
    if C_Map.GetMapInfo(mapID) then return mapID end
    return nil, "Unknown map ID: " .. explicitID .. "."
  end

  local names, reason = namedMaps()
  if not names then return nil, reason end
  local search = normalizeZoneName(zone)
  for name, id in pairs(names) do
    if normalizeZoneName(name) == search then return id end
  end
  local matches = {}
  for name in pairs(names) do
    local ok, match = pcall(string.match, normalizeZoneName(name), search)
    if not ok then return nil, "Invalid zone-name pattern '" .. zone .. "'." end
    if match then matches[#matches + 1] = name end
  end
  if #matches == 0 then return nil, "Unknown zone '" .. zone .. "'. Use #mapID instead." end
  if #matches > 7 then
    return nil, "Found " .. #matches .. " possible matches for zone '" .. zone .. "'. Please be more specific."
  end
  if #matches > 1 then
    table.sort(matches)
    return nil, "Zone '" .. zone .. "' is ambiguous. Use #mapID or a qualified name: " ..
      table.concat(matches, ", ") .. "."
  end
  return names[matches[1]]
end

--- Parses the waypoint-creation subset of TomTom's /way syntax.
---@param input string Command arguments, without /way.
---@return table|nil waypoint Map ID, normalized coordinates, and optional description.
---@return string|nil reason An explanation when the input cannot create a waypoint.
function module:ParseWaypoint(input)
  -- TomTom accepts both decimal separators and punctuation followed by a space between coordinates.
  -- Normalize the complete input, including descriptions, before finding the first numeric token.
  local decimal = tonumber("1.1") and "." or ","
  local otherDecimal = decimal == "." and "," or "%."
  input = input:gsub("(%d)[%.,] (%d)", "%1 %2"):gsub("(%d)" .. otherDecimal .. "(%d)", "%1" .. decimal .. "%2")
  local tokens = {}
  for token in input:gmatch("%S+") do tokens[#tokens + 1] = token end
  local firstCoordinate
  for index, token in ipairs(tokens) do
    if tonumber(token) then
      firstCoordinate = index
      break
    end
  end
  if not firstCoordinate or not tokens[firstCoordinate + 1] then return nil, USAGE end
  local x, y = tonumber(tokens[firstCoordinate]), tonumber(tokens[firstCoordinate + 1])
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
    prn("Blizzard does not allow a native waypoint on map #" .. waypoint.mapID .. ".")
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
