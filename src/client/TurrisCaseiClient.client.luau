local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local ControlModule = PlayerModule:GetControls()

local MenuModule = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu8to10"))
local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local TurrisModule = require(ReplicatedStorage.Modules:WaitForChild("TurrisCaseiModule", 2))

-- creates a sound instance attached to this script
local function createSound(id, volume)
	if not id or id == "rbxassetid://0" then return nil end
	local s = Instance.new("Sound")
	s.SoundId = id; s.Volume = volume; s.Parent = script
	return s
end

local hoverSound = createSound("rbxassetid://500472891", 0.4)
local selectSound = createSound("rbxassetid://70844388753756", 0.5)
local gameOverSound = createSound("rbxassetid://5855421995", 0.7)
local placeSound = createSound("rbxassetid://4612375233", 0.8)
local perfectSound = createSound("rbxassetid://6895079853", 1.0)

local soundEnabled = true
local function playSound(s)
	if not soundEnabled then return end
	if s then s:Play() end
end

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes", 10)
local TurrisFolder = ArcadeRemotes and ArcadeRemotes:WaitForChild("TurrisCasei", 10)
local LobbySystem = TurrisFolder and TurrisFolder:FindFirstChild("LobbySystem")

local StartRequest = TurrisFolder and TurrisFolder:WaitForChild("StartTurrisCaseiRequest", 5)
local MatchStatus = TurrisFolder and TurrisFolder:WaitForChild("MatchStatus", 5)
local OpenArcadeMenu = ArcadeRemotes and ArcadeRemotes:WaitForChild("OpenArcadeMenu", 10)
local ToggleAudio = TurrisFolder and TurrisFolder:FindFirstChild("ToggleAudio")
local GetAudioState = TurrisFolder and TurrisFolder:FindFirstChild("GetAudioState")

local UpdateLiveScore, RoomUpdate, PlayerDiedEvent, SpectateEvent
local CreateRoomFunc, JoinRoomFunc, StartMatchEvent, LeaveRoomEvent, KickPlayerEvent

if LobbySystem then
	UpdateLiveScore = LobbySystem:WaitForChild("UpdateLiveScore", 5)
	RoomUpdate = LobbySystem:WaitForChild("RoomUpdate", 5)
	PlayerDiedEvent = LobbySystem:FindFirstChild("PlayerDied")
	SpectateEvent = LobbySystem:FindFirstChild("SpectateTarget")

	CreateRoomFunc = LobbySystem:WaitForChild("CreateRoom")
	JoinRoomFunc = LobbySystem:WaitForChild("JoinRoom")
	StartMatchEvent = LobbySystem:WaitForChild("StartMultiplayerMatch")
	LeaveRoomEvent = LobbySystem:WaitForChild("LeaveRoom")
	KickPlayerEvent = LobbySystem:WaitForChild("KickPlayer")
end

local Assets = ReplicatedStorage:WaitForChild("TurrisCasei_Assets", 10)

task.spawn(function()
	if GetAudioState then soundEnabled = not GetAudioState:InvokeServer() end
end)
if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local inGame = false
local isVersusMode = false
local Setup3DGame

local currentTowerFolder = nil
local cameraOriginalCFrame = nil
local GAME_ORIGIN = Vector3.new(0, 2000, 0)
local turnTimer = 0
local MAX_INITIAL_WAIT = 5
local MAX_TURN_TIME = 4
local turnPenalty = 0
local COMBO_COUNTER = 0
local SHAKE_INTENSITY = 0

local gameData = {
	currentBlock = nil, previousBlock = nil, moveConnection = nil,
	direction = "X", speed = 20, limit = 15, score = 0,
	startTime = 0, startPos = Vector3.new(), blocksCount = 0,
	activeBlockData = nil, phase = 0
}

-- snapshot of original lighting so it can be restored on exit
local originalLighting = {
	TimeOfDay = Lighting.TimeOfDay, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient, ColorShift_Bottom = Lighting.ColorShift_Bottom,
	ColorShift_Top = Lighting.ColorShift_Top, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}

local versusGui = nil
local hudScoreLabel = nil

-- destroys the tower folder, resets camera, and restores lighting
local function Cleanup3DGame()
	UniversalController.LimpiarControles()
	if gameData.moveConnection then gameData.moveConnection:Disconnect() end
	if currentTowerFolder then currentTowerFolder:Destroy() end
	if versusGui then versusGui:Destroy(); versusGui = nil end

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom; cam.FieldOfView = 70
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		cam.CameraSubject = player.Character:FindFirstChild("Humanoid")
		cam.CFrame = cameraOriginalCFrame or CFrame.lookAt(player.Character.HumanoidRootPart.Position + Vector3.new(0, 5, 12), player.Character.HumanoidRootPart.Position)
	end

	Lighting.TimeOfDay = originalLighting.TimeOfDay
	Lighting.Brightness = originalLighting.Brightness
	Lighting.Ambient = originalLighting.Ambient
	Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
	Lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom
	Lighting.ColorShift_Top = originalLighting.ColorShift_Top
	Lighting.FogColor = originalLighting.FogColor

	for _, name in ipairs({"SunsetAtmosphere", "SunsetSky"}) do
		local obj = Lighting:FindFirstChild(name); if obj then obj:Destroy() end
	end
	local customClouds = workspace.Terrain:FindFirstChild("SunsetClouds")
	if customClouds then customClouds:Destroy() end
end

function FullQuitGame()
	inGame = false; isVersusMode = false
	MenuModule.CerrarMenuCompleto()
	Cleanup3DGame()
	ControlModule:Enable()
end

local function ReturnToMainMenu()
	FullQuitGame()
	MenuModule.ShowMainMenu()
end

local function endGame()
	local finalTime = 0
	if gameData.startTime > 0 then finalTime = os.clock() - gameData.startTime end
	if MatchStatus then MatchStatus:FireServer("GameOver", gameData.score, finalTime) end
	inGame = false
	Cleanup3DGame()
	MenuModule.ShowGameOver(gameData.score, false, ReturnToMainMenu, FullQuitGame)
end

-- injects turris casei-specific colors, sounds, and callbacks into the shared menu module
local function InyectarConfiguracionTurris()
	MenuModule.Config.Title = "TURRIS CASEI"
	MenuModule.Config.SupportTitle = "TURRIS SUPPORT"
	MenuModule.Config.MainIcon = "cheese"

	MenuModule.Config.Emotes = { controller = "🎮", crown = "👑", door = "🚪", bird = "🐦", cheese = "🧀", solo = "👤", duo = "👥", back = "⬅️" }

	MenuModule.Config.Colors = {
		BG = Color3.fromHex("fef9c3"), BtnBase = Color3.fromHex("eab308"), BtnPlay = Color3.fromHex("facc15"),
		BtnExit = Color3.fromHex("a16207"), Underline = Color3.fromHex("a16207"), TitleMain = Color3.fromHex("a16207"),
		TitleAlt = Color3.fromHex("eab308"), LabelText = Color3.fromHex("fef9c3"), HUDMuteOn = Color3.fromHex("22c55e"),
		HUDMuteOff = Color3.fromHex("6b7280"), HUDExit = Color3.fromHex("ef4444")
	}

	MenuModule.Config.LobbyColors = {
		BG = Color3.fromHex("c4b5fd"), Primary = Color3.fromHex("8b5cf6"), Accent = Color3.fromHex("7c3aed"),
		Dark = Color3.fromHex("5b21b6"), TextLight = Color3.fromHex("f5f3ff"), ExitRed = Color3.fromHex("ef4444"), WinGold = Color3.fromHex("fbbf24")
	}

	MenuModule.Config.Donations = {
		{ Id = 3518446349, Price = 5, Name = "Cheese Tip" }, { Id = 3518446440, Price = 15, Name = "Cheese Treat" },
		{ Id = 3518446529, Price = 50, Name = "Cheese Sub" }, { Id = 3518446659, Price = 100, Name = "Cheese Sponsor" },
		{ Id = 3518446761, Price = 500, Name = "Cheese Whale" }, { Id = 3518446854, Price = 1000, Name = "Cheese Legend" }
	}

	MenuModule.Config.Sounds = { Hover = hoverSound, Select = selectSound, GameOver = gameOverSound, Perfect = perfectSound }

	MenuModule.Callbacks.OnPlaySolo = function()
		inGame = true; isVersusMode = false
		MenuModule.CerrarMenuCompleto()
		if StartRequest then pcall(function() StartRequest:FireServer("Solo") end) end
		Setup3DGame()
	end

	MenuModule.Callbacks.OnExitGame = function() FullQuitGame() end
	MenuModule.Callbacks.OnToggleAudio = function(state) soundEnabled = state; if ToggleAudio then ToggleAudio:FireServer(state) end end

	if LobbySystem then
		MenuModule.Callbacks.OnCreateRoom = function() return CreateRoomFunc:InvokeServer() end
		MenuModule.Callbacks.OnJoinRoom = function(pin) return JoinRoomFunc:InvokeServer(pin) end
		MenuModule.Callbacks.OnStartMatch = function() StartMatchEvent:FireServer() end
		MenuModule.Callbacks.OnLeaveRoom = function() LeaveRoomEvent:FireServer() end
		MenuModule.Callbacks.OnKickPlayer = function(name) KickPlayerEvent:FireServer(name) end
	end
end

-- side bar showing player avatar icons positioned by their current score
local function createVersusHUD()
	if playerGui:FindFirstChild("VersusHUD") then playerGui.VersusHUD:Destroy() end
	local gui = Instance.new("ScreenGui", playerGui); gui.Name = "VersusHUD"
	local barBg = Instance.new("Frame", gui)
	barBg.Size = UDim2.new(0.03, 0, 0.6, 0); barBg.Position = UDim2.new(0.95, 0, 0.2, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50); barBg.BorderSizePixel = 0
	Instance.new("UISizeConstraint", barBg).MaxSize = Vector2.new(40, 800)
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame", barBg)
	fill.Name = "Fill"; fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundTransparency = 1
	versusGui = gui
end

local function updateVersusHUD(playerList)
	if not versusGui then return end
	local fill = versusGui:FindFirstChild("Frame"):FindFirstChild("Fill")
	if not fill then return end
	for _, c in ipairs(fill:GetChildren()) do if c:IsA("ImageLabel") then c:Destroy() end end
	for _, pData in ipairs(playerList) do
		local percent = math.clamp((pData.Score or 0) / 50, 0, 1)
		local icon = Instance.new("ImageLabel", fill)
		icon.Size = UDim2.new(1.5, 0, 1.5, 0); Instance.new("UIAspectRatioConstraint", icon).AspectRatio = 1
		icon.Position = UDim2.new(0.5, 0, 1 - percent, 0); icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1; icon.ZIndex = 5
		icon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(pData.Id) .. "&w=150&h=150"
		Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

		if not pData.Alive then
			icon.ImageColor3 = Color3.new(0.2, 0.2, 0.2)
			local x = Instance.new("TextLabel", icon)
			x.Size = UDim2.fromScale(1,1); x.BackgroundTransparency = 1; x.Text = "❌"; x.TextScaled = true; x.ZIndex = 6
		end
		if pData.Name == player.Name then
			local s = Instance.new("UIStroke", icon); s.Thickness=2; s.Color=Color3.new(1,1,0)
		end
	end
end

-- returns a warm yellow-orange hue that slowly shifts with the score
local function GetYellowGradientColor(score)
	local hue = 0.14 + (math.sin(score * 0.1) * 0.04)
	return Color3.fromHSV(hue, 0.8, 1)
end

-- briefly offsets the camera in random directions to simulate impact
local function TriggerScreenShake(intensity)
	SHAKE_INTENSITY = intensity
	task.spawn(function()
		local startTime = tick()
		while (tick() - startTime) < 0.25 do
			if not inGame then break end
			local shake = Vector3.new((math.random()-0.5)*SHAKE_INTENSITY, (math.random()-0.5)*SHAKE_INTENSITY, (math.random()-0.5)*SHAKE_INTENSITY)
			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * CFrame.new(shake)
			RunService.RenderStepped:Wait()
			cam.CFrame = cam.CFrame * CFrame.new(-shake)
		end
		SHAKE_INTENSITY = 0
	end)
end

-- flashes a block white then returns it to its original color
local function FlashBlock(block)
	local t = TweenService:Create(block, TweenInfo.new(0.1), {Color = Color3.new(1,1,1)})
	t:Play()
	t.Completed:Connect(function()
		local targetColor = block:GetAttribute("OriginalColor") or block.Color
		TweenService:Create(block, TweenInfo.new(0.3), {Color = targetColor}):Play()
	end)
end

-- spawns a neon ring that expands and fades outward from a position
local function SpawnShockwave(pos)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder; ring.Anchored = true; ring.CanCollide = false
	ring.Material = Enum.Material.Neon; ring.Color = Color3.fromRGB(255, 255, 200)
	ring.Size = Vector3.new(0.5, 10, 10)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0,0,math.rad(90))
	ring.Parent = workspace
	Debris:AddItem(ring, 1)
	TweenService:Create(ring, TweenInfo.new(0.5), {Size = Vector3.new(0.5, 30, 30), Transparency = 1}):Play()
end

-- emits a burst of particles at a position using the given color
local function SpawnCutParticles(pos, color)
	local att = Instance.new("Attachment"); att.Parent = workspace.Terrain; att.WorldPosition = pos
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://1266170131"; emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.5, 0); emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(10, 20); emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Rate = 0; emitter.Parent = att
	emitter:Emit(20); Debris:AddItem(att, 2)
end

-- bounces a block slightly larger then springs it back to original size
local function PopBlock(block)
	local originalSize = block.Size
	block.Size = originalSize * 1.2
	TweenService:Create(block, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), {Size = originalSize}):Play()
end

-- shows a floating score text that drifts upward and auto-destroys
local function ShowBonusText(pos, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = nil; billboard.Size = UDim2.fromScale(4, 2); billboard.AlwaysOnTop = true
	local lbl = Instance.new("TextLabel", billboard)
	lbl.Size = UDim2.fromScale(1,1); lbl.BackgroundTransparency = 1; lbl.Text = text
	lbl.TextColor3 = color; lbl.Font = Enum.Font.GothamBlack; lbl.TextScaled = true
	Instance.new("UIStroke", lbl).Thickness = 2
	local part = Instance.new("Part")
	part.Anchored = true; part.CanCollide = false; part.Transparency = 1; part.Position = pos; part.Parent = workspace
	billboard.Adornee = part; billboard.Parent = playerGui
	TweenService:Create(part, TweenInfo.new(1), {Position = pos + Vector3.new(0, 5, 0)}):Play()
	Debris:AddItem(part, 1); Debris:AddItem(billboard, 1)
end

-- smoothly moves and zooms the camera to keep the active block in good view
local function UpdateDynamicCamera()
	local cam = workspace.CurrentCamera
	if inGame and gameData.currentBlock then
		local sx = gameData.currentBlock.Size.X; local sz = gameData.currentBlock.Size.Z
		local minDim = math.min(sx, sz)

		local targetFOV = 70
		local targetPos = GAME_ORIGIN + Vector3.new(13, 28, 15)
		local lookAtPos = Vector3.new(GAME_ORIGIN.X, gameData.currentBlock.Position.Y - 2, GAME_ORIGIN.Z)

		if minDim < 6.0 then
			local percent = math.clamp(minDim / 6.0, 0.2, 1.0)
			targetFOV = 50 + (20 * percent)
			local offsetX = 8 + (5 * percent); local offsetY = 22 + (6 * percent); local offsetZ = 10 + (5 * percent)
			targetPos = GAME_ORIGIN + Vector3.new(offsetX, offsetY, offsetZ)
		end
		TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = targetFOV, CFrame = CFrame.lookAt(targetPos, lookAtPos) }):Play()
	end
end

-- slides the whole tower down by one block height and removes blocks below the origin
local function ScrollTowerDown()
	local THRESHOLD = 6
	local bHeight = TurrisModule.Settings.BlockHeight or 1.5
	if gameData.blocksCount > THRESHOLD then
		for _, obj in ipairs(currentTowerFolder:GetChildren()) do
			if obj.Name ~= "RoomModel" then
				local newY = obj.Position.Y - bHeight
				TweenService:Create(obj, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Position = Vector3.new(obj.Position.X, newY, obj.Position.Z) }):Play()
				if newY < (GAME_ORIGIN.Y - (bHeight * 1)) then obj:Destroy() end
			end
		end
	end
end

-- creates the next moving block above the previous one, alternating X/Z axis
local function SpawnNextBlock()
	if not inGame or not gameData.previousBlock then return end
	local prevPos = gameData.previousBlock.Position
	local bHeight = TurrisModule.Settings.BlockHeight or 1.5
	local limit = gameData.limit or 15

	gameData.direction = (gameData.direction == "X") and "Z" or "X"
	local spawnPos = (gameData.direction == "X") and (prevPos + Vector3.new(-limit, bHeight, 0)) or (prevPos + Vector3.new(0, bHeight, -limit))
	local nextBlockData = TurrisModule.PickNextBlockData()
	gameData.activeBlockData = nextBlockData

	local finalColor = nextBlockData.Color
	if nextBlockData.Type == "Normal" then finalColor = GetYellowGradientColor(gameData.score) end

	local newBlock = Assets.QuesoBlock:Clone()
	newBlock.Size = Vector3.new(gameData.previousBlock.Size.X, bHeight, gameData.previousBlock.Size.Z)
	newBlock.CFrame = CFrame.new(spawnPos); newBlock.Color = finalColor; newBlock:SetAttribute("OriginalColor", finalColor)
	newBlock.Parent = currentTowerFolder

	-- green light turns on when the block is aligned within tolerance
	local alignLight = Instance.new("SpotLight")
	alignLight.Name = "AlignLight"; alignLight.Face = Enum.NormalId.Bottom
	alignLight.Angle = 90; alignLight.Brightness = 0; alignLight.Range = 20; alignLight.Color = Color3.fromRGB(57, 255, 20); alignLight.Parent = newBlock

	if nextBlockData.Value ~= 0 then
		local sg = Instance.new("SurfaceGui", newBlock)
		sg.Face = Enum.NormalId.Top; sg.CanvasSize = Vector2.new(100, 100); sg.AlwaysOnTop = false; sg.LightInfluence = 0
		local lbl = Instance.new("TextLabel", sg)
		lbl.Size = UDim2.fromScale(1,1); lbl.BackgroundTransparency = 1
		local prefix = (nextBlockData.Value > 0) and "+" or ""
		lbl.Text = prefix .. tostring(nextBlockData.Value); lbl.TextColor3 = Color3.new(1,1,1); lbl.Font = Enum.Font.GothamBlack; lbl.TextScaled = true
		Instance.new("UIStroke", lbl).Thickness = 3
	end

	local highlight = Instance.new("Highlight")
	highlight.Adornee = newBlock; highlight.FillTransparency = 1; highlight.OutlineColor = Color3.fromRGB(255, 140, 0); highlight.OutlineTransparency = 0; highlight.Parent = newBlock

	gameData.currentBlock = newBlock; gameData.startPos = spawnPos; turnTimer = tick()
end

-- drives the oscillating block movement each frame using a sine wave
local function StartMovementLoop()
	if gameData.moveConnection then gameData.moveConnection:Disconnect() end
	gameData.phase = -math.pi / 2

	gameData.moveConnection = RunService.RenderStepped:Connect(function(dt)
		if not inGame or not gameData.currentBlock then return end

		if isVersusMode then
			local elapsed = tick() - turnTimer
			if gameData.score == 0 and elapsed > MAX_INITIAL_WAIT then
				inGame = false
				if PlayerDiedEvent then PlayerDiedEvent:FireServer() end
				return
			end
			if gameData.score > 0 and elapsed > MAX_TURN_TIME then turnPenalty = (elapsed - MAX_TURN_TIME) * 5 else turnPenalty = 0 end
		end

		local currentSize = (gameData.direction == "X") and gameData.previousBlock.Size.X or gameData.previousBlock.Size.Z
		local sizeFactor = math.clamp(currentSize / 10, 0.4, 1.0)
		local currentSpeed = math.min(((gameData.speed or 20) * sizeFactor) + turnPenalty, 30)

		gameData.phase = gameData.phase + (dt * (currentSpeed / 10))
		local limit = gameData.limit or 15
		local offset = math.sin(gameData.phase) * limit

		local basePos = gameData.startPos
		local targetPos = (gameData.direction == "X") and Vector3.new(gameData.previousBlock.Position.X + offset, basePos.Y, basePos.Z) or Vector3.new(basePos.X, basePos.Y, gameData.previousBlock.Position.Z + offset)

		gameData.currentBlock.Position = targetPos

		local diff = (gameData.direction == "X") and (targetPos.X - gameData.previousBlock.Position.X) or (targetPos.Z - gameData.previousBlock.Position.Z)
		local tolerance = (TurrisModule and TurrisModule.Settings and TurrisModule.Settings.Tolerance) or 3.0
		local light = gameData.currentBlock:FindFirstChild("AlignLight")

		if light then
			if math.abs(diff) <= tolerance then
				light.Brightness = 10
				gameData.currentBlock.Material = Enum.Material.Neon
			else
				light.Brightness = 0
				if gameData.activeBlockData and gameData.activeBlockData.Type == "Normal" then
					gameData.currentBlock.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end)
end

-- snaps the block in place, calculates overlap, spawns waste piece, and scores the result
local function PlaceBlock()
	if not inGame or not gameData.currentBlock then return end
	gameData.moveConnection:Disconnect()

	local success, newSize, offset, fallingPartData, bonusScore = TurrisModule.CalculateStack(
		gameData.previousBlock.Size, gameData.previousBlock.CFrame, gameData.currentBlock.CFrame, gameData.activeBlockData
	)

	if not success then
		gameData.currentBlock.Anchored = false
		Debris:AddItem(gameData.currentBlock, 2)
		playSound(gameOverSound)
		TriggerScreenShake(0.8)
		inGame = false

		if isVersusMode then
			if PlayerDiedEvent then PlayerDiedEvent:FireServer() end
			MenuModule.ShowBottomAlert("YOU DIED!", "Spectating other players...", Color3.fromRGB(225, 29, 72))
		else
			task.wait(1)
			endGame()
		end
		return
	end

	local bHeight = TurrisModule.Settings.BlockHeight or 1.5
	local prevPos = gameData.previousBlock.Position
	local newCenter = Vector3.new(prevPos.X + offset.X, prevPos.Y + bHeight, prevPos.Z + offset.Z)

	gameData.currentBlock.Size = newSize; gameData.currentBlock.CFrame = CFrame.new(newCenter)

	for _, v in ipairs(gameData.currentBlock:GetChildren()) do
		if v:IsA("SurfaceGui") or v:IsA("SpotLight") then v:Destroy() end
	end

	PopBlock(gameData.currentBlock)
	FlashBlock(gameData.currentBlock)

	if fallingPartData then
		COMBO_COUNTER = 0; playSound(placeSound); SpawnCutParticles(newCenter, gameData.currentBlock.Color); TriggerScreenShake(0.3)

		local waste = gameData.currentBlock:Clone()
		waste.Name = "Waste"; waste.Anchored = false; waste.CanCollide = false
		local wasteHighlight = waste:FindFirstChild("Highlight")
		if wasteHighlight then wasteHighlight:Destroy() end
		for _, v in ipairs(waste:GetChildren()) do if v:IsA("SurfaceGui") then v:Destroy() end end
		Debris:AddItem(waste, 0.3)

		if gameData.direction == "X" then
			waste.Size = Vector3.new(math.abs(fallingPartData.diffX), newSize.Y, newSize.Z)
			local wasteX = (fallingPartData.diffX > 0) and (newCenter.X + newSize.X/2 + waste.Size.X/2) or (newCenter.X - newSize.X/2 - waste.Size.X/2)
			waste.Position = Vector3.new(wasteX, newCenter.Y, newCenter.Z)
		else
			waste.Size = Vector3.new(newSize.X, newSize.Y, math.abs(fallingPartData.diffZ))
			local wasteZ = (fallingPartData.diffZ > 0) and (newCenter.Z + newSize.Z/2 + waste.Size.Z/2) or (newCenter.Z - newSize.Z/2 - waste.Size.Z/2)
			waste.Position = Vector3.new(newCenter.X, newCenter.Y, wasteZ)
		end
		waste.Parent = currentTowerFolder
	else
		COMBO_COUNTER = COMBO_COUNTER + 1; playSound(perfectSound); SpawnShockwave(newCenter); TriggerScreenShake(0.1)
		if COMBO_COUNTER > 1 then
			gameData.currentBlock.Material = Enum.Material.Neon
			if gameData.activeBlockData.Type == "Normal" then gameData.currentBlock.Color = Color3.fromHSV(0.16, 1, 1) end
		end
	end

	local points = 1
	if type(bonusScore) == "number" then
		points = 1 + bonusScore
		if bonusScore > 0 then ShowBonusText(newCenter, "+"..tostring(bonusScore).."!", Color3.new(0,1,0))
		elseif bonusScore < 0 then ShowBonusText(newCenter, tostring(bonusScore), Color3.new(1,0,0)) end
	end

	gameData.score = gameData.score + points
	gameData.blocksCount = gameData.blocksCount + 1
	gameData.previousBlock = gameData.currentBlock
	gameData.speed = TurrisModule.GetNextSpeed(gameData.speed)

	UpdateDynamicCamera()

	if isVersusMode and UpdateLiveScore then UpdateLiveScore:FireServer(gameData.score) end
	if hudScoreLabel then hudScoreLabel.Text = "SCORE: " .. tostring(gameData.score) end

	ScrollTowerDown()
	SpawnNextBlock()
	StartMovementLoop()
end

-- builds the room, base block, hud, camera, and starts the first block
Setup3DGame = function()
	MenuModule.CerrarMenuCompleto()
	ControlModule:Disable()

	if currentTowerFolder then currentTowerFolder:Destroy() end
	currentTowerFolder = Instance.new("Folder"); currentTowerFolder.Name = "Local_TurrisCasei_Game"; currentTowerFolder.Parent = workspace

	Lighting.TimeOfDay = "17:30:00"; Lighting.Brightness = 0.2; Lighting.Ambient = Color3.fromHex("FF6B2B")
	Lighting.OutdoorAmbient = Color3.fromHex("FF8C42"); Lighting.ColorShift_Bottom = Color3.fromHex("FF3300")
	Lighting.ColorShift_Top = Color3.fromHex("FFAA00"); Lighting.FogColor = Color3.fromHex("FF7043")

	local room = Assets.RoomModel:Clone()
	room:PivotTo(CFrame.new(GAME_ORIGIN)); room.Parent = currentTowerFolder
	local base = Assets.BaseP1:Clone()
	base.Position = GAME_ORIGIN + Vector3.new(0, 1, 0); base.Parent = currentTowerFolder

	gameData.previousBlock = base; gameData.score = 0; gameData.blocksCount = 0
	gameData.direction = "Z"; gameData.startTime = os.clock(); COMBO_COUNTER = 0

	hudScoreLabel = MenuModule.ShowInGameHUD(not soundEnabled, MenuModule.Callbacks.OnToggleAudio, function()
		if isVersusMode and LeaveRoomEvent then LeaveRoomEvent:FireServer() end
		FullQuitGame()
	end)

	UniversalController.CrearControlesTurris(PlaceBlock)

	local Camera = workspace.CurrentCamera
	cameraOriginalCFrame = Camera.CFrame; Camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(Camera, TweenInfo.new(1.5, Enum.EasingStyle.Exponential), { CFrame = CFrame.lookAt(GAME_ORIGIN + Vector3.new(10, 28, 10), GAME_ORIGIN) }):Play()

	task.delay(1.6, function()
		if inGame then SpawnNextBlock(); StartMovementLoop() end
	end)
end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gn)
		if gn == "TurrisCasei" and not inGame then
			InyectarConfiguracionTurris()
			MenuModule.ShowMainMenu()
		end
	end)
end

if SpectateEvent then
	SpectateEvent.OnClientEvent:Connect(function(targetPlayer)
		local camera = workspace.CurrentCamera
		if targetPlayer and targetPlayer.Character then
			local hum = targetPlayer.Character:FindFirstChild("Humanoid")
			if hum then camera.CameraSubject = hum end
		end
	end)
end

if RoomUpdate then
	RoomUpdate.OnClientEvent:Connect(function(type, data)
		if type == "ScoreUpdate" and inGame and isVersusMode then
			updateVersusHUD(data)
		elseif type == "PlayerJoined" or type == "PlayerLeft" then
			MenuModule.UpdateLobbyPlayers(data)
		elseif type == "StartGame" then
			FullQuitGame(); task.wait(0.1)
			inGame = true; isVersusMode = true
			Setup3DGame(); createVersusHUD()
		elseif type == "MatchEnded" then
			local win = (data.Winner == player.Name)
			Cleanup3DGame()
			inGame = false; isVersusMode = false
			MenuModule.ShowGameOver(data.Score or 0, win, ReturnToMainMenu, FullQuitGame)

			local titleColor = win and Color3.fromHex("fbbf24") or Color3.fromHex("5b21b6")
			local textTitle = win and "VICTORY!" or "GAME OVER"
			MenuModule.ShowInfoOverlay(textTitle, "Winner: " .. (data.Winner or "") .. "\nScore: " .. tostring(data.Score or 0), titleColor)
		elseif type == "EliminatedEarly" then
			Cleanup3DGame()
			inGame = false; isVersusMode = false
			MenuModule.ShowGameOver(data.Score or 0, false, ReturnToMainMenu, FullQuitGame)
		elseif type == "SuddenDeathWait" then
			MenuModule.ShowBottomAlert("MATCH ENDING...", "The game will close in 5 seconds!", Color3.fromRGB(255, 100, 100))
		elseif type == "SuddenDeath" then
			playSound(perfectSound)
			MenuModule.ShowBottomAlert("SUDDEN DEATH!", "THE GAME ENDS IN 5 SECONDS!", Color3.fromRGB(255, 50, 50))
		elseif type == "Kicked" or type == "RoomClosed" then
			MenuModule.DestroyAllMenus()
			MenuModule.ShowMainMenu()
			local titleText = (type == "Kicked") and "KICKED" or "CLOSED"
			local msgText = (type == "Kicked") and "You were removed." or "Room closed."
			MenuModule.ShowInfoOverlay(titleText, msgText, Color3.fromRGB(239, 68, 68))
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not inGame then return end

	if UniversalController.EsBotonAtras(input) then
		if isVersusMode and LeaveRoomEvent then LeaveRoomEvent:FireServer() end
		FullQuitGame()
		return
	end

	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		if not processed then PlaceBlock() end
	end
end)
