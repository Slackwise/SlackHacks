--INITIALIZE
local addon = LibStub("AceAddon-3.0"):NewAddon(
  "Slackwow", "AceConsole-3.0", "AceEvent-3.0")
addon.config = LibStub("AceConfig-3.0")
_G.Slackwow = addon
local db
local db_defaults = {
}

--[[
  General API Documentation:
  https://wow.gamepedia.com/World_of_Warcraft_API)
  https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation
]]--

--Event Handlers
function addon:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("SlackwowDB", db_defaults, true)
  db = self.db.profile
  self.config:RegisterOptionsTable("Slackwow", self.options, "slackwow")

  addon.SetMaxCameraDistance()
end

function addon:OnEnable()
  self:RegisterEvent("MERCHANT_SHOW")
end

function addon:OnDisable()
end

function addon:MERCHANT_SHOW()
  addon:SellGreyItems()
end

function addon:IsClassic()
  -- #TODO: Find the most foolproof way to check if we're in Classic
  return not SaveBindings -- Renamed to AttemptToSaveBindings: https://wow.gamepedia.com/API_SaveBindings
end

function addon:GetGameType()
  if addon.IsClassic() then
    return "CLASSIC"
  else
    return "RETAIL"
  end
end

function addon:SetMaxCameraDistance()
  SetCVar("cameraDistanceMaxZoomFactor", 2.6)
end

function addon:SellGreyItems()
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 0, GetContainerNumSlots(bag) do
      local link = GetContainerItemLink(bag, slot)
      if link and select(3, GetItemInfo(link)) == 0 then
        UseContainerItem(bag, slot)
      end
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
