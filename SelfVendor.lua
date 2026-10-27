--[[
  SelfVendor.lua

  Lets players request scripted trades using item keywords in party, raid, instance, say, or
  whisper chat. Multiple keywords combine into one queued request. Requests can optionally be
  restricted to guild members (`selfVendor.guildOnly`). Automatic Trade Response
  (`selfVendor.autoTradeMode`, also set via `/slack vend <mode>`) vends a fixed mode to anyone who
  opens a trade with us, jumping the queue, independent of the chat request toggles.
  Combat clears all queued and active service state; vending only accepts new requests out of combat.

  Design decisions worth remembering:
  - Everything funnels through a FIFO queue (`self.tradeQueue`) so only one trade is ever
    prepared/opened at a time. WoW's trade window, bag manipulation, and item-splitting APIs
    are single-actor and asynchronous, so vending to multiple people concurrently would corrupt
    state (wrong items ending up in the wrong trade window).
  - We enqueue a requester *before* doing any async work (inspecting, bag polling) so their
    queue position is stable and can be reported back immediately, even though the inspect/bag
    checks that follow are asynchronous.
  - Item quantities are handled via C_Container.SplitContainerItem + polling rather than trusting
    an immediate stack read, because the client updates container info asynchronously after a
    split; polling with backoff (see PollPreparedStack) avoids racing the game's own item move.
  - Vantus Runes are intentionally excluded from the buffs/consumables bundle because they are
    per-raid-instance items you may not want handed out by
    default, unlike flasks/oils/augment runes which are always useful. They get their own mode
    instead.
]]

setfenv(1, _G.SlackHacks)

local module = Self:NewModule("SelfVendor", "AceEvent-3.0")
Self.SelfVendor = module
local maxTradeSlots = MAX_TRADABLE_ITEMS or 6
local VendorMode = Enum.SelfVendorMode

--- Report whether a value is secret and cannot be inspected by addon code.
-- @param value any value to test.
-- @return boolean true when the value is secret.
local function isSecret(value)
  return _G.issecretvalue and _G.issecretvalue(value) or false
end

--- Look up the saved-variable configuration table for a given vendor mode.
-- Centralized so every read/write of a mode's `enabled`/`runeQuantity`
-- goes through one place instead of repeating the `db.profile.selfVendor.modes[mode]` path.
-- @param mode number Enum.SelfVendorMode value.
-- @return table|nil the mode's profile configuration table, or nil if unknown.
local function modeConfiguration(mode)
  local details = SELF_VENDOR_MODES[mode]
  if details and details.flaskItemName then mode = VendorMode.FLASK end
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

local function requestIncludesMode(request, mode)
  return request == mode or type(request) == "table" and request[mode] == true
end

local function requestLabel(request)
  local labels = {}
  for mode, details in pairs(SELF_VENDOR_MODES) do
    if requestIncludesMode(request, mode) then labels[#labels + 1] = details.name end
  end
  table.sort(labels)
  return #labels > 0 and table.concat(labels, ", ") or "unknown request"
end

local chatRequestModes = {
  flask = VendorMode.FLASK, flasks = VendorMode.FLASK,
  crit = VendorMode.CRIT_FLASK, criticalstrike = VendorMode.CRIT_FLASK,
  critflask = VendorMode.CRIT_FLASK, criticalstrikeflask = VendorMode.CRIT_FLASK,
  mast = VendorMode.MASTERY_FLASK, mastery = VendorMode.MASTERY_FLASK,
  mastflask = VendorMode.MASTERY_FLASK, masteryflask = VendorMode.MASTERY_FLASK,
  haste = VendorMode.HASTE_FLASK, hasteflask = VendorMode.HASTE_FLASK,
  vers = VendorMode.VERSATILITY_FLASK, versatility = VendorMode.VERSATILITY_FLASK,
  versability = VendorMode.VERSATILITY_FLASK,
  versflask = VendorMode.VERSATILITY_FLASK, versatilityflask = VendorMode.VERSATILITY_FLASK,
  versabilityflask = VendorMode.VERSATILITY_FLASK,
  oil = VendorMode.OIL, oils = VendorMode.OIL,
  rune = VendorMode.AUGMENT_RUNES, runes = VendorMode.AUGMENT_RUNES,
  augmentrune = VendorMode.AUGMENT_RUNES, augmentrunes = VendorMode.AUGMENT_RUNES,
  vantus = VendorMode.VANTUS_RUNE, vantusrune = VendorMode.VANTUS_RUNE,
  vantusrunes = VendorMode.VANTUS_RUNE,
  buffs = VendorMode.CONSUMABLES,
  consumables = VendorMode.CONSUMABLES,
  augments = VendorMode.AUGMENTS,
}

local SELF_VENDOR_ALLOWED_WORDS = { "and", "give", "need", "please" }

--- Parse a chat message into the set of Self Vendor modes it requests.
-- Multi-word phrases ("vantus rune", "augment rune", "<stat> flask") are matched before single
-- words so the trailing word isn't also counted as its own request.
-- @param message string raw chat message text.
-- @return table|nil set of requested Enum.SelfVendorMode values (mode -> true), string|nil reason when nothing matched.
function module:ParseChatRequest(message)
  if InCombatLockdown() then return nil, "Self Vendor is paused during combat" end
  -- Secret strings still report type "string" but error on indexing (:sub, :lower, ...).
  if isSecret(message) then return nil, "message is secret" end
  if type(message) ~= "string" then return nil, "message is not text" end
  if not db.profile.selfVendor.enabled then return nil, "Self Vendor is disabled" end
  local settings = db.profile.selfVendor
  local prefix = settings.chatPrefix
  if not prefix or prefix == "" then prefix = "!" end
  local hasPrefix = message:sub(1, #prefix) == prefix
  if settings.requirePrefix and not hasPrefix then return nil, "required prefix is missing" end
  if hasPrefix then message = message:sub(#prefix + 1) end
  local words = {}
  for word in message:lower():gmatch("%w+") do
    words[#words + 1] = word
  end
  local requested = {}
  local wordIndex = 1
  while wordIndex <= #words do
    local word = words[wordIndex]
    local nextWord = words[wordIndex + 1]
    local mode = chatRequestModes[word]
    if (word == "vantus" or word == "augment") and (nextWord == "rune" or nextWord == "runes") then
      mode = word == "vantus" and VendorMode.VANTUS_RUNE or VendorMode.AUGMENT_RUNES
      wordIndex = wordIndex + 1
    end
    -- "crit flask" means one crit flask; without consuming "flask" it would also queue the generic
    -- Flask mode and hand out a second (spec-recommended) flask.
    local modeDetails = mode and SELF_VENDOR_MODES[mode]
    if modeDetails and modeDetails.flaskItemName and (nextWord == "flask" or nextWord == "flasks") then
      wordIndex = wordIndex + 1
    end
    if not mode and not tContains(SELF_VENDOR_ALLOWED_WORDS, word) then
      return nil, "unrecognized word: " .. word
    end
    local configuration = mode and modeConfiguration(mode)
    if configuration and configuration.enabled then requested[mode] = true end
    wordIndex = wordIndex + 1
  end
  if next(requested) then return requested end
  return nil, "no enabled item triggers matched"
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

local GROUP_CHAT_EVENTS = {
  CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true,
  CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
  CHAT_MSG_INSTANCE_CHAT = true, CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}

--- Determine whether a chat request sender should be vended to.
-- Group channels only accept group members; say/whisper accept anyone nearby. The optional
-- guild-only setting is applied on top of both.
-- @param event string chat event name that carried the request.
-- @param sender string sender name (with or without realm).
-- @return boolean true if eligible, string|nil reason when not eligible.
local function chatSenderIsEligible(event, sender)
  if GROUP_CHAT_EVENTS[event] and not groupUnitFor(sender) then
    return false, "sender is not in the group"
  end
  if db.profile.selfVendor.guildOnly and not guildMember(sender) then
    return false, "sender is not a guild member"
  end
  return true
end

--- Find a unit token currently pointing at the named player.
-- Say/whisper requesters usually aren't grouped, and InitiateTrade/CheckInteractDistance need a
-- real unit token, so fall back to target/focus/mouseover and then visible nameplates.
-- @param name string player name (with or without realm).
-- @return string|nil unit token, or nil if the player can't be resolved to a unit right now.
local function unitForName(name)
  local unit = groupUnitFor(name)
  if unit then return unit end
  -- "NPC" is the open trade window's partner, which covers strangers who opened a trade with us.
  for _, candidate in ipairs({ "target", "focus", "mouseover", "NPC" }) do
    if UnitIsPlayer(candidate) and sameName(UnitName(candidate), name) then return candidate end
  end
  for index = 1, 40 do
    local plate = "nameplate" .. index
    if UnitIsPlayer(plate) and sameName(UnitName(plate), name) then return plate end
  end
end

--- Ensure `module.pendingUnit` still refers to the pending player.
-- Nameplate/mouseover tokens are transient and can be reassigned to someone else while trade
-- items are being prepared asynchronously, so re-resolve whenever the token no longer matches.
-- @param module table the SelfVendor module.
local function refreshPendingUnit(module)
  if not module.pendingName then return end
  if module.pendingUnit and sameName(UnitName(module.pendingUnit), module.pendingName) then return end
  module.pendingUnit = unitForName(module.pendingName)
end

--- Check whether the trade window is currently open with the named player.
-- @param name string|nil player name (with or without realm).
-- @return boolean true if a trade window is open and its partner is that player.
local function tradeWindowOpenWith(name)
  if not name or not (TradeFrame and TradeFrame:IsShown()) then return false end
  return sameName(UnitName("NPC"), name)
end

--- Normalize a mode for Automatic Trade Response.
-- Specific stat flasks aren't offered; they collapse to the dynamic Flask mode, which picks the
-- flask from the selected Wowhead/Icy Veins source for the trade partner's spec.
-- @param mode number|nil Enum.SelfVendorMode value.
-- @return number|nil the mode to auto-trade, or nil if it isn't a known mode.
local function autoTradeModeFor(mode)
  local details = mode and SELF_VENDOR_MODES[mode]
  if not details then return nil end
  return details.flaskItemName and VendorMode.FLASK or mode
end

--- Read the configured Automatic Trade Response mode.
-- @return number|nil Enum.SelfVendorMode value to auto-trade, or nil when the feature is Off.
local function autoTradeMode()
  local mode = db.profile.selfVendor.autoTradeMode
  if mode and mode ~= 0 then return autoTradeModeFor(mode) end
end

--- Determine whether the module needs its events registered.
-- Automatic Trade Response works even when chat requests (the "Enable Self Vendor Module" toggle)
-- are off, so either one keeps the module active; ParseChatRequest still gates chat on `enabled`.
-- @return boolean true if chat requests or Automatic Trade Response are on.
local function moduleShouldBeActive()
  return db.profile.selfVendor.enabled or autoTradeMode() ~= nil
end

--- Combine two Self Vendor requests into one set request.
-- @param first table|number|nil request (Enum.SelfVendorMode value or set of values).
-- @param second table|number|nil request (Enum.SelfVendorMode value or set of values).
-- @return table set of every Enum.SelfVendorMode value included in either request.
local function mergeRequests(first, second)
  local merged = {}
  for mode in pairs(SELF_VENDOR_MODES) do
    if requestIncludesMode(first, mode) or requestIncludesMode(second, mode) then merged[mode] = true end
  end
  return merged
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
-- window) and the "trade in progress" phase tracked by UI_INFO_MESSAGE/TRADE_CLOSED. We
-- snapshot pendingName/pendingMode into activeTradeName/activeTradeMode
-- here (rather than leaving them in the pending* fields) so TRADE_CLOSED can
-- still report who/what was vended to even though the pending fields get cleared for the next
-- queued trade.
-- @param module table the SelfVendor module (passed explicitly since this is a local function,
--   not a method, so it can be called from contexts without `self`).
-- @param added number total item quantity actually placed into the trade window.
local function finishTradePopulation(module, added)
  if added == 0 then
    log("Trade population found no items to add")
    prn("no Self Vendor items found in your bags.")
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
  module.partnerOpenedTrade = nil
  module.activeTradeMode = module.pendingMode
  module.pendingMode = nil
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
-- Used only for the gear-focused `/slack sendaugs` mail flow (not the chat-trade flow, which
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
-- Used only for the CONSUMABLES mode, to decide whether an already-buffed target
-- still needs that particular consumable traded to them.
-- @param unit string|nil unit token to inspect; returns false immediately if nil (can't inspect,
--   e.g. no unit token available for the target of a manual request).
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
-- trade with — unlike the chat-trade flow, which requires the recipient to be in range.
-- Gated to isSlackwise() because this is a personal bulk-mailing tool, not a general feature.
-- @param input string command text after "sendaugs", e.g. "shaman enhancement wowhead" or
--   "Charname Realmname" for a personal override lookup.
function module:SendAugsForClassSpec(input)
  if InCombatLockdown() then
    prn("Self Vendor is paused during combat.")
    return
  end
  if not isSlackwise() then
    prn("unknown command.")
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
        prn("open the mail compose window first.")
        for itemID, quantity in pairs(shortages) do print(shoppingListItem(itemID, quantity)) end
        return
      end
      if next(shortages) then
        prn("missing items for " .. resolvedOverrideKey .. ":")
        for itemID, quantity in pairs(shortages) do print(shoppingListItem(itemID, quantity)) end
        return
      end
      local orderedIDs = sortedItemIDs(required)
      for mailIndex, itemID in ipairs(orderedIDs) do
        if mailIndex > 12 or not attachItemToMail(itemID, required[itemID], mailIndex) then
          prn("failed to attach items for " .. resolvedOverrideKey .. ".")
          return
        end
      end
      prn("BIS enchants and gems for " .. resolvedOverrideKey .. " have been added to the letter.")
      return
    end
  end
  local classKey, resolvedSpec = parseClassAndSpec(table.concat(tokens, " "))
  if not classKey or not resolvedSpec then
    prn("unknown class/spec for sendaugs: " .. strtrim(input or ""))
    print("Usage: /slack sendaugs <class> <spec> [wowhead|icyveins|murlok]")
    if isSlackwise() then prn("personal overrides use /slack sendaugs <character> <realm> [wowhead|icyveins|murlok]") end
    return
  end

  local sourceData = ENHANCEMENTS_BIS and ENHANCEMENTS_BIS[sourceKey]
  local classData = sourceData and sourceData[classKey]
  local specData = classData and classData[resolvedSpec]
  if not specData then
    prn("no " .. displayEnhancementSource(sourceKey) .. " BIS data found for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ".")
    return
  end

  local recommendationData = buildBISEnhancementRecommendation(specData, enhancementFlaskName(sourceKey, classKey, resolvedSpec))
  local required = buildRequiredForRecommendation(recommendationData)
  local shortages = missingListForRequired(required)

  if not mailFrameOpen() then
    prn("open the mail compose window first.")
    if next(shortages) then
      prn("buy these items from the auction house for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ":")
      for itemID, quantity in pairs(shortages) do
        print(shoppingListItem(itemID, quantity))
      end
    else
      prn("you already have everything needed for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ".")
    end
    return
  end

  if next(shortages) then
    prn("missing items for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. ":")
    for itemID, quantity in pairs(shortages) do
      print(shoppingListItem(itemID, quantity))
    end
    prn("buy the missing items from the auction house, then reopen the mail compose window.")
    return
  end

  local orderedIDs = sortedItemIDs(required)
  local mailCount = 0
  for _, itemID in ipairs(orderedIDs) do
    if mailCount >= 12 then break end
    local quantity = required[itemID]
    local bag, slot = findBagItem(itemID, quantity)
    if not bag or not slot then
      prn("unable to find " .. itemName(itemID) .. " x" .. quantity .. " in your bags.")
      return
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local stackCount = info and info.stackCount or 0
    if stackCount < quantity then
      prn("not enough " .. itemName(itemID) .. " in a single stack for mail.")
      return
    end
    if not attachItemToMail(itemID, quantity, mailCount + 1) then
      prn("failed to attach " .. itemName(itemID) .. " x" .. quantity .. " to the mail.")
      return
    end
    mailCount = mailCount + 1
  end

  prn("BIS enchants and gems for " .. displayClassName(classKey) .. " / " .. displaySpecName(resolvedSpec) .. " have been added to the letter.")
end

--- Toggle Self Vendor chat requests on/off (persisted setting + Ace3 Enable/Disable).
-- Delegates to AceAddon's Enable/Disable so OnEnable/OnDisable run their event
-- (un)registration side effects consistently, rather than duplicating that logic here. The module
-- stays enabled while Automatic Trade Response is on, since that works without chat requests.
-- @param enabled boolean whether Self Vendor chat requests should be accepted.
function module:SetEnabled(enabled)
  db.profile.selfVendor.enabled = enabled
  log("Self Vendor enabled state changed to " .. tostring(enabled))
  if moduleShouldBeActive() then self:Enable() else self:Disable() end
end

--- Set the Automatic Trade Response mode, which auto-trades that mode's items to anyone who opens a
-- trade with us, regardless of which mode checkboxes are enabled.
-- @param mode number|nil Enum.SelfVendorMode value, or 0/nil to turn the feature Off.
-- @return boolean true if the mode was valid and applied.
function module:SetAutoTradeMode(mode)
  mode = tonumber(mode) or 0
  if mode ~= 0 then
    mode = autoTradeModeFor(mode)
    if not mode then return false end
  end
  db.profile.selfVendor.autoTradeMode = mode
  log("Self Vendor Automatic Trade Response changed to " .. tostring(mode))
  if moduleShouldBeActive() then self:Enable() else self:Disable() end
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
  return true
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
  if not enabled then self:RemoveDisabledRequests() end
end

--- Remove disabled chat items from waiting and unfinished requests, preserving automatic trade items.
-- Automatic Trade Response is independent of the chat checkboxes; its selected mode is recorded
-- on each service so an interrupted/requeued automatic trade keeps that distinction.
function module:RemoveDisabledRequests()
  --- Retain enabled chat modes and the mode explicitly supplied by Automatic Trade Response.
  -- @param request table|number requested modes.
  -- @param automaticMode number|nil mode supplied by Automatic Trade Response.
  -- @return table|nil remaining modes, boolean whether any modes were removed.
  local function filter(request, automaticMode)
    local remaining, changed = {}, false
    for mode in pairs(SELF_VENDOR_MODES) do
      if requestIncludesMode(request, mode) then
        local configuration = modeConfiguration(mode)
        if mode == automaticMode or configuration and configuration.enabled then
          remaining[mode] = true
        else
          changed = true
        end
      end
    end
    return next(remaining) and remaining or nil, changed
  end

  self.tradeQueue = self.tradeQueue or {}
  for index = #self.tradeQueue, 1, -1 do
    local entry = self.tradeQueue[index]
    local remaining, changed = filter(entry.mode, entry.automaticMode)
    if changed then
      log("Removed disabled Self Vendor items from queued request for " .. entry.name)
      if remaining then entry.mode = remaining else table.remove(self.tradeQueue, index) end
    end
  end
  local name = self.activeTradeName or self.pendingName
  -- A closed trade has already finished; do not requeue items that may have been delivered.
  if name and not self.tradeClosing then
    local request = self.activeTradeName and self.activeTradeMode or self.pendingMode
    local remaining, changed = filter(request, self.serviceAutomaticMode)
    if changed then
      local automaticMode = self.serviceAutomaticMode
      self:CancelCurrentService()
      if remaining then
        table.insert(self.tradeQueue, 1, { name = name, mode = remaining, automaticMode = automaticMode })
      end
      log("Cancelled disabled Self Vendor items for " .. name)
      prn("updated Self Vendor request for " .. name .. " after disabling item triggers.")
      self:StartNextQueuedTrade()
    end
  end
  self:RefreshQueueWindow()
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

--- Stop vending to whoever is currently being vended to, without starting the next player.
-- Bumps `serviceToken` so in-flight bag prep, stack polling, and trade population callbacks for the
-- cancelled player stop, and closes any open trade window so it can't complete half-populated.
-- During combat only local state is cleared; trade and cursor APIs are left alone.
-- @param keepTradeOpen boolean|nil leave the trade window open (used when a different player opened
--   it with us and is about to be vended to through Automatic Trade Response).
-- @return string|nil name, table|number|nil request, number|nil Automatic Trade Response mode.
function module:CancelCurrentService(keepTradeOpen)
  local name = self.activeTradeName or self.pendingName
  local mode = self.activeTradeName and self.activeTradeMode or self.pendingMode
  local automaticMode = self.serviceAutomaticMode
  -- Invalidate callbacks even if the service has already lost its player name.
  self.serviceToken = (self.serviceToken or 0) + 1
  self.pendingName = nil
  self.pendingUnit = nil
  self.pendingMode = nil
  self.pendingRequired = nil
  self.pendingTradeItems = nil
  self.pendingTradeIndex = nil
  self.pendingTradeInitiated = nil
  self.partnerOpenedTrade = nil
  self.inspectGUID = nil
  self.activeTradeName = nil
  self.activeTradeMode = nil
  self.tradeAccepted = nil
  self.tradeSucceeded = nil
  self.tradeCanceled = nil
  self.tradeClosing = nil
  self.pendingBagUpdate = nil
  self.selfInitiatedTradeName = nil
  self.serviceAutomaticMode = nil
  -- Combat cleanup only discards local state; do not call protected trade or bag APIs.
  -- Reset state first because closing a trade can deliver additional trade events.
  if name and not InCombatLockdown() then
    if not keepTradeOpen and TradeFrame and TradeFrame:IsShown() then CloseTrade() end
    if GetCursorInfo() then ClearCursor() end
  end
  if name then log("Cancelled Self Vendor service for " .. name) end
  return name, mode, automaticMode
end

--- Clear the entire queue, including whoever is currently being vended to.
-- @param quiet boolean|nil suppress the local notification for automatic cleanup.
function module:ClearQueue(quiet)
  local count = self.tradeQueue and #self.tradeQueue or 0
  self.tradeQueue = {}
  if self:CancelCurrentService() then count = count + 1 end
  self:RefreshQueueWindow()
  log("Self Vendor queue cleared; removed " .. count .. " entries")
  if not quiet then prn("cleared " .. count .. " player(s) from the Self Vendor queue.") end
end

--- Resolve typed slash command text into an Automatic Trade Response mode.
-- Accepts chat request aliases ("vantus", "flask") and SELF_VENDOR_MODES commands ("vantusrune"),
-- with spaces ignored so "vantus rune" works as well. Stat flask words ("crit flask") resolve to
-- the dynamic Flask mode, since specific flasks aren't offered for Automatic Trade Response.
-- @param text string lower-cased mode text.
-- @return number|nil matching Enum.SelfVendorMode value.
local function modeForSlashText(text)
  local compact = text:gsub("%s+", "")
  return autoTradeModeFor(chatRequestModes[compact] or modeForCommand(compact))
end

--- Print usage for the `/slack vend <mode>` slash command, including the current mode.
local function printVendSlashUsage()
  local commands = {}
  for _, details in pairs(SELF_VENDOR_MODES) do
    if not details.flaskItemName then commands[#commands + 1] = details.command end
  end
  table.sort(commands)
  local mode = autoTradeMode()
  prn("Automatic Trade Response is " .. (mode and SELF_VENDOR_MODES[mode].name or "Off") .. ".")
  print("Usage: /slack vend <off|" .. table.concat(commands, "|") .. ">")
end

--- Handle `/slack vend <mode>` (also routed from `vendor` and `trade`): set the Automatic Trade
-- Response mode. Also accepts `toggle` (chat requests on/off) and `clearqueue`.
-- @param input string text after the slash command word.
function module:HandleSlash(input)
  local command = strlower(strtrim(input or ""))
  if command == "" then
    printVendSlashUsage()
  elseif command == "off" or command == "none" or command == "0" then
    self:SetAutoTradeMode(0)
    prn("Automatic Trade Response: Off")
  elseif command == "toggle" then
    self:SetEnabled(not db.profile.selfVendor.enabled)
    prn("Self Vendor: " .. (db.profile.selfVendor.enabled and "ON" or "OFF"))
  elseif command == "clearqueue" then
    self:ClearQueue()
  else
    local mode = modeForSlashText(command)
    if mode then
      self:SetAutoTradeMode(mode)
      prn("Automatic Trade Response: " .. SELF_VENDOR_MODES[autoTradeModeFor(mode)].name)
    else
      prn("unknown Self Vendor mode '" .. command .. "'.")
      printVendSlashUsage()
    end
  end
end

--- Initialize the module and track player-initiated trades outside combat.
function module:OnInitialize()
  if db.profile.selfVendor.source ~= "wowhead" and db.profile.selfVendor.source ~= "icyveins" then
    db.profile.selfVendor.source = "icyveins"
  end
  log("Self Vendor initialized; enabled=" .. tostring(db.profile.selfVendor.enabled) .. ", autoTradeMode=" .. tostring(db.profile.selfVendor.autoTradeMode))
  -- TRADE_SHOW fires for trades we open too; remember who we last opened one with so Automatic
  -- Trade Response only answers trades other players open with us, not our own manual trades.
  hooksecurefunc("InitiateTrade", function(unitOrName)
    if InCombatLockdown() then return end
    module.selfInitiatedTradeName = unitOrName and UnitName(unitOrName) or unitOrName
  end)
  if not moduleShouldBeActive() then self:Disable() end
end

-- Events that carry chat or UI message text, mapped to their handler method. Chat events stay registered
-- (outside combat) even when only Automatic Trade Response is on; ParseChatRequest rejects them while chat
-- requests are disabled.
local TEXT_EVENTS = {
  CHAT_MSG_PARTY = "CHAT_MSG_GROUP",
  CHAT_MSG_PARTY_LEADER = "CHAT_MSG_GROUP",
  CHAT_MSG_RAID = "CHAT_MSG_GROUP",
  CHAT_MSG_RAID_LEADER = "CHAT_MSG_GROUP",
  CHAT_MSG_INSTANCE_CHAT = "CHAT_MSG_GROUP",
  CHAT_MSG_INSTANCE_CHAT_LEADER = "CHAT_MSG_GROUP",
  CHAT_MSG_SAY = "CHAT_MSG_GROUP",
  CHAT_MSG_WHISPER = "CHAT_MSG_GROUP",
  UI_INFO_MESSAGE = "UI_INFO_MESSAGE",
}

--- Register or unregister the chat/UI message events.
-- They're dropped for the whole of combat rather than ignored inside the handlers: in combat (and
-- Mythic+/encounters on Midnight 12.0+) their text arrives as secret values, and simply receiving
-- them in addon code risks secret-value errors and spreads SlackHacks taint.
-- @param module table the SelfVendor module.
-- @param listen boolean true to register the events, false to unregister them.
local function setTextEventsRegistered(module, listen)
  for event, method in pairs(TEXT_EVENTS) do
    if listen then
      module:RegisterEvent(event, method)
    else
      module:UnregisterEvent(event)
    end
  end
end

--- Register vending and combat events, clearing stale work if enabled during combat.
function module:OnEnable()
  log("Self Vendor enabled; registering events")
  self:RegisterEvent("TRADE_SHOW")
  self:RegisterEvent("INSPECT_READY")
  self:RegisterEvent("TRADE_ACCEPT_UPDATE")
  self:RegisterEvent("TRADE_CLOSED")
  self:RegisterEvent("TRADE_REQUEST_CANCEL")
  self:RegisterEvent("GROUP_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.wasInGroup = IsInGroup()
  if InCombatLockdown() then
    self:PLAYER_REGEN_DISABLED()
  else
    setTextEventsRegistered(self, true)
  end
end

--- Discard all vending work at combat entry without interacting with chat, bags, or trades.
-- Saved settings remain unchanged; only new out-of-combat requests can start another service.
function module:PLAYER_REGEN_DISABLED()
  setTextEventsRegistered(self, false)
  self:ClearQueue(true)
end

--- Resume listening for chat requests and trade messages once combat ends.
function module:PLAYER_REGEN_ENABLED()
  setTextEventsRegistered(self, true)
end

--- Turn Automatic Trade Response Off after leaving a group, when that option is enabled.
-- Tracks the previous group state because GROUP_ROSTER_UPDATE fires for every roster change, not
-- just for leaving.
function module:GROUP_ROSTER_UPDATE()
  local inGroup = IsInGroup()
  local leftGroup = self.wasInGroup and not inGroup
  self.wasInGroup = inGroup
  if not leftGroup or not db.profile.selfVendor.autoTradeOffAfterGroup or not autoTradeMode() then return end
  log("Left group; turning Automatic Trade Response off")
  prn("left group; Automatic Trade Response turned Off.")
  self:SetAutoTradeMode(0)
end

--- Hide the queue, cancel pending work, and unregister module events.
function module:OnDisable()
  log("Self Vendor disabled; unregistering events")
  if self.queueFrame then self.queueFrame:Hide() end
  self.tradeQueue = {}
  self:CancelCurrentService()
  self:UnregisterAllEvents()
end

--- Poll a prepared stack until confirmed, failed, or its service is cancelled.
-- @param bag number container index.
-- @param slot number slot index.
-- @param itemID number expected item ID.
-- @param quantity number expected stack quantity.
-- @param onSuccess function callback when the stack matches.
-- @param onFailure function callback when polling times out.
function module:PollPreparedStack(bag, slot, itemID, quantity, onSuccess, onFailure)
  if InCombatLockdown() then return end
  local delay = 0.1
  local token = self.serviceToken
  local function check()
    if InCombatLockdown() then return end
    if self.serviceToken ~= token or not self.pendingName then return end
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

--- Whisper and beckon to an out-of-range player outside combat.
-- @param name string|nil requesting player name.
function module:NotifyTradeUnavailable(name)
  if InCombatLockdown() then return end
  if not name then return end
  SendChatMessage("You're too far away to trade with me. Move closer and I'll try again.", "WHISPER", nil, name)
  -- TargetUnit is protected (hardware-event only); DoEmote accepts the name directly instead.
  DoEmote("BECKON", name)
end

local TRADE_INTERACT_DISTANCE = 2

--- Test WoW's trade interaction range; index 2 identifies the interaction, not a distance.
-- @param unit string|nil unit token for the requester.
-- @return boolean|nil whether the unit is within trade range.
local function inTradeRange(unit)
  return unit and CheckInteractDistance(unit, TRADE_INTERACT_DISTANCE)
end

--- Report a failed pending trade and advance to the next queued player outside combat.
-- @param message string failure description.
-- @param outOfRange boolean|nil true only when a range check actually failed.
function module:FailPendingTrade(message, outOfRange)
  if InCombatLockdown() then return end
  if outOfRange then
    self:NotifyTradeUnavailable(self.pendingName)
  elseif self.pendingName then
    SendChatMessage("Sorry, I couldn't prepare or complete your Self Vendor trade. Please try again.", "WHISPER", nil, self.pendingName)
  end
  log("Self Vendor failed: " .. message)
  if message then prn(message) end
  self.pendingName = nil
  self.pendingUnit = nil
  self.pendingRequired = nil
  self.pendingTradeItems = nil
  self.pendingTradeIndex = nil
  self.pendingTradeInitiated = nil
  self.inspectGUID = nil
  self.pendingMode = nil
  self:StartNextQueuedTrade()
end

--- Notify the pending player about missing items and advance the queue outside combat.
-- @param shortages table map of item IDs to missing quantities.
function module:ReportMissingItems(shortages)
  if InCombatLockdown() then return end
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
  self:StartNextQueuedTrade()
end

local function queuePositionFor(queue, name)
  if not queue then return nil end
  for index, entry in ipairs(queue) do
    if sameName(entry.name, name) then return index end
  end
end

-- A name should never be both actively vended to and sitting in the waiting array; purge stray duplicates whenever we notice one
local function removeQueueEntries(queue, name)
  if not queue then return end
  for index = #queue, 1, -1 do
    if sameName(queue[index].name, name) then table.remove(queue, index) end
  end
end

--- Enqueue before asynchronous inspection and bag checks so the player's position is stable.
-- @param sender string requesting player name.
-- @param mode table|number requested vendor mode or set of modes.
function module:BeginChatTrade(sender, mode)
  if InCombatLockdown() then return end
  self.tradeQueue = self.tradeQueue or {}
  local label = requestLabel(mode)
  if sameName(self.pendingName, sender) or sameName(self.activeTradeName, sender) then
    removeQueueEntries(self.tradeQueue, sender)
    prn("already vending to " .. sender .. ".")
    log(tostring(sender) .. " requested again (" .. label .. ") while already being vended to; ignoring duplicate")
    return
  end
  local existingPosition = queuePositionFor(self.tradeQueue, sender)
  if existingPosition then
    SendChatMessage("You're already in the queue at position #" .. existingPosition .. ". Please stand still close to me and I'll auto-trade with you as soon as I can.", "WHISPER", nil, sender)
    prn(sender .. " is already in the Self Vendor queue (position #" .. existingPosition .. ").")
    log(tostring(sender) .. " requested again (" .. label .. ") while already queued at position " .. existingPosition)
    return
  end
  table.insert(self.tradeQueue, { name = sender, mode = mode })
  self:RefreshQueueWindow()
  if self.pendingName or self.activeTradeName then
    local currentName = self.activeTradeName or self.pendingName
    local position = #self.tradeQueue
    SendChatMessage("I'm busy vending to " .. currentName .. " at the moment. You're position #" .. position .. " in the queue. Please stand still close to me and I'll auto-trade with you as soon as I can.", "WHISPER", nil, sender)
    prn(sender .. " joined the Self Vendor queue requesting " .. label .. " (" .. position .. " in queue).")
    log("Added " .. sender .. " to the Self Vendor queue requesting " .. label .. "; queue size=" .. position)
    return
  end
  self:StartNextQueuedTrade()
end

--- Handle a potential Self Vendor request from group, say, or whisper chat.
-- @param event string chat event name.
-- @param message string chat message text.
-- @param sender string sender name (usually "Name-Realm").
function module:CHAT_MSG_GROUP(event, message, sender)
  if InCombatLockdown() then return end
  if not sender then return end
  -- During encounters and other restricted contexts (Midnight 12.0+), chat text and sender names
  -- arrive as secret values that error when indexed or compared, so requests can't be read then.
  if isSecret(message) or isSecret(sender) then
    log("Self Vendor ignored " .. event .. ": chat message or sender is secret (restricted context)")
    return
  end
  if sameName(sender, UnitName("player")) then return end
  local eligible, ineligibleReason = chatSenderIsEligible(event, sender)
  if not eligible then
    log("Self Vendor ignored " .. event .. " from " .. sender .. ": " .. ineligibleReason)
    return
  end
  local request, reason = self:ParseChatRequest(message)
  if request then
    log("Self Vendor accepted " .. event .. " from " .. sender .. ": " .. requestLabel(request))
    self:BeginChatTrade(sender, request)
  else
    log("Self Vendor ignored " .. event .. " from " .. sender .. ": " .. reason)
  end
end

--- Continue preparing the pending trade when its inspection completes outside combat.
-- @param _ string event name.
-- @param guid string inspected unit GUID.
function module:INSPECT_READY(_, guid)
  if InCombatLockdown() then return end
  log("Inspect ready received: guid=" .. tostring(guid) .. ", expected=" .. tostring(self.inspectGUID))
  if self.inspectGUID ~= guid or not self.pendingName then
    log("Ignoring inspect result because it does not match the pending trade")
    return
  end
  self.inspectGUID = nil
  self:CheckAndInitiateTrade()
end

--- Populate an out-of-combat trade or handle Automatic Trade Response.
function module:TRADE_SHOW()
  if InCombatLockdown() then return end
  local partner = UnitName("NPC")
  local selfInitiated = sameName(partner, self.selfInitiatedTradeName)
  self.selfInitiatedTradeName = nil
  log("Trade window shown; partner=" .. tostring(partner) .. ", pending player=" .. tostring(self.pendingName))
  if self.pendingName and (not partner or sameName(partner, self.pendingName)) then
    if self.pendingTradeInitiated then
      self:OpenPendingTrade()
    else
      -- They opened the trade before their items finished preparing; PrepareTradeItems populates
      -- this window once prep is done instead of initiating a second trade.
      self.partnerOpenedTrade = true
      log(self.pendingName .. " opened the trade before item prep finished; populating once ready")
    end
    return
  end
  -- Any other partner (including a late-opening trade from a player whose service was cancelled)
  -- only gets items through Automatic Trade Response; never load the pending requester's items
  -- into a different player's trade window.
  if partner and not selfInitiated and autoTradeMode() then
    self:BeginAutoTrade(GetUnitName("NPC", true) or partner)
    return
  end
  if self.pendingName then
    log("Trade partner " .. tostring(partner) .. " is not the pending player; leaving the trade window alone")
  end
end

--- Automatic Trade Response: vend the configured mode to a player who opened a trade with us.
-- They jump the queue: whoever was being vended to is interrupted and re-queued at #1, and any
-- request the partner already had queued is merged into this trade so they don't lose it.
-- @param partner string trade partner name (with realm when cross-realm).
function module:BeginAutoTrade(partner)
  if InCombatLockdown() then return end
  local mode = autoTradeMode()
  if not mode then return end
  if db.profile.selfVendor.guildOnly and not guildMember(partner) then
    log("Automatic Trade Response ignored " .. partner .. ": not a guild member")
    return
  end
  self.tradeQueue = self.tradeQueue or {}
  local position = queuePositionFor(self.tradeQueue, partner)
  local request = position and mergeRequests(self.tradeQueue[position].mode, mode) or mode
  removeQueueEntries(self.tradeQueue, partner)
  -- A trade that just closed is still settling (tradeClosing); it's finished, not interrupted.
  local finishing = self.tradeClosing
  local interruptedName, interruptedMode, interruptedAutomaticMode = self:CancelCurrentService(true)
  if interruptedName and not finishing then
    table.insert(self.tradeQueue, 1, { name = interruptedName, mode = interruptedMode, automaticMode = interruptedAutomaticMode })
    prn("interrupted " .. interruptedName .. " (re-queued at #1) for Automatic Trade Response.")
  end
  table.insert(self.tradeQueue, 1, { name = partner, mode = request, automaticMode = mode })
  prn("Automatic Trade Response: vending " .. requestLabel(request) .. " to " .. partner .. ".")
  log("Automatic Trade Response started for " .. partner .. " (" .. requestLabel(request) .. "); interrupted=" .. tostring(interruptedName))
  self:StartNextQueuedTrade()
end

--- Process trade completion and range notifications outside combat.
-- @param _ string event name (unused).
-- @param _ number message type (unused).
-- @param message string informational message.
function module:UI_INFO_MESSAGE(_, _, message)
  if InCombatLockdown() then return end
  -- Secret messages error when compared or indexed (restricted contexts such as Mythic+).
  if isSecret(message) then return end
  if message and message == ERR_TRADE_COMPLETE then
    if self.activeTradeName then
      self.tradeSucceeded = true
      log("Trade completion confirmed for " .. self.activeTradeName)
    end
    return
  end
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
  self:StartNextQueuedTrade()
end

--- Track trade acceptance outside combat.
-- @param _ string event name.
-- @param playerAccepted number player acceptance flag.
-- @param targetAccepted number partner acceptance flag.
function module:TRADE_ACCEPT_UPDATE(_, playerAccepted, targetAccepted)
  if InCombatLockdown() then return end
  local playerReady = playerAccepted == 1
  local targetReady = targetAccepted == 1
  self.tradeAccepted = (playerReady and targetReady) or nil
end

--- Handle a cancelled pending trade outside combat.
function module:TRADE_REQUEST_CANCEL()
  if InCombatLockdown() then return end
  self.tradeCanceled = true
  self.selfInitiatedTradeName = nil
  -- If InitiateTrade was already sent but the window never populated (target declined, timed
  -- out, out of range, etc.), TRADE_CLOSED never gets an activeTradeName to key off of, so this
  -- is the only reliable signal to fail the pending trade and move on to the next queued player.
  if self.pendingTradeInitiated and self.pendingName and not self.activeTradeName then
    self.pendingTradeInitiated = nil
    self:FailPendingTrade(self.pendingName .. "'s trade request was declined or timed out")
  end
end

--- Start vending to the next queued player, or refresh the queue window when nobody is left.
-- Every path that ends a trade funnels through here, so this is also where the window's
-- "Now vending to" row is kept in sync.
function module:StartNextQueuedTrade()
  if InCombatLockdown() then return end
  if not self.tradeQueue or #self.tradeQueue == 0 then
    self:RefreshQueueWindow()
    return
  end
  local queuedTrade = table.remove(self.tradeQueue, 1)
  removeQueueEntries(self.tradeQueue, queuedTrade.name)
  -- A failed Automatic Trade Response (missing items, bag errors) can leave the previous partner's
  -- trade window open; close it so the next player's InitiateTrade isn't blocked by it.
  if self.partnerOpenedTrade and not tradeWindowOpenWith(queuedTrade.name) and TradeFrame and TradeFrame:IsShown() then
    CloseTrade()
  end
  -- New service generation: any delayed callbacks still running for a previous service see the
  -- token change and stop instead of acting on this player.
  self.serviceToken = (self.serviceToken or 0) + 1
  self.activeTradeName = nil
  self.tradeAccepted = nil
  self.tradeSucceeded = nil
  self.tradeCanceled = nil
  self.pendingTradeInitiated = nil
  self.pendingName = queuedTrade.name
  self.pendingMode = queuedTrade.mode
  self.serviceAutomaticMode = queuedTrade.automaticMode
  -- Set when this player already has a trade window open with us (Automatic Trade Response), so
  -- item prep populates that window instead of initiating a new trade.
  self.partnerOpenedTrade = tradeWindowOpenWith(queuedTrade.name) or nil
  self:RefreshQueueWindow()
  self.pendingUnit = unitForName(queuedTrade.name)
  if requestIncludesMode(queuedTrade.mode, VendorMode.AUGMENTS) and self.pendingUnit then
    self.inspectGUID = UnitGUID(self.pendingUnit)
    NotifyInspect(self.pendingUnit)
  else
    self:CheckAndInitiateTrade()
  end
end

--- Schedule completion handling for an out-of-combat trade.
function module:TRADE_CLOSED()
  if InCombatLockdown() then return end
  if not self.activeTradeName and self.partnerOpenedTrade then
    -- The partner closed their trade before items were ready; once prep finishes we initiate a
    -- trade with them ourselves, like any queued request.
    self.partnerOpenedTrade = nil
    log("Trade closed before Self Vendor items were ready for " .. tostring(self.pendingName))
    return
  end
  if not self.activeTradeName or self.tradeClosing then return end
  self.tradeClosing = true
  -- The completion message can follow TRADE_CLOSED; keep this trade until its events settle.
  local token = self.serviceToken
  C_Timer.After(0.2, function()
    if self.serviceToken == token then self:FinishClosedTrade() end
  end)
end

--- Finish the closed trade and advance the queue outside combat.
function module:FinishClosedTrade()
  if InCombatLockdown() then return end
  if not self.tradeClosing or not self.activeTradeName then return end
  local servicedName = self.activeTradeName
  local servicedLabel = requestLabel(self.activeTradeMode)
  local successful = self.tradeSucceeded
  self.activeTradeName = nil
  self.activeTradeMode = nil
  self.tradeAccepted = nil
  self.tradeSucceeded = nil
  self.tradeCanceled = nil
  self.tradeClosing = nil
  if successful then
    prn("finished vending to " .. servicedName .. " (" .. servicedLabel .. ").")
    log("Finished vending to " .. servicedName .. " (" .. servicedLabel .. ")")
  else
    prn("trade with " .. servicedName .. " (" .. servicedLabel .. ") did not complete.")
    log("Trade with " .. servicedName .. " did not complete; moving to next queued player")
  end
  -- Whether the trade succeeded or not, the rest of the queue is unaffected and should keep moving.
  self:StartNextQueuedTrade()
  local remaining = self.tradeQueue and #self.tradeQueue or 0
  if remaining > 0 then
    prn(remaining .. " still in the Self Vendor queue.")
    log("Self Vendor queue has " .. remaining .. " remaining")
  else
    prn("Self Vendor queue is cleared.")
    log("Self Vendor queue cleared")
  end
end

local function modeIncludesGear(mode)
  return requestIncludesMode(mode, VendorMode.AUGMENTS)
end

local function modeIncludesConsumable(mode, kind)
  if type(mode) == "table" then
    for requestedMode in pairs(mode) do
      if modeIncludesConsumable(requestedMode, kind) then return true end
    end
    return false
  end
  -- Vantus Runes are situational/per-raid, not part of the general "consumables" bundle.
  return mode == VendorMode.CONSUMABLES and kind ~= "vantusRune"
    or mode == VendorMode.AUGMENT_RUNES and kind == "augmentRune"
    or mode == VendorMode.OIL and kind == "oil"
    or mode == VendorMode.FLASK and kind == "flask"
    or mode == VendorMode.VANTUS_RUNE and kind == "vantusRune"
end

function module:GetRequiredItems()
  local required = {}
  local mode = self.pendingMode
  local hasExplicitFlask = false
  for flaskMode, details in pairs(SELF_VENDOR_MODES) do
    if details.flaskItemName and requestIncludesMode(mode, flaskMode) then
      addRequiredItem(required, itemID(details.flaskItemName))
      hasExplicitFlask = true
    end
  end
  local needsRecommendation = modeIncludesGear(mode)
    or not hasExplicitFlask and modeIncludesConsumable(mode, "flask")
    or modeIncludesConsumable(mode, "oil")
    or modeIncludesConsumable(mode, "augmentRune")
    or modeIncludesConsumable(mode, "vantusRune")
  if not needsRecommendation then return required end
  local recommendationData, sourceKey = currentRecommendation(self.pendingUnit or "player", db.profile.selfVendor.source, self.pendingName)
  if not recommendationData then
    return nil, sourceKey
  end
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
    if modeIncludesConsumable(mode, item.kind) and not (hasExplicitFlask and item.kind == "flask") then
      local quantity = item.quantity
      if item.kind == "augmentRune" and requestIncludesMode(mode, VendorMode.AUGMENT_RUNES) then
        quantity = modeConfiguration(VendorMode.AUGMENT_RUNES).runeQuantity
      end
      local hasBuff = requestIncludesMode(mode, VendorMode.CONSUMABLES)
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

--- Check the pending player's range and inventory before preparing an out-of-combat trade.
function module:CheckAndInitiateTrade()
  if InCombatLockdown() then return end
  if not self.pendingName then
    log("Trade check skipped because there is no pending player")
    return
  end
  refreshPendingUnit(self)
  -- A player with an open trade window is already in range, even if no unit token resolves to them.
  if not self.partnerOpenedTrade and self.pendingUnit and not inTradeRange(self.pendingUnit) then
    log(self.pendingName .. " is out of trade range; notifying and skipping")
    self:NotifyTradeUnavailable(self.pendingName)
    self.pendingName = nil
    self.pendingUnit = nil
    self.pendingRequired = nil
    self.pendingTradeItems = nil
    self.pendingTradeIndex = nil
    self.pendingMode = nil
    self:StartNextQueuedTrade()
    return
  end
  log("Checking inventory for pending player " .. self.pendingName)
  local required, sourceKey = self:GetRequiredItems()
  if not required then
    prn("no " .. displayEnhancementSource(sourceKey or db.profile.selfVendor.source) .. " BIS data found for your current class/spec.")
    log("No BIS data found for pending player " .. self.pendingName .. "; clearing pending trade")
    self.pendingName = nil
    self.pendingUnit = nil
    self.pendingRequired = nil
    self.pendingTradeItems = nil
    self.pendingTradeIndex = nil
    self.pendingMode = nil
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
  local augmentMode = modeIncludesGear(self.pendingMode)
  if augmentMode and not next(required) then
    DoEmote("IMPRESSED", self.pendingName)
    log("Augments already match for " .. self.pendingName)
    self.pendingName = nil
    self.pendingUnit = nil
    self.pendingRequired = nil
    self.pendingTradeItems = nil
    self.pendingTradeIndex = nil
    self.pendingMode = nil
    self:StartNextQueuedTrade()
    return
  end
  log("Inventory check passed; preparing exact stacks before trade")
  self.pendingRequired = required
  self:PrepareTradeItems(required)
end

--- Prepare exact bag stacks for the pending trade, stopping on combat or cancellation.
-- @param required table map of item IDs to required quantities.
function module:PrepareTradeItems(required)
  if InCombatLockdown() then return end
  local itemIDs = {}
  for itemID in pairs(required) do
    table.insert(itemIDs, itemID)
  end
  self.pendingTradeItems = itemIDs
  self.pendingTradeIndex = 1
  local itemIndex = 1
  local remaining = required[itemIDs[itemIndex]]
  local token = self.serviceToken
  local function prepareNextItem()
    if InCombatLockdown() then return end
    if self.serviceToken ~= token or not self.pendingName then return end
    if itemIndex > #itemIDs then
      refreshPendingUnit(self)
      if self.partnerOpenedTrade and tradeWindowOpenWith(self.pendingName) then
        log("Exact trade stacks prepared; populating the trade window " .. self.pendingName .. " opened")
        self.pendingTradeInitiated = true
        self:OpenPendingTrade()
        return
      end
      if self.pendingUnit and not inTradeRange(self.pendingUnit) then
        log(self.pendingName .. " moved out of trade range during item prep")
        self:FailPendingTrade(self.pendingName .. " moved out of trade range", true)
        return
      end
      log("Exact trade stacks prepared; initiating trade with " .. self.pendingName)
      self.pendingTradeInitiated = true
      InitiateTrade(self.pendingUnit or self.pendingName)
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

--- Populate the pending trade with exact stacks, stopping on combat or cancellation.
function module:OpenPendingTrade()
  if InCombatLockdown() then return end
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
  local token = self.serviceToken
  local function addNextItem()
    if InCombatLockdown() then return end
    if self.serviceToken ~= token or not self.pendingName then return end
    if itemIndex > #itemIDs then
      finishTradePopulation(self, added)
      return
    end
    if tradeSlot > maxTradeSlots then
      self.pendingTradeIndex = itemIndex
      prn("trade again to continue with the remaining Self Vendor items.")
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

--=====================================================================
-- Queue window ("Self Vendor Queue")
--=====================================================================
-- A standard Blizzard bordered window (BasicFrameTemplateWithInset) showing who is currently being
-- vended to plus who's waiting, in order, and what they requested. There is no slash command for it:
-- it shows itself as soon as any request is being handled (even a single one with nobody waiting)
-- and hides itself once nobody is being vended to or waiting. Every row, including "Now vending to", has:
--   * a vend button: on a waiting row it vends to that player immediately (interrupting and
--     re-queueing whoever is being vended to at #1); on the "Now vending to" row it retries that player
--     from scratch, e.g. after they moved out of range or declined the trade.
--   * a close-style button to drop just that player (cancelling their trade if it's in progress).
-- Interrupting mid-trade is safe because CancelCurrentService bumps `serviceToken`, which every
-- async prep/poll/populate callback checks before acting.
-- Closing the window itself (its own CloseButton) clears the entire queue, including whoever is
-- currently being vended to, matching the "X" semantics used everywhere else in this addon.
-- The frame itself lives on `self.queueFrame` (not a file-local) so OnDisable, defined earlier in
-- this file, can still reach it to hide it when the module is turned off.

local MAX_QUEUE_ROWS = 10
local ROW_HEIGHT = 22
local TITLE_BAR_HEIGHT = 30
local queueRows

local function ensureQueueFrame(module)
  local queueFrame = module.queueFrame
  if queueFrame then return queueFrame end
  queueFrame = CreateFrame("Frame", "SlackHacksSelfVendorQueueFrame", UIParent, "BasicFrameTemplateWithInset")
  module.queueFrame = queueFrame
  -- One extra row is reserved for the "Now vending to" entry above the waiting list.
  queueFrame:SetSize(300, TITLE_BAR_HEIGHT + 10 + (MAX_QUEUE_ROWS + 1) * ROW_HEIGHT)
  queueFrame:SetPoint("CENTER")
  queueFrame:SetFrameStrata("DIALOG")
  queueFrame:SetMovable(true)
  queueFrame:EnableMouse(true)
  queueFrame:RegisterForDrag("LeftButton")
  queueFrame:SetScript("OnDragStart", queueFrame.StartMoving)
  queueFrame:SetScript("OnDragStop", queueFrame.StopMovingOrSizing)
  queueFrame.TitleText:SetText("Self Vendor Queue")
  queueFrame.overflowText = queueFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  queueFrame.overflowText:SetPoint("BOTTOMLEFT", queueFrame, "BOTTOMLEFT", 10, 8)
  -- Closing the window clears the entire queue, including whoever is currently being vended to.
  queueFrame.CloseButton:HookScript("OnClick", function() module:ClearQueue() end)
  return queueFrame
end

--- Show a one-line tooltip for a queue row button, based on its `tooltipText` field.
-- @param button table the hovered button frame.
local function showQueueButtonTooltip(button)
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText(button.tooltipText)
  GameTooltip:Show()
end

--- Get or lazily create the queue window row at a given position.
-- @param module table the SelfVendor module.
-- @param index number 1-based row position in the window.
-- @return table the row frame, with `text`, `vendButton`, and `removeButton` children.
local function ensureQueueRow(module, index)
  local queueFrame = module.queueFrame
  queueRows = queueRows or {}
  local row = queueRows[index]
  if row then return row end
  row = CreateFrame("Frame", nil, queueFrame)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", queueFrame, "TOPLEFT", 10, -TITLE_BAR_HEIGHT - (index - 1) * ROW_HEIGHT)
  row:SetPoint("RIGHT", queueFrame, "RIGHT", -10, 0)
  row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.text:SetPoint("RIGHT", row, "RIGHT", -40, 0)
  row.text:SetJustifyH("LEFT")
  row.removeButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
  row.removeButton:SetSize(18, 18)
  row.removeButton:SetPoint("RIGHT", row, "RIGHT", 4, 0)
  row.removeButton:SetScript("OnClick", function() module:RemoveFromQueue(row.name) end)
  row.removeButton:SetScript("OnEnter", showQueueButtonTooltip)
  row.removeButton:SetScript("OnLeave", GameTooltip_Hide)
  row.vendButton = CreateFrame("Button", nil, row)
  row.vendButton:SetSize(16, 16)
  row.vendButton:SetPoint("RIGHT", row.removeButton, "LEFT", -2, 0)
  row.vendButton:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
  row.vendButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  row.vendButton:SetScript("OnClick", function() module:VendNow(row.name) end)
  row.vendButton:SetScript("OnEnter", showQueueButtonTooltip)
  row.vendButton:SetScript("OnLeave", GameTooltip_Hide)
  queueRows[index] = row
  return row
end

--- Show/hide the queue window to match whether anyone is being vended to or waiting, and redraw its rows.
-- Called after every queue mutation (enqueue, dequeue, manual removal, clear) and whenever a trade
-- starts or ends, so the window is always in sync without any slash command driving it.
function module:RefreshQueueWindow()
  if InCombatLockdown() then
    if self.queueFrame then self.queueFrame:Hide() end
    return
  end
  local queue = self.tradeQueue or {}
  local currentName = self.activeTradeName or self.pendingName
  local currentMode = self.activeTradeName and self.activeTradeMode or self.pendingMode
  if #queue == 0 and not currentName then
    if self.queueFrame then self.queueFrame:Hide() end
    return
  end
  local queueFrame = ensureQueueFrame(self)
  if not queueFrame:IsShown() then queueFrame:Show() end
  local rowIndex = 0
  if currentName then
    rowIndex = 1
    local row = ensureQueueRow(self, rowIndex)
    row.name = currentName
    row.text:SetText("|cff00ff00Now vending to:|r  " .. currentName .. " - " .. requestLabel(currentMode))
    row.vendButton.tooltipText = "Retry vending to " .. currentName
    row.removeButton.tooltipText = "Stop vending to " .. currentName .. " and remove them"
    row:Show()
  end
  local shown = math.min(#queue, MAX_QUEUE_ROWS)
  for index = 1, shown do
    local entry = queue[index]
    rowIndex = rowIndex + 1
    local row = ensureQueueRow(self, rowIndex)
    row.name = entry.name
    row.text:SetText("#" .. index .. "  " .. entry.name .. " - " .. requestLabel(entry.mode))
    row.vendButton.tooltipText = "Vend to " .. entry.name .. " now"
    row.removeButton.tooltipText = "Remove " .. entry.name .. " from the queue"
    row:Show()
  end
  for index = rowIndex + 1, (queueRows and #queueRows or 0) do
    queueRows[index]:Hide()
  end
  queueFrame.overflowText:SetText(#queue > MAX_QUEUE_ROWS and ("+" .. (#queue - MAX_QUEUE_ROWS) .. " more waiting") or "")
end

--- Drop a single named player from the queue (used by each row's own close button).
-- If that player is currently being vended to, their trade is cancelled and the next queued
-- player is started.
-- @param name string player name as stored in the tradeQueue entry or the current trade.
function module:RemoveFromQueue(name)
  if InCombatLockdown() then return end
  if not name then return end
  local vendingTo = sameName(name, self.activeTradeName or self.pendingName)
  if not vendingTo and not (self.tradeQueue and queuePositionFor(self.tradeQueue, name)) then return end
  removeQueueEntries(self.tradeQueue, name)
  if vendingTo then self:CancelCurrentService() end
  SendChatMessage("You've been removed from the Self Vendor queue.", "WHISPER", nil, name)
  prn("removed " .. name .. " from the Self Vendor queue.")
  log("Manually removed " .. name .. " from the Self Vendor queue via the queue window")
  if vendingTo then
    self:StartNextQueuedTrade()
  else
    self:RefreshQueueWindow()
  end
end

--- Vend to a listed player immediately, or retry the player currently being vended to.
-- Vending to a waiting player interrupts the current trade and puts that interrupted player back at
-- the front of the queue, so nobody loses their place.
-- @param name string player name shown in the queue window row.
function module:VendNow(name)
  if InCombatLockdown() then return end
  if not name then return end
  self.tradeQueue = self.tradeQueue or {}
  local entry
  if sameName(name, self.activeTradeName or self.pendingName) then
    local currentName, currentMode, automaticMode = self:CancelCurrentService()
    entry = { name = currentName, mode = currentMode, automaticMode = automaticMode }
    prn("retrying " .. currentName .. ".")
    log("Retrying Self Vendor trade for " .. currentName .. " via the queue window")
  else
    local position = queuePositionFor(self.tradeQueue, name)
    if not position then return end
    entry = table.remove(self.tradeQueue, position)
    local interruptedName, interruptedMode, automaticMode = self:CancelCurrentService()
    if interruptedName then
      table.insert(self.tradeQueue, 1, { name = interruptedName, mode = interruptedMode, automaticMode = automaticMode })
    end
    prn("vending to " .. entry.name .. " now.")
    log("Vending to " .. entry.name .. " out of order via the queue window; interrupted=" .. tostring(interruptedName))
  end
  removeQueueEntries(self.tradeQueue, entry.name)
  table.insert(self.tradeQueue, 1, entry)
  self:StartNextQueuedTrade()
end
