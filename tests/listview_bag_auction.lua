-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_auction.lua
SlackHacks = setmetatable({ db = { global = {} } }, { __index = _G })
SlackHacks.Self = SlackHacks
SlackHacks.addonName = "SlackHacks"
local forever = false
function SlackHacks.isForever() return forever end
local warnings, frames, ticker = {}, {}, nil
local now, profileTime, resultCost, resultReads = 100, 0, 0, 0
function SlackHacks.prn(text) warnings[#warnings + 1] = text end
function GetNormalizedRealmName() return "TestRealm" end
function UnitFactionGroup() return "Alliance" end
function GetCurrentRegion() return 1 end
function GetTime() return now end
function debugprofilestop() return profileTime end
function time() return 123456 end
UIParent = {}
--- Create a mock UI object that records progress and layout settings.
---@return table object Mock UI object.
local function widget()
  local object = { scripts = {}, points = {}, shown = false }
  setmetatable(object, { __index = function() return function() end end })
  function object:SetScript(name, callback) self.scripts[name] = callback end
  function object:SetPoint(point, ...) self.points[point] = { ... } end
  function object:ClearAllPoints() self.points = {} end
  function object:SetSize(width, height) self.width, self.height = width, height end
  function object:SetHeight(height) self.height = height end
  function object:GetWidth() return self.width end
  function object:GetHeight() return self.height end
  function object:SetText(text) self.text = text end
  function object:SetTexture(texture) self.texture = texture end
  function object:SetAtlas(atlas) self.atlas = atlas end
  function object:SetStatusBarTexture(texture) self.statusTexture = texture end
  function object:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
  function object:SetValue(value) self.value = value end
  function object:CreateFontString(_, _, font)
    local text = widget()
    text.font = font
    return text
  end
  function object:CreateTexture() return widget() end
  function object:Show() self.shown = true end
  function object:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
  end
  return object
end
--- Create a minimal frame for the scanner and progress window.
---@param frameType string Widget type.
---@param name string|nil Frame name.
---@param parent table|nil Parent frame.
---@param template string|nil UI template.
---@return table frame Mock frame.
function CreateFrame(frameType, name, parent, template)
  local frame = widget()
  frame.frameType, frame.name, frame.parent, frame.template = frameType, name, parent, template
  if template == "SimplePanelTemplate" then frame.Inset, frame.Bg = widget(), widget() end
  if template == "ObjectiveTrackerProgressBarTemplate" then
    frame:SetPoint("CENTER")
    frame.Bar = widget()
    frame.Bar:SetSize(180, 15)
    frame.Bar:SetPoint("RIGHT", 15, 0)
    frame.Bar.BorderLeft, frame.Bar.BorderRight = widget(), widget()
    frame.Bar.BorderLeft:SetSize(9, 22)
    frame.Bar.BorderRight:SetSize(9, 22)
  end
  frames[#frames + 1] = frame
  return frame
end
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_Container = { GetContainerItemInfo = function() return { hyperlink = "item:42", isBound = false } end }
C_Timer = {
  NewTicker = function(_, callback)
    ticker = { callback = callback, cancelled = false }
    function ticker:Cancel() self.cancelled = true end
    return ticker
  end,
}
local hooks = {}
function hooksecurefunc(object, name, callback) hooks[name] = callback end
local key = { itemID = 42, itemLevel = 1, itemSuffix = 0, battlePetSpeciesID = 0 }
local full, searches, more, refreshes = false, 0, 0, 0
local results = { { unitPrice = 10, quantity = 2 }, { unitPrice = 20, quantity = 8 } }
C_AuctionHouse = {
  GetItemKeyFromItem = function() return key end,
  IsThrottledMessageSystemReady = function() return true end,
  SendSearchQuery = function()
    searches = searches + 1
    hooks.SendSearchQuery()
  end,
  RequestMoreCommoditySearchResults = function()
    more = more + 1
    hooks.RequestMoreCommoditySearchResults()
  end,
  RequestMoreItemSearchResults = function() end,
  HasFullCommoditySearchResults = function() return full end,
  HasFullItemSearchResults = function() return full end,
  GetNumCommoditySearchResults = function() return #results end,
  GetCommoditySearchResultInfo = function(_, index)
    profileTime, resultReads = profileTime + resultCost, resultReads + 1
    return results[index]
  end,
  GetNumItemSearchResults = function() return #results end,
  GetItemSearchResultInfo = function(_, index) return results[index] end,
}
assert(loadfile("ListviewBagAuction.lua"))()
local auction = SlackHacks.ListviewBagAuction
local low, average = auction.Summarize(key, true)
assert(low == 10 and average == 18, "commodity average must be quantity-weighted")
results = { { buyoutAmount = 20, quantity = 2 }, { buyoutAmount = 160, quantity = 8 } }
low, average = auction.Summarize(key, false)
assert(low == 10 and average == 18, "stack buyouts must be converted to per-item prices")
results = { { unitPrice = 10, quantity = 2 }, { unitPrice = 20, quantity = 8 } }
local items = { { link = "item:42", bagID = 0, slot = 1 } }
auction.Start(items, function() refreshes = refreshes + 1 end)
assert(ticker and not ticker.cancelled)
local listener = frames[1]
local window = frames[2]
assert(window.template == "SimplePanelTemplate" and window.title.text == "Checking Auction Prices"
  and window.headline.texture == "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
  and window.cancel.template == "SharedButtonSmallTemplate" and window.addonLabel.text == "SlackHacks"
  and window.CloseButton.template == "UIPanelCloseButtonDefaultAnchors",
  "The scan window must use the reminder panel styling")
assert(window.barFrame.template == "ObjectiveTrackerProgressBarTemplate" and window.barFrame.shown
  and window.bar == window.barFrame.Bar
  and window.bar.minimum == 0 and window.bar.maximum == 1 and window.bar.value == 0
  and window.text.text == "0 / 1 items", "Retail progress must begin at zero")
assert(window.bar.width == window.width * 0.8 and window.bar.height == 15 * 1.5
  and window.bar.BorderLeft.height == 22 * 1.5 and window.bar.BorderRight.height == 22 * 1.5
  and window.bar.points.CENTER and not window.bar.points.RIGHT
  and window.barFrame.points.TOP and not window.barFrame.points.CENTER,
  "The tracker bar and border must resize and center within the window")
ticker.callback()
assert(searches == 1, "the initial query must be sent")
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
ticker.callback()
assert(more == 1, "incomplete results must request another page")
full = true
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_ADDED", 42)
local quote = auction.GetQuote("item:42")
assert(quote.minimum == 10 and quote.average == 18 and quote.timestamp == 123456)
assert(ticker.cancelled and refreshes > 0, "completion must stop the ticker and refresh")
assert(window.bar.value == 1 and window.text.text == "1 / 1 items" and not window.shown,
  "Completion must update the progress before hiding the window")
local twoItems = { items[1], items[1] }
auction.Start(twoItems, function() end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(window.bar.value == 1 and window.bar.maximum == 2 and window.text.text == "1 / 2 items",
  "The progress bar must advance for a partial scan")
window.cancel.scripts.OnClick()
assert(ticker.cancelled and not window.shown, "Cancel must stop and hide the active scan")
auction.Start(items, function() end)
assert(window.bar.value == 0 and window.bar.maximum == 1 and window.text.text == "0 / 1 items",
  "Restarting must reset the progress")
window.CloseButton.scripts.OnClick()
assert(ticker.cancelled and not window.shown, "Closing the window must cancel the scan")
auction.Start(items, function() end)
window:Hide()
assert(ticker.cancelled, "Hiding the window must cancel the scan")

local batchedRefreshes = 0
local threeItems = { items[1], items[1], items[1] }
auction.Start(threeItems, function() batchedRefreshes = batchedRefreshes + 1 end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(batchedRefreshes == 0, "Individual quotes must not rebuild the bag immediately")
now = now + 1
ticker.callback()
assert(batchedRefreshes == 1, "Pending quotes must refresh periodically")
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(batchedRefreshes == 2 and ticker.cancelled, "Completion must flush pending quotes only once")

batchedRefreshes = 0
auction.Start(twoItems, function() batchedRefreshes = batchedRefreshes + 1 end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
window.cancel.scripts.OnClick()
assert(batchedRefreshes == 1 and ticker.cancelled, "Cancellation must display previously completed quotes")

results = {}
for index = 1, 250 do results[index] = { unitPrice = index, quantity = 1 } end
resultReads = 0
auction.Start(items, function() end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(resultReads == 100 and listener.scripts.OnUpdate and window.bar.value == 0,
  "Large summaries must yield after a bounded number of results")
local searchesDuringSummary = searches
now = now + 31
ticker.callback()
assert(searches == searchesDuringSummary and not ticker.cancelled,
  "A pending summary must not send another query or time out while processing")
listener.scripts.OnUpdate()
assert(resultReads == 200 and not ticker.cancelled, "A summary must resume on the next frame")
listener.scripts.OnUpdate()
quote = auction.GetQuote("item:42")
assert(resultReads == 250 and quote.minimum == 1 and quote.average == 126 and ticker.cancelled
  and not listener.scripts.OnUpdate, "The completed summary must publish the exact weighted prices")

resultReads, resultCost, profileTime = 0, 0.21, 0
auction.Start(items, function() end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(resultReads == 10 and listener.scripts.OnUpdate, "Slow result reads must yield at the time budget")
window.cancel.scripts.OnClick()
assert(ticker.cancelled and not listener.scripts.OnUpdate and auction.GetQuote("item:42") == quote,
  "Cancellation must discard unfinished summaries and stop frame updates")

resultReads, resultCost = 0, 0
auction.Start(items, function() end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
results = {}
for index = 1, 150 do results[index] = { unitPrice = 20, quantity = 1 } end
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(resultReads == 200 and listener.scripts.OnUpdate, "New results must restart a pending summary")
listener.scripts.OnUpdate()
quote = auction.GetQuote("item:42")
assert(quote.minimum == 20 and quote.average == 20 and ticker.cancelled,
  "A restarted summary must not mix old and new results")

results = {}
for index = 1, 150 do results[index] = { unitPrice = 30, quantity = 1 } end
auction.Start(items, function() end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
full = false
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(not listener.scripts.OnUpdate, "Incomplete replacement results must discard the pending summary")
local moreBeforeReplacement = more
ticker.callback()
assert(more == moreBeforeReplacement + 1, "Incomplete replacement results must request another page")
full = true
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_ADDED", 42)
listener.scripts.OnUpdate()
quote = auction.GetQuote("item:42")
assert(quote.minimum == 30 and quote.average == 30 and ticker.cancelled,
  "The completed replacement page must produce the new quote")

results = {}
for index = 1, 120 do results[index] = { buyoutAmount = index * 2, quantity = 2 } end
auction.Start(items, function() end)
ticker.callback()
listener.scripts.OnEvent(listener, "ITEM_SEARCH_RESULTS_UPDATED", key)
assert(listener.scripts.OnUpdate, "Item listings must also be processed incrementally")
listener.scripts.OnUpdate()
quote = auction.GetQuote("item:42")
assert(quote.minimum == 1 and quote.average == 61 and ticker.cancelled,
  "Incremental item listings must retain per-item weighted prices")

local getResult = C_AuctionHouse.GetCommoditySearchResultInfo
C_AuctionHouse.GetCommoditySearchResultInfo = function() error("result read failed") end
auction.Start(items, function() end)
ticker.callback()
local ok, failure = pcall(listener.scripts.OnEvent, listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(not ok and failure:find("result read failed", 1, true) and ticker.cancelled
  and not listener.scripts.OnUpdate and warnings[#warnings]:find("result processing failed", 1, true),
  "Summary errors must stop the scan and remain visible")
C_AuctionHouse.GetCommoditySearchResultInfo = getResult

results = { { unitPrice = 10, quantity = 2 }, { unitPrice = 20, quantity = 8 } }
Auctionator = { API = { v1 = {
  GetAuctionPriceByItemLink = function() return 77 end,
  GetAuctionAgeByItemLink = function() return 2 end,
} } }
C_AddOns = { IsAddOnLoaded = function(name) return name == "Auctionator_PriceHistoryTrends" end }
AUCTIONATOR_PRICE_HISTORY_TRENDS_CONFIG = { enabled = true, historyDays = 7, minPoints = 2, thresholdPercent = 5 }
Auctionator.Utilities = { DBKeyFromLink = function(_, callback) callback({ "42" }) end }
Auctionator.Database = {
  GetPrice = function() return 77 end,
  GetPriceHistory = function() return {
    { rawDay = 1, minSeen = 100, available = 4 }, { rawDay = 2, minSeen = 50, available = 8 },
  } end,
}
quote = auction.GetQuote("item:42")
assert(quote.minimum == 77 and quote.ageDays == 2 and quote.average == nil)
assert(quote.trend.percent == -23 and quote.trend.days == 1 and quote.trend.direction == "down",
  "trend must use the same scan-day baseline and current price as the companion tooltip")
local searchesBeforeAuctionator = searches
auction.Start(items, function() end)
assert(searches == searchesBeforeAuctionator, "Auctionator must suppress direct auction queries")
Auctionator = nil
auction.Start(items, function() end)
hooks.SendSearchQuery()
assert(ticker.cancelled and #warnings > 0, "another search must cancel the scan")
results = {}
auction.Start(items, function() end)
ticker.callback()
listener.scripts.OnEvent(listener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
quote = auction.GetQuote("item:42")
assert(quote and quote.minimum == nil and quote.timestamp == 123456 and ticker.cancelled,
  "an empty completed search must replace the old cached price")
auction.Start(items, function() end)
ticker.callback()
now = now + 31
ticker.callback()
assert(ticker.cancelled and warnings[#warnings]:find("could not be completed", 1, true),
  "timed-out searches must finish and report failure")
auction.Start(items, function() end)
C_Container.GetContainerItemInfo = function() return { hyperlink = "item:99", isBound = false } end
ticker.callback()
assert(ticker.cancelled and warnings[#warnings]:find("could not be completed", 1, true),
  "moved items must not be queried under the wrong link")
GetCurrentRegion = function() return 2 end
assert(auction.GetQuote("item:42") == nil, "cached prices must not leak between markets")
forever = true
assert(loadfile("ListviewBagAuction.lua"))()
local foreverAuction = SlackHacks.ListviewBagAuction
local firstFrame = #frames
foreverAuction.Start(twoItems, function() end)
local foreverListener, foreverWindow = frames[firstFrame + 1], frames[firstFrame + 2]
assert(foreverWindow.barFrame.template == "ObjectiveTrackerProgressBarTemplate" and foreverWindow.barFrame.shown
  and foreverWindow.bar.value == 0 and foreverWindow.bar.maximum == 2 and foreverWindow.text.text == "0 / 2 items",
  "Forever must use its native objective tracker bar at zero progress")
assert(foreverWindow.bar.width == foreverWindow.width * 0.8 and foreverWindow.bar.height == 15 * 1.5
  and foreverWindow.bar.BorderLeft.height == 22 * 1.5 and foreverWindow.bar.BorderRight.height == 22 * 1.5,
  "Forever's tracker bar and border must resize together")
C_Container.GetContainerItemInfo = function() return { hyperlink = "item:42", isBound = false } end
ticker.callback()
foreverListener.scripts.OnEvent(foreverListener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(foreverWindow.bar.value == 1 and foreverWindow.bar.maximum == 2 and foreverWindow.text.text == "1 / 2 items",
  "Forever's tracker bar must reflect partial progress")
ticker.callback()
foreverListener.scripts.OnEvent(foreverListener, "COMMODITY_SEARCH_RESULTS_UPDATED", 42)
assert(foreverWindow.bar.value == 2 and foreverWindow.text.text == "2 / 2 items"
  and ticker.cancelled and not foreverWindow.shown,
  "Forever's progress must reach full before completing the scan")
foreverAuction.Start(items, function() end)
assert(foreverWindow.bar.value == 0 and foreverWindow.bar.maximum == 1 and foreverWindow.text.text == "0 / 1 items",
  "A new Forever scan must reset the native bar")
foreverWindow.CloseButton.scripts.OnClick()
assert(ticker.cancelled and not foreverWindow.shown)
print("Listview Bag auction tests passed")
