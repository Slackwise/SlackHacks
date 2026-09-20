local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

-- Documentation for AceConfig "Options" tables: https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables

function openOptions()
  -- If Blizzard SettingsPanel is already open, toggle it closed:
  if SettingsPanel and SettingsPanel:IsShown() then
    HideUIPanel(SettingsPanel)
    return
  end

  local categoryID = Self.configCategoryID or (Self.configDialog and Self.configDialog.name)
  if Settings and Settings.OpenToCategory and categoryID and not InCombatLockdown() then
    Settings.OpenToCategory(categoryID)
    return
  end

  if InterfaceOptionsFrame_OpenToCategory and Self.configDialog and not InCombatLockdown() then
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
      InterfaceOptionsFrame:Hide()
      return
    end
    InterfaceOptionsFrame_OpenToCategory(Self.configDialog)
    return
  end

  local acd = LibStub("AceConfigDialog-3.0")
  if acd.OpenFrames and acd.OpenFrames["SlackHacks"] and acd.OpenFrames["SlackHacks"]:IsShown() then
    acd:Close("SlackHacks")
  else
    acd:Open("SlackHacks")
  end
end
toggleOptions = openOptions

function handleSlashCommand(input)
  local command = strlower(strtrim(input or ""))
  if command == "vendor" then
    print("Usage: /slack vendor [consumablesmissing|consumables|flaskandoil|oil|runes|augments] [wowhead|icyveins|murlok]")
  elseif command == "clearlogs" then
    clearLogs()
    print("SlackHacks: logs cleared")
  elseif command == "options" or command == "config" or command == "opt" then
    openOptions()
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
    minimap = {
      type = "group",
      name = "Minimap",
      desc = "Minimap shape, opacity, and button visibility.",
      order = 7.5,
      args = {
        enabled = {
          name = "Enable",
          desc = "Enable minimap enhancements. When disabled, the minimap looks and behaves exactly like stock Blizzard UI.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.minimap.enabled end,
          set = function(_, value)
            db.profile.minimap.enabled = value
            if value then
              Self.Minimap:Enable()
            else
              Self.Minimap:Disable()
            end
            Self.Minimap:Refresh()
          end,
          order = 0
        },
        openEditMode = {
          name = "Open Visual Settings via Edit Mode",
          desc = "Open Blizzard's Edit Mode and select the Minimap to configure its visual settings and position/size.",
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
          disabled = function() return not db.profile.minimap.enabled end,
          order = 0.1
        },
        appearanceGroup = {
          type = "group",
          name = "Appearance",
          inline = true,
          disabled = function() return not db.profile.minimap.enabled end,
          order = 1,
          args = {
            shape = {
              name = "Shape",
              desc = "The shape of the minimap.",
              type = "select",
              width = "full",
              values = { circle = "Round", square = "Square" },
              sorting = { "circle", "square" },
              get = function() return db.profile.minimap.shape end,
              set = function(_, value)
                db.profile.minimap.shape = value
                Self.Minimap:Refresh()
              end,
              order = 1
            },
            showBorder = {
              name = "Show Border",
              desc = "Show the minimap's background border.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.showBorder end,
              set = function(_, value)
                db.profile.minimap.showBorder = value
                Self.Minimap:Refresh()
              end,
              order = 2
            }
          }
        },
        opacityGroup = {
          type = "group",
          name = "Opacity",
          inline = true,
          disabled = function() return not db.profile.minimap.enabled end,
          order = 2,
          args = {
            alpha = {
              name = "Opacity",
              desc = "Base opacity of the minimap.",
              type = "range",
              min = 0,
              max = 100,
              step = 1,
              get = function() return db.profile.minimap.alpha end,
              set = function(_, value)
                db.profile.minimap.alpha = value
                Self.Minimap:Refresh()
              end,
              order = 1
            },
            fadeEnabled = {
              name = "Fade Based on Combat / Movement",
              desc = "Temporarily use a different opacity while in combat or while moving.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.fadeEnabled end,
              set = function(_, value)
                db.profile.minimap.fadeEnabled = value
                Self.Minimap:Refresh()
              end,
              order = 2
            },
            combatAlpha = {
              name = "Combat Opacity",
              type = "range",
              min = 0,
              max = 100,
              step = 1,
              get = function() return db.profile.minimap.combatAlpha end,
              set = function(_, value)
                db.profile.minimap.combatAlpha = value
                Self.Minimap:Refresh()
              end,
              disabled = function() return not db.profile.minimap.fadeEnabled end,
              order = 3
            },
            movingAlpha = {
              name = "Moving Opacity",
              type = "range",
              min = 0,
              max = 100,
              step = 1,
              get = function() return db.profile.minimap.movingAlpha end,
              set = function(_, value)
                db.profile.minimap.movingAlpha = value
                Self.Minimap:Refresh()
              end,
              disabled = function() return not db.profile.minimap.fadeEnabled end,
              order = 4
            }
          }
        },
        buttonsGroup = {
          type = "group",
          name = "Buttons",
          inline = true,
          disabled = function() return not db.profile.minimap.enabled end,
          order = 3,
          args = {
            showZoneText = {
              name = "Show Zone Text",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.showZoneText end,
              set = function(_, value)
                db.profile.minimap.showZoneText = value
                Self.Minimap:Refresh()
              end,
              order = 1
            },
            showClock = {
              name = "Show Clock",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.showClock end,
              set = function(_, value)
                db.profile.minimap.showClock = value
                Self.Minimap:Refresh()
              end,
              order = 2
            },
            showCalendar = {
              name = "Show Calendar Button",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.showCalendar end,
              set = function(_, value)
                db.profile.minimap.showCalendar = value
                Self.Minimap:Refresh()
              end,
              order = 3
            },
            hideDiel = {
              name = "Hide Day/Night Icon",
              desc = [[Hide the big useless day/night (diel) icon.]],
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.hideDiel end,
              set = function(_, value)
                db.profile.minimap.hideDiel = value
                Self.Minimap:Refresh()
              end,
              hidden = function() return isRetail() end,
              order = 3.5
            },
            showTracking = {
              name = "Show Tracking Button",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.showTracking end,
              set = function(_, value)
                db.profile.minimap.showTracking = value
                Self.Minimap:Refresh()
              end,
              order = 4
            },
            showAllMinimapTracking = {
              name = "Show All Minimap Tracking Options",
              desc = "Show all minimap tracking options,\nincluding the option to turn off target tracking.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.showAllMinimapTracking end,
              set = function(_, value)
                db.profile.minimap.showAllMinimapTracking = value
                Self.Minimap:Refresh()
              end,
              order = 5
            },
            hideExtraButtons = {
              name = "Hide Extra Minimap Buttons",
              desc = "Hide LFG, instance difficulty, garrison/expansion landing page, and other extra buttons (always active in square mode).",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function()
                if db.profile.minimap.shape == "square" then return true end
                return db.profile.minimap.hideExtraButtons
              end,
              set = function(_, value)
                db.profile.minimap.hideExtraButtons = value
                Self.Minimap:Refresh()
              end,
              disabled = function() return db.profile.minimap.shape == "square" end,
              order = 6
            },
            mouseWheelZoom = {
              name = "Mouse Wheel Zoom",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.mouseWheelZoom end,
              set = function(_, value)
                db.profile.minimap.mouseWheelZoom = value
                Self.Minimap:Refresh()
              end,
              order = 7
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
    weeklies = {
      type = "group",
      name = "Weeklies",
      desc = "Track weekly quest completions and activities.",
      order = 11,
      args = {
        enabled = {
          name = "Enable",
          desc = "Track weekly quest completions and activities.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.weeklies.enabled end,
          set = function(_, value) Self.Weeklies:SetEnabled(value) end,
          order = 0
        },
        trackDelves = {
          name = "Track Delves",
          desc = "Show a Delves button on the Objective Tracker with the weekly Gilded Stash, Trovehunter's Bounty, Valeera's level, and Delve Renown.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.weeklies.trackDelves end,
          set = function(_, value) Self.Weeklies:SetTrackDelves(value) end,
          disabled = function() return not db.profile.weeklies.enabled end,
          order = 1
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

