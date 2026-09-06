local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

-- Documentation for AceConfig "Options" tables: https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables

function handleSlashCommand(input)
  local command = strlower(strtrim(input or ""))
  if command == "vendor" then
    print("Usage: /slack vendor [consumablesmissing|consumables|flaskandoil|oil|runes|augments] [wowhead|icyveins|murlok]")
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

local selfVendorEmoteValues, selfVendorEmoteSorting = {}, {}
for token, emote in pairs(SELF_VENDOR_TRIGGER_EMOTES) do
  selfVendorEmoteValues[token] = emote.slashCommands
  table.insert(selfVendorEmoteSorting, token)
end
table.sort(selfVendorEmoteSorting, function(left, right)
  return selfVendorEmoteValues[left] < selfVendorEmoteValues[right]
end)

local selfVendorModeSorting = {
  Enum.SelfVendorMode.CONSUMABLES_MISSING,
  Enum.SelfVendorMode.CONSUMABLES_ALL,
  Enum.SelfVendorMode.CONSUMABLES_PERSISTENT,
  Enum.SelfVendorMode.OIL,
  Enum.SelfVendorMode.RUNES,
  Enum.SelfVendorMode.AUGMENTS,
}

local function selfVendorModeOptions()
  local args = {}
  args.enabled = {
    name = "Enable Self Vendor",
    desc = "Enable or disable all Self Vendor emote and slash-command triggers.",
    type = "toggle",
    descStyle = "inline",
    width = "full",
    get = function() return db.profile.selfVendor.enabled end,
    set = function(_, value) Self.SelfVendor:SetEnabled(value) end,
    order = 0,
  }
  for order, mode in ipairs(selfVendorModeSorting) do
    local configuredMode = mode
    local details = SELF_VENDOR_MODES[mode]
    args[details.key] = {
      type = "group",
      name = details.name,
      inline = true,
      order = order,
      args = {
        description = {
          type = "description",
          name = details.description,
          width = "full",
          order = 1,
        },
        enabled = {
          name = "Enable",
          type = "toggle",
          width = 1.1,
          get = function() return db.profile.selfVendor.modes[configuredMode].enabled end,
          set = function(_, value) Self.SelfVendor:SetModeEnabled(configuredMode, value) end,
          order = 2,
        },
        triggerEmote = {
          name = "Trigger Emote",
          type = "select",
          width = 1.9,
          values = selfVendorEmoteValues,
          sorting = selfVendorEmoteSorting,
          get = function() return db.profile.selfVendor.modes[configuredMode].triggerEmote end,
          set = function(_, value) Self.SelfVendor:SetModeTriggerEmote(configuredMode, value) end,
          order = 3,
        },
      },
    }
    if mode == Enum.SelfVendorMode.RUNES then
      args[details.key].args.runeQuantity = {
        name = "Rune Stack Size",
        type = "input",
        width = 0.7,
        get = function() return tostring(db.profile.selfVendor.modes[configuredMode].runeQuantity) end,
        set = function(_, value) Self.SelfVendor:SetRuneQuantity(value) end,
        validate = function(_, value) return tonumber(value) and tonumber(value) >= 1 and tonumber(value) <= 100 end,
        order = 4,
      }
    end
  end
  return args
end

options = {
  type = "group",
  args = {
    enable = {
      name = "Enable",
      desc = "Fully enables/disables the entire addon",
      type = "toggle",
      descStyle = "inline",
      width = "full",
      get = function() return Self:IsEnabled() end,
      set = function() if Self:IsEnabled() then Self:Disable() else Self:Enable() end end,
      order = 0 -- first
    },
    debug = {
      name = "Debug Mode",
      desc = "Prints debug information to the chat window and logs to DB for later analysis",
      type = "toggle",
      descStyle = "inline",
      width = "full",
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
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.general.autoSellGreyItems end,
          set = function(_, value) db.profile.general.autoSellGreyItems = value end,
          order = 1
        },
        maximumCameraZoom = {
          name = "Maximum Camera Zoom",
          desc = "Allow the camera to zoom out to its maximum distance.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.general.maximumCameraZoom end,
          set = function(_, value)
            db.profile.general.maximumCameraZoom = value
            setCVars()
          end,
          order = 2
        },
        autoRepairGroup = {
          type = "group",
          name = "Auto Repair",
          desc = "Automatically repair all items when visiting a merchant.",
          inline = true,
          order = 3,
          args = {
            autoRepair = {
              name = "Enable Auto Repair",
              desc = "Automatically repair all items when visiting a merchant.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.general.autoRepair end,
              set = function(_, value) db.profile.general.autoRepair = value end,
              order = 1
            },
            autoRepairMode = {
              name = "Funds",
              desc = "Choose which funds to use for automatic repairs.",
              type = "select",
              width = "full",
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
            },
            autoRepairModeDescription = {
              type = "description",
              name = "Choose which funds to use for automatic repairs.",
              width = "full",
              order = 3
            }
          },
        }
      }
    },
    vendor = {
      type = "group",
      name = "Self Vendor",
      desc = "Trade recommended enchants, gems, and consumables to nearby group or guild members using targeted emotes.",
      order = 10,
      args = selfVendorModeOptions()
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

