setfenv(1, _G.SlackHacks)

-- Reminders: the parent of every reminder feature (Consumable Buff Reminders in Reminders_Buffs.lua and Talent
-- Reminders in Reminders_Talents.lua). This module's enable switch is the master switch for its sub-modules, the
-- same way the Info Display's switch works for its own.
local module = Self:NewModule("Reminders")
Self.Reminders = module

-- AceModule names on Self that the Reminders enable switch turns on and off. Buffs isn't listed: that module stays
-- enabled to keep its Edit Mode hooks alive and gates itself on the switch whenever it refreshes.
local SUBMODULES = { "Talents" }

--- Returns whether the Reminders master switch is on.
---@return boolean enabled
function module:IsActive()
  return db.profile.reminders.enabled and true or false
end

--- Turns every reminder feature on or off and saves the choice. Sub-modules also check `reminders.enabled` when
--- they initialize and enable, so turning this on only starts the ones whose own settings are on.
---@param enabled boolean Whether the Reminders sub-modules may run.
function module:SetEnabled(enabled)
  db.profile.reminders.enabled = enabled
  if enabled then self:Enable() else self:Disable() end
  for _, name in ipairs(SUBMODULES) do
    local submodule = Self[name]
    if submodule then
      if enabled then submodule:Enable() else submodule:Disable() end
    end
  end
  if Self.Buffs and Self.Buffs.Refresh then Self.Buffs:Refresh() end
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- AceAddon initialization hook; keeps the module disabled when Reminders are turned off.
function module:OnInitialize()
  if not db.profile.reminders.enabled then self:Disable() end
end
