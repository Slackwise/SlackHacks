setfenv(1, _G.Slackwow)

options = {
  type = "group",
  args = {
    general = {
      type = "group",
      name = "General Settings",
      desc = "General settings for the entire addon.",
      args = {
        enable = {
          name = "Enabled",
          desc = "Enable/disable this addon",
          type = "toggle",
          get = function() return Self:IsEnabled() end,
          set = function() if Self:IsEnabled() then Self:Disable() else Self:Enable() end end,
        }
      }
    },
    bind = {
      type = "execute",
      name = "Set Bindings",
      desc = "Set binding presets for current character's class and spec.",
      func = function() setBindings() end
    }
  }
}

