setfenv(1, _G.SlackHacks)

local module = Self:NewModule("InfoDisplay")
Self.InfoDisplay = module

function module:Refresh()
  if Self.CharSheet then Self.CharSheet:Refresh() end
end

function module:SetEnabled(enabled)
  db.profile.infoDisplay.enabled = enabled
  if Self.CharSheet then Self.CharSheet:SetGearStatsEnabled(enabled) end
  if enabled then self:Enable() else self:Disable() end
  self:Refresh()
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

function module:OnInitialize()
  if not db.profile.infoDisplay.enabled then self:Disable() end
end

function module:OnEnable()
  if Self.CharSheet and not Self.CharSheet:IsEnabled() then Self.CharSheet:Enable() end
end

function module:OnDisable()
  if Self.CharSheet and Self.CharSheet:IsEnabled() then Self.CharSheet:Disable() end
end
