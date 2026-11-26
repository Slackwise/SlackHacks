setfenv(1, _G.SlackHacks)

--- Create a reusable native icon selector with a name field and optional extra controls.
---@param parent table Hidden parent frame.
---@param options table Labels, optional extra-control factory, and confirmation callback.
---@return table popup Icon and name selection frame.
function CreateIconNamePopupFrame(parent, options)
  local popup = CreateFrame("Frame", options.frameName or "SlackHacksIconNamePopupFrame", parent, "IconSelectorPopupFrameTemplate")
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
  local library = LibStub("LibRPMedia-1.2")
  local icons = {}

  --- Rebuild the displayed icon indices from the native provider and the library's filenames.
  local function refreshIcons()
    if not popup.iconDataProvider then return end
    local query = search:GetText():lower()
    icons = {}
    for index = 1, popup.iconDataProvider:GetNumIcons() do
      local icon = popup.iconDataProvider:GetIconByIndex(index)
      local name
      if query ~= "" then name = type(icon) == "number" and library:GetIconNameByID(icon) or icon end
      if query == "" or (type(name) == "string" and name:lower():find(query, 1, true)) then
        icons[#icons + 1] = icon
      end
    end
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
