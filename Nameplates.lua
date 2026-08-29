setfenv(1, _G.SlackHacks)

local function isEnemyUnit(unitTarget)
	if type(unitTarget) ~= "string" then
		return false
	end

	return UnitCanAttack("player", unitTarget)
end

function raiseCastingNameplate(unitTarget)
	if not isEnemyUnit(unitTarget) then
		return
	end

	log("Enemy cast detected: " .. tostring(unitTarget))
	local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
	if nameplate then
		local currentLevel = nameplate:GetFrameLevel()
		nameplate:SetFrameLevel(currentLevel + 30)
		log("Raised nameplate by 30 levels")
	else
		log("No nameplate found for unit: " .. tostring(unitTarget))
	end
end

function handleCasts(addonSelf, eventName, unitTarget)
	if not isEnemyUnit(unitTarget) then
		return
	end

	raiseCastingNameplate(unitTarget)
end

