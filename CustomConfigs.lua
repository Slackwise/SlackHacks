-- Personal per-player overrides, keyed by battletag.
-- Each entry may define:
--   config    - a table merged into the addon's SavedVariables/db (see setSlackwiseOptions in Slackwise.lua)
--   setCvars  - a function called from Core.lua's setCVars() to apply personal CVar preferences
--   setOptions - a function called from Init.lua's OnInitialize() to merge `config` into the db

-- Change implicit global scope to our addon "namespace":
setfenv(1, _G.SlackHacks)

--- Merges a CustomConfigs entry's `config.profile`/`.global`/`.char` tables into the live db
--- (mirrors the merge logic in setSlackwiseOptions in Slackwise.lua, generalized for reuse).
function applyCustomConfig(config)
  if not db or type(config) ~= "table" then return end

  if type(config.profile) == "table" and type(db.profile) == "table" then
    recursiveMerge(db.profile, config.profile)
  end
  if type(config.global) == "table" and type(db.global) == "table" then
    recursiveMerge(db.global, config.global)
  end
  if type(config.char) == "table" and type(db.char) == "table" then
    recursiveMerge(db.char, config.char)
  end

  if isInitialized() and Self.Minimap and Self.Minimap.Refresh then
    Self.Minimap:Refresh()
  end
end

CustomConfigs = {
  -- Populated by Slackwise.lua, which references its own SLACKWISE_CONFIG/setSlackwiseCvars/setSlackwiseOptions.

  ["blockspiders#1398"] = {
    config = {
      profile = {
        general = {
          maximumCameraZoom = true,
          enableDynamicCamera = true,
        },
        combat = {
          raiseCastingNameplates = true,
        },
        minimap = {
          enabled = true,
          shape = "square",
          showAllMinimapTracking = true,
        },
        weeklies = {
          enabled = true,
          trackDelves = true,
        },
      },
    },
    setCvars = function() end,
    setOptions = function()
      applyCustomConfig(CustomConfigs["blockspiders#1398"].config)
    end,
  },
}
