setfenv(1, _G.SlackHacks)

--- Initial lift above the current nameplate level used for the first active caster.
nameplateCastLiftBase = 30
--- Current first-caster lift; resetNameplateCastLift() restores it from nameplateCastLiftBase.
nameplateCastLift = 30
--- Highest level assigned to a caster in the current tracking period.
lastNameplateLevel = 0

-- Unit token -> desired frame level. Blizzard re-sorts nameplate levels every frame, so these levels
-- must be reapplied while a unit is casting rather than treated as a one-time adjustment.
local activeCasters = {}
local castLiftTicker = nil
local castLiftTickerInterval = 0.2

--- Cancel the level-reapplication ticker if one is running.
---@return nil
local function stopCastLiftTicker()
	if castLiftTicker then
		castLiftTicker:Cancel()
		castLiftTicker = nil
	end
end

--- Whether a unit token identifies an attackable enemy that can have a nameplate.
--- Some otherwise valid unit tokens are unsuitable for C_NamePlate.GetNamePlateForUnit and can throw.
---@param unitTarget any - Unit token supplied by a unit spellcast event.
---@return boolean isEnemy - True when the token is safe to query and attackable by the player.
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

--- Return a usable frame for a nameplate, preferring its unit frame when available.
--- Forbidden frames cannot be inspected or changed by addon code, so return nil for those.
---@param nameplate Frame? - Nameplate returned by the C_NamePlate API, if any.
---@return Frame? frame - The usable unit frame or nameplate, or nil when unavailable/forbidden.
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

--- Keep tracked casters above every non-casting nameplate and discard missing plates.
--- The game continually re-sorts nameplate levels; shifting all tracked levels together when a
--- non-caster catches up preserves their relative order and keeps the newest caster on top.
---@return nil
local function reconcileCasterLevels()
	if next(activeCasters) == nil then
		stopCastLiftTicker()
		return
	end

	local casterFrames = {}
	local lowestCasterLevel
	for unitTarget, level in pairs(activeCasters) do
		local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
		local targetFrame = getSafeNameplateFrame(nameplate)
		if targetFrame then
			casterFrames[targetFrame] = true
			if not lowestCasterLevel or level < lowestCasterLevel then
				lowestCasterLevel = level
			end
		else
			activeCasters[unitTarget] = nil
		end
	end

	if not lowestCasterLevel then
		stopCastLiftTicker()
		return
	end

	local highestOtherLevel = nil
	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
		local targetFrame = getSafeNameplateFrame(nameplate)
		if targetFrame and not casterFrames[targetFrame] then
			local frameLevel = targetFrame:GetFrameLevel()
			if not highestOtherLevel or frameLevel > highestOtherLevel then
				highestOtherLevel = frameLevel
			end
		end
	end

	if highestOtherLevel and highestOtherLevel >= lowestCasterLevel then
		local levelIncrease = highestOtherLevel - lowestCasterLevel + 1
		for unitTarget, level in pairs(activeCasters) do
			activeCasters[unitTarget] = level + levelIncrease
		end
		lastNameplateLevel = lastNameplateLevel + levelIncrease
	end
end

--- Reconcile desired levels, then apply them to the currently available caster frames.
--- SetFrameLevel is protected by pcall because frame availability/protection can change between
--- lookup and mutation; a single rejected update should not break event handling or the ticker.
---@return nil
local function applyCasterLevels()
	reconcileCasterLevels()

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

--- Start the periodic reapplication ticker once, avoiding duplicate tickers.
---@return nil
local function startCastLiftTicker()
	if not castLiftTicker then
		castLiftTicker = C_Timer.NewTicker(castLiftTickerInterval, applyCasterLevels)
	end
end

--- Clear casting state and restore the baseline for the next tracking period.
--- Called when the feature is disabled and after combat, so stale event state cannot leak forward.
---@return nil
function resetNameplateCastLift()
	nameplateCastLift = nameplateCastLiftBase
	lastNameplateLevel = 0
	activeCasters = {}
	stopCastLiftTicker()
end

--- Assign a high frame level to an enemy's nameplate while it is casting.
--- The first caster gets a large lift over its current level; later casters get consecutive levels,
--- making the most recently observed caster the topmost one without unnecessarily lifting all plates.
---@param unitTarget string - Unit token for the casting unit.
---@return nil
function raiseCastingNameplate(unitTarget)
	if not isEnemyUnit(unitTarget) then
		return
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
	local targetFrame = getSafeNameplateFrame(nameplate)
	if targetFrame then
		local currentLevel = targetFrame:GetFrameLevel()
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

--- Stop tracking a caster after its cast ends, fails, or is interrupted.
---@param unitTarget string - Unit token for the unit whose cast ended.
---@return nil
function stopTrackingCastingNameplate(unitTarget)
	if activeCasters[unitTarget] then
		activeCasters[unitTarget] = nil
		if next(activeCasters) == nil then
			stopCastLiftTicker()
		end
	end
end

--- Handle a nameplate becoming available while one or more casters are being tracked.
--- Cast events can arrive before a unit's plate exists; this event lets the next level application
--- include it without starting another ticker or changing state when the feature is disabled.
---@param addonSelf table - Addon instance supplied by AceEvent.
---@param eventName string - Name of the nameplate event.
---@param unitTarget string - Unit token whose nameplate was added.
---@return nil
function handleNameplateAdded(addonSelf, eventName, unitTarget)
	if not db.profile.combat.raiseCastingNameplates or next(activeCasters) == nil then
		return
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
	local targetFrame = getSafeNameplateFrame(nameplate)
	if not targetFrame then
		return
	end

	applyCasterLevels()
end

--- Handle a cast-start/update event and raise the enemy caster's nameplate.
--- The shared event handler filters non-enemies because the registered spellcast events include
--- friendly units as well as hostile ones.
---@param addonSelf table - Addon instance supplied by AceEvent.
---@param eventName string - Spellcast event name.
---@param unitTarget string - Unit token that started or updated a cast.
---@return nil
function handleCasts(addonSelf, eventName, unitTarget)
	if not db.profile.combat.raiseCastingNameplates then
		return
	end

	if not isEnemyUnit(unitTarget) then
		return
	end

	raiseCastingNameplate(unitTarget)
end

--- Handle cast-stop events by removing the unit from the active caster set.
---@param addonSelf table - Addon instance supplied by AceEvent.
---@param eventName string - Spellcast stop/failure/interruption event name.
---@param unitTarget string - Unit token whose cast stopped.
---@return nil
function handleCastStops(addonSelf, eventName, unitTarget)
	stopTrackingCastingNameplate(unitTarget)
end

