local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local SafeStore = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DataStoreSafe"))
local AudioDataStore = SafeStore.Get("Resilio_AudioSettings_v1")
local playerAudioSettings = {}

local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes")
local folder = arc:WaitForChild("Resilio")
local modules = ReplicatedStorage:WaitForChild("Modules")

local StartResilioRequest = folder:WaitForChild("StartResilioRequest")
local SubmitMoveInput     = folder:WaitForChild("SubmitMoveInput")
local SubmitLaunch        = folder:WaitForChild("SubmitLaunch")
local GameState           = folder:WaitForChild("GameState")

local ToggleAudio = folder:FindFirstChild("ToggleAudio")
if not ToggleAudio then
	ToggleAudio = Instance.new("RemoteEvent")
	ToggleAudio.Name = "ToggleAudio"
	ToggleAudio.Parent = folder
end

local ResilioModule = require(modules:WaitForChild("ResilioModule"))
local UniversalLeaderboard = require(modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(modules:WaitForChild("AnalyticsModule"))

local sessions: {[Player]: any} = {}
local loops: {[Player]: RBXScriptConnection} = {}
local rateLimits = {}

local function checkRateLimit(player, action, limit)
	if not rateLimits[player] then rateLimits[player] = {} end
	local now = os.clock()
	if not rateLimits[player][action] then
		rateLimits[player][action] = now
		return true
	end
	if now - rateLimits[player][action] < limit then
		return false
	end
	rateLimits[player][action] = now
	return true
end

local function stopLoopFor(player: Player)
	local loop = loops[player]
	if loop then loop:Disconnect() end
	loops[player] = nil
end

-- disconnects the heartbeat loop and fires the end event to the client
local function endSession(player: Player, payload: table)
	stopLoopFor(player)
	sessions[player] = nil
	pcall(function()
		GameState:FireClient(player, "End", payload or {})
	end)
end

-- starts a new game, runs a heartbeat loop, reports score when the ball is lost
local function startSession(player: Player)
	if sessions[player] then return end

	local isEnabled = playerAudioSettings[player.UserId]
	if isEnabled == nil then isEnabled = true end

	pcall(function()
		ToggleAudio:FireClient(player, isEnabled)
	end)

	local game = ResilioModule.new()
	sessions[player] = game

	local startState = game:getState()
	startState.audioEnabled = isEnabled

	pcall(function()
		GameState:FireClient(player, "Start", startState)
	end)

	local sessionStart = os.clock()
	local last = os.clock()
	local levelTimes = {}
	local lastLevel = (game.level or game.levelIndex or 1)
	local levelStart = sessionStart

	loops[player] = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = math.clamp(now - last, 1/240, 1/15)
		last = now

		local alive = game:step(dt)
		local state = game:getState()

		-- detect level transitions to record per-level time
		local curLevel = state.level or game.level or lastLevel
		if curLevel ~= lastLevel then
			levelTimes[lastLevel] = now - levelStart
			levelStart = now
			lastLevel = curLevel
		end

		pcall(function()
			GameState:FireClient(player, "Update", state)
		end)

		if not alive then
			local durationMs = math.floor((os.clock() - sessionStart) * 1000)
			local finalScore = state.score or 0

			UniversalLeaderboard:ReportScore("Resilio", player, finalScore, durationMs)

			-- close out the final level time
			levelTimes[lastLevel] = (os.clock() - levelStart)

			AnalyticsModule.ReportSessionAsync(player, "Resilio", finalScore, durationMs / 1000, {
				levelReached = lastLevel,
				levelTimes   = levelTimes
			})

			endSession(player, {
				score   = finalScore,
				perfect = state.perfect == true,
				reason  = (state.perfect and "perfect") or "gameover",
			})
		end
	end)
end

StartResilioRequest.OnServerEvent:Connect(function(player)
	if not checkRateLimit(player, "Start", 1) then return end
	startSession(player)
end)

SubmitMoveInput.OnServerEvent:Connect(function(player, dir)
	if not checkRateLimit(player, "Paddle", 0.05) then return end
	local game = sessions[player]
	if not game then return end
	if dir == "Left" or dir == "Right" or dir == "Stop" then
		game:handleInput(dir)
	end
end)

SubmitLaunch.OnServerEvent:Connect(function(player)
	if not checkRateLimit(player, "Launch", 0.2) then return end
	local game = sessions[player]
	if not game then return end
	game:handleInput("Fire")
end)

ToggleAudio.OnServerEvent:Connect(function(player, isEnabled)
	if not checkRateLimit(player, "Audio", 0.5) then return end
	if type(isEnabled) ~= "boolean" then return end
	playerAudioSettings[player.UserId] = isEnabled
end)

Players.PlayerRemoving:Connect(function(player)
	stopLoopFor(player)
	sessions[player] = nil
	rateLimits[player] = nil

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

-- confirms donation purchases
local function _disabledProcessReceipt(receiptInfo)  -- centralized in DonationHandler
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("donation processed for " .. player.Name .. " (product id: " .. receiptInfo.ProductId .. ")")

	AnalyticsModule.ReportDonationAsync("Resilio", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- saves audio settings for all players if the server shuts down
game:BindToClose(function()
	for userId, isEnabled in pairs(playerAudioSettings) do
		pcall(function()
			AudioDataStore:SetAsync(tostring(userId), isEnabled)
		end)
	end
end)
