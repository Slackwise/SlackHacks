-- Change implicit globla scope to our addon "namespace":
setfenv(1, _G.SlackHacks)

--[[
  General API Documentation:
   - https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
   - https://warcraft.wiki.gg/wiki/Events
   - https://github.com/BigWigsMods/WoWUI/tree/live/AddOns
   - https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_APIDocumentationGenerated
   - https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation

  Lua type-checking via VSCode extension:
   - https://luals.github.io/wiki/type-checking/

  Common data structures:
   - ItemLink: https://warcraft.wiki.gg/wiki/ItemLink

  Common functions:
   - Item functions (take an ItemLink as "ItemInfo"):
     - GetItemInfo(): https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfo
     - GetContainerItemInfo(): https://warcraft.wiki.gg/wiki/API_C_Container.GetContainerItemInfo
     - GetItemIDForItemInfo(): https://warcraft.wiki.gg/wiki/API_C_Item.GetItemIDForItemInfo
]]--

--Event Handlers
local nameplateCastEventsRegistered = false
local nameplateCastStartEvents = {
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_EMPOWER_START",
  "UNIT_SPELLCAST_INTERRUPTIBLE",
}
local nameplateCastStopEvents = {
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_EMPOWER_STOP",
}

local function setNameplateCastEventRegistration(shouldRegister)
  if shouldRegister == nameplateCastEventsRegistered then return end

  for _, eventName in ipairs(nameplateCastStartEvents) do
    if shouldRegister then
      Self:RegisterEvent(eventName, "handleCasts")
    else
      Self:UnregisterEvent(eventName)
    end
  end
  for _, eventName in ipairs(nameplateCastStopEvents) do
    if shouldRegister then
      Self:RegisterEvent(eventName, "handleCastStops")
    else
      Self:UnregisterEvent(eventName)
    end
  end
  if shouldRegister then
    Self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "handleNameplateAdded")
  else
    Self:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
  end

  nameplateCastEventsRegistered = shouldRegister
end

function updateNameplateCastEventRegistration()
  local shouldRegister = db and db.profile and db.profile.combat and db.profile.combat.raiseCastingNameplates
  setNameplateCastEventRegistration(shouldRegister and true or false)
end

function Self:OnEnable()
  self:RegisterEvent("MERCHANT_SHOW")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
  self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  -- self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  self:RegisterEvent("BAG_UPDATE_DELAYED")
  updateNameplateCastEventRegistration()
  initBagsFrameHiding()
  -- self:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
end

function Self:OnDisable()
  setNameplateCastEventRegistration(false)
  resetNameplateCastLift()
end

function Self:BAG_UPDATE_DELAYED() -- Fires after all BAG_UPDATE's are done
  bindBestUseItems()
end

-- GAME_READY = false
function Self:PLAYER_ENTERING_WORLD(eventName, isLogin, isReload) -- Out of combat
  -- GAME_READY = true
  setCVars()
  handleDragonriding()
  processLogs(isLogin or isReload)
  initBagsFrameHiding()
end

function Self:MERCHANT_SHOW(eventName)
  if db.profile.inventory.autoRepair then
    repairAllItems()
  end
  if db.profile.inventory.autoSellGreyItems then
    sellGreyItems()
  end
end

function Self:PLAYER_REGEN_ENABLED(eventName) -- Out of combat
  handleDragonriding()
  runAfterCombatActions()
  resetNameplateCastLift()
end

function Self:PLAYER_MOUNT_DISPLAY_CHANGED(eventName)
  handleDragonriding()
end

function Self:PLAYER_REGEN_DISABLED(eventName) -- In combat
end

function Self:ACTIVE_TALENT_GROUP_CHANGED(currentSpecID, previousSpecID)
  setBindings()
end

function Self:UPDATE_SHAPESHIFT_FORM(eventName)
  handleDragonriding()
end

-- --- "Vignettes" are pop-up events on the minimap or world map like rare mobs or treasures: https://warcraft.wiki.gg/wiki/Vignette
-- --- https://warcraft.wiki.gg/wiki/VIGNETTE_MINIMAP_UPDATED
-- --- @param vignetteGUID string
-- --- @param onMinimap boolean
-- function Self:VIGNETTE_MINIMAP_UPDATED(eventName, vignetteGUID, onMinimap)
--   findDruidRareMobs(vignetteGUID)
-- end


afterCombatActions = {}
function runAfterCombat(f)
  table.insert(afterCombatActions, f)
end

function runAfterCombatActions()
  while #afterCombatActions > 0 do
    if not InCombatLockdown() then
      table.remove(afterCombatActions)()
    end
  end
end

--- Convert a boolean value to an integer (1 or 0).
---@param bool boolean - The boolean value to convert.
---@return number - 1 if true, 0 if false.
function bool2int(bool)
  if bool then
    return 1
  else
    return 0
  end
end

function inVehicle()
  return UnitHasVehicleUI("player")
end

function getClassName()
  return select(2, UnitClass("player"))
end

function classKeyForName(rawClass)
  local aliases = {
    deathknight = "DEATHKNIGHT",
    death = "DEATHKNIGHT",
    druid = "DRUID",
    demonhunter = "DEMONHUNTER",
    demon = "DEMONHUNTER",
    evoker = "EVOKER",
    hunter = "HUNTER",
    mage = "MAGE",
    monk = "MONK",
    paladin = "PALADIN",
    priest = "PRIEST",
    rogue = "ROGUE",
    shaman = "SHAMAN",
    warlock = "WARLOCK",
    warrior = "WARRIOR",
  }
  local normalized = strlower((rawClass or ""):gsub("[%s%-'%.]", ""))
  return aliases[normalized]
end

function specKeyForName(rawSpec)
  return strupper((rawSpec or ""):gsub("[%s%-]+", "_"))
end

function displayClassName(classKey)
  local names = { DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter" }
  return names[classKey] or (classKey:sub(1, 1) .. strlower(classKey:sub(2)))
end

function displaySpecName(specKey)
  return (specKey:gsub("_", " "):gsub("(%a)(%a*)", function(first, rest)
    return strupper(first) .. strlower(rest)
  end))
end

function shortName(name)
  return name and Ambiguate(name, "none")
end

function sameName(left, right)
  -- Unit names can be "secret" values (e.g. combat anti-bot protections) that error when compared.
  local ok, isSame = pcall(function() return shortName(left) == shortName(right) end)
  return ok and isSame
end

function characterFullName(characterName, realmName)
  if not characterName or not realmName then return nil end
  return characterName .. "-" .. realmName:gsub("%s+", "")
end

function groupUnitFor(name)
  if sameName(UnitName("player"), name) then return "player" end
  for index = 1, GetNumGroupMembers() do
    local unit = IsInRaid() and "raid" .. index or "party" .. index
    if sameName(UnitName(unit), name) then return unit end
  end
end

function guildMember(name)
  if not IsInGuild() then return false end
  if GuildRoster then GuildRoster()
  elseif C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
  else return false end
  for index = 1, GetNumGuildMembers() do
    if sameName(GetGuildRosterInfo(index), name) then return true end
  end
  return false
end

function itemIDFromInfo(info)
  return info and (info.itemID or C_Item.GetItemInfoInstant(info.hyperlink))
end

function inventoryEnchantID(unit, slot, link)
  if GetInventoryItemEnchantInfo then return select(4, GetInventoryItemEnchantInfo(unit, slot)) end
  return link and tonumber(link:match("item:%d+:(%d+):"))
end

function bagItemCount(itemID)
  local count = 0
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if itemIDFromInfo(info) == itemID then count = count + (info.stackCount or 0) end
    end
  end
  return count
end

function findBagItem(itemID, minimumCount)
  local preferredBag, preferredSlot, preferredCount
  local fallbackBag, fallbackSlot, fallbackCount
  minimumCount = minimumCount or 1
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if itemIDFromInfo(info) == itemID then
        local stackCount = info.stackCount or 0
        if stackCount >= minimumCount and (not preferredCount or stackCount > preferredCount) then
          preferredBag, preferredSlot, preferredCount = bag, slot, stackCount
        elseif not fallbackCount or stackCount > fallbackCount then
          fallbackBag, fallbackSlot, fallbackCount = bag, slot, stackCount
        end
      end
    end
  end
  return preferredBag or fallbackBag, preferredSlot or fallbackSlot
end

function findExactBagItem(itemID, quantity)
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if itemIDFromInfo(info) == itemID and info.stackCount == quantity then return bag, slot end
    end
  end
end

function findEmptyBagSlot()
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      if not C_Container.GetContainerItemInfo(bag, slot) then return bag, slot end
    end
  end
end

function getSpecName()
  local specIndex = C_SpecializationInfo.GetSpecialization()
  if specIndex then
    log("specIndex = " .. (specIndex or "nil"))
    local specID, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
    log("specID = " .. (specID or "nil"))
    log("specName = " .. (specName or "nil"))
    if specName then
      return strupper(specName)
    end
  end
  return nil
end

--- Sets a `cvar` to a specific `value` if it isn't already,
--- to avoid triggering a cvar change event, especially too many on startup.
---@param cvar string - CVar name.
---@param value object - The `value` to set it to if needed.
---@return bool - True if was set before invocation.
function ensureCVar(cvar, value)
  local currentValue = GetCVar(cvar)
  local targetValue = tostring(value) -- Uh, make sure the values are always at least the same type.
  local wasSet = true -- In case we care to know if it was set prior to this call.
  
  if currentValue ~= targetValue then
      wasSet = false
      SetCVar(cvar, value)
  end
  
  return wasSet
end

function setCVars()
  local customConfig = CustomConfigs and CustomConfigs[getBattletag()]
  if customConfig and customConfig.setCvars then
    customConfig.setCvars()
  end
end

function ensureLogging()
  if not LoggingCombat() then -- Gating to prevent potential in-combat logging issues
      LoggingCombat(true) -- Equal to `/combatlog` being toggled ON
  end
end

function repairAllItems()
  if CanMerchantRepair() then
    local useGuildRepair = db.profile.inventory.autoRepairMode == "guild"
    if db.profile.inventory.autoRepairMode == "guildRaid" then
      useGuildRepair = IsInRaid()
    end
    RepairAllItems(useGuildRepair)
  end
end

function canCollectTransmog(itemInfo) -- itemID, itemLink, or Name
  if isClassic() then
    return false
  end
  -- local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType = C_Item.GetItemInfo(itemInfo)
  -- if itemType ~= "Armor" then
  --   log(itemLink)
  --   return false
  -- end
  local itemAppearanceID, sourceID  = C_TransmogCollection.GetItemInfo(itemInfo) -- https://warcraft.wiki.gg/wiki/API_C_TransmogCollection.GetItemInfo
  if sourceID then
    local categoryID, visualID, canEnchant, icon, isCollected, itemLink, transmogLink, unknown1, itemSubTypeIndex = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
    return not isCollected
  end
  return false
end

ITEM_QUALITY_GREY = 0 

function sellGreyItems()
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      local link = C_Container.GetContainerItemLink(bag, slot)
      if link then
        local itemName, itemLink, itemQuality = C_Item.GetItemInfo(link)
        if itemQuality == ITEM_QUALITY_GREY then
          -- if canCollectTransmog(itemLink) then
          --   print("[SlackHacks] Not selling transmog-able item: " .. itemLink)
          -- else
            C_Container.UseContainerItem(bag, slot)
          -- end
        end
      end
    end
  end
end

function isSpellKnown(spellName)
  local link, spellID = GetSpellLink(spellName)
  if spellID then
    return IsSpellKnown(spellID)
  end
  return false
end

--=====================================================================
-- Bags Bar (the persistent Backpack/Bag icons Edit Mode calls "Bags")
--=====================================================================
-- BagsBar (Interface/AddOns/Blizzard_MainMenuBarBagButtons) is the native Edit Mode system for the
-- movable Backpack/Bag-slot icon cluster (Enum.EditModeSystem.Bags). Its own OnLoad already treats
-- :Hide() as a supported permanent-off state (see the BagsUIDisabled game rule check), so hiding it
-- directly -- rather than faking invisibility -- is safe and matches Blizzard's own usage.
local bagsBarShowHooked = false

function applyHideBagsFrame()
  if not (_G.BagsBar and _G.BagsBar.IsProtected) then return end
  if BagsBar:IsProtected() and InCombatLockdown() then return end
  if db.profile.inventory.hideBagsFrame then
    BagsBar:Hide()
  else
    BagsBar:Show()
  end
end

local function hookBagsBarShow()
  if bagsBarShowHooked or not _G.BagsBar then return end
  bagsBarShowHooked = true
  BagsBar:HookScript("OnShow", function(self)
    if db.profile.inventory.hideBagsFrame then
      self:Hide()
    end
  end)
end

-- A small checkbox attached beside Blizzard's own Edit Mode settings dialog whenever the Bags system
-- (BagsBar, a native Edit Mode system unlike our custom Buffs container) is the one selected.
local bagsEditModeCheckbox

local function createBagsEditModeCheckbox()
  local cb = CreateFrame("CheckButton", "SlackHacksHideBagsFrameCheckButton", UIParent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetFrameStrata("DIALOG")
  cb.text:SetText("Hide Bags Frame (SlackHacks)")
  cb.text:SetFontObject("GameFontHighlight")
  cb:SetScript("OnClick", function(self)
    db.profile.inventory.hideBagsFrame = self:GetChecked() and true or false
    applyHideBagsFrame()
  end)
  cb:Hide()
  return cb
end

local function showBagsEditModeCheckbox(show)
  if not show then
    if bagsEditModeCheckbox then bagsEditModeCheckbox:Hide() end
    return
  end
  bagsEditModeCheckbox = bagsEditModeCheckbox or createBagsEditModeCheckbox()
  bagsEditModeCheckbox:SetChecked(db.profile.inventory.hideBagsFrame)
  bagsEditModeCheckbox:ClearAllPoints()
  if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
    bagsEditModeCheckbox:SetPoint("TOPLEFT", EditModeSystemSettingsDialog, "TOPRIGHT", 10, 0)
  else
    bagsEditModeCheckbox:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
  end
  bagsEditModeCheckbox:Show()
end

local bagsEditModeHooksInstalled = false
local function registerBagsEditModeHooks()
  if bagsEditModeHooksInstalled then return end
  if not (EditModeManagerFrame and EditModeSystemSettingsDialog and Enum.EditModeSystem and _G.BagsBar) then return end
  bagsEditModeHooksInstalled = true

  hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(_, systemFrame)
    showBagsEditModeCheckbox(systemFrame and systemFrame.system == Enum.EditModeSystem.Bags)
  end)
  EditModeSystemSettingsDialog:HookScript("OnHide", function() showBagsEditModeCheckbox(false) end)
end

function initBagsFrameHiding()
  hookBagsBarShow()
  registerBagsEditModeHooks()
  applyHideBagsFrame()
end


--- Trim outer whitespace and leading indentation after each newline.
---@param str string - The multiline string to trim.
---@return string - The trimmed string.
function multilineTrim(str)
  if not str then return "" end
  return (strtrim(str):gsub("\n%s*(%S)", "\n%1"))
end

--- Get all keys from a given `targetTable`.
---@param targetTable table - The table to extract keys from.
---@param value object - The `value` to key off of.
---@return array - First key matching value.
function getKeyByValue(targetTable, targetValue)
  for key, value in pairs(targetTable) do
    if value == targetValue then
      return key
    end
  end
  return nil
end

--- Get all keys from a given `targetTable`.
---@param targetTable table - The table to extract keys from.
---@return array - Array of keys.
function keys(targetTable)
  local collectedKeys = {}
  for key, value in pairs(targetTable) do
    table.insert(collectedKeys, key)
  end
  return collectedKeys
end

--- Recursively merge values from a source table into a destination table, overwriting existing keys.
---@param dest table - Destination table to merge into (modified in place).
---@param src table - Source table to copy values from.
function recursiveMerge(dest, src)
  if type(dest) ~= "table" or type(src) ~= "table" then return end
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dest[k]) ~= "table" then
        dest[k] = {}
      end
      recursiveMerge(dest[k], v)
    else
      dest[k] = v
    end
  end
end

--- Find the first table element that match `kvPredicate` function.
---@param targetTable table - The table to find the first element from.
---@param kvPredicate Function(key, value) - A predicate function that takes in `(key, value)` and returns `true` or `false` if it matches.
---@return key, value - First element that matches `kvPredicate`.
function findFirstElement(targetTable, kvPredicate)
  for key, value in pairs(targetTable) do
    if kvPredicate(key, value) then
      return key, value
    end
  end
  return nil, nil
end

--- Find all table elements that match `kvPredicate` function.
---@param targetTable table - The table to find the first element from.
---@param kvPredicate Function(key, value) - A predicate function that takes in `(key, value)` and returns `true` or `false` if it matches.
---@return object[] - Array of all elements that matched `kvPredicate`.
function findElements(targetTable, kvPredicate)
  local found = {}
  for key, value in pairs(targetTable) do
    if kvPredicate(key, value) then
      found[key] = value
    end
  end
  return found
end

--- Returns array of `ContainerItemInfo` tables found in bags that match any of a given array of `itemIDs`
---@param array itemIDs - Array of itemIDs
---@return ContainerItemInfo[] Array of ContainerItemInfo
function findItemsByItemIDs(itemIDs)
  local found = {}
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      local containerItemInfo = C_Container.GetContainerItemInfo(bag, slot)
      if containerItemInfo then
        local itemName = C_Item.GetItemInfo(containerItemInfo.hyperlink)
        if itemName and tContains(itemIDs, containerItemInfo.itemID) then
          table.insert(found, containerItemInfo)
        end
      end
    end
  end
  return found
end

--- Returns array of `ContainerItemInfo` tables found in bags that match Lua regex `pattern`
---@param regex string Lua regexp pattern: https://warcraft.wiki.gg/wiki/Pattern_matching
---@return ContainerItemInfo[] Array of ContainerItemInfo
function findItemsByRegex(regex)
  local found = {}
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      local containerItemInfo = C_Container.GetContainerItemInfo(bag, slot)
      if containerItemInfo then
        local itemName = C_Item.GetItemInfo(containerItemInfo.hyperlink)
        if itemName and string.match(itemName, regex) then
          table.insert(found, containerItemInfo)
        end
      end
    end
  end
  return found
end

--- Group array items into a table by the output of a function.
---@param Array - The array to group.
---@param Function(object) - Takes in an object, and returns new `key, value` which will be grouped by `key`.
---@return Array - The grouped array.
function groupBy(array, groupingFunction)
  local grouped = {}
  for key, value in pairs(array) do
    local groupingKey, newValue = groupingFunction(value)
    if grouped[value] then
      table.insert(grouped[groupingKey], newValue)
    else
      grouped[groupingKey] = { newValue }
    end
  end
  return grouped
end

--- Find the largest (numeric) index of an array.
---@param Array - The array to search.
---@return Integer - Largest numeric index.
function findLargestIndex(array)
  local largestIndex = 0
  for key, value in pairs(array) do
    if tonumber(key) and key >= largestIndex then
      largestIndex = key
    end
  end
  return largestIndex
end

--- Recursively search up the map hierarchy to find a specific map type.
---@param map The map to start at.
---@param upMapType An Enum.UIMapType of the map you're trying to find.
---@return UiMapDetails
function findParentMapByType(map, uiMapType)
  if not map then
    return nil
  end
  if map.mapType == uiMapType or map.mapType == Enum.UIMapType.Cosmic then
    return map
  end 
  return findParentMapByType(C_Map.GetMapInfo(map.parentMapID), uiMapType)
end

function getCurrentMap()
  return C_Map.GetMapInfo(C_Map.GetBestMapForUnit("player") or 0)
end

function getCurrentContinent()
  local map = getCurrentMap()
  if map then
    return findParentMapByType(map, Enum.UIMapType.Continent)
  end
  return nil
end

function getCurrentZone()
  local map = getCurrentMap()
  if map then
    return findParentMapByType(map, Enum.UIMapType.Zone)
  end
  return nil
end

function isActuallyFlyableArea()
  local continent   = getCurrentContinent()
  local continentID = continent and continent.mapID or 0
  local zone 			  = getCurrentZone()
  local zoneID      = zone and zone.mapID or 0
  local map         = getCurrentMap()
  local mapID       = map and map.mapID or 0

  local listedFlyableContinent    = not not tContains(	    ACTUALLY_FLYABLE_MAP_IDS.CONTINENTS,  continentID )
  local listedFlyableZone         = not not tContains(	    ACTUALLY_FLYABLE_MAP_IDS.ZONES,       zoneID      )
  local listedFlyableMap          = not not tContains(	    ACTUALLY_FLYABLE_MAP_IDS.MAPS,        mapID       )

  local listedNonFlyableContinent = not not tContains(	NOT_ACTUALLY_FLYABLE_MAP_IDS.CONTINENTS,  continentID )
  local listedNonFlyableZone      = not not tContains(	NOT_ACTUALLY_FLYABLE_MAP_IDS.ZONES,       zoneID      )
  local listedNonFlyableMap       = not not tContains(	NOT_ACTUALLY_FLYABLE_MAP_IDS.MAPS,        mapID       )

  if listedFlyableMap           then return true end
  if listedNonFlyableMap        then return false end

  if listedFlyableZone          then return true end
  if listedNonFlyableZone       then return false end

  if listedFlyableContinent     then return true end
  if listedNonFlyableContinent  then return false end

  return IsFlyableArea()
end

function printDebugMapInfo()
  local map = getCurrentMap()
  local zone = getCurrentZone()
  local continent = getCurrentContinent()
  local parentMap = C_Map.GetMapInfo(map.parentMapID) or "nil"
  if isDebugging() then
    p = log
  else
    p = print
  end
  p("===============================")
  p(map.name .. ", " .. (parentMap.name or "nil"))
  p("Zone: "      .. zone.name .. " (" .. zone.mapID .. ')')
  if continent then
    p("Continent: " .. continent.name .. " (" .. continent.mapID .. ')')
  end
  p("-------------------------------------------------------") -- Chat window does not used fixed width; trying to match header
  p("mapID: "       .. map.mapID)
  p("parentMapID: " .. map.parentMapID)
  p("mapType: "     .. (getKeyByValue(Enum.UIMapType, map.mapType) or "nil") .. " (" .. (map.mapType or "nil") .. ")")
  p("Outdoor: "     .. tostring(IsOutdoors()))
  p("Submerged: "   .. tostring(IsSubmerged()))
  p("Flyable: "     .. tostring(IsFlyableArea()))
  p("AdvancedFlyable: " .. tostring(IsAdvancedFlyableArea()))
  p("ActuallyFlyable: " .. tostring(isActuallyFlyableArea()))
  p("===============================")
end

DRUID_RARE_MOBS = {
  "Keen-eyed Cian",
  "Matriarch Keevah",
  "Moragh the Slothful",
  "Mosa Umbramane",
  "Ristar the Rabid",
  "Talthonei Ashwhisper"
}
function findDruidRareMobs(vignetteGUID)
  if getClassName() ~= "DRUID" then return end

  log("VIGNETTE ID: " .. vignetteGUID)
	local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID) -- https://warcraft.wiki.gg/wiki/API_C_VignetteInfo.GetVignetteInfo
	if not vignetteInfo then return end
  local name = vignetteInfo.name
  log("VIGNETTE NAME: " .. (name or ""))

  if tContains(DRUID_RARE_MOBS, name) then
    foundDruidRare(name)
  end
end

foundDruidRares = {}
function foundDruidRare(name)
  local currentUnixTimestamp = GetServerTime()
  local currentHour, currentMinute = GetGameTime()
  local lastTimeFound = foundDruidRares[name]
  if not lastTimeFound or isTimeWithin(lastTimeFound, 5 * 60, GetServerTime()) then
    foundDruidRares[name] = { currentUnixTimestamp, currentHour, currentMinute }
  end
end

function announceFoundDruidRare(name)
  log("Found druid rare: " .. name)
  SendChatMessage(name ".. spotted!", "CHANNEL", nil, 5)
end

--- Checks if a time is within a given time of another time
--- @param originUnixTimestamp integer
--- @param secondsToBeWithin integer
--- @param currentUnixTimestamp integer
--- @return boolean
function isTimeWithin(originUnixTimestamp, secondsToBeWithin, currentUnixTimestamp)
  return currentUnixTimestamp >= (originUnixTimestamp + (secondsToBeWithin * 1000))
end

--[[ -- TODO: Update broken fishing pole right-click handler
function events:PLAYER_EQUIPMENT_CHANGED(slot, hasItem)
  if InCombat() then return
  if select(6, GetItemInfo(GetInventoryItemID("player", slot))) == "Fishing Poles" then
    --Right-click to cast.
    if not frame:IsHooked(WorldFrame, "OnMouseDown") then
      frame:HookScript(WorldFrame, "OnMouseDown",
        function()
        end
      )
    end
  else
    --Undo right-click casting.
    if frame:IsHooked(WorldFrame, "OnMouseDown") then
      frame:Unhook(WorldFrame, "OnMouseDown")
    end
  end
end
]]
