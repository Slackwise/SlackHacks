local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

dbDefaults = {
  global = {
    configVersion = CONFIG_VERSION,
    logs = {
      debug = {},
      error = {},
      isDebugging = false,
      errorLoggingEnabled = false,
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
      autoRepairMode = "personal",
      hideBagsFrame = false
    },
    listviewBag = {
      enabled = false,
      showListviewBag = false,
      columnOrder = { "quantity", "name", "ilvl", "armorType", "armorSlot", "bind" },
      protectedItems = {},
      trashItems = {},
      autoSellMarkedItems = false,
      point = nil
    },
    controls = {
      maximumCameraZoom = false,
      enableDynamicCamera = false
    },
    graphics = {
      enabled = false,
      enableGroundEffectDensity = false,
      groundEffectDensity = 16,
      enableGroundEffectFade = false,
      groundEffectFade = 70,
      enableGroundEffectDist = false,
      groundEffectDist = 70,
      enableLodObjectFadeScale = false,
      lodObjectFadeScale = 100,
      enableLodObjectCullSize = false,
      lodObjectCullSize = 15,
      enableTerrainLodDist = false,
      terrainLodDist = 400,
      resampleAlwaysSharpen = false,
      enableReflectionMode = false,
      reflectionMode = 0,
      enableWeatherDensity = false,
      weatherDensity = 2
    },
    mouseRing = {
      enabled = false,
      showOutOfCombat = false,
      scale = 50,
      opacity = 100,
      color = { r = 1, g = 1, b = 1 }
    },
    combat = {
      raiseCastingNameplates = false,
      paladin = {
        trackHolyShockCharges = false,
        onlyInCombat = false,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0
      }
    },
    movableWindows = {
      enabled = false,
      moveToasts = false, -- adds Blizzard's toast popups (loot, mounts, achievements, etc.) as a draggable box in the real Edit Mode
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
      showExpansionLandingPage = true,
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
      lastUsedItems = {},
      contentTypes = {
        mythicDungeons = true,
        nonLfrRaids = true
      },
      categories = {
        food = true,
        flask = true,
        oil = true,
        rune = false
      }
    },
    selfVendor = {
      enabled = false,
      source = "icyveins",
      requirePrefix = false,
      chatPrefix = "!",
      modes = {
        [Enum.SelfVendorMode.CONSUMABLES] = { enabled = false },
        [Enum.SelfVendorMode.FLASK] = { enabled = false },
        [Enum.SelfVendorMode.OIL] = { enabled = false },
        [Enum.SelfVendorMode.AUGMENT_RUNES] = { enabled = false, runeQuantity = 5 },
        [Enum.SelfVendorMode.AUGMENTS] = { enabled = false },
        [Enum.SelfVendorMode.VANTUS_RUNE] = { enabled = false },
      }
    },
    weeklies = {
      enabled = false,
      trackDelves = false
    },
    infoDisplay = {
      enabled = false,
      charSheet = {
        itemLevel = true,
        upgradeTrack = true,
        maxUpgradeStar = false,
        slotWatermark = true,
        secondaryStats = true,
        tertiaryStats = false,
        itemStats = true,
        highWatermarkColoring = true,
        enchants = true,
        gemSockets = true,
      }
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

WIP_MODULES = {
  {
    key = "buffs",
    name = "Consumable Buff Reminders",
    disable = function()
      if Self.db and Self.db.profile and Self.db.profile.buffs then
        Self.db.profile.buffs.enabled = false
      end
      if Self.Buffs and Self.Buffs.Refresh then
        Self.Buffs:Refresh()
      end
    end
  },
  {
    key = "combat",
    name = "Combat",
    disable = function()
      if Self.db and Self.db.profile and Self.db.profile.combat then
        Self.db.profile.combat.raiseCastingNameplates = false
        if Self.db.profile.combat.paladin then
          Self.db.profile.combat.paladin.trackHolyShockCharges = false
        end
      end
      resetNameplateCastLift()
      if Self.ChargeTracking and Self.ChargeTracking.Refresh then
        Self.ChargeTracking:Refresh()
      end
    end
  },
  {
    -- Nested under the "Inventory" group instead of a top-level options.args entry.
    key = { "inventory", "listviewBag" },
    name = "Listview Bag",
    disable = function()
      if Self.db and Self.db.profile and Self.db.profile.listviewBag then
        Self.db.profile.listviewBag.enabled = false
      end
      if Self.ListviewBag then
        Self.ListviewBag:Disable()
      end
    end
  }
}

RETAIL_MODULES = {
  { key = "buffs", name = "Consumable Buff Reminders" },
  { key = { "combat", "paladin" }, name = "Paladin" },
  { key = "vendor", name = "Self Vendor" },
  { key = "weeklies", name = "Weeklies" },
}

-- mod.key is a plain string for a top-level options.args entry, or a table of keys to walk through
-- nested .args groups (e.g. {"inventory", "listviewBag"} ).
local function resolveOptionGroup(key)
  if type(key) == "string" then
    return options and options.args and options.args[key]
  end
  local group = options and options.args and options.args[key[1]]
  for i = 2, #key do
    group = group and group.args and group.args[key[i]]
  end
  return group
end

local function applyWIPOptionsDecoration()
  for _, mod in ipairs(WIP_MODULES) do
    local group = resolveOptionGroup(mod.key)
    if group then
      if not group.name:find("%(WIP%)") then
        group.name = "(WIP) " .. group.name
      end
      local originalDesc = group.desc or ""
      if not originalDesc:find("%[Work in Progress%]") then
        group.desc = "|cffff8000[Work in Progress]|r " .. originalDesc
      end
      group.icon = 134070
      if group.args then
        -- In AceConfigDialog, negative orders sort AFTER positive orders (designed for bottom/footer buttons).
        -- To put something at the very top, order must be >= 0 and smaller than any positive order.
        -- Shift all existing non-negative args up by 1, and set wipWarning order = 0.
        for key, arg in pairs(group.args) do
          if key ~= "wipWarning" and type(arg) == "table" and type(arg.order) == "number" and arg.order >= 0 then
            arg.order = arg.order + 1
          end
        end

        group.args.wipWarning = {
          name = "|cffff8000Warning:|r This module is a work in progress and currently experimental. Use |cffffffff/slack wipoff|r to disable all WIP modules.",
          type = "description",
          order = 0
        }
      end
    end
  end
end

local function hideNonRetailOptions()
  for _, mod in ipairs(RETAIL_MODULES) do
    local group = resolveOptionGroup(mod.key)
    if group then
      group.hidden = function() return not isRetail() end
    end
  end
end

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

local function getWIPModuleNames()
  local names = {}
  for _, mod in ipairs(WIP_MODULES) do
    table.insert(names, mod.name)
  end
  return table.concat(names, ", ")
end

local function printSlashHelp()
  print(grey(icon(16)) .. " " .. color("FFD100")("SlackHacks Slash Commands:") .. "")
  print("  " .. color("FFFFFF")("/slack") .. " - Open the SlackHacks config window")
  print("  " .. color("FFFFFF")("/slack help") .. " - Show this list of slash commands")
  print("  " .. color("FFFFFF")("/slack debug") .. " - Toggle debug mode on/off")
  print("  " .. color("FFFFFF")("/slack bugs") .. " - View and report error logs")
  print("  " .. color("FFFFFF")("/slack reset") .. " - Reset profile and addon state to defaults")
  print("  " .. color("FFFFFF")("/slack wipoff") .. " - Disable work-in-progress modules (" .. getWIPModuleNames() .. ")")
end

function disableWIPModules()
  if not Self.db or not Self.db.profile then return end

  for _, mod in ipairs(WIP_MODULES) do
    if mod.disable then
      -- pcall'd so one module erroring out can't abort the loop and leave the remaining WIP
      -- modules (and the options UI refresh below) never touched.
      local ok, err = pcall(mod.disable)
      if not ok then
        geterrorhandler()(("SlackHacks: error disabling WIP module '%s': %s"):format(mod.name, tostring(err)))
      end
    end
  end

  local acr = LibStub("AceConfigRegistry-3.0", true)
  if acr then
    acr:NotifyChange("SlackHacks")
  end

  print("SlackHacks: disabled all WIP modules (" .. getWIPModuleNames() .. ").")
end

function handleSlashCommand(input)
  local command = strlower(strtrim(input or ""))
  if command == "" then
    openOptions()
  elseif command == "help" then
    printSlashHelp()
  elseif command == "debug" then
    toggleDebugging()
  elseif command == "bugs" then
    Self.Debug:ReportErrors()
  elseif command == "reset" then
    promptResetProfile()
  elseif command == "wipoff" then
    disableWIPModules()
  elseif command == "induce-error" then
    Self.Debug:InduceError()
  else
    print("SlackHacks: unknown command '" .. command .. "'. Type " .. color("FFFFFF")("/slack help") .. " for available commands.")
  end
end

local selfVendorModeSorting = {
  Enum.SelfVendorMode.FLASK,
  Enum.SelfVendorMode.OIL,
  Enum.SelfVendorMode.AUGMENT_RUNES,
  Enum.SelfVendorMode.VANTUS_RUNE,
  Enum.SelfVendorMode.CONSUMABLES,
  Enum.SelfVendorMode.AUGMENTS,
}

local function listviewVendorItemValues()
  local values = {}
  for key, item in pairs(db.profile.listviewBag.trashItems or {}) do
    if type(item) == "table" then
      local suffix = "Quality " .. tostring(item.quality or 0) .. ", iLvl " .. tostring(item.itemLevel or 0)
      if item.upgradeTrack and item.upgradeTrack ~= "" then
        suffix = suffix .. ", " .. item.upgradeTrack
      end
      values[key] = (item.name or "Unknown item") .. " (" .. suffix .. ")"
    else
      values[key] = tostring(key)
    end
  end
  return values
end

local function selfVendorModeOptions()
  local args = {}
  args.requestDescription = {
    type = "description",
    name = "|cffffd100Let group members request buff items by saying phrases like 'crit oil rune' to be auto-traded a crit flask, oil, and x runes from your inventory. Any combination of the below selected enabled options will work.|r",
    fontSize = "medium",
    width = "full",
    order = 0,
  }
  args.enabled = {
    name = "Enable Self Vendor Module",
    desc = "Accept Self Vendor requests in party, raid, and instance chat. Requests may also include 'and', 'give', 'need', or 'please'.",
    type = "toggle",
    descStyle = "inline",
    width = "full",
    get = function() return db.profile.selfVendor.enabled end,
    set = function(_, value) Self.SelfVendor:SetEnabled(value) end,
    order = 2,
  }
  args.source = {
    name = "Flask and Augments Source",
    desc = "Select Wowhead or Icy Veins for optimal flask selection and Augments recommendations.",
    type = "select",
    values = { wowhead = "Wowhead", icyveins = "Icy Veins" },
    get = function() return db.profile.selfVendor.source end,
    set = function(_, value) Self.SelfVendor:SetSource(value) end,
    order = 5,
  }
  args.requirePrefix = {
    name = "Require Chat Prefix",
    desc = "Only process requests that begin with the configured prefix.",
    type = "toggle",
    descStyle = "inline",
    width = "full",
    get = function() return db.profile.selfVendor.requirePrefix end,
    set = function(_, value) db.profile.selfVendor.requirePrefix = value end,
    order = 3,
  }
  args.chatPrefix = {
    name = "Chat Prefix",
    type = "input",
    get = function() return db.profile.selfVendor.chatPrefix end,
    set = function(_, value) db.profile.selfVendor.chatPrefix = value end,
    validate = function(_, value) return #value > 0 and not value:find("%s") end,
    disabled = function() return not db.profile.selfVendor.requirePrefix end,
    order = 4,
  }
  for order, mode in ipairs(selfVendorModeSorting) do
    local configuredMode = mode
    local details = SELF_VENDOR_MODES[mode]
    args[details.key] = {
      type = "toggle",
      name = details.name,
      desc = details.description,
      descStyle = "inline",
      width = "full",
      get = function() return db.profile.selfVendor.modes[configuredMode].enabled end,
      set = function(_, value) Self.SelfVendor:SetModeEnabled(configuredMode, value) end,
      order = order + 5,
    }
    if mode == Enum.SelfVendorMode.AUGMENT_RUNES then
      args.runeQuantity = {
        name = "Augment Rune Stack Size",
        type = "input",
        width = 0.7,
        get = function() return tostring(db.profile.selfVendor.modes[configuredMode].runeQuantity) end,
        set = function(_, value) Self.SelfVendor:SetRuneQuantity(value) end,
        validate = function(_, value) return tonumber(value) and tonumber(value) >= 1 and tonumber(value) <= 100 end,
        order = order + 5.5,
      }
    end
  end
  return args
end

local function goldModuleOverview(text)
  return {
    type = "description",
    name = "|cffffd100" .. text .. "|r",
    fontSize = "medium",
    width = "full",
    order = 0,
  }
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
        overview = goldModuleOverview("Small quality-of-life features for managing your inventory."),
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
        },
        hideBagsFrame = {
          name = "Hide Bags Frame",
          desc = "Hides the Blizzard Backpack and Bag icons/frame. " ..
            "(Useful if you only use keyboard shortcuts to open your bags.)",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.inventory.hideBagsFrame end,
          set = function(_, value)
            db.profile.inventory.hideBagsFrame = value
            applyHideBagsFrame()
          end,
          order = 4.5
        },
        listviewBag = {
          type = "group",
          name = "Listview Bag",
          desc = "A sortable list-view alternative to the default grid bag window.",
          order = 5,
          args = {
            overview = goldModuleOverview("A sortable list-view alternative to the default grid bag window."),
            enabled = {
              name = "Enable Listview Bag Module",
              desc = "Enables Listview Bag features and adds its option to the Blizzard backpack menu.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.listviewBag.enabled end,
              set = function(_, value)
                db.profile.listviewBag.enabled = value
                if value then
                  Self.ListviewBag:Enable()
                else
                  Self.ListviewBag:Disable()
                end
              end,
              order = 1
            },
            showListviewBag = {
              name = "Switch Backpack with Listview Bag",
              desc = "Use Listview Bag instead of Blizzard's grid bags when opening the backpack. Turn this off to return to the standard bags.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.listviewBag.showListviewBag end,
              set = function(_, value)
                db.profile.listviewBag.showListviewBag = value
                Self.ListviewBag:SetShowListviewBag(value)
              end,
              disabled = function() return not db.profile.listviewBag.enabled end,
              order = 2
            },
            autoSellMarkedItems = {
              name = "Auto-Sell Items Marked for Vendoring",
              desc = "Sell marked items automatically when opening a merchant. Otherwise, they sell when you " ..
                "confirm Blizzard's Sell All Junk action.",
              type = "toggle",
              get = function() return db.profile.listviewBag.autoSellMarkedItems end,
              set = function(_, value) db.profile.listviewBag.autoSellMarkedItems = value end,
              width = "full",
              order = 3
            },
            autoVendorItems = {
              name = "Auto-Vendor Items",
              desc = "Uncheck an item to remove it from the auto-vendor list.",
              type = "multiselect",
              values = listviewVendorItemValues,
              get = function(_, key) return db.profile.listviewBag.trashItems[key] ~= nil end,
              set = function(_, key, value)
                if not value then
                  db.profile.listviewBag.trashItems[key] = nil
                  if Self.ListviewBag then
                    Self.ListviewBag:Refresh()
                  end
                end
              end,
              width = "full",
              order = 4
            }
          }
        }
      }
    },
    controls = {
      type = "group",
      name = "Controls",
      desc = "Camera behavior and keybinding options.",
      order = 5.2,
      args = {
        overview = goldModuleOverview("Camera behavior and keybinding options."),
        openKeybindings = {
          name = "Open Keybindings",
          desc = "Open the Blizzard Key Bindings menu, expanded to the SlackHacks section.",
          descStyle = "inline",
          type = "execute",
          func = function() openKeybindings() end,
          order = 0.1
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
    graphics = {
      type = "group",
      name = "Graphics",
      order = 5.4,
      args = {
        overview = {
          type = "description",
          name = "|cffffd100Tweak hidden client CVars to push draw distances, foliage density, and visual clarity beyond standard in-game options. Each option can be individually enabled or unset back to game defaults.|r",
          fontSize = "medium",
          width = "full",
          order = 0
        },
        enabled = {
          name = "Enable Graphics Module",
          desc = "Enable custom hidden graphical options. When disabled, standard game defaults are restored.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.graphics.enabled end,
          set = function(_, value) Self.Graphics:SetEnabled(value) end,
          order = 0.1
        },
        resetToDefaults = {
          name = "Reset to Defaults",
          desc = "Disables all overrides and resets all graphics options back to standard game defaults.",
          type = "execute",
          disabled = function() return not db.profile.graphics.enabled end,
          func = function() Self.Graphics:ResetToDefaults() end,
          order = 0.6
        },
        groundEffectDensityGroup = {
          type = "group",
          name = "Ground Effect Density",
          inline = true,
          order = 1,
          args = {
            enableGroundEffectDensity = {
              name = "Override Ground Effect Density",
              desc = "Enable custom override for ground foliage density. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableGroundEffectDensity end,
              set = function(_, value)
                db.profile.graphics.enableGroundEffectDensity = value
                Self.Graphics:Apply("groundEffectDensity")
              end,
              order = 1
            },
            groundEffectDensity = {
              name = "Density",
              desc = "Controls the density of ground foliage and clutter, such as grass, flowers, ferns, and small rocks.",
              type = "range",
              min = 16,
              max = 256,
              step = 1,
              bigStep = 16,
              width = "full",
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableGroundEffectDensity
              end,
              get = function() return db.profile.graphics.groundEffectDensity end,
              set = function(_, value)
                db.profile.graphics.groundEffectDensity = value
                Self.Graphics:Apply("groundEffectDensity")
              end,
              order = 2
            },
            groundEffectDensityDesc = {
              name = "|cff808080Controls density of ground clutter (grass, flowers, ferns, rocks). (CVar: groundEffectDensity | Default: 16 | Max: 256)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        },
        groundEffectFadeGroup = {
          type = "group",
          name = "Ground Effect Fade Distance",
          inline = true,
          order = 2,
          args = {
            enableGroundEffectFade = {
              name = "Override Ground Effect Fade Distance",
              desc = "Enable custom override for ground clutter fade distance. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableGroundEffectFade end,
              set = function(_, value)
                db.profile.graphics.enableGroundEffectFade = value
                Self.Graphics:Apply("groundEffectFade")
              end,
              order = 1
            },
            groundEffectFade = {
              name = "Fade Distance",
              desc = "Controls the distance from the player at which ground clutter begins to fade into the distance.",
              type = "range",
              min = 50,
              max = 370,
              step = 1,
              bigStep = 10,
              width = "full",
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableGroundEffectFade
              end,
              get = function() return db.profile.graphics.groundEffectFade end,
              set = function(_, value)
                db.profile.graphics.groundEffectFade = value
                Self.Graphics:Apply("groundEffectFade")
              end,
              order = 2
            },
            groundEffectFadeDesc = {
              name = "|cff808080Controls the distance at which ground clutter begins fading into the background. (CVar: groundEffectFade | Default: 70 | Max: 370)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        },
        groundEffectDistGroup = {
          type = "group",
          name = "Ground Effect Render Distance",
          inline = true,
          order = 3,
          args = {
            enableGroundEffectDist = {
              name = "Override Ground Effect Render Distance",
              desc = "Enable custom override for ground clutter maximum draw distance. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableGroundEffectDist end,
              set = function(_, value)
                db.profile.graphics.enableGroundEffectDist = value
                Self.Graphics:Apply("groundEffectDist")
              end,
              order = 1
            },
            groundEffectDist = {
              name = "Render Distance",
              desc = "Controls the maximum draw distance at which ground clutter (grass, plants, rocks) is rendered.",
              type = "range",
              min = 40,
              max = 500,
              step = 1,
              bigStep = 10,
              width = "full",
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableGroundEffectDist
              end,
              get = function() return db.profile.graphics.groundEffectDist end,
              set = function(_, value)
                db.profile.graphics.groundEffectDist = value
                Self.Graphics:Apply("groundEffectDist")
              end,
              order = 2
            },
            groundEffectDistDesc = {
              name = "|cff808080Controls the maximum draw distance for ground clutter to minimize pop-in. (CVar: groundEffectDist | Default: 70 | Max: 500)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        },
        lodObjectFadeScaleGroup = {
          type = "group",
          name = "LoD Object Fade Scale",
          inline = true,
          order = 4,
          args = {
            enableLodObjectFadeScale = {
              name = "Override LoD Object Fade Scale",
              desc = "Enable custom override for level of detail (LoD) object fade scale. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableLodObjectFadeScale end,
              set = function(_, value)
                db.profile.graphics.enableLodObjectFadeScale = value
                Self.Graphics:Apply("lodObjectFadeScale")
              end,
              order = 1
            },
            lodObjectFadeScale = {
              name = "Fade Scale (%)",
              desc = "Scales the fade distance for level of detail (LoD) objects and doodads. Higher values keep distant structures and objects visible further away.",
              type = "range",
              min = 50,
              max = 200,
              step = 1,
              bigStep = 5,
              width = "full",
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableLodObjectFadeScale
              end,
              get = function() return db.profile.graphics.lodObjectFadeScale end,
              set = function(_, value)
                db.profile.graphics.lodObjectFadeScale = value
                Self.Graphics:Apply("lodObjectFadeScale")
              end,
              order = 2
            },
            lodObjectFadeScaleDesc = {
              name = "|cff808080Scales the distance over which level of detail (LoD) objects fade out (50% - 200%). (CVar: lodObjectFadeScale | Default: 100 | Max: 200)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        },
        lodObjectCullSizeGroup = {
          type = "group",
          name = "LoD Object Cull Size",
          inline = true,
          order = 5,
          args = {
            enableLodObjectCullSize = {
              name = "Override LoD Object Cull Size",
              desc = "Enable custom override for level of detail (LoD) object culling size. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableLodObjectCullSize end,
              set = function(_, value)
                db.profile.graphics.enableLodObjectCullSize = value
                Self.Graphics:Apply("lodObjectCullSize")
              end,
              order = 1
            },
            lodObjectCullSize = {
              name = "Cull Pixel Size",
              desc = "Screen-space pixel size threshold below which small objects and doodads are culled (not drawn). Lower values force smaller and more distant objects to render.",
              type = "range",
              min = 1,
              max = 35,
              step = 1,
              width = "full",
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableLodObjectCullSize
              end,
              get = function() return db.profile.graphics.lodObjectCullSize end,
              set = function(_, value)
                db.profile.graphics.lodObjectCullSize = value
                Self.Graphics:Apply("lodObjectCullSize")
              end,
              order = 2
            },
            lodObjectCullSizeDesc = {
              name = "|cff808080Pixel size threshold below which small objects are culled. Lower values render smaller/distant doodads. (CVar: lodObjectCullSize | Default: 15 | Min: 1)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        },
        terrainLodDistGroup = {
          type = "group",
          name = "Terrain LoD Distance",
          inline = true,
          order = 6,
          args = {
            enableTerrainLodDist = {
              name = "Override Terrain LoD Distance",
              desc = "Enable custom override for terrain level of detail distance. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableTerrainLodDist end,
              set = function(_, value)
                db.profile.graphics.enableTerrainLodDist = value
                Self.Graphics:Apply("terrainLodDist")
              end,
              order = 1
            },
            terrainLodDist = {
              name = "Terrain LoD Distance",
              desc = "Controls the draw distance for high-detail terrain mesh geometry, reducing visible terrain morphing and popping in the distance.",
              type = "range",
              min = 200,
              max = 1000,
              step = 10,
              bigStep = 50,
              width = "full",
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableTerrainLodDist
              end,
              get = function() return db.profile.graphics.terrainLodDist end,
              set = function(_, value)
                db.profile.graphics.terrainLodDist = value
                Self.Graphics:Apply("terrainLodDist")
              end,
              order = 2
            },
            terrainLodDistDesc = {
              name = "|cff808080Controls the draw distance for high-detail terrain meshes, preventing terrain geometry popping. (CVar: terrainLodDist | Default: 400 | Max: 1000)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        },
        resampleAlwaysSharpenGroup = {
          type = "group",
          name = "Resample Sharpening",
          inline = true,
          order = 7,
          args = {
            resampleAlwaysSharpen = {
              name = "Always Run Resample Sharpening",
              desc = "Runs the spatial sharpening filter pass (FSR / CAS) even when rendering at native resolution without upscaling, producing a sharper, clearer image. Uncheck to unset and restore default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.resampleAlwaysSharpen end,
              set = function(_, value)
                db.profile.graphics.resampleAlwaysSharpen = value
                Self.Graphics:Apply("resampleAlwaysSharpen")
              end,
              order = 1
            },
            resampleAlwaysSharpenDesc = {
              name = "|cff808080Runs sharpness pass even at native resolution. (CVar: ResampleAlwaysSharpen | Default: Off / 0 | Max: On / 1)|r",
              type = "description",
              width = "full",
              order = 2
            }
          }
        },
        reflectionModeGroup = {
          type = "group",
          name = "Water Reflection Mode",
          inline = true,
          order = 8,
          args = {
            enableReflectionMode = {
              name = "Override Water Reflection Mode",
              desc = "Enable custom override for water reflection quality. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableReflectionMode end,
              set = function(_, value)
                db.profile.graphics.enableReflectionMode = value
                Self.Graphics:Apply("reflectionMode")
              end,
              order = 1
            },
            reflectionMode = {
              name = "Mode",
              desc = "Controls water reflection detail (0: Disabled, 1: Terrain, 2: Terrain and objects, 3: Full reflections including player models, NPCs, and sky).",
              type = "select",
              width = "full",
              values = {
                [0] = "0 - Disabled",
                [1] = "1 - Terrain Only",
                [2] = "2 - Terrain & Objects",
                [3] = "3 - Full (All Entities & Sky)"
              },
              sorting = { 0, 1, 2, 3 },
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableReflectionMode
              end,
              get = function() return db.profile.graphics.reflectionMode end,
              set = function(_, value)
                db.profile.graphics.reflectionMode = value
                Self.Graphics:Apply("reflectionMode")
              end,
              order = 2
            },
            reflectionModeDesc = {
              name = "|cff808080Controls water reflection detail (0: Off, 1: Terrain, 2: Objects, 3: Full with entities & sky). (CVar: reflectionMode | Default: 0 | Max: 3)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        },
        weatherDensityGroup = {
          type = "group",
          name = "Weather Density",
          inline = true,
          order = 9,
          args = {
            enableWeatherDensity = {
              name = "Override Weather Density",
              desc = "Enable custom override for weather effect intensity. Uncheck to unset and restore game default.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.graphics.enabled end,
              get = function() return db.profile.graphics.enableWeatherDensity end,
              set = function(_, value)
                db.profile.graphics.enableWeatherDensity = value
                Self.Graphics:Apply("weatherDensity")
              end,
              order = 1
            },
            weatherDensity = {
              name = "Density",
              desc = "Controls the intensity and density of precipitation and weather effects such as rain, snow, and sandstorms (0: Off, 1: Light, 2: Medium, 3: Heavy / Maximum).",
              type = "range",
              min = 0,
              max = 3,
              step = 1,
              width = "full",
              disabled = function()
                return not db.profile.graphics.enabled or not db.profile.graphics.enableWeatherDensity
              end,
              get = function() return db.profile.graphics.weatherDensity end,
              set = function(_, value)
                db.profile.graphics.weatherDensity = value
                Self.Graphics:Apply("weatherDensity")
              end,
              order = 2
            },
            weatherDensityDesc = {
              name = "|cff808080Controls the intensity of weather effects like rain, snow, and storms (0: Off, 1: Light, 2: Medium, 3: Heavy). (CVar: weatherDensity | Default: 2 | Max: 3)|r",
              type = "description",
              width = "full",
              order = 3
            }
          }
        }
      }
    },
    mouseRing = {
      type = "group",
      name = "Mouse Ring",
      desc = "Shows a ring around your mouse cursor.",
      order = 6.5,
      args = {
        overview = goldModuleOverview("Shows a ring around your mouse cursor, with controls for when it appears and how it looks."),
        enabled = {
          name = "Enable Mouse Ring Module",
          desc = "Show a ring around your mouse cursor.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.mouseRing.enabled end,
          set = function(_, value) Self.MouseRing:SetEnabled(value) end,
          order = 0.1
        },
        showOutOfCombat = {
          name = "Show Out of Combat",
          desc = "Also show the ring while out of combat. When disabled, the ring only appears while you're " ..
            "in combat.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.mouseRing.enabled end,
          get = function() return db.profile.mouseRing.showOutOfCombat end,
          set = function(_, value)
            db.profile.mouseRing.showOutOfCombat = value
            Self.MouseRing:Refresh()
          end,
          order = 1
        },
        scale = {
          name = "Scale",
          desc = "Size of the ring as a percentage of its default size.",
          type = "range",
          min = 25,
          max = 100,
          step = 5,
          disabled = function() return not db.profile.mouseRing.enabled end,
          get = function() return db.profile.mouseRing.scale end,
          set = function(_, value)
            db.profile.mouseRing.scale = value
            Self.MouseRing:Refresh()
          end,
          order = 2
        },
        opacity = {
          name = "Opacity",
          desc = "Opacity of the ring.",
          type = "range",
          min = 0,
          max = 100,
          step = 1,
          disabled = function() return not db.profile.mouseRing.enabled end,
          get = function() return db.profile.mouseRing.opacity end,
          set = function(_, value)
            db.profile.mouseRing.opacity = value
            Self.MouseRing:Refresh()
          end,
          order = 3
        },
        color = {
          name = "Color",
          desc = "Color of the ring.",
          type = "color",
          hasAlpha = false,
          disabled = function() return not db.profile.mouseRing.enabled end,
          get = function()
            local color = db.profile.mouseRing.color
            return color.r, color.g, color.b
          end,
          set = function(_, r, g, b)
            db.profile.mouseRing.color.r = r
            db.profile.mouseRing.color.g = g
            db.profile.mouseRing.color.b = b
            Self.MouseRing:Refresh()
          end,
          order = 4
        }
      }
    },
    debug = {
      type = "group",
      name = "Debug",
      desc = "Debugging, error logging, and reporting options.",
      order = 2,
      args = {
        overview = goldModuleOverview("Configure error capture, debug output, reporting, and automatic log cleanup."),
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
                Self.Debug:SetErrorLoggingEnabled(value)
              end,
              order = 1
            },
            showReportErrorLog = {
              name = "Report Errors",
              desc = "Opens a window displaying all errors formatted in GitHub-compatible Markdown, provides a " ..
                "direct issue link, and attempts to report pending logs directly to Slack.",
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
                toggleDebugging()
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
      order = 98,
      args = {
        overview = goldModuleOverview("Combat-related features and class-specific trackers."),
        raiseCastingNameplates = {
          name = "Raise Casting Nameplates",
          desc = "Raise enemy nameplates while they are casting.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.combat.raiseCastingNameplates end,
          set = function(_, value)
            db.profile.combat.raiseCastingNameplates = value
            updateNameplateCastEventRegistration()
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
            overview = goldModuleOverview("Track Holy Shock charges and position the tracker in Edit Mode."),
            trackHolyShockCharges = {
              name = "Track Holy Shock Charges",
              desc = "Show a circular charge tracker for Holy Shock. Can be repositioned anywhere in Edit Mode.",
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
            onlyInCombat = {
              name = "Only Show in Combat",
              desc = "Only display the Holy Shock charge tracker while in combat.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.combat.paladin.onlyInCombat end,
              set = function(_, value)
                db.profile.combat.paladin.onlyInCombat = value
                Self.ChargeTracking:Refresh()
              end,
              disabled = function() return not db.profile.combat.paladin.trackHolyShockCharges end,
              order = 2
            },
            openEditMode = {
              name = "Position Charge Tracker via Edit Mode",
              desc = "Open Blizzard's Edit Mode to position the Holy Shock charge tracker.",
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
              disabled = function() return not db.profile.combat.paladin.trackHolyShockCharges end,
              order = 3
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
        overview = goldModuleOverview("Customize the minimap's shape, appearance, opacity, and visible buttons."),
        enabled = {
          name = "Enable Minimap Module",
          desc = "Enable minimap enhancements. When disabled, the minimap looks and behaves exactly like " ..
            "stock Blizzard UI.",
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
          order = 0.05
        },
        openEditMode = {
          name = "Open Visual Settings via Edit Mode",
          desc = "Open Blizzard's Edit Mode and select the Minimap to configure its visual settings and " ..
            "position/size.",
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
          desc = "Move third-party addon icons into the Addon Compartment menu instead of showing them on " ..
            "the minimap.",
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
            showExpansionLandingPage = {
              name = "Show Expansion Landing Page",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.minimap.enabled or db.profile.minimap.shape ~= "square" end,
              get = function() return db.profile.minimap.showExpansionLandingPage end,
              set = function(_, value)
                db.profile.minimap.showExpansionLandingPage = value
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
      order = 99,
      args = {
        overview = goldModuleOverview("Get clickable reminders for food, flask, oil, and augment rune buffs in Mythic dungeons and raids."),
        enabled = {
          name = "Enable Consumable Buff Reminders Module",
          desc = "Show consumable buff reminders.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.buffs.enabled end,
          set = function(_, value)
            db.profile.buffs.enabled = value
            Self.Buffs:Refresh()
          end,
          order = 0.05
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
              desc = "Show reminders when a timed buff will expire before the Mythic dungeon timer or " ..
                "estimated raid boss fight ends.",
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
            food = {
              name = "Food Buff",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.buffs.categories.food end,
              set = function(_, value)
                db.profile.buffs.categories.food = value
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
    infoDisplay = {
      type = "group",
      name = "Info Display",
      desc = "Displays equipment information overlays on your character sheet.",
      order = 8,
      args = {
        overview = goldModuleOverview("Display item levels, upgrade tracks, stats, enchants, and gems directly on equipment icons."),
        enabled = {
          name = "Enable Info Display Module",
          desc = "Enable Info Display overlays on equipment slots.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.infoDisplay.enabled end,
          set = function(_, value) Self.InfoDisplay:SetEnabled(value) end,
          order = 0.05
        },
        description = {
          type = "description",
          name = "Displays item levels, upgrade tracks, stats, enchants, and gems on equipment icons.",
          order = 0.5
        },
        charSheet = {
          type = "group",
          name = "Char Sheet",
          desc = "Character Sheet equipment overlay options.",
          inline = true,
          order = 1,
          args = {
            itemLevel = {
              name = "Item Level",
              desc = "Show item level on equipment icons.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.itemLevel end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.itemLevel = value
                Self.InfoDisplay:Refresh()
              end,
              order = 1
            },
            upgradeTrack = {
              name = "Upgrade Track",
              desc = "Show upgrade track progress (e.g. '6/6 C') below item level.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.upgradeTrack end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.upgradeTrack = value
                Self.InfoDisplay:Refresh()
              end,
              order = 2
            },
            maxUpgradeStar = {
              name = "Star for Max Upgrade",
              desc = "Replace the upgrade track numbers (e.g. '6/6') with the chat star icon (|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t) when an item is fully upgraded.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = function() return not db.profile.infoDisplay.enabled or not db.profile.infoDisplay.charSheet.upgradeTrack end,
              get = function() return db.profile.infoDisplay.charSheet.maxUpgradeStar end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.maxUpgradeStar = value
                Self.InfoDisplay:Refresh()
              end,
              order = 2.1
            },
            slotWatermark = {
              name = "Slot Watermark Item Level",
              desc = "Show the slot's high watermark item level at the top of the side stats.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.slotWatermark ~= false end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.slotWatermark = value
                Self.InfoDisplay:Refresh()
              end,
              order = 2.5
            },
            highWatermarkColoring = {
              name = function() return isRetail() and "High Watermark Coloring" or "Item Quality Coloring" end,
              desc = function()
                return isRetail()
                  and "Color item level based on upgrade track watermark tiers (White, Green, Blue, Purple, Orange, Golden)."
                  or "Color item level matching the item's quality color (Common, Uncommon, Rare, Epic, Legendary)."
              end,
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.highWatermarkColoring end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.highWatermarkColoring = value
                Self.InfoDisplay:Refresh()
              end,
              order = 3
            },
            secondaryStats = {
              name = "Secondary Stats",
              desc = "Show secondary stat totals (Crit, Haste, Mastery, Vers) and percentages in the side summary.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.secondaryStats end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.secondaryStats = value
                Self.InfoDisplay:Refresh()
              end,
              order = 4
            },
            tertiaryStats = {
              name = "Tertiary Stats",
              desc = "Show tertiary stat totals (Speed, Leech, Avoidance) and percentages in the side summary.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return true end,
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.tertiaryStats end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.tertiaryStats = value
                Self.InfoDisplay:Refresh()
              end,
              order = 5
            },
            itemStats = {
              name = "Item Stats",
              desc = "Show all item stats (Strength, Agility, Stamina, Intellect, Spirit, etc.) in the side summary.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return isRetail() end,
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.itemStats end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.itemStats = value
                Self.InfoDisplay:Refresh()
              end,
              order = 5.5
            },
            enchants = {
              name = "Enchants",
              desc = "Show enchant info in the breakdown and missing enchant alert icons.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.enchants end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.enchants = value
                Self.InfoDisplay:Refresh()
              end,
              order = 6
            },
            gemSockets = {
              name = "Gem Sockets",
              desc = "Show gem info in the breakdown and missing gem alert icons.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = function() return not db.profile.infoDisplay.enabled end,
              get = function() return db.profile.infoDisplay.charSheet.gemSockets end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.gemSockets = value
                Self.InfoDisplay:Refresh()
              end,
              order = 7
            }
          }
        }
      }
    },
    movableWindows = {
      type = "group",
      name = "Movable Windows",
      desc = "Drag most Blizzard windows by their title bar to reposition them, and resize them with the " ..
        "mouse wheel.",
      order = 9,
      args = {
        overview = goldModuleOverview("Move Blizzard windows by dragging their title bars and resize them with modifier keys and the mouse wheel."),
        enabled = {
          name = "Enable Movable Windows Module",
          desc = "Make registered Blizzard windows draggable and mouse-wheel scalable.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.movableWindows.enabled end,
          set = function(_, value) Self.MovableWindows:SetEnabled(value) end,
          order = 0.01
        },
        moveToasts = {
          name = "Make Toasts Movable in Edit Mode",
          desc = "Toasts are the popup windows in the center bottom of your screen for achievements and " ..
            "notable items. This enables you to move a blue box in Edit Mode so they pop up elsewhere.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.movableWindows.moveToasts end,
          set = function(_, value) Self.MovableWindows:SetMoveToastsEnabled(value) end,
          disabled = function() return not db.profile.movableWindows.enabled end,
          order = 0.05
        },
        keybindHint = {
          name = "Set a keybinding for \"Toggle Movable Windows\" under Key Bindings > SlackHacks to quickly " ..
            "enable/disable this without opening options.",
          type = "description",
          order = 0.1
        },
        modifierKey = {
          name = "Move Modifier Key",
          desc = "Key that must be held while left-click-dragging a window's title bar to move it (dragging " ..
            "elsewhere on the window does nothing). Choose None to allow moving with a plain left-click-drag.",
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
          desc = "Hold the modifier key below and scroll the mouse wheel over a window's title bar to resize " ..
            "it (scrolling elsewhere on the window is left alone).",
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
          desc = "Key that must be held while scrolling the mouse wheel over a window's title bar to resize " ..
            "it. Choose None to allow resizing with a plain mouse wheel scroll.",
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
      order = 10,
      args = selfVendorModeOptions()
    },
    weeklies = {
      type = "group",
      name = "Weeklies",
      desc = "Track weekly quest completions and activities.",
      order = 11,
      args = {
        overview = goldModuleOverview("Track weekly activities and show their progress in the Objective Tracker."),
        enabled = {
          name = "Enable Weeklies Module",
          desc = "Track weekly quest completions and activities.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.weeklies.enabled end,
          set = function(_, value) Self.Weeklies:SetEnabled(value) end,
          order = 0.05
        },
        trackDelves = {
          name = "Track Delves",
          desc = "Show a Delves button on the Objective Tracker with the weekly Gilded Stash, Trovehunter's " ..
            "Bounty, Valeera's level, and Delve Renown.",
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
  hookResetProfileOption()
  applyWIPOptionsDecoration()
  hideNonRetailOptions()
  migrateConfig()
  local customConfig = CustomConfigs and CustomConfigs[getBattletag()]
  if customConfig and customConfig.setOptions then
    customConfig.setOptions()
  end
  config:RegisterOptionsTable("SlackHacks", options)
  Self.configDialog, Self.configCategoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SlackHacks", icon(16) .. " SlackHacks")
end

