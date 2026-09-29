--[[
  SelfVendor.lua

  Lets an eligible player (group/raid/guild member) request a scripted trade from you by
  emoting at you or by you targeting them and running a slash command. Each "mode" (e.g.
  Consumables, Augment Runes, Vantus Rune, Augments) maps to a bundle of items, and a single
  configurable emote can act as that mode's trigger so the sender never needs an addon of
  their own.

  Design decisions worth remembering:
  - Everything funnels through a FIFO queue (`self.tradeQueue`) so only one trade is ever
    prepared/opened at a time. WoW's trade window, bag manipulation, and item-splitting APIs
    are single-actor and asynchronous, so servicing multiple people concurrently would corrupt
    state (wrong items ending up in the wrong trade window).
  - We enqueue a requester *before* doing any async work (inspecting, bag polling) so their
    queue position is stable and can be reported back immediately, even though the inspect/bag
    checks that follow are asynchronous.
  - Item quantities are handled via C_Container.SplitContainerItem + polling rather than trusting
    an immediate stack read, because the client updates container info asynchronously after a
    split; polling with backoff (see PollPreparedStack) avoids racing the game's own item move.
  - Vantus Runes are intentionally excluded from the "Consumables" bundles (CONSUMABLES_MISSING /
    CONSUMABLES_ALL) because they are per-raid-instance items you may not want handed out by
    default, unlike flasks/oils/augment runes which are always useful. They get their own mode
    and trigger emote instead.
]]

setfenv(1, _G.SlackHacks)

local module = Self:NewModule("SelfVendor", "AceEvent-3.0")
Self.SelfVendor = module
local maxTradeSlots = MAX_TRADABLE_ITEMS or 6
local VendorMode = Enum.SelfVendorMode

--- Look up the saved-variable configuration table for a given vendor mode.
-- Centralized so every read/write of a mode's `enabled`/`triggerEmote`/`runeQuantity`
-- goes through one place instead of repeating the `db.profile.selfVendor.modes[mode]` path.
-- @param mode number Enum.SelfVendorMode value.
-- @return table|nil the mode's profile configuration table, or nil if unknown.
local function modeConfiguration(mode)
  return db.profile.selfVendor.modes[mode]
end

--- Resolve which vendor mode a typed slash command corresponds to.
-- SELF_VENDOR_MODES stores a stable `command` string per mode (e.g. "vantusrune") so slash
-- commands stay human-typeable and decoupled from the Enum's numeric values.
-- @param command string lower-cased command word (already stripped of "/slack vendor ").
-- @return number|nil matching Enum.SelfVendorMode value, or nil if no mode uses that command.
local function modeForCommand(command)
  for mode, details in pairs(SELF_VENDOR_MODES) do
    if details.command == command then return mode end
  end
end

--- Determine which configured emote (if any) a raw CHAT_MSG_TEXT_EMOTE message matches.
-- We use a plain substring match (`find(..., 1, true)`) rather than a pattern match because
-- emote text contains punctuation/parentheses that would need escaping, and because the
-- observer-facing emote text ("<Name> glares angrily at you") only ever needs to *contain*
-- the configured fragment, not match it exactly (the player name prefix varies).
-- NOTE: SELF_VENDOR_TRIGGER_EMOTES.trigger values must be written from the *target's*
-- point of view (what the recipient of the emote sees), not the actor's own message.
-- @param message string lower-cased chat text of the emote as seen by the local player.
-- @return string|nil the SELF_VENDOR_TRIGGER_EMOTES token (e.g. "STARE") that matched, or nil.
local function emoteForTargetedMessage(message)
  for token, emote in pairs(SELF_VENDOR_TRIGGER_EMOTES) do
    if message:find(emote.trigger, 1, true) then return token end
  end
end

--- Build a human-readable label describing what was requested, for chat/log output.
-- Falls back to "(manual command)" when the request came from a targeted slash command
-- instead of an emote, so queue/status messages always read naturally either way.
-- @param mode number Enum.SelfVendorMode value.
-- @param emoteToken string|nil SELF_VENDOR_TRIGGER_EMOTES token if the request came from an emote.
-- @return string e.g. "Vantus Rune (via /stare)" or "Augments (manual command)".
local function requestLabel(mode, emoteToken)
  local modeName = SELF_VENDOR_MODES[mode] and SELF_VENDOR_MODES[mode].name or "unknown request"
  local emoteInfo = emoteToken and SELF_VENDOR_TRIGGER_EMOTES[emoteToken]
  if emoteInfo then
    return modeName .. " (via " .. emoteInfo.slashCommands:match("%S+") .. ")"
  end
  return modeName .. " (manual command)"
end

--- Look up an item's numeric ID by its display name.
-- Thin wrapper over the global ITEM_NAMES lookup table (built in StaticData.lua) that
-- tolerates ITEM_NAMES being unavailable during early load order.
-- @param itemName string exact in-game item name.
-- @return number|nil item ID, or nil if unknown.
local function itemID(itemName)
  return ITEM_NAMES and ITEM_NAMES[itemName]
end

--- Normalize and validate a requested BIS data source key ("wowhead"/"icyveins"/"murlok").
-- Falls back to DEFAULT_ENHANCEMENT_SOURCE when no source is given, and returns nil (rather
-- than an invalid string) when the source doesn't actually exist in ENHANCEMENTS_BIS, so
-- callers can safely use the result as a definite "is this valid" check.
-- @param rawSource string|nil user-provided source name, any case.
-- @return string|nil canonical lower-case source key if valid, else nil.
local function enhancementSourceKey(rawSource)
  local sourceKey = strlower(rawSource or DEFAULT_ENHANCEMENT_SOURCE or "")
  return ENHANCEMENTS_BIS and ENHANCEMENTS_BIS[sourceKey] and sourceKey
end

--- Convert an internal source key into the display name shown to users in chat output.
-- @param sourceKey string one of "wowhead", "icyveins", "murlok".
-- @return string display name (e.g. "Icy Veins"), or the raw key if unrecognized.
local function displayEnhancementSource(sourceKey)
  local names = { wowhead = "Wowhead", icyveins = "Icy Veins", murlok = "Murlok M+" }
  return names[sourceKey] or sourceKey
end

--- Resolve which flask a class/spec should use, for the "murlok" data source only.
-- Murlok M+ guides don't publish their own flask recommendation, so we deliberately borrow
-- the flask choice from the Icy Veins raid data for the same class/spec rather than leaving
-- it blank. Other sources (wowhead/icyveins) carry their own `Flask` field directly in their
-- spec data and don't need this fallback.
-- @param sourceKey string enhancement data source key.
-- @param classKey string class file name (e.g. "DEATHKNIGHT").
-- @param specKey string spec key as used in ENHANCEMENTS_BIS.
-- @return string|nil flask item name, or nil if source isn't "murlok" or no match found.
local function enhancementFlaskName(sourceKey, classKey, specKey)
  if sourceKey ~= "murlok" then return nil end
  local classData = ENHANCEMENTS_BIS.icyveins and ENHANCEMENTS_BIS.icyveins[classKey]
  local specData = classData and classData[specKey]
  return specData and specData.Flask
end

--- Case-insensitively look up a personal BIS override by "Character-Realm" key.
-- Case-insensitive because character/realm names typed in slash commands or read from
-- UnitFullName may not match the exact casing stored in ENHANCEMENTS_BIS_OVERRIDES.
-- @param key string|nil "Character-Realm" identifier to look up.
-- @return table|nil override spec data, string|nil the exact key it was stored under.
local function enhancementOverrideForKey(key)
  if not key or not ENHANCEMENTS_BIS_OVERRIDES then return nil end
  for overrideKey, override in pairs(ENHANCEMENTS_BIS_OVERRIDES) do
    if overrideKey:lower() == key:lower() then return override, overrideKey end
  end
end

--- Look up a personal BIS override for a specific unit or a fallback "Name-Realm" string.
-- Overrides are gated behind isSlackwise() because they encode one person's (Slackwise's)
-- personal gear preferences that diverge from the generic class/spec guides, and shouldn't
-- silently apply to other players running this addon.
-- @param unit string|nil unit token (e.g. "target") to resolve a full name from.
-- @param fallbackName string|nil "Name-Realm" string to use if `unit` doesn't resolve.
-- @return table|nil override spec data if one exists for this character.
local function enhancementOverride(unit, fallbackName)
  if not isSlackwise() or not ENHANCEMENTS_BIS_OVERRIDES then return nil end
  local characterName, realmName = unit and UnitFullName(unit)
  local key = characterFullName(characterName, realmName)
  if not key and fallbackName then
    characterName, realmName = fallbackName:match("^(.+)%-(.+)$")
    key = characterFullName(characterName, realmName)
  end
  return enhancementOverrideForKey(key)
end

--- Find which spec key within a class's BIS data matches a raw (possibly abbreviated) spec name.
-- Searches across every enhancement data source (not just one) because a player's requested
-- source may not have a spec entry that another source does, and we only need to confirm the
-- spec name itself is valid for the class somewhere before doing per-source lookups later.
-- @param classKey string class file name.
-- @param rawSpec string user-typed spec name/abbreviation.
-- @return string|nil canonical spec key if the class/spec combination is known.
local function specNameForClass(classKey, rawSpec)
  local specKey = specKeyForName(rawSpec)
  for _, sourceData in pairs(ENHANCEMENTS_BIS or {}) do
    local classData = sourceData[classKey]
    if classData and classData[specKey] then return specKey end
  end
end

--- Translate a raw BIS spec-data table (enchants/gems/flask) into a normalized recommendation
-- structure used throughout this module for both gear-check and consumable-check logic.
-- Consumables are always the same four items (flask, Thalassian Phoenix Oil, an augment rune,
-- and the current Vantus Rune) regardless of data source, since only enchants/gems/flask vary
-- by class/spec/source; hard-coding them here keeps that list in exactly one place.
-- @param data table raw spec data (Enchants/Gems/Flask) from ENHANCEMENTS_BIS or an override.
-- @param flaskName string|nil resolved flask name (see enhancementFlaskName); falls back to data.Flask.
-- @return table recommendation with slotKeys/slots/enchantNames/enchantIDs/gemNames/gemEntries/gemIDs/consumables.
local function buildBISEnhancementRecommendation(data, flaskName)
  flaskName = flaskName or data.Flask
  local slotKeys = { "HEAD", "SHOULDER", "CHEST", "WAIST", "LEGS", "FEET", "WRIST", "HANDS", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2", "BACK", "MAINHAND", "OFFHAND" }
  local slots, enchantNames, enchantIDs = {}, {}, {}
  for _, slotKey in ipairs(slotKeys) do
    local enchantName = data.Enchants and data.Enchants[slotKey]
    if enchantName then
      enchantNames[slotKey] = enchantName
      enchantIDs[slotKey] = ITEM_NAMES[enchantName]
      slots[#slots + 1] = SLOT_IDS[slotKey]
    end
  end
  local gemEntries, gemNames, gemIDs = {}, {}, {}
  if data.Gems and data.Gems.Primary then gemEntries[#gemEntries + 1] = { itemName = data.Gems.Primary, itemID = ITEM_NAMES[data.Gems.Primary], quantity = 1 } end
  if data.Gems and data.Gems.Secondary then gemEntries[#gemEntries + 1] = { itemName = data.Gems.Secondary, itemID = ITEM_NAMES[data.Gems.Secondary], quantity = SECONDARY_GEM_QUANTITY } end
  for index, gem in ipairs(gemEntries) do
    gemNames[index] = gem.itemName
    gemIDs[index] = ITEM_NAMES[gem.itemName]
  end
  return {
    slotKeys = slotKeys, slots = slots, enchantNames = enchantNames, enchantIDs = enchantIDs,
    gemNames = gemNames, gemEntries = gemEntries, gemIDs = gemIDs,
    consumables = {
      { itemName = flaskName, itemID = ITEM_NAMES[flaskName], kind = "flask", buffName = "Flask" },
      { itemName = "Thalassian Phoenix Oil", itemID = ITEM_NAMES["Thalassian Phoenix Oil"], kind = "oil", buffName = "Thalassian Phoenix Oil", auraSpellID = 1237006 },
      { itemName = RUNE_ITEM_NAMES[1], itemID = RUNE_ITEM_IDS[1], kind = "augmentRune", buffName = "Void-Touched", quantity = 5 },
      { itemName = CURRENT_VANTUS_RUNE_NAME, itemID = ITEM_NAMES[CURRENT_VANTUS_RUNE_NAME], kind = "vantusRune", buffName = "Vantus Rune", quantity = 1 }
    }
  }
end

--- Determine whether a named player is allowed to request a Self Vendor trade.
-- Eligibility is intentionally limited to people in your current group/raid or your guild
-- (not, say, "anyone who whispers you") so random players can't emote at you to drain your
-- consumables/enchant mats.
-- @param name string player name (with or without realm).
-- @return boolean|string truthy if eligible: a unit token from groupUnitFor, or true-ish guild match.
local function senderIsEligible(name)
  return groupUnitFor(name) or guildMember(name)
end

--- Compute the full BIS recommendation (gear + consumables) for a unit, given a data source.
-- Falls back through: requested spec -> first available spec for that class (`fallbackSpecKey`)
-- so that a source missing data for a hybrid spec doesn't hard-fail; then applies a personal
-- override (Slackwise-only) if one exists for that exact character, since a maintained personal
-- loadout should always win over generic guide data.
-- @param unit string|nil unit token to inspect (defaults to "player").
-- @param sourceKey string|nil requested/validated enhancement data source.
-- @param characterName string|nil "Name-Realm" fallback used for override lookups.
-- @return table|nil recommendation (see buildBISEnhancementRecommendation), string|nil resolved sourceKey.
local function currentRecommendation(unit, sourceKey, characterName)
  local _, classFile = UnitClass(unit or "player")
  local specName = getSpecName()
  sourceKey = enhancementSourceKey(sourceKey)
  local sourceData = sourceKey and ENHANCEMENTS_BIS[sourceKey]
  local classData = sourceData and sourceData[classFile]
  if not classData then return nil, sourceKey end
  local specKey = specKeyForName(specName)
  local fallbackSpecKey, fallbackSpecData = next(classData)
  if not classData[specKey] then specKey = fallbackSpecKey end
  local specData = classData and (classData[specKey] or fallbackSpecData)
  local override, overrideKey = enhancementOverride(unit, characterName)
  if override then
    log("Using enhancement override for " .. overrideKey)
    specData = override
  end
  return specData and buildBISEnhancementRecommendation(specData, enhancementFlaskName(sourceKey, classFile, specKey)), sourceKey
end

--- Transition module state from "pending" to "active" once the trade window has been populated.
-- This is the hand-off point between preparation (finding/splitting items, opening the trade
-- window) and the "trade in progress" phase tracked by TRADE_ACCEPT_UPDATE/TRADE_CLOSED. We
-- snapshot pendingName/pendingMode/pendingEmote into activeTradeName/activeTradeMode/
-- activeTradeEmote here (rather than leaving them in the pending* fields) so TRADE_CLOSED can
-- still report who/what was serviced even though the pending fields get cleared for the next
-- queued trade.
-- @param module table the SelfVendor module (passed explicitly since this is a local function,
--   not a method, so it can be called from contexts without `self`).
-- @param added number total item quantity actually placed into the trade window.
local function finishTradePopulation(module, added)
  if added == 0 then
    log("Trade population found no items to add")
    print("SlackHacks: no Self Vendor items found in your bags.")
  else
    log("Added " .. added .. " item entries to the trade window")
  end
  module.activeTradeName = module.pendingName
  module.tradeSucceeded = nil
  module.pendingName = nil
  module.pendingUnit = nil
  module.pendingRequired = nil
  module.pendingTradeItems = nil
  module.pendingTradeIndex = nil
  module.pendingTradeInitiated = nil
  module.activeTradeMode = module.pendingMode
  module.activeTradeEmote = module.pendingEmote
  module.pendingMode = nil
  module.pendingEmote = nil
end

--- Convert an item ID back into a display name for chat/log output.
-- Falls back to a generic "Item <id>" placeholder rather than erroring or returning nil,
-- so shortage/status messages remain readable even for an item missing from ITEM_NAMES_BY_ID.
-- @param itemID number item ID.
-- @return string display name.
local function itemName(itemID)
  return ITEM_NAMES_BY_ID[itemID] or ("Item " .. itemID)
end

--- Parse a free-form "<class> <spec>" command tail into canonical class/spec keys.
-- Class names can be multiple words ("Death Knight"), so we try progressively shorter
-- prefixes of the token list as the candidate class name (longest first) and treat
-- whatever's left as the spec text. This greedy longest-match approach correctly handles
-- both single-word classes ("Druid Balance") and multi-word ones ("Death Knight Blood")
-- without needing a fixed class-name word count.
-- @param rawCommand string remaining command text after "sendaugs", e.g. "death knight blood".
-- @return string|nil classKey, string|nil specName; both nil if no valid combination is found.
local function parseClassAndSpec(rawCommand)
  local tokens = {}
  for token in (rawCommand or ""):gmatch("%S+") do
    tokens[#tokens + 1] = token
  end
  if #tokens < 2 then return nil, nil end
  for classCount = #tokens, 1, -1 do
    local className = table.concat(tokens, " ", 1, classCount)
    local classKey = classKeyForName(className)
    if classKey then
      local specText = table.concat(tokens, " ", classCount + 1, #tokens)
      local specName = specNameForClass(classKey, specText)
      if specName then
        return classKey, specName
      end
    end
  end
  return nil, nil
end

--- Flatten a recommendation's enchants + gems into a single "itemID -> total quantity needed" map.
-- Used only for the gear-focused `/slack sendaugs` mail flow (not the emote-trade flow, which
-- has its own GetRequiredItems that also accounts for consumables and what's already equipped).
-- @param recommendationData table from buildBISEnhancementRecommendation.
-- @return table map of itemID -> required quantity.
local function buildRequiredForRecommendation(recommendationData)
  local required = {}
  local function add(itemID, quantity)
    if itemID then
      required[itemID] = (required[itemID] or 0) + (quantity or 1)
    end
  end
  for _, enchantID in pairs(recommendationData.enchantIDs or {}) do
    add(enchantID, 1)
  end
  for _, gem in ipairs(recommendationData.gemEntries or {}) do
    add(gem.itemID, gem.quantity or 1)
  end
  return required
end

--- Compare a required-items map against current bag contents and report what's missing.
-- @param required table map of itemID -> required quantity.
-- @return table map of itemID -> missing quantity, containing only items that are short.
local function missingListForRequired(required)
  local shortages = {}
  for itemID, quantity in pairs(required) do
    local missing = quantity - bagItemCount(itemID)
    if missing > 0 then shortages[itemID] = missing end
  end
  return shortages
end

--- Produce a deterministic, alphabetically-sorted list of item IDs from a required-items map.
-- Sorting matters because mail attachment slots and trade slots are filled in list order;
-- without a stable sort, repeated runs (e.g. after a partial mail send) could attach items
-- in a different order and confuse the "which slot has what" mental model for the user.
-- @param required table map of itemID -> quantity.
-- @return table array of item IDs sorted by display name.
local function sortedItemIDs(required)
  local itemIDs = {}
  for itemID in pairs(required) do
    itemIDs[#itemIDs + 1] = itemID
  end
  table.sort(itemIDs, function(left, right)
    return itemName(left) < itemName(right)
  end)
  return itemIDs
end

--- Format a single required/missing item line for shopping-list style chat output.
-- @param itemID number item ID.
-- @param quantity number quantity needed; only shown when greater than 1 to avoid noisy "1x" prefixes.
-- @return string e.g. "- 5x Void-Touched Augment Rune" or "- Flask of the Magisters".
local function shoppingListItem(itemID, quantity)
  local prefix = quantity > 1 and quantity .. "x " or ""
  return "- " .. prefix .. itemName(itemID)
end

--- Check whether the mail compose window is currently open.
-- The `/slack sendaugs` flow attaches items to mail rather than trading directly, so every
-- attach attempt needs to confirm the frame is actually up before touching cursor/mail APIs.
-- @return boolean true if SendMailFrame exists and is shown.
local function mailFrameOpen()
  return SendMailFrame and SendMailFrame:IsShown()
end

--- Move exactly `quantity` of an item from bags into a specific mail attachment slot.
-- Splits the stack first when the bag stack is larger than needed (so we don't over-mail),
-- otherwise picks up the whole matching stack directly. Every cursor operation is checked
-- with GetCursorInfo() because the pickup/split calls are fire-and-forget client requests;
-- if the cursor didn't pick anything up (e.g. bag changed, item moved), we bail out with
-- `false` rather than blindly clicking a mail slot with an empty cursor.
-- @param itemID number item to attach.
-- @param quantity number exact stack size to attach.
-- @param mailIndex number 1-based SendMailItem button index (mail supports up to 12).
-- @return boolean true if the item was successfully attached to that mail slot.
local function attachItemToMail(itemID, quantity, mailIndex)
  local bag, slot = findBagItem(itemID, quantity)
  if not bag or not slot then return false end
  if GetCursorInfo() then ClearCursor() end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  local stackCount = info and info.stackCount or 0
  if stackCount > quantity then
    C_Container.SplitContainerItem(bag, slot, quantity)
    if not GetCursorInfo() then return false end
  else
    C_Container.PickupContainerItem(bag, slot)
    if not GetCursorInfo() then return false end
  end
  local button = _G["SendMailItem" .. mailIndex]
  if button then
    ClickSendMailItemButton(mailIndex)
    return true
  end
  return false
end

--- Add to (or initialize) an itemID's entry in a required-items accumulator map.
-- Small helper to avoid repeating the `required[id] = (required[id] or 0) + qty` idiom
-- across GetRequiredItems' several accumulation sites.
-- @param required table map of itemID -> quantity, mutated in place.
-- @param itemID number|nil item to add; a no-op if nil (keeps call sites branch-free).
-- @param quantity number|nil amount to add; defaults to 1.
local function addRequiredItem(required, itemID, quantity)
  if itemID then required[itemID] = (required[itemID] or 0) + (quantity or 1) end
end

--- Check whether a unit currently has a matching buff active, by name substring or spell ID.
-- Iterates the HELPFUL aura list manually (up to 40 slots) rather than using a named-lookup
-- API because we need to match on a partial/lower-cased name (buff tooltip text can vary
-- slightly, e.g. rank suffixes) and, for oils, an exact spell ID is more reliable than name
-- matching since temporary weapon enchants don't always surface a clean aura name.
-- Used only for the CONSUMABLES_MISSING mode, to decide whether an already-buffed target
-- still needs that particular consumable traded to them.
-- @param unit string|nil unit token to inspect; returns false immediately if nil (can't inspect,
--   e.g. no unit token available for the target of an emote-only request).
-- @param buffName string|table exact/partial buff name(s) to match against, case-insensitive.
-- @param auraSpellID number|nil optional exact spell ID to match (used for the Phoenix Oil check).
-- @return boolean true if a matching aura was found.
local function hasConsumableBuff(unit, buffName, auraSpellID)
  if not unit then return false end
  local buffNames = type(buffName) == "table" and buffName or { buffName }
  for index = 1, 40 do
    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
    local name = auraData and auraData.name
    if auraSpellID and auraData and auraData.spellId == auraSpellID then return true end
    if name then
      for _, expectedName in ipairs(buffNames) do
        if name:lower():find(expectedName:lower(), 1, true) then return true end
      end
    end
  end
  return false
end

--- Handler for `/slack sendaugs <class> <spec> [source]` (and the Slackwise-only
-- `/slack sendaugs <character> <realm> [source]` override form). Mails BIS enchants/gems
-- for a class/spec (or a saved personal override) rather than trading them directly, since
-- this command is meant for prepping mail to alts/other players who aren't online/nearby to
-- trade with — unlike the emote-trade flow, which requires the recipient to be in range.
-- Gated to isSlackwise() because this is a personal bulk-mailing tool, not a general feature.
-- @param input string command text after "sendaugs", e.g. "shaman enhancement wowhead" or
--   "Charname Realmname" for a personal override lookup.
function module:SendAugsForClassSpec(input)
  if not isSlackwise() then
    print("SlackHacks: unknown command.")
    return
  end
  local tokens = {}
  for token in (input or ""):gmatch("%S+") do
    tokens[#tokens + 1] = token
  end
  local sourceKey = enhancementSourceKey(tokens[#tokens])
  if sourceKey then table.remove(tokens) end
  sourceKey = sourceKey or DEFAULT_ENHANCEMENT_SOURCE
  if isSlackwise() and #tokens == 2 then
    local overrideKey = characterFullName(tokens[1], tokens[2])
    local override, resolvedOverrideKey = enhancementOverrideForKey(overrideKey)
    if override then
      local recommendationData = buildBISEnhancementRecommendation(override)
      local required = buildRequiredForRecommendation(recommendationData)
      local shortages = missingListForRequired(required)
      if not mailFrameOpen() then
        print("SlackHacks: open the mail compose window first.")
        for itemID, quantity in pairs(shortages) do print(shoppingListItem(itemID, quantity)) end
        return
      end
      if next(shortages) then
        print("SlackHacks: missing items for " .. resolvedOverrideKey .. ":")
        for itemID, quantity in pairs(shortages) do print(shoppingListItem(itemID, quantity)) end
        return
      end
      local orderedIDs = sortedItemIDs(required)
      for mailIndex, itemID in ipairs(orderedIDs) do
        if mailIndex > 12 or not attachItemToMail(itemID, required[itemID], mailIndex) then
          print("SlackHacks: failed to attach items for " .. resolvedOverrideKey .. ".")
          return
        end
      end
      print("SlackHacks: BIS enchants and gems for " .. resolvedOverrideKey .. " have been added to the letter.")
      return
    end
  end
  local classKey, resolvedSpec = parseClassAndSpec(table.concat(tokens, " "))
  if not classKey or not resolvedSpec then
    print("SlackHacks: unknown class/spec for sendaugs: " .. strtrim(input or ""))
    print("Usage: /slack sendaugs <class> <spec> [wowhead|icyveins|murlok]")
    if isSlackwise() then print("SlackHacks: personal overrides use /slack sendaugs <character> <realm> [wowhead|icyveins|murlok]") end
    return
  end

  local sourceData = ENHANCEMENTS_BIS and ENHANCEMENTS_BIS[sourceKey]
  local classData = sourceData and sourceData[classKey]
  local specData = classData and classData[resolvedSpec]
  if not specData then
    print("SlackHacks: no " .. displayEnhancementSource(sourceKey) .. " BIS data found for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ".")
    return
  end

  local recommendationData = buildBISEnhancementRecommendation(specData, enhancementFlaskName(sourceKey, classKey, resolvedSpec))
  local required = buildRequiredForRecommendation(recommendationData)
  local shortages = missingListForRequired(required)

  if not mailFrameOpen() then
    print("SlackHacks: open the mail compose window first.")
    if next(shortages) then
      print("SlackHacks: buy these items from the auction house for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ":")
      for itemID, quantity in pairs(shortages) do
        print(shoppingListItem(itemID, quantity))
      end
    else
      print("SlackHacks: you already have everything needed for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ".")
    end
    return
  end

  if next(shortages) then
    print("SlackHacks: missing items for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ":")
    for itemID, quantity in pairs(shortages) do
      print(shoppingListItem(itemID, quantity))
    end
    print("SlackHacks: buy the missing items from the auction house, then reopen the mail compose window.")
    return
  end

  local orderedIDs = sortedItemIDs(required)
  local mailCount = 0
  for _, itemID in ipairs(orderedIDs) do
    if mailCount >= 12 then break end
    local quantity = required[itemID]
    local bag, slot = findBagItem(itemID, quantity)
    if not bag or not slot then
      print("SlackHacks: unable to find " .. itemName(itemID) .. " x" .. quantity .. " in your bags.")
      return
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local stackCount = info and info.stackCount or 0
    if stackCount < quantity then
      print("SlackHacks: not enough " .. itemName(itemID) .. " in a single stack for mail.")
      return
    end
    if not attachItemToMail(itemID, quantity, mailCount + 1) then
      print("SlackHacks: failed to attach " .. itemName(itemID) .. " x" .. quantity .. " to the mail.")
      return
    end
    mailCount = mailCount + 1
  end

  print("SlackHacks: BIS enchants and gems for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. " have been added to the letter.")
end

--- Toggle the entire Self Vendor module on/off (persisted setting + Ace3 Enable/Disable).
-- Delegates to AceAddon's Enable/Disable so OnEnable/OnDisable run their event
-- (un)registration side effects consistently, rather than duplicating that logic here.
-- @param enabled boolean whether Self Vendor should be active.
function module:SetEnabled(enabled)
  db.profile.selfVendor.enabled = enabled
  log("Self Vendor enabled state changed to " .. tostring(enabled))
  if enabled then self:Enable() else self:Disable() end
end

--- Enable or disable a single vendor mode (e.g. turn off Vantus Rune requests without
-- disabling Consumables). No-ops silently for an unknown mode so callers (options UI)
-- don't need to guard against invalid Enum values themselves.
-- @param mode number Enum.SelfVendorMode value.
-- @param enabled boolean whether this specific mode should respond to its trigger/command.
function module:SetModeEnabled(mode, enabled)
  local configuration = modeConfiguration(mode)
  if not configuration then return end
  configuration.enabled = enabled
end

--- Assign a trigger emote to a vendor mode, enforcing that each emote token is used by at
-- most one mode at a time. Without this uniqueness check, two modes could silently share an
-- emote and only one (whichever `pairs()` iteration order hits first in CHAT_MSG_TEXT_EMOTE)
-- would ever actually fire, which is a confusing, hard-to-debug state for the user to end up in.
-- @param mode number Enum.SelfVendorMode value to assign the emote to.
-- @param emote string SELF_VENDOR_TRIGGER_EMOTES token (e.g. "STARE").
-- @return boolean|nil true on success; false if the emote is already claimed by another mode;
--   nil if the mode or emote token itself is invalid.
function module:SetModeTriggerEmote(mode, emote)
  local configuration = modeConfiguration(mode)
  if not configuration or not SELF_VENDOR_TRIGGER_EMOTES[emote] then return end
  for otherMode, otherConfiguration in pairs(db.profile.selfVendor.modes) do
    if otherMode ~= mode and otherConfiguration.triggerEmote == emote then
      print("SlackHacks: " .. SELF_VENDOR_MODES[otherMode].name .. " already uses that trigger emote.")
      return false
    end
  end
  configuration.triggerEmote = emote
  return true
end

--- Set how many Augment Runes are traded as a single stack for the AUGMENT_RUNES mode.
-- Clamped to [1, 100] to keep the value sane for the options UI slider/input and to avoid
-- someone accidentally configuring an absurd or non-positive quantity that would then fail
-- every stack-preparation attempt.
-- @param value number|string requested rune quantity (string tolerated since options widgets
--   sometimes hand back text-box input).
function module:SetRuneQuantity(value)
  local configuration = modeConfiguration(VendorMode.AUGMENT_RUNES)
  if configuration then configuration.runeQuantity = math.max(1, math.min(100, tonumber(value) or 1)) end
end

--- Change which BIS data source (Wowhead/Icy Veins/Murlok M+) is used for gear/consumable
-- recommendations. Validates the key first so a bad/typo'd source never gets persisted,
-- which would otherwise silently break every subsequent recommendation lookup.
-- @param sourceKey string requested source key, any case.
-- @return boolean true if the source was valid and applied.
function module:SetSource(sourceKey)
  sourceKey = enhancementSourceKey(sourceKey)
  if not sourceKey then return false end
  db.profile.selfVendor.source = sourceKey
  log("Self Vendor source changed to " .. sourceKey)
  return true
end

function module:ClearQueue()
  local count = self.tradeQueue and #self.tradeQueue or 0
  self.tradeQueue = {}
  log("Self Vendor queue manually cleared; removed " .. count .. " entries")
  print("SlackHacks: cleared " .. count .. " player(s) from the Self Vendor queue.")
end

function module:HandleSlash(input)
  local command = strlower(strtrim(input or ""))
  local requestedSource = command:match("%s+(%S+)$")
  local sourceKey = requestedSource and enhancementSourceKey(requestedSource)
  if sourceKey then
    command = strtrim(command:sub(1, #command - #requestedSource))
    self:SetSource(sourceKey)
  end
  local mode = modeForCommand(command)
  if mode then
    if not db.profile.selfVendor.enabled then
      print("SlackHacks: Self Vendor is disabled.")
      return
    end
    local targetName = UnitName("target")
    if not targetName or not senderIsEligible(targetName) then
      print("SlackHacks: target an eligible group, raid, or guild member first.")
      return
    end
    if not modeConfiguration(mode).enabled then
      print("SlackHacks: " .. SELF_VENDOR_MODES[mode].name .. " is disabled.")
      return
    end
    self:BeginEmoteTrade(targetName, mode)
  elseif command == "mode" then
    print("Usage: /slack vendor [consumablesmissing|consumables|flaskandoil|oil|augmentrunes|augments|vantusrune] [wowhead|icyveins|murlok]")
  elseif command == "toggle" then
    self:SetEnabled(not db.profile.selfVendor.enabled)
    print("SlackHacks Self Vendor: " .. (db.profile.selfVendor.enabled and "ON" or "OFF"))
  elseif command == "clearqueue" then
    self:ClearQueue()
  else
    print("Usage: /slack vendor [toggle|clearqueue|consumablesmissing|consumables|flaskandoil|oil|augmentrunes|augments|vantusrune] [wowhead|icyveins|murlok]")
  end
end

function module:OnInitialize()
  if not enhancementSourceKey(db.profile.selfVendor.source) then
    db.profile.selfVendor.source = DEFAULT_ENHANCEMENT_SOURCE
  end
  log("Self Vendor initialized; enabled=" .. tostring(db.profile.selfVendor.enabled))
  if not db.profile.selfVendor.enabled then self:Disable() end
end

function module:OnEnable()
  log("Self Vendor enabled; registering events")
  self:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
  self:RegisterEvent("TRADE_SHOW")
  self:RegisterEvent("INSPECT_READY")
  self:RegisterEvent("UI_INFO_MESSAGE")
  self:RegisterEvent("TRADE_ACCEPT_UPDATE")
  self:RegisterEvent("TRADE_CLOSED")
  self:RegisterEvent("TRADE_REQUEST_CANCEL")
end

function module:OnDisable()
  log("Self Vendor disabled; unregistering events")
  self.pendingBagUpdate = nil
  self.pendingMode = nil
  self.pendingEmote = nil
  self.pendingTradeInitiated = nil
  self.activeTradeName = nil
  self.activeTradeMode = nil
  self.activeTradeEmote = nil
  self.tradeAccepted = nil
  self.tradeSucceeded = nil
  self.tradeCanceled = nil
  self.tradeQueue = {}
  self:UnregisterAllEvents()
end

function module:PollPreparedStack(bag, slot, itemID, quantity, onSuccess, onFailure)
  local delay = 0.1
  local function check()
    if not self.pendingName then return end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local actualItemID = itemIDFromInfo(info)
    local actualQuantity = info and info.stackCount or 0
    log("Prepared stack poll: expectedItem=" .. itemID .. ", actualItem=" .. tostring(actualItemID) .. ", expectedQuantity=" .. quantity .. ", actualQuantity=" .. actualQuantity .. ", nextDelay=" .. delay)
    if actualItemID == itemID and actualQuantity == quantity then
      onSuccess()
      return
    end
    if delay >= 3 then
      log("Prepared stack did not reach the expected quantity after polling")
      onFailure()
      return
    end
    delay = math.min(delay + 0.1, 3)
    C_Timer.After(delay, check)
  end
  C_Timer.After(delay, check)
end

function module:NotifyTradeUnavailable(name)
  if not name then return end
  SendChatMessage("You're too far away to trade with me. Move closer and I'll try again.", "WHISPER", nil, name)
  TargetUnit(name)
  DoEmote("BECKON", name)
end

local TRADE_INTERACT_DISTANCE = 2

local function inTradeRange(unit)
  return unit and CheckInteractDistance(unit, TRADE_INTERACT_DISTANCE)
end

function module:FailPendingTrade(message)
  self:NotifyTradeUnavailable(self.pendingName)
  log("Self Vendor failed: " .. message)
  if message then print("SlackHacks: " .. message) end
  self.pendingName = nil
  self.pendingUnit = nil
  self.pendingRequired = nil
  self.pendingTradeItems = nil
  self.pendingTradeIndex = nil
  self.pendingTradeInitiated = nil
  self.inspectGUID = nil
  self.pendingMode = nil
  self.pendingEmote = nil
  self:StartNextQueuedTrade()
end

function module:ReportMissingItems(shortages)
  if self.pendingName then
    DoEmote("SORRY", self.pendingName)
    SendChatMessage("Sorry, I'm missing these items and need to restock:", "WHISPER", nil, self.pendingName)
    for itemID, quantity in pairs(shortages) do
      SendChatMessage(shoppingListItem(itemID, quantity), "WHISPER", nil, self.pendingName)
    end
  end
  log("Self Vendor trade blocked because required items are missing")
  self.pendingName = nil
  self.pendingUnit = nil
  self.pendingRequired = nil
  self.pendingTradeItems = nil
  self.pendingTradeIndex = nil
  self.pendingTradeInitiated = nil
  self.inspectGUID = nil
  self.pendingMode = nil
  self.pendingEmote = nil
  self:StartNextQueuedTrade()
end

local function queuePositionFor(queue, name)
  if not queue then return nil end
  for index, entry in ipairs(queue) do
    if sameName(entry.name, name) then return index end
  end
end

-- A name should never be both actively serviced and sitting in the waiting array; purge stray duplicates whenever we notice one
local function removeQueueEntries(queue, name)
  if not queue then return end
  for index = #queue, 1, -1 do
    if sameName(queue[index].name, name) then table.remove(queue, index) end
  end
end

-- Enqueue immediately so the player holds a queue position before any async work (inspect, bag checks) begins
function module:BeginEmoteTrade(sender, mode, emoteToken)
  self.tradeQueue = self.tradeQueue or {}
  local label = requestLabel(mode, emoteToken)
  if sameName(self.pendingName, sender) or sameName(self.activeTradeName, sender) then
    removeQueueEntries(self.tradeQueue, sender)
    print("SlackHacks: " .. sender .. " is already being serviced.")
    log(tostring(sender) .. " emoted again (" .. label .. ") while already being serviced; ignoring duplicate")
    return
  end
  local existingPosition = queuePositionFor(self.tradeQueue, sender)
  if existingPosition then
    SendChatMessage("You're already in the queue at position #" .. existingPosition .. ". Please stand still close to me and I'll auto-trade with you as soon as I can.", "WHISPER", nil, sender)
    print("SlackHacks: " .. sender .. " is already in the Self Vendor queue (position #" .. existingPosition .. ").")
    log(tostring(sender) .. " emoted again (" .. label .. ") while already queued at position " .. existingPosition)
    return
  end
  table.insert(self.tradeQueue, { name = sender, mode = mode, emote = emoteToken })
  if self.pendingName or self.activeTradeName then
    local currentName = self.activeTradeName or self.pendingName
    local position = #self.tradeQueue
    SendChatMessage("I'm busy servicing " .. currentName .. " at the moment. You're position #" .. position .. " in the queue. Please stand still close to me and I'll auto-trade with you as soon as I can.", "WHISPER", nil, sender)
    print("SlackHacks: " .. sender .. " joined the Self Vendor queue requesting " .. label .. " (" .. position .. " in queue).")
    log("Added " .. sender .. " to the Self Vendor queue requesting " .. label .. "; queue size=" .. position)
    return
  end
  self:StartNextQueuedTrade()
end

function module:CHAT_MSG_TEXT_EMOTE(_, message, sender, languageName, channelName, target, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, senderGUID)
  log("Text emote received: message=" .. tostring(message) .. ", sender=" .. tostring(sender) .. ", target=" .. tostring(target) .. ", language=" .. tostring(languageName) .. ", channel=" .. tostring(channelName) .. ", senderGUID=" .. tostring(senderGUID))
  if not senderIsEligible(sender) then
    log("Ignoring text emote because sender is not eligible")
    return
  end
  if not message then
    log("Ignoring text emote because it has no message text")
    return
  end
  local emoteToken = emoteForTargetedMessage(message:lower())
  if not emoteToken then
    log("Ignoring text emote because it does not match a configured target-emote pattern")
    return
  end
  for mode, details in pairs(SELF_VENDOR_MODES) do
    local configuration = modeConfiguration(mode)
    if configuration and configuration.enabled and configuration.triggerEmote == emoteToken then
      log("Matching " .. details.name .. " trigger received from " .. tostring(sender))
      self:BeginEmoteTrade(sender, mode, emoteToken)
      return
    end
  end
  log("Ignoring text emote because it does not match an enabled trigger")
end

function module:INSPECT_READY(_, guid)
  log("Inspect ready received: guid=" .. tostring(guid) .. ", expected=" .. tostring(self.inspectGUID))
  if self.inspectGUID ~= guid or not self.pendingName then
    log("Ignoring inspect result because it does not match the pending trade")
    return
  end
  self.inspectGUID = nil
  self:CheckAndInitiateTrade()
end

function module:TRADE_SHOW()
  log("Trade window shown; pending player=" .. tostring(self.pendingName))
  if not self.pendingName then return end
  self:OpenPendingTrade()
end

function module:UI_INFO_MESSAGE(_, _, message)
  if not self.pendingName or not message then return end
  local lowerMessage = message:lower()
  if not lowerMessage:find("too far", 1, true) and not lowerMessage:find("out of range", 1, true) then return end
  log("Trade target is out of range; notifying " .. self.pendingName)
  self:NotifyTradeUnavailable(self.pendingName)
  self.pendingName = nil
  self.pendingUnit = nil
  self.pendingRequired = nil
  self.pendingTradeItems = nil
  self.pendingTradeIndex = nil
  self.pendingTradeInitiated = nil
  self.pendingMode = nil
  self.pendingEmote = nil
  self:StartNextQueuedTrade()
end

function module:TRADE_ACCEPT_UPDATE(_, playerAccepted, targetAccepted)
  -- playerAccepted/targetAccepted are 0/1 numbers, not booleans: 0 is truthy in Lua, so a raw
  -- `playerAccepted and targetAccepted` treats an all-zero (nobody has accepted yet) update as
  -- "both accepted" and marks the trade succeeded before anything actually happened.
  local playerReady = playerAccepted == 1
  local targetReady = targetAccepted == 1
  self.tradeAccepted = (playerReady and targetReady) or nil
  -- TRADE_SUCCEEDED is not a real client event; both parties accepting means the trade completed
  if self.tradeAccepted then
    self.tradeSucceeded = true
  end
end

function module:TRADE_REQUEST_CANCEL()
  self.tradeCanceled = true
  -- If InitiateTrade was already sent but the window never populated (target declined, timed
  -- out, out of range, etc.), TRADE_CLOSED never gets an activeTradeName to key off of, so this
  -- is the only reliable signal to fail the pending trade and move on to the next queued player.
  if self.pendingTradeInitiated and self.pendingName and not self.activeTradeName then
    self.pendingTradeInitiated = nil
    self:FailPendingTrade(self.pendingName .. "'s trade request was declined or timed out")
  end
end

function module:StartNextQueuedTrade()
  if not self.tradeQueue or #self.tradeQueue == 0 then return end
  local queuedTrade = table.remove(self.tradeQueue, 1)
  removeQueueEntries(self.tradeQueue, queuedTrade.name)
  self.activeTradeName = nil
  self.tradeAccepted = nil
  self.tradeSucceeded = nil
  self.tradeCanceled = nil
  self.pendingTradeInitiated = nil
  self.pendingName = queuedTrade.name
  self.pendingMode = queuedTrade.mode
  self.pendingEmote = queuedTrade.emote
  self.pendingUnit = groupUnitFor(queuedTrade.name)
  if not self.pendingUnit and sameName(UnitName("target"), queuedTrade.name) then self.pendingUnit = "target" end
  if queuedTrade.mode == VendorMode.AUGMENTS and self.pendingUnit then
    self.inspectGUID = UnitGUID(self.pendingUnit)
    NotifyInspect(self.pendingUnit)
  else
    self:CheckAndInitiateTrade()
  end
end

function module:TRADE_CLOSED()
  -- Blizzard fires TRADE_CLOSED twice when a trade is canceled from an open window. The first
  -- call below clears activeTradeName, so the ghost duplicate has nothing left to close; ignore
  -- it instead of re-running cleanup against whichever trade we've already moved on to.
  if not self.activeTradeName then return end
  local servicedName = self.activeTradeName
  local servicedLabel = requestLabel(self.activeTradeMode, self.activeTradeEmote)
  local successful = self.tradeSucceeded and not self.tradeCanceled
  self.activeTradeName = nil
  self.activeTradeMode = nil
  self.activeTradeEmote = nil
  self.tradeAccepted = nil
  self.tradeSucceeded = nil
  self.tradeCanceled = nil
  if successful then
    print("SlackHacks: finished servicing " .. servicedName .. " (" .. servicedLabel .. ").")
    log("Finished servicing " .. servicedName .. " (" .. servicedLabel .. ")")
  else
    self:NotifyTradeUnavailable(servicedName)
    print("SlackHacks: trade with " .. servicedName .. " (" .. servicedLabel .. ") did not complete.")
    log("Trade with " .. servicedName .. " did not complete; moving to next queued player")
  end
  -- Whether the trade succeeded or not, the rest of the queue is unaffected and should keep moving.
  self:StartNextQueuedTrade()
  local remaining = self.tradeQueue and #self.tradeQueue or 0
  if remaining > 0 then
    print("SlackHacks: " .. remaining .. " still in the Self Vendor queue.")
    log("Self Vendor queue has " .. remaining .. " remaining")
  else
    print("SlackHacks: Self Vendor queue is cleared.")
    log("Self Vendor queue cleared")
  end
end

local function modeIncludesGear(mode)
  return mode == VendorMode.AUGMENTS
end

local function modeIncludesConsumable(mode, kind)
  -- Vantus Runes are situational/per-raid, not part of the general "consumables" bundle.
  return mode == VendorMode.CONSUMABLES_MISSING and kind ~= "vantusRune"
    or mode == VendorMode.CONSUMABLES_ALL and kind ~= "vantusRune"
    or mode == VendorMode.CONSUMABLES_PERSISTENT and (kind == "flask" or kind == "oil")
    or mode == VendorMode.AUGMENT_RUNES and kind == "augmentRune"
    or mode == VendorMode.OIL and kind == "oil"
    or mode == VendorMode.VANTUS_RUNE and kind == "vantusRune"
end

function module:GetRequiredItems()
  local recommendationData, sourceKey = currentRecommendation(self.pendingUnit or "player", db.profile.selfVendor.source, self.pendingName)
  if not recommendationData then
    return nil, sourceKey
  end
  local required = {}
  local mode = self.pendingMode
  if modeIncludesGear(mode) then
    local equippedGemCounts = {}
    for _, slotKey in ipairs(recommendationData.slotKeys) do
      local slot = SLOT_IDS[slotKey]
      local link = self.pendingUnit and GetInventoryItemLink(self.pendingUnit, slot)
      local enchantID = link and inventoryEnchantID(self.pendingUnit, slot, link)
      local expectedEnchantID = recommendationData.enchantIDs[slotKey]
      if expectedEnchantID and enchantID ~= expectedEnchantID then
        addRequiredItem(required, expectedEnchantID)
      end
      if link then
        for gemIndex = 1, 3 do
          local gemLink = select(2, C_Item.GetItemGem(link, gemIndex))
          local gemID = gemLink and C_Item.GetItemInfoInstant(gemLink)
          if gemID and tContains(recommendationData.gemIDs, gemID) then
            equippedGemCounts[gemID] = (equippedGemCounts[gemID] or 0) + 1
          end
        end
      end
    end
    if self.pendingUnit then
      for _, gem in ipairs(recommendationData.gemEntries or {}) do
        local equippedQuantity = equippedGemCounts[gem.itemID] or 0
        local missingQuantity = (gem.quantity or 1) - equippedQuantity
        if missingQuantity > 0 then
          addRequiredItem(required, gem.itemID, missingQuantity)
        end
      end
    else
      for _, enchantID in pairs(recommendationData.enchantIDs) do
        addRequiredItem(required, enchantID)
      end
      for _, gem in ipairs(recommendationData.gemEntries or {}) do
        addRequiredItem(required, gem.itemID, gem.quantity)
      end
    end
  end
  for _, item in ipairs(recommendationData.consumables) do
    if modeIncludesConsumable(mode, item.kind) then
      local quantity = item.quantity
      if mode == VendorMode.AUGMENT_RUNES then
        quantity = modeConfiguration(VendorMode.AUGMENT_RUNES).runeQuantity
      end
      local hasBuff = mode == VendorMode.CONSUMABLES_MISSING
        and item.kind ~= "oil" and hasConsumableBuff(self.pendingUnit, item.buffName, item.auraSpellID)
      if item.kind == "oil" then
        log("Cannot verify Phoenix Oil on another player; temporary weapon enchant data is player-only")
      end
      if not hasBuff then
        addRequiredItem(required, item.itemID, quantity)
        log("Consumable needed: " .. itemName(item.itemID) .. " x" .. (quantity or 1))
      else
        log("Consumable already active; skipping " .. itemName(item.itemID))
      end
    end
  end
  return required, sourceKey
end

function module:CheckAndInitiateTrade()
  if not self.pendingName then
    log("Trade check skipped because there is no pending player")
    return
  end
  if self.pendingUnit and not inTradeRange(self.pendingUnit) then
    log(self.pendingName .. " is out of trade range; notifying and skipping")
    self:NotifyTradeUnavailable(self.pendingName)
    self.pendingName = nil
    self.pendingUnit = nil
    self.pendingRequired = nil
    self.pendingTradeItems = nil
    self.pendingTradeIndex = nil
    self.pendingMode = nil
    self.pendingEmote = nil
    self:StartNextQueuedTrade()
    return
  end
  log("Checking inventory for pending player " .. self.pendingName)
  local required, sourceKey = self:GetRequiredItems()
  if not required then
    print("SlackHacks: no " .. displayEnhancementSource(sourceKey or db.profile.selfVendor.source) .. " BIS data found for your current class/spec.")
    log("No BIS data found for pending player " .. self.pendingName .. "; clearing pending trade")
    self.pendingName = nil
    self.pendingUnit = nil
    self.pendingRequired = nil
    self.pendingTradeItems = nil
    self.pendingTradeIndex = nil
    self.pendingMode = nil
    self.pendingEmote = nil
    self:StartNextQueuedTrade()
    return
  end
  local shortages = {}
  for itemID, quantity in pairs(required) do
    local missing = quantity - bagItemCount(itemID)
    if missing > 0 then shortages[itemID] = missing end
  end
  if next(shortages) then
    self:ReportMissingItems(shortages)
    return
  end
  local augmentMode = self.pendingMode == VendorMode.AUGMENTS
  if augmentMode and not next(required) then
    DoEmote("IMPRESSED", self.pendingName)
    log("Augments already match for " .. self.pendingName)
    self.pendingName = nil
    self.pendingUnit = nil
    self.pendingRequired = nil
    self.pendingTradeItems = nil
    self.pendingTradeIndex = nil
    self.pendingMode = nil
    self.pendingEmote = nil
    self:StartNextQueuedTrade()
    return
  end
  log("Inventory check passed; preparing exact stacks before trade")
  self.pendingRequired = required
  self:PrepareTradeItems(required)
end

function module:PrepareTradeItems(required)
  local itemIDs = {}
  for itemID in pairs(required) do
    table.insert(itemIDs, itemID)
  end
  self.pendingTradeItems = itemIDs
  self.pendingTradeIndex = 1
  local itemIndex = 1
  local remaining = required[itemIDs[itemIndex]]
  local function prepareNextItem()
    if not self.pendingName then return end
    if itemIndex > #itemIDs then
      if self.pendingUnit and not inTradeRange(self.pendingUnit) then
        log(self.pendingName .. " moved out of trade range during item prep")
        self:FailPendingTrade(self.pendingName .. " moved out of trade range")
        return
      end
      log("Exact trade stacks prepared; initiating trade with " .. self.pendingName)
      self.pendingTradeInitiated = true
      InitiateTrade(self.pendingName)
      return
    end
    local itemID = itemIDs[itemIndex]
    local exactBag, exactSlot = findExactBagItem(itemID, remaining)
    if exactBag then
      itemIndex = itemIndex + 1
      remaining = required[itemIDs[itemIndex]]
      C_Timer.After(0.5, prepareNextItem)
      return
    end
    local bag, slot = findBagItem(itemID, remaining + 1)
    if not bag then
      self:FailPendingTrade("could not prepare " .. itemName(itemID) .. " for trade")
      return
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local stackCount = info and info.stackCount or 0
    if stackCount <= remaining then
      self:FailPendingTrade("could not find a stack larger than the requested " .. itemName(itemID) .. " quantity")
      return
    end
    local emptyBag, emptySlot = findEmptyBagSlot()
    if not emptyBag then
      log("Unable to prepare exact trade stacks because bags are full")
      self:FailPendingTrade("make room in your bags before trading Self Vendor items")
      return
    end
    if GetCursorInfo() then ClearCursor() end
    log("Splitting item " .. itemID .. " before trade: quantity=" .. remaining .. ", stack=" .. stackCount)
    C_Container.SplitContainerItem(bag, slot, remaining)
    if not GetCursorInfo() then
      self:FailPendingTrade("could not split " .. itemName(itemID) .. " to the requested quantity")
      return
    end
    C_Container.PickupContainerItem(emptyBag, emptySlot)
    if GetCursorInfo() then
      self:FailPendingTrade("could not place the split " .. itemName(itemID) .. " into an empty bag slot")
      return
    end
    log("Split stack placed in bag; starting quantity polling")
    self:PollPreparedStack(emptyBag, emptySlot, itemID, remaining, function()
      itemIndex = itemIndex + 1
      remaining = required[itemIDs[itemIndex]]
      C_Timer.After(0.5, prepareNextItem)
    end, function()
      self:FailPendingTrade("could not confirm the exact " .. itemName(itemID) .. " stack in your bags")
    end)
    return
  end
  prepareNextItem()
end

function module:OpenPendingTrade()
  if not self.pendingName then
    log("Trade population skipped because there is no pending player")
    return
  end
  log("Populating trade window for " .. self.pendingName)
  local required = self.pendingRequired or self:GetRequiredItems()
  local added = 0
  local tradeSlot = 1
  local itemIDs = self.pendingTradeItems or {}
  if #itemIDs == 0 then
    for itemID in pairs(required) do
      table.insert(itemIDs, itemID)
    end
    self.pendingTradeItems = itemIDs
  end
  local itemIndex = self.pendingTradeIndex or 1
  local remaining = required[itemIDs[itemIndex]]
  local function addNextItem()
    if itemIndex > #itemIDs then
      finishTradePopulation(self, added)
      return
    end
    if tradeSlot > maxTradeSlots then
      self.pendingTradeIndex = itemIndex
      print("SlackHacks: trade again to continue with the remaining Self Vendor items.")
      log("Trade window reached its six-slot limit; waiting for another trade")
      return
    end
    local itemID = itemIDs[itemIndex]
    local bag, slot = findExactBagItem(itemID, remaining)
    if not bag then
      self:FailPendingTrade("could not find an exact " .. itemName(itemID) .. " stack while populating trade")
      return
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local stackCount = info and info.stackCount or 0
    if stackCount <= 0 then
      self:FailPendingTrade("could not read the stack size for " .. itemName(itemID))
      return
    end
    if GetCursorInfo() then ClearCursor() end
    log("Adding exact item stack " .. itemID .. " to trade: quantity=" .. remaining .. ", tradeSlot=" .. tradeSlot)
    C_Container.PickupContainerItem(bag, slot)
    if not GetCursorInfo() then
      self:FailPendingTrade("could not pick up the exact " .. itemName(itemID) .. " stack")
      return
    end
    ClickTradeButton(tradeSlot)
    added = added + remaining
    tradeSlot = tradeSlot + 1
    itemIndex = itemIndex + 1
    self.pendingTradeIndex = itemIndex
    remaining = required[itemIDs[itemIndex]]
    C_Timer.After(0.5, addNextItem)
  end
  addNextItem()
end


