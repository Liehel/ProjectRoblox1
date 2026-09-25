local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

print("firmament defender server started.")

local remotes = ReplicatedStorage:WaitForChild("ArcadeRemotes"):WaitForChild("FirmamentDefender")
local StartReq = remotes:WaitForChild("StartFirmamentDefenderRequest")
local SubmitMove = remotes:WaitForChild("SubmitMove")
local GameState = remotes:WaitForChild("GameState")
local ToggleAudio = remotes:WaitForChild("ToggleAudio")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FirmamentModule = require(Modules:WaitForChild("FirmamentDefenderModule"))
local UniversalLeaderboard = require(Modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("SkyDefenderSettings_v1")
local PurchaseHistoryStore = SafeStore.Get("FirmamentDefender_PurchaseHistory_v1")

local sessions = {}
local playerAudioSettings = {}
local playerRateLimits = {}

local DONATION_PRODUCTS = {
	[3477824531] = "Firmament Tip (5)",
	[3477824658] = "Firmament Treat (15)",
	[3477824790] = "Firmament Sub (50)",
	[3477825231] = "Firmament Sponsor (100)",
	[3477825407] = "Firmament Whale (500)",
	[3477825563] = "Firmament Legend (1000)",
}

-- sends the current game state to the client
local function sendState(plr)
	local game = sessions[plr]
	if not game then return end
	GameState:FireClient(plr, "Update", game:getState())
end

-- loads audio preference; staggered to avoid flooding the datastore queue on join
Players.PlayerAdded:Connect(function(plr)
	task.spawn(function()
		task.wait(1)
		local success, savedAudioState = pcall(function()
			return SettingsStore:GetAsync(tostring(plr.UserId) .. "_Audio")
		end)

		local isEnabled = true
		if success and savedAudioState ~= nil then
			isEnabled = savedAudioState
		end

		playerAudioSettings[plr.UserId] = isEnabled

		task.wait(1)
		if plr and plr.Parent then
			ToggleAudio:FireClient(plr, isEnabled)
		end
	end)
end)

ToggleAudio.OnServerEvent:Connect(function(plr, isEnabled)
	if typeof(isEnabled) ~= "boolean" then return end  -- reject malformed input
	playerAudioSettings[plr.UserId] = isEnabled
end)

StartReq.OnServerEvent:Connect(function(plr)
	local game = FirmamentModule.new()
	sessions[plr] = game
	playerRateLimits[plr] = { count = 0, lastTick = os.clock() }
	GameState:FireClient(plr, "Start", game:getState())
end)

SubmitMove.OnServerEvent:Connect(function(plr, input)
	local game = sessions[plr]

	if typeof(input) == "table" and input.action == "Exit" then
		sessions[plr] = nil
		return
	end

	if not game then return end

	local rLimit = playerRateLimits[plr]
	if rLimit then
		local now = os.clock()
		if now - rLimit.lastTick > 1 then
			rLimit.count = 0
			rLimit.lastTick = now
		end
		rLimit.count += 1
		if rLimit.count > 40 then return end
	end

	if typeof(input) == "string" then
		if input == "Left" or input == "Right" or input == "Stop" then
			if game.setMove then game:setMove(input) end

		elseif input == "Shoot" or input == "Fire" then
			if game.shoot then game:shoot()
			elseif game.fire then game:fire()
			elseif game.requestFire then game:requestFire()
			end

		elseif input == "ShootHoldOn" then
			if game.setShooting then game:setShooting(true) end

		elseif input == "ShootHoldOff" then
			if game.setShooting then game:setShooting(false) end
		end

	elseif typeof(input) == "table" then
		local action = input.action

		if action == "Move" and (input.dir == "Left" or input.dir == "Right" or input.dir == "Stop") then
			if game.setMove then game:setMove(input.dir) end

		elseif action == "Shoot" then
			if game.shoot then game:shoot()
			elseif game.fire then game:fire()
			elseif game.requestFire then game:requestFire()
			end

		elseif action == "ShootHold" then
			local on = input.on == true
			if game.setShooting then game:setShooting(on) end
		end
	end
end)

-- runs the update loop, reports score when the game ends
RunService.Heartbeat:Connect(function(dt)
	for plr, game in pairs(sessions) do
		game:update(dt)

		if game.win or game.alive == false then
			local score = game.score or 0
			local timeMs = math.floor((game.timePlayed or 0) * 1000)

			local maxAllowedScore = ((timeMs / 1000) * 1000) + 2000
			if score > maxAllowedScore or score < 0 then
				score = 0
			end

			UniversalLeaderboard:ReportScore("FirmamentDefender", plr, score, timeMs)

			AnalyticsModule.ReportSessionAsync(plr, "FirmamentDefender", score, game.timePlayed or 0, {
				levelReached = game.wave or 1
			})

			GameState:FireClient(plr, "End", { score = score, win = game.win })
			sessions[plr] = nil
		else
			sendState(plr)
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

	AnalyticsModule.ReportDonationAsync("FirmamentDefender", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("firmament defender server ready.")
