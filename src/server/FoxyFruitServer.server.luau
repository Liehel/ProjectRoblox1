local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

print("foxy fruit server started.")

local arcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes")
local foxyFolder = arcadeRemotes:FindFirstChild("FoxyFruit")
if not foxyFolder then
	foxyFolder = Instance.new("Folder")
	foxyFolder.Name = "FoxyFruit"
	foxyFolder.Parent = arcadeRemotes
end

local StartReq   = foxyFolder:WaitForChild("StartFoxyFruitRequest")
local SubmitMove = foxyFolder:WaitForChild("SubmitMove")
local GameState  = foxyFolder:WaitForChild("GameState")

local ToggleAudio = foxyFolder:FindFirstChild("ToggleAudio")
if not ToggleAudio then
	ToggleAudio = Instance.new("RemoteEvent")
	ToggleAudio.Name = "ToggleAudio"
	ToggleAudio.Parent = foxyFolder
end

local GlobalBoardFolder = arcadeRemotes:WaitForChild("GlobalBoard")
local UpdateUniversalLeaderboard = GlobalBoardFolder:WaitForChild("UpdateUniversalLeaderboard")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local foxyLogicModule = Modules:FindFirstChild("FoxyFruitModule")
if not foxyLogicModule then
	error("[FoxyFruitServer] critical: FoxyFruitModule not found in Modules.")
end
local FoxyModule = require(foxyLogicModule)

local UniversalLeaderboard = require(Modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("FoxyFruitSettings_v1")
local PurchaseHistoryStore = SafeStore.Get("FoxyFruit_PurchaseHistory_v1")

local sessions = {}
local playerAudioSettings = {}
local playerRateLimits = {}

local DONATION_PRODUCTS = {
	[3475288218] = "Foxy Tip (5)",
	[3475288422] = "Foxy Treat (15)",
	[3475288643] = "Foxy Sub (50)",
	[3475288826] = "Foxy Sponsor (100)",
	[3475288972] = "Foxy Whale (500)",
	[3475289214] = "Foxy Legend (1000)",
}

-- sends the current foxy fruit top-10 to a single player
local function sendFullBoardToPlayer(plr)
	if not UniversalLeaderboard then return end
	local top = UniversalLeaderboard:GetTop("FoxyFruit", 10)
	local config = UniversalLeaderboard.GAMES_CONFIG["FoxyFruit"]

	if top and config then
		local payload = {
			["FoxyFruit"] = {
				Config = config,
				Top10 = top
			}
		}
		pcall(function() UpdateUniversalLeaderboard:FireClient(plr, payload) end)
	end
end

-- loads audio preference and sends the current leaderboard when a player joins
Players.PlayerAdded:Connect(function(plr)
	task.spawn(function()
		task.wait(1)
		sendFullBoardToPlayer(plr)

		local successLoad, savedAudioState = pcall(function()
			return SettingsStore:GetAsync(tostring(plr.UserId) .. "_Audio")
		end)

		local isEnabled = true
		if successLoad and savedAudioState ~= nil then
			isEnabled = savedAudioState
		end

		playerAudioSettings[plr.UserId] = isEnabled

		task.wait(1)
		if plr and plr.Parent then
			pcall(function() ToggleAudio:FireClient(plr, isEnabled) end)
		end
	end)
end)

ToggleAudio.OnServerEvent:Connect(function(plr, isEnabled)
	if typeof(isEnabled) ~= "boolean" then return end
	playerAudioSettings[plr.UserId] = isEnabled

	task.spawn(function()
		pcall(function()
			SettingsStore:SetAsync(tostring(plr.UserId) .. "_Audio", isEnabled)
		end)
	end)
end)

-- creates a new game instance and initializes the rate limit tracker for the player
local function startSession(plr)
	local foxyGame = FoxyModule.new()
	local state = foxyGame:getState()

	sessions[plr] = {
		foxyGame      = foxyGame,
		timeMs        = 0,
		lastLevel     = foxyGame.level or 1,
		levelStartMs  = 0,
		levelTimes    = {}
	}
	playerRateLimits[plr] = { count = 0, lastTick = os.clock() }

	GameState:FireClient(plr, "Start", state)
end

-- reports score to the leaderboard and fires the end event to the client
local function finishSession(plr, win)
	local session = sessions[plr]
	if not session then return end

	local foxyGame = session.foxyGame
	local score = (foxyGame and foxyGame.score) or 0
	local timeMs = math.floor(session.timeMs or 0)

	local timeInSeconds = timeMs / 1000
	local maxAllowedScore = math.floor((timeInSeconds * 800) + 4000)
	if score > maxAllowedScore or score < 0 then
		warn("foxy fruit: " .. plr.Name .. " exceeded score limit. score: " .. score)
		score = 0
	end

	local topList
	local ok, err = pcall(function()
		topList = UniversalLeaderboard:ReportScore("FoxyFruit", plr, score, timeMs)
	end)

	if ok and topList then
		local config = UniversalLeaderboard.GAMES_CONFIG["FoxyFruit"]
		local payload = {
			["FoxyFruit"] = {
				Config = config,
				Top10 = topList
			}
		}
		task.spawn(function() UpdateUniversalLeaderboard:FireAllClients(payload) end)
	end

	-- close the timer for the final level reached and report the session
	local finalLevel = (foxyGame and foxyGame.level) or session.lastLevel or 1
	session.levelTimes[finalLevel] = (session.timeMs - (session.levelStartMs or 0)) / 1000
	AnalyticsModule.ReportSessionAsync(plr, "FoxyFruit", score, timeInSeconds, {
		levelReached = finalLevel,
		levelTimes   = session.levelTimes
	})

	GameState:FireClient(plr, "End", { score = score, win = win })
	sessions[plr] = nil
end

StartReq.OnServerEvent:Connect(function(plr)
	startSession(plr)
end)

SubmitMove.OnServerEvent:Connect(function(plr, payload)
	local session = sessions[plr]
	if not session then return end
	local foxyGame = session.foxyGame
	if not foxyGame then return end

	local rLimit = playerRateLimits[plr]
	if rLimit then
		local now = os.clock()
		if now - rLimit.lastTick > 1 then
			rLimit.count = 0
			rLimit.lastTick = now
		end
		rLimit.count += 1
		if rLimit.count > 25 then return end
	end

	local t = typeof(payload)

	if t == "string" then
		local dir = payload
		if dir == "Left" or dir == "Right" or dir == "Up" or dir == "Down" or dir == "Stop" then
			if foxyGame.setMove then foxyGame:setMove(dir)
			elseif foxyGame.setNextDir then foxyGame:setNextDir(dir)
			elseif foxyGame.setDir then foxyGame:setDir(dir) end
		end
	elseif t == "table" and payload.action == "Exit" then
		finishSession(plr, false)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for plr, session in pairs(sessions) do
		local foxyGame = session.foxyGame
		if foxyGame then
			session.timeMs = (session.timeMs or 0) + dt * 1000
			pcall(function() foxyGame:update(dt) end)

			-- detect level transitions to record per-level times
			local curLevel = foxyGame.level or session.lastLevel or 1
			if curLevel ~= session.lastLevel then
				local elapsed = (session.timeMs - (session.levelStartMs or 0)) / 1000
				session.levelTimes[session.lastLevel] = elapsed
				session.levelStartMs = session.timeMs
				session.lastLevel = curLevel
			end

			if foxyGame.win then
				finishSession(plr, true)
			elseif foxyGame.alive == false then
				finishSession(plr, false)
			else
				pcall(function() GameState:FireClient(plr, "Update", foxyGame:getState()) end)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	if sessions[plr] then
		finishSession(plr, false)
	end
	playerRateLimits[plr] = nil
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

	if not checkSuccess then return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif isPurchased then return Enum.ProductPurchaseDecision.PurchaseGranted end

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

	AnalyticsModule.ReportDonationAsync("FoxyFruit", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("foxy fruit server ready.")
