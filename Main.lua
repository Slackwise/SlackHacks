--INITIALIZE
local self = LibStub("AceAddon-3.0"):NewAddon(
	"Slackwow", "AceConsole-3.0", "AceEvent-3.0")
self.config = LibStub("AceConfig-3.0")
_G.Slackwow = self

local db
local dbDefaults = {
}

--[[
	General API Documentation:
	https://wow.gamepedia.com/World_of_Warcraft_API)
	https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation
]]--

--Event Handlers
function self:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SlackwowDB", dbDefaults, true)
	db = self.db.profile
	self.config:RegisterOptionsTable("Slackwow", self.options, "slackwow")

	self:SetMaxCameraDistance()
end

function self:OnEnable()
	self:RegisterEvent("MERCHANT_SHOW")
end

function self:OnDisable()
end

function self:MERCHANT_SHOW()
	self:RepairAllItems()
	self:SellGreyItems()
end

function self:IsRetail()
	-- Official way Blizzard distinguishes between game clients: https://wow.gamepedia.com/WOW_PROJECT_ID
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		return true
	else
		return false
	end
end

function self:IsClassic()
	-- Official way Blizzard distinguishes between game clients: https://wow.gamepedia.com/WOW_PROJECT_ID
	if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		return true
	else
		return false
	end
end

function self:GetGameType()
	if self:IsRetail() then
		return "RETAIL"
	elseif self:IsClassic() then
		return "CLASSIC"
  else
		return "UNKNOWN" -- Uh oh
	end
end

function self:SetMaxCameraDistance()
	SetCVar("cameraDistanceMaxZoomFactor", 2.6)
end

function self:RepairAllItems()
	if CanMerchantRepair() then
		RepairAllItems() -- #TODO: pass `true` for guild repairs if currently raiding with guild
	end
end

function self:SellGreyItems()
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 0, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link and select(3, GetItemInfo(link)) == 0 then
				UseContainerItem(bag, slot)
			end
		end
	end
end

self.notActuallyFlyableZones = {
	continents = {},
	zones = {}
}

function self:Mount()  
	if IsMounted() then
		Dismount()
		return
	end

	if UnitUsingVehicle("player") then
		VehicleExit()
		return
	end

	--if IsOutdoors() and IsFlyableArea() and not in self.notActuallyFlyableZones

	IsOutdoors()
	IsFlying()
	IsFlyableArea()
	IsSubmerged()
end

function self:GetCurrentContinent()

end

function self:GetCurrentZone()

end

function self:IsNonFlyableContinent()

end

function self:IsNonFlyableZone()

end

--- Recursively search up the map hierarchy to find a specific map type.
-- @param map - The map to start at.
-- @param upMapType - An Enum.UIMapType of the map you're trying to find.
-- @return UiMapDetails
function self:FindParentMapByType(map, uiMapType)
	 
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
