setfenv(1, _G.SlackHacks)

--=====================================================================
-- Graphics
--=====================================================================
-- Hidden graphical options and advanced rendering CVars:
--   * groundEffectDensity: Foliage and clutter density (grass, ferns, rocks).
--   * groundEffectFade: Distance at which ground clutter begins fading out.
--   * groundEffectDist: Maximum draw distance for ground clutter rendering.
--   * lodObjectFadeScale: Fade distance scale for level of detail (LoD) doodads/objects.
--   * lodObjectCullSize: Pixel size threshold below which small objects are culled.
--   * terrainLodDist: Maximum draw distance for high-detail terrain mesh geometry.
--   * ResampleAlwaysSharpen: Runs spatial sharpening filter pass even without FSR upscaling.
--   * reflectionMode: Water reflection quality mode (0: off, 1: terrain, 2: objects, 3: all/sky).
--   * weatherDensity: Precipitation and weather effect intensity (0: off, 1-3: density).

local module = Self:NewModule("Graphics", "AceEvent-3.0")
Self.Graphics = module

local function settings()
  return db.profile.graphics
end

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

local CVAR_NAMES = {
  groundEffectDensity = "groundEffectDensity",
  groundEffectFade = "groundEffectFade",
  groundEffectDist = "groundEffectDist",
  lodObjectFadeScale = "lodObjectFadeScale",
  lodObjectCullSize = "lodObjectCullSize",
  terrainLodDist = "terrainLodDist",
  resampleAlwaysSharpen = "ResampleAlwaysSharpen",
  reflectionMode = "reflectionMode",
  weatherDensity = "weatherDensity",
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

--- Returns the game's default value for a given graphics CVar key.
function module:GetDefault(key)
  local cvarName = CVAR_NAMES[key] or key
  if GetCVarDefault then
    local def = GetCVarDefault(cvarName)
    if def ~= nil and def ~= "" then
      local num = tonumber(def)
      if num then return num end
    end
  end
  return BLIZZARD_DEFAULTS[cvarName] or BLIZZARD_DEFAULTS[key]
end

function module:Apply(key)
  if not settings().enabled then return end

  if key == "groundEffectDensity" then
    if settings().enableGroundEffectDensity then
      applyCVar("groundEffectDensity", settings().groundEffectDensity)
    else
      revertCVar("groundEffectDensity", BLIZZARD_DEFAULTS.groundEffectDensity)
    end
  elseif key == "groundEffectFade" then
    if settings().enableGroundEffectFade then
      applyCVar("groundEffectFade", settings().groundEffectFade)
    else
      revertCVar("groundEffectFade", BLIZZARD_DEFAULTS.groundEffectFade)
    end
  elseif key == "groundEffectDist" then
    if settings().enableGroundEffectDist then
      applyCVar("groundEffectDist", settings().groundEffectDist)
    else
      revertCVar("groundEffectDist", BLIZZARD_DEFAULTS.groundEffectDist)
    end
  elseif key == "lodObjectFadeScale" then
    if settings().enableLodObjectFadeScale then
      applyCVar("lodObjectFadeScale", settings().lodObjectFadeScale)
    else
      revertCVar("lodObjectFadeScale", BLIZZARD_DEFAULTS.lodObjectFadeScale)
    end
  elseif key == "lodObjectCullSize" then
    if settings().enableLodObjectCullSize then
      applyCVar("lodObjectCullSize", settings().lodObjectCullSize)
    else
      revertCVar("lodObjectCullSize", BLIZZARD_DEFAULTS.lodObjectCullSize)
    end
  elseif key == "terrainLodDist" then
    if settings().enableTerrainLodDist then
      applyCVar("terrainLodDist", settings().terrainLodDist)
    else
      revertCVar("terrainLodDist", BLIZZARD_DEFAULTS.terrainLodDist)
    end
  elseif key == "resampleAlwaysSharpen" then
    if settings().resampleAlwaysSharpen then
      applyCVar("ResampleAlwaysSharpen", 1)
    else
      revertCVar("ResampleAlwaysSharpen", BLIZZARD_DEFAULTS.ResampleAlwaysSharpen)
    end
  elseif key == "reflectionMode" then
    if settings().enableReflectionMode then
      applyCVar("reflectionMode", settings().reflectionMode)
    else
      revertCVar("reflectionMode", BLIZZARD_DEFAULTS.reflectionMode)
    end
  elseif key == "weatherDensity" then
    if settings().enableWeatherDensity then
      applyCVar("weatherDensity", settings().weatherDensity)
    else
      revertCVar("weatherDensity", BLIZZARD_DEFAULTS.weatherDensity)
    end
  else
    self:ApplyAll()
  end
end

function module:ApplyAll()
  if not settings().enabled then return end

  self:Apply("groundEffectDensity")
  self:Apply("groundEffectFade")
  self:Apply("groundEffectDist")
  self:Apply("lodObjectFadeScale")
  self:Apply("lodObjectCullSize")
  self:Apply("terrainLodDist")
  self:Apply("resampleAlwaysSharpen")
  self:Apply("reflectionMode")
  self:Apply("weatherDensity")
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

function module:ResetToDefaults()
  settings().enableGroundEffectDensity = false
  settings().groundEffectDensity = self:GetDefault("groundEffectDensity")
  settings().enableGroundEffectFade = false
  settings().groundEffectFade = self:GetDefault("groundEffectFade")
  settings().enableGroundEffectDist = false
  settings().groundEffectDist = self:GetDefault("groundEffectDist")
  settings().enableLodObjectFadeScale = false
  settings().lodObjectFadeScale = self:GetDefault("lodObjectFadeScale")
  settings().enableLodObjectCullSize = false
  settings().lodObjectCullSize = self:GetDefault("lodObjectCullSize")
  settings().enableTerrainLodDist = false
  settings().terrainLodDist = self:GetDefault("terrainLodDist")
  settings().resampleAlwaysSharpen = false
  settings().enableReflectionMode = false
  settings().reflectionMode = self:GetDefault("reflectionMode")
  settings().enableWeatherDensity = false
  settings().weatherDensity = self:GetDefault("weatherDensity")

  self:RestoreDefaults()

  local acr = LibStub("AceConfigRegistry-3.0", true)
  if acr then
    acr:NotifyChange("SlackHacks")
  end
end
module.UnsetAll = module.ResetToDefaults

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
