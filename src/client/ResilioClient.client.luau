local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local Menu1to7 = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu1to7"))

local function findResilioRemotes()
	local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes")
	local res = arc:WaitForChild("Resilio")
	local startReq     = res:WaitForChild("StartResilioRequest")
	local submitMove   = res:WaitForChild("SubmitMoveInput")
	local submitLaunch = res:WaitForChild("SubmitLaunch")
	local gameState    = res:WaitForChild("GameState")
	local openMenu     = arc:WaitForChild("OpenArcadeMenu")
	local toggleAudio  = res:WaitForChild("ToggleAudio")
	return startReq, submitMove, submitLaunch, gameState, openMenu, toggleAudio
end

local StartRequest, SubmitMoveInput, SubmitLaunch, GameState, OpenArcadeMenu, ToggleAudio = findResilioRemotes()

local soundEnabled = true
local didPreloadOnce = false

local DESTROY_SOUND_ID = "rbxassetid://92876108656319"
local destroySound = Instance.new("Sound", script)
destroySound.SoundId = DESTROY_SOUND_ID
destroySound.Volume = 0.8

if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local function playDestroySound()
	if soundEnabled then
		if destroySound.IsPlaying then destroySound:Stop() end
		destroySound:Play()
	end
end

local inGame = false
local gameGui, canvas, scoreLabel = nil, nil, nil
local hudExitBtn, hudMuteBtn = nil, nil
local cols, rows = 16, 12
local cw, ch = cols * 30, rows * 30
local lastScore = 0

local unbindInputs, initResilioGui, bindInputs, exitCurrentGame

local function Color3FromHex(hex)
	hex = tostring(hex or ""):gsub("#","")
	if #hex == 3 then hex = hex:gsub(".", "%1%1") end
	return Color3.fromRGB(tonumber(hex:sub(1,2), 16) or 255, tonumber(hex:sub(3,4), 16) or 255, tonumber(hex:sub(5,6), 16) or 255)
end

local COLOR_BTN_EXIT = Color3FromHex("c6005c")

-- overlays a glass sheen over any frame
local function addGlassEffectToFrame(targetFrame)
	local glassOverlay = Instance.new("Frame")
	glassOverlay.Name = "GlassEffectOverlay"
	glassOverlay.Size = UDim2.new(1, 0, 1, 0)
	glassOverlay.BackgroundTransparency = 1
	glassOverlay.ZIndex = targetFrame.ZIndex + 1
	Instance.new("UICorner", glassOverlay).CornerRadius = targetFrame:FindFirstChildOfClass("UICorner") and targetFrame:FindFirstChildOfClass("UICorner").CornerRadius or UDim.new(0, 10)

	local gradient = Instance.new("UIGradient", glassOverlay)
	gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))})
	gradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 0.95)})
	gradient.Rotation = 90

	local uiStroke = Instance.new("UIStroke", glassOverlay)
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Color = Color3.new(1, 1, 1)
	uiStroke.Thickness = 1
	uiStroke.Transparency = 0.7
	glassOverlay.Parent = targetFrame
end

local DONATION_PRODUCTS = {
	{ Id = 3475290016, Price = 5,    Name = "Resilio Tip" },
	{ Id = 3475290155, Price = 15,   Name = "Resilio Treat" },
	{ Id = 3475290208, Price = 50,   Name = "Resilio Sub" },
	{ Id = 3475290357, Price = 100,  Name = "Resilio Sponsor" },
	{ Id = 3475290476, Price = 500,  Name = "Resilio Whale" },
	{ Id = 3475290784, Price = 1000, Name = "Resilio Legend" },
}

local function showLoadingOverlay()
	local overlay = Instance.new("ScreenGui", playerGui)
	overlay.Name = "ResilioPreloadOverlay"
	overlay.DisplayOrder = 9999

	local frame = Instance.new("Frame", overlay)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.new(0.5,0,0.5,0)
	frame.Size = UDim2.new(0.4, 0, 0.2, 0)
	frame.BackgroundColor3 = Color3FromHex("861043")
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

local configResilio = {
	Titulo = "RESILIO",
	IconoPrincipal = "🧱",
	IconosBotones = { Play = "🎮", Vip = "👑", Exit = "🚪" },
	ColorFondo = "fce7f3",
	ColorBtnPlay = "fda5d5",
	ColorBtnVip = "f6339a",
	ColorBtnExit = "c6005c",
	Donaciones = DONATION_PRODUCTS,

	Controlador = UniversalController,

	OnPlay = function()
		if not didPreloadOnce then
			local overlay = showLoadingOverlay()
			local t0 = os.clock()
			local bucket = Instance.new("Folder")

			local function mkSnd(id)
				local s = Instance.new("Sound", bucket)
				s.SoundId = id; s.Volume = 0; return s
			end
			mkSnd(DESTROY_SOUND_ID)

			pcall(function() ContentProvider:PreloadAsync(bucket:GetChildren()) end)

			local remain = math.max(0, 2 - (os.clock() - t0))
			if remain > 0 then task.wait(remain) end

			overlay:Destroy()
			bucket:Destroy()
			didPreloadOnce = true
		end

		inGame = true
		initResilioGui()
		bindInputs()

		if StartRequest then StartRequest:FireServer() end
		task.delay(0.05, function()
			if SubmitLaunch then SubmitLaunch:FireServer() end
		end)
	end,

	OnExit = function()
		print("exiting resilio...")
	end
}

local function updateMuteButtonVisuals(btn)
	if not btn then return end
	if soundEnabled then
		btn.BackgroundColor3 = COLOR_BTN_EXIT
		btn.Text = "🔊 ON"
	else
		btn.BackgroundColor3 = Color3FromHex("666666")
		btn.Text = "🔇 MUTED"
	end
end

function exitCurrentGame()
	inGame = false
	if unbindInputs then unbindInputs() end
	if gameGui then gameGui:Destroy(); gameGui = nil end
	Menu1to7.AbrirMenuPrincipal(configResilio)
end

-- builds the breakout game frame, canvas, score label, exit and mute buttons
function initResilioGui()
	if gameGui then gameGui:Destroy() end
	Menu1to7.EstablecerEnfoque(true)

	gameGui = Instance.new("ScreenGui", playerGui)
	gameGui.Name = "ResilioGameGui"
	gameGui.ResetOnSpawn = false

	local gameFrame = Instance.new("Frame", gameGui)
	gameFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	gameFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	gameFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
	gameFrame.BackgroundColor3 = Color3FromHex("fce7f3")

	Instance.new("UIAspectRatioConstraint", gameFrame).AspectRatio = cw / (ch + 30)
	Instance.new("UISizeConstraint", gameFrame).MaxSize = Vector2.new(960, 780)

	canvas = Instance.new("Frame", gameFrame)
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, 0, ch/(ch+30), 0)
	canvas.Position = UDim2.new(0, 0, 30/(ch+30), 0)
	canvas.BackgroundColor3 = Color3.new(0,0,0)
	canvas.BorderSizePixel = 0

	scoreLabel = Instance.new("TextLabel", gameFrame)
	scoreLabel.Size = UDim2.new(0.5, 0, 30/390, 0)
	scoreLabel.Position = UDim2.new(0, 6, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.new(0,0,0)
	scoreLabel.TextScaled = true
	scoreLabel.Text = "Score: 0"
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left

	hudExitBtn = Instance.new("TextButton", gameFrame)
	hudExitBtn.AnchorPoint = Vector2.new(1,0)
	hudExitBtn.Position = UDim2.new(0.98, 0, 2/390, 0)
	hudExitBtn.Size = UDim2.new(0.15, 0, 26/390, 0)
	hudExitBtn.BackgroundColor3 = COLOR_BTN_EXIT
	hudExitBtn.Text = "EXIT"
	hudExitBtn.TextColor3 = Color3.new(1,1,1)
	hudExitBtn.TextScaled = true
	hudExitBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudExitBtn).CornerRadius = UDim.new(0, 8)
	addGlassEffectToFrame(hudExitBtn)
	hudExitBtn.MouseButton1Click:Connect(exitCurrentGame)

	hudMuteBtn = Instance.new("TextButton", gameFrame)
	hudMuteBtn.AnchorPoint = Vector2.new(1, 0)
	hudMuteBtn.Position = UDim2.new(0.82, 0, 2/390, 0)
	hudMuteBtn.Size = UDim2.new(0.20, 0, 26/390, 0)
	hudMuteBtn.TextColor3 = Color3.new(1,1,1)
	hudMuteBtn.TextScaled = true
	hudMuteBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudMuteBtn).CornerRadius = UDim.new(0, 8)
	updateMuteButtonVisuals(hudMuteBtn)

	hudMuteBtn.MouseButton1Click:Connect(function()
		soundEnabled = not soundEnabled
		updateMuteButtonVisuals(hudMuteBtn)
		if ToggleAudio then ToggleAudio:FireServer(soundEnabled) end
	end)
end

local function clearCanvas()
	if not canvas then return end
	for _,ch in ipairs(canvas:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
end

local COLOR_YELLOW = Color3.fromRGB(255, 214, 10)
local COLOR_ORANGE = Color3.fromRGB(255, 149, 0)
local BALL_COLOR   = Color3FromHex("7C3AED")
local TRAIL_COLOR  = Color3FromHex("A78BFA")
local SHOT_COLOR   = Color3.fromRGB(255, 0, 127)

-- creates a brick frame with hp label if hp > 1; flickers color for auto_fire bricks
local function makeBrick(br)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(br.w / cw, 0, br.h / ch, 0)
	f.Position = UDim2.new(br.x / cw, 0, br.y / ch, 0)
	f.BorderSizePixel = 0
	local palette = {
		[1] = COLOR_YELLOW,
		[2] = Color3.fromRGB(10, 132, 255),
		[3] = Color3.fromRGB(255, 59, 48),
	}
	if br.special == "auto_fire" then
		local alpha = (math.sin(tick() * 5) + 1) / 2
		f.BackgroundColor3 = COLOR_YELLOW:lerp(COLOR_ORANGE, alpha)
	else
		f.BackgroundColor3 = palette[br.type] or Color3.fromRGB(200,200,200)
	end
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
	if br.hp and br.hp > 1 then
		local txt = Instance.new("TextLabel", f)
		txt.BackgroundTransparency = 1
		txt.Size = UDim2.fromScale(1,1)
		txt.Text = tostring(br.hp)
		txt.TextScaled = true
		txt.Font = Enum.Font.GothamBold
		txt.TextColor3 = Color3.fromRGB(255,255,255)
	end
	return f
end

local function makePaddle(x,y,w,h)
	local p = Instance.new("Frame")
	p.Size = UDim2.new(w / cw, 0, h / ch, 0)
	p.Position = UDim2.new(x / cw, 0, y / ch, 0)
	p.BackgroundColor3 = Color3FromHex("f6339a")
	p.BorderSizePixel = 0
	Instance.new("UICorner", p).CornerRadius = UDim.new(0, 6)
	return p
end

-- spawns an expanding ring that fades out to show the ball path
local function spawnTrail(x,y,r)
	if not canvas then return end
	local t = Instance.new("Frame")
	t.Size = UDim2.new((r*1.6) / cw, 0, (r*1.6) / ch, 0)
	t.Position = UDim2.new((x - r*0.8) / cw, 0, (y - r*0.8) / ch, 0)
	t.BackgroundColor3 = TRAIL_COLOR
	t.BackgroundTransparency = 0.2
	t.BorderSizePixel = 0
	Instance.new("UICorner", t).CornerRadius = UDim.new(1,0)
	t.ZIndex = 0
	t.Parent = canvas

	TweenService:Create(t, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new((r*3.6) / cw, 0, (r*3.6) / ch, 0),
		Position = UDim2.new((x - r*1.8) / cw, 0, (y - r*1.8) / ch, 0),
		BackgroundTransparency = 1
	}):Play()
	Debris:AddItem(t, 0.4)
end

local function makeBall(x,y,r)
	local b = Instance.new("Frame")
	b.Size = UDim2.new((r*2) / cw, 0, (r*2) / ch, 0)
	b.Position = UDim2.new((x - r) / cw, 0, (y - r) / ch, 0)
	b.BackgroundColor3 = BALL_COLOR
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(1,0)
	return b
end

-- draws a short vertical beam from the paddle for each active laser shot
local function makeShotEffect(shotData)
	local x, y0, y1 = shotData.x, shotData.y0, shotData.y1
	local beam = Instance.new("Frame", canvas)
	beam.AnchorPoint = Vector2.new(0.5, 1)
	beam.Position = UDim2.new(x / cw, 0, y0 / ch, 0)
	beam.Size = UDim2.new(4 / cw, 0, (y0 - y1) / ch, 0)
	beam.BackgroundColor3 = SHOT_COLOR
	beam.BorderSizePixel = 0
	Debris:AddItem(beam, 0.1)
end

-- redraws all bricks, paddle, ball trail, and shot beams from server state
local function renderState(data)
	if not gameGui or not gameGui.Parent then initResilioGui() end
	if not data then return end
	if scoreLabel then
		scoreLabel.Text = ("Score: %d   |   Lives: %d   |   Lv: %d"):format(data.score or 0, data.lives or 0, data.level or 1)
	end

	clearCanvas()

	if data.bricks then
		for _,br in ipairs(data.bricks) do
			makeBrick(br).Parent = canvas
		end
	end
	if data.paddle then
		local p = makePaddle(data.paddle.x, data.paddle.y, data.paddle.w, data.paddle.h)
		p.ZIndex = 10
		p.Parent = canvas
	end
	if data.shots then
		for _,shotData in ipairs(data.shots) do
			makeShotEffect(shotData)
		end
	end
	if data.ball then
		if lastScore < data.score then playDestroySound() end
		lastScore = data.score
		spawnTrail(data.ball.x, data.ball.y, data.ball.r or 6)
		local b = makeBall(data.ball.x, data.ball.y, data.ball.r or 6)
		b.ZIndex = 20
		b.Parent = canvas
	end
end

local leftHeld, rightHeld = false, false
local lastDir = nil   -- which side was pressed most recently

-- Sends the held direction. With both keys down the NEWEST press wins: the
-- old code sent "Stop" instead, so rolling A->D (or mashing them) froze the
-- platform mid-move instead of turning it around.
local function sendDir()
	local dir
	if leftHeld and rightHeld then
		dir = lastDir or "Stop"
	elseif leftHeld then
		dir = "Left"
	elseif rightHeld then
		dir = "Right"
	else
		dir = "Stop"
	end
	SubmitMoveInput:FireServer(dir)
end

local function onMoveIzq(actionName, state, inputObject)
	-- Track the key state ALWAYS, even outside a match. The guard used to
	-- run first, so a key released after the match ended never cleared its
	-- flag: the next match started with a phantom direction held down, which
	-- read as the platform locking up and then drifting on its own.
	if state == Enum.UserInputState.Begin then leftHeld = true; lastDir = "Left"
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then leftHeld = false end
	if not inGame then return Enum.ContextActionResult.Pass end
	sendDir()
	return Enum.ContextActionResult.Sink
end

local function onMoveDer(actionName, state, inputObject)
	-- Track the key state ALWAYS, even outside a match. The guard used to
	-- run first, so a key released after the match ended never cleared its
	-- flag: the next match started with a phantom direction held down, which
	-- read as the platform locking up and then drifting on its own.
	if state == Enum.UserInputState.Begin then rightHeld = true; lastDir = "Right"
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then rightHeld = false end
	if not inGame then return Enum.ContextActionResult.Pass end
	sendDir()
	return Enum.ContextActionResult.Sink
end

local function onLaunch(_, state)
	if not inGame then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if SubmitLaunch then SubmitLaunch:FireServer() end
	end
	return Enum.ContextActionResult.Sink
end

function bindInputs()
	unbindInputs()
	UniversalController.CrearControlesResilio(onMoveIzq, onMoveDer, onLaunch)
end

function unbindInputs()
	UniversalController.LimpiarControles()
	leftHeld = false
	rightHeld = false
	lastDir = nil
	sendDir()
end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gameName)
		if gameName == "Resilio" and not inGame then
			Menu1to7.AbrirMenuPrincipal(configResilio)
		end
	end)
end

if GameState then
	GameState.OnClientEvent:Connect(function(mode, data)
		if mode == "Start" then
			if data.audioEnabled ~= nil then
				soundEnabled = data.audioEnabled
				if hudMuteBtn then updateMuteButtonVisuals(hudMuteBtn) end
			end
			inGame = true
			lastScore = 0
			initResilioGui()
			bindInputs()
		elseif mode == "Update" then
			if inGame then renderState(data) end
		elseif mode == "End" then
			if inGame then
				inGame = false
				unbindInputs()
				if gameGui then gameGui:Destroy(); gameGui = nil end
				Menu1to7.AbrirGameOver(data and data.score or 0, data and data.perfect == true)
			end
		end
	end)
end
