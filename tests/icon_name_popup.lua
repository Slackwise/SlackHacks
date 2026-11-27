-- Run with Lua 5.1 from the addon root.
SlackHacks = setmetatable({}, { __index = _G })
UIParent = {}
ICON_SELECTION_CLICK = "Selected"
GameFontHighlightSmall = {}
IconSelectorPopupFrameIconFilterTypes = { All = 1, Spell = 2, Item = 3 }
IconDataProviderExtraType = { Equipment = 1 }
IconDataProviderMixin = {}

--- Construct a minimal frame for the native selector.
---@return table frame Mock frame.
local function widget()
  local frame = { scripts = {}, hooks = {}, text = "", height = 495 }
  local function noop() end
  setmetatable(frame, { __index = function() return noop end })
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:HookScript(name, callback) self.hooks[name] = callback end
  function frame:SetText(text) self.text = text; if self.hooks.OnTextChanged then self.hooks.OnTextChanged(self) end end
  function frame:GetText() return self.text end
  function frame:GetHeight() return self.height end
  function frame:GetFrameLevel() return 50 end
  function frame:SetHeight(height) self.height = height end
  function frame:Hide() self.hidden = true; if self.scripts.OnHide then self.scripts.OnHide(self) end end
  function frame:Show() self.hidden = false; if self.scripts.OnShow then self.scripts.OnShow(self) end end
  function frame:IsShown() return not self.hidden end
  return frame
end

IconSelectorPopupFrameTemplateMixin = {}
--- Initialize the mock native popup.
---@param self table Popup.
function IconSelectorPopupFrameTemplateMixin.OnShow(self) self.nativeShown = true end
--- Close the mock native popup.
---@param self table Popup.
function IconSelectorPopupFrameTemplateMixin.OnHide(self) self.nativeShown = false end
--- Apply the mock icon-type filter.
---@param self table Popup.
---@param filter number Filter.
function IconSelectorPopupFrameTemplateMixin.SetIconFilterInternal(self, filter)
  self.iconFilter = filter
  self.iconDataProvider:SetIconTypes(filter)
  self.IconSelector:UpdateSelections()
end

--- Create the selector template or its child controls.
---@param _ string Frame type.
---@param name string|nil Frame name.
---@param parent table|nil Parent.
---@param template string|nil Template name.
---@return table frame Mock frame.
function CreateFrame(_, name, parent, template)
  local frame = widget()
  if template == "IconSelectorPopupFrameTemplate" then
    for key, value in pairs(IconSelectorPopupFrameTemplateMixin) do frame[key] = value end
    frame.BorderBox = widget()
    local border = frame.BorderBox
    border.EditBoxHeaderText = widget()
    border.IconSelectionText = widget()
    border.IconTypeDropdown = widget()
    border.IconDragArea = widget()
    border.IconSelectorEditBox = widget()
    border.SelectedIconArea = widget()
    local selected = border.SelectedIconArea
    selected.SelectedIconButton = widget()
    function selected.SelectedIconButton:SetIconTexture(icon) self.icon = icon end
    function selected.SelectedIconButton:GetIconTexture() return self.icon end
    selected.SelectedIconText = widget()
    selected.SelectedIconText.SelectedIconDescription = widget()
    frame.IconSelector = widget()
    function frame.IconSelector:SetSelectionsDataProvider(get, count) self.get = get; self.count = count end
    function frame.IconSelector:SetSelectedCallback(callback) self.callback = callback end
    function frame.IconSelector:SetSelectedIndex(index) self.index = index end
    function frame:ReevaluateSelectedIcon() self.IconSelector.index = self:GetIndexOfIcon(selected.SelectedIconButton.icon) end
  end
  return frame
end

WOW_PROJECT_MAINLINE, WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = 1, 2, 1
C_UIFileAsset = {}
--- Check whether the mock client can display an icon file.
---@param id number File ID.
---@return boolean known Whether the file is available.
function C_UIFileAsset.IsKnownFile(id) return id ~= 700 end
SlackHacks.IconNames = { data = [[
100|3|inv_sword_01
200|3|ability_fire
300|3|inv_axe
400|2|forever_only
500|1|retail_only
600|4|mists_only
601|8|tbc_only
602|16|vanilla_only
700|3|unavailable_icon
626003|3|classicon_paladin
]] }
--- Supply the native provider with file IDs and an older string icon.
---@return table provider Icon provider.
function CreateAndInitFromMixin()
  local provider = { icons = { 100, 200, "INTERFACE\\ICONS\\INV_AXE" } }
  function provider:GetNumIcons() return #self.icons end
  function provider:GetIconByIndex(index) return self.icons[index] end
  function provider:SetIconTypes(filter)
    if filter == 2 then
      self.icons = { 200 }
    elseif filter == 3 then
      self.icons = { 100, "INTERFACE\\ICONS\\INV_AXE" }
    else
      self.icons = { 100, 200, "INTERFACE\\ICONS\\INV_AXE" }
    end
  end
  function provider:Release() self.released = true end
  return provider
end

assert(loadfile("IconNamePopup.lua"))()
local confirmed
local popup = SlackHacks.CreateIconNamePopupFrame(UIParent, {
  nameLabel = "Nickname:",
  createExtraControls = function() return { marker = true } end,
  onConfirm = function(name, icon, extra)
    confirmed = { name, icon, extra }
    return true
  end,
})
assert(popup.BorderBox.EditBoxHeaderText:GetText() == "Nickname:" and popup:GetHeight() == 560)
popup:Show()
assert(popup:GetNumIcons() == 5 and popup:GetIconByIndex(5) == 626003)
popup.search:SetText("SWorD")
assert(popup:GetNumIcons() == 1 and popup:GetIconByIndex(1) == 100)
popup.search:SetText("axe")
assert(popup:GetNumIcons() == 1 and popup:GetIconByIndex(1) == "INTERFACE\\ICONS\\INV_AXE")
popup.search:SetText("CLASSICON_Paladin")
assert(popup:GetNumIcons() == 1 and popup:GetIconByIndex(1) == 626003)
popup.IconSelector.callback(1, popup:GetIconByIndex(1))
assert(popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() == 626003)
popup.BorderBox.IconSelectorEditBox:SetText("Paladin")
popup:OkayButton_OnClick()
assert(confirmed[1] == "Paladin" and confirmed[2] == 626003 and popup.hidden)
popup:Show()
popup.search:SetText("classicon_paladin")
popup:SetIconFilterInternal(2)
assert(popup:GetNumIcons() == 0)
popup:SetIconFilterInternal(3)
assert(popup:GetNumIcons() == 0)
popup:SetIconFilterInternal(1)
assert(popup:GetNumIcons() == 1 and popup:GetIndexOfIcon(626003) == 1)
popup.search:SetText("not found")
assert(popup:GetNumIcons() == 0)
popup.search:SetText("forever_only")
assert(popup:GetNumIcons() == 0)
popup.search:SetText("unavailable")
assert(popup:GetNumIcons() == 0)
popup.search:SetText("")
popup:SetIconFilterInternal(2)
assert(popup:GetNumIcons() == 1 and popup:GetIconByIndex(1) == 200)
popup.IconSelector.callback(1, 200)
popup.BorderBox.IconSelectorEditBox:SetText("  Alt  ")
local provider = popup.iconDataProvider
popup:OkayButton_OnClick()
assert(confirmed[1] == "Alt" and confirmed[2] == 200 and confirmed[3].marker)
assert(provider.released and popup.hidden)
popup:Open("Existing", 626003)
assert(popup.BorderBox.IconSelectorEditBox:GetText() == "Existing")
assert(popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() == 626003
  and popup.IconSelector.index == popup:GetIndexOfIcon(626003))
local previousProvider = popup.iconDataProvider
popup:Open("Missing icon", 999999)
assert(previousProvider.released and rawget(popup.IconSelector, "index") == nil
  and popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() == 999999)
popup:OkayButton_OnClick()
assert(confirmed[1] == "Missing icon" and confirmed[2] == 999999)
popup:Open()
assert(popup.BorderBox.IconSelectorEditBox:GetText() == ""
  and popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() == 100)
popup:Hide()
WOW_PROJECT_ID = WOW_PROJECT_CAMELOT
local foreverPopup = SlackHacks.CreateIconNamePopupFrame(UIParent, {
  nameLabel = "Name:",
  --- Accept the mock selection.
  ---@return boolean accepted Whether the popup should close.
  onConfirm = function() return true end,
})
foreverPopup:Show()
foreverPopup.search:SetText("forever_only")
assert(foreverPopup:GetNumIcons() == 1 and foreverPopup:GetIconByIndex(1) == 400)
foreverPopup.search:SetText("retail_only")
assert(foreverPopup:GetNumIcons() == 0)
foreverPopup:Hide()
WOW_PROJECT_ID = 3
local interface = 50504
--- Supply a mock client build.
---@return string, string, string, number version, build, date, interface Client build details.
function GetBuildInfo() return "", "", "", interface end
for _, client in ipairs({ { 50504, "mists_only", 600 }, { 20506, "tbc_only", 601 }, { 11509, "vanilla_only", 602 } }) do
  interface = client[1]
  local classicPopup = SlackHacks.CreateIconNamePopupFrame(UIParent, {
    nameLabel = "Name:",
    --- Accept the mock selection.
    ---@return boolean accepted Whether the popup should close.
    onConfirm = function() return true end,
  })
  classicPopup:Show()
  classicPopup.search:SetText(client[2])
  assert(classicPopup:GetNumIcons() == 1 and classicPopup:GetIconByIndex(1) == client[3])
  classicPopup:Hide()
end
assert(loadfile("IconNames.lua"))()
WOW_PROJECT_ID = WOW_PROJECT_MAINLINE
local extractedPopup = SlackHacks.CreateIconNamePopupFrame(UIParent, {
  nameLabel = "Name:",
  --- Accept the mock selection.
  ---@return boolean accepted Whether the popup should close.
  onConfirm = function() return true end,
})
extractedPopup:Show()
extractedPopup.search:SetText("classicon_paladin")
assert(extractedPopup:GetIndexOfIcon(626003))
extractedPopup:Hide()
print("Icon name popup tests passed")
