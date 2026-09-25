local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local Menu1to7 = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu1to7"))

local function findRemotes()
	local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes")
	local grp = arc:WaitForChild("FirmamentSiege")
	local StartRequest   = grp:WaitForChild("StartFirmamentSiegeRequest")
	local SubmitMove     = grp:WaitForChild("SubmitMove")
	local GameState      = grp:WaitForChild("GameState")
	local OpenArcadeMenu = arc:WaitForChild("OpenArcadeMenu")
	local ToggleAudio    = grp:FindFirstChild("ToggleAudio")
	return StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio
end

local StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio = findRemotes()

local soundEnabled = true
local didPreloadOnce = false

local LASER_SOUND_ID     = "rbxassetid://137510557013265"
local EXPLOSION_SOUND_ID = "rbxassetid://92876108656319"

local sndLaser     = Instance.new("Sound", script); sndLaser.SoundId = LASER_SOUND_ID; sndLaser.Volume = 0.5
local sndExplosion = Instance.new("Sound", script); sndExplosion.SoundId = EXPLOSION_SOUND_ID; sndExplosion.Volume = 0.6

if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local function playOnce(s)
	if soundEnabled and s then s:Play() end
end

local function Color3FromHex(hex)
	hex = tostring(hex or ""):gsub("#","")
	if #hex == 3 then hex = hex:gsub(".", "%1%1") end
	return Color3.fromRGB(tonumber(hex:sub(1,2), 16) or 255, tonumber(hex:sub(3,4), 16) or 255, tonumber(hex:sub(5,6), 16) or 255)
end

local COLOR_BTN_VIP = Color3FromHex("ca3500")

local inGame = false
local gameGui, canvas, hudLbl, overlayLbl, hudExitBtn, hudMuteBtn = nil, nil, nil, nil, nil, nil
local rows, cols, cell = 16, 18, 28
local lastState = nil

local bindControls, unbindControls, initGameGui, exitCurrentGame, ensureStars

local function showLoadingOverlay()
	local overlay = Instance.new("ScreenGui", playerGui)
	overlay.Name = "FirmamentPreloadOverlay"
	overlay.DisplayOrder = 9999

	local frame = Instance.new("Frame", overlay)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.new(0.5,0,0.5,0)
	frame.Size = UDim2.new(0.4, 0, 0.2, 0)
	frame.BackgroundColor3 = Color3FromHex("ff8904")
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

local configFirmament = {
	Titulo = "FIRMAMENT SIEGE",
	IconoPrincipal = "✈️",
	IconosBotones = { Play = "🎮", Vip = "👑", Exit = "🚪" },
	ColorFondo = "ffd6a7",
	ColorBtnPlay = "ff8904",
	ColorBtnVip = "ca3500",
	ColorBtnExit = "7e2a0c",
	Donaciones = {
		{ Id = 3478073654, Price = 5,    Name = "Firmament's Tip" },
		{ Id = 3478073816, Price = 15,   Name = "Firmament's Treat" },
		{ Id = 3478073972, Price = 50,   Name = "Firmament's Sub" },
		{ Id = 3478077889, Price = 100,  Name = "Firmament's Sponsor" },
		{ Id = 3478078031, Price = 500,  Name = "Firmament's Whale" },
		{ Id = 3478078163, Price = 1000, Name = "Firmament's Legend" },
	},

	Controlador = UniversalController,

	OnPlay = function()
		if not didPreloadOnce then
			local overlay = showLoadingOverlay()
			local t0 = os.clock()
			local bucket = Instance.new("Folder")

			local function mkImg(id)
				local i = Instance.new("ImageLabel", bucket)
				i.Image = id
				return i
			end
			mkImg("rbxassetid://110024853780697"); mkImg("rbxassetid://99832337457913")
			mkImg("rbxassetid://112975600588751"); mkImg("rbxassetid://135423621381073")
			mkImg("rbxassetid://94603443977330"); mkImg("rbxassetid://84586330906641")
			mkImg("rbxassetid://78062085930051"); mkImg("rbxassetid://86777896781320")
			mkImg("rbxassetid://82732311289463"); mkImg("rbxassetid://118805495954860")
			mkImg("rbxassetid://94593623470608"); mkImg("rbxassetid://94432423541372")

			pcall(function() ContentProvider:PreloadAsync(bucket:GetChildren()) end)

			local remain = math.max(0, 1.5 - (os.clock() - t0))
			if remain > 0 then task.wait(remain) end

			overlay:Destroy()
			bucket:Destroy()
			didPreloadOnce = true
		end

		inGame = true
		initGameGui()
		bindControls()
		if StartRequest then StartRequest:FireServer() end
	end,

	OnReturnToMenu = function() exitCurrentGame() end,
	OnExit = function() print("returning to lobby...") end
}

-- joystick vectors and aim state shared between the control loop and renderstep
local currentJoyMove = Vector2.new(0, 0)
local lastSentAx, lastSentAy = 0, 0
local isUsingGamepadAim = false
local gamepadAimAngle = 0
local aimSendAccum = 0

local function onJoyIzq(vec) if inGame then currentJoyMove = vec end end

-- calculates aim angle from the right stick, falling back to mouse when idle
local function onJoyDer(vec)
	if not inGame then return end
	if vec.Magnitude > 0.1 then
		isUsingGamepadAim = true
		gamepadAimAngle = math.deg(math.atan2(-vec.Y, vec.X))
	else
		isUsingGamepadAim = false
	end
end

local function onShootAction(actionName, inputState)
	if not inGame then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		if SubmitMove then SubmitMove:FireServer({action="Fire"}) end
		playOnce(sndLaser)
	end
	return Enum.ContextActionResult.Sink
end

local mouseConnBegan = nil
local function bindMouseShoot()
	if mouseConnBegan then mouseConnBegan:Disconnect() end
	mouseConnBegan = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or not inGame then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if SubmitMove then SubmitMove:FireServer({action="Fire"}) end
			playOnce(sndLaser)
		end
	end)
end

function bindControls()
	UniversalController.CrearControlesFirmamentSiege(onJoyIzq, onJoyDer, onShootAction)
	bindMouseShoot()
end

function unbindControls()
	UniversalController.LimpiarControles()
	if mouseConnBegan then mouseConnBegan:Disconnect(); mouseConnBegan = nil end
	currentJoyMove = Vector2.new(0,0)
	lastSentAx, lastSentAy = 0, 0
	isUsingGamepadAim = false
end

-- sends movement axes and aim angle to server at ~20hz
RunService.RenderStepped:Connect(function(dt)
	if not inGame or not canvas or not lastState or not lastState.ship then return end

	local ax, ay = currentJoyMove.X, -currentJoyMove.Y
	local dAx = (ax > 0.3 and 1) or (ax < -0.3 and -1) or 0
	local dAy = (ay > 0.3 and 1) or (ay < -0.3 and -1) or 0

	if dAx ~= lastSentAx or dAy ~= lastSentAy then
		lastSentAx = dAx; lastSentAy = dAy
		if SubmitMove then SubmitMove:FireServer({action="MoveAxes", ax=dAx, ay=dAy}) end
	end

	aimSendAccum += dt
	if aimSendAccum >= 0.05 then
		aimSendAccum = 0
		local ang = 0

		if isUsingGamepadAim then
			ang = gamepadAimAngle
		else
			local mousePos = UserInputService:GetMouseLocation()
			local cpos = canvas.AbsolutePosition
			local cs = canvas.AbsoluteSize
			local mx = math.clamp(mousePos.X - cpos.X, 0, cs.X)
			local my = math.clamp(mousePos.Y - cpos.Y, 0, cs.Y)

			local sx = ((lastState.ship.c - 0.5) / cols) * cs.X
			local sy = ((lastState.ship.r - 0.5) / rows) * cs.Y
			local dx, dy = mx - sx, my - sy

			if dx ~= 0 or dy ~= 0 then ang = math.deg(math.atan2(dy, dx))
			else ang = lastState.ship.rot or 0 end
		end

		if SubmitMove then SubmitMove:FireServer({action="Aim", angleDeg=ang}) end
		lastState.ship.rot = ang
	end
end)

function exitCurrentGame()
	inGame = false
	pcall(function() if SubmitMove then SubmitMove:FireServer({action="Exit"}) end end)
	unbindControls()
	if gameGui then gameGui:Destroy(); gameGui = nil end
	Menu1to7.AbrirMenuPrincipal(configFirmament)
end

local function updateMuteButtonVisuals(btn)
	if not btn then return end
	if soundEnabled then
		btn.BackgroundColor3 = Color3FromHex("ff8904")
		btn.Text = "🔊 ON"
	else
		btn.BackgroundColor3 = Color3FromHex("666666")
		btn.Text = "🔇 MUTED"
	end
end

-- builds the game frame, star background, hud, and canvas
function initGameGui()
	if gameGui then gameGui:Destroy() end
	Menu1to7.EstablecerEnfoque(true)

	gameGui = Instance.new("ScreenGui", playerGui)
	gameGui.Name = "FirmamentGameGui"
	gameGui.ResetOnSpawn = false

	local frame = Instance.new("Frame", gameGui)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.new(0.5,0,0.5,0)
	frame.Size = UDim2.new(0.85, 0, 0.85, 0)
	frame.BackgroundColor3 = Color3.new(0,0,0)

	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = (cols * cell) / (rows * cell + 30)
	Instance.new("UISizeConstraint", frame).MaxSize = Vector2.new(960, 780)

	local canvasHScale = (rows * cell) / (rows * cell + 30)
	local hudHScale = 30 / (rows * cell + 30)

	canvas = Instance.new("Frame", frame)
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, 0, canvasHScale, 0)
	canvas.Position = UDim2.new(0, 0, hudHScale, 0)
	canvas.BackgroundColor3 = Color3.fromRGB(10,10,10)
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true

	ensureStars()

	hudLbl = Instance.new("TextLabel", frame)
	hudLbl.Name = "HudLabel"
	hudLbl.Size = UDim2.new(0.5, 0, hudHScale, 0)
	hudLbl.Position = UDim2.new(0, 6, 0, 0)
	hudLbl.BackgroundTransparency = 1
	hudLbl.TextColor3 = Color3.new(1,1,1)
	hudLbl.TextScaled = true
	hudLbl.Font = Enum.Font.GothamBold
	hudLbl.TextXAlignment = Enum.TextXAlignment.Left
	hudLbl.Text = "Score: 0   Lives: 3"

	overlayLbl = Instance.new("TextLabel", canvas)
	overlayLbl.Name = "Overlay"
	overlayLbl.Size = UDim2.new(1, 0, 1, 0)
	overlayLbl.BackgroundTransparency = 1
	overlayLbl.TextScaled = true
	overlayLbl.Font = Enum.Font.GothamBlack
	overlayLbl.TextColor3 = Color3.fromRGB(255,255,0)
	overlayLbl.ZIndex = 10
	overlayLbl.Text = "WAITING FOR SERVER..."

	hudExitBtn = Instance.new("TextButton", frame)
	hudExitBtn.AnchorPoint = Vector2.new(1,0)
	hudExitBtn.Position = UDim2.new(0.98, 0, 2/390, 0)
	hudExitBtn.Size = UDim2.new(0.15, 0, 26/390, 0)
	hudExitBtn.BackgroundColor3 = COLOR_BTN_VIP
	hudExitBtn.Text = "EXIT"
	hudExitBtn.TextColor3 = Color3.new(1,1,1)
	hudExitBtn.TextScaled = true
	hudExitBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudExitBtn).CornerRadius = UDim.new(0, 8)
	hudExitBtn.MouseButton1Click:Connect(exitCurrentGame)

	hudMuteBtn = Instance.new("TextButton", frame)
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
		if soundEnabled then playOnce(sndLaser) end
		if ToggleAudio then ToggleAudio:FireServer(soundEnabled) end
	end)
end

local starsLayer, twinkleConn
-- creates a twinkling star field, only once per canvas lifetime
function ensureStars()
	if starsLayer and starsLayer.Parent then return end
	starsLayer = Instance.new("Frame", canvas)
	starsLayer.Name = "Stars"
	starsLayer.Size = UDim2.new(1,0,1,0)
	starsLayer.BackgroundTransparency = 1
	starsLayer.ZIndex = 1

	local n = math.clamp(math.floor((cols*cell*rows*cell)/800), 50, 120)
	for i = 1, n do
		local s = Instance.new("Frame", starsLayer)
		s.Size = UDim2.fromOffset(math.random(1,2), math.random(1,2))
		s.Position = UDim2.new(math.random(), 0, math.random(), 0)
		s.BackgroundColor3 = Color3.fromRGB(255,255,255)
		s.BackgroundTransparency = math.random() * 0.4 + 0.2
		s.BorderSizePixel = 0
	end

	if twinkleConn then twinkleConn:Disconnect() end
	twinkleConn = RunService.Heartbeat:Connect(function()
		if not starsLayer or not starsLayer.Parent then return end
		local children = starsLayer:GetChildren()
		for i = 1, math.min(6, #children) do
			local s = children[math.random(1, #children)]
			s.BackgroundTransparency = math.clamp(s.BackgroundTransparency + (math.random()-0.5)*0.2, 0.1, 0.9)
		end
	end)
end

local function clearCanvas()
	if not canvas then return end
	for _,ch in ipairs(canvas:GetChildren()) do
		if ch.Name ~= "Overlay" and ch.Name ~= "Stars" then ch:Destroy() end
	end
end

local function getScale(w, h)   return UDim2.new(w / (cols * cell), 0, h / (rows * cell), 0) end
local function getPosScale(x, y) return UDim2.new(x / (cols * cell), 0, y / (rows * cell), 0) end

local function addPixelRect(name, r, c, w, h, z, color)
	local f = Instance.new("Frame", canvas)
	f.Name = name
	f.Size = getScale(w, h)
	f.Position = getPosScale((c-1)*cell, (r-1)*cell)
	f.BackgroundColor3 = color or Color3.fromRGB(30, 200, 30)
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	return f
end

-- draws a square sprite centered inside the cell
local function addSpriteAtPx(name, r, c, px, imgId, z)
	local img = Instance.new("ImageLabel", canvas)
	img.Name = name
	img.BackgroundTransparency = 1
	img.Size = getScale(px, px)
	img.Position = getPosScale((c-1)*cell + (cell - px)/2, (r-1)*cell + (cell - px)/2)
	img.ZIndex = z or 3
	img.Image = imgId
	img.ScaleType = Enum.ScaleType.Stretch
	return img
end

local function drawShip(ship, state)
	if not ship then return end
	local imgId = (state and state.gameState == "dying") and "rbxassetid://99832337457913" or "rbxassetid://110024853780697"
	local spr = addSpriteAtPx("Ship", ship.r, ship.c, cell, imgId, 5)
	if spr then spr.Rotation = (state.ship.rot or 0) + 90 end
end

local function drawAliens(aliens)
	if not aliens then return end
	local imgs = { A = "rbxassetid://94603443977330", B = "rbxassetid://94603443977330", C = "rbxassetid://94603443977330" }
	for _,a in ipairs(aliens) do
		local px = a.px or cell
		local glowSize = math.floor(px * 0.5)
		local glow = addPixelRect("AlienGlow", a.r, a.c, glowSize, glowSize, 2, Color3.fromRGB(200, 40, 40))
		local offX = ((cell - glowSize) / 2) / (cols * cell)
		local offY = ((cell - glowSize) / 2) / (rows * cell)
		glow.Position = glow.Position + UDim2.new(offX, 0, offY, 0)
		glow.BackgroundTransparency = 0.35
		Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

		local spr = addSpriteAtPx("Alien", a.r, a.c, px, imgs[a.type or "A"], 3)
		if spr then spr.Rotation = a.rot or 0 end
	end
end

local function drawBullets(playerBullets)
	if not playerBullets then return end
	for _,b in ipairs(playerBullets) do
		local sz = math.floor(cell*0.18)
		local dot = addPixelRect("PBullet", b.r, b.c, sz, sz, 6, Color3.fromRGB(120, 220, 255))
		local offX = math.floor((cell - sz)/2) / (cols * cell)
		local offY = math.floor((cell - sz)/2) / (rows * cell)
		dot.Position = dot.Position + UDim2.new(offX, 0, offY, 0)
	end
end

local function renderState(state)
	lastState = state
	if not gameGui or not gameGui.Parent then
		rows = state.rows or rows
		cols = state.cols or cols
		initGameGui()
	end

	if hudLbl then
		if state.hudText then hudLbl.Text = state.hudText
		else hudLbl.Text = ("Score: %d   Lives: %d"):format(state.score or 0, state.lives or 3) end
	end

	clearCanvas()
	overlayLbl.Text = state.overlayText or (state.gameState == "ready" and "READY!" or "")

	drawAliens(state.aliens)
	drawShip(state.ship, state)
	drawBullets(state.playerBullets)
end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gameName)
		if gameName == "FirmamentSiege" then
			if inGame or playerGui:FindFirstChild("ArcadeMenuPrincipal") then return end
			Menu1to7.AbrirMenuPrincipal(configFirmament)
		end
	end)
end

if GameState then
	GameState.OnClientEvent:Connect(function(mode, data)
		if mode == "Start" then
			inGame = true
			rows = (data and data.rows) or rows
			cols = (data and data.cols) or cols
			initGameGui()
			bindControls()
			renderState(data or {})
		elseif mode == "Update" then
			if inGame and data then
				if data.explosionEvent then playOnce(sndExplosion) end
				renderState(data)
			end
		elseif mode == "End" then
			if not inGame then return end
			inGame = false
			unbindControls()
			if gameGui then gameGui:Destroy(); gameGui = nil end
			Menu1to7.AbrirGameOver(data and data.score or 0, data and data.win == true)
		end
	end)
end
