local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local localUserId = player.UserId

print("universal leaderboard client loaded.")

local function Color3FromHex(hex)
	hex = tostring(hex or ""):gsub("#","")
	if #hex == 3 then hex = hex:gsub(".", "%1%1") end
	return Color3.fromRGB(tonumber(hex:sub(1,2), 16) or 255, tonumber(hex:sub(3,4), 16) or 255, tonumber(hex:sub(5,6), 16) or 255)
end

local function formatTimeMs(ms)
	local totalMs = tonumber(ms) or 0
	local s = math.floor(totalMs / 1000)
	local minutes = math.floor(s / 60)
	local seconds = s % 60
	local millis = totalMs % 1000
	return string.format("%02d:%02d.%03d", minutes, seconds, millis)
end

local COLUMNS_CONFIG = {
	{ Name = "",      Type = "Image", Width = 0.12, Align = Enum.TextXAlignment.Center },
	{ Name = "POS",   Type = "Text",  Width = 0.10, Align = Enum.TextXAlignment.Center },
	{ Name = "NAME",  Type = "Text",  Width = 0.40, Align = Enum.TextXAlignment.Left   },
	{ Name = "SCORE", Type = "Text",  Width = 0.20, Align = Enum.TextXAlignment.Center },
	{ Name = "TIME",  Type = "Text",  Width = 0.18, Align = Enum.TextXAlignment.Right  },
}

local BORDER_THICKNESS = 12
local ROW_HEIGHT = 55
local HEADER_HEIGHT = 50
local TEXT_SIZE_BODY = 32
local TEXT_SIZE_HEADER = 24

local activeBoards = {}
-- caches this player's own rank per game so the 10th row can show their score
-- when they are outside the top 10. nil means unranked / not fetched yet.
local myRankCache = {}

-- creates a single cell in a row, either as text or an async avatar image
local function createRowCell(parentRow, content, colConfig, isHeader, currentPalette, gameId)
	local container = Instance.new("Frame", parentRow)
	container.Name = colConfig.Name == "" and "Icon" or colConfig.Name
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(colConfig.Width, 0, 1, 0)

	if isHeader or colConfig.Type == "Text" then
		local label = Instance.new("TextLabel", container)
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = isHeader and Enum.Font.GothamBold or Enum.Font.GothamSemibold
		label.Text = tostring(content)

		if isHeader then
			label.TextColor3 = Color3FromHex(currentPalette.HeaderTextCol)
			label.TextSize = TEXT_SIZE_HEADER
		else
			if gameId == "Oxybelis" and (colConfig.Name == "SCORE" or colConfig.Name == "POS") then
				label.TextColor3 = Color3FromHex(currentPalette.SpecialTextCol)
			else
				label.TextColor3 = Color3FromHex(currentPalette.TextLight)
			end
			label.TextSize = TEXT_SIZE_BODY
		end

		if colConfig.Name == "SCORE" and not isHeader then
			label.Font = Enum.Font.GothamBlack
		end

		label.TextXAlignment = colConfig.Align

		local pad = Instance.new("UIPadding", label)
		pad.PaddingLeft = UDim.new(0, 5)
		pad.PaddingRight = UDim.new(0, 5)

	elseif colConfig.Type == "Image" and not isHeader then
		local imgContainer = Instance.new("Frame", container)
		imgContainer.Size = UDim2.fromScale(0.9, 0.9)
		imgContainer.Position = UDim2.fromScale(0.05, 0.05)
		imgContainer.BackgroundTransparency = 1
		Instance.new("UIAspectRatioConstraint", imgContainer)

		local image = Instance.new("ImageLabel", imgContainer)
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		Instance.new("UICorner", image).CornerRadius = UDim.new(1, 0)

		local userId = tonumber(content)
		if userId and userId > 0 then
			task.spawn(function()
				local thumb, isReady = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				if isReady and image.Parent then
					image.Image = thumb
				end
			end)
		end
	end
end

-- creates or updates a surface gui leaderboard on a world part for the given game
local function renderOnPart(part, gameId, gameData)
	local config = gameData.Config
	local top = gameData.Top10
	local palette = config.Palette

	if not activeBoards[part] then
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "UniversalSurface_" .. part.Name
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surfaceGui.CanvasSize = Vector2.new(900, 950)
		surfaceGui.Adornee = part
		surfaceGui.Parent = player:WaitForChild("PlayerGui")

		local borderFrame = Instance.new("Frame", surfaceGui)
		borderFrame.Name = "BorderFrame"
		borderFrame.Size = UDim2.fromScale(1, 1)
		borderFrame.BorderSizePixel = 0

		local glassFrame = Instance.new("Frame", borderFrame)
		glassFrame.Name = "GlassFrame"
		glassFrame.Size = UDim2.new(1, -(BORDER_THICKNESS * 2), 1, -(BORDER_THICKNESS * 2))
		glassFrame.Position = UDim2.fromOffset(BORDER_THICKNESS, BORDER_THICKNESS)
		glassFrame.BackgroundTransparency = palette.GlassTransp or 0.4
		Instance.new("UICorner", glassFrame).CornerRadius = UDim.new(0, 16)

		local titleLabel = Instance.new("TextLabel", glassFrame)
		titleLabel.Name = "TitleLabel"
		titleLabel.Size = UDim2.new(1, 0, 0.12, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBlack
		titleLabel.TextScaled = true
		Instance.new("UIPadding", titleLabel).PaddingTop = UDim.new(0, 15)

		local listContainer = Instance.new("Frame", glassFrame)
		listContainer.Name = "ListContainer"
		listContainer.BackgroundTransparency = 1
		listContainer.Position = UDim2.new(0.02, 0, 0.14, 0)
		listContainer.Size = UDim2.new(0.96, 0, 0.84, 0)
		listContainer.ClipsDescendants = true

		local layout = Instance.new("UIListLayout", listContainer)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)

		activeBoards[part] = {
			Border = borderFrame,
			Glass = glassFrame,
			Title = titleLabel,
			List = listContainer,
			CurrentPalette = palette
		}

		-- continuously pulses the title between two palette colors
		task.spawn(function()
			while titleLabel and titleLabel.Parent do
				local tInfo = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				local activeBoardData = activeBoards[part]

				local altPulseColor = activeBoardData and activeBoardData.CurrentPalette and activeBoardData.CurrentPalette.TitlePulseAlt or "ffffff"
				TweenService:Create(titleLabel, tInfo, {TextColor3 = Color3FromHex(altPulseColor)}):Play()
				task.wait(1.6)

				local targetPulseColor = activeBoardData and activeBoardData.CurrentPalette and activeBoardData.CurrentPalette.TitlePulse or "ffffff"
				TweenService:Create(titleLabel, tInfo, {TextColor3 = Color3FromHex(targetPulseColor)}):Play()
				task.wait(1.6)
			end
		end)
	end

	local board = activeBoards[part]
	board.CurrentPalette = palette

	local tInfo = TweenInfo.new(0.5)
	TweenService:Create(board.Border, tInfo, {BackgroundColor3 = Color3FromHex(palette.BorderColor)}):Play()
	TweenService:Create(board.Glass, tInfo, {
		BackgroundColor3 = Color3FromHex(palette.GlassColor),
		BackgroundTransparency = palette.GlassTransp or 0.4
	}):Play()

	board.Title.TextColor3 = Color3FromHex(palette.TitleMain)
	board.Title.Text = config.Title .. " Best Scores " .. config.Icon

	for _, child in ipairs(board.List:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local header = Instance.new("Frame", board.List)
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.BackgroundColor3 = Color3FromHex(palette.Header)
	header.BackgroundTransparency = palette.HeaderTransp or 0.2
	header.LayoutOrder = 1
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
	local hl = Instance.new("UIListLayout", header)
	hl.FillDirection = Enum.FillDirection.Horizontal

	for _, col in ipairs(COLUMNS_CONFIG) do
		local txt = col.Type == "Image" and "👤" or col.Name
		createRowCell(header, txt, col, true, palette, gameId)
	end

	-- decide which rows to render:
	--  - if the local player is already in the top 10, show the full top 10
	--  - if not, show the top 9 plus a 10th row with the player's own real rank
	local meInTop = false
	for _, e in ipairs(top) do
		if e.userId == localUserId then meInTop = true break end
	end

	local rows = {}
	if meInTop or not myRankCache[gameId] then
		rows = top
	else
		for i = 1, math.min(9, #top) do
			rows[i] = top[i]
		end
		rows[#rows + 1] = myRankCache[gameId]
	end

	if #rows == 0 then
		local empty = Instance.new("TextLabel", board.List)
		empty.Name = "EmptyText"
		empty.Size = UDim2.new(1, 0, 0, 100)
		empty.BackgroundTransparency = 1
		empty.Text = "No scores yet!"
		empty.TextColor3 = Color3FromHex(palette.TextLight)
		empty.Font = Enum.Font.GothamMedium
		empty.TextSize = 30
		empty.LayoutOrder = 2
	else
		for i, entry in ipairs(rows) do
			local row = Instance.new("Frame", board.List)
			row.Name = "Row_" .. i
			row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			row.LayoutOrder = i + 1

			local isMe = (entry.userId == localUserId)
			if isMe then
				row.BackgroundColor3 = Color3FromHex(palette.LocalPlayer)
				row.BackgroundTransparency = palette.LocalTransp or 0.3
			elseif i % 2 == 0 then
				row.BackgroundColor3 = Color3FromHex(palette.RowEven)
				row.BackgroundTransparency = palette.RowEvenTransp or 0.8
			else
				row.BackgroundColor3 = Color3FromHex(palette.RowOdd)
				row.BackgroundTransparency = palette.RowOddTransp or 0.9
			end

			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
			local rl = Instance.new("UIListLayout", row)
			rl.FillDirection = Enum.FillDirection.Horizontal

			createRowCell(row, entry.userId, COLUMNS_CONFIG[1], false, palette, gameId)
			createRowCell(row, "#" .. entry.position, COLUMNS_CONFIG[2], false, palette, gameId)
			createRowCell(row, entry.name, COLUMNS_CONFIG[3], false, palette, gameId)
			createRowCell(row, entry.score, COLUMNS_CONFIG[4], false, palette, gameId)
			createRowCell(row, formatTimeMs(entry.timeMs), COLUMNS_CONFIG[5], false, palette, gameId)
		end
	end
end

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes")
local GlobalBoardFolder = ArcadeRemotes:WaitForChild("GlobalBoard")
local UpdateUniversalLeaderboard = GlobalBoardFolder:WaitForChild("UpdateUniversalLeaderboard")
local GetMyRank = GlobalBoardFolder:WaitForChild("GetMyRank", 10)

-- maps tagged parts to their game id and triggers a re-render for each
UpdateUniversalLeaderboard.OnClientEvent:Connect(function(allData)
	local TAG_MAP = {
		["LeadboradOxybelis"]          = "Oxybelis",
		["LeadboradAvisToucan"]        = "AvisToucan",
		["LeadBoradTurris"]            = "TurrisCasei",
		["LeadboradResilio"]           = "Resilio",
		["LeadBoradImNotASphere"]      = "ImNotASphere",
		["LeadBoradFoxyFruit"]         = "FoxyFruit",
		["LeadboradFirmamentDefender"] = "FirmamentDefender",
		["LeadboradFirmamentSiege"]    = "FirmamentSiege",
		["LeadboradJuiceCutter"]       = "JuiceCutter",
		["LeadboradTapAndHold"]        = "TapAndHold"
	}

	for _, part in ipairs(workspace:GetDescendants()) do
		if (part.Name == "UniversalLeaderboardPart" or part.Name == "FirmamentDefenderLeaderboardPart" or part.Name == "JuiceCutterLeaderboardPart") and part:IsA("BasePart") then
			local gameId = part:GetAttribute("GAMEID") or part:GetAttribute("GameId")

			if not gameId then
				for tag, mappedGameId in pairs(TAG_MAP) do
					if CollectionService:HasTag(part, tag) then
						gameId = mappedGameId
						break
					end
				end
			end

			if gameId and allData[gameId] then
				renderOnPart(part, gameId, allData[gameId])

				-- refresh this player's own rank, then re-render so their row
				-- shows in slot 10 when they are outside the top 10
				if GetMyRank then
					local gd = allData[gameId]
					local thisPart = part
					local thisGameId = gameId
					task.spawn(function()
						local ok, rank = pcall(function()
							return GetMyRank:InvokeServer(thisGameId)
						end)
						if ok then
							myRankCache[thisGameId] = rank
							if thisPart and thisPart.Parent then
								renderOnPart(thisPart, thisGameId, gd)
							end
						end
					end)
				end
			end
		end
	end
end)
