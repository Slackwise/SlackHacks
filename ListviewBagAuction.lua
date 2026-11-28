setfenv(1, _G.SlackHacks)

local auction = {}
Self.ListviewBagAuction = auction

local scan
local scannerFrame
local progress
local posting
local postProgress
local sending = false
local hooksInstalled = false
local databaseKeys = {}
local pendingKeys = {}
local SUMMARY_SLICE_MS = 2
local SUMMARY_SLICE_RESULTS = 100
local REFRESH_INTERVAL = 1

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

--- Calculate prices, optionally yielding between bounded batches of results.
---@param itemKey table Blizzard auction item key.
---@param commodity boolean Whether results are commodity listings.
---@param incremental boolean Whether to yield between batches.
---@return number|nil minimum Lowest per-item buyout.
---@return number|nil average Quantity-weighted per-item buyout.
local function summarize(itemKey, commodity, incremental)
  local api = C_AuctionHouse
  local count = commodity and api.GetNumCommoditySearchResults(itemKey.itemID)
    or api.GetNumItemSearchResults(itemKey)
  local minimum, totalPrice, totalQuantity = nil, 0, 0
  local sliceStart = incremental and debugprofilestop()
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
    -- Check periodically to limit profiling overhead, with a hard cap even on fast machines.
    if incremental and index < count and index % 10 == 0
      and (index % SUMMARY_SLICE_RESULTS == 0 or debugprofilestop() - sliceStart >= SUMMARY_SLICE_MS) then
      coroutine.yield()
      sliceStart = debugprofilestop()
    end
  end
  if not minimum then return nil, nil end
  return math.floor(minimum + 0.5), math.floor(totalPrice / totalQuantity + 0.5)
end

--- Calculate the lowest and quantity-weighted average buyout across loaded results.
---@param itemKey table Blizzard auction item key.
---@param commodity boolean Whether results are commodity listings.
---@return number|nil minimum Lowest per-item buyout.
---@return number|nil average Quantity-weighted per-item buyout.
function auction.Summarize(itemKey, commodity)
  return summarize(itemKey, commodity, false)
end

--- Hide the progress UI and stop the active price scan.
---@param reason string|nil Reason to report to the user.
function auction.Cancel(reason)
  if not scan then return end
  local refresh = scan.dirty and scan.refresh
  if scan.ticker then scan.ticker:Cancel() end
  scan = nil
  if scannerFrame then
    scannerFrame:UnregisterAllEvents()
    scannerFrame:SetScript("OnUpdate", nil)
  end
  if progress then progress:Hide() end
  if reason then prn(reason) end
  if refresh then refresh() end
end

--- Create a native-style progress window for an auction task.
---@param name string Global frame name.
---@param title string Window title.
---@param cancel function Cancellation callback.
---@param onHide function Callback when the window is hidden.
---@return table window Progress window.
local function createProgressWindow(name, title, cancel, onHide)
  local window = CreateFrame("Frame", name, UIParent, "SimplePanelTemplate")
  window:SetSize(300, 160)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:SetDontSavePosition(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  window:Hide()
  window.Inset:Hide()
  window.Bg:ClearAllPoints()
  window.Bg:SetPoint("TOPLEFT", 0, -6)
  window.Bg:SetPoint("BOTTOMRIGHT", -4, 3)

  window.headline = window:CreateTexture(nil, "BACKGROUND")
  window.headline:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
  window.headline:SetBlendMode("ADD")
  window.headline:SetVertexColor(0.1, 0.1, 0.1, 1)
  window.headline:SetHeight(26)
  window.headline:SetPoint("TOPLEFT", 40, -21)
  window.headline:SetPoint("TOPRIGHT", -40, -21)
  window.title = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  window.title:SetHeight(26)
  window.title:SetPoint("TOPLEFT", 12, -21)
  window.title:SetPoint("TOPRIGHT", -14, -21)
  window.title:SetJustifyH("CENTER")
  window.title:SetText(title)
  window.text = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  window.text:SetPoint("TOP", 0, -54)
  window.barFrame = CreateFrame("Frame", nil, window, "ObjectiveTrackerProgressBarTemplate")
  window.bar = window.barFrame.Bar
  local barWidth, heightScale = window:GetWidth() * 0.8, 1.5
  window.bar.BorderLeft:SetHeight(window.bar.BorderLeft:GetHeight() * heightScale)
  window.bar.BorderRight:SetHeight(window.bar.BorderRight:GetHeight() * heightScale)
  window.bar:SetSize(barWidth, window.bar:GetHeight() * heightScale)
  -- The tracker template is hidden and offsets its bar for the quest list.
  window.barFrame:ClearAllPoints()
  window.barFrame:SetSize(barWidth, window.bar.BorderLeft:GetHeight())
  window.barFrame:SetPoint("TOP", 0, -70)
  window.bar:ClearAllPoints()
  window.bar:SetPoint("CENTER")
  window.bar:EnableMouse(false)
  window.barFrame:Show()
  window.cancel = CreateFrame("Button", nil, window, "SharedButtonSmallTemplate")
  window.cancel:SetSize(140, 22)
  window.cancel:SetPoint("BOTTOM", 0, 16)
  window.cancel:SetText("Cancel")
  window.cancel:SetScript("OnClick", cancel)
  window:SetScript("OnHide", onHide)
  window.CloseButton = CreateFrame("Button", nil, window, "UIPanelCloseButtonDefaultAnchors")
  window.CloseButton:SetScript("OnClick", cancel)
  window.addonLabel = window:CreateFontString(nil, "ARTWORK", "GameFontDarkGraySmall")
  window.addonLabel:SetPoint("BOTTOMRIGHT", -7, 5)
  window.addonLabel:SetTextColor(0.4, 0.4, 0.4)
  window.addonLabel:SetText(addonName)
  return window
end

--- Construct the native-style price-scan progress window on first use.
---@return table window Progress window.
local function progressWindow()
  if progress then return progress end
  progress = createProgressWindow("SlackHacksAuctionScanProgress", "Checking Auction Prices",
    function() auction.Cancel("Auction price scan cancelled.") end, function()
      if scan then auction.Cancel("Auction price scan cancelled.") end
    end)
  return progress
end

--- Update the scan count and native objective tracker progress bar.
---@param completed number Number of completed items.
---@param total number Total number of items.
local function updateProgress(completed, total)
  progress.bar:SetMinMaxValues(0, total)
  progress.bar:SetValue(completed)
  progress.text:SetText(("%d / %d items"):format(completed, total))
end

--- Publish progress and complete the scan once every requested item is processed.
local function advance()
  if not scan then return end
  scan.index = scan.index + 1
  scan.current = nil
  scan.pendingMore = false
  scan.waiting = false
  scan.deadline = nil
  updateProgress(scan.index - 1, #scan.items)
  if scan.index > #scan.items then
    local failed, refresh, dirty = scan.failed, scan.refresh, scan.dirty
    auction.Cancel()
    if failed > 0 then prn(("%d auction price queries could not be completed."):format(failed)) end
    if not dirty then refresh() end
  end
end

--- Resume one bounded result-processing slice and publish a completed quote.
local function resumeSummary()
  local active = scan
  if not active or not active.worker then return end
  local ok, minimum, average = coroutine.resume(active.worker)
  if not ok then
    auction.Cancel("Auction price scan stopped because result processing failed.")
    error(minimum)
  end
  if scan ~= active or coroutine.status(active.worker) ~= "dead" then return end
  scannerFrame:SetScript("OnUpdate", nil)
  active.worker = nil
  marketCache()[active.current.link] = {
    minimum = minimum, average = average, timestamp = time(), source = "Auction House",
  }
  active.dirty = true
  advance()
end

--- Complete a result only when Blizzard reports that every page has arrived.
---@param event string Auction result event.
---@param item table|number Result item key or commodity ID.
local function onResult(event, item)
  if not scan or not scan.current or not (scan.waiting or scan.worker) then return end
  local current = scan.current
  local commodity = event:match("^COMMODITY") ~= nil
  if commodity then
    if item ~= current.key.itemID then return end
  elseif not sameKey(item, current.key) then return end
  -- A new result event can replace the result set while a summary is yielding.
  if scan.worker then
    scan.worker = nil
    scannerFrame:SetScript("OnUpdate", nil)
  end
  local full = commodity and C_AuctionHouse.HasFullCommoditySearchResults(current.key.itemID)
    or not commodity and C_AuctionHouse.HasFullItemSearchResults(current.key)
  if not full then
    scan.pendingMore = commodity and "commodity" or "item"
    scan.waiting = false
    scan.deadline = GetTime() + 30
    return
  end
  scan.waiting = false
  scan.deadline = nil
  scan.worker = coroutine.create(function() return summarize(current.key, commodity, true) end)
  resumeSummary()
  if scan and scan.worker then scannerFrame:SetScript("OnUpdate", resumeSummary) end
end

--- Send queued searches and pages only while Blizzard's auction throttle permits it.
local function tick()
  if not scan then return end
  if scan.dirty and GetTime() >= scan.nextRefresh then
    local active = scan
    active.dirty = false
    active.nextRefresh = GetTime() + REFRESH_INTERVAL
    active.refresh()
    if scan ~= active then return end
  end
  if scan.worker then return end
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

--- Count copies of a hyperlink across the player's bags and reagent bag.
---@param link string Item hyperlink.
---@return number count Current inventory quantity.
local function inventoryCount(link)
  local count = 0
  -- Count by link across bags so a slot change does not look like a successful post.
  for bagID = 0, 5 do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      if info and info.hyperlink == link then count = count + (info.stackCount or 1) end
    end
  end
  return count
end

--- Calculate the native Auction House's auto-populated buyout value.
---@param link string Item hyperlink.
---@return number|nil price Default price, or nil when the native default is unavailable.
local function defaultAuctionPrice(link)
  local api = C_AuctionHouse
  local multiplier = Constants and Constants.AuctionConstants
    and Constants.AuctionConstants.DEFAULT_AUCTION_PRICE_MULTIPLIER
  if not api.ShouldAutoPopulatePrice() or type(multiplier) ~= "number" then return nil end
  local vendorPrice = select(11, C_Item.GetItemInfo(link))
  local price = type(vendorPrice) == "number" and vendorPrice * multiplier or COPPER_PER_SILVER
  -- Match FrameXML's rounding exactly; it advances to the next silver even on an exact amount.
  price = price + (COPPER_PER_SILVER - (price % COPPER_PER_SILVER))
  return math.max(price, COPPER_PER_SILVER)
end

--- Finish a Quick Sell job and refresh the bag view.
---@param active table Active posting job.
---@param message string|nil Optional user-facing result.
local function finishQuickSell(active, message)
  if posting ~= active then return end
  posting = nil
  if postProgress then postProgress:Hide() end
  if message then prn(message) end
  if active.refresh then active.refresh() end
end

local postCurrentItem

--- Wait progressively for Blizzard's auction throttle, then enable the next click-driven post.
---@param active table Active posting job.
---@param delay number|nil Next polling delay in seconds.
---@param started number|nil Time the wait began.
local function awaitNextPost(active, delay, started)
  if posting ~= active then return end
  delay, started = delay or 0.1, started or GetTime()
  if C_AuctionHouse.IsThrottledMessageSystemReady() then
    active.ready = true
    postProgress.note:SetText("Next: " .. (active.items[active.index].link or "item"))
    postProgress.post:Enable()
    return
  end
  local elapsed = GetTime() - started
  if elapsed >= 3 then
    finishQuickSell(active, "Quick Sell stopped because the Auction House remained throttled.")
    return
  end
  postProgress.note:SetText("Waiting for the Auction House...")
  C_Timer.After(math.min(delay, 3 - elapsed), function()
    awaitNextPost(active, math.min(delay + 0.1, 1), started)
  end)
end

--- Confirm a posted stack left the bags, then advance to the next item.
---@param active table Active posting job.
---@param link string Posted item hyperlink.
---@param expected number Maximum bag quantity once the post succeeds.
---@param delay number Delay before this check in seconds.
---@param started number Time verification began.
local function verifyPost(active, link, expected, delay, started)
  C_Timer.After(delay, function()
    if posting ~= active then return end
    if inventoryCount(link) <= expected then
      active.completed = active.completed + 1
      active.index = active.index + 1
      postProgress.bar:SetValue(active.completed)
      postProgress.text:SetText(("%d / %d items"):format(active.completed, #active.items))
      if active.index > #active.items then
        finishQuickSell(active, ("Quick Sell posted %d item stacks."):format(active.completed))
      else
        C_Timer.After(0.5, function() awaitNextPost(active) end)
      end
      return
    end
    local elapsed = GetTime() - started
    if elapsed >= 3 then
      finishQuickSell(active,
        "Quick Sell stopped because the Auction House did not remove the posted item from your bags.")
      return
    end
    verifyPost(active, link, expected, math.min(delay + 0.1, 3 - elapsed), started)
  end)
end

--- Validate and post the current item. Must run inside a click handler.
---@param active table Active posting job.
postCurrentItem = function(active)
  -- PostItem/PostCommodity require a hardware event, so each post runs directly from a click
  -- rather than from a timer or coroutine; timers only wait for throttling and verification.
  if posting ~= active then return end
  active.ready = false
  postProgress.post:Disable()
  local api = C_AuctionHouse
  if not api.IsThrottledMessageSystemReady() then
    awaitNextPost(active)
    return
  end
  local item, duration = active.items[active.index], active.duration
  local function stop(reason) finishQuickSell(active, "Quick Sell stopped because " .. reason) end
  if item.canPost and not item.canPost() then
    return stop("an item's Auction flag or eligibility changed.")
  end
  local info = C_Container.GetContainerItemInfo(item.bagID, item.slot)
  if not info or info.hyperlink ~= item.link or info.itemID ~= item.itemID
    or info.isBound or info.isLocked or (info.stackCount or 1) ~= item.count then
    return stop("an item moved or changed in your bags.")
  end
  local location = ItemLocation:CreateFromBagAndSlot(item.bagID, item.slot)
  if not location:IsValid() or not api.IsSellItemValid(location, false) then
    return stop("an item is no longer eligible for auction.")
  end
  local price = defaultAuctionPrice(item.link)
  if not price or price <= 0 then
    return stop("the Auction House could not determine a default price.")
  end
  local commodityStatus = api.GetItemCommodityStatus(location)
  if commodityStatus ~= Enum.ItemCommodityStatus.Item
    and commodityStatus ~= Enum.ItemCommodityStatus.Commodity then
    return stop("an item's Auction House type could not be determined.")
  end
  local commodity = commodityStatus == Enum.ItemCommodityStatus.Commodity
  local available = api.GetAvailablePostCount(location)
  local quantity = math.min(item.count, type(available) == "number" and available or item.count)
  if quantity < 1 then
    return stop("an item has no available auction quantity.")
  end
  local deposit = commodity
    and api.CalculateCommodityDeposit(item.itemID, duration, quantity)
    or api.CalculateItemDeposit(location, duration, quantity)
  if GetMoney() < deposit then
    return stop("there is not enough money for an auction deposit.")
  end
  local before = inventoryCount(item.link)
  if before < quantity then
    return stop("an item's inventory quantity changed.")
  end

  if commodity then
    if api.PostCommodity(location, duration, quantity, price) then
      api.ConfirmPostCommodity(location, duration, quantity, price)
    end
  else
    if api.PostItem(location, duration, quantity, nil, price) then
      api.ConfirmPostItem(location, duration, quantity, nil, price)
    end
  end
  postProgress.note:SetText("Confirming " .. item.link .. "...")
  verifyPost(active, item.link, before - quantity, 0.1, GetTime())
end

--- Post the next queued Quick Sell item from a user click.
function auction.PostNextQuickSell()
  if posting and posting.ready then postCurrentItem(posting) end
end

--- Cancel Quick Sell without attempting to cancel a request already sent to Blizzard.
---@param reason string|nil Reason to report to the user.
function auction.CancelQuickSell(reason)
  if not posting then return end
  local active = posting
  finishQuickSell(active, reason or "Quick Sell cancelled. The active auction request may still complete.")
end

--- Create the dedicated Quick Sell progress window on first use.
---@return table window Progress window.
local function quickSellProgressWindow()
  if postProgress then return postProgress end
  postProgress = createProgressWindow("SlackHacksAuctionPostProgress", "Posting Auction Items",
    function() auction.CancelQuickSell() end, function()
      if posting then auction.CancelQuickSell() end
    end)
  postProgress:SetHeight(180)
  postProgress.note = postProgress:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  postProgress.note:SetPoint("TOP", 0, -112)
  postProgress.note:SetWidth(260)
  postProgress.post = CreateFrame("Button", nil, postProgress, "SharedButtonSmallTemplate")
  postProgress.post:SetSize(120, 22)
  postProgress.post:SetPoint("BOTTOMRIGHT", postProgress, "BOTTOM", -4, 16)
  postProgress.post:SetText("Post Next")
  postProgress.post:SetScript("OnClick", auction.PostNextQuickSell)
  postProgress.post:SetMotionScriptsWhileDisabled(true)
  postProgress.post:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Post Next")
    GameTooltip:AddLine("Blizzard requires a click for each auction posting.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  postProgress.post:SetScript("OnLeave", GameTooltip_Hide)
  postProgress.cancel:SetSize(120, 22)
  postProgress.cancel:ClearAllPoints()
  postProgress.cancel:SetPoint("BOTTOMLEFT", postProgress, "BOTTOM", 4, 16)
  return postProgress
end

--- Start a throttled sale of the provided auction-flagged bag stacks, posting one per click.
---@param items table Entries with link, itemID, bagID, slot, count, and optional canPost callback.
---@param refresh function Refresh callback after the job ends.
function auction.QuickSell(items, refresh)
  if posting then
    if posting.ready then
      postCurrentItem(posting)
    else
      prn("Quick Sell is waiting for the Auction House before the next posting.")
    end
    return
  end
  auction.Cancel()
  if type(items) ~= "table" or #items == 0 then
    prn("There are no eligible Auction-flagged items to sell.")
    return
  end
  local api = C_AuctionHouse
  local required = {
    "IsThrottledMessageSystemReady", "IsSellItemValid", "GetItemCommodityStatus",
    "GetAvailablePostCount", "PostItem", "ConfirmPostItem", "PostCommodity", "ConfirmPostCommodity",
    "CalculateItemDeposit", "CalculateCommodityDeposit", "ShouldAutoPopulatePrice",
  }
  for _, name in ipairs(required) do
    if not api or type(api[name]) ~= "function" then
      prn("Quick Sell is unavailable: missing Auction House API " .. name .. ".")
      return
    end
  end
  if not C_Container or type(C_Container.GetContainerItemInfo) ~= "function"
    or type(C_Container.GetContainerNumSlots) ~= "function"
    or not ItemLocation or type(ItemLocation.CreateFromBagAndSlot) ~= "function"
    or not C_Item or type(C_Item.GetItemInfo) ~= "function"
    or not C_Timer or type(C_Timer.After) ~= "function" or type(GetCVar) ~= "function"
    or type(GetMoney) ~= "function" or type(GetTime) ~= "function" then
    prn("Quick Sell is unavailable because required inventory or pricing APIs are missing.")
    return
  end
  if not (Enum and Enum.ItemCommodityStatus and Enum.ItemCommodityStatus.Item
    and Enum.ItemCommodityStatus.Commodity)
    or type(COPPER_PER_SILVER) ~= "number" then
    prn("Quick Sell is unavailable because this client does not expose Auction House item types.")
    return
  end
  if not api.ShouldAutoPopulatePrice() then
    prn("Quick Sell requires the Auction House's automatic default pricing to be enabled.")
    return
  end
  local duration = tonumber(GetCVar("auctionHouseDurationDropdown"))
  if not duration or duration < 1 or duration > 3 then
    prn("Quick Sell could not read the Auction House listing duration.")
    return
  end
  local multiplier = Constants and Constants.AuctionConstants
    and Constants.AuctionConstants.DEFAULT_AUCTION_PRICE_MULTIPLIER
  if type(multiplier) ~= "number" then
    prn("Quick Sell could not read the Auction House's default price multiplier.")
    return
  end

  local active = { items = items, refresh = refresh, duration = duration, completed = 0, index = 1 }
  posting = active
  postProgress = quickSellProgressWindow()
  postProgress.post:Disable()
  postProgress.bar:SetMinMaxValues(0, #items)
  postProgress.bar:SetValue(0)
  postProgress.text:SetText(("0 / %d items"):format(#items))
  postProgress:Show()
  -- The Quick Sell click is a hardware event, so the first item posts immediately.
  postCurrentItem(active)
end

--- Start a throttled scan for the provided bag items when no pricing addon is active.
---@param items table Items with links and bag locations.
---@param refresh function Refresh callback after prices change.
function auction.Start(items, refresh)
  auction.Cancel()
  if posting then auction.CancelQuickSell("Quick Sell stopped because auction price scanning started.") end
  if auction.HasAuctionator() or #items == 0 then return end
  if not C_AuctionHouse or not C_AuctionHouse.SendSearchQuery or not C_Timer or not C_Timer.NewTicker
    or not ItemLocation or not ItemLocation.CreateFromBagAndSlot
    or not C_Container or not C_Container.GetContainerItemInfo then
    prn("Auction price queries are unavailable on this client.")
    return
  end
  for _, name in ipairs({ "GetItemKeyFromItem", "IsThrottledMessageSystemReady",
    "HasFullCommoditySearchResults", "HasFullItemSearchResults", "GetNumCommoditySearchResults",
    "GetCommoditySearchResultInfo", "GetNumItemSearchResults", "GetItemSearchResultInfo",
    "RequestMoreCommoditySearchResults", "RequestMoreItemSearchResults" }) do
    if type(C_AuctionHouse[name]) ~= "function" then
      prn("Auction price queries are unavailable: missing " .. name .. ".")
      return
    end
  end
  if not hooksInstalled then
    for _, method in ipairs({ "SendSearchQuery", "SendSellSearchQuery", "SendBrowseQuery",
      "RequestMoreItemSearchResults", "RequestMoreCommoditySearchResults" }) do
      if type(C_AuctionHouse[method]) == "function" then
        hooksecurefunc(C_AuctionHouse, method, function()
          if scan and not sending then auction.Cancel("Auction price scan stopped because another search started.") end
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
  scan = { items = items, refresh = refresh, index = 1, failed = 0, nextRefresh = GetTime() + REFRESH_INTERVAL }
  local window = progressWindow()
  updateProgress(0, #items)
  window:Show()
  scan.ticker = C_Timer.NewTicker(0.2, tick)
end
