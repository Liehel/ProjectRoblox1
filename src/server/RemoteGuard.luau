--!strict
-- RemoteGuard: one validated entry point for every RemoteEvent / RemoteFunction.
-- Each call is checked for rate (anti-spam), arg type/range, and authority;
-- failed calls are dropped and the player flagged. Server-only.
--
-- Usage:
--   RemoteGuard.onEvent(remote, { rate = { max = 10, per = 1 },
--       args = { RemoteGuard.is.integer(1, 19) } }, function(player, index) ... end)
--   RemoteGuard.onInvoke(func, { args = { RemoteGuard.is.string(50) } },
--       function(player, name) return ... end)

local Players = game:GetService("Players")

local RemoteGuard = {}

-- If a player exceeds this many violations, kick them. nil = never auto-kick
-- (safer default: just warn in the output, so legit players are never punished
-- for a transient bug). Set e.g. RemoteGuard.KickAfter = 30 once you trust it.
RemoteGuard.KickAfter = nil

-- ────────────────────────────────────────────────────────────────────────
--  Validators  (each returns true if the value is acceptable)
-- ────────────────────────────────────────────────────────────────────────
local is = {}
RemoteGuard.is = is

function is.number(min: number?, max: number?)
	return function(v: any): boolean
		if type(v) ~= "number" then return false end
		if v ~= v or v == math.huge or v == -math.huge then return false end  -- NaN/inf
		if min and v < min then return false end
		if max and v > max then return false end
		return true
	end
end

function is.integer(min: number?, max: number?)
	local numCheck = is.number(min, max)
	return function(v: any): boolean
		return numCheck(v) and math.floor(v) == v
	end
end

function is.string(maxLen: number?)
	return function(v: any): boolean
		if type(v) ~= "string" then return false end
		if maxLen and #v > maxLen then return false end
		return true
	end
end

function is.boolean()
	return function(v: any): boolean
		return type(v) == "boolean"
	end
end

-- A table with at most `maxEntries` top-level keys (blocks oversized-payload DoS).
-- Does not deep-validate; pair it with the handler's own field checks.
function is.table(maxEntries: number?)
	local cap = maxEntries or 64
	return function(v: any): boolean
		if type(v) ~= "table" then return false end
		local n = 0
		for _ in pairs(v) do
			n += 1
			if n > cap then return false end
		end
		return true
	end
end

function is.vector3()
	return function(v: any): boolean
		return typeof(v) == "Vector3"
	end
end

function is.instance(className: string?)
	return function(v: any): boolean
		if typeof(v) ~= "Instance" then return false end
		if className and not v:IsA(className) then return false end
		return true
	end
end

-- value must be one of the allowed entries (table used as a set OR a list)
function is.enum(allowed: {[any]: any})
	-- accept either { "a", "b" } (list) or { a = true } (set)
	local set = {}
	for k, val in pairs(allowed) do
		if type(k) == "number" then set[val] = true else set[k] = true end
	end
	return function(v: any): boolean
		return set[v] == true
	end
end

-- wraps another validator so nil is also accepted
function is.optional(inner: (any) -> boolean)
	return function(v: any): boolean
		return v == nil or inner(v)
	end
end

function is.any()
	return function(_v: any): boolean
		return true
	end
end

-- ────────────────────────────────────────────────────────────────────────
--  Rate limiting + violation tracking
-- ────────────────────────────────────────────────────────────────────────
-- buckets[userId][remote] = { count, windowStart }
local buckets: {[number]: {[Instance]: {count: number, windowStart: number}}} = {}
local strikes: {[number]: number} = {}

local function allowRate(player: Player, remote: Instance, rate: {max: number, per: number}?): boolean
	if not rate then return true end
	local uid = player.UserId
	local now = os.clock()
	local byRemote = buckets[uid]
	if not byRemote then byRemote = {}; buckets[uid] = byRemote end
	local b = byRemote[remote]
	if not b or (now - b.windowStart) >= rate.per then
		byRemote[remote] = { count = 1, windowStart = now }
		return true
	end
	if b.count >= rate.max then
		return false
	end
	b.count += 1
	return true
end

local function flag(player: Player, remote: Instance, reason: string)
	local uid = player.UserId
	strikes[uid] = (strikes[uid] or 0) + 1
	warn(("[RemoteGuard] %s blocked on '%s' (%s) - strike %d")
		:format(player.Name, remote.Name, reason, strikes[uid]))
	if RemoteGuard.KickAfter and strikes[uid] >= RemoteGuard.KickAfter then
		player:Kick("Disconnected: too many invalid requests.")
	end
end

-- run rate + args + authority; returns true if the call should proceed
local function passes(player: Player, remote: Instance, config, packed: {any}, n: number): boolean
	if not allowRate(player, remote, config.rate) then
		flag(player, remote, "rate")
		return false
	end
	if config.args then
		for i, validator in ipairs(config.args) do
			if not validator(packed[i]) then
				flag(player, remote, "arg#" .. i)
				return false
			end
		end
		-- extra args beyond what we validate are ignored by the handler anyway,
		-- so we don't block on them (avoids false positives on legit clients)
	end
	if config.authority and not config.authority(player, table.unpack(packed, 1, n)) then
		flag(player, remote, "authority")
		return false
	end
	return true
end

-- ────────────────────────────────────────────────────────────────────────
--  Public: wire a remote through the guard
-- ────────────────────────────────────────────────────────────────────────
function RemoteGuard.onEvent(remote: RemoteEvent, config, handler)
	remote.OnServerEvent:Connect(function(player, ...)
		local n = select("#", ...)
		local packed = table.pack(...)
		if passes(player, remote, config, packed, n) then
			handler(player, ...)
		end
	end)
end

function RemoteGuard.onInvoke(remote: RemoteFunction, config, handler)
	remote.OnServerInvoke = function(player, ...)
		local n = select("#", ...)
		local packed = table.pack(...)
		if passes(player, remote, config, packed, n) then
			return handler(player, ...)
		end
		return nil  -- safe default for blocked calls
	end
end

-- ────────────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	buckets[player.UserId] = nil
	strikes[player.UserId] = nil
end)

return RemoteGuard
