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
local spellBookSlotIndex
local spellBookSpellBank
local trackedCharges
local wasRecharging = false

local function findSpellBookSlot()
  if not spellBookSlotIndex then
    spellBookSlotIndex, spellBookSpellBank = C_SpellBook.FindSpellBookSlotForSpell(HOLY_SHOCK_SPELL_ID)
  end
  return spellBookSlotIndex, spellBookSpellBank
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

function module:UpdateHolyShockCharges()
  if not container or not container:IsShown() then return end

  local chargeInfo = C_Spell.GetSpellCharges(HOLY_SHOCK_SPELL_ID)
  if not chargeInfo then return end

  -- Fetch the recharge time as an opaque duration object; it can be handed straight to the native
  -- Cooldown widget without ever reading the underlying secret start/duration numbers ourselves.
  local slotIndex, spellBank = findSpellBookSlot()
  local durationObj = slotIndex and C_SpellBook.GetSpellBookItemChargeDuration(slotIndex, spellBank)
  local isRecharging = durationObj ~= nil

  -- currentCharges itself can't be compared while in combat, so we derive our own non-secret counter:
  -- a recharge finishing (isRecharging drops to false) always means a charge was just gained. Casting
  -- a charge away is tracked separately via UNIT_SPELLCAST_SUCCEEDED. Outside combat we can safely
  -- resync against the real value to correct for any drift (e.g. talents that grant bonus charges).
  if not InCombatLockdown() then
    trackedCharges = chargeInfo.currentCharges
  elseif trackedCharges == nil then
    trackedCharges = chargeInfo.maxCharges
  elseif wasRecharging and not isRecharging then
    trackedCharges = math.min(trackedCharges + 1, chargeInfo.maxCharges)
  end
  wasRecharging = isRecharging

  for index, iconFrame in ipairs(icons) do
    if index <= trackedCharges then
      iconFrame.cooldown:Clear()
      iconFrame.icon:SetDesaturated(false)
      iconFrame.icon:SetAlpha(1)
    elseif durationObj and index == trackedCharges + 1 then
      iconFrame.cooldown:SetCooldownFromDurationObject(durationObj)
      iconFrame.icon:SetDesaturated(true)
      iconFrame.icon:SetAlpha(0.55)
    else
      iconFrame.cooldown:Clear()
      iconFrame.icon:SetDesaturated(true)
      iconFrame.icon:SetAlpha(0.3)
    end
  end
end

function module:OnHolyShockCast(_, unitTarget, _, spellID)
  if unitTarget == "player" and spellID == HOLY_SHOCK_SPELL_ID and trackedCharges then
    trackedCharges = math.max(trackedCharges - 1, 0)
    self:UpdateHolyShockCharges()
  end
end

function module:Refresh()
  createChargeTrackingFrame()
  hookAnchorVisibility(_G.PersonalResourceDisplayFrame)
  spellBookSlotIndex, spellBookSpellBank = nil, nil -- spellbook slot can shift on spec/loadout change
  trackedCharges = nil -- resync from scratch; safe since Refresh only runs outside active combat updates

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
  if container then container:Hide() end
end


