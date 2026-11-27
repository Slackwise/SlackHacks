setfenv(1, _G.SlackHacks)

local MEDIA_ADDON = "SlackHacks_MediaMetadata"
local pickerHooked = false
local nativePickers = setmetatable({}, { __mode = "k" })

--- Load the optional media catalog when an icon picker needs it.
---@return table|nil library Icon metadata library, if available.
---@return string|nil reason Load failure, if any.
local function loadIconLibrary()
  local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
  if not load then return nil, "The addon loading API is unavailable." end
  local loaded, reason = load(MEDIA_ADDON)
  if not loaded then return nil, tostring(reason or "Unknown loading error") end
  local library = LibStub("LibRPMedia-1.2", true)
  if not library or not library.db then return nil, "The media metadata library did not initialize." end
  return library
end

--- Build a filtered icon list, keeping Blizzard's Spell and Item filters intact.
---@param provider table Native icon provider.
---@param filter number Native icon filter.
---@param query string Search text.
---@param library table|nil Icon metadata, when available.
---@return table icons Matching texture IDs or paths.
local function buildIconList(provider, filter, query, library)
  local icons, seen = {}, {}
  query = query:lower()
  local includeLibrary = library and filter == IconSelectorPopupFrameIconFilterTypes.All
  for index = 1, provider:GetNumIcons() do
    local icon = provider:GetIconByIndex(index)
    local name
    if query ~= "" then name = type(icon) == "number" and library:GetIconNameByID(icon) or icon end
    if query == "" or (type(name) == "string" and name:lower():find(query, 1, true)) then
      icons[#icons + 1] = icon
      if includeLibrary then
        if type(icon) == "number" then
          seen[icon] = true
        elseif type(icon) == "string" then
          local basename = icon:match("([^\\/:]+)$")
          local info = basename and library:GetIconInfoByName(basename:lower():gsub("%.blp$", ""))
          if info and info.file then seen[info.file] = true end
        end
      end
    end
  end
  -- Extra file icons do not have Blizzard's Spell/Item classifications.
  if includeLibrary then
    for info in library:FindIcons(query, { reuseTable = {} }) do
      if info.file and not seen[info.file] then
        icons[#icons + 1] = info.file
        seen[info.file] = true
      end
    end
  end
  return icons
end

--- Add a search field and a mouse target for its disabled-state explanation.
---@param popup table Icon selector popup.
---@return table search Search edit box.
---@return table blocker Disabled-state tooltip target.
local function createIconSearch(popup)
  local search = CreateFrame("EditBox", nil, popup.BorderBox, "SearchBoxTemplate")
  search:SetSize(150, 20)
  search:SetPoint("LEFT", popup.BorderBox.IconSelectionText, "RIGHT", 12, 0)
  search:SetAutoFocus(false)
  local blocker = CreateFrame("Frame", nil, popup.BorderBox)
  blocker:SetAllPoints(search)
  blocker:SetFrameLevel(search:GetFrameLevel() + 1)
  blocker:EnableMouse(true)
  blocker:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Icon Search Unavailable")
    GameTooltip:AddLine("Enable SlackHacks: Media Metadata to search icons by name. Reload the UI if necessary.", 1, 1, 1, true)
    if self.reason then GameTooltip:AddLine("Reason: " .. self.reason, 1, 0.4, 0.4, true) end
    GameTooltip:Show()
  end)
  blocker:SetScript("OnLeave", function() GameTooltip:Hide() end)
  blocker:Hide()
  return search, blocker
end

--- Set the search field's availability without disabling normal icon selection.
---@param search table Search edit box.
---@param blocker table Tooltip target.
---@param library table|nil Loaded metadata library.
---@param reason string|nil Loading error.
local function setSearchAvailability(search, blocker, library, reason)
  search:EnableMouse(library ~= nil)
  search:SetTextColor(library and 1 or 0.5, library and 1 or 0.5, library and 1 or 0.5)
  search:SetAlpha(library and 1 or 0.5)
  blocker.reason = reason
  blocker:SetShown(library == nil)
end

--- Refresh a hooked native picker's filtered data after its provider exists.
---@param popup table Blizzard icon picker.
local function refreshNativePicker(popup)
  local state = nativePickers[popup]
  if not state or not popup.iconDataProvider then return end
  if not (db and db.profile.utilities.addIconPickerSearch) then
    state.icons = nil
  else
    state.icons = buildIconList(popup.iconDataProvider, popup.iconFilter,
      state.library and state.search:GetText() or "", state.library)
  end
  popup.IconSelector:UpdateSelections()
  popup:ReevaluateSelectedIcon()
end

--- Prepare a native picker after Blizzard calls the shared OnShow implementation.
---@param popup table Blizzard icon picker.
local function attachNativePicker(popup)
  if popup.slackHacksOwnIconPicker or not (db and db.profile.utilities.addIconPickerSearch) then return end
  local state = nativePickers[popup]
  if state and state.loading then return end
  if not state then
    local search, blocker = createIconSearch(popup)
    state = { search = search, blocker = blocker }
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
    search:HookScript("OnTextChanged", function() refreshNativePicker(popup) end)
    hooksecurefunc(popup, "SetIconFilterInternal", function() refreshNativePicker(popup) end)
    popup:HookScript("OnHide", function()
      state.active = false
      state.icons = nil
      search:ClearFocus()
    end)
  end
  state.icons = nil
  state.active = true
  state.loading = true
  state.library, state.reason = loadIconLibrary()
  state.loading = false
  state.search:Show()
  setSearchAvailability(state.search, state.blocker, state.library, state.reason)
  state.search:SetText("")
  -- The shared OnShow runs before Macro/Equipment creates its icon provider.
  C_Timer.After(0, function()
    if popup:IsShown() then refreshNativePicker(popup) end
  end)
end

--- Enable or disable search injection for currently open and future native pickers.
function ApplyNativeIconPickerSearch()
  if not pickerHooked and IconSelectorPopupFrameTemplateMixin then
    hooksecurefunc(IconSelectorPopupFrameTemplateMixin, "OnShow", attachNativePicker)
    pickerHooked = true
  end
  for popup, state in pairs(nativePickers) do
    if not (db and db.profile.utilities.addIconPickerSearch) then
      state.search:Hide()
      state.blocker:Hide()
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
        -- An already-open picker captured its original methods before we installed the wrappers.
        popup.IconSelector:SetSelectionsDataProvider(
          function(index) return popup:GetIconByIndex(index) end,
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

  local search, blocker = createIconSearch(popup)
  popup.search = search
  local library
  local icons = {}

  --- Rebuild the displayed icons from the native provider and matching library file icons.
  local function refreshIcons()
    if not popup.iconDataProvider then return end
    icons = buildIconList(popup.iconDataProvider, popup.iconFilter, library and search:GetText() or "", library)
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
    local reason
    library, reason = loadIconLibrary()
    setSearchAvailability(search, blocker, library, reason)
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
