-- Run with Lua 5.1 from the addon root: lua tests/listview_bag_auction.lua
SlackHacks = setmetatable({ db = { global = {} } }, { __index = _G })
SlackHacks.Self = SlackHacks
local warnings, frames, ticker = {}, {}, nil
local now = 100
function SlackHacks.prn(text) warnings[#warnings + 1] = text end
function GetNormalizedRealmName() return "TestRealm" end
function UnitFactionGroup() return "Alliance" end
function GetCurrentRegion() return 1 end
function GetTime() return now end
function time() return 123456 end
UIParent = {}
--- Create a minimal frame for the scanner and progress window.
---@return table frame Mock frame.
function CreateFrame()
  local frame = { scripts = {}, TitleText = { SetText = function() end }, CloseButton = { SetScript = function() end } }
  setmetatable(frame, { __index = function() return function() end end })
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:CreateFontString() return CreateFrame() end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
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
  GetCommoditySearchResultInfo = function(_, index) return results[index] end,
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
auction.Start(items, function() end)
assert(searches == 1, "Auctionator must suppress direct auction queries")
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
print("Listview Bag auction tests passed")
