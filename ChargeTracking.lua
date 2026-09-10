setfenv(1, _G.SlackHacks)

local module = Self:NewModule("ChargeTracking", "AceEvent-3.0")
Self.ChargeTracking = module

local HOLY_SHOCK_SPELL_ID = 20473
local CHARGE_ICON_SIZE = 36
local CHARGE_ICON_ANCHOR_GAP = 6

local container
local anchorVisibilityHooked = false
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
  container:Hide()

  -- Same border art the Blizzard TotemFrame uses for its totem buttons (Blizzard_UnitFrame/TotemFrame.xml);
  -- it's always-loaded (unlike the Cooldown Manager's atlases) and has the metallic gold look natively.
  local border = container:CreateTexture(nil, "OVERLAY")
  border:SetSize(CHARGE_ICON_SIZE + 6, CHARGE_ICON_SIZE + 6)
  border:SetPoint("CENTER")
  border:SetAtlas("UI-HUD-UnitFrame-TotemFrame", false)

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

local function hookAnchorVisibility(anchorFrame)
  if anchorVisibilityHooked or not anchorFrame then return end
  anchorVisibilityHooked = true
  anchorFrame:HookScript("OnShow", function() module:Refresh() end)
  anchorFrame:HookScript("OnHide", function() module:Refresh() end)
end

local function updatePosition()
  if not container then return end

  container:ClearAllPoints()
  local anchorFrame = _G.PersonalResourceDisplayFrame
  if anchorFrame then
    if db.profile.combat.paladin.holyShockChargesPosition == "above" then
      container:SetPoint("BOTTOM", anchorFrame, "TOP", 0, CHARGE_ICON_ANCHOR_GAP)
    else
      container:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -CHARGE_ICON_ANCHOR_GAP)
    end
  else
    container:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
  end
end

function module:RefreshDisplay(chargeInfo)
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
  if unitTarget ~= "player" or spellID ~= HOLY_SHOCK_SPELL_ID then return end
  if trackedCharges == nil then trackedCharges = maxCharges end
  trackedCharges = math.max(trackedCharges - 1, 0)
  startRechargeTimer() -- no-op if a recharge is already in progress (only one runs at a time)
  self:RefreshDisplay()
end

function module:Refresh()
  createChargeTrackingFrame()
  hookAnchorVisibility(_G.PersonalResourceDisplayFrame)
  stopRechargeTimer()
  trackedCharges = nil -- resync from scratch

  local shouldShow = isRetail() and getClassName() == "PALADIN" and getSpecName() == "HOLY" and db.profile.combat.paladin.trackHolyShockCharges
  local anchorFrame = _G.PersonalResourceDisplayFrame
  shouldShow = shouldShow and anchorFrame and anchorFrame:IsShown()
  if shouldShow then
    updatePosition()
    container:Show()
    self:UpdateHolyShockCharges()
  else
    container:Hide()
  end
end

function module:OnInitialize()
  createChargeTrackingFrame()
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "Refresh")
  self:RegisterEvent("SPELL_UPDATE_CHARGES", "UpdateHolyShockCharges")
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnHolyShockCast")
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  stopRechargeTimer()
  if container then container:Hide() end
end


