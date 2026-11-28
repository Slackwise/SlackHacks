-- Run from the addon root with Lua 5.1: lua tests\inventory_log.lua

local now, bags, equipped, mail, offered, received, hooks = 100, {}, {}, {}, {}, {}, {}
local inbox = {}
local cursor, lootItems, lootSources, rewards, choices = nil, {}, {}, {}, {}
local frames, callbacks, modules = {}, {}, {}
local popup, notices = nil, {}
local tradePartner = "Trade Partner-Realm"
StaticPopupDialogs = {}
YES, NO = "Yes", "No"
--- Capture native confirmations without automatically accepting them.
---@param id string Popup identifier.
---@param _ nil Unused format argument.
---@param __ nil Unused format argument.
---@param captured table Confirmation context.
---@return table dialog Confirmation placeholder.
function StaticPopup_Show(id, _, __, captured)
  popup = { id = id, data = captured }
  return {}
end
--- Clear a ledger in place.
---@param values table Saved entries.
function wipe(values) for key in pairs(values) do values[key] = nil end end
local link = "|cffffffff|Hitem:101:0:0|h[Example Item]|h|r"
local variant = "|cff0070dd|Hitem:101:1:0|h[Example Item]|h|r"
local other = "|cffffffff|Hitem:102:0:0|h[Other Item]|h|r"
local merchantBundle = 5
local names = { [link] = "Example Item", [variant] = "Example Item", [other] = "Other Item" }
local arrows, shots, otherProjectile = "item:201", "item:202", "item:203"
local soulShard = "item:6265"
local projectileTypes = { [arrows] = 2, [shots] = 3, [otherProjectile] = 1 }
names[arrows], names[shots], names[otherProjectile] = "Arrows", "Shots", "Other projectile"
names[soulShard] = "Soul Shard"
local legacySelected = link
local data = { entries = {}, actions = {}, bindings = {}, categories = {} }
SlackHacks = setmetatable({ db = {
  char = { inventoryLog = data },
  profile = { inventory = { inventoryLogEnabled = false },
    listviewBag = { customEssentialItems = {}, flagFilters = {} } },
} }, { __index = _G })
SlackHacks.Self = SlackHacks
--- Report addon-wide enable state independently of child module preferences.
---@return boolean enabled Addon preference.
function SlackHacks:IsEnabled() return self.rootEnabled ~= false end
--- Capture rejected settings and stale confirmations.
---@param message string User-facing notice.
function SlackHacks.prn(message) notices[#notices + 1] = message end
Enum = { ItemClass = {}, ItemQuality = { Common = 1 } }
MenuResponse = { Refresh = 1 }
UISpecialFrames = {}
NUM_BAG_SLOTS, NUM_REAGENTBAG_SLOTS, NUM_BANKBAGSLOTS, BANK_CONTAINER = 4, 1, 7, -1
ERR_TRADE_COMPLETE = "Trade complete."

--- Supply unused native frame methods.
local function noop() end
--- Supply an inspectable native widget mock.
---@param frameType string|nil Widget type.
---@param name string|nil Global name.
---@param parent table|nil Parent frame.
---@return table widget Mock widget.
local function widget(frameType, name, parent)
  local object = { frameType = frameType, name = name, parent = parent, shown = true, scripts = {}, points = {},
    hooks = {}, text = "", verticalScroll = 0 }
  --- Keep irrelevant native methods callable without inventing a legacy-dropdown field.
  setmetatable(object, { __index = function(_, key) if key ~= "legacy" then return noop end end })
  --- Record a widget's size.
  function object:SetSize(width, height) self.width, self.height = width, height end
  --- Record its height.
  function object:SetHeight(height) self.height = height end
  --- Record its width.
  function object:SetWidth(width) self.width = width end
  --- Resolve the scroll viewport from its actual top and bottom anchor offsets.
  ---@return number height Available viewport or explicit widget height.
  function object:GetHeight()
    if self.frameType == "ScrollFrame" then
      return self.parent.height + self.points.TOPLEFT[2] - self.points.BOTTOMRIGHT[2]
    end
    return self.height
  end
  --- Return its width.
  function object:GetWidth() return self.width end
  --- Estimate the full untruncated text width for narrow-quantity behavior.
  ---@return number width Natural text width.
  function object:GetStringWidth() return #self.text * (self.fontSize or 10) / 2 end
  --- Return its global name.
  function object:GetName() return self.name end
  --- Return the native font.
  function object:GetFont() return "mock-font", 10 end
  --- Record the chosen font without changing its inherited native color.
  ---@param font string Font file.
  ---@param size number Font size.
  function object:SetFont(font, size) self.font, self.fontSize = font, size end
  --- Capture explicit font colors on reusable rows.
  ---@param r number Red component.
  ---@param g number Green component.
  ---@param b number Blue component.
  ---@param a number|nil Alpha component.
  function object:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a or 1 } end
  --- Supply the inherited mail color or the most recently assigned color.
  ---@return number r Red component.
  ---@return number g Green component.
  ---@return number b Blue component.
  ---@return number a Alpha component.
  function object:GetTextColor() return unpack(rawget(self, "textColor") or { 0.2, 0.2, 0.2, 1 }) end
  --- Record text.
  function object:SetText(text) self.text = text end
  --- Return text.
  function object:GetText() return self.text end
  --- Record a normal icon.
  function object:SetNormalTexture(texture) self.normalTexture = texture end
  --- Record a row icon.
  function object:SetTexture(texture) self.texture = texture end
  --- Record a native script.
  function object:SetScript(event, handler) self.scripts[event] = handler end
  --- Record a script hook without replacing native behavior.
  function object:HookScript(event, handler) self.hooks[event] = handler end
  --- Record an anchor.
  function object:SetPoint(point, ...) self.points[point] = { ... } end
  --- Clear anchors.
  function object:ClearAllPoints() self.points = {} end
  --- Report visibility.
  function object:IsShown() return self.shown end
  --- Hide a widget.
  function object:Hide() self.shown = false end
  --- Show a widget and dispatch OnShow only on a transition.
  function object:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
  end
  --- Record conditional visibility.
  function object:SetShown(shown) self.shown = shown end
  --- Record a scroll child.
  function object:SetScrollChild(child) self.child = child end
  --- Return the viewport offset.
  function object:GetVerticalScroll() return self.verticalScroll end
  --- Change the viewport and dispatch native scrolling hooks.
  function object:SetVerticalScroll(offset)
    self.verticalScroll = offset
    if self.hooks.OnVerticalScroll then self.hooks.OnVerticalScroll(self, offset) end
  end
  --- Create a label.
  ---@param _ string|nil Unused region name.
  ---@param __ string|nil Unused draw layer.
  ---@param fontTemplate string|nil Native font template.
  ---@return table label Mock font string.
  function object:CreateFontString(_, __, fontTemplate)
    local label = widget("FontString", nil, self)
    label.fontTemplate = fontTemplate
    self.labels = rawget(self, "labels") or {}
    self.labels[#self.labels + 1] = label
    return label
  end
  --- Create an icon.
  function object:CreateTexture() return widget("Texture", nil, self) end
  --- Supply the hidden binding-tooltip scan.
  function object:NumLines() return 0 end
  --- Record a dropdown builder.
  function object:SetupMenu(builder) self.menuBuilder = builder end
  --- Record a dropdown label.
  function object:OverrideText(text) self.text = text end
  if name then frames[name] = object end
  return object
end

--- Create native controls and their template regions.
function CreateFrame(frameType, name, parent, template)
  local object = widget(frameType, name, parent)
  object.template = template
  if template == "SimplePanelTemplate" then
    object.Inset, object.Bg = widget(), widget()
  elseif template == "ButtonFrameTemplate" then
    object:SetSize(338, 424)
    object.Inset, object.Bg = widget(), widget()
    object.Inset:Show()
    object.TitleContainer = widget()
    object.TitleContainer.TitleText = widget()
    object.CloseButton = CreateFrame("Button", nil, object, "UIPanelCloseButtonDefaultAnchors")
    --- Set the native title bar's label.
    ---@param title string Window title.
    function object:SetTitle(title) self.TitleContainer.TitleText:SetText(title) end
    --- Set the native portrait asset.
    ---@param asset string Icon path.
    function object:SetPortraitToAsset(asset) self.portraitAsset = asset end
  elseif template == "SearchBoxTemplate" then
    object.Left, object.Middle, object.Right = widget(), widget(), widget()
  elseif template == "ScrollFrameTemplate" then
    object.ScrollBar = widget()
  elseif template == "UIPanelCloseButtonDefaultAnchors" then
    --- Simulate the native close template without altering module preferences.
    ---@param button table Native close button.
    object:SetScript("OnClick", function(button) button.parent:Hide() end)
  end
  return object
end
--- Match the native no-footer inset anchors.
---@param frame table ButtonFrameTemplate window.
function ButtonFrameTemplate_HideButtonBar(frame)
  frame.buttonBarHidden = true
  frame.Inset:SetPoint("TOPLEFT", 4, -60)
  frame.Inset:SetPoint("BOTTOMRIGHT", -6, 4)
end
UIParent = widget(); UIParent:SetSize(1200, 1200)
MerchantFrame, BankFrame, GuildBankFrame, TradeFrame = widget(), widget(), widget(), widget()
GameFontHighlightSmall = widget()
MailTextFontNormal, ChatFontNormal = widget(), widget()
GREEN_FONT_COLOR = { r = 0, g = 1, b = 0 }
RED_FONT_COLOR = { r = 1, g = 0.1, b = 0.1 }
GameTooltip = widget()
--- Capture tooltip links and reset supplemental lines between hovered items.
---@param itemLink string Saved item link.
function GameTooltip:SetHyperlink(itemLink) self.link, self.lines = itemLink, {} end
--- Capture the complete transfer destination/source in the item tooltip.
---@param text string Supplemental tooltip line.
function GameTooltip:AddLine(text)
  self.lines = rawget(self, "lines") or {}
  self.lines[#self.lines + 1] = text
end
GameTooltip_Hide = noop
HandleModifiedItemClick = noop
SearchBoxTemplate_OnTextChanged = noop
MenuUtil = { CreateContextMenu = noop }
--- Supply the current clock.
function GetTime() return now end
--- Supply deterministic saved timestamps.
function time() return 1700000000 + now end
date = os.date
--- Supply no optional configuration registry.
function LibStub() return nil end
--- Supply client branches used by the shared classifier.
function SlackHacks.isRetail() return true end
--- Supply the non-Forever client.
function SlackHacks.isForever() return false end
--- Include the reagent bag.
function SlackHacks.isRetailOrForever() return true end
--- Supply isolated Ace modules.
function SlackHacks:NewModule(name)
  local result = { events = {}, timers = {} }
  modules[name] = result
  --- Report the module lifecycle state.
  function result:IsEnabled() return self.enabled ~= false end
  --- Set a desired module state without activating it.
  ---@param enabled boolean Desired state.
  function result:SetEnabledState(enabled) self.enabled = enabled end
  --- Activate the module as AceAddon does, independently of its desired state.
  ---@return boolean changed Whether activation occurred.
  function result:Enable()
    self.enabled = true
    if self.active then return false end
    self.active = true
    if self.OnEnable then self:OnEnable() end
    return true
  end
  --- Stop the module while preserving its saved configuration.
  ---@return boolean changed Whether deactivation occurred.
  function result:Disable()
    self.enabled = false
    if not self.active then return false end
    self.active = false
    if self.OnDisable then self:OnDisable() end
    return true
  end
  --- Record event registration.
  function result:RegisterEvent(event, method)
    assert(type(self[method]) == "function", "AceEvent requires an existing handler: " .. method)
    self.events[event] = method
  end
  --- Record a coalesced timer.
  function result:ScheduleTimer(method, delay)
    local timer = { method = method, delay = delay }
    self.timers[#self.timers + 1] = timer
    return timer
  end
  --- Record periodic maintenance independently of debug preferences.
  function result:ScheduleRepeatingTimer(method, delay)
    self.repeating = { method = method, delay = delay }
  end
  --- Record timer cancellation.
  function result:CancelTimer(timer) timer.cancelled = true end
  --- Remove event registrations when disabled.
  function result:UnregisterAllEvents() self.events = {} end
  --- Cancel all module timers when disabled.
  function result:CancelAllTimers()
    for _, timer in ipairs(self.timers) do timer.cancelled = true end
    if self.repeating then self.repeating.cancelled = true end
  end
  return result
end
--- Record AceDB profile lifecycle callbacks.
function SlackHacks.db.RegisterCallback(receiver, event, method) callbacks[event] = method end
SlackHacks.db.UnregisterAllCallbacks = noop
--- Capture post-hooks without executing or replacing protected APIs.
function hooksecurefunc(target, name, callback)
  if type(target) == "string" then hooks[target] = name
  else hooks[target] = hooks[target] or {}; hooks[target][name] = callback end
end
C_Item = {}
--- Supply native item metadata to the real bag classifier.
function C_Item.GetItemInfo(itemLink)
  return names[itemLink], itemLink, itemLink == variant and 3 or 1, 10, 1, "", "", itemLink == other and 1 or 20, "",
    "item-icon", 1, projectileTypes[itemLink] and 6 or 0, projectileTypes[itemLink] or 0, 0, 0, nil, false
end
--- Supply instant item types even when the full item cache is unavailable.
---@param itemLink string Item link.
---@return number itemID Item identifier.
---@return string itemType Item type.
---@return string itemSubtype Item subtype.
---@return string equipLoc Equipment slot.
---@return string icon Item icon.
---@return number classID Item class.
---@return number subclassID Item subclass.
function C_Item.GetItemInfoInstant(itemLink)
  return 201, "", "", "", "icon", projectileTypes[itemLink] and 6 or 0, projectileTypes[itemLink] or 0
end
LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %s.", "You create: %sx%d."
C_Container = { UseContainerItem = noop }
--- Supply current bag capacity.
function C_Container.GetContainerNumSlots(bag) return #(bags[bag] or {}) end
--- Supply a current bag stack.
function C_Container.GetContainerItemInfo(bag, slot) return (bags[bag] or {})[slot] end
--- Supply equipped items, which must not be mistaken for losses.
function GetInventoryItemLink(unit, slot) return equipped[slot] end
--- Supply equipped item quantities.
function GetInventoryItemCount() return 1 end
--- Supply a staged mail link.
function GetSendMailItemLink(slot) return mail[slot] and mail[slot].link end
--- Supply native mail attachment counts (the fourth return value).
function GetSendMailItem(slot) return "name", 101, "icon", mail[slot].count end
--- Supply staged outgoing trade links.
function GetTradePlayerItemLink(slot) return offered[slot] and offered[slot].link end
--- Supply staged outgoing trade quantities.
function GetTradePlayerItemInfo(slot) return "name", "icon", offered[slot].count end
--- Supply the other player's trade links.
function GetTradeTargetItemLink(slot) return received[slot] and received[slot].link end
--- Supply the other player's trade quantities.
function GetTradeTargetItemInfo(slot) return "name", "icon", received[slot].count end
--- Supply the client-formatted partner name while the trade unit is available.
---@param unit string Native unit token.
---@return string|nil name Trade partner.
function SlackHacks.unitFullName(unit) assert(unit == "NPC"); return tradePartner end
--- Supply cursor ownership.
function GetCursorInfo() if cursor then return "item", 101, cursor end end
DeleteCursorItem, SendMail, GetQuestReward, PostAuction, BuyMerchantItem = noop, noop, noop, noop, noop
TakeInboxItem, AutoLootMailItem = noop, noop
--- Supply the visible inbox message count.
---@return number count Messages in the mailbox.
function GetInboxNumItems() return #inbox end
--- Supply exact attachment links before a native pickup request.
---@param index number Message index.
---@param slot number Attachment slot.
---@return string|nil link Attachment link.
function GetInboxItemLink(index, slot)
  local item = inbox[index] and inbox[index][slot]
  return item and item.link
end
--- Supply native inbox attachment quantities.
---@param index number Message index.
---@param slot number Attachment slot.
---@return string|nil name Attachment name.
---@return number|nil itemID Item identity.
---@return string|nil icon Item icon.
---@return number|nil count Attachment quantity.
function GetInboxItem(index, slot)
  local item = inbox[index] and inbox[index][slot]
  if item then return "Inbox item", 101, "icon", item.count end
end
--- Supply the catalog link after a native vendor purchase request.
---@param index number Merchant item index.
---@return string link Merchant item.
function GetMerchantItemLink(index) assert(index == 1); return link end
--- Supply legacy vendor bundle quantities.
---@param index number Merchant item index.
---@return string name Item name.
---@return string icon Item icon.
---@return number price Bundle price.
---@return number quantity Default bundle size.
function GetMerchantItemInfo(index) assert(index == 1); return "Merchant item", "icon", 1, merchantBundle end
--- Supply the native legacy sell-slot item identity without removing it from the bags.
function GetAuctionSellItemInfo()
  return "name", "icon", 5, 1, true, 1, 1, 20, 5, 101, "legacy-guid"
end
--- Resolve the exact selected legacy auction variant.
function C_Item.GetItemLinkByGUID() return legacySelected end
C_MerchantFrame = { SellAllJunkItems = noop }
--- Supply modern vendor bundle quantities.
---@param index number Merchant item index.
---@return table info Vendor catalog information.
function C_MerchantFrame.GetItemInfo(index) assert(index == 1); return { stackCount = merchantBundle } end
C_AuctionHouse = { PostItem = noop, PostCommodity = noop, ConfirmPostItem = noop, ConfirmPostCommodity = noop }
--- Supply current loot slots.
function GetNumLootItems() return #lootItems end
--- Supply loot links before they clear.
function GetLootSlotLink(slot) return lootItems[slot].link end
--- Supply loot quantities.
function GetLootSlotInfo(slot) return "icon", "name", lootItems[slot].count end
--- Supply corpse/node source GUIDs.
function GetLootSourceInfo(slot) return lootSources[slot], lootItems[slot].count end
C_Spell = {}
--- Supply localized native gathering spell names.
function C_Spell.GetSpellName(spellID) return tostring(spellID) end
--- Supply guaranteed quest rewards.
function GetNumQuestRewards() return #rewards end
--- Supply no choice rewards.
function GetNumQuestChoices() return #choices end
--- Supply reward links.
function GetQuestItemLink(kind, index) return (kind == "choice" and choices or rewards)[index].link end
--- Supply reward quantities.
function GetQuestItemInfo(kind, index) return "name", "icon", (kind == "choice" and choices or rewards)[index].count end

assert(loadfile("ListviewBag.lua"))()
assert(loadfile("InventoryLog.lua"))()
local log = SlackHacks.InventoryLog
log:OnInitialize()
assert(not log:IsEnabled() and not log.active, "The opt-in Ace3 module must start disabled")

--- Make one stack.
---@param itemLink string Link.
---@param count number Quantity.
---@return table item Container information.
local function stack(itemLink, count)
  return { hyperlink = itemLink, stackCount = count, quality = 1, isBound = false }
end
--- Start a scenario with a clean ledger and a stable inventory.
---@param count number Initial quantity.
local function reset(count)
  bags, equipped, mail, offered, received = { [0] = { stack(link, count) } }, {}, {}, {}, {}
  inbox = {}
  if MailFrame then MailFrame:Hide() end
  cursor = nil
  tradePartner = "Trade Partner-Realm"
  data.entries, data.actions, data.bindings, data.categories = {}, {}, {}, {}
  MerchantFrame:Hide(); BankFrame:Hide(); GuildBankFrame:Hide(); TradeFrame:Hide()
  log:GetSettings().actionsToLog = {}
  log:GetSettings().entriesToKeep = 3000
  log:SetLoggingEnabled(true)
end
--- Check an exact committed action and quantity.
---@param index number Entry index.
---@param action string Expected action.
---@param quantity number Expected quantity.
---@param direction number Expected sign.
local function check(index, action, quantity, direction)
  local entry = data.entries[index]
  assert(entry and entry.action == action and entry.quantity == quantity and entry.direction == direction,
    "Incorrect committed action at entry " .. index)
end

reset(5)
assert(#data.entries == 0, "Enabling must not log possessions as new gains")
log:Expect("Looted", link, 1, 1)
bags[0][1].stackCount = 6
log:Reconcile()
check(1, "Looted", 1, 1)
assert(data.entries[1].category == "consumables" and data.entries[1].binding == "unbound")
log:Reconcile()
assert(#data.entries == 1, "Repeated notifications must not duplicate entries")
bags[0][1].stackCount = 7
log:Reconcile()
assert(#data.entries == 1, "Unmatched inventory gains must not be recorded")
reset(5)
NUM_REAGENTBAG_SLOTS = nil
log:Expect("Looted", other, 2, 1)
bags[5] = { stack(other, 2) }
log:Reconcile()
check(1, "Looted", 2, 1)
assert(data.entries[1].link == other, "Reagent-bag logging must follow the supported client's bag enumeration")
NUM_REAGENTBAG_SLOTS = 1

reset(5)
log:Expect("Sold", link, 2, -1)
bags[0][1].stackCount = 2
log:Reconcile()
check(1, "Sold", 2, -1)
assert(#data.entries == 1, "Unmatched losses beyond a confirmed sale must be ignored")

for _, consumedLink in ipairs({ link, variant, other, arrows, shots, soulShard }) do
  reset(5)
  bags[0] = { stack(consumedLink, 5) }
  log:ResetTracking()
  log:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "player", "consume-item", 688)
  bags[0][1].stackCount = 4
  log:Reconcile()
  bags[0][1].stackCount = 2
  log:Reconcile()
  assert(#data.entries == 0, "Spell reagents, Soul Shards, ammo, and direct item consumption must not be logged")
  log:Expect("Purchased", consumedLink, 1, 1)
  bags[0][1].stackCount = 3
  log:Reconcile()
  check(1, "Purchased", 1, 1)
  MerchantFrame:Show()
  hooks[C_Container].UseContainerItem(0, 1)
  bags[0][1].stackCount = 1
  log:Reconcile()
  check(2, "Sold", 2, -1)
  assert(#data.entries == 2, "Ignored consumption must advance the baseline without hiding later confirmed transactions")
end
reset(5)
log:Record({ link = link }, "Unknown", 1, -1)
log:Record({ link = link }, "Used", 1, -1)
assert(#data.entries == 0, "Retired actions must not create entries even through direct recording callbacks")
local historical = { { link = link, name = "Old unknown item", action = "Unknown", quantity = 1 },
  { link = other, name = "Old used item", action = "Used", quantity = 1 } }
data.entries, data.actions.Unknown, data.actions.Used = historical, false, false
log:MigrateCharacterSettings(SlackHacks.db.char)
assert(data.entries == historical and #log:GetFilteredEntries("") == 2
  and historical[1].action == "Unknown" and historical[2].action == "Used",
  "Retired action filters must not hide or delete existing historical entries")

reset(5)
log:OnItemCreated("CHAT_MSG_LOOT", LOOT_ITEM_CREATED_SELF:format(link))
assert(#data.entries == 0, "Creation messages must wait for an actual inventory gain")
bags[0][1].stackCount = 6
log:OnAcquiredBagUpdate()
check(1, "Created", 1, 1)
reset(5)
bags[0][1].stackCount = 7
log:OnItemCreated("CHAT_MSG_LOOT", LOOT_ITEM_CREATED_SELF_MULTIPLE:format(link, 2))
check(1, "Created", 2, 1)
assert(log.events.CHAT_MSG_LOOT == "OnItemCreated", "Native creation confirmations must be observed")
reset(5)
local creationSingle, creationMultiple = LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE
LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE = "Hergestellt: %s.", "Hergestellt: %s (%d)."
log:OnItemCreated("CHAT_MSG_LOOT", LOOT_ITEM_CREATED_SELF_MULTIPLE:format(variant, 3))
bags[0][2] = stack(variant, 3)
log:OnAcquiredBagUpdate()
check(1, "Created", 3, 1)
assert(data.entries[1].link == variant, "Localized creation confirmations must preserve exact item variants")
LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE = creationSingle, creationMultiple
reset(5)
log:OnItemCreated("CHAT_MSG_LOOT", "You receive loot: " .. link .. "x2.")
log:OnItemCreated("CHAT_MSG_LOOT", "Other Player creates: " .. link .. "x2.")
bags[0][1].stackCount = 7
log:Reconcile()
assert(#data.entries == 0, "Unrecognized loot messages must not create speculative gain records")
reset(5)
log:GetSettings().actionsToLog.Created = false
bags[0][1].stackCount = 6
log:OnItemCreated("CHAT_MSG_LOOT", LOOT_ITEM_CREATED_SELF:format(link))
assert(#data.entries == 0, "Disabled Created actions must not fall through to Unknown")
reset(5)
bags[0] = {}
log:ResetTracking()
log:OnItemCreated("CHAT_MSG_LOOT", LOOT_ITEM_CREATED_SELF:format(link))
bags[0][1] = stack(link, 1)
log:OnAcquiredBagUpdate()
log:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "player", "immediate-use", 7001)
bags[0] = {}
log:Reconcile()
check(1, "Created", 1, 1)
assert(#data.entries == 1, "Immediate consumption must not erase a confirmed creation or add a Used entry")

for _, ammoLink in ipairs({ arrows, shots }) do
  reset(5)
  bags[0] = { stack(ammoLink, 5) }
  log:ResetTracking()
  log:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "player", "ammo-fired", 75)
  bags[0][1].stackCount = 3
  log:Reconcile()
  bags[0][1].stackCount = 2
  log:Reconcile()
  assert(#data.entries == 0, "Unattributed arrow and bullet consumption must not create log entries")
  bags[0][1].stackCount = 4
  log:Reconcile()
  assert(#data.entries == 0, "Unattributed ammo gains must also remain unlogged")
  log:Expect("Purchased", ammoLink, 2, 1)
  bags[0][1].stackCount = 6
  log:Reconcile()
  check(1, "Purchased", 2, 1)
  log:Expect("Sold", ammoLink, 1, -1)
  bags[0][1].stackCount = 3
  log:Reconcile()
  check(2, "Sold", 1, -1)
  assert(#data.entries == 2, "Matched ammo transactions must log while unmatched consumption stays suppressed")
  log:Expect("Destroyed", ammoLink, 3, -1)
  bags[0] = {}
  log:Reconcile()
  check(3, "Destroyed", 3, -1)
  assert(#data.entries == 3, "Explicitly destroying the final ammo stack must still be logged")
end
reset(5)
local cachedItemInfo = C_Item.GetItemInfo
--- Simulate ammo whose full item information has not yet loaded.
---@param itemLink string Item link.
---@return any ... Cached item information for other items.
function C_Item.GetItemInfo(itemLink)
  if itemLink ~= arrows then return cachedItemInfo(itemLink) end
end
bags[0] = { stack(arrows, 5) }
log:ResetTracking()
bags[0][1].stackCount = 4
log:Reconcile()
assert(#data.entries == 0, "Ammo consumption must stay suppressed before its full item metadata is cached")
C_Item.GetItemInfo = cachedItemInfo
reset(5)
bags[0] = { stack(otherProjectile, 5) }
log:ResetTracking()
bags[0][1].stackCount = 4
log:Reconcile()
assert(#data.entries == 0, "Unmatched losses of other projectile types must remain unlogged")

reset(5)
log:Expect("Auctioned", link, 5, -1)
log:Reconcile()
assert(#data.entries == 0, "A failed request must not log success")
now = now + 6
bags[0][1].stackCount = 4
log:Reconcile()
assert(#data.entries == 0, "Expired requests must not turn unrelated later losses into records")

reset(5)
MerchantFrame:Show()
hooks[C_Container].UseContainerItem(0, 1)
bags[0][1].stackCount = 3
log:Reconcile()
check(1, "Sold", 2, -1)
reset(5)
bags[0][1].isBound = true
bags[0][2] = stack(link, 2)
log:ResetTracking()
MerchantFrame:Show()
SlackHacks.db.profile.listviewBag.customEssentialItems[101] = true
hooks[C_Container].UseContainerItem(0, 2)
bags[0][2] = nil
log:Reconcile()
assert(data.entries[1].binding == "unbound" and data.entries[1].category == "consumables",
  "Actions must retain source binding without inheriting Listview Bag's custom Essentials category")
assert(SlackHacks.ListviewBag:GetInventoryLogCategory({ itemID = 6948, classID = 15 }) == "other"
  and SlackHacks.ListviewBag:GetInventoryLogCategory({ itemID = 2901, classID = 2,
    equipLoc = "INVTYPE_WEAPONMAINHAND" }) == "equipment"
  and SlackHacks.ListviewBag:GetInventoryLogCategory({ itemID = 6265, classID = 7,
    isCraftingReagent = true }) == "reagents",
  "Built-in Essentials must retain their normal ledger categories")
SlackHacks.db.profile.listviewBag.customEssentialItems[101] = nil
reset(5)
MerchantFrame:Show()
bags[0][1].quality = 0
log:ResetTracking()
hooks[C_MerchantFrame].SellAllJunkItems()
bags[0] = {}
log:Reconcile()
check(1, "Sold", 5, -1)
reset(1)
equipped[1], bags[0] = link, {}
log:Reconcile()
assert(#data.entries == 0, "Equipping an item is neither a gain nor a loss")

reset(5)
mail[1], bags[0] = { link = link, count = 5 }, {}
log:Reconcile()
assert(#data.entries == 0, "Attaching items is not successful mail")
hooks.SendMail("Failed-Recipient")
mail, bags[0] = {}, { stack(link, 5) }
log:OnMailFailed()
log:Reconcile()
assert(#data.entries == 0, "Failed mail must not create gains or losses")
mail[1], bags[0] = { link = link, count = 5 }, {}
log:Reconcile()
hooks.SendMail("Mail Recipient-Realm")
mail = {}
now = now + 20
log:Reconcile()
assert(#data.entries == 0, "Submitted mail must remain in escrow until success or failure")
log:OnMailSuccess()
log:Reconcile()
check(1, "Mailed", 5, -1)
assert(data.entries[1].category == "consumables", "Staging must preserve captured filtering metadata")
assert(data.entries[1].counterparty == "Mail Recipient-Realm",
  "Confirmed mail must retain the recipient submitted with its attachments, not the failed draft")

reset(5)
MailFrame = widget()
MailFrame:SetHeight(424)
inbox = { { { link = link, count = 5 } } }
log:OnInboxUpdate("MAIL_SHOW")
assert(#data.entries == 0, "Opening mail must not count unclaimed attachments as received")
hooks.TakeInboxItem(1)
log:OnInboxUpdate("MAIL_INBOX_UPDATE")
hooks.TakeInboxItem(1, 1)
assert(#data.entries == 0, "Repeated pickup requests must wait for an actual inventory gain")
inbox[1][1] = nil
log:OnInboxUpdate("MAIL_INBOX_UPDATE")
bags[0][1].stackCount = 10
log:OnAcquiredBagUpdate()
check(1, "Mailed", 5, 1)
assert(not data.entries[1].counterparty, "Received mail must not store a fake outgoing recipient")
bags[0][1].stackCount = 15
log:Reconcile()
assert(#data.entries == 1, "Repeated pickup clicks must not leave duplicate mail correlations")

reset(5)
MailFrame:Show()
inbox = { { { link = link, count = 5 } }, { { link = link, count = 5 } } }
log:OnInboxUpdate("MAIL_SHOW")
hooks.AutoLootMailItem(1)
table.remove(inbox, 1)
log:OnInboxUpdate("MAIL_INBOX_UPDATE")
hooks.AutoLootMailItem(1)
bags[0][1].stackCount = 15
log:OnAcquiredBagUpdate()
check(1, "Mailed", 5, 1)
check(2, "Mailed", 5, 1)
assert(#data.entries == 2, "Reindexed identical messages must retain separate pickup requests")

reset(5)
MailFrame:Show()
inbox = { { { link = variant, count = 2 }, { link = other, count = 3 } } }
log:OnInboxUpdate("MAIL_SHOW")
hooks.AutoLootMailItem(1)
inbox[1] = {}
log:OnInboxUpdate("MAIL_INBOX_UPDATE")
bags[0][2], bags[0][3] = stack(variant, 2), stack(other, 3)
log:OnAcquiredBagUpdate()
local claimed = {}
for _, entry in ipairs(data.entries) do claimed[entry.link] = entry end
assert(#data.entries == 2 and claimed[variant].action == "Mailed" and claimed[variant].quantity == 2
  and claimed[other].action == "Mailed" and claimed[other].quantity == 3,
  "Bulk mail pickup must attribute each exact attachment and its quantity")

reset(5)
MailFrame:Show()
inbox = { { { link = link, count = 1 } } }
log:OnInboxUpdate("MAIL_SHOW")
hooks.TakeInboxItem(1, 1)
log:Reconcile()
assert(#data.entries == 0, "A failed pickup must not record received mail")
now = now + 6
bags[0][1].stackCount = 6
log:Reconcile()
assert(#data.entries == 0, "An expired pickup must not label a later unrelated gain as received mail")

reset(5)
MailFrame:Show()
inbox = { { { link = link, count = 1 } } }
log:OnInboxUpdate("MAIL_SHOW")
inbox = {}
log:OnInboxUpdate("MAIL_INBOX_UPDATE")
bags[0][1].stackCount = 6
log:Reconcile()
assert(#data.entries == 0, "Removing mail without requesting a pickup must not create a received entry")

reset(5)
MailFrame:Show()
inbox = { { { link = link, count = 1 } } }
log:OnInboxUpdate("MAIL_SHOW")
log:GetSettings().actionsToLog.Mailed = false
hooks.TakeInboxItem(1, 1)
bags[0][1].stackCount = 6
log:OnAcquiredBagUpdate()
assert(#data.entries == 0, "Disabling Mailed recording must also suppress received attachments")

reset(5)
MailFrame:Show()
inbox = { { { link = link, count = 1 } } }
log:OnInboxUpdate("MAIL_SHOW")
hooks.TakeInboxItem(1, 1)
log:OnInboxUpdate("MAIL_CLOSED")
bags[0][1].stackCount = 6
log:OnAcquiredBagUpdate()
check(1, "Mailed", 1, 1)
MerchantFrame:Show()
hooks[C_Container].UseContainerItem(0, 1)
bags[0] = {}
log:Reconcile()
check(2, "Sold", 6, -1)
assert(#data.entries == 2, "Received mail must be captured before an immediate resale hides its gain")
MailFrame = nil

reset(5)
tradePartner = "Cancelled Partner-Realm"
log:OnInteraction("TRADE_SHOW")
offered[1], bags[0] = { link = link, count = 5 }, {}
received[1] = { link = other, count = 2 }
log:OnTradeUpdated()
log:Reconcile()
assert(#data.entries == 0, "Offering a trade is not a successful trade")
log:OnInteraction("TRADE_CLOSED")
offered, received = {}, {}
bags[0] = { stack(link, 5) }
log:Reconcile()
assert(#data.entries == 0, "Cancelled trades must not create activity")
tradePartner = "Confirmed Partner-Realm"
log:OnInteraction("TRADE_SHOW")
offered[1], received[1], bags[0] = { link = link, count = 5 }, { link = other, count = 2 }, {}
log:OnTradeUpdated()
log:Reconcile()
log:OnInteraction("TRADE_CLOSED")
tradePartner = nil
offered, received, bags[0] = {}, {}, { stack(other, 2) }
log:OnInfoMessage("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
log:Reconcile()
local traded = {}
for _, entry in ipairs(data.entries) do traded[entry.link] = entry end
assert(#data.entries == 2 and traded[link].action == "Traded" and traded[link].direction == -1
  and traded[other].action == "Traded" and traded[other].quantity == 2 and traded[other].direction == 1)
assert(traded[link].counterparty == "Confirmed Partner-Realm"
  and traded[other].counterparty == "Confirmed Partner-Realm",
  "Both confirmed trade directions must retain the partner after the window and NPC unit disappear")

reset(5)
tradePartner = nil
log:OnInteraction("TRADE_SHOW")
offered[1], received[1], bags[0] = { link = link, count = 5 }, { link = link, count = 5 }, {}
tradePartner = "Late Partner-Realm"
log:OnTradeUpdated()
log:Reconcile()
log:OnInteraction("TRADE_CLOSED")
offered, received, bags[0] = {}, {}, { stack(link, 5) }
log:OnTradeUpdated()
log:OnInfoMessage("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
log:Reconcile()
check(1, "Traded", 5, -1); check(2, "Traded", 5, 1)
assert(#data.entries == 2 and data.entries[1].counterparty == "Late Partner-Realm"
  and data.entries[2].counterparty == "Late Partner-Realm",
  "Trade updates must capture a late-available partner for both sides of a net-zero exchange")

reset(5)
bags[-1] = { stack(link, 100) }
log:OnInteraction("BANKFRAME_OPENED")
bags[0][1].stackCount, bags[-1][1].stackCount = 3, 102
log:Reconcile()
check(1, "Banked", 2, -1)
bags[0][1].stackCount = 2
log:Reconcile()
assert(#data.entries == 1, "A merely open bank must not record unrelated losses as deposits")

reset(5)
lootItems, lootSources = { { link = link, count = 2 } }, { "Creature-0-1-2-3-4-5" }
log:OnLootOpened("LOOT_READY")
log:OnLootSlotCleared("LOOT_SLOT_CLEARED", 1)
bags[0][1].stackCount = 7
log:Reconcile()
check(1, "Looted", 2, 1)
reset(5)
lootSources = { "GameObject-0-1-2-3-4-5" }
log:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2575)
log:OnLootOpened("LOOT_READY")
log:OnLootOpened("LOOT_OPENED")
log:OnLootSlotCleared("LOOT_SLOT_CLEARED", 1)
bags[0][1].stackCount = 7
log:Reconcile()
check(1, "Gathered", 2, 1)
reset(5)
lootItems = { { link = link, count = 2 }, { link = other, count = 1 } }
lootSources = { "GameObject-0-1-2-3-4-5", "GameObject-0-1-2-3-4-5" }
log:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2575)
log:OnLootOpened("LOOT_READY")
log:OnLootSlotCleared("LOOT_SLOT_CLEARED", 1)
log:OnLootSlotCleared("LOOT_SLOT_CLEARED", 2)
bags[0] = { stack(link, 7), stack(other, 1) }
log:Reconcile()
assert(#data.entries == 2 and data.entries[1].action == "Gathered" and data.entries[2].action == "Gathered",
  "Every item in one resource node must share its gathering attribution")
reset(5)
lootItems, lootSources = { { link = link, count = 2 } }, { "GameObject-0-1-2-3-4-5" }
log:OnLootOpened("LOOT_READY")
log:OnLootSlotCleared("LOOT_SLOT_CLEARED", 1)
bags[0][1].stackCount = 7
log:Reconcile()
assert(#data.entries == 0, "Unidentified object loot must not be labeled or recorded speculatively")

reset(5)
rewards = { { link = link, count = 2 } }
log:OnQuestComplete()
log:OnQuestTurnedIn()
bags[0][1].stackCount = 7
log:Reconcile()
check(1, "Quest", 2, 1)
reset(5)
rewards, choices = {}, { { link = link, count = 1 }, { link = other, count = 1 } }
log:OnQuestComplete()
hooks.GetQuestReward(2)
log:OnQuestTurnedIn()
bags[0][2] = stack(other, 1)
log:Reconcile()
check(1, "Quest", 1, 1)
bags[0][1].stackCount = 6
log:Reconcile()
assert(#data.entries == 1, "Unselected quest rewards or unrelated gains must not create extra entries")
choices = {}

reset(5)
cursor = link
bags[0] = {}
log:OnCursorChanged()
log:Reconcile()
assert(#data.entries == 0, "Picked-up stacks are not destroyed")
cursor = nil
hooks.DeleteCursorItem()
log:Reconcile()
check(1, "Destroyed", 5, -1)

reset(5)
local location = {
  --- Confirm the mocked native item is in a bag.
  IsBagAndSlot = function() return true end,
  --- Supply its slot.
  GetBagAndSlot = function() return 0, 1 end,
}
hooks[C_AuctionHouse].PostCommodity(location, 1, 2)
now = now + 6
log:Reconcile()
hooks[C_AuctionHouse].ConfirmPostCommodity(location, 1, 2)
bags[0][1].stackCount = 3
log:Reconcile()
check(1, "Auctioned", 2, -1)
bags[0][1].stackCount = 2
log:Reconcile()
assert(#data.entries == 1, "Unmatched losses after posting must not create extra auction or Unknown entries")
reset(5)
legacySelected = link
log:OnAuctionSellChanged()
hooks.PostAuction(1, 1, 1, 2, 1, false)
log:Reconcile()
assert(#data.entries == 0, "Selecting the legacy sell slot must not duplicate owned inventory")
now = now + 6
log:Reconcile()
hooks.PostAuction(1, 1, 1, 2, 1, true)
bags[0][1].stackCount = 3
log:Reconcile()
check(1, "Auctioned", 2, -1)
reset(5)
bags[0][2] = stack(variant, 1)
log:ResetTracking()
log:Expect("Sold", link, 1, -1)
bags[0][2] = nil
log:Reconcile()
assert(#data.entries == 0, "A transaction for one variant must not record an unmatched loss of another")

reset(5)
MerchantFrame:Show()
bags[0] = {}
log:ResetTracking()
hooks.BuyMerchantItem(1)
assert(#data.entries == 0, "Requesting a purchase must not record an unconfirmed gain")
bags[0] = { stack(link, merchantBundle) }
log:OnAcquiredBagUpdate()
check(1, "Purchased", merchantBundle, 1)
hooks[C_Container].UseContainerItem(0, 1)
bags[0] = {}
log:Reconcile()
check(2, "Sold", merchantBundle, -1)
assert(#data.entries == 2 and log.events.BAG_UPDATE == "OnAcquiredBagUpdate",
  "A quick purchase and resale must record both transactions rather than disappear as a net-zero delta")
reset(5)
hooks.BuyMerchantItem(1, 2)
bags[0][1].stackCount = 7
log:OnAcquiredBagUpdate()
check(1, "Purchased", 2, 1)
assert(data.entries[1].stackSize == 20, "Purchase records must capture native stackability")
reset(5)
bags[0][1].stackCount = 6
hooks.BuyMerchantItem(1, 1)
check(1, "Purchased", 1, 1)
assert(#data.entries == 1, "An already-visible purchase gain must be reconciled directly from its native hook")
reset(5)
local modernMerchantInfo = C_MerchantFrame.GetItemInfo
C_MerchantFrame.GetItemInfo = nil
hooks.BuyMerchantItem(1)
bags[0][1].stackCount = 10
log:Reconcile()
check(1, "Purchased", 5, 1)
C_MerchantFrame.GetItemInfo = modernMerchantInfo
reset(5)
hooks.BuyMerchantItem(1, 1)
log:OnAcquiredBagUpdate()
assert(#data.entries == 0, "Failed purchases must not create ledger entries")
now = now + 6
bags[0][1].stackCount = 6
log:Reconcile()
assert(#data.entries == 0, "An expired purchase request must not label a later unmatched gain")
reset(5)
hooks.BuyMerchantItem(1, 1)
bags[0][2] = stack(other, 2)
log:OnAcquiredBagUpdate()
assert(#data.entries == 0, "An unconfirmed purchase must not prematurely reconcile unrelated bag updates")
log:Expect("Looted", other, 2, 1)
log:Reconcile()
check(1, "Looted", 2, 1)
reset(5)
log:GetSettings().actionsToLog.Purchased = false
hooks.BuyMerchantItem(1, 2)
bags[0][1].stackCount = 7
log:OnAcquiredBagUpdate()
assert(#data.entries == 0, "Disabled purchases must still consume their deltas, not become Unknown")

reset(5)
log:GetSettings().actionsToLog.Sold = false
MerchantFrame:Show()
hooks[C_Container].UseContainerItem(0, 1)
bags[0][1].stackCount = 3
log:Reconcile()
assert(#data.entries == 0, "Disabled Sold actions must not be relabeled Unknown")
reset(5)
log:GetSettings().actionsToLog.Mailed = false
mail[1], bags[0] = { link = link, count = 5 }, {}
log:Reconcile()
hooks.SendMail()
mail = {}
log:OnMailSuccess()
log:Reconcile()
assert(#data.entries == 0, "Disabled confirmed transfers must still reconcile their inventory changes")
reset(5)
log:GetSettings().actionsToLog.Unknown, log:GetSettings().actionsToLog.Used = true, true
bags[0][1].stackCount = 6
log:Reconcile()
assert(log:GetSettings().actionsToLog.Unknown == nil and log:GetSettings().actionsToLog.Used == nil,
  "Retired recording preferences must be removed from current-version development profiles")
log:Reconcile()
assert(#data.entries == 0, "Stale retired preferences must never re-enable unmatched or consumption records")

reset(5)
for _, action in ipairs(log.ACTIONS) do log:Record({ link = link }, action.id, 1, 1) end
assert(#data.entries == #log.ACTIONS, "Every action must be recorded by default")
for _, action in ipairs(log.ACTIONS) do log:GetSettings().actionsToLog[action.id] = false end
for _, action in ipairs(log.ACTIONS) do log:Record({ link = link }, action.id, 1, 1) end
assert(#data.entries == #log.ACTIONS, "Every action must support disabling recording independently")
reset(5)
for index = 1, 5 do log:Record({ link = link }, "Sold", index, -1) end
for _, invalid in ipairs({ "", "abc", "0", "-1", "2.5", "inf", 0 / 0, math.huge, -math.huge }) do
  assert(log:ValidateEntriesToKeep(invalid) ~= true)
end
log:SetEntriesToKeep("2.5")
assert(log:GetSettings().entriesToKeep == 3000 and #data.entries == 5 and #notices > 0)
log:SetEntriesToKeep("2")
assert(#data.entries == 2 and data.entries[1].quantity == 4 and data.entries[2].quantity == 5)
log:Record({ link = link }, "Sold", 6, -1)
log:Record({ link = link }, "Sold", 7, -1)
assert(#data.entries == 4, "Changing retention must preserve temporary insertion overflow")
log:Purge()
assert(#data.entries == 2 and data.entries[1].quantity == 6 and data.entries[2].quantity == 7)
log:SetEntriesToKeep("10")
assert(#data.entries == 2 and data.entries[1].quantity == 6, "Raising retention must preserve existing history")

reset(5)
for index = 1, 3007 do
  log:Record({ link = link, name = "Example Item", binding = "unbound", category = "consumables" },
    index % 2 == 0 and "Sold" or "Created", index, index % 2 == 0 and -1 or 1)
end
assert(#data.entries == 3007, "Insertion must allow overflow instead of pruning every time")
log:Purge()
assert(#data.entries == 3000 and data.entries[1].quantity == 8 and data.entries[3000].quantity == 3007)
local visible = log:GetFilteredEntries("EXAMPLE")
assert(#visible == 3000 and visible[1].quantity == 3007 and visible[3000].quantity == 8)
data.actions.Sold = false
visible = log:GetFilteredEntries("example")
assert(#visible == 1500 and visible[1].action == "Created")
data.categories.consumables = false
assert(#log:GetFilteredEntries("") == 0)
data.categories.consumables, data.actions.Sold = true, true
data.bindings.unbound = false
assert(#log:GetFilteredEntries("") == 0)
data.bindings.unbound = true
assert(#log:GetFilteredEntries("[") == 0, "Search must use literal text rather than Lua patterns")

local titles, selections, filterButtons = {}, {}, {}
local root = {
  --- Capture section titles.
  CreateTitle = function(_, title) titles[title] = true end,
  CreateDivider = noop,
  --- Capture shared menu selections.
  CreateCheckbox = function(_, title, checked, select) selections[title] = { checked = checked, select = select } end,
  --- Supply native refresh responses.
  CreateButton = function(_, title, select) filterButtons[title] = select; return { SetResponse = noop } end,
}
data.categories.special = false
SlackHacks.ListviewBag:OpenInventoryLogFilters({}, root, log)
assert(titles.Actions and titles.Binding and titles.Categories and not titles.Flags
  and selections.Quest and selections.Traded and not selections.Unflagged and not selections.Essentials
  and not selections.Unknown and not selections.Used,
  "Retired actions and Listview Bag-only categories must not appear in ledger filters")
filterButtons["Show All"]()
assert(data.categories.special == false, "Show All must not restore the retired, invisible Essentials filter")
selections.Sold.select()
assert(data.actions.Sold == false and SlackHacks.db.profile.listviewBag.flagFilters.Sold == nil
  and log:GetSettings().actionsToLog.Sold ~= false,
  "Display filters must not modify recording preferences or the bag's own filter state")
data.actions.Sold = true
log:Open()
local panel = frames.SlackHacksInventoryLogFrame
assert(panel.width == 410 and panel.height == 424 * 1.5 and panel.template == "ButtonFrameTemplate"
  and panel.TitleContainer.TitleText.text == "Inventory Log" and panel.buttonBarHidden and panel.Inset.shown,
  "The ledger must use MailFrame's native title bar and inset without the bottom button bar")
assert(panel.stationeryLeft.texture == "Interface\\Stationery\\stationerytest1"
  and panel.stationeryRight.texture == "Interface\\Stationery\\stationerytest2"
  and panel.stationeryRight.points.TOPLEFT[1] == panel.stationeryLeft,
  "The body must use both Send Mail stationery pieces, not the inbox texture")
assert(panel.search.Left.texture == "Interface\\Common\\Common-Input-Border"
  and panel.search.Middle.texture == panel.search.Left.texture
  and panel.search.Right.texture == panel.search.Left.texture
  and panel.search.parent == panel.header and panel.filters.parent == panel.header
  and panel.header.points.TOPLEFT[2] == -28 and panel.header.height == 26,
  "Search and Filters must occupy the native control header, with mail-style input borders")
assert(panel.scroll.template == "ScrollFrameTemplate"
  and panel.scroll.ScrollBar.points.TOPLEFT[3] == 10 and panel.scroll.ScrollBar.points.TOPLEFT[4] == -4
  and panel.scroll.ScrollBar.points.BOTTOMLEFT[4] == 3,
  "The ledger must use Send Mail's per-client native scrollbar and offsets")
assert(panel.rows[1].quantity.fontTemplate == "MailTextFontNormal" and panel.rows[1].quantity.fontSize == 9
  and panel.rows[1].action.fontTemplate == "MailTextFontNormal" and panel.rows[1].timestamp.fontSize == 7
  and panel.rows[1].height == 28 - 5
  and panel.rows[1].points.TOPLEFT[4] - panel.rows[2].points.TOPLEFT[4] == 28 - 5
  and rawget(panel.rows[1], "shade") == nil and rawget(panel.rows[2], "shade") == nil,
  "Ledger text must inherit mail's readable parchment color without enlarging the narrow columns")
assert(panel.CloseButton.template == "UIPanelCloseButtonDefaultAnchors")
panel.CloseButton.scripts.OnClick(panel.CloseButton)
assert(not panel.shown and log.active and log:IsLoggingEnabled(), "Closing history must not disable logging")
log:Open()
assert(panel.search.template == "SearchBoxTemplate" and panel.filters.text == "Filters (None)")
assert(#panel.filtered == 3000 and #panel.rows <= math.ceil(panel.scroll:GetHeight() / 23) + 1)
panel.CloseButton.scripts.OnClick(panel.CloseButton)
UIParent:SetHeight(2000)
MailFrame = widget()
MailFrame:SetHeight(500)
log:Open()
assert(panel.height == MailFrame:GetHeight() * 1.5,
  "Reopening must size against the actual MailFrame once its addon loads")
panel.CloseButton.scripts.OnClick(panel.CloseButton)
UIParent:SetHeight(600)
log:Open()
assert(panel.height == 600 * 0.9, "The mail-sized window must still fit smaller screens")
panel.CloseButton.scripts.OnClick(panel.CloseButton)
UIParent:SetHeight(1200)
MailFrame = nil
log:Open()
assert(panel.columns.labels[1].text == "Qty." and panel.columns.labels[2].text == "Item"
  and panel.columns.labels[3].text == "Action" and panel.columns.labels[4].text == "Timestamp")
assert(panel.rows[1].quantity:GetWidth() <= 48 / 2
  and panel.rows[1].icon.points.LEFT[1] >= panel.rows[1].quantity:GetWidth() + 6
  and panel.rows[1].item.points.LEFT[1] == panel.columns.labels[2].points.BOTTOMLEFT[1],
  "The compact quantity column must leave a gap before the icon and keep the item heading aligned")
assert(panel.rows[1].quantity.text == "" and panel.rows[1].item.text == link
  and panel.rows[1].action.text == "Created", "Quantity must have its own column without item/action suffixes")
assert(panel.rows[2].quantity.text == "" and panel.rows[2].action.text == "Sold",
  "Oversized quantities must be blank rather than clipped to ellipses")
assert(panel.rows[1].timestamp.text:match("^%d%d/%d%d %d%d:%d%d[ap]m$")
  and panel.rows[1].points.TOPLEFT[4] == panel.rows[1].points.TOPRIGHT[4],
  "Timestamp shape and row anchors must fit the requested table layout")
local viewportWidth = panel.width + panel.scroll.points.BOTTOMRIGHT[1] - panel.scroll.points.TOPLEFT[1]
local timestampLeft = panel.columns.labels[4].points.BOTTOMLEFT[1]
assert(panel.scrollChild:GetWidth() <= viewportWidth - 24
  and panel.rows[1].points.TOPRIGHT[1] == panel.scrollChild and panel.rows[1].points.TOPRIGHT[3] == 0,
  "Rows must stop before the stationery's transparent right margin")
assert(timestampLeft + panel.rows[1].timestamp:GetWidth() == panel.scrollChild:GetWidth()
  and panel.rows[1].timestamp:GetWidth() == 54 + 5
  and panel.rows[1].action:GetWidth() == 74 - 5
  and panel.rows[1].counterparty:GetWidth() == panel.rows[1].action:GetWidth()
  and panel.rows[1].timestamp:GetStringWidth() <= panel.rows[1].timestamp:GetWidth()
  and panel.rows[1].action.points.LEFT[1] + panel.rows[1].action:GetWidth() < timestampLeft
  and panel.scrollChild:GetWidth() + panel.rows[1].item.points.RIGHT[1] == 202,
  "The yearless timestamp must fit inside the paper without overlapping Action or shrinking item-link space")
local timestampEntry = panel.rows[1].entry
local originalTimestamp = timestampEntry.timestamp
for hour, expected in pairs({ [11] = "11/28 11:58am", [23] = "11/28 11:58pm" }) do
  timestampEntry.timestamp = os.time({ year = 2026, month = 11, day = 28, hour = hour, min = 58, sec = 0 })
  log:Refresh()
  assert(panel.rows[1].timestamp.text == expected, "Timestamps must use compact slashes and lowercase am/pm")
end
timestampEntry.timestamp = originalTimestamp
log:Refresh()
panel.scroll:SetVerticalScroll(23 * 100)
assert(panel.rows[1].entry.quantity == 2907, "The viewport must render the scrolled entry, not the first one")
panel.rows[1].scripts.OnEnter(panel.rows[1])
assert(GameTooltip.link == link, "Tooltips must use the saved link after the item leaves inventory")
assert(GameTooltip.lines[1] == "Quantity: +2907",
  "The full signed quantity must remain readable when the narrow column clips it")
panel.search:SetText("not present")
panel.search.scripts.OnTextChanged(panel.search)
assert(#panel.filtered == 0 and panel.empty.shown)
panel.search:SetText("")
panel.search.scripts.OnTextChanged(panel.search)
assert(#panel.filtered == 3000 and panel.rows[1].entry.quantity == 3007)
assert(log.repeating.method == "Purge" and log.repeating.delay == 300
  and callbacks.OnProfileChanged == "SyncProfile" and log.events.MAIL_SEND_SUCCESS == "OnMailSuccess")
log:SetLoggingEnabled(false)
assert(not log:IsEnabled() and not log.active and log.repeating.cancelled and not next(log.events)
  and popup.id == "SLACKHACKS_DISABLE_INVENTORY_LOG_CLEAR", "Disabling must stop the Ace3 module and offer log clearing")
bags[0][1].stackCount = 1
log:QueueReconcile()
log:Reconcile()
assert(#data.entries == 3000, "Dismissing the clear offer must preserve history and stop new entries")
local menu = {}
log:AddMenu(nil, menu)
assert(#menu == 1 and menu[1].text == "Open Inventory Log" and menu[1].notCheckable)
menu[1].func()
assert(panel.shown and not log:IsLoggingEnabled() and popup.id == "SLACKHACKS_ENABLE_INVENTORY_LOG"
  and StaticPopupDialogs[popup.id].button2 == NO,
  "Opening disabled history must offer to enable logging without changing it before confirmation")
StaticPopupDialogs[popup.id].OnAccept(nil, popup.data)
assert(log:IsLoggingEnabled() and log.active and #data.entries == 3000)
local modernButtons = {}
--- Capture modern open actions.
function root:CreateButton(title, select) modernButtons[title] = select end
log:AddMenu(root)
assert(not selections["Inventory Log"] and modernButtons["Open Inventory Log"],
  "The shared modern menu must not include an Inventory Log checkbox")
popup = nil
modernButtons["Open Inventory Log"]()
assert(not popup, "Enabled logging must open directly without an enable offer")
log:SetLoggingEnabled(false)
popup = nil
log:Open()
assert(panel.shown and not log:IsLoggingEnabled() and popup.id == "SLACKHACKS_ENABLE_INVENTORY_LOG",
  "Direct Inventory Log opens must offer to enable the disabled module")
modernButtons["Open Inventory Log"]()
assert(panel.shown and not log:IsLoggingEnabled() and #data.entries == 3000
  and popup.id == "SLACKHACKS_ENABLE_INVENTORY_LOG",
  "Declining the modern menu's enable offer must leave existing history readable and logging disabled")
local offeredProfile, enableOffer, noticeCount = SlackHacks.db.profile, popup.data, #notices
SlackHacks.db.profile = { listviewBag = {}, inventoryLog = { enabled = false } }
StaticPopupDialogs[popup.id].OnAccept(nil, enableOffer)
assert(not log:IsLoggingEnabled() and #notices == noticeCount + 1,
  "A stale enable offer must not enable a different profile")
SlackHacks.db.profile = offeredProfile
local offeredSettings = log:GetSettings()
SlackHacks.db.profile.inventoryLog = { enabled = false }
noticeCount = #notices
StaticPopupDialogs[popup.id].OnAccept(nil, enableOffer)
assert(not log:IsLoggingEnabled() and #notices == noticeCount + 1,
  "Resetting settings within the same profile must invalidate an older enable offer")
SlackHacks.db.profile.inventoryLog = offeredSettings
local showPopup = StaticPopup_Show
--- Simulate a native popup failing to open.
function StaticPopup_Show() return nil end
noticeCount = #notices
log:Open()
assert(panel.shown and not log:IsLoggingEnabled() and #notices == noticeCount + 1,
  "A missing enable confirmation must report the failure without enabling logging")
StaticPopup_Show = showPopup
local ledgerButton = CreateFrame("Button")
log:ConfigureButton(ledgerButton)
assert(ledgerButton.normalTexture == "Interface\\Icons\\INV_Scroll_03")
ledgerButton.scripts.OnEnter(ledgerButton)
assert(GameTooltip.text == "Inventory Log")
panel:Hide()
popup = nil
ledgerButton.scripts.OnClick()
assert(panel.shown and not log:IsLoggingEnabled() and popup.id == "SLACKHACKS_ENABLE_INVENTORY_LOG",
  "The footer button must offer enable confirmation while leaving logging disabled until acceptance")
menu[1].func()
StaticPopupDialogs[popup.id].OnAccept(nil, popup.data)
popup = nil
ledgerButton.scripts.OnClick()
assert(log:IsLoggingEnabled() and not popup, "An enabled ledger must also open directly from its footer button")
local legacyFilters
--- Capture the shared legacy filter menu.
function EasyMenu(entries) legacyFilters = entries end
SlackHacks.ListviewBag:OpenInventoryLogFilters({}, nil, log)
assert(legacyFilters[2].text == "Actions" and legacyFilters[3].text == "Quest"
  and log.filtersMenu ~= SlackHacks.ListviewBag.filtersMenu)
for _, entry in ipairs(legacyFilters) do
  assert(entry.text ~= "Essentials" and entry.text ~= "Unknown" and entry.text ~= "Used",
    "The legacy ledger filter must not offer retired actions or Listview Bag Essentials")
end
legacyFilters[3].func()
assert(data.actions.Quest == false and panel.filters.text == "Filters (1)")
assert(log:IsEnabled(), "A parent shutdown does not clear the module's desired enabled state")
log.active = false
log:OnDisable()
hooks.SendMail()
hooks.BuyMerchantItem(1, 1)
log:Expect("Sold", link, 1, -1)
bags[0][1].stackCount = 2
log:Reconcile()
assert(#data.entries == 3000, "Permanent secure hooks must not keep logging after addon shutdown")

SlackHacks.rootEnabled = false
log:SyncProfile()
assert(not log.active and log:IsEnabled(), "Profile callbacks must not activate children while the parent is disabled")
SlackHacks.rootEnabled = true
log:SyncProfile()
local originalProfile = SlackHacks.db.profile
local disabledProfile = { listviewBag = {}, inventoryLog = { enabled = false } }
SlackHacks.db.profile = disabledProfile
log:SyncProfile()
assert(not log.active and callbacks.OnProfileChanged == "SyncProfile" and #data.entries == 3000)
SlackHacks.db.profile = originalProfile
log:SyncProfile()
assert(log.active and #data.entries == 3000, "Profile changes must reactivate the module without deleting character history")
log:SetLoggingEnabled(false)
local stale = popup
log:SetLoggingEnabled(true)
StaticPopupDialogs[stale.id].OnAccept(nil, stale.data)
assert(#data.entries == 3000, "A stale disable offer must not clear a re-enabled module's history")
log:SetLoggingEnabled(false)
stale = popup
SlackHacks.db.profile = disabledProfile
log:SyncProfile()
StaticPopupDialogs[stale.id].OnAccept(nil, stale.data)
assert(#data.entries == 3000, "A stale disable offer must not clear history after switching profiles")
SlackHacks.db.profile = originalProfile
log:SyncProfile()
log:RequestClearLog(originalProfile)
StaticPopupDialogs[popup.id].OnAccept(nil, popup.data)
assert(#data.entries == 0 and not log.active, "Accepting the disable offer must clear history without enabling the module")
log:SetLoggingEnabled(true)
log:Record({ link = link }, "Sold", 4, -1)
data.actions.Quest = false
log:GetSettings().actionsToLog.Gathered = false
log:SetEntriesToKeep("7")
MerchantFrame:Show()
hooks[C_Container].UseContainerItem(0, 1)
log:RequestClearLog()
assert(#data.entries == 1 and popup.id == "SLACKHACKS_CLEAR_INVENTORY_LOG",
  "Explicit clearing must wait for confirmation")
StaticPopupDialogs[popup.id].OnAccept(nil, popup.data)
assert(#data.entries == 0 and log.active and data.actions.Quest == false
  and log:GetSettings().entriesToKeep == 7 and log:GetSettings().actionsToLog.Gathered == false
  and #panel.filtered == 0 and rawget(panel.rows[1], "entry") == nil,
  "Clearing must preserve module preferences and display filters")
bags[0] = {}
log:Reconcile()
assert(#data.entries == 1 and data.entries[1].action == "Sold" and data.entries[1].quantity == 2,
  "Clearing history must not invalidate an in-flight transaction")
log:Record({ link = link }, "Mailed", 1, -1, "Long Mail Recipient-Realm")
log:Record({ link = link }, "Traded", 1, 1, "Trade Partner-Realm")
log:Open()
assert(panel.rows[1].action.text == "Traded" and panel.rows[1].counterparty.text == "Trade Partner-Realm"
  and panel.rows[2].action.text == "Mailed" and panel.rows[2].counterparty.text == "Long Mail Recipient-Realm"
  and panel.rows[1].counterparty.fontSize < panel.rows[1].action.fontSize
  and panel.rows[1].counterparty.points.LEFT[2] < panel.rows[1].action.points.LEFT[2],
  "Transfer counterparties must appear beneath the action without changing its filter key")
assert(panel.rows[1].action.points.LEFT[2] + panel.rows[1].action:GetHeight() / 2
    <= panel.rows[1]:GetHeight() / 2
  and panel.rows[1].counterparty.points.LEFT[2] - panel.rows[1].counterparty:GetHeight() / 2
    >= -panel.rows[1]:GetHeight() / 2,
  "Both transfer text lines must fit within the reduced row spacing")
assert(panel.rows[1].quantity.text == "+1" and panel.rows[2].quantity.text == "-1",
  "Known transaction quantities must show plus for gains and minus for losses")
assert(panel.rows[1].quantity.textColor[1] == GREEN_FONT_COLOR.r
  and panel.rows[1].quantity.textColor[2] == GREEN_FONT_COLOR.g
  and panel.rows[1].quantity.textColor[3] == GREEN_FONT_COLOR.b
  and panel.rows[2].quantity.textColor[1] == RED_FONT_COLOR.r
  and panel.rows[2].quantity.textColor[2] == RED_FONT_COLOR.g
  and panel.rows[2].quantity.textColor[3] == RED_FONT_COLOR.b,
  "Gains must use Blizzard's green font color and losses its red font color")
panel.rows[1].scripts.OnEnter(panel.rows[1])
assert(GameTooltip.lines[2] == "Traded from: Trade Partner-Realm")
panel.rows[2].scripts.OnEnter(panel.rows[2])
assert(GameTooltip.lines[2] == "Mailed to: Long Mail Recipient-Realm")
panel.rows[3].scripts.OnEnter(panel.rows[3])
assert(#GameTooltip.lines == 1 and GameTooltip.lines[1] == "Quantity: -2",
  "Entries without counterparty metadata must show their quantity without stale transfer details")
log:Record({ link = link }, "Traded", 1, -1, "Trade Partner-Realm")
log:Refresh()
assert(panel.rows[1].quantity.textColor[1] == RED_FONT_COLOR.r
  and panel.rows[1].quantity.textColor[2] == RED_FONT_COLOR.g,
  "Reusing a formerly positive row for a loss must replace its green color")
panel.rows[1].scripts.OnEnter(panel.rows[1])
assert(GameTooltip.lines[2] == "Traded to: Trade Partner-Realm")
log:Record({ link = link }, "Mailed", 5, 1, "Legacy Name-Realm")
log:Refresh()
assert(panel.rows[1].action.text == "Mailed" and panel.rows[1].counterparty.text == "(Received)"
  and panel.rows[1].counterparty.shown
  and panel.rows[1].counterparty.points.LEFT[2] < panel.rows[1].action.points.LEFT[2],
  "Incoming mail must show (Received) beneath Mailed, not an outgoing recipient name")
panel.rows[1].scripts.OnEnter(panel.rows[1])
assert(GameTooltip.lines[1] == "Quantity: +5" and GameTooltip.lines[2] == "Mail received"
  and #GameTooltip.lines == 2, "Incoming mail tooltips must not describe a recipient")
log:Record({ link = link }, "Mailed", 1, 1)
log:Refresh()
assert(panel.rows[1].counterparty.text == "(Received)" and panel.rows[1].counterparty.shown,
  "Incoming mail without counterparty metadata must still show its received label")
log:Record({ link = other }, "Looted", 1, 1)
log:Refresh()
assert(panel.rows[1].entry.stackSize == 1 and panel.rows[1].quantity.text == ""
  and not panel.rows[1].counterparty.shown,
  "Nonstackable singletons must not show 1 or a recycled transfer recipient")
log:Record({ link = link, stackSize = 20 }, "Looted", 1, 1)
log:Refresh()
assert(panel.rows[1].quantity.text == "+1", "A single unit of a stackable item must retain its signed count")
local quantityLabel = panel.rows[1].quantity
local measureQuantity = quantityLabel.GetStringWidth
--- Simulate a native font whose signed single-digit count is wider than the former 12-pixel column.
---@return number width Natural text width.
function quantityLabel:GetStringWidth()
  if self.text == "+5" then return 13 end
  return measureQuantity(self)
end
log:Record({ link = link, stackSize = 20 }, "Purchased", 5, 1)
log:Refresh()
assert(panel.rows[1].quantity.text == "+5"
  and quantityLabel:GetStringWidth() <= quantityLabel:GetWidth(),
  "A five-unit vendor bundle must display +5 even with wider native font glyphs")
quantityLabel.GetStringWidth = measureQuantity
log:Record({ link = link }, "Created", 1, 1)
data.entries[#data.entries].quantity = nil
log:Refresh()
assert(panel.rows[1].quantity.text == "", "Unknown quantities must be empty without placeholder ellipses")
panel.rows[1].scripts.OnEnter(panel.rows[1])
assert(#GameTooltip.lines == 0, "Unknown quantities must not be invented in the tooltip")
log:Record({ link = link }, "Looted", 1000, 1)
log:Refresh()
assert(panel.rows[1].quantity.text == "")
panel.rows[1].scripts.OnEnter(panel.rows[1])
assert(GameTooltip.lines[1] == "Quantity: +1000", "Clipped signed quantities must remain available in tooltips")
log:Record({ link = other, stackSize = 1 }, "Looted", 2, 1)
log:Refresh()
assert(panel.rows[1].quantity.text == "+2", "Multiple nonstackable copies must still show their signed quantity")
local savedEntry, itemInfo = data.entries[#data.entries], C_Item.GetItemInfo
savedEntry.direction = nil
log:Refresh()
assert(panel.rows[1].quantity.text == "2", "Older entries without a direction must not invent a gain or loss sign")
local mailRed, mailGreen, mailBlue, mailAlpha = MailTextFontNormal:GetTextColor()
assert(panel.rows[1].quantity.textColor[1] == mailRed
  and panel.rows[1].quantity.textColor[2] == mailGreen
  and panel.rows[1].quantity.textColor[3] == mailBlue
  and panel.rows[1].quantity.textColor[4] == mailAlpha,
  "Unsigned historical quantities must reset recycled rows to the normal mail-text color")
savedEntry.direction = 1
savedEntry.stackSize, savedEntry.name, savedEntry.category = nil, "Saved item name", "equipment"
--- Simulate an unavailable item cache while refreshing older saved entries.
function C_Item.GetItemInfo() return nil end
log:Refresh()
assert(savedEntry.name == "Saved item name" and savedEntry.category == "equipment",
  "Loading missing stackability metadata must not discard existing saved names or categories")
C_Item.GetItemInfo = itemInfo
savedEntry.category, data.categories.special = "special", false
log:MigrateCharacterSettings(SlackHacks.db.char)
log:Refresh()
assert(savedEntry.category == "consumables" and data.categories.special == nil,
  "Older Essentials entries must resolve to their normal categories once item metadata is available")
print("Inventory log tracking, retention, filters, and UI tests passed")
