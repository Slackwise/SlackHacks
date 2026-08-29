setfenv(1, _G.SlackHacks)

local function isInterruptibleEnemyCast(unitTarget)
	if not unitTarget or not UnitCanAttack("player", unitTarget) then
		return false
	end

	local castName, castText, castTexture, castStartTime, castEndTime, isTradeSkill, castID, notInterruptibleCast, castSpellID = UnitCastingInfo(unitTarget)
	if notInterruptibleCast ~= nil then
		return not notInterruptibleCast
	end

	local channelName, channelText, channelTexture, channelStartTime, channelEndTime, channelIsTradeSkill, channelCastID, notInterruptableChannel, channelSpellID = UnitChannelInfo(unitTarget)
	if notInterruptableChannel ~= nil then
		return not notInterruptableChannel
	end

	return false
end

function raiseCastingNameplate(unitTarget)
	if not isInterruptibleEnemyCast(unitTarget) then
		return
	end

	log("Interruptible enemy cast detected: " .. tostring(unitTarget))
	local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
	if nameplate then
		nameplate:SetFrameLevel(9999)
		log("Popped nameplate!")
	else
		log("No nameplate found for unit: " .. tostring(unitTarget))
	end
end

function handleInterruptibleCast(eventName, unitTarget)
	if isInterruptibleEnemyCast(unitTarget) then
		raiseCastingNameplate(unitTarget)
	end
end

