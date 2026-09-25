--!strict
-- Server-authoritative fireworks economy. Launches go through canLaunch/commit.
-- Everyone: 3 normal (1-16) launches/min, +1 free firework/min (inventory cap 8),
-- 1/100 raffle/min for big ones, +2 big at 8 min, all-access (6 uses) at 15 min.
-- VIP (owns the Game Pass): +3 free launches of any firework every 3 minutes.

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local FireworksModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FireworksModule"))

local Inv = {}

-- config (tunable)
local VIP_GAMEPASS_ID   = FireworksModule.VipGamePassId or 0
local NORMAL_PER_MIN    = 3
local INV_CAP           = 8
local RAFFLE_CHANCE     = 1 / 100
local RAFFLE_REWARD     = 3
local GIFT_PER_MIN      = 1
local REWARD_8MIN       = 2
local ALL_ACCESS_USES   = 6
local MILESTONE_8       = 8 * 60
local MILESTONE_15      = 15 * 60
local ALL_ACCESS_EXPIRE = 15 * 60
local VIP_FREE_PER_CYCLE = 3        -- free "any firework" launches for VIPs...
local VIP_CYCLE          = 3 * 60   -- ...every 3 minutes

-- big = comet/mega/explosion
local bigSet, normalIndices, bigIndices = {}, {}, {}
for i, def in ipairs(FireworksModule.Types) do
	if def.kind == "comet" or def.kind == "mega" or def.kind == "explosion" then
		bigSet[i] = true
		table.insert(bigIndices, i)
	else
		table.insert(normalIndices, i)
	end
end
local function isBig(index: number) return bigSet[index] == true end
local function randomNormal() return normalIndices[math.random(1, #normalIndices)] end
local function randomBig() return bigIndices[math.random(1, #bigIndices)] end

local state = {}        -- [player] = { ... }
local notifyRemote      -- server -> client on-screen messages
local availRemote       -- server -> client per-type availability (for menu greying)

function Inv.SetNotifier(remote) notifyRemote = remote end
function Inv.SetAvailabilityRemote(remote) availRemote = remote end

local function notify(player, msg)
	if notifyRemote then notifyRemote:FireClient(player, msg) end
end

-- send which fireworks the player can currently launch (for the menu UI)
local function pushAvailability(player)
	if not availRemote then return end
	if not state[player] then return end
	local avail = {}
	for i = 1, #FireworksModule.Types do
		avail[i] = (Inv.canLaunch(player, i)) == true
	end
	availRemote:FireClient(player, avail)
end

local function name(index)
	local d = FireworksModule.Types[index]
	return d and (d.name .. "  #" .. index) or ("#" .. index)
end

local function grant(player, index, announce)
	local st = state[player]
	if not st then return false end
	if #st.inv >= INV_CAP then return false end  -- full, drop
	table.insert(st.inv, index)
	if announce ~= false then notify(player, "You received: " .. name(index)) end
	return true
end

local function resetCycle(st)
	st.cycleStart = os.clock()
	st.got8 = false
	st.allAccess = nil
end

-- VIP detection (permanent Game Pass)
local function grantVIP(st, player, announce)
	st.isVIP = true
	st.vipFree = VIP_FREE_PER_CYCLE
	st.vipCycleStart = os.clock()
	player:SetAttribute("FireworksVIP", true)  -- client reads this to show VIP state
	if announce then
		notify(player, "VIP pass active: " .. VIP_FREE_PER_CYCLE .. " free launches every 3 min")
	end
	pushAvailability(player)
end

local function checkVIP(player)
	if VIP_GAMEPASS_ID <= 0 then return end
	task.spawn(function()
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
		end)
		if ok and owns and state[player] and not state[player].isVIP then
			grantVIP(state[player], player, false)
		end
	end)
end

-- flips VIP on if bought mid-session; re-verifies ownership (defense in depth)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or passId ~= VIP_GAMEPASS_ID or not state[player] then return end
	task.spawn(function()
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
		end)
		if ok and owns and state[player] then
			grantVIP(state[player], player, true)
		end
	end)
end)

-- player lifecycle
local function initPlayer(player)
	if state[player] then return end
	state[player] = {
		normal       = NORMAL_PER_MIN,
		inv          = {},
		isVIP        = false,
		vipFree      = 0,
		vipCycleStart = os.clock(),
		cycleStart   = os.clock(),
		got8         = false,
		allAccess    = nil,
	}
	checkVIP(player)
	task.delay(2, function() pushAvailability(player) end)  -- after client loads
end

Players.PlayerAdded:Connect(initPlayer)
for _, p in ipairs(Players:GetPlayers()) do initPlayer(p) end
Players.PlayerRemoving:Connect(function(player) state[player] = nil end)

-- Launch gating. Priority: all-access -> inventory item -> normal quota (1-16) ->
-- VIP free (any). Normals spend the free quota first, saving VIP for big ones.
function Inv.canLaunch(player, index)
	local st = state[player]
	if not st then return false, "Please wait..." end
	if st.allAccess and st.allAccess.uses > 0 then return true end
	if table.find(st.inv, index) then return true end
	if not isBig(index) and st.normal > 0 then return true end
	if st.isVIP and st.vipFree > 0 then return true end
	if isBig(index) then
		return false, "Big fireworks: get the VIP pass or win one"
	end
	return false, "No launches left this minute (max " .. NORMAL_PER_MIN .. ")"
end

function Inv.commit(player, index)
	local st = state[player]
	if not st then return end
	if st.allAccess and st.allAccess.uses > 0 then
		st.allAccess.uses -= 1
		if st.allAccess.uses <= 0 then
			st.allAccess = nil
			resetCycle(st)
			notify(player, "All access used up - timer reset.")
		end
		pushAvailability(player)
		return
	end
	local invIdx = table.find(st.inv, index)
	if invIdx then table.remove(st.inv, invIdx); pushAvailability(player); return end
	if not isBig(index) and st.normal > 0 then
		st.normal -= 1
		pushAvailability(player)
		return
	end
	if st.isVIP and st.vipFree > 0 then
		st.vipFree -= 1
	end
	pushAvailability(player)
end

-- per-minute tick
local function tickPlayer(player)
	local st = state[player]
	if not st then return end

	st.normal = NORMAL_PER_MIN                       -- refresh normal quota
	for _ = 1, GIFT_PER_MIN do grant(player, randomNormal()) end  -- free gift

	if math.random() < RAFFLE_CHANCE then            -- raffle
		for _ = 1, RAFFLE_REWARD do grant(player, randomBig(), false) end
		notify(player, "You won the raffle! +" .. RAFFLE_REWARD .. " big fireworks")
	end

	-- VIP freedom every 3 minutes
	if st.isVIP and (os.clock() - st.vipCycleStart) >= VIP_CYCLE then
		st.vipFree = VIP_FREE_PER_CYCLE
		st.vipCycleStart = os.clock()
		notify(player, "VIP: " .. VIP_FREE_PER_CYCLE .. " free launches refreshed")
	end

	-- time milestones
	local elapsed = os.clock() - st.cycleStart
	if not st.got8 and elapsed >= MILESTONE_8 then
		st.got8 = true
		for _ = 1, REWARD_8MIN do grant(player, randomBig(), false) end
		notify(player, "8 minutes: +" .. REWARD_8MIN .. " big fireworks")
	end
	if not st.allAccess and elapsed >= MILESTONE_15 then
		st.inv = {}
		st.allAccess = { uses = ALL_ACCESS_USES, grantedAt = os.clock() }
		notify(player, "15 min: ALL ACCESS - " .. ALL_ACCESS_USES .. " uses of any firework")
	end
	if st.allAccess and (os.clock() - st.allAccess.grantedAt) >= ALL_ACCESS_EXPIRE then
		st.allAccess = nil
		resetCycle(st)
		notify(player, "All access expired unused - reset.")
	end

	pushAvailability(player)
end

-- push current availability on demand (e.g. when the player opens the menu)
function Inv.RefreshAvailability(player)
	pushAvailability(player)
end

function Inv.Start()
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pairs(state) do tickPlayer(player) end
		end
	end)
end

return Inv
