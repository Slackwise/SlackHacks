setfenv(1, _G.SlackHacks)

nameplateCastLiftBase = 30
nameplateCastLift = 30
lastNameplateLevel = 0

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
		if nameplate.IsProtected and nameplate:IsProtected() then
			log("unit=" .. tostring(unitTarget) .. " protected nameplate")
			return
		end

		local currentLevel = nameplate:GetFrameLevel()
		if lastNameplateLevel == 0 then
			-- Starting off, we want to bump the first caster by a big amount so they're at the top:
			lastNameplateLevel = currentLevel + nameplateCastLift
		else
			-- But for every other, we 'll just take the last nameplate's level, and bump THAT so the newest is always highest:
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

