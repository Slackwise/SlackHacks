-- Run with Lua 5.1 from the addon root: lua tests/bindings_inline_macro.lua

SlackHacks = setmetatable({}, { __index = _G })
local macros, bindings, profile = {}, {}, nil

--- Find a mocked macro by name.
---@param name string Macro name.
---@return number index
function GetMacroIndexByName(name)
  for index, macro in pairs(macros) do
    if macro.name == name then return index end
  end
  return 0
end

--- Create a mocked macro in the requested list.
---@param name string Macro name.
---@param icon string|number Icon.
---@param body string Macro body.
---@param perCharacter boolean Character-specific flag.
---@return number index
function CreateMacro(name, icon, body, perCharacter)
  local index = perCharacter and 121 or 1
  while macros[index] do index = index + 1 end
  macros[index] = { name = name, icon = icon, body = body }
  return index
end

--- Return a mocked macro's saved fields.
---@param index number Macro index.
---@return string, string|number, string
function GetMacroInfo(index)
  local macro = macros[index]
  return macro.name, macro.icon, macro.body
end

--- Update a mocked macro.
---@param index number Macro index.
---@param name string Macro name.
---@param icon string|number Icon.
---@param body string Macro body.
function EditMacro(index, name, icon, body)
  macros[index] = { name = name, icon = icon, body = body }
end

--- Record a normal macro binding.
---@param key string Binding key.
---@param name string Macro name.
function SetBindingMacro(key, name) bindings[key] = name end

--- Split the unmodified button key used by this test.
---@param separator string Separator.
---@param text string Text to split.
---@return string
function strsplit(separator, text)
  assert(separator == "-" and not text:find("-", 1, true))
  return text
end

C_ClickBindings = {
  --- Return an empty default click-cast profile.
  ---@return table
  GetProfileInfo = function() return {} end,
  --- Record the resulting click-cast profile.
  ---@param bindings table Click-cast bindings.
  SetProfileByInfo = function(bindings) profile = bindings end,
}

assert(loadfile("Bindings.lua"))()
local addon = SlackHacks
local short = { "SHORT", "/say short" }
addon.setBinding({ "A", short }, false)
assert(macros[1].name == "SHORT" and macros[1].icon == "inv_misc_questionmark")
assert(macros[1].body == "/say short" and bindings.A == "SHORT")
assert(short[2] == "/say short" and #short == 2)

addon.setBinding({ "A", { "SHORT", "/say updated" } }, false)
assert(macros[1].icon == "inv_misc_questionmark" and macros[1].body == "/say updated")

addon.setBinding({ "B", { "EXPLICIT", 12345, "/say explicit" } }, true)
assert(macros[121].icon == 12345 and macros[121].body == "/say explicit")
assert(bindings.B == "EXPLICIT")

addon.setBinding({ "BUTTON1", { "CLICK", "/say click" }, addon.BT.CLICKCAST }, true)
addon.applyClickCastBindings()
assert(macros[122].icon == "inv_misc_questionmark" and macros[122].body == "/say click")
assert(#profile == 1 and profile[1].actionID == 122 and profile[1].button == "LeftButton")

print("Inline macro binding tests passed.")
