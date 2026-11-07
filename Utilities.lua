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
  return settings ~= nil and settings.questItems == true
end

--- Updates the quest-item sparkle option and applies it to the client.
---@param enabled boolean Whether to show quest-item sparkles.
function module:SetQuestSparklesEnabled(enabled)
  if not settings then return end
  settings.questItems = enabled == true
  if settings.questItems then sparkleWasEnabled = true end
  applyQuestSparkles()
end

--- Refreshes all sparkle behavior after a profile change.
function module:ApplySparkles()
  if not isForever() then return end
  settings = Self.db.profile.utilities.lootSparkles
  if settings.questItems == nil then settings.questItems = false end
  if settings.sparkleOre == nil then settings.sparkleOre = false end
  if settings.sparkleHerbs == nil then settings.sparkleHerbs = false end
  if settings.sparkleQuest == nil then settings.sparkleQuest = false end
  if settings.sparkleCorpseLoot == nil then settings.sparkleCorpseLoot = false end
  if settings.questItems then sparkleWasEnabled = true end
  self:InitializeSoftTarget(settings, Self.db.global)
  applyQuestSparkles()
  self:RefreshSoftTarget(false)
  self:UpdateSoftTargetPoller()
end

--- Changes one soft-target category option and refreshes the targeting CVars.
---@param key string Category setting key.
---@param enabled boolean Whether that category should sparkle.
function module:SetSoftTargetOption(key, enabled)
  if not settings then return end
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
  if not settings then return end
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

-- Soft-target approach sparkles
local TARGET_UNIT = "softinteract"
local SPARKLE_TEXTURE = "Interface\\Cooldown\\star4"
local TARGET_RANGE = 60
local TARGET_ARC = 2
local UPDATE_INTERVAL = 0.12
local CATEGORY_SETTING = {
  ore = "sparkleOre",
  herb = "sparkleHerbs",
  quest = "sparkleQuest",
  corpse = "sparkleCorpseLoot"
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
local GLINT_TOTAL = 7
local GLINT_SIZE = 34
local GLINT_RADIUS = 46
local PLATE_OFFSET = -45
local FADE_IN_TIME = 0.35
local STATE_BLEND_TIME = 0.3
local STABLE_TIME = 0.15
local LOCKED_STABLE_TIME = 0.6
local GOLD = { 1, 0.88, 0.52 }
local GREY = { 0.62, 0.62, 0.62 }

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
local targetSparkle = {}

local min, max = math.min, math.max
local pi = math.pi

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

--- Returns whether any approach-sparkle category is enabled.
---@return boolean active True when soft-target sparkles should run.
local function hasActiveCategory()
  if not categorySettings then return false end
  for _, key in pairs(CATEGORY_SETTING) do
    if categorySettings[key] == true then return true end
  end
  return false
end

--- Interpolates between two numeric values.
---@param from number Starting value.
---@param to number Target value.
---@param progress number Interpolation amount.
---@return number value Interpolated result.
local function interpolate(from, to, progress)
  return from + (to - from) * progress
end

--- Moves a number toward a target by at most the given amount.
---@param value number Starting value.
---@param target number Desired value.
---@param amount number Maximum step.
---@return number result Updated value.
local function approach(value, target, amount)
  if value < target then return min(value + amount, target) end
  return max(value - amount, target)
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

--- Restores the CVar values saved before soft-target sparkles were enabled.
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

--- Returns whether a corpse still has loot available to this character.
---@param unit string Unit token.
---@return boolean hasLoot True when the unit is dead and lootable.
local function corpseHasLoot(unit)
  local guid = safeCall(UnitGUID, unit)
  if not guid or not CanLootUnit then return false end
  local ok, hasLoot, canLoot = pcall(CanLootUnit, guid)
  if not ok or isSecret(hasLoot) or isSecret(canLoot) then return false end
  return safeCall(UnitIsDead, unit) == true and hasLoot == true and canLoot ~= false
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

--- Places one new glint within the sparkle cluster.
---@param glint table Glint animation data.
---@param startNow boolean|nil Whether to start at the visible part of its animation.
local function resetGlint(glint, startNow)
  local angle = math.random() * 2 * pi
  local distance = math.sqrt(math.random())
  glint.x = math.cos(angle) * distance * GLINT_RADIUS
  glint.y = math.sin(angle) * distance * GLINT_RADIUS * 0.75
  glint.life = 0.6 + 0.8 * math.random()
  glint.scale = 0.5 + 0.7 * math.random()
  glint.rotation = math.random() * 2 * pi
  glint.rotationSpeed = (math.random() - 0.5) * 2
  glint.age = startNow and 0 or -0.6 * math.random()
end

--- Updates sparkle glint positions, colors, and fade state.
---@param frame table Sparkle animation frame.
---@param elapsed number Time elapsed since the previous frame.
local function animateSparkles(frame, elapsed)
  elapsed = min(elapsed, 0.1)
  targetSparkle.opacity = approach(targetSparkle.opacity, 1, elapsed / FADE_IN_TIME)
  targetSparkle.readyBlend = approach(targetSparkle.readyBlend,
    targetSparkle.state == "ready" and 1 or 0, elapsed / STATE_BLEND_TIME)
  targetSparkle.lockBlend = approach(targetSparkle.lockBlend,
    targetSparkle.state == "locked" and 1 or 0, elapsed / STATE_BLEND_TIME)

  local ready, locked = targetSparkle.readyBlend, targetSparkle.lockBlend
  local opacity = targetSparkle.opacity * interpolate(0.55, 1, ready) * (1 - 0.55 * locked)
  local red = interpolate(GOLD[1], GREY[1], locked)
  local green = interpolate(GOLD[2], GREY[2], locked)
  local blue = interpolate(GOLD[3], GREY[3], locked)
  local speed = interpolate(0.8, 1.2, ready) * (1 - 0.5 * locked)

  for _, glint in ipairs(targetSparkle.glints) do
    glint.age = glint.age + elapsed * speed
    if glint.age >= glint.life then resetGlint(glint, false) end
    local shine = glint.age > 0 and math.sin(pi * glint.age / glint.life) or 0
    local texture = glint.texture
    texture:SetPoint("CENTER", frame, "CENTER", glint.x, glint.y + 10 * max(glint.age, 0))
    local size = max(GLINT_SIZE * glint.scale * (0.35 + 0.65 * shine), 0.01)
    texture:SetSize(size, size)
    texture:SetRotation(glint.rotation + glint.rotationSpeed * max(glint.age, 0))
    texture:SetVertexColor(red, green, blue, min(opacity * shine, 1))
  end
end

--- Creates the animated sparkle frame and its texture particles.
---@return table frame New sparkle frame.
local function createSparkleFrame()
  local frame = CreateFrame("Frame")
  frame:SetSize(1, 1)
  frame:Hide()
  targetSparkle.glints = {}
  for index = 1, GLINT_TOTAL do
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(SPARKLE_TEXTURE)
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(1, 1, 1, 0)
    if texture.SetSnapToPixelGrid then
      texture:SetSnapToPixelGrid(false)
      texture:SetTexelSnappingBias(0)
    end
    targetSparkle.glints[index] = { texture = texture }
  end
  frame:SetScript("OnUpdate", animateSparkles)
  targetSparkle.frame = frame
  return frame
end

--- Hides and detaches the sparkle frame from its current target.
local function clearSparkle()
  if not targetSparkle.anchor then return end
  targetSparkle.frame:Hide()
  targetSparkle.frame:ClearAllPoints()
  targetSparkle.frame:SetParent(nil)
  targetSparkle.anchor = nil
end

--- Attaches the sparkle animation to a nameplate for a newly selected target.
---@param plate table Target nameplate.
---@param state string Initial interaction state.
local function attachSparkle(plate, state)
  local frame = targetSparkle.frame or createSparkleFrame()
  frame:SetParent(plate)
  local ok, level = pcall(plate.GetFrameLevel, plate)
  if ok and level and not isSecret(level) then frame:SetFrameLevel(max(level - 1, 0)) end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", plate, "CENTER", 0, PLATE_OFFSET)
  frame:SetIgnoreParentAlpha(true)

  targetSparkle.anchor = plate
  targetSparkle.state = state
  targetSparkle.pendingState = nil
  targetSparkle.readyBlend = state == "ready" and 1 or 0
  targetSparkle.lockBlend = state == "locked" and 1 or 0
  targetSparkle.opacity = 0
  for _, glint in ipairs(targetSparkle.glints) do resetGlint(glint, false) end
  frame:Show()
end

--- Changes the displayed interaction state only after it stays stable briefly.
---@param state string New state: ready, far, or locked.
local function proposeState(state)
  if state == targetSparkle.state then
    targetSparkle.pendingState = nil
    return
  end
  local now = GetTime()
  if targetSparkle.pendingState ~= state then
    targetSparkle.pendingState = state
    targetSparkle.pendingSince = now
  elseif now - targetSparkle.pendingSince >= (state == "locked" and LOCKED_STABLE_TIME or STABLE_TIME) then
    targetSparkle.pendingState = nil
    targetSparkle.state = state
    if state == "ready" then
      for _, glint in ipairs(targetSparkle.glints) do resetGlint(glint, true) end
    end
  end
end

--- Determines whether the current unit can be interacted with.
---@param unit string Unit token.
---@param unavailable boolean Whether the cursor marks it unavailable.
---@return string state ready, far, or locked.
local function interactionState(unit, unavailable)
  local inRange = UnitIsInInteractRange and safeCall(UnitIsInInteractRange, unit)
  if inRange == false then return "far" end
  if unavailable then return inRange == true and "locked" or "far" end
  return "ready"
end

--- Finds the current soft target and updates its nameplate sparkle.
function module:EvaluateSoftTarget()
  if not hasActiveCategory() then
    clearSparkle()
    return
  end
  local unit, plate, unknown = resolveSoftTarget()
  if not unit then
    setTargetGate(unknown == true)
    clearSparkle()
    return
  end

  local category, unavailable
  if safeCall(UnitIsGameObject, unit) == true then
    category, unavailable = classifyUnit(unit, safeCall(UnitName, unit))
  elseif categorySettings.sparkleCorpseLoot and corpseHasLoot(unit) then
    category = "corpse"
  else
    setTargetGate(false)
    clearSparkle()
    return
  end

  local key = CATEGORY_SETTING[category]
  local wanted = key ~= nil and categorySettings[key] == true
  setTargetGate(wanted)
  if not wanted or not plate then
    clearSparkle()
    return
  end

  local state = interactionState(unit, unavailable == true)
  if targetSparkle.anchor ~= plate or targetSparkle.retarget then
    targetSparkle.retarget = nil
    clearSparkle()
    attachSparkle(plate, state)
  else
    proposeState(state)
  end
end

--- Applies or restores the soft-target CVars according to enabled categories.
---@param force boolean|nil Whether enabling a category should turn on interact options.
function module:RefreshSoftTarget(force)
  if hasActiveCategory() then
    enableSoftTarget(force == true)
  else
    clearSparkle()
    restoreSoftTarget()
  end
end

--- Enables or pauses the periodic target-state poller.
function module:UpdateSoftTargetPoller()
  if module.targetPoller then module.targetPoller:SetShown(hasActiveCategory()) end
end

--- Installs profile settings, saved CVar storage, and cursor texture lookups.
---@param profileSettings table Active profile's loot sparkle options.
---@param accountSettings table Global AceDB data.
function module:InitializeSoftTarget(profileSettings, accountSettings)
  categorySettings = profileSettings
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
    if plate and plate == targetSparkle.anchor then clearSparkle() end
  elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
    local oldTarget, newTarget = ...
    if not isSecret(oldTarget) and not isSecret(newTarget) and oldTarget and newTarget
      and oldTarget ~= newTarget then
      targetSparkle.retarget = targetSparkle.anchor ~= nil
    end
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

--- Creates the periodic target evaluator and refreshes it on each frame update.
module.targetPoller = CreateFrame("Frame")
module.targetPoller:Hide()
local elapsedSinceCheck = 0
--- Runs the target evaluator at a bounded interval.
---@param _ table Poller frame.
---@param elapsed number Time elapsed since the previous frame.
module.targetPoller:SetScript("OnUpdate", function(_, elapsed)
  elapsedSinceCheck = elapsedSinceCheck + elapsed
  if elapsedSinceCheck >= UPDATE_INTERVAL then
    elapsedSinceCheck = 0
    module:EvaluateSoftTarget()
  end
end)
