-- These are my personal configs.
-- They only load for me, so don't worry about 'em.


-- Change implicit global scope to our addon "namespace":
setfenv(1, _G.SlackHacks)

-- if not isSlackwise() then
--   -- Cancel loading the rest of the file:
--   return -- Does not impact loading subsequent files, though!
-- end

SLACKWISE_CONFIG = {
  global = {
    logPurgeEnabled = true,
  },
  profile = {
    general = {
      maximumCameraZoom = true,
    },
    minimap = {
      enabled = true,
      shape = "square",
      showAllMinimapTracking = true,
    },
  },
}

--- Set game CVars to personal preferred values.
function setSlackwiseCvars()
  if not isSlackwise() then return end

  -- Camera:
  ensureCVar("test_cameraDynamicPitch", 1) -- Equal to `/console ActionCam basic`

  -- Logging:
  ensureCVar("advancedCombatLogging", 1) -- The checkbox "Advanced Combat Logging" in settings
  ensureLogging()

  -- Nameplates:
  ensureCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", 1) -- Enable name-only nameplates for friendlies
  ensureCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", 1) -- Class-color friendly nameplates
  ensureCVar("nameplateSimplifiedScale", 0.5) -- Change scale of "Simplified" nameplates (for minor enemies)

  -- Floating Combat Text:
  ensureCVar("floatingCombatTextCombatLogPeriodicSpells", 1) -- Periodic Damage (DoTs)
  ensureCVar("floatingCombatTextPetMeleeDamage", 1)          -- Pet Melee Damage
  ensureCVar("floatingCombatTextPetSpellDamage", 1)          -- Pet Spell Damage
  local shouldBeEnabled = bool2int(not isRetail())
  ensureCVar("floatingCombatTextCombatDamage",      shouldBeEnabled)  -- Direct Damage (White/Yellow Hits)
  ensureCVar("floatingCombatTextCombatDamage_v2",   shouldBeEnabled)  -- Direct Damage (White/Yellow Hits) v2 ?
  ensureCVar("floatingCombatTextCombatHealing",     shouldBeEnabled)  -- All Healing
  ensureCVar("floatingCombatTextCombatHealing_v2",  shouldBeEnabled)  -- All Healing v2 ?
end

--- Merge personal configuration overrides from `SLACKWISE_CONFIG` into the addon DB.
function setSlackwiseOptions()
  if not isSlackwise() then return end

  -- Merge my own `SLACKWISE_CONFIG` table over the current addon config:
  local targetDB = _G.SlackHacksDB or SlackHacksDB or (db and rawget(db, "sv"))
  if targetDB and type(SLACKWISE_CONFIG) == "table" then
    if type(SLACKWISE_CONFIG.global) == "table" then
      targetDB.global = targetDB.global or {}
      recursiveMerge(targetDB.global, SLACKWISE_CONFIG.global)
    end
    if type(SLACKWISE_CONFIG.profile) == "table" and targetDB.profiles then
      local profileKey = (db and db.GetCurrentProfile and db:GetCurrentProfile()) or "Default"
      targetDB.profiles[profileKey] = targetDB.profiles[profileKey] or {}
      recursiveMerge(targetDB.profiles[profileKey], SLACKWISE_CONFIG.profile)
    end
  end

  if db and type(SLACKWISE_CONFIG) == "table" then
    if type(SLACKWISE_CONFIG.profile) == "table" and type(db.profile) == "table" then
      recursiveMerge(db.profile, SLACKWISE_CONFIG.profile)
    end
    if type(SLACKWISE_CONFIG.global) == "table" and type(db.global) == "table" then
      recursiveMerge(db.global, SLACKWISE_CONFIG.global)
    end
    if type(SLACKWISE_CONFIG.char) == "table" and type(db.char) == "table" then
      recursiveMerge(db.char, SLACKWISE_CONFIG.char)
    end
    for k, v in pairs(SLACKWISE_CONFIG) do
      if k ~= "profile" and k ~= "global" and k ~= "char" and k ~= "profiles" and k ~= "profileKeys" then
        if type(v) == "table" and type(db.profile) == "table" and (type(db.profile[k]) == "table" or (dbDefaults and dbDefaults.profile and dbDefaults.profile[k] ~= nil)) then
          if type(db.profile[k]) ~= "table" then
            db.profile[k] = {}
          end
          recursiveMerge(db.profile[k], v)
        end
      end
    end
  end

  if isInitialized() and Self.Minimap and Self.Minimap.Refresh then
    Self.Minimap:Refresh()
  end
end

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

BT = BINDING_TYPE

BINDINGS = {
  GLOBAL = {
    {"ALT-CTRL-END",         "SLACKHACKS_RELOADUI", BT.COMMAND},
    {"ALT-CTRL-`",           "FOCUSTARGET", BT.COMMAND},
    {"ALT-`",                "INTERACTTARGET", BT.COMMAND},
    {"W",                    "MOVEFORWARD", BT.COMMAND},
    {"A",                    "STRAFELEFT", BT.COMMAND},
    {"S",                    "MOVEBACKWARD", BT.COMMAND},
    {"D",                    "STRAFERIGHT", BT.COMMAND},
    {"ALT-A",                "TURNLEFT", BT.COMMAND},
    {"ALT-D",                "TURNRIGHT", BT.COMMAND},
    {"F1",                   "ACTIONBUTTON1", BT.COMMAND},
    {"F2",                   "ACTIONBUTTON2", BT.COMMAND},
    {"F3",                   "ACTIONBUTTON3", BT.COMMAND},
    {"F4",                   "ACTIONBUTTON4", BT.COMMAND},
    {"F5",                   "ACTIONBUTTON5", BT.COMMAND},
    {"F6",                   "ACTIONBUTTON6", BT.COMMAND},
    {"F7",                   "ACTIONBUTTON7", BT.COMMAND},
    {"F8",                   "ACTIONBUTTON8", BT.COMMAND},
    {"F9",                   "ACTIONBUTTON9", BT.COMMAND},
    {"F10",                  "ACTIONBUTTON10", BT.COMMAND},
    {"F11",                  "ACTIONBUTTON11", BT.COMMAND},
    {"F12",                  "ACTIONBUTTON12", BT.COMMAND},
    {"1",                    "NONE", BT.COMMAND},
    {"2",                    "NONE", BT.COMMAND},
    {"3",                    "NONE", BT.COMMAND},
    {"4",                    "NONE", BT.COMMAND},
    {"5",                    "NONE", BT.COMMAND},
    {"6",                    "NONE", BT.COMMAND},
    {"7",                    "NONE", BT.COMMAND},
    {"8",                    "NONE", BT.COMMAND},
    {"9",                    "NONE", BT.COMMAND},
    {"0",                    "NONE", BT.COMMAND},
    {"-",                    "NONE", BT.COMMAND},
    {"=",                    "NONE", BT.COMMAND},
    {"SHIFT-1",              "NONE", BT.COMMAND},
    {"SHIFT-2",              "NONE", BT.COMMAND},
    {"SHIFT-3",              "NONE", BT.COMMAND},
    {"SHIFT-4",              "NONE", BT.COMMAND},
    {"SHIFT-5",              "NONE", BT.COMMAND},
    {"SHIFT-6",              "NONE", BT.COMMAND},
    {"SHIFT-7",              "NONE", BT.COMMAND},
    {"SHIFT-8",              "NONE", BT.COMMAND},
    {"SHIFT-9",              "NONE", BT.COMMAND},
    {"SHIFT-0",              "NONE", BT.COMMAND},
    {"CTRL-1",               "NONE", BT.COMMAND},
    {"CTRL-2",               "NONE", BT.COMMAND},
    {"CTRL-3",               "NONE", BT.COMMAND},
    {"CTRL-4",               "NONE", BT.COMMAND},
    {"CTRL-5",               "NONE", BT.COMMAND},
    {"CTRL-6",               "NONE", BT.COMMAND},
    {"CTRL-7",               "NONE", BT.COMMAND},
    {"CTRL-8",               "NONE", BT.COMMAND},
    {"CTRL-9",               "NONE", BT.COMMAND},
    {"CTRL-0",               "NONE", BT.COMMAND},
    {",",                    "NONE", BT.COMMAND},
    {"ALT-CTRL-W",           "TOGGLEFOLLOW", BT.COMMAND},
    {"E",                    "INTERACTTARGET", BT.COMMAND},
    {"SHIFT-E",              "INTERACTTARGET", BT.COMMAND},
    {"CTRL-E",               "Single-Button Assistant"},
    {"ALT-E",                "EXTRAACTIONBUTTON1", BT.COMMAND},
    {"SHIFT-R",              "NONE", BT.COMMAND},
    {"CTRL-R",               "NONE", BT.COMMAND},
    {"CTRL-S",               "NONE", BT.COMMAND},
    {"ALT-CTRL-S",           "Survey"},
    {"H",                    "TOGGLEGROUPFINDER", BT.COMMAND},
    {"SHIFT-H",              "TOGGLECHARACTER4", BT.COMMAND}, -- Honor Panel (PvP Queue)
    {"CTRL-H",               "HEARTH", BT.MACRO},
    {"ALT-CTRL-H",           "HEARTH_DALARAN", BT.MACRO},
    {"ALT-H",                "TOGGLEUI", BT.COMMAND},
    {"ALT-CTRL-L",           "TOGGLEACTIONBARLOCK", BT.COMMAND},
    {"X",                    "SITORSTAND", BT.COMMAND},
    {"SHIFT-X",              "MOUNT_BEAR", BT.MACRO},
    {"CTRL-SHIFT-X",         "MOUNT_DINO", BT.MACRO},
    {"ALT-X",                "SITORSTAND", BT.COMMAND},
    {"ALT-CTRL-X",           "TOGGLERUN", BT.COMMAND},
    {"ALT-CTRL-SHIFT-X",     "Switch Flight Style"},
    {"ALT-CTRL-SHIFT-V",     "Recuperate"},
    {"ALT-CTRL-SHIFT-M",     "Switch Flight Style"},
    {"ALT-C",                "SLACKHACKS_BEST_MANA_POTION", BT.COMMAND},
    {"ALT-V",                "SLACKHACKS_BEST_HEALING_POTION", BT.COMMAND},
    {"ALT-CTRL-V",           "SLACKHACKS_BEST_BANDAGE", BT.COMMAND},
    {"V",                    "NONE", BT.COMMAND},
    {"SHIFT-V",              "NONE", BT.COMMAND},
    {"CTRL-V",               "NONE", BT.COMMAND},
    {"B",                    "INTERACTTARGET", BT.COMMAND},
    {"SHIFT-B",              "OPENALLBAGS", BT.COMMAND},
    {"CTRL-B",               "TOGGLECHARACTER0", BT.COMMAND},
    {"ALT-CTRL-B",           "SLACKHACKS_SETBINDINGS", BT.COMMAND},
    {"ALT-B",                "TOGGLESHEATH", BT.COMMAND},
    {"CTRL-M",               "TOGGLEMUSIC", BT.COMMAND},
    {"ALT-M",                "TOGGLESOUND", BT.COMMAND},
    {"ALT-CTRL-M",           "SLACKHACKS_RESTART_SOUND", BT.COMMAND},
    {"SHIFT-UP",             "NONE", BT.COMMAND},
    {"SHIFT-DOWN",           "NONE", BT.COMMAND},
    {"SHIFT-ENTER",          "REPLY", BT.COMMAND},
    {"CTRL-ENTER",           "REPLY2", BT.COMMAND},
    {"SHIFT-SPACE",          "SLACKHACKS_MOUNT", BT.COMMAND},
    {"SHIFT-HOME",           "SETVIEW1", BT.COMMAND},
    {"HOME",                 "SETVIEW2", BT.COMMAND},
    {"END",                  "SETVIEW3", BT.COMMAND},
    {"PRINTSCREEN",          "SCREENSHOT", BT.COMMAND},
    {"NUMLOCK",              "NONE", BT.COMMAND},
    {"NUMPAD0",              "RAIDTARGET8", BT.COMMAND},
    {"NUMPAD1",              "RAIDTARGET7", BT.COMMAND},
    {"NUMPAD2",              "RAIDTARGET2", BT.COMMAND},
    {"NUMPAD3",              "RAIDTARGET4", BT.COMMAND},
    {"NUMPAD4",              "RAIDTARGET6", BT.COMMAND},
    {"NUMPAD5",              "RAIDTARGET5", BT.COMMAND},
    {"NUMPAD6",              "RAIDTARGET1", BT.COMMAND},
    {"NUMPAD7",              "RAIDTARGET3", BT.COMMAND},
    {"NUMPADDECIMAL",        "RAIDTARGETNONE", BT.COMMAND},
    {"BUTTON3",              "TOGGLEAUTORUN", BT.COMMAND},
    {"ALT-BUTTON3",          "TOGGLEPINGLISTENER", BT.COMMAND},
    {"SHIFT-MOUSEWHEELUP",   "NONE", BT.COMMAND},
    {"SHIFT-MOUSEWHEELDOWN", "NONE", BT.COMMAND}
  },
  RETAIL = {
    HUNTER = {
      CLASS = {
        {"E",                "MULTIACTIONBAR7BUTTON1", BT.COMMAND},
        {"F8",               "Call Pet 1"},
        {"F9",               "Call Pet 2"},
        {"F10",              "Call Pet 3"},
        {"F11",              "Call Pet 4"},
        {"F12",              "Call Pet 5"},
        {"`",                ".", BT.MACRO},
        {"1",                "Hunter's Mark"},
        {"ALT-1",            "MD", BT.MACRO},
        {"3",                "Multi-Shot"},
        {"4",                "Arcane Shot"},
        {"Q",                "PetControl", BT.MACRO},
        {"CTRL-Q",           "BONUSACTIONBUTTON7", BT.COMMAND},        -- Pet Family Ability
        {"CTRL-SHIFT-Q",     "BONUSACTIONBUTTON1", BT.COMMAND},        -- Pet Family Ability
        {"ALT-CTRL-Q",       "PetToggle", BT.MACRO},
        {"ALT-SHIFT-Q",      "Play Dead"},
        {"ALT-CTRL-SHIFT-Q", "Eyes of the Beast"},
        {"SHIFT-F",          "Bursting Shot"},
        {"R",                "Steady Shot"},
        {"ALT-CTRL-E",       "ChainEagle", BT.MACRO},
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
        -- {"ALT-CTRL-C",    "CallFocus", BT.MACRO},
        {"CTRL-Z",           "Feign Death"},
        {"CTRL-SHIFT-Z",     "Shadowmeld", BT.MACRO},
        {"C",                "Traps", BT.MACRO},
        -- {"SHIFT-C",       ""},
        -- {"CTRL-C",        "", BT.MACRO},
        -- {"CTRL-SHIFT-C",  "Gladiator's Medallion", "ITEM"},
        {"B",                "FETCH", BT.MACRO},
        {"V",                "VITALITY", BT.MACRO},
        {"SHIFT-V",          "Survival of the Fittest"},
        {"CTRL-V",           "Aspect of the Turtle"},
        -- {"CTRL-SHIFT-V",  "Wildercloth Bandage", "ITEM"},
        -- {"ALT-V",         "Vitality", BT.MACRO},
        -- {"ALT-CTRL-V",    "SurviveFocus", BT.MACRO},
        {"CTRL-SPACE",       "Disengage"},
        {"BUTTON4",          "TrapsCursor", BT.MACRO},
        {"BUTTON5",          "PetAttackCursor", BT.MACRO},
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
        {"G",       "Trueshot!", BT.MACRO},
      },
      SURVIVAL = {
        {"1",       "Serpent Sting", BT.MACRO},
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
        {"1",  "ACTIONBUTTON1", BT.COMMAND},
        {"2",  "ACTIONBUTTON2", BT.COMMAND},
        {"3",  "ACTIONBUTTON3", BT.COMMAND},
        {"4",  "ACTIONBUTTON4", BT.COMMAND},
        {"5",  "ACTIONBUTTON5", BT.COMMAND},
        {"6",  "ACTIONBUTTON6", BT.COMMAND},
        {"7",  "ACTIONBUTTON7", BT.COMMAND},
        {"8",  "ACTIONBUTTON8", BT.COMMAND},
        {"9",  "ACTIONBUTTON9", BT.COMMAND},
        {"10", "ACTIONBUTTON10", BT.COMMAND},
        {"11", "ACTIONBUTTON11", BT.COMMAND},
        {"12", "ACTIONBUTTON12", BT.COMMAND},

        ---------------------------------------------------

        -- General
        {"F8",               "SUMMONPET", BT.MACRO},
        {"F9",               "SHAPESHIFTBUTTON1", BT.COMMAND},
        {"F10",              "SHAPESHIFTBUTTON2", BT.COMMAND},
        {"F11",              "SHAPESHIFTBUTTON3", BT.COMMAND},
        {"F12",              "SHAPESHIFTBUTTON4", BT.COMMAND},
        {"CTRL-SPACE",       "Divine Steed"},
        {"BUTTON4",          "MOUSE4", BT.MACRO},
        {"BUTTON5",          "MOUSE5", BT.MACRO},
        {"ALT-CTRL-SHIFT-X", "Contemplation"},
        {"SHIFT-G",          "TRINKETS", BT.MACRO},

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
        -- {"T", "TARGET", BT.MACRO},
        {"T",    "BLESST", BT.MACRO},

        ---------------------------------------------------

        -- CC
        {"F",         "Rebuke"},
        {"SHIFT-F",   "Hammer of Justice"},
        -- {"CTRL-F", "Repentance"},
        {"CTRL-F",    "Blinding Light"},

        -- Ultimates (Big Cooldowns)
        {"G", "WINGS", BT.MACRO},

        -- Extras
        {"Z",          "FREEDOM", BT.MACRO},
        {"SHIFT-Z",    "Will to Survive"},
        {"ALT-Z",      "PVP_TRINKET", BT.MACRO},
        {"ALT-CTRL-Z", "REZ", BT.MACRO},

        -- AoE (emanating from me)
        {"C",       "Consecration"},
        {"SHIFT-C", "Divine Toll"},
        {"CTRL-C",  "Divine Toll"},

        -- Vitality (Self-Heals/Protections)
        {"V",            "VITALITY", BT.MACRO},
        {"SHIFT-V",      "Divine Shield"},
        {"CTRL-SHIFT-V", "BOP_SELF", BT.MACRO},
        {"CTRL-V",       "LAY_SELF", BT.MACRO},
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
        {"R",          "SHOCK", BT.MACRO},
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
        {"SHIFT-C",      "BEACON_SELF", BT.MACRO},
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
        {"Q",       "Q", BT.MACRO},
        {"SHIFT-Q", "Templar's Verdict"},
        {"R",       "Blade of Justice"},

        -- Targetting

        ---------------------------------------------------

        -- Blessings
        {"CTRL-Z", "SANC_SELF", BT.MACRO},

        -- AoE (emanating from me)
        {"C", "Divine Storm"},
      },
    },
    DRUID = {
      CLASS = {
        {"BUTTON4",          "MOUSE4", BT.MACRO},
        {"SHIFT-SPACE",      "TRAVEL", BT.MACRO}, -- Travel Form, but only out of combat, otherwise Mount Form
        {"CTRL-SPACE",       "Wild Charge"},
        {"CTRL-SHIFT-SPACE", "SLACKHACKS_MOUNT", BT.COMMAND},
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
        {"E",                "SINGLE_TARGET", BT.MACRO},
        -- {"SHIFT-E",       "Shred"},
        -- {"CTRL-E",        "Mangle"},
        -- {"ALT-E",         "Wrath"},
        {"R",                "AOE", BT.MACRO},
        {"SHIFT-R",          "Swipe"},
        {"CTRL-R",           ""},
        {"ALT-R",            "Starfire"},
        {"T",                "T", BT.MACRO}, -- Taunt or Cleanse
        {"F",                "INTERRUPT", BT.MACRO},
        {"SHIFT-F",          "Entangling Roots"},
        {"CTRL-F",           "Incapacitating Roar"},
        {"ALT-CTRL-F",       "Mass Entanglement"},
        {"CTRL-G",           "ULT", BT.MACRO},
        {"Z",                "Dash"},
        {"SHIFT-Z",          "Stampeding Roar"},
        {"CTRL-Z",           "Shadowmeld"},
        {"CTRL-SHIFT-Z",     "Shadowmeld"},
        {"ALT-CTRL-Z",       "REZ", BT.MACRO},
        {"X",                "X", BT.MACRO},
        {"C",                "CAT", BT.MACRO},
        {"SHIFT-C",          "Prowl"},
        {"V",                "BEAR", BT.MACRO}, -- Switch to Bear or cast "Frenzied Regeneration"
        {"SHIFT-V",          "Barkskin"},
        {"CTRL-V",           "Renewal"},
      },
      BALANCE = {
        {"CTRL-3",  "Starfall"},
        {"5",       "Fury of Elune"},
        {"SHIFT-5", "Wild Mushroom"},
        {"X",       "X", BT.MACRO}, -- Switch to Moonkin or cast "Flap"
        {"G",       "Celestial Alignment"}, -- Also maps to Incarnation as that replaces Celestial Alignment
        {"SHIFT-G", "Celestial Alignment"},
      },
      FERAL = {
        {"E", "MULTIACTIONBAR7BUTTON1", BT.COMMAND},
      },
      GUARDIAN = {
      },
      RESTORATION = {
        {"E",                "MULTIACTIONBAR7BUTTON1", BT.COMMAND},
        {"`",                "Swiftmend"},
        {"SHIFT-1",          "Lifebloom"},
        {"G",                "Convoke the Spirits"},
        {"SHIFT-G",          "Tranquility"},
        {"ALT-CTRL-SHIFT-Z", "Revitalize"},
      }
    },
    MAGE = {
      CLASS = {
        {"Q",            "MULTIACTIONBAR7BUTTON1", BT.COMMAND},
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
        {"BUTTON4", "BLIZZ_CURSOR", BT.MACRO},
        {"4",       "Ice Lance"},
        {"2",       "Ray of Frost"},
        {"3",       "Frozen Orb"},
        {"5",       "Flurry"},
        {"V",       "Ice Barrier"},
        {"CTRL-C",  "BLIZZ_SELF", BT.MACRO},
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
        {"Q",            "CHAIN", BT.MACRO},
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
        {"SHIFT-C",      "RAIN_SELF", BT.MACRO},
        {"V",            "Astral Shift"},
        {"CTRL-C",       "Stone Bulwark Totem"},
        {"CTRL-SPACE",   "Gust of Wind"},
        {"ALT-CTRL-Z",   "Ancestral Spirit"},
      },
      ELEMENTAL = {
        {"BUTTON4", "MOUSE4_ELE", BT.MACRO},
      },
      ENHANCEMENT = {},
      RESTORATION = {
        {"BUTTON4",          "MOUSE4_RESTO", BT.MACRO},
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
        {"F",                "SOOTHE_SELF", BT.MACRO},
        {"SHIFT-F",          "Psychic Scream"},
        {"CTRL-F",           "Dominate Mind"},
        {"ALT-CTRL-F",       "Mind Vision"},
        {"G",                "ULT", BT.MACRO},
        {"SHIFT-G",          "PI_SELF", BT.MACRO},
        {"Z",                "FEATHER_SELF", BT.MACRO},
        {"SHIFT-Z",          "Fade"},
        {"CTRL-Z",           "Shadowmeld"},
        {"CTRL-SHIFT-Z",     "Shadowmeld"},
        {"ALT-CTRL-Z",       "REZ", BT.MACRO},
        {"X",                "LEVITATE_SELF", BT.MACRO},
        {"C",                "Holy Nova"},
        {"CTRL-C",           "Halo"},
        {"V",                "Desperate Prayer"},
        {"SHIFT-V",          "Fade"},
        {"CTRL-SPACE",       "Leap of Faith"},
        {"BUTTON4",          "MOUSE4", BT.MACRO},
        -- {"BUTTON4",       "SANCTIFY_CURSOR", BT.MACRO},
        -- {"SHIFT-BUTTON4", "FEATHER_CURSOR", BT.MACRO},
        -- {"CTRL-BUTTON4",  "SOOTHE_CURSOR", BT.MACRO},
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
        {"CTRL-V",           "GUARD_SELF", BT.MACRO},
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
        {"E",            "MULTIACTIONBAR7BUTTON1", BT.COMMAND},
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
        {"BUTTON4",      "MOUSE4", BT.MACRO},
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
        {"F8",         "SUMMONPET", BT.MACRO},
        {"CTRL-SPACE", "Hover"},
        {"BUTTON4",    "MOUSE4", BT.MACRO},
        {"BUTTON5",    "MOUSE5", BT.MACRO},
        {"SHIFT-G",    "TRINKETS", BT.MACRO},

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
        -- {"T", "TARGET", BT.MACRO},
        {"T",    "BLESST", BT.MACRO},

        ---------------------------------------------------

        -- CC
        {"F",         "Rebuke"},
        {"SHIFT-F",   "Hammer of Justice"},
        -- {"CTRL-F", "Repentance"},
        {"CTRL-F",    "Blinding Light"},

        -- Ultimates (Big Cooldowns)
        {"G", "WINGS", BT.MACRO},

        -- Extras
        {"Z",          "FREEDOM", BT.MACRO},
        {"SHIFT-Z",    "Will to Survive"},
        {"ALT-Z",      "PVP_TRINKET", BT.MACRO},
        {"ALT-CTRL-Z", "REZ", BT.MACRO},

        -- AoE (emanating from me)
        {"C",       "Consecration"},
        {"SHIFT-C", "Divine Toll"},
        {"CTRL-C",  "Divine Toll"},

        -- Vitality (Self-Heals/Protections)
        {"V",            "VITALITY", BT.MACRO},
        {"SHIFT-V",      "Divine Shield"},
        {"CTRL-SHIFT-V", "BOP_SELF", BT.MACRO},
        {"CTRL-V",       "LAY_SELF", BT.MACRO},
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
        {"BUTTON4",    "MOUSE4", BT.MACRO},
        {"CTRL-SPACE", "Spatial Rift"},
        {"Q",          "PetControl", BT.MACRO},
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
  FOREVER = {
    DRUID = {
      {"1",             "Rejuvenation"},
      {"SHIFT-1",       "Healing Touch"},
      {"2",             "Wrath"},
      {"4",             "Moonfire"},
      {"T",             "Growl"},
      {"SHIFT-E",       "Maul"},
      {"SHIFT-T",       "Demoralizing Roar"},
      {"F",             "Entangling Roots"},
      {"V",             {"BEAR", "Ability_Racial_BearForm", "/cast [form:1] Frenzied Regeneration; Bear Form"}},
      {"B",             {"NOFORM", "Classicon_druid", "/cancelform"}},
      {"CTRL-F",        "Nature's Grasp"},
      {"ALT-CTRL-Z",    "Shadowmeld"},
      {"CTRL-G",        "Elune's Light"},
      {"CTRL-H",        "Teleport: Moonglade"},
    },
    PALADIN = {
      -- General
      {"E", { "!ENGAGE",
              "classicon_paladin",
              multilineTrim([[
              #showtooltip Holy Strike
              /startattack
              /cast Holy Strike
            ]])} },
      {"F9",      "SHAPESHIFTBUTTON1", BT.COMMAND},
      {"F10",     "SHAPESHIFTBUTTON2", BT.COMMAND},
      {"F11",     "SHAPESHIFTBUTTON3", BT.COMMAND},
      {"F12",     "SHAPESHIFTBUTTON4", BT.COMMAND},
      {"`",       "!STOP", BT.MACRO},
      {"BUTTON4", "MOUSE4", BT.MACRO},
      {"BUTTON5", "MOUSE5", BT.MACRO},

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
      {"1",  "ACTIONBUTTON1", BT.COMMAND},
      {"2",  "ACTIONBUTTON2", BT.COMMAND},
      {"3",  "ACTIONBUTTON3", BT.COMMAND},
      {"4",  "ACTIONBUTTON4", BT.COMMAND},
      {"5",  "ACTIONBUTTON5", BT.COMMAND},
      {"6",  "ACTIONBUTTON6", BT.COMMAND},
      {"7",  "ACTIONBUTTON7", BT.COMMAND},
      {"8",  "ACTIONBUTTON8", BT.COMMAND},
      {"9",  "ACTIONBUTTON9", BT.COMMAND},
      {"10", "ACTIONBUTTON10", BT.COMMAND},
      {"12", "ACTIONBUTTON12", BT.COMMAND},
      {"11", "ACTIONBUTTON11", BT.COMMAND},

      {"`",            "!STOP", BT.MACRO},
      {"1",            "Renew"},
      {"2",            "Lesser Heal"},
      {"4",            "Shadow Word: Pain"},
      -- {"5",         "Penance"},
      {"Q",            "Power Word: Shield"},
      {"E",            "!ENGAGE", BT.MACRO},
      {"T",            "Power Word: Fortitude"},
      {"Z",            "Fade"},
      {"CTRL-Z",       "Fade"},
      {"SHIFT-Z",      "Shadowmeld"},
      {"CTRL-SHIFT-Z", "Shadowmeld"},
      {"V",            "SHIELD_SELF", BT.MACRO},
    }
  },
  CLASSIC = {
    DRUID = {
      {"1",  "ACTIONBUTTON1", BT.COMMAND},
      {"2",  "ACTIONBUTTON2", BT.COMMAND},
      {"3",  "ACTIONBUTTON3", BT.COMMAND},
      {"4",  "ACTIONBUTTON4", BT.COMMAND},
      {"5",  "ACTIONBUTTON5", BT.COMMAND},
      {"6",  "ACTIONBUTTON6", BT.COMMAND},
      {"7",  "ACTIONBUTTON7", BT.COMMAND},
      {"8",  "ACTIONBUTTON8", BT.COMMAND},
      {"9",  "ACTIONBUTTON9", BT.COMMAND},
      {"10", "ACTIONBUTTON10", BT.COMMAND},
      {"11", "ACTIONBUTTON11", BT.COMMAND},
      {"12", "ACTIONBUTTON12", BT.COMMAND},
    },
    PALADIN = {
      {"1",  "ACTIONBUTTON1", BT.COMMAND},
      {"2",  "ACTIONBUTTON2", BT.COMMAND},
      {"3",  "ACTIONBUTTON3", BT.COMMAND},
      {"4",  "ACTIONBUTTON4", BT.COMMAND},
      {"5",  "ACTIONBUTTON5", BT.COMMAND},
      {"6",  "ACTIONBUTTON6", BT.COMMAND},
      {"7",  "ACTIONBUTTON7", BT.COMMAND},
      {"8",  "ACTIONBUTTON8", BT.COMMAND},
      {"9",  "ACTIONBUTTON9", BT.COMMAND},
      {"10", "ACTIONBUTTON10", BT.COMMAND},
      {"11", "ACTIONBUTTON11", BT.COMMAND},
      {"12", "ACTIONBUTTON12", BT.COMMAND},

      ---------------------------------------------------

      -- General
      {"E", "!ENGAGE", BT.MACRO}, -- Crusader Strike

      {"F9",      "SHAPESHIFTBUTTON1", BT.COMMAND},
      {"F10",     "SHAPESHIFTBUTTON2", BT.COMMAND},
      {"F11",     "SHAPESHIFTBUTTON3", BT.COMMAND},
      {"F12",     "SHAPESHIFTBUTTON4", BT.COMMAND},
      {"`",       "!STOP", BT.MACRO},
      {"BUTTON4", "MOUSE4", BT.MACRO},
      {"BUTTON5", "MOUSE5", BT.MACRO},

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
      {"1",  "ACTIONBUTTON1", BT.COMMAND},
      {"2",  "ACTIONBUTTON2", BT.COMMAND},
      {"3",  "ACTIONBUTTON3", BT.COMMAND},
      {"4",  "ACTIONBUTTON4", BT.COMMAND},
      {"5",  "ACTIONBUTTON5", BT.COMMAND},
      {"6",  "ACTIONBUTTON6", BT.COMMAND},
      {"7",  "ACTIONBUTTON7", BT.COMMAND},
      {"8",  "ACTIONBUTTON8", BT.COMMAND},
      {"9",  "ACTIONBUTTON9", BT.COMMAND},
      {"10", "ACTIONBUTTON10", BT.COMMAND},
      {"12", "ACTIONBUTTON12", BT.COMMAND},
      {"11", "ACTIONBUTTON11", BT.COMMAND},

      {"`",            "!STOP", BT.MACRO},
      {"1",            "Renew"},
      {"2",            "Lesser Heal"},
      {"4",            "Shadow Word: Pain"},
      -- {"5",         "Penance"},
      {"Q",            "Power Word: Shield"},
      {"E",            "!ENGAGE", BT.MACRO},
      {"T",            "Power Word: Fortitude"},
      {"Z",            "Fade"},
      {"CTRL-Z",       "Fade"},
      {"SHIFT-Z",      "Shadowmeld"},
      {"CTRL-SHIFT-Z", "Shadowmeld"},
      {"V",            "SHIELD_SELF", BT.MACRO},
    }
  }
}