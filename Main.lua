--INITIALIZE
local Self = LibStub("AceAddon-3.0"):NewAddon(
	"Slackwow", "AceConsole-3.0", "AceEvent-3.0")
Self.config = LibStub("AceConfig-3.0")
_G.Slackwow = Self

local db
local dbDefaults = {
}

--[[
	General API Documentation:
	https://wow.gamepedia.com/World_of_Warcraft_API)
	https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation
]]--

--Event Handlers
function Self:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SlackwowDB", dbDefaults, true)
	db = self.db.profile
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

Self.notActuallyFlyableMaps = {
	continents = {
		905,	-- Argus
	},
	zones = {
		--94,		-- Eversong Woods
		--97,		-- Azuremyst Isle
	}
}

--- Recursively search up the map hierarchy to find a specific map type.
-- @param map - The map to start at.
-- @param upMapType - An Enum.UIMapType of the map you're trying to find.
-- @return UiMapDetails
function Self:FindParentMapByType(map, uiMapType)
	if map.mapType == uiMapType or map.mapType == Enum.UIMapType.Cosmic then
		return map
	else
		return self:FindParentMapByType(C_Map.GetMapInfo(map.parentMapID), uiMapType)
	end 
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

function Self:IsNonFlyableContinent()
	return not not tContains(self.notActuallyFlyableMaps.continents, self:GetCurrentContinent().mapID)
end

function Self:IsNonFlyableZone()
	return not not tContains(self.notActuallyFlyableMaps.zones, self:GetCurrentZone().mapID)
end

Self.mounts = {
	['RAPTOR'] 		= 110,
	['PHOENIX'] 	= 183,
	['TURTLE'] 		= 312,
}

function Self:Mount()  
	if IsMounted() then
		Dismount()
		return
	end

	if UnitUsingVehicle("player") then
		VehicleExit()
		return
	end

	if IsOutdoors() and not IsControlKeyDown() and (IsFlyableArea() or not (self:IsNonFlyableContinent() or self:IsNonFlyableZone())) then
		-- Summon flying mount
		C_MountJournal.SummonByID(self.mounts.PHOENIX)
	elseif IsOutdoors() and IsSubmerged() and not IsControlKeyDown() then
		-- Summon water mount
		C_MountJournal.SummonByID(self.mounts.TURTLE)
	elseif IsOutdoors() then
		-- Summon ground mount
		C_MountJournal.SummonByID(self.mounts.RAPTOR)
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
