local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UniversalLeaderboard = require(Modules:WaitForChild("UniversalLeaderboardModule"))

print("universal leaderboard server started.")

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes")
local GlobalBoardFolder = ArcadeRemotes:FindFirstChild("GlobalBoard") or Instance.new("Folder")
GlobalBoardFolder.Name = "GlobalBoard"
GlobalBoardFolder.Parent = ArcadeRemotes

local UpdateUniversalLeaderboard = GlobalBoardFolder:FindFirstChild("UpdateUniversalLeaderboard") or Instance.new("RemoteEvent")
UpdateUniversalLeaderboard.Name = "UpdateUniversalLeaderboard"
UpdateUniversalLeaderboard.Parent = GlobalBoardFolder

-- lets a client query its own rank for a game, even when outside the top 10
local GetMyRank = GlobalBoardFolder:FindFirstChild("GetMyRank") or Instance.new("RemoteFunction")
GetMyRank.Name = "GetMyRank"
GetMyRank.Parent = GlobalBoardFolder

GetMyRank.OnServerInvoke = function(player, gameId)
	if type(gameId) ~= "string" then return nil end
	return UniversalLeaderboard:GetPlayerRank(gameId, player.UserId)
end

UniversalLeaderboard:Init()

local BROADCAST_INTERVAL = 10

-- broadcasts all game top-10 data to every client every 10 seconds
task.spawn(function()
	while true do
		local allData = {}

		for gameId, config in pairs(UniversalLeaderboard.GAMES_CONFIG) do
			allData[gameId] = {
				Config = config,
				Top10 = UniversalLeaderboard:GetTop(gameId, 10)
			}
		end

		UpdateUniversalLeaderboard:FireAllClients(allData)

		task.wait(BROADCAST_INTERVAL)
	end
end)
