local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteGuard = require(ServerScriptService:WaitForChild("RemoteGuard"))
local is = RemoteGuard.is
local MAX_SCORE = 500  -- plausibility cap (solo mode rejects > 490); blocks leaderboard nukes

local MatchManager = {}

print("im not a sphere match manager started.")

local ArcadeRemotes = ReplicatedStorage:FindFirstChild("ArcadeRemotes") or Instance.new("Folder", ReplicatedStorage)
ArcadeRemotes.Name = "ArcadeRemotes"

local GameFolder = ArcadeRemotes:FindFirstChild("ImNotASphere") or Instance.new("Folder", ArcadeRemotes)
GameFolder.Name = "ImNotASphere"

local LobbyRemotes = GameFolder:FindFirstChild("LobbySystem") or Instance.new("Folder", GameFolder)
LobbyRemotes.Name = "LobbySystem"

local MatchStatusEvent = GameFolder:FindFirstChild("MatchStatus")
if not MatchStatusEvent then
	MatchStatusEvent = Instance.new("RemoteEvent")
	MatchStatusEvent.Name = "MatchStatus"
	MatchStatusEvent.Parent = GameFolder
end

local function ensureRemote(name, class)
	local r = LobbyRemotes:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = LobbyRemotes
	end
	return r
end

local CreateRoomFunc = ensureRemote("CreateRoom", "RemoteFunction")
local JoinRoomFunc = ensureRemote("JoinRoom", "RemoteFunction")
local StartMatchEvent = ensureRemote("StartMultiplayerMatch", "RemoteEvent")
local RoomUpdateEvent = ensureRemote("RoomUpdate", "RemoteEvent")
local KickPlayerEvent = ensureRemote("KickPlayer", "RemoteEvent")
local LeaveRoomEvent = ensureRemote("LeaveRoom", "RemoteEvent")
local UpdateLiveScore = ensureRemote("UpdateLiveScore", "RemoteEvent")
local SpectateEvent = ensureRemote("SpectateTarget", "RemoteEvent")
local PlayerDiedEvent = ensureRemote("PlayerDied", "RemoteEvent")

local rooms = {}
local playerRoomMap = {}

local MAX_PLAYERS_PER_ROOM = 10
local ROOM_TIMEOUT = 300

-- generates a unique 4-digit room PIN
local function generatePIN()
	local pin
	repeat
		pin = string.format("%04d", math.random(0, 9999))
	until not rooms[pin]
	return pin
end

-- removes a room and clears all player-to-room mappings for it
local function cleanupRoom(pin)
	local room = rooms[pin]
	if room then
		for _, plr in ipairs(room.Players) do
			if playerRoomMap[plr] == pin then
				playerRoomMap[plr] = nil
			end
		end
		rooms[pin] = nil
	end
end

-- fires a room update event to all players in the room
local function notifyRoomUpdate(pin, type)
	local room = rooms[pin]
	if not room then return end
	local playerNames = {}
	for _, p in ipairs(room.Players) do table.insert(playerNames, p.Name) end
	for _, p in ipairs(room.Players) do RoomUpdateEvent:FireClient(p, type, playerNames) end
end

-- sends the current score table to every player in the room
function MatchManager.BroadcastScores(room)
	local pack = {}
	for _, p in ipairs(room.Players) do
		local data = room.Scores[p]
		if data then
			table.insert(pack, {
				Name = p.Name,
				Score = data.Score,
				Alive = data.Alive,
				Id = p.UserId
			})
		end
	end
	for _, p in ipairs(room.Players) do
		RoomUpdateEvent:FireClient(p, "ScoreUpdate", pack)
	end
end

-- determines the winner by highest score then earliest finish time, then broadcasts the result
function MatchManager.EndMatch(pin)
	local room = rooms[pin]
	if not room or room.Status ~= "Playing" then return end

	room.Status = "Finished"

	local bestPlayerName = "Nobody"
	local highestScore = -1
	local bestTime = math.huge

	for p, data in pairs(room.Scores) do
		local s = data.Score or 0
		local t = data.FinishedTime or math.huge

		if s > highestScore then
			highestScore = s
			bestTime = t
			bestPlayerName = p.Name
		elseif s == highestScore then
			if t < bestTime then
				bestTime = t
				bestPlayerName = p.Name
			elseif t == bestTime then
				bestPlayerName = "TIE"
			end
		end
	end

	for _, p in ipairs(room.Players) do
		RoomUpdateEvent:FireClient(p, "MatchEnded", {Winner = bestPlayerName, Score = highestScore})
	end
	task.delay(3, function() cleanupRoom(pin) end)
end

-- records a player finishing a level; starts a 30-second countdown for remaining players
function MatchManager.HandlePlayerFinished(player, finalScore, finalTime)
	local pin = playerRoomMap[player]
	if not pin then return end
	local room = rooms[pin]
	if not room or room.Status ~= "Playing" then return end

	if room.Scores[player] then
		room.Scores[player].Score = finalScore or room.Scores[player].Score
		room.Scores[player].FinishedTime = finalTime or os.clock()
	end

	if #room.Players <= 1 then
		MatchManager.EndMatch(pin)
		return
	end

	local allFinished = true
	for _, p in ipairs(room.Players) do
		if room.Scores[p] and room.Scores[p].FinishedTime == nil then
			allFinished = false
			break
		end
	end

	if allFinished then
		MatchManager.EndMatch(pin)
		return
	end

	if not room.FinishCountdownTriggered then
		room.FinishCountdownTriggered = true
		print("im not a sphere: " .. player.Name .. " finished. 30 seconds remaining.")

		for _, p in ipairs(room.Players) do
			RoomUpdateEvent:FireClient(p, "CountdownToFinish", 30)
		end

		task.delay(30, function()
			MatchManager.EndMatch(pin)
		end)
	end
end

-- marks the player briefly as dead and then restores alive status for respawn
function MatchManager.HandleDeath(player)
	local pin = playerRoomMap[player]
	if not pin then return end
	local room = rooms[pin]
	if not room or room.Status ~= "Playing" then return end

	if room.Scores[player] then
		room.Scores[player].Alive = false
		MatchManager.BroadcastScores(room)

		task.delay(1, function()
			if rooms[pin] and room.Scores[player] then
				room.Scores[player].Alive = true
				MatchManager.BroadcastScores(room)
			end
		end)
	end
end

-- removes a player from their current room; ends the room if they were the host
function MatchManager.RemovePlayer(player)
	local pin = playerRoomMap[player]
	playerRoomMap[player] = nil
	if not pin then return end
	local room = rooms[pin]
	if not room then return end

	if player == room.Host and room.Status == "Waiting" then
		for _, p in ipairs(room.Players) do
			if p ~= player then
				RoomUpdateEvent:FireClient(p, "RoomClosed")
				playerRoomMap[p] = nil
			end
		end
		rooms[pin] = nil
	else
		for i, p in ipairs(room.Players) do
			if p == player then table.remove(room.Players, i); break end
		end

		if room.Status == "Playing" and room.Scores[player] then
			room.Scores[player] = nil
			MatchManager.BroadcastScores(room)

			if #room.Players == 0 then
				cleanupRoom(pin)
			elseif #room.Players == 1 then
				MatchManager.EndMatch(pin)
			else
				local allFinished = true
				for _, p in ipairs(room.Players) do
					if room.Scores[p] and room.Scores[p].FinishedTime == nil then
						allFinished = false
						break
					end
				end
				if allFinished then
					MatchManager.EndMatch(pin)
				end
			end
		else
			notifyRoomUpdate(pin, "PlayerLeft")
		end
	end
end

-- creates a new room and returns its PIN
function MatchManager.CreateRoom(player)
	MatchManager.RemovePlayer(player); task.wait()
	local pin = generatePIN()
	rooms[pin] = {
		Host = player,
		Players = {player},
		Status = "Waiting",
		Scores = {},
		LastActivity = os.time(),
		FinishCountdownTriggered = false
	}
	playerRoomMap[player] = pin
	print("im not a sphere: room created: " .. pin .. " by " .. player.Name)
	return pin
end

-- adds a player to an existing waiting room
function MatchManager.JoinRoom(player, pin)
	MatchManager.RemovePlayer(player); task.wait()
	local room = rooms[pin]
	if not room then return false, "room does not exist." end
	if room.Status ~= "Waiting" then return false, "match already started." end
	if #room.Players >= MAX_PLAYERS_PER_ROOM then return false, "room is full." end

	table.insert(room.Players, player)
	playerRoomMap[player] = pin
	notifyRoomUpdate(pin, "PlayerJoined")
	return true
end

-- allows the host to remove a player from the waiting room
function MatchManager.KickPlayer(hostPlayer, targetName)
	local pin = playerRoomMap[hostPlayer]
	local room = rooms[pin]
	if room and room.Host == hostPlayer and room.Status == "Waiting" then
		local targetPlayer = Players:FindFirstChild(targetName)
		for i, p in ipairs(room.Players) do
			if p.Name == targetName then
				MatchManager.RemovePlayer(p)
				if targetPlayer then RoomUpdateEvent:FireClient(targetPlayer, "Kicked") end
				break
			end
		end
	end
end

RemoteGuard.onEvent(StartMatchEvent, { rate = { max = 4, per = 1 } }, function(player)
	local pin = playerRoomMap[player]
	local room = rooms[pin]
	if room and room.Host == player and room.Status == "Waiting" then
		room.Status = "Playing"
		room.LastActivity = os.time()
		print("im not a sphere: versus match starting in room: " .. pin)
		for _, p in ipairs(room.Players) do
			room.Scores[p] = { Alive = true, Score = 0 }
			RoomUpdateEvent:FireClient(p, "StartGame")
		end
	end
end)

-- score is client-reported; cap it to a plausible range so it can't nuke the board
RemoteGuard.onEvent(UpdateLiveScore, {
	rate = { max = 30, per = 1 },
	args = { is.integer(0, MAX_SCORE) },
}, function(player, newScore)
	local pin = playerRoomMap[player]
	local room = rooms[pin]
	if room and room.Status == "Playing" and room.Scores[player] then
		room.Scores[player].Score = newScore
		MatchManager.BroadcastScores(room)
	end
end)

RemoteGuard.onEvent(PlayerDiedEvent, { rate = { max = 6, per = 1 } }, function(player)
	MatchManager.HandleDeath(player)
end)

RemoteGuard.onEvent(MatchStatusEvent, {
	rate = { max = 6, per = 1 },
	args = { is.string(20), is.optional(is.integer(0, MAX_SCORE)), is.optional(is.number(0, 86400000)) },
}, function(player, statusType, finalScore, finalTime)
	if statusType == "GameOver" then
		local pin = playerRoomMap[player]
		if pin then
			local room = rooms[pin]
			if room and room.Scores[player] then
				room.Scores[player].Score = finalScore or room.Scores[player].Score
				MatchManager.BroadcastScores(room)
			end
			MatchManager.HandlePlayerFinished(player, finalScore, finalTime)
		end
	end
end)

-- KickPlayer already checks host authority internally; just type + rate guard it
RemoteGuard.onEvent(KickPlayerEvent, {
	rate = { max = 6, per = 1 },
	args = { is.string(50) },
}, function(p, t) MatchManager.KickPlayer(p, t) end)

RemoteGuard.onEvent(LeaveRoomEvent, { rate = { max = 6, per = 1 } }, function(player)
	MatchManager.RemovePlayer(player)
end)
Players.PlayerRemoving:Connect(MatchManager.RemovePlayer)

RemoteGuard.onInvoke(CreateRoomFunc, { rate = { max = 4, per = 1 } }, MatchManager.CreateRoom)
RemoteGuard.onInvoke(JoinRoomFunc, {
	rate = { max = 6, per = 1 },
	args = { is.string(12) },
}, MatchManager.JoinRoom)

-- cleans up waiting rooms that have been inactive longer than the timeout
task.spawn(function()
	while true do
		task.wait(60)
		local now = os.time()
		for pin, room in pairs(rooms) do
			if room.Status == "Waiting" and (now - room.LastActivity) > ROOM_TIMEOUT then
				cleanupRoom(pin)
			end
		end
	end
end)

return MatchManager
