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
	local spec = getSpecName()

	if spec ~= "" then
		for _, binding in ipairs(bindings[class][spec]) do
			setBinding(binding)
		end
	end
	SaveBindings(bindingType.CHARACTER_BINDINGS)
	print(spec .. " " .. class .. " binding presets loaded!")
end

bindings = {
	global = {
		{"ALT-CTRL-END",          "command",  "SLACKUI_RELOADUI"},
		{"CTRL-`",                "command",  "FOCUSTARGET"},
		{"ALT-`",                 "command",  "INTERACTTARGET"},
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
		{"CTRL-G",                "item",     "Net-O-Matic 5000"},
		{"CTRL-H",                "macro",    "HEARTH"},
		{"ALT-H",                 "command",  "TOGGLEUI"},
		{"CTRL-L",                "command",  "TOGGLEACTIONBARLOCK"},
		{"CTRL-B",                "command",  "TOGGLECHARACTER0"},
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
	HUNTER = {
		MARKSMANSHIP = {
			{ "F8",               "spell",   "Call Pet 1" },
			{ "F9",               "spell",   "Call Pet 2" },
			{ "F10",              "spell",   "Call Pet 3" },
			{ "F11",              "spell",   "Call Pet 4" },
			{ "F12",              "spell",   "Call Pet 5" },
			{ "`",                "macro",   "*" },
			{ "1",                "macro",   "Serpent Sting" },
			{ "2",                "spell",   "Volley" },
			{ "SHIFT-2",          "spell",   "Wild Spirits" },
			{ "ALT-1",            "macro",   "MD" },
			{ "CTRL-1",           "spell",   "Hunter's Mark" },
			{ "3",                "spell",   "Multi-Shot" },
			{ "SHIFT-3",          "spell",   "Barrage" },
			{ "4",                "spell",   "Arcane Shot" },
			{ "SHIFT-4",          "spell",   "Aimed Shot" },
			{ "CTRL-4",           "spell",   "Double Tap" },
			{ "5",                "spell",   "Kill Shot" },
			{ "SHIFT-5",          "spell",   "Sniper Shot" },
			{ "Q",                "macro",   "PetControl" },
			{ "CTRL-Q",           "command", "BONUSACTIONBUTTON7" },        -- Pet Family Ability
			{ "CTRL-SHIFT-Q",     "command", "BONUSACTIONBUTTON1" },        -- Pet Family Ability
			{ "ALT-CTRL-Q",       "macro",   "PetToggle" },
			{ "ALT-SHIFT-Q",      "spell",   "Play Dead" },
			{ "ALT-CTRL-SHIFT-Q", "spell",   "Eyes of the Beast" },
			{ "E",                "spell",   "Bursting Shot" },
			{ "ALT-CTRL-E",       "macro",   "ChainEagle" },
			{ "R",                "spell",   "Steady Shot" },
			{ "SHIFT-R",          "spell",   "Rapid Fire" },
			{ "CTRL-R",           "macro",   "Trueshot!" },
			{ "ALT-R",            "item",    "Potion of Phantom Fire" },
			{ "T",                "macro",   "Traps" },
			{ "ALT-CTRL-S",       "spell",   "Survey" },
			{ "F",                "spell",   "Wing Clip" },        --Auto-maps to "Concussive Shot" in MM spec
			{ "SHIFT-F",          "spell",   "Scatter Shot" },
			{ "CTRL-F",           "spell",   "Counter Shot" },
			{ "ALT-F",            "spell",   "Tranquilizing Shot" },
			{ "ALT-CTRL-F",       "spell",   "Scare Beast" },
			{ "ALT-CTRL-SHIFT-F", "spell",   "Fireworks" },
			{ "G",                "spell",   "Wild Spirits" },
			{ "Z",                "spell",   "Camouflage" },
			{ "SHIFT-Z",          "spell",   "Aspect of the Chameleon" },
			{ "CTRL-Z",           "spell",   "Feign Death" },
			{ "CTRL-SHIFT-Z",     "macro",   "Shadowmeld" },
			{ "ALT-Z",            "item",    "Potion of the Hidden Spirit" },
			{ "C",                "spell",   "Soulshape" },
			{ "SHIFT-C",          "spell",   "Aspect of the Cheetah" },
			{ "CTRL-C",           "macro",   "Call" },
			{ "CTRL-SHIFT-C",     "item",    "Gladiator's Medallion" },
			{ "ALT-C",            "item",    "Potion of the Psychopomp's Speed" },
			{ "ALT-CTRL-C",       "macro",   "CallFocus" },
			{ "V",                "spell",   "Exhilaration" },
			{ "SHIFT-V",          "spell",   "Survival of the Fittest" },
			{ "CTRL-V",           "spell",   "Aspect of the Turtle" },
			{ "CTRL-SHIFT-V",     "item",    "Heavy Shrouded Cloth Bandage" },
			{ "ALT-V",            "macro",   "Vitality" },
			{ "ALT-CTRL-V",       "macro",   "SurviveFocus" },
			{ "B",                "spell",   "Fetch" },
			{ "CTRL-SPACE",       "spell",   "Disengage" },
			{ "BUTTON4",          "macro",   "MouseTraps" },
			{ "BUTTON5",          "macro",   "MousePetAttack" },
		}
	},
	PALADIN = {
		HOLY = {
			{ "1",  "command", "ACTIONBUTTON1" },
			{ "2",  "command", "ACTIONBUTTON2" },
			{ "3",  "command", "ACTIONBUTTON3" },
			{ "4",  "command", "ACTIONBUTTON4" },
			{ "5",  "command", "ACTIONBUTTON5" },
			{ "6",  "command", "ACTIONBUTTON6" },
			{ "7",  "command", "ACTIONBUTTON7" },
			{ "8",  "command", "ACTIONBUTTON8" },
			{ "9",  "command", "ACTIONBUTTON9" },
			{ "10", "command", "ACTIONBUTTON10" },
			{ "11", "command", "ACTIONBUTTON11" },
			{ "12", "command", "ACTIONBUTTON12" },
		}
	}
}
