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
assert(comparisons[2].primary == -2 and gear.IsDowngrade(comparisons))
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
assert(not gear.IsDowngrade({ comparisons[1] }), "mixed gains and losses are not strictly worse")
stats.right = nil
assert(gear.CompareItem("candidate", "INVTYPE_FINGER") == nil, "uncached equipped stats must not look like zero")
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
retail = false
assert(gear.GetSlots("INVTYPE_RANGED")[1] == 18)
print("Listview Bag gear comparisons passed")
