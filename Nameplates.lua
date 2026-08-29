setfenv(1, _G.SlackHacks)

nameplateCastLiftBase = 30
nameplateCastLift = 30
lastNameplateLevel = 0

local function isEnemyUnit(unitTarget)
	if type(unitTarget) ~= "string" then
		return false
	end

	if unitTarget ~= "target" and unitTarget:lower():match("target$") then
		return false
	end

	return UnitCanAttack("player", unitTarget)
end

function resetNameplateCastLift()
	nameplateCastLift = nameplateCastLiftBase
	lastNameplateLevel = 0
end

function raiseCastingNameplate(unitTarget)
	if not isEnemyUnit(unitTarget) then
		return
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
	if nameplate then
		local currentLevel = nameplate:GetFrameLevel()
		if lastNameplateLevel == 0 then
			lastNameplateLevel = currentLevel + nameplateCastLift
		else
			lastNameplateLevel = lastNameplateLevel + 1
		end

		log("unit=" .. tostring(unitTarget) .. " level=" .. tostring(lastNameplateLevel))
		nameplate:SetFrameLevel(lastNameplateLevel)
	else
		log("unit=" .. tostring(unitTarget) .. " no nameplate")
	end
end

function handleCasts(addonSelf, eventName, unitTarget)
	if not isEnemyUnit(unitTarget) then
		return
	end

	raiseCastingNameplate(unitTarget)
end

