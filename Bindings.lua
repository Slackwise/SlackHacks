-- Bindings have to be in global scope,
-- so we need them to be set before `setfenv()` changes scope!
BINDING_HEADER_SLACKHACKS = "SlackHacks"
BINDING_NAME_SLACKHACKS_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKHACKS_RELOADUI = "Reload UI"
BINDING_NAME_SLACKHACKS_MOUNT = "Mount"
BINDING_NAME_SLACKHACKS_SETBINDINGS = "Load Keybindings"
BINDING_HEADER_SLACKHACKS = "SlackHacks"
BINDING_NAME_SLACKHACKS_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKHACKS_RELOADUI = "Reload UI"
BINDING_NAME_SLACKHACKS_MOUNT = "Mount"
BINDING_NAME_SLACKHACKS_SETBINDINGS = "Load Keybindings"
BINDING_NAME_SLACKHACKS_BEST_HEALING_POTION = "Use Best Healing Potion"
BINDING_NAME_SLACKHACKS_BEST_MANA_POTION = "Use Best Mana Potion"
BINDING_NAME_SLACKHACKS_BEST_BANDAGE = "Use Best Bandage"


-- Change implicit global scope to our addon "namespace":
setfenv(1, _G.SlackHacks)

BINDINGS = {} --#TODO: Map these to the DB/config file

BINDING_TYPE = {
  DEFAULT_BINDINGS   = 0,
  ACCOUNT_BINDINGS   = 1,
  CHARACTER_BINDINGS = 2
}


BINDINGS_FUNCTIONS = {
  ["command"] = SetBinding,
  ["spell"]   = SetBindingSpell,
  ["macro"]   = SetBindingMacro,
  ["item"]    = SetBindingItem,
  ["click"]   = SetBindingClick
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
  if InCombatLockdown() then
    runAfterCombat(bindBestUseItems)
    return
  end

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
    print("SlackHacks Bindings: Work in progress. Cannot bind currently.")
    return
  end

  if InCombatLockdown() then
    runAfterCombat(setBindings)
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
      print("SlackHacks Binding: No spec currently to bind!")
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