setfenv(1, _G.SlackHacks)

local module = Self:NewModule("ChargeTracking", "AceEvent-3.0")
Self.ChargeTracking = module

local HOLY_SHOCK_SPELL_ID = 20473
local CHARGE_ICON_SIZE = 36

local container
local isEditing = false
local selection
local trackedCharges
local maxCharges = 2 -- static fact about Holy Shock; used whenever the real value isn't safely readable
local rechargeDuration -- cached seconds; refreshed opportunistically whenever it's a clean number
local rechargeTimer

local function isSecret(value)
  return _G.issecretvalue and _G.issecretvalue(value) or false
end

local function isCleanNumber(value)
  return not isSecret(value) and type(value) == "number"
end

local function stopRechargeTimer()
  if rechargeTimer then
    rechargeTimer:Cancel()
    rechargeTimer = nil
  end
end

local function createChargeTrackingFrame()
  if container then return end

  container = CreateFrame("Frame", "SlackHacksHolyShockChargeTracker", UIParent)
  container:SetSize(CHARGE_ICON_SIZE, CHARGE_ICON_SIZE)
  container:SetMovable(true)
  container:SetClampedToScreen(true)
  container:SetDontSavePosition(true)
  container:Hide()

  -- The TotemFrame ring art bakes its thickness in as a fixed ~13% of its own size, so scaling it never
  -- makes it visually thinner -- the hole shrinks right along with the outer edge. A plain color clipped
  -- by the same circular mask has no such ratio, so its thickness is just however much bigger it is than
  -- the icon, giving direct control over how thin the ring appears.
  local border = container:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("CENTER")
  border:SetSize(CHARGE_ICON_SIZE + 2, CHARGE_ICON_SIZE + 2)
  border:SetColorTexture(1, 0.82, 0)

  local borderMask = container:CreateMaskTexture(nil, "BACKGROUND")
  borderMask:SetAllPoints(border)
  borderMask:SetAtlas("CircleMaskScalable", false)
  border:AddMaskTexture(borderMask)

  local icon = container:CreateTexture(nil, "BORDER")
  icon:SetAllPoints(container)
  icon:SetTexture(C_Spell.GetSpellTexture(HOLY_SHOCK_SPELL_ID))

  local iconMask = container:CreateMaskTexture(nil, "BORDER")
  iconMask:SetAllPoints(icon)
  iconMask:SetAtlas("CircleMaskScalable", false)
  icon:AddMaskTexture(iconMask)

  local cooldown = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
  cooldown:SetAllPoints(container)
  cooldown:SetHideCountdownNumbers(false)
  cooldown:SetDrawBling(false)
  cooldown:SetDrawEdge(true)

  -- Same corner/font convention Blizzard action buttons use for their charge count text.
  local count = container:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  count:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 2)

  container.icon = icon
  container.cooldown = cooldown
  container.border = border
  container.count = count
end

local function getPaladinDb()
  if not db.profile.combat then db.profile.combat = {} end
  if not db.profile.combat.paladin then db.profile.combat.paladin = {} end
  return db.profile.combat.paladin
end

local function updatePosition()
  if not container then return end

  local p = getPaladinDb()
  local point = p.point or "CENTER"
  local relativePoint = p.relativePoint or "CENTER"
  local x = p.x or 0
  local y = p.y or 0

  container:ClearAllPoints()
  container:SetPoint(point, UIParent, relativePoint, x, y)
end

local function onDragStart()
  if InCombatLockdown() then return end
  if container then
    container:StartMoving()
  end
end

local function onDragStop()
  if not container then return end
  container:StopMovingOrSizing()
  if InCombatLockdown() then return end

  local point, relativeTo, relativePoint, x, y = container:GetPoint(1)
  if point then
    local p = getPaladinDb()
    p.point = point
    p.relativePoint = relativePoint or point
    p.x = math.floor(x + 0.5)
    p.y = math.floor(y + 0.5)
  end
  updatePosition()
end

local function createSelection()
  if selection then return selection end
  if not container then createChargeTrackingFrame() end

  local success, sel = pcall(CreateFrame, "Frame", "SlackHacksHolyShockEditModeSelection", container, "EditModeSystemSelectionTemplate")
  if success and sel then
    selection = sel
    selection:SetAllPoints(container)
    selection:SetFrameStrata(container:GetFrameStrata())
    selection:SetFrameLevel(container:GetFrameLevel() + 20)
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    selection:SetScript("OnDragStart", onDragStart)
    selection:SetScript("OnDragStop", onDragStop)
    selection.system = {
      GetSystemName = function()
        return "Holy Shock Charges"
      end
    }
    if selection.SetSelectionText then
      selection:SetSelectionText("Holy Shock Charges")
    elseif selection.Label then
      selection.Label:SetText("Holy Shock Charges")
    end
    selection:SetScript("OnMouseDown", function(self)
      if InCombatLockdown() then return end
      if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
        EditModeManagerFrame:ClearSelectedSystem()
      end
      if self.ShowSelected then
        self:ShowSelected(true)
      end
    end)
  else
    local f = CreateFrame("Frame", "SlackHacksHolyShockEditModeSelection", container, "BackdropTemplate")
    f:SetAllPoints(container)
    f:SetFrameStrata(container:GetFrameStrata())
    f:SetFrameLevel(container:GetFrameLevel() + 20)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    f:SetBackdropBorderColor(0.2, 0.6, 1.0, 0.8)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", f, "CENTER", 0, 0)
    label:SetText("Holy Shock Charges")
    f.Label = label
    f.ShowHighlighted = function(self)
      self:SetBackdropBorderColor(0.2, 0.6, 1.0, 0.8)
      self:Show()
    end
    f.ShowSelected = function(self)
      self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
      self:Show()
    end
    f:SetScript("OnDragStart", onDragStart)
    f:SetScript("OnDragStop", onDragStop)
    f:SetScript("OnMouseDown", function(self)
      self:ShowSelected()
    end)
    selection = f
  end

  return selection
end

local function shouldTrack(inCombat)
  if inCombat == nil then
    inCombat = InCombatLockdown()
  end
  local p = getPaladinDb()
  return isRetail() and getClassName() == "PALADIN" and getSpecName() == "HOLY" and p.trackHolyShockCharges and (not p.onlyInCombat or inCombat)
end

local function enterEditMode()
  if isEditing or InCombatLockdown() then return end
  isEditing = true
  module:Refresh()
end

local function exitEditMode()
  if not isEditing then return end
  isEditing = false
  if selection then
    selection:Hide()
  end
  module:Refresh()
end

function module:RefreshDisplay(chargeInfo)
  if isEditing then return end
  if not container or not container:IsShown() or trackedCharges == nil then return end
  chargeInfo = chargeInfo or C_Spell.GetSpellCharges(HOLY_SHOCK_SPELL_ID)
  if not chargeInfo then return end

  -- trackedCharges is our own locally-simulated number (never read from a secret field), so it's always
  -- safe to display directly -- unlike currentCharges, which can be secret and isn't safe to format/compare.
  container.count:SetText(trackedCharges)

  if trackedCharges >= maxCharges then
    container.cooldown:Clear()
    container.icon:SetDesaturated(false)
    container.icon:SetAlpha(1)
  else
    -- The real timing fields may be secret; SetCooldown is a sanctioned direct sink for them either way.
    container.cooldown:SetCooldown(chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration, chargeInfo.chargeModRate)
    container.icon:SetDesaturated(trackedCharges == 0)
    container.icon:SetAlpha(trackedCharges == 0 and 0.55 or 1)
  end
end

local function startRechargeTimer()
  if rechargeTimer or not rechargeDuration or trackedCharges == nil or trackedCharges >= maxCharges then return end
  rechargeTimer = C_Timer.NewTimer(rechargeDuration, function()
    rechargeTimer = nil
    trackedCharges = math.min((trackedCharges or 0) + 1, maxCharges)
    module:RefreshDisplay()
    startRechargeTimer() -- only one charge recharges at a time; chain if still below max
  end)
end

-- Learns the static facts (max charges, recharge duration) whenever they happen to be clean, and
-- resyncs our local simulation to the real charge count/remaining time whenever THAT is clean too.
-- Neither is guaranteed to be readable in combat, so this is opportunistic, not combat-gated.
function module:UpdateHolyShockCharges()
  if isEditing then return end
  if not container or not container:IsShown() then return end

  local chargeInfo = C_Spell.GetSpellCharges(HOLY_SHOCK_SPELL_ID)
  if not chargeInfo then return end

  if isCleanNumber(chargeInfo.maxCharges) and chargeInfo.maxCharges > 0 then
    maxCharges = chargeInfo.maxCharges
  end
  if isCleanNumber(chargeInfo.cooldownDuration) and chargeInfo.cooldownDuration > 0 then
    rechargeDuration = chargeInfo.cooldownDuration
  end

  if isCleanNumber(chargeInfo.currentCharges) then
    trackedCharges = chargeInfo.currentCharges
    stopRechargeTimer()
    if trackedCharges < maxCharges then
      if isCleanNumber(chargeInfo.cooldownStartTime) and isCleanNumber(chargeInfo.cooldownDuration) then
        local remaining = (chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration) - GetTime()
        if remaining > 0 then
          rechargeTimer = C_Timer.NewTimer(remaining, function()
            rechargeTimer = nil
            trackedCharges = math.min((trackedCharges or 0) + 1, maxCharges)
            module:RefreshDisplay()
            startRechargeTimer()
          end)
        end
      else
        startRechargeTimer()
      end
    end
  elseif trackedCharges == nil then
    trackedCharges = maxCharges -- best guess until either a real read or a cast tells us otherwise
  end

  self:RefreshDisplay(chargeInfo)
end

function module:OnHolyShockCast(_, unitTarget, _, spellID)
  if isEditing then return end
  if unitTarget ~= "player" or spellID ~= HOLY_SHOCK_SPELL_ID then return end
  if trackedCharges == nil then trackedCharges = maxCharges end
  trackedCharges = math.max(trackedCharges - 1, 0)
  startRechargeTimer() -- no-op if a recharge is already in progress (only one runs at a time)
  self:RefreshDisplay()
end

local function updateVisibility(inCombat)
  if not container then return end

  if isEditing then
    local p = getPaladinDb()
    local isHolyPaladin = isRetail() and getClassName() == "PALADIN" and getSpecName() == "HOLY" and p.trackHolyShockCharges
    if isHolyPaladin then
      updatePosition()
      container:Show()
      container.count:SetText(maxCharges)
      container.cooldown:Clear()
      container.icon:SetDesaturated(false)
      container.icon:SetAlpha(1)
      local sel = createSelection()
      if sel then
        sel:Show()
        if sel.ShowHighlighted then
          sel:ShowHighlighted()
        end
      end
    else
      if selection then selection:Hide() end
      container:Hide()
    end
    return
  end

  if shouldTrack(inCombat) then
    if selection then selection:Hide() end
    updatePosition()
    container:Show()
    module:UpdateHolyShockCharges()
  else
    if selection then selection:Hide() end
    container:Hide()
    stopRechargeTimer()
  end
end

function module:Refresh(inCombat)
  createChargeTrackingFrame()
  stopRechargeTimer()
  trackedCharges = nil -- resync from scratch
  updateVisibility(inCombat)
end

function module:OnDatabaseReset()
  isEditing = false
  if selection then selection:Hide() end
  self:Refresh()
end

function module:PLAYER_REGEN_DISABLED()
  if isEditing then
    exitEditMode()
  end
  updateVisibility(true)
end

function module:PLAYER_REGEN_ENABLED()
  updateVisibility(false)
end

function module:OnInitialize()
  createChargeTrackingFrame()
  db:RegisterCallback("OnDatabaseReset", module.OnDatabaseReset, module)

  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", enterEditMode, module)
    EventRegistry:RegisterCallback("EditMode.Exit", exitEditMode, module)
  end

  if EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", enterEditMode)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", exitEditMode)
    if EditModeManagerFrame.SelectSystem then
      hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
        if selection and selection.ShowHighlighted then
          selection:ShowHighlighted()
        end
      end)
    end
  end

  if EditModeSystemSettingsDialog then
    EditModeSystemSettingsDialog:HookScript("OnShow", function()
      if selection and selection.ShowHighlighted then
        selection:ShowHighlighted()
      end
    end)
  end
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "Refresh")
  self:RegisterEvent("SPELL_UPDATE_CHARGES", "UpdateHolyShockCharges")
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnHolyShockCast")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
    enterEditMode()
  else
    self:Refresh()
  end
end

function module:OnDisable()
  self:UnregisterAllEvents()
  stopRechargeTimer()
  if isEditing then
    exitEditMode()
  end
  if container then container:Hide() end
end


