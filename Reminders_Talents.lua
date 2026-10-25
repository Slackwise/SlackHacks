setfenv(1, _G.SlackHacks)

--[[
  Talent Reminders: reminds the player when their active talent loadout doesn't match the one they picked for the
  content they're in (Questing, Delves, Raids, Dungeons or PvP), and optionally for each of the current season's
  Mythic+ dungeons. On entering or leaving content it shows a small, movable prompt near the top of the screen with
  the desired loadout pre-selected in a dropdown; confirming loads that loadout.

  The chosen loadouts are saved per character (db.char), keyed by specialization ID, since loadouts belong to a
  character's spec. Whether the module is enabled is a profile setting, like every other module.

  It's a sub-module of Reminders (Reminders.lua): it only runs while both its own setting and the Reminders master
  switch are on.
]]--

local module = Self:NewModule("Talents", "AceEvent-3.0")
Self.Talents = module

-- Content contexts in display order. `key` is the saved-data key under each spec's `contexts` table.
module.CONTEXTS = {
  { key = "questing", name = "Questing", desc = "The open world, outside of any instance." },
  { key = "delves", name = "Delves", desc = "Any Delve." },
  { key = "raids", name = "Raids", desc = "Any raid, at any difficulty." },
  { key = "dungeons", name = "Dungeons", desc = "Any dungeon, at any difficulty (including Mythic+)." },
  { key = "pvp", name = "PvP", desc = "Battlegrounds and arenas." },
}
-- Fixed option slots: Druids have the most specializations, and a season's Mythic+ pool has been 8 dungeons.
module.MAX_SPECS = 4
module.MAX_SEASON_DUNGEONS = 12

local CONTEXT_NAMES = {}
for _, context in ipairs(module.CONTEXTS) do
  CONTEXT_NAMES[context.key] = context.name
end

local DELVE_DIFFICULTY_ID = 208
-- Instance info and talent data settle a moment after a loading screen, so evaluation is briefly delayed.
local EVALUATE_DELAY_SECONDS = 1
local PROMPT_WIDTH = 360
local PROMPT_HEIGHT = 160
local DROPDOWN_WIDTH = 240
local BUTTON_WIDTH = 130
local BUTTON_HEIGHT = 22
-- Fallback for clients without Blizzard's shared backdrop table (Backdrop.lua).
local DIALOG_BACKDROP = BACKDROP_DIALOG_32_32 or {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local prompt
-- Identifies the content last evaluated (context plus instance), so only entering/leaving content prompts.
local lastContextKey
-- Set when an evaluation was skipped because of combat, so it runs once combat ends.
local pendingEvaluation = false
local evaluateTimer

--- Returns whether this client has the talent loadout APIs this module relies on.
---@return boolean supported
local function isSupported()
  return isRetail() and C_ClassTalents ~= nil and C_Traits ~= nil
end

--- Returns whether talent reminders may run: the client supports them, and both this module's setting and the
--- Reminders master switch are on.
---@return boolean allowed
local function isAllowed()
  return isSupported() and db.profile.reminders.enabled and db.profile.reminders.talents.enabled
end

--- Returns the player's active specialization ID.
---@return number|nil specID
local function currentSpecID()
  local index = GetSpecialization and GetSpecialization()
  if not index then return nil end
  return (GetSpecializationInfo(index))
end

--- Returns the per-character saved loadout choices for a specialization. AceDB's "*" default creates the table on
--- first access.
---@param specID number
---@return table settings Contains `contexts` (context key -> configID), `perMythicEnabled`, and `mythics`
---  (challenge map ID -> configID).
local function specSettings(specID)
  return db.char.reminders.talents.specs[specID]
end

--- Returns the character's saved talent loadouts for a specialization, in the talent UI's order.
---@param specID number|nil
---@return table loadouts Array of `{ configID = number, name = string }`.
function module:GetLoadouts(specID)
  local loadouts = {}
  if not specID or not isSupported() then return loadouts end
  for _, configID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
    local info = C_Traits.GetConfigInfo(configID)
    if info and info.name then
      table.insert(loadouts, { configID = configID, name = info.name })
    end
  end
  return loadouts
end

--- Returns a loadout's name, or nil when the spec no longer has that loadout (e.g. it was deleted).
---@param specID number
---@param configID number|nil
---@return string|nil name
local function loadoutName(specID, configID)
  if not configID then return nil end
  for _, loadout in ipairs(module:GetLoadouts(specID)) do
    if loadout.configID == configID then return loadout.name end
  end
  return nil
end

--- Returns the loadout chosen for a content context, ignoring choices whose loadout no longer exists.
---@param specID number
---@param contextKey string A `CONTEXTS` key.
---@return number|nil configID nil means "Off".
function module:GetContextLoadout(specID, contextKey)
  local configID = specSettings(specID).contexts[contextKey]
  if loadoutName(specID, configID) then return configID end
  return nil
end

--- Saves the loadout for a content context.
---@param specID number
---@param contextKey string A `CONTEXTS` key.
---@param configID number|nil nil turns the reminder off for that context.
function module:SetContextLoadout(specID, contextKey, configID)
  specSettings(specID).contexts[contextKey] = configID
end

--- Returns whether per-Mythic+ dungeon loadouts are turned on for a specialization.
---@param specID number
---@return boolean enabled
function module:IsPerMythicEnabled(specID)
  return specSettings(specID).perMythicEnabled and true or false
end

--- Turns per-Mythic+ dungeon loadouts on or off for a specialization.
---@param specID number
---@param enabled boolean
function module:SetPerMythicEnabled(specID, enabled)
  specSettings(specID).perMythicEnabled = enabled
end

--- Returns the loadout chosen for a Mythic+ dungeon, ignoring choices whose loadout no longer exists.
---@param specID number
---@param challengeMapID number
---@return number|nil configID nil means "Use Default" (the Dungeons loadout).
function module:GetMythicLoadout(specID, challengeMapID)
  local configID = specSettings(specID).mythics[challengeMapID]
  if loadoutName(specID, configID) then return configID end
  return nil
end

--- Saves the loadout for a Mythic+ dungeon.
---@param specID number
---@param challengeMapID number
---@param configID number|nil nil falls back to the Dungeons loadout.
function module:SetMythicLoadout(specID, challengeMapID, configID)
  specSettings(specID).mythics[challengeMapID] = configID
end

--- Returns the current Mythic+ season's dungeons, from the game's own Mythic+ map table, sorted by name.
---@return table dungeons Array of `{ challengeMapID = number, name = string, instanceID = number|nil }`.
function module:GetSeasonDungeons()
  local dungeons = {}
  if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then return dungeons end
  for _, challengeMapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
    -- The sixth return is the dungeon's instance map ID, the same ID GetInstanceInfo() reports inside it.
    local name, _, _, _, _, instanceID = C_ChallengeMode.GetMapUIInfo(challengeMapID)
    if name then
      table.insert(dungeons, { challengeMapID = challengeMapID, name = name, instanceID = instanceID })
    end
  end
  table.sort(dungeons, function(a, b) return a.name < b.name end)
  return dungeons
end

--- Returns the Mythic+ challenge map ID of the dungeon the player is in, if it's in the current season.
---@param instanceID number|nil The instance map ID from GetInstanceInfo().
---@param instanceName string|nil The instance name from GetInstanceInfo(), matched when the IDs aren't available.
---@return number|nil challengeMapID
local function currentChallengeMapID(instanceID, instanceName)
  local activeMapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
    and C_ChallengeMode.GetActiveChallengeMapID()
  if activeMapID then return activeMapID end
  for _, dungeon in ipairs(module:GetSeasonDungeons()) do
    if (instanceID and dungeon.instanceID == instanceID) or dungeon.name == instanceName then
      return dungeon.challengeMapID
    end
  end
  return nil
end

--- Works out which content context the player is in.
---@return string|nil contextKey A `CONTEXTS` key, or nil for instances no context covers (e.g. scenarios).
---@return number|nil instanceID The instance map ID, when inside an instance.
---@return string|nil instanceName The instance name, when inside an instance.
local function currentContext()
  local inInstance, instanceType = IsInInstance()
  if not inInstance then return "questing" end
  local instanceName, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
  local contextKey
  if difficultyID == DELVE_DIFFICULTY_ID
    or (C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress()) then
    contextKey = "delves"
  elseif instanceType == "party" then
    contextKey = "dungeons"
  elseif instanceType == "raid" then
    contextKey = "raids"
  elseif instanceType == "pvp" or instanceType == "arena" then
    contextKey = "pvp"
  end
  return contextKey, instanceID, instanceName
end

--- Returns the loadout the player wants for their current content: a dungeon's own loadout when per-Mythic+
--- loadouts are on and one is chosen, otherwise the context's loadout.
---@param specID number
---@param contextKey string
---@param instanceID number|nil
---@param instanceName string|nil
---@return number|nil configID
local function desiredLoadout(specID, contextKey, instanceID, instanceName)
  if contextKey == "dungeons" and module:IsPerMythicEnabled(specID) then
    local challengeMapID = currentChallengeMapID(instanceID, instanceName)
    local configID = challengeMapID and module:GetMythicLoadout(specID, challengeMapID)
    if configID then return configID end
  end
  return module:GetContextLoadout(specID, contextKey)
end

--- Returns the specialization's active saved loadout, or nil while the Starter Build is active.
---@param specID number
---@return number|nil configID
local function activeLoadout(specID)
  if C_ClassTalents.GetStarterBuildActive and C_ClassTalents.GetStarterBuildActive() then return nil end
  return C_ClassTalents.GetLastSelectedSavedConfigID(specID)
end

--- Loads a saved talent loadout for the active specialization.
---@param specID number The spec the loadout belongs to; nothing is loaded if the player has since changed spec.
---@param configID number|nil The loadout to load.
---@return boolean started Whether the loadout started loading (or was already active).
function module:ApplyLoadout(specID, configID)
  if not configID then return false end
  local name = loadoutName(specID, configID)
  if not name then
    prn("that talent loadout no longer exists.")
    return false
  end
  if InCombatLockdown() then
    prn("can't switch talents in combat.")
    return false
  end
  if specID ~= currentSpecID() then
    prn("your specialization changed, so your talents weren't switched.")
    return false
  end
  if C_ClassTalents.CanEditTalents then
    local canEdit, changeError = C_ClassTalents.CanEditTalents()
    if not canEdit then
      prn("can't switch talents right now" .. ((changeError and changeError ~= "") and (": " .. changeError) or "."))
      return false
    end
  end
  local result, changeError = C_ClassTalents.LoadConfig(configID, true)
  local errorResult = Enum.LoadConfigResult and Enum.LoadConfigResult.Error or 0
  if result == errorResult then
    prn("couldn't switch talents to " .. name .. ((changeError and changeError ~= "") and (": " .. changeError) or "."))
    return false
  end
  -- Blizzard's talent UI does the same after loading a loadout, so its loadout dropdown shows the new selection.
  C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, configID)
  prn("switching talents to " .. name .. ".")
  return true
end

--- Moves the prompt to its saved position.
local function applyPromptPosition()
  local settings = db.profile.reminders.talents.prompt
  prompt:ClearAllPoints()
  prompt:SetPoint(settings.point or "TOP", UIParent, settings.relativePoint or settings.point or "TOP",
    settings.x or 0, settings.y or -60)
end

--- Saves the prompt's position after it's dragged.
local function savePromptPosition()
  local settings = db.profile.reminders.talents.prompt
  local point, _, relativePoint, x, y = prompt:GetPoint()
  settings.point = point
  settings.relativePoint = relativePoint or point
  settings.x = math.floor(x + 0.5)
  settings.y = math.floor(y + 0.5)
end

--- Creates the switch-talents prompt on first use.
local function createPrompt()
  if prompt then return end
  local frame = CreateFrame("Frame", "SlackHacksTalentReminderPrompt", UIParent, "BackdropTemplate")
  frame:SetSize(PROMPT_WIDTH, PROMPT_HEIGHT)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetDontSavePosition(true)
  frame:EnableMouse(true)
  -- Keyboard input is deliberately never enabled (no EnableKeyboard, edit boxes or UISpecialFrames entry), so the
  -- prompt can pop up mid-movement without stealing keys from the player.
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePromptPosition()
  end)
  frame:SetBackdrop(DIALOG_BACKDROP)
  frame:Hide()

  frame.Title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  frame.Title:SetPoint("TOP", 0, -20)
  frame.Title:SetText("Talent Reminder")

  frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  frame.Text:SetPoint("TOPLEFT", 24, -44)
  frame.Text:SetPoint("TOPRIGHT", -24, -44)
  frame.Text:SetJustifyH("CENTER")

  frame.Dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
  frame.Dropdown:SetWidth(DROPDOWN_WIDTH)
  frame.Dropdown:SetPoint("TOP", frame.Text, "BOTTOM", 0, -10)
  frame.Dropdown:SetupMenu(function(_, rootDescription)
    --- Returns whether a loadout is the prompt's current selection.
    ---@param configID number
    ---@return boolean
    local function isSelected(configID) return frame.selectedConfigID == configID end
    --- Makes a loadout the prompt's selection.
    ---@param configID number
    local function setSelected(configID) frame.selectedConfigID = configID end
    for _, loadout in ipairs(module:GetLoadouts(frame.specID)) do
      rootDescription:CreateRadio(loadout.name, isSelected, setSelected, loadout.configID)
    end
  end)

  frame.SwitchButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.SwitchButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  frame.SwitchButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 20)
  frame.SwitchButton:SetText("Switch Talents")
  frame.SwitchButton:SetScript("OnClick", function()
    if module:ApplyLoadout(frame.specID, frame.selectedConfigID) then frame:Hide() end
  end)

  frame.CancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.CancelButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  frame.CancelButton:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 20)
  frame.CancelButton:SetText("Not Now")
  frame.CancelButton:SetScript("OnClick", function() frame:Hide() end)

  frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.CloseButton:SetPoint("TOPRIGHT", -6, -6)

  prompt = frame
end

--- Shows the prompt offering to switch to a loadout.
---@param specID number
---@param configID number The loadout to pre-select.
---@param contextLabel string Describes the content the player is in, e.g. "Dungeons (Ara-Kara)".
local function showPrompt(specID, configID, contextLabel)
  createPrompt()
  applyPromptPosition()
  prompt.specID = specID
  prompt.selectedConfigID = configID
  prompt.Text:SetText(("You're now in %s, but your talents don't match the loadout you chose for it. "
    .. "Switch talent loadouts?"):format("|cffffd100" .. contextLabel .. "|r"))
  -- Rebuilds the dropdown's menu from the new spec's loadouts and refreshes its text to the new selection.
  prompt.Dropdown:GenerateMenu()
  prompt:Show()
end

--- Hides the switch-talents prompt.
function module:HidePrompt()
  if prompt then prompt:Hide() end
end

--- Checks the player's content and active loadout, and prompts to switch when they don't match. Only prompts when
--- the content changed since the last check, unless forced.
---@param force boolean|nil Re-check even if the content hasn't changed (e.g. after a spec change).
---@param silent boolean|nil Only record the current content without prompting (e.g. after a UI reload).
function module:Evaluate(force, silent)
  if not isAllowed() then return end
  if InCombatLockdown() then
    pendingEvaluation = true
    return
  end
  local contextKey, instanceID, instanceName = currentContext()
  local specID = currentSpecID()
  -- Loadouts aren't loaded yet right after login; TRAIT_CONFIG_LIST_UPDATED re-runs this once they are, so don't
  -- record the content as handled until then.
  if not specID or #self:GetLoadouts(specID) == 0 then return end
  -- The open world is one context, so moving between zones doesn't prompt again; each instance is its own.
  local key = (contextKey or "other") .. ":" .. tostring(contextKey ~= "questing" and instanceID or "")
  if key == lastContextKey and not force then return end
  lastContextKey = key
  self:HidePrompt()
  if silent or not contextKey then return end
  -- Talents are locked once a Mythic+ keystone has started.
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
    return
  end
  local configID = desiredLoadout(specID, contextKey, instanceID, instanceName)
  if not configID or configID == activeLoadout(specID) then return end
  local label = CONTEXT_NAMES[contextKey]
  if contextKey ~= "questing" and instanceName and instanceName ~= "" then
    label = label .. " (" .. instanceName .. ")"
  end
  showPrompt(specID, configID, label)
end

--- Runs Evaluate after a short delay, replacing any evaluation already waiting.
---@param force boolean|nil Passed to Evaluate.
---@param silent boolean|nil Passed to Evaluate.
local function scheduleEvaluation(force, silent)
  if evaluateTimer then evaluateTimer:Cancel() end
  evaluateTimer = C_Timer.NewTimer(EVALUATE_DELAY_SECONDS, function()
    evaluateTimer = nil
    module:Evaluate(force, silent)
  end)
end

--- Loading screens: entering or leaving instances. A UI reload only records the current content.
---@param _ string Event name.
---@param _isInitialLogin boolean
---@param isReloadingUi boolean
function module:PLAYER_ENTERING_WORLD(_, _isInitialLogin, isReloadingUi)
  scheduleEvaluation(false, isReloadingUi)
end

--- Zone changes without a loading screen; Evaluate ignores them unless the content actually changed.
function module:ZONE_CHANGED_NEW_AREA()
  scheduleEvaluation()
end

--- A spec change switches to that spec's loadouts, so re-check the current content against them.
function module:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
  scheduleEvaluation(true)
end

--- Talents can't be changed once a keystone starts, so drop any open prompt.
function module:CHALLENGE_MODE_START()
  self:HidePrompt()
end

--- Loadouts were loaded, created, renamed or deleted: refresh the options' dropdowns, and finish an evaluation that
--- was waiting on the loadouts to load after login.
function module:TRAIT_CONFIG_LIST_UPDATED()
  local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
  scheduleEvaluation()
end

--- Runs an evaluation that was skipped because of combat.
function module:PLAYER_REGEN_ENABLED()
  if not pendingEvaluation then return end
  pendingEvaluation = false
  scheduleEvaluation()
end

--- Updates the profile's Talent Reminders setting and enables or disables the module.
---@param enabled boolean Whether talent reminders are enabled.
function module:SetEnabled(enabled)
  db.profile.reminders.talents.enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

--- AceAddon initialization hook; keeps the module disabled when it isn't allowed to run.
function module:OnInitialize()
  if not isAllowed() then self:Disable() end
end

--- Registers the events that signal content, spec or loadout changes, then checks the current content.
function module:OnEnable()
  -- Addon-wide re-enables (e.g. profile reset) and the Reminders switch enable every module, so re-check.
  if not isAllowed() then
    self:SetEnabledState(false)
    return
  end
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
  self:RegisterEvent("CHALLENGE_MODE_START")
  self:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  scheduleEvaluation()
end

--- Unregisters events, cancels pending checks and hides the prompt.
function module:OnDisable()
  self:UnregisterAllEvents()
  if evaluateTimer then
    evaluateTimer:Cancel()
    evaluateTimer = nil
  end
  lastContextKey = nil
  pendingEvaluation = false
  self:HidePrompt()
end
