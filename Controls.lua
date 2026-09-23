setfenv(1, _G.SlackHacks)

--=====================================================================
-- Controls
--=====================================================================
-- Camera behavior tweaks (max zoom distance, ActionCam-style dynamic pitch/motion).

local module = Self:NewModule("Controls", "AceEvent-3.0")
Self.Controls = module

local function settings()
  return db.profile.controls
end

local function applyMaximumCameraZoom()
  if settings().maximumCameraZoom then
    ensureCVar("cameraDistanceMaxZoomFactor", 2.6) -- Max out camera zoom
  else
    ensureCVar("cameraDistanceMaxZoomFactor", GetCVarDefault("cameraDistanceMaxZoomFactor"))
  end
end

local function applyDynamicCamera()
  if settings().enableDynamicCamera then
    ensureCVar("test_cameraDynamicPitch", 1) -- Equal to `/console ActionCam basic`
    -- CameraKeepCharacterCentered=1 silently blocks ActionCam's dynamic pitch from having any effect.
    -- Mirrors what turning ON the in-game "Motion Sickness" checkbox does (CameraKeepCharacterCentered=false,
    -- CameraReduceUnexpectedMovement=true) -- these two cvars are always set as an inverse pair.
    ensureCVar("CameraKeepCharacterCentered", 0)
    ensureCVar("CameraReduceUnexpectedMovement", 1)
  else
    ensureCVar("test_cameraDynamicPitch", GetCVarDefault("test_cameraDynamicPitch"))
    ensureCVar("CameraKeepCharacterCentered", GetCVarDefault("CameraKeepCharacterCentered"))
    ensureCVar("CameraReduceUnexpectedMovement", GetCVarDefault("CameraReduceUnexpectedMovement"))
  end
end

function module:ApplyAll()
  applyMaximumCameraZoom()
  applyDynamicCamera()
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyAll")
  self:ApplyAll()
end
