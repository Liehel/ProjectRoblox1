local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

print("turris casei server started.")

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes", 10)
if not ArcadeRemotes then
	ArcadeRemotes = Instance.new("Folder")
	ArcadeRemotes.Name = "ArcadeRemotes"
	ArcadeRemotes.Parent = ReplicatedStorage
end

local TurrisFolder = ArcadeRemotes:FindFirstChild("TurrisCasei")
if not TurrisFolder then
	TurrisFolder = Instance.new("Folder")
	TurrisFolder.Name = "TurrisCasei"
	TurrisFolder.Parent = ArcadeRemotes
end

local function ensureRemote(name, class)
	local r = TurrisFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = TurrisFolder
	end
	return r
end

local StartRequest = ensureRemote("StartTurrisCaseiRequest", "RemoteEvent")
local MatchStatus  = ensureRemote("MatchStatus", "RemoteEvent")
local ToggleAudio  = ensureRemote("ToggleAudio", "RemoteEvent")
local GetAudioState = ensureRemote("GetAudioState", "RemoteFunction")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UniversalLeaderboardModule = require(Modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("TurrisUser_Settings_v1")
local PurchaseHistoryStore = SafeStore.Get("TurrisCasei_PurchaseHistory_v1")
local sessions = {}

local DONATION_PRODUCTS = {
	[3518446349] = "Cheese Tip (5)",
	[3518446440] = "Cheese Treat (15)",
	[3518446529] = "Cheese Sub (50)",
	[3518446659] = "Cheese Sponsor (100)",
	[3518446761] = "Cheese Whale (500)",
	[3518446854] = "Cheese Legend (1000)"
}

-- loads audio preference; staggered to avoid flooding the datastore queue on join
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		task.wait(1)
		local key = tostring(player.UserId)
		local success, isEnabled = pcall(function() return SettingsStore:GetAsync(key) end)

		task.wait(1)
		if player and player.Parent then
			if success and isEnabled ~= nil then
				ToggleAudio:FireClient(player, isEnabled)
			else
				ToggleAudio:FireClient(player, true)
			end
		end
	end)
end)

ToggleAudio.OnServerEvent:Connect(function(player, isEnabled)
	if type(isEnabled) ~= "boolean" then return end
	local key = tostring(player.UserId)
	pcall(function() SettingsStore:SetAsync(key, isEnabled) end)
end)

StartRequest.OnServerEvent:Connect(function(player, mode)
	if type(mode) ~= "string" then return end
	if sessions[player] then sessions[player] = nil end
	sessions[player] = { StartTime = os.clock(), Mode = mode or "Solo", IsActive = true }
end)

-- receives the final score from the client, validates it, and reports to the leaderboard
MatchStatus.OnServerEvent:Connect(function(player, status, clientScore, clientTime)
	local session = sessions[player]
	if status == "GameOver" and session and session.IsActive then
		local finalScore = tonumber(clientScore) or 0
		session.IsActive = false

		local serverTime = os.clock() - session.StartTime
		local timeMs = math.floor(serverTime * 1000)

		local maxAllowedScore = math.floor(serverTime * 3.5) + 15
		if finalScore > maxAllowedScore then
			sessions[player] = nil
			return
		end

		print("turris casei result: " .. player.Name .. " | score: " .. finalScore)

		task.spawn(function()
			pcall(function()
				UniversalLeaderboardModule:ReportScore("TurrisCasei", player, finalScore, timeMs)
			end)
		end)

		AnalyticsModule.ReportSessionAsync(player, "TurrisCasei", finalScore, serverTime)

		sessions[player] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)

-- validates purchases with deduplication via purchase history store
local function _disabledProcessReceipt(receiptInfo)  -- centralized in DonationHandler
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	local player = Players:GetPlayerByUserId(playerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local purchaseKey = "Purchase_" .. purchaseId
	local checkSuccess, isPurchased = pcall(function() return PurchaseHistoryStore:GetAsync(purchaseKey) end)

	if not checkSuccess then return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif isPurchased then return Enum.ProductPurchaseDecision.PurchaseGranted end

	local setSuccess, errorMessage = pcall(function() PurchaseHistoryStore:SetAsync(purchaseKey, true) end)
	if not setSuccess then return Enum.ProductPurchaseDecision.NotProcessedYet end

	AnalyticsModule.ReportDonationAsync("TurrisCasei", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("turris casei server ready.")

-- searches ServerScriptService for the match manager module at runtime
local function getMatchManager()
	for _, obj in pairs(game:GetService("ServerScriptService"):GetDescendants()) do
		if obj:IsA("ModuleScript") and obj.Name == "TurrisCaseiMatchManager" then
			return require(obj)
		end
	end
	return nil
end

local MatchManager = getMatchManager()
if not MatchManager then
	warn("turris casei: TurrisCaseiMatchManager not found.")
end
