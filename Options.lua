local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

-- Documentation for AceConfig "Options" tables: https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables

options = {
  type = "group",
  args = {
    enable = {
      name = "Enabled",
      desc = "Enable/disable " .. addonName,
      type = "toggle",
      get = function() return Self:IsEnabled() end,
      set = function() if Self:IsEnabled() then Self:Disable() else Self:Enable() end end,
      order = 0 -- first
    },
    debug = {
      name = "Enable Debugging",
      desc = "Enable debugging logs and stuff",
      type = "toggle",
      get = function() return db.global.isDebugging end,
      set = function()
        db.global.isDebugging = not db.global.isDebugging
        if db.global.isDebugging then
          print("SlackHacks Debugging ON")
        else
          print("SlackHacks Debugging OFF")
        end
      end,
    },
    bind = {
      type = "execute",
      name = "Set Bindings",
      desc = "Set binding presets for current character's class and spec.",
      func = function() setBindings() end,
      hidden = true -- Current just used by me
    },
    reset = {
      type = "execute",
      name = "Reset All Data",
      desc = "DANGER: Wipes all settings! Cannot be undone!",
      func = function()
        db:ResetDB()
        print("SlackHacks: ALL DATA WIPED")
      end,
      confirm = true
    }
  },
  -- mount = {
  --   type = "group",
  --   name = "Mount",
  --   desc = "Mount binding configuration",
  --   func = function()
  --     -- mount()
  --     print("SlackHacks: mounting...")
  --   end,
  --   args = {
  --   }
  -- }
}

