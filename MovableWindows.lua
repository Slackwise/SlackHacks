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

-- Forward declarations for functions referenced before their definition further down the file.
local onMouseDown, onMouseUp, onMouseWheel, onShow, onSetPoint, onSizeUpdate, checkMouseWheelCapture

--=====================================================================
-- Settings helpers
--=====================================================================
local function settings()
  return db.profile.movableWindows
end

local function isModuleEnabled()
  return settings() and settings().enabled or false
end

local function isModifierKeyDown(key)
  if key == "SHIFT" then return IsShiftKeyDown() end
  if key == "CTRL" then return IsControlKeyDown() end
  if key == "ALT" then return IsAltKeyDown() end
  return true -- "NONE": no modifier required
end

local function isMoveModifierDown()
  return isModifierKeyDown(settings().modifierKey)
end

local function isScaleModifierDown()
  return isModifierKeyDown(settings().scaleModifierKey)
end

--=====================================================================
-- Frame name / registry helpers
--=====================================================================
local function getFrameName(frame)
  local frameData = frame and frameRegistry[frame]
  return frameData and frameData.storage and frameData.storage.frameName
end

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
-- Protected frames can't be reparented/repositioned/hooked while in combat; anything that needs to touch
-- one is deferred here and flushed as soon as combat ends.
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
-- Captures a frame's CURRENT anchor(s) as-is (used to remember a detachable subframe's original anchor so
-- it can be re-attached later).
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

-- Converts a frame's current position into a single, resolution/scale-independent anchor relative to the
-- nearest screen edge (or center) -- inspired by LibWindow-1.1 -- so a saved position still looks right
-- after a UI reload or resolution change.
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

local function realSetPoint(frame, anchorPoint, relativeFrame, relativePoint, offX, offY)
  local setPoint = frame.SetPointBase or frame.SetPoint
  setPoint(frame, anchorPoint, relativeFrame, relativePoint, offX, offY)
end

-- Applying a saved point directly to a protected frame outside of combat is usually fine, but can be
-- risky when the anchor target is itself protected/forbidden; route those through a secure snippet so it
-- can never be blamed for tainting Blizzard's own code.
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

-- Reapplying SetPoint from directly inside a SetPoint hook can be unreliable; queue it for the very next
-- frame update instead (only used by the "permanent" position watchdog).
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

-- When the strategy is "permanent", alias storage.points directly to the saved-variable sub-table so any
-- mutation (drag/detach) is automatically persisted -- no separate save step, and it naturally survives
-- a UI reload since the same (now pre-populated) table gets re-aliased next time.
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
local function getFrameScale(frame)
  local frameData = frameRegistry[frame]
  local parentScale = (frameData.storage.frameParent and not frameData.ManuallyScaleWithParent and getFrameScale(frameData.storage.frameParent)) or 1
  return frame:GetScale() * parentScale
end

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
local function startMoving(frame)
  if moveHandles[frame] then
    -- Arm the handle's own native OnDragStart (already listening via PanelDragBarTemplate's RegisterForDrag)
    -- so Blizzard's own StartMoving() call fires from a real drag event, not from our insecure hook.
    frame.onDragStartCallback = nil
    return
  end
  frame:StartMoving()
end

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

function onMouseDown(frame, button)
  local moveHandle = moveHandles[frame] and frame or nil
  if moveHandle then frame = moveHandle:GetParent() end
  return doOnMouseDown(frame, button, moveHandle)
end

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

function onMouseUp(frame, button)
  local moveHandle = moveHandles[frame] and frame or nil
  if moveHandle then frame = moveHandle:GetParent() end
  return doOnMouseUp(frame, button, moveHandle)
end

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

function onMouseWheel(frame, delta)
  if not settings().enableScaling or not isScaleModifierDown() then return false end
  return doOnMouseWheel(frame, delta)
end

local function onEnter(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return end
  mouseoverFrames[frame] = true
  checkMouseWheelCapture()
end

local function onLeave(frame)
  if not mouseoverFrames[frame] then return end
  mouseoverFrames[frame] = nil
  checkMouseWheelCapture()
end

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

local function waitForGlobalMouseUp(frame)
  awaitingGlobalMouseUp = frame
  module:RegisterEvent("GLOBAL_MOUSE_UP")
end

local function onSubFrameHide(frame)
  local frameData = frameRegistry[frame]
  if not frameData or not frameData.storage or frameData.storage.disabled then return end

  local parent = frameData.storage.frameParent
  if parent then return onSubFrameHide(parent) end

  if frameData.storage.isMoving then
    waitForGlobalMouseUp(frame)
  end
end

function module:GLOBAL_MOUSE_UP(event, button)
  self:UnregisterEvent(event)
  if not awaitingGlobalMouseUp then return end
  onMouseUp(awaitingGlobalMouseUp, button)
  awaitingGlobalMouseUp = nil
end

-- Anti-rubberband watchdog: if something else (Blizzard's own code, another addon) calls SetPoint on a
-- frame we've dragged, immediately reassert the dragged position instead of silently losing it.
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

-- Keeps a dragged/scaled frame from being able to get clamped/dragged off-screen entirely.
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
-- A full-screen, top-strata frame arbitrates the scale-modifier+MouseWheel combo: it only actually
-- captures the wheel when the configured scale modifier is held over a registered frame that isn't
-- already fielding wheel/click input on its own (so we never steal scrolling from a spellbook list, quest
-- log, scrollable dialog, etc).
function checkMouseWheelCapture()
  if not mouseWheelCaptureFrame then return end
  mouseWheelCaptureFrame:EnableMouseWheel(false)

  if not settings().enableScaling then return end
  if not isScaleModifierDown() or not next(mouseoverFrames) then return end

  local foci = GetMouseFoci and GetMouseFoci() or {}
  if not next(foci) then return end

  for _, frame in ipairs(foci) do
    local frameData = frameRegistry[frame]
    local shouldHandle = frameData and not frameData.IgnoreMouseWheel

    if
      not shouldHandle
      and (
        frame:IsForbidden()
        or (frame.HasSecretValues and frame:HasSecretValues())
        or (not moveHandles[frame] and frame:IsMouseWheelEnabled())
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

local function initMouseWheelCaptureFrame()
  mouseWheelCaptureFrame = CreateFrame("Frame", "SlackHacksMovableWindowsMouseWheelCapture")
  mouseWheelCaptureFrame:SetPoint("TOPLEFT")
  mouseWheelCaptureFrame:SetPoint("BOTTOMRIGHT")
  mouseWheelCaptureFrame:SetScript("OnUpdate", checkMouseWheelCapture)
  mouseWheelCaptureFrame:SetScript("OnEvent", checkMouseWheelCapture)
  mouseWheelCaptureFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
  mouseWheelCaptureFrame:SetScript("OnMouseWheel", function(_, delta)
    for _, frame in ipairs(GetMouseFoci()) do
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
local function hookScript(frame, script, handler)
  if frame:HasScript(script) then
    module:SecureHookScript(frame, script, handler)
  end
end

-- A plain (unprotected) overlay button inheriting Blizzard's own PanelDragBarTemplate, so dragging a
-- protected frame still goes through Blizzard's native StartMoving()/StopMovingOrSizing(), just triggered
-- by our own OnMouseDown/OnMouseUp instead of the template's built-in unconditional left-click-drag.
-- Sized to only the top title-bar strip of the frame, not the whole window, so drags only start there.
-- Also owns the mouse-wheel-scaling hover region for the same reason: scroll-to-scale should only engage
-- over the title bar, not anywhere on the window (unless ignoreMouseWheel opts the frame out entirely).
local function makeMoveHandle(frame, rootFrame, titleBarHeight, ignoreMouseWheel)
  local handle = CreateFrame("Frame", nil, rootFrame, "PanelDragBarTemplate")
  handle:SetParent(frame)
  handle:SetPoint("TOPLEFT", frame, "TOPLEFT")
  handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
  handle:SetHeight(titleBarHeight)
  handle:SetFrameLevel(frame:GetFrameLevel() + TITLE_BAR_HANDLE_LEVEL_OFFSET)
  handle:SetPropagateMouseMotion(true)
  handle:SetPropagateMouseClicks(true)
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

  local handle = makeMoveHandle(frame, rootFrame, frameData.TitleBarHeight or DEFAULT_TITLE_BAR_HEIGHT, frameData.IgnoreMouseWheel)
  frameData.moveHandle = handle
  moveHandles[handle] = true
end

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
---  IgnoreClamping, ManuallyScaleWithParent, ForceUseSecureMoveHandle, ForcePosition, TitleBarHeight.
function module:RegisterFrame(frameName, frameData)
  frameData = frameData or {}
  registeredFrames[frameName] = frameData
  if isModuleEnabled() then
    processFrame(frameName, frameData)
  end
end

function module:ApplyAll()
  if not isModuleEnabled() then return end
  for frameName, frameData in pairs(registeredFrames) do
    if not (frameData.storage and frameData.storage.hooked) then
      processFrame(frameName, frameData)
    end
  end
end

function module:ResetPositions()
  wipe(settings().points)
end

function module:ResetScales()
  wipe(settings().scales)
  wipe(sessionScales)
end

-- Curated set of commonly-used windows, not an exhaustive database -- add more via module:RegisterFrame()
-- as needed.
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
    ["AchievementFrame"] = {},
  }
  for i = 1, 13 do
    sharedFrames["ContainerFrame" .. i] = {}
  end

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
end

--=====================================================================
-- Lifecycle
--=====================================================================
function module:SetEnabled(enabled)
  settings().enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

function module:Toggle()
  self:SetEnabled(not settings().enabled)
  print("SlackHacks: Movable Windows " .. (settings().enabled and "enabled" or "disabled"))
end

function toggleMovableWindows()
  Self.MovableWindows:Toggle()
end

function module:OnInitialize()
  if not (isRetail() or isForever()) then
    self:SetEnabledState(false)
    return
  end
  registerDefaultFrames()
  if not settings().enabled then
    self:SetEnabledState(false)
  end
end

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
end
