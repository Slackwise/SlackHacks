-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_gear.lua
SlackHacks = setmetatable({}, { __index = _G })
SlackHacks.Self = SlackHacks
local retail = false
function SlackHacks.isRetail() return retail end
assert(loadfile("ListviewBagGear.lua"))()
local gear = SlackHacks.ListviewBagGear
local stats = {
  candidate = { ITEM_MOD_AGILITY_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 2 },
  left = { ITEM_MOD_AGILITY_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 3 },
  right = { ITEM_MOD_AGILITY_SHORT = 9, ITEM_MOD_STAMINA_SHORT = 3 },
}
C_Item = { GetItemStats = function(link) return stats[link] end }
GetInventoryItemLink = function(_, slot) return slot == 11 and "left" or slot == 12 and "right" end
local comparisons = gear.CompareItem("candidate", "INVTYPE_FINGER")
assert(#comparisons == 2, "both ring slots must be compared")
assert(comparisons[1].primary == 2 and comparisons[1].hasGain and comparisons[1].hasLoss)
assert(comparisons[2].primary == -2 and gear.IsDowngrade({ comparisons[2] }))
assert(not gear.IsDowngrade(comparisons),
  "A loss against one ring must not hide a gain against the other")
assert(gear.FormatComparison(comparisons[1], true):find("+3 Agi", 1, true))
assert(gear.FormatComparison(comparisons[1], true):find("-1 Stam", 1, true))
local weaponComparison = gear.CompareStats({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 },
  { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 15 }, 16)
assert(gear.FormatComparison(weaponComparison, false):find("+5 dps", 1, true),
  "Weapon damage-per-second differences must use the compact dps label")
local rangedComparison = gear.CompareStats({ ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 20 },
  { ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 15 }, 18)
assert(gear.FormatComparison(rangedComparison, false):find("+5 RAP", 1, true),
  "Ranged attack power differences must use the compact RAP label")
local rounded = gear.CompareStats({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20.234,
  ITEM_MOD_STAMINA_SHORT = 8.763 }, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 19,
  ITEM_MOD_STAMINA_SHORT = 10 }, 16)
local roundedText = gear.FormatComparison(rounded, false)
assert(roundedText:find("+1.23 dps", 1, true) and roundedText:find("-1.24 Stam", 1, true),
  "Upgrade differences must be rounded to at most two decimal places")
local tiny = gear.CompareStats({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 0.004 }, {}, 16)
assert(gear.FormatComparison(tiny, false) == "No change", "Rounded zero must not show a signed zero")
local tinyLoss = gear.CompareStats({}, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 0.004 }, 16)
assert(gear.FormatComparison(tinyLoss, false) == "No change" and not gear.IsDowngrade({ tinyLoss }),
  "A loss rounded out of the display must not be shown by Downgrade Only")
assert(not gear.IsDowngrade({ comparisons[1] }), "mixed gains and losses are not strictly worse")
local loss = gear.CompareStats({ ITEM_MOD_AGILITY_SHORT = 2 }, { ITEM_MOD_AGILITY_SHORT = 3 }, 11)
local neutral = gear.CompareStats({}, {}, 12)
local gain = gear.CompareStats({ ITEM_MOD_AGILITY_SHORT = 4 }, { ITEM_MOD_AGILITY_SHORT = 3 }, 12)
assert(gear.IsDowngrade({ loss, neutral }) and gear.IsDowngrade({ loss, loss }),
  "Losses without gains across all slots are downgrades")
assert(not gear.IsDowngrade({ loss, gain }) and not gear.IsDowngrade({ gain, loss })
  and not gear.IsDowngrade({ neutral }) and not gear.IsDowngrade(nil),
  "Any gain, or no loss, must disqualify an item from Downgrade Only")
stats.right = nil
local pendingComparison, availableStats = gear.CompareItem("candidate", "INVTYPE_FINGER")
assert(pendingComparison == nil and availableStats == stats.candidate,
  "Uncached equipped stats must not look like zero or hide the candidate's available stats")
stats.right = { ITEM_MOD_AGILITY_SHORT = 2 }
GetInventoryItemLink = function(_, slot) return slot == 16 and "left" or slot == 17 and "right" end
comparisons = gear.CompareItem("candidate", "INVTYPE_2HWEAPON")
assert(#comparisons == 1 and comparisons[1].primary == 0 and comparisons[1].label == "Both Hands",
  "a two-handed item replaces the combined main-hand and off-hand stats")
IsPlayerSpell = function(id) return id == 46917 end
C_Item.GetItemInfoInstant = function() return 1, nil, nil, "INVTYPE_2HWEAPON", nil, 2, 8 end
comparisons = gear.CompareItem("candidate", "INVTYPE_2HWEAPON")
assert(#comparisons == 2, "Titan's Grip compares each weapon slot separately")
IsPlayerSpell = nil
GetInventoryItemLink = function(_, slot) return slot == 16 and "left" end
comparisons = gear.CompareItem("candidate", "INVTYPE_WEAPON")
assert(#comparisons == 2 and comparisons[2].primary == comparisons[1].primary
  and comparisons[2].label == "Replaces Main Hand", "equipping an offhand displaces a two-handed main hand")
IsPlayerSpell = function() return true end
comparisons = gear.CompareItem("candidate", "INVTYPE_WEAPON")
assert(comparisons[2].primary == 10, "Titan's Grip permits an offhand alongside a two-handed main hand")
C_Item.GetItemInfoInstant = function() return 1, nil, nil, "INVTYPE_2HWEAPON", nil, 2, 10 end
comparisons = gear.CompareItem("candidate", "INVTYPE_WEAPON")
assert(comparisons[2].label == "Replaces Main Hand", "Titan's Grip does not allow dual-wielding staves")
IsPlayerSpell = nil
retail = true
assert(gear.GetSlots("INVTYPE_RANGED")[1] == 16)
assert(not gear.GetSlots("INVTYPE_RELIC"), "Retail must not expose the removed relic slot")
retail = false
assert(gear.GetSlots("INVTYPE_RANGED")[1] == 18)
assert(gear.GetSlots("INVTYPE_RELIC")[1] == 18, "Forever relics use the ranged equipment slot")
do
  local expected = {
    retail = {
      Strength = "ITEM_MOD_STRENGTH_SHORT", Agility = "ITEM_MOD_AGILITY_SHORT",
      Intellect = "ITEM_MOD_INTELLECT_SHORT", Stamina = "ITEM_MOD_STAMINA_SHORT",
      ["Critical Strike"] = "ITEM_MOD_CRIT_RATING_SHORT", Haste = "ITEM_MOD_HASTE_RATING_SHORT",
      Mastery = "ITEM_MOD_MASTERY_RATING_SHORT", Versatility = "ITEM_MOD_VERSATILITY",
      Leech = "ITEM_MOD_CR_LIFESTEAL_SHORT", Avoidance = "ITEM_MOD_CR_AVOIDANCE_SHORT",
      Speed = "ITEM_MOD_CR_SPEED_SHORT", Indestructible = "ITEM_MOD_CR_STURDINESS_SHORT",
    },
    forever = {
      Strength = "ITEM_MOD_STRENGTH_SHORT", Agility = "ITEM_MOD_AGILITY_SHORT",
      Intellect = "ITEM_MOD_INTELLECT_SHORT", Stamina = "ITEM_MOD_STAMINA_SHORT",
      ["Critical Strike"] = "ITEM_MOD_CRIT_SPELL_RATING_SHORT", Haste = "ITEM_MOD_HASTE_RATING_SHORT",
      Spirit = "ITEM_MOD_SPIRIT_SHORT", ["Attack Power"] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
      ["Ranged Attack Power"] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", ["Spell Power"] = "ITEM_MOD_SPELL_POWER_SHORT",
      ["Spell Damage"] = "ITEM_MOD_FIRE_DAMAGE_DONE_SHORT", Healing = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
      ["Hit Rating"] = "ITEM_MOD_HIT_SPELL_RATING_SHORT", Expertise = "ITEM_MOD_EXPERTISE_RATING_SHORT",
      ["Weapon Skill"] = "ITEM_MOD_SWORDS_SHORT", ["Armor Penetration"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
      ["Spell Penetration"] = "ITEM_MOD_SPELL_PENETRATION_SHORT", Defense = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
      Dodge = "ITEM_MOD_DODGE_RATING_SHORT", Parry = "ITEM_MOD_PARRY_RATING_SHORT",
      ["Block Chance"] = "ITEM_MOD_BLOCK_RATING_SHORT", ["Mana per 5 Seconds"] = "ITEM_MOD_POWER_REGEN0_SHORT",
      ["Health per 5 Seconds"] = "ITEM_MOD_HEALTH_REGEN_SHORT", ["Magic Resistances"] = "RESISTANCE5_NAME",
    },
  }
  for _, client in ipairs({ "retail", "forever" }) do
    retail = client == "retail"
    local seen = {}
    for _, choice in ipairs(gear.StatFilterChoices()) do
      local key = expected[client][choice.name]
      assert(key and not seen[choice.name], "Unexpected or duplicate " .. client .. " stat: " .. choice.name)
      assert(gear.StatChoiceMatches(choice, { [key] = 1 }), choice.name .. " must match its item stat")
      assert(not gear.StatChoiceMatches(choice, { [key] = 0 }), choice.name .. " must ignore zero values")
      seen[choice.name] = true
    end
    for name in pairs(expected[client]) do assert(seen[name], "Missing " .. client .. " stat: " .. name) end
  end
end
print("Listview Bag gear comparisons passed")
