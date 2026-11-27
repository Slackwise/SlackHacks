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

-- A filter keeps its original GetItemStats keys, so existing unchecked settings remain usable.
local commonStatFilters = {
  { "Strength", "STRENGTH" }, { "Agility", "AGILITY" },
  { "Intellect", "INTELLECT" }, { "Stamina", "STAMINA" },
  { "Critical Strike", "CRIT_RATING", "CRIT_MELEE_RATING", "CRIT_RANGED_RATING", "CRIT_SPELL_RATING" },
  { "Haste", "HASTE_RATING", "HASTE_MELEE_RATING", "HASTE_RANGED_RATING", "HASTE_SPELL_RATING",
    "SPELL_HASTE_RATING" },
}
local retailStatFilters = {
  { "Mastery", "MASTERY_RATING" }, { "Versatility", "VERSATILITY", "VERSATILITY_RATING" },
  { "Leech", "CR_LIFESTEAL" }, { "Avoidance", "CR_AVOIDANCE" },
  { "Speed", "CR_SPEED" }, { "Indestructible", "CR_STURDINESS" },
}
local foreverStatFilters = {
  { "Spirit", "SPIRIT" },
  { "Attack Power", "ATTACK_POWER", "MELEE_ATTACK_POWER", "FERAL_ATTACK_POWER" },
  { "Ranged Attack Power", "RANGED_ATTACK_POWER" },
  { "Spell Power", "SPELL_POWER" },
  { "Spell Damage", "SPELL_DAMAGE_DONE", "FIRE_DAMAGE_DONE", "FROST_DAMAGE_DONE", "SHADOW_DAMAGE_DONE",
    "NATURE_DAMAGE_DONE", "ARCANE_DAMAGE_DONE", "HOLY_DAMAGE_DONE", "SPELL_DAMAGE_AND_HEALING_DONE" },
  { "Healing", "SPELL_HEALING_DONE", "HEALING_DONE", "BONUS_HEALING" },
  { "Hit Rating", "HIT_RATING", "HIT_MELEE_RATING", "HIT_RANGED_RATING", "HIT_SPELL_RATING" },
  { "Expertise", "EXPERTISE_RATING", "EXPERTISE" },
  { "Weapon Skill", "WEAPON_SKILL_RATING", "WEAPON_SKILL", "AXES", "TWOHANDED_AXES", "MACES",
    "TWOHANDED_MACES", "SWORDS", "TWOHANDED_SWORDS", "DAGGERS", "FIST_WEAPONS", "STAVES",
    "POLEARMS", "BOWS", "GUNS", "CROSSBOWS", "THROWN", "WANDS", "DUAL_WIELD" },
  { "Armor Penetration", "ARMOR_PENETRATION_RATING", "ARMOR_PENETRATION" },
  { "Spell Penetration", "SPELL_PENETRATION", "ARCANE_PENETRATION", "FIRE_PENETRATION",
    "FROST_PENETRATION", "NATURE_PENETRATION", "SHADOW_PENETRATION" },
  { "Defense", "DEFENSE_SKILL_RATING", "DEFENSE_SKILL" },
  { "Dodge", "DODGE_RATING" }, { "Parry", "PARRY_RATING" }, { "Block Chance", "BLOCK_RATING" },
  { "Mana per 5 Seconds", "MANA_REGENERATION", "POWER_REGEN0" },
  { "Health per 5 Seconds", "HEALTH_REGEN", "HEALTH_REGENERATION" },
}

--- Build the combat-stat choices supported by the current client.
---@return table choices Filter labels and their saved and matching stat keys.
function gear.StatFilterChoices()
  local choices = {}
  --- Add the known keys for each combat stat.
  ---@param definitions table Stat labels and Blizzard key stems.
  local function add(definitions)
    for _, definition in ipairs(definitions) do
      local keys = {}
      for index = 2, #definition do
        local stem = "ITEM_MOD_" .. definition[index]
        keys[#keys + 1], keys[#keys + 2] = stem .. "_SHORT", stem
      end
      choices[#choices + 1] = {
        key = keys[1], keys = keys,
        name = #definition == 2 and type(_G[keys[1]]) == "string" and _G[keys[1]] or definition[1],
      }
    end
  end
  add(commonStatFilters)
  if isRetail() then
    add(retailStatFilters)
  else
    add(foreverStatFilters)
    for _, choice in ipairs(choices) do
      if choice.key == "ITEM_MOD_ATTACK_POWER_SHORT" then
        choice.extraMatch = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER" }
      elseif choice.key == "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" then
        choice.extraMatch = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_POWER" }
      elseif choice.key == "ITEM_MOD_SPELL_HEALING_DONE_SHORT" then
        choice.extraMatch = { "ITEM_MOD_SPELL_DAMAGE_AND_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_DAMAGE_AND_HEALING_DONE",
          "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_POWER" }
      end
    end
    choices[#choices + 1] = {
      key = "RESISTANCE2_NAME", name = "Magic Resistances",
      keys = { "RESISTANCE2_NAME", "RESISTANCE3_NAME", "RESISTANCE4_NAME", "RESISTANCE5_NAME", "RESISTANCE6_NAME" },
    }
  end
  return choices
end

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
  if equipLoc == "INVTYPE_RELIC" and not isRetail() then return { 18 } end
  if isRetail() and (equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
      or equipLoc == "INVTYPE_THROWN") then return { 16 } end
  return slots[equipLoc]
end

local gearChoicesCache, gearChoicesClient, gearChoicesSubclassAPI

--- Collect supported, localized filter choices, merging labels that describe the same filter.
---@param equipmentSlots table Supported equipment inventory types.
---@return table groups Ordered filter groups and their choices.
function gear.FilterChoices(equipmentSlots)
  local client = isRetail() and "retail" or "classic"
  local subclassAPI = C_Item and C_Item.GetItemSubClassInfo
  if gearChoicesCache and gearChoicesClient == client and gearChoicesSubclassAPI == subclassAPI then
    return gearChoicesCache
  end
  local groups = { { name = "Armor and Weapons", key = "types", entries = {} },
    { name = "Equipment Slots", key = "slots", entries = {} },
    { name = "Stats", key = "stats", entries = gear.StatFilterChoices() } }
  --- Merge distinct Blizzard identifiers that share a localized label.
  ---@param section table Filter section.
  ---@param label string Display name.
  ---@param key string Saved filter identifier.
  local function addChoice(section, label, key)
    for _, entry in ipairs(section.entries) do
      if entry.name == label then entry.keys[#entry.keys + 1] = key; return end
    end
    section.entries[#section.entries + 1] = { key = key, keys = { key }, name = label }
  end
  if subclassAPI then
    -- Bear/cat claws and spears are internal or obsolete subclasses, not normal player gear.
    local armor = isRetail() and { 0, 1, 2, 3, 4, 5, 6 } or { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    local weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 18, 19, 20 }
    weapons[#weapons + 1] = isRetail() and 9 or 16
    for _, class in ipairs({ { id = 4, subclasses = armor }, { id = 2, subclasses = weapons } }) do
      for _, subclassID in ipairs(class.subclasses) do
        local label = subclassAPI(class.id, subclassID)
        if label and label ~= "" then addChoice(groups[1], label, class.id .. ":" .. subclassID) end
      end
    end
  end
  for key in pairs(equipmentSlots) do
    if gear.GetSlots(key) then addChoice(groups[2], _G[key] or key, key) end
  end
  for _, group in ipairs(groups) do
    group.byKey = {}
    for _, entry in ipairs(group.entries) do
      table.sort(entry.keys)
      entry.key = entry.keys[1]
      for _, key in ipairs(entry.keys) do group.byKey[key] = entry end
    end
    table.sort(group.entries, function(a, b)
      return a.name == b.name and a.key < b.key or a.name < b.name
    end)
  end
  gearChoicesCache, gearChoicesClient, gearChoicesSubclassAPI = groups, client, subclassAPI
  return gearChoicesCache
end

--- Check whether a grouped choice is enabled, including older independently saved keys.
---@param values table Saved unchecked filter keys.
---@param choice table Choice and its equivalent keys.
---@return boolean enabled Whether every key in the group is enabled.
function gear.ChoiceEnabled(values, choice)
  for _, key in ipairs(choice.keys) do
    if values[key] == false then return false end
  end
  return true
end

--- Check whether a stat choice matches a nonzero item stat.
---@param choice table Stat category and its item-stat keys.
---@param stats table|nil Item stats from Blizzard.
---@return boolean matches Whether the item has a stat in the category.
function gear.StatChoiceMatches(choice, stats)
  if not stats then return false end
  for index = 1, 2 do
    local keys = index == 1 and choice.keys or choice.extraMatch
    if keys then
      for _, key in ipairs(keys) do
        local value = stats[key]
        if type(value) == "number" and value ~= 0 then return true end
      end
    end
  end
  return false
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
---@return table|nil itemStats Candidate item's stats, even if an equipped item is unavailable.
function gear.CompareItem(link, equipLoc)
  local applicable = gear.GetSlots(equipLoc, link)
  if not applicable or not link or not C_Item or not C_Item.GetItemStats then return nil end
  local itemStats = C_Item.GetItemStats(link)
  if not itemStats then return nil end
  local results = {}
  for _, slot in ipairs(applicable) do
    local equippedLink = GetInventoryItemLink("player", slot)
    if not equippedLink and GetInventoryItemID and GetInventoryItemID("player", slot) then return nil, itemStats end
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
    if not equippedStats then return nil, itemStats end
    local combined
    if equipLoc == "INVTYPE_2HWEAPON" and #applicable == 1 then
      local offhandLink = GetInventoryItemLink("player", 17)
      if not offhandLink and GetInventoryItemID and GetInventoryItemID("player", 17) then return nil, itemStats end
      if offhandLink then
        local offhandStats = C_Item.GetItemStats(offhandLink)
        if not offhandStats then return nil, itemStats end
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

--- Format a stat change to the precision shown in Gear view.
---@param value number Stat change.
---@return string|nil text Signed value, or nil when it rounds to zero.
local function formatStatDelta(value)
  local text = ("%+.2f"):format(value)
  if tonumber(text) == 0 then return nil end
  return (text:gsub("0+$", ""):gsub("%.$", ""))
end

--- Format a comparison with colored stat changes.
---@param comparison table Compared slot and stat changes.
---@param includeSlot boolean Whether to prefix the slot number.
---@return string text Colored display text.
function gear.FormatComparison(comparison, includeSlot)
  local parts = {}
  for _, change in ipairs(comparison.changes) do
    local value = formatStatDelta(change.value)
    if value then
      local color = change.value > 0 and "ff40ff40" or "ffff4040"
      parts[#parts + 1] = ("|c%s%s %s|r"):format(color, value, gear.StatLabel(change.key))
    end
  end
  local text = #parts > 0 and table.concat(parts, ", ") or "No change"
  local label = comparison.label or slotLabels[comparison.slot] or tostring(comparison.slot)
  return (includeSlot or comparison.label) and (label .. ": " .. text) or text
end

--- Decide whether the item has visible losses and no gains across its equipment comparisons.
---@param comparisons table|nil Equipment-slot comparisons.
---@return boolean downgrade Whether a loss is displayed and no stats are gained.
function gear.IsDowngrade(comparisons)
  local hasLoss = false
  for _, comparison in ipairs(comparisons or {}) do
    if comparison.hasGain then return false end
    if comparison.hasLoss then
      for _, change in ipairs(comparison.changes) do
        if change.value < 0 and formatStatDelta(change.value) then hasLoss = true; break end
      end
    end
  end
  return hasLoss
end
