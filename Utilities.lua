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
  self:ApplySparkles()
end

--- Observes profile changes so command registration follows the active profile.
function module:OnInitialize()
  Self.db.RegisterCallback(self, "OnProfileChanged", "ApplyAll")
  Self.db.RegisterCallback(self, "OnProfileCopied", "ApplyAll")
  Self.db.RegisterCallback(self, "OnProfileReset", "ApplyAll")
  self:InitializeSparkles()
end

--- Registers the command when opted in, yielding if TomTom or another addon loads later.
function module:OnEnable()
  self:RegisterEvent("ADDON_LOADED", "ApplyAll")
  self:ApplyAll()
  self:EnableSparkles()
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

local LOOT_CVAR = "outlineModeShowLootEffectWhenDisabled"
local WANTED = "1"
local DISABLED = "0"
local watchedCVars = {
  graphicsquality = true,
  raidgraphicsquality = true,
  [LOOT_CVAR:lower()] = true
}

local settings
local sparkleWasEnabled
local applyingCVar = false
local applyAfterCombat = false
local applyAt

--- Reads a CVar without raising an error when the client does not expose it.
---@param name string CVar name.
---@return string|nil value Current value, or nil if unavailable.
local function readCVar(name)
  local getter = C_CVar and C_CVar.GetCVar or GetCVar
  if type(getter) ~= "function" then return nil end
  local ok, value = pcall(getter, name)
  if ok and type(value) == "string" then return value end
end

--- Sets a CVar only when the client reports a different current value.
---@param name string CVar name.
---@param value string Desired value.
local function writeCVar(name, value)
  if not C_CVar or type(C_CVar.GetCVar) ~= "function" or type(C_CVar.SetCVar) ~= "function" then return end
  local current = readCVar(name)
  if current == nil or current == value then return end
  pcall(C_CVar.SetCVar, name, value)
end

--- Applies the quest-item sparkle setting, deferring enable writes during combat.
local function applyQuestSparkles()
  if not settings then return end
  if settings.questItems then
    if InCombatLockdown() then
      applyAfterCombat = true
      return
    end
    applyingCVar = true
    writeCVar(LOOT_CVAR, WANTED)
    applyingCVar = false
  else
    applyAfterCombat = false
    if applyAt then
      applyAt = nil
      module.applyTimer:Hide()
    end
    applyingCVar = true
    writeCVar(LOOT_CVAR, DISABLED)
    applyingCVar = false
    if sparkleWasEnabled then
      print("|cffff8000SlackHacks:|r restart the game to remove quest-item sparkles. /reload is not enough.")
    end
  end
end

--- Schedules a delayed CVar re-apply after a graphics preset change.
---@param delay number Seconds to wait.
local function scheduleApply(delay)
  applyAt = GetTime() + delay
  module.applyTimer:Show()
end

--- Reads whether quest-item sparkles are enabled in the active profile.
---@return boolean enabled True when the quest sparkle option is enabled.
function module:IsQuestSparklesEnabled()
  return isForever() and settings ~= nil and settings.questItems == true
end

--- Updates the quest-item sparkle option and applies it to the client.
---@param enabled boolean Whether to show quest-item sparkles.
function module:SetQuestSparklesEnabled(enabled)
  if not isForever() or not settings then return end
  settings.questItems = enabled == true
  if settings.questItems then sparkleWasEnabled = true end
  applyQuestSparkles()
end

--- Refreshes loot effects and native soft-target behavior after a profile change.
function module:ApplySparkles()
  if not isForever() then return end
  settings = Self.db.profile.utilities.lootSparkles
  if settings.questItems == nil then settings.questItems = false end
  if settings.sparkleOre == nil then settings.sparkleOre = false end
  if settings.sparkleHerbs == nil then settings.sparkleHerbs = false end
  if settings.sparkleQuest == nil then settings.sparkleQuest = false end
  if settings.showNodeNames == nil then settings.showNodeNames = false end
  if settings.questItems then sparkleWasEnabled = true end
  self:InitializeSoftTarget(settings, Self.db.global)
  applyQuestSparkles()
  self:RefreshSoftTarget(false)
  self:UpdateSoftTargetPoller()
end

--- Changes one soft-target category option and refreshes the targeting CVars.
---@param key string Soft-target category setting key.
---@param enabled boolean Whether that native soft-target category is enabled.
function module:SetSoftTargetOption(key, enabled)
  if not isForever() or not settings then return end
  settings[key] = enabled == true
  self:RefreshSoftTarget(settings[key])
  self:UpdateSoftTargetPoller()
end

--- Initializes profile settings and listens for profile lifecycle changes.
function module:InitializeSparkles()
  if not isForever() then return end
  settings = Self.db.profile.utilities.lootSparkles
  if settings.questItems == nil then settings.questItems = false end
  sparkleWasEnabled = settings.questItems == true
  self:InitializeSoftTarget(settings, Self.db.global)
end

--- Registers client events and starts delayed CVar application.
function module:EnableSparkles()
  if not isForever() or not settings then return end
  self.applyTimer = CreateFrame("Frame")
  self.applyTimer:Hide()
  --- Re-applies quest sparkles after a delayed reset.
  ---@param frame table Update frame.
  self.applyTimer:SetScript("OnUpdate", function(frame)
    if applyAt and GetTime() >= applyAt then
      frame:Hide()
      applyAt = nil
      applyQuestSparkles()
    end
  end)

  --- Applies quest sparkles on login and retries after a graphics preset update.
  self:RegisterEvent("PLAYER_LOGIN", function()
    applyQuestSparkles()
    scheduleApply(5)
  end)
  --- Re-applies a deferred CVar change when combat ends.
  self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if applyAfterCombat then
      applyAfterCombat = false
      applyQuestSparkles()
    end
  end)
  --- Schedules a delayed apply when a relevant client CVar changes.
  ---@param event string Event name.
  ---@param cvar string|nil Updated CVar name.
  self:RegisterEvent("CVAR_UPDATE", function(event, cvar)
    if not applyingCVar and type(cvar) == "string" and watchedCVars[cvar:lower()] then
      scheduleApply(1)
    end
  end)
end

-- Blizzard soft-target selection and optional node-name labels
local TARGET_UNIT = "softinteract"
local TARGET_RANGE = 60
local TARGET_ARC = 2
local UPDATE_INTERVAL = 0.12
local CATEGORY_SETTING = {
  ore = "sparkleOre",
  herb = "sparkleHerbs",
  quest = "sparkleQuest"
}
local CURSOR_TYPES = {
  Mine = "ore",
  GatherHerbs = "herb",
  Quest = "quest",
  QuestRepeatable = "quest",
  QuestTurnIn = "quest"
}
local CURSOR_WORDS = {
  { "gather", "herb" },
  { "mine", "ore" },
  { "quest", "quest" }
}
local MANAGED_CVARS = {
  "SoftTargetInteract",
  "SoftTargetNameplateInteract",
  "SoftTargetInteractRange",
  "SoftTargetInteractArc",
  "SoftTargetInteractOnlyInRange",
  "SoftTargetIconGameObject"
}
local NODE_NAME_OFFSET = 28

local categorySettings
local globalSettings
local originalCVars
local targetGateOpen
local pendingCVars
local pendingForce
local directTargetPlateWorks = false
local shownPlates = {}
local cursorTypeByID = {}
local objectiveText = {}
local objectivesNeedRefresh = true
local targetName = {}

--- Returns whether a client value is secret and cannot safely be inspected.
---@param value any Client-returned value.
---@return boolean secret True if the client marks the value secret.
local function isSecret(value)
  return issecretvalue ~= nil and issecretvalue(value)
end

--- Calls a client API while treating errors and secret results as unavailable.
---@param func function|nil Client API function.
---@param ... any Arguments passed to the function.
---@return any result First return value when it is safe to read.
local function safeCall(func, ...)
  if type(func) ~= "function" then return nil end
  local ok, result = pcall(func, ...)
  if not ok or isSecret(result) then return nil end
  return result
end

--- Reads a CVar while tolerating CVars not exposed by the current client.
---@param name string CVar name.
---@return string|nil value Current value, or nil when unavailable.
local function readCVar(name)
  if not C_CVar or type(C_CVar.GetCVar) ~= "function" then return nil end
  local ok, value = pcall(C_CVar.GetCVar, name)
  if ok and type(value) == "string" then return value end
end

--- Changes a CVar only when necessary to avoid redundant client notifications.
---@param name string CVar name.
---@param value string|number Desired value.
local function writeCVar(name, value)
  if not C_CVar or type(C_CVar.SetCVar) ~= "function" then return end
  local current = readCVar(name)
  value = tostring(value)
  if current == nil or current == value then return end
  pcall(C_CVar.SetCVar, name, value)
end

--- Returns whether any native soft-target category or node-name feature is enabled.
---@return boolean active True when soft-target features should run.
local function hasActiveCategory()
  if not categorySettings then return false end
  if categorySettings.showNodeNames == true then return true end
  for _, key in pairs(CATEGORY_SETTING) do
    if categorySettings[key] == true then return true end
  end
  return false
end

--- Captures the original CVar values and enables Blizzard soft targeting.
---@param force boolean|nil Whether to ensure the interact key and object icons are on.
local function enableSoftTarget(force)
  if InCombatLockdown() then
    pendingCVars = "apply"
    pendingForce = pendingForce or force == true
    return
  end

  if not originalCVars then
    originalCVars = {}
    if globalSettings then globalSettings.lootSparklesSavedCVars = originalCVars end
  end
  if originalCVars.SoftTargetInteract == nil or originalCVars.SoftTargetIconGameObject == nil then
    force = true
  end
  for _, name in ipairs(MANAGED_CVARS) do
    if originalCVars[name] == nil then
      originalCVars[name] = readCVar(name) or false
    end
  end
  if force then
    writeCVar("SoftTargetInteract", 3)
    writeCVar("SoftTargetIconGameObject", 1)
  end
  writeCVar("SoftTargetInteractRange", TARGET_RANGE)
  writeCVar("SoftTargetInteractArc", TARGET_ARC)
  writeCVar("SoftTargetInteractOnlyInRange", 0)
  targetGateOpen = nil
  module:EvaluateSoftTarget()
end

--- Restores the CVar values saved before soft targeting was enabled.
local function restoreSoftTarget()
  if InCombatLockdown() then
    pendingCVars = "restore"
    return
  end
  if not originalCVars then return end
  for name, value in pairs(originalCVars) do
    if value ~= false then writeCVar(name, value) end
  end
  originalCVars = nil
  if globalSettings then globalSettings.lootSparklesSavedCVars = nil end
  targetGateOpen = nil
end

--- Sets the game's interaction-target nameplate visibility outside combat.
---@param open boolean Whether the target nameplate should be displayed.
local function setTargetGate(open)
  if open == targetGateOpen or InCombatLockdown() then return end
  targetGateOpen = open
  writeCVar("SoftTargetNameplateInteract", open and 1 or 0)
end

--- Normalizes quest and object text for objective-name comparisons.
---@param text string Text to normalize.
---@return string normalized Lowercase text without progress counters.
local function normalizeText(text)
  text = text:lower():gsub("\194\160", " ")
  text = text:gsub("\226\128\153", "'")
  text = text:gsub("%d+%s*/%s*%d+", "")
  return text:gsub("^[%s:%-]+", ""):gsub("[%s:%-]+$", "")
end

--- Rebuilds the cache of unfinished quest objectives.
local function refreshObjectiveText()
  objectivesNeedRefresh = false
  wipe(objectiveText)
  if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return end

  local modernAPI = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetQuestIDForLogIndex
  local countGetter = modernAPI and C_QuestLog.GetNumQuestLogEntries or GetNumQuestLogEntries
  local count = safeCall(countGetter) or 0
  for index = 1, count do
    local questID
    if modernAPI then
      questID = safeCall(C_QuestLog.GetQuestIDForLogIndex, index)
    elseif GetQuestLogTitle then
      local ok, _, _, _, isHeader, _, _, _, id = pcall(GetQuestLogTitle, index)
      if ok and not isHeader then questID = id end
    end
    local objectives = type(questID) == "number"
      and safeCall(C_QuestLog.GetQuestObjectives, questID)
    if type(objectives) == "table" then
      for _, objective in ipairs(objectives) do
        if not objective.finished and type(objective.text) == "string" and not isSecret(objective.text) then
          local text = normalizeText(objective.text)
          if #text >= 4 then objectiveText[#objectiveText + 1] = text end
        end
      end
    end
  end
end

--- Checks if an object's display name is contained in an unfinished objective.
---@param name string|nil Object name.
---@return boolean matches True when the name matches a current objective.
local function matchesObjective(name)
  if type(name) ~= "string" or #name < 4 then return false end
  if objectivesNeedRefresh then refreshObjectiveText() end
  name = normalizeText(name)
  for _, text in ipairs(objectiveText) do
    if text:find(name, 1, true) or (#text >= 5 and name:find(text, 1, true)) then
      return true
    end
  end
  return false
end

--- Identifies quest-related units using quest APIs, tooltip data, or objective text.
---@param unit string Unit token.
---@param name string|nil Unit name.
---@return boolean related True when the unit is part of an active quest.
local function isQuestUnit(unit, name)
  if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
    and safeCall(C_QuestLog.UnitIsRelatedToActiveQuest, unit) == true then
    return true
  end
  local questLine = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective
  if questLine and C_TooltipInfo and C_TooltipInfo.GetUnit then
    local data = safeCall(C_TooltipInfo.GetUnit, unit)
    if data and type(data.lines) == "table" then
      for _, line in ipairs(data.lines) do
        if line.type == questLine then return true end
      end
    end
  end
  return matchesObjective(name)
end

--- Resolves a cursor texture or atlas name to an object category.
---@param value any Cursor texture or atlas identifier.
---@return string|nil category Matching category, if recognized.
---@return boolean unavailable True when the cursor indicates interaction is unavailable.
local function classifyCursorName(value)
  if type(value) ~= "string" then return nil, false end
  local name = value:lower()
  local unavailable = name:find("unable", 1, true) ~= nil
  for _, item in ipairs(CURSOR_WORDS) do
    if name:find(item[1], 1, true) then return item[2], unavailable end
  end
  return nil, unavailable
end

--- Reads a unit's cursor and maps it to ore, herb, quest, or another category.
---@param unit string Unit token.
---@param name string|nil Unit name.
---@return string|nil category Recognized object category.
---@return boolean unavailable True if its interaction cursor is greyed out.
local function classifyUnit(unit, name)
  local category, unavailable
  if safeCall(SetUnitCursorTexture, module.cursorProbe, unit, nil, true) then
    local texture = module.cursorProbe:GetTexture()
    local atlas = module.cursorProbe.GetAtlas and module.cursorProbe:GetAtlas()
    if isSecret(texture) then texture = nil end
    if isSecret(atlas) then atlas = nil end
    local known = type(texture) == "number" and cursorTypeByID[texture]
    if known then
      category, unavailable = known.category, known.unavailable
    else
      category, unavailable = classifyCursorName(texture)
      if not category then
        local atlasCategory, atlasUnavailable = classifyCursorName(atlas)
        category = atlasCategory
        unavailable = unavailable or atlasUnavailable
      end
    end
  end
  if category ~= "ore" and category ~= "herb" and isQuestUnit(unit, name) then
    category = "quest"
  end
  return category, unavailable == true
end

--- Returns the nameplate currently associated with a unit.
---@param unit string Unit token.
---@return table|nil plate Blizzard nameplate frame, when available.
local function getNameplate(unit)
  return C_NamePlate and safeCall(C_NamePlate.GetNamePlateForUnit, unit)
end

--- Determines whether a soft-interaction unit exists, including game objects.
---@return boolean|nil exists True/false, or nil when the client value is secret.
local function softTargetExists()
  local unitExists = safeCall(UnitExists, TARGET_UNIT)
  local objectExists = safeCall(UnitIsGameObject, TARGET_UNIT)
  if unitExists == true or objectExists == true then return true end
  if unitExists == false and objectExists == false then return false end
end

--- Resolves the soft target and its nameplate, searching visible plates if needed.
---@return string|nil unit Unit token.
---@return table|nil plate Target's nameplate.
---@return boolean unknown Whether the target's existence could not be determined.
local function resolveSoftTarget()
  local exists = softTargetExists()
  if exists == false then return nil end
  local plate = getNameplate(TARGET_UNIT)
  if plate then
    if not directTargetPlateWorks and safeCall(UnitIsGameObject, TARGET_UNIT) == true then
      directTargetPlateWorks = true
    end
    return TARGET_UNIT, plate
  end
  if not directTargetPlateWorks then
    for unit in pairs(shownPlates) do
      if safeCall(UnitIsGameObject, unit) == true or safeCall(UnitIsUnit, unit, TARGET_UNIT) == true then
        plate = getNameplate(unit)
        if plate then return unit, plate end
      end
    end
  end
  if exists then return TARGET_UNIT end
  return nil, nil, true
end

--- Hides and detaches the node-name label from its current target.
local function clearNodeName()
  if not targetName.anchor then return end
  targetName.frame:Hide()
  targetName.frame:ClearAllPoints()
  targetName.frame:SetParent(nil)
  targetName.anchor = nil
end

--- Displays a node's name above its current soft-target nameplate.
---@param plate table Target nameplate.
---@param name string Node name.
local function showNodeName(plate, name)
  if not targetName.frame then
    local frame = CreateFrame("Frame")
    frame:SetSize(220, 20)
    local text = frame:CreateFontString(nil, "OVERLAY")
    if GameFontNormalSmall then
      text:SetFontObject(GameFontNormalSmall)
    elseif GameFontNormal then
      text:SetFontObject(GameFontNormal)
    end
    text:SetAllPoints(frame)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 0.88, 0.52)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    targetName.frame = frame
    targetName.text = text
  end

  local frame = targetName.frame
  if targetName.anchor ~= plate then
    frame:SetParent(plate)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", plate, "TOP", 0, NODE_NAME_OFFSET)
    local ok, level = pcall(plate.GetFrameLevel, plate)
    if ok and level and not isSecret(level) then frame:SetFrameLevel(level + 2) end
    frame:SetIgnoreParentAlpha(true)
    targetName.anchor = plate
  end
  if targetName.text:GetText() ~= name then
    targetName.text:SetText(name)
  end
  frame:Show()
end

--- Finds the current soft target and updates Blizzard's target gate and optional label.
function module:EvaluateSoftTarget()
  if not isForever() or not hasActiveCategory() then
    clearNodeName()
    return
  end
  local unit, plate, unknown = resolveSoftTarget()
  if not unit then
    setTargetGate(unknown == true)
    clearNodeName()
    return
  end

  local category, unavailable, name
  if safeCall(UnitIsGameObject, unit) == true then
    name = safeCall(UnitName, unit)
    category, unavailable = classifyUnit(unit, name)
  else
    setTargetGate(false)
    clearNodeName()
    return
  end

  local key = CATEGORY_SETTING[category]
  local wanted = key ~= nil and categorySettings[key] == true
  local showName = category ~= nil and categorySettings.showNodeNames == true
    and type(name) == "string" and name ~= ""
  setTargetGate(wanted or showName)
  if unavailable then
    setTargetGate(false)
    clearNodeName()
    return
  end
  if not plate then
    clearNodeName()
    return
  end

  if showName then
    showNodeName(plate, name)
  else
    clearNodeName()
  end
end

--- Applies or restores the native soft-target CVars according to enabled categories.
---@param force boolean|nil Whether enabling a category should turn on interact options.
function module:RefreshSoftTarget(force)
  if not isForever() then return end
  if hasActiveCategory() then
    enableSoftTarget(force == true)
  else
    clearNodeName()
    restoreSoftTarget()
  end
end

--- Enables or pauses the periodic target-state poller.
function module:UpdateSoftTargetPoller()
  if module.targetPoller then module.targetPoller:SetShown(isForever() and hasActiveCategory()) end
end

--- Installs profile settings, saved CVar storage, and cursor texture lookups.
---@param profileSettings table Active profile's loot sparkle options.
---@param accountSettings table Global AceDB data.
function module:InitializeSoftTarget(profileSettings, accountSettings)
  if not isForever() then return end
  categorySettings = profileSettings
  if categorySettings.showNodeNames == nil then categorySettings.showNodeNames = false end
  globalSettings = accountSettings
  originalCVars = globalSettings.lootSparklesSavedCVars

  if not module.cursorProbe then
    module.cursorProbe = UIParent:CreateTexture(nil, "BACKGROUND")
    module.cursorProbe:Hide()
  end
  if GetFileIDFromPath and not next(cursorTypeByID) then
    for name, category in pairs(CURSOR_TYPES) do
      for _, prefix in ipairs({ "", "Unable" }) do
        local path = "Interface\\Cursor\\" .. prefix .. name
        local id = safeCall(GetFileIDFromPath, path) or safeCall(GetFileIDFromPath, path .. ".blp")
        if id then cursorTypeByID[id] = { category = category, unavailable = prefix ~= "" } end
      end
    end
  end
end

--- Applies pending CVar changes when combat ends.
local function handleCombatEnd()
  if pendingCVars == "apply" then
    enableSoftTarget(pendingForce)
  elseif pendingCVars == "restore" then
    restoreSoftTarget()
  end
  pendingCVars, pendingForce = nil, false
  module:EvaluateSoftTarget()
end

--- Marks quest objective text stale after the quest log changes.
local function handleQuestUpdate()
  objectivesNeedRefresh = true
end

--- Registers target/nameplate events and starts the polling frame.
local softTargetEvents = CreateFrame("Frame")
--- Dispatches target events to the evaluator and CVar manager.
---@param _ table Event frame.
---@param event string WoW event name.
---@param ... any Event arguments.
softTargetEvents:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "VARIABLES_LOADED" then
    if hasActiveCategory() then enableSoftTarget(false) end
    module:UpdateSoftTargetPoller()
  elseif event == "PLAYER_REGEN_DISABLED" then
    if hasActiveCategory() then setTargetGate(false) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    handleCombatEnd()
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    shownPlates[(...)] = true
    module:EvaluateSoftTarget()
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local unit = ...
    shownPlates[unit] = nil
    local plate = getNameplate(unit)
    if plate and plate == targetName.anchor then clearNodeName() end
  elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
    module:EvaluateSoftTarget()
  elseif event == "QUEST_LOG_UPDATE" then
    handleQuestUpdate()
  end
end)

--- Registers one target event when supported by the current client.
---@param event string WoW event name.
local function registerTargetEvent(event)
  pcall(softTargetEvents.RegisterEvent, softTargetEvents, event)
end

if isForever() then
  for _, event in ipairs({
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "VARIABLES_LOADED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_SOFT_INTERACT_CHANGED",
    "QUEST_LOG_UPDATE"
  }) do
    registerTargetEvent(event)
  end
end

--- Creates the periodic target evaluator and refreshes it on each frame update.
module.targetPoller = CreateFrame("Frame")
module.targetPoller:Hide()
local elapsedSinceCheck = 0
--- Runs the target evaluator at a bounded interval.
---@param _ table Poller frame.
---@param elapsed number Time elapsed since the previous frame.
module.targetPoller:SetScript("OnUpdate", function(_, elapsed)
  if not isForever() then return end
  elapsedSinceCheck = elapsedSinceCheck + elapsed
  if elapsedSinceCheck >= UPDATE_INTERVAL then
    elapsedSinceCheck = 0
    module:EvaluateSoftTarget()
  end
end)
