setfenv(1, _G.SlackHacks)

--[[
  InfoDisplay - Character Sheet Equipment Information Overlay.
  Displays item levels, upgrade tracks, secondary and tertiary stats (with diminishing returns),
  high watermark quality coloring, enchants, and gem sockets on character sheet equipment icons.
]]--

local module = Self:NewModule("InfoDisplay", "AceEvent-3.0")
Self.InfoDisplay = module

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local STATS_FONT = "Fonts\\ARIALN.TTF"
local FONT_SIZE_LEVEL = 11
local FONT_SIZE_TRACK = 8
local FONT_SIZE_STATS = 7
local FONT_SIZE_ENCHANT = 10
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
local COLOR_ENCHANT_HAVE = { r = 0, g = 1, b = 0, a = 1 }
local COLOR_ENCHANT_MISSING = { r = 1, g = 0, b = 0, a = 1 }
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

-- Map item stat tokens from C_Item.GetItemStats to our internal identifiers
local SECONDARY_STAT_KEYS = {
  ["ITEM_MOD_CRIT_RATING_SHORT"]        = { type = "CRIT", cr = CR_CRIT, suffix = "C", order = 1 },
  ["ITEM_MOD_CRIT_RATING"]              = { type = "CRIT", cr = CR_CRIT, suffix = "C", order = 1 },
  ["ITEM_MOD_CRIT_MELEE_RATING_SHORT"]  = { type = "CRIT", cr = CR_CRIT, suffix = "C", order = 1 },
  ["ITEM_MOD_CRIT_RANGED_RATING_SHORT"] = { type = "CRIT", cr = CR_CRIT, suffix = "C", order = 1 },
  ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"]  = { type = "CRIT", cr = CR_CRIT, suffix = "C", order = 1 },

  ["ITEM_MOD_HASTE_RATING_SHORT"]       = { type = "HASTE", cr = CR_HASTE, suffix = "H", order = 2 },
  ["ITEM_MOD_HASTE_RATING"]             = { type = "HASTE", cr = CR_HASTE, suffix = "H", order = 2 },
  ["ITEM_MOD_HASTE_MELEE_RATING_SHORT"] = { type = "HASTE", cr = CR_HASTE, suffix = "H", order = 2 },
  ["ITEM_MOD_HASTE_RANGED_RATING_SHORT"]= { type = "HASTE", cr = CR_HASTE, suffix = "H", order = 2 },
  ["ITEM_MOD_HASTE_SPELL_RATING_SHORT"] = { type = "HASTE", cr = CR_HASTE, suffix = "H", order = 2 },

  ["ITEM_MOD_MASTERY_RATING_SHORT"]     = { type = "MASTERY", cr = CR_MASTERY, suffix = "M", order = 3 },
  ["ITEM_MOD_MASTERY_RATING"]           = { type = "MASTERY", cr = CR_MASTERY, suffix = "M", order = 3 },

  ["ITEM_MOD_VERSATILITY"]              = { type = "VERSATILITY", cr = CR_VERS, suffix = "V", order = 4 },
  ["ITEM_MOD_VERSATILITY_RATING_SHORT"] = { type = "VERSATILITY", cr = CR_VERS, suffix = "V", order = 4 },
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

--- Format stat amount and percentage increase cleanly.
--- E.g. "112M (+0.5%)"
---@param amount number
---@param suffix string
---@param pct number
---@return string
local function formatStatString(amount, suffix, pct)
  local pctStr
  if pct >= 0.05 then
    pctStr = string.format("(+%.1f%%)", pct)
  elseif pct > 0 then
    pctStr = string.format("(+%.2f%%)", pct)
  else
    pctStr = "(+0.0%)"
  end
  return string.format("%d%s %s", amount, suffix, pctStr)
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

  -- Clean out any quality atlas embedded in rawEnchantText if not already separated
  local cleanText = rawEnchantText
  local atlas = enchantAtlas
  if not atlas or atlas == "" then
    local matchedText, matchedAtlas = rawEnchantText:match("(.*)|A:(.-):%d+:%d+|a")
    if matchedText and matchedAtlas then
      cleanText = matchedText
      atlas = matchedAtlas
    end
  end

  -- Strip leading "+" or whitespace
  cleanText = cleanText:gsub("^%s*[%+]*%s*", ""):gsub("%s*$", "")

  -- If raw text is already a short stat like "29 Haste" or "+29 Haste"
  local num, stat = cleanText:match("^(%d+)%s+([%a%s]+)$")
  if num and stat then
    local formatted = "+" .. num .. " " .. stat
    if atlas and atlas ~= "" then
      return "|A:" .. atlas .. ":12:12|a " .. formatted
    end
    return formatted
  end

  local statText = nil

  -- Compute stat delta between itemLink with and without enchantID
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

      -- Check primary stats (Chest enchants like Mark of the Worldsoul, Crystalline Radiance, etc.)
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
    -- Strip verbose "Enchant <Slot> - " prefixes to leave effect or stat name
    local cleaned = cleanText:gsub("^Enchant%s+[%a%s]+%s*-%s*", "")
    cleaned = cleaned:gsub("^Enchant%s*-%s*", "")

    -- Match known stat keywords in the remaining name
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
      -- If it's a named effect, display the effect name
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

  -- Item Level: center top anchor of icon
  local level = slotOverlay:CreateFontString(frameName .. "Level", "OVERLAY", "GameTooltipText")
  level:SetPoint("TOP", slotOverlay, "TOP", 0, -2)
  level:SetFont(DEFAULT_FONT, FONT_SIZE_LEVEL, FONT_OUTLINE)
  level:SetJustifyH("CENTER")
  slotOverlay.Level = level

  -- Upgrade Track: anchored under center of item level, small text in white
  local track = slotOverlay:CreateFontString(frameName .. "Track", "OVERLAY", "GameTooltipText")
  track:SetPoint("TOP", level, "BOTTOM", 0, 0)
  track:SetFont(DEFAULT_FONT, FONT_SIZE_TRACK, FONT_OUTLINE)
  track:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
  track:SetJustifyH("CENTER")
  slotOverlay.Track = track

  -- Secondary Stats: bottom left corner of icon
  local secondary = slotOverlay:CreateFontString(frameName .. "Secondary", "OVERLAY", "GameTooltipText")
  secondary:SetPoint("BOTTOMLEFT", slotOverlay, "BOTTOMLEFT", 1, 1)
  secondary:SetFont(getStatsFont(), FONT_SIZE_STATS, FONT_OUTLINE)
  secondary:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a)
  secondary:SetJustifyH("LEFT")
  slotOverlay.Secondary = secondary

  -- Enchant text (matches Liq style and position)
  local relativePoint = slot.side == "LEFT" and "RIGHT" or "LEFT"
  local offsetX = slot.side == "LEFT" and 9 or -10
  local offsetEnchantY = (slot.id == 16 or slot.id == 17) and -12 or 8

  local enchant = slotOverlay:CreateFontString(frameName .. "Enchant", "OVERLAY", "GameTooltipText")
  enchant:SetPoint(slot.side, slotOverlay, relativePoint, offsetX, offsetEnchantY)
  enchant:SetWidth(120)
  enchant:SetWordWrap(false)
  enchant:SetFont(DEFAULT_FONT, FONT_SIZE_ENCHANT, FONT_OUTLINE)
  enchant:SetJustifyH(slot.side == "RIGHT" and "RIGHT" or "LEFT")
  slotOverlay.Enchant = enchant

  -- Gem sockets buttons (matches Liq style and position)
  slotOverlay.Sockets = {}
  for socketIndex = 1, 3 do
    local socketFrame = CreateFrame("Button", frameName .. "Socket" .. socketIndex, slotOverlay, "UIPanelButtonTemplate")
    socketFrame:SetSize(14, 14)
    socketFrame:EnableMouse(true)
    socketFrame:SetFrameLevel(slotOverlay:GetFrameLevel() + 10)
    local socketOffsetX = offsetX - 3 - (15 * (socketIndex - 1))
    if slot.side == "LEFT" then
      socketOffsetX = offsetX + 3 + (15 * (socketIndex - 1))
    end
    socketFrame:SetPoint(slot.side, slotOverlay, relativePoint, socketOffsetX, 0)
    slotOverlay.Sockets[socketIndex] = socketFrame
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
  -- 2. Item Level Display & Watermark Coloring (Center Top Anchor)
  -- --------------------------------------------------------------------------
  slotOverlay.Level:ClearAllPoints()
  slotOverlay.Level:SetPoint("TOP", slotOverlay, "TOP", 0, -2)
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
  -- 3. Upgrade Track Display (Anchored Below Item Level)
  -- --------------------------------------------------------------------------
  slotOverlay.Track:ClearAllPoints()
  slotOverlay.Track:SetPoint("TOP", slotOverlay.Level, "BOTTOM", 0, 0)
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
  -- 4. Secondary & Tertiary Stats Display
  -- --------------------------------------------------------------------------
  local secondaryFormattedLines = {}
  local tertiaryFormattedLines = {}

  local itemStats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(itemLink)) or {}

  -- Collect secondary stats
  local foundSecondary = {}
  for statKey, statInfo in pairs(SECONDARY_STAT_KEYS) do
    local amount = itemStats[statKey]
    if amount and amount > 0 and not foundSecondary[statInfo.type] then
      foundSecondary[statInfo.type] = true
      local pct = calculateSecondaryStatIncrease(statInfo.cr, amount)
      table.insert(secondaryFormattedLines, {
        order = statInfo.order,
        amount = amount,
        text = formatStatString(amount, statInfo.suffix, pct),
      })
    end
  end
  table.sort(secondaryFormattedLines, function(a, b)
    if a.amount ~= b.amount then return a.amount > b.amount end
    return a.order < b.order
  end)

  -- Convert tables to display strings
  local secondaryText = ""
  if settings.secondaryStats and #secondaryFormattedLines > 0 then
    local lines = {}
    for _, item in ipairs(secondaryFormattedLines) do
      table.insert(lines, item.text)
    end
    secondaryText = table.concat(lines, "\n")
  end

  -- Position Secondary stats at bottom left of icon
  slotOverlay.Secondary:ClearAllPoints()
  slotOverlay.Secondary:SetPoint("BOTTOMLEFT", slotOverlay, "BOTTOMLEFT", 1, 1)
  slotOverlay.Secondary:SetFont(getStatsFont(), FONT_SIZE_STATS, FONT_OUTLINE)
  slotOverlay.Secondary:SetJustifyH("LEFT")

  if secondaryText ~= "" then
    slotOverlay.Secondary:SetText(secondaryText)
    slotOverlay.Secondary:Show()
  else
    slotOverlay.Secondary:SetText("")
    slotOverlay.Secondary:Hide()
  end

  if slotOverlay.Tertiary then
    slotOverlay.Tertiary:SetText("")
    slotOverlay.Tertiary:Hide()
  end

  -- --------------------------------------------------------------------------
  -- 5. Enchants (Style & Position from Liq)
  -- --------------------------------------------------------------------------
  local _, _, _, _, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(itemLink)
  local enchantText = ""
  local colorEnchant = COLOR_ENCHANT_HAVE

  if itemEnchant == nil then
    if slot.canEnchant then
      enchantText = "No enchant"
      colorEnchant = COLOR_ENCHANT_MISSING
      if settings.enchants and (itemEquipLoc ~= "INVTYPE_HOLDABLE" and itemEquipLoc ~= "INVTYPE_SHIELD") then
        slotOverlay.Enchant:Show()
      else
        slotOverlay.Enchant:Hide()
      end
    else
      slotOverlay.Enchant:Hide()
    end
  else
    enchantText = getEnchantDisplayText(itemLink, itemEnchant, itemEnchantAtlas, slot.id)
    if settings.enchants then
      slotOverlay.Enchant:Show()
    else
      slotOverlay.Enchant:Hide()
    end
  end

  slotOverlay.Enchant:SetText(enchantText)
  slotOverlay.Enchant:SetTextColor(colorEnchant.r, colorEnchant.g, colorEnchant.b, colorEnchant.a)

  if slot.id ~= 16 and slot.id ~= 17 then
    local point, relativeTo, relPoint, offX = slotOverlay.Enchant:GetPoint()
    if itemSocketCount > 0 or (slot.id == 9 or slot.id == 14) then
      slotOverlay.Enchant:SetPoint(point, relativeTo, relPoint, offX, 8)
    else
      slotOverlay.Enchant:SetPoint(point, relativeTo, relPoint, offX, 0)
    end
  end

  -- --------------------------------------------------------------------------
  -- 6. Gem Sockets (Style & Position from Liq)
  -- --------------------------------------------------------------------------
  local itemPayload = itemLink:match("item:([%-?%d:]+)")
  local payloadParts = itemPayload and { strsplit(":", itemPayload) } or {}

  for socketIndex = 1, 3 do
    local gemID = tonumber(payloadParts[2 + socketIndex])
    local _, gemLink = C_Item.GetItemGem and C_Item.GetItemGem(itemLink, socketIndex)
    if (not gemLink or gemLink == "") and gemID and gemID > 0 then
      gemLink = select(2, C_Item.GetItemInfo(gemID)) or ("item:" .. gemID)
    end

    if gemID and gemID > 0 and not itemSockets[socketIndex] and C_Item.GetItemIconByID then
      itemSockets[socketIndex] = C_Item.GetItemIconByID(gemID)
      itemSocketCount = math.max(itemSocketCount, socketIndex)
    end

    local socketFrame = slotOverlay.Sockets[socketIndex]
    local point, relativeTo, relPoint, offX = socketFrame:GetPoint()

    socketFrame.gemLink = gemLink
    socketFrame.gemID = gemID
    socketFrame.socketType = itemSocketTypes and itemSocketTypes[socketIndex]

    local shouldShowSocket = settings.gemSockets and (socketIndex <= itemSocketCount or (gemID and gemID > 0)) and itemSockets[socketIndex]

    if shouldShowSocket then
      socketFrame:SetNormalTexture(itemSockets[socketIndex])
      socketFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.gemLink then
          GameTooltip:SetHyperlink(self.gemLink)
        elseif self.gemID and self.gemID > 0 then
          GameTooltip:SetItemByID(self.gemID)
        elseif self.socketType then
          GameTooltip:SetText(self.socketType)
        else
          GameTooltip:SetText(EMPTY_SOCKET_PRISMATIC or "Prismatic Socket")
        end
        GameTooltip:Show()
      end)
      socketFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
      socketFrame:Show()
    else
      socketFrame:SetScript("OnEnter", nil)
      socketFrame:SetScript("OnLeave", nil)
      socketFrame:Hide()
    end

    if enchantText ~= "" or (slot.id == 9 or slot.id == 14) then
      socketFrame:SetPoint(point, relativeTo, relPoint, offX, -8)
    else
      socketFrame:SetPoint(point, relativeTo, relPoint, offX, 0)
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
