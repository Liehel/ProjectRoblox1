local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local Menu1to7 = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu1to7"))

local function findFoxyRemotes()
	local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes")
	local foxyFolder = arc:WaitForChild("FoxyFruit")
	local StartRequest   = foxyFolder:WaitForChild("StartFoxyFruitRequest")
	local SubmitMove     = foxyFolder:WaitForChild("SubmitMove")
	local GameState      = foxyFolder:WaitForChild("GameState")
	local OpenArcadeMenu = arc:WaitForChild("OpenArcadeMenu")
	local ToggleAudio    = foxyFolder:FindFirstChild("ToggleAudio")
	return StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio
end

local StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio = findFoxyRemotes()

local soundEnabled = true
local didPreloadOnce = false

local EAT_SOUND_ID    = "rbxassetid://98007189797443"
local SELECT_SOUND_ID = "rbxassetid://70844388753756"

local BACKGROUND_IMG   = "rbxassetid://86979479269660"
local GRASS_TILE_IMG   = "rbxassetid://86979479269660"
local PATH_BG_IMG      = "rbxassetid://98429019094869"
local OBSTACLES        = { "rbxassetid://77219857208492", "rbxassetid://77219857208492", "rbxassetid://77219857208492", "rbxassetid://77219857208492" }
local RASPBERRY_IMG    = "rbxassetid://140042030472535"
local BLUEBERRY_IMG    = "rbxassetid://130525867921249"
local FOXY_IMG_1       = "rbxassetid://125247709365483"
local FOXY_IMG_2       = "rbxassetid://83822401541320"
local ENEMY_SCARED_IMG = "rbxassetid://78853404808140"

-- enemy images keyed by the logical id sent from the server
local ENEMY_IMG = {
	enemy1     = "rbxassetid://100415970370909",
	enemy2     = "rbxassetid://77314793235417",
	extraenemy = "rbxassetid://87329261274234",
	enemy3     = "rbxassetid://100976401502279",
}

local sndBite   = Instance.new("Sound", script); sndBite.SoundId = EAT_SOUND_ID; sndBite.Volume = 0.5
local sndSelect = Instance.new("Sound", script); sndSelect.SoundId = SELECT_SOUND_ID; sndSelect.Volume = 0.5

if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local function playOnce(s)
	if not soundEnabled then return end
	if s then s:Play() end
end

local inGame     = false
local gameGui    = nil
local canvas     = nil
local scoreLbl   = nil
local overlayLbl = nil
local hudExitBtn = nil
local hudMuteBtn = nil
local lastScore  = 0
local rows, cols = 12, 16

local foxyAnimOn       = false
local foxyAnimTimer    = 0
local foxyAnimConn     = nil
local latestPlayerDir  = "Stop"
local lastFoxyRotation = 0

-- blink state for raspberries, blueberries, and frightened enemies
local raspberryBlinkOn = true
local raspberryTimer   = 0
local blueberryBlinkOn = true
local blueberryTimer   = 0
local enemyBlinkOn     = false
local enemyBlinkTimer  = 0
local enemyBlinkSpeed  = 0.25

local bindControls, unbindControls, initFoxyGui, exitCurrentGame

-- overlays a glass sheen over any frame
local function addGlassEffectToFrame(targetFrame)
	local glassOverlay = Instance.new("Frame")
	glassOverlay.Name = "GlassEffectOverlay"
	glassOverlay.Size = UDim2.new(1, 0, 1, 0)
	glassOverlay.BackgroundTransparency = 1
	glassOverlay.ZIndex = targetFrame.ZIndex + 1
	Instance.new("UICorner", glassOverlay).CornerRadius = targetFrame:FindFirstChildOfClass("UICorner") and targetFrame:FindFirstChildOfClass("UICorner").CornerRadius or UDim.new(0, 10)

	local gradient = Instance.new("UIGradient", glassOverlay)
	gradient.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
	gradient.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 0.95)}
	gradient.Rotation = 90

	local uiStroke = Instance.new("UIStroke", glassOverlay)
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Color = Color3.new(1,1,1)
	uiStroke.Thickness = 1
	uiStroke.Transparency = 0.7
	glassOverlay.Parent = targetFrame
end

-- shows a full-screen loading card while assets are being preloaded
local function showLoadingOverlay()
	local overlay = Instance.new("ScreenGui", playerGui)
	overlay.Name = "FoxyPreloadOverlay"
	overlay.DisplayOrder = 9999

	local frame = Instance.new("Frame", overlay)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.new(0.5,0,0.5,0)
	frame.Size = UDim2.new(0.4, 0, 0.2, 0)
	frame.BackgroundColor3 = Color3.fromHex("4f39f6")
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
	addGlassEffectToFrame(frame)

	local lbl = Instance.new("TextLabel", frame)
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "LOADING ASSETS..."
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1,1,1)

	return overlay
end

local DONATION_PRODUCTS = {
	{ Id = 3475288218, Price = 5,    Name = "Foxy Tip" },
	{ Id = 3475288422, Price = 15,   Name = "Foxy Treat" },
	{ Id = 3475288643, Price = 50,   Name = "Foxy Sub" },
	{ Id = 3475288826, Price = 100,  Name = "Foxy Sponsor" },
	{ Id = 3475288972, Price = 500,  Name = "Foxy Whale" },
	{ Id = 3475289214, Price = 1000, Name = "Foxy Legend" },
}

local configFoxy = {
	Titulo = "FOXY FRUIT",
	IconoPrincipal = "🦊",
	IconosBotones = { Play = "🎮", Vip = "👑", Exit = "🚪" },
	ColorFondo = "e0e7ff",
	ColorBtnPlay = "a3b3ff",
	ColorBtnVip = "7c86ff",
	ColorBtnExit = "4f39f6",
	Donaciones = DONATION_PRODUCTS,
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

			mkImg(BACKGROUND_IMG); mkImg(GRASS_TILE_IMG); mkImg(PATH_BG_IMG)
			mkImg(RASPBERRY_IMG); mkImg(BLUEBERRY_IMG); mkImg(FOXY_IMG_1); mkImg(FOXY_IMG_2)
			mkImg(ENEMY_SCARED_IMG)
			for _,id in pairs(ENEMY_IMG) do mkImg(id) end
			for _,id in ipairs(OBSTACLES) do mkImg(id) end

			pcall(function() ContentProvider:PreloadAsync(bucket:GetChildren()) end)

			local remain = math.max(0, 2 - (os.clock() - t0))
			if remain > 0 then task.wait(remain) end

			overlay:Destroy()
			bucket:Destroy()
			didPreloadOnce = true
		end

		inGame = true
		initFoxyGui()
		bindControls()
		if StartRequest then StartRequest:FireServer() end
	end,

	OnReturnToMenu = function()
		exitCurrentGame()
	end,

	OnExit = function()
		print("returning to hub from foxy fruit...")
	end
}

local function updateMuteButtonVisuals(btn)
	if not btn then return end
	if soundEnabled then
		btn.BackgroundColor3 = Color3.fromHex("4f39f6")
		btn.Text = "🔊 ON"
	else
		btn.BackgroundColor3 = Color3.fromHex("777777")
		btn.Text = "🔇 MUTED"
	end
end

-- drives the foxy walk animation and all item blink timers each frame
local function ensureFoxyAnimLoop()
	if foxyAnimConn then return end
	foxyAnimConn = RunService.Heartbeat:Connect(function(dt)
		if not inGame then return end

		if latestPlayerDir ~= "Stop" then
			foxyAnimTimer += dt
			if foxyAnimTimer >= 0.13 then
				foxyAnimTimer = 0
				foxyAnimOn = not foxyAnimOn
			end
		else
			foxyAnimOn = false
			foxyAnimTimer = 0
		end

		raspberryTimer += dt
		if raspberryBlinkOn then
			if raspberryTimer >= 2 then raspberryTimer = 0; raspberryBlinkOn = false end
		else
			if raspberryTimer >= 1 then raspberryTimer = 0; raspberryBlinkOn = true end
		end

		blueberryTimer += dt
		if blueberryTimer >= 1 then blueberryTimer = 0; blueberryBlinkOn = not blueberryBlinkOn end

		enemyBlinkTimer += dt
		if enemyBlinkTimer >= enemyBlinkSpeed then enemyBlinkTimer = 0; enemyBlinkOn = not enemyBlinkOn end
	end)
end

local function stopFoxyAnimLoop()
	if foxyAnimConn then foxyAnimConn:Disconnect(); foxyAnimConn = nil end
	foxyAnimOn = false; foxyAnimTimer = 0
	raspberryBlinkOn = true; raspberryTimer = 0
	blueberryBlinkOn = true; blueberryTimer = 0
	enemyBlinkOn = false; enemyBlinkTimer = 0
end

-- returns the sprite rotation angle for a given movement direction
local function rotationForDir(dir)
	if dir == "Right" then return 0
	elseif dir == "Left" then return 180
	elseif dir == "Down" then return 90
	elseif dir == "Up" then return 270
	else return lastFoxyRotation end
end

local function cleanupGameGui()
	if gameGui then gameGui:Destroy() end
	gameGui = nil; canvas = nil; scoreLbl = nil; overlayLbl = nil; hudExitBtn = nil; hudMuteBtn = nil
end

function exitCurrentGame()
	playOnce(sndSelect)
	pcall(function() if SubmitMove then SubmitMove:FireServer({action="Exit"}) end end)
	inGame = false
	stopFoxyAnimLoop()
	unbindControls()
	cleanupGameGui()
	Menu1to7.AbrirMenuPrincipal(configFoxy)
end

-- builds the game frame, canvas, score label, and hud buttons
function initFoxyGui()
	cleanupGameGui()
	Menu1to7.EstablecerEnfoque(true)

	gameGui = Instance.new("ScreenGui", playerGui)
	gameGui.Name = "FoxyFruitGameGui"
	gameGui.ResetOnSpawn = false

	local frame = Instance.new("Frame", gameGui)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.new(0.5,0,0.5,0)
	frame.Size = UDim2.new(0.85, 0, 0.85, 0)
	frame.BackgroundColor3 = Color3.new(0,0,0)
	frame.BorderSizePixel = 0

	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = (cols * 30) / ((rows * 30) + 30)
	Instance.new("UISizeConstraint", frame).MaxSize = Vector2.new(960, 780)

	local canvasRatio = (rows * 30) / ((rows * 30) + 30)
	local hudRatio = 30 / ((rows * 30) + 30)

	canvas = Instance.new("Frame", frame)
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, 0, canvasRatio, 0)
	canvas.Position = UDim2.new(0, 0, hudRatio, 0)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true

	scoreLbl = Instance.new("TextLabel", frame)
	scoreLbl.Name = "ScoreLabel"
	scoreLbl.Size = UDim2.new(0.5, 0, hudRatio, 0)
	scoreLbl.Position = UDim2.new(0,6,0,0)
	scoreLbl.BackgroundTransparency = 1
	scoreLbl.TextColor3 = Color3.new(1,1,1)
	scoreLbl.Font = Enum.Font.GothamBold
	scoreLbl.TextScaled = true
	scoreLbl.TextXAlignment = Enum.TextXAlignment.Left
	scoreLbl.Text = "Score: 0    Lives: 0    Lv: 1"

	overlayLbl = Instance.new("TextLabel", canvas)
	overlayLbl.Name = "Overlay"
	overlayLbl.Size = UDim2.new(1, 0, 1, 0)
	overlayLbl.Position = UDim2.new(0, 0, 0, 0)
	overlayLbl.BackgroundTransparency = 1
	overlayLbl.TextScaled = true
	overlayLbl.Font = Enum.Font.GothamBlack
	overlayLbl.TextColor3 = Color3.fromRGB(255,255,0)
	overlayLbl.Text = ""
	overlayLbl.ZIndex = 100

	hudExitBtn = Instance.new("TextButton", frame)
	hudExitBtn.AnchorPoint = Vector2.new(1,0)
	hudExitBtn.Position = UDim2.new(0.98, 0, 2/390, 0)
	hudExitBtn.Size = UDim2.new(0.15, 0, 26/390, 0)
	hudExitBtn.BackgroundColor3 = Color3.fromHex("4f39f6")
	hudExitBtn.Text = "EXIT"
	hudExitBtn.TextColor3 = Color3.new(1,1,1)
	hudExitBtn.TextScaled = true
	hudExitBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudExitBtn).CornerRadius = UDim.new(0, 8)
	addGlassEffectToFrame(hudExitBtn)
	hudExitBtn.MouseButton1Click:Connect(exitCurrentGame)

	hudMuteBtn = Instance.new("TextButton", frame)
	hudMuteBtn.AnchorPoint = Vector2.new(1, 0)
	hudMuteBtn.Position = UDim2.new(0.82, 0, 2/390, 0)
	hudMuteBtn.Size = UDim2.new(0.20, 0, 26/390, 0)
	hudMuteBtn.TextColor3 = Color3.new(1,1,1)
	hudMuteBtn.TextScaled = true
	hudMuteBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudMuteBtn).CornerRadius = UDim.new(0, 8)
	addGlassEffectToFrame(hudMuteBtn)
	updateMuteButtonVisuals(hudMuteBtn)

	hudMuteBtn.MouseButton1Click:Connect(function()
		soundEnabled = not soundEnabled
		updateMuteButtonVisuals(hudMuteBtn)
		if soundEnabled then playOnce(sndSelect) end
		if ToggleAudio then pcall(function() ToggleAudio:FireServer(soundEnabled) end) end
	end)
end

-- returns the size and position udim2 values for a grid cell at row r, col c
local function getCellTransform(r, c)
	local wScale = 1 / cols
	local hScale = 1 / rows
	local x = (c - 1) * wScale
	local y = (r - 1) * hScale
	return UDim2.new(wScale, 0, hScale, 0), UDim2.new(x, 0, y, 0)
end

-- removes all canvas children except the persistent overlay and background grid
local function clearCanvas()
	if not canvas then return end
	for _,ch in ipairs(canvas:GetChildren()) do
		if ch.Name ~= "Overlay" and ch.Name ~= "PATH_GRID" then
			ch:Destroy()
		end
	end
end

-- creates the static tiled floor grid only once
local function drawBackgroundGrid()
	if not canvas or canvas:FindFirstChild("PATH_GRID") then return end

	local gridFrame = Instance.new("Frame", canvas)
	gridFrame.Name = "PATH_GRID"
	gridFrame.Size = UDim2.new(1, 0, 1, 0)
	gridFrame.BackgroundTransparency = 1
	gridFrame.BorderSizePixel = 0
	gridFrame.ZIndex = 0

	for r = 1, rows do
		for c = 1, cols do
			local size, pos = getCellTransform(r, c)
			local floor = Instance.new("ImageLabel", gridFrame)
			floor.Name = "PathBase_" .. r .. "_" .. c
			floor.Size = size
			floor.Position = pos
			floor.BackgroundColor3 = Color3.new(1,1,1)
			floor.BorderSizePixel = 0
			floor.Image = PATH_BG_IMG
			floor.ZIndex = 1
		end
	end
end

-- draws a single tile based on its value: 1=wall, 2=raspberry, 3=blueberry, 4=jail
local function drawTile(r,c,v)
	local size, pos = getCellTransform(r, c)

	if v == 1 or v == 4 then
		local floor = Instance.new("ImageLabel", canvas)
		floor.Size = size; floor.Position = pos; floor.BackgroundTransparency = 1; floor.BorderSizePixel = 0; floor.Image = GRASS_TILE_IMG; floor.ZIndex = 2

		if v == 1 then
			local seed = (r * 7 + c * 13)
			local idx = (seed % #OBSTACLES) + 1
			local obstacle = Instance.new("ImageLabel", floor)
			obstacle.Size = UDim2.fromScale(1, 1); obstacle.BackgroundTransparency = 1; obstacle.BorderSizePixel = 0; obstacle.Image = OBSTACLES[idx]; obstacle.ZIndex = 3

		elseif v == 4 then
			local jail = Instance.new("Frame", floor)
			jail.Size = UDim2.fromScale(1, 1); jail.BackgroundColor3 = Color3.fromRGB(80, 40, 10); jail.BorderSizePixel = 0; jail.BackgroundTransparency = 0.5; jail.ZIndex = 3
			local s = Instance.new("UIStroke", jail); s.Color = Color3.fromRGB(139, 69, 19); s.Thickness = 2
		end

	elseif v == 2 or v == 3 then
		local itemContainer = Instance.new("Frame", canvas)
		itemContainer.Size = size; itemContainer.Position = pos; itemContainer.BackgroundTransparency = 1; itemContainer.BorderSizePixel = 0; itemContainer.ZIndex = 2

		if v == 2 then
			local lightFrame = Instance.new("Frame", itemContainer)
			lightFrame.Size = UDim2.fromScale(0.5, 0.5); lightFrame.AnchorPoint = Vector2.new(0.5,0.5); lightFrame.Position = UDim2.fromScale(0.5, 0.5)
			lightFrame.BackgroundColor3 = Color3.new(1,1,1); lightFrame.BorderSizePixel = 0; lightFrame.ZIndex = 2
			lightFrame.BackgroundTransparency = raspberryBlinkOn and 0.3 or 0.85
			Instance.new("UICorner", lightFrame).CornerRadius = UDim.new(1,0)

			local gradR = Instance.new("UIGradient", lightFrame)
			gradR.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 120, 120)), ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 0, 0)) })
			gradR.Rotation = raspberryBlinkOn and 0 or 180

			local dot = Instance.new("ImageLabel", itemContainer)
			dot.Size = UDim2.fromScale(0.6, 0.6); dot.AnchorPoint = Vector2.new(0.5,0.5); dot.Position = UDim2.fromScale(0.5, 0.5)
			dot.BackgroundTransparency = 1; dot.BorderSizePixel = 0; dot.Image = RASPBERRY_IMG; dot.ZIndex = 3

		elseif v == 3 then
			local power = Instance.new("ImageLabel", itemContainer)
			power.Size = UDim2.fromScale(0.7, 0.7); power.AnchorPoint = Vector2.new(0.5,0.5); power.Position = UDim2.fromScale(0.5, 0.5)
			power.BackgroundTransparency = 1; power.BorderSizePixel = 0; power.Image = BLUEBERRY_IMG; power.ZIndex = 3

			local lightFrame = Instance.new("Frame", itemContainer)
			lightFrame.Size = UDim2.fromScale(1.4, 1.4); lightFrame.AnchorPoint = Vector2.new(0.5,0.5); lightFrame.Position = UDim2.fromScale(0.5, 0.5)
			lightFrame.BackgroundColor3 = Color3.new(1,1,1); lightFrame.BorderSizePixel = 0; lightFrame.ZIndex = 2
			lightFrame.BackgroundTransparency = blueberryBlinkOn and 0.3 or 0.7
			Instance.new("UICorner", lightFrame).CornerRadius = UDim.new(1,0)

			local gradient = Instance.new("UIGradient", lightFrame)
			gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 200, 255)), ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 255, 0)) })
			gradient.Rotation = blueberryBlinkOn and 0 or 180
		end
	end
end

-- draws foxy's sprite at the given cell and updates the walk animation frame
local function drawFoxyImage(r,c,dir)
	local size, pos = getCellTransform(r, c)
	local img = Instance.new("ImageLabel", canvas)
	img.BackgroundTransparency = 1; img.BorderSizePixel = 0; img.Size = size; img.Position = pos; img.ZIndex = 10
	latestPlayerDir = dir or "Stop"

	ensureFoxyAnimLoop()
	img.Image = (dir ~= "Stop" and foxyAnimOn) and FOXY_IMG_2 or FOXY_IMG_1

	local rot = rotationForDir(dir)
	img.Rotation = rot
	lastFoxyRotation = rot
end

-- draws an enemy sprite, swapping to scared image when frightened (with blink in last 2 s)
local function drawEnemyImage(enemy, frightened, blinkPhase)
	local size, pos = getCellTransform(enemy.r, enemy.c)
	local img = Instance.new("ImageLabel", canvas)
	img.BackgroundTransparency = 1; img.BorderSizePixel = 0; img.Size = size; img.Position = pos; img.ZIndex = 9

	if frightened then
		img.Image = (blinkPhase and not enemyBlinkOn) and (ENEMY_IMG[enemy.name] or ENEMY_IMG.enemy1) or ENEMY_SCARED_IMG
	else
		img.Image = ENEMY_IMG[enemy.name] or ENEMY_IMG.enemy1
	end
end

local function renderOverlay(state)
	overlayLbl.Text = ""
	if state.gameState == "ready" then
		overlayLbl.Text = "READY!"
	elseif state.gameState == "countdown" then
		overlayLbl.Text = (state.countdownValue and state.countdownValue > 0) and tostring(state.countdownValue) or "GO!"
	end
end

-- redraws the entire game canvas from the latest server state
local function renderState(state)
	if not gameGui or not gameGui.Parent then
		rows = state.rows or rows
		cols = state.cols or cols
		initFoxyGui()
	end

	if scoreLbl then
		local s = state.score or 0
		if s > lastScore then playOnce(sndBite) end
		lastScore = s
		local lives = state.lives or (state.hud and state.hud.lives) or 0
		local level = state.level or state.currentLevel or (state.hud and state.hud.level) or 1
		scoreLbl.Text = state.hudText or ("Score: %d    Lives: %d    Lv: %d"):format(s, lives, level)
	end

	-- speed up enemy blink rate when power mode is about to expire
	if state.powerMode and (state.powerTimeLeft or 0) <= 2 then
		enemyBlinkSpeed = 0.1
		ensureFoxyAnimLoop()
	else
		enemyBlinkSpeed = 0.25
	end

	drawBackgroundGrid()
	clearCanvas()
	renderOverlay(state)

	if state.tiles then
		for _,t in ipairs(state.tiles) do drawTile(t.r, t.c, t.v) end
	end

	local frightened = state.powerMode
	local blinkPhase = frightened and (state.powerTimeLeft or 0) <= 2

	if state.enemies then
		for _,enemy in ipairs(state.enemies) do drawEnemyImage(enemy, frightened, blinkPhase) end
	end

	if state.player then
		drawFoxyImage(state.player.r, state.player.c, state.player.dir)
	end
end

local function onDirUp(a, s)    if not inGame then return Enum.ContextActionResult.Pass end if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Up")    end return Enum.ContextActionResult.Sink end
local function onDirDown(a, s)  if not inGame then return Enum.ContextActionResult.Pass end if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Down")  end return Enum.ContextActionResult.Sink end
local function onDirLeft(a, s)  if not inGame then return Enum.ContextActionResult.Pass end if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Left")  end return Enum.ContextActionResult.Sink end
local function onDirRight(a, s) if not inGame then return Enum.ContextActionResult.Pass end if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Right") end return Enum.ContextActionResult.Sink end

function bindControls()   UniversalController.CrearControlesFoxyFruit(onDirUp, onDirDown, onDirLeft, onDirRight) end
function unbindControls() UniversalController.LimpiarControles() end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gameName)
		if gameName == "FoxyFruit" then
			if inGame or playerGui:FindFirstChild("ArcadeMenuPrincipal") then return end
			Menu1to7.AbrirMenuPrincipal(configFoxy)
		end
	end)
end

if GameState then
	GameState.OnClientEvent:Connect(function(mode, data)
		if mode == "Start" then
			inGame = true
			lastScore = 0
			rows = data.rows or rows
			cols = data.cols or cols
			initFoxyGui()
			bindControls()
			ensureFoxyAnimLoop()
			renderState(data)
		elseif mode == "Update" then
			if inGame then renderState(data) end
		elseif mode == "End" then
			if not inGame then return end
			inGame = false
			stopFoxyAnimLoop()
			unbindControls()
			cleanupGameGui()
			Menu1to7.AbrirGameOver(data and data.score or 0, data and data.win == true)
		end
	end)
end
