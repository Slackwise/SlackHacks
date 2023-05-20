local addonName, addonTable = ...
setfenv(1, _G.SlackUI)

options = {
  type = "group",
  args = {
    enable = {
      name = "Enabled",
      desc = "Enable/disable " .. addonName,
      type = "toggle",
      get = function() return Self:IsEnabled() end,
      set = function() if Self:IsEnabled() then Self:Disable() else Self:Enable() end end,
    },
    debug = {
      name = "Enable Debugging",
      desc = "Enable debugging logs and stuff",
      type = "toggle",
      get = function() return SlackUIDB.isDebugging end,
      set = function() SlackUIDB.isDebugging = not SlackUIDB.isDebugging end,
    },
    bind = {
      type = "execute",
      name = "Set Bindings",
      desc = "Set binding presets for current character's class and spec.",
      func = function() setBindings() end
    }
  }
}

