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
local FONT_SIZE_LEVEL = 13
local FONT_SIZE_TRACK = 8
local FONT_SIZE_STATS = 9
local FONT_OUTLINE = "OUTLINE"

local function getStatsFont()
  if NumberFontNormalSmall then
    local font = NumberFontNormalSmall:GetFont()
    if font then return font end
  end
  return STATS_FONT
end

local COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
local COLOR_GREY = { r = 0.7, g = 0.7, b = 0.7, a = 1 }
local COLOR_TINT = { r = 0, g = 0, b = 0, a = 0.33 }

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
  [9]  = { id = 9,  side = "LEFT",  name = "Wrist",         canEnchant = true },
  [10] = { id = 10, side = "RIGHT", name = "Hands",         canEnchant = false },
  [11] = { id = 11, side = "RIGHT", name = "Finger0",       canEnchant = true },
  [12] = { id = 12, side = "RIGHT", name = "Finger1",       canEnchant = true },
  [13] = { id = 13, side = "RIGHT", name = "Trinket0",       canEnchant = false },
  [14] = { id = 14, side = "RIGHT", name = "Trinket1",       canEnchant = false },
  [15] = { id = 15, side = "LEFT",  name = "Back",          canEnchant = true },
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
    secondaryStats = true,
    tertiaryStats = true,
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

--- Returns high watermark color based on item level and track presence.
--- - White: No Track, below Adventurer ilevel 266
--- - Green: 266 to 276
--- - Blue: 279 to 289
--- - Purple: 292 to 302
--- - Orange: 305 to 315
--- - Golden: 318+
---@param itemLevel number|nil
---@param hasTrack boolean
---@return table
local function getWatermarkColor(itemLevel, hasTrack)
  if not hasTrack or not itemLevel or itemLevel < 266 then
    return getQualityColor(1) -- White (Common)
  elseif itemLevel <= 276 then
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
  if B <= 0 then return 0 end
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
  if D <= 0 then return 0 end
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
  local currentRating = (GetCombatRating and GetCombatRating(crId)) or 0
  local currentBonus = (GetCombatRatingBonus and GetCombatRatingBonus(crId)) or 0

  if currentRating > 0 and currentBonus > 0 then
    local unDiminishedBonus = undiminishSecondaryPercent(currentBonus)
    if unDiminishedBonus > 0 then
      return currentRating / unDiminishedBonus
    end
  end

  -- Fallback level scaling (scaled to level 80 baseline)
  local playerLevel = (UnitLevel and UnitLevel("player")) or 80
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
  if not k or k <= 0 then return 0 end

  local currentRating = (GetCombatRating and GetCombatRating(crId)) or 0
  local ratingWithoutItem = math.max(0, currentRating - itemStatRating)

  local B_total = currentRating / k
  local B_base = ratingWithoutItem / k

  local D_total = calculateSecondaryDiminishedPercent(B_total)
  local D_base = calculateSecondaryDiminishedPercent(B_base)

  local pctIncrease = math.max(0, D_total - D_base)

  -- For Mastery, multiply by the active specialization's mastery coefficient
  if crId == CR_MASTERY and GetMasteryEffect then
    local _, bonusCoeff = GetMasteryEffect()
    if bonusCoeff and bonusCoeff > 0 then
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
  if B <= 0 then return 0 end
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

  local currentRating = (GetCombatRating and GetCombatRating(crId)) or 0
  local currentBonus = (GetCombatRatingBonus and GetCombatRatingBonus(crId)) or 0

  local k
  if currentRating > 0 and currentBonus > 0 then
    k = currentRating / currentBonus
  else
    local playerLevel = (UnitLevel and UnitLevel("player")) or 80
    local levelScale = playerLevel / 80
    if statType == "SPEED" then k = 500 * levelScale
    elseif statType == "LEECH" then k = 450 * levelScale
    elseif statType == "AVOIDANCE" then k = 450 * levelScale
    else k = 500 * levelScale end
  end

  local ratingWithoutItem = math.max(0, currentRating - itemStatRating)
  local B_total = currentRating / k
  local B_base = ratingWithoutItem / k

  local D_total = calculateTertiaryDiminishedPercent(statType, B_total)
  local D_base = calculateTertiaryDiminishedPercent(statType, B_base)

  return math.max(0, D_total - D_base)
end

--- Formats an enchantment string to show its stat values (e.g. "+29 Haste", "+50 Primary")
--- or effect name if it's a non-stat proc/effect.
---@param itemLink string Full item link
---@param rawEnchantText string Text extracted from tooltip enchant line
---@param enchantAtlas string|nil Optional quality tier atlas icon
---@param slotId number Equipment slot ID
---@return string
local function getEnchantDisplayText(itemLink, rawEnchantText, enchantAtlas, slotId)
  if not rawEnchantText or rawEnchantText == "" then return "" end

  local cleanText = rawEnchantText
  local atlas = enchantAtlas
  if not atlas or atlas == "" then
    local matchedText, matchedAtlas = rawEnchantText:match("(.*)|A:(.-):%d+:%d+|a")
    if matchedText and matchedAtlas then
      cleanText = matchedText
      atlas = matchedAtlas
    end
  end

  cleanText = cleanText:gsub("^%s*[%+]*%s*", ""):gsub("%s*$", "")

  local num, stat = cleanText:match("^(%d+)%s+([%a%s]+)$")
  if num and stat then
    local formatted = "+" .. num .. " " .. stat
    if atlas and atlas ~= "" then
      return "|A:" .. atlas .. ":12:12|a " .. formatted
    end
    return formatted
  end

  local statText = nil
  local itemPayload = itemLink and itemLink:match("item:([%-?%d:]+)")
  if itemPayload then
    local parts = { strsplit(":", itemPayload) }
    local enchantID = tonumber(parts[2])
    if enchantID and enchantID > 0 then
      parts[2] = "0"
      local linkWithoutEnchant = "item:" .. table.concat(parts, ":")

      local statsWith = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)) or {}
      local statsWithout = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(linkWithoutEnchant)) or {}

      local diffs = {}
      for k, v in pairs(statsWith) do
        local d = v - (statsWithout[k] or 0)
        if d > 0 then
          diffs[k] = d
        end
      end

      local str = diffs["ITEM_MOD_STRENGTH_SHORT"] or diffs["ITEM_MOD_STRENGTH"]
      local agi = diffs["ITEM_MOD_AGILITY_SHORT"] or diffs["ITEM_MOD_AGILITY"]
      local int = diffs["ITEM_MOD_INTELLECT_SHORT"] or diffs["ITEM_MOD_INTELLECT"]
      local primaryVal = str or agi or int

      local haste = diffs["ITEM_MOD_HASTE_RATING_SHORT"] or diffs["ITEM_MOD_HASTE_RATING"]
      local crit = diffs["ITEM_MOD_CRIT_RATING_SHORT"] or diffs["ITEM_MOD_CRIT_RATING"]
      local mastery = diffs["ITEM_MOD_MASTERY_RATING_SHORT"] or diffs["ITEM_MOD_MASTERY_RATING"]
      local vers = diffs["ITEM_MOD_VERSATILITY"] or diffs["ITEM_MOD_VERSATILITY_RATING_SHORT"]
      local stam = diffs["ITEM_MOD_STAMINA_SHORT"] or diffs["ITEM_MOD_STAMINA"]
      local speed = diffs["ITEM_MOD_CR_SPEED_SHORT"] or diffs["ITEM_MOD_CR_SPEED"]
      local leech = diffs["ITEM_MOD_CR_LIFESTEAL_SHORT"] or diffs["ITEM_MOD_CR_LIFESTEAL"]
      local avoid = diffs["ITEM_MOD_CR_AVOIDANCE_SHORT"] or diffs["ITEM_MOD_CR_AVOIDANCE"]

      if primaryVal and (slotId == 5 or (str and agi and int) or cleanText:find("Worldsoul", 1, true) or cleanText:find("Radiance", 1, true)) then
        statText = string.format("+%d Primary", primaryVal)
      elseif haste then
        statText = string.format("+%d Haste", haste)
      elseif crit then
        statText = string.format("+%d Crit", crit)
      elseif mastery then
        statText = string.format("+%d Mastery", mastery)
      elseif vers then
        statText = string.format("+%d Vers", vers)
      elseif speed then
        statText = string.format("+%d Speed", speed)
      elseif leech then
        statText = string.format("+%d Leech", leech)
      elseif avoid then
        statText = string.format("+%d Avoid", avoid)
      elseif primaryVal then
        statText = string.format("+%d Primary", primaryVal)
      elseif stam then
        statText = string.format("+%d Stam", stam)
      end
    end
  end

  if not statText then
    local cleaned = cleanText:gsub("^Enchant%s+[%a%s]+%s*-%s*", "")
    cleaned = cleaned:gsub("^Enchant%s*-%s*", "")

    local lower = cleaned:lower()
    if lower:find("worldsoul") or lower:find("radiance") then
      statText = "+50 Primary"
    elseif lower:find("alacrity") or (lower:find("haste") and not lower:find("cursed")) then
      statText = "+29 Haste"
    elseif lower:find("tenacity") or (lower:find("versatility") and not lower:find("cursed")) then
      statText = "+29 Vers"
    elseif lower:find("fury") or (lower:find("crit") and not lower:find("cursed")) then
      statText = "+29 Crit"
    elseif lower:find("mastery") and not lower:find("cursed") then
      statText = "+29 Mastery"
    else
      statText = cleaned
    end
  end

  if atlas and atlas ~= "" then
    return "|A:" .. atlas .. ":12:12|a " .. statText
  end
  return statText
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
  if slotOverlay then return slotOverlay end

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
  level:SetPoint("CENTER", slotOverlay, "CENTER", 0, 4)
  level:SetFont(DEFAULT_FONT, FONT_SIZE_LEVEL, FONT_OUTLINE)
  level:SetJustifyH("CENTER")
  slotOverlay.Level = level

  -- Upgrade Track: anchored underneath centered to item level
  local track = slotOverlay:CreateFontString(frameName .. "Track", "OVERLAY", "GameTooltipText")
  track:SetPoint("TOP", level, "BOTTOM", 0, -1)
  track:SetFont(DEFAULT_FONT, FONT_SIZE_TRACK, FONT_OUTLINE)
  track:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
  track:SetJustifyH("CENTER")
  slotOverlay.Track = track

  -- Side Summary Frame: sits off to the side where enchants and gems display
  local relativePoint = slot.side == "LEFT" and "RIGHT" or "LEFT"
  local offsetX = slot.side == "LEFT" and 8 or -8

  local sideSummary = CreateFrame("Frame", frameName .. "SideSummary", slotOverlay)
  sideSummary:SetSize(130, 37)
  sideSummary:SetPoint(slot.side, slotOverlay, relativePoint, offsetX, 0)
  sideSummary:EnableMouse(true)
  sideSummary:SetFrameLevel(slotOverlay:GetFrameLevel() + 10)
  slotOverlay.SideSummary = sideSummary

  -- Stats summary font string (multi-line)
  local statsText = sideSummary:CreateFontString(frameName .. "SideStats", "OVERLAY", "GameTooltipText")
  statsText:SetAllPoints(sideSummary)
  statsText:SetFont(getStatsFont(), FONT_SIZE_STATS, FONT_OUTLINE)
  statsText:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
  statsText:SetJustifyH(slot.side == "RIGHT" and "RIGHT" or "LEFT")
  statsText:SetJustifyV("MIDDLE")
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
    GameTooltip:AddLine("Stat & Enhancement Breakdown", 1, 0.82, 0)

    if data.statsList and #data.statsList > 0 then
      for _, stat in ipairs(data.statsList) do
        GameTooltip:AddLine(" ")
        local rightText = string.format("+%d  (+%.1f%%)", stat.total, stat.pct)
        GameTooltip:AddDoubleLine(stat.name, rightText, 1, 1, 1, 0, 1, 0)

        if stat.base > 0 then
          GameTooltip:AddDoubleLine("  Item Base:", string.format("+%d", stat.base), 0.75, 0.75, 0.75, 1, 1, 1)
        end
        if stat.enchant > 0 then
          local desc = stat.enchantDesc and ("  Enchant (" .. stat.enchantDesc .. "):") or "  Enchant:"
          GameTooltip:AddDoubleLine(desc, string.format("+%d", stat.enchant), 0.75, 0.75, 0.75, 0.2, 1, 0.4)
        end
        if stat.gems then
          for _, g in ipairs(stat.gems) do
            local desc = g.name and ("  Gem (" .. g.name .. "):") or "  Gem:"
            GameTooltip:AddDoubleLine(desc, string.format("+%d", g.amount), 0.75, 0.75, 0.75, 0.4, 0.8, 1)
          end
        end
      end
    end

    if data.enchantEffect and data.enchantEffect ~= "" then
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine("Enchant:", data.enchantEffect, 1, 0.82, 0, 0.2, 1, 0.4)
    end

    if data.gemsList and #data.gemsList > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Slotted Gems:", 1, 0.82, 0)
      for _, g in ipairs(data.gemsList) do
        GameTooltip:AddDoubleLine("  " .. g.name, g.statSummary or "", 1, 1, 1, 0.4, 0.8, 1)
      end
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

  local enchantPattern = ENCHANTED_TOOLTIP_LINE and ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)") or "Enchanted: (.*)"
  local enchantAtlasPattern = "(.*)|A:(.*):20:20|a"

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
          if enchantMatch:find("|A:") then
            itemEnchant, itemEnchantAtlas = enchantMatch:match(enchantAtlasPattern)
          else
            itemEnchant = enchantMatch
          end
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
              trackText = string.format("%s/%s %s", cur, maxR, abbrev)
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
        if enchantMatch:find("|A:") then
          itemEnchant, itemEnchantAtlas = enchantMatch:match(enchantAtlasPattern)
        else
          itemEnchant = enchantMatch
        end
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
            trackText = string.format("%s/%s %s", cur, maxR, abbrev)
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
  -- 2. Item Level Display & Watermark Coloring (Center Anchor)
  -- --------------------------------------------------------------------------
  slotOverlay.Level:ClearAllPoints()
  slotOverlay.Level:SetPoint("CENTER", slotOverlay, "CENTER", 0, 4)
  slotOverlay.Level:SetFont(DEFAULT_FONT, FONT_SIZE_LEVEL, FONT_OUTLINE)
  slotOverlay.Level:SetJustifyH("CENTER")

  if settings.itemLevel and itemLevel then
    slotOverlay.Level:SetText(tostring(itemLevel))
    if settings.highWatermarkColoring then
      local watermarkColor = getWatermarkColor(itemLevel, hasTrack)
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
  -- 3. Upgrade Track Display (Centered Underneath Item Level)
  -- --------------------------------------------------------------------------
  slotOverlay.Track:ClearAllPoints()
  slotOverlay.Track:SetPoint("TOP", slotOverlay.Level, "BOTTOM", 0, -1)
  slotOverlay.Track:SetFont(DEFAULT_FONT, FONT_SIZE_TRACK, FONT_OUTLINE)
  slotOverlay.Track:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
  slotOverlay.Track:SetJustifyH("CENTER")

  if settings.upgradeTrack and hasTrack and trackText ~= "" then
    slotOverlay.Track:SetText(trackText)
    slotOverlay.Track:Show()
  else
    slotOverlay.Track:SetText("")
    slotOverlay.Track:Hide()
  end

  -- --------------------------------------------------------------------------
  -- 4. Side Summary & Breakdown Calculation
  -- --------------------------------------------------------------------------
  local itemName = C_Item.GetItemInfo(itemLink) or "Item"
  local itemPayload = itemLink:match("item:([%-?%d:]+)")
  local payloadParts = itemPayload and { strsplit(":", itemPayload) } or {}
  local enchantID = tonumber(payloadParts[2])

  local totalStats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)) or {}

  -- Calculate enchant stat contribution
  local enchantStats = {}
  local enchantEffectText = nil
  local isMissingEnchant = false

  if itemEnchant ~= nil then
    enchantEffectText = getEnchantDisplayText(itemLink, itemEnchant, itemEnchantAtlas, slot.id)
  end

  if enchantID and enchantID > 0 then
    local partsWithoutEnchant = { unpack(payloadParts) }
    partsWithoutEnchant[2] = "0"
    local linkWithoutEnchant = "item:" .. table.concat(partsWithoutEnchant, ":")
    local statsWithout = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(linkWithoutEnchant)) or {}

    for k, v in pairs(totalStats) do
      local d = v - (statsWithout[k] or 0)
      if d > 0 then
        enchantStats[k] = d
      end
    end
  elseif slot.canEnchant then
    local _, _, _, _, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(itemLink)
    if itemEquipLoc ~= "INVTYPE_HOLDABLE" and itemEquipLoc ~= "INVTYPE_SHIELD" then
      isMissingEnchant = true
    end
  end

  -- Calculate gem contributions and identify slotted gems vs empty sockets
  local gemList = {}
  local totalGemStats = {}
  local missingGemCount = 0

  for socketIndex = 1, 3 do
    local gemID = tonumber(payloadParts[2 + socketIndex])
    local _, gemLink = C_Item.GetItemGem and C_Item.GetItemGem(itemLink, socketIndex)
    if (not gemLink or gemLink == "") and gemID and gemID > 0 then
      gemLink = select(2, C_Item.GetItemInfo(gemID)) or ("item:" .. gemID)
    end

    if gemID and gemID > 0 then
      local gStats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats("item:" .. gemID)) or {}
      local gName = C_Item.GetItemInfo(gemID) or ("Gem " .. socketIndex)

      local statParts = {}
      for k, v in pairs(gStats) do
        totalGemStats[k] = (totalGemStats[k] or 0) + v
        local sInfo = SECONDARY_STAT_KEYS[k] or TERTIARY_STAT_KEYS[k]
        if sInfo then
          table.insert(statParts, "+" .. v .. " " .. sInfo.suffix)
        end
      end

      table.insert(gemList, {
        id = gemID,
        name = gName,
        link = gemLink,
        stats = gStats,
        statSummary = table.concat(statParts, ", "),
      })
    elseif socketIndex <= itemSocketCount then
      missingGemCount = missingGemCount + 1
    end
  end

  -- Collect active secondary and tertiary stats with breakdown data
  local activeStats = {}
  local sideSummaryLines = {}

  -- Process Secondary stats
  local foundSecondary = {}
  for statKey, statInfo in pairs(SECONDARY_STAT_KEYS) do
    local total = totalStats[statKey]
    if total and total > 0 and not foundSecondary[statInfo.type] then
      foundSecondary[statInfo.type] = true
      local enchantVal = enchantStats[statKey] or 0
      local gemVal = totalGemStats[statKey] or 0
      local baseVal = math.max(0, total - enchantVal - gemVal)
      local pct = calculateSecondaryStatIncrease(statInfo.cr, total)

      local statGems = {}
      for _, g in ipairs(gemList) do
        local gAmt = g.stats[statKey]
        if gAmt and gAmt > 0 then
          table.insert(statGems, { name = g.name, amount = gAmt })
        end
      end

      table.insert(activeStats, {
        type = statInfo.type,
        name = statInfo.name,
        suffix = statInfo.suffix,
        order = statInfo.order,
        total = total,
        base = baseVal,
        enchant = enchantVal,
        enchantDesc = enchantEffectText,
        gems = statGems,
        pct = pct,
        isTertiary = false,
      })

      if settings.secondaryStats then
        table.insert(sideSummaryLines, {
          order = statInfo.order,
          text = string.format("+%d %s (+%.1f%%)", total, statInfo.suffix, pct),
        })
      end
    end
  end

  -- Process Tertiary stats
  local foundTertiary = {}
  for statKey, statInfo in pairs(TERTIARY_STAT_KEYS) do
    local total = totalStats[statKey]
    if total and total > 0 and not foundTertiary[statInfo.type] then
      foundTertiary[statInfo.type] = true
      local enchantVal = enchantStats[statKey] or 0
      local gemVal = totalGemStats[statKey] or 0
      local baseVal = math.max(0, total - enchantVal - gemVal)
      local pct = calculateTertiaryStatIncrease(statInfo.type, statInfo.cr, total)

      local statGems = {}
      for _, g in ipairs(gemList) do
        local gAmt = g.stats[statKey]
        if gAmt and gAmt > 0 then
          table.insert(statGems, { name = g.name, amount = gAmt })
        end
      end

      table.insert(activeStats, {
        type = statInfo.type,
        name = statInfo.name,
        suffix = statInfo.suffix,
        order = 10 + statInfo.order,
        total = total,
        base = baseVal,
        enchant = enchantVal,
        enchantDesc = enchantEffectText,
        gems = statGems,
        pct = pct,
        isTertiary = true,
      })

      if settings.tertiaryStats then
        table.insert(sideSummaryLines, {
          order = 10 + statInfo.order,
          text = string.format("+%d %s (+%.1f%%)", total, statInfo.suffix, pct),
        })
      end
    end
  end

  table.sort(activeStats, function(a, b) return a.order < b.order end)
  table.sort(sideSummaryLines, function(a, b) return a.order < b.order end)

  -- Save breakdown data onto the SideSummary frame for hover tooltip
  slotOverlay.SideSummary.breakdownData = {
    itemName = itemName,
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

  -- Position stats text according to whether missing icons are present
  sideSummary.StatsText:ClearAllPoints()
  if showMissingEnchant or showMissingGem then
    if slot.side == "LEFT" then
      sideSummary.StatsText:SetPoint("TOPLEFT", sideSummary, "TOPLEFT", 0, 0)
      sideSummary.StatsText:SetPoint("BOTTOMRIGHT", sideSummary, "BOTTOMRIGHT", 0, 16)
    else
      sideSummary.StatsText:SetPoint("TOPRIGHT", sideSummary, "TOPRIGHT", 0, 0)
      sideSummary.StatsText:SetPoint("BOTTOMLEFT", sideSummary, "BOTTOMLEFT", 0, 16)
    end
    sideSummary.StatsText:SetJustifyV("TOP")
  else
    sideSummary.StatsText:SetAllPoints(sideSummary)
    sideSummary.StatsText:SetJustifyV("MIDDLE")
  end

  -- Hide side summary if everything is empty and no alerts
  if summaryString == "" and not showMissingEnchant and not showMissingGem then
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

--- Refreshes all active character sheet equipment overlays.
function module:Refresh()
  if not isModuleEnabled() then
    for _, overlay in ipairs(createdOverlays) do
      overlay:Hide()
    end
    return
  end

  updateAllSlots("player")
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
end

function module:OnInitialize()
  -- Hook CharacterFrame OnShow to ensure slots refresh immediately when opened
  if CharacterFrame then
    CharacterFrame:HookScript("OnShow", function()
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
    if slotId then
      updateSlot("player", slotId)
    else
      updateAllSlots("player")
    end
  end)
  self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unitId)
    if unitId == "player" or unitId == "target" then
      updateAllSlots(unitId)
    end
  end)
  self:RegisterEvent("INSPECT_READY", function()
    updateAllSlots("target")
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

