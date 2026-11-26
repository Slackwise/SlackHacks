-- Run with Lua 5.1 from the addon root.
SlackHacks = setmetatable({}, { __index = _G })
UIParent = {}
ICON_SELECTION_CLICK = "Selected"
GameFontHighlightSmall = {}
IconSelectorPopupFrameIconFilterTypes = { All = 1, Spell = 2 }
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

local names = { [100] = "inv_sword_01", [200] = "ability_fire" }
--- Supply the icon filename library.
---@return table library Icon name lookup.
function LibStub()
  return { GetIconNameByID = function(_, id) return names[id] end }
end
--- Supply the native provider with file IDs and an older string icon.
---@return table provider Icon provider.
function CreateAndInitFromMixin()
  local provider = { icons = { 100, 200, "INTERFACE\\ICONS\\INV_AXE" } }
  function provider:GetNumIcons() return #self.icons end
  function provider:GetIconByIndex(index) return self.icons[index] end
  function provider:SetIconTypes(filter)
    self.icons = filter == 2 and { 200 } or { 100, 200, "INTERFACE\\ICONS\\INV_AXE" }
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
assert(popup:GetNumIcons() == 3)
popup.search:SetText("SWorD")
assert(popup:GetNumIcons() == 1 and popup:GetIconByIndex(1) == 100)
popup.search:SetText("axe")
assert(popup:GetNumIcons() == 1 and popup:GetIconByIndex(1) == "INTERFACE\\ICONS\\INV_AXE")
popup.search:SetText("not found")
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
print("Icon name popup tests passed")
