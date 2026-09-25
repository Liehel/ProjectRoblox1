local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

print("firmament siege server started.")

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes")
local remotes = ArcadeRemotes:WaitForChild("FirmamentSiege")

local StartReq = remotes:WaitForChild("StartFirmamentSiegeRequest")
local SubmitMove = remotes:WaitForChild("SubmitMove")
local GameState = remotes:WaitForChild("GameState")
local ToggleAudio = remotes:WaitForChild("ToggleAudio")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FirmamentSiegeModule = require(Modules:WaitForChild("FirmamentSiegeModule"))
local UniversalLeaderboardModule = require(Modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("FirmamentSiegeSettings_v1")
local PurchaseHistoryStore = SafeStore.Get("FirmamentSiege_PurchaseHistory_v1")

local sessions = {}
local playerAudioSettings = {}
local playerRateLimits = {}

local DONATION_PRODUCTS = {
	[3478073654] = "Firmament's Tip (5)",
	[3478073816] = "Firmament's Treat (15)",
	[3478073972] = "Firmament's Sub (50)",
	[3478077889] = "Firmament's Sponsor (100)",
	[3478078031] = "Firmament's Whale (500)",
	[3478078163] = "Firmament's Legend (1000)",
}

-- reads score and elapsed time from whichever fields the module exposes
local function getFinalScoreAndTime(gameSession)
	local score = 0
	if gameSession and typeof(gameSession.score) == "number" then
		score = gameSession.score
	end

	local timeMs = 0
	if gameSession then
		if gameSession.getTimeMs then
			local ok, t = pcall(function() return gameSession:getTimeMs() end)
			if ok and typeof(t) == "number" then timeMs = t end
		elseif gameSession.getState then
			local ok, st = pcall(function() return gameSession:getState() end)
			if ok and type(st) == "table" and typeof(st.timeMs) == "number" then
				timeMs = st.timeMs
			end
		end
	end

	return score, timeMs
end

-- sends the current game state to the client
local function sendState(plr)
	local gameSession = sessions[plr]
	if not gameSession then return end
	local ok, st = pcall(function() return gameSession:getState() end)
	if ok and st then
		pcall(function()
			GameState:FireClient(plr, "Update", st)
		end)
	end
end

-- reports score to the leaderboard and fires the end event to the client
local function endSession(plr, gameSession, win)
	local score, timeMs = getFinalScoreAndTime(gameSession)

	local timeInSeconds = timeMs / 1000
	local maxPossibleScore = math.floor((timeInSeconds * 600) + 1500)

	if score > maxPossibleScore or score < 0 then
		score = 0
	end

	pcall(function()
		UniversalLeaderboardModule:ReportScore("FirmamentSiege", plr, score, timeMs)
	end)

	AnalyticsModule.ReportSessionAsync(plr, "FirmamentSiege", score, timeInSeconds)

	pcall(function()
		GameState:FireClient(plr, "End", { score = score, timeMs = timeMs, win = win == true })
	end)

	sessions[plr] = nil
end

-- loads audio preference; staggered to avoid flooding the datastore queue on join
Players.PlayerAdded:Connect(function(plr)
	task.spawn(function()
		task.wait(1)
		local key = tostring(plr.UserId) .. "_Audio"

		local success, saved = pcall(function()
			return SettingsStore:GetAsync(key)
		end)

		local isEnabled = true
		if success and saved ~= nil then
			isEnabled = saved
		end

		playerAudioSettings[plr.UserId] = isEnabled

		task.wait(1)
		if plr and plr.Parent then
			pcall(function()
				ToggleAudio:FireClient(plr, isEnabled)
			end)
		end
	end)
end)

ToggleAudio.OnServerEvent:Connect(function(plr, isEnabled)
	if typeof(isEnabled) ~= "boolean" then return end
	playerAudioSettings[plr.UserId] = isEnabled
end)

StartReq.OnServerEvent:Connect(function(plr)
	local gameSession = FirmamentSiegeModule.new()
	sessions[plr] = gameSession
	playerRateLimits[plr] = { count = 0, lastTick = os.clock() }

	local isEnabled = playerAudioSettings[plr.UserId]
	if isEnabled == nil then isEnabled = true end
	pcall(function()
		ToggleAudio:FireClient(plr, isEnabled)
	end)

	local ok, st = pcall(function() return gameSession:getState() end)
	if ok and st then
		pcall(function()
			GameState:FireClient(plr, "Start", st)
		end)
	else
		pcall(function()
			GameState:FireClient(plr, "Start", { score = 0, timeMs = 0, win = false })
		end)
	end
end)

SubmitMove.OnServerEvent:Connect(function(plr, input)
	local gameSession = sessions[plr]
	if not gameSession then return end

	local rLimit = playerRateLimits[plr]
	if rLimit then
		local now = os.clock()
		if now - rLimit.lastTick > 1 then
			rLimit.count = 0
			rLimit.lastTick = now
		end
		rLimit.count += 1
		if rLimit.count > 45 then return end
	end

	local function doRotate(dir)
		if gameSession.setRotate then gameSession:setRotate(dir)
		elseif gameSession.rotate then gameSession:rotate(dir) end
	end

	local function doThrust(on)
		if gameSession.setThrust then gameSession:setThrust(on)
		elseif gameSession.thrust then gameSession:thrust(on) end
	end

	local function doFire()
		if gameSession.fire then gameSession:fire()
		elseif gameSession.shoot then gameSession:shoot() end
	end

	local function doHyperspace()
		if gameSession.hyperspace then gameSession:hyperspace()
		elseif gameSession.jump then gameSession:jump() end
	end

	local function doAim(deg)
		if type(deg) == "number" then
			if deg ~= deg or deg == math.huge or deg == -math.huge then return end
			if gameSession.setAimAngle then gameSession:setAimAngle(deg) end
		end
	end

	local function doMoveAxes(ax, ay)
		if gameSession.setMoveAxes then gameSession:setMoveAxes(ax, ay) end
	end

	local function doMoveDir(dir)
		local ax, ay = 0, 0
		if dir == "Up" then ay = -1
		elseif dir == "Down" then ay = 1
		elseif dir == "Left" then ax = -1
		elseif dir == "Right" then ax = 1
		elseif dir == "Stop" then ax, ay = 0, 0 end
		if gameSession.setMoveDir then pcall(function() gameSession:setMoveDir(dir) end) end
		doMoveAxes(ax, ay)
	end

	if typeof(input) == "string" then
		if input == "MoveUp" then doMoveDir("Up")
		elseif input == "MoveDown" then doMoveDir("Down")
		elseif input == "MoveLeft" then doMoveDir("Left")
		elseif input == "MoveRight" then doMoveDir("Right")
		elseif input == "MoveStop" then doMoveDir("Stop")
		elseif input == "Fire" or input == "Shoot" then doFire()
		elseif input == "Hyperspace" then doHyperspace()
		elseif input == "RotateLeft" or input == "Left" then doRotate("Left")
		elseif input == "RotateRight" or input == "Right" then doRotate("Right")
		elseif input == "RotateStop" or input == "Stop" then doRotate("Stop")
		elseif input == "ThrustOn" then doThrust(true)
		elseif input == "ThrustOff" then doThrust(false)
		elseif input == "Exit" then endSession(plr, gameSession, false) end
	elseif typeof(input) == "table" then
		local action = input.action
		if action == "Move" then
			if input.dir then doMoveDir(input.dir)
			else doMoveAxes(tonumber(input.ax) or 0, tonumber(input.ay) or 0) end
		elseif action == "MoveAxes" or action == "MoveVec" then
			doMoveAxes(tonumber(input.ax) or 0, tonumber(input.ay) or 0)
		elseif action == "Aim" then
			doAim(input.angleDeg)
		elseif action == "Fire" or action == "Shoot" then
			doFire()
		elseif action == "Hyperspace" then
			doHyperspace()
		elseif action == "Rotate" then
			local dir = input.dir
			if dir == -1 then dir = "Left" end
			if dir == 1 then dir = "Right" end
			if dir == 0 then dir = "Stop" end
			if dir == "Left" or dir == "Right" or dir == "Stop" then doRotate(dir) end
		elseif action == "Thrust" then
			doThrust(input.on == true)
		elseif action == "Exit" then
			endSession(plr, gameSession, false)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for plr, gameSession in pairs(sessions) do
		if not plr or not plr.Parent then
			sessions[plr] = nil
		else
			pcall(function()
				gameSession:update(dt)
			end)

			if gameSession.win == true then
				endSession(plr, gameSession, true)
			elseif gameSession.alive == false or (gameSession.lives and gameSession.lives <= 0) or gameSession.gameOver == true then
				endSession(plr, gameSession, false)
			else
				sendState(plr)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	sessions[plr] = nil
	playerRateLimits[plr] = nil

	local audioSetting = playerAudioSettings[plr.UserId]
	if audioSetting ~= nil then
		pcall(function()
			SettingsStore:SetAsync(tostring(plr.UserId) .. "_Audio", audioSetting)
		end)
	end
	playerAudioSettings[plr.UserId] = nil
end)

-- validates purchases with deduplication via purchase history store
local function _disabledProcessReceipt(receiptInfo)  -- centralized in DonationHandler
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	local player = Players:GetPlayerByUserId(playerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local purchaseKey = "Purchase_" .. purchaseId
	local checkSuccess, isPurchased = pcall(function()
		return PurchaseHistoryStore:GetAsync(purchaseKey)
	end)

	if not checkSuccess then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif isPurchased then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productName = DONATION_PRODUCTS[productId]
	if productName then
		print("donation approved: " .. player.Name .. " supported with " .. productName)
	else
		warn("unknown product id: " .. tostring(productId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local setSuccess, errorMessage = pcall(function()
		PurchaseHistoryStore:SetAsync(purchaseKey, true)
	end)

	if not setSuccess then
		warn("could not save receipt for " .. player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	AnalyticsModule.ReportDonationAsync("FirmamentSiege", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("firmament siege server ready.")
