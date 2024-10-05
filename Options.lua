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
      get = function() return db.global.isDebugging end,
      set = function()
        db.global.isDebugging = not db.global.isDebugging
        if db.global.isDebugging then
          print("SlackUI Debugging ON")
        else
          print("SlackUI Debugging OFF")
        end
      end,
    },
    bind = {
      type = "execute",
      name = "Set Bindings",
      desc = "Set binding presets for current character's class and spec.",
      func = function() setBindings() end
    },
    reset = {
      type = "execute",
      name = "Reset All Data",
      desc = "DANGER: Wipes all settings! Cannot be undone!",
      func = function()
        db:ResetDB()
        print("SlackUI: ALL DATA WIPED")
      end
    }
  },
  -- mount = {
  --   type = "group",
  --   name = "Mount",
  --   desc = "Mount binding configuration",
  --   func = function()
  --     -- mount()
  --     print("SlackUI: mounting...")
  --   end,
  --   args = {
  --   }
  -- }
}

