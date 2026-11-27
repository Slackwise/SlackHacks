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
  setmetatable(frame, { __index = function(_, key)
    if key ~= "slackHacksOwnIconPicker" and key ~= "iconDataProvider" and key ~= "reason" and key ~= "hidden" then
      return noop
    end
  end })
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:HookScript(name, callback) self.hooks[name] = callback end
  function frame:SetText(text) self.text = text; if self.hooks.OnTextChanged then self.hooks.OnTextChanged(self) end end
  function frame:GetText() return self.text end
  function frame:GetHeight() return self.height end
  function frame:GetFrameLevel() return 50 end
  function frame:SetHeight(height) self.height = height end
  function frame:SetShown(shown) self.hidden = not shown end
  function frame:EnableMouse(enabled) self.mouseEnabled = enabled end
  function frame:Hide()
    self.hidden = true
    if self.scripts.OnHide then self.scripts.OnHide(self) end
    if self.hooks.OnHide then self.hooks.OnHide(self) end
  end
  function frame:Show() self.hidden = false; if self.scripts.OnShow then self.scripts.OnShow(self) end end
  function frame:IsShown() return not self.hidden end
  return frame
end

IconSelectorPopupFrameTemplateMixin = {}
--- Return a native icon by index.
---@param index number Icon index.
---@return number|string|nil icon Native texture.
function IconSelectorPopupFrameTemplateMixin:GetIconByIndex(index) return self.iconDataProvider:GetIconByIndex(index) end
--- Return the native index of a texture.
---@param icon number|string Texture.
---@return number|nil index Native index.
function IconSelectorPopupFrameTemplateMixin:GetIndexOfIcon(icon)
  for index = 1, self.iconDataProvider:GetNumIcons() do
    if self.iconDataProvider:GetIconByIndex(index) == icon then return index end
  end
end
--- Return the native provider's icon count.
---@return number count Native icon count.
function IconSelectorPopupFrameTemplateMixin:GetNumIcons() return self.iconDataProvider:GetNumIcons() end
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
local frames = {}
function CreateFrame(_, name, parent, template)
  local frame = widget()
  frames[#frames + 1] = { frame = frame, parent = parent, template = template }
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

local names = {
  [100] = "inv_sword_01", [200] = "ability_fire", [300] = "inv_axe",
  [626003] = "classicon_paladin",
}
local libraryIcons = {
  { file = 100, name = names[100] },
  { file = 200, name = names[200] },
  { file = 300, name = names[300] },
  { file = 626003, name = names[626003] },
  { name = "classicon_paladin_atlas" },
}
--- Supply the icon filename library.
---@return table library Icon name lookup.
function LibStub()
  return {
    db = {},
    GetIconNameByID = function(_, id) return names[id] end,
    GetIconInfoByName = function(_, name)
      for _, info in ipairs(libraryIcons) do
        if info.name == name then return info end
      end
    end,
    FindIcons = function(_, query)
      local index = 0
      return function()
        repeat
          index = index + 1
          local info = libraryIcons[index]
          if not info or info.name:find(query, 1, true) then return info end
        until false
      end
    end,
  }
end
local loadCount, loadFailure, onLoad = 0, nil, nil
C_AddOns = {
  LoadAddOn = function()
    loadCount = loadCount + 1
    if onLoad then onLoad() end
    if loadFailure then return false, loadFailure end
    return true
  end,
}
local tooltip = {}
GameTooltip = {
  SetOwner = function() end,
  SetText = function(_, text) tooltip.title = text end,
  AddLine = function(_, text) tooltip[#tooltip + 1] = text end,
  Show = function() tooltip.shown = true end,
  Hide = function() tooltip.shown = false end,
}
local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
--- Wrap a mock method with a post-hook.
---@param target table Hooked object.
---@param name string Method name.
---@param callback function Hook.
function hooksecurefunc(target, name, callback)
  local original = target[name]
  target[name] = function(...)
    local result = original(...)
    callback(...)
    return result
  end
end
--- Execute queued zero-delay callbacks.
local function runTimers()
  local pending = timers
  timers = {}
  for _, callback in ipairs(pending) do callback() end
end
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
assert(popup:GetNumIcons() == 4 and popup:GetIconByIndex(4) == 626003)
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
assert(loadCount > 0)

-- A failed companion load leaves Blizzard's icons usable and explains the disabled search.
loadFailure = "DISABLED"
popup:Show()
assert(not popup.search.mouseEnabled and popup:GetNumIcons() == 3)
local ownBlocker
for _, entry in ipairs(frames) do
  if entry.parent == popup.BorderBox and entry.frame.reason == "DISABLED" then ownBlocker = entry.frame end
end
assert(ownBlocker and not ownBlocker.hidden)
ownBlocker.scripts.OnEnter(ownBlocker)
assert(tooltip.shown and tooltip.title == "Icon Search Unavailable"
  and tooltip[1]:find("Enable SlackHacks: Media Metadata", 1, true))
popup:Hide()
loadFailure = nil
popup:Show()
assert(popup.search.mouseEnabled and popup:GetNumIcons() == 4 and ownBlocker.hidden)
popup:Hide()

-- Native pickers are discovered through the shared mixin and follow the profile toggle.
SlackHacks.db = { profile = { utilities = { addIconPickerSearch = false } } }
SlackHacks.ApplyNativeIconPickerSearch()
local native = CreateFrame("Frame", nil, UIParent, "IconSelectorPopupFrameTemplate")
MacroPopupFrame = native
local beforeNativeShow = loadCount
IconSelectorPopupFrameTemplateMixin.OnShow(native)
assert(loadCount == beforeNativeShow and #timers == 0)
SlackHacks.db.profile.utilities.addIconPickerSearch = true
native.iconDataProvider = CreateAndInitFromMixin()
native.iconFilter = 1
onLoad = function() SlackHacks.ApplyNativeIconPickerSearch() end
SlackHacks.ApplyNativeIconPickerSearch()
onLoad = nil
runTimers()
local nativeCount, nativeIndex = native:GetNumIcons(), native:GetIndexOfIcon(626003)
assert(nativeCount == 4 and nativeIndex == 4,
  "native count/index: " .. tostring(nativeCount) .. "/" .. tostring(nativeIndex))
local nativeSearch
for _, entry in ipairs(frames) do
  if entry.parent == native.BorderBox and entry.template == "SearchBoxTemplate" then nativeSearch = entry.frame end
end
assert(nativeSearch and nativeSearch.mouseEnabled)
nativeSearch:SetText("classicon_paladin")
assert(native:GetNumIcons() == 1 and native:GetIconByIndex(1) == 626003)
assert(native.IconSelector.count() == 1 and native.IconSelector.get(1) == 626003)
local previousLoadCount = loadCount
SlackHacks.ApplyNativeIconPickerSearch()
assert(nativeSearch:GetText() == "classicon_paladin" and loadCount == previousLoadCount)
native:SetIconFilterInternal(2)
assert(native:GetNumIcons() == 0)
native:SetIconFilterInternal(1)
assert(native:GetNumIcons() == 1)
SlackHacks.db.profile.utilities.addIconPickerSearch = false
SlackHacks.ApplyNativeIconPickerSearch()
assert(nativeSearch.hidden and native:GetNumIcons() == 3)
SlackHacks.db.profile.utilities.addIconPickerSearch = true
SlackHacks.ApplyNativeIconPickerSearch()
runTimers()
assert(not nativeSearch.hidden and native:GetNumIcons() == 4)
native:Hide()
loadFailure = "MISSING"
IconSelectorPopupFrameTemplateMixin.OnShow(native)
native.hidden = false
native.iconDataProvider = CreateAndInitFromMixin()
native.iconFilter = 1
runTimers()
assert(not nativeSearch.mouseEnabled and native:GetNumIcons() == 3)
local nativeBlocker
for _, entry in ipairs(frames) do
  if entry.parent == native.BorderBox and entry.frame.reason == "MISSING" then nativeBlocker = entry.frame end
end
assert(nativeBlocker and not nativeBlocker.hidden)
loadFailure = nil
print("Icon name popup tests passed")
