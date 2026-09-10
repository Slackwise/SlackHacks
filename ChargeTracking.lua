setfenv(1, _G.SlackHacks)

local module = Self:NewModule("ChargeTracking", "AceEvent-3.0")
Self.ChargeTracking = module

local HOLY_SHOCK_SPELL_ID = 20473
local CHARGE_ICON_SIZE = 30
local CHARGE_ICON_SPACING = 6
local CHARGE_ICON_ANCHOR_GAP = 6
local CHARGE_ICON_BORDER_COLOR = { 1, 0.82, 0 }

local container
local icons = {}
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

local function createChargeIcon(parent, index)
  local iconFrame = CreateFrame("Frame", nil, parent)
  iconFrame:SetSize(CHARGE_ICON_SIZE, CHARGE_ICON_SIZE)

  -- Ring drawn behind the icon; must use a real texture (not SetColorTexture) for SetMask to crop it into a circle.
  local border = iconFrame:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("CENTER")
  border:SetSize(CHARGE_ICON_SIZE + 4, CHARGE_ICON_SIZE + 4)
  border:SetTexture("Interface\\Buttons\\WHITE8x8")
  border:SetVertexColor(CHARGE_ICON_BORDER_COLOR[1], CHARGE_ICON_BORDER_COLOR[2], CHARGE_ICON_BORDER_COLOR[3])
  border:SetMask("Interface\\Masks\\CircleMaskScalable")

  local icon = iconFrame:CreateTexture(nil, "BORDER")
  icon:SetAllPoints(iconFrame)
  icon:SetTexture(C_Spell.GetSpellTexture(HOLY_SHOCK_SPELL_ID))
  icon:SetMask("Interface\\Masks\\CircleMaskScalable")

  local cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
  cooldown:SetAllPoints(iconFrame)
  cooldown:SetHideCountdownNumbers(false)
  cooldown:SetDrawBling(false)
  cooldown:SetDrawEdge(true)

  iconFrame.icon = icon
  iconFrame.cooldown = cooldown
  iconFrame.border = border
  return iconFrame
end

local function createChargeTrackingFrame()
  if container then return end

  container = CreateFrame("Frame", "SlackHacksHolyShockChargeTracker", UIParent)
  container:SetSize(CHARGE_ICON_SIZE * 2 + CHARGE_ICON_SPACING, CHARGE_ICON_SIZE)
  container:Hide()

  for index = 1, 2 do
    local iconFrame = createChargeIcon(container, index)
    iconFrame:SetPoint("LEFT", container, "LEFT", (index - 1) * (CHARGE_ICON_SIZE + CHARGE_ICON_SPACING), 0)
    icons[index] = iconFrame
  end
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

  for index, iconFrame in ipairs(icons) do
    if index <= trackedCharges then
      iconFrame.cooldown:Clear()
      iconFrame.icon:SetDesaturated(false)
      iconFrame.icon:SetAlpha(1)
    elseif index == trackedCharges + 1 then
      -- The real timing fields may be secret; SetCooldown is a sanctioned direct sink for them either way.
      iconFrame.cooldown:SetCooldown(chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration, chargeInfo.chargeModRate)
      iconFrame.icon:SetDesaturated(true)
      iconFrame.icon:SetAlpha(0.55)
    else
      iconFrame.cooldown:Clear()
      iconFrame.icon:SetDesaturated(true)
      iconFrame.icon:SetAlpha(0.3)
    end
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


