local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local SafeStore = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DataStoreSafe"))
local AudioDataStore = SafeStore.Get("JuiceCutter_AudioSettings_v1")
local PurchaseHistoryStore = SafeStore.Get("JuiceCutter_PurchaseHistory_v1")
local playerAudioSettings = {}

local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes")
local folder = arc:WaitForChild("JuiceCutter")
local modules = ReplicatedStorage:WaitForChild("Modules")

local StartJuiceCutterRequest = folder:WaitForChild("StartJuiceCutterRequest")
local SubmitMove = folder:WaitForChild("SubmitMove")
local GameState = folder:WaitForChild("GameState")
local ToggleAudio = folder:WaitForChild("ToggleAudio")

local JuiceCutterModule = require(modules:WaitForChild("JuiceCutterModule"))
local UniversalLeaderboardModule = require(modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(modules:WaitForChild("AnalyticsModule"))

local MAX_LEVEL = 5
local sessions = {}

local playerCuts = {}

local DONATION_PRODUCTS = {
	[3485520379] = "Juice Tip",
	[3485520618] = "Juice Treat",
	[3485520810] = "Juice Sub",
	[3485521145] = "Juice Sponsor",
	[3485521376] = "Juice Whale",
	[3485521765] = "Juice Legend",
}

-- disconnects the heartbeat loop for a player without clearing the session
local function stopLoopFor(player)
	local s = sessions[player]
	if not s then return end
	if s.loop then
		s.loop:Disconnect()
		s.loop = nil
	end
end

-- stops the loop and removes the session entry
local function destroySession(player)
	stopLoopFor(player)
	sessions[player] = nil
end

-- fires GameState safely, ignoring errors if the client is gone
local function fireSafe(player, mode, payload)
	if player then
		pcall(function()
			GameState:FireClient(player, mode, payload or {})
		end)
	end
end

-- reports the final score to the universal leaderboard
local function reportLeaderboard(player, finalScore, durationMs)
	pcall(function()
		UniversalLeaderboardModule:ReportScore("JuiceCutter", player, finalScore, durationMs)
	end)
end

-- reads score from whichever field the module exposes
local function computeScoreFromState(state)
	if typeof(state.score) == "number" then
		return state.score
	elseif typeof(state.juice) == "number" then
		return state.juice
	end
	return 0
end

-- creates a new game instance at the given level, optionally carrying over score and lives
local function newGameAtLevel(level, carryScore, carryLives)
	local g = JuiceCutterModule.new(level, carryLives)
	if carryScore and type(carryScore) == "number" then
		if typeof(g.score) == "number" then
			g.score = carryScore
		end
	end
	return g
end

-- runs the per-frame update loop, fires state to the client, and ends the session on game over
local function startLoop(player)
	local s = sessions[player]
	if not s or not s.game then return end

	stopLoopFor(player)

	s.sessionStart = s.sessionStart or os.clock()
	s.levelStartTime = os.clock()
	s.levelTimes = s.levelTimes or {}
	s.lastTick = os.clock()

	s.loop = RunService.Heartbeat:Connect(function()
		if not sessions[player] or not player or not player.Parent then
			stopLoopFor(player)
			return
		end

		if s.waitingNextLevel then return end

		local now = os.clock()
		local dt = math.clamp(now - (s.lastTick or now), 1/240, 1/15)
		s.lastTick = now

		local game = s.game
		local alive = true

		if game.step then
			alive = game:step(dt)
		end

		local state = (game.getState and game:getState()) or {}
		state.level = state.level or game.levelIndex or 1

		s.totalScore = computeScoreFromState(state)
		s.currentLives = state.lives

		fireSafe(player, "Update", state)

		if alive == false then
			local currentLevel = tonumber(state.level) or 1
			local isPerfect = (state.perfect == true)

			if isPerfect and currentLevel < MAX_LEVEL then
				-- record per-level time before pausing the loop
				s.levelTimes[currentLevel] = os.clock() - (s.levelStartTime or os.clock())

				s.waitingNextLevel = true
				stopLoopFor(player)

				local payload = state
				payload.score = s.totalScore
				payload.perfect = true
				payload.reason = "level_complete"
				payload.nextLevel = currentLevel + 1

				fireSafe(player, "LevelComplete", payload)
				return
			end

			-- record time for the final level played
			s.levelTimes[currentLevel] = os.clock() - (s.levelStartTime or os.clock())

			local endTime = os.clock()
			local startTime = s.sessionStart or endTime
			local durationMs = math.floor((endTime - startTime) * 1000)
			local finalScore = s.totalScore or 0

			reportLeaderboard(player, finalScore, durationMs)

			AnalyticsModule.ReportSessionAsync(player, "JuiceCutter", finalScore, endTime - startTime, {
				levelReached = currentLevel,
				levelTimes   = s.levelTimes
			})

			fireSafe(player, "End", {
				score   = finalScore,
				perfect = (state.perfect == true),
				reason  = (state.perfect and "perfect") or (state.reason or "gameover"),
				level   = currentLevel
			})

			destroySession(player)
		end
	end)
end

-- starts a new session or advances to the next level if one is pending
local function startOrContinueSession(player, payload)
	payload = (type(payload) == "table") and payload or {}

	local requestedLevel = tonumber(payload.level) or 1
	requestedLevel = math.clamp(requestedLevel, 1, MAX_LEVEL)

	local s = sessions[player]

	local isEnabled = playerAudioSettings[player.UserId]
	if isEnabled == nil then isEnabled = true end

	pcall(function()
		ToggleAudio:FireClient(player, isEnabled)
	end)

	if not s then
		s = {
			game = newGameAtLevel(requestedLevel, 0, nil),
			waitingNextLevel = false,
			totalScore = 0,
			currentLives = 5,
			sessionStart = os.clock(),
			lastTick = os.clock(),
			loop = nil,
		}
		sessions[player] = s

		local startState = s.game:getState()
		startState.audioEnabled = isEnabled

		fireSafe(player, "Start", startState)
		startLoop(player)
		return
	end

	if s.waitingNextLevel then
		s.waitingNextLevel = false
		local carryScore = s.totalScore or 0
		local carryLives = s.currentLives

		s.game = newGameAtLevel(requestedLevel, carryScore, carryLives)
		s.lastTick = os.clock()

		local startState = s.game:getState()
		startState.audioEnabled = isEnabled

		fireSafe(player, "Start", startState)
		startLoop(player)
		return
	end

	if payload.restart == true then
		local carryScore = 0
		s.totalScore = 0
		s.sessionStart = os.clock()
		s.game = newGameAtLevel(requestedLevel, carryScore, nil)

		local startState = s.game:getState()
		startState.audioEnabled = isEnabled

		fireSafe(player, "Start", startState)
		startLoop(player)
	end
end

StartJuiceCutterRequest.OnServerEvent:Connect(function(player, payload)
	startOrContinueSession(player, payload)
end)

SubmitMove.OnServerEvent:Connect(function(player, move)
	local s = sessions[player]
	if not s or not s.game then return end
	if s.waitingNextLevel then return end

	if type(move) == "table" and move.kind == "cut" then
		local x0, y0, x1, y1 = tonumber(move.x0), tonumber(move.y0), tonumber(move.x1), tonumber(move.y1)
		if x0 and y0 and x1 and y1 then
			local dx = x1 - x0
			local dy = y1 - y0
			local dist = math.sqrt(dx*dx + dy*dy)

			if dist > 1000 then
				return
			end

			local pStats = playerCuts[player]
			if not pStats then
				pStats = { lastTime = os.clock(), count = 0 }
				playerCuts[player] = pStats
			end

			local now = os.clock()
			if now - pStats.lastTime > 1.0 then
				pStats.count = 0
				pStats.lastTime = now
			end

			pStats.count = pStats.count + 1
			if pStats.count > 15 then
				return
			end
		end
	end

	local game = s.game
	if game.handleInput then
		game:handleInput(move)
	elseif game.handleMove then
		game:handleMove(move)
	end
end)

ToggleAudio.OnServerEvent:Connect(function(player, isEnabled)
	if type(isEnabled) ~= "boolean" then return end
	playerAudioSettings[player.UserId] = isEnabled
end)

Players.PlayerRemoving:Connect(function(player)
	playerCuts[player] = nil
	destroySession(player)

	local audioSetting = playerAudioSettings[player.UserId]
	if audioSetting ~= nil then
		pcall(function()
			AudioDataStore:SetAsync(tostring(player.UserId), audioSetting)
		end)
	end
	playerAudioSettings[player.UserId] = nil
end)

-- loads audio preference; staggered to avoid flooding the datastore queue on join
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		task.wait(1)
		local success, savedValue = pcall(function()
			return AudioDataStore:GetAsync(tostring(player.UserId))
		end)

		local isEnabled = true
		if success and savedValue ~= nil then
			isEnabled = savedValue
		end
		playerAudioSettings[player.UserId] = isEnabled

		task.wait(1)
		if player and player.Parent then
			pcall(function()
				ToggleAudio:FireClient(player, isEnabled)
			end)
		end
	end)
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

	AnalyticsModule.ReportDonationAsync("JuiceCutter", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("juice cutter server ready.")
