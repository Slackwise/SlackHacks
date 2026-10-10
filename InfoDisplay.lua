setfenv(1, _G.SlackHacks)

--[[
  InfoDisplay - Character Sheet Equipment Information Overlay.
  Displays centered item levels and upgrade tracks on equipment icons, with a side-anchored
  summary of total secondary/tertiary stats, missing enchant/gem alerts, and a hover breakdown tooltip.
]]--

local module = Self:NewModule("InfoDisplay", "AceEvent-3.0")
Self.InfoDisplay = module

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local STATS_FONT = "Fonts\\ARIALN.TTF"
local FONT_SIZE_LEVEL = 17
local FONT_SIZE_WATERMARK = 11
local FONT_SIZE_TRACK = 12
local FONT_SIZE_STATS = 9
local FONT_OUTLINE = "OUTLINE"

local STAR_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:11:11:0:-1|t"

local function getStatsFont()
  if NumberFontNormalSmall then
    local font = NumberFontNormalSmall:GetFont()
    if font then return font end
  end
  return STATS_FONT
end

local function isSecret(value)
  return _G.issecretvalue and _G.issecretvalue(value) or false
end

local function isCleanNumber(value)
  return not isSecret(value) and type(value) == "number"
end

local COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
local COLOR_GREY = { r = 0.7, g = 0.7, b = 0.7, a = 1 }
local COLOR_TINT = { r = 0, g = 0, b = 0, a = 0.66 }

local OVERLAY_NAME_SUFFIX = "SHInfoDisplayOverlay"

-- Supported equipment slots
local SLOTS = {
  [1]  = { id = 1,  side = "LEFT",  name = "Head",          canEnchant = true },
  [2]  = { id = 2,  side = "LEFT",  name = "Neck",          canEnchant = false },
  [3]  = { id = 3,  side = "LEFT",  name = "Shoulder",      canEnchant = true },
  [5]  = { id = 5,  side = "LEFT",  name = "Chest",         canEnchant = true },
  [6]  = { id = 6,  side = "RIGHT", name = "Waist",         canEnchant = false },
  [7]  = { id = 7,  side = "RIGHT", name = "Legs",          canEnchant = true },
  [8]  = { id = 8,  side = "RIGHT", name = "Feet",          canEnchant = true },
  [9]  = { id = 9,  side = "LEFT",  name = "Wrist",         canEnchant = false },
  [10] = { id = 10, side = "RIGHT", name = "Hands",         canEnchant = false },
  [11] = { id = 11, side = "RIGHT", name = "Finger0",       canEnchant = true },
  [12] = { id = 12, side = "RIGHT", name = "Finger1",       canEnchant = true },
  [13] = { id = 13, side = "RIGHT", name = "Trinket0",       canEnchant = false },
  [14] = { id = 14, side = "RIGHT", name = "Trinket1",       canEnchant = false },
  [15] = { id = 15, side = "LEFT",  name = "Back",          canEnchant = false },
  [16] = { id = 16, side = "RIGHT", name = "MainHand",      canEnchant = true },
  [17] = { id = 17, side = "LEFT",  name = "SecondaryHand", canEnchant = true },
}

-- Combat rating identifiers
local CR_CRIT = CR_CRIT_MELEE or 9
local CR_HASTE = CR_HASTE_MELEE or 18
local CR_MASTERY = CR_MASTERY or 26
local CR_VERS = CR_VERSATILITY_DAMAGE_DONE or 29
local CR_SPEED = CR_SPEED or 14
local CR_LEECH = CR_LIFESTEAL or 17
local CR_AVOID = CR_AVOIDANCE or 21

local SECONDARY_STATS = {
  { type = "CRIT", cr = CR_CRIT, name = "Critical Strike", suffix = "Crit", order = 1 },
  { type = "HASTE", cr = CR_HASTE, name = "Haste", suffix = "Haste", order = 2 },
  { type = "MASTERY", cr = CR_MASTERY, name = "Mastery", suffix = "Mastery", order = 3 },
  { type = "VERSATILITY", cr = CR_VERS, name = "Versatility", suffix = "Vers", order = 4 },
}

local TERTIARY_STATS = {
  { type = "SPEED", cr = CR_SPEED, name = "Speed", suffix = "Speed", order = 1 },
  { type = "LEECH", cr = CR_LEECH, name = "Leech", suffix = "Leech", order = 2 },
  { type = "AVOIDANCE", cr = CR_AVOID, name = "Avoidance", suffix = "Avoid", order = 3 },
}

-- Map item stat tokens from C_Item.GetItemStats to our internal identifiers
local SECONDARY_STAT_KEYS = {
  ["ITEM_MOD_CRIT_RATING_SHORT"]        = { type = "CRIT", cr = CR_CRIT, name = "Critical Strike", suffix = "Crit", order = 1 },
  ["ITEM_MOD_CRIT_RATING"]              = { type = "CRIT", cr = CR_CRIT, name = "Critical Strike", suffix = "Crit", order = 1 },
  ["ITEM_MOD_CRIT_MELEE_RATING_SHORT"]  = { type = "CRIT", cr = CR_CRIT, name = "Critical Strike", suffix = "Crit", order = 1 },
  ["ITEM_MOD_CRIT_RANGED_RATING_SHORT"] = { type = "CRIT", cr = CR_CRIT, name = "Critical Strike", suffix = "Crit", order = 1 },
  ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"]  = { type = "CRIT", cr = CR_CRIT, name = "Critical Strike", suffix = "Crit", order = 1 },

  ["ITEM_MOD_HASTE_RATING_SHORT"]       = { type = "HASTE", cr = CR_HASTE, name = "Haste", suffix = "Haste", order = 2 },
  ["ITEM_MOD_HASTE_RATING"]             = { type = "HASTE", cr = CR_HASTE, name = "Haste", suffix = "Haste", order = 2 },
  ["ITEM_MOD_HASTE_MELEE_RATING_SHORT"] = { type = "HASTE", cr = CR_HASTE, name = "Haste", suffix = "Haste", order = 2 },
  ["ITEM_MOD_HASTE_RANGED_RATING_SHORT"]= { type = "HASTE", cr = CR_HASTE, name = "Haste", suffix = "Haste", order = 2 },
  ["ITEM_MOD_HASTE_SPELL_RATING_SHORT"] = { type = "HASTE", cr = CR_HASTE, name = "Haste", suffix = "Haste", order = 2 },

  ["ITEM_MOD_MASTERY_RATING_SHORT"]     = { type = "MASTERY", cr = CR_MASTERY, name = "Mastery", suffix = "Mastery", order = 3 },
  ["ITEM_MOD_MASTERY_RATING"]           = { type = "MASTERY", cr = CR_MASTERY, name = "Mastery", suffix = "Mastery", order = 3 },

  ["ITEM_MOD_VERSATILITY"]              = { type = "VERSATILITY", cr = CR_VERS, name = "Versatility", suffix = "Vers", order = 4 },
  ["ITEM_MOD_VERSATILITY_RATING_SHORT"] = { type = "VERSATILITY", cr = CR_VERS, name = "Versatility", suffix = "Vers", order = 4 },
}

local TERTIARY_STAT_KEYS = {
  ["ITEM_MOD_CR_SPEED_SHORT"]     = { type = "SPEED", cr = CR_SPEED, name = "Speed", suffix = "Speed", order = 1 },
  ["ITEM_MOD_CR_SPEED"]           = { type = "SPEED", cr = CR_SPEED, name = "Speed", suffix = "Speed", order = 1 },
  ["ITEM_MOD_CR_LIFESTEAL_SHORT"] = { type = "LEECH", cr = CR_LEECH, name = "Leech", suffix = "Leech", order = 2 },
  ["ITEM_MOD_CR_LIFESTEAL"]       = { type = "LEECH", cr = CR_LEECH, name = "Leech", suffix = "Leech", order = 2 },
  ["ITEM_MOD_CR_AVOIDANCE_SHORT"] = { type = "AVOIDANCE", cr = CR_AVOID, name = "Avoidance", suffix = "Avoid", order = 3 },
  ["ITEM_MOD_CR_AVOIDANCE"]       = { type = "AVOIDANCE", cr = CR_AVOID, name = "Avoidance", suffix = "Avoid", order = 3 },
}

-- Classic / Forever item stat definitions (Strength, Agility, Stamina, Intellect, Spirit, etc.)
local FOREVER_STAT_DEFS = {
  ["ITEM_MOD_STRENGTH_SHORT"]               = { name = "Strength", suffix = "Str", order = 1 },
  ["ITEM_MOD_AGILITY_SHORT"]                = { name = "Agility", suffix = "Agi", order = 2 },
  ["ITEM_MOD_STAMINA_SHORT"]                = { name = "Stamina", suffix = "Stam", order = 3 },
  ["ITEM_MOD_INTELLECT_SHORT"]              = { name = "Intellect", suffix = "Int", order = 4 },
  ["ITEM_MOD_SPIRIT_SHORT"]                 = { name = "Spirit", suffix = "Spi", order = 5 },

  ["ITEM_MOD_SPELL_POWER_SHORT"]            = { name = "Spell Power", suffix = "SP", order = 6 },
  ["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"]      = { name = "Spell Damage", suffix = "Spell Dmg", order = 7 },
  ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]     = { name = "Healing", suffix = "Healing", order = 8 },
  ["ITEM_MOD_ATTACK_POWER_SHORT"]           = { name = "Attack Power", suffix = "AP", order = 9 },
  ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"]    = { name = "Ranged AP", suffix = "RAP", order = 10 },
  ["ITEM_MOD_MANA_REGENERATION_SHORT"]      = { name = "Mana per 5 sec", suffix = "MP5", order = 11 },
  ["ITEM_MOD_HEALTH_REGEN_SHORT"]          = { name = "Health per 5 sec", suffix = "HP5", order = 12 },

  ["ITEM_MOD_HIT_MELEE_RATING_SHORT"]       = { name = "Hit", suffix = "Hit", order = 13 },
  ["ITEM_MOD_HIT_RATING_SHORT"]             = { name = "Hit", suffix = "Hit", order = 13 },
  ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]       = { name = "Spell Hit", suffix = "Spell Hit", order = 14 },
  ["ITEM_MOD_CRIT_MELEE_RATING_SHORT"]      = { name = "Crit", suffix = "Crit", order = 15 },
  ["ITEM_MOD_CRIT_RATING_SHORT"]            = { name = "Crit", suffix = "Crit", order = 15 },
  ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"]      = { name = "Spell Crit", suffix = "Spell Crit", order = 16 },

  ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]   = { name = "Defense", suffix = "Def", order = 17 },
  ["ITEM_MOD_DODGE_RATING_SHORT"]           = { name = "Dodge", suffix = "Dodge", order = 18 },
  ["ITEM_MOD_PARRY_RATING_SHORT"]           = { name = "Parry", suffix = "Parry", order = 19 },
  ["ITEM_MOD_BLOCK_RATING_SHORT"]           = { name = "Block", suffix = "Block", order = 20 },
  ["ITEM_MOD_BLOCK_VALUE_SHORT"]            = { name = "Block Value", suffix = "Block Val", order = 21 },

  ["ITEM_MOD_ARMOR_SHORT"]                  = { name = "Armor", suffix = "Armor", order = 22 },
  ["ITEM_MOD_EXTRA_ARMOR_SHORT"]            = { name = "Bonus Armor", suffix = "Armor", order = 22 },

  ["ITEM_MOD_FIRE_RESISTANCE_SHORT"]        = { name = "Fire Resistance", suffix = "Fire Res", order = 23 },
  ["ITEM_MOD_NATURE_RESISTANCE_SHORT"]      = { name = "Nature Resistance", suffix = "Nature Res", order = 24 },
  ["ITEM_MOD_FROST_RESISTANCE_SHORT"]       = { name = "Frost Resistance", suffix = "Frost Res", order = 25 },
  ["ITEM_MOD_SHADOW_RESISTANCE_SHORT"]      = { name = "Shadow Resistance", suffix = "Shadow Res", order = 26 },
  ["ITEM_MOD_ARCANE_RESISTANCE_SHORT"]      = { name = "Arcane Resistance", suffix = "Arcane Res", order = 27 },
}

-- Known upgrade track name abbreviations
local TRACK_ABBREVIATIONS = {
  ["EXPLORER"]   = "E",
  ["ADVENTURER"] = "A",
  ["VETERAN"]    = "V",
  ["CHAMPION"]   = "C",
  ["HERO"]       = "H",
  ["MYTH"]       = "M",
  ["MYTHIC"]     = "M",
  ["AWAKENED"]   = "Aw",
}

-- Ensure ColorMixin is directly accessible on Self if Blizzard C code rawgets from the caller's fenv
if _G.ColorMixin and not Self.ColorMixin then
  Self.ColorMixin = _G.ColorMixin
end

-- Call C_TooltipInfo from a function explicitly running in _G to ensure mixin resolution succeeds in the C engine
local getInventoryTooltipData = setfenv(function(unitId, slotId)
  if _G.C_TooltipInfo and _G.C_TooltipInfo.GetInventoryItem then
    return _G.C_TooltipInfo.GetInventoryItem(unitId, slotId)
  end
end, _G)

local function safeGetInventoryTooltipData(unitId, slotId)
  local ok, data = pcall(getInventoryTooltipData, unitId, slotId)
  if ok and data then
    return data
  end
  return nil
end

local getHyperlinkTooltipData = setfenv(function(link)
  if _G.C_TooltipInfo and _G.C_TooltipInfo.GetHyperlink then
    return _G.C_TooltipInfo.GetHyperlink(link)
  end
end, _G)

local function safeGetHyperlinkTooltipData(link)
  local ok, data = pcall(getHyperlinkTooltipData, link)
  if ok and data then
    return data
  end
  return nil
end

local scanTooltip = CreateFrame("GameTooltip", "SlackHacksInfoDisplayScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function scanInventoryItemLines(unitId, slotId)
  local lines = {}
  local ok = pcall(function()
    scanTooltip:ClearLines()
    scanTooltip:SetInventoryItem(unitId, slotId)
    for i = 1, scanTooltip:NumLines() do
      local fs = _G["SlackHacksInfoDisplayScanTooltipTextLeft" .. i]
      if fs then
        local text = fs:GetText()
        if text and text ~= "" then
          table.insert(lines, text)
        end
      end
    end
  end)
  if not ok then return {} end
  return lines
end

-- Cache created overlay frames so we can hide/show them on module toggle
local createdOverlays = {}

--- Returns whether the InfoDisplay module is enabled in profile settings.
---@return boolean
local function isModuleEnabled()
  return (db and db.profile and db.profile.infoDisplay and db.profile.infoDisplay.enabled) and module:IsEnabled()
end

--- Returns the active profile charSheet settings.
---@return table
local function charSheetSettings()
  if db and db.profile and db.profile.infoDisplay and db.profile.infoDisplay.charSheet then
    return db.profile.infoDisplay.charSheet
  end
  return {
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
end

--- Get quality color table by quality index.
---@param quality number
---@return table
local function getQualityColor(quality)
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
    local c = ITEM_QUALITY_COLORS[quality]
    return { r = c.r, g = c.g, b = c.b, a = 1 }
  end
  if quality == 1 then return COLOR_WHITE
  elseif quality == 2 then return { r = 0.12, g = 1, b = 0, a = 1 }
  elseif quality == 3 then return { r = 0, g = 0.44, b = 0.87, a = 1 }
  elseif quality == 4 then return { r = 0.64, g = 0.21, b = 0.93, a = 1 }
  elseif quality == 5 then return { r = 1, g = 0.50, b = 0, a = 1 }
  elseif quality == 6 then return { r = 0.90, g = 0.80, b = 0.50, a = 1 }
  end
  return COLOR_WHITE
end

--- Returns item level display color:
--- - In Retail (isRetail): Uses high watermark brackets (White <266, Green 266-276, Blue 279-289, Purple 292-302, Orange 305-315, Golden 318+)
--- - In Forever (isForever / Classic): Uses the item's native quality color (Common, Uncommon, Rare, Epic, Legendary).
---@param itemLevel number|nil
---@param itemQuality number|nil
---@return table
local function getWatermarkColor(itemLevel, itemQuality)
  if isRetail() then
    if not isCleanNumber(itemLevel) or itemLevel < 266 then
      return getQualityColor(1) -- White (Common)
    elseif itemLevel < 279 then
      return getQualityColor(2) -- Green (Uncommon)
    elseif itemLevel < 292 then
      return getQualityColor(3) -- Blue (Rare)
    elseif itemLevel < 305 then
      return getQualityColor(4) -- Purple (Epic)
    elseif itemLevel < 318 then
      return getQualityColor(5) -- Orange (Legendary)
    else
      return getQualityColor(6) -- Golden (Artifact)
    end
  else
    return getQualityColor(isCleanNumber(itemQuality) and itemQuality or 1)
  end
end

local SLOT_TO_INVTYPE = {
  [1]  = "INVTYPE_HEAD",
  [2]  = "INVTYPE_NECK",
  [3]  = "INVTYPE_SHOULDER",
  [5]  = "INVTYPE_CHEST",
  [6]  = "INVTYPE_WAIST",
  [7]  = "INVTYPE_LEGS",
  [8]  = "INVTYPE_FEET",
  [9]  = "INVTYPE_WRIST",
  [10] = "INVTYPE_HAND",
  [11] = "INVTYPE_FINGER",
  [12] = "INVTYPE_FINGER",
  [13] = "INVTYPE_TRINKET",
  [14] = "INVTYPE_TRINKET",
  [15] = "INVTYPE_CLOAK",
  [16] = "INVTYPE_WEAPON",
  [17] = "INVTYPE_SHIELD",
}

--- Retrieves the high watermark item level for an equipment slot in Retail.
--- Queries C_ItemUpgrade APIs, falling back to equipped item level if higher.
---@param unitId string "player" | "target"
---@param slotId number Equipment slot ID
---@param itemLink string|nil Equipped item link
---@param equippedItemLevel number|nil Equipped item level
---@return number|nil watermarkIlevel
local function getSlotHighWatermark(unitId, slotId, itemLink, equippedItemLevel)
  if not isRetail() or unitId ~= "player" then return nil end

  local watermark = nil

  if C_ItemUpgrade then
    -- Method 1: C_ItemUpgrade.GetHighWatermarkForItem(itemLink)
    if itemLink and C_ItemUpgrade.GetHighWatermarkForItem then
      local ok, val = pcall(C_ItemUpgrade.GetHighWatermarkForItem, itemLink)
      if ok and isCleanNumber(val) and val > 0 then
        watermark = val
      end
    end

    -- Method 2: C_ItemUpgrade.GetItemHyperlinkHighWatermark(itemLink)
    if not watermark and itemLink and C_ItemUpgrade.GetItemHyperlinkHighWatermark then
      local ok, val = pcall(C_ItemUpgrade.GetItemHyperlinkHighWatermark, itemLink)
      if ok and isCleanNumber(val) and val > 0 then
        watermark = val
      end
    end

    -- Method 3: C_ItemUpgrade.GetHighWatermarkForSlot(slot)
    if not watermark and C_ItemUpgrade.GetHighWatermarkForSlot then
      local ok, val = pcall(C_ItemUpgrade.GetHighWatermarkForSlot, slotId)
      if ok and isCleanNumber(val) and val > 0 then
        watermark = val
      end

      if not watermark and C_ItemUpgrade.GetHighWatermarkSlotForInventoryType then
        local invType = nil
        if itemLink and C_Item and C_Item.GetItemInfo then
          invType = select(9, C_Item.GetItemInfo(itemLink))
        end
        if not invType and GetItemInfo and itemLink then
          invType = select(9, GetItemInfo(itemLink))
        end
        if not invType then
          invType = SLOT_TO_INVTYPE[slotId]
        end
        if invType then
          local okSlot, hwSlot = pcall(C_ItemUpgrade.GetHighWatermarkSlotForInventoryType, invType)
          if okSlot and hwSlot then
            local okVal, val2 = pcall(C_ItemUpgrade.GetHighWatermarkForSlot, hwSlot)
            if okVal and isCleanNumber(val2) and val2 > 0 then
              watermark = val2
            end
          end
        end
      end
    end
  end

  -- A slot's watermark can never be lower than the currently equipped item level
  if isCleanNumber(equippedItemLevel) and equippedItemLevel > 0 then
    if not isCleanNumber(watermark) or equippedItemLevel > watermark then
      watermark = equippedItemLevel
    end
  end

  return watermark
end

--- Derives a short track abbreviation (e.g. "Champion" -> "C").
--- Returns nil if the name is not a recognized upgrade track.
---@param trackName string
---@return string|nil
local function getTrackAbbreviation(trackName)
  if not trackName or trackName == "" then return nil end
  local upper = trackName:upper()
  for name, abbrev in pairs(TRACK_ABBREVIATIONS) do
    if upper:find(name, 1, true) then
      return abbrev
    end
  end
  return nil
end

--- Helper to group related stat keys or text into canonical internal types.
---@param key string
---@return string|nil
local function getStatGroup(key)
  if not key then return nil end
  local upper = key:upper()
  if upper:find("CRIT") then return "CRIT"
  elseif upper:find("HASTE") then return "HASTE"
  elseif upper:find("MASTERY") then return "MASTERY"
  elseif upper:find("VERSATILITY") or upper:find("VERS") then return "VERSATILITY"
  elseif upper:find("SPEED") then return "SPEED"
  elseif upper:find("LIFESTEAL") or upper:find("LEECH") then return "LEECH"
  elseif upper:find("AVOIDANCE") or upper:find("AVOID") then return "AVOIDANCE"
  elseif upper:find("PRIMARY") then return "PRIMARY"
  elseif upper:find("STRENGTH") or upper:find("STR") then return "STRENGTH"
  elseif upper:find("AGILITY") or upper:find("AGI") then return "AGILITY"
  elseif upper:find("INTELLECT") or upper:find("INT") then return "INTELLECT"
  elseif upper:find("STAMINA") or upper:find("STAM") then return "STAMINA"
  elseif upper:find("SPIRIT") or upper:find("SPI") then return "SPIRIT"
  elseif upper:find("ARMOR") then return "ARMOR"
  elseif upper:find("DEFENSE") then return "DEFENSE"
  elseif upper:find("DODGE") then return "DODGE"
  elseif upper:find("PARRY") then return "PARRY"
  elseif upper:find("BLOCK VALUE") then return "BLOCK_VALUE"
  elseif upper:find("BLOCK") then return "BLOCK"
  elseif upper:find("SPELL POWER") or upper:find("SPELL DAMAGE") or upper:find("HEALING") then return "SPELL_POWER"
  elseif upper:find("ATTACK POWER") or upper:find("RAP") then return "ATTACK_POWER"
  elseif upper:find("MANA PER 5") or upper:find("MP5") then return "MANA_REGEN"
  elseif upper:find("HEALTH PER 5") or upper:find("HP5") then return "HEALTH_REGEN"
  elseif upper:find("HIT") then return "HIT"
  end
  return key
end

--- Retrieves the player's primary stat token and localized display name.
---@return string statKey "STRENGTH" | "AGILITY" | "INTELLECT" | "PRIMARY"
---@return string statName "Strength" | "Agility" | "Intellect" | "Primary Stat"
---@return string statSuffix "Str" | "Agi" | "Int" | "Primary"
local function getPlayerPrimaryStat()
  if GetSpecialization and GetSpecializationInfo then
    local spec = GetSpecialization()
    if spec and spec > 0 then
      local _, _, _, _, _, primaryStatID = GetSpecializationInfo(spec)
      if primaryStatID == 1 then return "STRENGTH", "Strength", "Str"
      elseif primaryStatID == 2 then return "AGILITY", "Agility", "Agi"
      elseif primaryStatID == 4 then return "INTELLECT", "Intellect", "Int"
      end
    end
  end
  if UnitStat then
    local str = select(2, UnitStat("player", 1)) or 0
    local agi = select(2, UnitStat("player", 2)) or 0
    local int = select(2, UnitStat("player", 4)) or 0
    if str > agi and str > int then return "STRENGTH", "Strength", "Str"
    elseif agi > str and agi > int then return "AGILITY", "Agility", "Agi"
    elseif int > str and int > agi then return "INTELLECT", "Intellect", "Int"
    end
  end
  return "PRIMARY", "Primary Stat", "Primary"
end

-- Known enchant definitions for War Within & Midnight when tooltip lines omit explicit numbers
local KNOWN_ENCHANTS = {
  -- Ring Enchants
  { pattern = "radiant%s+haste", stats = { HASTE = 315 }, text = "+315 Haste" },
  { pattern = "radiant%s+crit", stats = { CRIT = 315 }, text = "+315 Crit" },
  { pattern = "radiant%s+mastery", stats = { MASTERY = 315 }, text = "+315 Mastery" },
  { pattern = "radiant%s+vers", stats = { VERSATILITY = 315 }, text = "+315 Vers" },
  { pattern = "cursed%s+haste", stats = { HASTE = 375, AVOIDANCE = -150 }, text = "+375 Haste" },
  { pattern = "cursed%s+crit", stats = { CRIT = 375, LEECH = -150 }, text = "+375 Crit" },
  { pattern = "cursed%s+mastery", stats = { MASTERY = 375, SPEED = -150 }, text = "+375 Mastery" },
  { pattern = "cursed%s+vers", stats = { VERSATILITY = 375, SPEED = -150 }, text = "+375 Vers" },
  { pattern = "glimmering%s+haste", stats = { HASTE = 220 }, text = "+220 Haste" },
  { pattern = "glimmering%s+crit", stats = { CRIT = 220 }, text = "+220 Crit" },
  { pattern = "glimmering%s+mastery", stats = { MASTERY = 220 }, text = "+220 Mastery" },
  { pattern = "glimmering%s+vers", stats = { VERSATILITY = 220 }, text = "+220 Vers" },
  { pattern = "silvermoon's%s+alacrity", stats = { HASTE = 315 }, text = "+315 Haste" },
  { pattern = "silvermoon's%s+tenacity", stats = { VERSATILITY = 315 }, text = "+315 Vers" },
  { pattern = "nature's%s+fury", stats = { CRIT = 315 }, text = "+315 Crit" },
  { pattern = "eyes%s+of%s+the%s+eagle", stats = { CRIT = 315 }, text = "+315 Crit" },
  { pattern = "zul'jin's%s+mastery", stats = { MASTERY = 315 }, text = "+315 Mastery" },

  -- Chest Enchants
  { pattern = "crystalline%s+radiance", stats = { PRIMARY = 605 }, text = "+605 Primary" },
  { pattern = "mark%s+of%s+the%s+worldsoul", stats = { PRIMARY = 50 }, text = "+50 Primary" },
  { pattern = "mark%s+of%s+the%s+magister", stats = { PRIMARY = 50 }, text = "+50 Primary" },
  { pattern = "council's%s+intellect", stats = { INTELLECT = 450 }, text = "+450 Int" },
  { pattern = "stormrider's%s+agility", stats = { AGILITY = 450 }, text = "+450 Agi" },

  -- Boots Enchants
  { pattern = "scout's%s+march", stats = { SPEED = 250 }, text = "+250 Speed" },
  { pattern = "defender's%s+march", stats = { SPEED = 250, STAMINA = 1150 }, text = "+250 Speed" },
  { pattern = "cavalry's%s+march", stats = { SPEED = 250 }, text = "+250 Speed" },
  { pattern = "lynx's%s+dexterity", stats = { SPEED = 250 }, text = "+250 Speed" },
  { pattern = "shaladrassil's%s+roots", stats = { SPEED = 250 }, text = "+250 Speed" },
  { pattern = "farstrider's%s+hunt", stats = { SPEED = 250 }, text = "+250 Speed" },

  -- Cloak Enchants
  { pattern = "winged%s+grace", stats = { AVOIDANCE = 125, SPEED = 125 }, text = "+125 Avoid / +125 Speed" },
  { pattern = "leeching%s+fangs", stats = { LEECH = 250 }, text = "+250 Leech" },
  { pattern = "silken%s+avoidance", stats = { AVOIDANCE = 250 }, text = "+250 Avoid" },
  { pattern = "empowered%s+blessing%s+of%s+speed", stats = { SPEED = 250 }, text = "+250 Speed" },
  { pattern = "empowered%s+hex%s+of%s+leeching", stats = { LEECH = 250 }, text = "+250 Leech" },
  { pattern = "empowered%s+rune%s+of%s+avoidance", stats = { AVOIDANCE = 250 }, text = "+250 Avoid" },

  -- Wrist Enchants
  { pattern = "armored%s+avoidance", stats = { AVOIDANCE = 200, ARMOR = 250 }, text = "+200 Avoid" },
  { pattern = "armored%s+speed", stats = { SPEED = 200, ARMOR = 250 }, text = "+200 Speed" },
  { pattern = "armored%s+leech", stats = { LEECH = 200, ARMOR = 250 }, text = "+200 Leech" },

  -- Leg Enhancements (Spellthreads & Armor Kits)
  { pattern = "sunfire%s+silk%s+spellthread", stats = { INTELLECT = 450, STAMINA = 1150 }, text = "+450 Int / +1150 Stam" },
  { pattern = "sunset%s+spellthread", stats = { INTELLECT = 450, STAMINA = 1150 }, text = "+450 Int / +1150 Stam" },
  { pattern = "daybreak%s+spellthread", stats = { INTELLECT = 450, STAMINA = 1150 }, text = "+450 Int / +1150 Stam" },
  { pattern = "arcanoweave%s+spellthread", stats = { INTELLECT = 325, STAMINA = 850 }, text = "+325 Int / +850 Stam" },
  { pattern = "dual%s+flocked%s+spellthread", stats = { INTELLECT = 325, STAMINA = 850 }, text = "+325 Int / +850 Stam" },
  { pattern = "forest%s+hunter's%s+armor%s+kit", stats = { PRIMARY = 450, STAMINA = 1150 }, text = "+450 Primary / +1150 Stam" },
  { pattern = "blood%s+knight's%s+armor%s+kit", stats = { PRIMARY = 450, STAMINA = 1150 }, text = "+450 Primary / +1150 Stam" },
  { pattern = "stormbound%s+armor%s+kit", stats = { PRIMARY = 450, STAMINA = 1150 }, text = "+450 Primary / +1150 Stam" },

  -- Shoulder Enchants
  { pattern = "akil'zon's%s+swiftness", stats = { SPEED = 250 }, text = "+250 Speed" },
  { pattern = "amirdrassil's%s+grace", stats = { AVOIDANCE = 250 }, text = "+250 Avoid" },
  { pattern = "silvermoon's%s+mending", stats = { LEECH = 250 }, text = "+250 Leech" },
  { pattern = "flight%s+of%s+the%s+eagle", stats = { AVOIDANCE = 250 }, text = "+250 Avoid" },
}

--- Parses numeric stat grants from arbitrary text strings (such as enchant or gem lines).
--- Accurately handles multi-stat lines (e.g. "+147 Critical Strike and +98 Haste", "+70 Speed and +35 Leech").
---@param rawText string
---@return table stats Table mapping canonical stat group to integer value
local function parseStatsFromText(rawText)
  local stats = {}
  if not rawText or rawText == "" then return stats end

  -- Strip formatting codes, textures, and hyperlinks
  local clean = rawText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  clean = clean:gsub("|A:[^|]+|a", ""):gsub("|T[^|]+|t", "")
  clean = clean:gsub("|H.-|h(.-)|h", "%1")
  clean = clean:gsub("(%d+),(%d+)", "%1%2"):gsub("(%d+),(%d+)", "%1%2")

  -- Normalize non-breaking spaces, conjunctions, and delimiters to commas
  clean = clean:gsub("\194\160", " "):gsub("\160", " ")
  clean = clean:gsub("%s+and%s+", ", ")
  clean = clean:gsub("%s*&%s*", ", ")
  clean = clean:gsub("%s*[/\\|]%s*", ", ")
  clean = clean:gsub("([%a%)%.])%s*([%+%-]%s*%d+)", "%1, %2")

  local function addParsedStat(sign, numStr, statStr)
    if not numStr or not statStr then return end
    statStr = statStr:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+and%s*$", ""):gsub("%s+or%s*$", "")
    if statStr:match("^%%") or statStr:match("^percent") then return end

    local num = tonumber(numStr)
    if sign == "-" then num = -num end
    if num and num ~= 0 then
      local upperStat = statStr:upper()
      if upperStat:find("ALL STATS") or upperStat:find("TO ALL STATS") then
        stats["STRENGTH"] = (stats["STRENGTH"] or 0) + num
        stats["AGILITY"] = (stats["AGILITY"] or 0) + num
        stats["INTELLECT"] = (stats["INTELLECT"] or 0) + num
        stats["STAMINA"] = (stats["STAMINA"] or 0) + num
      elseif upperStat:find("PRIMARY") then
        stats["PRIMARY"] = (stats["PRIMARY"] or 0) + num
      else
        local group = getStatGroup(statStr)
        if group then
          stats[group] = (stats[group] or 0) + num
        end
      end
    end
  end

  for chunk in clean:gmatch("[^,;\n]+") do
    chunk = chunk:gsub("^%s+", ""):gsub("%s+$", "")
    if chunk ~= "" and not chunk:match("%d+%%") then
      local sign, numStr, statStr = chunk:match("^([%+%-]?)(%d+)%s+(.-)$")
      if not numStr then
        statStr, sign, numStr = chunk:match("^(.-)%s+by%s+([%+%-]?)(%d+)")
      end
      if not numStr then
        statStr, sign, numStr = chunk:match("^(.-)%s+([%+%-]?)(%d+)%s*$")
      end

      if numStr and statStr then
        addParsedStat(sign, numStr, statStr)
      end
    end
  end

  -- Fallback scan to capture any remaining (number, stat) pairs
  if not next(stats) then
    for sign, numStr, statStr in clean:gmatch("([%+%-]?)(%d+)%s+([%a%s]+)") do
      addParsedStat(sign, numStr, statStr)
    end
  end

  return stats
end

-- ============================================================================
-- Diminishing Returns and Stat Percentage Calculations
-- ============================================================================

--- Calculates effective secondary stat percentage after diminishing returns penalties.
--- Tiers for rating-derived percentage:
--- 0% - 30%: 0% penalty (100% effectiveness)
--- 30% - 39%: 10% penalty (90% effectiveness)
--- 39% - 47%: 20% penalty (80% effectiveness)
--- 47% - 54%: 30% penalty (70% effectiveness)
--- 54% - 66%: 40% penalty (60% effectiveness)
--- 66% - 126%: 50% penalty (50% effectiveness)
--- > 126%: 100% penalty (0% effectiveness)
---@param B number Un-diminished percentage from rating
---@return number D Diminished effective percentage
local function calculateSecondaryDiminishedPercent(B)
  if not isCleanNumber(B) or B <= 0 then return 0 end
  if B <= 30 then
    return B
  elseif B <= 39 then
    return 30 + (B - 30) * 0.9
  elseif B <= 47 then
    return 38.1 + (B - 39) * 0.8
  elseif B <= 54 then
    return 44.5 + (B - 47) * 0.7
  elseif B <= 66 then
    return 49.4 + (B - 54) * 0.6
  elseif B <= 126 then
    return 56.6 + (B - 66) * 0.5
  else
    return 86.6
  end
end

--- Inverts the secondary stat diminishing returns piecewise linear function to recover
--- the un-diminished rating percentage B from effective bonus D.
---@param D number Diminished effective percentage
---@return number B Un-diminished percentage
local function undiminishSecondaryPercent(D)
  if not isCleanNumber(D) or D <= 0 then return 0 end
  if D <= 30 then
    return D
  elseif D <= 38.1 then
    return 30 + (D - 30) / 0.9
  elseif D <= 44.5 then
    return 39 + (D - 38.1) / 0.8
  elseif D <= 49.4 then
    return 47 + (D - 44.5) / 0.7
  elseif D <= 56.6 then
    return 54 + (D - 49.4) / 0.6
  elseif D <= 86.6 then
    return 66 + (D - 56.6) / 0.5
  else
    return 126
  end
end

--- Computes the base rating required per 1% un-diminished stat at the player's level.
---@param crId number Combat rating ID
---@return number ratingPerPercent
local function getRatingPerPercent(crId)
  local currentRating = GetCombatRating and GetCombatRating(crId)
  local currentBonus = GetCombatRatingBonus and GetCombatRatingBonus(crId)

  if isCleanNumber(currentRating) and isCleanNumber(currentBonus) and currentRating > 0 and currentBonus > 0 then
    local unDiminishedBonus = undiminishSecondaryPercent(currentBonus)
    if isCleanNumber(unDiminishedBonus) and unDiminishedBonus > 0 then
      return currentRating / unDiminishedBonus
    end
  end

  -- Fallback level scaling (scaled to level 80 baseline)
  local rawLevel = UnitLevel and UnitLevel("player")
  local playerLevel = (isCleanNumber(rawLevel) and rawLevel > 0) and rawLevel or 80
  local levelScale = playerLevel / 80
  if crId == CR_CRIT then return 700 * levelScale
  elseif crId == CR_HASTE then return 660 * levelScale
  elseif crId == CR_MASTERY then return 700 * levelScale
  elseif crId == CR_VERS then return 780 * levelScale
  elseif crId == CR_SPEED then return 500 * levelScale
  elseif crId == CR_LEECH then return 450 * levelScale
  elseif crId == CR_AVOID then return 450 * levelScale
  end
  return 700 * levelScale
end

--- Calculates the marginal stat percentage increase provided by this item's rating,
--- accounting for current equipped total rating and diminishing returns.
---@param crId number Combat rating ID
---@param itemStatRating number Rating amount on item
---@return number pctIncrease
local function calculateSecondaryStatIncrease(crId, itemStatRating)
  if not itemStatRating or itemStatRating <= 0 then return 0 end

  local k = getRatingPerPercent(crId)
  if not isCleanNumber(k) or k <= 0 then return 0 end

  local currentRating = GetCombatRating and GetCombatRating(crId)
  local pctIncrease
  if isCleanNumber(currentRating) and currentRating > 0 and currentRating >= itemStatRating then
    local ratingWithoutItem = currentRating - itemStatRating
    local B_total = currentRating / k
    local B_base = ratingWithoutItem / k
    local D_total = calculateSecondaryDiminishedPercent(B_total)
    local D_base = calculateSecondaryDiminishedPercent(B_base)
    pctIncrease = math.max(0, D_total - D_base)
  else
    local B = itemStatRating / k
    pctIncrease = calculateSecondaryDiminishedPercent(B)
  end

  -- For Mastery, multiply by the active specialization's mastery coefficient
  if crId == CR_MASTERY and GetMasteryEffect then
    local ok, _, bonusCoeff = pcall(GetMasteryEffect)
    if ok and isCleanNumber(bonusCoeff) and bonusCoeff > 0 then
      pctIncrease = pctIncrease * bonusCoeff
    end
  end

  return pctIncrease
end

--- Calculates tertiary stat percentage with diminishing returns penalties.
--- Leech: 0-10% no penalty, >10% 50% penalty
--- Avoidance: 0-8% no penalty, >8% 50% penalty
--- Speed: 100% effectiveness
---@param statType string
---@param B number
---@return number D
local function calculateTertiaryDiminishedPercent(statType, B)
  if not isCleanNumber(B) or B <= 0 then return 0 end
  if statType == "LEECH" then
    if B <= 10 then return B else return 10 + (B - 10) * 0.5 end
  elseif statType == "AVOIDANCE" then
    if B <= 8 then return B else return 8 + (B - 8) * 0.5 end
  else
    return B
  end
end

--- Calculates the marginal percentage increase for a tertiary stat.
---@param statType string "SPEED" | "LEECH" | "AVOIDANCE"
---@param crId number
---@param itemStatRating number
---@return number pctIncrease
local function calculateTertiaryStatIncrease(statType, crId, itemStatRating)
  if not itemStatRating or itemStatRating <= 0 then return 0 end

  local currentRating = GetCombatRating and GetCombatRating(crId)
  local currentBonus = GetCombatRatingBonus and GetCombatRatingBonus(crId)

  local k
  if isCleanNumber(currentRating) and isCleanNumber(currentBonus) and currentRating > 0 and currentBonus > 0 then
    k = currentRating / currentBonus
  else
    local rawLevel = UnitLevel and UnitLevel("player")
    local playerLevel = (isCleanNumber(rawLevel) and rawLevel > 0) and rawLevel or 80
    local levelScale = playerLevel / 80
    if statType == "SPEED" then k = 500 * levelScale
    elseif statType == "LEECH" then k = 450 * levelScale
    elseif statType == "AVOIDANCE" then k = 450 * levelScale
    else k = 500 * levelScale end
  end

  if not isCleanNumber(k) or k <= 0 then return 0 end

  local pctIncrease
  if isCleanNumber(currentRating) and currentRating > 0 and currentRating >= itemStatRating then
    local ratingWithoutItem = currentRating - itemStatRating
    local B_total = currentRating / k
    local B_base = ratingWithoutItem / k
    local D_total = calculateTertiaryDiminishedPercent(statType, B_total)
    local D_base = calculateTertiaryDiminishedPercent(statType, B_base)
    pctIncrease = math.max(0, D_total - D_base)
  else
    local B = itemStatRating / k
    pctIncrease = calculateTertiaryDiminishedPercent(statType, B)
  end

  return pctIncrease
end

--- Formats an enchantment string to show its stat values (e.g. "+29 Haste", "+50 Primary")
--- or effect name if it's a non-stat proc/effect.
---@param itemLink string Full item link
---@param rawEnchantText string Text extracted from tooltip enchant line
---@param enchantAtlas string|nil Optional quality tier atlas icon
---@param slotId number Equipment slot ID
---@param enchantBuckets table|nil Optional pre-calculated enchant stat buckets
---@return string
local function getEnchantDisplayText(itemLink, rawEnchantText, enchantAtlas, slotId, enchantBuckets)
  if not rawEnchantText or rawEnchantText == "" then return "" end

  local atlas = enchantAtlas
  if not atlas or atlas == "" then
    atlas = rawEnchantText:match("|A:([^:]+)")
  end

  local cleanText = rawEnchantText:gsub("|A:[^|]+|a", ""):gsub("|T[^|]+|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")

  -- If raw text already has "+123 Stat" format, use it directly
  local sign, num, stat = cleanText:match("^([%+%-]?)(%d+)%s+(.+)$")
  if num and stat then
    local formatted = (sign == "-" and "-" or "+") .. num .. " " .. stat
    if atlas and atlas ~= "" then
      return "|A:" .. atlas .. ":12:12|a " .. formatted
    end
    return formatted
  end

  -- If enchantBuckets has calculated stats, format cleanly from stats
  if enchantBuckets and next(enchantBuckets) then
    local parts = {}
    if enchantBuckets["PRIMARY"] then table.insert(parts, string.format("+%d Primary", enchantBuckets["PRIMARY"])) end
    if enchantBuckets["STRENGTH"] then table.insert(parts, string.format("+%d Str", enchantBuckets["STRENGTH"])) end
    if enchantBuckets["AGILITY"] then table.insert(parts, string.format("+%d Agi", enchantBuckets["AGILITY"])) end
    if enchantBuckets["INTELLECT"] then table.insert(parts, string.format("+%d Int", enchantBuckets["INTELLECT"])) end
    if enchantBuckets["CRIT"] then table.insert(parts, string.format("+%d Crit", enchantBuckets["CRIT"])) end
    if enchantBuckets["HASTE"] then table.insert(parts, string.format("+%d Haste", enchantBuckets["HASTE"])) end
    if enchantBuckets["MASTERY"] then table.insert(parts, string.format("+%d Mastery", enchantBuckets["MASTERY"])) end
    if enchantBuckets["VERSATILITY"] then table.insert(parts, string.format("+%d Vers", enchantBuckets["VERSATILITY"])) end
    if enchantBuckets["SPEED"] then table.insert(parts, string.format("+%d Speed", enchantBuckets["SPEED"])) end
    if enchantBuckets["LEECH"] then table.insert(parts, string.format("+%d Leech", enchantBuckets["LEECH"])) end
    if enchantBuckets["AVOIDANCE"] then table.insert(parts, string.format("+%d Avoid", enchantBuckets["AVOIDANCE"])) end
    if #parts > 0 then
      local formatted = table.concat(parts, " / ")
      if atlas and atlas ~= "" then
        return "|A:" .. atlas .. ":12:12|a " .. formatted
      end
      return formatted
    end
  end

  local lower = cleanText:lower()
  for _, ke in ipairs(KNOWN_ENCHANTS) do
    if lower:find(ke.pattern) then
      if atlas and atlas ~= "" then
        return "|A:" .. atlas .. ":12:12|a " .. ke.text
      end
      return ke.text
    end
  end

  local cleaned = cleanText:gsub("^Enchant%s+[%a%s]+%s*-%s*", "")
  cleaned = cleaned:gsub("^Enchant%s*-%s*", "")

  if atlas and atlas ~= "" then
    return "|A:" .. atlas .. ":12:12|a " .. cleaned
  end
  return cleaned
end

--- Returns whether a slot can be enchanted in the current client expansion.
--- In modern retail, bracers (slot 9) and cloak/back (slot 15) do not have enchants.
--- In Forever / Classic, bracers and cloak can be enchanted.
---@param slot table
---@return boolean
local function canSlotEnchant(slot)
  if not slot then return false end
  if slot.id == 9 or slot.id == 15 then
    return not isRetail()
  end
  return slot.canEnchant == true
end

-- ============================================================================
-- Slot Overlay Creation & UI Management
-- ============================================================================

--- Creates or retrieves the slot overlay frame attached to a character/inspect slot frame.
---@param characterSlotFrame Button
---@param slot table
---@return Frame slotOverlay
local function getOrCreateSlotOverlay(characterSlotFrame, slot)
  local frameName = characterSlotFrame:GetName() .. OVERLAY_NAME_SUFFIX
  local slotOverlay = characterSlotFrame[OVERLAY_NAME_SUFFIX]
  if not slotOverlay then
    slotOverlay = CreateFrame("Frame", frameName, characterSlotFrame)
    characterSlotFrame[OVERLAY_NAME_SUFFIX] = slotOverlay
    table.insert(createdOverlays, slotOverlay)

    slotOverlay:SetAllPoints(characterSlotFrame)
    slotOverlay:SetFrameLevel(characterSlotFrame:GetFrameLevel() + 5)

    -- Subtle dark background tint on icon
    local tint = slotOverlay:CreateTexture(nil, "BACKGROUND")
    tint:SetTexture("Interface\\TutorialFrame\\TutorialFrameBackground")
    tint:SetColorTexture(COLOR_TINT.r, COLOR_TINT.g, COLOR_TINT.b, COLOR_TINT.a)
    tint:SetAllPoints(slotOverlay)
    slotOverlay.Tint = tint

    -- Item Level: center of icon
    local level = slotOverlay:CreateFontString(frameName .. "Level", "OVERLAY", "GameTooltipText")
    level:SetPoint("CENTER", slotOverlay, "CENTER", 0, 0)
    level:SetFont(DEFAULT_FONT, FONT_SIZE_LEVEL, FONT_OUTLINE)
    level:SetJustifyH("CENTER")
    slotOverlay.Level = level

    -- Upgrade Track: anchored underneath centered to item level
    local track = slotOverlay:CreateFontString(frameName .. "Track", "OVERLAY", "GameTooltipText")
    track:SetPoint("TOP", level, "BOTTOM", 0, -1)
    track:SetFont(DEFAULT_FONT, FONT_SIZE_TRACK, FONT_OUTLINE)
    track:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
    track:SetJustifyH("CENTER")
    track:Hide()
    slotOverlay.Track = track

    -- Side Summary Frame: sits off to the side where enchants and gems display
    local isBottomSlot = (slot.id == 16 or slot.id == 17)
    local relativePoint = slot.side == "LEFT" and "RIGHT" or "LEFT"
    local offsetX = slot.side == "LEFT" and 8 or -8

    local sideSummaryPoint, slotPoint
    if isBottomSlot then
      sideSummaryPoint = slot.side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT"
      slotPoint = slot.side == "LEFT" and "BOTTOMRIGHT" or "BOTTOMLEFT"
    else
      sideSummaryPoint = slot.side
      slotPoint = relativePoint
    end

    local sideSummary = CreateFrame("Frame", frameName .. "SideSummary", slotOverlay)
    sideSummary:SetSize(90, 37)
    sideSummary:SetPoint(sideSummaryPoint, slotOverlay, slotPoint, offsetX, 0)
    sideSummary:EnableMouse(true)
    sideSummary:SetFrameLevel(slotOverlay:GetFrameLevel() + 10)
    slotOverlay.SideSummary = sideSummary

    -- Watermark item level at the top of side summary
    local watermarkText = sideSummary:CreateFontString(frameName .. "Watermark", "OVERLAY", "GameTooltipText")
    watermarkText:SetFont(DEFAULT_FONT, FONT_SIZE_WATERMARK, FONT_OUTLINE)
    watermarkText:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
    watermarkText:SetJustifyH(slot.side == "RIGHT" and "RIGHT" or "LEFT")
    sideSummary.WatermarkText = watermarkText

    -- Stats summary font string (multi-line)
    local statsText = sideSummary:CreateFontString(frameName .. "SideStats", "OVERLAY", "GameTooltipText")
    statsText:SetFont(getStatsFont(), FONT_SIZE_STATS, FONT_OUTLINE)
    statsText:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
    statsText:SetJustifyH(slot.side == "RIGHT" and "RIGHT" or "LEFT")
    statsText:SetJustifyV("TOP")
    sideSummary.StatsText = statsText

    -- Missing Enchant alert icon
    local missingEnchant = CreateFrame("Button", frameName .. "MissingEnchant", sideSummary)
    missingEnchant:SetSize(14, 14)
    missingEnchant:EnableMouse(true)
    missingEnchant:SetFrameLevel(sideSummary:GetFrameLevel() + 2)
    local meIcon = missingEnchant:CreateTexture(nil, "ARTWORK")
    meIcon:SetAllPoints()
    meIcon:SetTexture("Interface\\Icons\\inv_misc_enchantedscroll")
    meIcon:SetVertexColor(1, 0.25, 0.25)
    missingEnchant.Icon = meIcon
    sideSummary.MissingEnchant = missingEnchant

    -- Missing Gem alert icon
    local missingGem = CreateFrame("Button", frameName .. "MissingGem", sideSummary)
    missingGem:SetSize(14, 14)
    missingGem:EnableMouse(true)
    missingGem:SetFrameLevel(sideSummary:GetFrameLevel() + 2)
    local mgIcon = missingGem:CreateTexture(nil, "ARTWORK")
    mgIcon:SetAllPoints()
    mgIcon:SetTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic")
    missingGem.Icon = mgIcon
    sideSummary.MissingGem = missingGem

    -- Hover tooltip on the side summary showing the stat and enhancement breakdown
    local function showBreakdownTooltip(anchorFrame)
      if not sideSummary.breakdownData then return end
      GameTooltip:SetOwner(anchorFrame, slot.side == "LEFT" and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
      GameTooltip:ClearLines()

      local data = sideSummary.breakdownData
      GameTooltip:AddLine(data.itemName or "Equipment Details", 1, 1, 1)

      if data.watermarkIlevel and data.watermarkIlevel > 0 then
        local wmColor = getWatermarkColor(data.watermarkIlevel, data.itemQuality)
        GameTooltip:AddDoubleLine("Slot Watermark:", tostring(data.watermarkIlevel), 1, 0.82, 0, wmColor.r, wmColor.g, wmColor.b)
      end

      local hasEnchantInStats = false

      if data.statsList and #data.statsList > 0 then
        for _, stat in ipairs(data.statsList) do
          GameTooltip:AddLine(" ")
          local rightText
          local totalPct = stat.totalPct or stat.pct
          if totalPct then
            rightText = string.format("%d (%.1f%%)", stat.total, totalPct)
          else
            rightText = string.format("%d", stat.total)
          end
          GameTooltip:AddDoubleLine(stat.name .. ":", rightText, 1, 1, 1, 0, 1, 0)

          if stat.base and stat.base > 0 then
            local basePctText
            if stat.basePct then
              basePctText = string.format("%d (%.1f%%)", stat.base, stat.basePct)
            else
              basePctText = string.format("%d", stat.base)
            end
            GameTooltip:AddDoubleLine("  Item:", basePctText, 0.75, 0.75, 0.75, 1, 1, 1)
          end
          if stat.enchant and stat.enchant > 0 then
            hasEnchantInStats = true
            local enchPctText
            if stat.enchantPct then
              enchPctText = string.format("%d (%.1f%%)", stat.enchant, stat.enchantPct)
            else
              enchPctText = string.format("%d", stat.enchant)
            end
            GameTooltip:AddDoubleLine("  Enchant:", enchPctText, 0.75, 0.75, 0.75, 0.2, 1, 0.4)
          end
          if stat.gem and stat.gem > 0 then
            local gemPctText
            if stat.gemPct then
              gemPctText = string.format("%d (%.1f%%)", stat.gem, stat.gemPct)
            else
              gemPctText = string.format("%d", stat.gem)
            end
            GameTooltip:AddDoubleLine("  Gem:", gemPctText, 0.75, 0.75, 0.75, 0.4, 0.8, 1)
          end
        end
      end

      if data.enchantEffect and data.enchantEffect ~= "" and not hasEnchantInStats then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Enchant:", data.enchantEffect, 1, 0.82, 0, 0.2, 1, 0.4)
      end

      if data.isMissingEnchant then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffff2020Warning: Missing Enchant!|r")
      end

      if data.missingGemCount and data.missingGemCount > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("|cffff2020Warning: %d Empty Gem Socket%s!|r", data.missingGemCount, data.missingGemCount > 1 and "s" or ""))
      end

      GameTooltip:Show()
    end

    sideSummary:SetScript("OnEnter", showBreakdownTooltip)
    sideSummary:SetScript("OnLeave", function() GameTooltip:Hide() end)
    missingEnchant:SetScript("OnEnter", showBreakdownTooltip)
    missingEnchant:SetScript("OnLeave", function() GameTooltip:Hide() end)
    missingGem:SetScript("OnEnter", showBreakdownTooltip)
    missingGem:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  slotOverlay:EnableMouse(false)
  if slotOverlay.SetMouseClickEnabled then pcall(slotOverlay.SetMouseClickEnabled, slotOverlay, false) end
  if slotOverlay.SetMouseMotionEnabled then pcall(slotOverlay.SetMouseMotionEnabled, slotOverlay, false) end
  slotOverlay:SetScript("OnEnter", nil)
  slotOverlay:SetScript("OnLeave", nil)
  slotOverlay:SetScript("OnMouseDown", nil)
  slotOverlay:SetScript("OnMouseUp", nil)

  -- Hide any legacy overlay elements from earlier builds
  if slotOverlay.Secondary then slotOverlay.Secondary:Hide() end
  if slotOverlay.Tertiary then slotOverlay.Tertiary:Hide() end
  if slotOverlay.Enchant then slotOverlay.Enchant:Hide() end
  if slotOverlay.Sockets then
    for i = 1, #slotOverlay.Sockets do
      slotOverlay.Sockets[i]:Hide()
    end
  end

  slotOverlay.slot = slot
  return slotOverlay
end

--- Updates a single equipment slot overlay.
---@param unitId string "player" | "target"
---@param slotId number Equipment slot ID
local function updateSlot(unitId, slotId)
  if not unitId or not slotId then return end
  local slot = SLOTS[slotId]
  if not slot then return end

  local prefix = (unitId == "player" and "Character" or "Inspect")
  local characterSlotFrame = _G[prefix .. slot.name .. "Slot"]
  if not characterSlotFrame then return end

  local slotOverlay = getOrCreateSlotOverlay(characterSlotFrame, slot)
  slotOverlay:EnableMouse(false)
  if slotOverlay.SetMouseClickEnabled then pcall(slotOverlay.SetMouseClickEnabled, slotOverlay, false) end
  if slotOverlay.SetMouseMotionEnabled then pcall(slotOverlay.SetMouseMotionEnabled, slotOverlay, false) end

  if not isModuleEnabled() then
    slotOverlay:Hide()
    return
  end

  local itemId = GetInventoryItemID(unitId, slotId)
  if not itemId then
    slotOverlay:Hide()
    return
  end

  local itemLink = GetInventoryItemLink(unitId, slotId)
  if not itemLink or itemLink == "" then
    slotOverlay:Hide()
    return
  end

  local settings = charSheetSettings()

  -- --------------------------------------------------------------------------
  -- 1. Scan Tooltip Information (ItemLevel, Track, Enchants, Gem Sockets)
  -- --------------------------------------------------------------------------
  local itemLevel = nil
  local trackText = ""
  local hasTrack = false
  local itemEnchant = nil
  local itemEnchantAtlas = nil
  local itemSocketCount = 0
  local itemSockets = {}
  local itemSocketTypes = {}
  local itemSocketList = {}

  local enchantPattern = ENCHANTED_TOOLTIP_LINE and ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)") or "Enchanted: (.*)"

  -- Tooltip upgrade track patterns
  local upgradePattern
  if ITEM_UPGRADE_TOOLTIP_FORMAT_STRING then
    local p = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", function(c)
      if c == "%" then return "%" else return "%" .. c end
    end)
    upgradePattern = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
  end

  local inventoryTooltipData = safeGetInventoryTooltipData(unitId, slotId)
  if inventoryTooltipData and inventoryTooltipData.lines then
    for lineIndex = 1, #inventoryTooltipData.lines do
      local line = inventoryTooltipData.lines[lineIndex]

      -- Item Level line
      if line.type == Enum.TooltipDataLineType.ItemLevel and line.itemLevel then
        itemLevel = line.itemLevel
      end

      -- Enchant line
      if line.leftText then
        local text = line.leftText
        local enchantMatch = text:match(enchantPattern)
        if enchantMatch then
          itemEnchantAtlas = enchantMatch:match("|A:([^:]+)")
          itemEnchant = enchantMatch:gsub("|A:[^|]+|a", ""):gsub("|T[^|]+|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        end

        -- Upgrade Track line
        if not hasTrack and not text:find("Unique", 1, true) and not text:find("Equip", 1, true) and not text:find("Set:", 1, true) then
          local tName, cur, maxR
          if upgradePattern then
            tName, cur, maxR = text:match(upgradePattern)
          end
          if not (tName and cur and maxR) and not text:find("PVP", 1, true) then
            tName, cur, maxR = text:match("([%a%s]+)%s+(%d+)%s*/%s*(%d+)")
          end
          if tName and cur and maxR then
            local abbrev = getTrackAbbreviation(tName)
            if abbrev then
              local curNum = tonumber(cur)
              local maxNum = tonumber(maxR)
              local isMaxRank = (curNum and maxNum and curNum >= maxNum) or (cur == maxR)
              if settings.maxUpgradeStar and isMaxRank then
                  trackText = string.format("%s %s", STAR_ICON, abbrev)
              else
                trackText = string.format("%s/%s %s", cur, maxR, abbrev)
              end
              hasTrack = true
            end
          end
        end
      end

      -- Gem Sockets
      if line.type == Enum.TooltipDataLineType.GemSocket then
        itemSocketCount = itemSocketCount + 1
        if line.gemIcon then
          itemSockets[itemSocketCount] = line.gemIcon
        elseif line.socketType then
          itemSockets[itemSocketCount] = string.format("Interface\\ItemSocketingFrame\\UI-EmptySocket-%s", line.socketType)
          itemSocketTypes[itemSocketCount] = line.socketType
        end
        table.insert(itemSocketList, {
          gemIcon = line.gemIcon,
          socketType = line.socketType,
          text = line.leftText,
        })
      end
    end
  else
    -- Fallback via classic tooltip scanning
    local scannedLines = scanInventoryItemLines(unitId, slotId)
    local ilvlPattern = (ITEM_LEVEL and ITEM_LEVEL:gsub("%%d", "(%%d+)")) or "Item Level (%d+)"
    for _, text in ipairs(scannedLines) do
      if not itemLevel then
        local ilvl = text:match(ilvlPattern)
        if ilvl then
          itemLevel = tonumber(ilvl)
        end
      end

      local enchantMatch = text:match(enchantPattern)
      if enchantMatch and not itemEnchant then
        itemEnchantAtlas = enchantMatch:match("|A:([^:]+)")
        itemEnchant = enchantMatch:gsub("|A:[^|]+|a", ""):gsub("|T[^|]+|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
      end

      if not hasTrack and not text:find("Unique", 1, true) and not text:find("Equip", 1, true) and not text:find("Set:", 1, true) then
        local tName, cur, maxR
        if upgradePattern then
          tName, cur, maxR = text:match(upgradePattern)
        end
        if not (tName and cur and maxR) and not text:find("PVP", 1, true) then
          tName, cur, maxR = text:match("([%a%s]+)%s+(%d+)%s*/%s*(%d+)")
        end
        if tName and cur and maxR then
          local abbrev = getTrackAbbreviation(tName)
          if abbrev then
            local curNum = tonumber(cur)
            local maxNum = tonumber(maxR)
            local isMaxRank = (curNum and maxNum and curNum >= maxNum) or (cur == maxR)
            if settings.maxUpgradeStar and isMaxRank then
              trackText = string.format("%s %s", STAR_ICON, abbrev)
            else
              trackText = string.format("%s/%s %s", cur, maxR, abbrev)
            end
            hasTrack = true
          end
        end
      end
    end
  end

  -- Fallback for itemLevel if tooltip line didn't supply it
  if not itemLevel and C_Item and C_Item.GetDetailedItemLevelInfo then
    itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
  end

  -- --------------------------------------------------------------------------
  -- 2. Item Level & Upgrade Track Display (Centered on Icon)
  -- --------------------------------------------------------------------------
  local itemName, _, itemQuality = C_Item.GetItemInfo(itemLink)
  if not itemQuality and GetItemInfo then
    itemName, _, itemQuality = GetItemInfo(itemLink)
  end

  local showTrack = isRetail() and settings.upgradeTrack and hasTrack and trackText ~= ""
  local levelY = showTrack and 6 or 0
  slotOverlay.Level:ClearAllPoints()
  slotOverlay.Level:SetPoint("CENTER", slotOverlay, "CENTER", 0, levelY)
  slotOverlay.Level:SetFont(DEFAULT_FONT, FONT_SIZE_LEVEL, FONT_OUTLINE)
  slotOverlay.Level:SetJustifyH("CENTER")

  if settings.itemLevel and itemLevel then
    slotOverlay.Level:SetText(tostring(itemLevel))
    if settings.highWatermarkColoring then
      local watermarkColor = getWatermarkColor(itemLevel, itemQuality)
      slotOverlay.Level:SetTextColor(watermarkColor.r, watermarkColor.g, watermarkColor.b, watermarkColor.a)
    else
      slotOverlay.Level:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
    end
    slotOverlay.Level:Show()
    slotOverlay.Tint:Show()
  else
    slotOverlay.Level:Hide()
    slotOverlay.Tint:Hide()
  end

  -- --------------------------------------------------------------------------
  -- 3. Upgrade Track Display (Centered Underneath Item Level, Retail Only)
  -- --------------------------------------------------------------------------
  if showTrack then
    slotOverlay.Track:ClearAllPoints()
    slotOverlay.Track:SetPoint("TOP", slotOverlay.Level, "BOTTOM", 0, -1)
    slotOverlay.Track:SetFont(DEFAULT_FONT, FONT_SIZE_TRACK, FONT_OUTLINE)
    slotOverlay.Track:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
    slotOverlay.Track:SetJustifyH("CENTER")
    slotOverlay.Track:SetText(trackText)
    slotOverlay.Track:Show()
  else
    slotOverlay.Track:ClearAllPoints()
    slotOverlay.Track:SetText("")
    slotOverlay.Track:Hide()
  end

  -- --------------------------------------------------------------------------
  -- 4. Side Summary & Breakdown Calculation
  -- --------------------------------------------------------------------------
  itemName = itemName or "Item"
  local itemPayload = itemLink:match("item:([%-?%d:]+)")
  local payloadParts = itemPayload and { strsplit(":", itemPayload) } or {}
  local enchantID = tonumber(payloadParts[2])

  local totalStats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)) or {}

  -- Build pure base item link (strip enchantID and all 4 gem IDs)
  local partsBase = { unpack(payloadParts) }
  partsBase[2] = "0"
  partsBase[3] = "0"
  partsBase[4] = "0"
  partsBase[5] = "0"
  partsBase[6] = "0"
  local linkBase = "item:" .. table.concat(partsBase, ":")
  local baseStats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(linkBase)) or {}

  -- Calculate enchant stat contribution
  local enchantBuckets = {}
  local enchantEffectText = nil
  local isMissingEnchant = false

  -- 1. Parse enchant from tooltip line if text is available
  if itemEnchant ~= nil and itemEnchant ~= "" then
    local pStats = parseStatsFromText(itemEnchant)
    for g, v in pairs(pStats) do
      enchantBuckets[g] = math.max(enchantBuckets[g] or 0, v)
    end
  end

  -- 2. Try reading enchant:enchantID hyperlink tooltip
  if enchantID and enchantID > 0 then
    local enchData = safeGetHyperlinkTooltipData and safeGetHyperlinkTooltipData("enchant:" .. enchantID)
    if enchData and enchData.lines then
      for _, eLine in ipairs(enchData.lines) do
        if eLine.leftText then
          local pStats = parseStatsFromText(eLine.leftText)
          for g, v in pairs(pStats) do
            enchantBuckets[g] = math.max(enchantBuckets[g] or 0, v)
          end
        end
      end
    end

    if not next(enchantBuckets) then
      pcall(function()
        scanTooltip:ClearLines()
        scanTooltip:SetHyperlink("enchant:" .. enchantID)
        for i = 1, scanTooltip:NumLines() do
          local fs = _G["SlackHacksInfoDisplayScanTooltipTextLeft" .. i]
          if fs then
            local t = fs:GetText()
            if t and t ~= "" then
              local pStats = parseStatsFromText(t)
              for g, v in pairs(pStats) do
                enchantBuckets[g] = math.max(enchantBuckets[g] or 0, v)
              end
            end
          end
        end
      end)
    end

    -- 3. Diff item stats with/without enchant
    local partsNoEnchant = { unpack(payloadParts) }
    partsNoEnchant[2] = "0"
    local linkNoEnchant = "item:" .. table.concat(partsNoEnchant, ":")
    local statsNoEnchant = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(linkNoEnchant)) or {}

    for k, v in pairs(totalStats) do
      local d = v - (statsNoEnchant[k] or 0)
      if d > 0 then
        local g = getStatGroup(k)
        if g then
          enchantBuckets[g] = math.max(enchantBuckets[g] or 0, d)
        end
      end
    end
  end

  -- 4. Known enchants table fallback by name
  if itemEnchant and itemEnchant ~= "" and not next(enchantBuckets) then
    local lowerEnchant = itemEnchant:lower()
    for _, ke in ipairs(KNOWN_ENCHANTS) do
      if lowerEnchant:find(ke.pattern) then
        for g, val in pairs(ke.stats) do
          enchantBuckets[g] = math.max(enchantBuckets[g] or 0, val)
        end
        break
      end
    end
  end

  if itemEnchant ~= nil and itemEnchant ~= "" then
    enchantEffectText = getEnchantDisplayText(itemLink, itemEnchant, itemEnchantAtlas, slot.id, enchantBuckets)
  end

  if (not itemEnchant or itemEnchant == "") and canSlotEnchant(slot) then
    local _, _, _, _, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(itemLink)
    if itemEquipLoc ~= "INVTYPE_HOLDABLE" and itemEquipLoc ~= "INVTYPE_SHIELD" then
      isMissingEnchant = true
    end
  end

  -- Calculate gem contributions and identify slotted gems vs empty sockets
  local gemList = {}
  local missingGemCount = 0
  local numSockets = (C_Item and C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(itemLink))
    or (GetItemNumSockets and GetItemNumSockets(itemLink)) or 0
  local totalSocketCount = math.max(itemSocketCount, #itemSocketList, numSockets)

  for socketIndex = 1, 4 do
    local gemID = tonumber(payloadParts[2 + socketIndex])
    local socketData = itemSocketList[socketIndex]
    local hasSocket = (socketIndex <= totalSocketCount) or (gemID and gemID > 0) or (socketData ~= nil)

    if hasSocket then
      local isFilled = (gemID and gemID > 0) or (socketData and socketData.gemIcon ~= nil)
      if isFilled then
        local gName, gLink
        if C_Item and C_Item.GetItemGem then
          gName, gLink = C_Item.GetItemGem(itemLink, socketIndex)
        end
        if not gName and gemID and gemID > 0 then
          gName = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(gemID))
        end
        if not gLink and gemID and gemID > 0 then
          gLink = select(2, C_Item.GetItemInfo(gemID)) or ("item:" .. gemID)
        end
        gName = gName or ("Gem " .. socketIndex)

        local gBuckets = {}

        -- 1. Query gem item stats directly using full gemLink
        if gLink and C_Item and C_Item.GetItemStats then
          local rawGStats = C_Item.GetItemStats(gLink)
          if rawGStats then
            for k, v in pairs(rawGStats) do
              if v and v > 0 then
                local g = getStatGroup(k)
                if g then
                  gBuckets[g] = math.max(gBuckets[g] or 0, v)
                end
              end
            end
          end
        end

        -- 2. Scan gem hyperlink tooltip (picks up dual stats and equip text)
        if gLink then
          local gemData = safeGetHyperlinkTooltipData and safeGetHyperlinkTooltipData(gLink)
          if gemData and gemData.lines then
            for _, gLine in ipairs(gemData.lines) do
              if gLine.leftText and not gLine.leftText:find("Item Level") and not gLine.leftText:find(gName, 1, true) then
                local pStats = parseStatsFromText(gLine.leftText)
                for g, v in pairs(pStats) do
                  gBuckets[g] = math.max(gBuckets[g] or 0, v)
                end
              end
            end
          end

          if not next(gBuckets) then
            pcall(function()
              scanTooltip:ClearLines()
              scanTooltip:SetHyperlink(gLink)
              for i = 1, scanTooltip:NumLines() do
                local fs = _G["SlackHacksInfoDisplayScanTooltipTextLeft" .. i]
                if fs then
                  local t = fs:GetText()
                  if t and t ~= "" and not t:find("Item Level") and not t:find(gName, 1, true) then
                    local pStats = parseStatsFromText(t)
                    for g, v in pairs(pStats) do
                      gBuckets[g] = math.max(gBuckets[g] or 0, v)
                    end
                  end
                end
              end
            end)
          end
        end

        -- 3. Parse stats from socket line text in the item's own tooltip
        if socketData and socketData.text then
          local pStats = parseStatsFromText(socketData.text)
          for g, v in pairs(pStats) do
            gBuckets[g] = math.max(gBuckets[g] or 0, v)
          end
        end

        table.insert(gemList, {
          id = gemID,
          name = gName,
          link = gLink,
          buckets = gBuckets,
        })
      else
        missingGemCount = missingGemCount + 1
      end
    end
  end

  local totalBuckets = {}
  for k, v in pairs(totalStats) do
    if v and v > 0 then
      local g = getStatGroup(k)
      if g then
        totalBuckets[g] = (totalBuckets[g] or 0) + v
      end
    end
  end

  local baseBuckets = {}
  for k, v in pairs(baseStats) do
    if v and v > 0 then
      local g = getStatGroup(k)
      if g then
        baseBuckets[g] = (baseBuckets[g] or 0) + v
      end
    end
  end

  -- Accurately deduce base stats from totalStats by subtracting enchant and gem contributions
  for g, totalVal in pairs(totalBuckets) do
    local enchVal = enchantBuckets[g] or 0
    local gemVal = 0
    for _, gem in ipairs(gemList) do
      gemVal = gemVal + (gem.buckets and gem.buckets[g] or 0)
    end
    local deducedBase = math.max(0, totalVal - enchVal - gemVal)
    if not baseBuckets[g] or baseBuckets[g] > totalVal or baseBuckets[g] == 0 then
      baseBuckets[g] = deducedBase
    end
  end

  if not next(baseBuckets) then
    if inventoryTooltipData and inventoryTooltipData.lines then
      for _, line in ipairs(inventoryTooltipData.lines) do
        if line.type ~= Enum.TooltipDataLineType.GemSocket and line.leftText then
          local text = line.leftText
          if not text:match(enchantPattern) and not text:find("Item Level") and not text:find("Requires") and not text:find("Unique") and not text:find("Equip:") and not text:find("Use:") and not text:find("Set:") then
            local pStats = parseStatsFromText(text)
            for g, v in pairs(pStats) do
              baseBuckets[g] = (baseBuckets[g] or 0) + v
            end
          end
        end
      end
    end
  end

  -- Function to get the true SUM of stats across all sources (item base + enchant + gems)
  local function getStatSumAndBreakdown(statKeyOrType)
    local g = getStatGroup(statKeyOrType)
    local bAmt = baseBuckets[g] or 0
    local eAmt = enchantBuckets[g] or 0
    local gAmt = 0
    for _, gem in ipairs(gemList) do
      local a = gem.buckets and gem.buckets[g] or 0
      if a > 0 then
        gAmt = gAmt + a
      end
    end
    local sum = bAmt + eAmt + gAmt
    if totalBuckets[g] and totalBuckets[g] > 0 and sum < totalBuckets[g] then
      bAmt = math.max(0, totalBuckets[g] - eAmt - gAmt)
      sum = bAmt + eAmt + gAmt
    end
    return sum, bAmt, eAmt, gAmt
  end

  -- Collect active stats with breakdown data
  local activeStats = {}
  local sideSummaryLines = {}

  if isRetail() then
    -- ------------------------------------------------------------------------
    -- Retail Mode: Primary, Secondary & Tertiary Stats with Diminishing Returns
    -- ------------------------------------------------------------------------
    -- Process Primary stat (Strength, Agility, Intellect, or generic Primary)
    local pKey, pName, pSuffix = getPlayerPrimaryStat()
    local foundPrimaryKey = pKey
    if (baseBuckets[pKey] or 0) > 0 or (enchantBuckets[pKey] or 0) > 0 then
      foundPrimaryKey = pKey
    elseif (baseBuckets["STRENGTH"] or 0) > 0 or (enchantBuckets["STRENGTH"] or 0) > 0 then
      foundPrimaryKey = "STRENGTH"
      pName, pSuffix = "Strength", "Str"
    elseif (baseBuckets["AGILITY"] or 0) > 0 or (enchantBuckets["AGILITY"] or 0) > 0 then
      foundPrimaryKey = "AGILITY"
      pName, pSuffix = "Agility", "Agi"
    elseif (baseBuckets["INTELLECT"] or 0) > 0 or (enchantBuckets["INTELLECT"] or 0) > 0 then
      foundPrimaryKey = "INTELLECT"
      pName, pSuffix = "Intellect", "Int"
    end

    local pBase = (baseBuckets[foundPrimaryKey] or 0) + ((foundPrimaryKey ~= "PRIMARY") and (baseBuckets["PRIMARY"] or 0) or 0)
    local pEnchant = (enchantBuckets[foundPrimaryKey] or 0) + ((foundPrimaryKey ~= "PRIMARY") and (enchantBuckets["PRIMARY"] or 0) or 0)
    local pGem = 0
    for _, gem in ipairs(gemList) do
      local a = (gem.buckets and gem.buckets[foundPrimaryKey] or 0) + ((foundPrimaryKey ~= "PRIMARY") and (gem.buckets and gem.buckets["PRIMARY"] or 0) or 0)
      pGem = pGem + a
    end
    local pSum = pBase + pEnchant + pGem

    if pSum > 0 then
      local displayName = pName
      if pBase == 0 and (pEnchant > 0 or pGem > 0) then
        displayName = "Primary Stat"
        pSuffix = "Primary"
      end

      table.insert(activeStats, {
        type = foundPrimaryKey,
        name = displayName,
        suffix = pSuffix,
        order = 0,
        total = pSum,
        base = pBase,
        enchant = pEnchant,
        gem = pGem,
        isPrimary = true,
      })
    end

    -- Process Secondary stats
    for _, statInfo in ipairs(SECONDARY_STATS) do
      local sum, bAmt, eAmt, gAmt = getStatSumAndBreakdown(statInfo.type)
      if sum > 0 then
        local totalPct = calculateSecondaryStatIncrease(statInfo.cr, sum)
        local basePct = (bAmt > 0) and calculateSecondaryStatIncrease(statInfo.cr, bAmt) or nil
        local enchantPct = (eAmt > 0) and calculateSecondaryStatIncrease(statInfo.cr, eAmt) or nil
        local gemPct = (gAmt > 0) and calculateSecondaryStatIncrease(statInfo.cr, gAmt) or nil

        table.insert(activeStats, {
          type = statInfo.type,
          name = statInfo.name,
          suffix = statInfo.suffix,
          order = statInfo.order,
          total = sum,
          totalPct = totalPct,
          base = bAmt,
          basePct = basePct,
          enchant = eAmt,
          enchantPct = enchantPct,
          gem = gAmt,
          gemPct = gemPct,
          isTertiary = false,
        })

        if settings.secondaryStats then
          table.insert(sideSummaryLines, {
            order = statInfo.order,
            text = string.format("+%d %s (+%.1f%%)", sum, statInfo.suffix, totalPct),
          })
        end
      end
    end

    -- Process Tertiary stats (included in tooltip breakdown, not on side summary)
    for _, statInfo in ipairs(TERTIARY_STATS) do
      local sum, bAmt, eAmt, gAmt = getStatSumAndBreakdown(statInfo.type)
      if sum > 0 then
        local totalPct = calculateTertiaryStatIncrease(statInfo.type, statInfo.cr, sum)
        local basePct = (bAmt > 0) and calculateTertiaryStatIncrease(statInfo.type, statInfo.cr, bAmt) or nil
        local enchantPct = (eAmt > 0) and calculateTertiaryStatIncrease(statInfo.type, statInfo.cr, eAmt) or nil
        local gemPct = (gAmt > 0) and calculateTertiaryStatIncrease(statInfo.type, statInfo.cr, gAmt) or nil

        table.insert(activeStats, {
          type = statInfo.type,
          name = statInfo.name,
          suffix = statInfo.suffix,
          order = 10 + statInfo.order,
          total = sum,
          totalPct = totalPct,
          base = bAmt,
          basePct = basePct,
          enchant = eAmt,
          enchantPct = enchantPct,
          gem = gAmt,
          gemPct = gemPct,
          isTertiary = true,
        })
      end
    end
  else
    -- ------------------------------------------------------------------------
    -- Forever / Classic Mode: Display All Item Stats (Strength, Agi, Stam, Int, Spi, etc.)
    -- ------------------------------------------------------------------------
    local processedStats = {}
    for statKey, statInfo in pairs(FOREVER_STAT_DEFS) do
      if not processedStats[statInfo.name] then
        local sum, bAmt, eAmt, gAmt = getStatSumAndBreakdown(statKey)
        if sum > 0 then
          processedStats[statInfo.name] = true
          table.insert(activeStats, {
            type = statKey,
            name = statInfo.name,
            suffix = statInfo.suffix,
            order = statInfo.order,
            total = sum,
            base = bAmt,
            enchant = eAmt,
            gem = gAmt,
            isForever = true,
          })

          if settings.itemStats then
            table.insert(sideSummaryLines, {
              order = statInfo.order,
              text = string.format("+%d %s", sum, statInfo.suffix),
            })
          end
        end
      end
    end
  end

  table.sort(activeStats, function(a, b) return a.order < b.order end)
  table.sort(sideSummaryLines, function(a, b) return a.order < b.order end)

  -- Save breakdown data onto the SideSummary frame for hover tooltip
  local showWatermark = isRetail() and (settings.slotWatermark ~= false)
  local watermarkIlevel = showWatermark and getSlotHighWatermark(unitId, slotId, itemLink, itemLevel) or nil

  slotOverlay.SideSummary.breakdownData = {
    itemName = itemName,
    itemQuality = itemQuality,
    watermarkIlevel = watermarkIlevel,
    statsList = activeStats,
    enchantEffect = enchantEffectText,
    gemsList = gemList,
    isMissingEnchant = isMissingEnchant,
    missingGemCount = missingGemCount,
  }

  -- Build side summary text
  local summaryString = ""
  if #sideSummaryLines > 0 then
    local lineTexts = {}
    for _, l in ipairs(sideSummaryLines) do
      table.insert(lineTexts, l.text)
    end
    summaryString = table.concat(lineTexts, "\n")
  end

  local sideSummary = slotOverlay.SideSummary
  sideSummary.StatsText:SetFont(getStatsFont(), FONT_SIZE_STATS, FONT_OUTLINE)
  sideSummary.StatsText:SetText(summaryString)
  sideSummary.StatsText:SetJustifyH(slot.side == "RIGHT" and "RIGHT" or "LEFT")

  -- Re-anchor sideSummary to ensure correct bottom vs center alignment
  local isBottomSlot = (slot.id == 16 or slot.id == 17)
  local relativePoint = slot.side == "LEFT" and "RIGHT" or "LEFT"
  local offsetX = slot.side == "LEFT" and 8 or -8
  local sideSummaryPoint, slotPoint
  if isBottomSlot then
    sideSummaryPoint = slot.side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT"
    slotPoint = slot.side == "LEFT" and "BOTTOMRIGHT" or "BOTTOMLEFT"
  else
    sideSummaryPoint = slot.side
    slotPoint = relativePoint
  end
  sideSummary:ClearAllPoints()
  sideSummary:SetPoint(sideSummaryPoint, slotOverlay, slotPoint, offsetX, 0)

  -- Missing alert icons
  local showMissingEnchant = settings.enchants and isMissingEnchant
  local showMissingGem = settings.gemSockets and (missingGemCount > 0)

  if showMissingEnchant then
    sideSummary.MissingEnchant:ClearAllPoints()
    if slot.side == "LEFT" then
      sideSummary.MissingEnchant:SetPoint("BOTTOMLEFT", sideSummary, "BOTTOMLEFT", 0, 0)
    else
      sideSummary.MissingEnchant:SetPoint("BOTTOMRIGHT", sideSummary, "BOTTOMRIGHT", 0, 0)
    end
    sideSummary.MissingEnchant:Show()
  else
    sideSummary.MissingEnchant:Hide()
  end

  if showMissingGem then
    sideSummary.MissingGem:ClearAllPoints()
    if slot.side == "LEFT" then
      if showMissingEnchant then
        sideSummary.MissingGem:SetPoint("LEFT", sideSummary.MissingEnchant, "RIGHT", 4, 0)
      else
        sideSummary.MissingGem:SetPoint("BOTTOMLEFT", sideSummary, "BOTTOMLEFT", 0, 0)
      end
    else
      if showMissingEnchant then
        sideSummary.MissingGem:SetPoint("RIGHT", sideSummary.MissingEnchant, "LEFT", -4, 0)
      else
        sideSummary.MissingGem:SetPoint("BOTTOMRIGHT", sideSummary, "BOTTOMRIGHT", 0, 0)
      end
    end
    sideSummary.MissingGem:Show()
  else
    sideSummary.MissingGem:Hide()
  end

  -- Position watermark and stats text: bottom-anchored for weapon slots, center-anchored for all other slots
  local numLines = #sideSummaryLines
  local hasWatermark = (watermarkIlevel and watermarkIlevel > 0)
  local gap = (hasWatermark and numLines > 0) and 2 or 0
  local hWatermark = 13
  local hPerStatLine = 11
  local totalContentH = (hasWatermark and hWatermark or 0) + gap + (numLines * hPerStatLine)
  local alertH = (showMissingEnchant or showMissingGem) and 16 or 0
  local frameH = math.max(20, math.min(37, totalContentH + alertH))
  local maxTextW = math.max(sideSummary.StatsText:GetStringWidth() or 0, sideSummary.WatermarkText:GetStringWidth() or 0)
  local frameW = math.max(75, math.min(95, maxTextW + 8))
  sideSummary:SetSize(frameW, frameH)

  sideSummary.WatermarkText:ClearAllPoints()
  sideSummary.StatsText:ClearAllPoints()

  if isBottomSlot then
    -- ------------------------------------------------------------------------
    -- Main-Hand & Off-Hand: Anchor to Bottom
    -- ------------------------------------------------------------------------
    local bottomY = (showMissingEnchant or showMissingGem) and 16 or 0

    if hasWatermark then
      sideSummary.WatermarkText:SetFont(DEFAULT_FONT, FONT_SIZE_WATERMARK, FONT_OUTLINE)
      sideSummary.WatermarkText:SetText(tostring(watermarkIlevel))
      if settings.highWatermarkColoring then
        local wmColor = getWatermarkColor(watermarkIlevel, itemQuality)
        sideSummary.WatermarkText:SetTextColor(wmColor.r, wmColor.g, wmColor.b, wmColor.a)
      else
        sideSummary.WatermarkText:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
      end

      if numLines > 0 then
        if slot.side == "LEFT" then
          sideSummary.StatsText:SetPoint("BOTTOMLEFT", sideSummary, "BOTTOMLEFT", 0, bottomY)
          sideSummary.StatsText:SetJustifyH("LEFT")
          sideSummary.WatermarkText:SetPoint("BOTTOMLEFT", sideSummary.StatsText, "TOPLEFT", 0, gap)
          sideSummary.WatermarkText:SetJustifyH("LEFT")
        else
          sideSummary.StatsText:SetPoint("BOTTOMRIGHT", sideSummary, "BOTTOMRIGHT", 0, bottomY)
          sideSummary.StatsText:SetJustifyH("RIGHT")
          sideSummary.WatermarkText:SetPoint("BOTTOMRIGHT", sideSummary.StatsText, "TOPRIGHT", 0, gap)
          sideSummary.WatermarkText:SetJustifyH("RIGHT")
        end
        sideSummary.StatsText:Show()
      else
        if slot.side == "LEFT" then
          sideSummary.WatermarkText:SetPoint("BOTTOMLEFT", sideSummary, "BOTTOMLEFT", 0, bottomY)
          sideSummary.WatermarkText:SetJustifyH("LEFT")
        else
          sideSummary.WatermarkText:SetPoint("BOTTOMRIGHT", sideSummary, "BOTTOMRIGHT", 0, bottomY)
          sideSummary.WatermarkText:SetJustifyH("RIGHT")
        end
        sideSummary.StatsText:Hide()
      end
      sideSummary.WatermarkText:Show()
    else
      sideSummary.WatermarkText:SetText("")
      sideSummary.WatermarkText:Hide()

      if numLines > 0 then
        if slot.side == "LEFT" then
          sideSummary.StatsText:SetPoint("BOTTOMLEFT", sideSummary, "BOTTOMLEFT", 0, bottomY)
          sideSummary.StatsText:SetJustifyH("LEFT")
        else
          sideSummary.StatsText:SetPoint("BOTTOMRIGHT", sideSummary, "BOTTOMRIGHT", 0, bottomY)
          sideSummary.StatsText:SetJustifyH("RIGHT")
        end
        sideSummary.StatsText:Show()
      else
        sideSummary.StatsText:Hide()
      end
    end
  else
    -- ------------------------------------------------------------------------
    -- Other Equipment Slots: Center-Anchor Vertically
    -- ------------------------------------------------------------------------
    local hWatermark = 13
    local hPerStatLine = 11
    local totalContentH = (hasWatermark and hWatermark or 0) + gap + (numLines * hPerStatLine)

    local topY = math.floor(totalContentH / 2)
    if (showMissingEnchant or showMissingGem) and totalContentH > 25 then
      topY = topY + 6
    end

    if hasWatermark then
      sideSummary.WatermarkText:SetFont(DEFAULT_FONT, FONT_SIZE_WATERMARK, FONT_OUTLINE)
      sideSummary.WatermarkText:SetText(tostring(watermarkIlevel))
      if settings.highWatermarkColoring then
        local wmColor = getWatermarkColor(watermarkIlevel, itemQuality)
        sideSummary.WatermarkText:SetTextColor(wmColor.r, wmColor.g, wmColor.b, wmColor.a)
      else
        sideSummary.WatermarkText:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
      end

      if slot.side == "LEFT" then
        sideSummary.WatermarkText:SetPoint("TOPLEFT", sideSummary, "LEFT", 0, topY)
        sideSummary.WatermarkText:SetJustifyH("LEFT")
        if numLines > 0 then
          sideSummary.StatsText:SetPoint("TOPLEFT", sideSummary.WatermarkText, "BOTTOMLEFT", 0, -gap)
          sideSummary.StatsText:SetJustifyH("LEFT")
          sideSummary.StatsText:Show()
        else
          sideSummary.StatsText:Hide()
        end
      else
        sideSummary.WatermarkText:SetPoint("TOPRIGHT", sideSummary, "RIGHT", 0, topY)
        sideSummary.WatermarkText:SetJustifyH("RIGHT")
        if numLines > 0 then
          sideSummary.StatsText:SetPoint("TOPRIGHT", sideSummary.WatermarkText, "BOTTOMRIGHT", 0, -gap)
          sideSummary.StatsText:SetJustifyH("RIGHT")
          sideSummary.StatsText:Show()
        else
          sideSummary.StatsText:Hide()
        end
      end
      sideSummary.WatermarkText:Show()
    else
      sideSummary.WatermarkText:SetText("")
      sideSummary.WatermarkText:Hide()

      if numLines > 0 then
        if slot.side == "LEFT" then
          sideSummary.StatsText:SetPoint("TOPLEFT", sideSummary, "LEFT", 0, topY)
          sideSummary.StatsText:SetJustifyH("LEFT")
        else
          sideSummary.StatsText:SetPoint("TOPRIGHT", sideSummary, "RIGHT", 0, topY)
          sideSummary.StatsText:SetJustifyH("RIGHT")
        end
        sideSummary.StatsText:Show()
      else
        sideSummary.StatsText:Hide()
      end
    end
  end

  -- Hide side summary if everything is empty and no alerts
  local hasWatermark = (watermarkIlevel and watermarkIlevel > 0)
  if summaryString == "" and not hasWatermark and not showMissingEnchant and not showMissingGem then
    sideSummary:Hide()
  else
    sideSummary:Show()
  end

  -- Clean up any legacy overlay elements on the slot
  if slotOverlay.Secondary then slotOverlay.Secondary:Hide() end
  if slotOverlay.Tertiary then slotOverlay.Tertiary:Hide() end
  if slotOverlay.Enchant then slotOverlay.Enchant:Hide() end
  if slotOverlay.Sockets then
    for i = 1, #slotOverlay.Sockets do
      slotOverlay.Sockets[i]:Hide()
    end
  end

  slotOverlay:Show()
end

--- Updates all equipment slots for a unit.
---@param unitId string "player" | "target"
local function updateAllSlots(unitId)
  if not unitId then return end
  for slotId in pairs(SLOTS) do
    updateSlot(unitId, slotId)
  end
end

-- ============================================================================
-- AceAddon Module Lifecycle & Events
-- ============================================================================

-- Character Sheet "Show Gear Stats" Checkbox
local gearStatsCheckbox

local function getForeverScrollArea()
  local sb = _G["CharacterStatsPaneScrollBox"]
  if sb then
    return (sb.ScrollBox or sb)
  end
  if CharacterStatsPane then
    if CharacterStatsPane.ScrollBox then
      return CharacterStatsPane.ScrollBox
    end
    if CharacterStatsPane.ScrollBar then
      return CharacterStatsPane.ScrollBar
    end
  end
  if _G["CharacterStatsPaneScrollBar"] then
    return _G["CharacterStatsPaneScrollBar"]
  end
  if PaperDollFrame then
    if PaperDollFrame.ScrollBox then
      return PaperDollFrame.ScrollBox
    end
    if PaperDollFrame.StatsPane then
      return PaperDollFrame.StatsPane.ScrollBox or PaperDollFrame.StatsPane
    end
  end
  if CharacterFrame and CharacterFrame.ScrollBox then
    return CharacterFrame.ScrollBox
  end
  return CharacterAttributesFrame or PaperDollFrame or CharacterFrame
end

local function getCheckboxParentAndAnchor()
  if isRetail() then
    local parent = CharacterFrameInsetRight
      or (CharacterFrame and CharacterFrame.InsetRight)
      or CharacterStatsPane
      or CharacterFrame
    return parent, "BOTTOM", parent, "BOTTOM", 9
  else
    local scrollArea = getForeverScrollArea()
    local parent = PaperDollFrame or (scrollArea and scrollArea:GetParent()) or CharacterFrame
    if scrollArea and scrollArea ~= PaperDollFrame and scrollArea ~= CharacterFrame then
      return parent, "TOP", scrollArea, "BOTTOM", -5
    else
      return parent, "BOTTOM", parent, "BOTTOM", 72
    end
  end
end

local function updateGearStatsCheckbox()
  if not gearStatsCheckbox then return end
  local enabled = (db and db.profile and db.profile.infoDisplay and db.profile.infoDisplay.enabled) and true or false
  gearStatsCheckbox:SetChecked(enabled)
end

local function updateCheckboxPosition()
  if not gearStatsCheckbox then return end
  local parent, point, relFrame, relPoint, yOffset = getCheckboxParentAndAnchor()
  if not parent or not relFrame then return end

  if gearStatsCheckbox:GetParent() ~= parent then
    gearStatsCheckbox:SetParent(parent)
    local statsLevel = (relFrame.GetFrameLevel and relFrame:GetFrameLevel()) or 0
    local parentLevel = (parent.GetFrameLevel and parent:GetFrameLevel()) or 0
    gearStatsCheckbox:SetFrameLevel(math.max(statsLevel, parentLevel) + 15)
  end

  local boxSize = isRetail() and 20 or 18
  gearStatsCheckbox:SetSize(boxSize, boxSize)

  local text = gearStatsCheckbox.text or gearStatsCheckbox.Text or _G[gearStatsCheckbox:GetName() .. "Text"]
  local textWidth = (text and text:GetStringWidth()) or 0
  if not textWidth or textWidth == 0 then
    textWidth = 92
  end

  local offsetX = -math.floor((textWidth + 4) / 2)
  gearStatsCheckbox:ClearAllPoints()
  gearStatsCheckbox:SetPoint(point, relFrame, relPoint, offsetX, yOffset)
  gearStatsCheckbox:SetHitRectInsets(0, -textWidth - 4, 0, 0)
end

local function getOrCreateGearStatsCheckbox()
  if gearStatsCheckbox then return gearStatsCheckbox end
  if not CharacterFrame then return nil end

  local parent, point, relFrame, relPoint, yOffset = getCheckboxParentAndAnchor()
  if not parent or not relFrame then return nil end

  local cb = CreateFrame("CheckButton", "SlackHacksInfoDisplayGearStatsToggle", parent, "UICheckButtonTemplate")
  gearStatsCheckbox = cb

  local boxSize = isRetail() and 20 or 18
  cb:SetSize(boxSize, boxSize)
  local statsLevel = (relFrame.GetFrameLevel and relFrame:GetFrameLevel()) or 0
  local parentLevel = (parent.GetFrameLevel and parent:GetFrameLevel()) or 0
  cb:SetFrameLevel(math.max(statsLevel, parentLevel) + 15)

  local text = cb.text or cb.Text or _G[cb:GetName() .. "Text"]
  if text then
    text:SetText("Show Gear Stats")
    text:SetFontObject("GameFontHighlightSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  end

  updateCheckboxPosition()
  updateGearStatsCheckbox()

  cb:SetScript("OnClick", function(self)
    local isChecked = self:GetChecked() and true or false
    if isChecked then
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    else
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
    end
    module:SetEnabled(isChecked)
  end)

  cb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Show Gear Stats", 1, 1, 1)
    GameTooltip:AddLine("Toggle equipment stat overlays on your character sheet.", nil, nil, nil, true)
    GameTooltip:Show()
  end)

  cb:SetScript("OnLeave", function()
    GameTooltip_Hide()
  end)

  if CharacterStatsPane then
    CharacterStatsPane:HookScript("OnShow", function()
      if gearStatsCheckbox then
        gearStatsCheckbox:Show()
        updateCheckboxPosition()
        updateGearStatsCheckbox()
      end
    end)
    CharacterStatsPane:HookScript("OnHide", function()
      if isRetail() and gearStatsCheckbox then
        gearStatsCheckbox:Hide()
      end
    end)
  end

  if PaperDollFrame then
    PaperDollFrame:HookScript("OnShow", function()
      if gearStatsCheckbox then
        if isRetail() and CharacterStatsPane then
          gearStatsCheckbox:SetShown(CharacterStatsPane:IsShown())
        else
          gearStatsCheckbox:Show()
        end
        updateCheckboxPosition()
        updateGearStatsCheckbox()
      end
    end)
  end

  return cb
end

--- Refreshes all active character sheet equipment overlays.
function module:Refresh()
  updateGearStatsCheckbox()
  if not isModuleEnabled() then
    for _, overlay in ipairs(createdOverlays) do
      overlay:Hide()
    end
    return
  end

  if CharacterFrame and CharacterFrame:IsShown() then
    updateAllSlots("player")
  end
  if InspectFrame and InspectFrame:IsShown() then
    updateAllSlots("target")
  end
end

--- Toggles module enabled state and applies changes.
---@param enabled boolean
function module:SetEnabled(enabled)
  db.profile.infoDisplay.enabled = enabled
  if enabled then
    self:Enable()
  else
    self:Disable()
  end
  self:Refresh()
  updateGearStatsCheckbox()
  local acr = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if acr then
    acr:NotifyChange("SlackHacks")
  end
end

function module:OnInitialize()
  getOrCreateGearStatsCheckbox()

  -- Hook CharacterFrame OnShow to ensure slots refresh immediately when opened
  if CharacterFrame then
    CharacterFrame:HookScript("OnShow", function()
      local cb = getOrCreateGearStatsCheckbox()
      if cb then
        if isRetail() and CharacterStatsPane then
          cb:SetShown(CharacterStatsPane:IsShown())
        else
          cb:Show()
        end
        updateCheckboxPosition()
        updateGearStatsCheckbox()
      end
      if isModuleEnabled() then
        updateAllSlots("player")
      end
    end)
  end

  -- Hook InspectFrame OnShow if loaded or when loaded
  local function hookInspect()
    if InspectFrame and not InspectFrame._shInfoDisplayHooked then
      InspectFrame._shInfoDisplayHooked = true
      InspectFrame:HookScript("OnShow", function()
        if isModuleEnabled() then
          updateAllSlots("target")
        end
      end)
    end
  end
  hookInspect()
  self:RegisterEvent("ADDON_LOADED", function(_, addonName)
    if addonName == "Blizzard_InspectUI" then
      hookInspect()
    end
  end)

  if not (db and db.profile and db.profile.infoDisplay and db.profile.infoDisplay.enabled) then
    self:Disable()
  end
end

function module:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
  self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slotId)
    if CharacterFrame and CharacterFrame:IsShown() then
      if slotId then
        updateSlot("player", slotId)
      else
        updateAllSlots("player")
      end
    end
  end)
  self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unitId)
    if unitId == "player" then
      if CharacterFrame and CharacterFrame:IsShown() then
        updateAllSlots("player")
      end
    elseif unitId == "target" then
      if InspectFrame and InspectFrame:IsShown() then
        updateAllSlots("target")
      end
    end
  end)
  self:RegisterEvent("INSPECT_READY", function()
    if InspectFrame and InspectFrame:IsShown() then
      updateAllSlots("target")
    end
  end)
  self:RegisterEvent("BAG_UPDATE_DELAYED", "Refresh")
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  for _, overlay in ipairs(createdOverlays) do
    overlay:Hide()
  end
end

