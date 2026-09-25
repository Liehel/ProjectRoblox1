local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes", 10)
if not ArcadeRemotes then
	ArcadeRemotes = Instance.new("Folder")
	ArcadeRemotes.Name = "ArcadeRemotes"
	ArcadeRemotes.Parent = ReplicatedStorage
end

local TapFolder = ArcadeRemotes:FindFirstChild("TapAndHold")
if not TapFolder then
	TapFolder = Instance.new("Folder")
	TapFolder.Name = "TapAndHold"
	TapFolder.Parent = ArcadeRemotes
end

-- creates a remote inside the TapAndHold folder if missing
local function ensureRemote(name, class)
	local r = TapFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = TapFolder
	end
	return r
end

local StartRequest = ensureRemote("StartTapAndHoldRequest", "RemoteEvent")
local MatchStatus  = ensureRemote("MatchStatus", "RemoteEvent")
local ToggleAudio  = ensureRemote("ToggleAudio", "RemoteEvent")
local GetAudioState = ensureRemote("GetAudioState", "RemoteFunction")
local UpdateLeaderboard = ensureRemote("UpdateTapAndHoldLeaderboard", "RemoteEvent")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UniversalLeaderboardModule = require(Modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("TapAndHold_Settings_v1")
local PurchaseHistoryStore = SafeStore.Get("TapAndHold_PurchaseHistory_v1")
local sessions = {}

local DONATION_PRODUCTS = {
	[3572911018] = "Tap Tip (5)",
	[3572911230] = "Tap Treat (15)",
	[3572911349] = "Tap Sub (50)",
	[3572911440] = "Tap Sponsor (100)",
	[3572911513] = "Tap Whale (500)",
	[3474075594] = "Tap Legend (1000)"
}

-- loads audio preference and sends the current leaderboard when a player joins
Players.PlayerAdded:Connect(function(player)
	local key = "Player_" .. player.UserId

	task.spawn(function()
		task.wait(1)
		local success, isEnabled = pcall(function()
			return SettingsStore:GetAsync(key)
		end)

		task.wait(1)
		if player and player.Parent then
			if success and isEnabled ~= nil then
				ToggleAudio:FireClient(player, isEnabled)
			else
				ToggleAudio:FireClient(player, true)
			end

			local topData = UniversalLeaderboardModule:GetTop("TapAndHold", 10)
			if topData then
				UpdateLeaderboard:FireClient(player, topData)
			end
		end
	end)
end)

ToggleAudio.OnServerEvent:Connect(function(player, isEnabled)
	if type(isEnabled) ~= "boolean" then return end
	local key = "Player_" .. player.UserId
	pcall(function()
		SettingsStore:SetAsync(key, isEnabled)
	end)
end)

StartRequest.OnServerEvent:Connect(function(player, mode)
	if type(mode) ~= "string" then return end
	if sessions[player] then sessions[player] = nil end

	sessions[player] = {
		StartTime = os.clock(),
		Mode = mode or "Solo",
		IsActive = true
	}
	print("tap and hold: " .. player.Name .. " started a session in mode: " .. tostring(mode or "Solo"))
end)

-- receives the final score from the client, validates it, and reports to the leaderboard
MatchStatus.OnServerEvent:Connect(function(player, status, clientScore, clientTime)
	local session = sessions[player]

	if status == "GameOver" and session and session.IsActive then
		local finalScore = tonumber(clientScore) or 0
		session.IsActive = false

		local serverTime = os.clock() - session.StartTime
		local timeMs = math.floor(serverTime * 1000)

		local maxAllowedScore = math.floor((serverTime * 2.5) + 15)

		if finalScore > maxAllowedScore then
			sessions[player] = nil
			return
		end

		if finalScore > 100000 or finalScore < 0 or (serverTime < 1 and finalScore > 10) then
			sessions[player] = nil
			return
		end

		print("tap and hold result: " .. player.Name .. " | score: " .. finalScore)

		task.spawn(function()
			pcall(function()
				local topData = UniversalLeaderboardModule:ReportScore("TapAndHold", player, finalScore, timeMs)
				if topData then
					UpdateLeaderboard:FireAllClients(topData)
				end
			end)
		end)

		AnalyticsModule.ReportSessionAsync(player, "TapAndHold", finalScore, serverTime)

		sessions[player] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

-- validates purchases with deduplication via purchase history store
local function _disabledProcessReceipt(receiptInfo)  -- centralized in DonationHandler
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

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

	AnalyticsModule.ReportDonationAsync("TapAndHold", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("tap and hold server ready.")

-- searches ServerScriptService for the match manager module at runtime
local function getMatchManager()
	for _, obj in pairs(ServerScriptService:GetDescendants()) do
		if obj:IsA("ModuleScript") and obj.Name == "TapAndHoldMatchManager" then
			return require(obj)
		end
	end
	return nil
end

local MatchManager = getMatchManager()
if not MatchManager then
	warn("tap and hold: TapAndHoldMatchManager not found.")
end
