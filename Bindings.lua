-- Bindings have to be in global scope,
-- so we need them to be set before `setfenv()` changes scope!
BINDING_HEADER_SLACKHACKS = "SlackHacks"
BINDING_NAME_SLACKHACKS_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKHACKS_RELOADUI = "Reload UI"
BINDING_NAME_SLACKHACKS_MOUNT = "Mount"
BINDING_NAME_SLACKHACKS_SETBINDINGS = "Load Keybindings"
BINDING_NAME_SLACKHACKS_OPTIONS = "Open Options"
BINDING_NAME_SLACKHACKS_QUICK_KEYBIND_MODE = "Open Quick Keybind Mode"
BINDING_NAME_SLACKHACKS_CLICK_CASTING = "Open Click Casting"
BINDING_NAME_SLACKHACKS_BEST_HEALING_POTION = "Use Best Healing Potion"
BINDING_NAME_SLACKHACKS_BEST_MANA_POTION = "Use Best Mana Potion"
BINDING_NAME_SLACKHACKS_BEST_BANDAGE = "Use Best Bandage"
BINDING_NAME_SLACKHACKS_TOGGLE_MOVABLE_WINDOWS = "Toggle Movable Windows"


-- Change implicit global scope to our addon "namespace":
setfenv(1, _G.SlackHacks)

BINDINGS = {} --#TODO: Map these to the DB/config file

BINDING_CATEGORY = {
  DEFAULT_BINDINGS   = 0,
  ACCOUNT_BINDINGS   = 1,
  CHARACTER_BINDINGS = 2
}

BINDING_TYPE = {
  COMMAND        = "COMMAND",
  SPELL          = "SPELL",
  MACRO          = "MACRO",
  ITEM           = "ITEM",
  CLICK          = "CLICK",
  CLICKCAST      = "CLICKCAST",
  CLICKCASTMACRO = "CLICKCASTMACRO"
}

BT = BINDING_TYPE

function openQuickKeybindMode()
  if not QuickKeybindFrame and LoadAddOn then
    LoadAddOn("Blizzard_QuickKeybind")
  end
  if QuickKeybindFrame then
    QuickKeybindFrame:Show()
  end
end

function openClickCasting()
  if ClickBindingFrame_LoadUI then
    ClickBindingFrame_LoadUI()
  end
  if ClickBindingFrame and ClickBindingFrame_Toggle and not ClickBindingFrame:IsShown() then
    ClickBindingFrame_Toggle()
  end
end

--- Best-effort: expands our own "SlackHacks" section in the (already-open-or-about-to-open) Key Bindings
--- category, so its keybindings are visible immediately instead of collapsed behind a header. Pokes at
--- undocumented Settings-panel internals (category/layout/initializer objects) that could be renamed or
--- restructured across client versions, so every step is guarded and the whole thing is safe to just skip
--- on failure -- the caller always falls back to a plain, guaranteed-to-work panel open regardless.
local function expandSlackHacksKeybindingSection()
  if not (Settings and Settings.KEYBINDINGS_CATEGORY_ID and SettingsPanel and SettingsPanel.GetCategory and SettingsPanel.GetLayout) then
    return
  end
  pcall(function()
    local category = SettingsPanel:GetCategory(Settings.KEYBINDINGS_CATEGORY_ID)
    local layout = category and SettingsPanel:GetLayout(category)
    if not (layout and layout.EnumerateInitializers) then return end
    for _, initializer in layout:EnumerateInitializers() do
      if initializer.GetName and initializer:GetName() == BINDING_HEADER_SLACKHACKS then
        initializer.data.expanded = true
        break
      end
    end
  end)
end

--- Opens the Blizzard Key Bindings settings category, best-effort expanded/scrolled to our own
--- "SlackHacks" header so the user doesn't have to hunt for it in the full keybindings list. Always falls
--- back to at least opening the Settings panel if the fancy expand-and-scroll trick isn't available or
--- errors out on this client build.
function openKeybindings()
  if InCombatLockdown() then return end
  if not (Settings and Settings.OpenToCategory) then
    print("SlackHacks: unable to open Key Bindings automatically on this client. Open it via the Game Menu > Settings > Key Bindings.")
    return
  end
  expandSlackHacksKeybindingSection()
  if Settings.KEYBINDINGS_CATEGORY_ID then
    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, BINDING_HEADER_SLACKHACKS)
  elseif SettingsPanel then
    ShowUIPanel(SettingsPanel)
  end
end

BINDINGS_FUNCTIONS = {
  [BT.COMMAND] = SetBinding,
  [BT.SPELL]   = SetBindingSpell,
  [BT.MACRO]   = SetBindingMacro,
  [BT.ITEM]    = SetBindingItem,
  [BT.CLICK]   = SetBindingClick
}

GLOBAL_MACRO_SLOTS = 120 -- Slots 1-120 are general/account-wide macros; 121-150 are per-character.

--- Create or update an in-game macro so its name/icon/body match the given definition, moving it between
--- the general and per-character macro lists if it already exists in the wrong one for `perCharacter`.
--- `GetMacroIndexByName` searches both lists, so an existing macro in either context is found and reused.
---@param name string - The macro's name.
---@param icon number - The macro's icon fileID.
---@param body string - The macro's script/text contents.
---@param perCharacter boolean - Whether the macro should be per-character rather than general/account-wide.
---@return number - The macro's slot index.
function defineMacro(name, icon, body, perCharacter)
  local index = GetMacroIndexByName(name)

  if index ~= 0 and (index > GLOBAL_MACRO_SLOTS) ~= (perCharacter or false) then
    DeleteMacro(index)
    index = 0
  end

  if index == 0 then
    return CreateMacro(name, icon, body, perCharacter)
  end

  local existingName, existingIcon, existingBody = GetMacroInfo(index)
  if existingName ~= name or existingIcon ~= icon or existingBody ~= body then
    EditMacro(index, name, icon, body)
  end
  return index
end

--- Names of macros defined via `MACROS` tables during the current `setBindings()` run, so bindings can refer
--- to them by name (and implicitly default to a macro binding instead of a spell binding).
local namedMacros = {}

--- Click-cast bindings collected during the current `setBindings()` run, applied all at once at the end
--- since the click-cast profile can only be set as a whole.
local pendingClickCastBindings = {}

--- Define every macro in a binding table's `MACROS` list, e.g. `BINDINGS.GLOBAL.MACROS` (general/account-wide)
--- or `BINDINGS.FOREVER.PALADIN.MACROS` (per-character), so bindings in that or any later table can bind them by
--- name, e.g. `{"E", "!ENGAGE"}` or `{"E", "!ENGAGE", BT.MACRO}`.
--- Each entry is a macro definition table: `{macroName, icon, body}`.
---@param bindingTable table - A bindings table that may contain a `MACROS` list.
---@param perCharacter boolean - Whether the macros should be per-character rather than general/account-wide.
function defineMacros(bindingTable, perCharacter)
  if not (bindingTable and bindingTable.MACROS) then return end
  for _, macro in ipairs(bindingTable.MACROS) do
    local name, icon, body = unpack(macro)
    defineMacro(name, icon, body, perCharacter)
    namedMacros[name] = true
  end
end

local CLICK_CAST_BUTTONS = {
  BUTTON1      = "LeftButton",
  LEFTBUTTON   = "LeftButton",
  BUTTON2      = "RightButton",
  RIGHTBUTTON  = "RightButton",
  BUTTON3      = "MiddleButton",
  MIDDLEBUTTON = "MiddleButton",
}

local CLICK_CAST_MODIFIER_NAMES = {
  SHIFT = function() return { "SHIFT", SHIFT_KEY_TEXT } end,
  CTRL  = function() return { "CTRL", CTRL_KEY_TEXT } end,
  ALT   = function() return { "ALT", ALT_KEY_TEXT } end,
  META  = function() return { "META", "CMD", META_KEY_TEXT } end,
}

local clickCastModifierBits

--- The modifier bitmask layout used by click-casting isn't documented, so discover it by asking the client to
--- describe each single bit and matching the description against the (possibly localized) modifier key names.
--- Each modifier has separate left/right bits (e.g. ALT = 16 + 32), and the client sets *both* whenever either
--- side is held, so a modifier's value is the sum of every bit that describes it.
---@return table - Map of modifier name ("SHIFT", "CTRL", "ALT", "META") to its combined bit value.
local function getClickCastModifierBits()
  if clickCastModifierBits then return clickCastModifierBits end
  local modifiersToString = GetStringFromModifiers or (C_ClickBindings and C_ClickBindings.GetStringFromModifiers)
  local bits = {}
  if modifiersToString then
    for i = 0, 15 do
      local flag = 2 ^ i
      local description = string.upper(modifiersToString(flag) or "")
      if description ~= "" then
        for modifier, getNames in pairs(CLICK_CAST_MODIFIER_NAMES) do
          for _, modifierName in ipairs(getNames()) do
            if modifierName and modifierName ~= "" and description:find(string.upper(modifierName), 1, true) then
              bits[modifier] = (bits[modifier] or 0) + flag
              break
            end
          end
        end
      end
    end
  end
  clickCastModifierBits = bits
  return bits
end

--- Parse a binding key such as "CTRL-BUTTON4" into a click-cast mouse button name and modifier bitmask.
---@param key string - A binding key whose last part is a mouse button, e.g. "BUTTON4", "SHIFT-BUTTON1".
---@return string|nil - The click-cast button name, e.g. "Button4", or `nil` if the key isn't a mouse button.
---@return number|nil - The modifier bitmask, or `nil` if a modifier couldn't be mapped.
function parseClickCastKey(key)
  local parts = { strsplit("-", string.upper(key)) }
  local buttonPart = table.remove(parts)
  local button = CLICK_CAST_BUTTONS[buttonPart]
  if not button then
    local buttonNumber = buttonPart:match("^BUTTON(%d+)$")
    if not buttonNumber then return nil end
    button = "Button" .. buttonNumber
  end

  local bits = getClickCastModifierBits()
  local modifiers, seen = 0, {}
  for _, modifier in ipairs(parts) do
    local flag = bits[modifier]
    if not flag then return button, nil end
    if not seen[modifier] then
      seen[modifier] = true
      modifiers = modifiers + flag
    end
  end
  return button, modifiers
end

--- Get the spellID of a known spell by name, as the base spell ID that click-casting expects.
local function getClickCastSpellID(name)
  local spellID
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(name)
    spellID = info and info.spellID
  elseif GetSpellInfo then
    spellID = select(7, GetSpellInfo(name))
  end
  if spellID and FindBaseSpellByID then
    spellID = FindBaseSpellByID(spellID) or spellID
  end
  return spellID
end

local function getClickBindingType(typeName, fallback)
  return (Enum and Enum.ClickBindingType and Enum.ClickBindingType[typeName]) or fallback
end

--- Built-in click-cast interactions, bindable by these names instead of a spell/macro name:
--- "TARGET" targets the clicked unit (default left-click), and "CONTEXTMENU" opens its unit menu (default right-click).
CLICK_CAST_INTERACTIONS = {
  TARGET      = { enumName = "Target",          fallback = 1 },
  CONTEXTMENU = { enumName = "OpenContextMenu", fallback = 2 },
}

--- Resolve a click-cast binding's action to a `ClickBindingInfo` type and actionID.
--- For a macro (`isMacro`), `name` is an in-game macro name. Otherwise `name` is an interaction name (see
--- `CLICK_CAST_INTERACTIONS`) or a known spell name.
---@param isMacro boolean - Whether `name` refers to a macro rather than a spell/interaction.
---@return number|nil, number|nil - The `Enum.ClickBindingType` and actionID, or `nil` if unresolvable.
local function resolveClickCastAction(name, isMacro)
  if isMacro then
    local macroIndex = GetMacroIndexByName(name)
    if macroIndex and macroIndex ~= 0 then
      return getClickBindingType("Macro", 2), macroIndex
    end
    return nil
  end
  local interaction = CLICK_CAST_INTERACTIONS[name]
  if interaction then
    local interactionID = (Enum and Enum.ClickBindingInteraction and Enum.ClickBindingInteraction[interaction.enumName])
      or interaction.fallback
    return getClickBindingType("Interaction", 3), interactionID
  end
  local spellID = getClickCastSpellID(name)
  if spellID then
    return getClickBindingType("Spell", 1), spellID
  end
  return nil
end

--- Queue a click-cast (mouse click on unit frames) binding to be applied by `applyClickCastBindings()`.
--- `name` is a macro name if `isMacro`, otherwise a spell or interaction name; see `resolveClickCastAction()`.
function setClickCastBinding(key, name, isMacro)
  local button, modifiers = parseClickCastKey(key)
  if not button then
    print("SlackHacks Binding: Click-cast key must be a mouse button (e.g. \"CTRL-BUTTON4\"): " .. key)
    return
  end
  if not modifiers then
    print("SlackHacks Binding: Unable to map click-cast modifiers for: " .. key)
    return
  end
  local actionType, actionID = resolveClickCastAction(name, isMacro)
  if not actionType then
    print("SlackHacks Binding: Unknown " .. (isMacro and "macro" or "spell") .. " for click-cast binding " .. key .. ": " .. name)
    return
  end
  table.insert(pendingClickCastBindings, {
    type = actionType,
    actionID = actionID,
    button = button,
    modifiers = modifiers,
  })
end

--- Apply all queued click-cast bindings. Like regular keybindings, the click-cast profile is first reset to the
--- game defaults (e.g. left-click to target) and then our bindings are layered on top, replacing any default
--- that uses the same button and modifiers. Mouseover/hover casting is intentionally left untouched.
--- The game only allows one binding per interaction (Target/Menu), so binding an interaction *moves* it, e.g.
--- binding "TARGET" to "ALT-BUTTON1" means a plain left-click on a unit frame no longer targets.
--- If no click-cast bindings were queued, the existing click-cast profile is left as-is.
function applyClickCastBindings()
  local clickCastBindings = pendingClickCastBindings
  pendingClickCastBindings = {}
  if #clickCastBindings == 0 then return end

  if not (C_ClickBindings and C_ClickBindings.SetProfileByInfo and C_ClickBindings.GetProfileInfo) then
    print("SlackHacks Binding: Click casting is not available on this client; skipping click-cast bindings.")
    return
  end

  if C_ClickBindings.ResetCurrentProfile then
    C_ClickBindings.ResetCurrentProfile()
  end

  local interactionType = getClickBindingType("Interaction", 3)
  local function conflicts(a, b)
    if a.button == b.button and a.modifiers == b.modifiers then
      return true
    end
    return a.type == interactionType and b.type == interactionType and a.actionID == b.actionID
  end

  -- Later bindings win over earlier ones (e.g. class bindings over GLOBAL), and over the game defaults.
  local profile = {}
  local function addBinding(info)
    for i = #profile, 1, -1 do
      if conflicts(profile[i], info) then
        table.remove(profile, i)
      end
    end
    table.insert(profile, info)
  end

  for _, info in ipairs(C_ClickBindings.GetProfileInfo() or {}) do
    addBinding(info)
  end
  for _, clickCastBinding in ipairs(clickCastBindings) do
    addBinding(clickCastBinding)
  end

  C_ClickBindings.SetProfileByInfo(profile)
end

--- A binding entry is `{key, name, bindingType}`, where `bindingType` is optional and defaults to "SPELL",
--- or to "MACRO" if `name` is a macro defined in a `MACROS` table.
--- If `name` is a table `{macroName, icon, body}` instead of a string, the binding is treated as a macro
--- (no `bindingType` needed): the macro is created/updated to match the definition, then bound to `key`.
--- Click-cast bindings bind a mouse button `key` (e.g. "CTRL-BUTTON4") via the game's Click Casting feature
--- (clicking on unit frames):
---   "CLICKCAST"      - `name` is a spell name, or an interaction name ("TARGET"/"CONTEXTMENU").
---   "CLICKCASTMACRO" - `name` is a macro name (e.g. from a `MACROS` table) or a macro definition table.
--- A macro definition table with "CLICKCAST" is also treated as a macro, since it's unambiguous.
---@param perCharacter boolean - Whether a newly-defined macro should be per-character rather than general.
function setBinding(binding, perCharacter)
  local key, name, bindingType = unpack(binding)
  local isClickCast = bindingType == BT.CLICKCAST or bindingType == BT.CLICKCASTMACRO
  if type(name) == "table" then
    local macroName, icon, body = unpack(name)
    defineMacro(macroName, icon, body, perCharacter)
    namedMacros[macroName] = true
    if isClickCast then
      setClickCastBinding(key, macroName, true)
    else
      SetBindingMacro(key, macroName)
    end
    return
  end
  if isClickCast then
    setClickCastBinding(key, name, bindingType == BT.CLICKCASTMACRO)
    return
  end
  BINDINGS_FUNCTIONS[bindingType or (namedMacros[name] and BT.MACRO) or BT.SPELL](key, name)
end

--- Whether a binding should be skipped because it's a spell binding for a spell the player doesn't know.
--- Macro bindings (including "CLICKCASTMACRO") are never skipped, so a missing macro is reported instead.
function shouldSkipBinding(binding)
  local key, name, bindingType = unpack(binding)
  if type(name) == "table" or bindingType == BT.CLICKCASTMACRO then
    return false
  end
  if bindingType == BT.CLICKCAST then
    return not CLICK_CAST_INTERACTIONS[name] and not getClickCastSpellID(name)
  end
  if namedMacros[name] then
    return false
  end
  return (bindingType or "SPELL") == "SPELL" and not C_Spell.DoesSpellExist(name)
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

--- Set Self Cast to "Auto" (auto self cast on, no self cast key), matching the Combat settings dropdown.
--- The default ALT self cast key otherwise hijacks ALT-clicks, e.g. our ALT-BUTTON1 click-cast "TARGET" binding.
--- The self cast key is a "modified click" saved alongside keybindings, so this must run after `LoadBindings()`.
function setSelfCastAuto()
  SetCVar("autoSelfCast", "1")
  SetModifiedClick("SELFCAST", "NONE")
end

function bindBestUseItems()
  if InCombatLockdown() then
    runAfterCombat(bindBestUseItems)
    return
  end

  ClearOverrideBindings(Self.itemBindingFrame)

  for itemType, itemMap in pairs(BEST_ITEMS) do
    -- log("Binding " .. getBindingDescription(itemMap.BINDING_NAME) .. "...")
    bindBestUseItem(itemMap)
  end
end

function bindBestUseItem(bestItemMap)
  -- Find all matching items in bags:
  local containerItemInfos = findItemsByItemIDs(keys(bestItemMap))
  if isDebugging() and containerItemInfos then
    -- log(getBindingDescription(bestItemMap.BINDING_NAME) .. ": found items:")
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

  LoadBindings(BINDING_CATEGORY.DEFAULT_BINDINGS)
  unbindUnwantedDefaults()
  setSelfCastAuto()

  namedMacros = {}
  pendingClickCastBindings = {}

  -- Global bindings: macros defined here go in the general/account-wide macro list.
  defineMacros(BINDINGS.GLOBAL, false)
  for _, binding in ipairs(BINDINGS.GLOBAL) do
    setBinding(binding, false)
  end

  -- Class specific bindings:
  local game = getGameType()
  local class = getClassName()
  local bindings = (BINDINGS[game] and BINDINGS[game][class]) or {}

  if isRetail() then
    local spec = getSpecName()
    if not spec then
      print("SlackHacks Binding: No spec currently to bind!")
    end

    defineMacros(bindings, true)

    if bindings.CLASS ~= nil then
      defineMacros(bindings.CLASS, true)
      if bindings.CLASS.PRE_SCRIPT then
        bindings.CLASS.PRE_SCRIPT()	
      end
      for _, binding in ipairs(bindings.CLASS) do
        if not shouldSkipBinding(binding) then
          setBinding(binding, true)
        end
      end
      if bindings.CLASS.POST_SCRIPT then
        bindings.CLASS.POST_SCRIPT()	
      end
    end

    local specBindings = spec and spec ~= "" and bindings[spec]
    if specBindings then
      if specBindings.PRE_SCRIPT then
        specBindings.PRE_SCRIPT()	
      end
      defineMacros(specBindings, true)
      for _, binding in ipairs(specBindings) do
        if not shouldSkipBinding(binding) then
          setBinding(binding, true)
        end
      end
      if specBindings.POST_SCRIPT then
        specBindings.POST_SCRIPT()	
      end
    end

    applyClickCastBindings()
    SaveBindings(BINDING_CATEGORY.CHARACTER_BINDINGS)
    print((spec or "CLASS-ONLY") .. " " .. class .. " binding presets loaded!")
  elseif isForever() then
    defineMacros(bindings, true)

    if bindings.PRE_SCRIPT then
      bindings.PRE_SCRIPT()	
    end

    for _, binding in ipairs(bindings) do
      if not shouldSkipBinding(binding) then
        setBinding(binding, true)
      end
    end

    if bindings.POST_SCRIPT then
      bindings.POST_SCRIPT()	
    end

    applyClickCastBindings()
    SaveBindings(BINDING_CATEGORY.CHARACTER_BINDINGS)
    print(class .. " binding presets loaded!")
  elseif isClassic() then
    defineMacros(bindings, true)

    if bindings.PRE_SCRIPT then
      bindings.PRE_SCRIPT()	
    end

    for _, binding in ipairs(bindings) do
      if not shouldSkipBinding(binding) then
        setBinding(binding, true)
      end
    end

    if bindings.POST_SCRIPT then
      bindings.POST_SCRIPT()	
    end

    applyClickCastBindings()
    SaveBindings(BINDING_CATEGORY.CHARACTER_BINDINGS)
    print(class .. " binding presets loaded!")
  else -- There are other game types like TBC and WOTLK classic, and who knows what else in the future...
    applyClickCastBindings()
    print("Unknown game type! Cannot rebind.")
  end
end