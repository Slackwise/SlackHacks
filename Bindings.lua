setfenv(1, _G.SlackUI)

BINDING_HEADER_SLACKUI = "SlackUI"
BINDING_NAME_SLACKUI_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKUI_RELOADUI = "Reload UI"
BINDING_NAME_SLACKUI_MOUNT = "Mount"

bindingType = {
	DEFAULT_BINDINGS   = 0,
	ACCOUNT_BINDINGS   = 1,
	CHARACTER_BINDINGS = 2
}


bindingFunctions = {
	["command"] = SetBinding,
	["spell"]   = SetBindingSpell,
	["macro"]   = SetBindingMacro,
	["item"]    = SetBindingItem
}

function setBinding(binding)
	local key, type, name = unpack(binding)
	bindingFunctions[type](key, name)
end

function unbindUnwantedDefaults()
	SetBinding("SHIFT-T")
end

function setBindings()
	if not isTester() then
		print("[WIP Feature] Binding system is still in progress. Will not perform any binds, don't worry.")
		return
	end

	LoadBindings(bindingType.DEFAULT_BINDINGS)
	unbindUnwantedDefaults()

	for _, binding in ipairs(bindings.global) do
		setBinding(binding)
	end

	local class = getClassName()
	local game  = getGameType()

	if isRetail() then
		local spec = getSpecName()
		for _, binding in ipairs(bindings[game][class][spec]) do
			setBinding(binding)
		end
		SaveBindings(bindingType.CHARACTER_BINDINGS) 
		print(spec .. " " .. class .. " binding presets loaded!")
	else
		-- Respecing isn't free in Classic, so skip that sub-table
		for _, binding in ipairs(bindings[game][class]) do
			setBinding(binding)
		end
		AttemptToSaveBindings(bindingType.CHARACTER_BINDINGS)
		print(class .. " binding presets loaded!")
	end
end

bindings = {
	global = {
		{"ALT-CTRL-END",          "command",  "SLACKUI_RELOADUI"},
		{"CTRL-`",                "command",  "FOCUSTARGET"},
		{"W",                     "command",  "MOVEFORWARD"},
		{"A",                     "command",  "STRAFELEFT"},
		{"S",                     "command",  "MOVEBACKWARD"},
		{"D",                     "command",  "STRAFERIGHT"},
		{"ALT-A",                 "command",  "TURNLEFT"},
		{"ALT-D",                 "command",  "TURNRIGHT"},
		{"F1",                    "command",  "ACTIONBUTTON1"},
		{"F2",                    "command",  "ACTIONBUTTON2"},
		{"F3",                    "command",  "ACTIONBUTTON3"},
		{"F4",                    "command",  "ACTIONBUTTON4"},
		{"F5",                    "command",  "ACTIONBUTTON5"},
		{"F6",                    "command",  "ACTIONBUTTON6"},
		{"F7",                    "command",  "ACTIONBUTTON7"},
		{"F8",                    "command",  "ACTIONBUTTON8"},
		{"F9",                    "command",  "ACTIONBUTTON9"},
		{"F10",                   "command",  "ACTIONBUTTON10"},
		{"F11",                   "command",  "ACTIONBUTTON11"},
		{"F12",                   "command",  "ACTIONBUTTON12"},
		{"1",                     "command",  "NONE"},
		{"2",                     "command",  "NONE"},
		{"3",                     "command",  "NONE"},
		{"4",                     "command",  "NONE"},
		{"5",                     "command",  "NONE"},
		{"6",                     "command",  "NONE"},
		{"7",                     "command",  "NONE"},
		{"8",                     "command",  "NONE"},
		{"9",                     "command",  "NONE"},
		{"0",                     "command",  "NONE"},
		{"-",                     "command",  "NONE"},
		{"=",                     "command",  "NONE"},
		{"SHIFT-1",               "command",  "NONE"},
		{"SHIFT-2",               "command",  "NONE"},
		{"SHIFT-3",               "command",  "NONE"},
		{"SHIFT-4",               "command",  "NONE"},
		{"SHIFT-5",               "command",  "NONE"},
		{"SHIFT-6",               "command",  "NONE"},
		{"SHIFT-7",               "command",  "NONE"},
		{"SHIFT-8",               "command",  "NONE"},
		{"SHIFT-9",               "command",  "NONE"},
		{"SHIFT-0",               "command",  "NONE"},
		{"CTRL-1",                "command",  "NONE"},
		{"CTRL-2",                "command",  "NONE"},
		{"CTRL-3",                "command",  "NONE"},
		{"CTRL-4",                "command",  "NONE"},
		{"CTRL-5",                "command",  "NONE"},
		{"CTRL-6",                "command",  "NONE"},
		{"CTRL-7",                "command",  "NONE"},
		{"CTRL-8",                "command",  "NONE"},
		{"CTRL-9",                "command",  "NONE"},
		{"CTRL-0",                "command",  "NONE"},
		{",",                     "command",  "NONE"},
		{"ALT-CTRL-W",            "command",  "TOGGLEFOLLOW"},
		{"CTRL-E",                "command",  "EXTRAACTIONBUTTON1"},
		{"SHIFT-R",               "command",  "NONE"},
		{"CTRL-R",                "command",  "NONE"},
		{"CTRL-S",                "command",  "NONE"},
		{"G",                     "spell",    "Covenant Ability"},
		{"SHIFT-G",               "spell",    "Signature Ability"},
		{"CTRL-G",                "item",     "Net-O-Matic 5000"},
		{"CTRL-H",                "spell",    "Eternal Traveler's Hearthstone"},
		{"ALT-H",                 "command",  "TOGGLEUI"},
		{"CTRL-L",                "command",  "TOGGLEACTIONBARLOCK"},
		{"ALT-C",                 "command",  "TOGGLECHARACTER0"},
		{"X",                     "command",  "SITORSTAND"},
		{"SHIFT-X",               "macro",    "MountHarvester"},
		{"CTRL-X",                "macro",    "MountPassenger"},
		{"CTRL-SHIFT-X",          "macro",    "MountYak"},
		{"ALT-X",                 "command",  "TOGGLESHEATH"},
		{"ALT-CTRL-X",            "command",  "TOGGLERUN"},
		{"V",                     "command",  "NONE"},
		{"SHIFT-V",               "command",  "NONE"},
		{"CTRL-V",                "command",  "NONE"},
		{"B",                     "command",  "TOGGLEBACKPACK"},
		{"SHIFT-B",               "command",  "OPENALLBAGS"},
		{"CTRL-M",                "command",  "TOGGLEMUSIC"},
		{"ALT-M",                 "command",  "TOGGLESOUND"},
		{"ALT-CTRL-M",            "command",  "SLACKUI_RESTART_SOUND"},
		{"SHIFT-UP",              "command",  "NONE"},
		{"SHIFT-DOWN",            "command",  "NONE"},
		{"SHIFT-ENTER",           "command",  "REPLY"},
		{"CTRL-ENTER",            "command",  "REPLY2"},
		--{"SHIFT-SPACE",           "macro",    "Mount"},
		{"SHIFT-SPACE",           "command",  "SLACKUI_MOUNT"},
		{"SHIFT-HOME",            "command",  "SETVIEW1"},
		{"HOME",                  "command",  "SETVIEW2"},
		{"END",                   "command",  "SETVIEW3"},
		{"PRINTSCREEN",           "command",  "SCREENSHOT"},
		{"NUMLOCK",               "command",  "NONE"},
		{"NUMPAD0",               "command",  "RAIDTARGET8"},
		{"NUMPAD1",               "command",  "RAIDTARGET7"},
		{"NUMPAD2",               "command",  "RAIDTARGET2"},
		{"NUMPAD3",               "command",  "RAIDTARGET4"},
		{"NUMPAD4",               "command",  "RAIDTARGET6"},
		{"NUMPAD5",               "command",  "RAIDTARGET5"},
		{"NUMPAD6",               "command",  "RAIDTARGET1"},
		{"NUMPAD7",               "command",  "RAIDTARGET3"},
		{"NUMPADDECIMAL",         "command",  "RAIDTARGETNONE"},
		{"BUTTON3",               "command",  "TOGGLEAUTORUN"},
		{"SHIFT-MOUSEWHEELUP",    "command",  "NONE"},
		{"SHIFT-MOUSEWHEELDOWN",  "command",  "NONE"}
	},
	RETAIL = {
		HUNTER = {
			MARKSMANSHIP = {
				{"F8",                        "spell",     "Call Pet 1"},
				{"F9",                        "spell",     "Call Pet 2"},
				{"F10",                       "spell",     "Call Pet 3"},
				{"F11",                       "spell",     "Call Pet 4"},
				{"F12",                       "spell",     "Call Pet 5"},
				{"`",                         "macro",     "*"},
				{"1",                         "macro",     "DOT"},
				{"ALT-1",                     "spell",     "MD"},
				{"CTRL-1",                    "macro",     "Hunter's Mark"},
				{"3",                         "spell",     "Multi-Shot"},
				{"SHIFT-3",                   "spell",     "Barrage"},
				{"CTRL-3",                    "spell",     "Volley"},
				{"4",                         "spell",     "Arcane Shot"},
				{"SHIFT-4",                   "spell",     "Aimed Shot"},
				{"CTRL-4",                    "spell",     "Double Tap"},
				{"5",                         "spell",     "Kill Shot"},
				{"SHIFT-5",                   "spell",     "Sniper Shot"},
				{"CTRL-5",                    "spell",     "Tranquilizing Shot"},
				{"Q",                         "macro",     "PetControl"},
				{"CTRL-Q",                    "macro",     "PetSpecial"},
				{"CTRL-SHIFT-Q",              "macro",     "PetMove"},
				{"ALT-CTRL-Q",                "macro",     "PetToggle"},
				{"ALT-SHIFT-Q",               "spell",     "Play Dead"},
				{"ALT-CTRL-SHIFT-Q",          "spell",     "Eyes of the Beast"},
				{"E",                         "spell",     "Bursting Shot"},
				{"ALT-CTRL-E",                "macro",     "ChainEagle"},
				{"R",                         "spell",     "Steady Shot"},
				{"SHIFT-R",                   "spell",     "Rapid Fire"},
				{"CTRL-R",                    "macro",     "Trueshot!"},
				{"T",                         "macro",     "Traps"},
				{"ALT-CTRL-S",                "spell",     "Survey"},
				{"F",                         "spell",     "Wing Clip"}, --Auto-maps to "Concussive Shot" in MM spec
				{"SHIFT-F",                   "spell",     "Scatter Shot"},
				{"CTRL-F",                    "spell",     "Counter Shot"},
				{"ALT-CTRL-F",                "spell",     "Scare Beast"},
				{"Z",                         "spell",     "Camouflage"},
				{"SHIFT-Z",                   "spell",     "Aspect of the Chameleon"},
				{"CTRL-Z",                    "spell",     "Feign Death"},
				{"ALT-Z",                     "macro",     "Shadowmeld"},
				{"C",                         "spell",     "Aspect of the Cheetah"},
				{"SHIFT-C",                   "macro",     "Call"},
				{"CTRL-C",                    "spell",     "Gladiator's Medallion"},
				{"SHIFT-CTRL-C",              "item",      "Potion of the Psychopomp's Speed"},
				{"ALT-C",                     "macro",     "CallFocus"},
				{"V",                         "macro",     "Vitality"},
				{"SHIFT-V",                   "macro",     "Survive"},
				{"CTRL-V",                    "spell",     "Aspect of the Turtle"},
				{"ALT-V",                     "macro",     "SurviveFocus"},
				{"ALT-CTRL-V",                "item",      "Shrouded Cloth Bandage"},
				{"B",                         "spell",     "Fetch"},
				{"CTRL-SPACE",                "spell",     "Disengage"},
				{"BUTTON4",                   "macro",     "MouseTraps"},
				{"BUTTON5",                   "macro",     "MousePetAttack"},
			}
		}
	},
	CLASSIC = {
		HUNTER = {
			{"1",                         "macro",     "Attack"},
			{"2",                         "spell",     "Kill Command"},
			{"3",                         "spell",     "Multi-Shot"},
			{"4",                         "spell",     "Arcane Shot"},
			{"5",                         "spell",     "Hunter's Mark"},
			{"SHIFT-5",                   "spell",     "Tranquilizing Shot"},
			{"Q",                         "macro",     "PetControl"},
			{"CTRL-Q",                    "macro",     "PetSpecial"},
			{"CTRL-SHIFT-Q",              "spell",     "Mend Pet"},
			{"ALT-CTRL-Q",                "spell",     "Revive Pet"},
			{"E",                         "spell",     "Wing Clip"},
			{"SHIFT-E",                   "macro",     "Melee"},
			{"R",                         "macro",     "R"},
			{"SHIFT-T",                   "spell",     "Frost Trap"},
			{"CTRL-T",                    "spell",     "Freezing Trap"},
			{"ALT-T",                     "spell",     "Immolation Trap"},
			{"SHIFT-ALT-T",               "spell",     "Explosive Trap"},
			{"ALT-CTRL-T",                "spell",     "Explosive Trap"},
			{"ALT-CTRL-A",                "macro",     "Burst!"},
			{"ALT-CTRL-S",                "spell",     "Survey"},
			{"F",                         "spell",     "Concussive Shot"},
			{"SHIFT-F",                   "spell",     "Serpent Sting"},
			{"CTRL-F",                    "spell",     "Wyvern Sting"},
			{"ALT-F",                     "spell",     "Distracting Shot"},
			{"ALT-CTRL-F",                "spell",     "Scare Beast"},
			{"G",                         "macro",     "Call"},
			{"Z",                         "spell",     "Disengage"},
			{"CTRL-Z",                    "spell",     "Feign Death"},
			{"ALT-Z",                     "macro",     "Peace"},
			{"CTRL-X",                    "item",      "Linen Bandage"},
			{"BUTTON4",                   "macro",     "Mouse"},
			{"ALT-BUTTON4",               "macro",     "MouseAlt"}
		}
	}
}

