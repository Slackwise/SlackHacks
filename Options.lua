local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

dbDefaults = {
  global = {
    configVersion = CONFIG_VERSION,
    logs = {
      debug = {},
      error = {},
      isDebugging = false,
      errorLoggingEnabled = true,
      logPurgeEnabled = true,
      logPurgeHours = 48,
    },
  },
  char = {
    cache = {
      lastKnownGildedStashesRemaining = nil
    }
  },
  profile = {
    inventory = {
      autoSellGreyItems = false,
      autoRepair = false,
      autoRepairMode = "personal"
    },
    controls = {
      maximumCameraZoom = false,
      enableDynamicCamera = false
    },
    combat = {
      raiseCastingNameplates = false,
      paladin = {
        trackHolyShockCharges = false,
        holyShockChargesPosition = "below"
      }
    },
    movableWindows = {
      enabled = false,
      modifierKey = "NONE", -- "NONE" | "SHIFT" | "CTRL" | "ALT" -- held to drag a registered frame
      enableScaling = false, -- scaleModifierKey + mouse wheel over a title bar resizes a registered frame
      scaleModifierKey = "NONE", -- "NONE" | "SHIFT" | "CTRL" | "ALT" -- held to scale a registered frame
      savePositionStrategy = "permanent", -- "off" | "session" | "permanent"
      saveScaleStrategy = "permanent", -- "session" | "permanent"
      points = {},
      scales = {}
    },
    minimap = {
      enabled = false,
      shape = "circle",
      showIconsOnHover = false,
      showAddonIconsOnHover = false,
      hideDiel = false,
      showAllMinimapTracking = false,
      alpha = 100,
      fadeEnabled = false,
      combatAlpha = 100,
      movingAlpha = 100,
      showZoneText = true,
      showClock = true,
      showTracking = true,
      showCalendar = true,
      showInstanceDifficulty = true,
      showGarrison = true,
      showAddonCompartment = true,
      addonsInCompartment = false
    },
    buffs = {
      enabled = false,
      point = "TOP",
      relativePoint = "TOP",
      x = 0,
      y = -130,
      iconSize = 150,
      iconGap = 6,
      showGlow = true,
      showIfExpiring = true,
      durationPosition = "below",
      contentTypes = {
        mythicDungeons = true,
        nonLfrRaids = true
      },
      categories = {
        wellFed = true,
        flask = true,
        oil = true,
        rune = false
      }
    },
    selfVendor = {
      enabled = false,
      source = "murlok",
      modes = {
        [Enum.SelfVendorMode.CONSUMABLES_MISSING] = { enabled = false, triggerEmote = "SALUTE" },
        [Enum.SelfVendorMode.CONSUMABLES_ALL] = { enabled = false, triggerEmote = "GLARE" },
        [Enum.SelfVendorMode.CONSUMABLES_PERSISTENT] = { enabled = false, triggerEmote = "GAZE" },
        [Enum.SelfVendorMode.OIL] = { enabled = false, triggerEmote = "FLIRT" },
        [Enum.SelfVendorMode.AUGMENT_RUNES] = { enabled = false, triggerEmote = "FLEX", runeQuantity = 5 },
        [Enum.SelfVendorMode.AUGMENTS] = { enabled = false, triggerEmote = "VICTORY" },
        [Enum.SelfVendorMode.VANTUS_RUNE] = { enabled = false, triggerEmote = "GLARE" },
      }
    },
    weeklies = {
      enabled = false,
      trackDelves = true
    },
    mounts = {
      ["ground"] = nil,
      ["ground-showoff"] = nil,
      ["skyriding"] = nil,
      ["skyriding-showoff"] = nil,
      ["steadyflight"] = nil,
      ["steadyflight-showoff"] = nil,
      ["water"] = nil,
      ["water-showoff"] = nil,
      ["ground-passenger"] = nil,
      ["ground-passenger-showoff"] = nil,
      ["skyriding-passenger"] = nil,
      ["skyriding-passenger-showoff"] = nil,
      ["steadyflight-passenger"] = nil,
      ["steadyflight-passenger-showoff"] = nil,
    }
  }
}

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
    print("Usage: /slack vendor [consumablesmissing|consumables|flaskandoil|oil|augmentrunes|vantusrune|augments] [wowhead|icyveins|murlok]")
  elseif command == "clearlogs" or command == "cleardebuglogs" then
    clearDebugLogs()
    print("SlackHacks: debug logs cleared")
  elseif command == "reporterrors" or command == "reportbugs" or command == "bug" then
    Self.Debug:ReportErrors()
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
  Enum.SelfVendorMode.AUGMENT_RUNES,
  Enum.SelfVendorMode.VANTUS_RUNE,
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
    if mode == Enum.SelfVendorMode.AUGMENT_RUNES then
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
      name = "Enable Addon",
      desc = "Fully enables/disables the entire addon",
      type = "toggle",
      width = "full",
      get = function() return Self:IsEnabled() end,
      set = function() if Self:IsEnabled() then Self:Disable() else Self:Enable() end end,
      order = 0 -- first
    },
    inventory = {
      type = "group",
      name = "Inventory",
      desc = "Small quality-of-life features.",
      order = 5,
      args = {
        autoSellGreyItems = {
          name = "Auto Sell Grey Items",
          desc = "Automatically sell grey-quality items when visiting a merchant.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.inventory.autoSellGreyItems end,
          set = function(_, value) db.profile.inventory.autoSellGreyItems = value end,
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
              get = function() return db.profile.inventory.autoRepair end,
              set = function(_, value) db.profile.inventory.autoRepair = value end,
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
              get = function() return db.profile.inventory.autoRepairMode end,
              set = function(_, value) db.profile.inventory.autoRepairMode = value end,
              disabled = function() return not db.profile.inventory.autoRepair end,
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
    controls = {
      type = "group",
      name = "Controls",
      desc = "Camera behavior and keybinding options.",
      order = 5.2,
      args = {
        openKeybindings = {
          name = "Open Keybindings",
          desc = "Open the Blizzard Key Bindings menu, expanded to the SlackHacks section.",
          descStyle = "inline",
          type = "execute",
          func = function() openKeybindings() end,
          order = 0
        },
        maximumCameraZoom = {
          name = "Maximum Camera Zoom",
          desc = "Allow the camera to zoom out to its maximum distance.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.controls.maximumCameraZoom end,
          set = function(_, value)
            db.profile.controls.maximumCameraZoom = value
            Self.Controls:ApplyAll()
          end,
          order = 1
        },
        enableDynamicCamera = {
          name = "Enable Dynamic Camera (Basic Mode)",
          desc = "Causes the camera to shift in view for more visibility. Try it out!",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.controls.enableDynamicCamera end,
          set = function(_, value)
            db.profile.controls.enableDynamicCamera = value
            Self.Controls:ApplyAll()
          end,
          order = 2
        }
      }
    },
    debug = {
      type = "group",
      name = "Debug",
      desc = "Debugging, error logging, and reporting options.",
      order = 2,
      args = {
        errorReportingGroup = {
          type = "group",
          name = "Error Logging and Reporting",
          desc = "Captures and reports errors that occur within SlackHacks.",
          inline = true,
          order = 1,
          args = {
            logErrors = {
              name = "Log Errors",
              desc = "Captures errors that occur specifically within SlackHacks (not other addons), with timestamps, " ..
                "character names, and de-duplicated by message. Works independently of Debug Mode. " ..
                "BugSack and BugGrabber continue capturing all errors normally.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.global.logs and db.global.logs.errorLoggingEnabled end,
              set = function(_, value)
                if not db.global.logs then db.global.logs = { debug = {}, error = {} } end
                db.global.logs.errorLoggingEnabled = value
              end,
              order = 1
            },
            showReportErrorLog = {
              name = "Report Errors",
              desc = "Opens a window displaying all errors formatted in GitHub-compatible Markdown, provides a direct issue link, and attempts to report pending logs directly to Slack.",
              type = "execute",
              func = function() Self.Debug:ReportErrors() end,
              order = 2
            },
            clearErrorLog = {
              name = "Clear Error Log",
              desc = "Clear all SlackHacks error logs stored in SlackHacksDB.",
              type = "execute",
              func = function()
                clearErrorLogs()
                print("SlackHacks: error logs cleared")
              end,
              confirm = true,
              order = 3
            }
          }
        },
        debugModeGroup = {
          type = "group",
          name = "Debug Mode",
          desc = "Debug logging and verbose output options.",
          inline = true,
          order = 2,
          args = {
            debugLogging = {
              name = "Debug Logging",
              desc = "Prints debug information to the chat window and logs to DB for later analysis.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.global.logs and db.global.logs.isDebugging end,
              set = function()
                if not db.global.logs then db.global.logs = { debug = {}, error = {} } end
                db.global.logs.isDebugging = not db.global.logs.isDebugging
                if db.global.logs.isDebugging then
                  print("SlackHacks Debugging ON")
                else
                  print("SlackHacks Debugging OFF")
                end
                Self.Buffs:Refresh()
              end,
              order = 1
            },
            clearDebugLogs = {
              name = "Clear Debug Logs",
              desc = "Clear all debug logs stored in SlackHacksDB.",
              type = "execute",
              func = function()
                clearDebugLogs()
                print("SlackHacks: debug logs cleared")
              end,
              confirm = true,
              order = 2
            }
          }
        },
        logPurgeGroup = {
          type = "group",
          name = "Log Purging",
          desc = "Automatically remove old debug logs and error logs so SlackHacksDB doesn't grow unbounded.",
          inline = true,
          order = 3,
          args = {
            logPurgeEnabled = {
              name = "Automatically Purge Old Logs",
              desc = "Once per login, remove logged entries older than the configured number of hours.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.global.logs and db.global.logs.logPurgeEnabled end,
              set = function(_, value)
                if not db.global.logs then db.global.logs = { debug = {}, error = {} } end
                db.global.logs.logPurgeEnabled = value
              end,
              order = 1
            },
            logPurgeHours = {
              name = "Keep Logs For (Hours)",
              desc = "Number of hours to keep a log entry before it is eligible for automatic purging.",
              type = "input",
              width = "full",
              get = function() return tostring(db.global.logs and db.global.logs.logPurgeHours or 48) end,
              set = function(_, value)
                if not db.global.logs then db.global.logs = { debug = {}, error = {} } end
                db.global.logs.logPurgeHours = tonumber(value)
              end,
              validate = function(_, value)
                local hours = tonumber(value)
                return hours and hours >= LOG_PURGE_MIN_HOURS and hours <= LOG_PURGE_MAX_HOURS
              end,
              disabled = function() return not (db.global.logs and db.global.logs.logPurgeEnabled) end,
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
        showAllMinimapTracking = {
          name = "Show All Tracking Options",
          desc = "Show all minimap tracking options,\nincluding the option to turn off target tracking.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.minimap.enabled end,
          get = function() return db.profile.minimap.showAllMinimapTracking end,
          set = function(_, value)
            db.profile.minimap.showAllMinimapTracking = value
            Self.Minimap:Refresh()
          end,
          order = 0.2
        },
        showAddonIconsOnHover = {
          name = "Show Addon Icons on Hover Only",
          desc = "Only show addon minimap icons and the Addon Compartment when hovering over the minimap.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.minimap.enabled end,
          get = function() return db.profile.minimap.showAddonIconsOnHover end,
          set = function(_, value)
            db.profile.minimap.showAddonIconsOnHover = value
            Self.Minimap:Refresh()
          end,
          order = 1
        },
        addonsInCompartment = {
          name = "Move Addon Icons to Addon Compartment",
          desc = "Move third-party addon icons into the Addon Compartment menu instead of showing them on the minimap.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.minimap.enabled end,
          get = function() return db.profile.minimap.addonsInCompartment end,
          set = function(_, value)
            db.profile.minimap.addonsInCompartment = value
            Self.Minimap:Refresh()
          end,
          order = 2
        },
        hideDiel = {
          name = "Hide Day/Night Icon",
          desc = [[Hide the big useless day/night (diel) icon (Classic/Forever).]],
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.minimap.enabled end,
          get = function() return db.profile.minimap.hideDiel end,
          set = function(_, value)
            db.profile.minimap.hideDiel = value
            Self.Minimap:Refresh()
          end,
          hidden = function() return isRetail() end,
          order = 3
        },
        opacityGroup = {
          type = "group",
          name = "Opacity",
          inline = true,
          disabled = function() return not db.profile.minimap.enabled end,
          order = 5,
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
        squareGroup = {
          type = "group",
          name = "Square Minimap",
          inline = true,
          disabled = function() return not db.profile.minimap.enabled end,
          order = 6,
          args = {
            enableSquare = {
              name = "Enable",
              desc = "Enable square minimap shape with title bar.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.minimap.shape == "square" end,
              set = function(_, value)
                db.profile.minimap.shape = value and "square" or "circle"
                Self.Minimap:Refresh()
              end,
              order = 1
            },
            showIconsOnHover = {
              name = "Show Blizzard Icons On Hover",
              desc = "Only show standard minimap icons (Calendar, Tracking, etc.) when hovering over the minimap.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showIconsOnHover end,
              set = function(_, value)
                db.profile.minimap.showIconsOnHover = value
                Self.Minimap:Refresh()
              end,
              order = 2
            },
            showZoneText = {
              name = "Show Zone Text",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showZoneText end,
              set = function(_, value)
                db.profile.minimap.showZoneText = value
                Self.Minimap:Refresh()
              end,
              order = 3
            },
            showClock = {
              name = "Show Clock",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showClock end,
              set = function(_, value)
                db.profile.minimap.showClock = value
                Self.Minimap:Refresh()
              end,
              order = 4
            },
            showTracking = {
              name = "Show Tracking",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showTracking end,
              set = function(_, value)
                db.profile.minimap.showTracking = value
                Self.Minimap:Refresh()
              end,
              order = 5
            },
            showCalendar = {
              name = "Show Calendar",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showCalendar end,
              set = function(_, value)
                db.profile.minimap.showCalendar = value
                Self.Minimap:Refresh()
              end,
              order = 6
            },
            showInstanceDifficulty = {
              name = "Show Instance Difficulty",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showInstanceDifficulty end,
              set = function(_, value)
                db.profile.minimap.showInstanceDifficulty = value
                Self.Minimap:Refresh()
              end,
              order = 8
            },
            showGarrison = {
              name = "Show Garrison/Expansion Landing Page",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showGarrison end,
              set = function(_, value)
                db.profile.minimap.showGarrison = value
                Self.Minimap:Refresh()
              end,
              order = 9
            },
            showAddonCompartment = {
              name = "Show Addon Compartment",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showAddonCompartment end,
              set = function(_, value)
                db.profile.minimap.showAddonCompartment = value
                Self.Minimap:Refresh()
              end,
              order = 10
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
    movableWindows = {
      type = "group",
      name = "Movable Windows",
      desc = "Drag most Blizzard windows by their title bar to reposition them, and resize them with the mouse wheel.",
      order = 9,
      args = {
        enabled = {
          name = "Enable",
          desc = "Make registered Blizzard windows draggable and mouse-wheel scalable.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.movableWindows.enabled end,
          set = function(_, value) Self.MovableWindows:SetEnabled(value) end,
          order = 0
        },
        keybindHint = {
          name = "Set a keybinding for \"Toggle Movable Windows\" under Key Bindings > SlackHacks to quickly enable/disable this without opening options.",
          type = "description",
          order = 0.1
        },
        modifierKey = {
          name = "Move Modifier Key",
          desc = "Key that must be held while left-click-dragging a window's title bar to move it (dragging elsewhere on the window does nothing). Choose None to allow moving with a plain left-click-drag.",
          type = "select",
          width = "full",
          values = {
            NONE = "None",
            SHIFT = "Shift",
            CTRL = "Ctrl",
            ALT = "Alt"
          },
          sorting = { "NONE", "SHIFT", "CTRL", "ALT" },
          get = function() return db.profile.movableWindows.modifierKey end,
          set = function(_, value) db.profile.movableWindows.modifierKey = value end,
          disabled = function() return not db.profile.movableWindows.enabled end,
          order = 1
        },
        enableScaling = {
          name = "Enable Scaling (Modifier + Mouse Wheel)",
          desc = "Hold the modifier key below and scroll the mouse wheel over a window's title bar to resize it (scrolling elsewhere on the window is left alone).",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.movableWindows.enableScaling end,
          set = function(_, value) db.profile.movableWindows.enableScaling = value end,
          disabled = function() return not db.profile.movableWindows.enabled end,
          order = 2
        },
        scaleModifierKey = {
          name = "Scale Modifier Key",
          desc = "Key that must be held while scrolling the mouse wheel over a window's title bar to resize it. Choose None to allow resizing with a plain mouse wheel scroll.",
          type = "select",
          width = "full",
          values = {
            NONE = "None",
            SHIFT = "Shift",
            CTRL = "Ctrl",
            ALT = "Alt"
          },
          sorting = { "NONE", "SHIFT", "CTRL", "ALT" },
          get = function() return db.profile.movableWindows.scaleModifierKey end,
          set = function(_, value) db.profile.movableWindows.scaleModifierKey = value end,
          disabled = function() return not db.profile.movableWindows.enabled or not db.profile.movableWindows.enableScaling end,
          order = 2.5
        },
        savePositionStrategy = {
          name = "Remember Positions",
          desc =
            "Do Not Remember >> positions reset when you close and reopen a window\n\n" ..
            "In Session >> positions are kept until you reload your UI\n\n" ..
            "Remember Permanently >> positions are kept until reset or changed again",
          type = "select",
          width = 1.5,
          values = {
            off = "Do Not Remember",
            session = "In Session, Until Reload",
            permanent = "Remember Permanently"
          },
          sorting = { "off", "session", "permanent" },
          get = function() return db.profile.movableWindows.savePositionStrategy end,
          set = function(_, value) db.profile.movableWindows.savePositionStrategy = value end,
          disabled = function() return not db.profile.movableWindows.enabled end,
          order = 3
        },
        saveScaleStrategy = {
          name = "Remember Scales",
          desc =
            "In Session >> scales are kept until you reload your UI\n\n" ..
            "Remember Permanently >> scales are kept until reset or changed again",
          type = "select",
          width = 1.5,
          values = {
            session = "In Session, Until Reload",
            permanent = "Remember Permanently"
          },
          sorting = { "session", "permanent" },
          get = function() return db.profile.movableWindows.saveScaleStrategy end,
          set = function(_, value) db.profile.movableWindows.saveScaleStrategy = value end,
          disabled = function() return not db.profile.movableWindows.enabled end,
          order = 4
        },
        resetPositions = {
          name = "Reset Remembered Positions",
          desc = "Clear all permanently remembered window positions. Reloads your UI.",
          type = "execute",
          width = 1.5,
          func = function()
            Self.MovableWindows:ResetPositions()
            ReloadUI()
          end,
          confirm = function() return "Are you sure you want to reset all remembered window positions? This will reload the UI." end,
          disabled = function() return not db.profile.movableWindows.enabled end,
          order = 5
        },
        resetScales = {
          name = "Reset Remembered Scales",
          desc = "Clear all permanently remembered window scales. Reloads your UI.",
          type = "execute",
          width = 1.5,
          func = function()
            Self.MovableWindows:ResetScales()
            ReloadUI()
          end,
          confirm = function() return "Are you sure you want to reset all remembered window scales? This will reload the UI." end,
          disabled = function() return not db.profile.movableWindows.enabled end,
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

-- Registers the AceConfig options table above and the Blizzard options panel entry.
-- Called from OnInitialize, after all addon files/modules have loaded.
function registerOptions()
  options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(Self.db)
  options.args.profiles.order = 1
  migrateConfig()
  local customConfig = CustomConfigs and CustomConfigs[getBattletag()]
  if customConfig and customConfig.setOptions then
    customConfig.setOptions()
  end
  config:RegisterOptionsTable("SlackHacks", options)
  Self.configDialog, Self.configCategoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SlackHacks", icon(16) .. " SlackHacks")
end

