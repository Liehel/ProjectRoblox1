local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local Menu1to7 = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu1to7"))

local function findFirmamentRemotes()
	local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes")
	local grip = arc:WaitForChild("FirmamentDefender")
	local StartRequest = grip:WaitForChild("StartFirmamentDefenderRequest")
	local SubmitMove = grip:WaitForChild("SubmitMove")
	local GameState = grip:WaitForChild("GameState")
	local ToggleAudio = grip:WaitForChild("ToggleAudio")
	local OpenArcadeMenu = arc:WaitForChild("OpenArcadeMenu")
	return StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio
end

local StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio = findFirmamentRemotes()

local soundEnabled = true
local didPreloadOnce = false

local EXPLOSION_SOUND_ID = "rbxassetid://92876108656319"
local LASER_SOUND_ID     = "rbxassetid://137510557013265"
local SHIP_IMG           = "rbxassetid://110024853780697"
local SHIP_HIT_IMG       = "rbxassetid://99832337457913"
local IMG_A              = "rbxassetid://112975600588751"
local IMG_A_HIT          = "rbxassetid://135423621381073"
local IMG_B              = "rbxassetid://94603443977330"
local IMG_B_HIT          = "rbxassetid://84586330906641"
local IMG_C              = "rbxassetid://78062085930051"
local IMG_C_HIT          = "rbxassetid://86777896781320"
local UFO_L2R            = "rbxassetid://82732311289463"
local UFO_L2R_HIT        = "rbxassetid://118805495954860"
local UFO_R2L            = "rbxassetid://94593623470608"
local UFO_R2L_HIT        = "rbxassetid://94432423541372"

local sndExplosion = Instance.new("Sound", script)
sndExplosion.SoundId = EXPLOSION_SOUND_ID
sndExplosion.Volume = 0.6
local sndLaser = Instance.new("Sound", script)
sndLaser.SoundId = LASER_SOUND_ID
sndLaser.Volume = 0.5

if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local function playSound(s)
	if soundEnabled and s then s:Play() end
end

local inGame = false
local gameGui = nil
local canvas = nil
local hudLbl = nil
local overlayLbl = nil
local hudExitBtn = nil
local hudMuteBtn = nil
local lastScore = 0
local rows, cols, cell = 16, 18, 28

local lastAliens = nil
local lastUfo = nil
local lastUfoDirLR = true
local now = os.clock
local alienHitFlashes = {}
local ufoHitFlashes = {}
local starsLayer = nil
local stars = {}
local twinkleConn = nil
local invaderAnimTimer = 0

local bindControls, unbindControls, initFirmamentGui, exitCurrentGame, ensureStars

-- tracks the invader animation phase each frame
RunService.Heartbeat:Connect(function(dt)
	if not inGame then return end
	invaderAnimTimer += dt
	if invaderAnimTimer >= 0.25 then invaderAnimTimer = 0 end
end)

local function showLoadingOverlay()
	local overlay = Instance.new("ScreenGui", playerGui)
	overlay.Name = "FirmamentPreloadOverlay"
	overlay.DisplayOrder = 9999

	local frame = Instance.new("Frame", overlay)
	frame.AnchorPoint = Vector2.new(0.5,0.5)
	frame.Position = UDim2.new(0.5,0,0.5,0)
	frame.Size = UDim2.new(0.4, 0, 0.2, 0)
	frame.BackgroundColor3 = Color3.fromHex("ff8904")
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
	Titulo = "FIRMAMENT DEFENDER",
	IconoPrincipal = "✈️",
	IconosBotones = { Play = "🎮", Vip = "👑", Exit = "🚪" },
	ColorFondo = "ffd6a7",
	ColorBtnPlay = "ff8904",
	ColorBtnVip = "ca3500",
	ColorBtnExit = "7e2a0c",
	Donaciones = {
		{ Id = 3477824531, Price = 5,    Name = "Firmament Tip" },
		{ Id = 3477824658, Price = 15,   Name = "Firmament Treat" },
		{ Id = 3477824790, Price = 50,   Name = "Firmament Sub" },
		{ Id = 3477825231, Price = 100,  Name = "Firmament Sponsor" },
		{ Id = 3477825407, Price = 500,  Name = "Firmament Whale" },
		{ Id = 3477825563, Price = 1000, Name = "Firmament Legend" },
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

			mkImg(SHIP_IMG) mkImg(SHIP_HIT_IMG) mkImg(IMG_A) mkImg(IMG_A_HIT)
			mkImg(IMG_B) mkImg(IMG_B_HIT) mkImg(IMG_C) mkImg(IMG_C_HIT)
			mkImg(UFO_L2R) mkImg(UFO_L2R_HIT) mkImg(UFO_R2L) mkImg(UFO_R2L_HIT)

			pcall(function() ContentProvider:PreloadAsync(bucket:GetChildren()) end)

			local remain = math.max(0, 2 - (os.clock() - t0))
			if remain > 0 then task.wait(remain) end

			overlay:Destroy()
			bucket:Destroy()
			didPreloadOnce = true
		end

		inGame = true
		initFirmamentGui()
		bindControls()
		if StartRequest then StartRequest:FireServer() end
	end,

	OnReturnToMenu = function() exitCurrentGame() end,
	OnExit = function() print("returning to lobby...") end
}

local function updateMuteButtonVisuals(btn)
	if not btn then return end
	if soundEnabled then
		btn.BackgroundColor3 = Color3.fromHex("ff8904")
		btn.Text = "🔊 ON"
	else
		btn.BackgroundColor3 = Color3.fromHex("666666")
		btn.Text = "🔇 MUTED"
	end
end

function exitCurrentGame()
	inGame = false
	pcall(function() if SubmitMove then SubmitMove:FireServer({ action = "Exit" }) end end)
	if unbindControls then unbindControls() end
	if gameGui then gameGui:Destroy(); gameGui = nil end
	Menu1to7.AbrirMenuPrincipal(configFirmament)
end

-- builds the game frame, star field, hud, and canvas
function initFirmamentGui()
	if gameGui then gameGui:Destroy() end
	Menu1to7.EstablecerEnfoque(true)

	gameGui = Instance.new("ScreenGui", playerGui)
	gameGui.Name = "FirmamentGameGui"
	gameGui.ResetOnSpawn = false

	local frame = Instance.new("Frame", gameGui)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0.85, 0, 0.85, 0)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)

	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = (cols * cell) / (rows * cell + 30)
	Instance.new("UISizeConstraint", frame).MaxSize = Vector2.new(960, 780)

	canvas = Instance.new("Frame", frame)
	canvas.Name = "Canvas"
	local ch = rows * cell
	canvas.Size = UDim2.new(1, 0, ch / (ch + 30), 0)
	canvas.Position = UDim2.new(0, 0, 30 / (ch + 30), 0)
	canvas.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true

	ensureStars()

	hudLbl = Instance.new("TextLabel", frame)
	hudLbl.Name = "HudLabel"
	hudLbl.Size = UDim2.new(0.5, 0, 30/390, 0)
	hudLbl.Position = UDim2.new(0, 6, 0, 0)
	hudLbl.BackgroundTransparency = 1
	hudLbl.TextColor3 = Color3.new(1, 1, 1)
	hudLbl.TextScaled = true
	hudLbl.Font = Enum.Font.GothamBold
	hudLbl.TextXAlignment = Enum.TextXAlignment.Left
	hudLbl.Text = "Score: 0   Lives: 3   Wave: 1"

	overlayLbl = Instance.new("TextLabel", canvas)
	overlayLbl.Name = "Overlay"
	overlayLbl.Size = UDim2.new(1, 0, 1, 0)
	overlayLbl.Position = UDim2.new(0, 0, 0, 0)
	overlayLbl.BackgroundTransparency = 1
	overlayLbl.TextScaled = true
	overlayLbl.Font = Enum.Font.GothamBlack
	overlayLbl.TextColor3 = Color3.fromRGB(255, 255, 0)
	overlayLbl.Text = ""
	overlayLbl.ZIndex = 10

	hudExitBtn = Instance.new("TextButton", frame)
	hudExitBtn.AnchorPoint = Vector2.new(1,0)
	hudExitBtn.Position = UDim2.new(0.98, 0, 2/390, 0)
	hudExitBtn.Size = UDim2.new(0.15, 0, 26/390, 0)
	hudExitBtn.BackgroundColor3 = Color3.fromHex("7e2a0c")
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
		if ToggleAudio then ToggleAudio:FireServer(soundEnabled) end
	end)
end

-- removes all canvas children except the overlay and stars layer
local function clearCanvas()
	if not canvas then return end
	for _, ch in ipairs(canvas:GetChildren()) do
		if ch.Name ~= "Overlay" and ch.Name ~= "Stars" then ch:Destroy() end
	end
end

-- draws a solid colored rectangle at a grid cell position
local function addPixelRect(name, r, c, w, h, z, color)
	local widthScale = w / (cols * cell)
	local heightScale = h / (rows * cell)
	local x = (c - 1) / cols
	local y = (r - 1) / rows

	local f = Instance.new("Frame", canvas)
	f.Name = name
	f.Size = UDim2.new(widthScale, 0, heightScale, 0)
	f.Position = UDim2.new(x, 0, y, 0)
	f.BackgroundColor3 = color or Color3.fromRGB(30, 200, 30)
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	return f
end

-- draws an image sprite at a grid cell, falling back to a colored rect if no image
local function addSprite(name, r, c, imgId, z, fallbackColor)
	local x = (c - 1) / cols
	local y = (r - 1) / rows

	if imgId and imgId ~= "" then
		local img = Instance.new("ImageLabel", canvas)
		img.Name = name
		img.BackgroundTransparency = 1
		img.Size = UDim2.new(1/cols, 0, 1/rows, 0)
		img.Position = UDim2.new(x, 0, y, 0)
		img.ZIndex = z or 3
		img.Image = imgId
		img.ScaleType = Enum.ScaleType.Stretch
		return img
	else
		return addPixelRect(name, r, c, cell, cell, z or 3, fallbackColor)
	end
end

local function imageForAlien(a)
	if a.type == "A" then return IMG_A
	elseif a.type == "B" then return IMG_B
	else return IMG_C end
end

local function imageForAlienHit(aType)
	if aType == "A" then return IMG_A_HIT
	elseif aType == "B" then return IMG_B_HIT
	else return IMG_C_HIT end
end

local function drawShip(ship, state)
	if not ship then return end
	local imgId = (state and state.gameState == "dying") and SHIP_HIT_IMG or SHIP_IMG
	addSprite("Ship", ship.r, ship.c, imgId, 5, Color3.fromRGB(90, 200, 255))
end

local function drawAliens(aliens)
	if not aliens then return end
	for _, a in ipairs(aliens) do
		local spr = addSprite("Alien", a.r, a.c, imageForAlien(a), 3, nil)
		if spr and spr:IsA("GuiObject") then spr.Rotation = 180 end
	end
end

-- draws hit flash frames for aliens that died since the last render
local function drawAlienHitFlashes()
	if #alienHitFlashes == 0 then return end
	local t = now()
	local keep = {}
	for _, f in ipairs(alienHitFlashes) do
		if f.expire > t then
			local spr = addSprite("AlienHit", f.r, f.c, imageForAlienHit(f.type), 8, nil)
			if spr and spr:IsA("GuiObject") then spr.Rotation = 180 end
			table.insert(keep, f)
		end
	end
	alienHitFlashes = keep
end

-- chooses the correct ufo sprite based on last known travel direction
local function drawUfo(ufo)
	if not ufo then return end
	if not lastUfo then
		if ufo.c <= 1 then lastUfoDirLR = true elseif ufo.c >= cols then lastUfoDirLR = false end
	elseif ufo.c ~= lastUfo.c then
		lastUfoDirLR = (ufo.c > lastUfo.c)
	end
	local img = lastUfoDirLR and UFO_L2R or UFO_R2L
	local spr = addSprite("UFO", ufo.r, ufo.c, img, 4, nil)
	if spr and not lastUfoDirLR then spr.Rotation = 180 end
end

local function drawUfoHitFlashes()
	if #ufoHitFlashes == 0 then return end
	local t = now()
	local keep = {}
	for _, f in ipairs(ufoHitFlashes) do
		if f.expire > t then
			local img = f.dirLR and UFO_L2R_HIT or UFO_R2L_HIT
			local spr = addSprite("UFOHit", f.r, f.c, img, 9, nil)
			if spr and not f.dirLR then spr.Rotation = 180 end
			table.insert(keep, f)
		end
	end
	ufoHitFlashes = keep
end

local function drawBullets(playerBullets, enemyBullets)
	if playerBullets then
		for _, b in ipairs(playerBullets) do
			local bw = math.floor(cell * 0.2)
			local f = addPixelRect("PBullet", b.r, b.c, bw, cell, 6, Color3.fromRGB(120, 220, 255))
			f.Position = UDim2.new( (b.c - 1) / cols + (math.floor(cell * 0.4) / (cols * cell)), 0, (b.r - 1) / rows, 0 )
		end
	end
	if enemyBullets then
		for _, b in ipairs(enemyBullets) do
			local bw = math.floor(cell * 0.2)
			local f = addPixelRect("EBullet", b.r, b.c, bw, cell, 6, Color3.fromRGB(255, 120, 60))
			f.Position = UDim2.new( (b.c - 1) / cols + (math.floor(cell * 0.4) / (cols * cell)), 0, (b.r - 1) / rows, 0 )
		end
	end
end

-- colors shields green/yellow/red based on remaining hp
local function drawShields(shields)
	if not shields then return end
	for _, s in ipairs(shields) do
		local hp = s.hp or 3
		local col = (hp >= 3 and Color3.fromRGB(80, 220, 80)) or (hp == 2 and Color3.fromRGB(210, 210, 60)) or Color3.fromRGB(220, 80, 80)
		addPixelRect("Shield", s.r, s.c, cell, cell, 2, col)
	end
end

-- creates a twinkling star field behind the game canvas
function ensureStars()
	if starsLayer and starsLayer.Parent then return end
	starsLayer = Instance.new("Frame", canvas)
	starsLayer.Name = "Stars"
	starsLayer.Size = UDim2.new(1, 0, 1, 0)
	starsLayer.Position = UDim2.new(0, 0, 0, 0)
	starsLayer.BackgroundTransparency = 1
	starsLayer.ZIndex = 1

	stars = {}
	local w, h = cols * cell, rows * cell
	local n = math.clamp(math.floor((w * h) / 800), 50, 120)
	for _ = 1, n do
		local s = Instance.new("Frame", starsLayer)
		s.Size = UDim2.fromOffset(math.random(1, 2), math.random(1, 2))
		s.Position = UDim2.new(math.random(), 0, math.random(), 0)
		s.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		s.BackgroundTransparency = math.random() * 0.4 + 0.2
		s.BorderSizePixel = 0
		s.ZIndex = starsLayer.ZIndex
		table.insert(stars, s)
	end

	if twinkleConn then twinkleConn:Disconnect() end
	twinkleConn = RunService.Heartbeat:Connect(function()
		if not starsLayer or not starsLayer.Parent then return end
		for _ = 1, 6 do
			local s = stars[math.random(1, #stars)]
			if s then
				s.BackgroundTransparency = math.clamp(s.BackgroundTransparency + (math.random() - 0.5) * 0.2, 0.1, 0.9)
			end
		end
	end)
end

local function renderOverlay(state)
	overlayLbl.Text = ""
	if state.gameState == "ready" then
		overlayLbl.Text = "READY!"
	elseif state.gameState == "wave" and state.wave then
		overlayLbl.Text = "WAVE " .. tostring(state.wave)
	elseif state.gameState == "dying" then
		overlayLbl.Text = ""
	end
end

-- indexes aliens by type and grid key for efficient kill detection
local function indexAliensByType(list)
	local byType = { A = {}, B = {}, C = {} }
	for _, a in ipairs(list or {}) do
		local key = ("%d,%d"):format(a.r, a.c)
		local t = a.type or "A"
		byType[t][key] = true
	end
	return byType
end

-- compares prev and current alien lists to find which ones disappeared
local function computeAlienKills(prevList, curList)
	if not prevList or not curList then return {} end
	local curByType = indexAliensByType(curList)
	local killed = {}
	for _, a in ipairs(prevList) do
		local t = a.type or "A"
		local r, c = a.r, a.c
		local same  = curByType[t][("%d,%d"):format(r, c)]
		local left  = curByType[t][("%d,%d"):format(r, c - 1)]
		local right = curByType[t][("%d,%d"):format(r, c + 1)]
		local drop  = curByType[t][("%d,%d"):format(r + 1, c)]
		if not (same or left or right or drop) then
			table.insert(killed, { r = r, c = c, type = t })
		end
	end
	return killed
end

-- computes hit flashes, then redraws the full game canvas from server state
local function renderState(state)
	if lastAliens and state.aliens then
		local killed = computeAlienKills(lastAliens, state.aliens)
		local tEnd = now() + 0.18
		for _, k in ipairs(killed) do
			table.insert(alienHitFlashes, { r = k.r, c = k.c, type = k.type, expire = tEnd })
		end
	end
	lastAliens = state.aliens and table.clone(state.aliens) or nil

	if lastUfo and not state.ufo and state.explosionEvent then
		table.insert(ufoHitFlashes, { r = lastUfo.r, c = lastUfo.c, expire = now() + 0.25, dirLR = lastUfoDirLR })
	end
	lastUfo = state.ufo and { r = state.ufo.r, c = state.ufo.c } or nil

	if not gameGui or not gameGui.Parent then
		rows = state.rows or rows
		cols = state.cols or cols
		cell = state.cell or cell
		initFirmamentGui()
	end

	if hudLbl then
		local s = state.score or 0
		lastScore = s
		local lives = state.lives or (state.hud and state.hud.lives) or 3
		local wave = state.wave or state.level or (state.hud and state.hud.level) or 1
		if state.hudText then
			hudLbl.Text = state.hudText
		else
			hudLbl.Text = ("Score: %d   Lives: %d   Wave: %d"):format(s, lives, wave)
		end
	end

	clearCanvas()
	renderOverlay(state)

	addPixelRect("Ground", rows, 1, cols * cell, 2, 1, Color3.fromRGB(40, 40, 60))
	drawShields(state.shields)
	drawUfo(state.ufo)
	drawAliens(state.aliens)
	drawAlienHitFlashes()
	drawUfoHitFlashes()
	drawShip(state.ship, state)
	drawBullets(state.playerBullets, state.enemyBullets)
end

local upHeld, downHeld, leftHeld, rightHeld = false, false, false, false

-- sends the currently held direction to the server
local function sendDir()
	if not inGame then return end
	if leftHeld and not rightHeld then SubmitMove:FireServer("Left")
	elseif rightHeld and not leftHeld then SubmitMove:FireServer("Right")
	elseif upHeld and not downHeld then SubmitMove:FireServer("Up")
	elseif downHeld and not upHeld then SubmitMove:FireServer("Down")
	else SubmitMove:FireServer("Stop") end
end

local function onDirUp(actionName, state)
	if state == Enum.UserInputState.Begin then upHeld = true elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then upHeld = false end
	sendDir() return Enum.ContextActionResult.Sink
end
local function onDirDown(actionName, state)
	if state == Enum.UserInputState.Begin then downHeld = true elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then downHeld = false end
	sendDir() return Enum.ContextActionResult.Sink
end
local function onDirLeft(actionName, state)
	if state == Enum.UserInputState.Begin then leftHeld = true elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then leftHeld = false end
	sendDir() return Enum.ContextActionResult.Sink
end
local function onDirRight(actionName, state)
	if state == Enum.UserInputState.Begin then rightHeld = true elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then rightHeld = false end
	sendDir() return Enum.ContextActionResult.Sink
end

local function onShoot(actionName, state)
	if not inGame then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		SubmitMove:FireServer("Shoot")
		playSound(sndLaser)
	end
	return Enum.ContextActionResult.Sink
end

function bindControls()
	UniversalController.CrearControlesFirmament(onDirUp, onDirDown, onDirLeft, onDirRight, onShoot)
end

function unbindControls()
	UniversalController.LimpiarControles()
	upHeld, downHeld, leftHeld, rightHeld = false, false, false, false
end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gameName)
		if gameName == "FirmamentDefender" or gameName == "Firmament" then
			if inGame or playerGui:FindFirstChild("ArcadeMenuPrincipal") then return end
			Menu1to7.AbrirMenuPrincipal(configFirmament)
		end
	end)
end

if GameState then
	GameState.OnClientEvent:Connect(function(mode, data)
		if mode == "Start" then
			inGame = true
			lastScore = 0
			rows = (data and data.rows) or rows
			cols = (data and data.cols) or cols
			cell = (data and data.cell) or cell

			lastAliens = nil
			lastUfo = nil
			alienHitFlashes = {}
			ufoHitFlashes = {}

			initFirmamentGui()
			bindControls()
			renderState(data or {})
		elseif mode == "Update" then
			if inGame and data then
				if data.explosionEvent then playSound(sndExplosion) end
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
