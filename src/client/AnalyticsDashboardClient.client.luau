local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local CollectionService    = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local GuiService           = game:GetService("GuiService")
local Lighting             = game:GetService("Lighting")
local RunService           = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ChartEngine          = require(Modules:WaitForChild("ChartEngine"))
local UniversalLeaderboard = require(Modules:WaitForChild("UniversalLeaderboardModule"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ----------------------------------------------------------------------------
-- layout & font constants  (canvas = 1600 x 900)
-- ----------------------------------------------------------------------------

local SW, SH = 1600, 900
local MARGIN  = 32

-- font sizes  (generous — SurfaceGui shrinks physical parts)
local FS = {
	header   = 96,   subhead  = 30,
	cardVal  = 82,   cardCap  = 26,
	secTitle = 30,
	rankName = 34,   rankVal  = 38,
	donAmt   = 72,   donSub   = 24,
	contTtl  = 28,
	tick     = 22,   footer   = 24,
}

-- stat card row
local STAT_W, STAT_H = 282, 168
local STAT_GAP        = 16
local STAT_Y          = 204
local STAT_COUNT      = 5
-- centered: (1600 - (5*282 + 4*16)) / 2 = 63
local STAT_START_X    = math.floor((SW - (STAT_COUNT * STAT_W + (STAT_COUNT-1) * STAT_GAP)) / 2)

-- content area
local CONT_Y  = STAT_Y + STAT_H + 20   -- 368
local CONT_H  = SH - CONT_Y - 36       -- 496

-- left / right split
local LEFT_W   = 848
local RIGHT_X  = MARGIN + LEFT_W + STAT_GAP   -- 896
local RIGHT_W  = SW - RIGHT_X - MARGIN        -- 672
local R_HALF   = math.floor((RIGHT_W - STAT_GAP) / 2)  -- 328

-- right column rows
local RIGHT_H1  = 220   -- top: scores + time players
local RIGHT_GAP = 14
local RIGHT_H2  = CONT_H - RIGHT_H1 - RIGHT_GAP  -- bottom: donations + donors

-- face default
local DEFAULT_FACE = Enum.NormalId.Front

-- how close (studs) the player must be to open a board by clicking it
local OPEN_DISTANCE = 16

local META_LABELS = {
	General    = "GAMES OVERVIEW",
	Money      = "REVENUE ANALYTICS",
	RealMoney  = "LIVE DONATIONS",
	MoneyG     = "REVENUE BY GAME",
	RealPlayer = "LIVE SCORES",
}

-- boards that show a live scrolling ticker feed
local FEED_BOARDS = { RealMoney = true, RealPlayer = true }

local LEVEL_GAMES = {
	JuiceCutter = true, FoxyFruit = true,
	FirmamentDefender = true, Resilio = true,
}

local MEDALS       = { "1ST", "2ND", "3RD" }
local MEDAL_COLORS -- forward-declared

local PALETTE = ChartEngine.Palette

-- fills in MEDAL_COLORS after PALETTE is available
MEDAL_COLORS = { PALETTE.gold, PALETTE.silver, PALETTE.bronze }

local function labelFor(gameId)
	if META_LABELS[gameId] then return META_LABELS[gameId] end
	local cfg = UniversalLeaderboard.GAMES_CONFIG[gameId]
	return cfg and string.upper(cfg.Title) or gameId
end

-- ----------------------------------------------------------------------------
-- remotes
-- ----------------------------------------------------------------------------

local AnalyticsFolder = ReplicatedStorage:WaitForChild("AnalyticsRemotes", 10)
if not AnalyticsFolder then
	warn("[Analytics] remote folder missing.")
	return
end

local GetGameDashboard    = AnalyticsFolder:WaitForChild("GetGameDashboard", 10)
local GetGeneralDashboard = AnalyticsFolder:WaitForChild("GetGeneralDashboard", 10)
local GetMoneyDashboard   = AnalyticsFolder:WaitForChild("GetMoneyDashboard", 10)
local GetRecentDonations  = AnalyticsFolder:WaitForChild("GetRecentDonations", 10)
local GetRecentScores     = AnalyticsFolder:WaitForChild("GetRecentScores", 10)
local DashboardUpdated    = AnalyticsFolder:WaitForChild("DashboardUpdated", 10)

-- ----------------------------------------------------------------------------
-- format helpers
-- ----------------------------------------------------------------------------

local function fmtNum(n)
	if not n then return "0" end
	n = math.floor(n + 0.5)
	local s, result, count = tostring(n), "", 0
	for i = #s, 1, -1 do
		count += 1; result = s:sub(i,i) .. result
		if count % 3 == 0 and i > 1 then result = "," .. result end
	end
	return result
end

local function fmtTime(sec)
	if not sec or sec <= 0 then return "0:00" end
	return string.format("%d:%02d", math.floor(sec/60), math.floor(sec%60))
end

local function fmtTotalTime(sec)
	if not sec or sec <= 0 then return "0:00" end
	local h = math.floor(sec/3600)
	local m = math.floor((sec%3600)/60)
	local s = math.floor(sec%60)
	if h > 0 then return string.format("%dh %02dm", h, m) end
	return string.format("%d:%02d", m, s)
end

local function fmtCompact(n)
	if not n then return "0" end
	if n >= 1e6 then return string.format("%.1fM", n/1e6) end
	if n >= 1e3 then return string.format("%.1fk", n/1e3) end
	return tostring(math.floor(n))
end

local function fmtRobux(n) return "R$ " .. fmtNum(n) end

-- ----------------------------------------------------------------------------
-- ui helpers
-- ----------------------------------------------------------------------------

local function mkFrame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = PALETTE.surface
	for k,v in pairs(props or {}) do f[k]=v end
	f.Parent = parent
	return f
end

local function mkLabel(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = PALETTE.text
	l.TextScaled = false
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	for k,v in pairs(props or {}) do l[k]=v end
	l.Parent = parent
	return l
end

local function mkCorner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end

local function mkStroke(p, color, thick, transp)
	local s = Instance.new("UIStroke")
	s.Color = color or PALETTE.grid
	s.Thickness = thick or 1
	s.Transparency = transp or 0
	s.Parent = p
end

local function clearContent(p)
	for _, c in ipairs(p:GetChildren()) do
		if c:IsA("Frame") or c:IsA("ImageLabel") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
end

-- builds a stat card with accent strip, big value, and caption
local function statCard(parent, x, y, value, caption, accent)
	local card = mkFrame(parent, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(STAT_W, STAT_H)
	})
	mkCorner(card, 12)
	mkStroke(card, PALETTE.grid, 1, 0.5)

	mkFrame(card, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 5, 1, 0),
		BackgroundColor3 = accent or PALETTE.primary
	})

	mkLabel(card, value, {
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -26, 0, STAT_H - 70),
		TextColor3 = PALETTE.text,
		Font = Enum.Font.GothamBold,
		TextSize = FS.cardVal
	})
	mkLabel(card, caption, {
		Position = UDim2.fromOffset(20, STAT_H - 48),
		Size = UDim2.new(1, -26, 0, 36),
		TextColor3 = PALETTE.textDim,
		Font = Enum.Font.Gotham,
		TextSize = FS.cardCap
	})
end

-- builds a titled section card; returns the content frame
local function sectionCard(parent, x, y, w, h, title)
	local card = mkFrame(parent, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h)
	})
	mkCorner(card, 12)
	mkStroke(card, PALETTE.grid, 1, 0.5)

	mkLabel(card, title, {
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 44),
		TextColor3 = PALETTE.textDim,
		Font = Enum.Font.GothamBold,
		TextSize = FS.secTitle
	})

	local content = mkFrame(card, {
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 1, -86),
		BackgroundTransparency = 1
	})
	content.Name = "Content"
	return content
end

-- renders a single rank row at yOffset inside parent
local function rankRow(parent, yOff, rowH, idx, name, valText, valColor)
	local row = mkFrame(parent, {
		Position = UDim2.fromOffset(0, yOff),
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundColor3 = PALETTE.surfaceAlt
	})
	mkCorner(row, 8)

	mkLabel(row, MEDALS[idx] or "—", {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(60, rowH),
		TextColor3 = MEDAL_COLORS[idx] or PALETTE.textMuted,
		Font = Enum.Font.GothamBold, TextSize = FS.rankName
	})
	mkLabel(row, name or "—", {
		Position = UDim2.fromOffset(76, 0), Size = UDim2.new(1, -200, 1, 0),
		TextColor3 = PALETTE.text, Font = Enum.Font.GothamMedium, TextSize = FS.rankName
	})
	mkLabel(row, valText or "0", {
		Position = UDim2.new(1, -116, 0, 0), Size = UDim2.fromOffset(108, rowH),
		TextColor3 = valColor or PALETTE.text,
		Font = Enum.Font.GothamBold, TextSize = FS.rankVal,
		TextXAlignment = Enum.TextXAlignment.Right
	})
end

-- creates a chart canvas and renders it into an ImageLabel
local function drawChart(parent, x, y, w, h, cW, cH, drawFn)
	local img = Instance.new("ImageLabel")
	img.Position = UDim2.fromOffset(x, y)
	img.Size = UDim2.fromOffset(w, h)
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Stretch
	img.Parent = parent

	local ok, canvas = pcall(ChartEngine.CreateCanvas, cW, cH)
	if ok then
		pcall(drawFn, canvas)
		ChartEngine.AttachToLabel(img, canvas)
	end
	return img
end

-- ranked horizontal bar section
local function rankedBarSection(parent, x, y, w, h, title, labels, values, colors, fmt)
	local content = sectionCard(parent, x, y, w, h, title)
	if #labels == 0 then
		mkLabel(content, "No data yet.", {
			Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1,0,0,36),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end
	local lblW, valW = 196, 130
	local chartX = lblW + 10
	local chartW = math.max(60, w - 40 - lblW - valW - 20)
	local chartH = h - 88

	drawChart(content, chartX, 0, chartW, chartH, chartW, chartH, function(canvas)
		ChartEngine.DrawHorizontalBarChart(canvas, { x=0,y=0,width=chartW,height=chartH }, { values=values, colors=colors })
	end)

	local slot = chartH / #labels
	for i, name in ipairs(labels) do
		mkLabel(content, name, {
			Position = UDim2.fromOffset(0, (i-1)*slot + slot*0.15),
			Size = UDim2.fromOffset(lblW, slot*0.7),
			TextColor3 = PALETTE.text, Font = Enum.Font.GothamMedium, TextSize = 20
		})
		mkLabel(content, fmt and fmt(values[i]) or fmtNum(values[i]), {
			Position = UDim2.fromOffset(chartX + chartW + 8, (i-1)*slot + slot*0.15),
			Size = UDim2.fromOffset(valW, slot*0.7),
			TextColor3 = PALETTE.textDim, Font = Enum.Font.GothamBold, TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right
		})
	end
end

-- sorted list helper
local function rankedByField(games, field, desc)
	local sorted = {}
	for _, g in ipairs(games) do table.insert(sorted, g) end
	table.sort(sorted, function(a,b)
		local va, vb = a[field] or 0, b[field] or 0
		if desc then return va > vb else return va < vb end
	end)
	local lbls, vals, cols = {}, {}, {}
	for _, g in ipairs(sorted) do
		table.insert(lbls, labelFor(g.gameId))
		table.insert(vals, g[field] or 0)
		table.insert(cols, ChartEngine.ColorFor(g.gameId))
	end
	return lbls, vals, cols
end

-- ----------------------------------------------------------------------------
-- surface gui face helper
-- ----------------------------------------------------------------------------

local function faceFromPart(part)
	local name = part:GetAttribute("Face")
	if type(name) == "string" then
		for _, n in ipairs(Enum.NormalId:GetEnumItems()) do
			if n.Name:lower() == name:lower() then return n end
		end
	end
	return DEFAULT_FACE
end

-- builds the full-screen-sized SurfaceGui on a part
local function makeSurfaceGui(part, gameId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "AnalyticsBoard_" .. gameId
	gui.Adornee = part
	gui.Face = faceFromPart(part)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(SW, SH)
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local bg = mkFrame(gui, { Size = UDim2.fromScale(1,1), BackgroundColor3 = PALETTE.background })
	bg.Name = "Background"
	return gui, bg
end

-- ----------------------------------------------------------------------------
-- header builder
-- ----------------------------------------------------------------------------

local function buildHeader(parent, title, subtitle, accent, centered)
	local hdr = mkFrame(parent, {
		Position = UDim2.fromOffset(MARGIN, 18),
		Size = UDim2.new(1, -MARGIN*2, 0, 178),
		BackgroundTransparency = 1
	})

	local align = centered and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left

	mkLabel(hdr, title, {
		Size = UDim2.new(1,0,0,118),
		TextColor3 = PALETTE.text,
		Font = Enum.Font.GothamBold, TextSize = FS.header,
		TextXAlignment = align
	})
	mkLabel(hdr, subtitle, {
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1,0,0,40),
		TextColor3 = PALETTE.textDim,
		Font = Enum.Font.Gotham, TextSize = FS.subhead,
		TextXAlignment = align
	})

	-- accent underline: left-anchored normally, centered when requested
	local ul = mkFrame(hdr, {
		Position = centered and UDim2.new(0.5, -45, 0, 168) or UDim2.fromOffset(0, 168),
		Size = UDim2.fromOffset(90, 6),
		BackgroundColor3 = accent or PALETTE.primary
	})
	mkCorner(ul, 2)
end

-- ----------------------------------------------------------------------------
-- stat row builder (5 cards centered)
-- ----------------------------------------------------------------------------

local function buildStatRow(parent, cards)
	for i, c in ipairs(cards) do
		statCard(parent,
			STAT_START_X + (i-1) * (STAT_W + STAT_GAP),
			STAT_Y,
			c.v, c.c, c.a)
	end
end

-- ----------------------------------------------------------------------------
-- right column sections: scores, time players, donations, donors
-- ----------------------------------------------------------------------------

local function buildTopScores(parent, x, y, w, h, topScores)
	local content = sectionCard(parent, x, y, w, h, "TOP 3 SCORES")
	local rowH = math.floor((h - 74) / 3)
	for i = 1, 3 do
		local e = (topScores or {})[i]
		rankRow(content, (i-1)*rowH, rowH - 4, i,
			e and e.name or "—",
			e and fmtNum(e.score) or "0",
			e and PALETTE.text or PALETTE.textMuted)
	end
end

local function buildTopTimePlayers(parent, x, y, w, h, topTime)
	local content = sectionCard(parent, x, y, w, h, "TOP TIME PLAYERS")
	local rowH = math.floor((h - 74) / 3)
	for i = 1, 3 do
		local e = (topTime or {})[i]
		rankRow(content, (i-1)*rowH, rowH - 4, i,
			e and e.name or "—",
			e and fmtTotalTime(e.totalTime) or "0:00",
			e and PALETTE.secondary or PALETTE.textMuted)
	end
end

local function buildDonations(parent, x, y, w, h, totalDonations, topDonors)
	-- left half: total amount
	local lW = math.floor((w - STAT_GAP) / 2)
	local rW = w - lW - STAT_GAP
	local donContent = sectionCard(parent, x, y, lW, h, "TOTAL DONATIONS")

	mkLabel(donContent, fmtRobux(totalDonations), {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1,0,0,80),
		TextColor3 = PALETTE.gold,
		Font = Enum.Font.GothamBold, TextSize = FS.donAmt
	})
	mkLabel(donContent, "Robux contributed by players", {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1,0,0,28),
		TextColor3 = PALETTE.textDim,
		Font = Enum.Font.Gotham, TextSize = FS.donSub
	})

	-- right half: top donors
	local donorsContent = sectionCard(parent, x + lW + STAT_GAP, y, rW, h, "TOP CONTRIBUTORS")
	local rowH = math.floor((h - 74) / 3)
	for i = 1, 3 do
		local e = (topDonors or {})[i]
		rankRow(donorsContent, (i-1)*rowH, rowH - 4, i,
			e and e.name or "—",
			e and fmtRobux(e.total) or "R$ 0",
			e and PALETTE.gold or PALETTE.textMuted)
	end
end

-- ----------------------------------------------------------------------------
-- left column: histogram + optional level chart
-- ----------------------------------------------------------------------------

local function buildHistogram(parent, x, y, w, h, buckets, maxScore, accent)
	local content = sectionCard(parent, x, y, w, h, "SCORE DISTRIBUTION")
	local cW, cH = w - 40, h - 88
	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawHistogram(canvas, {x=50,y=10,width=cW-70,height=cH-40}, {
			buckets = buckets or {}, color = accent
		})
	end)
	mkLabel(content, "0", {
		Position = UDim2.fromOffset(4, cH - 26),
		Size = UDim2.fromOffset(60, 24),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	mkLabel(content, fmtCompact(maxScore), {
		Position = UDim2.fromOffset(cW - 80, cH - 26),
		Size = UDim2.fromOffset(80, 24),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick,
		TextXAlignment = Enum.TextXAlignment.Right
	})
end

local function buildLevelChart(parent, x, y, w, h, levelStats, accent)
	local content = sectionCard(parent, x, y, w, h, "AVERAGE TIME PER LEVEL")
	local levels, times = {}, {}
	for i = 1, 10 do
		local s = (levelStats or {})[i]
		if s and s.count > 0 then
			table.insert(levels, "Lv"..i)
			table.insert(times, s.avgTime)
		end
	end
	if #levels == 0 then
		mkLabel(content, "No level data recorded yet.", {
			Position = UDim2.fromOffset(0,40), Size = UDim2.new(1,0,0,32),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	local cW, cH = w - 40, h - 88
	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawBarChart(canvas, {x=60,y=10,width=cW-80,height=cH-40}, {
			values=times, color=accent
		})
	end)
	local slot = (cW - 80) / #levels
	for i, lname in ipairs(levels) do
		mkLabel(content, lname, {
			Position = UDim2.fromOffset(60 + (i-1)*slot, cH - 36),
			Size = UDim2.fromOffset(slot, 22),
			TextColor3 = PALETTE.textDim, Font = Enum.Font.Gotham, TextSize = FS.tick,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		mkLabel(content, fmtTime(times[i]), {
			Position = UDim2.fromOffset(60 + (i-1)*slot, cH - 16),
			Size = UDim2.fromOffset(slot, 18),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick - 2,
			TextXAlignment = Enum.TextXAlignment.Center
		})
	end
end

-- ----------------------------------------------------------------------------
-- new chart helpers for general overview
-- ----------------------------------------------------------------------------

-- builds a vertical bar chart of activity by hour of day (24 bars)
local function buildHourlyChart(parent, x, y, w, h, hourly)
	local content = sectionCard(parent, x, y, w, h, "PLAYERS BY HOUR OF DAY")
	local cW, cH = w - 40, h - 100
	local data = hourly or table.create(24, 0)

	-- check if there is any data
	local total = 0
	for _, v in ipairs(data) do total = total + v end

	if total == 0 then
		mkLabel(content, "No activity recorded yet.", {
			Position = UDim2.fromOffset(0, math.floor(cH/2) - 16), Size = UDim2.new(1,0,0,32),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	-- find peak hour
	local peakIdx, peakVal = 1, 0
	for i, v in ipairs(data) do if v > peakVal then peakIdx, peakVal = i, v end end

	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawBarChart(canvas, {x=40, y=10, width=cW-50, height=cH-30}, {
			values = data, color = PALETTE.primary
		})
	end)

	-- x-axis labels every 4 hours
	local slot = (cW - 50) / 24
	for h_i = 0, 23, 4 do
		mkLabel(content, string.format("%02dh", h_i), {
			Position = UDim2.fromOffset(40 + h_i * slot - 16, cH - 18),
			Size = UDim2.fromOffset(32, 22),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick - 2,
			TextXAlignment = Enum.TextXAlignment.Center
		})
	end

	mkLabel(content, string.format("Peak: %02dh — %s sessions", peakIdx - 1, fmtCompact(peakVal)), {
		Position = UDim2.fromOffset(0, cH + 6),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = PALETTE.primary, Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center
	})
end

-- builds a vertical bar chart of activity by weekday (7 bars)
local function buildDailyChart(parent, x, y, w, h, daily)
	local content = sectionCard(parent, x, y, w, h, "PLAYERS BY WEEKDAY")
	local cW, cH = w - 40, h - 100
	local data = daily or table.create(7, 0)
	local dayNames = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}

	local total = 0
	for _, v in ipairs(data) do total = total + v end

	if total == 0 then
		mkLabel(content, "No activity recorded yet.", {
			Position = UDim2.fromOffset(0, math.floor(cH/2) - 16), Size = UDim2.new(1,0,0,32),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	local peakIdx, peakVal = 1, 0
	for i, v in ipairs(data) do if v > peakVal then peakIdx, peakVal = i, v end end

	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawBarChart(canvas, {x=40, y=10, width=cW-50, height=cH-30}, {
			values = data, color = PALETTE.secondary
		})
	end)

	local slot = (cW - 50) / 7
	for i = 1, 7 do
		mkLabel(content, dayNames[i], {
			Position = UDim2.fromOffset(40 + (i-1) * slot, cH - 18),
			Size = UDim2.fromOffset(slot, 22),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick - 2,
			TextXAlignment = Enum.TextXAlignment.Center
		})
	end

	mkLabel(content, string.format("Peak: %s — %s sessions", dayNames[peakIdx], fmtCompact(peakVal)), {
		Position = UDim2.fromOffset(0, cH + 6),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = PALETTE.secondary, Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center
	})
end

-- builds a vertical bar chart of player retention (5 buckets of session count)
local function buildRetentionChart(parent, x, y, w, h, buckets)
	local content = sectionCard(parent, x, y, w, h, "PLAYER RETENTION")
	local cW, cH = w - 40, h - 100
	local data = buckets or table.create(5, 0)
	local labels = {"1 ses", "2-4", "5-9", "10-19", "20+"}
	local colors = { PALETTE.danger, PALETTE.accent, PALETTE.secondary, PALETTE.primary, PALETTE.gold }

	local total = 0
	for _, v in ipairs(data) do total = total + v end

	if total == 0 then
		mkLabel(content, "No retention data yet.", {
			Position = UDim2.fromOffset(0, math.floor(cH/2) - 16), Size = UDim2.new(1,0,0,32),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	-- frequent player percentage (5+ sessions)
	local frequent = (data[3] or 0) + (data[4] or 0) + (data[5] or 0)
	local freqPct  = total > 0 and (frequent / total * 100) or 0

	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawBarChart(canvas, {x=40, y=10, width=cW-50, height=cH-30}, {
			values = data, colors = colors
		})
	end)

	local slot = (cW - 50) / 5
	for i = 1, 5 do
		mkLabel(content, labels[i], {
			Position = UDim2.fromOffset(40 + (i-1) * slot, cH - 18),
			Size = UDim2.fromOffset(slot, 22),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick - 2,
			TextXAlignment = Enum.TextXAlignment.Center
		})
	end

	mkLabel(content, string.format("%.0f%% are frequent players (5+ sessions)", freqPct), {
		Position = UDim2.fromOffset(0, cH + 6),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = PALETTE.gold, Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center
	})
end

-- ----------------------------------------------------------------------------
-- revenue chart helpers (money dashboard)
-- ----------------------------------------------------------------------------

-- builds a vertical bar chart of revenue by hour of day (24 bars)
local function buildRevenueHourlyChart(parent, x, y, w, h, hourly)
	local content = sectionCard(parent, x, y, w, h, "REVENUE BY HOUR OF DAY")
	local cW, cH = w - 40, h - 100
	local data = hourly or table.create(24, 0)

	local total = 0
	for _, v in ipairs(data) do total = total + v end
	if total == 0 then
		mkLabel(content, "No revenue recorded yet.", {
			Position = UDim2.fromOffset(0, math.floor(cH/2) - 16), Size = UDim2.new(1,0,0,32),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	local peakIdx, peakVal = 1, 0
	for i, v in ipairs(data) do if v > peakVal then peakIdx, peakVal = i, v end end

	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawBarChart(canvas, {x=40, y=10, width=cW-50, height=cH-30}, {
			values = data, color = PALETTE.gold
		})
	end)

	local slot = (cW - 50) / 24
	for h_i = 0, 23, 4 do
		mkLabel(content, string.format("%02dh", h_i), {
			Position = UDim2.fromOffset(40 + h_i * slot - 16, cH - 18),
			Size = UDim2.fromOffset(32, 22),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick - 2,
			TextXAlignment = Enum.TextXAlignment.Center
		})
	end

	mkLabel(content, string.format("Peak: %02dh — R$ %s", peakIdx - 1, fmtNum(peakVal)), {
		Position = UDim2.fromOffset(0, cH + 6),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = PALETTE.gold, Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center
	})
end

-- builds a vertical bar chart of revenue by weekday (7 bars)
local function buildRevenueDailyChart(parent, x, y, w, h, daily)
	local content = sectionCard(parent, x, y, w, h, "REVENUE BY WEEKDAY")
	local cW, cH = w - 40, h - 100
	local data = daily or table.create(7, 0)
	local dayNames = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}

	local total = 0
	for _, v in ipairs(data) do total = total + v end
	if total == 0 then
		mkLabel(content, "No revenue recorded yet.", {
			Position = UDim2.fromOffset(0, math.floor(cH/2) - 16), Size = UDim2.new(1,0,0,32),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	local peakIdx, peakVal = 1, 0
	for i, v in ipairs(data) do if v > peakVal then peakIdx, peakVal = i, v end end

	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawBarChart(canvas, {x=40, y=10, width=cW-50, height=cH-30}, {
			values = data, color = PALETTE.accent
		})
	end)

	local slot = (cW - 50) / 7
	for i = 1, 7 do
		mkLabel(content, dayNames[i], {
			Position = UDim2.fromOffset(40 + (i-1) * slot, cH - 18),
			Size = UDim2.fromOffset(slot, 22),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick - 2,
			TextXAlignment = Enum.TextXAlignment.Center
		})
	end

	mkLabel(content, string.format("Peak: %s — R$ %s", dayNames[peakIdx], fmtNum(peakVal)), {
		Position = UDim2.fromOffset(0, cH + 6),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = PALETTE.accent, Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center
	})
end

-- builds a scatter plot of time played (x) vs revenue (y), one point per game
local function buildRevenueScatter(parent, x, y, w, h, games)
	local content = sectionCard(parent, x, y, w, h, "REVENUE vs TIME PLAYED")
	local cW, cH = w - 40, h - 100

	local points = {}
	for _, g in ipairs(games) do
		if (g.totalTimePlayed or 0) > 0 or (g.revenue or 0) > 0 then
			table.insert(points, {
				x = (g.totalTimePlayed or 0) / 3600,
				y = g.revenue or 0,
				color = ChartEngine.ColorFor(g.gameId)
			})
		end
	end

	if #points == 0 then
		mkLabel(content, "Need data from at least one game.", {
			Position = UDim2.fromOffset(0, math.floor(cH/2) - 16), Size = UDim2.new(1,0,0,32),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	drawChart(content, 0, 0, cW, cH, cW, cH, function(canvas)
		ChartEngine.DrawScatterPlot(canvas, {x=40, y=10, width=cW-50, height=cH-30}, {
			points = points
		})
	end)

	mkLabel(content, "hours played →", {
		Position = UDim2.fromOffset(0, cH - 18),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.tick - 2,
		TextXAlignment = Enum.TextXAlignment.Right
	})
	mkLabel(content, "↑ Robux  ·  each dot is a game", {
		Position = UDim2.fromOffset(0, cH + 6),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = PALETTE.secondary, Font = Enum.Font.GothamBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center
	})
end

-- ----------------------------------------------------------------------------
-- live ticker (marquee) for the bank feed boards
-- ----------------------------------------------------------------------------

-- per-background ticker generation token; bumping it stops the old animation loop
local tickerTokens = setmetatable({}, { __mode = "k" })

-- builds an infinite vertical scrolling list inside a container.
--  items     : array of data (newest first)
--  rowBuilder: function(parent, yOffset, width, rowH, item, index) -> creates one row
local function buildTicker(bg, container, items, rowBuilder)
	local cW = container.AbsoluteSize.X
	-- AbsoluteSize may be 0 before layout; fall back to the declared offset width
	if cW <= 0 then cW = container.Size.X.Offset end

	local rowH = 78
	local cH = container.Size.Y.Offset

	if #items == 0 then
		mkLabel(container, "Waiting for live activity…", {
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 40),
			AnchorPoint = Vector2.new(0, 0.5),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		return
	end

	local listH = #items * rowH

	-- track holds two stacked copies of the list for a seamless loop
	local track = mkFrame(container, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, listH * 2),
		BackgroundTransparency = 1
	})
	track.Name = "Track"

	for copy = 0, 1 do
		for i, item in ipairs(items) do
			rowBuilder(track, copy * listH + (i - 1) * rowH, cW, rowH, item, i)
		end
	end

	-- only animate when the list is taller than the visible area
	tickerTokens[bg] = (tickerTokens[bg] or 0) + 1
	local myToken = tickerTokens[bg]

	if listH <= cH then return end

	local SPEED = 36  -- pixels per second
	task.spawn(function()
		local y = 0
		while bg.Parent and track.Parent and tickerTokens[bg] == myToken do
			local dt = RunService.Heartbeat:Wait()
			y = y - SPEED * dt
			if y <= -listH then y = y + listH end
			track.Position = UDim2.new(0, 0, 0, math.floor(y))
		end
	end)
end

-- builds one feed row: a colored game tag, a name, and a right-aligned value
local function feedRow(parent, yOff, w, rowH, gameId, leftText, rightText, rightColor)
	local row = mkFrame(parent, {
		Position = UDim2.fromOffset(0, yOff),
		Size = UDim2.new(1, 0, 0, rowH - 8),
		BackgroundColor3 = PALETTE.surface
	})
	mkCorner(row, 8)
	mkStroke(row, PALETTE.grid, 1, 0.6)

	-- left color bar = game brand color
	local bar = mkFrame(row, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = ChartEngine.ColorFor(gameId)
	})
	mkCorner(bar, 3)

	-- game tag
	mkLabel(row, labelFor(gameId), {
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(0.42, -20, 1, -16),
		TextColor3 = ChartEngine.ColorFor(gameId),
		Font = Enum.Font.GothamBold, TextSize = 26,
		TextYAlignment = Enum.TextYAlignment.Center
	})
	-- player name / action
	mkLabel(row, leftText, {
		Position = UDim2.new(0.42, 8, 0, 8),
		Size = UDim2.new(0.32, -8, 1, -16),
		TextColor3 = PALETTE.text,
		Font = Enum.Font.GothamMedium, TextSize = 28,
		TextYAlignment = Enum.TextYAlignment.Center
	})
	-- value (robux / score)
	mkLabel(row, rightText, {
		Position = UDim2.new(0.74, 0, 0, 8),
		Size = UDim2.new(0.26, -16, 1, -16),
		TextColor3 = rightColor or PALETTE.text,
		Font = Enum.Font.GothamBlack, TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center
	})
end

-- draws a small revenue-by-hour sparkline cell for the MoneyG grid
local function moneyMiniCell(parent, x, y, w, h, gameId, revenue, hourly)
	local content = sectionCard(parent, x, y, w, h, labelFor(gameId))
	local cW, cH = w - 40, h - 96

	-- big revenue number
	mkLabel(content, fmtRobux(revenue), {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = PALETTE.gold, Font = Enum.Font.GothamBold, TextSize = 40
	})

	local barsY = 52
	local barsH = cH - barsY
	if barsH < 30 then barsH = 30 end

	local total = 0
	for _, v in ipairs(hourly or {}) do total = total + v end

	if total == 0 then
		mkLabel(content, "no revenue yet", {
			Position = UDim2.fromOffset(0, barsY + 8),
			Size = UDim2.new(1, 0, 0, 24),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 18
		})
		return
	end

	drawChart(content, 0, barsY, cW, barsH, cW, barsH, function(canvas)
		ChartEngine.DrawBarChart(canvas, {x=4, y=4, width=cW-8, height=barsH-8}, {
			values = hourly, color = ChartEngine.ColorFor(gameId)
		})
	end)
end

-- ----------------------------------------------------------------------------
-- dashboard renderers
-- ----------------------------------------------------------------------------

local function renderGameDashboard(bg, gameId, data)
	clearContent(bg)
	local accent = ChartEngine.ColorFor(gameId)
	local ago = data.lastUpdated > 0 and (os.time() - data.lastUpdated) or 0

	buildHeader(bg, labelFor(gameId),
		string.format("Updated %ds ago  ·  %s players  ·  %s sessions",
			ago, fmtCompact(data.uniquePlayers), fmtCompact(data.totalSessions)),
		accent)

	buildStatRow(bg, {
		{ v = fmtNum(data.uniquePlayers),           c = "UNIQUE PLAYERS",    a = accent },
		{ v = fmtNum(data.avgScore),                c = "AVERAGE SCORE",     a = PALETTE.primary },
		{ v = fmtNum(data.medianScore),             c = "MEDIAN SCORE",      a = PALETTE.secondary },
		{ v = fmtTime(data.avgTime),                c = "AVG PLAY TIME",     a = PALETTE.accent },
		{ v = string.format("%.2fx",data.replayRate), c = "REPLAY RATE",     a = PALETTE.danger },
	})

	local cy = CONT_Y
	local isLevel = LEVEL_GAMES[gameId]

	-- left column
	if isLevel then
		local hH = math.floor((CONT_H - RIGHT_GAP) / 2)
		buildHistogram(bg, MARGIN, cy, LEFT_W, hH, data.scoreHistogram, data.maxScoreSeen, accent)
		buildLevelChart(bg, MARGIN, cy + hH + RIGHT_GAP, LEFT_W, CONT_H - hH - RIGHT_GAP, data.levelStats, accent)
	else
		buildHistogram(bg, MARGIN, cy, LEFT_W, CONT_H, data.scoreHistogram, data.maxScoreSeen, accent)
	end

	-- right top: scores + time players
	buildTopScores(bg, RIGHT_X, cy, R_HALF, RIGHT_H1, data.topScores)
	buildTopTimePlayers(bg, RIGHT_X + R_HALF + STAT_GAP, cy, R_HALF, RIGHT_H1, data.topTimePlayers)

	-- right bottom: donations + donors
	buildDonations(bg, RIGHT_X, cy + RIGHT_H1 + RIGHT_GAP, RIGHT_W, RIGHT_H2,
		data.totalDonations, data.topDonors)

	mkLabel(bg, "ANALYTICS — " .. labelFor(gameId), {
		Position = UDim2.fromOffset(MARGIN, SH - 30),
		Size = UDim2.new(1, -MARGIN*2, 0, 22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
	})
end

local function renderGeneralDashboard(bg, payload)
	clearContent(bg)
	local games = payload.games or {}
	local totSess, totPlay, totTime, totRev = 0, 0, 0, 0
	for _, g in ipairs(games) do
		totSess = totSess + (g.totalSessions or 0)
		totPlay = totPlay + (g.uniquePlayers or 0)
		totTime = totTime + (g.totalTimePlayed or 0)
		totRev  = totRev  + (g.totalDonations or 0)
	end

	buildHeader(bg, "GAMES OVERVIEW",
		string.format("Analytics across %d arcade titles", #games), PALETTE.primary)

	buildStatRow(bg, {
		{ v = fmtNum(totSess),  c = "TOTAL SESSIONS",    a = PALETTE.primary },
		{ v = fmtNum(totPlay),  c = "TOTAL PLAYERS",     a = PALETTE.secondary },
		{ v = string.format("%.1fh", totTime/3600), c = "TOTAL TIME",   a = PALETTE.accent },
		{ v = fmtRobux(totRev), c = "TOTAL REVENUE",     a = PALETTE.gold },
		{ v = fmtCompact(#games), c = "GAMES TRACKED",   a = PALETTE.danger },
	})

	local cy = CONT_Y

	-- row 1: two ranked bar charts (sessions + revenue)
	local cellW2 = math.floor((SW - MARGIN*2 - STAT_GAP) / 2)
	local cellH1 = 248

	local lbls1, vals1, cols1 = rankedByField(games, "totalSessions", true)
	rankedBarSection(bg, MARGIN, cy, cellW2, cellH1,
		"MOST PLAYED — sessions per game", lbls1, vals1, cols1, fmtNum)

	local lbls2, vals2, cols2 = rankedByField(games, "totalDonations", true)
	rankedBarSection(bg, MARGIN + cellW2 + STAT_GAP, cy, cellW2, cellH1,
		"TOP EARNERS — Robux donated", lbls2, vals2, cols2, fmtRobux)

	-- row 2: three activity charts (hourly + daily + retention)
	local row2Y = cy + cellH1 + RIGHT_GAP
	local row2H = CONT_H - cellH1 - RIGHT_GAP
	local cellW3 = math.floor((SW - MARGIN*2 - STAT_GAP*2) / 3)

	buildHourlyChart(bg, MARGIN, row2Y, cellW3, row2H, payload.hourlyActivity)
	buildDailyChart(bg, MARGIN + cellW3 + STAT_GAP, row2Y, cellW3, row2H, payload.dailyActivity)
	buildRetentionChart(bg, MARGIN + 2*(cellW3 + STAT_GAP), row2Y, cellW3, row2H, payload.retentionBuckets)

	mkLabel(bg, "ANALYTICS — GAMES OVERVIEW", {
		Position = UDim2.fromOffset(MARGIN, SH-30),
		Size = UDim2.new(1,-MARGIN*2,0,22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
	})
end

local function renderMoneyDashboard(bg, payload)
	clearContent(bg)
	local games        = payload.games or {}
	local totRevenue   = payload.totalRevenue or 0
	local totSessions  = payload.totalSessions or 0
	local totTime      = payload.totalTime or 0

	buildHeader(bg, "REVENUE ANALYTICS",
		"Donations performance and conversion across all games", PALETTE.gold)

	local s2r = totSessions > 0 and (totRevenue / totSessions) or 0
	local hrs = totTime / 3600
	local rph = hrs > 0 and (totRevenue / hrs) or 0

	-- count contributors across games
	local contributors = 0
	for _, g in ipairs(games) do
		if (g.revenue or 0) > 0 then contributors = contributors + 1 end
	end

	buildStatRow(bg, {
		{ v = fmtRobux(totRevenue),              c = "TOTAL REVENUE",         a = PALETTE.gold },
		{ v = string.format("%.2f",s2r),         c = "ROBUX / SESSION",       a = PALETTE.primary },
		{ v = string.format("%.1f",rph),         c = "ROBUX / HOUR PLAYED",   a = PALETTE.secondary },
		{ v = fmtCompact(totSessions),           c = "TOTAL SESSIONS",        a = PALETTE.accent },
		{ v = fmtNum(contributors) .. "/" .. #games, c = "GAMES WITH REVENUE", a = PALETTE.danger },
	})

	local cy = CONT_Y

	-- if no revenue at all, show a friendly empty state instead of empty charts
	if totRevenue == 0 then
		local card = mkFrame(bg, {
			Position = UDim2.fromOffset(MARGIN, cy),
			Size = UDim2.new(1, -MARGIN*2, 0, CONT_H),
			BackgroundColor3 = PALETTE.surface
		})
		mkCorner(card, 12)
		mkStroke(card, PALETTE.grid, 1, 0.5)

		mkLabel(card, "💰", {
			Position = UDim2.new(0, 0, 0.5, -160),
			Size = UDim2.new(1, 0, 0, 120),
			TextColor3 = PALETTE.gold, Font = Enum.Font.GothamBold, TextSize = 110,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		mkLabel(card, "NO REVENUE RECORDED YET", {
			Position = UDim2.new(0, 0, 0.5, -10),
			Size = UDim2.new(1, 0, 0, 60),
			TextColor3 = PALETTE.text, Font = Enum.Font.GothamBold, TextSize = 48,
			TextXAlignment = Enum.TextXAlignment.Center
		})
		mkLabel(card, "Revenue will appear here once players start donating.", {
			Position = UDim2.new(0, 0, 0.5, 60),
			Size = UDim2.new(1, 0, 0, 40),
			TextColor3 = PALETTE.textDim, Font = Enum.Font.Gotham, TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Center
		})

		mkLabel(bg, "ANALYTICS — REVENUE", {
			Position = UDim2.fromOffset(MARGIN, SH-30),
			Size = UDim2.new(1,-MARGIN*2,0,22),
			TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
		})
		return
	end

	-- row 1: revenue by game (ranked bars) + revenue vs time-played (scatter correlation)
	local cellW2 = math.floor((SW - MARGIN*2 - STAT_GAP) / 2)
	local row1H  = 248

	local lbls, vals, cols = rankedByField(games, "revenue", true)
	rankedBarSection(bg, MARGIN, cy, cellW2, row1H,
		"REVENUE BY GAME — total Robux", lbls, vals, cols, fmtRobux)

	buildRevenueScatter(bg, MARGIN + cellW2 + STAT_GAP, cy, cellW2, row1H, games)

	-- row 2: revenue by hour + revenue by weekday + revenue per player
	local row2Y = cy + row1H + RIGHT_GAP
	local row2H = CONT_H - row1H - RIGHT_GAP
	local cellW3 = math.floor((SW - MARGIN*2 - STAT_GAP*2) / 3)

	buildRevenueHourlyChart(bg, MARGIN, row2Y, cellW3, row2H, payload.donationHourly)
	buildRevenueDailyChart(bg, MARGIN + cellW3 + STAT_GAP, row2Y, cellW3, row2H, payload.donationDaily)

	local plbls, pvals, pcols = rankedByField(games, "revenuePerPlayer", true)
	rankedBarSection(bg, MARGIN + 2*(cellW3 + STAT_GAP), row2Y, cellW3, row2H,
		"REVENUE PER PLAYER", plbls, pvals, pcols,
		function(n) return string.format("R$ %.2f",n) end)

	mkLabel(bg, "ANALYTICS — REVENUE", {
		Position = UDim2.fromOffset(MARGIN, SH-30),
		Size = UDim2.new(1,-MARGIN*2,0,22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
	})
end

-- shows a friendly informational message pointing players to the bank building
local function renderLastMessage(bg, gameId)
	clearContent(bg)

	-- big icon at the center
	mkLabel(bg, "🏦", {
		Position = UDim2.new(0, 0, 0.5, -240),
		Size = UDim2.new(1, 0, 0, 180),
		TextColor3 = PALETTE.gold, Font = Enum.Font.GothamBold, TextSize = 160,
		TextXAlignment = Enum.TextXAlignment.Center
	})

	-- big title
	mkLabel(bg, "WANT MORE DETAILED ANALYTICS?", {
		Position = UDim2.new(0, 0, 0.5, -50),
		Size = UDim2.new(1, 0, 0, 80),
		TextColor3 = PALETTE.text, Font = Enum.Font.GothamBold, TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center
	})

	-- subtitle
	mkLabel(bg, "Visit the Bank Building to see the full analytics suite", {
		Position = UDim2.new(0, 0, 0.5, 36),
		Size = UDim2.new(1, 0, 0, 48),
		TextColor3 = PALETTE.textDim, Font = Enum.Font.Gotham, TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center
	})

	-- accent line
	local underline = mkFrame(bg, {
		Position = UDim2.new(0.5, -80, 0.5, 100),
		Size = UDim2.fromOffset(160, 6),
		BackgroundColor3 = PALETTE.gold
	})
	mkCorner(underline, 3)

	-- hint at the bottom
	mkLabel(bg, "All 10 game dashboards · Global trends · Revenue breakdown · Player retention", {
		Position = UDim2.new(0, 0, 0.5, 140),
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center
	})

	mkLabel(bg, "ANALYTICS — INFO", {
		Position = UDim2.fromOffset(MARGIN, SH-30),
		Size = UDim2.new(1,-MARGIN*2,0,22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
	})
end

-- board 13: live donations ticker (RealMoney)
local function renderRealMoney(bg, items)
	clearContent(bg)
	items = items or {}

	buildHeader(bg, "LIVE DONATIONS",
		"Real-time feed of player contributions across all games", PALETTE.gold, true)

	-- live dot
	local dot = mkFrame(bg, {
		Position = UDim2.fromOffset(SW - MARGIN - 220, 60),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = PALETTE.danger
	})
	mkCorner(dot, 8)
	mkLabel(bg, "LIVE", {
		Position = UDim2.fromOffset(SW - MARGIN - 196, 48),
		Size = UDim2.fromOffset(180, 40),
		TextColor3 = PALETTE.danger, Font = Enum.Font.GothamBold, TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left
	})

	local container = mkFrame(bg, {
		Position = UDim2.fromOffset(MARGIN, 200),
		Size = UDim2.fromOffset(SW - MARGIN*2, SH - 200 - 48),
		BackgroundTransparency = 1
	})
	container.ClipsDescendants = true

	buildTicker(bg, container, items, function(parent, yOff, w, rowH, item)
		feedRow(parent, yOff, w, rowH, item.gameId,
			item.name or "Unknown",
			"R$ " .. fmtNum(item.robux or 0),
			PALETTE.gold)
	end)

	mkLabel(bg, "ANALYTICS — LIVE DONATIONS", {
		Position = UDim2.fromOffset(MARGIN, SH-30),
		Size = UDim2.new(1,-MARGIN*2,0,22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
	})
end

-- board 15: live scores ticker (RealPlayer)
local function renderRealPlayer(bg, items)
	clearContent(bg)
	items = items or {}

	buildHeader(bg, "LIVE SCORES",
		"Real-time feed of recent matches across all games", PALETTE.secondary, true)

	local dot = mkFrame(bg, {
		Position = UDim2.fromOffset(SW - MARGIN - 220, 60),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = PALETTE.danger
	})
	mkCorner(dot, 8)
	mkLabel(bg, "LIVE", {
		Position = UDim2.fromOffset(SW - MARGIN - 196, 48),
		Size = UDim2.fromOffset(180, 40),
		TextColor3 = PALETTE.danger, Font = Enum.Font.GothamBold, TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left
	})

	local container = mkFrame(bg, {
		Position = UDim2.fromOffset(MARGIN, 200),
		Size = UDim2.fromOffset(SW - MARGIN*2, SH - 200 - 48),
		BackgroundTransparency = 1
	})
	container.ClipsDescendants = true

	buildTicker(bg, container, items, function(parent, yOff, w, rowH, item)
		feedRow(parent, yOff, w, rowH, item.gameId,
			item.name or "Unknown",
			fmtNum(item.score or 0),
			PALETTE.secondary)
	end)

	mkLabel(bg, "ANALYTICS — LIVE SCORES", {
		Position = UDim2.fromOffset(MARGIN, SH-30),
		Size = UDim2.new(1,-MARGIN*2,0,22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
	})
end

-- board 14: grid of 10 mini revenue charts, one per game (MoneyG)
local function renderMoneyG(bg, payload)
	clearContent(bg)
	local games = payload.games or {}

	local totalRev = payload.totalRevenue or 0
	buildHeader(bg, "REVENUE BY GAME",
		string.format("Live revenue breakdown  ·  R$ %s total across %d games",
			fmtNum(totalRev), #games),
		PALETTE.gold, true)

	-- 5 columns x 2 rows grid
	local cols, rows = 5, 2
	local gridY = 196
	local gridH = SH - gridY - 48
	local gap = 14
	local cellW = math.floor((SW - MARGIN*2 - gap*(cols-1)) / cols)
	local cellH = math.floor((gridH - gap*(rows-1)) / rows)

	-- order games by revenue descending for a nicer layout
	local sorted = {}
	for _, g in ipairs(games) do table.insert(sorted, g) end
	table.sort(sorted, function(a,b) return (a.revenue or 0) > (b.revenue or 0) end)

	for idx, g in ipairs(sorted) do
		if idx > cols * rows then break end
		local c = (idx - 1) % cols
		local r = math.floor((idx - 1) / cols)
		moneyMiniCell(bg,
			MARGIN + c * (cellW + gap),
			gridY + r * (cellH + gap),
			cellW, cellH,
			g.gameId, g.revenue or 0, g.donationHourly)
	end

	mkLabel(bg, "ANALYTICS — REVENUE BY GAME", {
		Position = UDim2.fromOffset(MARGIN, SH-30),
		Size = UDim2.new(1,-MARGIN*2,0,22),
		TextColor3 = PALETTE.textMuted, Font = Enum.Font.Gotham, TextSize = FS.footer
	})
end

-- ----------------------------------------------------------------------------
-- fullscreen mode
-- ----------------------------------------------------------------------------

local activeBoards         = {}
local activeFullscreenGui    = nil
local activeFullscreenConns  = {}
local activeBlur             = nil
local prevCameraType         = nil

-- empty payload templates shared by both setup and fullscreen
local function emptyGameData()
	return {
		totalSessions=0, uniquePlayers=0, avgScore=0, medianScore=0,
		avgTime=0, replayRate=0, totalDonations=0, topScores={},
		topDonors={}, topTimePlayers={}, scoreHistogram={},
		maxScoreSeen=100, levelStats={}, lastUpdated=0,
		hourlyActivity = table.create(24, 0),
		dailyActivity  = table.create(7,  0),
		retentionBuckets = table.create(5, 0),
	}
end

local function emptyGeneralData()
	return {
		games = {},
		hourlyActivity   = table.create(24, 0),
		dailyActivity    = table.create(7,  0),
		retentionBuckets = table.create(5,  0),
	}
end

local function emptyMoneyData()
	return {
		games = {}, totalRevenue = 0, totalSessions = 0, totalTime = 0,
		donationHourly = table.create(24, 0),
		donationDaily  = table.create(7,  0),
	}
end

-- returns the player's control module, or nil if unavailable
local function getControls()
	local ok, controls = pcall(function()
		local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		return pm:GetControls()
	end)
	if ok then return controls end
	return nil
end

-- freezes the character so navigation keys don't move the avatar
local function freezeCharacter()
	local controls = getControls()
	if controls then pcall(function() controls:Disable() end) end
end

-- restores character movement
local function unfreezeCharacter()
	local controls = getControls()
	if controls then pcall(function() controls:Enable() end) end
end

local function closeFullscreen()
	if activeFullscreenGui then
		activeFullscreenGui:Destroy()
		activeFullscreenGui = nil
		unfreezeCharacter()

		-- restore the camera
		local cam = workspace.CurrentCamera
		if cam and prevCameraType then
			cam.CameraType = prevCameraType
		end
		prevCameraType = nil

		-- remove the world blur
		if activeBlur then
			activeBlur:Destroy()
			activeBlur = nil
		end
	end
	for _, c in ipairs(activeFullscreenConns) do
		pcall(function() c:Disconnect() end)
	end
	activeFullscreenConns = {}
end

-- builds an X icon from two rotated bars so it renders on every platform/font
local function buildXIcon(parent)
	local function bar(rot)
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.5)
		b.Size = UDim2.fromOffset(32, 6)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BorderSizePixel = 0
		b.Rotation = rot
		b.ZIndex = (parent.ZIndex or 1) + 1
		mkCorner(b, 3)
		b.Parent = parent
	end
	bar(45)
	bar(-45)
end

-- fixed bank boards: open as a single page with no navigation (just exit)
local FIXED_BOARDS = { RealMoney = true, MoneyG = true, RealPlayer = true }

-- builds the navigation page list for fullscreen, starting on the clicked board
local function buildFullscreenPages(startGameId)
	-- fixed bank boards show only themselves, no navigation
	if FIXED_BOARDS[startGameId] then
		return { startGameId }
	end
	-- game board: itself + the standard analytics trio
	local pages = {}
	if startGameId ~= "General" and startGameId ~= "Money" and startGameId ~= "LastMessage" then
		table.insert(pages, startGameId)
	end
	table.insert(pages, "General")
	table.insert(pages, "Money")
	table.insert(pages, "LastMessage")
	return pages
end

local function openFullscreen(startGameId)
	closeFullscreen()

	local pages = buildFullscreenPages(startGameId)
	if #pages == 0 then return end

	-- single-page boards (fixed bank boards) have no navigation at all
	local singlePage = (#pages <= 1)

	-- freeze the avatar so navigation keys don't move it in the world
	freezeCharacter()

	-- lock the camera so swiping/dragging doesn't rotate the world view
	local lockCam = workspace.CurrentCamera
	if lockCam then
		prevCameraType = lockCam.CameraType
		lockCam.CameraType = Enum.CameraType.Scriptable
	end

	-- blur the world behind the dashboard to focus attention on it
	activeBlur = Instance.new("BlurEffect")
	activeBlur.Name = "AnalyticsDashboardBlur"
	activeBlur.Size = 56
	activeBlur.Parent = Lighting

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name        = "AnalyticsFullscreen"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn  = false
	screenGui.DisplayOrder  = 200
	screenGui.Parent = playerGui

	-- outer dark background
	local outer = mkFrame(screenGui, {
		Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.new(0,0,0)
	})
	outer.BackgroundTransparency = 0.15

	-- scaled inner content frame (1600x900 virtual canvas), centered
	local inner = mkFrame(outer, {
		Size = UDim2.fromOffset(SW, SH),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PALETTE.background
	})

	local cam  = workspace.CurrentCamera
	local vp   = cam.ViewportSize
	local scale = math.min(vp.X / SW, vp.Y / SH) * 0.96
	local uiScale = Instance.new("UIScale")
	uiScale.Scale  = scale
	uiScale.Parent = inner

	-- treat any screen narrower than 1000px as mobile (works in the Studio emulator too)
	local isPhone = vp.X < 1000
	-- only auto-hide the move buttons when touch is actually available (so a small
	-- non-touch window doesn't get stuck with buttons hidden and no way to reveal them)
	local touchHide = isPhone and UserInputService.TouchEnabled

	-- navigation state: start on the game's own page
	local currentIdx = 1

	-- bottom info panel (auto-hides after 2 seconds, re-shows on page change)
	local navPanel = mkFrame(outer, {
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.new(0.6, 0, 0, 64),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = PALETTE.surface,
	})
	navPanel.BackgroundTransparency = 0.08
	mkCorner(navPanel, 14)
	-- clamp width so it never gets absurdly wide or collides with edge buttons
	local navSize = Instance.new("UISizeConstraint")
	navSize.MaxSize = Vector2.new(900, 64)
	navSize.MinSize = Vector2.new(240, 64)
	navSize.Parent = navPanel
	local navStroke = Instance.new("UIStroke")
	navStroke.Color = PALETTE.grid
	navStroke.Thickness = 1
	navStroke.Transparency = 0.4
	navStroke.Parent = navPanel

	local navLabel = mkLabel(navPanel, "", {
		Size = UDim2.new(1, -32, 1, -16),
		Position = UDim2.fromOffset(16, 8),
		TextColor3 = PALETTE.text,
		Font = Enum.Font.GothamMedium, TextSize = 26,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center
	})
	-- cap the scaled text so it doesn't get huge on a short string
	local navText = Instance.new("UITextSizeConstraint")
	navText.MaxTextSize = 26
	navText.MinTextSize = 11
	navText.Parent = navLabel

	-- buttons are forward-declared so showNav can toggle them on phones
	local prevBtn, nextBtn

	-- token guards the auto-hide timer so rapid page changes reset it
	local navToken = 0
	local function showNav()
		navToken += 1
		local myToken = navToken

		local gameId = pages[currentIdx]
		local controls
		if singlePage then
			-- fixed board: only the exit hint, no navigation
			if isPhone then controls = "Tap X to exit"
			elseif UserInputService.GamepadEnabled then controls = "B to exit"
			else controls = "Esc to exit" end
			navLabel.Text = string.format("%s     |     %s", labelFor(gameId), controls)
		else
			if isPhone then
				controls = "Swipe left / right to navigate  ·  Tap X to exit"
			elseif UserInputService.TouchEnabled then
				controls = "Tap arrows to navigate  ·  Tap X to exit"
			elseif UserInputService.GamepadEnabled then
				controls = "D-Pad / LB-RB navigate  ·  B exit"
			else
				controls = "A/D or arrows navigate  ·  Esc exit"
			end
			navLabel.Text = string.format("%d / %d   ·   %s     |     %s",
				currentIdx, #pages, labelFor(gameId), controls)
		end

		-- snap to visible
		navPanel.Visible = true
		TweenService:Create(navPanel, TweenInfo.new(0.2), { BackgroundTransparency = 0.08 }):Play()
		TweenService:Create(navStroke, TweenInfo.new(0.2), { Transparency = 0.4 }):Play()
		TweenService:Create(navLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

		-- on touch phones the move buttons appear together with the panel
		if touchHide and prevBtn and nextBtn then
			prevBtn.Visible = true
			nextBtn.Visible = true
		end

		-- fade out after 2 seconds
		task.delay(2, function()
			if myToken ~= navToken then return end
			if not navPanel.Parent then return end
			TweenService:Create(navPanel, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(navStroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			TweenService:Create(navLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			-- on touch phones, also hide the move buttons (swipe still works)
			if touchHide and prevBtn and nextBtn then
				prevBtn.Visible = false
				nextBtn.Visible = false
			end
		end)
	end

	local function refresh()
		local gameId = pages[currentIdx]
		showNav()

		clearContent(inner)
		mkLabel(inner, "Loading...", {
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(400, 80),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = PALETTE.textDim, Font = Enum.Font.GothamBold, TextSize = 52,
			TextXAlignment = Enum.TextXAlignment.Center
		})

		task.spawn(function()
			if not screenGui.Parent then return end
			if gameId == "LastMessage" then
				if screenGui.Parent then renderLastMessage(inner, gameId) end
			elseif gameId == "General" then
				local ok, p = pcall(function() return GetGeneralDashboard:InvokeServer() end)
				if screenGui.Parent then renderGeneralDashboard(inner, ok and p or emptyGeneralData()) end
			elseif gameId == "Money" then
				local ok, p = pcall(function() return GetMoneyDashboard:InvokeServer() end)
				if screenGui.Parent then renderMoneyDashboard(inner, ok and p or emptyMoneyData()) end
			elseif gameId == "MoneyG" then
				local ok, p = pcall(function() return GetMoneyDashboard:InvokeServer() end)
				if screenGui.Parent then renderMoneyG(inner, ok and p or emptyMoneyData()) end
			elseif gameId == "RealMoney" then
				local ok, p = pcall(function() return GetRecentDonations:InvokeServer() end)
				if screenGui.Parent then renderRealMoney(inner, ok and p or {}) end
			elseif gameId == "RealPlayer" then
				local ok, p = pcall(function() return GetRecentScores:InvokeServer() end)
				if screenGui.Parent then renderRealPlayer(inner, ok and p or {}) end
			else
				local ok, p = pcall(function() return GetGameDashboard:InvokeServer(gameId) end)
				if screenGui.Parent then renderGameDashboard(inner, gameId, ok and p or emptyGameData()) end
			end
		end)
	end

	-- page navigation
	local function goPrev()
		currentIdx = currentIdx > 1 and currentIdx - 1 or #pages
		refresh()
	end
	local function goNext()
		currentIdx = currentIdx < #pages and currentIdx + 1 or 1
		refresh()
	end

	-- on-screen navigation buttons float at the screen edges (mouse / touch).
	-- on phones they are pinned to the absolute screen extremes and always visible.
	-- fixed single-page boards get no move buttons at all.
	if not singlePage then
		local edgeInset = isPhone and 0 or 24
		local btnProps = {
			Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = PALETTE.surface,
			Font = Enum.Font.GothamBold,
			TextColor3 = PALETTE.text,
			TextSize = 44,
			AutoButtonColor = true,
			BorderSizePixel = 0,
		}

		prevBtn = Instance.new("TextButton")
		prevBtn.AnchorPoint = Vector2.new(0, 0.5)
		prevBtn.Position = UDim2.new(0, edgeInset, 0.5, 0)
		prevBtn.Text = "◀"
		for k,v in pairs(btnProps) do prevBtn[k]=v end
		mkCorner(prevBtn, 12)
		mkStroke(prevBtn, PALETTE.grid, 1, 0.4)
		if isPhone then prevBtn.BackgroundTransparency = 0.15 end
		prevBtn.Parent = outer
		prevBtn.MouseButton1Click:Connect(goPrev)

		nextBtn = Instance.new("TextButton")
		nextBtn.AnchorPoint = Vector2.new(1, 0.5)
		nextBtn.Position = UDim2.new(1, -edgeInset, 0.5, 0)
		nextBtn.Text = "▶"
		for k,v in pairs(btnProps) do nextBtn[k]=v end
		mkCorner(nextBtn, 12)
		mkStroke(nextBtn, PALETTE.grid, 1, 0.4)
		if isPhone then nextBtn.BackgroundTransparency = 0.15 end
		nextBtn.Parent = outer
		nextBtn.MouseButton1Click:Connect(goNext)
	end

	-- exit button with a frame-drawn X (renders on all platforms), top-right corner
	local exitBtn = Instance.new("TextButton")
	exitBtn.AnchorPoint = Vector2.new(1, 0)
	exitBtn.Position = UDim2.new(1, -24, 0, 24)
	exitBtn.Size = UDim2.fromOffset(68, 68)
	exitBtn.BackgroundColor3 = PALETTE.danger
	exitBtn.Text = ""
	exitBtn.AutoButtonColor = true
	exitBtn.BorderSizePixel = 0
	mkCorner(exitBtn, 12)
	exitBtn.Parent = outer
	buildXIcon(exitBtn)
	exitBtn.MouseButton1Click:Connect(closeFullscreen)

	-- on touch phones the buttons start visible, then auto-hide via showNav (swipe is primary)
	if touchHide and prevBtn and nextBtn then
		prevBtn.Visible = true
		nextBtn.Visible = true
	end

	-- initial render
	refresh()

	-- unified cross-platform input: keyboard + gamepad
	table.insert(activeFullscreenConns, UserInputService.InputBegan:Connect(function(input, processed)
		local kc = input.KeyCode

		-- exit handled even when gameProcessed (Esc is usually consumed by the Roblox menu)
		if kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB then
			closeFullscreen()
			return
		end

		-- fixed boards have no page navigation
		if singlePage then return end

		-- navigation keys respect gameProcessed (so chat typing doesn't navigate)
		if processed then return end

		-- previous page: A / Left / W / Up / D-Pad / LB
		if kc == Enum.KeyCode.A or kc == Enum.KeyCode.Left
			or kc == Enum.KeyCode.W or kc == Enum.KeyCode.Up
			or kc == Enum.KeyCode.DPadLeft or kc == Enum.KeyCode.DPadUp
			or kc == Enum.KeyCode.ButtonL1 then
			goPrev()
			return
		end

		-- next / select: D / Right / S / Down / D-Pad / RB / Enter / Space / A (Xbox) / Cross (PS)
		if kc == Enum.KeyCode.D or kc == Enum.KeyCode.Right
			or kc == Enum.KeyCode.S or kc == Enum.KeyCode.Down
			or kc == Enum.KeyCode.DPadRight or kc == Enum.KeyCode.DPadDown
			or kc == Enum.KeyCode.ButtonR1
			or kc == Enum.KeyCode.Return or kc == Enum.KeyCode.Space
			or kc == Enum.KeyCode.ButtonA then
			goNext()
			return
		end
	end))

	-- touch navigation only for multi-page boards
	if not singlePage then
		-- swipe left/right to change dashboard (carousel)
		table.insert(activeFullscreenConns, UserInputService.TouchSwipe:Connect(function(dir, _, processed)
			if dir == Enum.SwipeDirection.Left then
				goNext()
			elseif dir == Enum.SwipeDirection.Right then
				goPrev()
			end
		end))

		-- tapping anywhere re-reveals the controls for 2 seconds
		table.insert(activeFullscreenConns, UserInputService.TouchTap:Connect(function(_, processed)
			if processed then return end
			showNav()
		end))
	end

	activeFullscreenGui = screenGui
end

-- ----------------------------------------------------------------------------
-- board lifecycle
-- ----------------------------------------------------------------------------

-- builds a cheap signature of a feed so we only rebuild the ticker when it changes
local function feedSignature(items)
	local n = #items
	if n == 0 then return "0" end
	local top = items[1]
	return n .. "|" .. tostring(top.name) .. "|" .. tostring(top.robux or top.score) .. "|" .. tostring(top.t)
end

local function refreshBoard(board)
	if not board.bg or not board.bg.Parent then return end
	local gid = board.gameId

	if gid == "General" then
		local ok, p = pcall(function() return GetGeneralDashboard:InvokeServer() end)
		renderGeneralDashboard(board.bg, ok and p or emptyGeneralData())
	elseif gid == "Money" then
		local ok, p = pcall(function() return GetMoneyDashboard:InvokeServer() end)
		renderMoneyDashboard(board.bg, ok and p or emptyMoneyData())
	elseif gid == "MoneyG" then
		local ok, p = pcall(function() return GetMoneyDashboard:InvokeServer() end)
		renderMoneyG(board.bg, ok and p or emptyMoneyData())
	elseif gid == "RealMoney" then
		local ok, p = pcall(function() return GetRecentDonations:InvokeServer() end)
		local items = ok and p or {}
		-- only rebuild the ticker if the feed actually changed (keeps scroll smooth)
		local sig = feedSignature(items)
		if sig ~= board._feedSig then
			board._feedSig = sig
			renderRealMoney(board.bg, items)
		end
	elseif gid == "RealPlayer" then
		local ok, p = pcall(function() return GetRecentScores:InvokeServer() end)
		local items = ok and p or {}
		local sig = feedSignature(items)
		if sig ~= board._feedSig then
			board._feedSig = sig
			renderRealPlayer(board.bg, items)
		end
	elseif gid == "LastMessage" then
		-- static page, no server call
		renderLastMessage(board.bg, gid)
	else
		local ok, p = pcall(function() return GetGameDashboard:InvokeServer(gid) end)
		renderGameDashboard(board.bg, gid, ok and p or emptyGameData())
	end
end

local function setupBoard(part)
	if not part:IsA("BasePart") then return end
	local gameId = part:GetAttribute("GameId")
	if not gameId then
		warn("[Analytics] part missing GameId: " .. part:GetFullName())
		return
	end
	if activeBoards[part] then return end

	print(string.format("[Analytics] board: %s (%s)", gameId, faceFromPart(part).Name))

	local gui, bg = makeSurfaceGui(part, gameId)
	local board = { part=part, gui=gui, bg=bg, gameId=gameId }
	activeBoards[part] = board

	-- render empty state immediately
	if gameId == "General" then
		renderGeneralDashboard(bg, emptyGeneralData())
	elseif gameId == "Money" then
		renderMoneyDashboard(bg, emptyMoneyData())
	elseif gameId == "MoneyG" then
		renderMoneyG(bg, emptyMoneyData())
	elseif gameId == "RealMoney" then
		renderRealMoney(bg, {})
	elseif gameId == "RealPlayer" then
		renderRealPlayer(bg, {})
	elseif gameId == "LastMessage" then
		renderLastMessage(bg, gameId)
	else
		renderGameDashboard(bg, gameId, emptyGameData())
	end

	-- fetch real data after 1 second
	task.spawn(function()
		task.wait(1)
		refreshBoard(board)
	end)

	-- live feed boards poll faster (every ~4s) for a near real-time ticker
	if FEED_BOARDS[gameId] then
		task.spawn(function()
			while board.bg and board.bg.Parent do
				task.wait(4)
				if activeBoards[part] == board then
					refreshBoard(board)
				else
					break
				end
			end
		end)
	end

	-- transparent click button on top of SurfaceGui — only opens when the player is near
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.fromScale(1, 1)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.ZIndex = 50
	clickBtn.Parent = gui
	clickBtn.MouseButton1Click:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		-- require proximity so the board can't be opened from across the map
		if (hrp.Position - part.Position).Magnitude <= OPEN_DISTANCE then
			openFullscreen(gameId)
		end
	end)

	-- proximity prompt — cross-platform: E (PC), Y (gamepad), touch button (mobile)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText  = "Full Screen"
	prompt.ObjectText  = labelFor(gameId)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode  = Enum.KeyCode.ButtonY
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0
	prompt.Parent = part

	ProximityPromptService.PromptTriggered:Connect(function(p, trigPlayer)
		if p == prompt and trigPlayer == player then
			openFullscreen(gameId)
		end
	end)
end

local function teardownBoard(part)
	local b = activeBoards[part]
	if not b then return end
	if b.gui then b.gui:Destroy() end
	activeBoards[part] = nil
end

-- ----------------------------------------------------------------------------
-- entry point
-- ----------------------------------------------------------------------------

for _, part in ipairs(CollectionService:GetTagged("AnalyticsBoard")) do
	setupBoard(part)
end

CollectionService:GetInstanceAddedSignal("AnalyticsBoard"):Connect(setupBoard)
CollectionService:GetInstanceRemovedSignal("AnalyticsBoard"):Connect(teardownBoard)

local lastBroadcast = os.clock()

DashboardUpdated.OnClientEvent:Connect(function()
	lastBroadcast = os.clock()
	for _, board in pairs(activeBoards) do
		refreshBoard(board)
	end
end)

-- fallback refresh if broadcast never arrives
task.spawn(function()
	while true do
		task.wait(60)
		if os.clock() - lastBroadcast > 60 then
			for _, board in pairs(activeBoards) do refreshBoard(board) end
		end
	end
end)
