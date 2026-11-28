setfenv(1, _G.SlackHacks)
local module = Self:NewModule("InventoryLog", "AceEvent-3.0", "AceTimer-3.0")
Self.InventoryLog = module

module.ACTIONS = {}
for _, action in ipairs({ "Quest", "Looted", "Gathered", "Created", "Purchased", "Sold", "Auctioned", "Destroyed",
  "Banked", "Mailed", "Traded" }) do
  module.ACTIONS[#module.ACTIONS + 1] = { id = action, name = action }
end

local CORRELATION_SECONDS = 5
local ROW_HEIGHT = 28
local PAPER_ICON = "Interface\\Icons\\INV_Scroll_03"
local snapshot, pending, metadataCache = nil, {}, {}
local auctionRequests = {}
local bankOpen, guildBankOpen, tradeOpen = false, false, false
local loot, questRewards, tradeItems, outgoingMail = {}, {}, {}, {}
local questChoice, legacyAuctionLink, legacyAuctionRequest, outgoingMailRecipient
local lastCursorLink, gatheringUntil, gatheringKind, reconcileTimer
local window
local observing = false

--- Migrate the former Inventory checkbox and initialize standalone module settings.
---@param profile table Saved profile, including profiles from earlier v38 development builds.
function module:MigrateProfileSettings(profile)
  local config = profile.inventoryLog or {}
  profile.inventoryLog = config
  local inventory = rawget(profile, "inventory")
  local legacy = type(inventory) == "table" and rawget(inventory, "inventoryLogEnabled")
  if rawget(config, "enabled") == nil then config.enabled = legacy == true end
  if type(inventory) == "table" then inventory.inventoryLogEnabled = nil end
  if config.entriesToKeep == nil then config.entriesToKeep = 3000 end
  if config.actionsToLog == nil then config.actionsToLog = {} end
  config.actionsToLog.Unknown, config.actionsToLog.Used = nil, nil
end

--- Remove retired ledger filters while preserving history and unrelated filter choices.
---@param character table Saved character data, including earlier v38 development builds.
function module:MigrateCharacterSettings(character)
  character.inventoryLog = character.inventoryLog or {}
  local data = character.inventoryLog
  for _, field in ipairs({ "entries", "actions", "bindings", "categories" }) do
    data[field] = data[field] or {}
  end
  data.categories.special = nil
  data.actions.Unknown, data.actions.Used = nil, nil
  -- Resolve former Essentials through item metadata when the cache becomes available.
  for _, entry in ipairs(data.entries) do
    if entry.category == "special" then entry.category = nil end
  end
end

--- Return module settings, preserving choices made before the standalone section existed.
---@return table config Active profile's logging preferences.
function module:GetSettings()
  self:MigrateProfileSettings(Self.db.profile)
  return Self.db.profile.inventoryLog
end

--- Return the current character's ledger, independent of the active profile.
---@return table ledger Saved entries and filter selections.
local function ledger()
  return Self.db.char.inventoryLog
end

--- Report whether item logging is enabled for the current profile.
---@return boolean enabled Whether to observe inventory changes.
function module:IsLoggingEnabled()
  return self:GetSettings().enabled == true
end

--- Add quantities to an aggregate without losing the item's captured metadata.
---@param items table Aggregates indexed by exact item link.
---@param item table Item metadata, including its link.
---@param count number Quantity to add.
local function addItem(items, item, count)
  local existing = items[item.link]
  if not existing then
    existing = {}
    for key, value in pairs(item) do existing[key] = value end
    existing.count = 0
    items[item.link] = existing
  end
  existing.count = existing.count + count
end

--- Capture mail/trade attachments as inventory until the transaction actually succeeds.
---@param kind string "mail", "player", or "target".
---@return table items Attached items indexed by link.
local function attachments(kind)
  local items = {}
  for slot = 1, (kind == "mail" and (ATTACHMENTS_MAX_SEND or 12) or 6) do
    local link, count
    if kind == "mail" then
      link = GetSendMailItemLink and GetSendMailItemLink(slot)
      if link then count = select(4, GetSendMailItem(slot)) end
    elseif kind == "player" then
      link = GetTradePlayerItemLink and GetTradePlayerItemLink(slot)
      if link then count = select(3, GetTradePlayerItemInfo(slot)) end
    else
      link = GetTradeTargetItemLink and GetTradeTargetItemLink(slot)
      if link then count = select(3, GetTradeTargetItemInfo(slot)) end
    end
    if link and count and count > 0 then addItem(items, { link = link }, count) end
  end
  return items
end

--- Read a stable total of bags, equipped items, and uncommitted outgoing attachments.
---@return table state Totals, bag-slot identities, and visible bank quantities.
local function readInventory()
  local state = { items = {}, slots = {}, bank = {} }
  local playerBags = {}
  local lastBag = 0
  for _, bag in ipairs(Self.ListviewBag:GetInventoryBagIDs()) do
    lastBag = math.max(lastBag, bag)
    playerBags[bag] = true
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink then
        local key = info.hyperlink .. ":" .. tostring(info.isBound)
        local item = metadataCache[key]
        if not item then
          item = Self.ListviewBag:GetInventoryLogMetadata(bag, slot, info)
          if item.name then metadataCache[key] = item end
        end
        addItem(state.items, item, info.stackCount)
        state.slots[bag .. ":" .. slot] = { link = item.link, count = info.stackCount, item = item }
      end
    end
  end
  -- Equipped gear and bag containers are still owned; equipping them is not a gain or loss.
  for slot = 1, lastBag + 19 do
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if link then
      local old = snapshot and snapshot.items[link]
      addItem(state.items, old or Self.ListviewBag:GetInventoryLogMetadata(nil, nil,
        { hyperlink = link, isBound = true }),
        GetInventoryItemCount("player", slot))
    end
  end
  local heldMail = attachments("mail")
  -- Server responses can outlive the visible attachment slots. Keep submitted mail in escrow.
  for link, item in pairs(outgoingMail) do
    local held = heldMail[link] and heldMail[link].count or 0
    if held < item.count then addItem(heldMail, item, item.count - held) end
  end
  for _, item in pairs(heldMail) do
    addItem(state.items, snapshot and snapshot.items[item.link] or item, item.count)
  end
  if tradeOpen then
    for _, item in pairs(attachments("player")) do
      addItem(state.items, snapshot and snapshot.items[item.link] or item, item.count)
    end
  end
  if bankOpen then
    local bankBags = { [BANK_CONTAINER or -1] = true }
    if REAGENTBANK_CONTAINER then bankBags[REAGENTBANK_CONTAINER] = true end
    for bag = lastBag + 1, lastBag + (NUM_BANKBAGSLOTS or 7) do bankBags[bag] = true end
    if C_Bank and C_Bank.FetchViewableBankTypes and C_Bank.FetchPurchasedBankTabIDs then
      for _, bankType in ipairs(C_Bank.FetchViewableBankTypes()) do
        for _, bag in ipairs(C_Bank.FetchPurchasedBankTabIDs(bankType)) do bankBags[bag] = true end
      end
    end
    for bag in pairs(bankBags) do
      if not playerBags[bag] then
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
          local info = C_Container.GetContainerItemInfo(bag, slot)
          if info and info.hyperlink then
            state.bank[info.hyperlink] = (state.bank[info.hyperlink] or 0) + info.stackCount
          end
        end
      end
    end
  end
  if guildBankOpen and GetNumGuildBankTabs then
    for tab = 1, GetNumGuildBankTabs() do
      for slot = 1, 98 do
        local link = GetGuildBankItemLink(tab, slot)
        if link then
          local count = select(2, GetGuildBankItemInfo(tab, slot))
          state.bank[link] = (state.bank[link] or 0) + count
        end
      end
    end
  end
  return state
end

--- Remember an action candidate; only a matching inventory delta commits a log entry.
---@param action string Action label.
---@param link string Exact item link.
---@param count number Maximum quantity attributable to this action.
---@param direction number 1 for incoming items, -1 for outgoing items.
---@param item table|nil Metadata of the exact source slot when known.
---@return table|nil candidate Pending correlation, if logging is enabled.
function module:Expect(action, link, count, direction, item)
  if not observing or not self:IsLoggingEnabled() or not link or count <= 0 then return end
  local candidate = { action = action, link = link, remaining = count,
    direction = direction, item = item, expires = GetTime() + CORRELATION_SECONDS }
  pending[#pending + 1] = candidate
  self:QueueReconcile()
  return candidate
end

--- Append a selected, confirmed item change without pruning on the hot path.
---@param item table Captured metadata.
---@param action string Action label.
---@param count number Changed quantity.
---@param direction number Sign of the inventory change.
---@param counterparty string|nil Mail recipient or trade partner captured before confirmation.
function module:Record(item, action, count, direction, counterparty)
  if not observing or not self:IsLoggingEnabled() then return end
  -- Retired actions remain readable in saved history, but must never create new records.
  if action == "Unknown" or action == "Used" then return end
  -- Suppress records, not action correlation, so later changes still use the correct baseline.
  if self:GetSettings().actionsToLog[action] == false then return end
  local category = item.classID and Self.ListviewBag:GetInventoryLogCategory(item) or item.category
  local entry = { timestamp = time(), link = item.link, itemID = item.itemID, icon = item.icon,
    name = item.name, binding = item.binding, category = category, stackSize = item.stackSize,
    action = action, quantity = count, direction = direction, counterparty = counterparty }
  table.insert(ledger().entries, entry)
end

--- Commit server-confirmed transfers and offset the baseline to prevent duplicate delta records.
---@param action string Confirmed transaction type.
---@param items table Transferred quantities indexed by link.
---@param direction number Sign of the transfer.
---@param counterparty string|nil Mail recipient or trade partner captured before confirmation.
function module:ConfirmTransfers(action, items, direction, counterparty)
  if not observing or not self:IsLoggingEnabled() then return end
  local current = readInventory()
  for link, transfer in pairs(items) do
    local item = direction > 0 and current.items[link] or snapshot and snapshot.items[link]
    item = item or Self.ListviewBag:GetInventoryLogMetadata(nil, nil, { hyperlink = link })
    self:Record(item, action, transfer.count, direction, counterparty)
    -- Recording both sides matters when a trade exchanges identical items and its net delta is zero.
    if snapshot then addItem(snapshot.items, item, direction * transfer.count) end
  end
end

--- Record confirmed transactions and advance the baseline without logging unmatched changes.
function module:Reconcile()
  if reconcileTimer then self:CancelTimer(reconcileTimer, true) end
  reconcileTimer = nil
  if not observing or not self:IsLoggingEnabled() then return end
  -- A picked-up/split stack has temporarily left its slot. Wait until it is placed or deleted.
  if GetCursorInfo and GetCursorInfo() == "item" then return end
  local current = readInventory()
  if snapshot then
    local links = {}
    for link in pairs(snapshot.items) do links[link] = true end
    for link in pairs(current.items) do links[link] = true end
    for link in pairs(links) do
      local before, after = snapshot.items[link], current.items[link]
      local delta = (after and after.count or 0) - (before and before.count or 0)
      if delta ~= 0 then
        local direction, remaining = delta > 0 and 1 or -1, math.abs(delta)
        local item = direction > 0 and after or before
        local bankGain = (current.bank[link] or 0) - (snapshot.bank[link] or 0)
        if direction < 0 and bankGain > 0 then
          local count = math.min(remaining, bankGain)
          self:Record(item, "Banked", count, direction)
          remaining = remaining - count
        end
        for _, candidate in ipairs(pending) do
          if remaining == 0 then break end
          if candidate.expires >= GetTime() and candidate.link == link
            and candidate.direction == direction and candidate.remaining > 0 then
            local count = math.min(remaining, candidate.remaining)
            self:Record(candidate.item or item, candidate.action, count, direction)
            candidate.remaining = candidate.remaining - count
            remaining = remaining - count
          end
        end
      end
    end
  end
  snapshot = current
  lastCursorLink = nil
  for index = #pending, 1, -1 do
    if pending[index].remaining == 0 or pending[index].expires < GetTime() then
      table.remove(pending, index)
    end
  end
  self:Refresh()
end

--- Coalesce native notifications so attachment and bag updates settle before comparison.
function module:QueueReconcile()
  if observing and self:IsLoggingEnabled() and not reconcileTimer then
    reconcileTimer = self:ScheduleTimer("Reconcile", 0.3)
  end
end

--- Capture purchases and creations before immediate consumption or resale can hide a net-zero delta.
function module:OnAcquiredBagUpdate()
  if not observing or not self:IsLoggingEnabled() or not snapshot then return end
  local current
  for _, candidate in ipairs(pending) do
    if (candidate.action == "Purchased" or candidate.action == "Created")
      and candidate.remaining > 0 and candidate.expires >= GetTime() then
      current = current or readInventory()
      local before, after = snapshot.items[candidate.link], current.items[candidate.link]
      -- Leave unrelated updates coalesced so their loot, mail, and equipment notifications can settle.
      if after and after.count > (before and before.count or 0) then
        self:Reconcile()
        return
      end
    end
  end
end

--- Establish a fresh baseline without reporting existing possessions.
function module:ResetTracking()
  if reconcileTimer then self:CancelTimer(reconcileTimer); reconcileTimer = nil end
  pending, metadataCache, snapshot, auctionRequests = {}, {}, nil, {}
  loot, questRewards, tradeItems, outgoingMail = {}, {}, {}, {}
  questChoice, legacyAuctionLink, legacyAuctionRequest, outgoingMailRecipient = nil, nil, nil, nil
  lastCursorLink, gatheringUntil, gatheringKind = nil, nil, nil
  bankOpen = BankFrame and BankFrame:IsShown() or false
  guildBankOpen = GuildBankFrame and GuildBankFrame:IsShown() or false
  tradeOpen = TradeFrame and TradeFrame:IsShown() or false
  if self:IsLoggingEnabled() and (not GetCursorInfo or GetCursorInfo() ~= "item") then
    snapshot = readInventory()
  end
  self:Refresh()
end

--- Synchronize the Ace3 module with a selected/copied/reset profile without clearing history.
function module:SyncProfile()
  local enabled = self:IsLoggingEnabled()
  if not Self:IsEnabled() then self:SetEnabledState(enabled); return end
  local wasObserving = observing
  if enabled then
    self:Enable()
    if wasObserving then self:ResetTracking() end
  else
    self:Disable()
  end
end

--- Clear this character's saved entries without interrupting pending transactions.
function module:ClearLog()
  wipe(ledger().entries)
  if window then
    window.filtered = {}
    for _, row in ipairs(window.rows) do row.entry = nil; row:Hide() end
  end
  self:Refresh()
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- Ask before clearing history, optionally after disabling the module.
---@param disabledProfile table|nil Profile whose module was just disabled.
function module:RequestClearLog(disabledProfile)
  local id = disabledProfile and "SLACKHACKS_DISABLE_INVENTORY_LOG_CLEAR" or "SLACKHACKS_CLEAR_INVENTORY_LOG"
  StaticPopupDialogs[id] = {
    text = disabledProfile and "Inventory Log is disabled. Also clear this character's inventory log?"
      or "Clear this character's inventory log? This cannot be undone.",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    --- Only clear the captured character history and a still-disabled profile.
    ---@param _ table Confirmation dialog.
    ---@param data table Captured ledger and optional disabled profile.
    OnAccept = function(_, data)
      if ledger() ~= data.ledger or (data.profile and
        (Self.db.profile ~= data.profile or module:IsLoggingEnabled())) then
        prn("The profile or Inventory Log setting changed; the log was not cleared.")
        return
      end
      module:ClearLog()
    end,
  }
  if not StaticPopup_Show(id, nil, nil, { ledger = ledger(), profile = disabledProfile }) then
    prn("The Inventory Log confirmation could not be shown; existing logs were kept.")
  end
end

--- Enable/disable the Ace3 module and offer to clear history when disabling it.
---@param enabled boolean Whether to observe new changes.
function module:SetLoggingEnabled(enabled)
  local config = self:GetSettings()
  local wasEnabled = config.enabled
  config.enabled = enabled == true
  self:SyncProfile()
  if wasEnabled and not config.enabled and #ledger().entries > 0 then
    self:RequestClearLog(Self.db.profile)
  end
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange("SlackHacks") end
end

--- Validate the numeric retention input without imposing an arbitrary upper limit.
---@param value string|number Retention input.
---@return boolean|string valid True or an AceConfig validation message.
function module:ValidateEntriesToKeep(value)
  local count = tonumber(value)
  if count and count >= 1 and count < math.huge and count == math.floor(count) then return true end
  return "Enter a positive whole number of log entries."
end

--- Apply a valid retention limit and prune once when the preference changes.
---@param value string|number Retention input.
function module:SetEntriesToKeep(value)
  local valid = self:ValidateEntriesToKeep(value)
  if valid ~= true then prn(valid); return end
  self:GetSettings().entriesToKeep = tonumber(value)
  self:Purge()
end

--- Periodically keep only the newest entries, allowing overflow between maintenance passes.
function module:Purge()
  local entries = ledger().entries
  local retention = self:GetSettings().entriesToKeep
  local excess = #entries - retention
  if excess <= 0 then return end
  for i = 1, retention do entries[i] = entries[i + excess] end
  for i = #entries, retention + 1, -1 do entries[i] = nil end
  self:Refresh()
end

--- Remember the item on the cursor before a possible confirmed deletion.
function module:OnCursorChanged()
  if not self:IsLoggingEnabled() then return end
  local kind, _, link = GetCursorInfo()
  if kind == "item" then lastCursorLink = link end
  self:QueueReconcile()
end

--- Capture loot identities and source types before cleared slots disappear.
---@param event string Native loot-ready/open event.
function module:OnLootOpened(event)
  if not self:IsLoggingEnabled() then return end
  if event == "LOOT_OPENED" and next(loot) then return end
  loot = {}
  for slot = 1, GetNumLootItems() do
    local link = GetLootSlotLink(slot)
    if link then
      local count = select(3, GetLootSlotInfo(slot))
      local sources = { GetLootSourceInfo(slot) }
      local action
      if IsFishingLoot and IsFishingLoot() then
        action = "Gathered"
      elseif #sources > 0 then
        local corpses = true
        local nodes = true
        for i = 1, #sources, 2 do
          if not sources[i]:match("^Creature%-") then corpses = false end
          if not sources[i]:match("^GameObject%-") then nodes = false end
        end
        if gatheringUntil and gatheringUntil >= GetTime()
          and ((gatheringKind == 8613 and corpses) or (gatheringKind ~= 8613 and nodes)) then
          action = "Gathered"
        elseif corpses then
          action = "Looted"
        end
      end
      loot[slot] = { link = link, count = count, action = action }
    end
  end
  gatheringUntil, gatheringKind = nil, nil
end

--- Attribute a cleared loot slot only if that item actually enters the player's inventory.
---@param event string Native event.
---@param slot number Cleared loot slot.
function module:OnLootSlotCleared(event, slot)
  local item = loot[slot]
  if item then
    if item.action then self:Expect(item.action, item.link, item.count, 1) end
    loot[slot] = nil
  end
  self:QueueReconcile()
end

--- Recognize localized gathering casts without logging spell reagent or item consumption.
---@param event string Native event.
---@param unit string Casting unit.
---@param castGUID string Cast identity.
---@param spellID number Completed spell.
function module:OnSpellSucceeded(event, unit, castGUID, spellID)
  if not observing or unit ~= "player" or not self:IsLoggingEnabled() then return end
  local getName = C_Spell and C_Spell.GetSpellName or GetSpellInfo
  local name = getName(spellID)
  for _, id in ipairs({ 2575, 2366, 8613, 7620 }) do
    local professionName = getName(id)
    if name and professionName and name == professionName then
      gatheringUntil = GetTime() + CORRELATION_SECONDS
      gatheringKind = id
      return
    end
  end
end

--- Correlate Blizzard's localized self-creation messages with confirmed inventory gains.
---@param event string Chat event.
---@param message string Native item creation or loot message.
function module:OnItemCreated(event, message)
  if not observing or not self:IsLoggingEnabled() then return end
  local link = message:match("(|c%x+|Hitem:[^|]+|h.-|h|r)")
    or message:match("(|Hitem:[^|]+|h.-|h)")
  if not link then return end
  local quantity
  if message == LOOT_ITEM_CREATED_SELF:format(link) then
    quantity = 1
  else
    -- Parse counts outside the hyperlink so digits in item IDs and item names cannot become quantities.
    local first, last = message:find(link, 1, true)
    quantity = tonumber((message:sub(1, first - 1) .. message:sub(last + 1)):match("%d+"))
    if not quantity or quantity < 1 or message ~= LOOT_ITEM_CREATED_SELF_MULTIPLE:format(link, quantity) then return end
  end
  self:Expect("Created", link, quantity, 1)
  self:OnAcquiredBagUpdate()
end

--- Capture guaranteed and selectable quest rewards while their native item links are available.
function module:OnQuestComplete()
  if not self:IsLoggingEnabled() then return end
  questRewards = {}
  questChoice = nil
  for _, kind in ipairs({ "reward", "choice" }) do
    local count = kind == "reward" and GetNumQuestRewards() or GetNumQuestChoices()
    for index = 1, count do
      local link = GetQuestItemLink(kind, index)
      if link then
        questRewards[#questRewards + 1] = { link = link, count = select(3, GetQuestItemInfo(kind, index)),
          choice = kind == "choice" and index or nil }
      end
    end
  end
end

--- Commit reward candidates after the native quest turn-in succeeds.
function module:OnQuestTurnedIn()
  for _, item in ipairs(questRewards) do
    if not item.choice or item.choice == questChoice then self:Expect("Quest", item.link, item.count, 1) end
  end
  questRewards = {}
  self:QueueReconcile()
end

--- Capture both sides and the partner of a trade before the native window clears them.
function module:OnTradeUpdated()
  if not self:IsLoggingEnabled() or not tradeOpen then return end
  tradeItems = { player = attachments("player"), target = attachments("target"),
    counterparty = tradeItems.counterparty or unitFullName("NPC") }
  self:QueueReconcile()
end

--- Remember the selected legacy auction variant before posting clears its sell-slot data.
function module:OnAuctionSellChanged()
  if not self:IsLoggingEnabled() then return end
  local itemID, guid = select(10, GetAuctionSellItemInfo())
  if not itemID and not guid then self:QueueReconcile(); return end
  legacyAuctionLink = guid and C_Item.GetItemLinkByGUID and C_Item.GetItemLinkByGUID(guid)
  if not legacyAuctionLink and snapshot and itemID then
    -- Older clients without GUID links are safe only when the owned item ID has one variant.
    for link, item in pairs(snapshot.items) do
      if item.itemID == itemID then
        if legacyAuctionLink then legacyAuctionLink = nil; break end
        legacyAuctionLink = link
      end
    end
  end
  self:QueueReconcile()
end

--- Attribute traded items only after Blizzard announces a successful transaction.
---@param event string Native event.
---@param messageType number Native message identifier.
---@param message string Localized message.
function module:OnInfoMessage(event, messageType, message)
  if message ~= ERR_TRADE_COMPLETE then return end
  self:ConfirmTransfers("Traded", tradeItems.player or {}, -1, tradeItems.counterparty)
  self:ConfirmTransfers("Traded", tradeItems.target or {}, 1, tradeItems.counterparty)
  tradeItems = {}
  self:QueueReconcile()
end

--- Attribute outgoing attachments after the server confirms mail delivery.
function module:OnMailSuccess()
  local sent, recipient = outgoingMail, outgoingMailRecipient
  outgoingMail, outgoingMailRecipient = {}, nil
  self:ConfirmTransfers("Mailed", sent, -1, recipient)
  self:QueueReconcile()
end

--- Release submitted-mail escrow after failure; returning draft items are not new acquisitions.
function module:OnMailFailed()
  outgoingMail, outgoingMailRecipient = {}, nil
  self:QueueReconcile()
end

--- Refresh accessible bank/trade holdings at native interaction boundaries.
---@param event string Native open/close event.
function module:OnInteraction(event)
  if not self:IsLoggingEnabled() then return end
  if event == "BANKFRAME_OPENED" or event == "GUILDBANKFRAME_OPENED" then
    if event == "BANKFRAME_OPENED" then bankOpen = true else guildBankOpen = true end
    -- Opening a bank must not make all of its pre-existing contents look like new deposits.
    if snapshot then snapshot.bank = readInventory().bank end
  elseif event == "BANKFRAME_CLOSED" or event == "GUILDBANKFRAME_CLOSED" then
    self:Reconcile()
    if event == "BANKFRAME_CLOSED" then bankOpen = false else guildBankOpen = false end
    if snapshot then snapshot.bank = {} end
  elseif event == "TRADE_SHOW" then
    tradeOpen = true
    tradeItems = { counterparty = unitFullName("NPC") }
  elseif event == "TRADE_CLOSED" then
    tradeOpen = false
  end
  self:QueueReconcile()
end

--- Renew a confirmed request, restoring it if it expired while the native dialog was open.
---@param candidate table Pending action.
local function renewExpectedAction(candidate)
  candidate.expires = GetTime() + CORRELATION_SECONDS
  for _, entry in ipairs(pending) do
    if entry == candidate then module:QueueReconcile(); return end
  end
  pending[#pending + 1] = candidate
  module:QueueReconcile()
end

--- Observe protected requests without initiating any protected action ourselves.
function module:InstallHooks()
  if self.hooksInstalled then return end
  self.hooksInstalled = true
  --- Remember sold quantities from the last stable bag slots.
  ---@param bag number Bag identifier.
  ---@param slot number Slot identifier.
  ---@param onSelf boolean|nil True when explicitly using rather than selling the item.
  local function sold(bag, slot, onSelf)
    if onSelf or not module:IsLoggingEnabled() or not (MerchantFrame and MerchantFrame:IsShown()) then return end
    local item = snapshot and snapshot.slots[bag .. ":" .. slot]
    if item then module:Expect("Sold", item.link, item.count, -1, item.item) end
  end
  hooksecurefunc(C_Container, "UseContainerItem", sold)
  if BuyMerchantItem then
    --- Attribute only confirmed gains, using the requested units or the vendor's default bundle.
    ---@param index number Merchant item index.
    ---@param quantity number|nil Explicit units; nil buys the displayed bundle.
    hooksecurefunc("BuyMerchantItem", function(index, quantity)
      if not observing or not module:IsLoggingEnabled() then return end
      local link = GetMerchantItemLink(index)
      if quantity == nil then
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
          local info = C_MerchantFrame.GetItemInfo(index)
          quantity = info and info.stackCount
        elseif GetMerchantItemInfo then
          quantity = select(4, GetMerchantItemInfo(index))
        end
      end
      if not link or not quantity or quantity <= 0 then
        prn("Could not identify the requested vendor purchase; its inventory change will remain unattributed.")
        return
      end
      module:Expect("Purchased", link, quantity, 1)
      module:OnAcquiredBagUpdate()
    end)
  end
  if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems then
    --- Observe Blizzard's bulk sale without bypassing its own eligibility checks.
    hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", function()
      if not module:IsLoggingEnabled() or not snapshot or not (MerchantFrame and MerchantFrame:IsShown()) then return end
      for _, item in pairs(snapshot.items) do
        if item.quality == 0 then module:Expect("Sold", item.link, item.count, -1) end
      end
    end)
  end
  if DeleteCursorItem then
    --- Confirm deletion through the matching negative delta.
    hooksecurefunc("DeleteCursorItem", function()
      local item = snapshot and snapshot.items[lastCursorLink]
      if item then module:Expect("Destroyed", item.link, item.count, -1) end
      module:QueueReconcile()
    end)
  end
  if SendMail then
    --- Keep the submitted recipient and draft until MAIL_SEND_SUCCESS confirms delivery.
    ---@param recipient string Mail recipient passed to Blizzard's send request.
    hooksecurefunc("SendMail", function(recipient)
      if observing and module:IsLoggingEnabled() then
        outgoingMail = attachments("mail")
        outgoingMailRecipient = recipient
        module:Reconcile()
      end
    end)
  end
  if GetQuestReward then
    --- Remember the chosen reward, rather than attributing every available choice.
    ---@param choice number Selected reward index.
    hooksecurefunc("GetQuestReward", function(choice) questChoice = choice end)
  end
  --- Capture auction requests; failed/cancelled requests have no matching item loss.
  ---@param location table Native item location.
  ---@param duration number Listing duration.
  ---@param quantity number Requested quantity.
  local function auctioned(location, duration, quantity)
    if not module:IsLoggingEnabled() or not snapshot or not location:IsBagAndSlot() then return end
    local bag, slot = location:GetBagAndSlot()
    local item = snapshot.slots[bag .. ":" .. slot]
    if item then
      auctionRequests[bag .. ":" .. slot] = module:Expect("Auctioned", item.link, quantity, -1, item.item)
    end
  end
  --- Refresh a delayed confirmation without counting Post and ConfirmPost as two transactions.
  ---@param location table Native item location.
  ---@param duration number Listing duration.
  ---@param quantity number Confirmed quantity.
  local function auctionConfirmed(location, duration, quantity)
    if not module:IsLoggingEnabled() or not location:IsBagAndSlot() then return end
    local bag, slot = location:GetBagAndSlot()
    local candidate = auctionRequests[bag .. ":" .. slot]
    if candidate and candidate.remaining == quantity then
      renewExpectedAction(candidate)
    else
      auctioned(location, duration, quantity)
    end
  end
  if C_AuctionHouse then
    for _, method in ipairs({ "PostItem", "PostCommodity", "ConfirmPostItem", "ConfirmPostCommodity" }) do
      if C_AuctionHouse[method] then
        hooksecurefunc(C_AuctionHouse, method, method:match("^Confirm") and auctionConfirmed or auctioned)
      end
    end
  end
  if PostAuction or StartAuction then
    --- Observe legacy posting requests; the selected sell slot still belongs to the player's bags.
    ---@param minimumBid number Minimum bid.
    ---@param buyout number Buyout.
    ---@param duration number Listing duration.
    ---@param stackSize number Items per listing.
    ---@param numStacks number Number of listings.
    ---@param confirmed boolean|nil Whether this is a delayed native confirmation.
    local function legacyPosted(minimumBid, buyout, duration, stackSize, numStacks, confirmed)
      if not module:IsLoggingEnabled() or not legacyAuctionLink then return end
      local quantity = stackSize * numStacks
      if confirmed and legacyAuctionRequest and legacyAuctionRequest.link == legacyAuctionLink
        and legacyAuctionRequest.remaining == quantity then
        renewExpectedAction(legacyAuctionRequest)
      else
        legacyAuctionRequest = module:Expect("Auctioned", legacyAuctionLink, quantity, -1)
      end
    end
    if PostAuction then hooksecurefunc("PostAuction", legacyPosted) end
    if StartAuction then hooksecurefunc("StartAuction", legacyPosted) end
  end
end

--- Keep profile callbacks available even while the logging module is disabled.
function module:OnInitialize()
  self:MigrateCharacterSettings(Self.db.char)
  Self.db.RegisterCallback(self, "OnProfileChanged", "SyncProfile")
  Self.db.RegisterCallback(self, "OnProfileCopied", "SyncProfile")
  Self.db.RegisterCallback(self, "OnProfileReset", "SyncProfile")
  self:SetEnabledState(self:IsLoggingEnabled())
end

--- Start observation and periodic maintenance independently of replacement bags.
function module:OnEnable()
  if not self:IsLoggingEnabled() then self:SetEnabledState(false); return end
  self:InstallHooks()
  for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "MAIL_SEND_INFO_UPDATE",
    "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_ACCEPT_UPDATE" }) do
    self:RegisterEvent(event, event:match("^TRADE_") and "OnTradeUpdated" or "QueueReconcile")
  end
  for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "GUILDBANKFRAME_OPENED",
    "GUILDBANKFRAME_CLOSED", "TRADE_SHOW", "TRADE_CLOSED" }) do self:RegisterEvent(event, "OnInteraction") end
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "ResetTracking")
  self:RegisterEvent("BAG_UPDATE", "OnAcquiredBagUpdate")
  self:RegisterEvent("CHAT_MSG_LOOT", "OnItemCreated")
  self:RegisterEvent("CURSOR_CHANGED", "OnCursorChanged")
  self:RegisterEvent("LOOT_READY", "OnLootOpened")
  self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
  self:RegisterEvent("LOOT_SLOT_CLEARED", "OnLootSlotCleared")
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellSucceeded")
  self:RegisterEvent("QUEST_COMPLETE", "OnQuestComplete")
  self:RegisterEvent("QUEST_TURNED_IN", "OnQuestTurnedIn")
  self:RegisterEvent("UI_INFO_MESSAGE", "OnInfoMessage")
  self:RegisterEvent("MAIL_SEND_SUCCESS", "OnMailSuccess")
  self:RegisterEvent("MAIL_FAILED", "OnMailFailed")
  self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "Refresh")
  if GetAuctionSellItemInfo then self:RegisterEvent("NEW_AUCTION_UPDATE", "OnAuctionSellChanged") end
  observing = true
  self:ResetTracking()
  self:Purge()
  self:ScheduleRepeatingTimer("Purge", 300)
end

--- Stop observations and hide the ledger when the module or its parent is disabled.
function module:OnDisable()
  -- AceAddon preserves a child's desired enabledState when its parent shuts down.
  observing = false
  self:UnregisterAllEvents()
  self:CancelAllTimers()
  reconcileTimer, snapshot = nil, nil
  if window then window:Hide() end
end

--- Select newest-first entries using the ledger's action, binding, and normal item-category filters.
---@param query string Search text.
---@return table entries Matching saved entries, newest first.
function module:GetFilteredEntries(query)
  local data, entries = ledger(), {}
  query = query:lower()
  for index = #data.entries, 1, -1 do
    local entry = data.entries[index]
    if data.actions[entry.action] ~= false and data.bindings[entry.binding or "unbound"] ~= false
      and data.categories[entry.category or "other"] ~= false
      and (query == "" or (entry.name or entry.link):lower():find(query, 1, true)) then
      entries[#entries + 1] = entry
    end
  end
  return entries
end

--- Format a known quantity without guessing missing counts or displaying redundant singleton counts.
---@param entry table Saved ledger entry.
---@param includeSingle boolean|nil Include nonstackable singletons in detailed tooltips.
---@return string text Quantity, or empty when unknown or redundant.
local function quantityText(entry, includeSingle)
  local count = entry.quantity
  if type(count) ~= "number" or count < 1 or count >= math.huge or count ~= math.floor(count) then return "" end
  if not includeSingle and count == 1 and entry.stackSize == 1 then return "" end
  -- Historical Unknown entries keep their original gain/loss direction.
  local sign = entry.action == "Unknown" and (entry.direction == 1 and "+" or entry.direction == -1 and "-") or ""
  return (sign or "") .. count
end

--- Populate only viewport rows; thousands of saved records do not create thousands of widgets.
local function renderViewport()
  local first = math.floor(window.scroll:GetVerticalScroll() / ROW_HEIGHT) + 1
  local count = math.ceil(window.scroll:GetHeight() / ROW_HEIGHT) + 1
  for index = 1, math.max(count, #window.rows) do
    local row = window.rows[index]
    if not row and index <= count then
      row = CreateFrame("Button", nil, window.scrollChild)
      window.rows[index] = row
      row:SetHeight(ROW_HEIGHT)
      -- Inherit Send Mail's dark parchment text color, keeping the ledger's compact font sizes.
      local font = MailTextFontNormal:GetFont()
      row.shade = row:CreateTexture(nil, "BACKGROUND")
      row.shade:SetPoint("TOPLEFT", 0, -1)
      row.shade:SetPoint("BOTTOMRIGHT", 0, 1)
      row.shade:SetColorTexture(1, 1, 1, 1)
      row.shade:SetGradient("HORIZONTAL", CreateColor(0.5, 0.5, 0.5, 0.16), CreateColor(0.5, 0.5, 0.5, 0.04))
      row.quantity = row:CreateFontString(nil, "ARTWORK", "MailTextFontNormal")
      row.quantity:SetFont(font, 9)
      row.quantity:SetPoint("LEFT", 0, 0)
      row.quantity:SetWidth(12)
      row.quantity:SetWordWrap(false)
      row.quantity:SetJustifyH("RIGHT")
      row.timestamp = row:CreateFontString(nil, "ARTWORK", "MailTextFontNormal")
      row.timestamp:SetFont(font, 7)
      row.timestamp:SetWidth(59)
      row.timestamp:SetPoint("RIGHT", 0, 0)
      row.timestamp:SetWordWrap(false)
      row.timestamp:SetJustifyH("LEFT")
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(16, 16)
      row.icon:SetPoint("LEFT", 18, 0)
      row.item = row:CreateFontString(nil, "ARTWORK", "MailTextFontNormal")
      row.item:SetFont(font, 9)
      row.item:SetPoint("LEFT", 38, 0)
      row.item:SetPoint("RIGHT", -140, 0)
      row.item:SetHeight(ROW_HEIGHT - 2)
      row.item:SetJustifyH("LEFT")
      row.action = row:CreateFontString(nil, "ARTWORK", "MailTextFontNormal")
      row.action:SetFont(font, 9)
      row.action:SetPoint("LEFT", 208, 0)
      row.action:SetWidth(69)
      row.action:SetHeight(12)
      row.action:SetWordWrap(false)
      row.action:SetJustifyH("LEFT")
      row.counterparty = row:CreateFontString(nil, "ARTWORK", "MailTextFontNormal")
      row.counterparty:SetFont(font, 7)
      row.counterparty:SetPoint("LEFT", 208, -6)
      row.counterparty:SetWidth(69)
      row.counterparty:SetHeight(10)
      row.counterparty:SetWordWrap(false)
      row.counterparty:SetJustifyH("LEFT")
      --- Show full quantities and item details, including items no longer in any bag.
      ---@param button table Visible ledger row.
      row:SetScript("OnEnter", function(button)
        local entry = button.entry
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(entry.link)
        local quantity = quantityText(entry, true)
        if quantity ~= "" then GameTooltip:AddLine("Quantity: " .. quantity, 1, 1, 1) end
        if entry.counterparty then
          local label = entry.action == "Mailed" and "Mailed to: "
            or (entry.direction < 0 and "Traded to: " or "Traded from: ")
          GameTooltip:AddLine(label .. entry.counterparty, 1, 1, 1, true)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", GameTooltip_Hide)
      --- Preserve normal chat-link insertion and modified item clicks.
      row:SetScript("OnClick", function(button)
        HandleModifiedItemClick(button.entry.link)
      end)
    end
    if row then
      local entry = index <= count and window.filtered[first + index - 1]
      row:SetShown(entry ~= nil and entry ~= false)
      if entry then
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window.scrollChild, "TOPLEFT", 0, -(first + index - 2) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", window.scrollChild, "TOPRIGHT", 0, -(first + index - 2) * ROW_HEIGHT)
        row.shade:Show()
        row.quantity:SetText(quantityText(entry))
        -- A deliberately narrow Qty. column must not turn larger known counts into misleading ellipses.
        if row.quantity:GetStringWidth() > row.quantity:GetWidth() then row.quantity:SetText("") end
        row.timestamp:SetText(date("%m/%d %I:%M%p", entry.timestamp):lower())
        row.icon:SetTexture(entry.icon or PAPER_ICON)
        row.item:SetText(entry.link)
        local counterparty = (entry.action == "Mailed" or entry.action == "Traded") and entry.counterparty
        row.action:ClearAllPoints()
        row.action:SetPoint("LEFT", 208, counterparty and 5 or 0)
        row.action:SetText(entry.action)
        row.counterparty:SetText(counterparty or "")
        row.counterparty:SetShown(counterparty ~= nil and counterparty ~= false)
      end
    end
  end
end

--- Refresh visible results without disturbing the user's scroll position.
function module:Refresh()
  if not window or not window:IsShown() then return end
  for _, entry in ipairs(ledger().entries) do
    if not entry.name or not entry.category or not entry.stackSize then
      local item = Self.ListviewBag:GetInventoryLogMetadata(nil, nil,
        { hyperlink = entry.link, isBound = entry.binding == "soulbound" })
      entry.name, entry.icon, entry.category = entry.name or item.name, entry.icon or item.icon,
        entry.category or item.category
      entry.stackSize = item.stackSize
    end
  end
  window.filtered = self:GetFilteredEntries(window.search:GetText() or "")
  Self.ListviewBag:UpdateInventoryLogFiltersLabel(window.filters, self)
  window.scrollChild:SetHeight(math.max(1, #window.filtered * ROW_HEIGHT))
  local maximum = math.max(0, #window.filtered * ROW_HEIGHT - window.scroll:GetHeight())
  window.scroll:SetVerticalScroll(math.min(window.scroll:GetVerticalScroll(), maximum))
  renderViewport()
  window.empty:SetShown(#window.filtered == 0)
  window.empty:SetText((self:IsLoggingEnabled() or #ledger().entries > 0) and "No matching inventory log entries."
    or "Inventory logging is disabled.\nEnable Inventory Log in Inventory settings or the bag menu.")
end

--- Reuse Send Mail's native chrome, input borders, stationery, and scrollbar for the ledger.
local function createWindow()
  window = CreateFrame("Frame", "SlackHacksInventoryLogFrame", UIParent, "ButtonFrameTemplate")
  window:SetWidth(410)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:SetTitle("Inventory Log")
  window:SetPortraitToAsset(PAPER_ICON)
  ButtonFrameTemplate_HideButtonBar(window)
  window.header = CreateFrame("Frame", nil, window)
  window.header:SetPoint("TOPLEFT", 12, -28)
  window.header:SetPoint("TOPRIGHT", -14, -28)
  window.header:SetHeight(26)
  -- BagSearchBoxTemplate inherits this look, but its OnHide clears Blizzard's global bag search.
  window.search = CreateFrame("EditBox", "SlackHacksInventoryLogSearch", window.header, "SearchBoxTemplate")
  window.search:SetSize(182, 20)
  window.search:SetPoint("TOPLEFT", 68, 0)
  window.search:SetAutoFocus(false)
  window.search:SetFontObject(ChatFontNormal)
  -- Retain native search/clear behavior, but use SendMailSubjectEditBox's rectangular input artwork.
  for _, part in ipairs({ { "Left", 0, 0.0625 }, { "Middle", 0.0625, 0.9375 },
    { "Right", 0.9375, 1 } }) do
    local texture = window.search[part[1]]
    texture:SetTexture("Interface\\Common\\Common-Input-Border")
    texture:SetTexCoord(part[2], part[3], 0, 0.625)
  end
  window.search.Left:ClearAllPoints()
  window.search.Left:SetSize(8, 20)
  window.search.Left:SetPoint("TOPLEFT", -8, 0)
  window.search.Right:ClearAllPoints()
  window.search.Right:SetSize(8, 20)
  window.search.Right:SetPoint("TOPRIGHT", 8, 0)
  --- Apply ledger search without changing Blizzard's global bag-search state.
  window.search:SetScript("OnTextChanged", function(editBox)
    SearchBoxTemplate_OnTextChanged(editBox)
    window.scroll:SetVerticalScroll(0)
    module:Refresh()
  end)
  if MenuUtil and MenuUtil.CreateContextMenu then
    window.filters = CreateFrame("DropdownButton", "SlackHacksInventoryLogFilters", window.header,
      "WowStyle1DropdownTemplate")
    window.filters:SetWidth(118)
    window.filters:SetPoint("TOPRIGHT", 0, 2)
    --- Build the same native filter menu as the bag, substituting Actions for Flags.
    window.filters:SetupMenu(function(anchor, root)
      Self.ListviewBag:OpenInventoryLogFilters(anchor, root, module)
    end)
    window.filters:OverrideText("Filters")
  else
    window.filters = CreateFrame("Frame", "SlackHacksInventoryLogFilters", window.header, "UIDropDownMenuTemplate")
    window.filters.legacy = true
    window.filters:SetPoint("TOPRIGHT", 18, 4)
    UIDropDownMenu_SetWidth(window.filters, 104)
    UIDropDownMenu_SetText(window.filters, "Filters")
    --- Open the shared legacy filter menu on clients without modern dropdowns.
    _G[window.filters:GetName() .. "Button"]:SetScript("OnClick", function()
      Self.ListviewBag:OpenInventoryLogFilters(window.filters, nil, module)
    end)
  end
  window.columns = CreateFrame("Frame", nil, window)
  window.columns:SetPoint("TOPLEFT", 12, -64)
  window.columns:SetPoint("TOPRIGHT", -32, -64)
  window.columns:SetHeight(16)
  -- Align Item with its link text, leaving the icon's header space for the wider Qty. label.
  local positions = { 0, 38, 208, 283 }
  for index, label in ipairs({ "Qty.", "Item", "Action", "Timestamp" }) do
    local heading = window.columns:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    heading:SetPoint("BOTTOMLEFT", positions[index], 0)
    heading:SetText(label)
  end
  window.scroll = CreateFrame("ScrollFrame", "SlackHacksInventoryLogScroll", window, "ScrollFrameTemplate")
  window.scroll:SetPoint("TOPLEFT", 12, -84)
  window.scroll:SetPoint("BOTTOMRIGHT", -32, 16)
  window.scroll.ScrollBar:ClearAllPoints()
  window.scroll.ScrollBar:SetPoint("TOPLEFT", window.scroll, "TOPRIGHT", 10, -4)
  window.scroll.ScrollBar:SetPoint("BOTTOMLEFT", window.scroll, "BOTTOMRIGHT", 10, 3)
  -- Send Mail uses two stationery pieces, not the inbox's UI-MailFrameBG texture.
  window.stationeryLeft = window.scroll:CreateTexture(nil, "BACKGROUND")
  window.stationeryLeft:SetTexture("Interface\\Stationery\\stationerytest1")
  window.stationeryLeft:SetPoint("TOPLEFT")
  window.stationeryLeft:SetPoint("BOTTOMLEFT")
  window.stationeryLeft:SetWidth(366 * 252 / 316)
  window.stationeryRight = window.scroll:CreateTexture(nil, "BACKGROUND")
  window.stationeryRight:SetTexture("Interface\\Stationery\\stationerytest2")
  window.stationeryRight:SetPoint("TOPLEFT", window.stationeryLeft, "TOPRIGHT")
  window.stationeryRight:SetPoint("BOTTOMRIGHT")
  window.scrollChild = CreateFrame("Frame", nil, window.scroll)
  -- The stationery's transparent right edge is not usable paper; keep row shading and text inside it.
  window.scrollChild:SetSize(366 - 24, 1)
  window.scroll:SetScrollChild(window.scrollChild)
  window.rows, window.filtered = {}, {}
  window.scroll:HookScript("OnVerticalScroll", renderViewport)
  window.empty = window:CreateFontString(nil, "ARTWORK", "MailTextFontNormal")
  window.empty:SetPoint("TOPLEFT", window.scroll, "TOPLEFT", 12, -12)
  window.empty:SetPoint("TOPRIGHT", window.scroll, "TOPRIGHT", -12, -12)
  window.empty:SetJustifyH("CENTER")
  --- Refit the ledger and update results each time it is opened.
  window:SetScript("OnShow", function()
    -- MailFrame is load-on-demand; its native ButtonFrameTemplate height is 424 before it loads.
    window:SetHeight(math.min((MailFrame and MailFrame:GetHeight() or 424) * 1.5, UIParent:GetHeight() * 0.9))
    module:Refresh()
  end)
  window:Hide()
  table.insert(UISpecialFrames, window:GetName())
end

--- Open the ledger even if logging or the Listview Bag replacement is currently disabled.
function module:Open()
  if not window then createWindow() end
  window:Show()
  window:Raise()
  self:Refresh()
end

--- Open saved history and offer to enable logging when the menu is used while disabled.
function module:RequestOpen()
  self:Open()
  if self:IsLoggingEnabled() then return end
  local id = "SLACKHACKS_ENABLE_INVENTORY_LOG"
  StaticPopupDialogs[id] = {
    text = "Inventory logging is disabled. Enable Inventory Log?",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    --- Enable only the profile for which the offer was shown.
    ---@param _ table Confirmation dialog.
    ---@param data table Captured profile.
    OnAccept = function(_, data)
      if Self.db.profile ~= data.profile then
        prn("The profile changed; Inventory Log was not enabled.")
        return
      end
      if not module:IsLoggingEnabled() then module:SetLoggingEnabled(true) end
    end,
  }
  if not StaticPopup_Show(id, nil, nil, { profile = Self.db.profile }) then
    prn("The Inventory Log enable confirmation could not be shown; logging remains disabled.")
  end
end

--- Add the open action to shared modern or legacy bag menus.
---@param root table|nil Modern menu root.
---@param menu table|nil Legacy menu entries.
function module:AddMenu(root, menu)
  --- Open this character's ledger and offer to enable disabled logging.
  local function open() module:RequestOpen() end
  if root then
    root:CreateButton("Open Inventory Log", open)
  else
    menu[#menu + 1] = { text = "Open Inventory Log", notCheckable = true, func = open }
  end
end

--- Turn the footer's capacity-adjacent icon into an accessible ledger button.
---@param button table Native button.
function module:ConfigureButton(button)
  button:SetNormalTexture(PAPER_ICON)
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  --- Explain the ledger and the current observation preference.
  button:SetScript("OnEnter", function(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Inventory Log")
    GameTooltip:AddLine("View recent item activity.", 1, 1, 1)
    if not module:IsLoggingEnabled() then
      GameTooltip:AddLine("Logging is disabled. Use Open Inventory Log in the bag menu or enable it in Inventory settings.",
        1, 0.82, 0, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  --- Open the ledger without altering the logging preference.
  button:SetScript("OnClick", function() module:Open() end)
end
