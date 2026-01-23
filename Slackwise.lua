-- These are my personal configs.
-- They only load for me, so don't worry about 'em.


-- Change implicit global scope to our addon "namespace":
setfenv(1, _G.SlackwiseTweaks)

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
    ['GROUND_PASSENGER']  = MOUNT_IDS["Mekgineer's Chopper"],
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
    ['FLYING_PASSENGER']  = MOUNT_IDS["Algarian Stormrider"],
    ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    -- Green themed
    -- ['GROUND']            = MOUNT_IDS["Swift Razzashi Raptor"],
    -- ['FLYING']            = MOUNT_IDS["Ashes of Al'ar"],
    -- ['WATER']             = MOUNT_IDS["Sea Turtle"],
    -- ['GROUND_PASSENGER']  = MOUNT_IDS["Swift Razzashi Raptor"],
    -- ['FLYING_PASSENGER']  = MOUNT_IDS["Ashes of Al'ar"],
    -- ['GROUND_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
    -- ['FLYING_SHOWOFF']    = MOUNT_IDS["Swift Razzashi Raptor"],
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
}


BINDINGS = {
  GLOBAL = {
    {"ALT-CTRL-END",          "command",  "SLACKWISETWEAKS_RELOADUI"},
    {"ALT-CTRL-`",            "command",  "FOCUSTARGET"},
    {"ALT-`",                 "command",  "INTERACTTARGET"},
    {"W",                     "command",  "MOVEFORWARD"},
    {"A",                     "command",  "STRAFELEFT"},
    {"S",                     "command",  "MOVEBACKWARD"},
    {"D",                     "command",  "STRAFERIGHT"},
    {"ALT-A",                 "command",  "TURNLEFT"},
    {"ALT-D",                 "command",  "TURNRIGHT"},
    {"F1",                    "command",  "ACTIONBUTTON1"},
    {"F2",                    "command",  "ACTIONBUTTON2"},
    {"F3",                    "command",  "ACTIONBUTTON3"},
    {"F4",                    "command",  "ACTIONBUTTON4"},
    {"F5",                    "command",  "ACTIONBUTTON5"},
    {"F6",                    "command",  "ACTIONBUTTON6"},
    {"F7",                    "command",  "ACTIONBUTTON7"},
    {"F8",                    "command",  "ACTIONBUTTON8"},
    {"F9",                    "command",  "ACTIONBUTTON9"},
    {"F10",                   "command",  "ACTIONBUTTON10"},
    {"F11",                   "command",  "ACTIONBUTTON11"},
    {"F12",                   "command",  "ACTIONBUTTON12"},
    {"1",                     "command",  "NONE"},
    {"2",                     "command",  "NONE"},
    {"3",                     "command",  "NONE"},
    {"4",                     "command",  "NONE"},
    {"5",                     "command",  "NONE"},
    {"6",                     "command",  "NONE"},
    {"7",                     "command",  "NONE"},
    {"8",                     "command",  "NONE"},
    {"9",                     "command",  "NONE"},
    {"0",                     "command",  "NONE"},
    {"-",                     "command",  "NONE"},
    {"=",                     "command",  "NONE"},
    {"SHIFT-1",               "command",  "NONE"},
    {"SHIFT-2",               "command",  "NONE"},
    {"SHIFT-3",               "command",  "NONE"},
    {"SHIFT-4",               "command",  "NONE"},
    {"SHIFT-5",               "command",  "NONE"},
    {"SHIFT-6",               "command",  "NONE"},
    {"SHIFT-7",               "command",  "NONE"},
    {"SHIFT-8",               "command",  "NONE"},
    {"SHIFT-9",               "command",  "NONE"},
    {"SHIFT-0",               "command",  "NONE"},
    {"CTRL-1",                "command",  "NONE"},
    {"CTRL-2",                "command",  "NONE"},
    {"CTRL-3",                "command",  "NONE"},
    {"CTRL-4",                "command",  "NONE"},
    {"CTRL-5",                "command",  "NONE"},
    {"CTRL-6",                "command",  "NONE"},
    {"CTRL-7",                "command",  "NONE"},
    {"CTRL-8",                "command",  "NONE"},
    {"CTRL-9",                "command",  "NONE"},
    {"CTRL-0",                "command",  "NONE"},
    {",",                     "command",  "NONE"},
    {"ALT-CTRL-W",            "command",  "TOGGLEFOLLOW"},
    {"E",                     "command",  "INTERACTTARGET"},
    {"SHIFT-E",               "command",  "INTERACTTARGET"},
    {"CTRL-E",                "spell",    "Single-Button Assistant"},
    {"ALT-E",                 "command",  "EXTRAACTIONBUTTON1"},
    {"SHIFT-R",               "command",  "NONE"},
    {"CTRL-R",                "command",  "NONE"},
    {"CTRL-S",                "command",  "NONE"},
    {"ALT-CTRL-S",            "spell",    "Survey" },
    {"H",                     "command",  "TOGGLEGROUPFINDER"},
    {"SHIFT-H",               "command",  "TOGGLECHARACTER4"}, -- Honor Panel (PvP Queue)
    {"CTRL-H",                "macro",    "HEARTH"},
    {"ALT-CTRL-H",            "macro",    "HEARTH_DALARAN"},
    {"ALT-H",                 "command",  "TOGGLEUI"},
    {"ALT-CTRL-L",            "command",  "TOGGLEACTIONBARLOCK"},
    {"X",                     "command",  "SITORSTAND"},
    {"SHIFT-X",               "macro",    "MOUNT_BEAR"},
    {"CTRL-SHIFT-X",          "macro",    "MOUNT_DINO"},
    {"ALT-X",                 "command",  "SITORSTAND"},
    {"ALT-CTRL-X",            "command",  "TOGGLERUN"},
    {"ALT-CTRL-SHIFT-X",      "spell",    "Switch Flight Style" },
    {"ALT-CTRL-SHIFT-V",      "spell",    "Recuperate" },
    {"ALT-CTRL-SHIFT-M",      "spell",    "Switch Flight Style" },
    {"ALT-C",                 "command",  "SLACKWISETWEAKS_BEST_MANA_POTION" },
    {"ALT-V",                 "command",  "SLACKWISETWEAKS_BEST_HEALING_POTION" },
    {"ALT-CTRL-V",            "command",  "SLACKWISETWEAKS_BEST_BANDAGE" },
    {"V",                     "command",  "NONE"},
    {"SHIFT-V",               "command",  "NONE"},
    {"CTRL-V",                "command",  "NONE"},
    {"B",                     "command",  "INTERACTTARGET"},
    {"SHIFT-B",               "command",  "OPENALLBAGS"},
    {"CTRL-B",                "command",  "TOGGLECHARACTER0"},
    {"ALT-CTRL-B",            "command",  "SLACKWISETWEAKS_SETBINDINGS"},
    {"ALT-B",                 "command",  "TOGGLESHEATH"},
    {"CTRL-M",                "command",  "TOGGLEMUSIC"},
    {"ALT-M",                 "command",  "TOGGLESOUND"},
    {"ALT-CTRL-M",            "command",  "SLACKWISETWEAKS_RESTART_SOUND"},
    {"SHIFT-UP",              "command",  "NONE"},
    {"SHIFT-DOWN",            "command",  "NONE"},
    {"SHIFT-ENTER",           "command",  "REPLY"},
    {"CTRL-ENTER",            "command",  "REPLY2"},
    {"SHIFT-SPACE",           "command",  "SLACKWISETWEAKS_MOUNT"},
    {"SHIFT-HOME",            "command",  "SETVIEW1"},
    {"HOME",                  "command",  "SETVIEW2"},
    {"END",                   "command",  "SETVIEW3"},
    {"PRINTSCREEN",           "command",  "SCREENSHOT"},
    {"NUMLOCK",               "command",  "NONE"},
    {"NUMPAD0",               "command",  "RAIDTARGET8"},
    {"NUMPAD1",               "command",  "RAIDTARGET7"},
    {"NUMPAD2",               "command",  "RAIDTARGET2"},
    {"NUMPAD3",               "command",  "RAIDTARGET4"},
    {"NUMPAD4",               "command",  "RAIDTARGET6"},
    {"NUMPAD5",               "command",  "RAIDTARGET5"},
    {"NUMPAD6",               "command",  "RAIDTARGET1"},
    {"NUMPAD7",               "command",  "RAIDTARGET3"},
    {"NUMPADDECIMAL",         "command",  "RAIDTARGETNONE"},
    {"BUTTON3",               "command",  "TOGGLEAUTORUN"},
    {"ALT-BUTTON3",           "command",  "TOGGLEPINGLISTENER"},
    {"SHIFT-MOUSEWHEELUP",    "command",  "NONE"},
    {"SHIFT-MOUSEWHEELDOWN",  "command",  "NONE"}
  },
  RETAIL = {
    HUNTER = {
      CLASS = {
        { "F8",               "spell",   "Call Pet 1" },
        { "F9",               "spell",   "Call Pet 2" },
        { "F10",              "spell",   "Call Pet 3" },
        { "F11",              "spell",   "Call Pet 4" },
        { "F12",              "spell",   "Call Pet 5" },
        { "`",                "macro",   "." },
        { "1",                "spell",   "Explosive Shot" },
        { "2",                "spell",   "Hunter's Mark" },
        { "ALT-1",            "macro",   "MD" },
        { "3",                "spell",   "Multi-Shot" },
        { "SHIFT-3",          "spell",   "Explosive Shot" },
        { "4",                "spell",   "Arcane Shot" },
        { "Q",                "macro",   "PetControl" },
        { "CTRL-Q",           "command", "BONUSACTIONBUTTON7" },        -- Pet Family Ability
        { "CTRL-SHIFT-Q",     "command", "BONUSACTIONBUTTON1" },        -- Pet Family Ability
        { "ALT-CTRL-Q",       "macro",   "PetToggle" },
        { "ALT-SHIFT-Q",      "spell",   "Play Dead" },
        { "ALT-CTRL-SHIFT-Q", "spell",   "Eyes of the Beast" },
        { "SHIFT-E",          "spell",   "Bursting Shot" },
        { "ALT-CTRL-E",       "macro",   "ChainEagle" },
        { "T",                "macro",   "Traps" },
        { "F",                "spell",   "Concussive Shot" },
        { "SHIFT-F",          "spell",   "Counter Shot" },
        { "CTRL-F",           "spell",   "Intimidation" },
        { "ALT-F",            "spell",   "Tranquilizing Shot" },
        { "ALT-CTRL-F",       "spell",   "Scare Beast" },
        { "ALT-CTRL-SHIFT-F", "spell",   "Fireworks" },
        { "Z",                "spell",   "Aspect of the Cheetah" },
        { "SHIFT-Z",          "spell",   "Camouflage" },
        { "ALT-SHIFT-Z",      "spell",   "Aspect of the Chameleon" },
        -- { "ALT-Z",            "item",    "Potion of the Hidden Spirit" },
        -- { "ALT-C",            "item",    "Potion of the Psychopomp's Speed" },
        -- { "ALT-CTRL-C",       "macro",   "CallFocus" },
        { "CTRL-Z",           "spell",   "Feign Death" },
        { "CTRL-SHIFT-Z",     "macro",   "Shadowmeld" },
        { "C",                "spell",   "" },
        { "SHIFT-C",          "spell",   "" },
        { "CTRL-C",           "macro",   "" },
        -- { "CTRL-SHIFT-C",     "item",    "Gladiator's Medallion" },
        { "B",                "spell",   "Fetch" },
        { "V",                "spell",   "Exhilaration" },
        { "SHIFT-V",          "spell",   "Survival of the Fittest" },
        { "CTRL-V",           "spell",   "Aspect of the Turtle" },
        -- { "CTRL-SHIFT-V",     "item",    "Wildercloth Bandage" },
        -- { "ALT-V",            "macro",   "Vitality" },
        -- { "ALT-CTRL-V",       "macro",   "SurviveFocus" },
        { "CTRL-SPACE",       "spell",   "Disengage" },
        { "BUTTON4",          "macro",   "TrapsCursor" },
        { "BUTTON5",          "macro",   "PetAttackCursor" },
      },
      MARKSMANSHIP = {
        { "SHIFT-2",          "spell",   "Aimed Shot" },
        { "CTRL-3",           "spell",   "Barrage" },
        { "ALT-3",            "spell",   "Salvo" },
        { "SHIFT-4",          "spell",   "Aimed Shot" }, -- Procs as INSTANT so on same key as Arcane
        { "5",                "spell",   "Kill Shot" },
        { "SHIFT-5",          "spell",   "Sniper Shot" },
        { "R",                "spell",   "Steady Shot" },
        { "SHIFT-R",          "spell",   "Rapid Fire" },
        { "G",                "macro",   "Trueshot!" },
      },
      SURVIVAL = {
        { "1",                "macro",   "Serpent Sting" },
        { "2",                "spell",   "Kill Command" },
        { "4",                "spell",   "Shrapnel Bomb" },
        { "5",                "spell",   "Kill Shot" },
        { "E",                "spell",   "Raptor Strike" },
        { "SHIFT-E",          "spell",   "Butchery" },
        { "R",                "spell",   "Harpoon" },
        { "F",                "spell",   "Wing Clip" },        --Auto-maps to "Concussive Shot" in MM spec
      }
    },
    PALADIN = {
      CLASS = {
        { "1",  "command", "ACTIONBUTTON1" },
        { "2",  "command", "ACTIONBUTTON2" },
        { "3",  "command", "ACTIONBUTTON3" },
        { "4",  "command", "ACTIONBUTTON4" },
        { "5",  "command", "ACTIONBUTTON5" },
        { "6",  "command", "ACTIONBUTTON6" },
        { "7",  "command", "ACTIONBUTTON7" },
        { "8",  "command", "ACTIONBUTTON8" },
        { "9",  "command", "ACTIONBUTTON9" },
        { "10", "command", "ACTIONBUTTON10" },
        { "11", "command", "ACTIONBUTTON11" },
        { "12", "command", "ACTIONBUTTON12" },

        ---------------------------------------------------

        -- General
        { "F8",         "macro",   "SUMMONPET" },
        { "F9",         "command", "SHAPESHIFTBUTTON1" },
        { "F10",        "command", "SHAPESHIFTBUTTON2" },
        { "F11",        "command", "SHAPESHIFTBUTTON3" },
        { "F12",        "command", "SHAPESHIFTBUTTON4" },
        { "CTRL-SPACE", "spell",   "Divine Steed" },
        { "BUTTON4",    "macro",   "MOUSE4" },
        { "BUTTON5",    "macro",   "MOUSE5" },
        { "ALT-CTRL-SHIFT-X", "spell",   "Contemplation" },

        -- Quick Heals
        { "1",          "spell",   "Word of Glory" },
        { "CTRL-1",     "spell",   "Lay on Hands" },

        -- Cast Heals
        { "2",          "spell",   "Flash of Light" },

        -- Ranged Attacks
        { "4",          "spell",   "Judgment" },
        { "5",          "spell",   "Holy Prism" },

        ---------------------------------------------------

        -- Shield (Tanking)
        { "Q",          "spell",   "Shield of the Righteous" },
        { "ALT-Q",      "spell",   "Hand of Reckoning" },

        -- Sword
        { "E",          "spell",   "Crusader Strike" },

        -- Targetting
        -- { "T",          "spell",   "Hand of Reckoning" },
        -- { "T",          "macro",   "TARGET" },
        { "T",          "macro",   "BLESST" },

        ---------------------------------------------------

        -- CC
        { "F",          "spell",   "Rebuke" },
        { "SHIFT-F",    "spell",   "Hammer of Justice" },
        { "CTRL-F",     "spell",   "Repentance" },

        -- Ultimates (Big Cooldowns)
        { "G",          "macro",   "WINGS" },

        -- Extras
        { "Z",          "macro",   "FREEDOM" },
        { "SHIFT-Z",    "spell",   "Will to Survive" },
        { "ALT-Z",      "macro",   "PVP_TRINKET" },
        { "ALT-CTRL-Z", "macro",   "REZ" },

        -- AoE (emanating from me)
        { "C",          "spell",   "Consecration" },
        { "SHIFT-C",    "spell",   "Divine Toll" },

        -- Vitality (Self-Heals/Protections)
        { "V",          "macro",   "VITALITY" },
        { "SHIFT-V",    "spell",   "Divine Shield" },
        { "CTRL-SHIFT-V","macro",  "BOP_SELF" },
        { "CTRL-V",     "macro",   "LAY_SELF" },
      },
      HOLY = {
        -- Quick Heals
        { "`",          "spell",   "Barrier of Faith" },
        { "SHIFT-1",    "spell",   "Cleanse" },

        -- Cast Heals
        { "SHIFT-2",    "spell",   "Holy Light" },
        -- { "2",          "spell",   "Holy Light" },
        -- { "SHIFT-2",    "spell",   "Flash of Light" },

        -- AoE Heals
        { "3",          "spell",   "Light of Dawn" },
        -- { "SHIFT-3",    "spell",   "Holy Prism" },
        -- { "3",          "spell",   "Holy Prism" },
        -- { "SHIFT-3",    "spell",   "Light of Dawn" },

        ---------------------------------------------------

        -- Spec Abilities
        { "R",          "macro",   "SHOCK" },
        { "SHIFT-R",    "spell",   "Holy Prism" },
        -- { "SHIFT-R",    "spell",   "Barrier of Faith" },

        -- Targetting
        -- { "SHIFT-T",    "spell",   "Beacon of Faith" },
        -- { "CTRL-T",     "spell",   "Beacon of Light" },

        ---------------------------------------------------

        -- Ults (Big Cooldowns)
        { "SHIFT-G",    "spell",   "Aura Mastery" },

        -- Extras
        { "ALT-CTRL-SHIFT-Z", "spell",   "Absolution" },

        -- CC
        { "CTRL-F",     "spell",   "Blinding Light" },

        -- AoE (emanating from me)
        { "C",          "spell",   "Consecration" },
        { "CTRL-C",     "macro",   "BEACON_SELF" },
        -- { "CTRL-C",     "spell",   "Tyr's Deliverance" },
      },
      PROTECTION = {
        { "E",           "spell",    "Blessed Hammer"},
        -- Quick Heals
        { "SHIFT-1",    "spell",   "Cleanse Toxins" },

        ---------------------------------------------------
        { "CTRL-F",     "spell",   "Blinding Light" },


        -- Survival
        { "G",          "spell",   "Guardian of Ancient Kings" },


        -- Attacks
        { "R",          "spell",   "Avenger's Shield" },
        { "SHIFT-R",    "spell",   "Divine Toll" },
        { "5",          "spell",   "Divine Toll" },

        -- Taunting
        { "T",          "spell",   "Hand of Reckoning" },

        ---------------------------------------------------

        -- Blessings

        -- AoE (emanating from me)
        { "CTRL-C",     "spell",   "Divine Toll" },
      },
      RETRIBUTION = {
        -- Heals
        { "SHIFT-1",    "spell",   "Cleanse Toxins" },

        -- AoE Frontal
        { "3",          "spell",   "Wake of Ashes" },

        ---------------------------------------------------

        -- Sword
        { "Q",          "macro",   "Q" },
        { "SHIFT-Q",    "spell",   "Templar's Verdict" },
        { "R",          "spell",   "Blade of Justice" },

        -- Targetting

        ---------------------------------------------------

        -- Blessings
        { "CTRL-Z",     "macro",   "SANC_SELF" },

        -- AoE (emanating from me)
        { "C",         "spell",   "Divine Storm" },
      },
    },
    DRUID = {
      CLASS = {
        {"BUTTON4",               "macro",   "MOUSE4"},
        {"SHIFT-SPACE",           "macro",   "TRAVEL"}, -- Travel Form, but only out of combat, otherwise Mount Form
        {"CTRL-SPACE",            "spell",   "Wild Charge"},
        {"CTRL-SHIFT-SPACE",      "command", "SLACKWISETWEAKS_MOUNT"},
        {"SHIFT-H",               "spell",   "Dreamwalk"},
        {"1",                     "spell",   "Rejuvenation"},
        {"SHIFT-1",               "spell",   "Rejuvenation"},
        {"2",                     "spell",   "Regrowth"},
        {"SHIFT-2",               "spell",   "Wild Growth"},
        {"3",                     "spell",   "Sunfire"},
        {"SHIFT-3",               "spell",   "Starfire"},
        {"4",                     "spell",   "Moonfire"},
        {"SHIFT-4",               "spell",   "Wrath"},
        {"CTRL-4",                "spell",   "Starsurge"},
        {"5",                     "spell",   "Starsurge"},
        {"Q",                     "spell",   "Ferocious Bite"},
        {"E",                     "macro",   "SINGLE_TARGET"},
        -- {"SHIFT-E",               "spell",   "Shred"},
        -- {"CTRL-E",                "spell",   "Mangle"},
        -- {"ALT-E",                 "spell",   "Wrath"},
        {"R",                     "macro",   "AOE"},
        {"SHIFT-R",               "spell",   "Swipe"},
        {"CTRL-R",                "spell",   ""},
        {"ALT-R",                 "spell",   "Starfire"},
        {"T",                     "macro",   "T"}, -- Taunt or Cleanse
        {"F",                     "macro",   "INTERRUPT"},
        {"SHIFT-F",               "spell",   "Entangling Roots"},
        {"CTRL-F",                "spell",   "Incapacitating Roar"},
        {"ALT-CTRL-F",            "spell",   "Mass Entanglement"},
        {"CTRL-G",                "macro",   "ULT"},
        {"Z",                     "spell",   "Dash"},
        {"SHIFT-Z",               "spell",   "Stampeding Roar"},
        {"CTRL-Z",                "spell",   "Shadowmeld"},
        {"ALT-CTRL-Z",            "macro",   "REZ"},
        {"X",                     "macro",   "X"},
        {"C",                     "macro",   "CAT"},
        {"SHIFT-C",               "spell",   "Prowl"},
        {"V",                     "macro",   "BEAR"}, -- Switch to Bear or cast "Frenzied Regeneration"
        {"SHIFT-V",               "spell",   "Barkskin"},
        {"CTRL-V",                "spell",   "Renewal"},
      },
      BALANCE = {
        {"CTRL-3",                "spell",   "Starfall"},
        {"5",                     "spell",   "Fury of Elune"},
        {"SHIFT-5",               "spell",   "Wild Mushroom"},
        {"X",                     "macro",   "X"}, -- Switch to Moonkin or cast "Flap"
        {"G",                     "spell",   "Celestial Alignment"}, -- Also maps to Incarnation as that replaces Celestial Alignment
        {"SHIFT-G",               "spell",   "Celestial Alignment"},
      },
      FERAL = {
        {"E",                     "command", "MULTIACTIONBAR7BUTTON1"},
      },
      GUARDIAN = {
      },
      RESTORATION = {
        {"E",                     "command", "MULTIACTIONBAR7BUTTON1"},
        {"`",                     "spell",   "Swiftmend"},
        {"SHIFT-1",               "spell",   "Lifebloom"},
        {"G",                     "spell",   "Convoke the Spirits"},
        {"SHIFT-G",               "spell",   "Tranquility"},
        {"ALT-CTRL-SHIFT-Z",      "spell",   "Revitalize"},
      }
    },
    MAGE = {
      CLASS = {
        {"E",                 "spell",   "Frostbolt"},
        {"E",                 "command", "MULTIACTIONBAR7BUTTON1"},
        {"R",                 "spell",   "Cone of Cold"},
        {"T",                 "spell",   "Fire Blast"},
        {"F",                 "spell",   "Frost Nova"},
        {"SHIFT-F",           "spell",   "Counterspell"},
        {"CTRL-F",            "spell",   "Polymorph"},
        {"Z",                 "spell",   "Invisibility"},
        {"X",                 "spell",   "Slow Fall"},
        {"C",                 "spell",   "Arcane Explosion"},
        {"SHIFT-V",           "spell",   "Ice Cold"},
        {"CTRL-V",            "spell",   "Mass Barrier"},
        {"CTRL-SPACE",        "spell",   "Blink"},
        {"ALT-CTRL-Z",        "spell",   "Shadowmeld"},
      },
      ARCANE = {},
      FIRE = {},
      FROST = {
        {"BUTTON4",           "macro",   "BLIZZ_CURSOR"},
        {"3",                 "spell",   "Comet Storm"},
        {"4",                 "spell",   "Ice Lance"},
        {"5",                 "spell",   "Flurry"},
        {"Q",                 "spell",   "Frozen Orb"},
        {"V",                 "spell",   "Ice Barrier"},
      },
    },
    SHAMAN = {
      CLASS = {
        {"1",                 "spell",   "Flame Shock"},
        {"2",                 "spell",   "Healing Surge"},
        {"SHIFT-2",           "spell",   "Healing Surge"},
        {"3",                 "spell",   "Earth Shock"},
        {"4",                 "spell",   "Frost Shock"},
        {"5",                 "spell",   "Primordial Wave"},
        {"Q",                 "macro",   "CHAIN"},
        {"R",                 "spell",   "Lightning Bolt"},
        {"E",                 "spell",   "Primal Strike"},
        {"SHIFT-R",           "spell",   "Lava Burst"},
        {"CTRL-R",            "spell",   "Flame Shock"},
        {"T",                 "spell",   "Healing Stream Totem"},
        {"ALT-T",             "spell",   "Healing Tide Totem"},
        {"SHIFT-T",           "spell",   "Spirit Link Totem"},
        {"CTRL-T",            "spell",   "Earthbind Totem"},
        {"F",                 "spell",   "Wind Shear"},
        {"SHIFT-F",           "spell",   "Wind Shear"},
        {"CTRL-F",            "spell",   "Hex"},
        {"G",                 "spell",   "Spiritwalker's Grace"},
        {"SHIFT-G",           "spell",   "Ancestral Guidance"},
        {"CTRL-G",            "spell",   "Ascendance"},
        {"SHIFT-CTRL-G",      "spell",   "Heroism"},
        {"Z",                 "spell",   "Ghost Wolf"},
        {"SHIFT-Z",           "spell",   "Wind Rush Totem"},
        {"CTRL-Z",            "spell",   "Stoneform"},
        {"C",                 "spell",   "Thunderstorm"},
        {"SHIFT-C",           "macro",   "RAIN_SELF"},
        {"V",                 "spell",   "Astral Shift"},
        {"CTRL-C",            "spell",   "Stone Bulwark Totem"},
        {"CTRL-SPACE",        "spell",   "Gust of Wind"},
        {"ALT-CTRL-Z",        "spell",   "Ancestral Spirit"},
      },
      ELEMENTAL = {
        {"BUTTON4",           "macro",   "MOUSE4_ELE"},
      },
      ENHANCEMENT = {},
      RESTORATION = {
        {"BUTTON4",           "macro",   "MOUSE4_RESTO"},
        {"1",                 "spell",   "Riptide"},
        {"ALT-1",             "spell",   "Purify Spirit"},
        {"SHIFT-2",           "spell",   "Healing Wave"},
        {"ALT-CTRL-SHIFT-Z",  "spell",   "Ancestral Vision"},
      },
    },
    PRIEST = {
      CLASS = {
        {"1",                 "spell",   "Renew"},
        {"2",                 "spell",   "Flash Heal"},
        {"3",                 "spell",   "Divine Star"},
        {"4",                 "spell",   "Shadow Word: Pain"},
        {"Q",                 "spell",   ""},
        {"SHIFT-Q",           "spell",   "Shadowfiend"},
        {"E",                 "spell",   "Smite"},
        {"T",                 "spell",   "Dispel Magic"},
        {"SHIFT-T",           "spell",   "Power Word: Fortitude"},
        {"CTRL-T",            "spell",   "Power Word: Shield"},
        {"F",                 "macro",   "SOOTHE_SELF"},
        {"SHIFT-F",           "spell",   "Psychic Scream"},
        {"CTRL-F",            "spell",   "Dominate Mind"},
        {"ALT-CTRL-F",        "spell",   "Mind Vision"},
        {"G",                 "macro",   "ULT"},
        {"SHIFT-G",           "macro",   "PI_SELF"},
        {"Z",                 "macro",   "FEATHER_SELF"},
        {"SHIFT-Z",           "spell",   "Fade"},
        {"CTRL-Z",            "spell",   "Shadowmeld"},
        {"ALT-CTRL-Z",        "macro",   "REZ"},
        {"X",                 "macro",   "LEVITATE_SELF"},
        {"C",                 "spell",   "Holy Nova"},
        {"CTRL-C",            "spell",   "Halo"},
        {"V",                 "spell",   "Desperate Prayer"},
        {"SHIFT-V",           "spell",   "Fade"},
        {"CTRL-SPACE",        "spell",   "Leap of Faith"},
        {"BUTTON4",           "macro",   "MOUSE4"},
        -- {"BUTTON4",           "macro",   "SANCTIFY_CURSOR"},
        -- {"SHIFT-BUTTON4",     "macro",   "FEATHER_CURSOR"},
        -- {"CTRL-BUTTON4",      "macro",   "SOOTHE_CURSOR"},
      },
      DISCIPLINE = {
      },
      HOLY = {
        {"1",                 "spell",   "Holy Word: Serenity"},
        {"SHIFT-1",           "spell",   "Renew"},
        {"SHIFT-2",           "spell",   "Heal"},
        {"5",                 "spell",   "Holy Word: Chastise"},
        {"R",                 "spell",   "Holy Fire"},
        {"CTRL-G",            "spell",   "Divine Hymn"},
        {"ALT-SHIFT-G",       "spell",   "Symbol of Hope"},
        {"ALT-CTRL-SHIFT-Z",  "spell",   "Mass Resurrection"},
        {"SHIFT-C",           "spell",   "SANCTIFY_SELF"},
        {"CTRL-V",            "macro",   "GUARD_SELF"},
      },
      SHADOW = {
      }
    },
    WARRIOR = {
      CLASS = {
        {"`",                 "spell",   ""},
        {"1",                 "spell",   ""},
        {"2",                 "spell",   ""},
        {"4",                 "spell",   "Heroic Throw"},
        {"5",                 "spell",   "Champion's Spear"},
        {"SHIFT-2",           "spell",   ""},
        {"Q",                 "spell",   "Shield Slam"},
        {"SHIFT-Q",           "spell",   "Shield Block"},
        {"CTRL-Q",            "spell",   "Shield Charge"},
        {"R",                 "spell",   ""},
        {"E",                 "spell",   "Hamstring"},
        {"E",                 "command", "MULTIACTIONBAR7BUTTON1"},
        {"R",                 "spell",   "Whirlwind"},
        {"T",                 "spell",   "Taunt"},
        {"F",                 "spell",   "Pummel"},
        {"G",                 "spell",   "Avatar"},
        {"SHIFT-F",           "spell",   "Storm Bolt"},
        {"CTRL-F",            "spell",   ""},
        {"Z",                 "spell",   "Charge"},
        {"SHIFT-Z",           "spell",   "Shield Charge"},
        {"CTRL-Z",            "spell",   "Shadowmeld"},
        {"ALT-CTRL-Z",        "spell",   "Shadowmeld"},
        {"X",                 "spell",   ""},
        {"C",                 "spell",   "Thunder Clap"},
        {"SHIFT-V",           "spell",   ""},
        {"CTRL-V",            "spell",   ""},
        {"CTRL-SPACE",        "spell",   "Heroic Leap"},
        {"BUTTON4",          "macro",    "MOUSE4" },
      },
      ARMS = {
      },
      FURY = {
      },
      PROTECTION = {

        {"V",                 "spell",   "Shield Wall"},
      }
    }
  },
  CLASSIC = {
    DRUID = {
      { "1",  "command", "ACTIONBUTTON1" },
      { "2",  "command", "ACTIONBUTTON2" },
      { "3",  "command", "ACTIONBUTTON3" },
      { "4",  "command", "ACTIONBUTTON4" },
      { "5",  "command", "ACTIONBUTTON5" },
      { "6",  "command", "ACTIONBUTTON6" },
      { "7",  "command", "ACTIONBUTTON7" },
      { "8",  "command", "ACTIONBUTTON8" },
      { "9",  "command", "ACTIONBUTTON9" },
      { "10", "command", "ACTIONBUTTON10" },
      { "11", "command", "ACTIONBUTTON11" },
      { "12", "command", "ACTIONBUTTON12" },
    },
    PALADIN = {
      { "1",  "command", "ACTIONBUTTON1" },
      { "2",  "command", "ACTIONBUTTON2" },
      { "3",  "command", "ACTIONBUTTON3" },
      { "4",  "command", "ACTIONBUTTON4" },
      { "5",  "command", "ACTIONBUTTON5" },
      { "6",  "command", "ACTIONBUTTON6" },
      { "7",  "command", "ACTIONBUTTON7" },
      { "8",  "command", "ACTIONBUTTON8" },
      { "9",  "command", "ACTIONBUTTON9" },
      { "10", "command", "ACTIONBUTTON10" },
      { "11", "command", "ACTIONBUTTON11" },
      { "12", "command", "ACTIONBUTTON12" },

      ---------------------------------------------------

      -- General
      { "E",          "macro", "!ENGAGE" }, -- Crusader Strike

      { "F9",         "command", "SHAPESHIFTBUTTON1" },
      { "F10",        "command", "SHAPESHIFTBUTTON2" },
      { "F11",        "command", "SHAPESHIFTBUTTON3" },
      { "F12",        "command", "SHAPESHIFTBUTTON4" },
      { "`",          "macro",   "!STOP" },
    { "BUTTON4",    "macro",   "MOUSE4" },
      { "BUTTON5",    "macro",   "MOUSE5" },

      -- Core
      { "Z",         "spell",   "Divine Protection" },
      { "ALT-Z",     "spell",   "Perception" },

      -- Main Attacks and Runes?
      { "4",					"spell",   "Judgement" },
      { "5",          "spell",   "Hammer of Wrath" },
      { "C",          "spell",   "Consecration" },
      { "SHIFT-C",    "spell",   "Divine Storm" },

      -- Heals (Coming from left hand?)
      { "3",      		"spell",   "Divine Storm"}, -- AoE Heal
      { "Q",					"spell",   "Holy Light"}, -- Instant Attack (Holy Shock macro @ Enemy only)
      { "ALT-Q",			"spell",   "Purify" }, -- Cleanse later
      { "CTRL-Z",     "spell",   "Redemption" },

      -- "OHSHIT" Buttons
      { "G",          "spell",   "Blessing of Protection" },
      { "SHIFT-G",    "spell",   "Lay on Hands" },

      -- CC
      { "F",          "spell",   "Rebuke"},
      { "SHIFT-F",		"spell",   "Hammer of Justice" },

      -- Blessings
      { "T",					"spell",   "Blessing of Might" },
      { "SHIFT-T",		"spell",   "Blessing of Wisdom" },

      -- Seals & Judgement
      { "R",    			"spell",   "Seal of Righteousness" },
      { "SHIFT-R",    "spell",   "Seal of the Crusader" },

      -- Items
      { "ALT-Z",       "item",    "Insignia of the Alliance" }, -- PvP Trinket
    },
    PRIEST = {
      { "1",  "command", "ACTIONBUTTON1" },
      { "2",  "command", "ACTIONBUTTON2" },
      { "3",  "command", "ACTIONBUTTON3" },
      { "4",  "command", "ACTIONBUTTON4" },
      { "5",  "command", "ACTIONBUTTON5" },
      { "6",  "command", "ACTIONBUTTON6" },
      { "7",  "command", "ACTIONBUTTON7" },
      { "8",  "command", "ACTIONBUTTON8" },
      { "9",  "command", "ACTIONBUTTON9" },
      { "10", "command", "ACTIONBUTTON10" },
      { "11", "command", "ACTIONBUTTON11" },
      { "12", "command", "ACTIONBUTTON12" },

      { "`",        "macro",   "!STOP" },
      { "1",        "spell",   "Renew" },
      { "2",        "spell",   "Lesser Heal" },
      { "4",        "spell",   "Shadow Word: Pain" },
      -- { "5",        "spell",   "Penance" },
      { "Q",        "spell",   "Power Word: Shield" },
      { "E",        "macro",   "!ENGAGE" },
      { "T",        "spell",   "Power Word: Fortitude" },
      { "Z",        "spell",   "Fade" },
      { "SHIFT-Z",  "spell",   "Shadowmeld" },
      { "CTRL-Z",   "spell",   "Fade" },
      { "V",        "macro",   "SHIELD_SELF" },
    }
  }
}