local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

print("oxybelis server started.")

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes", 10)
if not ArcadeRemotes then
	ArcadeRemotes = Instance.new("Folder")
	ArcadeRemotes.Name = "ArcadeRemotes"
	ArcadeRemotes.Parent = ReplicatedStorage
end

local OxybelisFolder = ArcadeRemotes:FindFirstChild("Oxybelis")
if not OxybelisFolder then
	OxybelisFolder = Instance.new("Folder")
	OxybelisFolder.Name = "Oxybelis"
	OxybelisFolder.Parent = ArcadeRemotes
end

-- creates a remote if it doesn't exist yet
local function ensureRemote(parent, name, class)
	local r = parent:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = parent
		print("created missing remote: " .. name)
	end
	return r
end

local StartRequest  = ensureRemote(OxybelisFolder, "StartRequest", "RemoteEvent")
local SubmitMove    = ensureRemote(OxybelisFolder, "SubmitMove", "RemoteEvent")
local GameState     = ensureRemote(OxybelisFolder, "GameState", "RemoteEvent")
local ToggleAudio   = ensureRemote(OxybelisFolder, "ToggleAudio", "RemoteEvent")
local UpdateUniversalLeaderboard = ensureRemote(ArcadeRemotes, "UpdateUniversalLeaderboard", "RemoteEvent")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local OxybelisModule = require(Modules:WaitForChild("OxybelisModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))
local UniversalLeaderboard = nil

local okLb, lib = pcall(function()
	return require(Modules:WaitForChild("UniversalLeaderboardModule"))
end)
if okLb then
	UniversalLeaderboard = lib
else
	warn("oxybelis: could not load UniversalLeaderboardModule")
end

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("OxybelisUserSettings_v1")
local sessions = {}
local playerAudioSettings = {}
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

-- runs the game loop for a player until the snake dies, then reports the score
local function startOxybelis(player)
	if sessions[player] then return end

	local game = OxybelisModule.new(16, 12)
	sessions[player] = game
	game.startTime = os.clock()

	pcall(function()
		GameState:FireClient(player, "Start", { rows = 12, cols = 16 })
	end)

	task.spawn(function()
		while game and game.alive and sessions[player] == game do
			game:step()

			local state = {
				oxybelis = game.oxybelis,
				food  = game.food,
				score = game.score,
				rows  = game.rows or 12,
				cols  = game.cols or 16,
			}

			local ok = pcall(function()
				GameState:FireClient(player, "Update", state)
			end)

			if not ok then break end
			task.wait(0.18)
		end

		if sessions[player] == game then
			local elapsedMs = 0
			if game.startTime then
				elapsedMs = math.floor((os.clock() - game.startTime) * 1000 + 0.5)
			end

			local totalCells = (game.cols or 16) * (game.rows or 12)
			local oxybelisLen = #(game.oxybelis or {})
			local isPerfect = (oxybelisLen >= totalCells)

			local top
			if UniversalLeaderboard then
				local okTop, resultTop = pcall(function()
					return UniversalLeaderboard:ReportScore("Oxybelis", player, game.score or 0, elapsedMs)
				end)
				if okTop then top = resultTop end
			end

			AnalyticsModule.ReportSessionAsync(player, "Oxybelis", game.score or 0, elapsedMs / 1000)

			pcall(function()
				GameState:FireClient(player, "End", {
					score   = game.score or 0,
					perfect = isPerfect,
					timeMs  = elapsedMs,
				})
			end)

			if top then
				UpdateUniversalLeaderboard:FireAllClients("Oxybelis", top)
			end

			sessions[player] = nil
		end
	end)
end

SubmitMove.OnServerEvent:Connect(function(player, dir)
	if not checkRateLimit(player, "Move", 0.05) then return end

	local game = sessions[player]
	if not game or not game.alive then return end

	local curDir = game.dir
	if dir == "Up" and not (curDir.X == 0 and curDir.Y == 1) then
		game.nextDir = Vector2.new(0, -1)
	elseif dir == "Down" and not (curDir.X == 0 and curDir.Y == -1) then
		game.nextDir = Vector2.new(0, 1)
	elseif dir == "Left" and not (curDir.X == 1 and curDir.Y == 0) then
		game.nextDir = Vector2.new(-1, 0)
	elseif dir == "Right" and not (curDir.X == -1 and curDir.Y == 0) then
		game.nextDir = Vector2.new(1, 0)
	end
end)

StartRequest.OnServerEvent:Connect(function(player)
	if not checkRateLimit(player, "Start", 1) then return end
	if not sessions[player] then
		startOxybelis(player)
	end
end)

ToggleAudio.OnServerEvent:Connect(function(player, isEnabled)
	if not checkRateLimit(player, "Audio", 0.5) then return end
	if type(isEnabled) ~= "boolean" then return end

	playerAudioSettings[player.UserId] = isEnabled
	local key = tostring(player.UserId)
	task.spawn(function()
		pcall(function() SettingsStore:SetAsync(key, isEnabled) end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	rateLimits[player] = nil

	local audioSetting = playerAudioSettings[player.UserId]
	if audioSetting ~= nil then
		pcall(function()
			SettingsStore:SetAsync(tostring(player.UserId), audioSetting)
		end)
	end
	playerAudioSettings[player.UserId] = nil
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		task.wait(2)

		if UniversalLeaderboard then
			local currentTop = UniversalLeaderboard:GetTop("Oxybelis")
			UpdateUniversalLeaderboard:FireClient(player, "Oxybelis", currentTop)
		end

		local key = tostring(player.UserId)
		local success, savedValue = pcall(function()
			return SettingsStore:GetAsync(key)
		end)

		if success and savedValue ~= nil then
			playerAudioSettings[player.UserId] = savedValue
			ToggleAudio:FireClient(player, savedValue)
		else
			playerAudioSettings[player.UserId] = true
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

	AnalyticsModule.ReportDonationAsync("Oxybelis", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- saves audio settings for all players if the server shuts down
game:BindToClose(function()
	for userId, isEnabled in pairs(playerAudioSettings) do
		pcall(function()
			SettingsStore:SetAsync(tostring(userId), isEnabled)
		end)
	end
end)

print("oxybelis server ready.")
