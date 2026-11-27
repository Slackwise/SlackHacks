-- Run with Lua 5.1 from the addon root: lua tests/utilities_loot_containers.lua

local addon = setmetatable({}, { __index = _G })
SlackHacks, addon.Self = addon, addon
local module = {}
local inventory, opened, messages = {}, {}, {}
local now, combat, mounted, casting, cursor, loot = 0, false, false, false, false, 0
local enabled, consume = true, true
local cooldown = 0

--- Supplies the Utilities module.
---@return table module
function addon:NewModule() return module end
--- Reports the module lifecycle state.
---@return boolean enabled
function module:IsEnabled() return enabled end
--- Leaves the unrelated node-nameplate code inactive.
---@return boolean forever
function addon.isForever() return false end
--- Reports whether the test is running on Retail.
---@return boolean retail
function addon.isRetail() return true end
--- Creates a frame with event and script storage.
---@return table frame
function CreateFrame()
  local frame = { events = {}, scripts = {}, shown = true }
  --- Stores a frame script.
  ---@param event string Script name.
  ---@param handler function Callback.
  function frame:SetScript(event, handler) self.scripts[event] = handler end
  --- Registers a frame event.
  ---@param event string Event name.
  function frame:RegisterEvent(event) self.events[event] = true end
  --- Clears registered frame events.
  function frame:UnregisterAllEvents() self.events = {} end
  --- Sets frame visibility.
  ---@param shown boolean Visibility.
  function frame:SetShown(shown) self.shown = shown end
  --- Hides the frame.
  function frame:Hide() self.shown = false end
  --- Reports frame visibility.
  ---@return boolean shown
  function frame:IsShown() return self.shown end
  return frame
end
--- Reports the combat state.
---@return boolean combat
function InCombatLockdown() return combat end
--- Reports a living player.
---@return boolean dead
function UnitIsDeadOrGhost() return false end
--- Reports the mounted state.
---@return boolean mounted
function IsMounted() return mounted end
--- Reports a cast in progress.
---@return string|nil cast
function UnitCastingInfo() return casting and "Cast" or nil end
--- Reports no channeled spell.
function UnitChannelInfo() end
--- Reports an occupied cursor.
---@return string|nil cursorType
function GetCursorInfo() return cursor and "item" or nil end
--- Reports the currently open loot.
---@return number slots
function GetNumLootItems() return loot end
--- Supplies monotonic time.
---@return number now
function GetTime() return now end
--- Records visible failure notifications.
---@param message string Notification.
function addon.prn(message) messages[#messages + 1] = message end

NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4, 5
C_Container = {
  --- Supplies carried bag capacity.
  ---@param bag number Bag ID.
  ---@return number slots
  GetContainerNumSlots = function(bag) return 8 end,
  --- Supplies the current contents of a slot.
  ---@param bag number Bag ID.
  ---@param slot number Slot ID.
  ---@return table|nil info
  GetContainerItemInfo = function(bag, slot) return inventory[bag] and inventory[bag][slot] end,
  --- Supplies a cooldown which the test can clear.
  ---@return number start
  ---@return number duration
  GetContainerItemCooldown = function() return now, cooldown end,
  --- Records item use and optionally simulates server-side consumption.
  ---@param bag number Bag ID.
  ---@param slot number Slot ID.
  UseContainerItem = function(bag, slot)
    local info = assert(inventory[bag][slot])
    assert(not info.isLocked)
    opened[#opened + 1] = info.itemID
    if consume then
      info.stackCount = info.stackCount - 1
      if info.stackCount == 0 then inventory[bag][slot] = nil end
    end
  end,
}
addon.Enum = { SelfVendorMode = {
  CONSUMABLES = 1, OIL = 4, AUGMENT_RUNES = 5, VANTUS_RUNE = 6, AUGMENTS = 7,
  FLASK = 8, CRIT_FLASK = 9, MASTERY_FLASK = 10, HASTE_FLASK = 11, VERSATILITY_FLASK = 12,
} }
assert(loadfile("StaticData.lua"))()
assert(loadfile("Utilities.lua"))()
local settings = { clams = true, holidayRewards = true }
addon.db = { profile = { utilities = { autoOpenLootContainers = settings } } }
module:EnableLootContainerTracking()
local frame = module.lootContainerFrame

--- Writes a carried item or clears its slot.
---@param bag number Bag ID.
---@param slot number Slot ID.
---@param itemID number|nil Item ID.
---@param count number|nil Stack size.
---@param locked boolean|nil Item lock state.
local function put(bag, slot, itemID, count, locked)
  inventory[bag] = inventory[bag] or {}
  inventory[bag][slot] = itemID and { itemID = itemID, stackCount = count or 1, isLocked = locked } or nil
end
--- Dispatches an inventory event.
---@param event string|nil Event name.
local function fire(event)
  event = event or "BAG_UPDATE_DELAYED"
  assert(frame.events[event])
  frame.scripts.OnEvent(frame, event)
end
--- Advances only the active inventory processor.
---@param seconds number|nil Elapsed seconds.
local function tick(seconds)
  seconds = seconds or 0.5
  now = now + seconds
  if frame.shown then frame.scripts.OnUpdate(frame, seconds) end
end
--- Starts an isolated acquisition scenario.
local function reset()
  inventory, opened, messages = {}, {}, {}
  combat, mounted, casting, cursor, loot, consume = false, false, false, false, 0, true
  module:ResetLootContainerTracking()
end

-- Login, option changes, sorting, splitting, and merging must not open old inventory.
put(0, 1, 5523, 5)
fire("PLAYER_ENTERING_WORLD")
tick()
assert(#opened == 0)
put(0, 1, 5523, 2)
put(3, 2, 5523, 3)
fire()
tick()
assert(#opened == 0)
put(3, 2)
put(0, 1, 5523, 5)
module:SetLootContainerEnabled("clams", true)
fire()
tick()
assert(#opened == 0)
cursor = true
put(0, 1)
fire()
tick()
cursor = false
put(2, 1, 5523, 5)
fire()
tick()
assert(#opened == 0, "Dragging an old stack must not make it newly acquired")
put(2, 1)
put(0, 1, 5523, 5)
fire()

-- A stack increase opens exactly the added quantity, never the older stack.
put(0, 1, 5523, 7)
fire()
tick(0.49)
assert(#opened == 0)
tick(0.01)
tick()
tick()
assert(#opened == 2 and inventory[0][1].stackCount == 5 and not frame.shown)

-- Unknown, locked-chest, and unchecked items are never used.
reset()
put(0, 1, 6354)
put(0, 2, 999999)
put(0, 3, 6643)
fire()
tick()
assert(#opened == 0 and not frame.shown)

-- Annual presents, obsolete bags, and transferable treatises are excluded.
for _, itemID in ipairs({ 21310, 21327, 21363, 17726, 17727, 51999, 52005, 52006, 69903, 245755 }) do
  reset()
  put(0, 1, itemID)
  fire()
  tick()
  assert(#opened == 0 and not frame.shown, tostring(itemID))
end
-- A category checkbox controls every allowlisted item in that category, without changing other categories.
for _, category in ipairs(module.LootContainers) do
  local previous = settings[category.key]
  settings[category.key] = true
  for _, itemID in ipairs(category.ids) do
    reset()
    put(0, 1, itemID)
    fire()
    tick()
    tick()
    assert(#opened == 1 and opened[1] == itemID, category.name)
  end
  module:SetLootContainerEnabled(category.key, false)
  reset()
  put(0, 1, category.ids[1])
  fire()
  tick()
  assert(#opened == 0 and not frame.shown, category.name)
  settings[category.key] = previous
end

-- Knowledge items must not be used, even if the removed preference remains in an existing profile.
settings.professionKnowledge = true
for _, itemID in ipairs({
  263454, 263455, 263456, 263457, 263458, 263459, 263460, 263461, 263462, 263463, 263464,
  259188, 259189, 259190, 259191, 259192, 259193, 259194, 259195, 259196, 259197,
  259198, 259199, 259200, 259201, 259202, 259203, 267654, 267655, 267653,
  238465, 238466, 238467, 237496, 237506, 237507, 238625, 238626, 238627,
  246320, 246321, 246322, 246323, 246324, 246325, 246326, 246327,
  246328, 246329, 246330, 246331, 246332, 246333, 246334, 246335,
}) do
  reset()
  put(0, 1, itemID, 4)
  fire()
  tick()
  assert(#opened == 0 and not frame.shown, tostring(itemID))
end
for _, events in ipairs({ { "MAIL_SHOW", "MAIL_CLOSED" }, { "BANKFRAME_OPENED", "BANKFRAME_CLOSED" } }) do
  reset()
  fire(events[1])
  put(0, 1, 246321, 4)
  fire()
  fire(events[2])
  tick()
  assert(#opened == 0 and not frame.shown, events[1])
end
assert(module:GetLootContainerOptions().professionKnowledge == nil)
settings.professionKnowledge = nil

-- A genuine container received from mail is processed after the mailbox closes.
reset()
fire("MAIL_SHOW")
put(0, 1, 5523, 4)
fire()
tick()
assert(#opened == 0 and frame.shown)
fire("MAIL_CLOSED")
for _ = 1, 5 do tick() end
assert(#opened == 4 and inventory[0][1] == nil and not frame.shown)

-- The shared clam setting covers every listed clam; locked items wait and bag moves are re-resolved.
for _, itemID in ipairs(module.LootContainers[1].ids) do
  reset()
  put(0, 1, itemID, 1, true)
  fire()
  tick()
  assert(#opened == 0)
  put(0, 1)
  put(5, 2, itemID)
  fire()
  tick()
  tick()
  assert(#opened == 1 and opened[1] == itemID and not frame.shown)
end

-- Inventory interactions, combat, mounting, casts, cursor items, and open loot defer queued rewards.
reset()
put(0, 1, 54516)
fire()
combat = true; tick(); assert(#opened == 0)
combat, mounted = false, true; tick(); assert(#opened == 0)
mounted, casting = false, true; tick(); assert(#opened == 0)
casting, cursor = false, true; tick(); assert(#opened == 0)
cursor, loot = false, 1; tick(); assert(#opened == 0)
loot = 0
for _, events in ipairs({
  { "MERCHANT_SHOW", "MERCHANT_CLOSED" }, { "BANKFRAME_OPENED", "BANKFRAME_CLOSED" },
  { "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED" }, { "MAIL_SHOW", "MAIL_CLOSED" },
  { "TRADE_SHOW", "TRADE_CLOSED" }, { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" },
  { "LOOT_OPENED", "LOOT_CLOSED" },
}) do
  fire(events[1])
  tick()
  assert(#opened == 0, events[1])
  fire(events[2])
end
for _, name in ipairs({ "MerchantFrame", "BankFrame", "GuildBankFrame", "MailFrame", "TradeFrame",
  "AuctionHouseFrame", "AuctionFrame", "ItemInteractionFrame", "ScrappingMachineFrame", "LootFrame" }) do
  _G[name] = CreateFrame()
  tick()
  assert(#opened == 0, name)
  _G[name] = nil
end
tick()
tick()
assert(#opened == 1 and opened[1] == 54516)

-- A cooldown defers item use rather than turning a temporary failure into a discarded queue.
reset()
cooldown = 2
put(0, 1, 5523)
fire()
tick()
assert(#opened == 0 and frame.shown)
cooldown = 0
tick()
tick()
assert(#opened == 1 and not frame.shown)

-- Server refusal does not spam use attempts; an unemptied loot window does not trigger a false timeout.
reset()
consume = false
put(0, 1, 54516, 2)
fire()
tick()
loot = 1
tick(10)
assert(#opened == 1 and #messages == 0)
loot = 0
tick(6)
tick()
assert(#opened == 1 and #messages == 1 and not frame.shown)

-- Sold or removed pending items, disabled settings, world transitions, and profile switches cancel stale work.
reset()
put(0, 1, 54516)
fire()
put(0, 1)
fire()
tick()
assert(#opened == 0 and not frame.shown)
put(0, 1, 5523)
fire()
module:SetLootContainerEnabled("clams", false)
tick()
assert(#opened == 0)
module:SetLootContainerEnabled("clams", true)
put(0, 2, 5523)
fire()
fire("PLAYER_LEAVING_WORLD")
fire()
fire("PLAYER_ENTERING_WORLD")
tick()
assert(#opened == 0)
put(0, 3, 5523)
fire()
addon.db.profile = { utilities = { autoOpenLootContainers = { clams = true } } }
tick()
assert(#opened == 0 and not frame.shown)

-- Real options callbacks preserve unrelated preferences and do not retroactively open inventory.
addon.Talents = { MAX_SPECS = 0 }
addon.Enum = { SelfVendorMode = { FLASK = 1, OIL = 2, AUGMENT_RUNES = 3,
  VANTUS_RUNE = 4, CONSUMABLES = 5, AUGMENTS = 6 } }
addon.SELF_VENDOR_MODES = {}
for index = 1, 6 do
  addon.SELF_VENDOR_MODES[index] = { key = "mode" .. index, name = "Mode", description = "Mode" }
end
--- Supplies the options heading's version.
---@return string version
function addon.getAddonVersion() return "test" end
assert(loadfile("Options.lua"))()
local nativeSearchApplications, appliedSearchPreference = 0, nil
--- Count application of the native picker search preference.
function addon.ApplyNativeIconPickerSearch()
  nativeSearchApplications = nativeSearchApplications + 1
  appliedSearchPreference = addon.db.profile.utilities.addIconPickerSearch
end
local pickerSearch = addon.options.args.utilities.args.addIconPickerSearch
assert(addon.dbDefaults.profile.utilities.addIconPickerSearch == false)
assert(pickerSearch.order > addon.options.args.utilities.args.showInGameNavigation.order)
assert(pickerSearch.desc == "Adds a Search box to the Macro and Equipment Set icon pickers.")
pickerSearch.set(nil, true)
assert(pickerSearch.get() and nativeSearchApplications == 1)
pickerSearch.set(nil, false)
assert(not pickerSearch.get() and nativeSearchApplications == 2)
local profileCallbacks = {}
--- Capture the Utilities module's AceDB profile callbacks.
---@param target table Callback target.
---@param event string Profile event.
---@param method string Callback method.
function addon.db.RegisterCallback(target, event, method)
  --- Invoke the registered profile callback.
  profileCallbacks[event] = function() target[method](target) end
end
module:OnInitialize()
addon.db.profile.utilities.tomtomWayCommand = false
addon.db.profile.utilities.addIconPickerSearch = true
profileCallbacks.OnProfileChanged()
assert(nativeSearchApplications == 3 and appliedSearchPreference)
addon.db.profile.utilities.addIconPickerSearch = false
profileCallbacks.OnProfileCopied()
profileCallbacks.OnProfileReset()
assert(nativeSearchApplications == 5 and not appliedSearchPreference)
local group = addon.options.args.utilities.args.autoOpenLootContainers
local path = { "utilities", "autoOpenLootContainers", "clams" }
addon.db.profile.utilities.tomtomWayCommand = true
group.set(path, false)
assert(not group.get(path))
group.set(path, true)
tick()
assert(group.get(path) and #opened == 0 and addon.db.profile.utilities.tomtomWayCommand)
local options = module:GetLootContainerOptions()
assert(options.clams.type == "toggle" and options.fishing.type == "toggle")
local toggleCount = 0
for _, option in pairs(options) do
  if option.type == "toggle" then
    toggleCount = toggleCount + 1
    assert(option.descStyle == "inline" and type(option.desc) == "string" and #option.desc > 0)
  end
end
assert(toggleCount == 3 and not options.professionKnowledge and not options.dailyQuestRewards
  and not options.otherRewards and not options.dungeonRewards and not options.helpfulGoods and not options.pumpkin)

-- Shutdown unregisters acquisition events and stops the queue.
--- Supplies the unrelated AceEvent cleanup.
function module:UnregisterAllEvents() end
module:OnDisable()
assert(next(frame.events) == nil and not frame.shown)

print("Utilities loot-container tests passed")
