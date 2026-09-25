local AnalyticsModule = {}

local DataStoreService  = game:GetService("DataStoreService")
local RunService        = game:GetService("RunService")

-- max entries to keep in the time leaderboard per game
local TOP_TIME_TRACK = 10

-- maps a session count to a retention bucket index (1..5)
local function retentionBucket(count)
	if count <= 1 then return 1 end
	if count <= 4 then return 2 end
	if count <= 9 then return 3 end
	if count <= 19 then return 4 end
	return 5
end

-- explicit game id list; kept here to avoid a top-level cross-module require
-- that can cause initialization order issues when servers load in parallel
AnalyticsModule.GAME_IDS = {
	"AvisToucan",
	"FirmamentDefender",
	"FirmamentSiege",
	"FoxyFruit",
	"ImNotASphere",
	"JuiceCutter",
	"Oxybelis",
	"Resilio",
	"TapAndHold",
	"TurrisCasei",
}

-- aggregate storage configuration
local HISTOGRAM_BUCKETS = 20
local TOP_SCORES_COUNT  = 3
local CACHE_TTL         = 30

-- live-feed ring buffers (in-memory, newest first) for the bank ticker boards
local FEED_MAX = 40
AnalyticsModule._recentScores    = {}  -- { {name, gameId, score, t} ... }
AnalyticsModule._recentDonations = {}  -- { {name, gameId, robux, t} ... }

-- inserts an item at the front of a ring buffer and trims to FEED_MAX
local function pushFeed(buffer, item)
	table.insert(buffer, 1, item)
	while #buffer > FEED_MAX do
		table.remove(buffer)
	end
end

-- per-game aggregate cache to reduce datastore reads while dashboards are open
local aggregateCache    = {}
local cacheLastFetched  = {}

local AggregatesStore = nil
local PlayerLogStore  = nil

if RunService:IsServer() then
	-- GetDataStore THROWS when the place is unpublished or Studio API access is
	-- off. At module scope that failure is cached by require(), so every server
	-- script that requires this module fails too - one unguarded line here took
	-- down all ten games at once.
	-- The guards in GetAggregate / ReportSession already handle these being nil,
	-- so degrade quietly instead of exploding.
	local ok, err = pcall(function()
		AggregatesStore = DataStoreService:GetDataStore("Analytics_Aggregates_v1")
		PlayerLogStore  = DataStoreService:GetDataStore("Analytics_PlayerLog_v1")
	end)
	if not ok then
		AggregatesStore, PlayerLogStore = nil, nil
		warn("[Analytics] DataStore unavailable, analytics disabled: " .. tostring(err))
	end
end

-- returns an empty aggregate template
local function newEmptyAggregate()
	return {
		totalSessions    = 0,
		uniquePlayers    = 0,
		totalScore       = 0,
		totalTimePlayed  = 0,
		totalDonations   = 0,
		maxScoreSeen     = 100,
		topScores        = {},
		scoreHistogram   = table.create(HISTOGRAM_BUCKETS, 0),
		levelStats       = {},
		donorTotals      = {},
		topTimePlayers   = {},
		hourlyActivity   = table.create(24, 0),  -- sessions per local hour [1=00h..24=23h]
		dailyActivity    = table.create(7,  0),  -- sessions per weekday [1=Sun..7=Sat]
		retentionBuckets = table.create(5,  0),  -- [1]=1 ses, [2]=2-4, [3]=5-9, [4]=10-19, [5]=20+
		donationHourly   = table.create(24, 0),  -- robux earned per local hour
		donationDaily    = table.create(7,  0),  -- robux earned per weekday
		lastUpdated      = 0
	}
end

-- backfills any missing fields from the template (forward compatibility for old saves)
local function backfill(agg)
	local empty = newEmptyAggregate()
	for k, v in pairs(empty) do
		if agg[k] == nil then agg[k] = v end
	end
	return agg
end

-- reads an aggregate from datastore with a short ttl cache
function AnalyticsModule.GetAggregate(gameId)
	local now = os.clock()
	if aggregateCache[gameId] and (now - (cacheLastFetched[gameId] or 0)) < CACHE_TTL then
		return aggregateCache[gameId]
	end

	if not AggregatesStore then
		warn("[Analytics] AggregatesStore is nil — DataStore not available on this context.")
		aggregateCache[gameId]   = newEmptyAggregate()
		cacheLastFetched[gameId] = now
		return aggregateCache[gameId]
	end

	local ok, data = pcall(function()
		return AggregatesStore:GetAsync("Game_" .. gameId)
	end)

	if not ok then
		warn("[Analytics] GetAsync failed for " .. gameId .. ": " .. tostring(data))
	end

	aggregateCache[gameId]   = (ok and data) and backfill(data) or newEmptyAggregate()
	cacheLastFetched[gameId] = now
	return aggregateCache[gameId]
end

-- invalidates the cache so the next read pulls fresh data
local function invalidate(gameId)
	aggregateCache[gameId]   = nil
	cacheLastFetched[gameId] = nil
end

-- records a finished session and updates the per-game aggregate
function AnalyticsModule.ReportSession(data)
	if not RunService:IsServer() then return end
	if not data or not data.gameId then return end

	if not AggregatesStore then
		warn("[Analytics] ReportSession skipped — AggregatesStore is nil.")
		return
	end

	local userId   = data.userId or 0
	local username = data.username or "Unknown"
	local gameId   = data.gameId
	local score    = math.max(0, math.floor(data.score or 0))
	local timeS    = math.max(0, data.timePlayed or 0)

	-- push to the live scores feed (newest first)
	pushFeed(AnalyticsModule._recentScores, { name = username, gameId = gameId, score = score, t = os.time() })

	-- track per-player session count and capture before/after counts for retention bucket movement
	local isFirstSession   = false
	local newTotalTime     = timeS
	local prevSessionCount = 0
	local newSessionCount  = 1
	local playerKey = tostring(userId) .. "_" .. gameId

	local logOk, logErr = pcall(function()
		PlayerLogStore:UpdateAsync(playerKey, function(existing)
			if not existing then
				isFirstSession   = true
				newTotalTime     = timeS
				prevSessionCount = 0
				newSessionCount  = 1
				return {
					sessionCount  = 1,
					firstPlayedAt = os.time(),
					lastPlayedAt  = os.time(),
					bestScore     = score,
					totalScore    = score,
					totalTime     = timeS
				}
			end
			prevSessionCount = existing.sessionCount or 0
			newSessionCount  = prevSessionCount + 1
			newTotalTime     = (existing.totalTime or 0) + timeS
			return {
				sessionCount  = newSessionCount,
				firstPlayedAt = existing.firstPlayedAt or os.time(),
				lastPlayedAt  = os.time(),
				bestScore     = math.max(existing.bestScore or 0, score),
				totalScore    = (existing.totalScore or 0) + score,
				totalTime     = newTotalTime
			}
		end)
	end)

	if not logOk then
		warn("[Analytics] PlayerLog write failed for " .. gameId .. ": " .. tostring(logErr))
	end

	-- update the aggregate atomically
	local aggOk, aggErr = pcall(function()
		AggregatesStore:UpdateAsync("Game_" .. gameId, function(existing)
			local agg = existing or newEmptyAggregate()

			agg.totalSessions   = (agg.totalSessions or 0) + 1
			if isFirstSession then
				agg.uniquePlayers = (agg.uniquePlayers or 0) + 1
			end
			agg.totalScore      = (agg.totalScore or 0) + score
			agg.totalTimePlayed = (agg.totalTimePlayed or 0) + timeS
			agg.maxScoreSeen    = math.max(agg.maxScoreSeen or 100, score)

			-- bucket the score into the histogram
			local bucketWidth = agg.maxScoreSeen / HISTOGRAM_BUCKETS
			if bucketWidth <= 0 then bucketWidth = 1 end
			local bucketIdx = math.min(HISTOGRAM_BUCKETS, math.max(1, math.floor(score / bucketWidth) + 1))
			agg.scoreHistogram = agg.scoreHistogram or table.create(HISTOGRAM_BUCKETS, 0)
			agg.scoreHistogram[bucketIdx] = (agg.scoreHistogram[bucketIdx] or 0) + 1

			-- maintain top scores ordered descending
			agg.topScores = agg.topScores or {}
			table.insert(agg.topScores, { name = username, score = score, userId = userId })
			table.sort(agg.topScores, function(a, b) return (a.score or 0) > (b.score or 0) end)
			while #agg.topScores > TOP_SCORES_COUNT do
				table.remove(agg.topScores)
			end

			-- per-level stats for games that have levels
			agg.levelStats = agg.levelStats or {}
			if data.levelTimes then
				for level, lt in pairs(data.levelTimes) do
					local key = tostring(level)
					agg.levelStats[key] = agg.levelStats[key] or { timeSum = 0, count = 0 }
					agg.levelStats[key].timeSum = agg.levelStats[key].timeSum + lt
					agg.levelStats[key].count   = agg.levelStats[key].count + 1
				end
			end

			if data.levelReached then
				agg.levelStats["__max"] = agg.levelStats["__max"] or { timeSum = 0, count = 0 }
				if data.levelReached > (agg.levelStats["__max"].count or 0) then
					agg.levelStats["__max"].count = data.levelReached
				end
			end

			-- update top time players using the cumulative time captured above
			agg.topTimePlayers = agg.topTimePlayers or {}
			local timeFound = false
			for _, entry in ipairs(agg.topTimePlayers) do
				if entry.userId == userId then
					entry.totalTime = newTotalTime
					entry.name = username
					timeFound = true
					break
				end
			end
			if not timeFound then
				table.insert(agg.topTimePlayers, { userId = userId, name = username, totalTime = newTotalTime })
			end
			table.sort(agg.topTimePlayers, function(a, b) return (a.totalTime or 0) > (b.totalTime or 0) end)
			while #agg.topTimePlayers > TOP_TIME_TRACK do table.remove(agg.topTimePlayers) end

			-- hour-of-day activity (1=00h, 24=23h)
			agg.hourlyActivity = agg.hourlyActivity or table.create(24, 0)
			local h = tonumber(os.date("%H")) or 0
			local hourIdx = math.clamp(h + 1, 1, 24)
			agg.hourlyActivity[hourIdx] = (agg.hourlyActivity[hourIdx] or 0) + 1

			-- day-of-week activity (1=Sunday .. 7=Saturday)
			agg.dailyActivity = agg.dailyActivity or table.create(7, 0)
			local wday = tonumber(os.date("%w")) or 0  -- 0=Sun..6=Sat
			local dayIdx = math.clamp(wday + 1, 1, 7)
			agg.dailyActivity[dayIdx] = (agg.dailyActivity[dayIdx] or 0) + 1

			-- retention buckets: move the player between buckets based on prev/new session count
			agg.retentionBuckets = agg.retentionBuckets or table.create(5, 0)
			if prevSessionCount > 0 then
				local prevB = retentionBucket(prevSessionCount)
				agg.retentionBuckets[prevB] = math.max(0, (agg.retentionBuckets[prevB] or 0) - 1)
			end
			local newB = retentionBucket(newSessionCount)
			agg.retentionBuckets[newB] = (agg.retentionBuckets[newB] or 0) + 1

			agg.lastUpdated = os.time()
			return agg
		end)
	end)

	if aggOk then
		print("[Analytics] session saved: " .. gameId .. " score=" .. score .. " time=" .. string.format("%.1f", timeS))
	else
		warn("[Analytics] aggregate write failed for " .. gameId .. ": " .. tostring(aggErr))
	end

	invalidate(gameId)
end

-- records a donation purchase against the game that received it
function AnalyticsModule.ReportDonation(data)
	if not RunService:IsServer() then return end
	if not data or not data.gameId then return end

	local robux = math.max(0, math.floor(data.robuxAmount or 0))
	if robux == 0 then return end

	local userId   = data.userId or 0
	local username = data.username or ("User_" .. tostring(userId))

	-- push to the live donations feed (newest first)
	pushFeed(AnalyticsModule._recentDonations, { name = username, gameId = data.gameId, robux = robux, t = os.time() })

	local ok, err = pcall(function()
		AggregatesStore:UpdateAsync("Game_" .. data.gameId, function(existing)
			local agg = existing or newEmptyAggregate()
			agg.totalDonations = (agg.totalDonations or 0) + robux

			agg.donorTotals = agg.donorTotals or {}
			local key = tostring(userId)
			local entry = agg.donorTotals[key] or { name = username, total = 0 }
			entry.name  = username
			entry.total = entry.total + robux
			agg.donorTotals[key] = entry

			-- revenue by hour of day (1=00h, 24=23h)
			agg.donationHourly = agg.donationHourly or table.create(24, 0)
			local h = tonumber(os.date("%H")) or 0
			local hourIdx = math.clamp(h + 1, 1, 24)
			agg.donationHourly[hourIdx] = (agg.donationHourly[hourIdx] or 0) + robux

			-- revenue by weekday (1=Sunday .. 7=Saturday)
			agg.donationDaily = agg.donationDaily or table.create(7, 0)
			local wday = tonumber(os.date("%w")) or 0
			local dayIdx = math.clamp(wday + 1, 1, 7)
			agg.donationDaily[dayIdx] = (agg.donationDaily[dayIdx] or 0) + robux

			agg.lastUpdated = os.time()
			return agg
		end)
	end)

	if not ok then
		warn("[Analytics] donation write failed for " .. data.gameId .. ": " .. tostring(err))
	end

	invalidate(data.gameId)
end

-- one-liner used by game servers: spawns a non-blocking session report
function AnalyticsModule.ReportSessionAsync(player, gameId, score, timeSec, extras)
	task.spawn(function()
		local payload = {
			userId     = player and player.UserId or 0,
			username   = player and player.Name or "Unknown",
			gameId     = gameId,
			score      = score,
			timePlayed = timeSec
		}
		if extras then
			payload.levelReached = extras.levelReached
			payload.levelTimes   = extras.levelTimes
		end
		AnalyticsModule.ReportSession(payload)
	end)
end

-- one-liner used by game servers: spawns a non-blocking donation report from a receipt
function AnalyticsModule.ReportDonationAsync(gameId, receiptInfo)
	if not receiptInfo then return end
	task.spawn(function()
		local Players  = game:GetService("Players")
		local userId   = receiptInfo.PlayerId
		local username = "User_" .. tostring(userId)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			username = player.Name
		else
			local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
			if ok and name then username = name end
		end
		AnalyticsModule.ReportDonation({
			userId      = userId,
			username    = username,
			gameId      = gameId,
			robuxAmount = receiptInfo.CurrencySpent or 0
		})
	end)
end

-- estimates the median by interpolating the histogram
function AnalyticsModule.ComputeMedian(agg)
	if not agg or agg.totalSessions == 0 then return 0 end
	local half = agg.totalSessions / 2
	local running = 0
	local bucketWidth = agg.maxScoreSeen / HISTOGRAM_BUCKETS
	for i = 1, HISTOGRAM_BUCKETS do
		local count = agg.scoreHistogram[i] or 0
		if running + count >= half then
			local needed = half - running
			local frac = count > 0 and (needed / count) or 0
			return math.floor((i - 1 + frac) * bucketWidth)
		end
		running = running + count
	end
	return math.floor(agg.maxScoreSeen)
end

-- builds the dashboard payload for a single game
function AnalyticsModule.GetGameDashboard(gameId)
	local agg = AnalyticsModule.GetAggregate(gameId)

	local sessions  = agg.totalSessions
	local avgScore  = sessions > 0 and (agg.totalScore / sessions) or 0
	local avgTime   = sessions > 0 and (agg.totalTimePlayed / sessions) or 0
	local replay    = agg.uniquePlayers > 0 and (sessions / agg.uniquePlayers) or 0

	local levelStats = {}
	local maxLevelReached = 0
	for key, stats in pairs(agg.levelStats) do
		if key == "__max" then
			maxLevelReached = stats.count or 0
		else
			local level = tonumber(key)
			if level then
				levelStats[level] = {
					avgTime = stats.count > 0 and (stats.timeSum / stats.count) or 0,
					count   = stats.count
				}
			end
		end
	end

	local topDonors = {}
	for _, info in pairs(agg.donorTotals or {}) do
		table.insert(topDonors, { name = info.name, total = info.total })
	end
	table.sort(topDonors, function(a, b) return (a.total or 0) > (b.total or 0) end)
	while #topDonors > 3 do table.remove(topDonors) end

	-- top time players (cumulative across all sessions)
	local topTimePlayers = {}
	for _, entry in ipairs(agg.topTimePlayers or {}) do
		if #topTimePlayers >= 3 then break end
		table.insert(topTimePlayers, { name = entry.name, totalTime = entry.totalTime })
	end

	return {
		gameId           = gameId,
		totalSessions    = sessions,
		uniquePlayers    = agg.uniquePlayers,
		avgScore         = avgScore,
		medianScore      = AnalyticsModule.ComputeMedian(agg),
		avgTime          = avgTime,
		totalTimePlayed  = agg.totalTimePlayed,
		replayRate       = replay,
		topScores        = agg.topScores,
		topDonors        = topDonors,
		topTimePlayers   = topTimePlayers,
		totalDonations   = agg.totalDonations,
		scoreHistogram   = agg.scoreHistogram,
		maxScoreSeen     = agg.maxScoreSeen,
		levelStats       = levelStats,
		maxLevelReached  = maxLevelReached,
		hourlyActivity   = agg.hourlyActivity or table.create(24, 0),
		dailyActivity    = agg.dailyActivity or table.create(7, 0),
		retentionBuckets = agg.retentionBuckets or table.create(5, 0),
		donationHourly   = agg.donationHourly or table.create(24, 0),
		donationDaily    = agg.donationDaily or table.create(7, 0),
		lastUpdated      = agg.lastUpdated
	}
end

-- builds an overview snapshot of every tracked game with cross-game aggregations
function AnalyticsModule.GetGeneralDashboard()
	local games          = {}
	local hourTotal      = table.create(24, 0)
	local dayTotal       = table.create(7,  0)
	local retentionTotal = table.create(5,  0)

	for _, gameId in ipairs(AnalyticsModule.GAME_IDS) do
		local dash = AnalyticsModule.GetGameDashboard(gameId)
		table.insert(games, dash)

		-- aggregate hour/day/retention across all games
		for i = 1, 24 do hourTotal[i] = hourTotal[i] + (dash.hourlyActivity[i] or 0) end
		for i = 1,  7 do dayTotal[i]  = dayTotal[i]  + (dash.dailyActivity[i]  or 0) end
		for i = 1,  5 do retentionTotal[i] = retentionTotal[i] + (dash.retentionBuckets[i] or 0) end
	end

	return {
		games            = games,
		hourlyActivity   = hourTotal,
		dailyActivity    = dayTotal,
		retentionBuckets = retentionTotal,
	}
end

-- builds the revenue-focused snapshot used by the money dashboard
function AnalyticsModule.GetMoneyDashboard()
	local games = {}
	local totalRevenue, totalTime, totalSessions = 0, 0, 0
	local hourTotal = table.create(24, 0)  -- robux earned per hour across all games
	local dayTotal  = table.create(7,  0)  -- robux earned per weekday across all games

	for _, gameId in ipairs(AnalyticsModule.GAME_IDS) do
		local dash = AnalyticsModule.GetGameDashboard(gameId)
		local revenue = dash.totalDonations
		local hoursPlayed = dash.totalTimePlayed / 3600
		local revPerHour = hoursPlayed > 0 and (revenue / hoursPlayed) or 0

		table.insert(games, {
			gameId           = gameId,
			revenue          = revenue,
			sessions         = dash.totalSessions,
			avgTime          = dash.avgTime,
			totalTimePlayed  = dash.totalTimePlayed,
			revenuePerHour   = revPerHour,
			revenuePerPlayer = dash.uniquePlayers > 0 and (revenue / dash.uniquePlayers) or 0,
			donationHourly   = dash.donationHourly,
			uniquePlayers    = dash.uniquePlayers
		})

		totalRevenue  = totalRevenue + revenue
		totalTime     = totalTime + dash.totalTimePlayed
		totalSessions = totalSessions + dash.totalSessions

		-- aggregate revenue-by-time across all games
		for i = 1, 24 do hourTotal[i] = hourTotal[i] + (dash.donationHourly[i] or 0) end
		for i = 1,  7 do dayTotal[i]  = dayTotal[i]  + (dash.donationDaily[i]  or 0) end
	end

	return {
		games          = games,
		totalRevenue   = totalRevenue,
		totalTime      = totalTime,
		totalSessions  = totalSessions,
		donationHourly = hourTotal,
		donationDaily  = dayTotal,
	}
end

-- returns the live donations feed (newest first) for the RealMoney board
function AnalyticsModule.GetRecentDonations()
	local out = {}
	for i, e in ipairs(AnalyticsModule._recentDonations) do
		out[i] = { name = e.name, gameId = e.gameId, robux = e.robux, t = e.t }
	end
	return out
end

-- returns the live scores feed (newest first) for the RealPlayer board
function AnalyticsModule.GetRecentScores()
	local out = {}
	for i, e in ipairs(AnalyticsModule._recentScores) do
		out[i] = { name = e.name, gameId = e.gameId, score = e.score, t = e.t }
	end
	return out
end

return AnalyticsModule
