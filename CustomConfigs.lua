-- Personal per-player overrides, keyed by battletag.
-- Each entry may define:
--   config    - a table merged into the addon's SavedVariables/db (see setSlackwiseOptions in Slackwise.lua)
--   setCvars  - a function called from Core.lua's setCVars() to apply personal CVar preferences
--   setOptions - a function called from Init.lua's OnInitialize() to merge `config` into the db

-- Change implicit global scope to our addon "namespace":
setfenv(1, _G.SlackHacks)

CustomConfigs = {
  -- Populated by Slackwise.lua, which references its own SLACKWISE_CONFIG/setSlackwiseCvars/setSlackwiseOptions.

  -- Test entry: a no-op stub to prove out the CustomConfigs lookup mechanism.
  ["blockspiders#1398"] = {
    config = {},
    setCvars = function() end,
    setOptions = function() end,
  },
}
