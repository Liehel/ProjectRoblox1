local DataStoreService = game:GetService("DataStoreService")

local UniversalLeaderboard = {}
UniversalLeaderboard.Scores = {}
UniversalLeaderboard.Stores = {}

local MAX_STORED_ENTRIES = 50

-- per-game display config and leaderboard color palettes
UniversalLeaderboard.GAMES_CONFIG = {
	AvisToucan = {
		Title = "Avis Toucan",
		Icon = "🐦",
		DataKey = "AvisToucanScores_v1",
		Palette = {
			BorderColor     = "004f3b",
			GlassColor      = "5ee9b5",
			Header          = "5ee9b5",
			RowEven         = "00bc7d",
			RowOdd          = "006045",
			LocalPlayer     = "a4f4cf",
			TextLight       = "ecfdf5",
			TitleMain       = "083c2c",
			TitlePulse      = "012a21",
			HeaderTextCol   = "083c2c",
			SpecialTextCol  = "ecfdf5"
		}
	},

	TapAndHold = {
		Title = "Tap And Hold",
		Icon = "🚀",
		DataKey = "TapAndHoldScores_v1",
		Palette = {
			BorderColor     = "422006",
			GlassColor      = "fecdd3",
			Header          = "be123c",
			RowEven         = "fb7185",
			RowOdd          = "f43f5e",
			LocalPlayer     = "e11d48",
			TextLight       = "ffffff",
			TitleMain       = "be123c",
			TitlePulse      = "f43f5e",
			TitlePulseAlt   = "e11d48",
			HeaderTextCol   = "ffffff",
			SpecialTextCol  = "4c0519",
			GlassTransp     = 0.0,
			HeaderTransp    = 0.0,
			RowEvenTransp   = 0.15,
			RowOddTransp    = 0.15,
			LocalTransp     = 0.15
		}
	},

	ImNotASphere = {
		Title = "Im Not A Sphere",
		Icon = "🎱",
		DataKey = "ImNotASphereScores_v1",
		Palette = {
			BorderColor     = "422006",
			GlassColor      = "fecdd3",
			Header          = "be123c",
			RowEven         = "fb7185",
			RowOdd          = "f43f5e",
			LocalPlayer     = "e11d48",
			TextLight       = "ffffff",
			TitleMain       = "be123c",
			TitlePulse      = "f43f5e",
			TitlePulseAlt   = "e11d48",
			HeaderTextCol   = "ffffff",
			SpecialTextCol  = "4c0519",
			GlassTransp     = 0.0,
			HeaderTransp    = 0.0,
			RowEvenTransp   = 0.15,
			RowOddTransp    = 0.15,
			LocalTransp     = 0.15
		}
	},

	TurrisCasei = {
		Title = "Turris Casei",
		Icon = "🧀",
		DataKey = "TurrisCaseiScores_v1",
		Palette = {
			BorderColor     = "422006",
			GlassColor      = "fef08a",
			Header          = "ca8a04",
			RowEven         = "fde047",
			RowOdd          = "facc15",
			LocalPlayer     = "eab308",
			TextLight       = "ffffff",
			TitleMain       = "ca8a04",
			TitlePulse      = "eab308",
			TitlePulseAlt   = "facc15",
			HeaderTextCol   = "ffffff",
			SpecialTextCol  = "422006",
			GlassTransp     = 0.0,
			HeaderTransp    = 0.0,
			RowEvenTransp   = 0.15,
			RowOddTransp    = 0.15,
			LocalTransp     = 0.15
		}
	},

	Oxybelis = {
		Title = "Oxybelis",
		Icon = "🐍",
		DataKey = "OxybelisScores_v1",
		Palette = {
			BorderColor     = "000000",
			GlassColor      = "047857",
			Header          = "497d00",
			RowEven         = "35530e",
			RowOdd          = "192e03",
			LocalPlayer     = "9ae600",
			TextLight       = "ffffff",
			TitleMain       = "f7fee7",
			TitlePulse      = "bbf451",
			HeaderTextCol   = "192e03",
			SpecialTextCol  = "192e03"
		}
	},

	Resilio = {
		Title = "RESILIO",
		Icon = "🧱",
		DataKey = "ResilioScores_v1",
		Palette = {
			BorderColor     = "2a0a18",
			GlassColor      = "fce7f3",
			Header          = "e60076",
			RowEven         = "c6005c",
			RowOdd          = "861043",
			LocalPlayer     = "f6339a",
			TextLight       = "ffffff",
			TitleMain       = "ffffff",
			TitlePulse      = "fda5d5",
			HeaderTextCol   = "ffffff",
			SpecialTextCol  = "861043"
		}
	},

	FoxyFruit = {
		Title = "Foxy Fruit",
		Icon = "🦊",
		DataKey = "FoxyFruitScores_v1",
		Palette = {
			BorderColor     = "172554",
			GlassColor      = "1e3a8a",
			Header          = "2563eb",
			RowEven         = "1e40af",
			RowOdd          = "2563eb",
			LocalPlayer     = "38bdf8",
			TextLight       = "dbeafe",
			TitleMain       = "dbeafe",
			TitlePulse      = "93c5fd",
			HeaderTextCol   = "082f49",
			SpecialTextCol  = "dbeafe"
		}
	},

	FirmamentDefender = {
		Title = "Firmament Defender",
		Icon = "✈️",
		DataKey = "FirmamentDefenderScores_v1",
		Palette = {
			BorderColor     = "000000",
			GlassColor      = "FFD6A7",
			Header          = "FF6900",
			RowEven         = "7E2A0C",
			RowOdd          = "CA3500",
			LocalPlayer     = "FF8904",
			TextLight       = "FFFFFF",
			TitleMain       = "9F2D00",
			TitlePulse      = "FF8904",
			TitlePulseAlt   = "441306",
			HeaderTextCol   = "441306",
			SpecialTextCol  = "FFFFFF",
			GlassTransp     = 0.0,
			HeaderTransp    = 0.0,
			RowEvenTransp   = 0.25,
			RowOddTransp    = 0.30,
			LocalTransp     = 0.15
		}
	},

	FirmamentSiege = {
		Title = "FIRMAMENT SIEGE",
		Icon = "✈️",
		DataKey = "FirmamentSiegeScores_v1",
		Palette = {
			BorderColor     = "000000",
			GlassColor      = "FFD6A7",
			Header          = "FF6900",
			RowEven         = "7E2A0C",
			RowOdd          = "CA3500",
			LocalPlayer     = "FF8904",
			TextLight       = "FFFFFF",
			TitleMain       = "9F2D00",
			TitlePulse      = "FF8904",
			TitlePulseAlt   = "441306",
			HeaderTextCol   = "441306",
			SpecialTextCol  = "FFFFFF",
			GlassTransp     = 0.0,
			HeaderTransp    = 0.0,
			RowEvenTransp   = 0.25,
			RowOddTransp    = 0.30,
			LocalTransp     = 0.15
		}
	},

	JuiceCutter = {
		Title = "JUICE CUTTER",
		Icon = "🍑",
		DataKey = "JuiceCutterScores_v1",
		Palette = {
			BorderColor     = "000000",
			GlassColor      = "faf5ff",
			Header          = "7e22ce",
			RowEven         = "581c87",
			RowOdd          = "6b21a8",
			LocalPlayer     = "a855f7",
			TextLight       = "ffffff",
			TitleMain       = "4c1d95",
			TitlePulse      = "7c3aed",
			TitlePulseAlt   = "8b5cf6",
			HeaderTextCol   = "ffffff",
			SpecialTextCol  = "ffffff",
			GlassTransp     = 0.0,
			HeaderTransp    = 0.0,
			RowEvenTransp   = 0.15,
			RowOddTransp    = 0.15,
			LocalTransp     = 0.15
		}
	}
}

-- opens a datastore for each game and loads any previously saved scores
function UniversalLeaderboard:Init()
	for gameId, config in pairs(self.GAMES_CONFIG) do
		self.Scores[gameId] = {}
		local success, store = pcall(function()
			return DataStoreService:GetDataStore(config.DataKey)
		end)

		if success then
			self.Stores[gameId] = store
			local ok, data = pcall(function() return store:GetAsync(config.DataKey) end)
			if ok and data then
				self.Scores[gameId] = data
				print("leaderboard loaded " .. gameId .. ": " .. #data .. " entries.")
			else
				print("no saved data for " .. gameId)
			end
		else
			warn("could not connect datastore for: " .. gameId)
		end
	end
end

-- returns true if the new score beats the existing one; uses time as a tiebreaker
local function isBetter(newScore, newTimeMs, oldScore, oldTimeMs)
	if newScore > oldScore then return true end
	if newScore < oldScore then return false end
	return newTimeMs < oldTimeMs
end

-- submits a score for a player; updates if better, sorts, trims, and persists
function UniversalLeaderboard:ReportScore(gameId, player, score, timeMs)
	if not self.Scores[gameId] then return end

	local userId = player.UserId
	local displayName = player.DisplayName or player.Name
	score = score or 0
	timeMs = timeMs or 0

	local existing
	for _, entry in ipairs(self.Scores[gameId]) do
		if entry.userId == userId then
			existing = entry
			break
		end
	end

	local updated = false

	if existing then
		if isBetter(score, timeMs, existing.score, existing.timeMs) then
			existing.score = score
			existing.timeMs = timeMs
			existing.name = displayName
			updated = true
		end
	else
		table.insert(self.Scores[gameId], {
			userId = userId, name = displayName, score = score, timeMs = timeMs
		})
		updated = true
	end

	if updated then
		table.sort(self.Scores[gameId], function(a, b)
			if a.score ~= b.score then return a.score > b.score end
			if a.timeMs ~= b.timeMs then return a.timeMs < b.timeMs end
			return a.userId < b.userId
		end)

		if #self.Scores[gameId] > MAX_STORED_ENTRIES then
			for i = #self.Scores[gameId], MAX_STORED_ENTRIES + 1, -1 do
				table.remove(self.Scores[gameId], i)
			end
		end

		local store = self.Stores[gameId]
		local key = self.GAMES_CONFIG[gameId].DataKey
		if store then
			task.spawn(function()
				pcall(function() store:SetAsync(key, self.Scores[gameId]) end)
			end)
		end
	end
	return self:GetTop(gameId, 10)
end

-- returns the top N entries for a game as a position-annotated list
function UniversalLeaderboard:GetTop(gameId, maxEntries)
	maxEntries = maxEntries or 10
	local top = {}
	if not self.Scores[gameId] then return top end

	local limit = math.min(maxEntries, #self.Scores[gameId])
	for i = 1, limit do
		local e = self.Scores[gameId][i]
		top[i] = { position = i, userId = e.userId, name = e.name, score = e.score, timeMs = e.timeMs }
	end
	return top
end

-- returns a player's own entry with its real position, even if outside the top 10
-- (the score list is kept sorted, so the array index is the rank). returns nil if unranked.
function UniversalLeaderboard:GetPlayerRank(gameId, userId)
	if not self.Scores[gameId] then return nil end
	for i, e in ipairs(self.Scores[gameId]) do
		if e.userId == userId then
			return { position = i, userId = e.userId, name = e.name, score = e.score, timeMs = e.timeMs }
		end
	end
	return nil
end

return UniversalLeaderboard
