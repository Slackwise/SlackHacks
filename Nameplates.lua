setfenv(1, _G.SlackHacks)

nameplateCastLiftBase = 30
nameplateCastLift = 30
lastNameplateLevel = 0

-- unitTarget -> frame level to (re)apply; the engine re-sorts nameplate levels every frame, so
-- a ticker must keep reasserting the level for as long as the unit is casting.
local activeCasters = {}
local castLiftTicker = nil
local castLiftTickerInterval = 0.1

local function stopCastLiftTicker()
	if castLiftTicker then
		castLiftTicker:Cancel()
		castLiftTicker = nil
	end
end

local function isEnemyUnit(unitTarget)
	if type(unitTarget) ~= "string" then
		return false
	end

	-- Turns out that the target frame is special and you can't mess with it? Throws if you try.
	if unitTarget ~= "target" and unitTarget:lower():match("target$") then
		return false
	end

	-- bossN/raidN/partyN/raidpetN/partypetN unit tokens aren't valid for GetNamePlateForUnit and throw if used.
	if unitTarget:lower():match("^boss%d+$") or unitTarget:lower():match("^raid%d+$")
		or unitTarget:lower():match("^party%d+$") or unitTarget:lower():match("^raidpet%d+$")
		or unitTarget:lower():match("^partypet%d+$") then
		return false
	end

	return UnitCanAttack("player", unitTarget)
end

local function getSafeNameplateFrame(nameplate)
	if not nameplate then
		return nil
	end

	if nameplate.UnitFrame and not nameplate.UnitFrame:IsForbidden() then
		return nameplate.UnitFrame
	end

	if not nameplate:IsForbidden() then
		return nameplate
	end

	return nil
end

local function applyCasterLevels()
	for unitTarget, level in pairs(activeCasters) do
		local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
		local targetFrame = getSafeNameplateFrame(nameplate)
		if targetFrame then
			local success, errorMessage = pcall(function()
				targetFrame:SetFrameLevel(level)
			end)
			if not success then
				log("unit=" .. tostring(unitTarget) .. " failed to set frame level: " .. tostring(errorMessage))
			end
		else
			if nameplate and nameplate:IsForbidden() then
				log("unit=" .. tostring(unitTarget) .. " nameplate is protected; skipping frame-level change")
			end
			-- Nameplate went away (unit died/left range) without a cast-stop event; stop tracking it.
			activeCasters[unitTarget] = nil
		end
	end

	if next(activeCasters) == nil then
		stopCastLiftTicker()
	end
end

local function startCastLiftTicker()
	if not castLiftTicker then
		castLiftTicker = C_Timer.NewTicker(castLiftTickerInterval, applyCasterLevels)
	end
end

local function syncNameplateCastLiftBase(frameLevel)
	if type(frameLevel) ~= "number" then
		return
	end

	if frameLevel > nameplateCastLiftBase then
		nameplateCastLiftBase = frameLevel
		nameplateCastLift = frameLevel
	end
end

function resetNameplateCastLift()
	nameplateCastLift = nameplateCastLiftBase
	lastNameplateLevel = 0
	activeCasters = {}
	stopCastLiftTicker()
end

function raiseCastingNameplate(unitTarget)
	if not isEnemyUnit(unitTarget) then
		return
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
	local targetFrame = getSafeNameplateFrame(nameplate)
	if targetFrame then
		local currentLevel = targetFrame:GetFrameLevel()
		syncNameplateCastLiftBase(currentLevel)
		if lastNameplateLevel == 0 then
			-- Starting off, we want to bump the first caster by a big amount so they're at the top:
			lastNameplateLevel = currentLevel + nameplateCastLift
		else
			-- But for every other, we 'll just take the last nameplate's level, and bump THAT so the newest is always highest:
			lastNameplateLevel = lastNameplateLevel + 1
		end

		log("unit=" .. tostring(unitTarget) .. " level=" .. tostring(lastNameplateLevel) .. " base=" .. tostring(nameplateCastLiftBase))
		activeCasters[unitTarget] = lastNameplateLevel
		startCastLiftTicker()
		applyCasterLevels()
	else
		if nameplate and nameplate:IsForbidden() then
			log("unit=" .. tostring(unitTarget) .. " nameplate is protected; skipping raise")
		else
			log("unit=" .. tostring(unitTarget) .. " no nameplate")
		end
	end
end

function lowerCastingNameplate(unitTarget)
	if activeCasters[unitTarget] then
		activeCasters[unitTarget] = nil
		if next(activeCasters) == nil then
			stopCastLiftTicker()
		end
	end
end

function handleNameplateAdded(addonSelf, eventName, unitTarget)
	if not db.profile.combat.raiseCastingNameplates or next(activeCasters) == nil then
		return
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
	local targetFrame = getSafeNameplateFrame(nameplate)
	if not targetFrame then
		return
	end

	local currentLevel = targetFrame:GetFrameLevel()
	syncNameplateCastLiftBase(currentLevel)
	if currentLevel >= lastNameplateLevel then
		local levelIncrease = currentLevel - lastNameplateLevel + 1
		for casterUnit, level in pairs(activeCasters) do
			activeCasters[casterUnit] = level + levelIncrease
		end
		lastNameplateLevel = lastNameplateLevel + levelIncrease
	end

	applyCasterLevels()
end

function handleCasts(addonSelf, eventName, unitTarget)
	if not db.profile.combat.raiseCastingNameplates then
		return
	end

	if not isEnemyUnit(unitTarget) then
		return
	end

	raiseCastingNameplate(unitTarget)
end

function handleCastStops(addonSelf, eventName, unitTarget)
	lowerCastingNameplate(unitTarget)
end

