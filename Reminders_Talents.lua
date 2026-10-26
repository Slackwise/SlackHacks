setfenv(1, _G.SlackHacks)

--[[
  Talent Reminders: reminds the player when their active talent loadout doesn't match the one they picked for the
  content they're in (Questing, Delves, Raids, Dungeons or PvP), and optionally for each of the current season's
  Mythic+ dungeons and Midnight Season 2 raid boss rooms. On entering or leaving content it shows a small, movable
  prompt near the top of the screen with the desired loadout pre-selected in a dropdown; confirming loads it.

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
module.MAX_SEASON_MYTHICS = 12

-- Midnight Season 2: The Venomous Abyss and The Unbinding of Kith'ix (12.1.5).
-- Instance/encounter IDs come from JournalInstance/JournalEncounter (1320 and 1324); localized room names come
-- from AreaTable (parent areas 16915 and 17059). Keep this list season-specific, not "latest tier".
-- Sources: https://wago.tools/db2/JournalEncounter?filter[JournalInstanceID]=1320
-- https://wago.tools/db2/AreaTable?filter[ParentAreaID]=16915
-- The Vile Crypt mapping for Entombed Sentinels was confirmed by the user.
module.SEASON_RAIDS = {
  [3004] = { areaID = 16915, name = "The Venomous Abyss" },
  [3095] = { areaID = 17059, name = "The Unbinding of Kith'ix" },
}
module.RAID_BOSSES = {
  { instanceID = 3004, encounterID = 3470, journalEncounterID = 2888, areaID = 17680, name = "Nek'zali the Soulcoiler" },
  { instanceID = 3004, encounterID = 3445, journalEncounterID = 2874, areaID = 17687, name = "Entombed Sentinels" },
  { instanceID = 3004, encounterID = 3497, journalEncounterID = 2894, areaID = 17682, name = "The Lost Explorers" },
  { instanceID = 3004, encounterID = 3455, journalEncounterID = 2882, areaID = 17715, name = "Vashnik the Malignant" },
  { instanceID = 3004, encounterID = 3420, journalEncounterID = 2871, areaID = 17686, name = "Sszorak" },
  { instanceID = 3004, encounterID = 3421, journalEncounterID = 2887, areaID = 17681, name = "The Twin Fangs" },
  { instanceID = 3004, encounterID = 3429, journalEncounterID = 2883, areaID = 17701, name = "The Coiled Altar" },
  { instanceID = 3004, encounterID = 3492, journalEncounterID = 2895, areaID = 17702, name = "Ula'tek" },
  { instanceID = 3095, encounterID = 3513, journalEncounterID = 2896, areaID = 17778, name = "Kith'ix" },
}

local CONTEXT_NAMES = {}
for _, context in ipairs(module.CONTEXTS) do
  CONTEXT_NAMES[context.key] = context.name
end

local DELVE_DIFFICULTY_ID = 208
-- Instance info and talent data settle a moment after a loading screen, so evaluation is briefly delayed.
local EVALUATE_DELAY_SECONDS = 1
local PROMPT_WIDTH = 300
local PROMPT_HEIGHT = 286
-- Matches KeystoneLoot's loot specialization reminder card.
local SPEC_CARD_WIDTH = 180
local SPEC_CARD_HEIGHT = 90
local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 22
-- Spec ID -> "spec-thumbnail-<suffix>" atlas: the class talents spec page's artwork. Blizzard keeps this table local
-- to Blizzard_ClassSpecializationsFrame.lua (SPEC_FORMAT_STRINGS), so it's copied here; new specs need adding.
local SPEC_THUMBNAILS = {
  [62] = "mage-arcane", [63] = "mage-fire", [64] = "mage-frost",
  [65] = "paladin-holy", [66] = "paladin-protection", [70] = "paladin-retribution",
  [71] = "warrior-arms", [72] = "warrior-fury", [73] = "warrior-protection",
  [102] = "druid-balance", [103] = "druid-feral", [104] = "druid-guardian", [105] = "druid-restoration",
  [250] = "deathknight-blood", [251] = "deathknight-frost", [252] = "deathknight-unholy",
  [253] = "hunter-beastmastery", [254] = "hunter-marksmanship", [255] = "hunter-survival",
  [256] = "priest-discipline", [257] = "priest-holy", [258] = "priest-shadow",
  [259] = "rogue-assassination", [260] = "rogue-outlaw", [261] = "rogue-subtlety",
  [262] = "shaman-elemental", [263] = "shaman-enhancement", [264] = "shaman-restoration",
  [265] = "warlock-affliction", [266] = "warlock-demonology", [267] = "warlock-destruction",
  [268] = "monk-brewmaster", [269] = "monk-windwalker", [270] = "monk-mistweaver",
  [577] = "demonhunter-havoc", [581] = "demonhunter-vengeance", [1480] = "demonhunter-devourer",
  [1467] = "evoker-devastation", [1468] = "evoker-preservation", [1473] = "evoker-augmentation",
}

local prompt
-- Identifies the content last evaluated (context plus instance), so only entering/leaving content prompts.
local lastContextKey
-- A queued evaluation token, cleared on disable so callbacks in the shared combat queue become no-ops.
local pendingEvaluation
local evaluateTimer
-- The loadout being committed by ApplyLoadout ({ specID, configID }), finished on TRAIT_CONFIG_UPDATED.
local pendingLoad

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
---@return table settings Contains context choices, per-Mythic choices keyed by challenge map ID, and raid boss
--- choices keyed by encounter ID, with separate per-Mythic and per-raid-boss enable settings.
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

--- Returns whether boss-room reminders are enabled for a specialization.
---@param specID number
---@return boolean enabled
function module:IsPerRaidBossEnabled(specID)
  return specSettings(specID).perRaidBossEnabled and true or false
end

--- Enables or disables boss-room reminders for a specialization.
---@param specID number
---@param enabled boolean
function module:SetPerRaidBossEnabled(specID, enabled)
  specSettings(specID).perRaidBossEnabled = enabled
end

--- Returns a boss's saved loadout; nil means "Use Default", including when the saved loadout was deleted.
---@param specID number
---@param encounterID number The DungeonEncounter ID, not the journal encounter ID.
---@return number|nil configID
function module:GetRaidBossLoadout(specID, encounterID)
  local configID = specSettings(specID).raidBosses[encounterID]
  if loadoutName(specID, configID) then return configID end
  return nil
end

--- Saves a boss loadout; nil restores the general Raids loadout fallback.
---@param specID number
---@param encounterID number
---@param configID number|nil
function module:SetRaidBossLoadout(specID, encounterID, configID)
  specSettings(specID).raidBosses[encounterID] = configID
end

--- Returns the localized journal boss name, using the English label until journal data is available.
---@param boss table A RAID_BOSSES entry.
---@return string name
function module:GetRaidBossName(boss)
  local name = EJ_GetEncounterInfo and EJ_GetEncounterInfo(boss.journalEncounterID)
  return name or boss.name
end

--- Matches only the supported raid's localized boss-room subzones; corridors and other raids have no match.
---@param instanceID number|nil The instance map ID from GetInstanceInfo.
---@return table|nil boss A RAID_BOSSES entry.
function module:GetCurrentRaidBoss(instanceID)
  if not self.SEASON_RAIDS[instanceID] then return nil end
  local subzone = GetSubZoneText()
  if not subzone or subzone == "" then return nil end
  for _, boss in ipairs(self.RAID_BOSSES) do
    local areaName = C_Map.GetAreaInfo(boss.areaID)
    if boss.instanceID == instanceID and areaName and subzone == areaName then return boss end
  end
  return nil
end

--- Returns the current Mythic+ season's dungeons, from the game's own Mythic+ map table, sorted by name.
---@return table mythics Array of `{ challengeMapID = number, name = string, instanceID = number|nil }`.
function module:GetSeasonMythics()
  local mythics = {}
  if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then return mythics end
  for _, challengeMapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
    -- The sixth return is the dungeon's instance map ID, the same ID GetInstanceInfo() reports inside it.
    local name, _, _, _, _, instanceID = C_ChallengeMode.GetMapUIInfo(challengeMapID)
    if name then
      table.insert(mythics, { challengeMapID = challengeMapID, name = name, instanceID = instanceID })
    end
  end
  table.sort(mythics, function(a, b) return a.name < b.name end)
  return mythics
end

--- Returns the Mythic+ challenge map ID of the dungeon the player is in, if it's in the current season.
---@param instanceID number|nil The instance map ID from GetInstanceInfo().
---@param instanceName string|nil The instance name from GetInstanceInfo(), matched when the IDs aren't available.
---@return number|nil challengeMapID
local function currentChallengeMapID(instanceID, instanceName)
  local activeMapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
    and C_ChallengeMode.GetActiveChallengeMapID()
  if activeMapID then return activeMapID end
  for _, mythic in ipairs(module:GetSeasonMythics()) do
    if (instanceID and mythic.instanceID == instanceID) or mythic.name == instanceName then
      return mythic.challengeMapID
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

--- Records a loadout as the spec's selected loadout and shows it in Blizzard's talent frame.
--- LoadConfig only changes the talents; the loadout name shown in the talent frame comes from the "last selected"
--- loadout, which Blizzard's frame records itself after its own commits finish. Its dropdown also caches its
--- selection and only re-reads the last selected loadout while empty, so an already-loaded frame is updated directly.
---@param specID number
---@param configID number
local function markLoadoutSelected(specID, configID)
  C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, configID)
  local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
  if not (talentsFrame and talentsFrame.SetSelectedSavedConfigID and talentsFrame.LoadSystem) then return end
  if talentsFrame.IsInspecting and talentsFrame:IsInspecting() then return end
  -- Matches Blizzard's own post-commit bookkeeping; skipLoad only changes the dropdown selection, never the talents.
  talentsFrame.lastSelectedConfigID = configID
  talentsFrame:SetSelectedSavedConfigID(configID, false, true)
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
  local results = Enum.LoadConfigResult or {}
  if result == (results.Error or 0) then
    prn("couldn't switch talents to " .. name .. ((changeError and changeError ~= "") and (": " .. changeError) or "."))
    return false
  end
  if result == (results.NoChangesNecessary or 1) then
    pendingLoad = nil
    markLoadoutSelected(specID, configID)
    prn("your talents already match " .. name .. ".")
    return true
  end
  -- The commit finishes asynchronously (a short cast); TRAIT_CONFIG_UPDATED marks the loadout selected once it does.
  pendingLoad = { specID = specID, configID = configID }
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

--- Creates the switch-talents prompt on first use. Its look follows KeystoneLoot's loot specialization reminder: a
--- simple panel with a dark headline strip, and a card showing the spec's talent-page artwork.
local function createPrompt()
  if prompt then return end
  local frame = CreateFrame("Frame", "SlackHacksTalentReminderPrompt", UIParent, "SimplePanelTemplate")
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
  frame:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN) end)
  frame:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE) end)
  frame:Hide()

  -- SimplePanelTemplate's inset is unused, and its background is pulled in to sit flush with the border art.
  frame.Inset:Hide()
  frame.Bg:ClearAllPoints()
  frame.Bg:SetPoint("TOPLEFT", 0, -6)
  frame.Bg:SetPoint("BOTTOMRIGHT", -4, 3)

  frame.HeadlineBg = frame:CreateTexture(nil, "BACKGROUND")
  frame.HeadlineBg:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
  frame.HeadlineBg:SetBlendMode("ADD")
  frame.HeadlineBg:SetVertexColor(0.1, 0.1, 0.1, 1)
  frame.HeadlineBg:SetHeight(26)
  frame.HeadlineBg:SetPoint("TOPLEFT", 40, -21)
  frame.HeadlineBg:SetPoint("TOPRIGHT", -40, -21)

  frame.Title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  frame.Title:SetHeight(26)
  frame.Title:SetPoint("TOPLEFT", 12, -21)
  frame.Title:SetPoint("TOPRIGHT", -14, -21)
  frame.Title:SetJustifyH("CENTER")
  frame.Title:SetText("Correct talent loadout set?")

  frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  frame.Text:SetPoint("TOPLEFT", 16, -52)
  frame.Text:SetPoint("TOPRIGHT", -16, -52)
  frame.Text:SetJustifyH("CENTER")

  frame.ContentName = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  frame.ContentName:SetPoint("TOPLEFT", frame.Text, "BOTTOMLEFT", 0, -8)
  frame.ContentName:SetPoint("TOPRIGHT", frame.Text, "BOTTOMRIGHT", 0, -8)
  frame.ContentName:SetJustifyH("CENTER")
  frame.ContentName:Hide()

  frame.SpecCard = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
  frame.SpecCard:SetSize(SPEC_CARD_WIDTH, SPEC_CARD_HEIGHT)
  frame.SpecCard:SetPoint("TOP", frame.Text, "BOTTOM", 0, -30)
  -- The inset's background tiles by default, which would repeat the spec artwork instead of stretching it.
  frame.SpecCard.Bg:SetHorizTile(false)
  frame.SpecCard.Bg:SetVertTile(false)

  frame.SpecName = frame.SpecCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  frame.SpecName:SetPoint("BOTTOM", frame.SpecCard, "TOP", 0, 5)
  frame.SpecName:SetJustifyH("CENTER")

  frame.Dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
  frame.Dropdown:SetWidth(SPEC_CARD_WIDTH)
  frame.Dropdown:SetPoint("TOP", frame.SpecCard, "BOTTOM", 0, -10)
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

  frame.SwitchButton = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
  frame.SwitchButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  frame.SwitchButton:SetPoint("TOP", frame.Dropdown, "BOTTOM", 0, -8)
  frame.SwitchButton:SetText("Switch Talents")
  frame.SwitchButton:SetScript("OnClick", function()
    if module:ApplyLoadout(frame.specID, frame.selectedConfigID) then frame:Hide() end
  end)

  frame.AddonLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontDarkGraySmall")
  frame.AddonLabel:SetPoint("BOTTOMRIGHT", -7, 5)
  frame.AddonLabel:SetTextColor(0.4, 0.4, 0.4)
  frame.AddonLabel:SetText(addonName)

  frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")

  prompt = frame
end

--- Shows a specialization's name and talent-page artwork on the prompt's spec card.
---@param specID number
local function setPromptSpec(specID)
  local _, name, _, icon = GetSpecializationInfoByID(specID)
  prompt.SpecName:SetText(name or "")
  local thumbnail = SPEC_THUMBNAILS[specID]
  -- Unknown (newer) specs fall back to the spec's icon rather than another spec's artwork. The atlas isn't validated
  -- with C_Texture.GetAtlasInfo: that API resolves Vector2DMixin from the caller's environment, which is SlackHacks
  -- (setfenv) rather than _G, and errors. Every listed atlas comes from Blizzard's own table.
  if thumbnail then
    prompt.SpecCard.Bg:SetAtlas("spec-thumbnail-" .. thumbnail)
  else
    prompt.SpecCard.Bg:SetTexture(icon)
  end
end

--- Shows the prompt offering to switch to a loadout.
---@param specID number
---@param configID number The loadout to pre-select.
---@param contextLabel string Describes the content the player is in, e.g. "Dungeons (Ara-Kara)".
---@param mythicName string|nil The dungeon name when showing the dungeon-context prompt.
---@param bossName string|nil The boss name when showing a boss-room prompt.
local function showPrompt(specID, configID, contextLabel, mythicName, bossName)
  createPrompt()
  applyPromptPosition()
  prompt.specID = specID
  prompt.selectedConfigID = configID
  setPromptSpec(specID)
  local contentNameHeight = 0
  prompt.SpecCard:ClearAllPoints()
  if mythicName or bossName then
    prompt.Text:SetText(bossName
      and "Your current talents don't match your specified loadout for the current raid boss:"
      or "Your current talents don't match your specified loadout for the current Mythic dungeon:")
    prompt.ContentName:SetText(bossName or mythicName)
    prompt.ContentName:Show()
    contentNameHeight = 8 + prompt.ContentName:GetStringHeight()
    prompt.SpecCard:SetPoint("TOP", prompt.ContentName, "BOTTOM", 0, -30)
  else
    prompt.Text:SetText(("Your talents don't match your %s loadout."):format("|cffffd100" .. contextLabel .. "|r"))
    prompt.ContentName:Hide()
    prompt.SpecCard:SetPoint("TOP", prompt.Text, "BOTTOM", 0, -30)
  end
  -- Fit wrapped context/dungeon names without letting the description overlap the spec card or controls.
  prompt:SetHeight(52 + prompt.Text:GetStringHeight() + contentNameHeight + 30 + SPEC_CARD_HEIGHT + 10
    + prompt.Dropdown:GetHeight() + 8 + BUTTON_HEIGHT + 24)
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
function module:Evaluate(force)
  if not isAllowed() then return end
  if InCombatLockdown() then
    if pendingEvaluation then
      pendingEvaluation.force = pendingEvaluation.force or force
      return
    end
    local pending = { force = force }
    pendingEvaluation = pending
    --- Rechecks current content after combat, unless this queued evaluation was invalidated by disabling.
    runAfterCombat(function()
      if pendingEvaluation ~= pending then return end
      pendingEvaluation = nil
      self:Evaluate(pending.force)
    end)
    return
  end
  local contextKey, instanceID, instanceName = currentContext()
  local specID = currentSpecID()
  -- Loadouts aren't loaded yet right after login; TRAIT_CONFIG_LIST_UPDATED re-runs this once they are, so don't
  -- record the content as handled until then.
  if not specID or #self:GetLoadouts(specID) == 0 then return end
  -- The open world is one context, so moving between zones doesn't prompt again; each instance is its own.
  local key = (contextKey or "other") .. ":" .. tostring(contextKey ~= "questing" and instanceID or "")
  local boss
  local useBossRooms = contextKey == "raids" and self.SEASON_RAIDS[instanceID] ~= nil
    and self:IsPerRaidBossEnabled(specID)
  if useBossRooms then
    boss = self:GetCurrentRaidBoss(instanceID)
    key = key .. ":" .. (boss and tostring(boss.encounterID) or "unmapped")
  end
  if key == lastContextKey and not force then return end
  lastContextKey = key
  self:HidePrompt()
  if not contextKey then return end
  -- Moving out of a boss room clears stale prompts but never asks for the general Raids loadout in corridors.
  if useBossRooms and not boss then return end
  -- Talents are locked once a Mythic+ keystone has started.
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
    return
  end
  local configID
  if boss then
    configID = self:GetRaidBossLoadout(specID, boss.encounterID) or self:GetContextLoadout(specID, "raids")
  else
    configID = desiredLoadout(specID, contextKey, instanceID, instanceName)
  end
  if not configID or configID == activeLoadout(specID) then return end
  local label = CONTEXT_NAMES[contextKey]
  if contextKey ~= "questing" and instanceName and instanceName ~= "" then
    label = label .. " (" .. instanceName .. ")"
  end
  showPrompt(specID, configID, label, contextKey == "dungeons" and instanceName or nil,
    boss and self:GetRaidBossName(boss) or nil)
end

--- Runs Evaluate after a short delay, replacing any evaluation already waiting.
---@param force boolean|nil Passed to Evaluate.
local function scheduleEvaluation(force)
  if evaluateTimer then evaluateTimer:Cancel() end
  evaluateTimer = C_Timer.NewTimer(EVALUATE_DELAY_SECONDS, function()
    evaluateTimer = nil
    module:Evaluate(force)
  end)
end

--- Loading screens: logging in, reloading the UI, and entering or leaving instances.
function module:PLAYER_ENTERING_WORLD()
  scheduleEvaluation()
end

--- Zone changes without a loading screen; Evaluate ignores them unless the content actually changed.
function module:ZONE_CHANGED_NEW_AREA()
  scheduleEvaluation()
end

--- Boss rooms can change subzone without a loading screen or a new instance.
function module:ZONE_CHANGED()
  scheduleEvaluation()
end

--- Some indoor area transitions use a separate event; the context key still prevents duplicate prompts.
function module:ZONE_CHANGED_INDOORS()
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

--- Finishes a loadout switch once its commit completes; the active (spec) config is what gets updated.
---@param _ string Event name.
---@param configID number The updated trait config.
function module:TRAIT_CONFIG_UPDATED(_, configID)
  if not pendingLoad or configID ~= C_ClassTalents.GetActiveConfigID() then return end
  local load = pendingLoad
  pendingLoad = nil
  if load.specID ~= currentSpecID() then return end
  markLoadoutSelected(load.specID, load.configID)
end

--- A failed commit leaves the previous loadout in place, so don't mark the requested one as selected.
function module:CONFIG_COMMIT_FAILED()
  if not pendingLoad then return end
  pendingLoad = nil
  prn("switching talents failed.")
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
  self:RegisterEvent("ZONE_CHANGED")
  self:RegisterEvent("ZONE_CHANGED_INDOORS")
  self:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
  self:RegisterEvent("CHALLENGE_MODE_START")
  self:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
  self:RegisterEvent("TRAIT_CONFIG_UPDATED")
  self:RegisterEvent("CONFIG_COMMIT_FAILED")
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
  pendingEvaluation = nil
  pendingLoad = nil
  self:HidePrompt()
end
