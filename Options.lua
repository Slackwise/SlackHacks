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
  elseif command:find("^sendaugs%s+") then
    if not isSlackwise() then
      print("SlackHacks: unknown command.")
      return
    end
    local arguments = command:match("^sendaugs%s+(.+)$")
    if arguments then
      Self.SelfVendor:SendAugsForClassSpec(arguments)
    else
      print("Usage: /slack sendaugs <class> <spec> [wowhead|icyveins|murlok]")
      print("SlackHacks: personal overrides use /slack sendaugs <character> <realm> [wowhead|icyveins|murlok]")
    end
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
    general = {
      type = "group",
      name = "General",
      desc = "Small quality-of-life features.",
      order = 5,
      args = {
        autoSellGreyItems = {
          name = "Auto Sell Grey Items",
          desc = "Automatically sell grey-quality items when visiting a merchant.",
          type = "toggle",
          get = function() return db.profile.general.autoSellGreyItems end,
          set = function(_, value) db.profile.general.autoSellGreyItems = value end,
          order = 1
        },
        autoRepairGroup = {
          type = "group",
          name = "Auto Repair",
          desc = "Automatically repair all items when visiting a merchant.",
          inline = true,
          order = 2,
          args = {
            autoRepair = {
              name = "Enable Auto Repair",
              type = "toggle",
              get = function() return db.profile.general.autoRepair end,
              set = function(_, value) db.profile.general.autoRepair = value end,
              order = 1
            },
            autoRepairMode = {
              name = "Funds",
              desc = "Choose which funds to use for automatic repairs.",
              type = "select",
              values = {
                personal = "Personal Funds",
                guild = "Guild Funds",
                guildRaid = "Guild Funds (Only in Raids)"
              },
              sorting = { "personal", "guild", "guildRaid" },
              get = function() return db.profile.general.autoRepairMode end,
              set = function(_, value) db.profile.general.autoRepairMode = value end,
              disabled = function() return not db.profile.general.autoRepair end,
              order = 2
            }
          },
        }
      }
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

