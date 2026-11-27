setfenv(1, _G.SlackHacks)

--- Identify the upstream icon dataset for the current client.
---@return number|nil flag Dataset bit, or nil for an unsupported client.
local function getIconDatasetFlag()
  if WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return 1 end
  if WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then return 2 end
  local interface = select(4, GetBuildInfo())
  if interface >= 50000 and interface < 60000 then return 4 end
  if interface >= 20000 and interface < 30000 then return 8 end
  if interface >= 10000 and interface < 20000 then return 16 end
end

--- Decode the generated icon names once, when an icon picker first needs them.
---@return string data File IDs, client flags, and names separated into lines.
local function getIconNameData()
  if IconNames.compressed then
    local previousID, previousName = 0, ""
    -- IDs are deltas and names reuse a prefix from the previous record.
    --- Expand one generated record and update the previous-record state.
    ---@param delta string File ID delta.
    ---@param flags string Client flags.
    ---@param prefix string Length of the shared name prefix.
    ---@param suffix string Remaining name characters.
    ---@return string record Expanded record.
    IconNames.data = IconNames.data:gsub("(%d+)|(%d+)|(%d+)|([^\n]*)\n", function(delta, flags, prefix, suffix)
      previousID = previousID + tonumber(delta)
      -- A terminal marker protects meaningful trailing spaces from whitespace cleanup.
      if suffix:byte(-1) == 126 then suffix = suffix:sub(1, -2) end
      previousName = previousName:sub(1, tonumber(prefix)) .. suffix
      return previousID .. "|" .. flags .. "|" .. previousName .. "\n"
    end)
    IconNames.compressed = nil
  end
  return IconNames.data
end

--- Build a filtered icon list using the native provider and extracted file names.
---@param provider table Native icon provider.
---@param filter number Native icon filter.
---@param query string Search text.
---@return table icons Matching texture IDs or paths.
local function buildIconList(provider, filter, query)
  query = query:lower()
  local icons = {}
  local datasetFlag = getIconDatasetFlag()
  local includeExtracted = filter == IconSelectorPopupFrameIconFilterTypes.All
  local matchingIDs, matchingNames, extraIcons = {}, {}, {}
  if datasetFlag and (query ~= "" or includeExtracted) then
    -- Only matching records need temporary lookup tables.
    for idText, flagsText, name in getIconNameData():gmatch("(%d+)|(%d+)|([^\n]+)\n") do
      local flags = tonumber(flagsText)
      if math.floor(flags / datasetFlag) % 2 == 1 and (query == "" or name:find(query, 1, true)) then
        local id = tonumber(idText)
        if C_UIFileAsset.IsKnownFile(id) then
          matchingIDs[id] = true
          if includeExtracted then
            matchingNames[name] = matchingNames[name] or id
            extraIcons[#extraIcons + 1] = id
          end
        end
      end
    end
  end
  local seen = {}
  for index = 1, provider:GetNumIcons() do
    local icon = provider:GetIconByIndex(index)
    local matches = query == "" or
      (type(icon) == "number" and matchingIDs[icon]) or
      (type(icon) == "string" and icon:lower():find(query, 1, true))
    if matches then
      icons[#icons + 1] = icon
      if includeExtracted then
        if type(icon) == "number" then
          seen[icon] = true
        elseif type(icon) == "string" then
          local basename = icon:match("([^\\/:]+)$")
          local id = basename and matchingNames[basename:lower():gsub("%.blp$", "")]
          if id then seen[id] = true end
        end
      end
    end
  end
  -- Extracted icons have no native Spell/Item classification, so add them only to All.
  if includeExtracted then
    for _, id in ipairs(extraIcons) do
      if not seen[id] then
        icons[#icons + 1] = id
        seen[id] = true
      end
    end
  end
  return icons
end

local pickerHooked = false
local nativePickers = setmetatable({}, { __mode = "k" })

--- Refresh a native picker after its icon provider has been created.
---@param popup table Blizzard icon picker.
local function refreshNativePicker(popup)
  local state = nativePickers[popup]
  if not state or not popup.iconDataProvider then return end
  if state.active and not state.ready then return end
  if state.active and db and db.profile.utilities.addIconPickerSearch then
    state.icons = buildIconList(popup.iconDataProvider, popup.iconFilter, state.search:GetText())
  else
    state.icons = nil
  end
  popup.IconSelector:UpdateSelections()
  popup:ReevaluateSelectedIcon()
end

--- Attach the opt-in search box to a native icon picker.
---@param popup table Blizzard icon picker.
local function attachNativePicker(popup)
  if popup.slackHacksOwnIconPicker or not (db and db.profile.utilities.addIconPickerSearch) then return end
  local state = nativePickers[popup]
  if not state then
    local search = CreateFrame("EditBox", nil, popup.BorderBox, "SearchBoxTemplate")
    search:SetSize(150, 20)
    search:SetPoint("LEFT", popup.BorderBox.IconSelectionText, "RIGHT", 12, 0)
    search:SetAutoFocus(false)
    state = { search = search }
    nativePickers[popup] = state
    local getIcon, getIndex, getCount = popup.GetIconByIndex, popup.GetIndexOfIcon, popup.GetNumIcons
    --- Return an icon from the filtered list or the original provider.
    ---@param self table Icon picker.
    ---@param index number Icon index.
    ---@return number|string|nil icon Texture.
    popup.GetIconByIndex = function(self, index)
      if state.icons then return state.icons[index] end
      return getIcon(self, index)
    end
    --- Find an icon in the filtered list or the original provider.
    ---@param self table Icon picker.
    ---@param icon number|string Texture.
    ---@return number|nil index Icon index.
    popup.GetIndexOfIcon = function(self, icon)
      if state.icons then
        for index, value in ipairs(state.icons) do if value == icon then return index end end
        return nil
      end
      return getIndex(self, icon)
    end
    --- Count the filtered icons or the original provider's icons.
    ---@param self table Icon picker.
    ---@return number count Icon count.
    popup.GetNumIcons = function(self)
      if state.icons then return #state.icons end
      return getCount(self)
    end
    --- Refresh the results when the search text changes.
    search:HookScript("OnTextChanged", function() refreshNativePicker(popup) end)
    --- Refresh the results when the native icon category changes.
    hooksecurefunc(popup, "SetIconFilterInternal", function() refreshNativePicker(popup) end)
    --- Discard filtered results when the picker closes.
    popup:HookScript("OnHide", function()
      state.active = false
      state.icons = nil
      search:ClearFocus()
    end)
  end
  state.icons = nil
  state.active = true
  state.ready = false
  state.search:Show()
  state.search:SetText("")
  -- Blizzard initializes the provider after the shared OnShow returns.
  --- Refresh after Blizzard has initialized the icon provider.
  C_Timer.After(0, function()
    if state.active and popup:IsShown() then
      state.ready = true
      refreshNativePicker(popup)
    end
  end)
end

--- Apply the profile preference to open and future native icon pickers.
function ApplyNativeIconPickerSearch()
  if not pickerHooked and IconSelectorPopupFrameTemplateMixin then
    hooksecurefunc(IconSelectorPopupFrameTemplateMixin, "OnShow", attachNativePicker)
    pickerHooked = true
  end
  for popup, state in pairs(nativePickers) do
    if not (db and db.profile.utilities.addIconPickerSearch) then
      state.search:Hide()
      state.search:ClearFocus()
      state.active = false
      state.icons = nil
      if popup:IsShown() and popup.iconDataProvider then refreshNativePicker(popup) end
    elseif popup:IsShown() and not state.active then
      attachNativePicker(popup)
    end
  end
  if db and db.profile.utilities.addIconPickerSearch then
    for _, name in ipairs({ "MacroPopupFrame", "GearManagerPopupFrame", "GuildBankPopupFrame" }) do
      local popup = _G[name]
      if popup and popup:IsShown() and not nativePickers[popup] and popup.iconDataProvider then
        attachNativePicker(popup)
        -- An already-open picker captured the original methods before the wrappers were installed.
        popup.IconSelector:SetSelectionsDataProvider(
          --- Retrieve a texture from the updated picker.
          ---@param index number Icon index.
          ---@return number|string|nil icon Texture.
          function(index) return popup:GetIconByIndex(index) end,
          --- Count the updated picker's icons.
          ---@return number count Icon count.
          function() return popup:GetNumIcons() end)
      end
    end
  end
end

--- Create a reusable native icon selector with a name field and optional extra controls.
---@param parent table Hidden parent frame.
---@param options table Labels, optional extra-control factory, and confirmation callback.
---@return table popup Icon and name selection frame.
function CreateIconNamePopupFrame(parent, options)
  local popup = CreateFrame("Frame", options.frameName or "SlackHacksIconNamePopupFrame", parent, "IconSelectorPopupFrameTemplate")
  popup.slackHacksOwnIconPicker = true
  popup:Hide()
  popup:ClearAllPoints()
  popup:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
  popup:SetFrameStrata("DIALOG")
  -- The native selector is explicitly HIGH; keep it above this dialog's border and background.
  popup.IconSelector:SetFrameStrata("DIALOG")
  popup.IconSelector:SetFrameLevel(popup.BorderBox:GetFrameLevel() + 1)
  popup.BorderBox.EditBoxHeaderText:SetText(options.nameLabel)

  local extraHeight = options.createExtraControls and 65 or 0
  if extraHeight > 0 then
    popup:SetHeight(popup:GetHeight() + extraHeight)
    popup.BorderBox.IconSelectionText:ClearAllPoints()
    popup.BorderBox.IconSelectionText:SetPoint("TOPLEFT", 24, -79 - extraHeight)
    popup.BorderBox.IconTypeDropdown:ClearAllPoints()
    popup.BorderBox.IconTypeDropdown:SetPoint("TOPRIGHT", -44, -68 - extraHeight)
    popup.BorderBox.IconDragArea:ClearAllPoints()
    popup.BorderBox.IconDragArea:SetPoint("TOPLEFT", 13, -68 - extraHeight)
    popup.IconSelector:ClearAllPoints()
    popup.IconSelector:SetPoint("TOPLEFT", 21, -97 - extraHeight)
    local region = CreateFrame("Frame", nil, popup.BorderBox)
    region:SetPoint("TOPLEFT", 24, -65)
    region:SetPoint("TOPRIGHT", -24, -65)
    region:SetHeight(extraHeight - 5)
    popup.extraControls = options.createExtraControls(region)
  end

  local search = CreateFrame("EditBox", nil, popup.BorderBox, "SearchBoxTemplate")
  search:SetSize(150, 20)
  search:SetPoint("LEFT", popup.BorderBox.IconSelectionText, "RIGHT", 12, 0)
  popup.search = search
  local icons = {}

  --- Rebuild the displayed icons from the native provider and matching extracted file icons.
  local function refreshIcons()
    if not popup.iconDataProvider then return end
    icons = buildIconList(popup.iconDataProvider, popup.iconFilter, search:GetText())
    popup.IconSelector:UpdateSelections()
    popup:ReevaluateSelectedIcon()
  end

  --- Return a visible icon by its filtered index.
  ---@param index number Filtered index.
  ---@return number|string|nil icon Icon texture.
  function popup:GetIconByIndex(index) return icons[index] end

  --- Return the filtered index of an icon.
  ---@param icon number|string Icon texture.
  ---@return number|nil index Filtered index.
  function popup:GetIndexOfIcon(icon)
    for index, value in ipairs(icons) do
      if value == icon then return index end
    end
  end

  --- Return the number of visible icons.
  ---@return number count Icon count.
  function popup:GetNumIcons() return #icons end

  --- Open the selector with optional existing name and icon values.
  ---@param name string|nil Existing name, or nil for a new entry.
  ---@param icon number|string|nil Existing icon, or nil for the default.
  function popup:Open(name, icon)
    if self:IsShown() then self:Hide() end
    self:Show()
    if name then self.BorderBox.IconSelectorEditBox:SetText(name) end
    if icon then
      self.IconSelector:SetSelectedIndex(self:GetIndexOfIcon(icon))
      self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
      self.IconSelector:ScrollToSelectedIndex()
      self:SetSelectedIconText()
    end
  end

  --- Apply Blizzard's icon-type filter before updating the text filter.
  ---@param filter number Native icon filter.
  function popup:SetIconFilterInternal(filter)
    if self.iconFilter == filter then return end
    IconSelectorPopupFrameTemplateMixin.SetIconFilterInternal(self, filter)
    refreshIcons()
  end

  --- Confirm the name, selected icon, and any caller-provided controls.
  function popup:OkayButton_OnClick()
    local name = self.BorderBox.IconSelectorEditBox:GetText():match("^%s*(.-)%s*$")
    if name == "" then
      prn("enter a name.")
      self.BorderBox.IconSelectorEditBox:SetFocus()
      return
    end
    if options.onConfirm(name, self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture(),
      self.extraControls) then
      self:Hide()
    end
  end

  search:HookScript("OnTextChanged", refreshIcons)
  popup:SetScript("OnShow", function(self)
    IconSelectorPopupFrameTemplateMixin.OnShow(self)
    self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Equipment)
    self.iconFilter = IconSelectorPopupFrameIconFilterTypes.All
    self:UpdateDropdown()
    self.IconSelector:SetSelectionsDataProvider(
      function(index) return self:GetIconByIndex(index) end,
      function() return self:GetNumIcons() end)
    self.IconSelector:SetSelectedCallback(function(_, icon)
      self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
      -- Blizzard calls this before the selector updates its selected index.
      local description = self.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription
      description:SetText(ICON_SELECTION_CLICK)
      description:SetFontObject(GameFontHighlightSmall)
    end)
    search:SetText("")
    refreshIcons()
    self.IconSelector:SetSelectedIndex(1)
    self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self:GetIconByIndex(1))
    self:SetSelectedIconText()
    self.BorderBox.IconSelectorEditBox:SetText("")
    self.BorderBox.IconSelectorEditBox:SetFocus()
  end)
  popup:SetScript("OnHide", function(self)
    IconSelectorPopupFrameTemplateMixin.OnHide(self)
    self.iconDataProvider:Release()
    self.iconDataProvider = nil
  end)
  return popup
end
