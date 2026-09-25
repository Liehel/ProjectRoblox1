local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnalyticsModule"))

-- create the remotes folder for analytics
local AnalyticsFolder = ReplicatedStorage:FindFirstChild("AnalyticsRemotes") or Instance.new("Folder")
AnalyticsFolder.Name = "AnalyticsRemotes"
AnalyticsFolder.Parent = ReplicatedStorage

-- creates a remote of the given class inside the analytics folder if missing
local function ensureRemote(name, class)
	local r = AnalyticsFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = AnalyticsFolder
	end
	return r
end

local GetGameDashboard    = ensureRemote("GetGameDashboard",    "RemoteFunction")
local GetGeneralDashboard = ensureRemote("GetGeneralDashboard", "RemoteFunction")
local GetMoneyDashboard   = ensureRemote("GetMoneyDashboard",   "RemoteFunction")
local GetRecentDonations  = ensureRemote("GetRecentDonations",  "RemoteFunction")
local GetRecentScores     = ensureRemote("GetRecentScores",     "RemoteFunction")
local DashboardUpdated    = ensureRemote("DashboardUpdated",    "RemoteEvent")

-- ── Access control ────────────────────────────────────────────────────────
-- These dashboards expose revenue / donations / cross-game stats, so ONLY the
-- owner (or listed admins) may read them. Add your own UserId(s) here.
local ADMIN_IDS = {
	-- [123456789] = true,
}

local function isAdmin(player)
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true  -- the game owner (personal place)
	end
	-- group game? uncomment and set your group + min rank:
	-- if player:GetRankInGroup(YOUR_GROUP_ID) >= YOUR_MIN_RANK then return true end
	return ADMIN_IDS[player.UserId] == true
end

-- per-(player, board) rate limit so multiple boards can refresh independently
-- key format: "userId_gameId"
local lastRequestAt = {}
local MIN_INTERVAL  = 5.0   -- minimum seconds between refreshes of the same board by the same player

local function rateLimited(player, gameId, interval)
	local key = player.UserId .. "_" .. (gameId or "meta")
	local now = os.clock()
	local prev = lastRequestAt[key] or 0
	if now - prev < (interval or MIN_INTERVAL) then return true end
	lastRequestAt[key] = now
	return false
end

-- returns the dashboard payload for a single game id
GetGameDashboard.OnServerInvoke = function(player, gameId)
	if not isAdmin(player) then return nil end
	if type(gameId) ~= "string" or #gameId > 40 then return nil end
	if rateLimited(player, gameId) then return nil end
	return AnalyticsModule.GetGameDashboard(gameId)
end

-- returns the cross-game general dashboard payload
GetGeneralDashboard.OnServerInvoke = function(player)
	if not isAdmin(player) then return nil end
	if rateLimited(player, "General") then return nil end
	return AnalyticsModule.GetGeneralDashboard()
end

-- returns the revenue-focused dashboard payload
GetMoneyDashboard.OnServerInvoke = function(player)
	if not isAdmin(player) then return nil end
	if rateLimited(player, "Money") then return nil end
	return AnalyticsModule.GetMoneyDashboard()
end

-- returns the live donations feed (RealMoney board); lighter rate limit for near real-time
GetRecentDonations.OnServerInvoke = function(player)
	if not isAdmin(player) then return nil end
	if rateLimited(player, "FeedDonations", 2.0) then return nil end
	return AnalyticsModule.GetRecentDonations()
end

-- returns the live scores feed (RealPlayer board)
GetRecentScores.OnServerInvoke = function(player)
	if not isAdmin(player) then return nil end
	if rateLimited(player, "FeedScores", 2.0) then return nil end
	return AnalyticsModule.GetRecentScores()
end

Players.PlayerRemoving:Connect(function(player)
	-- clear all rate limit entries for this player
	local prefix = player.UserId .. "_"
	for key in pairs(lastRequestAt) do
		if key:sub(1, #prefix) == prefix then
			lastRequestAt[key] = nil
		end
	end
end)

-- periodic broadcast so open dashboards refresh themselves automatically
task.spawn(function()
	while true do
		task.wait(30)
		DashboardUpdated:FireAllClients()
	end
end)

print("analytics server ready.")
