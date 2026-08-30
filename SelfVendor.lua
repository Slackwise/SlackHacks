setfenv(1, _G.SlackHacks)

local module = Self:NewModule("SelfVendor", "AceEvent-3.0")
Self.SelfVendor = module
local maxTradeSlots = MAX_TRADABLE_ITEMS or 6

SelfVendorBIS = SelfVendorBIS or {}

local function itemID(itemName)
  return ITEM_IDS and ITEM_IDS[itemName]
end

local function shortName(name)
  return name and Ambiguate(name, "none")
end

local function sameName(left, right)
  return shortName(left) == shortName(right)
end

local function groupUnitFor(name)
  if sameName(UnitName("player"), name) then return "player" end
  for index = 1, GetNumGroupMembers() do
    local unit = IsInRaid() and "raid" .. index or "party" .. index
    if sameName(UnitName(unit), name) then return unit end
  end
end

local function guildMember(name)
  if not IsInGuild() then return false end
  if GuildRoster then
    GuildRoster()
  elseif C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
  else
    log("Guild membership check skipped because no guild roster API is available")
    return false
  end
  for index = 1, GetNumGuildMembers() do
    local memberName = GetGuildRosterInfo(index)
    if sameName(memberName, name) then return true end
  end
  return false
end

local function senderIsEligible(name)
  return groupUnitFor(name) or guildMember(name)
end

local function currentRecommendation(unit)
  local _, classFile = UnitClass(unit or "player")
  local specIndex = GetSpecialization()
  local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
  return SelfVendorBIS[classFile .. ":" .. (specName or "")] or SelfVendorBIS[classFile]
end

local function itemIDFromInfo(info)
  return info and (info.itemID or C_Item.GetItemInfoInstant(info.hyperlink))
end

local function inventoryEnchantID(unit, slot, link)
  if GetInventoryItemEnchantInfo then
    local _, _, _, enchantID = GetInventoryItemEnchantInfo(unit, slot)
    return enchantID
  end
  return link and tonumber(link:match("item:%d+:(%d+):"))
end

local function bagItemCount(itemID)
  local count = 0
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if itemIDFromInfo(info) == itemID then count = count + (info.stackCount or 0) end
    end
  end
  return count
end

local function findBagItem(itemID, minimumCount)
  local preferredBag, preferredSlot, preferredCount
  local fallbackBag, fallbackSlot, fallbackCount
  minimumCount = minimumCount or 1
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if itemIDFromInfo(info) == itemID then
        local stackCount = info.stackCount or 0
        if stackCount >= minimumCount and (not preferredCount or stackCount > preferredCount) then
          preferredBag, preferredSlot, preferredCount = bag, slot, stackCount
        elseif not fallbackCount or stackCount > fallbackCount then
          fallbackBag, fallbackSlot, fallbackCount = bag, slot, stackCount
        end
      end
    end
  end
  return preferredBag or fallbackBag, preferredSlot or fallbackSlot
end

local function findExactBagItem(itemID, quantity)
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if itemIDFromInfo(info) == itemID and info.stackCount == quantity then return bag, slot end
    end
  end
end

local function findEmptyBagSlot()
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      if not C_Container.GetContainerItemInfo(bag, slot) then return bag, slot end
    end
  end
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
  return ITEM_NAMES[itemID] or ("Item " .. itemID)
end

local function addRequiredItem(required, itemID, quantity)
  if itemID then required[itemID] = math.max(required[itemID] or 0, quantity or 1) end
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

function module:HandleSlash(input)
  local command = strlower(strtrim(input or ""))
  local mode = command:match("^mode%s+(%S+)$") or command:match("^(everything)$") or command:match("^(augments)$") or command:match("^(buff)$") or command:match("^(consumable)$") or command:match("^(consumables)$") or command:match("^(flaskoil)$") or command:match("^(runes)$") or command:match("^(oil)$") or command:match("^(flasks)$")
  if mode == "everything" or mode == "augments" or mode == "buff" or mode == "consumable" or mode == "consumables" or mode == "flaskoil" or mode == "runes" or mode == "oil" or mode == "flasks" then
    self:SetMode(mode)
    if not db.profile.selfVendor.enabled then self:SetEnabled(true) end
    print("SlackHacks Self Vendor mode: " .. db.profile.selfVendor.mode)
  elseif command == "mode" then
    print("Usage: /slack vendor mode [everything|augments|consumables|flaskOil|runes|oil|flasks]")
  elseif command == "" or command == "toggle" then
    self:SetEnabled(not db.profile.selfVendor.enabled)
    print("SlackHacks Self Vendor: " .. (db.profile.selfVendor.enabled and "ON" or "OFF"))
  else
    print("Usage: /slack vendor [toggle|mode everything|augments|consumables|flaskOil|runes|oil|flasks]")
  end
end

function module:OnInitialize()
  if db.profile.selfVendor.mode == "gear" then
    db.profile.selfVendor.mode = "augments"
  elseif db.profile.selfVendor.mode == nil or db.profile.selfVendor.mode == "buff" or db.profile.selfVendor.mode == "consumable" then
    db.profile.selfVendor.mode = "consumables"
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
    print("- " .. itemName(itemID) .. " x" .. quantity)
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
  local recommendationData = currentRecommendation(self.pendingUnit or "player")
  local required = {}
  local mode = db.profile.selfVendor.mode
  if modeIncludesGear(mode) then
    for _, slotName in ipairs(recommendationData.slotNames) do
      local slot = SLOT_IDS[slotName]
      local link = self.pendingUnit and GetInventoryItemLink(self.pendingUnit, slot)
      local enchantID = link and inventoryEnchantID(self.pendingUnit, slot, link)
      local expectedEnchantID = recommendationData.enchantIDs[slotName]
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
  return required
end

function module:CheckAndInitiateTrade()
  if not self.pendingName then
    log("Trade check skipped because there is no pending player")
    return
  end
  log("Checking inventory for pending player " .. self.pendingName)
  local required = self:GetRequiredItems()
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


