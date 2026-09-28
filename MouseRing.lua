setfenv(1, _G.SlackHacks)

--=====================================================================
-- Mouse Ring
--=====================================================================
-- Draws a simple ring that follows the mouse cursor, with options for scale, opacity, color, and whether
-- it should also be visible while out of combat.
--
-- Design decisions worth calling out:
--   * The ring is just a single plain frame + texture, no cooldown swipes, animations, trail history, or
--     alternate ring styles. Keeping it this small is what keeps the CPU cost negligible.
--   * Cursor-following is driven by an OnUpdate script (see `followCursor` below) because WoW's API has
--     no event for "mouse moved" -- polling GetCursorPosition() every frame is the only way to track it.
--     To keep that cost as close to zero as possible when it's not needed, the OnUpdate handler is only
--     ever attached while the ring is actually shown (see `setFollowingCursor`), and is fully detached
--     (set to nil) the instant it's hidden -- e.g. whenever "Show Out of Combat" is off and the player is
--     out of combat, which is the default and most common state.
--   * Visibility toggles for entering/leaving combat are driven by the PLAYER_REGEN_DISABLED/ENABLED
--     events instead of checking InCombatLockdown() on every OnUpdate tick, so there's no extra work done
--     for combat-state polling either.
--   * The ring is resized (Frame:SetSize) rather than scaled (Frame:SetScale) to apply the user's "Scale"
--     setting. The frame is re-anchored with a single CENTER point every frame in followCursor(); scaling
--     the frame instead of resizing it would scale that anchor offset too, which visibly drags the ring
--     off-center from the cursor as the scale setting changes. Resizing avoids that problem entirely,
--     since the CENTER anchor point itself never moves relative to the cursor regardless of ring size.

--- The addon module instance. Exposed as `Self.MouseRing` so Options.lua can call `:SetEnabled()` and
--- `:Refresh()` from the config UI.
local module = Self:NewModule("MouseRing", "AceEvent-3.0")
Self.MouseRing = module

local RING_TEXTURE = "Interface\\AddOns\\SlackHacks\\Assets\\ring"
local RING_SIZE = 70 -- Native pixel size of the ring artwork at 100% scale.

local frame -- The single frame anchored to the cursor; created once and reused (see createFrame()).
local texture -- The ring's texture object, held onto so Refresh() can recolor it without a table lookup.
local isFollowingCursor = false -- Tracks whether the OnUpdate cursor-tracking script is currently attached.

--- Re-anchors `frame` to the current mouse cursor position. Assigned as `frame`'s OnUpdate script (see
--- `setFollowingCursor`), so this runs once per rendered frame, but only while the ring is visible.
--- Cursor position from GetCursorPosition() is reported in real screen pixels, so it has to be divided by
--- UIParent's effective scale before it can be used as an offset for anchoring a regular UI frame.
local function followCursor()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

--- Creates the ring's frame and texture the first time it's needed. Safe to call repeatedly; does
--- nothing after the first call. Deferred out of file-load time (rather than created immediately) since
--- OnInitialize/Refresh already call it, keeping frame creation in one place regardless of caller.
local function createFrame()
  if frame then return end

  frame = CreateFrame("Frame", "SlackHacksMouseRing", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(false) -- The ring is purely visual; it must never intercept clicks meant for the game world or UI beneath it.
  frame:Hide()

  texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(frame)
  texture:SetTexture(RING_TEXTURE)
end

--- Attaches or detaches the per-frame cursor-tracking OnUpdate script. This is the main efficiency
--- lever for this module: GetCursorPosition() and the SetPoint() calls in followCursor() only ever run
--- while `shouldFollow` is true, so the ring costs nothing at all while hidden (its most common state,
--- since out-of-combat visibility defaults to off). Guarded by `isFollowingCursor` so redundant calls
--- (e.g. Refresh() running twice) don't keep re-assigning the same script.
---@param shouldFollow boolean - Whether the ring should currently be tracking the cursor.
local function setFollowingCursor(shouldFollow)
  if shouldFollow == isFollowingCursor then return end
  isFollowingCursor = shouldFollow
  frame:SetScript("OnUpdate", shouldFollow and followCursor or nil)
end

--- Shows or hides the ring based on the current settings and combat state, and attaches/detaches its
--- cursor-tracking accordingly. Called on Refresh() (settings changed) and on the combat-transition
--- events (see PLAYER_REGEN_DISABLED/ENABLED below) -- never polled on a timer, since those events are
--- the only times visibility could possibly need to change.
local function updateVisibility()
  if not frame then return end

  local settings = db.profile.mouseRing
  local shouldShow = settings.enabled and (settings.showOutOfCombat or InCombatLockdown())

  if shouldShow then
    followCursor() -- Snap to the current position immediately instead of waiting for the next OnUpdate,
                    -- so the ring doesn't flash at its last remembered (possibly stale) position for a frame.
    frame:Show()
  else
    frame:Hide()
  end
  setFollowingCursor(shouldShow)
end

--- Applies all current `db.profile.mouseRing` settings (scale, opacity, color, visibility) to the ring.
--- Called once on module enable and again any time an option changes in Options.lua.
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

--- Enables or disables the whole module and persists that choice to the saved settings. Called from the
--- "Enable" checkbox in Options.lua.
---@param enabled boolean - Whether the Mouse Ring feature should be turned on.
function module:SetEnabled(enabled)
  db.profile.mouseRing.enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

--- AceAddon lifecycle callback, fired once when the addon loads. Creates the frame up front (cheap, and
--- keeps createFrame() calls consistent everywhere else) and disables the module immediately if the
--- saved settings have it turned off, so OnEnable() never runs needlessly at login.
function module:OnInitialize()
  createFrame()
  if not db.profile.mouseRing.enabled then self:Disable() end
end

--- AceAddon lifecycle callback, fired whenever the module becomes enabled (at login, or via SetEnabled).
--- Registers combat-transition events -- the only external triggers that can change whether the ring
--- should be visible -- and applies current settings immediately.
function module:OnEnable()
  self:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
  self:RegisterEvent("PLAYER_REGEN_ENABLED") -- Leaving combat
  self:Refresh()
end

--- AceAddon lifecycle callback, fired whenever the module becomes disabled. Tears down everything that
--- could otherwise keep costing CPU or holding the frame visible: unregisters events, detaches the
--- cursor-tracking OnUpdate script, and hides the frame.
function module:OnDisable()
  self:UnregisterAllEvents()
  setFollowingCursor(false)
  if frame then frame:Hide() end
end

--- Event handler for PLAYER_REGEN_DISABLED (fires the instant the player enters combat). Re-evaluates
--- visibility, since combat state is one of the two things (alongside the "Show Out of Combat" setting)
--- that determines whether the ring should be shown.
function module:PLAYER_REGEN_DISABLED()
  updateVisibility()
end

--- Event handler for PLAYER_REGEN_ENABLED (fires the instant the player leaves combat). Re-evaluates
--- visibility for the same reason as PLAYER_REGEN_DISABLED above.
function module:PLAYER_REGEN_ENABLED()
  updateVisibility()
end

