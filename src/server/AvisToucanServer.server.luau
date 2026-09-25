local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local RunService        = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

print("avis toucan server started.")

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes", 10)
if not ArcadeRemotes then
	ArcadeRemotes = Instance.new("Folder")
	ArcadeRemotes.Name = "ArcadeRemotes"
	ArcadeRemotes.Parent = ReplicatedStorage
end

local AvisToucanFolder = ArcadeRemotes:FindFirstChild("AvisToucan")
if not AvisToucanFolder then
	AvisToucanFolder = Instance.new("Folder")
	AvisToucanFolder.Name = "AvisToucan"
	AvisToucanFolder.Parent = ArcadeRemotes
end

-- creates a remote inside the AvisToucan folder if missing
local function ensureRemote(name, class)
	local r = AvisToucanFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = AvisToucanFolder
		print("created missing remote: " .. name)
	end
	return r
end

local StartRequest    = ensureRemote("StartAvisToucanRequest", "RemoteEvent")
local SubmitFlap      = ensureRemote("SubmitFlap", "RemoteEvent")
local GameState       = ensureRemote("GameState", "RemoteEvent")
local ToggleAudio     = ensureRemote("ToggleAudio", "RemoteEvent")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AvisToucanModule = require(Modules:WaitForChild("AvisToucanModule"))
local UniversalLeaderboard = require(Modules:WaitForChild("UniversalLeaderboardModule"))
local AnalyticsModule = require(Modules:WaitForChild("AnalyticsModule"))

local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local SettingsStore = SafeStore.Get("AvisToucanUserSettings_v1")
local sessions = {}
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

-- starts a new game session and runs the physics loop until the bird dies
local function startAvisToucanSession(player)
	if sessions[player] then
		warn("avis toucan: " .. player.Name .. " tried to start a double session.")
		return
	end

	print("new avis toucan session for: " .. player.Name)

	math.randomseed(os.clock() * 1000)

	local gameInstance = AvisToucanModule.new()
	local startTime = os.clock()

	local session = {game = gameInstance, loop = true, startTime = startTime}
	sessions[player] = session

	GameState:FireClient(player, "Start", gameInstance:serialize())

	task.spawn(function()
		local prev = os.clock()
		local accum = 0

		while session.loop and gameInstance.alive do
			local now = os.clock()
			local dt = now - prev
			prev = now

			if dt > 0.1 then dt = 0.1 end

			gameInstance:step(dt)
			accum += dt

			if accum >= 0.05 then
				accum -= 0.05
				GameState:FireClient(player, "Update", gameInstance:serialize())
			end
			RunService.Heartbeat:Wait()
		end

		if sessions[player] == session then
			local elapsedMs = math.floor((os.clock() - session.startTime) * 1000 + 0.5)
			print("game over for " .. player.Name .. ". score: " .. gameInstance.score)

			pcall(function()
				UniversalLeaderboard:ReportScore("AvisToucan", player, gameInstance.score, elapsedMs)
			end)

			AnalyticsModule.ReportSessionAsync(player, "AvisToucan", gameInstance.score or 0, elapsedMs / 1000)

			local finalState = gameInstance:serialize()
			GameState:FireClient(player, "End", {
				score = finalState.score,
				birdX = finalState.birdX,
				birdY = finalState.birdY,
				perfect = false,
			})

			sessions[player] = nil
		end
	end)
end

StartRequest.OnServerEvent:Connect(function(player)
	if not checkRateLimit(player, "Start", 1) then return end
	if sessions[player] then sessions[player] = nil end
	startAvisToucanSession(player)
end)

SubmitFlap.OnServerEvent:Connect(function(player)
	if not checkRateLimit(player, "Flap", 0.05) then return end
	local s = sessions[player]
	if s and s.game and s.game.alive then
		s.game:flap()
	end
end)

ToggleAudio.OnServerEvent:Connect(function(player, isEnabled)
	if not checkRateLimit(player, "Audio", 0.5) then return end
	if type(isEnabled) ~= "boolean" then return end
	local key = tostring(player.UserId)
	pcall(function() SettingsStore:SetAsync(key, isEnabled) end)
end)

Players.PlayerRemoving:Connect(function(player)
	if sessions[player] then
		sessions[player].loop = false
		sessions[player] = nil
	end
	rateLimits[player] = nil
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		task.wait(2)
		local key = tostring(player.UserId)
		local ok, val = pcall(function() return SettingsStore:GetAsync(key) end)
		if ok and val ~= nil then ToggleAudio:FireClient(player, val) end
	end)
end)

-- confirms donation purchases
local function _disabledProcessReceipt(receiptInfo)  -- centralized in DonationHandler
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("donation processed for " .. player.Name .. " (product id: " .. receiptInfo.ProductId .. ")")

	AnalyticsModule.ReportDonationAsync("AvisToucan", receiptInfo)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("avis toucan server ready.")
