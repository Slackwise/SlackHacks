setfenv(1, _G.SlackHacks)

local auction = {}
Self.ListviewBagAuction = auction

local scan
local scannerFrame
local progress
local sending = false
local hooksInstalled = false
local databaseKeys = {}
local pendingKeys = {}

--- Find the trend information displayed by the installed Auctionator companion.
---@param link string Item hyperlink.
---@param refresh function|nil Refresh callback for asynchronous item-key resolution.
---@return table|nil trend Price change and period, if enough scan days are available.
local function tooltipTrend(link, refresh)
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Auctionator_PriceHistoryTrends")
  local config = AUCTIONATOR_PRICE_HISTORY_TRENDS_CONFIG
  local database = Auctionator and Auctionator.Database
  local utilities = Auctionator and Auctionator.Utilities
  if not loaded or type(config) ~= "table" or config.enabled == false
    or not database or not database.GetPriceHistory or not database.GetPrice
    or not utilities or not utilities.DBKeyFromLink then return nil end
  local modifier = config.modifier
  if modifier == "shift" and not IsShiftKeyDown() or modifier == "ctrl" and not IsControlKeyDown()
    or modifier == "alt" and not IsAltKeyDown() then return nil end
  if not databaseKeys[link] and not pendingKeys[link] then
    pendingKeys[link] = true
    local synchronous = true
    utilities.DBKeyFromLink(link, function(keys)
      pendingKeys[link] = nil
      databaseKeys[link] = keys or {}
      if not synchronous and refresh then refresh() end
    end)
    synchronous = false
  end
  local days = math.max(1, math.min(30, tonumber(config.historyDays) or 7))
  local minPoints = math.max(2, math.min(31, tonumber(config.minPoints) or 2))
  for _, key in ipairs(databaseKeys[link] or {}) do
    local points, seen = {}, {}
    for _, entry in ipairs(database:GetPriceHistory(key) or {}) do
      local day = tonumber(entry.rawDay)
      local price = tonumber(entry.minSeen) or tonumber(entry.maxSeen)
      if day and price and price > 0 and not seen[day] then
        points[#points + 1] = { day = day, price = price }
        seen[day] = true
      end
    end
    table.sort(points, function(a, b) return a.day > b.day end)
    if #points > 0 then
      local newest, oldest, count = points[1], points[1], 0
      for _, point in ipairs(points) do
        if point.day >= newest.day - days then oldest, count = point, count + 1 end
      end
      if count >= minPoints then
        local current = tonumber(database:GetPrice(key))
        if not current or current <= 0 then current = newest.price end
        local delta = (current - oldest.price) * 100 / oldest.price
        local rounded = delta >= 0 and math.floor(delta + 0.5) or math.ceil(delta - 0.5)
        local threshold = tonumber(config.thresholdPercent) or 5
        return { percent = rounded, days = newest.day - oldest.day,
          direction = delta > threshold and "up" or delta < -threshold and "down" or "stable" }
      end
    end
  end
end

--- Return whether Auctionator is loaded and can supply its own cached prices.
---@return boolean available Whether Auctionator is active.
function auction.HasAuctionator()
  return Auctionator and Auctionator.API and Auctionator.API.v1
    and type(Auctionator.API.v1.GetAuctionPriceByItemLink) == "function" or false
end

--- Select a market-specific persistent cache.
---@return table cache Prices for the current region, realm, and faction.
local function marketCache()
  local global = Self.db.global
  global.listviewBagAuctionPrices = global.listviewBagAuctionPrices or {}
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
  local faction = UnitFactionGroup("player") or "unknown"
  local region = GetCurrentRegion and GetCurrentRegion() or 0
  local market = table.concat({ region, realm, faction }, ":")
  global.listviewBagAuctionPrices[market] = global.listviewBagAuctionPrices[market] or {}
  return global.listviewBagAuctionPrices[market]
end

--- Return the preferred cached price for an item.
---@param link string|nil Item hyperlink.
---@param refresh function|nil Refresh callback after asynchronous item-key resolution.
---@return table|nil quote Minimum, weighted average, timestamp, and source when available.
function auction.GetQuote(link, refresh)
  if not link then return nil end
  if auction.HasAuctionator() then
    local api = Auctionator.API.v1
    local minimum = api.GetAuctionPriceByItemLink("SlackHacks", link)
    if not minimum then return nil end
    local age = api.GetAuctionAgeByItemLink and api.GetAuctionAgeByItemLink("SlackHacks", link)
    return { minimum = minimum, ageDays = age, source = "Auctionator", trend = tooltipTrend(link, refresh) }
  end
  return marketCache()[link]
end

--- Compare Blizzard auction item keys, including variant-specific fields.
---@param left table|nil First item key.
---@param right table|nil Second item key.
---@return boolean equal Whether both identify the same auction item.
local function sameKey(left, right)
  return left and right and left.itemID == right.itemID
    and left.itemLevel == right.itemLevel and left.itemSuffix == right.itemSuffix
    and left.battlePetSpeciesID == right.battlePetSpeciesID
end

--- Calculate the lowest and quantity-weighted average buyout across loaded results.
---@param itemKey table Blizzard auction item key.
---@param commodity boolean Whether results are commodity listings.
---@return number|nil minimum Lowest per-item buyout.
---@return number|nil average Quantity-weighted per-item buyout.
function auction.Summarize(itemKey, commodity)
  local api = C_AuctionHouse
  local count = commodity and api.GetNumCommoditySearchResults(itemKey.itemID)
    or api.GetNumItemSearchResults(itemKey)
  local minimum, totalPrice, totalQuantity = nil, 0, 0
  for index = 1, count do
    local result
    if commodity then result = api.GetCommoditySearchResultInfo(itemKey.itemID, index)
    else result = api.GetItemSearchResultInfo(itemKey, index) end
    local quantity = result and result.quantity
    local price = result and (commodity and result.unitPrice or result.buyoutAmount)
    if type(quantity) == "number" and quantity > 0 and type(price) == "number" and price > 0 then
      local unitPrice = commodity and price or price / quantity
      minimum = not minimum and unitPrice or math.min(minimum, unitPrice)
      totalPrice = totalPrice + unitPrice * quantity
      totalQuantity = totalQuantity + quantity
    end
  end
  if not minimum then return nil, nil end
  return math.floor(minimum + 0.5), math.floor(totalPrice / totalQuantity + 0.5)
end

--- Hide the progress UI and stop the active scan.
---@param reason string|nil Reason to report to the user.
function auction.Cancel(reason)
  if not scan then return end
  if scan.ticker then scan.ticker:Cancel() end
  scan = nil
  if scannerFrame then scannerFrame:UnregisterAllEvents() end
  if progress then progress:Hide() end
  if reason then prn(reason) end
end

--- Construct the native-style progress window on first use.
---@return table window Progress window.
local function progressWindow()
  if progress then return progress end
  progress = CreateFrame("Frame", "SlackHacksAuctionScanProgress", UIParent, "BasicFrameTemplateWithInset")
  progress:SetSize(300, 100)
  progress:SetPoint("CENTER")
  progress:SetFrameStrata("DIALOG")
  progress.TitleText:SetText("Checking Auction Prices")
  progress.text = progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  progress.text:SetPoint("TOP", 0, -30)
  progress.bar = CreateFrame("StatusBar", nil, progress)
  progress.bar:SetPoint("TOPLEFT", 16, -48)
  progress.bar:SetPoint("TOPRIGHT", -16, -48)
  progress.bar:SetHeight(12)
  progress.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  progress.bar:SetStatusBarColor(0.2, 0.65, 0.25)
  progress.cancel = CreateFrame("Button", nil, progress, "UIPanelButtonTemplate")
  progress.cancel:SetSize(80, 20)
  progress.cancel:SetPoint("BOTTOM", 0, 8)
  progress.cancel:SetText("Cancel")
  progress.cancel:SetScript("OnClick", function() auction.Cancel("auction price scan cancelled.") end)
  progress:SetScript("OnHide", function()
    if scan then auction.Cancel("auction price scan cancelled.") end
  end)
  if progress.CloseButton then
    progress.CloseButton:SetScript("OnClick", function() auction.Cancel("auction price scan cancelled.") end)
  end
  return progress
end

--- Publish progress and complete the scan once every requested item is processed.
local function advance()
  if not scan then return end
  scan.index = scan.index + 1
  scan.current = nil
  scan.pendingMore = false
  scan.waiting = false
  scan.deadline = nil
  progress.bar:SetValue(scan.index - 1)
  progress.text:SetText(("%d / %d items"):format(scan.index - 1, #scan.items))
  if scan.index > #scan.items then
    local failed, refresh = scan.failed, scan.refresh
    auction.Cancel()
    if failed > 0 then prn(("%d auction price queries could not be completed."):format(failed)) end
    refresh()
  end
end

--- Complete a result only when Blizzard reports that every page has arrived.
---@param event string Auction result event.
---@param item table|number Result item key or commodity ID.
local function onResult(event, item)
  if not scan or not scan.current or not scan.waiting then return end
  local current = scan.current
  local commodity = event:match("^COMMODITY") ~= nil
  if commodity then
    if item ~= current.key.itemID then return end
  elseif not sameKey(item, current.key) then return end
  local full = commodity and C_AuctionHouse.HasFullCommoditySearchResults(current.key.itemID)
    or not commodity and C_AuctionHouse.HasFullItemSearchResults(current.key)
  if not full then
    scan.pendingMore = commodity and "commodity" or "item"
    scan.waiting = false
    return
  end
  local minimum, average = auction.Summarize(current.key, commodity)
  marketCache()[current.link] = { minimum = minimum, average = average, timestamp = time(), source = "Auction House" }
  scan.refresh()
  advance()
end

--- Send queued searches and pages only while Blizzard's auction throttle permits it.
local function tick()
  if not scan then return end
  if scan.deadline and GetTime() > scan.deadline then
    scan.failed = scan.failed + 1
    advance()
    return
  end
  if scan.waiting then return end
  if not scan.current then
    local item = scan.items[scan.index]
    scan.current = { link = item.link, bagID = item.bagID, slot = item.slot }
    scan.deadline = GetTime() + 30
  end
  local current = scan.current
  local info = C_Container.GetContainerItemInfo(current.bagID, current.slot)
  if not info or info.hyperlink ~= current.link or info.isBound then
    scan.failed = scan.failed + 1
    advance()
    return
  end
  if not current.key then
    local location = ItemLocation:CreateFromBagAndSlot(current.bagID, current.slot)
    current.key = C_AuctionHouse.GetItemKeyFromItem(location)
    if not current.key then return end
  end
  if not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
  -- The server can silently ignore searches until its item-key information is cached.
  if C_AuctionHouse.GetItemKeyInfo and not C_AuctionHouse.GetItemKeyInfo(current.key) then return end
  scan.waiting = true
  scan.deadline = GetTime() + 30
  sending = true
  if scan.pendingMore == "commodity" then
    C_AuctionHouse.RequestMoreCommoditySearchResults(current.key.itemID)
  elseif scan.pendingMore == "item" then
    C_AuctionHouse.RequestMoreItemSearchResults(current.key)
  else
    C_AuctionHouse.SendSearchQuery(current.key, {}, false)
  end
  sending = false
  scan.pendingMore = false
end

--- Start a throttled scan for the provided bag items when no pricing addon is active.
---@param items table Items with links and bag locations.
---@param refresh function Refresh callback after prices change.
function auction.Start(items, refresh)
  auction.Cancel()
  if auction.HasAuctionator() or #items == 0 then return end
  if not C_AuctionHouse or not C_AuctionHouse.SendSearchQuery or not C_Timer or not C_Timer.NewTicker
    or not ItemLocation or not ItemLocation.CreateFromBagAndSlot
    or not C_Container or not C_Container.GetContainerItemInfo then
    prn("auction price queries are unavailable on this client.")
    return
  end
  for _, name in ipairs({ "GetItemKeyFromItem", "IsThrottledMessageSystemReady",
    "HasFullCommoditySearchResults", "HasFullItemSearchResults", "GetNumCommoditySearchResults",
    "GetCommoditySearchResultInfo", "GetNumItemSearchResults", "GetItemSearchResultInfo",
    "RequestMoreCommoditySearchResults", "RequestMoreItemSearchResults" }) do
    if type(C_AuctionHouse[name]) ~= "function" then
      prn("auction price queries are unavailable: missing " .. name .. ".")
      return
    end
  end
  if not hooksInstalled then
    for _, method in ipairs({ "SendSearchQuery", "SendSellSearchQuery", "SendBrowseQuery",
      "RequestMoreItemSearchResults", "RequestMoreCommoditySearchResults" }) do
      if type(C_AuctionHouse[method]) == "function" then
        hooksecurefunc(C_AuctionHouse, method, function()
          if scan and not sending then auction.Cancel("auction price scan stopped because another search started.") end
        end)
      end
    end
    hooksInstalled = true
  end
  if not scannerFrame then
    scannerFrame = CreateFrame("Frame")
    scannerFrame:SetScript("OnEvent", function(_, event, item) onResult(event, item) end)
  end
  for _, event in ipairs({ "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED" }) do
    if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid(event) then
      scannerFrame:RegisterEvent(event)
    end
  end
  scan = { items = items, refresh = refresh, index = 1, failed = 0 }
  local window = progressWindow()
  window.bar:SetMinMaxValues(0, #items)
  window.bar:SetValue(0)
  window.text:SetText(("0 / %d items"):format(#items))
  window:Show()
  scan.ticker = C_Timer.NewTicker(0.2, tick)
end
