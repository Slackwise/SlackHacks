setfenv(1, _G.SlackHacks)

local module = Self:NewModule("Combat", "AceEvent-3.0")
Self.Combat = module

local DEFAULT_COMMANDS = "#showtooltip\n/assist [group] TANK\n/startattack"
local FOCUS_COMMANDS = "#showtooltip\n/assist [@focus,help,nodead] focus; [group] TANK\n/startattack"
local NO_TANK_COMMANDS = "#showtooltip\n/startattack"
local PET_COMMANDS = "#showtooltip\n/assist [@pet,exists,nodead] pet\n/startattack"
local SKULL_COMMANDS = "#showtooltip\n/tm 8\n/startattack"
local MACRO_ICON = "inv_misc_questionmark"
local MAX_BODY_LENGTH = 255
local BINDING_ACTION = "SLACKHACKS_ASSIST_TANK"
local drafts = setmetatable({}, { __mode = "k" })
local pendingUpdate = false
local pendingBindingUpdate = false
local bindingOwner, lastBindingSignature
local lastError

--- Return the active profile's assist-macro settings.
---@return table settings
local function settings()
  return db.profile.combat.assistTankMacro
end

--- Give a friendly current target priority over an existing assist or no-tank fallback.
---@param commands string Generated macro commands.
---@return string commands Commands with the current-target assist condition.
local function addCurrentTargetAssist(commands)
  local updated, count = commands:gsub("\n/assist ", "\n/assist [@target,help] target; ", 1)
  if count > 0 then return updated end
  return (commands:gsub("\n", "\n/assist [@target,help] target\n", 1))
end

--- Return the standard commands for the current assist preferences.
---@return string commands
function module:GetDefaultCommands()
  local p = settings()
  local commands = p.addFocusAssist and FOCUS_COMMANDS or DEFAULT_COMMANDS
  return p.assistCurrentTarget and addCurrentTargetAssist(commands) or commands
end

--- Return the saved template, ignoring custom commands when custom mode is off.
---@return string commands
function module:GetCommands()
  return settings().useCustomMacro and settings().macroCommands or self:GetDefaultCommands()
end

--- Return the current profile's unsaved editor values.
---@return table draft
local function draft()
  local p = settings()
  if not drafts[p] then
    drafts[p] = { macroName = p.macroName, macroCommands = p.macroCommands }
  end
  return drafts[p]
end

--- Read an editor field; standard templates remain read-only and reflect the assist preferences.
---@param key string Editor field name.
---@return string value
function module:GetDraft(key)
  if key == "macroCommands" and not settings().useCustomMacro then
    return self:GetDefaultCommands()
  end
  return draft()[key]
end

--- Validate and apply an editor change, retaining invalid drafts without replacing the working macro.
---@param key string Editor field name.
---@param value string Editor value.
---@return nil
function module:SetDraft(key, value)
  draft()[key] = value
  self:SaveMacro(false)
end

--- Reset and apply the selected standard template immediately.
---@return nil
function module:ResetCommands()
  draft().macroCommands = self:GetDefaultCommands()
  self:SaveMacro(false)
end

--- Find the first other group member assigned Tank.
---@return string|nil name Tank name, or nil if no eligible tank is known.
local function findTank()
  if not IsInGroup() then return nil end
  local raid = IsInRaid()
  local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
  for index = 1, count do
    local unit = (raid and "raid" or "party") .. index
    local role = UnitGroupRolesAssigned(unit)
    if not (_G.issecretvalue and _G.issecretvalue(role))
      and role == "TANK" and not UnitIsUnit(unit, "player") then
      local name, realm = UnitFullName(unit)
      if not (_G.issecretvalue and (_G.issecretvalue(name) or _G.issecretvalue(realm)))
        and name and name ~= "" then
        if realm and realm ~= "" then
          return name .. (isForever() and (" " .. realm) or ("-" .. realm:gsub("%s", "")))
        end
        return name
      end
    end
  end
end

--- Report whether the player is assigned the Tank role in their group.
---@return boolean tank
local function isPlayerTank()
  if not IsInGroup() then return false end
  local role = UnitGroupRolesAssigned("player")
  return not (_G.issecretvalue and _G.issecretvalue(role)) and role == "TANK"
end

--- Expand every placeholder without treating percent signs in a name as replacement escapes.
---@param commands string Macro template.
---@param tank string Tank name.
---@return string body Expanded macro body.
local function expandCommands(commands, tank)
  local replacement = tank:gsub("%%", "%%%%")
  return (commands:gsub("TANK", replacement))
end

--- Resolve attack tooltips and use non-toggling Shoot for wand classes or an equipped wand.
---@param commands string Macro commands.
---@return string body Commands with bare tooltip directives resolved.
local function applyAttackTooltip(commands)
  local class = getClassName()
  local usesWand = class == "MAGE" or class == "PRIEST" or class == "WARLOCK"
  if not usesWand and GetInventoryItemID and GetItemInfoInstant then
    local itemID = GetInventoryItemID("player", 18)
    if itemID then
      local _, _, _, _, _, itemClass, itemSubclass = GetItemInfoInstant(itemID)
      usesWand = itemClass == 2 and itemSubclass == 19
    end
  end
  local name
  if class == "HUNTER" then
    name = "Auto Shot"
  else
    local spellID = usesWand and 5019 or 6603
    if C_Spell and C_Spell.GetSpellName then
      name = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
      name = GetSpellInfo(spellID)
    end
    -- Some clients do not expose unlearned ranged spells; the requested English names remain usable there.
    name = name or (usesWand and "Shoot" or "Attack")
  end
  local body = ("\n" .. commands):gsub("\n#showtooltip[ \t]*\r?\n", "\n#showtooltip" .. (name and (" " .. name) or "") .. "\n")
  body = body:gsub("\n#showtooltip[ \t]*$", "\n#showtooltip" .. (name and (" " .. name) or ""))
  if usesWand then
    -- !Shoot starts wand auto-fire without toggling it off when the assist key is pressed again.
    body = body:gsub("\n/startattack[ \t]*\r?\n", "\n/cast !" .. name .. "\n")
    body = body:gsub("\n/startattack[ \t]*$", "\n/cast !" .. name)
  end
  return body:sub(2)
end

--- Validate both the template and the expanded body before Blizzard can truncate it.
---@param name string Macro name.
---@param commands string Template containing the literal TANK placeholder.
---@param tank string|nil Resolved tank name, when known.
---@return boolean|string result True when valid, otherwise an actionable error.
function module:ValidateMacro(name, commands, tank)
  if type(name) ~= "string" or not name:find("%S") or name:find("[\r\n]")
    or (strlenutf8 and strlenutf8(name) or #name) > 16 then
    return "Macro Name must contain 1 to 16 characters and no line breaks."
  end
  if type(commands) ~= "string" or not commands:find("TANK", 1, true) then
    return "Macro Commands must contain the literal TANK placeholder."
  end
  -- Macro API limits are byte-based; counting bytes also prevents truncating UTF-8 names.
  if #commands > MAX_BODY_LENGTH then
    return "Macro Commands exceed the 255-character (255-byte) macro limit."
  end
  if tank then
    local body = expandCommands(commands, tank)
    if #body > MAX_BODY_LENGTH then
      return "Macro Commands exceed the 255-character (255-byte) limit after replacing TANK with " .. tank .. "."
    end
  end
  return true
end

--- Report a failed update without repeating the same automatic error on every roster event.
---@param message string Error notification.
---@param notify boolean|nil Whether this was an explicit Save Macro request.
---@return nil
local function reportError(message, notify)
  if notify or lastError ~= message then prn("Assist Tank Macro: " .. message) end
  lastError = message
end

--- Create or update a character macro, assisting a Hunter/Warlock pet or attacking the current target without a tank.
---@param notify boolean|nil Whether to report success/waiting status for a manual save.
---@return boolean updated Whether the macro is ready for the current group state.
function module:UpdateMacro(notify)
  if not self:IsEnabled() or not settings().enabled then
    pendingUpdate = false
    return false
  end
  if InCombatLockdown() then
    pendingUpdate = true
    if notify then prn("Assist Tank Macro: settings saved; macro update queued until combat ends.") end
    return false
  end
  pendingUpdate = false
  local tank = findTank()
  local p = settings()
  local commands = self:GetCommands()
  local valid = self:ValidateMacro(p.macroName, commands, tank)
  if valid ~= true then
    reportError(valid, notify)
    return false
  end
  -- Keep the macro available for keybinding before grouping; never assist an obsolete tank after leaving.
  -- Without another tank to assist, a tank marks their own target instead of assisting nobody.
  local markSkull = not tank and p.tankMarkSkull and isPlayerTank()
  local class = getClassName()
  local assistPet = not tank and not markSkull and (class == "HUNTER" or class == "WARLOCK")
  local fallback = markSkull and SKULL_COMMANDS or assistPet and PET_COMMANDS or NO_TANK_COMMANDS
  if p.assistCurrentTarget and not p.useCustomMacro then
    fallback = addCurrentTargetAssist(fallback)
  end
  local body = applyAttackTooltip(tank and expandCommands(commands, tank) or fallback)
  if #body > MAX_BODY_LENGTH then
    reportError("Macro Commands exceed the 255-byte limit after resolving the attack tooltip.", notify)
    return false
  end
  -- Retail and Forever expose these through MacroConsts; older clients use globals.
  local macroConsts = Constants and Constants.MacroConsts
  local accountLimit = macroConsts and macroConsts.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS
  local characterLimit = macroConsts and macroConsts.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS
  if type(accountLimit) ~= "number" or type(characterLimit) ~= "number" then
    reportError("The game's macro slot limits are unavailable; cannot safely update the character macro.", notify)
    return false
  end
  local _, characterCount = GetNumMacros()
  local macroIndex, oldBody
  -- A same-named account macro must never be edited. Character slots start after the account capacity,
  -- not after the number of account macros currently in use.
  for index = accountLimit + 1, accountLimit + characterCount do
    local name, _, text = GetMacroInfo(index)
    if name == p.macroName then
      macroIndex, oldBody = index, text
      break
    end
  end
  if not macroIndex and characterCount >= characterLimit then
    reportError("No free character-specific macro slots. Delete a character macro or choose an existing character macro name and save again.", notify)
    return false
  end
  local shouldWrite = not macroIndex or oldBody ~= body or notify
  if shouldWrite then
    local ok, result
    if macroIndex then
      ok, result = pcall(EditMacro, macroIndex, p.macroName, MACRO_ICON, body)
    else
      ok, result = pcall(CreateMacro, p.macroName, MACRO_ICON, body, true)
    end
    if not ok or not result then
      reportError("Could not save macro: " .. tostring(result), notify)
      return false
    end
    -- GetMacroInfo may return the tooltip's resolved spell texture rather than the icon supplied to the API.
    local savedName, _, savedBody = GetMacroInfo(result)
    if result <= accountLimit or savedName ~= p.macroName or savedBody ~= body then
      reportError("The game did not save the complete character-specific macro. Check your macro slots and try again.", notify)
      return false
    end
  end
  lastError = nil
  if shouldWrite then
    local target = tank or (markSkull and "Skull") or (assistPet and "Pet" or "(no tank/pet)")
    prn("Assist Tank Macro recreated targeting: " .. target)
  end
  return true
end

--- Validate and persist the editor before applying or queuing a character-macro update.
---@param notify boolean|nil Report save status unless explicitly false.
---@return boolean saved Whether the settings passed validation and were saved.
function module:SaveMacro(notify)
  notify = notify ~= false
  local name, commands = self:GetDraft("macroName"), self:GetDraft("macroCommands")
  local tank = not InCombatLockdown() and findTank() or nil
  local valid = self:ValidateMacro(name, commands, tank)
  if valid ~= true then
    reportError(valid, notify)
    return false
  end
  if #applyAttackTooltip(tank and expandCommands(commands, tank) or commands) > MAX_BODY_LENGTH then
    reportError("Macro Commands exceed the 255-byte limit after resolving the attack tooltip.", notify)
    return false
  end
  local p = settings()
  p.macroName, p.macroCommands = name, commands
  self:UpdateBinding()
  if p.enabled then
    self:UpdateMacro(notify)
  elseif notify then
    prn("Assist Tank Macro: settings saved; enable the feature to generate the macro.")
  end
  return true
end

--- Apply an immediate feature/mode preference while retaining saved custom commands.
---@param key string Setting name.
---@param value boolean Setting value.
---@return nil
function module:SetOption(key, value)
  settings()[key] = value
  lastError = nil
  self:Refresh()
end

--- Refresh the active profile and cancel obsolete deferred work when disabled.
---@return nil
function module:Refresh()
  self:UpdateMacro()
  self:UpdateBinding()
end

--- Refresh when the name of a group member becomes available after a roster update.
---@param _ string Event name.
---@param unit string Unit token.
---@return nil
function module:UNIT_NAME_UPDATE(_, unit)
  if type(unit) == "string" and (unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$")) then
    self:Refresh()
  end
end

--- Redirect the SlackHacks Assist Tank Macro binding's saved keys to the character macro.
--- The binding has no body of its own because running a macro from a binding requires an override.
---@return nil
function module:UpdateBinding()
  if InCombatLockdown() then
    if not pendingBindingUpdate then
      pendingBindingUpdate = true
      -- The addon-level queue still runs after this module unregisters its events on disable.
      runAfterCombat(function()
        pendingBindingUpdate = false
        module:UpdateBinding()
      end)
    end
    return
  end
  pendingBindingUpdate = false
  local p = settings()
  local active = self:IsEnabled() and p.enabled
  local keys = { GetBindingKey(BINDING_ACTION) }
  -- Overrides fire UPDATE_BINDINGS themselves, so skip unchanged state to avoid a refresh loop.
  local signature = (active and p.macroName or "") .. "=" .. table.concat(keys, ",")
  if signature == lastBindingSignature then return end
  lastBindingSignature = signature
  bindingOwner = bindingOwner or CreateFrame("Frame")
  ClearOverrideBindings(bindingOwner)
  if not active then return end
  for _, key in ipairs(keys) do
    SetOverrideBindingMacro(bindingOwner, false, key, p.macroName)
  end
end

--- Process one deferred update against the latest roster and settings after combat.
---@return nil
function module:PLAYER_REGEN_ENABLED()
  if pendingUpdate then self:UpdateMacro() end
end

--- Subscribe to profile changes so queued work never uses another profile's editor.
---@return nil
function module:OnInitialize()
  for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset", "OnDatabaseReset" }) do
    db:RegisterCallback(event, self.OnProfileRefresh, self)
  end
end

--- Discard stale editor values after profile changes, copies, or resets.
---@return nil
function module:OnProfileRefresh()
  drafts = setmetatable({}, { __mode = "k" })
  lastError = nil
  self:Refresh()
end

--- Listen for joining, roster changes, role assignments, and reloads.
---@return nil
function module:OnEnable()
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "GROUP_JOINED", "GROUP_LEFT", "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM",
  }) do
    self:RegisterEvent(event, "Refresh")
  end
  self:RegisterEvent("UNIT_NAME_UPDATE")
  self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "Refresh")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("UPDATE_BINDINGS", "UpdateBinding")
  self:Refresh()
end

--- Stop automatic updates without deleting any user macro.
---@return nil
function module:OnDisable()
  self:UnregisterAllEvents()
  pendingUpdate = false
  lastError = nil
  self:UpdateBinding()
end
