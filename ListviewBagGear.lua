setfenv(1, _G.SlackHacks)

local gear = {}
Self.ListviewBagGear = gear

local slots = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
  INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
  INVTYPE_TABARD = { 19 },
}

local primary = {
  ITEM_MOD_STRENGTH_SHORT = true, ITEM_MOD_AGILITY_SHORT = true,
  ITEM_MOD_INTELLECT_SHORT = true, ITEM_MOD_STAMINA_SHORT = true,
  ITEM_MOD_SPIRIT_SHORT = true,
}

local abbreviations = {
  ITEM_MOD_STRENGTH_SHORT = "Str", ITEM_MOD_AGILITY_SHORT = "Agi",
  ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_STAMINA_SHORT = "Stam",
  ITEM_MOD_SPIRIT_SHORT = "Spi", ITEM_MOD_CRIT_RATING_SHORT = "Crit",
  ITEM_MOD_HASTE_RATING_SHORT = "Haste", ITEM_MOD_MASTERY_RATING_SHORT = "Mastery",
  ITEM_MOD_VERSATILITY = "Vers", ITEM_MOD_VERSATILITY_RATING_SHORT = "Vers",
  ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_SPELL_POWER_SHORT = "SP",
  ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
  ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}
local slotLabels = {
  [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2",
  [16] = "Main Hand", [17] = "Off Hand",
}

--- Check whether Titan's Grip permits the given two-handed weapon in the off hand.
---@param link string|nil Weapon hyperlink.
---@return boolean allowed Whether this weapon can be dual-wielded.
local function canDualWieldTwoHanded(link)
  if not link or not IsPlayerSpell or not IsPlayerSpell(46917)
    or not C_Item or not C_Item.GetItemInfoInstant then return false end
  local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
  return equipLoc == "INVTYPE_2HWEAPON" and classID == 2
    and (subclassID == 1 or subclassID == 5 or subclassID == 8)
end

--- Return the equipment slots against which an item can be compared.
---@param equipLoc string|nil Item inventory type.
---@param link string|nil Item hyperlink.
---@return table|nil slots Inventory slot IDs.
function gear.GetSlots(equipLoc, link)
  if equipLoc == "INVTYPE_2HWEAPON" and canDualWieldTwoHanded(link) then return { 16, 17 } end
  if isRetail() and (equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
      or equipLoc == "INVTYPE_THROWN") then return { 16 } end
  return slots[equipLoc]
end

--- Return a readable stat name, preferring compact labels for common stats.
---@param key string Blizzard item-stat identifier.
---@return string label Stat label.
function gear.StatLabel(key)
  if abbreviations[key] then return abbreviations[key] end
  local localized = _G[key]
  if type(localized) == "string" then
    localized = localized:gsub("%%[%d%$.+-]*[dsf]", ""):gsub("^%s*%+?%s*", ""):gsub("%s+$", "")
    if localized ~= "" then return localized end
  end
  return key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower()
end

--- Compare numeric item stats to a single equipped item.
---@param itemStats table Candidate item stats.
---@param equippedStats table Equipped item stats.
---@param slot number Equipment slot ID.
---@return table comparison Changed stats and primary/secondary sort totals.
function gear.CompareStats(itemStats, equippedStats, slot)
  local keys = {}
  for key, value in pairs(itemStats) do
    if type(key) == "string" and key:match("^ITEM_MOD_") and type(value) == "number" then keys[key] = true end
  end
  for key, value in pairs(equippedStats) do
    if type(key) == "string" and key:match("^ITEM_MOD_") and type(value) == "number" then keys[key] = true end
  end
  local result = { slot = slot, changes = {}, primary = 0, secondary = 0, hasLoss = false, hasGain = false }
  for key in pairs(keys) do
    local itemValue = type(itemStats[key]) == "number" and itemStats[key] or 0
    local equippedValue = type(equippedStats[key]) == "number" and equippedStats[key] or 0
    local delta = itemValue - equippedValue
    if delta ~= 0 then
      result.changes[#result.changes + 1] = { key = key, value = delta }
      if primary[key] then result.primary = result.primary + delta
      else result.secondary = result.secondary + delta end
      if delta < 0 then result.hasLoss = true else result.hasGain = true end
    end
  end
  table.sort(result.changes, function(a, b)
    if not not primary[a.key] ~= not not primary[b.key] then return not not primary[a.key] end
    return gear.StatLabel(a.key) < gear.StatLabel(b.key)
  end)
  return result
end

--- Build comparisons for every compatible equipment slot.
---@param link string Item hyperlink.
---@param equipLoc string Item inventory type.
---@return table|nil comparisons Comparison for each slot, or nil while item data is unavailable.
---@return table|nil itemStats Candidate item's stats.
function gear.CompareItem(link, equipLoc)
  local applicable = gear.GetSlots(equipLoc, link)
  if not applicable or not link or not C_Item or not C_Item.GetItemStats then return nil end
  local itemStats = C_Item.GetItemStats(link)
  if not itemStats then return nil end
  local results = {}
  for _, slot in ipairs(applicable) do
    local equippedLink = GetInventoryItemLink("player", slot)
    if not equippedLink and GetInventoryItemID and GetInventoryItemID("player", slot) then return nil end
    local replacesMainHand
    if slot == 17 and not equippedLink and C_Item.GetItemInfoInstant then
      local mainHand = GetInventoryItemLink("player", 16)
      -- An off-hand item displaces a two-hander unless Titan's Grip supports that weapon.
      if mainHand and select(4, C_Item.GetItemInfoInstant(mainHand)) == "INVTYPE_2HWEAPON"
        and not canDualWieldTwoHanded(mainHand) then
        equippedLink, replacesMainHand = mainHand, true
      end
    end
    local equippedStats = equippedLink and C_Item.GetItemStats(equippedLink)
    if not equippedLink then equippedStats = {} end
    if not equippedStats then return nil end
    local combined
    if equipLoc == "INVTYPE_2HWEAPON" and #applicable == 1 then
      local offhandLink = GetInventoryItemLink("player", 17)
      if not offhandLink and GetInventoryItemID and GetInventoryItemID("player", 17) then return nil end
      if offhandLink then
        local offhandStats = C_Item.GetItemStats(offhandLink)
        if not offhandStats then return nil end
        local total = {}
        for key, value in pairs(equippedStats) do total[key] = value end
        for key, value in pairs(offhandStats) do
          if type(value) == "number" then
            total[key] = (type(total[key]) == "number" and total[key] or 0) + value
          end
        end
        equippedStats, combined = total, true
      end
    end
    results[#results + 1] = gear.CompareStats(itemStats, equippedStats, slot)
    if combined then results[#results].label = "Both Hands" end
    if replacesMainHand then results[#results].label = "Replaces Main Hand" end
  end
  return results, itemStats
end

--- Format a comparison with colored stat changes.
---@param comparison table Compared slot and stat changes.
---@param includeSlot boolean Whether to prefix the slot number.
---@return string text Colored display text.
function gear.FormatComparison(comparison, includeSlot)
  local parts = {}
  for _, change in ipairs(comparison.changes) do
    local value = ("%+.2f"):format(change.value)
    if tonumber(value) ~= 0 then
      value = value:gsub("0+$", ""):gsub("%.$", "")
      local color = change.value > 0 and "ff40ff40" or "ffff4040"
      parts[#parts + 1] = ("|c%s%s %s|r"):format(color, value, gear.StatLabel(change.key))
    end
  end
  local text = #parts > 0 and table.concat(parts, ", ") or "No change"
  local label = comparison.label or slotLabels[comparison.slot] or tostring(comparison.slot)
  return (includeSlot or comparison.label) and (label .. ": " .. text) or text
end

--- Decide whether at least one equipped slot is strictly better in the displayed stats.
---@param comparisons table|nil Equipment-slot comparisons.
---@return boolean downgrade Whether a comparison has losses and no gains.
function gear.IsDowngrade(comparisons)
  for _, comparison in ipairs(comparisons or {}) do
    if comparison.hasLoss and not comparison.hasGain then return true end
  end
  return false
end
