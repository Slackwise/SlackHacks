--INITIALIZE
local Self = LibStub("AceAddon-3.0"):NewAddon(
	"SlackUI",
	"AceConsole-3.0",
	"AceEvent-3.0"
)
Self.config = LibStub("AceConfig-3.0")
_G.SlackUI = Self
Self.Self = Self
setmetatable(Self, {__index = _G}) -- The global environment is now checked if a key is not found in addon
setfenv(1, Self) -- Namespace local to addon

dbDefaults = {}

--[[
	General API Documentation:
	https://wow.gamepedia.com/World_of_Warcraft_API)
	https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation
]]--

--Event Handlers
function Self:OnInitialize()
	db = LibStub("AceDB-3.0"):New("SlackUIDB", dbDefaults, true)
	config:RegisterOptionsTable("SlackUI", options, "slack")

	setMaxCameraDistance()
end

function Self:OnEnable()
	self:RegisterEvent("MERCHANT_SHOW")
end

function Self:OnDisable()
end

function Self:MERCHANT_SHOW()
	repairAllItems()
	sellGreyItems()
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
	SetCVar("cameraDistanceMaxZoomFactor", 2.6)
end

function repairAllItems()
	if CanMerchantRepair() then
		RepairAllItems() -- #TODO: pass `true` for guild repairs if currently raiding with guild
	end
end

function sellGreyItems()
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 0, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link and select(3, GetItemInfo(link)) == 0 then
				UseContainerItem(bag, slot)
			end
		end
	end
end

--- Recursively search up the map hierarchy to find a specific map type.
-- @param map - The map to start at.
-- @param upMapType - An Enum.UIMapType of the map you're trying to find.
-- @return UiMapDetails
function findParentMapByType(map, uiMapType)
	if map.mapType == uiMapType or map.mapType == Enum.UIMapType.Cosmic then
		return map
	end 
	return findParentMapByType(C_Map.GetMapInfo(map.parentMapID), uiMapType)
end

function getCurrentMap()
	return C_Map.GetMapInfo((C_Map.GetBestMapForUnit("player")))
end

function getCurrentContinent()
	return findParentMapByType(getCurrentMap(), Enum.UIMapType.Continent)
end

function getCurrentZone()
	return findParentMapByType(getCurrentMap(), Enum.UIMapType.Zone)
end

actuallyFlyableMaps = {
	continents = {
		619, -- Broken Isles
	},
	zones = {
	}
}

notActuallyFlyableMaps = {
	continents = {
		905,	-- Argus
	},
	zones = {
	}
}

function isActuallyFlyableArea()
	local continentID = getCurrentContinent().mapID
	local zoneID 			= getCurrentZone().mapID

	local listedFlyableContinent    = not not tContains(	   actuallyFlyableMaps.continents,  continentID  )
	local listedFlyableZone         = not not tContains(	   actuallyFlyableMaps.zones,       zoneID       )

	local listedNonFlyableContinent = not not tContains(	notActuallyFlyableMaps.continents,  continentID  )
	local listedNonFlyableZone      = not not tContains(	notActuallyFlyableMaps.zones,       zoneID       )

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
	print("mapType: "     .. map.mapType)
	print("Outdoor: "     .. tostring(IsOutdoors()))
	print("Submerged: "   .. tostring(IsSubmerged()))
	print("Flyable: "     .. tostring(IsFlyableArea()))
	print("ActuallyFlyable: " .. tostring(isActuallyFlyableArea()))
	print("===============================")
end

mounts = {
	['RAPTOR']    = 110,
	['PHOENIX']   = 183,
	['TURTLE']    = 312,
}

mountsByType = {
	['GROUND'] = mounts.RAPTOR,
	['FLYING'] = mounts.PHOENIX,
	['WATER']  = mounts.TURTLE,
}

function mountByType(type)
	C_MountJournal.SummonByID(mountsByType[type])
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
			if isAlternativeMountRequested() then -- But we may want to show off our ground mount
				mountByType("GROUND")
			end
			mountByType("FLYING")
		elseif IsSubmerged() then -- Summon water mount
			if isAlternativeMountRequested() then -- But we may want to fly out of the water
				mountByType("FLYING")
			end
			mountByType("WATER")
		else -- Summon ground mount
			if isAlternativeMountRequested() then -- But we may want to show off our flying mount
				mountByType("FLYING")
			end
			mountByType("GROUND")
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
