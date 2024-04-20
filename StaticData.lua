setfenv(1, _G.SlackUI)

BEST_ITEMS = {
  BEST_HEALING_POTIONS = {
    BINDING_NAME = "SLACKUI_BEST_HEALING_POTION",

    -- Mapping of:
    -- ITEM_ID = MAX_HEALING

    -- Dragonflight Potions:
    [207023]     = 310592, -- Dreamwalker's Healing Potion (Quality 3)
    [207022]     = 266709, -- Dreamwalker's Healing Potion (Quality 2)
    [207021]     = 228992, -- Dreamwalker's Healing Potion (Quality 1)

    -- Classic Potions:
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

    -- Dragonflight Potions:
    [191386]     = 27600, -- Aerated Mana Potion (Quality 3)
    [191385]     = 24000, -- Aerated Mana Potion (Quality 2)
    [191384]     = 20870, -- Aerated Mana Potion (Quality 1)

    -- Classic Potions:
    [13444]      = 2250, -- Major Mana Potion
    [13443]      = 1500, -- Superior Mana Potion
    [6149]       = 900, -- Greater Mana Potion
    [3827]       = 585, -- Mana Potion
    [3385]       = 360, -- Lesser Mana Potion
    [2455]       = 180, -- Minor Mana Potion
  }
}
