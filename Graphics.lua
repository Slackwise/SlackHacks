setfenv(1, _G.SlackHacks)

--=====================================================================
-- Graphics
--=====================================================================
-- Hidden graphical options and advanced rendering CVars beyond standard settings:
--   * groundEffectDensity (256): Foliage and clutter density (grass, ferns, rocks).
--   * groundEffectFade (370): Distance at which ground clutter begins fading out.
--   * groundEffectDist (500): Maximum draw distance for ground clutter rendering.
--   * lodObjectFadeScale (200): Fade distance scale for level of detail (LoD) doodads/objects.
--   * lodObjectCullSize (8): Pixel size threshold below which small objects are culled.
--   * terrainLodDist (1000): Maximum draw distance for high-detail terrain mesh geometry.
--   * ResampleAlwaysSharpen (1): Runs spatial sharpening filter pass even without FSR upscaling.
--   * reflectionMode (3): Water reflection quality mode (0: off, 1: terrain, 2: objects, 3: all/sky).
--   * weatherDensity (3): Precipitation and weather effect intensity (0: off, 1-3: density).

local module = Self:NewModule("Graphics", "AceEvent-3.0")
Self.Graphics = module

local function settings()
  return db.profile.graphics
end

-- Recommended hidden graphics settings
local RECOMMENDED_GRAPHICS = {
  groundEffectDensity = 256,
  groundEffectFade = 370,
  groundEffectDist = 500,
  lodObjectFadeScale = 200,
  lodObjectCullSize = 8,
  terrainLodDist = 1000,
  resampleAlwaysSharpen = true,
  reflectionMode = 3,
  weatherDensity = 3,
}

-- Standard Blizzard defaults used as fallbacks when restoring game defaults
local BLIZZARD_DEFAULTS = {
  groundEffectDensity = 16,
  groundEffectFade = 70,
  groundEffectDist = 70,
  lodObjectFadeScale = 100,
  lodObjectCullSize = 15,
  terrainLodDist = 400,
  ResampleAlwaysSharpen = 0,
  reflectionMode = 0,
  weatherDensity = 2,
}

local function applyCVar(cvar, value)
  if GetCVar(cvar) ~= nil then
    ensureCVar(cvar, value)
  end
end

local function revertCVar(cvar, fallbackDefault)
  if GetCVar(cvar) ~= nil then
    local defaultVal = GetCVarDefault(cvar)
    if defaultVal == nil or defaultVal == "" then
      defaultVal = fallbackDefault
    end
    ensureCVar(cvar, defaultVal)
  end
end

function module:Apply(key)
  if not settings().enabled then return end

  if key == "groundEffectDensity" then
    applyCVar("groundEffectDensity", settings().groundEffectDensity)
  elseif key == "groundEffectFade" then
    applyCVar("groundEffectFade", settings().groundEffectFade)
  elseif key == "groundEffectDist" then
    applyCVar("groundEffectDist", settings().groundEffectDist)
  elseif key == "lodObjectFadeScale" then
    applyCVar("lodObjectFadeScale", settings().lodObjectFadeScale)
  elseif key == "lodObjectCullSize" then
    applyCVar("lodObjectCullSize", settings().lodObjectCullSize)
  elseif key == "terrainLodDist" then
    applyCVar("terrainLodDist", settings().terrainLodDist)
  elseif key == "resampleAlwaysSharpen" then
    applyCVar("ResampleAlwaysSharpen", settings().resampleAlwaysSharpen and 1 or 0)
  elseif key == "reflectionMode" then
    applyCVar("reflectionMode", settings().reflectionMode)
  elseif key == "weatherDensity" then
    applyCVar("weatherDensity", settings().weatherDensity)
  else
    self:ApplyAll()
  end
end

function module:ApplyAll()
  if not settings().enabled then return end

  applyCVar("groundEffectDensity", settings().groundEffectDensity)
  applyCVar("groundEffectFade", settings().groundEffectFade)
  applyCVar("groundEffectDist", settings().groundEffectDist)
  applyCVar("lodObjectFadeScale", settings().lodObjectFadeScale)
  applyCVar("lodObjectCullSize", settings().lodObjectCullSize)
  applyCVar("terrainLodDist", settings().terrainLodDist)
  applyCVar("ResampleAlwaysSharpen", settings().resampleAlwaysSharpen and 1 or 0)
  applyCVar("reflectionMode", settings().reflectionMode)
  applyCVar("weatherDensity", settings().weatherDensity)
end

function module:RestoreDefaults()
  revertCVar("groundEffectDensity", BLIZZARD_DEFAULTS.groundEffectDensity)
  revertCVar("groundEffectFade", BLIZZARD_DEFAULTS.groundEffectFade)
  revertCVar("groundEffectDist", BLIZZARD_DEFAULTS.groundEffectDist)
  revertCVar("lodObjectFadeScale", BLIZZARD_DEFAULTS.lodObjectFadeScale)
  revertCVar("lodObjectCullSize", BLIZZARD_DEFAULTS.lodObjectCullSize)
  revertCVar("terrainLodDist", BLIZZARD_DEFAULTS.terrainLodDist)
  revertCVar("ResampleAlwaysSharpen", BLIZZARD_DEFAULTS.ResampleAlwaysSharpen)
  revertCVar("reflectionMode", BLIZZARD_DEFAULTS.reflectionMode)
  revertCVar("weatherDensity", BLIZZARD_DEFAULTS.weatherDensity)
end

function module:ResetToRecommended()
  for k, v in pairs(RECOMMENDED_GRAPHICS) do
    settings()[k] = v
  end
  if settings().enabled then
    self:ApplyAll()
  end
  local acr = LibStub("AceConfigRegistry-3.0", true)
  if acr then
    acr:NotifyChange("SlackHacks")
  end
end

function module:SetEnabled(enabled)
  settings().enabled = enabled
  if enabled then
    self:Enable()
  else
    self:Disable()
  end
end

function module:OnInitialize()
  if not settings().enabled then
    self:Disable()
  end
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyAll")
  self:ApplyAll()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  self:RestoreDefaults()
end
