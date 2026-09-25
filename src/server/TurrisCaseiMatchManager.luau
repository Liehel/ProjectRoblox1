local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MatchManager = {}

print("turris casei match manager started.")

local ArcadeRemotes = ReplicatedStorage:FindFirstChild("ArcadeRemotes")
local TurrisFolder = ArcadeRemotes:FindFirstChild("TurrisCasei")
local LobbyRemotes = TurrisFolder:FindFirstChild("LobbySystem")

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
local MAX_PLAYERS_PER_ROOM = 50
local ROOM_TIMEOUT = 300

-- generates a unique 4-digit room PIN
local function generatePIN()
	local pin
	repeat pin = string.format("%04d", math.random(0, 9999)) until not rooms[pin]
	return pin
end

-- removes a room and clears all player-to-room mappings for it
local function cleanupRoom(pin)
	local room = rooms[pin]
	if room then
		for _, plr in ipairs(room.Players) do
			if playerRoomMap[plr] == pin then playerRoomMap[plr] = nil end
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
			table.insert(pack, {Name = p.Name, Score = data.Score, Alive = data.Alive, Id = p.UserId})
		end
	end
	for _, p in ipairs(room.Players) do RoomUpdateEvent:FireClient(p, "ScoreUpdate", pack) end
end

-- determines the winner and broadcasts the match result
local function EndGameNow(pin)
	local room = rooms[pin]
	if not room or room.Status == "Finished" then return end

	room.Status = "Finished"
	local highestScore = -1
	local bestPlayerName = "Nobody"

	for p, data in pairs(room.Scores) do
		if data.Score > highestScore then
			highestScore = data.Score
			bestPlayerName = p.Name
		elseif data.Score == highestScore then
			if data.Alive then
				bestPlayerName = p.Name
			end
		end
	end

	print("turris casei match " .. pin .. " ended. winner: " .. bestPlayerName .. " with " .. highestScore .. " pts.")

	for _, p in ipairs(room.Players) do
		local finalScore = room.Scores[p] and room.Scores[p].Score or 0
		RoomUpdateEvent:FireClient(p, "MatchEnded", {Winner = bestPlayerName, Score = finalScore})
	end
	task.delay(3, function() cleanupRoom(pin) end)
end

-- handles a player death; triggers sudden death timer if only one player remains alive
function MatchManager.CheckWinCondition(pin, lastDiedPlayer)
	local room = rooms[pin]
	if not room then return end

	local activeCount = 0
	local alivePlayer = nil

	for p, data in pairs(room.Scores) do
		if data.Alive then
			activeCount = activeCount + 1
			alivePlayer = p
		end
	end

	if activeCount > 1 then
		if lastDiedPlayer and room.Scores[lastDiedPlayer] then
			RoomUpdateEvent:FireClient(lastDiedPlayer, "EliminatedEarly", {Score = room.Scores[lastDiedPlayer].Score})
		end

	elseif activeCount == 1 and not room.SuddenDeathTriggered then
		room.SuddenDeathTriggered = true
		print("sudden death activated. 5 seconds remaining.")

		RoomUpdateEvent:FireClient(alivePlayer, "SuddenDeath", 5)

		if lastDiedPlayer then
			RoomUpdateEvent:FireClient(lastDiedPlayer, "SuddenDeathWait")
			SpectateEvent:FireClient(lastDiedPlayer, alivePlayer)
		end

		task.delay(5, function()
			if rooms[pin] then
				print("5 seconds elapsed. forcing game end.")
				EndGameNow(pin)
			end
		end)

	elseif activeCount == 0 and room.Status == "Playing" then
		EndGameNow(pin)
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
			local wasAlive = room.Scores[player].Alive
			room.Scores[player].Alive = false
			MatchManager.BroadcastScores(room)
			if wasAlive then MatchManager.CheckWinCondition(pin, player) end
		else
			notifyRoomUpdate(pin, "PlayerLeft")
		end
	end
end

-- marks the player as dead and checks the win condition
function MatchManager.HandleDeath(player)
	local pin = playerRoomMap[player]
	if not pin then return end
	local room = rooms[pin]
	if not room or room.Status ~= "Playing" then return end

	if room.Scores[player] and room.Scores[player].Alive then
		room.Scores[player].Alive = false
		MatchManager.BroadcastScores(room)

		local targetToSpectate = nil
		for _, p in ipairs(room.Players) do
			if p ~= player and room.Scores[p] and room.Scores[p].Alive then
				targetToSpectate = p
				break
			end
		end

		if targetToSpectate then
			SpectateEvent:FireClient(player, targetToSpectate)
		end

		MatchManager.CheckWinCondition(pin, player)
	end
end

-- creates a new room and returns its PIN
function MatchManager.CreateRoom(player)
	MatchManager.RemovePlayer(player)
	local pin = generatePIN()
	rooms[pin] = { Host = player, Players = {player}, Status = "Waiting", Scores = {}, LastActivity = os.time(), SuddenDeathTriggered = false }
	playerRoomMap[player] = pin
	return pin
end

-- adds a player to an existing waiting room
function MatchManager.JoinRoom(player, pin)
	MatchManager.RemovePlayer(player)
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

StartMatchEvent.OnServerEvent:Connect(function(player)
	local pin = playerRoomMap[player]
	local room = rooms[pin]
	if room and room.Host == player and room.Status == "Waiting" then
		room.Status = "Playing"
		room.LastActivity = os.time()
		for _, p in ipairs(room.Players) do
			room.Scores[p] = { Alive = true, Score = 0 }
			RoomUpdateEvent:FireClient(p, "StartGame")
		end
	end
end)

UpdateLiveScore.OnServerEvent:Connect(function(player, newScore)
	local pin = playerRoomMap[player]
	local room = rooms[pin]
	if room and room.Status == "Playing" and room.Scores[player] then
		room.Scores[player].Score = newScore
		MatchManager.BroadcastScores(room)
	end
end)

PlayerDiedEvent.OnServerEvent:Connect(function(player)
	MatchManager.HandleDeath(player)
end)

KickPlayerEvent.OnServerEvent:Connect(function(p, t) MatchManager.KickPlayer(p, t) end)
LeaveRoomEvent.OnServerEvent:Connect(MatchManager.RemovePlayer)
Players.PlayerRemoving:Connect(MatchManager.RemovePlayer)

LobbyRemotes:WaitForChild("CreateRoom").OnServerInvoke = MatchManager.CreateRoom
LobbyRemotes:WaitForChild("JoinRoom").OnServerInvoke = MatchManager.JoinRoom

-- cleans up waiting rooms that have been inactive longer than the timeout
task.spawn(function()
	while true do
		task.wait(60)
		local now = os.time()
		for pin, room in pairs(rooms) do
			if room.Status == "Waiting" and (now - room.LastActivity) > ROOM_TIMEOUT then cleanupRoom(pin) end
		end
	end
end)

return MatchManager
