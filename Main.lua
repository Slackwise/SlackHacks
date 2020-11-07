--INITIALIZE
local Self = LibStub("AceAddon-3.0"):NewAddon(
	"Slackwow", "AceConsole-3.0", "AceEvent-3.0")
Self.config = LibStub("AceConfig-3.0")
_G.Slackwow = Self

Self.dbDefaults = {}

--[[
	General API Documentation:
	https://wow.gamepedia.com/World_of_Warcraft_API)
	https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation
]]--

--Event Handlers
function Self:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SlackwowDB", self.dbDefaults, true)
	self.config:RegisterOptionsTable("Slackwow", self.options, "slackwow")

	self:SetMaxCameraDistance()
end

function Self:OnEnable()
	self:RegisterEvent("MERCHANT_SHOW")
end

function Self:OnDisable()
end

function Self:MERCHANT_SHOW()
	self:RepairAllItems()
	self:SellGreyItems()
end

function Self:IsRetail()
	-- Official way Blizzard distinguishes between game clients: https://wow.gamepedia.com/WOW_PROJECT_ID
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		return true
	else
		return false
	end
end

function Self:IsClassic()
	-- Official way Blizzard distinguishes between game clients: https://wow.gamepedia.com/WOW_PROJECT_ID
	if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		return true
	else
		return false
	end
end

function Self:GetGameType()
	if self:IsRetail() then
		return "RETAIL"
	elseif self:IsClassic() then
		return "CLASSIC"
  else
		return "UNKNOWN" -- Uh oh
	end
end

function Self:SetMaxCameraDistance()
	SetCVar("cameraDistanceMaxZoomFactor", 2.6)
end

function Self:RepairAllItems()
	if CanMerchantRepair() then
		RepairAllItems() -- #TODO: pass `true` for guild repairs if currently raiding with guild
	end
end

function Self:SellGreyItems()
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
function Self:FindParentMapByType(map, uiMapType)
	if map.mapType == uiMapType or map.mapType == Enum.UIMapType.Cosmic then
		return map
	end 
	return self:FindParentMapByType(C_Map.GetMapInfo(map.parentMapID), uiMapType)
end

function Self:GetCurrentMap()
	return C_Map.GetMapInfo((C_Map.GetBestMapForUnit("player")))
end

function Self:GetCurrentContinent()
	return self:FindParentMapByType(self:GetCurrentMap(), Enum.UIMapType.Continent)
end

function Self:GetCurrentZone()
	return self:FindParentMapByType(self:GetCurrentMap(), Enum.UIMapType.Zone)
end

Self.notActuallyFlyableMaps = {
	continents = {
		905,	-- Argus
	},
	zones = {
	}
}

function Self:IsActuallyFlyableArea()
	local listedNonFlyableContinent = not not tContains(self.notActuallyFlyableMaps.continents, self:GetCurrentContinent().mapID)
	local listedNonFlyableZone      = not not tContains(self.notActuallyFlyableMaps.zones,      self:GetCurrentZone().mapID)
	if listedNonFlyableContinent or listedNonFlyableZone then
		return false
	else
		if not IsFlyableArea() then -- Lawl, game thinks it isn't flyable but it most likely is!
			return true
		end
	end
	return IsFlyableArea()
end

function Self:PrintDebugMapInfo()
	local map = self:GetCurrentMap()
	local zone = self:GetCurrentZone()
	local continent = self:GetCurrentContinent()
	local parentMap = C_Map.GetMapInfo(map.parentMapID)
	print("MapID: " .. map.mapID)
	print("===============================")
	print(map.name .. ", " .. parentMap.name)
	print("Zone: "      .. zone.name)
	print("Continent: " .. continent.name)
	print("-------------------------------------------------------") -- Chat window does not used fixed width; trying to match header
	print("mapID: "       .. map.mapID)
	print("parentMapID: " .. map.parentMapID)
	print("mapType: "     .. map.mapType)
	print("Outdoor: "     .. tostring(IsOutdoors()))
	print("Submerged: "   .. tostring(IsSubmerged()))
	print("Flyable: "     .. tostring(IsFlyableArea()))
	print("ActuallyFlyable: " .. tostring(self:IsActuallyFlyableArea()))
	print("===============================")
end

Self.mounts = {
	['RAPTOR']    = 110,
	['PHOENIX']   = 183,
	['TURTLE']    = 312,
}

Self.mountsByType = {
	['GROUND'] = Self.mounts.RAPTOR,
	['FLYING'] = Self.mounts.PHOENIX,
	['WATER']  = Self.mounts.TURTLE,
}

function Self:MountByType(type)
	C_MountJournal.SummonByID(self.mountsByType[type])
end

function Self:IsAlternativeMountRequested()
	return IsControlKeyDown()
end

function Self:Mount()  
	if IsMounted() then
		Dismount()
		return
	end

	if UnitUsingVehicle("player") then
		VehicleExit()
		return
	end

	if IsOutdoors() then
		if self:IsActuallyFlyableArea() and not IsSubmerged() then -- Summon flying mount
			if self:IsAlternativeMountRequested() then -- But we may want to show off our ground mount
				self:MountByType("GROUND")
			end
			self:MountByType("FLYING")
		elseif IsSubmerged() then -- Summon water mount
			if self:IsAlternativeMountRequested() then -- But we may want to fly out of the water
				self:MountByType("FLYING")
			end
			self:MountByType("WATER")
		else -- Summon ground mount
			if self:IsAlternativeMountRequested() then -- But we may want to show off our flying mount
				self:MountByType("FLYING")
			end
			self:MountByType("GROUND")
		end
	end
end


--[[
local function events:PLAYER_EQUIPMENT_CHANGED(slot, hasItem)
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
