-- Bindings have to be in global scope,
-- so we need them to be set before `setfenv()` changes scope!
BINDING_HEADER_SLACKUI = "SlackUI"
BINDING_NAME_SLACKUI_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKUI_RELOADUI = "Reload UI"
BINDING_NAME_SLACKUI_MOUNT = "Mount"
BINDING_NAME_SLACKUI_SETBINDINGS = "Load Keybindings"
BINDING_HEADER_SLACKUI = "SlackUI"
BINDING_NAME_SLACKUI_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKUI_RELOADUI = "Reload UI"
BINDING_NAME_SLACKUI_MOUNT = "Mount"
BINDING_NAME_SLACKUI_SETBINDINGS = "Load Keybindings"
BINDING_NAME_SLACKUI_BEST_HEALING_POTION = "Use Best Healing Potion"
BINDING_NAME_SLACKUI_BEST_MANA_POTION = "Use Best Mana Potion"
BINDING_NAME_SLACKUI_BEST_BANDAGE = "Use Best Bandage"


-- Change implicit globla scope to our addon "namespace":
setfenv(1, _G.SlackUI)


BINDING_TYPE = {
  DEFAULT_BINDINGS   = 0,
  ACCOUNT_BINDINGS   = 1,
  CHARACTER_BINDINGS = 2
}


BINDINGS_FUNCTIONS = {
  ["command"] = SetBinding,
  ["spell"]   = SetBindingSpell,
  ["macro"]   = SetBindingMacro,
  ["item"]    = SetBindingItem
}

function setBinding(binding)
  local key, type, name = unpack(binding)
  BINDINGS_FUNCTIONS[type](key, name)
end

--- Get UI text description for a `Bindings.xml` binding name.
---@params bindingName string - The name as seen in `Bindings.xml`.
---@return string - The UI description as string.
function getBindingDescription(bindingName)
  return _G['BINDING_NAME_' .. bindingName] or ""
end

function unbindUnwantedDefaults()
  SetBinding("SHIFT-T")
end

function bindBestUseItems()
  -- if not isTester() then return end
  ClearOverrideBindings(Self.itemBindingFrame)

  for itemType, itemMap in pairs(BEST_ITEMS) do
    log("Binding " .. getBindingDescription(itemMap.BINDING_NAME) .. "...")
    bindBestUseItem(itemMap)
  end
end

function bindBestUseItem(bestItemMap)
  -- Find all matching items in bags:
  local containerItemInfos = findItemsByItemIDs(keys(bestItemMap))
  if isDebugging() and containerItemInfos then
    log(getBindingDescription(bestItemMap.BINDING_NAME) .. ": found items:")
    for i, item in ipairs(containerItemInfos) do
      log("    " .. item.stackCount .. "x of " .. item.itemID .. " " .. item.hyperlink)
    end
  end

  -- Group items by strength so that the keys are their strength,
  -- and the values are an array of itemIDs and stack counts:
  local itemsByBestStrength = groupBy(containerItemInfos,
    function(item)
      return bestItemMap[item.itemID], { item.itemID, item.stackCount }
    end
  )
  -- `itemsByBestStrength` is now a map of strength to an array of items with identical strength.

  -- Now that the keys/indexes are strengths, find the largest index, which is the strongest:
  local bestItems = itemsByBestStrength[findLargestIndex(itemsByBestStrength)]
  -- `bestItems` contains an array of items which are an array of (itemID, stackCount)

  -- Find the smallest stack so we use them up first to free up bag space;
  if bestItems then
    local smallestStack = 9999 -- Start with the largest stack possible as we're wittling down, and nothing stacks past 2000 as far as I know, and the most was arrows?
    local bestItemID = nil
    for i, itemStack in ipairs(bestItems) do
      local itemID, stackCount = unpack(itemStack)
      if stackCount < smallestStack then
        smallestStack = stackCount
        bestItemID = itemID
      end
    end
    log("Best found smallest stack itemID: " .. bestItemID)

    -- Bind the item directly:
    if bestItemID then
      local desiredBindingKeys = { GetBindingKey(bestItemMap.BINDING_NAME) }
      if #desiredBindingKeys > 0 then
        for i, key in ipairs(desiredBindingKeys) do
          log("Binding ID " .. bestItemID .. " " .. C_Item.GetItemNameByID(bestItemID) .. " to " .. key)
          SetOverrideBindingItem(Self.itemBindingFrame, true, key, "item:" .. bestItemID)
        end
      end
    end
  end
end

function setBindings()
  if not isTester() then
    print("SlackUI Bindings: Work in progress. Cannot bind currently.")
    return
  end

  LoadBindings(BINDING_TYPE.DEFAULT_BINDINGS)
  unbindUnwantedDefaults()

  -- Global bindings:
  for _, binding in ipairs(BINDINGS.GLOBAL) do
    setBinding(binding)
  end

  -- Class specific bindings:
  local game = getGameType()
  local class = getClassName()
  local bindings = BINDINGS[game][class]

  if isRetail() then
    local spec = getSpecName()
    if not spec then
      print("SlackUI Binding: No spec currently to bind!")
    end

    if bindings.CLASS ~= nil then
      if bindings.CLASS.PRE_SCRIPT then
        bindings.CLASS.PRE_SCRIPT()	
      end
      for _, binding in ipairs(bindings.CLASS) do
        local key, type, name = unpack(binding)
        if not (type == "spell" and not C_Spell.DoesSpellExist(name)) then
          setBinding(binding)
        end
      end
      if bindings.CLASS.POST_SCRIPT then
        bindings.CLASS.POST_SCRIPT()	
      end
    end

    if spec and spec ~= "" then
      if bindings[spec].PRE_SCRIPT then
        bindings[spec].PRE_SCRIPT()	
      end
      local specBindings = bindings[spec]
      if specBindings ~= nil then
        for _, binding in ipairs(specBindings) do
          if not (binding[2] == "spell" and not C_Spell.DoesSpellExist(binding[3])) then
            setBinding(binding)
          end
        end
      end
      if bindings[spec].POST_SCRIPT then
        bindings[spec].POST_SCRIPT()	
      end
    end

    SaveBindings(BINDING_TYPE.CHARACTER_BINDINGS)
    print((spec or "CLASS-ONLY") .. " " .. class .. " binding presets loaded!")
  elseif isClassic() then
    if bindings.PRE_SCRIPT then
      bindings.PRE_SCRIPT()	
    end

    for _, binding in ipairs(bindings) do
      local key, type, name = unpack(binding)
      if not (type == "spell" and not C_Spell.DoesSpellExist(name)) then
        setBinding(binding)
      end
    end

    if bindings.POST_SCRIPT then
      bindings.POST_SCRIPT()	
    end

    SaveBindings(BINDING_TYPE.CHARACTER_BINDINGS)
    print(class .. " binding presets loaded!")
  else -- There are other game types like TBC and WOTLK classic, and who knows what else in the future...
    print("Unknown game type! Cannot rebind.")
  end
end

BINDINGS = {
  GLOBAL = {
    {"ALT-CTRL-END",          "command",  "SLACKUI_RELOADUI"},
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
    {"E",                     "macro",    "!ENGAGE"},
    {"SHIFT-E",               "macro",    "!ASSIST"},
    {"CTRL-E",                "command",  "EXTRAACTIONBUTTON1"},
    {"SHIFT-R",               "command",  "NONE"},
    {"CTRL-R",                "command",  "NONE"},
    {"CTRL-S",                "command",  "NONE"},
    {"CTRL-G",                "item",     "Net-O-Matic 5000"},
    {"CTRL-H",                "macro",    "HEARTH"},
    {"ALT-H",                 "command",  "TOGGLEUI"},
    {"CTRL-L",                "command",  "TOGGLEACTIONBARLOCK"},
    {"CTRL-B",                "command",  "TOGGLECHARACTER0"},
    {"ALT-CTRL-B",            "command",  "SLACKUI_SETBINDINGS"},
    {"X",                     "command",  "SITORSTAND"},
    {"SHIFT-X",               "macro",    "MountPassenger"},
    {"CTRL-SHIFT-X",          "macro",    "MountYak"},
    {"ALT-X",                 "command",  "SITORSTAND"},
    {"ALT-CTRL-X",            "command",  "TOGGLERUN"},
    {"ALT-C",                 "command",  "SLACKUI_BEST_MANA_POTION" },
    {"ALT-V",                 "command",  "SLACKUI_BEST_HEALING_POTION" },
    {"ALT-CTRL-V",            "command",  "SLACKUI_BEST_BANDAGE" },
    {"V",                     "command",  "NONE"},
    {"SHIFT-V",               "command",  "NONE"},
    {"CTRL-V",                "command",  "NONE"},
    {"B",                     "command",  "TOGGLEBACKPACK"},
    {"SHIFT-B",               "command",  "OPENALLBAGS"},
    {"ALT-B",                 "command",  "TOGGLESHEATH"},
    {"CTRL-M",                "command",  "TOGGLEMUSIC"},
    {"ALT-M",                 "command",  "TOGGLESOUND"},
    {"ALT-CTRL-M",            "command",  "SLACKUI_RESTART_SOUND"},
    {"SHIFT-UP",              "command",  "NONE"},
    {"SHIFT-DOWN",            "command",  "NONE"},
    {"SHIFT-ENTER",           "command",  "REPLY"},
    {"CTRL-ENTER",            "command",  "REPLY2"},
    {"SHIFT-SPACE",           "command",  "SLACKUI_MOUNT"},
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
    {"SHIFT-MOUSEWHEELUP",    "command",  "NONE"},
    {"SHIFT-MOUSEWHEELDOWN",  "command",  "NONE"}
  },
  RETAIL = {
    HUNTER = {
      MARKSMANSHIP = {
        { "F8",               "spell",   "Call Pet 1" },
        { "F9",               "spell",   "Call Pet 2" },
        { "F10",              "spell",   "Call Pet 3" },
        { "F11",              "spell",   "Call Pet 4" },
        { "F12",              "spell",   "Call Pet 5" },
        { "`",                "macro",   "*" },
        { "1",                "macro",   "Serpent Sting" },
        { "2",                "spell",   "Volley" },
        { "SHIFT-2",          "spell",   "Wild Spirits" },
        { "ALT-1",            "macro",   "MD" },
        { "CTRL-1",           "spell",   "Hunter's Mark" },
        { "3",                "spell",   "Multi-Shot" },
        { "SHIFT-3",          "spell",   "Barrage" },
        { "4",                "spell",   "Arcane Shot" },
        { "SHIFT-4",          "spell",   "Aimed Shot" },
        { "CTRL-4",           "spell",   "Double Tap" },
        { "5",                "spell",   "Kill Shot" },
        { "SHIFT-5",          "spell",   "Sniper Shot" },
        { "Q",                "macro",   "PetControl" },
        { "CTRL-Q",           "command", "BONUSACTIONBUTTON7" },        -- Pet Family Ability
        { "CTRL-SHIFT-Q",     "command", "BONUSACTIONBUTTON1" },        -- Pet Family Ability
        { "ALT-CTRL-Q",       "macro",   "PetToggle" },
        { "ALT-SHIFT-Q",      "spell",   "Play Dead" },
        { "ALT-CTRL-SHIFT-Q", "spell",   "Eyes of the Beast" },
        { "CTRL-E",           "spell",   "Bursting Shot" },
        { "ALT-CTRL-E",       "macro",   "ChainEagle" },
        { "R",                "spell",   "Steady Shot" },
        { "SHIFT-R",          "spell",   "Rapid Fire" },
        { "CTRL-R",           "macro",   "Trueshot!" },
        { "ALT-R",            "item",    "Potion of Phantom Fire" },
        { "T",                "macro",   "Traps" },
        { "ALT-CTRL-S",       "spell",   "Survey" },
        { "F",                "spell",   "Wing Clip" },        --Auto-maps to "Concussive Shot" in MM spec
        { "SHIFT-F",          "spell",   "Scatter Shot" },
        { "CTRL-F",           "spell",   "Counter Shot" },
        { "ALT-F",            "spell",   "Tranquilizing Shot" },
        { "ALT-CTRL-F",       "spell",   "Scare Beast" },
        { "ALT-CTRL-SHIFT-F", "spell",   "Fireworks" },
        { "G",                "spell",   "Wild Spirits" },
        { "Z",                "spell",   "Camouflage" },
        { "SHIFT-Z",          "spell",   "Aspect of the Chameleon" },
        { "CTRL-Z",           "spell",   "Feign Death" },
        { "CTRL-SHIFT-Z",     "macro",   "Shadowmeld" },
        { "ALT-Z",            "item",    "Potion of the Hidden Spirit" },
        { "C",                "spell",   "Soulshape" },
        { "SHIFT-C",          "spell",   "Aspect of the Cheetah" },
        { "CTRL-C",           "macro",   "Call" },
        { "CTRL-SHIFT-C",     "item",    "Gladiator's Medallion" },
        { "ALT-C",            "item",    "Potion of the Psychopomp's Speed" },
        { "ALT-CTRL-C",       "macro",   "CallFocus" },
        { "V",                "spell",   "Exhilaration" },
        { "SHIFT-V",          "spell",   "Survival of the Fittest" },
        { "CTRL-V",           "spell",   "Aspect of the Turtle" },
        { "CTRL-SHIFT-V",     "item",    "Wildercloth Bandage" },
        { "ALT-V",            "macro",   "Vitality" },
        { "ALT-CTRL-V",       "macro",   "SurviveFocus" },
        { "B",                "spell",   "Fetch" },
        { "CTRL-SPACE",       "spell",   "Disengage" },
        { "BUTTON4",          "macro",   "MouseTraps" },
        { "BUTTON5",          "macro",   "MousePetAttack" },
      },
      SURVIVAL = {
        { "F8",               "spell",   "Call Pet 1" },
        { "F9",               "spell",   "Call Pet 2" },
        { "F10",              "spell",   "Call Pet 3" },
        { "F11",              "spell",   "Call Pet 4" },
        { "F12",              "spell",   "Call Pet 5" },
        { "`",                "macro",   "*" },
        { "1",                "macro",   "Serpent Sting" },
        { "2",                "spell",   "Kill Command" },
        { "SHIFT-2",          "spell",   "Wild Spirits" },
        { "ALT-1",            "macro",   "MD" },
        { "CTRL-1",           "spell",   "Hunter's Mark" },
        { "3",                "spell",   "Multi-Shot" },
        { "SHIFT-3",          "spell",   "Barrage" },
        { "4",                "spell",   "Shrapnel Bomb" },
        { "SHIFT-4",          "spell",   "Aimed Shot" },
        { "CTRL-4",           "spell",   "Double Tap" },
        { "5",                "spell",   "Kill Shot" },
        { "SHIFT-5",          "spell",   "Sniper Shot" },
        { "Q",                "macro",   "PetControl" },
        { "CTRL-Q",           "command", "BONUSACTIONBUTTON7" },        -- Pet Family Ability
        { "CTRL-SHIFT-Q",     "command", "BONUSACTIONBUTTON1" },        -- Pet Family Ability
        { "ALT-CTRL-Q",       "macro",   "PetToggle" },
        { "ALT-SHIFT-Q",      "spell",   "Play Dead" },
        { "ALT-CTRL-SHIFT-Q", "spell",   "Eyes of the Beast" },
        { "E",                "spell",   "Raptor Strike" },
        { "SHIFT-E",          "spell",   "Butchery" },
        { "ALT-CTRL-E",       "macro",   "ChainEagle" },
        { "R",                "spell",   "Harpoon" },
        { "SHIFT-R",          "spell",   "Rapid Fire" },
        { "CTRL-R",           "macro",   "Trueshot!" },
        { "ALT-R",            "item",    "Potion of Phantom Fire" },
        { "T",                "macro",   "Traps" },
        { "ALT-CTRL-S",       "spell",   "Survey" },
        { "F",                "spell",   "Wing Clip" },        --Auto-maps to "Concussive Shot" in MM spec
        { "SHIFT-F",          "spell",   "Scatter Shot" },
        { "CTRL-F",           "spell",   "Counter Shot" },
        { "ALT-F",            "spell",   "Tranquilizing Shot" },
        { "ALT-CTRL-F",       "spell",   "Scare Beast" },
        { "ALT-CTRL-SHIFT-F", "spell",   "Fireworks" },
        { "G",                "spell",   "Wild Spirits" },
        { "Z",                "spell",   "Camouflage" },
        { "SHIFT-Z",          "spell",   "Aspect of the Chameleon" },
        { "CTRL-Z",           "spell",   "Feign Death" },
        { "CTRL-SHIFT-Z",     "macro",   "Shadowmeld" },
        { "ALT-Z",            "item",    "Potion of the Hidden Spirit" },
        { "C",                "spell",   "Soulshape" },
        { "SHIFT-C",          "spell",   "Aspect of the Cheetah" },
        { "CTRL-C",           "macro",   "Call" },
        { "CTRL-SHIFT-C",     "item",    "Gladiator's Medallion" },
        { "ALT-C",            "item",    "Potion of the Psychopomp's Speed" },
        { "ALT-CTRL-C",       "macro",   "CallFocus" },
        { "V",                "spell",   "Exhilaration" },
        { "SHIFT-V",          "spell",   "Survival of the Fittest" },
        { "CTRL-V",           "spell",   "Aspect of the Turtle" },
        { "CTRL-SHIFT-V",     "item",    "Wildercloth Bandage" },
        { "ALT-V",            "macro",   "Vitality" },
        { "ALT-CTRL-V",       "macro",   "SurviveFocus" },
        { "B",                "spell",   "Fetch" },
        { "CTRL-SPACE",       "spell",   "Disengage" },
        { "BUTTON4",          "macro",   "MouseTraps" },
        { "BUTTON5",          "macro",   "MousePetAttack" },
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
        { "F9",         "command", "SHAPESHIFTBUTTON1" },
        { "F10",        "command", "SHAPESHIFTBUTTON2" },
        { "F11",        "command", "SHAPESHIFTBUTTON3" },
        { "F12",        "command", "SHAPESHIFTBUTTON4" },
        { "CTRL-SPACE", "spell",   "Divine Steed" },
        { "`",          "macro",   "STOP!" },
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
        { "5",          "spell",   "Hammer of Wrath" },
        { "SHIFT-5",    "macro",   "WINGS" },

        ---------------------------------------------------

        -- Shield (Tanking)
        { "Q",          "spell",   "Shield of the Righteous" },
        { "ALT-Q",      "spell",   "Hand of Reckoning" },

        -- Sword
        { "E",          "macro",   "ENGAGE" },

        -- Targetting
        { "T",          "macro",   "TARGET" },

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
        { "CTRL-Z",     "macro",   "REZ" },
        { "ALT-Z",      "macro",   "PVP_TRINKET" },
        { "ALT-CTRL-Z", "macro",   "REZ" },

        -- AoE (emanating from me)
        { "C",          "spell",   "Consecration" },
        { "CTRL-C",     "macro",   "BELL_SELF" },
        -- { "ALT-C",      "spell",   "Aerated Mana Potion" },

        -- Vitality (Self-Heals/Protections)
        { "V",          "macro",   "VITALITY" },
        { "SHIFT-V",    "spell",   "Divine Shield" },
        { "CTRL-V",     "macro",   "LAY_ON_SELF" },
        -- { "ALT-V",      "spell",   "Refreshing Healing Potion" },
        -- { "ALT-CTRL-V", "spell",   "Wildercloth Bandage" },
      },
      HOLY = {
        -- Quick Heals
        { "SHIFT-1",    "spell",   "Cleanse" },

        -- Cast Heals
        { "2",          "spell",   "Holy Light" },
        { "SHIFT-2",    "spell",   "Flash of Light" },
        { "CTRL-2",     "spell",   "Divine Favor" },

        -- AoE Heals
        { "3",          "spell",   "Light of Dawn" },
        { "SHIFT-3",    "macro",   "LHAMMER_TARGET" },

        ---------------------------------------------------

        -- Spec Abilities
        { "R",          "macro",   "SHOCK" },

        -- Targetting
        { "SHIFT-T",    "spell",   "Beacon of Faith" },
        { "CTRL-T",     "spell",   "Beacon of Light" },

        ---------------------------------------------------

        -- Ults (Big Cooldowns)
        { "SHIFT-G",    "spell",   "Daybreak" },
        { "CTRL-G",     "spell",   "Tyr's Deliverance" },
        { "ALT-G",      "spell",   "Aura Mastery" },

        -- Extras
        { "ALT-CTRL-SHIFT-Z", "spell",   "Absolution" },

        -- AoE (emanating from me)
        { "C",          "spell",   "Consecration" },
        { "SHIFT-C",    "macro",   "LHAMMER_SELF" },
      },
      PROTECTION = {
        -- Quick Heals
        { "SHIFT-1",    "spell",   "Cleanse Toxins" },

        ---------------------------------------------------

        -- Shield
        { "SHIFT-Q",    "spell",   "Bastion of Light" },

        -- Attacks
        { "R",          "spell",   "Avenger's Shield" },

        -- Taunting
        { "T",          "spell",   "Hand of Reckoning" },

        ---------------------------------------------------

        -- Blessings

        -- AoE (emanating from me)
        { "SHIFT-C",    "spell",   "Eye of Tyr" },
      },
      RETRIBUTION = {
        -- Heals
        { "SHIFT-1",    "spell",   "Cleanse Toxins" },

        -- AoE
        { "3",          "spell",   "Wake of Ashes" },
        { "BUTTON4",    "macro",   "RECKON_CURSOR" },

        ---------------------------------------------------

        -- Sword
        { "Q",          "macro",   "Q" },
        { "SHIFT-Q",    "spell",   "Templar's Verdict" },
        { "R",          "spell",   "Blade of Justice" },

        -- Targetting

        ---------------------------------------------------

        -- Blessings

        -- AoE (emanating from me)
        { "C",         "spell",   "Divine Storm" },
        { "SHIFT-C",   "macro",   "RECKON_SELF" }, -- Can't cast BELL_SELF on self as Ret
        { "CTRL-C",    "spell",   "Shield of Vengeance" },
      },
    },
    DRUID = {
      CLASS = {
        {"BUTTON4",               "macro",   "MOUSE4"},
        {"SHIFT-SPACE",           "macro",   "TRAVEL"}, -- Travel Form, but only out of combat, otherwise Mount Form
        {"CTRL-SPACE",            "spell",   "Wild Charge"},
        {"CTRL-SHIFT-SPACE",      "command", "SLACKUI_MOUNT"},
        {"SHIFT-H",               "spell",   "Dreamwalk"},
        {"1",                     "spell",   "Rejuvenation"},
        {"1",                     "spell",   "Rejuvenation"},
        {"SHIFT-1",               "spell",   "Rejuvenation"},
        {"2",                     "spell",   "Regrowth"},
        {"SHIFT-2",               "spell",   "Wild Growth"},
        {"3",                     "spell",   "Sunfire"},
        {"4",                     "spell",   "Moonfire"},
        {"SHIFT-4",               "spell",   "Starsurge"},
        {"Q",                     "spell",   "Ferocious Bite"},
        {"E",                     "macro",   "SINGLE_TARGET"},
        {"SHIFT-E",               "spell",   "Shred"},
        {"CTRL-E",                "spell",   "Mangle"},
        {"ALT-E",                 "spell",   "Wrath"},
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
        {"SHIFT-Z",               "spell",   "Stampeding Road"},
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
        {"SHIFT-3",               "spell",   "Starfall"},
        {"5",                     "spell",   "Fury of Elune"},
        {"SHIFT-5",               "spell",   "Wild Mushroom"},
        {"X",                     "macro",   "X"}, -- Switch to Moonkin or cast "Flap"
        {"G",                     "spell",   "Celestial Alignment"}, -- Also maps to Incarnation as that replaces Celestial Alignment
        {"SHIFT-G",               "spell",   "Celestial Alignment"},
      },
      FERAL = {
      },
      GUARDIAN = {
      },
      RESTORATION = {
        {"`",                     "spell",   "Swiftmend"},
        {"SHIFT-1",               "spell",   "Lifebloom"},
        {"G",                     "spell",   "Grove Guardians"},
        {"SHIFT-G",               "spell",   "Incarnation: Tree of Life"},
        {"ALT-CTRL-V",            "spell",   "Tranquility"},
      }
    },
    MAGE = {
      CLASS = {
        {"4",                 "spell",   "Ice Lance"},
        {"E",                 "command", "INTERACTTARGET"},
        {"R",                 "spell",   "Frostbolt"},
        {"T",                 "spell",   "Fire Blast"},
        {"F",                 "spell",   "Frost Nova"},
        {"SHIFT-F",           "spell",   "Counterspell"},
        {"CTRL-F",            "spell",   "Polymorph"},
        {"X",                 "spell",   "Slow Fall"},
        {"C",                 "spell",   "Arcane Explosion"},
        {"Z",                 "spell",   "Invisibility"},
        {"CTRL-SPACE",        "spell",   "Blink"},
        {"ALT-CTRL-Z",        "spell",   "Shadowmeld"},
      },
      ARCANE = {},
      FIRE = {},
      FROST = {},
    },
    SHAMAN = {
      CLASS = {
        {"BUTTON4",           "macro",   "MOUSE4"},
        {"`",                 "spell",   "Gift of the Naaru"},
        {"1",                 "spell",   "Healing Surge"},
        {"SHIFT-1",           "spell",   "Healing Surge"},
        {"2",                 "spell",   "Healing Surge"},
        {"SHIFT-2",           "spell",   "Healing Surge"},
        {"SHIFT-3",           "spell",   "Chain Lightning"},
        {"4",                 "spell",   "Flame Shock"},
        {"SHIFT-4",           "spell",   "Lava Burst"},
        {"Q",                 "macro",   "CHAIN"},
        {"E",                 "spell",   "Primal Strike"},
        {"SHIFT-E",           "spell",   "Lightning Bolt"},
        {"CTRL-E",            "spell",   "Chain Lightning"},
        {"R",                 "spell",   "Earth Shield"},
        {"SHIFT-R",           "spell",   "Lightning Shield"},
        {"CTRL-R",            "spell",   "Water Shield"},
        {"T",                 "spell",   "Healing Stream Totem"},
        {"ALT-T",             "spell",   "Healing Tide Totem"},
        {"SHIFT-T",           "spell",   "Spirit Link Totem"},
        {"CTRL-T",            "spell",   "Earthbind Totem"},
        {"ALT-CTRL-SHIFT-T",  "spell",   "Wind Rush Totem"},
        {"F",                 "spell",   "Frost Shock"},
        {"SHIFT-F",           "spell",   "Wind Shear"},
        {"CTRL-F",            "spell",   "Hex"},
        {"Z",                 "spell",   "Ghost Wolf"},
        {"C",                 "spell",   "Thunderstorm"},
        {"SHIFT-C",           "macro",   "SELF_RAIN"},
        {"V",                 "spell",   "Astral Shift"},
        {"CTRL-SPACE",        "spell",   "Gust of Wind"},
        {"ALT-CTRL-Z",        "spell",   "Ancestral Spirit"},
      },
      ELEMENTAL = {
        {"3",                 "spell",   "Earthquake"},
        {"5",                 "spell",   "Earth Shock"},
      },
      ENHANCEMENT = {},
      RESTORATION = {
        {"1",                 "spell",   "Riptide"},
        {"ALT-1",             "spell",   "Purify Spirit"},
        {"2",                 "spell",   "Healing Wave"},
        {"SHIFT-2",           "spell",   "Healing Surge"},
      },
    },
  },
  CLASSIC = {
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
    }
  }
}