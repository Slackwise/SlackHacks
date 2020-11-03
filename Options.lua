local addon = _G.Slackwow
addon.options = {
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
          get = function() return addon:IsEnabled() end,
          set = function() if addon:IsEnabled() then addon:Disable() else addon:Enable() end end,
        }
      }
    },
    bind = {
      type = "execute",
      name = "Set Bindings",
      desc = "Set binding presets for current character's class and spec.",
      func = function() addon:SetBindings() end
    }
  }
}

