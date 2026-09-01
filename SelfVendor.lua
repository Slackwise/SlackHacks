setfenv(1, _G.SlackHacks)

local module = Self:NewModule("SelfVendor", "AceEvent-3.0")
Self.SelfVendor = module
local maxTradeSlots = MAX_TRADABLE_ITEMS or 6

local function itemID(itemName)
  return ITEM_NAMES and ITEM_NAMES[itemName]
end

local function enhancementSourceKey(rawSource)
  local sourceKey = strlower(rawSource or DEFAULT_ENHANCEMENT_SOURCE or "")
  return ENHANCEMENTS_BIS and ENHANCEMENTS_BIS[sourceKey] and sourceKey
end

local function displayEnhancementSource(sourceKey)
  local names = { wowhead = "Wowhead", icyveins = "Icy Veins", murlok = "Murlok M+" }
  return names[sourceKey] or sourceKey
end

local function enhancementFlaskName(sourceKey, classKey, specKey)
  if sourceKey ~= "murlok" then return nil end
  local classData = ENHANCEMENTS_BIS.icyveins and ENHANCEMENTS_BIS.icyveins[classKey]
  local specData = classData and classData[specKey]
  return specData and specData.Flask
end

local function enhancementOverrideForKey(key)
  if not key or not ENHANCEMENTS_BIS_OVERRIDES then return nil end
  for overrideKey, override in pairs(ENHANCEMENTS_BIS_OVERRIDES) do
    if overrideKey:lower() == key:lower() then return override, overrideKey end
  end
end

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

local function specNameForClass(classKey, rawSpec)
  local specKey = specKeyForName(rawSpec)
  for _, sourceData in pairs(ENHANCEMENTS_BIS or {}) do
    local classData = sourceData[classKey]
    if classData and classData[specKey] then return specKey end
  end
end

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
      { itemName = "Void-Touched Augment Rune", itemID = ITEM_NAMES["Void-Touched Augment Rune"], kind = "augmentRune", buffName = "Augmented", quantity = 5 }
    }
  }
end

local function senderIsEligible(name)
  return groupUnitFor(name) or guildMember(name)
end

local function currentRecommendation(unit, sourceKey, characterName)
  local _, classFile = UnitClass(unit or "player")
  local specIndex = GetSpecialization()
  local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
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

local function finishTradePopulation(module, added)
  if added == 0 then
    log("Trade population found no items to add")
    print("SlackHacks: no Self Vendor items found in your bags.")
  else
    log("Added " .. added .. " item entries to the trade window")
  end
  module.pendingName = nil
  module.pendingUnit = nil
  module.pendingRequired = nil
  module.pendingTradeItems = nil
  module.pendingTradeIndex = nil
end

local function itemName(itemID)
  return ITEM_NAMES_BY_ID[itemID] or ("Item " .. itemID)
end

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

local function missingListForRequired(required)
  local shortages = {}
  for itemID, quantity in pairs(required) do
    local missing = quantity - bagItemCount(itemID)
    if missing > 0 then shortages[itemID] = missing end
  end
  return shortages
end

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

local function shoppingListItem(itemID, quantity)
  local prefix = quantity > 1 and quantity .. "x " or ""
  return "- " .. prefix .. itemName(itemID)
end

local function mailFrameOpen()
  return SendMailFrame and SendMailFrame:IsShown()
end

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

local function addRequiredItem(required, itemID, quantity)
  if itemID then required[itemID] = (required[itemID] or 0) + (quantity or 1) end
end

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

function module:SetEnabled(enabled)
  db.profile.selfVendor.enabled = enabled
  log("Self Vendor enabled state changed to " .. tostring(enabled))
  if enabled then self:Enable() else self:Disable() end
end

function module:SetMode(mode)
  if mode == "buff" then mode = "consumable" end
  if mode == "consumable" then mode = "consumables" end
  if mode == "flaskoil" then mode = "flaskOil" end
  if mode ~= "everything" and mode ~= "augments" and mode ~= "consumables" and mode ~= "flaskOil" and mode ~= "runes" and mode ~= "oil" and mode ~= "flasks" then return end
  db.profile.selfVendor.mode = mode
  log("Self Vendor mode changed to " .. mode)
end

function module:SetSource(sourceKey)
  sourceKey = enhancementSourceKey(sourceKey)
  if not sourceKey then return false end
  db.profile.selfVendor.source = sourceKey
  log("Self Vendor source changed to " .. sourceKey)
  return true
end

function module:HandleSlash(input)
  local command = strlower(strtrim(input or ""))
  local requestedSource = command:match("%s+(%S+)$")
  local sourceKey = enhancementSourceKey(requestedSource)
  if sourceKey then
    command = strtrim(command:sub(1, #command - #requestedSource))
    self:SetSource(sourceKey)
  end
  local mode = command:match("^mode%s+(%S+)$") or command:match("^(everything)$") or command:match("^(augments)$") or command:match("^(buff)$") or command:match("^(consumable)$") or command:match("^(consumables)$") or command:match("^(flaskoil)$") or command:match("^(runes)$") or command:match("^(oil)$") or command:match("^(flasks)$")
  if mode == "everything" or mode == "augments" or mode == "buff" or mode == "consumable" or mode == "consumables" or mode == "flaskoil" or mode == "runes" or mode == "oil" or mode == "flasks" then
    self:SetMode(mode)
    if not db.profile.selfVendor.enabled then self:SetEnabled(true) end
    print("SlackHacks Self Vendor mode: " .. db.profile.selfVendor.mode .. " (" .. displayEnhancementSource(db.profile.selfVendor.source) .. ")")
  elseif command == "mode" then
    print("Usage: /slack vendor mode [everything|augments|consumables|flaskOil|runes|oil|flasks] [wowhead|icyveins|murlok]")
  elseif command == "" or command == "toggle" then
    self:SetEnabled(not db.profile.selfVendor.enabled)
    print("SlackHacks Self Vendor: " .. (db.profile.selfVendor.enabled and "ON" or "OFF"))
  else
    print("Usage: /slack vendor [toggle|mode everything|augments|consumables|flaskOil|runes|oil|flasks] [wowhead|icyveins|murlok]")
  end
end

function module:OnInitialize()
  if db.profile.selfVendor.mode == "gear" then
    db.profile.selfVendor.mode = "augments"
  elseif db.profile.selfVendor.mode == nil or db.profile.selfVendor.mode == "buff" or db.profile.selfVendor.mode == "consumable" then
    db.profile.selfVendor.mode = "consumables"
  end
  if not enhancementSourceKey(db.profile.selfVendor.source) then
    db.profile.selfVendor.source = DEFAULT_ENHANCEMENT_SOURCE
  end
  log("Self Vendor initialized; enabled=" .. tostring(db.profile.selfVendor.enabled) .. ", mode=" .. db.profile.selfVendor.mode)
  if not db.profile.selfVendor.enabled then self:Disable() end
end

function module:OnEnable()
  log("Self Vendor enabled; registering events")
  self:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
  self:RegisterEvent("TRADE_SHOW")
  self:RegisterEvent("INSPECT_READY")
end

function module:OnDisable()
  log("Self Vendor disabled; unregistering events")
  self.pendingBagUpdate = nil
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

function module:FailPendingTrade(message)
  if self.pendingName then
    DoEmote("CRY", self.pendingName)
  end
  log("Self Vendor failed: " .. message)
  if message then print("SlackHacks: " .. message) end
  self.pendingName = nil
  self.pendingUnit = nil
  self.pendingRequired = nil
  self.inspectGUID = nil
end

function module:ReportMissingItems(shortages)
  if self.pendingName then
    DoEmote("SORRY", self.pendingName)
  end
  log("Self Vendor trade blocked because required items are missing")
  print("SlackHacks: buy these items from the auction house:")
  for itemID, quantity in pairs(shortages) do
    print(shoppingListItem(itemID, quantity))
  end
  self.pendingName = nil
  self.pendingUnit = nil
  self.pendingRequired = nil
  self.pendingTradeItems = nil
  self.pendingTradeIndex = nil
  self.inspectGUID = nil
end

function module:CHAT_MSG_TEXT_EMOTE(_, message, sender, languageName, channelName, target, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, senderGUID)
  log("Text emote received: message=" .. tostring(message) .. ", sender=" .. tostring(sender) .. ", target=" .. tostring(target) .. ", language=" .. tostring(languageName) .. ", channel=" .. tostring(channelName) .. ", senderGUID=" .. tostring(senderGUID))
  if not db.profile.selfVendor.enabled then
    log("Ignoring text emote because Self Vendor is disabled")
    return
  end
  if not senderIsEligible(sender) then
    log("Ignoring text emote because sender is not eligible")
    return
  end
  local playerName = UnitName("player")
  local addressedToPlayer = target and sameName(target, playerName)
  if not addressedToPlayer and message then
    local lowerMessage = message:lower()
    addressedToPlayer = message:find(playerName, 1, true) ~= nil or lowerMessage:find("salutes you", 1, true) ~= nil
  end
  log("Text emote target check: player=" .. tostring(playerName) .. ", addressedToPlayer=" .. tostring(addressedToPlayer))
  if addressedToPlayer and message and message:lower():find("salute", 1, true) then
    log("Matching salute received from " .. tostring(sender))
    self.pendingName = sender
    self.pendingUnit = groupUnitFor(sender)
    if not self.pendingUnit and sameName(UnitName("target"), sender) then self.pendingUnit = "target" end
    if self.pendingUnit then
      self.inspectGUID = UnitGUID(self.pendingUnit)
      NotifyInspect(self.pendingUnit)
    else
      self:CheckAndInitiateTrade()
    end
  else
    log("Ignoring text emote because it was not a targeted salute")
  end
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

local function modeIncludesGear(mode)
  return mode == "everything" or mode == "augments"
end

local function modeIncludesConsumable(mode, kind)
  return mode == "everything" or mode == "consumables"
    or mode == "flaskOil" and (kind == "flask" or kind == "oil")
    or mode == "runes" and kind == "augmentRune"
    or mode == "oil" and kind == "oil"
    or mode == "flasks" and kind == "flask"
end

function module:GetRequiredItems()
  local recommendationData, sourceKey = currentRecommendation(self.pendingUnit or "player", db.profile.selfVendor.source, self.pendingName)
  if not recommendationData then
    return nil, sourceKey
  end
  local required = {}
  local mode = db.profile.selfVendor.mode
  if modeIncludesGear(mode) then
    for _, slotKey in ipairs(recommendationData.slotKeys) do
      local slot = SLOT_IDS[slotKey]
      local link = self.pendingUnit and GetInventoryItemLink(self.pendingUnit, slot)
      local enchantID = link and inventoryEnchantID(self.pendingUnit, slot, link)
      local expectedEnchantID = recommendationData.enchantIDs[slotKey]
      if expectedEnchantID and enchantID ~= expectedEnchantID then
        addRequiredItem(required, expectedEnchantID)
      end
      local hasMatchingGem = false
      if link then
        for gemIndex = 1, 3 do
          local gemLink = select(2, C_Item.GetItemGem(link, gemIndex))
          local gemID = gemLink and C_Item.GetItemInfoInstant(gemLink)
          if gemID and tContains(recommendationData.gemIDs, gemID) then
            hasMatchingGem = true
            break
          end
        end
      end
      if not hasMatchingGem and link then
        for _, gem in ipairs(recommendationData.gemEntries or {}) do
          addRequiredItem(required, gem.itemID, gem.quantity)
        end
      end
    end
    if not self.pendingUnit then
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
      local hasBuff = item.kind ~= "oil" and hasConsumableBuff(self.pendingUnit, item.buffName, item.auraSpellID)
      if item.kind == "oil" then
        log("Cannot verify Phoenix Oil on another player; temporary weapon enchant data is player-only")
      end
      if not hasBuff then
        addRequiredItem(required, item.itemID, item.quantity)
        log("Consumable needed: " .. itemName(item.itemID) .. " x" .. (item.quantity or 1))
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
  log("Checking inventory for pending player " .. self.pendingName)
  local required, sourceKey = self:GetRequiredItems()
  if not required then
    print("SlackHacks: no " .. displayEnhancementSource(sourceKey or db.profile.selfVendor.source) .. " BIS data found for your current class/spec.")
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
      log("Exact trade stacks prepared; initiating trade with " .. self.pendingName)
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


