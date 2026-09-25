local TurrisCaseiModule = {}

-- gameplay tuning values
TurrisCaseiModule.Settings = {
	BlockHeight = 1.5,
	Speed = 25,
	Tolerance = 1.8,
	ScrollThreshold = 6,
	MaxSize = 7,
	Colors = {
		Normal = Color3.fromHex("facc15"),
		Good = Color3.fromHex("3b82f6"),
		Bad = Color3.fromHex("ef4444")
	}
}

-- returns the horizontal offset of a swinging block at the given time
function TurrisCaseiModule.GetBlockOffset(time, speed, limit)
	return math.sin(time * (speed / 10)) * limit
end

-- returns the speed unchanged (speed is kept constant)
function TurrisCaseiModule.GetNextSpeed(currentSpeed)
	return currentSpeed
end

-- randomly picks the next block type with weighted probabilities
function TurrisCaseiModule.PickNextBlockData()
	local rng = math.random(1, 1000)

	if rng <= 100 then
		return { Type = "Bad", Value = -1, SizeMod = -0.5, Color = TurrisCaseiModule.Settings.Colors.Bad }
	elseif rng > 100 and rng <= 225 then
		return { Type = "Good", Value = 1, SizeMod = 1, Color = TurrisCaseiModule.Settings.Colors.Good }
	elseif rng > 225 and rng <= 260 then
		local bonusRoll = math.random(1, 100)
		local val = 2
		if bonusRoll > 95 then val = 5 elseif bonusRoll > 80 then val = 4 elseif bonusRoll > 50 then val = 3 end
		return { Type = "Good", Value = val, SizeMod = val, Color = TurrisCaseiModule.Settings.Colors.Good }
	else
		return { Type = "Normal", Value = 0, SizeMod = 0, Color = TurrisCaseiModule.Settings.Colors.Normal }
	end
end

-- computes the overlap between the dropped block and the stack below; returns new size, offset, and falling debris data
function TurrisCaseiModule.CalculateStack(prevSize, prevCFrame, currentCFrame, activeBlockData)
	local prevPos = prevCFrame.Position
	local currPos = currentCFrame.Position

	local diffX = currPos.X - prevPos.X
	local diffZ = currPos.Z - prevPos.Z

	local isXAxis = math.abs(diffX) > math.abs(diffZ)
	if isXAxis then diffZ = 0 else diffX = 0 end

	local rawSizeX = prevSize.X - math.abs(diffX)
	local rawSizeZ = prevSize.Z - math.abs(diffZ)
	local newSizeY = TurrisCaseiModule.Settings.BlockHeight

	if rawSizeX <= 0 or rawSizeZ <= 0 then
		return false, nil, nil, nil, 0, nil
	end

	local isPerfect = false
	if math.abs(diffX) <= TurrisCaseiModule.Settings.Tolerance and isXAxis then
		diffX = 0; rawSizeX = prevSize.X; isPerfect = true
	elseif math.abs(diffZ) <= TurrisCaseiModule.Settings.Tolerance and not isXAxis then
		diffZ = 0; rawSizeZ = prevSize.Z; isPerfect = true
	end

	local sizeMod = 0; local scoreBonus = 0;
	local nextColor = TurrisCaseiModule.Settings.Colors.Normal
	if activeBlockData then
		sizeMod = activeBlockData.SizeMod or 0
		scoreBonus = activeBlockData.Value or 0
		nextColor = activeBlockData.Color or nextColor
	end

	local finalSizeX = rawSizeX
	local finalSizeZ = rawSizeZ

	if sizeMod ~= 0 then
		finalSizeX = finalSizeX + sizeMod
		finalSizeZ = finalSizeZ + sizeMod
	end

	local maxSize = TurrisCaseiModule.Settings.MaxSize
	if finalSizeX > maxSize then finalSizeX = maxSize end
	if finalSizeZ > maxSize then finalSizeZ = maxSize end

	if finalSizeX <= 0 or finalSizeZ <= 0 then
		return false, nil, nil, nil, scoreBonus, nextColor
	end

	local newSize = Vector3.new(finalSizeX, newSizeY, finalSizeZ)
	local correctionX = diffX / 2
	local correctionZ = diffZ / 2
	local offset = Vector3.new(correctionX, 0, correctionZ)

	local fallingPartData = nil
	if not isPerfect then
		fallingPartData = { diffX = diffX, diffZ = diffZ }
	end

	return true, newSize, offset, fallingPartData, scoreBonus, nextColor
end

return TurrisCaseiModule
