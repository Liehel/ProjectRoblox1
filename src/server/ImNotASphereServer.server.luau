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

local GameFolder = ArcadeRemotes:FindFirstChild("ImNotASphere")
if not GameFolder then
	GameFolder = Instance.new("Folder")
	GameFolder.Name = "ImNotASphere"
	GameFolder.Parent = ArcadeRemotes
end

-- creates a remote inside the ImNotASphere folder if missing
local function ensureRemote(name, class)
	local r = GameFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = GameFolder
	end
	return r
end

local StartRequest = ensureRemote("StartImNotASphereRequest", "RemoteEvent")
local MatchStatus  = ensureRemote("MatchStatus", "RemoteEvent")
local ToggleAudio  = ensureRemote("ToggleAudio", "RemoteEvent")
local GetAudioState = ensureRemote("GetAudioState", "RemoteFunction")
local UpdateLeaderboard = ensureRemote("UpdateImNotASphereLeaderboard", "RemoteEvent")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UniversalLeaderboardModule = require(Modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("ImNotASphere_Settings_v1")
local PurchaseHistoryStore = SafeStore.Get("ImNotASphere_PurchaseHistory_v1")
local sessions = {}

local DONATION_PRODUCTS = {
	[3588134038] = "Sphera Tip (5 Robux)",
	[3588134140] = "Sphera Treat (15 Robux)",
	[3588134227] = "Sphera Sub (50 Robux)",
	[3588134292] = "Sphera Sponsor (100 Robux)",
	[3588134381] = "Sphera Whale (500 Robux)",
	[3588134443] = "Sphera Legend (1000 Robux)",
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

			local topData = UniversalLeaderboardModule:GetTop("ImNotASphere", 10)
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
	if sessions[player] then sessions[player] = nil end

	sessions[player] = {
		StartTime = os.clock(),
		Mode = mode or "Solo",
		IsActive = true
	}
	print("im not a sphere: " .. player.Name .. " started a session in mode: " .. tostring(mode or "Solo"))
end)

-- receives the final score from the client, validates it, and reports to the leaderboard
MatchStatus.OnServerEvent:Connect(function(player, status, clientScore, clientTime)
	local session = sessions[player]

	if status == "GameOver" and session then
		local finalScore = tonumber(clientScore) or 0

		if finalScore > 490 or finalScore < 0 then
			sessions[player] = nil
			return
		end

		local serverTime = os.clock() - session.StartTime
		local timeMs = math.floor(serverTime * 1000)

		if serverTime < 1 and finalScore > 0 then
			sessions[player] = nil
			return
		end

		print("im not a sphere result: " .. player.Name .. " | score: " .. finalScore)

		task.spawn(function()
			pcall(function()
				local topData = UniversalLeaderboardModule:ReportScore("ImNotASphere", player, finalScore, timeMs)
				if topData then
					UpdateLeaderboard:FireAllClients(topData)
				end
			end)
		end)

		AnalyticsModule.ReportSessionAsync(player, "ImNotASphere", finalScore, serverTime)

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

	AnalyticsModule.ReportDonationAsync("ImNotASphere", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("im not a sphere server ready.")

-- searches ServerScriptService for the match manager module at runtime
local function getMatchManager()
	for _, obj in pairs(ServerScriptService:GetDescendants()) do
		if obj:IsA("ModuleScript") and obj.Name == "ImNotASphereMatchManager" then
			return require(obj)
		end
	end
	return nil
end

local MatchManager = getMatchManager()
if not MatchManager then
	warn("im not a sphere: ImNotASphereMatchManager not found.")
end
