-- Blanket anti-flood net. Counts every RemoteEvent call per player and kicks
-- anyone firing far faster than a human could. Safety net for remotes not wrapped
-- in RemoteGuard; it only counts, so it can't break gameplay.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Tuning ────────────────────────────────────────────────────────────────
local WINDOW       = 1.0   -- seconds per measurement bucket
local MAX_PER_SEC  = 100   -- total remote calls/sec a player may make (generous)
local STRIKES_KICK = 3     -- consecutive over-limit windows before a kick
local AUTO_KICK    = true  -- set false to only warn in the output

-- ── State ─────────────────────────────────────────────────────────────────
local counts:  {[number]: number} = {}  -- userId -> calls in current window
local strikes: {[number]: number} = {}  -- userId -> consecutive bad windows

-- ── Window reset loop ─────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(WINDOW)
		for uid, c in pairs(counts) do
			if c > MAX_PER_SEC then
				strikes[uid] = (strikes[uid] or 0) + 1
				local player = Players:GetPlayerByUserId(uid)
				local name = player and player.Name or ("uid " .. uid)
				warn(("[RemoteWatchdog] %s flooding: %d calls/s (strike %d/%d)")
					:format(name, c, strikes[uid], STRIKES_KICK))
				if AUTO_KICK and player and strikes[uid] >= STRIKES_KICK then
					player:Kick("Disconnected: abnormal request rate.")
				end
			else
				strikes[uid] = 0  -- behaving again
			end
		end
		table.clear(counts)
	end
end)

-- ── Attach a counter to every RemoteEvent ─────────────────────────────────
local function watch(remote: Instance)
	if not remote:IsA("RemoteEvent") then return end
	remote.OnServerEvent:Connect(function(player)
		local uid = player.UserId
		counts[uid] = (counts[uid] or 0) + 1
	end)
end

for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
	watch(inst)
end
ReplicatedStorage.DescendantAdded:Connect(watch)

Players.PlayerRemoving:Connect(function(player)
	counts[player.UserId] = nil
	strikes[player.UserId] = nil
end)
