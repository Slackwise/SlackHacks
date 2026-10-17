local addonName, addonTable = ...
setfenv(1, _G.SlackHacks)

local ADDON_DISPLAY_NAME = "SlackHacks v" .. getAddonVersion()

dbDefaults = {
  global = {
    configVersion = CONFIG_VERSION,
    addonVersion = nil,
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
      lastKnownGildedStashesRemaining = nil,
      lastKnownGildedStashesResetAt = nil
    }
  },
  profile = {
    minimapIcon = {
      enabled = true,
      minimapPos = 220,
    },
    inventory = {
      autoSellGreyItems = false,
      autoRepair = false,
      autoRepairMode = "personal",
      hideBagsFrame = false
    },
    listviewBag = {
      enabled = false,
      showListviewBag = false,
      trackCrestCurrencies = true,
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
    quest = {
      enabled = false,
      autoAccept = false,
      autoComplete = false,
      autoClickFirstOption = false,
      numberKeys = false,
      spacebar = false,
      questItemButton = false
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
    windows = {
      enabled = false, -- overall switch for the whole Windows module
      movableToasts = false, -- adds Blizzard's toast popups (loot, mounts, achievements, etc.) as a draggable box in the real Edit Mode
      scalingZoneMap = false, -- adds a "Change Scale" slider to the Zone Map tab's menu and applies its saved scale
      movable = {
        enabled = false, -- drag registered Blizzard windows by their title bar
        modifierKey = "NONE", -- "NONE" | "SHIFT" | "CTRL" | "ALT" -- held to drag a registered frame
        savePositionStrategy = "permanent", -- "off" | "session" | "permanent"
        points = {}
      },
      scaling = {
        enabled = false, -- modifierKey + mouse wheel over a title bar resizes a registered frame
        modifierKey = "NONE", -- "NONE" | "SHIFT" | "CTRL" | "ALT" -- held to scale a registered frame
        saveStrategy = "permanent", -- "off" | "session" | "permanent"
        scales = {}
      }
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
    infoDisplay = {
      enabled = true,
      weeklies = {
        enabled = false,
        trackDelves = false
      },
      charSheet = {
        enabled = true,
        gearStats = true,
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
      },
      guildieList = {
        enabled = false,
        minimized = false,
        fitToContent = true,
        opacity = 0.5, -- Edit Mode's default DamageMeter "Background Transparency" (50 -> 0.5 alpha).
        sortBy = "name", -- "name" or "zone"
        showInstanceIcons = true,
        showRankIcons = true,
        showFactionIcons = true,
        factionIconsOppositeOnly = true,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 260,
        height = 200,
      },
      friendsList = {
        enabled = false,
        minimized = false,
        fitToContent = true,
        opacity = 0.5, -- Edit Mode's default DamageMeter "Background Transparency" (50 -> 0.5 alpha).
        sortBy = "name", -- "name" (the friends list's order) or "zone"
        onlyFavorites = true,
        onlyWoW = true,
        onlySameWoWVersion = false, -- Only applies while onlyWoW is on.
        showInstanceIcons = true,
        showGameIcons = true,
        showFactionIcons = true,
        factionIconsOppositeOnly = true,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 280, -- Beside the Guildie List's default spot rather than on top of it.
        y = 0,
        width = 300,
        height = 200,
      },
      -- The Players Online window that stacks the Friends and Guildie lists (InfoDisplay.lua).
      playersOnline = {
        stacked = false,
        stackOrder = "friends", -- "friends" (Friends, Guildies) or "guildies" (Guildies, Friends)
        minimized = false,
        opacity = 0.5, -- Edit Mode's default DamageMeter "Background Transparency".
        fitToContent = true,
        collapsed = { friends = false, guildies = false }, -- Per-list section collapse state.
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 300,
        height = 300,
      }
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
}

RETAIL_MODULES = {
  { key = "buffs", name = "Consumable Buff Reminders" },
  { key = { "combat", "paladin" }, name = "Paladin" },
  { key = "vendor", name = "Self Vendor" },
  { key = { "infoDisplay", "weeklies" }, name = "Weeklies" },
}

-- Modules that need Retail's modern UI, which WoW Forever shares since it's built on the Retail client.
RETAIL_OR_FOREVER_MODULES = {
  { key = { "infoDisplay", "guildieList" }, name = "Guildie List" },
  { key = { "infoDisplay", "friendsList" }, name = "Friends List" },
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
  for _, mod in ipairs(RETAIL_OR_FOREVER_MODULES) do
    local group = resolveOptionGroup(mod.key)
    if group then
      group.hidden = function() return not isRetailOrForever() end
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

function reportBugs()
  if Self.Debug and Self.Debug.ReportErrors then
    Self.Debug:ReportErrors()
  end
end

-----------------------------------------------------------------------
-- Minimap Addon Icon (LibDBIcon) & Context Menu
-----------------------------------------------------------------------

local MINIMAP_ICON_NAME = "SlackHacksErrorLog"
local minimapLDBObj = nil

local function isListviewBagActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.listviewBag and profile.listviewBag.enabled
end

local function toggleListviewBag()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.listviewBag then profile.listviewBag = {} end
  local newState = not profile.listviewBag.enabled
  profile.listviewBag.enabled = newState
  profile.listviewBag.showListviewBag = newState
  if newState then
    if Self.ListviewBag then Self.ListviewBag:Enable() end
    if Self.ListviewBag and Self.ListviewBag.SetShowListviewBag then Self.ListviewBag:SetShowListviewBag(true) end
  else
    if Self.ListviewBag and Self.ListviewBag.SetShowListviewBag then Self.ListviewBag:SetShowListviewBag(false) end
    if Self.ListviewBag then Self.ListviewBag:Disable() end
  end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

local function isSquareMinimapActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.minimap and profile.minimap.enabled and profile.minimap.shape == "square"
end

local function toggleSquareMinimap()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.minimap then profile.minimap = {} end
  local isSquare = profile.minimap.enabled and profile.minimap.shape == "square"
  if isSquare then
    profile.minimap.shape = "circle"
    if Self.Minimap then Self.Minimap:Refresh() end
  else
    profile.minimap.enabled = true
    profile.minimap.shape = "square"
    if Self.Minimap then
      Self.Minimap:Enable()
      Self.Minimap:Refresh()
    end
  end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

--- Returns whether Gear Stats overlays are currently showing (the Info Display, Char Sheet and Gear Stats are all on).
---@return boolean active
local function isGearStatsActive()
  local infoDisplay = Self.db and Self.db.profile.infoDisplay
  return (infoDisplay and infoDisplay.enabled and infoDisplay.charSheet.enabled and infoDisplay.charSheet.gearStats)
    and true or false
end

--- Minimap toggle for Gear Stats. Turning it on also turns on whatever it depends on (the Info Display master
--- switch and the Char Sheet module); turning it off only hides Gear Stats so the other Info Display features stay.
local function toggleGearStats()
  if not Self.db or not Self.CharSheet or not Self.InfoDisplay then return end
  local infoDisplay = Self.db.profile.infoDisplay
  if isGearStatsActive() then
    Self.CharSheet:SetGearStatsEnabled(false)
    return
  end
  -- Enable the Char Sheet first so the master switch's sub-module Enable() doesn't immediately abort it.
  if not infoDisplay.charSheet.enabled then Self.CharSheet:SetCharSheetEnabled(true) end
  if not infoDisplay.enabled then Self.InfoDisplay:SetEnabled(true) end
  Self.CharSheet:SetGearStatsEnabled(true)
end

local function isMouseRingActive()
  local profile = Self.db and Self.db.profile
  return profile and profile.mouseRing and profile.mouseRing.enabled
end

local function toggleMouseRing()
  local profile = Self.db and Self.db.profile
  if not profile then return end
  if not profile.mouseRing then profile.mouseRing = {} end
  local newState = not profile.mouseRing.enabled
  profile.mouseRing.enabled = newState
  if Self.MouseRing then Self.MouseRing:SetEnabled(newState) end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

--- Returns whether the Delves weekly tracker is showing (the Info Display, Weeklies and Track Delves are all on).
---@return boolean active
local function isTrackDelvesActive()
  local infoDisplay = Self.db and Self.db.profile.infoDisplay
  return (infoDisplay and infoDisplay.enabled and infoDisplay.weeklies.enabled and infoDisplay.weeklies.trackDelves)
    and true or false
end

--- Minimap toggle for the Delves tracker. Turning it on also turns on the Info Display master switch and the
--- Weeklies module; turning it off disables Weeklies and Track Delves but leaves the rest of the Info Display alone.
local function toggleTrackDelves()
  if not Self.db or not Self.Weeklies or not Self.InfoDisplay then return end
  local newState = not isTrackDelvesActive()
  -- Save Weeklies' settings before the master switch enables sub-modules, so its Enable() isn't aborted.
  Self.Weeklies:SetTrackDelves(newState)
  Self.Weeklies:SetEnabled(newState)
  if newState and not Self.db.profile.infoDisplay.enabled then Self.InfoDisplay:SetEnabled(true) end
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

--- Returns a minimap checkbox's "is checked" callback for a Players Online list (Friends or Guildie List): checked
--- while both the Info Display master switch and the list are on.
---@param key string The list's `infoDisplay` settings key: "friendsList" or "guildieList".
---@return fun(): boolean isActive
local function listActiveChecker(key)
  return function()
    local infoDisplay = Self.db and Self.db.profile.infoDisplay
    return (infoDisplay and infoDisplay.enabled and infoDisplay[key].enabled) and true or false
  end
end

--- Returns a minimap checkbox's toggle callback for a Players Online list. Turning a list on also turns on the Info
--- Display master switch; turning it off only disables that list.
---@param key string The list's `infoDisplay` settings key: "friendsList" or "guildieList".
---@param moduleName string The list's AceModule name on Self: "FriendsList" or "GuildieList".
---@return fun() toggle
local function listToggler(key, moduleName)
  local isActive = listActiveChecker(key)
  return function()
    local listModule = Self[moduleName]
    if not Self.db or not listModule or not Self.InfoDisplay then return end
    local newState = not isActive()
    -- Saved before the master switch enables sub-modules, so the list's Enable() isn't aborted.
    listModule:SetEnabled(newState)
    if newState and not Self.db.profile.infoDisplay.enabled then Self.InfoDisplay:SetEnabled(true) end
  end
end

local isFriendsListActive, toggleFriendsList = listActiveChecker("friendsList"), listToggler("friendsList", "FriendsList")
local isGuildieListActive, toggleGuildieList = listActiveChecker("guildieList"), listToggler("guildieList", "GuildieList")

local function openMinimapContextMenu(anchor)
  if InCombatLockdown() then return end
  if GameTooltip then GameTooltip:Hide() end

  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
      rootDescription:CreateTitle(ADDON_DISPLAY_NAME)
      rootDescription:CreateButton("Options", function()
        openOptions()
      end)
      rootDescription:CreateButton("Report Bugs", function()
        reportBugs()
      end)
      rootDescription:CreateCheckbox("Listview Bag", isListviewBagActive, toggleListviewBag)
      rootDescription:CreateCheckbox("Square Minimap", isSquareMinimapActive, toggleSquareMinimap)
      rootDescription:CreateCheckbox("Display Gear Stats", isGearStatsActive, toggleGearStats)
      if isRetailOrForever() then
        rootDescription:CreateCheckbox("Friends List", isFriendsListActive, toggleFriendsList)
        rootDescription:CreateCheckbox("Guildies List", isGuildieListActive, toggleGuildieList)
      end
      rootDescription:CreateCheckbox("Mouse Ring", isMouseRingActive, toggleMouseRing)
      rootDescription:CreateCheckbox("All NPC Auto-Interacts", isAllQuestAutomationEnabled, toggleAllQuestAutomation)
      if isRetail and isRetail() then
        rootDescription:CreateCheckbox("Track Delve Weeklies", isTrackDelvesActive, toggleTrackDelves)
      end
    end)
    return
  end

  local menuList = {
    { text = ADDON_DISPLAY_NAME, isTitle = true, notCheckable = true },
    { text = "Options", func = function() openOptions() end, notCheckable = true },
    { text = "Report Bugs", func = function() reportBugs() end, notCheckable = true },
    { text = "Listview Bag", checked = isListviewBagActive, func = toggleListviewBag, isNotRadio = true, keepShownOnClick = true },
    { text = "Square Minimap", checked = isSquareMinimapActive, func = toggleSquareMinimap, isNotRadio = true, keepShownOnClick = true },
    { text = "Display Gear Stats", checked = isGearStatsActive, func = toggleGearStats, isNotRadio = true, keepShownOnClick = true },
    { text = "Mouse Ring", checked = isMouseRingActive, func = toggleMouseRing, isNotRadio = true, keepShownOnClick = true },
    { text = "All NPC Auto-Interacts", checked = isAllQuestAutomationEnabled, func = toggleAllQuestAutomation, isNotRadio = true, keepShownOnClick = true },
  }
  if isRetail and isRetail() then
    table.insert(menuList, {
      text = "Track Delve Weeklies",
      checked = isTrackDelvesActive,
      func = toggleTrackDelves,
      isNotRadio = true,
      keepShownOnClick = true,
    })
  end
  local menuFrame = CreateFrame("Frame", "SlackHacksMinimapContextMenu", UIParent, "UIDropDownMenuTemplate")
  EasyMenu(menuList, menuFrame, "cursor", 0, 0, "MENU")
end

local function ensureMinimapBadge(button)
  if button.errorBadge then return button.errorBadge end

  local badge = CreateFrame("Frame", nil, button)
  badge:SetFrameLevel(button:GetFrameLevel() + 5)
  badge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
  badge:SetSize(16, 16)

  local bg = badge:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(badge)
  bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  bg:SetVertexColor(0.85, 0.08, 0.08, 0.95)
  badge.bg = bg

  local countText = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  countText:SetFontObject(NumberFontNormalSmall or GameFontHighlightSmall)
  countText:SetPoint("CENTER", badge, "CENTER", 0, 0)
  countText:SetTextColor(1, 1, 1, 1)
  badge.countText = countText

  button.errorBadge = badge
  return badge
end

local function initMinimapIcon()
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
  if not ldb or not ldbi then return end

  if not minimapLDBObj then
    minimapLDBObj = ldb:NewDataObject(MINIMAP_ICON_NAME, {
      type = "data source",
      text = ADDON_DISPLAY_NAME,
      icon = SLACKHACKS_ICON,
      OnClick = function(clickedButton, mouseButton)
        if mouseButton == "RightButton" then
          openMinimapContextMenu(clickedButton)
        else
          local list = (Self.Debug and Self.Debug.GetErrorLog and Self.Debug:GetErrorLog())
            or (errorLogTable and errorLogTable()) or {}
          if #list > 0 and Self.Debug and Self.Debug.ShowWindow then
            Self.Debug:ShowWindow()
          else
            openOptions()
          end
        end
      end,
      OnTooltipShow = function(tooltip)
        local list = (Self.Debug and Self.Debug.GetErrorLog and Self.Debug:GetErrorLog())
          or (errorLogTable and errorLogTable()) or {}
        local count = #list
        tooltip:AddLine(ADDON_DISPLAY_NAME, 1, 0.82, 0)
        if count > 0 then
          tooltip:AddLine(" ")
          if count == 1 then
            tooltip:AddLine("You have 1 un-reported error in SlackHacks.", 1, 0.3, 0.3, true)
          else
            tooltip:AddLine(("You have %d un-reported errors in SlackHacks."):format(count), 1, 0.3, 0.3, true)
          end
          tooltip:AddLine("Left-click: Open error report window", 0.8, 0.8, 0.8)
        else
          tooltip:AddLine("Left-click: Open options", 0.8, 0.8, 0.8)
        end
        tooltip:AddLine("Right-click: Quick toggle menu", 0.8, 0.8, 0.8)
      end,
      OnEnter = function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
        if minimapLDBObj.OnTooltipShow then
          minimapLDBObj.OnTooltipShow(GameTooltip)
        end
        GameTooltip:Show()
      end,
      OnLeave = function()
        GameTooltip:Hide()
      end,
    })
  end

  if not ldbi:IsRegistered(MINIMAP_ICON_NAME) then
    local iconDB = (db and db.profile and db.profile.minimapIcon)
      or (Self.db and Self.db.profile and Self.db.profile.minimapIcon)
      or { enabled = true, minimapPos = 220 }
    ldbi:Register(MINIMAP_ICON_NAME, minimapLDBObj, iconDB)
  end
end

function updateMinimapIcon()
  local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
  if not ldbi then return end

  if not ldbi:IsRegistered(MINIMAP_ICON_NAME) then
    initMinimapIcon()
  end

  local list = (Self.Debug and Self.Debug.GetErrorLog and Self.Debug:GetErrorLog())
    or (errorLogTable and errorLogTable()) or {}
  local count = #list
  local button = ldbi:GetMinimapButton(MINIMAP_ICON_NAME)

  local isIconEnabled = true
  if db and db.profile and db.profile.minimapIcon then
    if db.profile.minimapIcon.enabled ~= nil then
      isIconEnabled = db.profile.minimapIcon.enabled
    end
  elseif Self.db and Self.db.profile and Self.db.profile.minimapIcon then
    if Self.db.profile.minimapIcon.enabled ~= nil then
      isIconEnabled = Self.db.profile.minimapIcon.enabled
    end
  end

  local shouldShow = count > 0 or isIconEnabled

  if shouldShow then
    if button then
      if count > 0 then
        local badge = ensureMinimapBadge(button)
        if count > 99 then
          badge.countText:SetText("99+")
          badge:SetSize(22, 16)
        elseif count >= 10 then
          badge.countText:SetText(tostring(count))
          badge:SetSize(18, 16)
        else
          badge.countText:SetText(tostring(count))
          badge:SetSize(16, 16)
        end
        badge:Show()
      elseif button.errorBadge then
        button.errorBadge:Hide()
      end
    end
    ldbi:Show(MINIMAP_ICON_NAME)
  else
    if button and button.errorBadge then
      button.errorBadge:Hide()
    end
    ldbi:Hide(MINIMAP_ICON_NAME)
  end
end
Self.UpdateMinimapIcon = updateMinimapIcon

local function getWIPModuleNames()
  local names = {}
  for _, mod in ipairs(WIP_MODULES) do
    table.insert(names, mod.name)
  end
  return table.concat(names, ", ")
end

local function printSlashHelp()
  print(grey(icon(16)) .. " " .. color("FFD100")(ADDON_DISPLAY_NAME .. " Slash Commands:") .. "")
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

  prn("disabled all WIP modules (" .. getWIPModuleNames() .. ").")
end

function handleSlashCommand(input)
  local command = strlower(strtrim(input or ""))
  if command == "" then
    openOptions()
    printSlashHelp()
  elseif command == "help" then
    printSlashHelp()
  elseif command == "debug" then
    toggleDebugging()
  elseif command == "bugs" or command == "bug" or command == "bugreport" or command == "error" or command == "errors" or command == "errorlog" then
    reportBugs()
  elseif command == "reset" then
    promptResetProfile()
  elseif command == "wipoff" then
    disableWIPModules()
  elseif command == "induce-error" then
    Self.Debug:InduceError()
  else
    prn("unknown command '" .. command .. "'. Type " .. color("FFFFFF")("/slack help") .. " for available commands.")
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

--- Closes the Settings panel and opens Blizzard's Edit Mode. Does nothing in combat (Edit Mode is
--- protected) or on clients without Edit Mode.
local function openEditMode()
  if InCombatLockdown() then return end
  if SettingsPanel and SettingsPanel:IsShown() then
    HideUIPanel(SettingsPanel)
  end
  if EditModeManagerFrame then
    ShowUIPanel(EditModeManagerFrame)
  end
end

--- AceConfig `disabled` callback: Info Display options are greyed out while its master switch is off.
---@return boolean disabled
local function infoDisplayDisabled()
  return not db.profile.infoDisplay.enabled
end

local function infoDisplayCharSheetDisabled()
  return not db.profile.infoDisplay.enabled or not db.profile.infoDisplay.charSheet.enabled
end

options = {
  type = "group",
  name = ADDON_DISPLAY_NAME,
  icon = SLACKHACKS_ICON,
  args = {
    enable = {
      name = "Enable Addon",
      desc = "Fully enables/disables the entire addon",
      type = "toggle",
      width = "normal",
      get = function() return Self:IsEnabled() end,
      set = function() if Self:IsEnabled() then Self:Disable() else Self:Enable() end end,
      order = 0 -- first
    },
    minimapIcon = {
      name = "Minimap Icon",
      desc = "Show the SlackHacks minimap icon. (Always appears when un-reported errors occur)",
      type = "toggle",
      width = "normal",
      get = function()
        return db and db.profile and db.profile.minimapIcon and db.profile.minimapIcon.enabled ~= false
      end,
      set = function(_, value)
        if not db.profile.minimapIcon then db.profile.minimapIcon = { minimapPos = 220 } end
        db.profile.minimapIcon.enabled = value
        updateMinimapIcon()
      end,
      order = 0.5
    },
    reportBug = {
      name = "Report Bugs",
      desc = "View and report recorded errors, or open the bug report link on GitHub if no errors are logged.",
      type = "execute",
      width = "normal",
      func = function()
        reportBugs()
      end,
      order = 0.8
    },
    inventory = {
      type = "group",
      name = "Inventory",
      desc = "Small quality-of-life features.",
      order = 6,
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
            trackCrestCurrencies = {
              name = "Track Crest Currencies",
              desc = "Display a strip of your current season crest currencies in the bottom status bar of the Listview Bag.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.listviewBag.trackCrestCurrencies end,
              set = function(_, value)
                db.profile.listviewBag.trackCrestCurrencies = value
                if Self.ListviewBag then Self.ListviewBag:RefreshFooter() end
              end,
              disabled = function() return not db.profile.listviewBag.enabled or not isRetail() end,
              order = 2.5
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
        },
      }
    },
    controls = {
      type = "group",
      name = "Controls",
      desc = "Camera behavior and keybinding options.",
      order = 3,
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
      order = 4,
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
      order = 8,
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
              func = function() reportBugs() end,
              order = 2
            },
            clearErrorLog = {
              name = "Clear Error Log",
              desc = "Clear the SlackHacks Error Log.",
              type = "execute",
              func = function()
                clearErrorLogs()
                if Self.Debug and Self.Debug.RefreshMarkdown then
                  Self.Debug:RefreshMarkdown()
                end
                prn("SlackHacks Error Log cleared")
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
                prn("debug logs cleared")
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
                prn("old logs purged")
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
      order = 11,
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
      order = 5,
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
          name = "Open Edit Mode",
          desc = "Open Blizzard's Edit Mode and select the Minimap to configure its visual settings and " ..
            "position/size.",
          type = "execute",
          func = openEditMode,
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
      order = 12,
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
      order = 7,
      args = {
        overview = goldModuleOverview("Display item levels, upgrade tracks, stats, enchants, and gems directly on equipment icons."),
        enabled = {
          name = "Enable Info Display Module",
          desc = "Enable all Info Display features: Char Sheet, Weeklies, and the Guildie and Friends lists. " ..
            "Turning this off disables all of them.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.infoDisplay.enabled end,
          set = function(_, value) Self.InfoDisplay:SetEnabled(value) end,
          order = 0.05
        },
        stackPlayerLists = {
          name = "Stacked Friends/Guildies List ('Players Online' Window)",
          desc = "Show the Friends and Guildie lists stacked in one collapsible \"Players Online\" window, " ..
            "like the Objective Tracker's sections, instead of in their own windows.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          hidden = function() return not isRetailOrForever() end,
          disabled = infoDisplayDisabled,
          get = function() return db.profile.infoDisplay.playersOnline.stacked end,
          set = function(_, value) Self.InfoDisplay:SetStackLists(value) end,
          order = 0.1
        },
        stackOrder = {
          name = "List Stack Order",
          desc = "Which list is shown on top in the Players Online window.",
          type = "select",
          values = { friends = "Friends, Guildies", guildies = "Guildies, Friends" },
          sorting = { "friends", "guildies" },
          hidden = function() return not isRetailOrForever() end,
          disabled = function() return infoDisplayDisabled() or not db.profile.infoDisplay.playersOnline.stacked end,
          get = function() return db.profile.infoDisplay.playersOnline.stackOrder end,
          set = function(_, value) Self.InfoDisplay:SetStackOrder(value) end,
          order = 0.2
        },
        charSheet = {
          type = "group",
          name = "Char Sheet",
          desc = "Character Sheet equipment overlay options.",
          order = 1,
          disabled = infoDisplayDisabled,
          args = {
            overview = goldModuleOverview("Display Gear Stats on the character sheet with configurable item-level, upgrade, stat, enchant, and gem details."),
            enabled = {
              name = "Enable Char Sheet Module",
              desc = "Inject the Gear Stats checkbox into the character sheet and enable its overlays.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.infoDisplay.charSheet.enabled end,
              set = function(_, value) Self.CharSheet:SetCharSheetEnabled(value) end,
              order = 1
            },
            gearStats = {
              name = "Show Gear Stats",
              desc = "Show or hide equipment overlays on your character sheet. This stays in sync with the in-game Gear Stats checkbox.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.infoDisplay.charSheet.gearStats end,
              set = function(_, value) Self.CharSheet:SetGearStatsEnabled(value) end,
              disabled = infoDisplayCharSheetDisabled,
              order = 1.5
            },
            itemLevel = {
              name = "Item Level",
              desc = "Show item level on equipment icons.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.itemLevel end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.itemLevel = value
                Self.InfoDisplay:Refresh()
              end,
              order = 2
            },
            upgradeTrack = {
              name = "Upgrade Track",
              desc = "Show upgrade track progress (e.g. '6/6 C') below item level.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.upgradeTrack end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.upgradeTrack = value
                Self.InfoDisplay:Refresh()
              end,
              order = 3
            },
            maxUpgradeStar = {
              name = "Star for Max Upgrade",
              desc = "Replace the upgrade track numbers (e.g. '6/6') with the chat star icon (|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t) when an item is fully upgraded.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = function() return infoDisplayCharSheetDisabled() or not db.profile.infoDisplay.charSheet.upgradeTrack end,
              get = function() return db.profile.infoDisplay.charSheet.maxUpgradeStar end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.maxUpgradeStar = value
                Self.InfoDisplay:Refresh()
              end,
              order = 3.1
            },
            slotWatermark = {
              name = "Slot Watermark Item Level",
              desc = "Show the slot's high watermark item level at the top of the side stats.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.slotWatermark ~= false end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.slotWatermark = value
                Self.InfoDisplay:Refresh()
              end,
              order = 3.5
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
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.highWatermarkColoring end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.highWatermarkColoring = value
                Self.InfoDisplay:Refresh()
              end,
              order = 4
            },
            secondaryStats = {
              name = "Secondary Stats",
              desc = "Show secondary stat totals (Crit, Haste, Mastery, Vers) and percentages in the side summary.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.secondaryStats end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.secondaryStats = value
                Self.InfoDisplay:Refresh()
              end,
              order = 5
            },
            tertiaryStats = {
              name = "Tertiary Stats",
              desc = "Show tertiary stat totals (Speed, Leech, Avoidance) and percentages in the side summary.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return true end,
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.tertiaryStats end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.tertiaryStats = value
                Self.InfoDisplay:Refresh()
              end,
              order = 6
            },
            itemStats = {
              name = "Item Stats",
              desc = "Show all item stats (Strength, Agility, Stamina, Intellect, Spirit, etc.) in the side summary.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return isRetail() end,
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.itemStats end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.itemStats = value
                Self.InfoDisplay:Refresh()
              end,
              order = 6.5
            },
            enchants = {
              name = "Enchants",
              desc = "Show enchant info in the breakdown and missing enchant alert icons.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.enchants end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.enchants = value
                Self.InfoDisplay:Refresh()
              end,
              order = 7
            },
            gemSockets = {
              name = "Gem Sockets",
              desc = "Show gem info in the breakdown and missing gem alert icons.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              hidden = function() return not isRetail() end,
              disabled = infoDisplayCharSheetDisabled,
              get = function() return db.profile.infoDisplay.charSheet.gemSockets end,
              set = function(_, value)
                db.profile.infoDisplay.charSheet.gemSockets = value
                Self.InfoDisplay:Refresh()
              end,
              order = 8
            }
          }
        },
        weeklies = {
          type = "group",
          name = "Weeklies",
          desc = "Track weekly quest completions and activities.",
          order = 2,
          disabled = infoDisplayDisabled,
          args = {
            overview = goldModuleOverview("Track weekly activities and show their progress in the Objective Tracker."),
            enabled = {
              name = "Enable Weeklies Module",
              desc = "Track weekly quest completions and activities.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.infoDisplay.weeklies.enabled end,
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
              get = function() return db.profile.infoDisplay.weeklies.trackDelves end,
              set = function(_, value) Self.Weeklies:SetTrackDelves(value) end,
              disabled = function() return not db.profile.infoDisplay.weeklies.enabled end,
              order = 1
            }
          }
        },
        guildieList = {
          type = "group",
          name = "Guildie List",
          desc = "A collapsible window listing online guild members.",
          order = 3,
          disabled = infoDisplayDisabled,
          args = {
            overview = goldModuleOverview("Show a movable, resizable, collapsible window listing your online guild members and their zones. Click a member for Invite, Whisper, and View Houses (Retail)."),
            enabled = {
              name = "Enable Guildie List Module",
              desc = "Show the online guild member window.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.infoDisplay.guildieList.enabled end,
              set = function(_, value) Self.GuildieList:SetEnabled(value) end,
              order = 0.05
            },
            fitToContent = {
              name = "Fit Window to Content",
              desc = "Automatically size the window to fit its members and locations (up to a maximum height, after which the list scrolls). Turns off manual resizing while enabled. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.guildieList.enabled end,
              get = function() return db.profile.infoDisplay.guildieList.fitToContent end,
              set = function(_, value) Self.GuildieList:SetFitToContent(value) end,
              order = 0.5
            },
            opacity = {
              name = "Background Opacity",
              desc = "How opaque the window's background is. Also available from the window's cog menu.",
              type = "range",
              isPercent = true,
              min = 0,
              max = 1,
              step = 0.05,
              disabled = function() return not db.profile.infoDisplay.guildieList.enabled end,
              get = function() return db.profile.infoDisplay.guildieList.opacity end,
              set = function(_, value) Self.GuildieList:SetOpacity(value) end,
              order = 1
            },
            sortBy = {
              name = "Sort By",
              desc = "Sort the list by member name or by location. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "select",
              values = { name = "Name", zone = "Location" },
              sorting = { "name", "zone" },
              disabled = function() return not db.profile.infoDisplay.guildieList.enabled end,
              get = function() return db.profile.infoDisplay.guildieList.sortBy end,
              set = function(_, value) Self.GuildieList:SetSortBy(value) end,
              order = 2
            },
            showInstanceIcons = {
              name = "Show Instance Icons",
              desc = "Show a Dungeon, Raid, or Delve icon after the location of members inside one. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.guildieList.enabled end,
              get = function() return db.profile.infoDisplay.guildieList.showInstanceIcons end,
              set = function(_, value) Self.GuildieList:SetDisplaySetting("showInstanceIcons", value) end,
              order = 3
            },
            showRankIcons = {
              name = "Show Rank Icons",
              desc = "Show the guild roster's crown icon after the Guild Master's name and its assistant icon after officers' names. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.guildieList.enabled end,
              get = function() return db.profile.infoDisplay.guildieList.showRankIcons end,
              set = function(_, value) Self.GuildieList:SetDisplaySetting("showRankIcons", value) end,
              order = 3.5
            },
            showFactionIcons = {
              name = "Show Faction Icons",
              desc = "Show a Horde or Alliance icon after member names. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.guildieList.enabled end,
              get = function() return db.profile.infoDisplay.guildieList.showFactionIcons end,
              set = function(_, value) Self.GuildieList:SetDisplaySetting("showFactionIcons", value) end,
              order = 4
            },
            factionIconsOppositeOnly = {
              name = "Only Show Opposite Faction Icon",
              desc = "Only show the faction icon for members of the opposite faction to your current character. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function()
                local settings = db.profile.infoDisplay.guildieList
                return not settings.enabled or not settings.showFactionIcons
              end,
              get = function() return db.profile.infoDisplay.guildieList.factionIconsOppositeOnly end,
              set = function(_, value) Self.GuildieList:SetDisplaySetting("factionIconsOppositeOnly", value) end,
              order = 5
            }
          }
        },
        friendsList = {
          type = "group",
          name = "Friends List",
          desc = "A collapsible window listing online friends.",
          order = 4,
          disabled = infoDisplayDisabled,
          args = {
            overview = goldModuleOverview("Show a movable, resizable, collapsible window listing your online friends and their locations."),
            enabled = {
              name = "Enable Friends List Module",
              desc = "Show the online friends window.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.infoDisplay.friendsList.enabled end,
              set = function(_, value) Self.FriendsList:SetEnabled(value) end,
              order = 0.05
            },
            fitToContent = {
              name = "Fit Window to Content",
              desc = "Automatically size the window to fit its friends and locations (up to a maximum height, after which the list scrolls). Turns off manual resizing while enabled. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.fitToContent end,
              set = function(_, value) Self.FriendsList:SetFitToContent(value) end,
              order = 0.5
            },
            opacity = {
              name = "Background Opacity",
              desc = "How opaque the window's background is. Also available from the window's cog menu.",
              type = "range",
              isPercent = true,
              min = 0,
              max = 1,
              step = 0.05,
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.opacity end,
              set = function(_, value) Self.FriendsList:SetOpacity(value) end,
              order = 1
            },
            onlyFavorites = {
              name = "Only Favorite Friends",
              desc = "Only list Battle.net friends you've marked as favorites. Turn off to list all online friends, including character friends. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.onlyFavorites end,
              set = function(_, value) Self.FriendsList:SetDisplaySetting("onlyFavorites", value) end,
              order = 1.5
            },
            onlyWoW = {
              name = "Only Playing WoW",
              desc = "Only list friends currently playing World of Warcraft, hiding those in other Blizzard games or the Battle.net app. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.onlyWoW end,
              set = function(_, value) Self.FriendsList:SetDisplaySetting("onlyWoW", value) end,
              order = 1.6
            },
            onlySameWoWVersion = {
              name = "Only Same WoW Version",
              desc = "Only list friends playing the same version of WoW as you (e.g. hide Classic players while you're on Retail). Requires Only Playing WoW. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function()
                local settings = db.profile.infoDisplay.friendsList
                return not settings.enabled or not settings.onlyWoW
              end,
              get = function() return db.profile.infoDisplay.friendsList.onlySameWoWVersion end,
              set = function(_, value) Self.FriendsList:SetDisplaySetting("onlySameWoWVersion", value) end,
              order = 1.7
            },
            sortBy = {
              name = "Sort By",
              desc = "Sort the list by name (the Friends list's order) or by location. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "select",
              values = { name = "Name", zone = "Location" },
              sorting = { "name", "zone" },
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.sortBy end,
              set = function(_, value) Self.FriendsList:SetSortBy(value) end,
              order = 1.2
            },
            showInstanceIcons = {
              name = "Show Instance Icons",
              desc = "Show a Dungeon, Raid, or Delve icon after the location of friends inside one. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.showInstanceIcons end,
              set = function(_, value) Self.FriendsList:SetDisplaySetting("showInstanceIcons", value) end,
              order = 3
            },
            showGameIcons = {
              name = "Show Game Icons",
              desc = "Show the icon of the Blizzard game or app each friend is in after their name, like the Friends list. Only shown for friends not in the same game as you (other WoW versions still show it). Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.showGameIcons end,
              set = function(_, value) Self.FriendsList:SetDisplaySetting("showGameIcons", value) end,
              order = 3.5
            },
            showFactionIcons = {
              name = "Show Faction Icons",
              desc = "Show a Horde or Alliance icon after the names of friends playing WoW. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function() return not db.profile.infoDisplay.friendsList.enabled end,
              get = function() return db.profile.infoDisplay.friendsList.showFactionIcons end,
              set = function(_, value) Self.FriendsList:SetDisplaySetting("showFactionIcons", value) end,
              order = 4
            },
            factionIconsOppositeOnly = {
              name = "Only Show Opposite Faction Icon",
              desc = "Only show the faction icon for friends on the opposite faction to your current character. Also available from the window's cog menu.",
              descStyle = "inline",
              type = "toggle",
              width = "full",
              disabled = function()
                local settings = db.profile.infoDisplay.friendsList
                return not settings.enabled or not settings.showFactionIcons
              end,
              get = function() return db.profile.infoDisplay.friendsList.factionIconsOppositeOnly end,
              set = function(_, value) Self.FriendsList:SetDisplaySetting("factionIconsOppositeOnly", value) end,
              order = 5
            }
          }
        }
      }
    },
    windows = {
      type = "group",
      name = "Windows",
      desc = "Reposition and resize Blizzard windows.",
      order = 9,
      args = {
        overview = goldModuleOverview("Make windows movable, scalable, and other related goodies."),
        enabled = {
          name = "Enable Windows Module",
          desc = "Turn on the Windows features below (Movable Windows and Scaling).",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.windows.enabled end,
          set = function(_, value) Self.Windows:SetEnabled(value) end,
          order = 0.01
        },
        movableToasts = {
          name = "Make Toasts Movable in Edit Mode",
          desc = "Toasts are the popup windows in the center bottom of your screen for achievements and " ..
            "notable items. This adds a blue box to Edit Mode so you can reposition where they'll popup.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.windows.movableToasts end,
          set = function(_, value) Self.Windows:SetMoveToastsEnabled(value) end,
          disabled = function() return not db.profile.windows.enabled end,
          order = 0.2
        },
        openEditMode = {
          name = "Open Edit Mode",
          desc = "Open Blizzard's Edit Mode to reposition the toasts.",
          type = "execute",
          func = openEditMode,
          disabled = function() return not (db.profile.windows.enabled and db.profile.windows.movableToasts) end,
          order = 0.25
        },
        scalingZoneMap = {
          name = "Enable Zone Map Scaling",
          desc = "Adds a 'Change Scale' slider to the Zone Map's tab menu " ..
            "(right-click the tab).",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.windows.scalingZoneMap end,
          set = function(_, value) Self.Windows:SetZoneMapScalingEnabled(value) end,
          disabled = function() return not db.profile.windows.enabled end,
          order = 0.3
        },
        movable = {
          type = "group",
          name = "Movable Windows",
          inline = true,
          order = 5,
          args = {
            enabled = {
              name = "Enable Movable Windows",
              desc = "Drag most Blizzard windows by their title bar to reposition them.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.windows.movable.enabled end,
              set = function(_, value) db.profile.windows.movable.enabled = value end,
              disabled = function() return not db.profile.windows.enabled end,
              order = 0.01
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
              get = function() return db.profile.windows.movable.modifierKey end,
              set = function(_, value) db.profile.windows.movable.modifierKey = value end,
              disabled = function() return not (db.profile.windows.enabled and db.profile.windows.movable.enabled) end,
              order = 1
            },
            savePositionStrategy = {
              name = "Remember Positions",
              desc =
                "Do Not Remember: positions reset when you close and reopen a window\n\n" ..
                "In Session: positions are kept until you reload your UI\n\n" ..
                "Remember Permanently: positions are kept until reset or changed again",
              type = "select",
              width = 1.5,
              values = {
                off = "Do Not Remember",
                session = "In Session, Until Reload",
                permanent = "Remember Permanently"
              },
              sorting = { "off", "session", "permanent" },
              get = function() return db.profile.windows.movable.savePositionStrategy end,
              set = function(_, value) db.profile.windows.movable.savePositionStrategy = value end,
              disabled = function() return not (db.profile.windows.enabled and db.profile.windows.movable.enabled) end,
              order = 3
            },
            resetPositions = {
              name = "Reset Remembered Positions",
              desc = "Clear all permanently remembered window positions. Reloads your UI.",
              type = "execute",
              width = 1.5,
              func = function()
                Self.Windows:ResetPositions()
                ReloadUI()
              end,
              confirm = function() return "Are you sure you want to reset all remembered window positions? This will reload the UI." end,
              disabled = function() return not (db.profile.windows.enabled and db.profile.windows.movable.enabled) end,
              order = 5
            }
          }
        },
        scaling = {
          type = "group",
          name = "Window Scaling",
          inline = true,
          order = 10,
          args = {
            enabled = {
              name = "Enable Window Scaling",
              desc = "Scroll on the titlebar to scale the window.",
              type = "toggle",
              descStyle = "inline",
              width = "full",
              get = function() return db.profile.windows.scaling.enabled end,
              set = function(_, value) db.profile.windows.scaling.enabled = value end,
              disabled = function() return not db.profile.windows.enabled end,
              order = 1
            },
            modifierKey = {
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
              get = function() return db.profile.windows.scaling.modifierKey end,
              set = function(_, value) db.profile.windows.scaling.modifierKey = value end,
              disabled = function() return not (db.profile.windows.enabled and db.profile.windows.scaling.enabled) end,
              order = 2
            },
            saveStrategy = {
              name = "Remember Scales",
              desc =
                "Do Not Remember: scales reset when you close and reopen a window\n\n" ..
                "In Session: scales are kept until you reload your UI\n\n" ..
                "Remember Permanently: scales are kept until reset or changed again",
              type = "select",
              width = 1.5,
              values = {
                off = "Do Not Remember",
                session = "In Session, Until Reload",
                permanent = "Remember Permanently"
              },
              sorting = { "off", "session", "permanent" },
              get = function() return db.profile.windows.scaling.saveStrategy end,
              set = function(_, value) db.profile.windows.scaling.saveStrategy = value end,
              disabled = function() return not db.profile.windows.enabled end,
              order = 3
            },
            resetScales = {
              name = "Reset Remembered Scales",
              desc = "Clear all permanently remembered window scales. Reloads your UI.",
              type = "execute",
              width = 1.5,
              func = function()
                Self.Windows:ResetScales()
                ReloadUI()
              end,
              confirm = function() return "Are you sure you want to reset all remembered window scales? This will reload the UI." end,
              disabled = function() return not db.profile.windows.enabled end,
              order = 4
            }
          }
        }
      }
    },
    vendor = {
      type = "group",
      name = "Self Vendor",
      order = 10,
      args = selfVendorModeOptions()
    },
    quest = {
      type = "group",
      name = "Quest / NPC",
      desc = "Quest and NPC dialog automation, plus an Extra Action Button for quest items.",
      order = 9.5,
      args = {
        overview = goldModuleOverview("Automates quest and NPC dialogs, adds number-key shortcuts to dialog options, and shows an Extra Action Button for quest items."),
        shiftNote = {
          type = "description",
          name = "|cffffffffHold |cff00ccffShift|cffffffff while interacting with an NPC to skip all automation for that interaction.|r",
          fontSize = "small",
          width = "full",
          order = 0.05
        },
        enabled = {
          name = "Enable Quest Module",
          desc = "Enable the Quest / NPC features below.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          get = function() return db.profile.quest.enabled end,
          set = function(_, value) Self.Quest:SetEnabled(value) end,
          order = 0.1
        },
        setKeybinds = {
          name = "Set Quest Keybinds",
          desc = "Open the Key Bindings settings to the SlackHacks section to bind the NPC auto-interact toggles.",
          type = "execute",
          func = function() openKeybindings() end,
          order = 0.2
        },
        autoAccept = {
          name = "Auto-Accept Quests",
          desc = "Automatically accepts quests on interact.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.quest.enabled end,
          get = function() return db.profile.quest.autoAccept end,
          set = function(_, value) Self.Quest:SetOption("autoAccept", value) end,
          order = 1
        },
        autoComplete = {
          name = "Auto-Complete Quests",
          desc = "Automatically completes quests that have no choices in reward.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.quest.enabled end,
          get = function() return db.profile.quest.autoComplete end,
          set = function(_, value) Self.Quest:SetOption("autoComplete", value) end,
          order = 2
        },
        autoClickFirstOption = {
          name = "Auto-Click First Dialog Option",
          desc = "Automatically clicks an interact option in an NPC dialog if it's the only option.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.quest.enabled end,
          get = function() return db.profile.quest.autoClickFirstOption end,
          set = function(_, value) Self.Quest:SetOption("autoClickFirstOption", value) end,
          order = 3
        },
        numberKeys = {
          name = "Keybind NPC Dialog Options to Number Keys",
          desc = "Keybind NPC dialog options to the number keys and shows each shortcut before its text.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          disabled = function() return not db.profile.quest.enabled end,
          get = function() return db.profile.quest.numberKeys end,
          set = function(_, value) Self.Quest:SetOption("numberKeys", value) end,
          order = 4
        },
        spacebar = {
          name = "Use Spacebar to Accept/Complete Quest",
          desc = "keybinds Spacebar to accept or complete the current quest. Disabled when choosing between quest rewards.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          --- Disables the control while its module is off.
          ---@return boolean
          disabled = function() return not db.profile.quest.enabled end,
          --- Reads the profile's Spacebar shortcut setting.
          ---@return boolean
          get = function() return db.profile.quest.spacebar end,
          --- Applies the Spacebar shortcut setting.
          ---@param _ table AceConfig option info.
          ---@param value boolean
          set = function(_, value) Self.Quest:SetOption("spacebar", value) end,
          order = 4.5
        },
        questItemButton = {
          name = "Use 'Extra Action Button' for Quest Items",
          desc = "Shows the 'Extra Action Button' when there is a quest item to use.",
          type = "toggle",
          descStyle = "inline",
          width = "full",
          hidden = function() return not Self.Quest:IsQuestItemButtonSupported() end,
          disabled = function() return not db.profile.quest.enabled end,
          get = function() return db.profile.quest.questItemButton end,
          set = function(_, value) Self.Quest:SetOption("questItemButton", value) end,
          order = 5
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
  --     prn("mounting...")
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
  if checkAddonVersionUpdate then
    checkAddonVersionUpdate()
  end
  local customConfig = CustomConfigs and CustomConfigs[getBattletag()]
  if customConfig and customConfig.setOptions then
    customConfig.setOptions()
  end
  config:RegisterOptionsTable("SlackHacks", options)
  Self.configDialog, Self.configCategoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SlackHacks", icon(16) .. " SlackHacks")
  updateMinimapIcon()
end
