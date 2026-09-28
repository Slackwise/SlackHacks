setfenv(1, _G.SlackHacks)

-- A simplified re-implementation of the "Main Ring" from the UltimateMouseCursor addon: just a ring
-- that follows the mouse cursor, with scale/opacity/color options and an out-of-combat visibility toggle.
local module = Self:NewModule("MouseRing", "AceEvent-3.0")
Self.MouseRing = module

local RING_TEXTURE = "Interface\\AddOns\\SlackHacks\\Assets\\ring"
local RING_SIZE = 70 -- Native pixel size of the ring artwork at 100% scale.

local frame
local texture
local isFollowingCursor = false

-- Same cursor-tracking math UltimateMouseCursor uses: cursor position is in screen pixels, so it has to
-- be divided by UIParent's effective scale before being used to anchor a UI frame.
local function followCursor()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function createFrame()
  if frame then return end

  frame = CreateFrame("Frame", "SlackHacksMouseRing", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(false)
  frame:Hide()

  texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(frame)
  texture:SetTexture(RING_TEXTURE)
end

-- Only keep the cursor-follow OnUpdate running while the ring is actually visible, so it costs nothing
-- while hidden (e.g. out of combat, with "Show Out of Combat" left off).
local function setFollowingCursor(shouldFollow)
  if shouldFollow == isFollowingCursor then return end
  isFollowingCursor = shouldFollow
  frame:SetScript("OnUpdate", shouldFollow and followCursor or nil)
end

local function updateVisibility()
  if not frame then return end

  local settings = db.profile.mouseRing
  local shouldShow = settings.enabled and (settings.showOutOfCombat or InCombatLockdown())

  if shouldShow then
    followCursor() -- Snap to the current position immediately instead of waiting for the next OnUpdate.
    frame:Show()
  else
    frame:Hide()
  end
  setFollowingCursor(shouldShow)
end

function module:Refresh()
  createFrame()

  local settings = db.profile.mouseRing
  -- Resize (rather than Frame:SetScale) the frame that's re-anchored to the cursor every frame, so its
  -- single CENTER anchor point unambiguously stays fixed on the cursor regardless of ring size.
  local size = RING_SIZE * (settings.scale or 50) / 100
  frame:SetSize(size, size)
  frame:SetAlpha((settings.opacity or 100) / 100)

  local color = settings.color or {}
  texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)

  updateVisibility()
end

function module:SetEnabled(enabled)
  db.profile.mouseRing.enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

function module:OnInitialize()
  createFrame()
  if not db.profile.mouseRing.enabled then self:Disable() end
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
  self:RegisterEvent("PLAYER_REGEN_ENABLED") -- Leaving combat
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  setFollowingCursor(false)
  if frame then frame:Hide() end
end

function module:PLAYER_REGEN_DISABLED()
  updateVisibility()
end

function module:PLAYER_REGEN_ENABLED()
  updateVisibility()
end
