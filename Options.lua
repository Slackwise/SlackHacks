local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

-- Documentation for AceConfig "Options" tables: https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables

function handleSlashCommand(input)
  local command = strlower(strtrim(input or ""))
  if command == "vendor" then
    Self.SelfVendor:SetEnabled(false)
    print("SlackHacks Self Vendor: OFF")
  elseif command:find("^vendor%s+") then
    Self.SelfVendor:HandleSlash(command:sub(8))
  else
    LibStub("AceConfigCmd-3.0"):HandleCommand("slack", "SlackHacks", input or "")
  end
end

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
    vendor = {
      type = "group",
      name = "Self Vendor",
      desc = "Trade recommended enchants, gems, and consumables to nearby group or guild members who salute you.",
      order = 10,
      args = {
        enabled = {
          name = "Enable Self Vendor",
          desc = "Open trades when an eligible party, raid, or guild member salutes you.",
          type = "toggle",
          get = function() return db.profile.selfVendor.enabled end,
          set = function(_, value) Self.SelfVendor:SetEnabled(value) end,
          order = 1
        },
        mode = {
          name = "Vendor Mode",
          desc = "Choose which recommendations are offered in the trade window.",
          type = "select",
          values = {
            everything = "Everything",
            augments = "Augments (Enchants and Gems)",
            consumables = "Consumables",
            flaskOil = "Flask and Oil",
            runes = "Runes",
            oil = "Oil",
            flasks = "Flasks"
          },
          sorting = { "everything", "augments", "consumables", "flaskOil", "runes", "oil", "flasks" },
          get = function() return db.profile.selfVendor.mode end,
          set = function(_, value) Self.SelfVendor:SetMode(value) end,
          order = 2
        }
      }
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

