local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

-- Documentation for AceConfig "Options" tables: https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables

function handleSlashCommand(input)
  local command = strlower(strtrim(input or ""))
  if command == "vendor" then
    print("Usage: /slack vendor [consumablesmissing|consumables|flaskandoil|oil|runes|augments] [wowhead|icyveins|murlok]")
  elseif command == "clearlogs" then
    clearLogs()
    print("SlackHacks: logs cleared")
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
  icon = SLACKHACKS_ICON,
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
    general = {
      type = "group",
      name = "General",
      desc = "Small quality-of-life features.",
      order = 5,
      args = {
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
          order = 1
        },
        showAllMinimapTracking = {
          name = "Show All Minimap Tracking",
          desc = "Show all minimap tracking options,\nincluding the option to turn off target tracking.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.general.showAllMinimapTracking end,
          set = function(_, value)
            db.profile.general.showAllMinimapTracking = value
            setCVars()
          end,
          order = 2
        },
        autoSellGreyItems = {
          name = "Auto Sell Grey Items",
          desc = "Automatically sell grey-quality items when visiting a merchant.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.general.autoSellGreyItems end,
          set = function(_, value) db.profile.general.autoSellGreyItems = value end,
          order = 3
        },
        autoRepairGroup = {
          type = "group",
          name = "Auto Repair",
          desc = "Automatically repair all items when visiting a merchant.",
          inline = true,
          order = 4,
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
    debug = {
      type = "group",
      name = "Debug",
      desc = "Debugging and logging options.",
      order = 6,
      args = {
        toggle = {
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
            Self.Buffs:Refresh()
          end,
          order = 1
        },
        clearLogs = {
          name = "Clear Logs",
          desc = "Clear all debug logs stored in SlackHacksDB.",
          type = "execute",
          func = function()
            clearLogs()
            print("SlackHacks: logs cleared")
          end,
          confirm = true,
          order = 2
        },
        logPurgeGroup = {
          type = "group",
          name = "Log Purging",
          desc = "Automatically remove old debug logs so SlackHacksDB doesn't grow unbounded.",
          inline = true,
          order = 3,
          args = {
            logPurgeEnabled = {
              name = "Automatically Purge Old Logs",
              desc = "Once per login, remove logged entries older than the configured number of hours.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.global.logPurgeEnabled end,
              set = function(_, value) db.global.logPurgeEnabled = value end,
              order = 1
            },
            logPurgeHours = {
              name = "Keep Logs For (Hours)",
              desc = "Number of hours to keep a log entry before it is eligible for automatic purging.",
              type = "input",
              width = "full",
              get = function() return tostring(db.global.logPurgeHours) end,
              set = function(_, value) db.global.logPurgeHours = tonumber(value) end,
              validate = function(_, value)
                local hours = tonumber(value)
                return hours and hours >= LOG_PURGE_MIN_HOURS and hours <= LOG_PURGE_MAX_HOURS
              end,
              disabled = function() return not db.global.logPurgeEnabled end,
              order = 2
            },
            purgeNow = {
              name = "Purge Old Logs Now",
              desc = "Immediately remove logged entries older than the configured number of hours.",
              type = "execute",
              func = function()
                purgeOldLogs()
                print("SlackHacks: old logs purged")
              end,
              order = 3
            }
          }
        }
      }
    },
    combat = {
      type = "group",
      name = "Combat",
      desc = "Combat-related features.",
      order = 7,
      args = {
        general = {
          type = "group",
          name = "General",
          desc = "Combat features that apply to all classes.",
          order = 1,
          args = {
            raiseCastingNameplates = {
              name = "Raise Casting Nameplates",
              desc = "Raise enemy nameplates while they are casting.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.combat.raiseCastingNameplates end,
              set = function(_, value)
                db.profile.combat.raiseCastingNameplates = value
                resetNameplateCastLift()
              end,
              order = 1
            }
          }
        },
        paladin = {
          type = "group",
          name = "Paladin",
          desc = "Combat features specific to Paladins.",
          order = 2,
          args = {
            trackHolyShockCharges = {
              name = "Track Holy Shock Charges",
              desc = "Show two circular charge trackers next to the Holy Power bar for Holy Shock.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.combat.paladin.trackHolyShockCharges end,
              set = function(_, value)
                db.profile.combat.paladin.trackHolyShockCharges = value
                Self.ChargeTracking:Refresh()
              end,
              order = 1
            },
            holyShockChargesPosition = {
              name = "Position",
              desc = "Where to anchor the Holy Shock charge trackers relative to the Holy Power bar.",
              type = "select",
              width = "full",
              values = {
                above = "Above Holy Power Bar",
                below = "Below Holy Power Bar"
              },
              sorting = { "above", "below" },
              get = function() return db.profile.combat.paladin.holyShockChargesPosition end,
              set = function(_, value)
                db.profile.combat.paladin.holyShockChargesPosition = value
                Self.ChargeTracking:Refresh()
              end,
              disabled = function() return not db.profile.combat.paladin.trackHolyShockCharges end,
              order = 2
            }
          }
        }
      }
    },
    buffs = {
      type = "group",
      name = "Consumable Buff Reminders",
      desc = "Reminds you to keep up raid/dungeon consumables\nwith clickable icons.",
      order = 8,
      args = {
        enabled = {
          name = "Enable",
          desc = "Show consumable buff reminders.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.buffs.enabled end,
          set = function(_, value)
            db.profile.buffs.enabled = value
            Self.Buffs:Refresh()
          end,
          order = 0
        },
        openEditMode = {
          name = "Position Buff Icons via Edit Mode",
          desc = "Open Blizzard's Edit Mode to position the buff reminder icons.",
          type = "execute",
          func = function()
            if InCombatLockdown() then return end
            if SettingsPanel and SettingsPanel:IsShown() then
              HideUIPanel(SettingsPanel)
            end
            if EditModeManagerFrame then
              ShowUIPanel(EditModeManagerFrame)
            end
          end,
          order = 0.1
        },
        showGlow = {
          name = "Show Item Glow",
          desc = "Show the proc golden glow on the icons to catch your attention.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.buffs.showGlow end,
          set = function(_, value)
            db.profile.buffs.showGlow = value
            Self.Buffs:Refresh()
          end,
          order = 0.5
        },
        showIfExpiringGroup = {
          type = "group",
          name = "Buff Expiration",
          inline = true,
          order = 0.6,
          args = {
            showIfExpiring = {
              name = "Show Buffs if They'll Expire Mid-Mythic / Raid Boss",
              desc = "Show reminders when a timed buff will expire before the Mythic dungeon timer or estimated raid boss fight ends.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.showIfExpiring end,
              set = function(_, value)
                db.profile.buffs.showIfExpiring = value
                Self.Buffs:Refresh()
              end,
              order = 1
            },
            durationPosition = {
              name = "Duration Remaining Position",
              desc = "Where to show the buff's remaining duration relative to its icon.",
              type = "select",
              width = "full",
              values = {
                above = "Above Icon",
                below = "Below Icon"
              },
              sorting = { "above", "below" },
              get = function() return db.profile.buffs.durationPosition end,
              set = function(_, value)
                db.profile.buffs.durationPosition = value
                Self.Buffs:Refresh()
              end,
              disabled = function() return not db.profile.buffs.showIfExpiring end,
              order = 2
            }
          }
        },
        contentGroup = {
          type = "group",
          name = "Where to Remind",
          inline = true,
          order = 1,
          args = {
            mythicDungeons = {
              name = "In Mythic Dungeons",
              desc = "Show buff reminders while in a Mythic (or Mythic Keystone)\ndungeon with a group.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.contentTypes.mythicDungeons end,
              set = function(_, value)
                db.profile.buffs.contentTypes.mythicDungeons = value
                Self.Buffs:Refresh()
              end,
              order = 1
            },
            nonLfrRaids = {
              name = "In (Non-LFR) Raids",
              desc = "Show buff reminders while in a Normal, Heroic, or Mythic raid\nwith a group.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.contentTypes.nonLfrRaids end,
              set = function(_, value)
                db.profile.buffs.contentTypes.nonLfrRaids = value
                Self.Buffs:Refresh()
              end,
              order = 2
            }
          }
        },
        categoriesGroup = {
          type = "group",
          name = "Buffs to Track",
          inline = true,
          order = 2,
          args = {
            wellFed = {
              name = "Food Buff",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.categories.wellFed end,
              set = function(_, value)
                db.profile.buffs.categories.wellFed = value
                Self.Buffs:Refresh()
              end,
              order = 1
            },
            flask = {
              name = "Flask Buff",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.categories.flask end,
              set = function(_, value)
                db.profile.buffs.categories.flask = value
                Self.Buffs:Refresh()
              end,
              order = 2
            },
            oil = {
              name = "Oil Buff",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.categories.oil end,
              set = function(_, value)
                db.profile.buffs.categories.oil = value
                Self.Buffs:Refresh()
              end,
              order = 3
            },
            rune = {
              name = "Augment Rune Buff",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.categories.rune end,
              set = function(_, value)
                db.profile.buffs.categories.rune = value
                Self.Buffs:Refresh()
              end,
              order = 4
            }
          }
        },
        iconSize = {
          name = "Icon Size",
          desc = "Size of the buff reminder icons as a percentage of the standard aura icon size.",
          type = "range",
          min = 50,
          max = 300,
          step = 5,
          get = function() return db.profile.buffs.iconSize end,
          set = function(_, value)
            db.profile.buffs.iconSize = value
            Self.Buffs:Refresh()
          end,
          order = 5
        },
        iconGap = {
          name = "Icon Gap",
          desc = "Space between the buff reminder icons.",
          type = "range",
          min = 0,
          max = 100,
          step = 1,
          get = function() return db.profile.buffs.iconGap end,
          set = function(_, value)
            db.profile.buffs.iconGap = value
            Self.Buffs:Refresh()
          end,
          order = 6
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

