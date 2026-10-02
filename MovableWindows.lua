setfenv(1, _G.SlackHacks)

--=====================================================================
-- Movable Windows
--=====================================================================
-- Lets you drag most Blizzard windows around by their title bar, and resize them with the mouse wheel.
-- Reviewed directly against Blizzard's own FrameXML, specifically `PanelDragBarMixin`
-- (Blizzard_SharedXML/SharedUIPanelTemplates.lua) -- the exact native drag-bar mixin Blizzard's own
-- movable panels use. Every registered window gets the same unprotected child overlay, sized to just its
-- title-bar strip (not the whole window), inheriting the real "PanelDragBarTemplate" (so dragging goes
-- through Blizzard's own frame:StartMoving()/StopMovingOrSizing() path, not a custom position hack, and
-- still works on protected frames outside combat lockdown).
--
-- This only ships a curated subset of commonly-used frames (not an exhaustive, version-gated database of
-- every frame across every WoW expansion back to Vanilla) since we only target current retail and WoW
-- Forever (Classic Era). Use module:RegisterFrame(frameName, frameData) to add more.
--
-- Two windows get special handling instead of the generic drag handle: Blizzard's toast popups (moved via
-- the real Edit Mode) and the Zone Map (moved by its own tab, with a "Change Scale" tab-menu slider). See
-- their own sections below for why.

local module = Self:NewModule("MovableWindows", "AceEvent-3.0", "AceHook-3.0")
Self.MovableWindows = module

--=====================================================================
-- Constants & state
--=====================================================================
local MIN_SCALE = 0.3 -- steps are 0.1, kept above 0.25 so nothing can shrink to invisible
local MAX_SCALE = 2.5
local DEFAULT_TITLE_BAR_HEIGHT = 20 -- matches most Blizzard windows' native title/border strip height
-- Blizzard's own portrait/title-bar decorations (NineSlice, TitleContainer, CloseButton, etc.) are commonly
-- placed at up to frame:GetFrameLevel()+510 (see PortraitFrameMixin:SetFrameLevelsFromBaseLevel); the drag
-- handle needs to sit above all of that or those elements silently eat the mousedown before it ever arrives.
local TITLE_BAR_HANDLE_LEVEL_OFFSET = 1000
local FAKE_UI_PARENT_NAME = "SlackHacksMovableWindowsFakeUIParent"
-- Blizzard's alert/toast popups -- achievements, notable items (mounts/toys/recipes/BoE epics/etc.), honor,
-- garrison, etc. -- all get anchored under this one global container frame.
local TOAST_FRAME_NAME = "AlertFrame"

-- A stand-in for UIParent: dragged frames get anchored relative to this instead of the real UIParent,
-- since UIParent itself can be protected/tainted in ways that make re-anchoring to it directly unreliable.
local fakeUIParent = CreateFrame("Frame", FAKE_UI_PARENT_NAME, nil, "SecureFrameTemplate")
fakeUIParent:SetAllPoints(UIParent)

local frameRegistry = {} -- [frame] = frameData
local registeredFrames = {} -- top-level [frameName] = frameData (what we try to (re)process)
local moveHandles = {} -- [handleFrame] = true
local mouseoverFrames = {} -- [frame] = true
local sessionScales = {} -- [frameName] = scale, cleared on reload
local combatLockdownQueue = {}
local setFramePointsQueue = {}
local ignoreSetPointHook = false
local mouseWheelCaptureFrame
local queueProcessorFrame
local awaitingGlobalMouseUp
local toastMover
local toastSelection
local toastHooked

-- Forward declarations for functions referenced before their definition further down the file.
local onMouseDown, onMouseUp, onMouseWheel, onShow, onSetPoint, onSizeUpdate, checkMouseWheelCapture
local registerToastEditMode
local setupZoneMap, setZoneMapScale

--=====================================================================
-- Settings helpers
--=====================================================================
--- Shorthand for this module's slice of the saved-variables DB. Centralized in one place (rather than
--- inlining `db.profile.movableWindows` everywhere) so the DB layout only has to be known here.
---@return table settings - The module's profile settings table.
local function settings()
  return db.profile.movableWindows
end

--- Whether the module's own on/off switch is enabled. Checked before doing any work so a disabled module
--- costs nothing at runtime (no hooks fire, no frames get processed).
---@return boolean enabled
local function isModuleEnabled()
  return settings() and settings().enabled or false
end

--- Resolves a user-configured modifier-key setting (one of "SHIFT"/"CTRL"/"ALT"/"NONE") to whether that
--- key is currently held. Shared by both the move-modifier and scale-modifier checks below so the two
--- independently configurable modifiers (e.g. move with no modifier, scale with Shift) use identical logic.
---@param key string - "SHIFT", "CTRL", "ALT", or "NONE".
---@return boolean isDown
local function isModifierKeyDown(key)
  if key == "SHIFT" then return IsShiftKeyDown() end
  if key == "CTRL" then return IsControlKeyDown() end
  if key == "ALT" then return IsAltKeyDown() end
  return true -- "NONE": no modifier required
end

--- Whether the user's configured "move" modifier key is currently held.
---@return boolean isDown
local function isMoveModifierDown()
  return isModifierKeyDown(settings().modifierKey)
end

--- Whether the user's configured "scale" (mouse-wheel-resize) modifier key is currently held.
---@return boolean isDown
local function isScaleModifierDown()
  return isModifierKeyDown(settings().scaleModifierKey)
end

--=====================================================================
-- Frame name / registry helpers
--=====================================================================
--- Looks up the global name a registered frame was registered under. Used when saving a position/anchor
--- so the anchor can be serialized as a stable string (survives reload) instead of a live frame reference.
---@param frame Frame? - A frame previously registered via module:RegisterFrame() (directly or as a SubFrame).
---@return string? frameName
local function getFrameName(frame)
  local frameData = frame and frameRegistry[frame]
  return frameData and frameData.storage and frameData.storage.frameName
end

--- Resolves a global frame name back to the live frame object, following dotted paths (e.g.
--- "Parent.ChildFrame") one segment at a time through the `_G` table. Used to re-resolve a saved anchor's
--- `relativeFrame` name back into a real frame reference when reapplying a saved position.
---@param frameName string - Global name, optionally dotted (e.g. "CharacterFrame" or "Parent.ChildFrame").
---@return Frame? frame - nil if any segment of the path doesn't currently exist.
local function getFrameFromName(frameName)
  local object = _G
  for key in frameName:gmatch("([^.]+)") do
    if not object[key] then return nil end
    object = object[key]
  end
  return object
end

--=====================================================================
-- Combat lockdown queue
--=====================================================================
--- Runs `func(...)` immediately if not in combat, or defers it until combat ends. Protected frames can't
--- be reparented/repositioned/hooked while in combat lockdown, so anything that needs to touch one has to
--- funnel through here instead of just failing/erroring mid-fight.
---@param func function - Function to call (immediately or once combat ends).
---@param ... any - Arguments to pass to func.
local function addToCombatLockdownQueue(func, ...)
  if not InCombatLockdown() then
    func(...)
    return
  end
  if #combatLockdownQueue == 0 then
    module:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
  tinsert(combatLockdownQueue, { func = func, args = { ... } })
end

--- AceEvent handler for PLAYER_REGEN_ENABLED (combat ends): flushes and runs every queued deferred call
--- from addToCombatLockdownQueue(), in the order they were queued, then unregisters itself again since
--- there's nothing to listen for until the queue has something in it again.
function module:PLAYER_REGEN_ENABLED()
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  if #combatLockdownQueue == 0 then return end
  local queued = combatLockdownQueue
  combatLockdownQueue = {}
  for _, item in ipairs(queued) do
    item.func(unpack(item.args))
  end
end

--=====================================================================
-- Frame position helpers
--=====================================================================
--- Captures a frame's CURRENT anchor point(s) exactly as SetPoint currently has them, resolving any
--- registered relative frame to its stable name (so it survives a reload) rather than a live reference.
--- Used only to remember a detachable subframe's original (parent-relative) anchor before we detach it,
--- so RightButton+Alt can put it back exactly where Blizzard originally anchored it.
---@param frame Frame - The frame whose current anchor points should be captured.
---@return table? points - Array of {anchorPoint, relativeFrame, relativePoint, offX, offY}, or nil if the
---  frame currently has no points at all.
local function capturePoints(frame)
  local numPoints = frame:GetNumPoints()
  if not numPoints or numPoints == 0 then return nil end

  local points = {}
  for i = 1, numPoints do
    local anchorPoint, relativeFrame, relativePoint, offX, offY = frame:GetPoint(i)
    local relativeFrameName
    if relativeFrame then
      relativeFrameName = getFrameName(relativeFrame) or (relativeFrame.GetName and relativeFrame:GetName())
    end
    points[i] = {
      anchorPoint = anchorPoint,
      relativeFrame = relativeFrameName or relativeFrame,
      relativePoint = relativePoint,
      offX = offX,
      offY = offY,
    }
  end
  return points
end

--- Converts a frame's current on-screen position into a single anchor point relative to whichever screen
--- edge (or center) it's actually closest to -- e.g. a frame near the bottom-left becomes
--- `{anchorPoint = "BOTTOMLEFT", relativeFrame = FAKE_UI_PARENT_NAME, ...}` with small offsets, instead of
--- an arbitrary absolute pixel position. This is what makes a saved drag position still look right after
--- a UI reload or resolution/aspect-ratio change: an edge-relative anchor scales naturally with the
--- screen, while a raw absolute coordinate would not. Always anchors relative to our own `fakeUIParent`
--- stand-in (see its declaration above) rather than the real UIParent, for the same taint-safety reason
--- setFramePoint() below routes through it.
---@param frame Frame - The frame whose current screen position should be captured.
---@return table? points - A single-entry array (same shape as capturePoints()) usable with setFramePoints().
local function getAbsoluteFramePosition(frame)
  local scale = frame:GetScale()
  if not scale or not frame:GetLeft() then return nil end

  local left, top = frame:GetLeft() * scale, frame:GetTop() * scale
  local right, bottom = frame:GetRight() * scale, frame:GetBottom() * scale
  local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()

  local horizontalOffset = (left + right) / 2 - screenWidth / 2
  local verticalOffset = (top + bottom) / 2 - screenHeight / 2

  local x, y, point = 0, 0, ""

  if left < (screenWidth - right) and left < abs(horizontalOffset) then
    x, point = left, "LEFT"
  elseif (screenWidth - right) < abs(horizontalOffset) then
    x, point = right - screenWidth, "RIGHT"
  else
    x = horizontalOffset
  end

  if bottom < (screenHeight - top) and bottom < abs(verticalOffset) then
    y, point = bottom, "BOTTOM" .. point
  elseif (screenHeight - top) < abs(verticalOffset) then
    y, point = top - screenHeight, "TOP" .. point
  else
    y = verticalOffset
  end

  if point == "" then point = "CENTER" end

  return {
    {
      anchorPoint = point,
      relativeFrame = FAKE_UI_PARENT_NAME,
      relativePoint = point,
      offX = x,
      offY = y,
    },
  }
end

local secureAnchorFrame = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")

--- Calls the frame's real, un-hooked SetPoint (bypassing our own onSetPoint watchdog hook further below),
--- so we can reposition a frame ourselves without that same call re-triggering our own "something moved
--- this frame, reassert the dragged position" anti-rubberband logic.
---@param frame Frame
---@param anchorPoint string
---@param relativeFrame Frame?
---@param relativePoint string
---@param offX number
---@param offY number
local function realSetPoint(frame, anchorPoint, relativeFrame, relativePoint, offX, offY)
  local setPoint = frame.SetPointBase or frame.SetPoint
  setPoint(frame, anchorPoint, relativeFrame, relativePoint, offX, offY)
end

--- Applies one saved anchor point to a frame. Resolves a string relativeFrame name back to a live frame
--- (via _G), and redirects any saved reference to the real UIParent onto our own `fakeUIParent` stand-in
--- (see its declaration above) since re-anchoring directly to UIParent can be unreliable/tainted for some
--- protected frames. Setting a point directly is fine in the overwhelming majority of cases, but if the
--- anchor target itself turns out to be protected/forbidden outside of combat, that's routed through a
--- `SecureHandlerBaseTemplate` snippet instead (Execute() runs with Blizzard's own execution context) so
--- our own insecure code can never be blamed for tainting anything downstream of that protected frame.
---@param frame Frame - The frame to reposition.
---@param point table - One entry from capturePoints()/getAbsoluteFramePosition(): {anchorPoint,
---  relativeFrame, relativePoint, offX, offY}.
---@param scale number - Divides offX/offY by this (the frame's own GetScale()) so saved pixel offsets,
---  which were captured in that same scale, still land in the same visual spot regardless of scale changes.
local function setFramePoint(frame, point, scale)
  ignoreSetPointHook = true

  local relativeFrame = point.relativeFrame
  if type(relativeFrame) == "string" then
    relativeFrame = _G[relativeFrame]
  end
  if relativeFrame == UIParent then
    relativeFrame = fakeUIParent
  end

  if not InCombatLockdown() and (not relativeFrame or select(2, relativeFrame:IsProtected())) then
    secureAnchorFrame:SetFrameRef("frame", frame)
    if relativeFrame then
      secureAnchorFrame:SetFrameRef("relativeFrame", relativeFrame)
    end
    secureAnchorFrame:SetAttribute("hasRelativeFrame", relativeFrame and true or false)
    secureAnchorFrame:SetAttribute("anchorPoint", point.anchorPoint)
    secureAnchorFrame:SetAttribute("relativePoint", point.relativePoint)
    secureAnchorFrame:SetAttribute("offX", point.offX / scale)
    secureAnchorFrame:SetAttribute("offY", point.offY / scale)
    secureAnchorFrame:Execute([[
      local frame = self:GetFrameRef("frame")
      local relativeFrame
      if self:GetAttribute("hasRelativeFrame") then
        relativeFrame = self:GetFrameRef("relativeFrame")
      end
      frame:SetPoint(self:GetAttribute("anchorPoint"), relativeFrame, self:GetAttribute("relativePoint"), self:GetAttribute("offX"), self:GetAttribute("offY"))
    ]])
  else
    realSetPoint(frame, point.anchorPoint, relativeFrame, point.relativePoint, point.offX / scale, point.offY / scale)
  end

  ignoreSetPointHook = false
end

--- Applies a full saved point list (as produced by capturePoints()/getAbsoluteFramePosition()) to a
--- frame, clearing any existing points first. This is the one function actually responsible for moving a
--- frame to a saved/dragged position -- everything else (drag handlers, the onSetPoint watchdog, Edit Mode
--- toast dragging) eventually funnels through this.
---@param frame Frame - The frame to reposition. No-op (returns false) if it's protected and we're in combat.
---@param points table? - Point list to apply; no-op (returns false) if nil/empty.
---@param raw boolean? - If true, skip dividing offsets by the frame's scale (points are already in that
---  frame's own local units, e.g. for the toast mover which isn't scale-adjusted).
---@return boolean applied
local function setFramePoints(frame, points, raw)
  if InCombatLockdown() and frame:IsProtected() then return false end
  if not points or not points[1] then return false end

  frame:ClearAllPoints()
  local scale = raw and 1 or frame:GetScale()
  for _, point in ipairs(points) do
    setFramePoint(frame, point, scale)
  end
  return true
end

--- Queues a frame to have setFramePoints() re-applied on the very next frame update, instead of calling
--- it immediately. Calling SetPoint again from directly inside our own SetPoint hook (onSetPoint below)
--- can be unreliable/re-entrant, so the "permanent" strategy's rubberband watchdog defers to here instead
--- of reapplying synchronously. Multiple queue requests for the same frame within one frame just overwrite
--- each other (last write wins) since only the final target position before the next update matters.
---@param frame Frame
---@param points table - Point list to apply on the next frame update.
local function addToSetFramePointsQueue(frame, points)
  if setFramePointsQueue[frame] then return end
  setFramePointsQueue[frame] = points

  if not queueProcessorFrame then
    queueProcessorFrame = CreateFrame("Frame")
  end
  queueProcessorFrame:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    for queuedFrame, queuedPoints in pairs(setFramePointsQueue) do
      setFramePoints(queuedFrame, queuedPoints)
    end
    wipe(setFramePointsQueue)
  end)
end

--- Wires up frameData.storage.points, the in-memory table that tracks a frame's drag/detach state. Under
--- the "session" save strategy this is just a plain scratch table (cleared on reload). Under "permanent"
--- it's instead aliased *by reference* to settings().points[frameName], so any later mutation (a drag, a
--- detach) is automatically persisted with no separate save step, and is naturally restored next login
--- since the same (already-populated) saved-variable table gets re-aliased here again. Also validates any
--- previously-saved detachPoints on load: if the frame it was detached-anchored to no longer exists (e.g.
--- from a different addon/version), the detached state is discarded rather than silently re-attaching to
--- a Frame that doesn't exist.
---@param frame Frame
---@param frameData table - The registered frameData for this frame; must already have `.storage.frameName` set.
---@return boolean ok - false only if frameData.storage.frameName is unset (shouldn't normally happen).
local function setupPointStorage(frame, frameData)
  local frameName = frameData.storage.frameName
  if not frameName then return false end

  if settings().savePositionStrategy ~= "permanent" then
    frameData.storage.points = frameData.storage.points or {}
    return true
  end

  if frameData.storage.points and frameData.storage.points == settings().points[frameName] then return true end

  settings().points[frameName] = settings().points[frameName] or {}
  frameData.storage.points = settings().points[frameName]

  if frameData.storage.points.detachPoints then
    local firstPoint = frameData.storage.points.detachPoints[1]
    local relativeFrameName = firstPoint and firstPoint.relativeFrame
    if type(relativeFrameName) == "string" and getFrameFromName(relativeFrameName) then
      frameData.storage.detached = true
    else
      wipe(frameData.storage.points)
    end
  end

  return true
end

--=====================================================================
-- Frame scale helpers
--=====================================================================
--- The frame's EFFECTIVE scale relative to the whole registry tree, i.e. its own GetScale() compounded
--- with its registered parent's effective scale (recursively) -- unless ManuallyScaleWithParent is set,
--- in which case the parent relationship is skipped since that subframe already scales itself in lockstep
--- with the parent via other means (see setFrameScaleSubs below) and shouldn't be double-counted.
---@param frame Frame - Must already be registered (a key in frameRegistry).
---@return number effectiveScale
local function getFrameScale(frame)
  local frameData = frameRegistry[frame]
  local parentScale = (frameData.storage.frameParent and not frameData.ManuallyScaleWithParent and getFrameScale(frameData.storage.frameParent)) or 1
  return frame:GetScale() * parentScale
end

--- Propagates a parent frame's scale change down to its registered SubFrames, keeping each subframe's
--- EFFECTIVE (on-screen) size constant across the parent's rescale, with one exception per subframe:
--- - ManuallyScaleWithParent subframes that are still attached: their own GetScale() is nudged so their
---   effective size tracks the parent's new scale (rather than staying visually the same size the parent
---   just changed).
--- - Detached subframes that do NOT want to scale with the parent: since a detached subframe is no longer
---   visually parented under it, its own GetScale() is compensated in the opposite direction so its actual
---   effective size doesn't silently change just because some *other*, no-longer-related frame rescaled.
--- - Everything else (still-attached, non-ManuallyScaleWithParent subframes): scale simply follows the
---   parent naturally through Blizzard's own frame hierarchy, so just recurse to handle any of ITS own
---   subframes the same way.
---@param frame Frame - The parent frame whose scale just changed.
---@param oldScale number - Its effective scale before the change.
---@param newScale number - Its effective scale after the change.
local function setFrameScaleSubs(frame, oldScale, newScale)
  local frameData = frameRegistry[frame]
  if not frameData.SubFrames then return end

  for _, subFrameData in pairs(frameData.SubFrames) do
    local subFrame = subFrameData.storage and subFrameData.storage.frame
    if subFrame then
      if subFrameData.ManuallyScaleWithParent and not subFrameData.storage.detached then
        subFrame:SetScale((subFrame:GetScale() / oldScale) * newScale)
      elseif not subFrameData.ManuallyScaleWithParent and subFrameData.storage.detached then
        subFrame:SetScale((oldScale * subFrame:GetScale()) / newScale)
      else
        setFrameScaleSubs(subFrame, oldScale, newScale)
      end
    end
  end
end

--- Sets a registered frame's scale to (as close as possible to) the requested EFFECTIVE scale, persisting
--- it (both to the saved-variable table and the session-only cache) and cascading the change to any
--- registered SubFrames via setFrameScaleSubs() so they don't visually shrink/grow just because their
--- parent did. No-ops (but returns true, i.e. "handled") if the frame is currently protected mid-combat,
--- since scale changes on protected frames are combat-restricted the same way position changes are.
---@param frame Frame - Must already be registered.
---@param requestedScale number - Desired effective (compounded) scale.
---@return boolean handled - false only if the frame isn't registered at all.
local function setFrameScale(frame, requestedScale)
  local frameData = frameRegistry[frame]
  if not frameData then return false end
  if InCombatLockdown() and frame:IsProtected() then return true end

  local oldScale = getFrameScale(frame)
  local newScale = requestedScale

  if frameData.storage.detached then
    local parentScale = getFrameScale(frameData.storage.frameParent)
    newScale = frameData.ManuallyScaleWithParent and requestedScale or (requestedScale / parentScale)
  elseif frameData.ManuallyScaleWithParent then
    newScale = getFrameScale(frameData.storage.frameParent)
  end

  local frameName = frameData.storage.frameName
  settings().scales[frameName] = newScale
  sessionScales[frameName] = newScale
  frame:SetScale(newScale)

  setFrameScaleSubs(frame, oldScale, newScale)

  return true
end

--=====================================================================
-- Movement start/stop (shared between direct EnableMouse frames and secure move handles)
--=====================================================================
--- Begins dragging `frame`. For a plain (non-protected) frame this is just its own real StartMoving(),
--- called from our own insecure OnMouseDown handler. For a PanelDragBarTemplate move handle wrapping a
--- protected frame, we can't call StartMoving() ourselves from an insecure OnMouseDown/OnDragStart --
--- Blizzard's PanelDragBarMixin already has its own native OnDragStart wired up via
--- `RegisterForDrag("LeftButton")`, which is what's actually allowed to call the protected frame's
--- StartMoving(). `onDragStartCallback` returning falsy (its default, set on creation) is what makes that
--- native handler bail out immediately -- so "arming" the drag here means just clearing that callback so
--- the *next* native OnDragStart (from the real drag gesture already in progress) is allowed to proceed.
---@param frame Frame - Either the frame itself, or (for protected frames) its move-handle overlay.
local function startMoving(frame)
  if moveHandles[frame] then
    -- Arm the handle's own native OnDragStart (already listening via PanelDragBarTemplate's RegisterForDrag)
    -- so Blizzard's own StartMoving() call fires from a real drag event, not from our insecure hook.
    frame.onDragStartCallback = nil
    return
  end
  frame:StartMoving()
end

--- Ends dragging `frame`, mirroring startMoving()'s move-handle special case: rearms the handle's
--- `onDragStartCallback` back to its default "block" state so the NEXT drag gesture also has to originate
--- from a real native OnDragStart before StartMoving() can fire again.
---@param frame Frame - Either the frame itself, or (for protected frames) its move-handle overlay.
local function stopMoving(frame)
  if moveHandles[frame] then
    frame.onDragStartCallback = function() return false end
    return
  end
  frame:StopMovingOrSizing()
end

--=====================================================================
-- Mouse handlers
--=====================================================================
--- Core mousedown handler shared by every registered frame's move handle. Recurses up through
--- frameData.storage.frameParent first (so, e.g., mousedown on a still-attached subframe's handle is
--- treated as if it happened on the root window, unless that subframe has since been Detached), then
--- handles three distinct gestures at whichever level in the chain actually owns the interaction:
--- - Left-click + Alt (only if Detachable and not already detached): detaches the subframe from its
---   parent, remembering its original anchor (via capturePoints()) so it can be reattached later.
--- - Left-click (any other case, or if already detached): begins a native Blizzard drag via startMoving().
--- - Right-click + Alt (only if currently detached): reattaches the subframe to its original saved anchor.
--- - Right-click + the scale modifier: resets scale to 1.
--- - Right-click + Shift: clears any dragged position, snapping back to whatever anchor Blizzard's own
---   code (or our own detach-restore) currently has it pointed at.
---@param frame Frame - The (possibly non-root) registered frame the mousedown conceptually applies to.
---@param button string - "LeftButton" or "RightButton".
---@param moveHandle Frame? - The PanelDragBarTemplate overlay actually receiving input, if any (nil for
---  frames that are directly EnableMouse()'d instead of using a handle).
---@return boolean handled - Whether this call (or a parent in the chain) did something with the click.
local function doOnMouseDown(frame, button, moveHandle)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return false end

  setupPointStorage(frame, frameData)

  local returnValue, parentReturnValue = false, false

  if button == "LeftButton" then
    if not moveHandle and IsAltKeyDown() and frameData.Detachable and not frameData.storage.detached then
      frameData.storage.points.detachPoints = capturePoints(frame)
      frameData.storage.detached = true
      returnValue = true
      PlaySound((SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN) or 839)
    end

    if not frameData.storage.detached then
      parentReturnValue = (frameData.storage.frameParent and doOnMouseDown(frameData.storage.frameParent, button, moveHandle)) or false
    end

    if (frameData.storage.detached or not parentReturnValue) and isMoveModifierDown() then
      local userPlaced = frame:IsUserPlaced()

      frame:SetMovable(true)
      startMoving(moveHandle or frame)
      frame:SetUserPlaced(userPlaced)
      frameData.storage.points.startPoints = frameData.storage.points.startPoints or getAbsoluteFramePosition(frame)
      frameData.storage.isMoving = true
      returnValue = true
    end
  end

  return returnValue or parentReturnValue
end

--- Public entry point wired to every move handle's (and any directly-EnableMouse'd frame's) OnMouseDown.
--- Resolves a move-handle overlay back to the real frame it belongs to (handles are children reparented
--- under the frame they control -- see makeMoveHandle) before delegating to doOnMouseDown().
---@param frame Frame - The frame that actually received the mousedown (may be a move handle).
---@param button string
function onMouseDown(frame, button)
  local moveHandle = moveHandles[frame] and frame or nil
  if moveHandle then frame = moveHandle:GetParent() end
  return doOnMouseDown(frame, button, moveHandle)
end

--- Mouse-up counterpart to doOnMouseDown(): ends any in-progress drag, snapshots and persists the frame's
--- new position via getAbsoluteFramePosition(), and marks it "dragged" so the onSetPoint watchdog knows
--- to defend this position against being overwritten later. Also handles finishing the RightButton+Alt
--- reattach / scale-reset / Shift-reset gestures doOnMouseDown() started evaluating. Recurses up the
--- parent chain the same way doOnMouseDown() does, for the same reason (attached subframes defer to root).
---@param frame Frame
---@param button string
---@param moveHandle Frame?
---@return boolean handled
local function doOnMouseUp(frame, button, moveHandle)
  if moveHandle then stopMoving(moveHandle) end

  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return false end

  local returnValue, parentReturnValue = false, false

  if not frameData.storage.detached then
    parentReturnValue = (frameData.storage.frameParent and doOnMouseUp(frameData.storage.frameParent, button, moveHandle)) or false
  end

  if frameData.storage.detached or not parentReturnValue then
    if button == "LeftButton" and frameData.storage.isMoving then
      stopMoving(moveHandle or frame)

      frameData.storage.points.dragPoints = getAbsoluteFramePosition(frame)
      frameData.storage.points.dragged = true
      frameData.storage.isMoving = nil
      returnValue = true

      -- When strategy == "permanent", storage.points IS (by reference) settings().points[frameName], so
      -- this mutation is already persisted -- no separate save step needed (see setupPointStorage above).
      setFramePoints(frame, frameData.storage.points.dragPoints)

    elseif button == "RightButton" then
      local fullReset = false

      if IsAltKeyDown() and frameData.storage.detached then
        if setFramePoints(frame, frameData.storage.points.detachPoints, true) then
          frameData.storage.points.detachPoints = nil
          frameData.storage.detached = nil
          returnValue = true
          fullReset = true
          PlaySound((SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE) or 840)
        end
      end

      if isScaleModifierDown() or fullReset then
        returnValue = setFrameScale(frame, 1) or returnValue
      end

      if IsShiftKeyDown() or fullReset then
        if frameData.storage.points then
          if not fullReset and frameData.storage.points.startPoints then
            setFramePoints(frame, frameData.storage.points.startPoints)
            frameData.storage.points.startPoints = nil
          end
          frameData.storage.points.dragPoints = nil
          frameData.storage.points.dragged = nil
        end
        returnValue = true
      end
    end
  end

  return returnValue or parentReturnValue
end

--- Public entry point wired to every move handle's OnMouseUp/OnDragStop (and the global-mouse-up safety
--- net below). Resolves handle -> real frame the same way onMouseDown() does, then delegates to
--- doOnMouseUp().
---@param frame Frame
---@param button string
function onMouseUp(frame, button)
  local moveHandle = moveHandles[frame] and frame or nil
  if moveHandle then frame = moveHandle:GetParent() end
  return doOnMouseUp(frame, button, moveHandle)
end

--- Core mouse-wheel-to-scale handler shared by every registered frame, recursing up the parent chain the
--- same way doOnMouseDown()/doOnMouseUp() do (an attached subframe's wheel input scales the root window
--- unless it's Detached). Scale changes in increments of 0.1 per wheel notch, clamped to
--- [MIN_SCALE, MAX_SCALE].
---@param frame Frame
---@param delta number - Wheel delta from OnMouseWheel (positive = scroll up/scale in, negative = down/out).
---@return boolean handled
local function doOnMouseWheel(frame, delta)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return false end

  local returnValue, parentReturnValue = false, false

  if not frameData.storage.detached then
    parentReturnValue = (frameData.storage.frameParent and doOnMouseWheel(frameData.storage.frameParent, delta)) or false
  end

  if frameData.storage.detached or not parentReturnValue then
    local oldScale = getFrameScale(frame) or 1
    local newScale = max(MIN_SCALE, min(MAX_SCALE, oldScale + 0.1 * delta))
    returnValue = setFrameScale(frame, newScale) or returnValue
  end

  return returnValue or parentReturnValue
end

--- Public entry point for mouse-wheel scaling. Gates on both the feature's own on/off setting and the
--- scale modifier currently being held (this module's whole point is that mouse wheel keeps its normal
--- behavior -- e.g. scrolling a list -- unless the modifier is held), then delegates to doOnMouseWheel().
---@param frame Frame
---@param delta number
function onMouseWheel(frame, delta)
  if not settings().enableScaling or not isScaleModifierDown() then return false end
  return doOnMouseWheel(frame, delta)
end

--- Marks a registered frame as moused-over for the mouse-wheel-capture arbitration frame (see
--- checkMouseWheelCapture() below), and re-evaluates capture immediately so wheel scaling can engage the
--- instant the modifier is already held when the mouse enters.
---@param frame Frame
local function onEnter(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return end
  mouseoverFrames[frame] = true
  checkMouseWheelCapture()
end

--- Un-marks a frame as moused-over and re-evaluates wheel capture (see onEnter() above).
---@param frame Frame
local function onLeave(frame)
  if not mouseoverFrames[frame] then return end
  mouseoverFrames[frame] = nil
  checkMouseWheelCapture()
end

--- Hooked to every registered frame's OnShow. Doesn't restore POSITION here (that's entirely the
--- onSetPoint watchdog's job, see below, since Blizzard's own code re-anchoring the frame on Show is
--- exactly the case that watchdog exists to catch) -- this only reapplies a previously-saved/session SCALE,
--- since SetScale (unlike SetPoint) isn't something we hook/watchdog the same way. Reruns itself once via
--- RunNextFrame() (skipRerun guards against infinite recursion) because some frames' own OnShow logic
--- resets scale-affecting state a frame later than their own Show fires.
---@param frame Frame
---@param skipRerun boolean? - Internal guard; omit when calling externally.
function onShow(frame, skipRerun)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return end

  if InCombatLockdown() and frame:IsProtected() then
    addToCombatLockdownQueue(onShow, frame)
    return
  end

  local frameName = frameData.storage.frameName

  -- Position isn't restored here -- it's handled entirely by the onSetPoint watchdog below, which
  -- reasserts frameData.storage.points.dragPoints (in-memory for "session", saved-variable-backed via
  -- table aliasing for "permanent") whenever Blizzard's own code re-anchors the frame, e.g. on every Show.
  local scaleStrategy = settings().saveScaleStrategy
  if scaleStrategy == "permanent" and settings().scales[frameName] then
    setFrameScale(frame, settings().scales[frameName])
  elseif sessionScales[frameName] then
    setFrameScale(frame, sessionScales[frameName])
  end

  if not skipRerun then
    RunNextFrame(function() onShow(frame, true) end)
  end
end

--- Starts listening for the next GLOBAL_MOUSE_UP event so a drag that's still "in progress" from the
--- registry's point of view (frameData.storage.isMoving) can be properly finalized even if the actual
--- mouse-up happened somewhere our own OnMouseUp handler never received it (see onSubFrameHide() below
--- for why that can happen).
---@param frame Frame - The (root) frame whose drag should be finalized on the next mouse-up anywhere.
local function waitForGlobalMouseUp(frame)
  awaitingGlobalMouseUp = frame
  module:RegisterEvent("GLOBAL_MOUSE_UP")
end

--- Hooked to a registered SUBFRAME's OnHide (never the root window's). If a subframe is hidden mid-drag --
--- e.g. Blizzard swaps tabs/pages and hides the very panel you're dragging -- its own OnMouseUp will never
--- fire (a hidden frame stops receiving mouse events), which would otherwise leave frameData.storage
--- permanently stuck thinking a drag is still in progress. Recurses to the ROOT frame's storage (drags are
--- always tracked/finalized at the root, see doOnMouseDown/doOnMouseUp) and, if that root thinks it's still
--- mid-drag, falls back to waitForGlobalMouseUp() to catch the mouse-up wherever it actually lands.
---@param frame Frame - The subframe that was just hidden.
local function onSubFrameHide(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return end

  local parent = frameData.storage.frameParent
  if parent then return onSubFrameHide(parent) end

  if frameData.storage.isMoving then
    waitForGlobalMouseUp(frame)
  end
end

--- AceEvent handler for the one-shot GLOBAL_MOUSE_UP registration from waitForGlobalMouseUp(): finalizes
--- the stranded drag by calling the normal onMouseUp() path, then unregisters itself again (this event
--- fires on every mouse-up game-wide, so we only ever want to listen for exactly one before going quiet).
---@param event string - Always "GLOBAL_MOUSE_UP".
---@param button string
function module:GLOBAL_MOUSE_UP(event, button)
  self:UnregisterEvent(event)
  if not awaitingGlobalMouseUp then return end
  onMouseUp(awaitingGlobalMouseUp, button)
  awaitingGlobalMouseUp = nil
end

--- Anti-rubberband watchdog, secure-hooked to every registered frame's real SetPoint. If Blizzard's own
--- code (or another addon) re-anchors a frame we've previously dragged -- e.g. simply reopening the
--- window, or some other frame's layout logic repositioning it -- this immediately reasserts the dragged
--- position instead of silently losing it to whatever SetPoint call just happened. Only applies to a
--- frame that's either the root of its chain or has been Detached (an attached, non-root subframe's
--- position is governed entirely by its parent, so it has nothing of its own to defend). Skipped entirely
--- while `ignoreSetPointHook` is true, which setFramePoint() sets around its OWN SetPoint calls so this
--- watchdog doesn't treat US moving the frame as something to fight back against. Under the "permanent"
--- strategy, defers via addToSetFramePointsQueue() instead of reapplying synchronously (safer from
--- directly inside a SetPoint hook -- see that function's own docs).
---@param frame Frame - The frame whose SetPoint was just (really) called.
function onSetPoint(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return end
  if settings().savePositionStrategy == "off" then return end
  if ignoreSetPointHook then return end

  frameData.storage.points = frameData.storage.points or {}
  if
    frameData.storage.points.dragged
    and (not frameData.storage.frameParent or frameData.storage.detached)
  then
    if settings().savePositionStrategy ~= "permanent" then
      setFramePoints(frame, frameData.storage.points.dragPoints)
    else
      addToSetFramePointsQueue(frame, frameData.storage.points.dragPoints)
    end
  end
end

--- Secure-hooked to every registered frame's SetWidth/SetHeight. Recomputes SetClampRectInsets so a frame
--- can never be dragged/scaled so far off-screen that none of it remains visible/grabbable -- specifically,
--- at least `clampDistance` pixels of the frame must always stay on-screen on every edge, regardless of
--- how big the frame currently is (hence recomputing on every size change, not just once). Skipped for
--- IgnoreClamping frames (frameData opt-out) since those manage their own clamping.
---@param frame Frame
function onSizeUpdate(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled or frameData.IgnoreClamping then return end

  if frame:IsProtected() and InCombatLockdown() then
    addToCombatLockdownQueue(onSizeUpdate, frame)
    return
  end

  local clampDistance = 40
  local clampWidth = (frame:GetWidth() or 0) - clampDistance
  local clampHeight = (frame:GetHeight() or 0) - clampDistance
  frame:SetClampRectInsets(clampWidth, -clampWidth, -clampHeight, clampHeight)
end

--- Secure-hooked to Blizzard's own UIPanelUpdateScaleForFit/UpdateScaleForFit (whichever exists on this
--- client version) -- the function Blizzard uses to auto-shrink certain panels to fit smaller screen
--- resolutions. That auto-shrink otherwise fights directly with a user's own saved/session scale, so this
--- reapplies our own scale immediately afterward to win that fight, the same way onShow() does.
---@param frame Frame
local function onUpdateScaleForFit(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return end

  if InCombatLockdown() and frame:IsProtected() then
    addToCombatLockdownQueue(onUpdateScaleForFit, frame)
    return
  end

  local frameName = frameData.storage.frameName
  local scaleStrategy = settings().saveScaleStrategy
  if scaleStrategy == "permanent" and settings().scales[frameName] then
    setFrameScale(frame, settings().scales[frameName])
  elseif sessionScales[frameName] then
    setFrameScale(frame, sessionScales[frameName])
  end
end

--=====================================================================
-- Mouse wheel capture
--=====================================================================
--- Decides whether the full-screen arbitration frame (mouseWheelCaptureFrame, see
--- initMouseWheelCaptureFrame() below) should currently be intercepting the mouse wheel at all. Called on
--- every MODIFIER_STATE_CHANGED and every onEnter/onLeave. Only actually enables capture when: scaling is
--- turned on, the scale modifier is currently held, the mouse is over at least one registered frame, AND
--- (walking every frame currently under the cursor, topmost-first via GetMouseFoci) nothing ELSE under the
--- cursor already wants the wheel for itself (a scrollable list, edit box, etc.) or is forbidden/secret --
--- we bail out (defer) the instant we hit one of those, before ever reaching a frame we'd otherwise handle,
--- since GetMouseFoci returns frames in top-to-bottom (visual stacking) order. Plain clickable widgets
--- (buttons, tabs, item slots) are deliberately NOT treated as wheel-consumers here even though they can
--- receive mouse focus, since otherwise densely-buttoned windows (CharacterFrame, MerchantFrame, BankFrame)
--- would never be scalable except over their few genuinely blank spots.
function checkMouseWheelCapture()
  if not mouseWheelCaptureFrame then return end
  mouseWheelCaptureFrame:EnableMouseWheel(false)

  if not settings().enableScaling then return end
  if not isScaleModifierDown() or not next(mouseoverFrames) then return end

  local foci = GetMouseFoci and GetMouseFoci() or {}
  if not next(foci) then return end

  for _, focusFrame in ipairs(foci) do
    -- our title-bar handle -- not the base window -- is what's actually mouse-enabled and shows up here,
    -- so resolve the real registered window through it before consulting frameRegistry/mouseoverFrames.
    local frame = moveHandles[focusFrame] and focusFrame:GetParent() or focusFrame
    local frameData = frameRegistry[frame]
    local shouldHandle = frameData and not frameData.IgnoreMouseWheel

    if
      not shouldHandle
      and (
        focusFrame:IsForbidden()
        or (focusFrame.HasSecretValues and focusFrame:HasSecretValues())
        or (not moveHandles[focusFrame] and focusFrame:IsMouseWheelEnabled())
      )
    then
      -- something that actually wants the wheel (scroll list, edit box, etc.) is in the way; defer to it.
      -- plain clickable widgets (buttons, tabs, item slots) don't consume wheel input, so they shouldn't
      -- block scaling -- otherwise densely-buttoned windows (CharacterFrame, MerchantFrame, BankFrame,
      -- etc.) would never be scalable except over their few blank spots.
      return
    end

    if shouldHandle and mouseoverFrames[frame] then
      mouseWheelCaptureFrame:EnableMouseWheel(true)
      return
    end
  end
end

--- One-time setup of the full-screen, TOOLTIP-strata (i.e. above virtually everything) arbitration frame
--- used to implement scroll-to-scale: since a normal registered frame's own EnableMouseWheel would
--- unconditionally steal the wheel from whatever's under the cursor, we instead leave every window's own
--- wheel handling untouched and only turn ON this separate full-screen frame's own wheel handling for the
--- brief moments checkMouseWheelCapture() decides scaling should actually happen -- otherwise it stays
--- disabled and every wheel event passes through to whatever's normally below it, completely unaffected.
local function initMouseWheelCaptureFrame()
  mouseWheelCaptureFrame = CreateFrame("Frame", "SlackHacksMovableWindowsMouseWheelCapture")
  mouseWheelCaptureFrame:SetPoint("TOPLEFT")
  mouseWheelCaptureFrame:SetPoint("BOTTOMRIGHT")
  mouseWheelCaptureFrame:SetScript("OnEvent", checkMouseWheelCapture)
  mouseWheelCaptureFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
  mouseWheelCaptureFrame:SetScript("OnMouseWheel", function(_, delta)
    for _, focusFrame in ipairs(GetMouseFoci()) do
      local frame = moveHandles[focusFrame] and focusFrame:GetParent() or focusFrame
      local frameData = frameRegistry[frame]
      if frameData and not frameData.IgnoreMouseWheel and mouseoverFrames[frame] then
        onMouseWheel(frame, delta)
        return
      end
    end
  end)
  mouseWheelCaptureFrame:SetFrameStrata("TOOLTIP")
  mouseWheelCaptureFrame:SetFrameLevel(9999)
  mouseWheelCaptureFrame:Show()
  mouseWheelCaptureFrame:EnableMouseWheel(false)
end

--=====================================================================
-- Move handles (for protected frames) & frame processing
--=====================================================================
--- Hooks `script` on `frame` via SecureHookScript, but only if the frame's template actually supports that
--- script at all (HasScript) -- some Blizzard frames don't define e.g. OnHide, and hooking a nonexistent
--- script errors instead of silently no-oping.
---@param frame Frame
---@param script string - Script name, e.g. "OnShow".
---@param handler function
local function hookScript(frame, script, handler)
  if frame:HasScript(script) then
    module:SecureHookScript(frame, script, handler)
  end
end

--- Creates the small, unprotected drag-bar overlay used to make a (possibly protected) frame movable and
--- wheel-scalable without ever calling a protected method ourselves. It inherits Blizzard's own
--- "PanelDragBarTemplate" so the actual StartMoving()/StopMovingOrSizing() calls always originate from
--- Blizzard's own template code reacting to a real native drag gesture (see startMoving()/stopMoving()
--- above for how we arm/disarm that), never from our own insecure OnMouseDown/OnDragStart -- this is what
--- lets protected frames (CharacterFrame, BankFrame, etc.) be dragged at all outside of combat lockdown,
--- since a plain insecure StartMoving() call on a protected frame would be blocked.
--- Deliberately sized to only the frame's TOP title-bar strip (not the whole window), and reparented from
--- its creation parent (rootFrame -- needed so its frame level is computed relative to the actual root
--- window, not a possibly-detached subframe) onto the real target frame, positioned via SetPoint so it
--- tracks the frame's own top edge. `titleBarRaise` extends that hit region upward past the frame's
--- technical top-left corner for windows whose visible title/banner artwork bleeds above it (e.g.
--- AchievementFrame). Also owns the scroll-to-scale hover region (onEnter/onLeave) for the same reason:
--- scaling should only engage from the title bar, not anywhere on the window body -- unless
--- `ignoreMouseWheel` opts the frame out of wheel scaling entirely.
---@param frame Frame - The frame this handle should visually track and control.
---@param rootFrame Frame - The root registered frame in this frame's chain (used only to compute frame level).
---@param titleBarHeight number - Height of the drag-bar hit region.
---@param titleBarRaise number - Extra pixels to extend the hit region upward past the frame's own top edge.
---@param ignoreMouseWheel boolean? - If true, skip wiring up scroll-to-scale hover tracking for this handle.
---@return Frame handle
local function makeMoveHandle(frame, rootFrame, titleBarHeight, titleBarRaise, ignoreMouseWheel)
  local handle = CreateFrame("Frame", nil, rootFrame, "PanelDragBarTemplate")
  handle:SetParent(frame)
  handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, titleBarRaise)
  handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, titleBarRaise)
  handle:SetHeight(titleBarHeight + titleBarRaise)
  handle:SetFrameLevel(frame:GetFrameLevel() + TITLE_BAR_HANDLE_LEVEL_OFFSET)
  -- SetPropagateMouseMotion/Clicks are protected once the handle is parented under a protected frame
  -- (e.g. CharacterFrame) -- guard with IsProtected()+pcall so it just silently no-ops there instead of
  -- throwing ADDON_ACTION_BLOCKED; harmless to skip, it only affects click/tooltip passthrough under the
  -- handle's own small title-bar strip.
  if not frame:IsProtected() then
    pcall(handle.SetPropagateMouseMotion, handle, true)
    pcall(handle.SetPropagateMouseClicks, handle, true)
  end
  handle.onDragStartCallback = function() return false end
  handle:HookScript("OnMouseDown", onMouseDown)
  handle:HookScript("OnMouseUp", onMouseUp)
  handle:HookScript("OnDragStop", function(self) onMouseUp(self, "LeftButton") end)

  if not ignoreMouseWheel then
    handle:EnableMouseWheel(true)
    handle:HookScript("OnEnter", function() onEnter(frame) end)
    handle:HookScript("OnLeave", function() onLeave(frame) end)
    if handle:IsMouseOver() then
      RunNextFrame(function()
        if handle:IsMouseOver() then onEnter(frame) end
      end)
    end
  end

  return handle
end

--- Replaces (if one already exists, e.g. re-registration) and (re)creates the move handle for a registered
--- frame, walking up frameData.parentData to find the true root of the registration chain first, since
--- the handle's frame LEVEL (not its visual parent) needs to be computed relative to the root window so it
--- reliably sits above the whole window's own layered decorations regardless of which subframe it's on.
---@param frame Frame
---@param frameData table - Must already have `.storage` set (via makeFrameMovable).
local function makeMoveHandles(frame, frameData)
  if frameData.moveHandle then
    frameData.moveHandle:SetScript("OnEvent", nil)
    frameData.moveHandle:Hide()
    moveHandles[frameData.moveHandle] = nil
  end

  local rootData = frameData
  while rootData.parentData do
    rootData = rootData.parentData
  end
  local rootFrame = (rootData.storage and rootData.storage.frame) or frame

  local handle = makeMoveHandle(
    frame,
    rootFrame,
    frameData.TitleBarHeight or DEFAULT_TITLE_BAR_HEIGHT,
    frameData.TitleBarRaise or 0,
    frameData.IgnoreMouseWheel
  )
  frameData.moveHandle = handle
  moveHandles[handle] = true
end

--- Does the actual one-time setup that turns a live Blizzard frame into a "registered" movable/scalable
--- window: builds its storage table, aliases/loads its saved position (setupPointStorage), enables
--- movability/clamping, creates its move handle (unless NonDraggable), wires up the OnShow/OnHide/SetPoint/
--- SetWidth/SetHeight hooks that make dragging, scaling, and anti-rubberband persistence all work, then
--- immediately re-applies any already-saved show/size/position state so the frame doesn't have to wait for
--- its next natural Show to look right. No-ops (returns false) if the frame is currently protected mid-
--- combat, since none of this setup is safe to do under combat lockdown.
---@param frame Frame - The live frame to make movable.
---@param frameName string - Its registered global name.
---@param frameData table - Registration flags/config passed to module:RegisterFrame().
---@param frameParent Frame? - The parent registered frame, if this is being processed as one of its SubFrames.
---@return boolean ok
local function makeFrameMovable(frame, frameName, frameData, frameParent)
  if not frame then return false end
  if InCombatLockdown() and (frameData.ForceUseSecureMoveHandle or frame:IsProtected()) then return false end

  local clampFrame = not frameParent or frameData.Detachable

  frameData.parentData = frameParent and frameRegistry[frameParent] or nil
  frameData.storage = {
    hooked = true,
    frame = frame,
    frameName = frameName,
    frameParent = frameParent,
  }
  frameRegistry[frame] = frameData

  -- Alias/preload storage.points from the saved-variable table now (not just lazily on first mouse-down)
  -- so the very first onSetPoint watchdog call below can already see a previous session's saved position.
  setupPointStorage(frame, frameData)

  frame:SetMovable(true)
  if not frameData.IgnoreClamping then
    frame:SetClampedToScreen(clampFrame)
  end

  if not frameData.NonDraggable then
    -- always via the title-bar-sized handle (not whole-frame EnableMouse) so dragging -- and scaling --
    -- only starts there (see makeMoveHandle).
    makeMoveHandles(frame, frameData)
  end

  hookScript(frame, "OnShow", onShow)
  if frameParent then
    hookScript(frame, "OnHide", onSubFrameHide)
  end

  if frameData.ForcePosition or not frameData.NonDraggable then
    -- prevents rubberbanding when something else re-anchors the frame after we've moved it
    module:SecureHook(frame, "SetPoint", onSetPoint)
  end
  module:SecureHook(frame, "SetWidth", onSizeUpdate)
  module:SecureHook(frame, "SetHeight", onSizeUpdate)

  onShow(frame)
  onSizeUpdate(frame)
  onSetPoint(frame)

  return true
end

--- Resolves a registered frame NAME to its live frame object (may not exist yet, e.g. a Blizzard
--- sub-addon like Blizzard_AuctionHouseUI that hasn't loaded) and, if found and not already processed,
--- runs makeFrameMovable() on it, then recurses into any configured SubFrames (passing the just-processed
--- frame as their parent). Safe to call repeatedly/redundantly -- ApplyAll() calls this for every
--- registered frame on every ADDON_LOADED, relying on the early-outs here to skip anything already done.
---@param frameName string
---@param frameData table
---@param frameParent Frame? - Passed down when this call is itself processing a SubFrame entry.
---@return boolean ok
local function processFrame(frameName, frameData, frameParent)
  local frame = getFrameFromName(frameName)
  if not frame then return false end -- retried later via ApplyAll()/ADDON_LOADED

  if frameData.storage and frameData.storage.hooked then return true end

  if InCombatLockdown() and frame:IsProtected() then
    addToCombatLockdownQueue(processFrame, frameName, frameData, frameParent)
    return false
  end

  if not makeFrameMovable(frame, frameName, frameData, frameParent) then
    return false
  end

  if frameData.SubFrames then
    for subFrameName, subFrameData in pairs(frameData.SubFrames) do
      processFrame(subFrameName, subFrameData, frame)
    end
  end

  return true
end

--- Reverses makeFrameMovable(): restores the frame's native movability/clamping/mouse state, hides and
--- forgets its move handle, and marks it `disabled` so every hook installed on it (onShow, onSetPoint,
--- etc.) becomes a no-op from here on rather than trying (and failing) to fully unhook everything --
--- Blizzard's secure hooks can't be selectively removed, only ignored via this disabled flag. Recurses
--- into SubFrames so disabling the module cleans up the whole registered tree, not just root windows.
--- No-ops entirely if the frame is protected mid-combat, since none of this is safe to touch there either
--- (this is only ever called from module:OnDisable(), so simply skipping is acceptable -- disabling mid-
--- combat leaves the frame movable until the player is next out of combat and reloads/toggles again).
---@param frame Frame
local function unprocessFrame(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or not frameData.storage.hooked then return end
  if InCombatLockdown() and frame:IsProtected() then return end

  frame:SetMovable(false)
  if not frameData.IgnoreClamping then frame:SetClampedToScreen(false) end
  frame:EnableMouse(false)
  frame:EnableMouseWheel(false)
  frameData.storage.disabled = true

  if frameData.moveHandle then
    frameData.moveHandle:Hide()
    moveHandles[frameData.moveHandle] = nil
    frameData.moveHandle = nil
  end

  if frameData.SubFrames then
    for _, subFrameData in pairs(frameData.SubFrames) do
      if subFrameData.storage and subFrameData.storage.frame then
        unprocessFrame(subFrameData.storage.frame)
      end
    end
  end
end

--=====================================================================
-- Registration API & built-in frame list
--=====================================================================
--- Register a frame (by global name) to be made movable/scalable. Safe to call at any time; if the
--- frame doesn't exist yet (e.g. a Blizzard sub-addon that hasn't loaded), it's retried automatically.
---@param frameName string - Global name of the frame, e.g. "CharacterFrame" or "Parent.ChildFrame".
---@param frameData table? - Optional flags: SubFrames, Detachable, NonDraggable, IgnoreMouseWheel,
---  IgnoreClamping, ManuallyScaleWithParent, ForceUseSecureMoveHandle, ForcePosition, TitleBarHeight,
---  TitleBarRaise.
function module:RegisterFrame(frameName, frameData)
  frameData = frameData or {}
  registeredFrames[frameName] = frameData
  if isModuleEnabled() then
    processFrame(frameName, frameData)
  end
end

--- Retries processFrame() for every registered frame that isn't hooked yet (frames that didn't exist the
--- first time, e.g. Blizzard sub-addons loaded after this module's own OnEnable), and re-registers the
--- toast Edit Mode integration if it's enabled but hasn't been set up yet (AlertFrame or
--- Blizzard_EditMode themselves may not have loaded the first time either), and likewise retries the Zone
--- Map setup (Blizzard_BattlefieldMap is load-on-demand). Wired to ADDON_LOADED so this
--- naturally happens every time something new finishes loading, and also called once directly from
--- OnEnable() to cover anything already loaded at that point.
function module:ApplyAll()
  if not isModuleEnabled() then return end
  for frameName, frameData in pairs(registeredFrames) do
    if not (frameData.storage and frameData.storage.hooked) then
      processFrame(frameName, frameData)
    end
  end
  if settings().moveToasts and not toastSelection then
    registerToastEditMode()
  end
  setupZoneMap()
end

--- Slash-command/options-panel action: forgets every saved drag position for every registered frame
--- (including detach anchors), reverting everything back to Blizzard's own default anchors on next Show.
function module:ResetPositions()
  wipe(settings().points)
end

--- Slash-command/options-panel action: forgets every saved AND session scale for every registered frame,
--- reverting everything back to its native scale (1.0, or whatever Blizzard's own code sets) on next Show.
--- The Zone Map is snapped back to 1.0 immediately instead, since it isn't a registry frame and so has no
--- onShow() hook that would pick up the wiped scale later.
function module:ResetScales()
  wipe(settings().scales)
  wipe(sessionScales)
  if isModuleEnabled() then
    setZoneMapScale(1)
  end
end

-- Toasts -- achievements, notable items (mounts/toys/recipes/BoE epics/etc.), honor, garrison, money,
-- etc. -- all funnel into one shared global container, "AlertFrame" (Blizzard calls the individual popups
-- "toasts" internally, e.g. AlertFrame_ShowNewAlert/AlertFrameQueueMixin, and third-party addons that
-- expose this same feature commonly call it "Toasts" too, so that's what we call it here).
--
-- This is opt-in via its own checkbox, separate from the curated defaults below, since most people don't
-- want to reposition it. Unlike every other frame in this file, it's made movable through Blizzard's
-- *real* Edit Mode (Escape -> Edit Mode) instead of our own custom drag-handle system, per the user's
-- request. Edit Mode has no native entry for AlertFrame, and AlertFrame itself can't be the thing we
-- attach a selection box to anyway: Blizzard hides/shows it dynamically (there's no toast to show most of
-- the time), and a Blizzard frame's own Hide() forces every child -- including a selection box we parented
-- to it -- invisible regardless of that child's own Show() call. So instead we create our own tiny,
-- permanently-shown, invisible-by-default "mover" frame that we fully control, tell AlertFrame to anchor
-- itself off of that mover via the real Blizzard API
-- `AlertContainerMixin:SetBaseAnchorFrame()`/`:UpdateAnchors()` (reviewed directly against
-- Blizzard_FrameXML/Mainline/AlertFrames.lua), and put the Edit Mode selection box -- Blizzard's actual
-- "EditModeSystemSelectionTemplate", the same draggable/highlightable box every native Edit Mode system
-- (action bars, unit frames, etc.) uses -- on the mover instead of on AlertFrame. We deliberately don't
-- inherit the full "EditModeSystemTemplate"/EditModeSystemMixin -- that's wired into Blizzard's own
-- persisted per-layout settings system, which addons can't add a new entry to -- just the selection/
-- overlay box itself, with our own drag scripts and our own (non-Edit-Mode-layout-specific) saved
-- position, using the same getAbsoluteFramePosition()/setFramePoints() helpers as every other window in
-- this file.

--- Lazily creates the toast mover the first time AlertFrame is available (it may not have loaded yet at
--- OnEnable/ApplyAll time -- ApplyAll() retries this on every subsequent ADDON_LOADED). Its starting
--- position is either the previously-saved spot, or (the very first time, before we've ever touched
--- AlertFrame's anchor) a snapshot of wherever Blizzard's own code currently has AlertFrame anchored, so
--- the box starts out exactly where toasts already appear instead of some arbitrary default. No clamping
--- is applied -- the user can drag this anywhere, including off the edges of the screen -- toasts aren't
--- important enough to be worth restricting placement over.
---@return Frame? mover - nil if AlertFrame hasn't loaded yet.
local function ensureToastMover()
  if toastMover then return toastMover end

  local alertFrame = _G[TOAST_FRAME_NAME]
  if not alertFrame then return nil end

  -- Parented directly to the real UIParent -- NOT `fakeUIParent` (our own stand-in used everywhere else
  -- in this file for saved-anchor purposes). This was the site of a real bug: an earlier version of this
  -- function parented `mover` to `fakeUIParent` instead, on the assumption that `fakeUIParent` (being
  -- `SetAllPoints(UIParent)`) was an interchangeable stand-in for the whole screen. In practice, one
  -- user's box could not be dragged higher than roughly screen-vertical-center, even though the intended
  -- clamp (a small ~150px headroom reserved for toasts stacking upward, see the removed
  -- TOAST_STACK_HEADROOM below) should have permitted dragging almost to the actual top of the screen.
  -- Debug prints of mover:GetTop()/GetBottom()/GetEffectiveScale() at the drag boundary ruled out a scale
  -- mismatch (effective scale was a normal 1.0), and the user confirmed other movable windows (e.g.
  -- CharacterFrame, which stays parented to the real UIParent) could reach the true top of the screen
  -- fine. Printing fakeUIParent's OWN measured GetTop()/GetBottom() alongside the mover's was what
  -- revealed the actual cause: fakeUIParent's rendered rect only spanned roughly 0-768 instead of the
  -- true 0-1200 screen height in that user's setup, despite the SetAllPoints(UIParent) call -- meaning
  -- `SetClampedToScreen()`/`SetClampRectInsets()` on a frame parented to fakeUIParent clamp relative to
  -- fakeUIParent's own (potentially undersized) rect, not the true screen. Every OTHER window in this
  -- file was unaffected by this because they keep their real native parent (typically UIParent itself)
  -- and only ever use fakeUIParent as a SetPoint anchor TARGET, never as their actual CreateFrame parent
  -- -- the toast mover was the one exception. The fix was simply to parent `mover` to the real UIParent.
  -- Per a later request, the clamp itself (a small headroom reserved for toasts stacking upward off the
  -- top of the screen, applied via SetClampedToScreen/SetClampRectInsets) was removed entirely afterward
  -- -- toasts aren't important enough to be worth restricting placement over, so the box can now be
  -- dropped anywhere, including off-screen -- but the UIParent-vs-fakeUIParent parenting lesson from
  -- that bug still applies to any other floating "mover"-style frame added to this file in the future.
  local mover = CreateFrame("Frame", nil, UIParent)
  mover:SetSize(240, 50)
  mover:SetMovable(true)
  mover:EnableMouse(false) -- purely an anchor point; the selection overlay (below) handles all input

  local points = settings().toastPoints or getAbsoluteFramePosition(alertFrame)
  if points then setFramePoints(mover, points) end

  toastMover = mover
  return mover
end

--- Points AlertFrame's real anchor at our mover via Blizzard's own AlertContainerMixin API. Safe/cheap to
--- call repeatedly (e.g. after every drag) to make sure any toast currently on screen snaps to the new
--- spot immediately instead of waiting for the next one to queue up.
local function applyToastAnchor()
  local alertFrame = _G[TOAST_FRAME_NAME]
  local mover = toastMover
  if not alertFrame or not mover then return end
  alertFrame:SetBaseAnchorFrame(mover)
  alertFrame:UpdateAnchors()
end

--- Shows the selection box in its "highlighted" (hovered-looking, but not actively selected) state
--- whenever Edit Mode is open and the feature is enabled; hides it otherwise (feature disabled, or Edit
--- Mode closed). Also doubles as the "deselect our box" handler whenever a native Blizzard Edit Mode
--- system gets selected instead (see registerToastEditMode()'s SelectSystem hook below) -- since
--- ShowHighlighted() with no argument reverts a previously ShowSelected(true) box back to just highlighted.
local function resetToastSelection()
  local selection = toastSelection
  if not selection then return end

  if settings().moveToasts and EditModeManagerFrame:IsShown() then
    selection:ShowHighlighted()
  else
    selection:Hide()
  end
end

--- OnMouseDown handler for the toast selection box: clears whatever native Edit Mode system (action bars,
--- unit frames, etc.) is currently selected first, so our box and a native one never both claim to be
--- "selected" at once and fight over subsequent drag input, then marks our own box selected.
---@param selection Frame - The EditModeSystemSelectionTemplate-based selection frame (self).
local function onToastMouseDown(selection)
  if InCombatLockdown() then return end
  EditModeManagerFrame:ClearSelectedSystem() -- deselect any native system so they don't fight over input
  selection:ShowSelected(true)
end

--- OnDragStart handler for the toast selection box: begins dragging the underlying mover frame directly
--- (mover:StartMoving() -- not the selection box itself, which merely visually overlays it 1:1 via
--- SetAllPoints). Registers PLAYER_REGEN_DISABLED as a safety net so entering combat mid-drag reliably
--- ends the drag via onToastDragStop (wired as this frame's OnEvent, see ensureToastSelection() below)
--- instead of leaving the mover stuck mid-move.
---@param selection Frame - The selection frame (self); selection.mover is set in ensureToastSelection().
local function onToastDragStart(selection)
  if InCombatLockdown() then return end
  selection:RegisterEvent("PLAYER_REGEN_DISABLED") -- safety net: bail out of the drag if combat starts
  selection.mover:StartMoving()
end

--- OnDragStop handler for the toast selection box (also reused directly as the PLAYER_REGEN_DISABLED
--- OnEvent handler, see the safety net in onToastDragStart() above): stops the mover's drag, captures its
--- new position via getAbsoluteFramePosition(), persists it to settings().toastPoints, reapplies it (for
--- symmetry with every other window's drag-stop handling, though the position shouldn't have visibly
--- changed), and finally re-anchors AlertFrame onto the mover's new spot so any currently-visible toast
--- snaps there immediately.
---@param selection Frame
local function onToastDragStop(selection)
  if InCombatLockdown() then return end
  selection:UnregisterEvent("PLAYER_REGEN_DISABLED")

  local mover = selection.mover
  mover:StopMovingOrSizing()

  local points = getAbsoluteFramePosition(mover)
  if points then
    settings().toastPoints = points
    setFramePoints(mover, points)
  end

  applyToastAnchor()
end

--- Lazily creates the Edit Mode selection/overlay box the first time the mover is available (which itself
--- requires AlertFrame to exist -- see ensureToastMover()). Inherits Blizzard's real
--- "EditModeSystemSelectionTemplate" (not the full "EditModeSystemTemplate", see the file-level comment
--- above for why) so it looks and drags exactly like every native Edit Mode system's own selection box,
--- fully sized to and parented under the mover so it visually tracks it at all times.
---@return Frame? selection - nil if the mover isn't available yet (AlertFrame not loaded); ApplyAll() retries.
local function ensureToastSelection()
  if toastSelection then return toastSelection end

  local mover = ensureToastMover()
  if not mover then return nil end -- AlertFrame not loaded yet; ApplyAll() retries

  local selection = CreateFrame("Frame", nil, mover, "EditModeSystemSelectionTemplate")
  selection.mover = mover
  -- As of patch 11.2, EditModeSystemSelectionMixin requires a system name to work correctly.
  selection.system = {
    GetSystemName = function() return "Toasts" end,
  }
  selection:SetAllPoints(mover)
  selection:SetScript("OnMouseDown", onToastMouseDown)
  selection:SetScript("OnDragStart", onToastDragStart)
  selection:SetScript("OnDragStop", onToastDragStop)
  selection:SetScript("OnEvent", onToastDragStop) -- PLAYER_REGEN_DISABLED mid-drag safety net
  selection:Hide()

  toastSelection = selection
  return selection
end

--- Sets up (or, if already set up, just refreshes) the toast Edit Mode integration: ensures the selection
--- box exists (which in turn ensures the mover exists), applies AlertFrame's anchor to the mover, and --
--- only once, the very first time -- hooks EditModeManagerFrame's own OnShow/OnHide (to show/hide our box
--- in sync with Edit Mode opening/closing) and its SelectSystem method (so selecting any native system,
--- e.g. clicking the action bars, properly deselects our box instead of showing two "selected" boxes at
--- once). Called from ApplyAll() (on load/ADDON_LOADED, if the feature is enabled), and from
--- SetMoveToastsEnabled() when the user turns the feature on live.
function registerToastEditMode()
  if not _G.EditModeManagerFrame then return end -- Blizzard_EditMode not loaded yet; ApplyAll() retries

  local selection = ensureToastSelection()
  if not selection then return end -- AlertFrame not loaded yet either; ApplyAll() retries

  applyToastAnchor()

  if not toastHooked then
    toastHooked = true
    hookScript(EditModeManagerFrame, "OnShow", resetToastSelection)
    hookScript(EditModeManagerFrame, "OnHide", resetToastSelection)
    -- Deselect our box (fall back to just "highlighted") whenever a native system gets selected instead.
    module:SecureHook(EditModeManagerFrame, "SelectSystem", resetToastSelection)
  end

  resetToastSelection()
end

--- Enable/disable moving Blizzard's toasts (see TOAST_FRAME_NAME) through the real Edit Mode UI.
--- Disabling only hides the Edit Mode selection box -- it does not move the toasts back, same as
--- disabling this module entirely doesn't undo any other window's saved position.
---@param enabled boolean
function module:SetMoveToastsEnabled(enabled)
  settings().moveToasts = enabled
  if not isModuleEnabled() then return end -- picked up on next Enable via registerDefaultFrames()
  if enabled then
    registerToastEditMode()
  else
    resetToastSelection()
  end
end

--=====================================================================
-- Zone Map (BattlefieldMapFrame)
--=====================================================================
-- The "Zone Map" (Shift+M; Blizzard's internal name is the Battlefield Map / Battlefield Minimap) lives in
-- the load-on-demand Blizzard_BattlefieldMap addon, so it usually doesn't exist yet at OnEnable() time --
-- setupZoneMap() is called from ApplyAll() and simply retries on every ADDON_LOADED until it does.
--
-- Unlike every other window, it is NOT put through the frame registry (module:RegisterFrame()). Reviewed
-- against Blizzard_BattlefieldMap/{Mainline,Classic}/Blizzard_BattlefieldMap.lua/.xml, the map has no
-- title bar at all: the visible map frame is anchored TOPLEFT to a separate little chat-style tab button
-- (BattlefieldMapTab) that fades in on hover, and that TAB is what actually gets moved -- Blizzard already
-- drags the tab (only while the "Lock Zone Map" menu checkbox is off) and persists its position on logout
-- itself (BattlefieldMapOptions.position, restored on ADDON_LOADED via IsUserPlaced()). A registry move
-- handle would have to sit over the top strip of the map itself (eating map clicks), and our SetPoint
-- watchdog would re-anchor the map away from its tab, splitting the two apart. So instead we:
-- - Let the tab be dragged even while Blizzard's "Lock" is on (that's the "movable when the module is
--   enabled" part), reusing Blizzard's own tab-position persistence rather than our own points table.
-- - Add a "Change Scale" entry to the tab's right-click menu, right under Blizzard's own "Change Opacity",
--   opening a slider panel that's a 1:1 clone of Blizzard's OpacityFrame (the panel "Change Opacity"
--   opens), stored in the same settings().scales/sessionScales tables as every other window's scale.
-- Only the map frame is scaled, not the tab: the map is anchored by its TOPLEFT to the tab's BOTTOMLEFT, so
-- scaling the map grows/shrinks it down and to the right from that fixed corner while the tab stays put.
local ZONE_MAP_FRAME_NAME = "BattlefieldMapFrame"
local ZONE_MAP_TAB_NAME = "BattlefieldMapTab"
local ZONE_MAP_MENU_TAG = "MENU_BATTLEFIELD_MAP" -- rootDescription:SetTag() in BattlefieldMapTabMixin:OnClick
local ZONE_MAP_SCALE_LABEL = "Change Scale" -- mirrors BATTLEFIELDMINIMAP_OPACITY_LABEL ("Change Opacity")
local zoneMapHooked -- tab drag hooks installed (reset on disable, since UnhookAll() tears them down)
local zoneMapScaleApplied -- saved scale applied to the live map this enable cycle
local zoneMapMenuModified -- Menu.ModifyMenu() registered (permanent -- there's no API to unregister it)
local zoneMapScaleFrame
local zoneMapDragging

--- Rounds to the nearest 0.1, matching the 0.1 step every other window's wheel-scaling uses. Needed because
--- the slider's own float math (and the inverted mapping below) otherwise produces values like 1.2999999.
---@param value number
---@return number rounded
local function roundScale(value)
  return math.floor(value * 10 + 0.5) / 10
end

--- The Zone Map's current saved scale, honoring the same "permanent" vs "session" save strategy as every
--- registry window's onShow() does.
---@return number scale - 1 if nothing has been saved yet.
local function getZoneMapScale()
  if settings().saveScaleStrategy == "permanent" and settings().scales[ZONE_MAP_FRAME_NAME] then
    return settings().scales[ZONE_MAP_FRAME_NAME]
  end
  return sessionScales[ZONE_MAP_FRAME_NAME] or 1
end

--- Persists and applies a new Zone Map scale (clamped to the same MIN_SCALE..MAX_SCALE range as every other
--- window). Saved to both tables just like setFrameScale() does, so switching save strategies behaves the
--- same as for registry windows. Safe to call before Blizzard_BattlefieldMap has loaded -- it just saves.
---@param scale number
function setZoneMapScale(scale)
  scale = roundScale(math.max(MIN_SCALE, math.min(MAX_SCALE, scale)))
  settings().scales[ZONE_MAP_FRAME_NAME] = scale
  sessionScales[ZONE_MAP_FRAME_NAME] = scale
  local map = _G[ZONE_MAP_FRAME_NAME]
  if map then
    map:SetScale(scale)
  end
end

--- Lazily builds our clone of Blizzard's OpacityFrame (Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml)
--- in Lua: same 80x180 dialog-bordered panel, same 16x128 vertical slider with the same backdrop/thumb art,
--- the same "-"/"+" markers, and the same invisible full-screen "click anywhere else to close" button behind
--- it. We clone it rather than reusing OpacityFrame itself because OpacityFrame is a single shared global
--- (Blizzard also uses it for chat frames etc.) hardcoded to a 0..1 range with an "Opacity" label.
--- Vertical sliders put their MIN value at the TOP; OpacityFrame relies on that (opacity 0 = fully visible
--- is at the top, next to "+"). For scale we want bigger at the top too, so the slider's raw value is
--- inverted: displayed scale = MIN_SCALE + MAX_SCALE - rawValue.
---@return Frame scaleFrame
local function ensureZoneMapScaleFrame()
  if zoneMapScaleFrame then return zoneMapScaleFrame end

  -- Retail's OpacityFrame uses DialogBorderTemplate; older clients only have the equivalent backdrop.
  local hasDialogBorder = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("DialogBorderTemplate")
  local frameTemplate = (not hasDialogBorder and BackdropTemplateMixin) and "BackdropTemplate" or nil
  local frame = CreateFrame("Frame", "SlackHacksZoneMapScaleFrame", UIParent, frameTemplate)
  frame:SetSize(80, 180)
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:Hide()
  if hasDialogBorder then
    frame.Border = CreateFrame("Frame", nil, frame, "DialogBorderTemplate")
  elseif frame.SetBackdrop and BACKDROP_DIALOG_32_32 then
    frame:SetBackdrop(BACKDROP_DIALOG_32_32)
  end

  local slider = CreateFrame("Slider", "SlackHacksZoneMapScaleFrameSlider", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  slider:SetOrientation("VERTICAL")
  slider:SetSize(16, 128)
  slider:SetPoint("TOP", -10, -35)
  if slider.SetBackdrop and BACKDROP_SLIDER_8_8 then
    slider:SetBackdrop(BACKDROP_SLIDER_8_8)
  end
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
  slider:GetThumbTexture():SetSize(32, 32)
  slider:SetMinMaxValues(MIN_SCALE, MAX_SCALE)
  slider:SetValueStep(0.1)
  slider:SetObeyStepOnDrag(true)
  frame.Slider = slider

  local label = slider:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetPoint("TOP", frame, "TOP", 0, -15)
  label:SetText("Scale")

  local minus = slider:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  minus:SetPoint("BOTTOMLEFT", slider, "BOTTOMRIGHT", 8, 3)
  minus:SetText("-")
  minus:SetTextColor(1, 1, 1)

  local plus = slider:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  plus:SetPoint("TOPLEFT", slider, "TOPRIGHT", 6, -3)
  plus:SetText("+")
  plus:SetTextColor(1, 1, 1)

  slider:SetScript("OnValueChanged", function(self, value)
    if frame.ignoreValueChanged then return end
    setZoneMapScale(MIN_SCALE + MAX_SCALE - value)
  end)

  -- Same trick as OpacityFrameCloseButton: a full-screen button one level below the panel catches any click
  -- outside it and closes the panel.
  local closeButton = CreateFrame("Button", nil, UIParent)
  closeButton:SetAllPoints(UIParent)
  closeButton:SetFrameLevel(math.max(0, closeButton:GetFrameLevel() - 1))
  closeButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
  closeButton:SetScript("OnClick", function() frame:Hide() end)
  closeButton:Hide()
  frame:SetScript("OnShow", function() closeButton:Show() end)
  frame:SetScript("OnHide", function() closeButton:Hide() end)

  zoneMapScaleFrame = frame
  return frame
end

--- Opens the scale slider panel. Mirrors BattlefieldMapTabMixin:ShowOpacity() exactly: same anchor (the
--- panel's TOPRIGHT pinned to the map's TOPLEFT, nudged up 7px), then sets the slider to the current value.
--- Since the map scales from that same TOPLEFT corner, the panel stays put while the slider is dragged.
local function showZoneMapScale()
  local map = _G[ZONE_MAP_FRAME_NAME]
  if not map then return end
  local frame = ensureZoneMapScaleFrame()
  if OpacityFrame and OpacityFrame:IsShown() then
    OpacityFrame:Hide() -- both panels anchor to the exact same spot
  end
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", map, "TOPLEFT", 0, 7)
  frame.ignoreValueChanged = true
  frame.Slider:SetValue(MIN_SCALE + MAX_SCALE - getZoneMapScale())
  frame.ignoreValueChanged = nil
  frame:Show()
end

--- Post-hook on the tab's OnDragStart. Blizzard's own handler only moves anything while the map is
--- unlocked, so we only step in while it's LOCKED (unlocked already works natively, and stepping in there
--- too would double-start the move). Respects the module's own move-modifier setting, like every window.
--- Moving the tab via its own StartMoving() marks it user-placed, which is exactly what Blizzard's own
--- PLAYER_LOGOUT handler checks to persist the position -- so no saving code of our own is needed.
---@param tab Button - BattlefieldMapTab.
local function onZoneMapTabDragStart(tab)
  if not isModuleEnabled() then return end
  if not (BattlefieldMapOptions and BattlefieldMapOptions.locked) then return end
  if not isMoveModifierDown() then return end
  zoneMapDragging = true
  tab:StartMoving()
end

--- Post-hook on the tab's OnDragStop: ends a drag that onZoneMapTabDragStart() started. Blizzard's own
--- OnDragStop already ran ValidateFramePosition() on the tab, but before we stopped moving it, so it's
--- rerun here against the tab's final resting spot.
---@param tab Button - BattlefieldMapTab.
local function onZoneMapTabDragStop(tab)
  if not zoneMapDragging then return end
  zoneMapDragging = nil
  tab:StopMovingOrSizing()
  if ValidateFramePosition then
    ValidateFramePosition(tab)
  end
end

--- Adds our "Change Scale" button to the tab's right-click menu. Blizzard builds that menu with MenuUtil
--- (on both retail and Classic) and tags it "MENU_BATTLEFIELD_MAP", which is exactly what
--- Menu.ModifyMenu() exists for. Modifications append to the end, which lands it directly under
--- "Change Opacity". Can't be unregistered, so it checks isModuleEnabled() each time the menu opens.
local function modifyZoneMapMenu()
  if zoneMapMenuModified or not (Menu and Menu.ModifyMenu) then return end
  zoneMapMenuModified = true
  Menu.ModifyMenu(ZONE_MAP_MENU_TAG, function(owner, rootDescription)
    if not isModuleEnabled() then return end
    rootDescription:CreateButton(ZONE_MAP_SCALE_LABEL, showZoneMapScale)
  end)
end

--- Wires up the Zone Map once Blizzard_BattlefieldMap has loaded (no-op until then; ApplyAll() retries on
--- every ADDON_LOADED). Idempotent: hooks, menu modification, and the initial scale apply each happen only
--- once per enable cycle.
function setupZoneMap()
  local map, tab = _G[ZONE_MAP_FRAME_NAME], _G[ZONE_MAP_TAB_NAME]
  if not (map and tab) then return end

  if not zoneMapHooked then
    zoneMapHooked = true
    hookScript(tab, "OnDragStart", onZoneMapTabDragStart)
    hookScript(tab, "OnDragStop", onZoneMapTabDragStop)
  end

  modifyZoneMapMenu()

  if not zoneMapScaleApplied then
    zoneMapScaleApplied = true
    map:SetScale(getZoneMapScale())
  end
end

--- Undoes setupZoneMap() for OnDisable(): returns the map to its native scale and closes the slider panel.
--- The saved scale itself is kept, so re-enabling restores it. The tab's drag hooks are torn down by
--- OnDisable()'s UnhookAll(); the menu entry hides itself via its isModuleEnabled() check.
local function teardownZoneMap()
  local map = _G[ZONE_MAP_FRAME_NAME]
  if map and zoneMapScaleApplied then
    map:SetScale(1)
  end
  if zoneMapScaleFrame then
    zoneMapScaleFrame:Hide()
  end
  zoneMapHooked = nil
  zoneMapScaleApplied = nil
  zoneMapDragging = nil
end

--- Registers the curated, built-in set of commonly-movable Blizzard windows this addon ships with (not an
--- exhaustive database of every frame across every WoW expansion/version -- callers can add more via
--- module:RegisterFrame()). Also kicks off the toast Edit Mode integration if that setting is already
--- enabled from a previous session. Called once from OnInitialize().
local function registerDefaultFrames()
  -- Modern retail replaced the old SpellBookFrame with PlayerSpellsFrame (Blizzard_PlayerSpells).
  local spellBookFrameName = isRetail() and "PlayerSpellsFrame" or "SpellBookFrame"

  local sharedFrames = {
    [spellBookFrameName] = {},
    ["CharacterFrame"] = {},
    ["BankFrame"] = {},
    ["MerchantFrame"] = {},
    ["TradeFrame"] = {},
    ["MailFrame"] = {},
    ["GuildBankFrame"] = {},
    ["MacroFrame"] = {},
    ["FriendsFrame"] = {},
    ["WorldMapFrame"] = {}, -- native wheel-zoom on the map canvas already defers scaling; title bar/border still scalable
    ["QuestFrame"] = {},
    ["GossipFrame"] = {},
    ["AddonList"] = {},
    -- Its ornate banner art bleeds upward past the frame's own top edge -- raise the hit target to cover
    -- that space instead of extending further down into the Header/search row content.
    ["AchievementFrame"] = { TitleBarRaise = 25 },
    -- Deliberately NOT ContainerFrame1..13/ContainerFrameCombinedBags: Blizzard repositions those itself
    -- every time a bag opens/closes (stacking them side by side based on how many are open), and our
    -- anti-rubberband SetPoint watchdog would fight that by forcing any one of them back to a stale saved
    -- spot the instant it was ever dragged, leaving the rest misanchored relative to it.
  }
  for frameName, frameData in pairs(sharedFrames) do
    module:RegisterFrame(frameName, frameData)
  end

  if isRetail() then
    local retailFrames = {
      ["CollectionsJournal"] = {},
      ["EncounterJournal"] = {},
      ["CommunitiesFrame"] = {},
      ["PVEFrame"] = {},
      ["AuctionHouseFrame"] = {},
      ["ItemSocketingFrame"] = {},
      ["ItemUpgradeFrame"] = {},
    }
    for frameName, frameData in pairs(retailFrames) do
      module:RegisterFrame(frameName, frameData)
    end
  end

  if settings().moveToasts then
    registerToastEditMode()
  end
end

--=====================================================================
-- Lifecycle
--=====================================================================
--- Turns the whole module on/off (the top-level "Enable Movable Windows" checkbox), via Ace3's standard
--- Enable()/Disable() (which in turn call OnEnable()/OnDisable() below).
---@param enabled boolean
function module:SetEnabled(enabled)
  settings().enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

--- Slash-command toggle for the whole module's on/off state, with a chat confirmation printed since this
--- (unlike the options-panel checkbox, which is already visible feedback) is typically invoked "blind".
function module:Toggle()
  self:SetEnabled(not settings().enabled)
  print("SlackHacks: Movable Windows " .. (settings().enabled and "enabled" or "disabled"))
end

--- Global slash-command entry point (bound in Bindings.xml/Core.lua) for toggling the module.
function toggleMovableWindows()
  Self.MovableWindows:Toggle()
end

--- AceAddon lifecycle: runs once, at addon load. Disables the whole module outright on any client that's
--- neither current retail nor WoW Forever (Classic Era) -- this file is deliberately not maintained
--- against every historical WoW version. Also does one-time migration cleanup of a legacy bug (an earlier
--- version of this module persisted ContainerFrame1..13 positions, which could fight Blizzard's own
--- dynamic bag-stacking layout -- see the comment on registerDefaultFrames() for why those are no longer
--- registered at all), then registers the built-in frame list.
function module:OnInitialize()
  if not (isRetail() or isForever()) then
    self:SetEnabledState(false)
    return
  end
  -- One-time cleanup: earlier versions registered ContainerFrame1..13 as position-persisted, which could
  -- have saved a stale dragged position fighting Blizzard's own bag layout; drop any leftover entries.
  for frameName in pairs(settings().points) do
    if frameName:match("^ContainerFrame%d*$") then
      settings().points[frameName] = nil
    end
  end
  registerDefaultFrames()
  if not settings().enabled then
    self:SetEnabledState(false)
  end
end

--- AceAddon lifecycle: runs whenever the module transitions to enabled (initial login with the setting
--- on, or the user flipping the checkbox/slash-toggling it on). Sets up the shared mouse-wheel-capture
--- arbitration frame and the UpdateScaleForFit hook exactly once (idempotent across repeated enables), and
--- (re)applies every registered frame's movability/position/scale via ApplyAll(), also registering it to
--- rerun on every future ADDON_LOADED so anything not yet loaded gets picked up as soon as it is.
function module:OnEnable()
  if not (isRetail() or isForever()) then
    self:SetEnabledState(false)
    return
  end
  if not settings().enabled then
    self:SetEnabledState(false)
    return
  end

  if not mouseWheelCaptureFrame then
    initMouseWheelCaptureFrame()
  end

  if _G.UIPanelUpdateScaleForFit then
    self:SecureHook("UIPanelUpdateScaleForFit", onUpdateScaleForFit)
  elseif _G.UpdateScaleForFit then
    self:SecureHook("UpdateScaleForFit", onUpdateScaleForFit)
  end

  self:RegisterEvent("ADDON_LOADED", "ApplyAll")
  self:ApplyAll()
end

--- AceAddon lifecycle: runs whenever the module transitions to disabled. Unregisters every event/hook this
--- module installed (Ace3's UnregisterAllEvents/UnhookAll), then unprocesses every registered frame
--- (restoring native movability/clamping/mouse state -- see unprocessFrame()) and hides the shared
--- mouse-wheel-capture frame and the toast selection box. `toastHooked` is reset to nil (rather than left
--- stale) since UnhookAll() above already tore down the EditModeManagerFrame hooks it guards -- if the
--- module is re-enabled later, registerToastEditMode() needs to know to re-install them.
function module:OnDisable()
  self:UnregisterAllEvents()
  self:UnhookAll()

  for frameName, frameData in pairs(registeredFrames) do
    if frameData.storage and frameData.storage.frame then
      unprocessFrame(frameData.storage.frame)
    end
  end

  if mouseWheelCaptureFrame then
    mouseWheelCaptureFrame:Hide()
  end

  if toastSelection then
    toastSelection:Hide()
  end
  toastHooked = nil -- UnhookAll() above already tore down the EditModeManagerFrame hooks
  teardownZoneMap()
end
