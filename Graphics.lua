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
--   * HDROutput: Enables HDR output when supported by the monitor and render settings.
--   * HDRFactor: Scales HDR lighting relative to SDR, capped by monitor peak brightness.
--   * HDRBrightness/useHDRBrightness: Overrides the SDR/UI brightness level in nits.
--   * HDRPeakBrightness/useHDRPeakBrightness: Overrides the monitor's peak brightness in nits.

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
  HDROutput = 0,
  HDRFactor = 2.0,
  HDRBrightness = 203,
  HDRPeakBrightness = 400,
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
  hdrOutput = "HDROutput",
  hdrFactor = "HDRFactor",
  hdrBrightness = "HDRBrightness",
  hdrPeakBrightness = "HDRPeakBrightness",
}

local OPTION_CVARS = {
  groundEffectDensity = { "groundEffectDensity" },
  groundEffectFade = { "groundEffectFade" },
  groundEffectDist = { "groundEffectDist" },
  lodObjectFadeScale = { "lodObjectFadeScale" },
  lodObjectCullSize = { "lodObjectCullSize" },
  terrainLodDist = { "terrainLodDist" },
  resampleAlwaysSharpen = { "ResampleAlwaysSharpen" },
  reflectionMode = { "reflectionMode" },
  weatherDensity = { "weatherDensity" },
  hdrOutput = {
    "HDROutput",
    "HDRFactor",
    "HDRBrightness",
    "useHDRBrightness",
    "HDRPeakBrightness",
    "useHDRPeakBrightness",
  },
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

--- Reports whether the current game client exposes every CVar required by an option group.
---@param key string Graphics option key.
---@return boolean available True when all required CVars exist on this client.
function module:IsOptionAvailable(key)
  local cvars = OPTION_CVARS[key]
  if not cvars or type(GetCVar) ~= "function" then return false end
  for _, cvar in ipairs(cvars) do
    local ok, value = pcall(GetCVar, cvar)
    if not ok or value == nil then return false end
  end
  return true
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

--- Resets one graphics option to its game default and refreshes the options panel.
---@param key string Graphics option key to reset.
function module:ResetOption(key)
  if key == "resampleAlwaysSharpen" then
    settings()[key] = false
  elseif key == "hdrOutput" then
    settings()[key] = self:GetDefault(key) ~= 0
  else
    settings()[key] = self:GetDefault(key)
  end

  self:Apply(key)
  local acr = LibStub("AceConfigRegistry-3.0", true)
  if acr then
    acr:NotifyChange("SlackHacks")
  end
end

--- Applies a saved graphics option to its game CVar.
---@param key string Graphics option key to apply.
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
    if settings().resampleAlwaysSharpen then
      applyCVar("ResampleAlwaysSharpen", 1)
    else
      revertCVar("ResampleAlwaysSharpen", BLIZZARD_DEFAULTS.ResampleAlwaysSharpen)
    end
  elseif key == "reflectionMode" then
    applyCVar("reflectionMode", settings().reflectionMode)
  elseif key == "weatherDensity" then
    applyCVar("weatherDensity", settings().weatherDensity)
  elseif key == "hdrOutput" then
    applyCVar("HDROutput", settings().hdrOutput and 1 or 0)
    self:Apply("hdrFactor")
    self:Apply("hdrBrightness")
    self:Apply("hdrPeakBrightness")
  elseif key == "hdrFactor" then
    if settings().hdrOutput then
      applyCVar("HDRFactor", settings().hdrFactor)
    else
      revertCVar("HDRFactor", BLIZZARD_DEFAULTS.HDRFactor)
    end
  elseif key == "hdrBrightness" then
    if settings().hdrOutput then
      applyCVar("useHDRBrightness", settings().enableHDRBrightness and 1 or 0)
      applyCVar("HDRBrightness", settings().hdrBrightness)
    else
      revertCVar("useHDRBrightness", 0)
      revertCVar("HDRBrightness", BLIZZARD_DEFAULTS.HDRBrightness)
    end
  elseif key == "hdrPeakBrightness" then
    if settings().hdrOutput then
      applyCVar("useHDRPeakBrightness", settings().enableHDRPeakBrightness and 1 or 0)
      applyCVar("HDRPeakBrightness", settings().hdrPeakBrightness)
    else
      revertCVar("useHDRPeakBrightness", 0)
      revertCVar("HDRPeakBrightness", BLIZZARD_DEFAULTS.HDRPeakBrightness)
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
  self:Apply("hdrOutput")
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
  revertCVar("HDROutput", BLIZZARD_DEFAULTS.HDROutput)
  revertCVar("HDRFactor", BLIZZARD_DEFAULTS.HDRFactor)
  revertCVar("useHDRBrightness", 0)
  revertCVar("HDRBrightness", BLIZZARD_DEFAULTS.HDRBrightness)
  revertCVar("useHDRPeakBrightness", 0)
  revertCVar("HDRPeakBrightness", BLIZZARD_DEFAULTS.HDRPeakBrightness)
end

--- Restores all saved graphics options and their game CVars to defaults.
function module:ResetToDefaults()
  settings().groundEffectDensity = self:GetDefault("groundEffectDensity")
  settings().groundEffectFade = self:GetDefault("groundEffectFade")
  settings().groundEffectDist = self:GetDefault("groundEffectDist")
  settings().lodObjectFadeScale = self:GetDefault("lodObjectFadeScale")
  settings().lodObjectCullSize = self:GetDefault("lodObjectCullSize")
  settings().terrainLodDist = self:GetDefault("terrainLodDist")
  settings().resampleAlwaysSharpen = false
  settings().reflectionMode = self:GetDefault("reflectionMode")
  settings().weatherDensity = self:GetDefault("weatherDensity")
  settings().hdrOutput = self:GetDefault("HDROutput") ~= 0
  settings().hdrFactor = self:GetDefault("HDRFactor")
  settings().enableHDRBrightness = false
  settings().hdrBrightness = self:GetDefault("HDRBrightness")
  settings().enableHDRPeakBrightness = false
  settings().hdrPeakBrightness = self:GetDefault("HDRPeakBrightness")

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
