setfenv(1, _G.SlackHacks)

--=====================================================================
-- Quest / NPC
--=====================================================================
-- NPC dialog automation (auto-accept, auto-complete, auto-click first option), number-key shortcuts for dialog
-- options, and an "Extra Action Button" style button for quest items usable in the current quest area.
--
-- Design decisions worth calling out:
--   * Everything is event-driven; there is no ticker or OnUpdate. Dialog events only fire while talking
--     to an NPC, so registering them costs nothing the rest of the time.
--   * The quest item button is a barebones take on the ExtraQuestButton addon. Instead of polling quest
--     distances, it relies on PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED (the same event Blizzard's objective
--     tracker uses to glow its quest item buttons) plus C_Minimap.IsInsideQuestBlob() for the initial
--     state. Bag/quest-progress events are only registered while inside a quest area that has an item.
--   * The quest item button only steals the EXTRAACTIONBUTTON1 key(s) via override bindings owned by a
--     secure state handler, so a real Extra Action Button ([extrabar]) or a pet battle always wins, even in
--     combat, without ever touching the player's saved keybindings.
--   * Dialog number keys are override bindings owned by a secure state handler whose "[combat]" state
--     clears them from restricted code, so they're disposed of the instant combat starts (when insecure
--     code can no longer touch bindings). They're also cleared whenever the dialog closes.
--   * The quest item button skips items that must be used on a unit (C_Item.IsHelpfulItem/IsHarmfulItem),
--     so it only shows items used on the ground or without a target.
--   * Holding Shift while interacting suppresses all dialog automation for that interaction.

--- The addon module instance. Exposed as `Self.Quest` so Options.lua can call `:SetEnabled()`,
--- `:SetOption()`, and `:IsQuestItemButtonSupported()` from the config UI.
local module = Self:NewModule("Quest", "AceEvent-3.0")
Self.Quest = module

local MAX_DIALOG_KEYS = 10 -- Keys 1-9 then 0.
local AUTO_INTERACT_REPEAT_GUARD = 2 -- Seconds before the same gossip option may be auto-selected again.

local GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local GetItemCooldown = (C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown)
local IsHelpfulItem = (C_Item and C_Item.IsHelpfulItem) or _G.IsHelpfulItem
local IsHarmfulItem = (C_Item and C_Item.IsHarmfulItem) or _G.IsHarmfulItem

-- The NPC dialog automation options, in display order. `label` is shared by Options.lua, chat messages,
-- and on-screen notifications.
AUTOMATION_OPTIONS = {
  { key = "autoAccept", label = "Auto-Accept Quests" },
  { key = "autoComplete", label = "Auto-Complete Quests" },
  { key = "autoClickFirstOption", label = "Auto-Click First Dialog Option" },
}
local ALL_AUTOMATION_LABEL = "All NPC Auto-Interacts"

local function settings()
  local s = db.profile.quest
  if not s then
    s = CopyTable(dbDefaults.profile.quest or {})
    db.profile.quest = s
  end
  return s
end

local function isAutomationSuppressed()
  return IsShiftKeyDown()
end

--=====================================================================
-- Dialog Number Keys
--=====================================================================

local dialogKeyOwner -- Secure state handler that owns (and clears in combat) the number-key override bindings.
local dialogKeyButton -- Plain button the number keys click; the mouse button name carries the entry index.
local dialogEntries = {} -- Current dialog's selectable entries, in on-screen order: { select = function }.
local isDialogOpen = false

local function clearDialogKeys()
  wipe(dialogEntries)
  if dialogKeyOwner and not InCombatLockdown() then
    ClearOverrideBindings(dialogKeyOwner)
  end
end

local function bindDialogKeys()
  if not dialogKeyOwner or InCombatLockdown() then return end
  ClearOverrideBindings(dialogKeyOwner)
  if not settings().numberKeys then return end
  for index = 1, math.min(#dialogEntries, MAX_DIALOG_KEYS) do
    local key = tostring(index % 10)
    SetOverrideBindingClick(dialogKeyOwner, true, key, dialogKeyButton:GetName(), tostring(index))
  end
end

local function createDialogKeyFrames()
  if dialogKeyOwner then return end

  dialogKeyOwner = CreateFrame("Frame", "SlackHacksQuestDialogKeyOwner", UIParent, "SecureHandlerStateTemplate")
  dialogKeyOwner:SetAttribute("_onstate-combat", [[
    if newstate == "combat" then
      self:ClearBindings()
    end
  ]])

  dialogKeyButton = CreateFrame("Button", "SlackHacksQuestDialogKeys", UIParent)
  dialogKeyButton:Hide()
  -- Key-up only: if the dialog changes between key-down and key-up, the leftover key-up can't fall
  -- through to an action button that fires on key-up.
  dialogKeyButton:RegisterForClicks("AnyUp")
  dialogKeyButton:SetScript("OnClick", function(_, mouseButton)
    local entry = dialogEntries[tonumber(mouseButton)]
    if entry then entry.select() end
  end)
end

--- Called out of combat to start/stop the combat-clearing state driver for the number keys.
local function applyDialogKeySecureState()
  createDialogKeyFrames()
  if module:IsEnabled() and settings().numberKeys then
    RegisterStateDriver(dialogKeyOwner, "combat", "[combat] combat; nocombat")
  else
    UnregisterStateDriver(dialogKeyOwner, "combat")
    ClearOverrideBindings(dialogKeyOwner)
  end
end

local function setDialogEntries(entries)
  dialogEntries = entries
  isDialogOpen = true
  bindDialogKeys()
end

local function onDialogClosed()
  isDialogOpen = false
  clearDialogKeys()
end

--=====================================================================
-- Gossip (GossipFrame) & Greeting (QuestFrameGreetingPanel)
--=====================================================================

local lastAutoOptionID, lastAutoOptionTime

local function sortGossipOptions(a, b)
  return (a.orderIndex or 0) < (b.orderIndex or 0)
end

local function selectGossipOption(option)
  if option.gossipOptionID and C_GossipInfo.SelectOption then
    C_GossipInfo.SelectOption(option.gossipOptionID)
  else
    C_GossipInfo.SelectOptionByIndex(option.orderIndex)
  end
end

--- Returns true if automation acted on the gossip (and therefore the dialog is moving on).
local function automateGossip(availableQuests, activeQuests, options)
  local s = settings()
  if isAutomationSuppressed() then return false end

  if s.autoComplete then
    for _, quest in ipairs(activeQuests) do
      if quest.isComplete then
        C_GossipInfo.SelectActiveQuest(quest.questID)
        return true
      end
    end
  end

  if s.autoAccept then
    for _, quest in ipairs(availableQuests) do
      if not quest.isIgnored then
        C_GossipInfo.SelectAvailableQuest(quest.questID)
        return true
      end
    end
  end

  if s.autoClickFirstOption and #availableQuests == 0 and #activeQuests == 0 and #options == 1
    and not (C_GossipInfo.ForceGossip and C_GossipInfo.ForceGossip()) then
    local option = options[1]
    local now = GetTime()
    -- Guard against NPCs that re-open the same single-option gossip, which would otherwise loop forever.
    if option.gossipOptionID ~= lastAutoOptionID or now - (lastAutoOptionTime or 0) > AUTO_INTERACT_REPEAT_GUARD then
      lastAutoOptionID, lastAutoOptionTime = option.gossipOptionID, now
      selectGossipOption(option)
      return true
    end
  end

  return false
end

function module:GOSSIP_SHOW()
  local availableQuests = C_GossipInfo.GetAvailableQuests() or {}
  local activeQuests = C_GossipInfo.GetActiveQuests() or {}
  local options = C_GossipInfo.GetOptions() or {}
  table.sort(options, sortGossipOptions)

  if automateGossip(availableQuests, activeQuests, options) then return end

  -- Same order GossipFrame lists them: available quests, active quests, then options.
  local entries = {}
  for _, quest in ipairs(availableQuests) do
    local questID = quest.questID
    entries[#entries + 1] = { select = function() C_GossipInfo.SelectAvailableQuest(questID) end }
  end
  for _, quest in ipairs(activeQuests) do
    local questID = quest.questID
    entries[#entries + 1] = { select = function() C_GossipInfo.SelectActiveQuest(questID) end }
  end
  for _, option in ipairs(options) do
    entries[#entries + 1] = { select = function() selectGossipOption(option) end }
  end
  setDialogEntries(entries)
end

function module:QUEST_GREETING()
  local s = settings()
  local numActive = GetNumActiveQuests()
  local numAvailable = GetNumAvailableQuests()

  if not isAutomationSuppressed() then
    if s.autoComplete then
      for index = 1, numActive do
        local _, isComplete = GetActiveTitle(index)
        if isComplete then
          SelectActiveQuest(index)
          return
        end
      end
    end
    if s.autoAccept and numAvailable > 0 then
      SelectAvailableQuest(1)
      return
    end
  end

  -- Same order QuestFrameGreetingPanel lists them: active quests, then available quests.
  local entries = {}
  for index = 1, numActive do
    entries[#entries + 1] = { select = function() SelectActiveQuest(index) end }
  end
  for index = 1, numAvailable do
    entries[#entries + 1] = { select = function() SelectAvailableQuest(index) end }
  end
  setDialogEntries(entries)
end

function module:QUEST_DETAIL()
  onDialogClosed() -- The greeting/gossip list (if any) has been replaced.
  if not settings().autoAccept or isAutomationSuppressed() then return end
  if QuestGetAutoAccept and QuestGetAutoAccept() then
    AcknowledgeAutoAcceptQuest()
  else
    AcceptQuest()
  end
end

function module:QUEST_PROGRESS()
  onDialogClosed()
  if not settings().autoComplete or isAutomationSuppressed() then return end
  if IsQuestCompletable() and GetQuestMoneyToGet() == 0 then
    CompleteQuest()
  end
end

function module:QUEST_COMPLETE()
  onDialogClosed()
  if not settings().autoComplete or isAutomationSuppressed() then return end
  local numChoices = GetNumQuestChoices()
  if numChoices <= 1 and GetQuestMoneyToGet() == 0 then
    GetQuestReward(numChoices) -- 0 = no choice, 1 = the only choice
  end
end

function module:GOSSIP_CLOSED()
  onDialogClosed()
end

function module:QUEST_FINISHED()
  onDialogClosed()
end

--=====================================================================
-- Quest Item Button ("Extra Action Button" for quest items)
--=====================================================================

local itemContainer -- Secure state handler: hides for [petbattle][extrabar] and owns the EXTRAACTIONBUTTON1 bindings.
local itemButton -- SecureActionButton that uses the current quest item.
local currentItemLink
local isInsideItemQuestArea = false
local needsSecureUpdate = false

-- Runs in the restricted environment, both from the state driver (any time, including combat) and from
-- insecure code via :Execute() (out of combat only) after the item attribute changes.
local ITEM_CONTAINER_UPDATE = [[
  local button = self:GetFrameRef("button")
  self:ClearBindings()
  if self:GetAttribute("state-extra") == "show" and button:GetAttribute("item") then
    self:Show()
    local key1, key2 = GetBindingKey("EXTRAACTIONBUTTON1")
    if key1 then self:SetBindingClick(true, key1, button, "LeftButton") end
    if key2 then self:SetBindingClick(true, key2, button, "LeftButton") end
  else
    self:Hide()
  end
]]

function module:IsQuestItemButtonSupported()
  return not not (C_Minimap and C_Minimap.IsInsideQuestBlob and GetQuestLogSpecialItemInfo
    and C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo)
end

local function isQuestItemButtonActive()
  return module:IsEnabled() and settings().questItemButton and module:IsQuestItemButtonSupported()
end

local function createItemButton()
  if itemContainer then return end

  itemContainer = CreateFrame("Frame", "SlackHacksQuestItemContainer", UIParent, "SecureHandlerStateTemplate")
  itemContainer:SetSize(52, 52)
  itemContainer:Hide()

  itemButton = CreateFrame("Button", "SlackHacksQuestItemButton", itemContainer, "SecureActionButtonTemplate")
  itemButton:SetAllPoints()
  itemButton:RegisterForClicks("AnyUp", "AnyDown") -- secure item click only fires reliably with both registered
  itemButton:SetAttribute("type", "item")

  local icon = itemButton:CreateTexture(nil, "BACKGROUND")
  icon:SetAllPoints()
  itemButton.Icon = icon

  local artwork = itemButton:CreateTexture(nil, "OVERLAY")
  artwork:SetPoint("CENTER")
  artwork:SetSize(256, 128)
  artwork:SetTexture("Interface\\ExtraButton\\Default")

  local cooldown = CreateFrame("Cooldown", nil, itemButton, "CooldownFrameTemplate")
  cooldown:SetPoint("TOPLEFT", 4, -4)
  cooldown:SetPoint("BOTTOMRIGHT", -3, 4)
  itemButton.Cooldown = cooldown

  local overlay = CreateFrame("Frame", nil, itemButton) -- Keeps text above the cooldown swipe.
  overlay:SetAllPoints()
  overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)

  local hotKey = overlay:CreateFontString(nil, "ARTWORK", "NumberFontNormalGray")
  hotKey:SetPoint("TOPRIGHT", -6, -6)
  itemButton.HotKey = hotKey

  local count = overlay:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
  count:SetPoint("BOTTOMRIGHT", -6, 6)
  itemButton.Count = count

  itemButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  itemButton:SetScript("OnEnter", function(self)
    if not currentItemLink then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink(currentItemLink)
  end)
  itemButton:SetScript("OnLeave", GameTooltip_Hide)

  itemContainer:SetFrameRef("button", itemButton)
  itemContainer:SetAttribute("_onstate-extra", ITEM_CONTAINER_UPDATE)
end

--- Places the button where the Blizzard Extra Action Button lives (as set in Edit Mode). Snapshotted
--- rather than anchored, so the secure button isn't tied into Blizzard's frame's anchor family.
local function positionItemContainer()
  itemContainer:ClearAllPoints()
  local anchor = _G.ExtraAbilityContainer or _G.ExtraActionBarFrame
  local x, y
  if anchor then x, y = anchor:GetCenter() end
  if x and y then
    local ratio = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    itemContainer:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * ratio, y * ratio)
  else
    itemContainer:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
  end
end

local function updateItemVisuals()
  if not currentItemLink then return end
  local count = GetItemCount(currentItemLink)
  itemButton.Count:SetText(count > 1 and count or "")
  local key = GetBindingKey("EXTRAACTIONBUTTON1")
  itemButton.HotKey:SetText(key and GetBindingText(key, 1) or "")
end

local function updateItemCooldown()
  if not currentItemLink or not GetItemCooldown then return end
  local start, duration = GetItemCooldown((GetItemInfoInstant(currentItemLink)))
  if start and duration and duration > 0 then
    itemButton.Cooldown:SetCooldown(start, duration)
  else
    itemButton.Cooldown:Clear()
  end
end

--- True for items that must be used on a friendly or hostile unit (clicked on a target), which don't
--- belong on the button. Ground-targeted and no-target items are neither helpful nor harmful.
local function requiresUnitTarget(link)
  if not (IsHelpfulItem and IsHarmfulItem) then return false end
  return IsHelpfulItem(link) or IsHarmfulItem(link)
end

--- Scans the quest log for a quest whose area the player is inside and that has a usable, non-targeted
--- special item in the player's bags. Prefers the super-tracked quest when several qualify.
---@return string|nil itemLink, boolean isInsideAnyItemQuestArea
local function findQuestItem()
  local superTrackedID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
  local found, insideAny
  for index = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(index)
    if info and not info.isHeader then
      local link, _, _, showWhenComplete = GetQuestLogSpecialItemInfo(index)
      if link and not requiresUnitTarget(link) and C_Minimap.IsInsideQuestBlob(info.questID) then
        insideAny = true
        if (showWhenComplete or not C_QuestLog.IsComplete(info.questID)) and GetItemCount(link) > 0 then
          found = link
          if info.questID == superTrackedID then break end
        end
      end
    end
  end
  return found, insideAny
end

local function setInsideItemQuestArea(inside)
  if inside == isInsideItemQuestArea then return end
  isInsideItemQuestArea = inside
  -- Only while inside a quest area that has an item: catch looting/using up the item or finishing the quest.
  if inside then
    module:RegisterEvent("BAG_UPDATE_DELAYED", "UpdateQuestItem")
    module:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
  else
    module:UnregisterEvent("BAG_UPDATE_DELAYED")
    module:UnregisterEvent("UNIT_QUEST_LOG_CHANGED")
  end
end

local function setItemShown(shown)
  if shown then
    module:RegisterEvent("BAG_UPDATE_COOLDOWN", updateItemCooldown)
    module:RegisterEvent("UPDATE_BINDINGS")
  else
    module:UnregisterEvent("BAG_UPDATE_COOLDOWN")
    module:UnregisterEvent("UPDATE_BINDINGS")
  end
end

--- Pushes `currentItemLink` into the secure button and re-runs the container's visibility/binding logic.
--- Out of combat only; in combat the change is deferred to PLAYER_REGEN_ENABLED.
local function applyItemSecureState()
  if InCombatLockdown() then
    needsSecureUpdate = true
    return
  end
  needsSecureUpdate = false
  createItemButton()

  if isQuestItemButtonActive() then
    RegisterStateDriver(itemContainer, "extra", "[petbattle][extrabar] hide; show")
  else
    UnregisterStateDriver(itemContainer, "extra")
    itemContainer:SetAttribute("state-extra", "hide")
  end

  if currentItemLink then
    positionItemContainer()
    itemButton:SetAttribute("item", "item:" .. GetItemInfoInstant(currentItemLink))
  else
    itemButton:SetAttribute("item", nil)
  end
  itemContainer:Execute(ITEM_CONTAINER_UPDATE)
end

function module:UpdateQuestItem()
  local link, insideAny
  if isQuestItemButtonActive() then
    link, insideAny = findQuestItem()
  end
  setInsideItemQuestArea(not not insideAny)

  if link ~= currentItemLink then
    currentItemLink = link
    createItemButton()
    if link then
      itemButton.Icon:SetTexture(select(5, GetItemInfoInstant(link)))
    end
    setItemShown(not not link)
    applyItemSecureState()
  end
  if currentItemLink then
    updateItemVisuals()
    updateItemCooldown()
  end
end

function module:PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED()
  self:UpdateQuestItem()
end

function module:QUEST_ACCEPTED()
  self:UpdateQuestItem()
end

function module:QUEST_REMOVED()
  self:UpdateQuestItem()
end

function module:UNIT_QUEST_LOG_CHANGED(_, unit)
  if unit == "player" then self:UpdateQuestItem() end
end

--- Quest log data isn't guaranteed to be ready at PLAYER_ENTERING_WORLD, and loading screens don't
--- fire blob events, so do a single scan on the next QUEST_LOG_UPDATE and then stop listening.
function module:PLAYER_ENTERING_WORLD()
  self:RegisterEvent("QUEST_LOG_UPDATE")
end

function module:QUEST_LOG_UPDATE()
  self:UnregisterEvent("QUEST_LOG_UPDATE")
  self:UpdateQuestItem()
end

local lastExtraKeys

--- Only re-binds when the player's EXTRAACTIONBUTTON1 keys actually changed, since setting override
--- bindings can itself fire UPDATE_BINDINGS.
function module:UPDATE_BINDINGS()
  local key1, key2 = GetBindingKey("EXTRAACTIONBUTTON1")
  local keys = tostring(key1) .. "|" .. tostring(key2)
  if keys == lastExtraKeys then return end
  lastExtraKeys = keys
  updateItemVisuals()
  applyItemSecureState()
end

local QUEST_ITEM_EVENTS = {
  "PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED",
  "QUEST_ACCEPTED",
  "QUEST_REMOVED",
  "PLAYER_ENTERING_WORLD",
}

local function setQuestItemEventsRegistered(registered)
  for _, event in ipairs(QUEST_ITEM_EVENTS) do
    if registered then module:RegisterEvent(event) else module:UnregisterEvent(event) end
  end
end

--=====================================================================
-- Module Lifecycle
--=====================================================================

local DIALOG_EVENTS = {
  "GOSSIP_SHOW",
  "GOSSIP_CLOSED",
  "QUEST_GREETING",
  "QUEST_DETAIL",
  "QUEST_PROGRESS",
  "QUEST_COMPLETE",
  "QUEST_FINISHED",
}

local function applySecureState()
  if InCombatLockdown() then
    needsSecureUpdate = true
    return
  end
  applyDialogKeySecureState()
  applyItemSecureState()
end

--- Re-applies all current `db.profile.quest` settings. Called on enable and whenever an option changes.
function module:Refresh()
  local s = settings()
  local dialogFeatures = s.autoAccept or s.autoComplete or s.autoClickFirstOption or s.numberKeys
  for _, event in ipairs(DIALOG_EVENTS) do
    if dialogFeatures then self:RegisterEvent(event) else self:UnregisterEvent(event) end
  end
  if not dialogFeatures then onDialogClosed() end

  setQuestItemEventsRegistered(isQuestItemButtonActive())
  self:UpdateQuestItem()
  applySecureState()
end

--- Enables or disables the whole module and persists that choice. Called from the "Enable" checkbox.
---@param enabled boolean
function module:SetEnabled(enabled)
  settings().enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

--- Sets a single `db.profile.quest` option and re-applies settings. Called from Options.lua.
---@param key string
---@param value any
function module:SetOption(key, value)
  settings()[key] = value
  if self:IsEnabled() then self:Refresh() end
end

--=====================================================================
-- Automation Toggles (keybindings & minimap menu)
--=====================================================================

local function getAutomationLabel(key)
  for _, option in ipairs(AUTOMATION_OPTIONS) do
    if option.key == key then return option.label end
  end
  return key
end

--- Reports a toggle in chat and with the same on-screen notice Blizzard uses for "Music Enabled".
local function announceToggle(label, enabled)
  prn(label .. ": " .. (enabled and color("00FF00")("Enabled") or color("FF4040")("Disabled")))
  local message = label .. " " .. (enabled and "Enabled" or "Disabled")
  if ActionStatus and ActionStatus.DisplayMessage then
    ActionStatus:DisplayMessage(message)
  elseif ActionStatus_DisplayMessage then
    ActionStatus_DisplayMessage(message, true)
  end
end

local function notifyOptionsChanged()
  local acr = LibStub("AceConfigRegistry-3.0", true)
  if acr then acr:NotifyChange("SlackHacks") end
end

--- Writes automation options and applies them. Turning anything on also enables the module, otherwise
--- the toggle would silently do nothing.
local function setAutomation(values)
  local s = settings()
  local anyOn = false
  for key, value in pairs(values) do
    s[key] = value
    anyOn = anyOn or value
  end
  if anyOn and not module:IsEnabled() then
    module:SetEnabled(true)
  elseif module:IsEnabled() then
    module:Refresh()
  end
  notifyOptionsChanged()
end

function isAllQuestAutomationEnabled()
  local s = Self.db and Self.db.profile and Self.db.profile.quest
  if not (s and s.enabled) then return false end
  for _, option in ipairs(AUTOMATION_OPTIONS) do
    if not s[option.key] then return false end
  end
  return true
end

--- Toggles a single automation option (e.g. "autoAccept"). Used by keybindings.
function toggleQuestAutomation(key)
  local s = settings()
  local enabled = not (s.enabled and s[key])
  setAutomation({ [key] = enabled })
  announceToggle(getAutomationLabel(key), enabled)
end

--- Turns all automation options off if they're all on, otherwise turns them all on.
function toggleAllQuestAutomation()
  local enabled = not isAllQuestAutomationEnabled()
  local values = {}
  for _, option in ipairs(AUTOMATION_OPTIONS) do
    values[option.key] = enabled
  end
  setAutomation(values)
  announceToggle(ALL_AUTOMATION_LABEL, enabled)
end

function module:OnInitialize()
  -- Create secure frames up front (load time is never in combat), so enabling later in combat is safe.
  createDialogKeyFrames()
  if self:IsQuestItemButtonSupported() then createItemButton() end
  if not settings().enabled then self:Disable() end
end

function module:OnEnable()
  -- Always listened to while enabled (a rare event): applies secure changes deferred during combat and
  -- restores number keys if a dialog is still open after combat ends.
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:Refresh()
end

function module:OnDisable()
  self:UnregisterAllEvents()
  onDialogClosed()
  setInsideItemQuestArea(false)
  setItemShown(false)
  currentItemLink = nil
  applySecureState()
  if needsSecureUpdate then
    -- Disabled mid-combat: still need to tear down the secure frames once combat ends.
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
end

function module:PLAYER_REGEN_ENABLED()
  if needsSecureUpdate then applySecureState() end
  if not self:IsEnabled() then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  if isDialogOpen then bindDialogKeys() end
end
