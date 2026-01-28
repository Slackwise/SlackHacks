setfenv(1, _G.SlackwiseTweaks)

MOUNT_IDS = { -- from https://wowpedia.fandom.com/wiki/MountID (Use the ID from the leftmost column)
  ["Charger"]                      = 84,
  ["Swift Razzashi Raptor"]        = 110,
  ["Ashes of Al'ar"]               = 183,
  ["Time-Lost Proto-Drake"]        = 265,
  ["Mekgineer's Chopper"]          = 275,
  ["Ironbound Proto-Drake"]        = 306,
  ["Sea Turtle"]                   = 312,
  ["X-45 Heartbreaker"]            = 352,
  ["Celestial Steed"]              = 376,
  ["Sandstone Drake"]              = 407,
  ["Tyrael's Charger"]             = 439,
  ["Grand Expedition Yak"]         = 460,
  ["Sky Golem"]                    = 522,
  ["Highlord's Golden Charger"]    = 885,
  ["Lightforged Warframe"]         = 932,
  ["Highland Drake"]               = 1563,
  ["Winding Slitherdrake"]         = 1588,
  ["Renewed Proto-Drake"]          = 1589,
  ["Grotto Netherwing Drake"]      = 1744,
  ["Algarian Stormrider"]          = 1792,
  ["Auspicious Arborwyrm"]         = 1795,
  ["Grizzly Hills Packmaster"]     = 2237,
  ["Coldflame Tempest"]            = 2261,
  ["Trader's Gilded Brutosaur"]    = 2265,
  ["Chaos-Forged Gryphon"]         = 2304,
  ["Lightwing Dragonhawk"]         = 2568,
  ["Royal Voidwing"]               = 2606,
  ["Starspark Netherdrake"]        = 2719,
}

ACTUALLY_FLYABLE_MAP_IDS = {
  CONTINENTS = {
    619, -- Broken Isles
  },
  ZONES = {
  },
  MAPS = {
    627,   -- Legion Dalaran, but as a dungeon due to phasing for the Harbinger questline
  }
}

NOT_ACTUALLY_FLYABLE_MAP_IDS = {
  CONTINENTS = {
    905,	-- Argus
  },
  ZONES = {
    94,    -- Eversong Woods
    95,    -- Ghostlands
    97,    -- Azuremyst Isle
    103,   -- The Exodar
    106,   -- Bloodmyst Isle
    110,   -- Silvermoon City
    122,   -- Isle of Quel'Danas
    747,   -- The Dreamgrove (Druid Legion Hall)
    946,   -- "Cosmic" (Ashran BG)
    1334,  -- Wintergrasp (BG)
    1543,  -- The Maw
    1961,  -- Korthia, The Maw
  },
  MAPS = {
    715,   -- Emerald Dreamway, The Dreamgrove (Druid Legion Hall)
    747,   -- The Dreamgrove (Druid Legion Hall)
    1478,  -- Ashran (BG)
  }
}

-- Alchemists have equal strength potions but they're cheaper to make,
-- so we're adding an amount to make them be used first when equal strength potions:
ALCHEMIST_VALUE_OFFSET = 1000 

BEST_ITEMS = {
  BEST_HEALING_POTIONS = {
    BINDING_NAME = "SLACKWISETWEAKS_BEST_HEALING_POTION",

    -- Mapping of:
    -- ITEM_ID = MAX_HEALING

    -- TWW Alchemist-Only Healing Potions
    [212944]     = 3839450 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Healing Potion (Quality 3)
    [212943]     = 3681800 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Healing Potion (Quality 2)
    [212942]     = 3530600 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Healing Potion (Quality 1)
    [211880]     = 3839450, -- Algari Healing Potion (Quality 3)
    [211879]     = 3681800, -- Algari Healing Potion (Quality 2)
    [211878]     = 3530600, -- Algari Healing Potion (Quality 1)

    -- TWW Healing/Mana Potions
    [212950]     = 2799950 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 3)
    [212949]     = 2685000 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 2)
    [212948]     = 2574760 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 1)
    [212244]     = 2799950, -- Cavedweller's Delight (Quality 3)
    [212243]     = 2685000, -- Cavedweller's Delight (Quality 2)
    [212242]     = 2574760, -- Cavedweller's Delight (Quality 1)
    
    
    -- Dragonflight Healing Potions:  https://www.wowhead.com/spells/professions/alchemy/name:Healing+Potion/live-only:on?filter=16;10;0
    [207023]     = 310592, -- Dreamwalker's Healing Potion (Quality 3)
    [207022]     = 266709, -- Dreamwalker's Healing Potion (Quality 2)
    [207021]     = 228992, -- Dreamwalker's Healing Potion (Quality 1)
    [191380]     = 160300, -- Refreshing Healing Potion (Quality 3)
    [191379]     = 137550, -- Refreshing Healing Potion (Quality 2)
    [191378]     = 118000, -- Refreshing Healing Potion (Quality 1)

    -- Classic Healing Potions:  https://www.wowhead.com/classic/spells/professions/alchemy/name:Healing+Potion/live-only:on?filter=16;10;0
    [13446]      = 1750,  -- Major Healing Potion
    [3928]       = 900,   -- Superior Healing Potion
    [1710]       = 585,   -- Greater Healing Potion
    [929]        = 360,   -- Healing Potion
    [858]        = 180,   -- Lesser Healing Potion
    [118]        = 90,    -- Minor Healing Potion
  },

  BEST_MANA_POTIONS = {
    BINDING_NAME = "SLACKWISETWEAKS_BEST_MANA_POTION",

    -- Mapping of:
    -- ITEM_ID = MAX_MANA_RESTORATION

    -- TWW Alchemist-Only Mana Potions
    [212947]     = 270000 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Mana Potion (Quality 3)
    [212946]     = 234783 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Mana Potion (Quality 2)
    [212945]     = 204159 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Mana Potion (Quality 1)
    [212241]     = 270000, -- Algari Mana Potion (Quality 3)
    [212240]     = 234783, -- Algari Mana Potion (Quality 2)
    [212239]     = 204159, -- Algari Mana Potion (Quality 1)

    -- TWW Mana/Healing Potions
    [212950]     = 202500 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 3)
    [212949]     = 176087 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 2)
    [212948]     = 153119 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 1)
    [212244]     = 202500, -- Cavedweller's Delight (Quality 3)
    [212243]     = 176087, -- Cavedweller's Delight (Quality 2)
    [212242]     = 153119, -- Cavedweller's Delight (Quality 1)


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
    BINDING_NAME = "SLACKWISETWEAKS_BEST_BANDAGE",

    -- Mapping of:
    -- ITEM_ID = MAX_HEALING

    -- TWW Bandages:
    [224442]     = 3339000, -- Weavercloth Bandage (Quality 3)
    [224441]     = 2504250, -- Weavercloth Bandage (Quality 2)
    [224440]     = 1669500, -- Weavercloth Bandage (Quality 1)


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
