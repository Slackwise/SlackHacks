--INITIALIZE
local Self = LibStub("AceAddon-3.0"):NewAddon(
  "SlackUI",
  "AceConsole-3.0",
  "AceEvent-3.0"
)
Self.config = LibStub("AceConfig-3.0")
Self.frame = CreateFrame("Frame", "SlackUI")
_G.SlackUI = Self
Self.Self = Self
setmetatable(Self, {__index = _G}) -- The global environment is now checked if a key is not found in addon
setfenv(1, Self) -- Namespace local to addon

addonName, addonTable = ...

dbDefaults = {
  profile = {
    isDebugging = false
  }
}

--[[
  General API Documentation:
  https://wow.gamepedia.com/World_of_Warcraft_API
  https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation
]]--

function isDebugging()
  return SlackUIDB.isDebugging
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
    if arg then
      for i, v in ipairs(arg) do
        print("Arg " .. i .. " = " .. v)
      end
    end
  end
end

--Event Handlers
function Self:OnInitialize()
  Self.db = LibStub("AceDB-3.0"):New("SlackUIDB", dbDefaults, true)
  config:RegisterOptionsTable("SlackUI", options, "slack")

  setMaxCameraDistance()
end

function Self:OnEnable()
  self:RegisterEvent("MERCHANT_SHOW")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("UNIT_AURA")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  -- self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

function Self:OnDisable()
end

function Self:PLAYER_ENTERING_WORLD(eventName, isLogin, isReload) -- Out of combat
  handleDragonriding()
end

function Self:MERCHANT_SHOW(eventName)
  repairAllItems()
  sellGreyItems()
end

function Self:PLAYER_REGEN_ENABLED(eventName) -- Out of combat
  handleDragonriding()
end

function Self:PLAYER_REGEN_DISABLED(eventName) -- In combat

end

function Self:ACTIVE_TALENT_GROUP_CHANGED(currentSpecID, previousSpecID)
  setBindings()
end

function Self:UNIT_AURA(eventName, unitTarget, updateInfo) -- https://wowpedia.fandom.com/wiki/UNIT_AURA
  if unitTarget == "player" then
    log("Aura handling dragonriding...")
    handleDragonriding()
  end
end

function handleDragonriding()
  if isTester() then
    if isDragonriding() then
      bindDragonriding()
    else
      unbindDragonriding()
    end
  end
end

isDragonridingBound = false

function bindDragonriding()
  if not InCombatLockdown() and not isDragonridingBound then
    SetOverrideBindingSpell(Self.frame, true, "BUTTON3",       "Skyward Ascent")   -- Fly up
    SetOverrideBindingSpell(Self.frame, true, "SHIFT-BUTTON3", "Surge Forward")    -- Fly forward
    SetOverrideBindingSpell(Self.frame, true, "CTRL-BUTTON3",  "Whirling Surge")   -- Fly forward x3
    SetOverrideBindingSpell(Self.frame, true, "X",             "Aerial Halt")      -- Brake
    SetOverrideBindingSpell(Self.frame, true, "BUTTON5",       "Aerial Halt")      -- Brake
    SetOverrideBindingSpell(Self.frame, true, "SHIFT-X",       "Bronze Timelock")  -- Rewind Time
    isDragonridingBound = true
    log("Dragonriding keys BOUND")
  end 
end

function unbindDragonriding()
  if not InCombatLockdown() and isDragonridingBound then
    ClearOverrideBindings(Self.frame)
    isDragonridingBound = false
    log("Dragonriding keys CLEARED")
  end
end

function isDragonriding()
  log("Checking if dragonriding...")
  local dragonridingSpellIds = C_MountJournal.GetCollectedDragonridingMounts()
  if IsMounted() and IsAdvancedFlyableArea() then
    for _, mountId in ipairs(dragonridingSpellIds) do
      local spellId = select(2, C_MountJournal.GetMountInfoByID(mountId))
      if C_UnitAuras.GetPlayerAuraBySpellID(spellId) then
        return true
      end
    end
  end
  return false
end


function inVehicle()
  return UnitHasVehicleUI("player")
end

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
  -- Official way Blizzard distinguishes between game clients: https://wow.gamepedia.com/WOW_PROJECT_ID
  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    return true
  else
    return false
  end
end

function isClassic()
  -- Official way Blizzard distinguishes between game clients: https://wow.gamepedia.com/WOW_PROJECT_ID
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

function getClassName()
  return select(2, UnitClass("player"))
end

function getSpecName()
  return strupper(select(2, GetSpecializationInfo(GetSpecialization())))
end

function setMaxCameraDistance()
  SetCVar("cameraDistanceMaxZoomFactor", 2.6) -- Max out camera zoon
  SetCVar("minimapTrackingShowAll", 1) -- Show all minimap tracking options (including turning off target tracking!)
end

function repairAllItems()
  if CanMerchantRepair() then
    RepairAllItems() -- #TODO: pass `true` for guild repairs if currently raiding with guild
  end
end

function canCollectTransmog(itemInfo) -- itemID, itemLink, or Name
  if isClassic() then
    return false
  end
  local itemAppearanceID, sourceID  = C_TransmogCollection.GetItemInfo(itemInfo) -- https://wowpedia.fandom.com/wiki/API_C_TransmogCollection.GetItemInfo
  if sourceID then
    local categoryID, visualID, canEnchant, icon, isCollected, itemLink, transmogLink, unknown1, itemSubTypeIndex = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
    -- local hasItemData, canCollect = C_TransmogCollection.PlayerCanCollectSource(sourceID)
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
        local itemName, itemLink, itemQuality = GetItemInfo(link)
        local collectable = canCollectTransmog(itemLink)
        if itemQuality == ITEM_QUALITY_GREY and not collectable then
          log("Grey Item to Sell: " .. tostring(itemName))
          C_Container.UseContainerItem(bag, slot)
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

--- Recursively search up the map hierarchy to find a specific map type.
-- @param map - The map to start at.
-- @param upMapType - An Enum.UIMapType of the map you're trying to find.
-- @return UiMapDetails
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
  return C_Map.GetMapInfo((C_Map.GetBestMapForUnit("player")))
end

function getCurrentContinentID()
  local map = getCurrentMap()
  if map then
    return findParentMapByType(map, Enum.UIMapType.Continent).mapID
  end
  return nil
end

function getCurrentZoneID()
  local map = getCurrentMap()
  if map then
    return findParentMapByType(map, Enum.UIMapType.Zone).mapID
  end
  return nil
end

ACTUALLY_FLYABLE_MAPS = {
  CONTINENTS = {
    619, -- Broken Isles
  },
  ZONES = {
  }
}

NOT_ACTUALLY_FLYABLE_MAPS = {
  CONTINENTS = {
    905,	-- Argus
  },
  ZONES = {
  }
}

function isActuallyFlyableArea()
  local continentID = getCurrentContinentID()
  local zoneID 			= getCurrentZoneID()

  if not continentID or not zoneID then
    return false
  end

  local listedFlyableContinent    = not not tContains(	   ACTUALLY_FLYABLE_MAPS.CONTINENTS,  continentID  )
  local listedFlyableZone         = not not tContains(	   ACTUALLY_FLYABLE_MAPS.ZONES,       zoneID       )

  local listedNonFlyableContinent = not not tContains(	NOT_ACTUALLY_FLYABLE_MAPS.CONTINENTS,  continentID  )
  local listedNonFlyableZone      = not not tContains(	NOT_ACTUALLY_FLYABLE_MAPS.ZONES,       zoneID       )

  local listedFlyable             = listedFlyableContinent    or listedFlyableZone
  local listedNonFlyable          = listedNonFlyableContinent or listedNonFlyableZone

  if listedNonFlyable then
    return false
  end

  if listedFlyable then
    return true
  end

  return IsFlyableArea()
end

function printDebugMapInfo()
  local map = getCurrentMap()
  local zone = getCurrentZone()
  local continent = getCurrentContinent()
  local parentMap = C_Map.GetMapInfo(map.parentMapID)
  print("MapID: " .. map.mapID)
  print("===============================")
  print(map.name .. ", " .. parentMap.name)
  print("Zone: "      .. zone.name .. " (" .. zone.mapID .. ')')
  print("Continent: " .. continent.name .. " (" .. continent.mapID .. ')')
  print("-------------------------------------------------------") -- Chat window does not used fixed width; trying to match header
  print("mapID: "       .. map.mapID)
  print("parentMapID: " .. map.parentMapID)
  print("mapType: "     .. Enum.UIMapType[map.mapType] .. '('..map.mapType..')')
  print("Outdoor: "     .. tostring(IsOutdoors()))
  print("Submerged: "   .. tostring(IsSubmerged()))
  print("Flyable: "     .. tostring(IsFlyableArea()))
  print("ActuallyFlyable: " .. tostring(isActuallyFlyableArea()))
  print("===============================")
end

MOUNT_IDS = { -- from https://wowpedia.fandom.com/wiki/MountID (Use the ID from the leftmost column)
  ["Charger"]                      = 84,
  ["Swift Razzashi Raptor"]        = 110,
  ["Ashes of Al'ar"]               = 183,
  ["Time-Lost Proto-Drake"]        = 265,
  ["Mekgineer's Chopper"]          = 275,
  ["Sea Turtle"]                   = 312,
  ["Sandstone Drake"]              = 407,
  ["Tyrael's Charger"]             = 439,
  ["Grand Expedition Yak"]         = 460,
  ["Sky Golem"]                    = 522,
  ["Highlord's Golden Charger"]    = 885,
  ["Highland Drake"]               = 1563,
  ["Winding Slitherdrake"]         = 1588,
  ["Renewed Proto-Drake"]          = 1589,
  ["Grotto Netherwing Drake"]      = 1744,
}

MOUNT_SHORTNAMES = {
  ["RAPTOR"]      = MOUNT_IDS["Swift Razzashi Raptor"],
  ["TURTLE"]      = MOUNT_IDS["Sea Turtle"],
  ["PHOENIX"]     = MOUNT_IDS["Ashes of Al'ar"],
  ["TLPD"]        = MOUNT_IDS["Time-Lost Proto-Drake"],
  ["CHARGER"]     = MOUNT_IDS["Highlord's Golden Charger"],
  ["MOTORCYCLE"]  = MOUNT_IDS["Mekgineer's Chopper"],
  ["NETHERDRAKE"] = MOUNT_IDS["Grotto Netherwing Drake"],
};

MOUNTS_BY_USAGE = {
  HUNTER = {
    ['GROUND']            = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['DRAGON']            = MOUNT_IDS["Winding Slitherdrake"], -- Dragonriding
    ['GROUND_PASSENGER']  = MOUNT_IDS["Mekgineer's Chopper"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Sandstone Drake"],
    ['GATHERING']         = MOUNT_IDS["Sky Golem"],
    ['GROUND_SHOWOFF']    = MOUNT_SHORTNAMES["RAPTOR"],
    ['FLYING_SHOWOFF']    = MOUNT_SHORTNAMES["TLPD"],
  },
  PALADIN = {
    ['GROUND']            = MOUNT_IDS["Highlord's Golden Charger"],
    ['FLYING']            = MOUNT_IDS["Highlord's Golden Charger"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['DRAGON']            = MOUNT_IDS["Winding Slitherdrake"], -- Dragonriding
    ['GROUND_PASSENGER']  = MOUNT_IDS["Mekgineer's Chopper"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Sandstone Drake"],
    ['GATHERING']         = MOUNT_IDS["Sky Golem"],
    ['GROUND_SHOWOFF']    = MOUNT_SHORTNAMES["RAPTOR"],
    ['FLYING_SHOWOFF']    = MOUNT_SHORTNAMES["TLPD"],
  }
}

function mountByUsage(usage)
  C_MountJournal.SummonByID(MOUNTS_BY_USAGE[getClassName()][usage])
end

function mountByName(mountName)
  C_MountJournal.SummonByID(MOUNT_IDS[mountName])
end

function mountByShortname(mountShortname)
  C_MountJournal.SummonByID(MOUNT_SHORTNAMES[mountShortname])
end

function isAlternativeMountRequested()
  return IsControlKeyDown()
end

function mount()  
  if IsMounted() then
    Dismount()
    return
  end

  if UnitUsingVehicle("player") then
    VehicleExit()
    return
  end

  if IsOutdoors() then
    if isActuallyFlyableArea() and not IsSubmerged() then -- Summon flying mount
      log("FLYING AREA")
      if isAlternativeMountRequested() then -- But we may want to show off our ground mount
        mountByUsage("FLYING_SHOWOFF")
        return
      end
      if IsInGroup() then
        mountByUsage("FLYING_PASSENGER")
        return
      else
        mountByUsage("FLYING")
        return
      end
      return
    elseif IsAdvancedFlyableArea() and not IsSubmerged() then -- Summon dragonriding mount
      if isAlternativeMountRequested() and isActuallyFlyableArea() then -- But we may want to show off our ground mount
        mountByUsage("FLYING_SHOWOFF")
        return
      elseif isAlternativeMountRequested() then
        mountByUsage("GROUND_SHOWOFF")
        return
      end
      mountByUsage("DRAGON")
      return
    elseif IsSubmerged() then -- Summon water mount
      if isAlternativeMountRequested() then -- But we may want to fly out of the water
        if IsAdvancedFlyableArea() then
          mountByUsage("DRAGON")
          return
        else
          mountByUsage("FLYING")
          return
        end
        return
      end
      mountByUsage("WATER")
      return
    else -- Summon ground mount
      if IsInGroup() then
        if isAlternativeMountRequested() then -- But we may want to show off
          mountByUsage("GROUND_SHOWOFF")
          return
        end
        mountByUsage("GROUND_PASSENGER")
        return
      else
        if isAlternativeMountRequested() then -- But we may want to show off
          mountByUsage("GROUND_SHOWOFF")
          return
        end
        mountByUsage("GROUND")
        return
      end
    end
  end
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
