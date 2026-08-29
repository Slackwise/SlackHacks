setfenv(1, _G.SlackHacks)

local module = Self:NewModule("SelfVendor", "AceEvent-3.0")
Self.SelfVendor = module

local function recommendation(enchantIDs, gemIDs, flaskID)
  return {
    slots = { 1, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 },
    enchantIDs = enchantIDs,
    gemIDs = gemIDs,
    consumables = {
      { itemID = flaskID, kind = "flask", buffName = "Flask" },
      { itemID = 243734, kind = "oil", buffName = "Thalassian Phoenix Oil" },
      { itemID = 259085, kind = "augmentRune", buffName = "Void-Touched Augment Rune", quantity = 5 }
    }
  }
end

local physicalDPS = recommendation({
  [1] = 244007, [3] = 243991, [5] = 243977, [6] = 244641,
  [7] = 244641, [8] = 243953, [9] = 243977, [10] = 243977,
  [11] = 243957, [12] = 243957, [16] = 273072, [17] = 273072
}, { 240967, 240898, 240908, 240892, 240918 }, 241322)

local casterDPS = recommendation({
  [1] = 244007, [3] = 244021, [5] = 243977, [6] = 244641,
  [7] = 244641, [8] = 243983, [9] = 243977, [10] = 243977,
  [11] = 243957, [12] = 243957, [16] = 244029, [17] = 244029
}, { 240967, 240892, 240908, 240900, 240918 }, 241324)

local healer = recommendation({
  [1] = 243951, [3] = 244021, [5] = 243977, [6] = 244641,
  [7] = 244641, [8] = 243983, [9] = 243977, [10] = 243977,
  [11] = 243987, [12] = 243987, [16] = 244029, [17] = 244029
}, { 240983, 240910, 240892, 240900 }, 241326)

local tank = recommendation({
  [1] = 243981, [3] = 243963, [5] = 243977, [6] = 244641,
  [7] = 244641, [8] = 244009, [9] = 243977, [10] = 243977,
  [11] = 244015, [12] = 244015, [16] = 243973, [17] = 243973
}, { 240983, 240894 }, 241324)

local function addSpecs(classFile, specs, data)
  for _, specName in ipairs(specs) do
    SelfVendorBIS[classFile .. ":" .. specName] = data
  end
  SelfVendorBIS[classFile] = SelfVendorBIS[classFile .. ":" .. specs[1]]
end

SelfVendorBIS = {}
addSpecs("DEATHKNIGHT", { "Blood" }, tank)
addSpecs("DEATHKNIGHT", { "Frost", "Unholy" }, physicalDPS)
addSpecs("DEMONHUNTER", { "Havoc", "Devourer" }, physicalDPS)
addSpecs("DEMONHUNTER", { "Vengeance" }, tank)
addSpecs("DRUID", { "Balance" }, casterDPS)
addSpecs("DRUID", { "Feral" }, physicalDPS)
addSpecs("DRUID", { "Guardian" }, tank)
addSpecs("DRUID", { "Restoration" }, healer)
addSpecs("EVOKER", { "Devastation", "Augmentation" }, casterDPS)
addSpecs("EVOKER", { "Preservation" }, healer)
addSpecs("HUNTER", { "Beast Mastery", "Marksmanship", "Survival" }, physicalDPS)
addSpecs("MAGE", { "Arcane", "Fire", "Frost" }, casterDPS)
addSpecs("MONK", { "Brewmaster" }, tank)
addSpecs("MONK", { "Mistweaver" }, healer)
addSpecs("MONK", { "Windwalker" }, physicalDPS)
addSpecs("PALADIN", { "Holy" }, healer)
addSpecs("PALADIN", { "Protection" }, tank)
addSpecs("PALADIN", { "Retribution" }, physicalDPS)
addSpecs("PRIEST", { "Discipline", "Holy" }, healer)
addSpecs("PRIEST", { "Shadow" }, casterDPS)
addSpecs("ROGUE", { "Assassination", "Outlaw", "Subtlety" }, physicalDPS)
addSpecs("SHAMAN", { "Elemental" }, casterDPS)
addSpecs("SHAMAN", { "Enhancement" }, physicalDPS)
addSpecs("SHAMAN", { "Restoration" }, healer)
addSpecs("WARLOCK", { "Affliction", "Demonology", "Destruction" }, casterDPS)
addSpecs("WARRIOR", { "Arms", "Fury" }, physicalDPS)
addSpecs("WARRIOR", { "Protection" }, tank)

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
  GuildRoster()
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

local function findBagItem(itemID)
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if itemIDFromInfo(info) == itemID then return bag, slot end
    end
  end
end

local function itemName(itemID)
  return C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
end

local function addRequiredItem(required, itemID, quantity)
  if itemID then required[itemID] = math.max(required[itemID] or 0, quantity or 1) end
end

local function hasConsumableBuff(unit, buffName)
  if not unit then return false end
  for index = 1, 40 do
    local name = UnitAura(unit, index, "HELPFUL")
    if name and name:lower():find(buffName:lower(), 1, true) then return true end
  end
  return false
end

function module:SetEnabled(enabled)
  db.profile.selfVendor.enabled = enabled
  if enabled then self:Enable() else self:Disable() end
end

function module:SetMode(mode)
  if mode == "buff" then mode = "consumable" end
  if mode ~= "gear" and mode ~= "consumable" then return end
  db.profile.selfVendor.mode = mode
end

function module:HandleSlash(input)
  local command = strlower(strtrim(input or ""))
  local mode = command:match("^mode%s+(%S+)$") or command:match("^(gear)$") or command:match("^(buff)$") or command:match("^(consumable)$")
  if mode == "gear" or mode == "buff" or mode == "consumable" then
    self:SetMode(mode)
    print("SlackHacks Self Vendor mode: " .. db.profile.selfVendor.mode)
  elseif command == "" or command == "toggle" then
    self:SetEnabled(not db.profile.selfVendor.enabled)
    print("SlackHacks Self Vendor: " .. (db.profile.selfVendor.enabled and "ON" or "OFF"))
  else
    print("Usage: /slack vendor [toggle|mode gear|mode consumable]")
  end
end

function module:OnInitialize()
  if db.profile.selfVendor.mode == nil or db.profile.selfVendor.mode == "buff" then
    db.profile.selfVendor.mode = "consumable"
  end
  if not db.profile.selfVendor.enabled then self:Disable() end
end

function module:OnEnable()
  self:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
  self:RegisterEvent("TRADE_SHOW")
  self:RegisterEvent("INSPECT_READY")
end

function module:OnDisable()
  self:UnregisterAllEvents()
end

function module:CHAT_MSG_TEXT_EMOTE(_, message, sender, _, _, target)
  if not db.profile.selfVendor.enabled or not senderIsEligible(sender) then return end
  local playerName = UnitName("player")
  local addressedToPlayer = target and sameName(target, playerName)
  if not addressedToPlayer and message then
    addressedToPlayer = message:find(playerName, 1, true) ~= nil
  end
  if addressedToPlayer and message and message:lower():find("salute", 1, true) then
    self.pendingName = sender
    self.pendingUnit = groupUnitFor(sender)
    if not self.pendingUnit and sameName(UnitName("target"), sender) then self.pendingUnit = "target" end
    if db.profile.selfVendor.mode == "gear" and self.pendingUnit then
      self.inspectGUID = UnitGUID(self.pendingUnit)
      NotifyInspect(self.pendingUnit)
    else
      self:CheckAndInitiateTrade()
    end
  end
end

function module:INSPECT_READY(_, guid)
  if self.inspectGUID ~= guid or not self.pendingName then return end
  self.inspectGUID = nil
  self:CheckAndInitiateTrade()
end

function module:TRADE_SHOW()
  if not self.pendingName then return end
  self:OpenPendingTrade()
end

function module:GetRequiredItems()
  local recommendationData = currentRecommendation(self.pendingUnit or "player")
  local required = {}
  if db.profile.selfVendor.mode == "gear" then
    for _, slot in ipairs(recommendationData.slots) do
      local link = self.pendingUnit and GetInventoryItemLink(self.pendingUnit, slot)
      local _, _, _, enchantID = link and GetInventoryItemEnchantInfo(self.pendingUnit, slot)
      local expectedEnchantID = recommendationData.enchantIDs[slot]
      if expectedEnchantID and enchantID ~= expectedEnchantID then
        addRequiredItem(required, expectedEnchantID)
      end
      local hasMatchingGem = false
      if link then
        for gemIndex = 1, 3 do
          local gemLink = select(1, GetItemGem(gemIndex, link))
          local gemID = gemLink and C_Item.GetItemInfoInstant(gemLink)
          if gemID and tContains(recommendationData.gemIDs, gemID) then
            hasMatchingGem = true
            break
          end
        end
      end
      if not hasMatchingGem and link then
        for _, gemID in ipairs(recommendationData.gemIDs) do
          addRequiredItem(required, gemID)
        end
      end
    end
    if not self.pendingUnit then
      for _, enchantID in pairs(recommendationData.enchantIDs) do
        addRequiredItem(required, enchantID)
      end
      for _, gemID in ipairs(recommendationData.gemIDs) do
        addRequiredItem(required, gemID)
      end
    end
  else
    for _, item in ipairs(recommendationData.consumables) do
      if not hasConsumableBuff(self.pendingUnit, item.buffName) then
        addRequiredItem(required, item.itemID, item.quantity)
      end
    end
  end
  return required
end

function module:CheckAndInitiateTrade()
  if not self.pendingName then return end
  local required = self:GetRequiredItems()
  local shortages = {}
  for itemID, quantity in pairs(required) do
    local missing = quantity - bagItemCount(itemID)
    if missing > 0 then shortages[itemID] = missing end
  end
  if next(shortages) then
    DoEmote("CRY", self.pendingName)
    print("SlackHacks: buy these items from the auction house:")
    for itemID, quantity in pairs(shortages) do
      print("- " .. itemName(itemID) .. " x" .. quantity)
    end
    self.pendingName = nil
    self.pendingUnit = nil
    self.inspectGUID = nil
    return
  end
  InitiateTrade(self.pendingName)
end

function module:OpenPendingTrade()
  if not self.pendingName then return end
  local required = self:GetRequiredItems()
  local uniqueItemIDs = {}
  for itemID in pairs(required) do
    uniqueItemIDs[itemID] = true
  end
  local added = 0
  for itemID in pairs(uniqueItemIDs) do
    for itemIndex = 1, required[itemID] do
      local bag, slot = findBagItem(itemID)
      if bag then
        C_TradeInfo.AddTradeItem(bag, slot)
        added = added + 1
      end
    end
  end
  if added == 0 then
    print("SlackHacks: no Self Vendor items found in your bags.")
  end
  self.pendingName = nil
  self.pendingUnit = nil
end


