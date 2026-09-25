local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

-- load shared modules
local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local Menu1to7 = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu1to7"))

-- fetch all remotes needed for avis toucan
local function findFlappyRemotes()
	local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes", 30)
	if not arc then return nil, nil, nil, nil, nil end
	local OpenArcadeMenu = arc:WaitForChild("OpenArcadeMenu", 10)
	local flappyFolder = arc:WaitForChild("AvisToucan", 10)
	local StartRequest, SubmitFlap, GameState, ToggleAudio

	if flappyFolder then
		StartRequest = flappyFolder:WaitForChild("StartAvisToucanRequest", 10)
		SubmitFlap = flappyFolder:WaitForChild("SubmitFlap", 10)
		GameState = flappyFolder:WaitForChild("GameState", 10)
		ToggleAudio = flappyFolder:WaitForChild("ToggleAudio", 10)
	end
	return StartRequest, SubmitFlap, GameState, OpenArcadeMenu, ToggleAudio
end

local StartFlappyRequest, SubmitFlap, GameState, OpenArcadeMenu, ToggleAudio = findFlappyRemotes()

-- abort if critical remotes are missing
if not (StartFlappyRequest and SubmitFlap and GameState and OpenArcadeMenu) then
	script.Disabled = true
	return
end

-- sound toggle and asset ids
local soundEnabled = true
local didPreloadOnce = false

local EAT_SOUND_ID  = "rbxassetid://92876108656319"
local BG_ID         = "rbxassetid://91967193285816"
local PIPE_DOWNID   = "rbxassetid://101253287538303"
local PIPE_UP_ID    = "rbxassetid://137927854784983"
local TUCAN_1       = "rbxassetid://121493955532115"
local TUCAN_3       = "rbxassetid://133330827904299"

local eatSound = Instance.new("Sound", script)
eatSound.SoundId = EAT_SOUND_ID
eatSound.Volume = 0.6

if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local function playEatSound()
	if soundEnabled and not eatSound.IsPlaying then eatSound:Play() end
end

-- game state and canvas dimensions
local inGame = false
local gameGui, canvas, scoreLabel, hudExitBtn, hudMuteBtn, pressHintLabel
local cellSize, cols, rows = 30, 16, 12
local cw, ch = cols * cellSize, rows * cellSize
local lastScore = 0
local BIRD_W, BIRD_H = 60, 45
local birdImageLabel = nil
local birdX, birdY = math.floor(cw * 0.27), 20
local pipeVisuals = {}
local flapSequenceId = 0
local FLAP_FRAME_TIME = 0.4

-- convert hex string to Color3
local function Color3FromHex(hex)
	hex = tostring(hex or ""):gsub("#","")
	if #hex == 3 then hex = hex:gsub(".", "%1%1") end
	return Color3.fromRGB(tonumber(hex:sub(1,2), 16) or 255, tonumber(hex:sub(3,4), 16) or 255, tonumber(hex:sub(5,6), 16) or 255)
end

local COLOR_BTN_BASE = Color3FromHex("00bc7d")
local COLOR_BTN_EXIT = Color3FromHex("004f3b")
local CAP_COLOR      = Color3FromHex("004f3b")
local CAP_THICK      = 16

-- donation product ids for the vip menu
local DONATION_PRODUCTS = {
	{ Id = 3474073921, Price = 5,    Name = "Toucan Tip" },
	{ Id = 3474074313, Price = 15,   Name = "Toucan Treat" },
	{ Id = 3474074984, Price = 50,   Name = "Toucan Sub" },
	{ Id = 3474075222, Price = 100,  Name = "Toucan Sponsor" },
	{ Id = 3474075401, Price = 500,  Name = "Toucan Whale" },
	{ Id = 3474075594, Price = 1000, Name = "Toucan Legend" },
}

-- overlay shown while preloading images
local function showLoadingOverlay()
	local overlay = Instance.new("ScreenGui", playerGui)
	overlay.Name = "ToucanPreloadOverlay"
	overlay.DisplayOrder = 9999

	local frame = Instance.new("Frame", overlay)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.new(0.5,0,0.5,0)
	frame.Size = UDim2.new(0.4, 0, 0.2, 0)
	frame.BackgroundColor3 = COLOR_BTN_BASE
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local lbl = Instance.new("TextLabel", frame)
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "LOADING ASSETS..."
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1,1,1)

	return overlay
end

-- config table consumed by Menu1to7
local configFlappy = {
	Titulo = "AVIS TOUCAN",
	IconoPrincipal = "🐦",
	IconosBotones = { Play = "🎮", Vip = "👑", Exit = "🚪" },
	ColorFondo = "5ee9b5",
	ColorBtnPlay = "a4f4cf",
	ColorBtnVip = "00bc7d",
	ColorBtnExit = "004f3b",
	Donaciones = DONATION_PRODUCTS,

	Controlador = UniversalController,

	OnPlay = function()
		-- preload assets only on first play to avoid stalls
		if not didPreloadOnce then
			local overlay = showLoadingOverlay()
			local t0 = os.clock()
			local bucket = Instance.new("Folder")

			local function mkImg(id)
				local i = Instance.new("ImageLabel", bucket)
				i.Image = id
				return i
			end
			mkImg(BG_ID); mkImg(PIPE_DOWNID); mkImg(PIPE_UP_ID); mkImg(TUCAN_1); mkImg(TUCAN_3)

			pcall(function() ContentProvider:PreloadAsync(bucket:GetChildren()) end)

			local remain = math.max(0, 2 - (os.clock() - t0))
			if remain > 0 then task.wait(remain) end

			overlay:Destroy()
			bucket:Destroy()
			didPreloadOnce = true
		end

		inGame = true
		initFlappyGui()
		if StartFlappyRequest then pcall(function() StartFlappyRequest:FireServer() end) end
	end,

	OnExit = function()
		print("returning to hub...")
	end
}

-- show flap frame then revert to idle frame after a short delay
local function animateFlapOnce()
	if not birdImageLabel then return end
	flapSequenceId = flapSequenceId + 1
	local myId = flapSequenceId
	birdImageLabel.Image = TUCAN_3
	birdImageLabel.Size = UDim2.new(BIRD_W / cw, 0, BIRD_H / ch, 0)
	local thisLabel = birdImageLabel

	task.delay(FLAP_FRAME_TIME, function()
		if myId ~= flapSequenceId then return end
		if not inGame or not birdImageLabel or birdImageLabel ~= thisLabel then return end
		birdImageLabel.Image = TUCAN_1
		birdImageLabel.Size = UDim2.new(BIRD_W / cw, 0, BIRD_H / ch, 0)
	end)
end

-- animate bird and send flap to server on input
local function handleFlapAction(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin and inGame then
		animateFlapOnce()
		if SubmitFlap then pcall(function() SubmitFlap:FireServer() end) end
	end
end

-- also catches direct touch/click events not routed through ContextActionService
UserInputService.InputBegan:Connect(function(input, processed)
	if inGame and not processed then
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			animateFlapOnce()
			if SubmitFlap then pcall(function() SubmitFlap:FireServer() end) end
		end
	end
end)

-- destroy game gui and clear all references
local function cleanupGameGui()
	if gameGui then gameGui:Destroy() end
	gameGui = nil
	canvas = nil
	birdImageLabel = nil
	hudExitBtn = nil
	hudMuteBtn = nil
	pressHintLabel = nil
	pipeVisuals = {}
	UniversalController.LimpiarControles()
end

-- stop game and return to main menu
local function exitCurrentGame()
	inGame = false
	cleanupGameGui()
	Menu1to7.AbrirMenuPrincipal(configFlappy)
end

-- sync mute button appearance to current sound state
local function updateMuteButtonVisuals(btn)
	if not btn then return end
	if soundEnabled then
		btn.BackgroundColor3 = COLOR_BTN_BASE
		btn.Text = "🔊 ON"
	else
		btn.BackgroundColor3 = Color3.fromHex("666666")
		btn.Text = "🔇 MUTED"
	end
end

-- build in-game screen gui with canvas, bird, pipes, score strip and hud buttons
function initFlappyGui()
	cleanupGameGui()
	Menu1to7.EstablecerEnfoque(true)

	gameGui = Instance.new("ScreenGui", playerGui)
	gameGui.Name = "FlappyGameGui"
	gameGui.ResetOnSpawn = false

	local gameFrame = Instance.new("Frame", gameGui)
	gameFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	gameFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	gameFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
	gameFrame.BackgroundTransparency = 1

	Instance.new("UIAspectRatioConstraint", gameFrame).AspectRatio = cw / (ch + 30)
	Instance.new("UISizeConstraint", gameFrame).MaxSize = Vector2.new(960, 780)

	local scoreStrip = Instance.new("Frame", gameFrame)
	scoreStrip.Size = UDim2.new(1, 0, 30/390, 0)
	scoreStrip.BackgroundColor3 = Color3.new(0, 0, 0)
	scoreStrip.BackgroundTransparency = 0.5
	scoreStrip.ZIndex = 3

	canvas = Instance.new("Frame", gameFrame)
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, 0, ch/(ch+30), 0)
	canvas.Position = UDim2.new(0, 0, 30/(ch+30), 0)
	canvas.BackgroundTransparency = 1
	canvas.ClipsDescendants = true

	local bg = Instance.new("ImageLabel", canvas)
	bg.BackgroundTransparency = 1
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.Image = BG_ID
	bg.ScaleType = Enum.ScaleType.Crop
	bg.ZIndex = 0

	scoreLabel = Instance.new("TextLabel", gameFrame)
	scoreLabel.Size = UDim2.new(0.5, 0, 30/390, 0)
	scoreLabel.Position = UDim2.new(0, 6, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.new(1, 1, 1)
	scoreLabel.TextScaled = true
	scoreLabel.Text = "Score: 0"
	scoreLabel.ZIndex = 4

	birdImageLabel = Instance.new("ImageLabel", canvas)
	birdImageLabel.BackgroundTransparency = 1
	birdImageLabel.Image = TUCAN_1
	birdImageLabel.Size = UDim2.new(BIRD_W / cw, 0, BIRD_H / ch, 0)
	birdImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	birdImageLabel.Position = UDim2.new((birdX + BIRD_W * 0.5) / cw, 0, (birdY + BIRD_H * 0.5) / ch, 0)
	birdImageLabel.ZIndex = 2

	lastScore = 0

	-- hint hidden once the server sends "started = true"
	pressHintLabel = Instance.new("TextLabel", gameFrame)
	pressHintLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	pressHintLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	pressHintLabel.Size = UDim2.new(0.9, 0, 0.15, 0)
	pressHintLabel.BackgroundTransparency = 1
	pressHintLabel.Text = "PRESS SPACE TO START"
	pressHintLabel.Font = Enum.Font.GothamBold
	pressHintLabel.TextColor3 = Color3.new(1, 1, 1)
	pressHintLabel.TextScaled = true
	pressHintLabel.ZIndex = 5

	hudExitBtn = Instance.new("TextButton", gameFrame)
	hudExitBtn.AnchorPoint = Vector2.new(1, 0)
	hudExitBtn.Position = UDim2.new(0.98, 0, 2/390, 0)
	hudExitBtn.Size = UDim2.new(0.15, 0, 26/390, 0)
	hudExitBtn.BackgroundColor3 = COLOR_BTN_EXIT
	hudExitBtn.Text = "EXIT"
	hudExitBtn.TextColor3 = Color3.new(1, 1, 1)
	hudExitBtn.TextScaled = true
	hudExitBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudExitBtn).CornerRadius = UDim.new(0, 8)
	hudExitBtn.MouseButton1Click:Connect(function() exitCurrentGame() end)

	hudMuteBtn = Instance.new("TextButton", gameFrame)
	hudMuteBtn.AnchorPoint = Vector2.new(1, 0)
	hudMuteBtn.Position = UDim2.new(0.82, 0, 2/390, 0)
	hudMuteBtn.Size = UDim2.new(0.20, 0, 26/390, 0)
	hudMuteBtn.TextColor3 = Color3.new(1, 1, 1)
	hudMuteBtn.TextScaled = true
	hudMuteBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudMuteBtn).CornerRadius = UDim.new(0, 8)
	updateMuteButtonVisuals(hudMuteBtn)

	hudMuteBtn.MouseButton1Click:Connect(function()
		soundEnabled = not soundEnabled
		updateMuteButtonVisuals(hudMuteBtn)
		if ToggleAudio then ToggleAudio:FireServer(soundEnabled) end
	end)

	UniversalController.CrearControlesFlappy(handleFlapAction)
end

-- play eat sound when score goes up, then update label
local function updateScore(newScore)
	if not scoreLabel then return end
	if newScore > lastScore then playEatSound() end
	lastScore = newScore
	scoreLabel.Text = "Score: " .. tostring(newScore)
end

-- lazily create pipe visual entries up to the requested index
local function ensurePipeVisual(index)
	while #pipeVisuals < index do
		local topCap = Instance.new("Frame", canvas)
		topCap.BackgroundColor3 = CAP_COLOR
		topCap.BorderSizePixel = 0
		topCap.ZIndex = 0

		local top = Instance.new("ImageLabel", canvas)
		top.BackgroundTransparency = 1
		top.Image = PIPE_UP_ID
		top.ScaleType = Enum.ScaleType.Stretch
		top.ZIndex = 1

		local bottom = Instance.new("ImageLabel", canvas)
		bottom.BackgroundTransparency = 1
		bottom.Image = PIPE_DOWNID
		bottom.ScaleType = Enum.ScaleType.Stretch
		bottom.ZIndex = 1

		table.insert(pipeVisuals, { x = 0, gapY = 0, top = top, bottom = bottom, topCap = topCap })
	end
end

-- translate server game state into gui positions and sizes
local function applyServerStateToGui(state)
	if not gameGui or not canvas or not state then return end
	local canvasW = state.canvasW or cw
	local canvasH = state.canvasH or ch

	if pressHintLabel then pressHintLabel.Visible = not state.started end
	if birdImageLabel and state.birdX and state.birdY then
		local bw = state.birdW or BIRD_W
		local bh = state.birdH or BIRD_H
		birdImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		birdImageLabel.Size = UDim2.new(bw / canvasW, 0, bh / canvasH, 0)
		birdImageLabel.Position = UDim2.new((state.birdX + bw * 0.5) / canvasW, 0, (state.birdY + bh * 0.5) / canvasH, 0)
	end
	if state.score ~= nil then updateScore(state.score) end

	local gap   = state.gap   or 146
	local pipeW = state.pipeW or 75
	local pipes = state.pipes or {}

	for i, p in ipairs(pipes) do
		ensurePipeVisual(i)
		local v    = pipeVisuals[i]
		local x    = p.x    or 0
		local gapY = p.gapY or (canvasH / 2)
		local topH = math.max(0, gapY - math.floor(gap / 2))
		local botY = gapY + math.floor(gap / 2)
		local botH = math.max(0, canvasH - botY)

		v.top.Visible    = topH > 0
		v.topCap.Visible = topH > 0
		v.bottom.Visible = botH > 0

		local wScale = pipeW / canvasW
		if topH > 0 then
			v.top.Size     = UDim2.new(wScale, 0, topH / canvasH, 0)
			v.top.Position = UDim2.new(x / canvasW, 0, 0, 0)
			v.topCap.Size     = UDim2.new(wScale, 0, CAP_THICK / canvasH, 0)
			v.topCap.Position = UDim2.new(x / canvasW, 0, 0, 0)
		end
		if botH > 0 then
			v.bottom.Size     = UDim2.new(wScale, 0, botH / canvasH, 0)
			v.bottom.Position = UDim2.new(x / canvasW, 0, botY / canvasH, 0)
		end
	end

	-- hide pipe visuals that are no longer in server state
	for j = #pipes + 1, #pipeVisuals do
		local v = pipeVisuals[j]
		v.top.Visible = false; v.bottom.Visible = false; v.topCap.Visible = false
	end
end

-- open menu when the arcade machine triggers this game
if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gameName)
		if gameName == "AvisToucan" and not inGame then
			Menu1to7.AbrirMenuPrincipal(configFlappy)
		end
	end)
end

-- handle start, update and end events from the server
if GameState then
	GameState.OnClientEvent:Connect(function(m, d)
		if m == "Start" then
			if not gameGui then initFlappyGui() end
			inGame = true
			if d then applyServerStateToGui(d) end
		elseif m == "Update" then
			if inGame and d then applyServerStateToGui(d) end
		elseif m == "End" then
			if inGame then
				if d and d.score then updateScore(d.score) end
				inGame = false
				cleanupGameGui()
				Menu1to7.AbrirGameOver(lastScore, false)
			end
		end
	end)
end
