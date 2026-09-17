-- These are my personal configs.
-- They only load for me, so don't worry about 'em.


-- Change implicit global scope to our addon "namespace":
setfenv(1, _G.SlackHacks)

-- if not isSlackwise() then
--   -- Cancel loading the rest of the file:
--   return -- Does not impact loading subsequent files, though!
-- end


MOUNTS_BY_USAGE = {
  DEFAULT = {
    ['GROUND']            = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Mekgineer's Chopper"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Algarian Stormrider"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["X-45 Heartbreaker"],
  },
  HUNTER = {
    ['GROUND']            = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Renewed Proto-Drake"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Renewed Proto-Drake"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
  },
  PALADIN = {
    -- Alliance themed
    ['GROUND']            = MOUNT_IDS["Highlord's Golden Charger"],
    ['FLYING']            = MOUNT_IDS["Chaos-Forged Gryphon"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Algarian Stormrider"],
    -- ['GROUND_PASSENGER']  = MOUNT_IDS["Mekgineer's Chopper"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Algarian Stormrider"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Ashes of Al'ar"],
    -- Green themed
    -- ['GROUND']            = MOUNT_IDS["Swift Razzashi Raptor"],
    -- -- ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    -- ['FLYING']            = MOUNT_IDS["Royal Voidwing"],
    -- ['WATER']             = MOUNT_IDS["Sea Turtle"],
    -- ['GROUND_PASSENGER']  = MOUNT_IDS["Algarian Stormrider"],
    -- ['FLYING_PASSENGER']  = MOUNT_IDS["Ashes of Al'ar"],
    -- ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    -- ['FLYING_SHOWOFF']    = MOUNT_IDS["Ashes of Al'ar"],
    -- Lightforged Warframe
    -- ['GROUND']            = MOUNT_IDS["Lightforged Warframe"],
    -- ['FLYING']            = MOUNT_IDS["Lightforged Warframe"],
    -- ['WATER']             = MOUNT_IDS["Sea Turtle"],
    -- ['GROUND_PASSENGER']  = MOUNT_IDS["Lightforged Warframe"],
    -- ['FLYING_PASSENGER']  = MOUNT_IDS["Lightforged Warframe"],
    -- ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    -- ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    -- Starspark Netherdrake
    -- ['GROUND']            = MOUNT_IDS["Starspark Netherdrake"],
    -- ['FLYING']            = MOUNT_IDS["Starspark Netherdrake"],
    -- ['WATER']             = MOUNT_IDS["Sea Turtle"],
    -- ['GROUND_PASSENGER']  = MOUNT_IDS["Starspark Netherdrake"],
    -- ['FLYING_PASSENGER']  = MOUNT_IDS["Starspark Netherdrake"],
    -- ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    -- ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
  },
  SHAMAN = {
    ['GROUND']            = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Algarian Stormrider"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
  },
  PRIEST = {
    ['GROUND']            = MOUNT_IDS["Lightwing Dragonhawk"],
    ['FLYING']            = MOUNT_IDS["Lightwing Dragonhawk"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Lightwing Dragonhawk"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Lightwing Dragonhawk"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Ashes of Al'ar"],
  },
  MAGE = {
    ['GROUND']            = MOUNT_IDS["Coldflame Tempest"],
    ['FLYING']            = MOUNT_IDS["Coldflame Tempest"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Coldflame Tempest"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Coldflame Tempest"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
  },
  EVOKER = {
    ['GROUND']            = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Renewed Proto-Drake"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Renewed Proto-Drake"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
  },
  WARLOCK = {
    ['GROUND']            = MOUNT_IDS["Incognitro, the Indecipherable Felcycle"],
    ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    ['WATER']             = MOUNT_IDS["Sea Turtle"],
    ['GROUND_PASSENGER']  = MOUNT_IDS["Grotto Netherwing Drake"],
    ['FLYING_PASSENGER']  = MOUNT_IDS["Grotto Netherwing Drake"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
  },
}

ENHANCEMENTS_BIS_OVERRIDES = {
  ["Amazoniangf-MoonGuard"] = {
    Flask = "Flask of the Blood Knights",
    Gems = {
      Primary = "Indecipherable Eversong Diamond",
      Secondary = "Flawless Versatile Peridot",
    },
    Enchants = {
      HEAD = "Enchant Helm - Empowered Hex of Leeching",
      SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
      CHEST = "Enchant Chest - Mark of the Worldsoul",
      LEGS = "Forest Hunter's Armor Kit",
      FEET = "Enchant Boots - Shaladrassil's Roots",
      FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
      FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
      MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
    },
  },
  ["Inukari-MoonGuard"] = {
    Flask = "Flask of the Magisters",
    Gems = {
      Primary = "Indecipherable Eversong Diamond",
      Secondary = "Flawless Quick Amethyst",
    },
    Enchants = {
      HEAD = "Enchant Helm - Empowered Rune of Avoidance",
      SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
      CHEST = "Enchant Chest - Mark of the Worldsoul",
      LEGS = "Forest Hunter's Armor Kit",
      FEET = "Enchant Boots - Lynx's Dexterity",
      FINGER1 = "Enchant Ring - Eyes of the Eagle",
      FINGER2 = "Enchant Ring - Eyes of the Eagle",
      MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
    },
  }
}


BINDINGS = {
  GLOBAL = {
    {"ALT-CTRL-END",         "SLACKHACKS_RELOADUI", "COMMAND"},
    {"ALT-CTRL-`",           "FOCUSTARGET", "COMMAND"},
    {"ALT-`",                "INTERACTTARGET", "COMMAND"},
    {"W",                    "MOVEFORWARD", "COMMAND"},
    {"A",                    "STRAFELEFT", "COMMAND"},
    {"S",                    "MOVEBACKWARD", "COMMAND"},
    {"D",                    "STRAFERIGHT", "COMMAND"},
    {"ALT-A",                "TURNLEFT", "COMMAND"},
    {"ALT-D",                "TURNRIGHT", "COMMAND"},
    {"F1",                   "ACTIONBUTTON1", "COMMAND"},
    {"F2",                   "ACTIONBUTTON2", "COMMAND"},
    {"F3",                   "ACTIONBUTTON3", "COMMAND"},
    {"F4",                   "ACTIONBUTTON4", "COMMAND"},
    {"F5",                   "ACTIONBUTTON5", "COMMAND"},
    {"F6",                   "ACTIONBUTTON6", "COMMAND"},
    {"F7",                   "ACTIONBUTTON7", "COMMAND"},
    {"F8",                   "ACTIONBUTTON8", "COMMAND"},
    {"F9",                   "ACTIONBUTTON9", "COMMAND"},
    {"F10",                  "ACTIONBUTTON10", "COMMAND"},
    {"F11",                  "ACTIONBUTTON11", "COMMAND"},
    {"F12",                  "ACTIONBUTTON12", "COMMAND"},
    {"1",                    "NONE", "COMMAND"},
    {"2",                    "NONE", "COMMAND"},
    {"3",                    "NONE", "COMMAND"},
    {"4",                    "NONE", "COMMAND"},
    {"5",                    "NONE", "COMMAND"},
    {"6",                    "NONE", "COMMAND"},
    {"7",                    "NONE", "COMMAND"},
    {"8",                    "NONE", "COMMAND"},
    {"9",                    "NONE", "COMMAND"},
    {"0",                    "NONE", "COMMAND"},
    {"-",                    "NONE", "COMMAND"},
    {"=",                    "NONE", "COMMAND"},
    {"SHIFT-1",              "NONE", "COMMAND"},
    {"SHIFT-2",              "NONE", "COMMAND"},
    {"SHIFT-3",              "NONE", "COMMAND"},
    {"SHIFT-4",              "NONE", "COMMAND"},
    {"SHIFT-5",              "NONE", "COMMAND"},
    {"SHIFT-6",              "NONE", "COMMAND"},
    {"SHIFT-7",              "NONE", "COMMAND"},
    {"SHIFT-8",              "NONE", "COMMAND"},
    {"SHIFT-9",              "NONE", "COMMAND"},
    {"SHIFT-0",              "NONE", "COMMAND"},
    {"CTRL-1",               "NONE", "COMMAND"},
    {"CTRL-2",               "NONE", "COMMAND"},
    {"CTRL-3",               "NONE", "COMMAND"},
    {"CTRL-4",               "NONE", "COMMAND"},
    {"CTRL-5",               "NONE", "COMMAND"},
    {"CTRL-6",               "NONE", "COMMAND"},
    {"CTRL-7",               "NONE", "COMMAND"},
    {"CTRL-8",               "NONE", "COMMAND"},
    {"CTRL-9",               "NONE", "COMMAND"},
    {"CTRL-0",               "NONE", "COMMAND"},
    {",",                    "NONE", "COMMAND"},
    {"ALT-CTRL-W",           "TOGGLEFOLLOW", "COMMAND"},
    {"E",                    "INTERACTTARGET", "COMMAND"},
    {"SHIFT-E",              "INTERACTTARGET", "COMMAND"},
    {"CTRL-E",               "Single-Button Assistant"},
    {"ALT-E",                "EXTRAACTIONBUTTON1", "COMMAND"},
    {"SHIFT-R",              "NONE", "COMMAND"},
    {"CTRL-R",               "NONE", "COMMAND"},
    {"CTRL-S",               "NONE", "COMMAND"},
    {"ALT-CTRL-S",           "Survey"},
    {"H",                    "TOGGLEGROUPFINDER", "COMMAND"},
    {"SHIFT-H",              "TOGGLECHARACTER4", "COMMAND"}, -- Honor Panel (PvP Queue)
    {"CTRL-H",               "HEARTH", "MACRO"},
    {"ALT-CTRL-H",           "HEARTH_DALARAN", "MACRO"},
    {"ALT-H",                "TOGGLEUI", "COMMAND"},
    {"ALT-CTRL-L",           "TOGGLEACTIONBARLOCK", "COMMAND"},
    {"X",                    "SITORSTAND", "COMMAND"},
    {"SHIFT-X",              "MOUNT_BEAR", "MACRO"},
    {"CTRL-SHIFT-X",         "MOUNT_DINO", "MACRO"},
    {"ALT-X",                "SITORSTAND", "COMMAND"},
    {"ALT-CTRL-X",           "TOGGLERUN", "COMMAND"},
    {"ALT-CTRL-SHIFT-X",     "Switch Flight Style"},
    {"ALT-CTRL-SHIFT-V",     "Recuperate"},
    {"ALT-CTRL-SHIFT-M",     "Switch Flight Style"},
    {"ALT-C",                "SLACKHACKS_BEST_MANA_POTION", "COMMAND"},
    {"ALT-V",                "SLACKHACKS_BEST_HEALING_POTION", "COMMAND"},
    {"ALT-CTRL-V",           "SLACKHACKS_BEST_BANDAGE", "COMMAND"},
    {"V",                    "NONE", "COMMAND"},
    {"SHIFT-V",              "NONE", "COMMAND"},
    {"CTRL-V",               "NONE", "COMMAND"},
    {"B",                    "INTERACTTARGET", "COMMAND"},
    {"SHIFT-B",              "OPENALLBAGS", "COMMAND"},
    {"CTRL-B",               "TOGGLECHARACTER0", "COMMAND"},
    {"ALT-CTRL-B",           "SLACKHACKS_SETBINDINGS", "COMMAND"},
    {"ALT-B",                "TOGGLESHEATH", "COMMAND"},
    {"CTRL-M",               "TOGGLEMUSIC", "COMMAND"},
    {"ALT-M",                "TOGGLESOUND", "COMMAND"},
    {"ALT-CTRL-M",           "SLACKHACKS_RESTART_SOUND", "COMMAND"},
    {"SHIFT-UP",             "NONE", "COMMAND"},
    {"SHIFT-DOWN",           "NONE", "COMMAND"},
    {"SHIFT-ENTER",          "REPLY", "COMMAND"},
    {"CTRL-ENTER",           "REPLY2", "COMMAND"},
    {"SHIFT-SPACE",          "SLACKHACKS_MOUNT", "COMMAND"},
    {"SHIFT-HOME",           "SETVIEW1", "COMMAND"},
    {"HOME",                 "SETVIEW2", "COMMAND"},
    {"END",                  "SETVIEW3", "COMMAND"},
    {"PRINTSCREEN",          "SCREENSHOT", "COMMAND"},
    {"NUMLOCK",              "NONE", "COMMAND"},
    {"NUMPAD0",              "RAIDTARGET8", "COMMAND"},
    {"NUMPAD1",              "RAIDTARGET7", "COMMAND"},
    {"NUMPAD2",              "RAIDTARGET2", "COMMAND"},
    {"NUMPAD3",              "RAIDTARGET4", "COMMAND"},
    {"NUMPAD4",              "RAIDTARGET6", "COMMAND"},
    {"NUMPAD5",              "RAIDTARGET5", "COMMAND"},
    {"NUMPAD6",              "RAIDTARGET1", "COMMAND"},
    {"NUMPAD7",              "RAIDTARGET3", "COMMAND"},
    {"NUMPADDECIMAL",        "RAIDTARGETNONE", "COMMAND"},
    {"BUTTON3",              "TOGGLEAUTORUN", "COMMAND"},
    {"ALT-BUTTON3",          "TOGGLEPINGLISTENER", "COMMAND"},
    {"SHIFT-MOUSEWHEELUP",   "NONE", "COMMAND"},
    {"SHIFT-MOUSEWHEELDOWN", "NONE", "COMMAND"}
  },
  RETAIL = {
    HUNTER = {
      CLASS = {
        {"E",                "MULTIACTIONBAR7BUTTON1", "COMMAND"},
        {"F8",               "Call Pet 1"},
        {"F9",               "Call Pet 2"},
        {"F10",              "Call Pet 3"},
        {"F11",              "Call Pet 4"},
        {"F12",              "Call Pet 5"},
        {"`",                ".", "MACRO"},
        {"1",                "Hunter's Mark"},
        {"ALT-1",            "MD", "MACRO"},
        {"3",                "Multi-Shot"},
        {"4",                "Arcane Shot"},
        {"Q",                "PetControl", "MACRO"},
        {"CTRL-Q",           "BONUSACTIONBUTTON7", "COMMAND"},        -- Pet Family Ability
        {"CTRL-SHIFT-Q",     "BONUSACTIONBUTTON1", "COMMAND"},        -- Pet Family Ability
        {"ALT-CTRL-Q",       "PetToggle", "MACRO"},
        {"ALT-SHIFT-Q",      "Play Dead"},
        {"ALT-CTRL-SHIFT-Q", "Eyes of the Beast"},
        {"SHIFT-F",          "Bursting Shot"},
        {"R",                "Steady Shot"},
        {"ALT-CTRL-E",       "ChainEagle", "MACRO"},
        {"F",                "Counter Shot"},
        {"SHIFT-F",          "Concussive Shot"},
        {"CTRL-F",           "Intimidation"},
        {"ALT-F",            "Tranquilizing Shot"},
        {"ALT-CTRL-F",       "Scare Beast"},
        {"ALT-CTRL-SHIFT-F", "Fireworks"},
        {"Z",                "Aspect of the Cheetah"},
        {"SHIFT-Z",          "Camouflage"},
        {"ALT-SHIFT-Z",      "Aspect of the Chameleon"},
        -- {"ALT-Z",         "Potion of the Hidden Spirit", "ITEM"},
        -- {"ALT-C",         "Potion of the Psychopomp's Speed", "ITEM"},
        -- {"ALT-CTRL-C",    "CallFocus", "MACRO"},
        {"CTRL-Z",           "Feign Death"},
        {"CTRL-SHIFT-Z",     "Shadowmeld", "MACRO"},
        {"C",                "Traps", "MACRO"},
        -- {"SHIFT-C",       ""},
        -- {"CTRL-C",        "", "MACRO"},
        -- {"CTRL-SHIFT-C",  "Gladiator's Medallion", "ITEM"},
        {"B",                "FETCH", "MACRO"},
        {"V",                "VITALITY", "MACRO"},
        {"SHIFT-V",          "Survival of the Fittest"},
        {"CTRL-V",           "Aspect of the Turtle"},
        -- {"CTRL-SHIFT-V",  "Wildercloth Bandage", "ITEM"},
        -- {"ALT-V",         "Vitality", "MACRO"},
        -- {"ALT-CTRL-V",    "SurviveFocus", "MACRO"},
        {"CTRL-SPACE",       "Disengage"},
        {"BUTTON4",          "TrapsCursor", "MACRO"},
        {"BUTTON5",          "PetAttackCursor", "MACRO"},
      },
      MARKSMANSHIP = {
        {"2",       "Aimed Shot"}, 
        {"SHIFT-3", "Explosive Shot"},
        {"CTRL-3",  "Explosive Shot"},
        {"SHIFT-4", "Aimed Shot"}, -- Procs as INSTANT so on same key as Arcane
        {"CTRL-4",  "Explosive Shot"},
        {"5",       "Kill Shot"},
        {"SHIFT-5", "Explosive Shot"},
        {"SHIFT-R", "Rapid Fire"},
        {"G",       "Trueshot!", "MACRO"},
      },
      SURVIVAL = {
        {"1",       "Serpent Sting", "MACRO"},
        {"2",       "Kill Command"},
        {"4",       "Shrapnel Bomb"},
        {"5",       "Kill Shot"},
        {"E",       "Raptor Strike"},
        {"SHIFT-E", "Butchery"},
        {"R",       "Harpoon"},
        {"F",       "Wing Clip"},        --Auto-maps to "Concussive Shot" in MM spec
      }
    },
    PALADIN = {
      CLASS = {
        {"1",  "ACTIONBUTTON1", "COMMAND"},
        {"2",  "ACTIONBUTTON2", "COMMAND"},
        {"3",  "ACTIONBUTTON3", "COMMAND"},
        {"4",  "ACTIONBUTTON4", "COMMAND"},
        {"5",  "ACTIONBUTTON5", "COMMAND"},
        {"6",  "ACTIONBUTTON6", "COMMAND"},
        {"7",  "ACTIONBUTTON7", "COMMAND"},
        {"8",  "ACTIONBUTTON8", "COMMAND"},
        {"9",  "ACTIONBUTTON9", "COMMAND"},
        {"10", "ACTIONBUTTON10", "COMMAND"},
        {"11", "ACTIONBUTTON11", "COMMAND"},
        {"12", "ACTIONBUTTON12", "COMMAND"},

        ---------------------------------------------------

        -- General
        {"F8",               "SUMMONPET", "MACRO"},
        {"F9",               "SHAPESHIFTBUTTON1", "COMMAND"},
        {"F10",              "SHAPESHIFTBUTTON2", "COMMAND"},
        {"F11",              "SHAPESHIFTBUTTON3", "COMMAND"},
        {"F12",              "SHAPESHIFTBUTTON4", "COMMAND"},
        {"CTRL-SPACE",       "Divine Steed"},
        {"BUTTON4",          "MOUSE4", "MACRO"},
        {"BUTTON5",          "MOUSE5", "MACRO"},
        {"ALT-CTRL-SHIFT-X", "Contemplation"},
        {"SHIFT-G",          "TRINKETS", "MACRO"},

        -- Quick Heals
        {"1",      "Word of Glory"},
        {"CTRL-1", "Lay on Hands"},

        -- Cast Heals
        {"2", "Flash of Light"},

        -- Ranged Attacks
        {"4", "Judgment"},
        {"5", "Divine Toll"},

        ---------------------------------------------------

        -- Shield (Tanking)
        {"Q",     "Shield of the Righteous"},
        {"ALT-Q", "Hand of Reckoning"},

        -- Sword
        {"E", "Crusader Strike"},

        -- Targetting
        -- {"T", "Hand of Reckoning"},
        -- {"T", "TARGET", "MACRO"},
        {"T",    "BLESST", "MACRO"},

        ---------------------------------------------------

        -- CC
        {"F",         "Rebuke"},
        {"SHIFT-F",   "Hammer of Justice"},
        -- {"CTRL-F", "Repentance"},
        {"CTRL-F",    "Blinding Light"},

        -- Ultimates (Big Cooldowns)
        {"G", "WINGS", "MACRO"},

        -- Extras
        {"Z",          "FREEDOM", "MACRO"},
        {"SHIFT-Z",    "Will to Survive"},
        {"ALT-Z",      "PVP_TRINKET", "MACRO"},
        {"ALT-CTRL-Z", "REZ", "MACRO"},

        -- AoE (emanating from me)
        {"C",       "Consecration"},
        {"SHIFT-C", "Divine Toll"},
        {"CTRL-C",  "Divine Toll"},

        -- Vitality (Self-Heals/Protections)
        {"V",            "VITALITY", "MACRO"},
        {"SHIFT-V",      "Divine Shield"},
        {"CTRL-SHIFT-V", "BOP_SELF", "MACRO"},
        {"CTRL-V",       "LAY_SELF", "MACRO"},
      },
      HOLY = {
        -- Quick Heals
        {"`",       "Barrier of Faith"},
        {"SHIFT-1", "Cleanse"},
        
        -- CC (No more interrupts...)
        {"F", "Hammer of Justice"},

        -- Cast Heals
        {"SHIFT-2",    "Holy Light"},
        -- {"2",       "Holy Light"},
        -- {"SHIFT-2", "Flash of Light"},

        -- AoE Heals
        {"3",          "Light of Dawn"},
        -- {"SHIFT-3", "Holy Prism"},
        -- {"3",       "Holy Prism"},
        -- {"SHIFT-3", "Light of Dawn"},

        ---------------------------------------------------

        -- Spec Abilities
        {"R",          "SHOCK", "MACRO"},
        {"SHIFT-R",    "Divine Toll"},
        -- {"SHIFT-R", "Barrier of Faith"},

        -- Targetting
        -- {"SHIFT-T", "Beacon of Faith"},
        -- {"CTRL-T",  "Beacon of Light"},

        ---------------------------------------------------

        -- Ults (Big Cooldowns)
        {"SHIFT-G", "Aura Mastery"},

        -- Extras
        {"ALT-CTRL-SHIFT-Z", "Absolution"},

        -- AoE (emanating from me)
        {"C",            "Consecration"},
        {"SHIFT-C",      "BEACON_SELF", "MACRO"},
        {"CTRL-SHIFT-C", "Aura Mastery"},
      },
      PROTECTION = {
        {"E", "Blessed Hammer"},
        -- Quick Heals
        {"SHIFT-1", "Cleanse Toxins"},

        -- Survival
        {"SHIFT-G", "Guardian of Ancient Kings"},

        -- Attacks
        {"R",       "Avenger's Shield"},
        {"SHIFT-R", "Divine Toll"},
        {"5",       "Divine Toll"},

        -- Taunting
        {"T", "Hand of Reckoning"},

        ---------------------------------------------------

        -- Blessings

        -- AoE (emanating from me)
        {"CTRL-C",  "Divine Toll"},
        {"SHIFT-4", "Divine Toll"},
      },
      RETRIBUTION = {
        -- Heals
        {"SHIFT-1", "Cleanse Toxins"},

        -- AoE Frontal
        {"3", "Wake of Ashes"},

        ---------------------------------------------------

        -- Sword
        {"Q",       "Q", "MACRO"},
        {"SHIFT-Q", "Templar's Verdict"},
        {"R",       "Blade of Justice"},

        -- Targetting

        ---------------------------------------------------

        -- Blessings
        {"CTRL-Z", "SANC_SELF", "MACRO"},

        -- AoE (emanating from me)
        {"C", "Divine Storm"},
      },
    },
    DRUID = {
      CLASS = {
        {"BUTTON4",          "MOUSE4", "MACRO"},
        {"SHIFT-SPACE",      "TRAVEL", "MACRO"}, -- Travel Form, but only out of combat, otherwise Mount Form
        {"CTRL-SPACE",       "Wild Charge"},
        {"CTRL-SHIFT-SPACE", "SLACKHACKS_MOUNT", "COMMAND"},
        {"SHIFT-H",          "Dreamwalk"},
        {"1",                "Rejuvenation"},
        {"SHIFT-1",          "Rejuvenation"},
        {"2",                "Regrowth"},
        {"SHIFT-2",          "Wild Growth"},
        {"3",                "Sunfire"},
        {"SHIFT-3",          "Starfire"},
        {"4",                "Moonfire"},
        {"SHIFT-4",          "Wrath"},
        {"CTRL-4",           "Starsurge"},
        {"5",                "Starsurge"},
        {"Q",                "Ferocious Bite"},
        {"E",                "SINGLE_TARGET", "MACRO"},
        -- {"SHIFT-E",       "Shred"},
        -- {"CTRL-E",        "Mangle"},
        -- {"ALT-E",         "Wrath"},
        {"R",                "AOE", "MACRO"},
        {"SHIFT-R",          "Swipe"},
        {"CTRL-R",           ""},
        {"ALT-R",            "Starfire"},
        {"T",                "T", "MACRO"}, -- Taunt or Cleanse
        {"F",                "INTERRUPT", "MACRO"},
        {"SHIFT-F",          "Entangling Roots"},
        {"CTRL-F",           "Incapacitating Roar"},
        {"ALT-CTRL-F",       "Mass Entanglement"},
        {"CTRL-G",           "ULT", "MACRO"},
        {"Z",                "Dash"},
        {"SHIFT-Z",          "Stampeding Roar"},
        {"CTRL-Z",           "Shadowmeld"},
        {"CTRL-SHIFT-Z",     "Shadowmeld"},
        {"ALT-CTRL-Z",       "REZ", "MACRO"},
        {"X",                "X", "MACRO"},
        {"C",                "CAT", "MACRO"},
        {"SHIFT-C",          "Prowl"},
        {"V",                "BEAR", "MACRO"}, -- Switch to Bear or cast "Frenzied Regeneration"
        {"SHIFT-V",          "Barkskin"},
        {"CTRL-V",           "Renewal"},
      },
      BALANCE = {
        {"CTRL-3",  "Starfall"},
        {"5",       "Fury of Elune"},
        {"SHIFT-5", "Wild Mushroom"},
        {"X",       "X", "MACRO"}, -- Switch to Moonkin or cast "Flap"
        {"G",       "Celestial Alignment"}, -- Also maps to Incarnation as that replaces Celestial Alignment
        {"SHIFT-G", "Celestial Alignment"},
      },
      FERAL = {
        {"E", "MULTIACTIONBAR7BUTTON1", "COMMAND"},
      },
      GUARDIAN = {
      },
      RESTORATION = {
        {"E",                "MULTIACTIONBAR7BUTTON1", "COMMAND"},
        {"`",                "Swiftmend"},
        {"SHIFT-1",          "Lifebloom"},
        {"G",                "Convoke the Spirits"},
        {"SHIFT-G",          "Tranquility"},
        {"ALT-CTRL-SHIFT-Z", "Revitalize"},
      }
    },
    MAGE = {
      CLASS = {
        {"Q",            "MULTIACTIONBAR7BUTTON1", "COMMAND"},
        {"R",            "Cone of Cold"},
        {"E",            "Frostbolt"},
        {"T",            ""},
        {"F",            "Counterspell"},
        {"SHIFT-F",      "Frost Nova"},
        {"CTRL-F",       "Dragon's Breath"},
        {"CTRL-SHIFT-F", "Polymorph"},
        {"G",            "Mirror Image"},
        {"CTRL-SHIFT-G", "Time Warp"},
        {"Z",            "Invisibility"},
        {"SHIFT-Z",      "Alter Time"},
        {"CTRL-Z",       "Shadowmeld"},
        {"CTRL-SHIFT-Z", "Shadowmeld"},
        {"X",            "Slow Fall"},
        {"C",            "Arcane Explosion"},
        {"SHIFT-C",      "Frost Nova"},
        {"SHIFT-V",      "Ice Block"},
        {"CTRL-SPACE",   "Blink"},
      },
      ARCANE = {},
      FIRE = {},
      FROST = {
        {"BUTTON4", "BLIZZ_CURSOR", "MACRO"},
        {"4",       "Ice Lance"},
        {"2",       "Ray of Frost"},
        {"3",       "Frozen Orb"},
        {"5",       "Flurry"},
        {"V",       "Ice Barrier"},
        {"CTRL-C",  "BLIZZ_SELF", "MACRO"},
      },
    },
    SHAMAN = {
      CLASS = {
        {"1",            "Flame Shock"},
        {"2",            "Healing Surge"},
        {"SHIFT-2",      "Healing Surge"},
        {"3",            "Earth Shock"},
        {"4",            "Frost Shock"},
        {"5",            "Primordial Wave"},
        {"Q",            "CHAIN", "MACRO"},
        {"R",            "Lightning Bolt"},
        {"E",            "Primal Strike"},
        {"SHIFT-R",      "Lava Burst"},
        {"CTRL-R",       "Flame Shock"},
        {"T",            "Healing Stream Totem"},
        {"ALT-T",        "Healing Tide Totem"},
        {"SHIFT-T",      "Spirit Link Totem"},
        {"CTRL-T",       "Earthbind Totem"},
        {"F",            "Wind Shear"},
        {"SHIFT-F",      "Wind Shear"},
        {"CTRL-F",       "Hex"},
        {"G",            "Spiritwalker's Grace"},
        {"SHIFT-G",      "Ancestral Guidance"},
        {"CTRL-G",       "Ascendance"},
        {"SHIFT-CTRL-G", "Heroism"},
        {"Z",            "Ghost Wolf"},
        {"SHIFT-Z",      "Wind Rush Totem"},
        {"CTRL-Z",       "Stoneform"},
        {"C",            "Thunderstorm"},
        {"SHIFT-C",      "RAIN_SELF", "MACRO"},
        {"V",            "Astral Shift"},
        {"CTRL-C",       "Stone Bulwark Totem"},
        {"CTRL-SPACE",   "Gust of Wind"},
        {"ALT-CTRL-Z",   "Ancestral Spirit"},
      },
      ELEMENTAL = {
        {"BUTTON4", "MOUSE4_ELE", "MACRO"},
      },
      ENHANCEMENT = {},
      RESTORATION = {
        {"BUTTON4",          "MOUSE4_RESTO", "MACRO"},
        {"1",                "Riptide"},
        {"ALT-1",            "Purify Spirit"},
        {"SHIFT-2",          "Healing Wave"},
        {"ALT-CTRL-SHIFT-Z", "Ancestral Vision"},
      },
    },
    PRIEST = {
      CLASS = {
        {"2",                "Flash Heal"},
        {"4",                "Shadow Word: Pain"},
        {"Q",                ""},
        {"SHIFT-Q",          "Shadowfiend"},
        {"E",                "Smite"},
        {"T",                "Dispel Magic"},
        {"SHIFT-T",          "Power Word: Fortitude"},
        {"CTRL-T",           "Power Word: Shield"},
        {"F",                "SOOTHE_SELF", "MACRO"},
        {"SHIFT-F",          "Psychic Scream"},
        {"CTRL-F",           "Dominate Mind"},
        {"ALT-CTRL-F",       "Mind Vision"},
        {"G",                "ULT", "MACRO"},
        {"SHIFT-G",          "PI_SELF", "MACRO"},
        {"Z",                "FEATHER_SELF", "MACRO"},
        {"SHIFT-Z",          "Fade"},
        {"CTRL-Z",           "Shadowmeld"},
        {"CTRL-SHIFT-Z",     "Shadowmeld"},
        {"ALT-CTRL-Z",       "REZ", "MACRO"},
        {"X",                "LEVITATE_SELF", "MACRO"},
        {"C",                "Holy Nova"},
        {"CTRL-C",           "Halo"},
        {"V",                "Desperate Prayer"},
        {"SHIFT-V",          "Fade"},
        {"CTRL-SPACE",       "Leap of Faith"},
        {"BUTTON4",          "MOUSE4", "MACRO"},
        -- {"BUTTON4",       "SANCTIFY_CURSOR", "MACRO"},
        -- {"SHIFT-BUTTON4", "FEATHER_CURSOR", "MACRO"},
        -- {"CTRL-BUTTON4",  "SOOTHE_CURSOR", "MACRO"},
      },
      DISCIPLINE = {
      },
      HOLY = {
        {"1",                "Holy Word: Serenity"},
        {"4",                "Holy Word: Chastise"},
        {"R",                "Holy Fire"},
        {"CTRL-G",           "Divine Hymn"},
        {"ALT-SHIFT-G",      "Symbol of Hope"},
        {"ALT-CTRL-SHIFT-Z", "Mass Resurrection"},
        {"SHIFT-C",          "SANCTIFY_SELF"},
        {"CTRL-V",           "GUARD_SELF", "MACRO"},
      },
      SHADOW = {
      }
    },
    WARRIOR = {
      CLASS = {
        {"`",            ""},
        {"1",            ""},
        {"2",            ""},
        {"4",            "Heroic Throw"},
        {"5",            "Champion's Spear"},
        {"SHIFT-2",      ""},
        {"Q",            "Shield Slam"},
        {"SHIFT-Q",      "Shield Block"},
        {"CTRL-Q",       "Shield Charge"},
        {"R",            ""},
        {"E",            "Hamstring"},
        {"E",            "MULTIACTIONBAR7BUTTON1", "COMMAND"},
        {"R",            "Whirlwind"},
        {"T",            "Taunt"},
        {"F",            "Pummel"},
        {"G",            "Avatar"},
        {"SHIFT-F",      "Storm Bolt"},
        {"CTRL-F",       ""},
        {"Z",            "Charge"},
        {"SHIFT-Z",      "Shield Charge"},
        {"CTRL-Z",       "Shadowmeld"},
        {"CTRL-SHIFT-Z", "Shadowmeld"},
        {"ALT-CTRL-Z",   "Shadowmeld"},
        {"X",            ""},
        {"C",            "Thunder Clap"},
        {"SHIFT-V",      ""},
        {"CTRL-V",       ""},
        {"CTRL-SPACE",   "Heroic Leap"},
        {"BUTTON4",      "MOUSE4", "MACRO"},
      },
      ARMS = {
      },
      FURY = {
      },
      PROTECTION = {

        {"V", "Shield Wall"},
      }
    },
    EVOKER = {
      CLASS = {
        -- General
        {"F8",         "SUMMONPET", "MACRO"},
        {"CTRL-SPACE", "Hover"},
        {"BUTTON4",    "MOUSE4", "MACRO"},
        {"BUTTON5",    "MOUSE5", "MACRO"},
        {"SHIFT-G",    "TRINKETS", "MACRO"},

        -- Quick Heals
        {"1",      "Word of Glory"},
        {"CTRL-1", "Lay on Hands"},

        -- Cast Heals
        {"2", "Flash of Light"},

        -- Ranged Attacks
        {"4", "Judgment"},
        {"5", "Divine Toll"},

        ---------------------------------------------------

        -- Shield (Tanking)
        {"Q",     "Shield of the Righteous"},
        {"ALT-Q", "Hand of Reckoning"},

        -- Sword
        {"E", "Crusader Strike"},

        -- Targetting
        -- {"T", "Hand of Reckoning"},
        -- {"T", "TARGET", "MACRO"},
        {"T",    "BLESST", "MACRO"},

        ---------------------------------------------------

        -- CC
        {"F",         "Rebuke"},
        {"SHIFT-F",   "Hammer of Justice"},
        -- {"CTRL-F", "Repentance"},
        {"CTRL-F",    "Blinding Light"},

        -- Ultimates (Big Cooldowns)
        {"G", "WINGS", "MACRO"},

        -- Extras
        {"Z",          "FREEDOM", "MACRO"},
        {"SHIFT-Z",    "Will to Survive"},
        {"ALT-Z",      "PVP_TRINKET", "MACRO"},
        {"ALT-CTRL-Z", "REZ", "MACRO"},

        -- AoE (emanating from me)
        {"C",       "Consecration"},
        {"SHIFT-C", "Divine Toll"},
        {"CTRL-C",  "Divine Toll"},

        -- Vitality (Self-Heals/Protections)
        {"V",            "VITALITY", "MACRO"},
        {"SHIFT-V",      "Divine Shield"},
        {"CTRL-SHIFT-V", "BOP_SELF", "MACRO"},
        {"CTRL-V",       "LAY_SELF", "MACRO"},
      },
      DEVASTATION = {
      },
      PRESERVATION = {
      },
      AUGMENTATION = {
        {"ALT-CTRL-SHIFT-Z", "Mass Return"},
      }
    },
    WARLOCK = {
      CLASS = {
        {"BUTTON4",    "MOUSE4", "MACRO"},
        {"CTRL-SPACE", "Spatial Rift"},
        {"Q",          "PetControl", "MACRO"},
        {"Z",          "Burning Rush"},
        {"1",          "Curse of Weakness"},
        {"2",          "Chaos Bolt"},
        {"4",          "Conflagrate"},
        {"T",          "Drain Life"},
        {"F",          "Fear"},
        {"V",          "Unending Resolve"},
      },
      AFFLICTION = {},
      DEMONOLOGY = {},
      DESTRUCTION = {
        {"E",       "Incinerate"},
        {"R",       "Immolate"},
        {"V",       "Unending Resolve"},
        {"SHIFT-V", "Drain Life"},
        {"CTRL-V",  "Drain Life"},
      }
    },
  },
  CLASSIC = {
    DRUID = {
      {"1",  "ACTIONBUTTON1", "COMMAND"},
      {"2",  "ACTIONBUTTON2", "COMMAND"},
      {"3",  "ACTIONBUTTON3", "COMMAND"},
      {"4",  "ACTIONBUTTON4", "COMMAND"},
      {"5",  "ACTIONBUTTON5", "COMMAND"},
      {"6",  "ACTIONBUTTON6", "COMMAND"},
      {"7",  "ACTIONBUTTON7", "COMMAND"},
      {"8",  "ACTIONBUTTON8", "COMMAND"},
      {"9",  "ACTIONBUTTON9", "COMMAND"},
      {"10", "ACTIONBUTTON10", "COMMAND"},
      {"11", "ACTIONBUTTON11", "COMMAND"},
      {"12", "ACTIONBUTTON12", "COMMAND"},
    },
    PALADIN = {
      {"1",  "ACTIONBUTTON1", "COMMAND"},
      {"2",  "ACTIONBUTTON2", "COMMAND"},
      {"3",  "ACTIONBUTTON3", "COMMAND"},
      {"4",  "ACTIONBUTTON4", "COMMAND"},
      {"5",  "ACTIONBUTTON5", "COMMAND"},
      {"6",  "ACTIONBUTTON6", "COMMAND"},
      {"7",  "ACTIONBUTTON7", "COMMAND"},
      {"8",  "ACTIONBUTTON8", "COMMAND"},
      {"9",  "ACTIONBUTTON9", "COMMAND"},
      {"10", "ACTIONBUTTON10", "COMMAND"},
      {"11", "ACTIONBUTTON11", "COMMAND"},
      {"12", "ACTIONBUTTON12", "COMMAND"},

      ---------------------------------------------------

      -- General
      {"E", "!ENGAGE", "MACRO"}, -- Crusader Strike

      {"F9",      "SHAPESHIFTBUTTON1", "COMMAND"},
      {"F10",     "SHAPESHIFTBUTTON2", "COMMAND"},
      {"F11",     "SHAPESHIFTBUTTON3", "COMMAND"},
      {"F12",     "SHAPESHIFTBUTTON4", "COMMAND"},
      {"`",       "!STOP", "MACRO"},
      {"BUTTON4", "MOUSE4", "MACRO"},
      {"BUTTON5", "MOUSE5", "MACRO"},

      -- Core
      {"Z",     "Divine Protection"},
      {"ALT-Z", "Perception"},

      -- Main Attacks and Runes?
      {"4",       "Judgement"},
      {"5",       "Hammer of Wrath"},
      {"C",       "Consecration"},
      {"SHIFT-C", "Divine Storm"},

      -- Heals (Coming from left hand?)
      {"3",      "Divine Storm"}, -- AoE Heal
      {"Q",      "Holy Light"}, -- Instant Attack (Holy Shock macro @ Enemy only)
      {"ALT-Q",  "Purify"}, -- Cleanse later
      {"CTRL-Z", "Redemption"},

      -- "OHSHIT" Buttons
      {"G",       "Blessing of Protection"},
      {"SHIFT-G", "Lay on Hands"},

      -- CC
      {"F",       "Rebuke"},
      {"SHIFT-F", "Hammer of Justice"},

      -- Blessings
      {"T",       "Blessing of Might"},
      {"SHIFT-T", "Blessing of Wisdom"},

      -- Seals & Judgement
      {"R",       "Seal of Righteousness"},
      {"SHIFT-R", "Seal of the Crusader"},

      -- Items
      {"ALT-Z", "Insignia of the Alliance", "ITEM"}, -- PvP Trinket
    },
    PRIEST = {
      {"1",  "ACTIONBUTTON1", "COMMAND"},
      {"2",  "ACTIONBUTTON2", "COMMAND"},
      {"3",  "ACTIONBUTTON3", "COMMAND"},
      {"4",  "ACTIONBUTTON4", "COMMAND"},
      {"5",  "ACTIONBUTTON5", "COMMAND"},
      {"6",  "ACTIONBUTTON6", "COMMAND"},
      {"7",  "ACTIONBUTTON7", "COMMAND"},
      {"8",  "ACTIONBUTTON8", "COMMAND"},
      {"9",  "ACTIONBUTTON9", "COMMAND"},
      {"10", "ACTIONBUTTON10", "COMMAND"},
      {"11", "ACTIONBUTTON11", "COMMAND"},
      {"12", "ACTIONBUTTON12", "COMMAND"},

      {"`",            "!STOP", "MACRO"},
      {"1",            "Renew"},
      {"2",            "Lesser Heal"},
      {"4",            "Shadow Word: Pain"},
      -- {"5",         "Penance"},
      {"Q",            "Power Word: Shield"},
      {"E",            "!ENGAGE", "MACRO"},
      {"T",            "Power Word: Fortitude"},
      {"Z",            "Fade"},
      {"SHIFT-Z",      "Shadowmeld"},
      {"CTRL-SHIFT-Z", "Shadowmeld"},
      {"CTRL-Z",       "Fade"},
      {"V",            "SHIELD_SELF", "MACRO"},
    }
  }
}