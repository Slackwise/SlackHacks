setfenv(1, _G.SlackUI)

MOUNT_IDS = { -- from https://wowpedia.fandom.com/wiki/MountID (Use the ID from the leftmost column)
  ["Charger"]                      = 84,
  ["Swift Razzashi Raptor"]        = 110,
  ["Ashes of Al'ar"]               = 183,
  ["Time-Lost Proto-Drake"]        = 265,
  ["Mekgineer's Chopper"]          = 275,
  ["Sea Turtle"]                   = 312,
  ["Sandstone Drake"]              = 407,
  ["Tyrael's Charger"]             = 439,
  ["Grand Expedition Yak"]         = 460,
  ["Sky Golem"]                    = 522,
  ["Highlord's Golden Charger"]    = 885,
  ["Highland Drake"]               = 1563,
  ["Winding Slitherdrake"]         = 1588,
  ["Renewed Proto-Drake"]          = 1589,
  ["Grotto Netherwing Drake"]      = 1744,
}

BEST_ITEMS = {
  BEST_HEALING_POTIONS = {
    BINDING_NAME = "SLACKUI_BEST_HEALING_POTION",

    -- Mapping of:
    -- ITEM_ID = MAX_HEALING

    -- Dragonflight Healing Potions:  https://www.wowhead.com/spells/professions/alchemy/name:Healing+Potion/live-only:on?filter=16;10;0
    [207023]     = 310592, -- Dreamwalker's Healing Potion (Quality 3)
    [207022]     = 266709, -- Dreamwalker's Healing Potion (Quality 2)
    [207021]     = 228992, -- Dreamwalker's Healing Potion (Quality 1)
    [191380]     = 160300, -- Refreshing Healing Potion (Quality 3)
    [191379]     = 137550, -- Refreshing Healing Potion (Quality 2)
    [191378]     = 118000, -- Refreshing Healing Potion (Quality 1)

    -- Classic Healing Potions:  https://www.wowhead.com/classic/spells/professions/alchemy/name:Healing+Potion/live-only:on?filter=16;10;0
    [13446]      = 1750, -- Major Healing Potion
    [3928]       = 900, -- Superior Healing Potion
    [1710]       = 585, -- Greater Healing Potion
    [929]        = 360, -- Healing Potion
    [858]        = 180, -- Lesser Healing Potion
    [118]        = 90, -- Minor Healing Potion
  },

  BEST_MANA_POTIONS = {
    BINDING_NAME = "SLACKUI_BEST_MANA_POTION",

    -- Mapping of:
    -- ITEM_ID = MAX_MANA_RESTORATION

    -- Dragonflight Mana Potions:  https://www.wowhead.com/spells/professions/alchemy/name:Mana+Potion/live-only:on?filter=16;10;0
    [191386]     = 27600, -- Aerated Mana Potion (Quality 3)
    [191385]     = 24000, -- Aerated Mana Potion (Quality 2)
    [191384]     = 20870, -- Aerated Mana Potion (Quality 1)

    -- Classic Mana Potions: https://www.wowhead.com/classic/spells/professions/alchemy/name:Mana+Potion#0-18+2
    [13444]      = 2250, -- Major Mana Potion
    [13443]      = 1500, -- Superior Mana Potion
    [6149]       = 900, -- Greater Mana Potion
    [3827]       = 585, -- Mana Potion
    [3385]       = 360, -- Lesser Mana Potion
    [2455]       = 180, -- Minor Mana Potion
  },

  BEST_BANDAGES = {
    BINDING_NAME = "SLACKUI_BEST_BANDAGE",

    -- Mapping of:
    -- ITEM_ID = MAX_HEALING

    -- Dragonflight Bandages:
    [194050]     = 50768, -- Wildercloth Bandage (Quality 3)
    [194049]     = 43560, -- Wildercloth Bandage (Quality 2)
    [194048]     = 37376, -- Wildercloth Bandage (Quality 1)

    -- Classic Bandages:
    [14530]      = 2000, -- Heavy Runecloth Bandage
    [14529]      = 1360, -- Runecloth Bandage
    [8545]       = 1104, -- Heavy Mageweave Bandage
    [8544]       = 800,  -- Mageweave Bandage
    [6451]       = 640,  -- Heavy Silk Bandage
    [6450]       = 400,  -- Silk Bandage
    [3531]       = 301,  -- Heavy Wool Bandage
    [3530]       = 161,  -- Wool Bandage
    [2581]       = 114,  -- Heavy Linen Bandage
    [1251]       = 66,   -- Linen Bandage
  },
}
