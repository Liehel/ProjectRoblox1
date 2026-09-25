local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local ControlModule = PlayerModule:GetControls()

local MenuModule = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu8to10"))
local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local TapModule = require(ReplicatedStorage.Modules:WaitForChild("TapAndHoldModule"))

-- creates a sound instance attached to this script
local function createSound(id, vol)
	if not id or id == "rbxassetid://0" then return nil end
	local s = Instance.new("Sound", script)
	s.SoundId = id; s.Volume = vol or 0.5
	return s
end

local hoverSound = createSound("rbxassetid://500472891", 0.4)
local selectSound = createSound("rbxassetid://70844388753756", 0.5)
local gameOverSound = createSound("rbxassetid://5855421995", 0.7)
local jumpSound = createSound("rbxassetid://6895079853", 0.8)
local perfectSound = createSound("rbxassetid://500472891", 1.0)
local chargeSound = createSound("rbxassetid://0", 0.3)

local soundEnabled = true
local function playSound(s)
	if not soundEnabled then return end
	if s then s:Play() end
end

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes", 10)
local TapFolder = ArcadeRemotes and ArcadeRemotes:WaitForChild("TapAndHold", 10)
local LobbySystem = TapFolder and TapFolder:FindFirstChild("LobbySystem")

local StartRequest = TapFolder and TapFolder:WaitForChild("StartTapAndHoldRequest", 5)
local MatchStatus = TapFolder and TapFolder:WaitForChild("MatchStatus", 5)
local OpenArcadeMenu = ArcadeRemotes and ArcadeRemotes:WaitForChild("OpenArcadeMenu", 10)
local ToggleAudio = TapFolder and TapFolder:FindFirstChild("ToggleAudio")
local GetAudioState = TapFolder and TapFolder:FindFirstChild("GetAudioState")

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

local Assets = ReplicatedStorage:WaitForChild("TapAndHold_Assets")

task.spawn(function()
	if GetAudioState then soundEnabled = not GetAudioState:InvokeServer() end
end)
if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local inGame = false
local isVersusMode = false
local currentTowerFolder = nil
local originalPosBeforeGame = nil

local GAME_ORIGIN = Vector3.new(50000, 1000, 50000)
local WATER_OFFSET_Y = 15
local MAX_CHARGE_TIME = 1.2
local GLOBAL_TOP_Y = 0
local AFK_TIMEOUT = 5

local gameData = {
	score = 0, platforms = {}, targetPlatform = nil, dummy = nil, humanoid = nil,
	isCharging = false, chargeStartTime = 0, isJumping = false, startTime = 0,
	jumpConnection = nil, scaleTween = nil, scaleConnection = nil, scaleVal = nil,
	startPromptText = nil, rotationTween = nil, lastLandTime = 0, afkConnection = nil, localChar = nil
}

-- snapshot of original lighting so it can be restored on exit
local originalLighting = {
	TimeOfDay = Lighting.TimeOfDay, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient, ColorShift_Bottom = Lighting.ColorShift_Bottom,
	ColorShift_Top = Lighting.ColorShift_Top, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}

local hudScoreLabel = nil
local versusGui = nil
local Setup3DGame

-- enables or disables the native roblox jump for the player's character
local function setNativeJumpEnabled(enabled)
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled) end
	end
end

-- disconnects all connections, destroys the game folder, restores character and lighting
local function Cleanup3DGame()
	UniversalController.LimpiarControles()

	if gameData.jumpConnection then gameData.jumpConnection:Disconnect() end
	if gameData.afkConnection then gameData.afkConnection:Disconnect() gameData.afkConnection = nil end

	if currentTowerFolder then currentTowerFolder:Destroy() end
	currentTowerFolder = nil
	gameData.localChar = nil

	if gameData.startPromptText then
		gameData.startPromptText:Destroy()
		gameData.startPromptText = nil
	end

	if versusGui then versusGui:Destroy(); versusGui = nil end

	local realCharacter = player.Character
	if realCharacter and originalPosBeforeGame then
		local hrp = realCharacter:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false hrp.Velocity = Vector3.new(0, 0, 0) end
		realCharacter:ScaleTo(1)
		realCharacter:PivotTo(originalPosBeforeGame)
	end

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	if realCharacter then
		local humanoid = realCharacter:FindFirstChild("Humanoid")
		if humanoid then cam.CameraSubject = humanoid end
	end

	Lighting.TimeOfDay = originalLighting.TimeOfDay
	Lighting.Brightness = originalLighting.Brightness
	Lighting.Ambient = originalLighting.Ambient
	Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
	Lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom
	Lighting.ColorShift_Top = originalLighting.ColorShift_Top
	Lighting.FogColor = originalLighting.FogColor
	Lighting.FogEnd = originalLighting.FogEnd
	Lighting.FogStart = originalLighting.FogStart

	local customAtmo = Lighting:FindFirstChild("SunsetAtmosphere")
	if customAtmo then customAtmo:Destroy() end
	local customSky = Lighting:FindFirstChild("SunsetSky")
	if customSky then customSky:Destroy() end
	local customClouds = workspace.Terrain:FindFirstChild("SunsetClouds")
	if customClouds then customClouds:Destroy() end
end

-- full teardown including menu close and re-enabling player controls
function FullQuitGame()
	inGame = false; isVersusMode = false
	MenuModule.CerrarMenuCompleto()
	Cleanup3DGame()
	originalPosBeforeGame = nil
	ControlModule:Enable()
	setNativeJumpEnabled(true)
end

local function ReturnToMainMenu()
	FullQuitGame()
	MenuModule.ShowMainMenu()
end

-- fires game over to server and shows the game over screen
local function endGame()
	local finalTime = 0
	if gameData.startTime > 0 then finalTime = os.clock() - gameData.startTime end
	if MatchStatus then MatchStatus:FireServer("GameOver", gameData.score, finalTime) end
	inGame = false
	Cleanup3DGame()
	MenuModule.ShowGameOver(gameData.score, false, ReturnToMainMenu, FullQuitGame)
end

-- injects tap and hold-specific colors, sounds, and callbacks into the shared menu module
local function InyectarConfiguracionTap()
	MenuModule.Config.Title = "TAP AND HOLD"
	MenuModule.Config.SupportTitle = "TAP SUPPORT"
	MenuModule.Config.MainIcon = "jump"

	MenuModule.Config.Emotes = { controller = "🎮", crown = "👑", door = "🚪", jump = "🚀", cheese = "🆙", solo = "👤", duo = "👥", back = "⬅️" }

	MenuModule.Config.Colors = {
		BG = Color3.fromHex("fecdd3"), BtnBase = Color3.fromHex("e11d48"), BtnPlay = Color3.fromHex("fb7185"),
		BtnExit = Color3.fromHex("be123c"), Underline = Color3.fromHex("9f1239"), TitleMain = Color3.fromHex("881337"),
		TitleAlt = Color3.fromHex("f43f5e"), LabelText = Color3.fromHex("fecdd3"), HUDMuteOn = Color3.fromHex("f43f5e"),
		HUDMuteOff = Color3.fromHex("4c0519"), HUDExit = Color3.fromHex("e11d48")
	}

	MenuModule.Config.LobbyColors = {
		BG = Color3.fromHex("fecdd3"), Primary = Color3.fromHex("fb7185"), Accent = Color3.fromHex("f43f5e"),
		Dark = Color3.fromHex("881337"), TextLight = Color3.fromHex("fecdd3"), ExitRed = Color3.fromHex("e11d48"), WinGold = Color3.fromHex("fbbf24")
	}

	MenuModule.Config.Donations = {
		{ Id = 3572911018, Price = 5, Name = "Tap Tip" }, { Id = 3572911230, Price = 15, Name = "Tap Treat" },
		{ Id = 3572911349, Price = 50, Name = "Tap Sub" }, { Id = 3572911440, Price = 100, Name = "Tap Sponsor" },
		{ Id = 3572911513, Price = 500, Name = "Tap Whale" }, { Id = 3474075594, Price = 1000, Name = "Tap Legend" }
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

-- creates a vertical progress bar on the right showing each player's score position
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

-- refreshes the versus hud with the latest player score list
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

-- returns the vertical distance from hrp center to the ground
local function getCharacterLegOffset(charHumanoid, charHrp)
	if charHumanoid.RigType == Enum.HumanoidRigType.R15 then
		return (charHrp.Size.Y / 2) + charHumanoid.HipHeight
	else
		return (charHrp.Size.Y / 2) + 2
	end
end

-- smoothly moves the camera to follow the avatar and frame the target platform
local function UpdateCamera()
	if not inGame or not gameData.dummy then return end
	local cam = workspace.CurrentCamera
	local targetPlatform = gameData.targetPlatform

	local lookPos = gameData.dummy.Position
	if targetPlatform then lookPos = gameData.dummy.Position:Lerp(targetPlatform.Position, 0.5) end

	local offset = Vector3.new(-15, 15, -15)
	local targetCFrame = CFrame.lookAt(gameData.dummy.Position + offset, lookPos)
	TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCFrame}):Play()

	if currentTowerFolder then
		local floor = currentTowerFolder:FindFirstChild("FloorModel")
		if floor then floor:PivotTo(floor:GetPivot().Rotation + Vector3.new(gameData.dummy.Position.X, GAME_ORIGIN.Y - WATER_OFFSET_Y, gameData.dummy.Position.Z)) end
	end
end

-- picks the next platform type, places it, and tweens it up into position
local function SpawnNextPlatform()
	if not inGame then return end

	local pData = TapModule.PickNextPlatformData()
	local modelName = pData.ModelName

	local prevPlatform = gameData.platforms[#gameData.platforms]
	local prevPos = prevPlatform.Position

	local distance = math.random(TapModule.Settings.MinDistance, TapModule.Settings.MaxDistance)
	local axis = (math.random() > 0.5) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)

	local template = Assets:FindFirstChild(modelName)
	if not template then return end

	local newPlatform = template:Clone()
	newPlatform.Anchored = true

	local newY = GLOBAL_TOP_Y - (newPlatform.Size.Y / 2)
	local targetXZ = prevPos + (axis * distance)
	local spawnPos = Vector3.new(targetXZ.X, newY, targetXZ.Z)

	newPlatform.CFrame = CFrame.new(spawnPos)
	newPlatform:SetAttribute("PlatformType", pData.Type)
	newPlatform:SetAttribute("PlatformValue", pData.Value)

	TapModule.ApplyRoseGradient(newPlatform, pData.Color)
	newPlatform.Parent = currentTowerFolder

	table.insert(gameData.platforms, newPlatform)
	gameData.targetPlatform = newPlatform

	if #gameData.platforms > TapModule.Settings.MaxVisiblePlatforms then
		local old = table.remove(gameData.platforms, 1)
		if old then old:Destroy() end
	end

	local startY = newPlatform.Position.Y
	newPlatform.Position = newPlatform.Position - Vector3.new(0, 10, 0)
	TweenService:Create(newPlatform, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = Vector3.new(newPlatform.Position.X, startY, newPlatform.Position.Z) }):Play()

	local lookTarget = Vector3.new(spawnPos.X, gameData.dummy.Position.Y, spawnPos.Z)
	local playerTargetCFrame = CFrame.lookAt(gameData.dummy.Position, lookTarget)
	gameData.rotationTween = TweenService:Create(gameData.dummy, TweenInfo.new(0.25), {CFrame = playerTargetCFrame})
	gameData.rotationTween:Play()

	UpdateCamera()
end

-- floats a score label above a position and destroys it after 1 second
local function ShowBonusText(pos, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(4, 2); billboard.AlwaysOnTop = true
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

-- emits a brief particle burst at a world position
local function SpawnParticleBurst(pos, isPerfect)
	local att = Instance.new("Attachment"); att.Parent = workspace.Terrain; att.WorldPosition = pos
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://1266170131"
	emitter.Color = isPerfect and ColorSequence.new(Color3.new(1,1,0)) or ColorSequence.new(Color3.new(1,1,1))
	emitter.Size = NumberSequence.new(1, 0); emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(15, 25); emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Rate = 0; emitter.Parent = att
	emitter:Emit(isPerfect and 30 or 10); Debris:AddItem(att, 2)
end

-- wraps the tap module's landing check with a small tolerance margin
local function checkLandingTolerant(finalPos, platform)
	local isInside, isPerfect = TapModule.CheckLanding(finalPos, platform)
	if not isInside then
		local pSize = platform.Size; local pPos = platform.Position
		local diffX = math.abs(finalPos.X - pPos.X); local diffZ = math.abs(finalPos.Z - pPos.Z)
		if diffX < (pSize.X / 2 + 1.5) and diffZ < (pSize.Z / 2 + 1.5) then
			isInside = true; isPerfect = false
		end
	end
	return isInside, isPerfect
end

-- scores or ends the game based on where the avatar lands
local function HandleLanding(finalPos)
	local platform = gameData.targetPlatform
	local isInside, isPerfect = checkLandingTolerant(finalPos, platform)

	local trail = gameData.dummy:FindFirstChild("JumpTrail")
	if trail then trail.Enabled = false end

	if isInside then
		if isPerfect then
			playSound(perfectSound); gameData.score = gameData.score + 3
			ShowBonusText(finalPos, "PERFECT!\n+3", Color3.new(1,1,0))
			SpawnParticleBurst(finalPos, true)
		else
			playSound(jumpSound); gameData.score = gameData.score + 1
			SpawnParticleBurst(finalPos, false)
		end

		local type = platform:GetAttribute("PlatformType")
		local val = platform:GetAttribute("PlatformValue") or 0
		if type == "Bonus" then
			gameData.score = gameData.score + val; ShowBonusText(finalPos + Vector3.new(0,2,0), "+"..val.." BONUS!", TapModule.Settings.Colors.Bonus)
		elseif type == "Penalty" then
			gameData.score = math.max(0, gameData.score + val); ShowBonusText(finalPos + Vector3.new(0,2,0), val.." PENALTY", TapModule.Settings.Colors.Penalty)
		end

		if hudScoreLabel then hudScoreLabel.Text = "SCORE: " .. tostring(gameData.score) end
		if isVersusMode and UpdateLiveScore then UpdateLiveScore:FireServer(gameData.score) end

		gameData.lastLandTime = tick()
		SpawnNextPlatform()
	else
		gameData.dummy.Anchored = false
		playSound(gameOverSound)

		task.wait(1.5)
		if isVersusMode then
			if PlayerDiedEvent then PlayerDiedEvent:FireServer() end
			MenuModule.ShowBottomAlert("YOU DIED!", "Spectating other players...", Color3.fromRGB(225, 29, 72))
		else
			endGame()
		end
	end
end

-- begins the charge phase, shrinking the avatar and emitting particles
local function StartCharge()
	if not inGame or gameData.isJumping or gameData.isCharging then return end

	if gameData.rotationTween then
		gameData.rotationTween:Cancel()
		if gameData.targetPlatform then
			local lookTarget = Vector3.new(gameData.targetPlatform.Position.X, gameData.dummy.Position.Y, gameData.targetPlatform.Position.Z)
			gameData.dummy.CFrame = CFrame.lookAt(gameData.dummy.Position, lookTarget)
		end
	end

	gameData.isCharging = true
	gameData.chargeStartTime = tick()

	if gameData.startPromptText then gameData.startPromptText:Destroy(); gameData.startPromptText = nil end
	if chargeSound then chargeSound:Play() end

	local emitter = gameData.dummy:FindFirstChild("ChargeEmitter", true)
	if emitter then emitter.Enabled = true end

	if gameData.scaleTween then gameData.scaleTween:Cancel() end
	gameData.scaleVal = Instance.new("NumberValue"); gameData.scaleVal.Value = 1

	gameData.scaleConnection = gameData.scaleVal.Changed:Connect(function()
		if gameData.localChar then gameData.localChar:ScaleTo(gameData.scaleVal.Value) end
	end)

	gameData.scaleTween = TweenService:Create(gameData.scaleVal, TweenInfo.new(MAX_CHARGE_TIME, Enum.EasingStyle.Linear), {Value = 0.6})
	gameData.scaleTween:Play()
end

-- launches the avatar along a parabolic arc based on charge duration
local function ReleaseCharge()
	if not inGame or not gameData.isCharging then return end
	gameData.isCharging = false; gameData.isJumping = true

	if chargeSound then chargeSound:Stop() end
	local emitter = gameData.dummy:FindFirstChild("ChargeEmitter", true)
	if emitter then emitter.Enabled = false end

	if gameData.scaleTween then gameData.scaleTween:Cancel() end
	if gameData.scaleConnection then gameData.scaleConnection:Disconnect() end
	if gameData.scaleVal then gameData.scaleVal:Destroy() end

	if gameData.localChar then gameData.localChar:ScaleTo(1) end

	local holdTime = tick() - gameData.chargeStartTime
	holdTime = math.min(holdTime, MAX_CHARGE_TIME)

	local vForward, vUp = TapModule.CalculateJumpVelocity(holdTime)
	local gravity = TapModule.Settings.Gravity
	local startPos = gameData.dummy.Position
	local timeInAir = 0
	local forwardDir = gameData.dummy.CFrame.LookVector

	local trail = gameData.dummy:FindFirstChild("JumpTrail")
	if trail then trail.Enabled = true end

	local legOffset = getCharacterLegOffset(gameData.humanoid, gameData.dummy)
	local perfectLandingY = GLOBAL_TOP_Y + legOffset

	if gameData.humanoid then gameData.humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding) end

	gameData.jumpConnection = RunService.RenderStepped:Connect(function(dt)
		timeInAir = timeInAir + dt

		local currentXZ = forwardDir * (vForward * timeInAir)
		local currentY = (vUp * timeInAir) - (0.5 * gravity * timeInAir^2)

		local newPos = startPos + currentXZ + Vector3.new(0, currentY, 0)
		gameData.dummy.CFrame = gameData.dummy.CFrame.Rotation + newPos

		UpdateCamera()

		if currentY < 0 and newPos.Y <= perfectLandingY then
			gameData.jumpConnection:Disconnect(); gameData.jumpConnection = nil
			gameData.dummy.CFrame = gameData.dummy.CFrame.Rotation + Vector3.new(newPos.X, perfectLandingY, newPos.Z)
			gameData.isJumping = false
			if gameData.humanoid then gameData.humanoid:ChangeState(Enum.HumanoidStateType.Landed) end
			HandleLanding(gameData.dummy.Position)
		elseif newPos.Y < GAME_ORIGIN.Y - 50 then
			gameData.jumpConnection:Disconnect()
			gameData.isJumping = false
			HandleLanding(newPos)
		end
	end)
end

-- sets up the scene, clones the avatar, spawns the first platform, and starts all systems
Setup3DGame = function()
	local realCharacter = player.Character or player.CharacterAdded:Wait()
	if realCharacter and not originalPosBeforeGame then originalPosBeforeGame = realCharacter:GetPivot() end

	MenuModule.CerrarMenuCompleto()
	ControlModule:Disable()
	setNativeJumpEnabled(false)

	if currentTowerFolder then currentTowerFolder:Destroy() end
	currentTowerFolder = Instance.new("Folder")
	currentTowerFolder.Name = "Local_TapAndHold_Game"
	currentTowerFolder.Parent = workspace

	if not Assets:FindFirstChild("Model") or not Assets:FindFirstChild("tapsuelo1") then return end

	originalLighting.TimeOfDay = Lighting.TimeOfDay
	originalLighting.Brightness = Lighting.Brightness
	originalLighting.Ambient = Lighting.Ambient
	originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
	originalLighting.ColorShift_Bottom = Lighting.ColorShift_Bottom
	originalLighting.ColorShift_Top = Lighting.ColorShift_Top
	originalLighting.FogColor = Lighting.FogColor
	originalLighting.FogEnd = Lighting.FogEnd
	originalLighting.FogStart = Lighting.FogStart

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") or child:IsA("Atmosphere") then child:Destroy() end
	end
	for _, child in ipairs(workspace.Terrain:GetChildren()) do
		if child:IsA("Clouds") then child:Destroy() end
	end

	Lighting.TimeOfDay = "17:30:00"; Lighting.Brightness = 0.2; Lighting.Ambient = Color3.fromHex("FF6B2B")
	Lighting.OutdoorAmbient = Color3.fromHex("FF8C42"); Lighting.ColorShift_Bottom = Color3.fromHex("FF3300")
	Lighting.ColorShift_Top = Color3.fromHex("FFAA00"); Lighting.FogColor = Color3.fromHex("FF7043")
	Lighting.FogEnd = 1500; Lighting.FogStart = 150

	local sky = Instance.new("Sky"); sky.Name = "SunsetSky"; sky.SunAngularSize = 1; sky.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere"); atmosphere.Name = "SunsetAtmosphere"; atmosphere.Density = 0.25; atmosphere.Offset = 0.25; atmosphere.Color = Color3.fromHex("FF8C42"); atmosphere.Decay = Color3.fromHex("FF5522"); atmosphere.Glare = 2.0; atmosphere.Haze = 3.0; atmosphere.Parent = Lighting
	local clouds = Instance.new("Clouds"); clouds.Name = "SunsetClouds"; clouds.Cover = 0.6; clouds.Density = 0.4; clouds.Color = Color3.fromHex("FFDAB3"); clouds.Parent = workspace.Terrain

	local room = Assets.Model:Clone()
	room.Name = "FloorModel"
	room:PivotTo(CFrame.new(GAME_ORIGIN - Vector3.new(0, WATER_OFFSET_Y, 0)))
	room.Parent = currentTowerFolder

	local base = Assets.tapsuelo1:Clone()
	base.Anchored = true
	base.Position = GAME_ORIGIN + Vector3.new(0, 1, 0)
	GLOBAL_TOP_Y = base.Position.Y + (base.Size.Y / 2)
	TapModule.ApplyRoseGradient(base, TapModule.Settings.Colors.Normal)
	base.Parent = currentTowerFolder

	local realHrp = realCharacter:FindFirstChild("HumanoidRootPart")
	if realHrp then realHrp.Anchored = true end

	realCharacter.Archivable = true
	local localChar = realCharacter:Clone()
	localChar.Name = "LocalTapAvatar"

	for _, child in ipairs(localChar:GetDescendants()) do
		if child:IsA("BaseScript") then child:Destroy() end
	end
	localChar.Parent = currentTowerFolder
	gameData.localChar = localChar

	local hrp = localChar:FindFirstChild("HumanoidRootPart")
	local humanoid = localChar:FindFirstChildOfClass("Humanoid")

	if hrp and humanoid then
		hrp.Anchored = true
		hrp.Velocity = Vector3.new(0,0,0)

		local legOffset = getCharacterLegOffset(humanoid, hrp)
		local spawnPos = Vector3.new(base.Position.X, GLOBAL_TOP_Y + legOffset, base.Position.Z)
		local lookForward = spawnPos + Vector3.new(0, 0, 1)
		localChar:PivotTo(CFrame.lookAt(spawnPos, lookForward))

		gameData.dummy = hrp
		gameData.humanoid = humanoid
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		if not hrp:FindFirstChild("JumpTrail") then
			local a0 = Instance.new("Attachment", hrp); a0.Name = "TrailAtt0"; a0.Position = Vector3.new(0, hrp.Size.Y/2, 0)
			local a1 = Instance.new("Attachment", hrp); a1.Name = "TrailAtt1"; a1.Position = Vector3.new(0, -hrp.Size.Y/2, 0)
			local trail = Instance.new("Trail", hrp); trail.Name = "JumpTrail"; trail.Attachment0 = a0; trail.Attachment1 = a1; trail.Color = ColorSequence.new(MenuModule.Config.Colors.BtnPlay); trail.Lifetime = 0.5; trail.Enabled = false
		end

		if not hrp:FindFirstChild("ChargeEmitter", true) then
			local chargeAtt = Instance.new("Attachment", hrp); chargeAtt.Name = "ChargeAtt"
			local chargeEmitter = Instance.new("ParticleEmitter", chargeAtt); chargeEmitter.Name = "ChargeEmitter"; chargeEmitter.Texture = "rbxassetid://2842055173"; chargeEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1)); chargeEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0)}); chargeEmitter.Lifetime = NumberRange.new(0.3, 0.5); chargeEmitter.Rate = 60; chargeEmitter.Speed = NumberRange.new(-15, -10); chargeEmitter.Shape = Enum.ParticleEmitterShape.Sphere; chargeEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume; chargeEmitter.Enabled = false
		end

		if gameData.startPromptText then gameData.startPromptText:Destroy() end
		local promptGui = Instance.new("BillboardGui"); promptGui.Name = "StartPrompt"; promptGui.Adornee = hrp; promptGui.Size = UDim2.fromScale(10, 2); promptGui.ExtentsOffset = Vector3.new(0, 4, 0); promptGui.AlwaysOnTop = true
		local promptLbl = Instance.new("TextLabel", promptGui); promptLbl.Size = UDim2.fromScale(1, 1); promptLbl.BackgroundTransparency = 1; promptLbl.Text = "PRESS TO START"; promptLbl.Font = Enum.Font.GothamBlack; promptLbl.TextColor3 = Color3.new(1, 1, 1); promptLbl.TextScaled = true
		Instance.new("UIStroke", promptLbl).Thickness = 2
		promptGui.Parent = playerGui; gameData.startPromptText = promptGui
	end

	table.clear(gameData.platforms)
	gameData.score = 0; gameData.targetPlatform = nil; gameData.isCharging = false; gameData.isJumping = false; gameData.startTime = os.clock(); gameData.lastLandTime = tick()
	table.insert(gameData.platforms, base)

	hudScoreLabel = MenuModule.ShowInGameHUD(not soundEnabled, MenuModule.Callbacks.OnToggleAudio, function()
		if isVersusMode and LeaveRoomEvent then LeaveRoomEvent:FireServer() end
		FullQuitGame()
	end)

	UniversalController.CrearControlesTapAndHold(function(state)
		if state == Enum.UserInputState.Begin then StartCharge()
		elseif state == Enum.UserInputState.End then ReleaseCharge() end
	end)

	local Camera = workspace.CurrentCamera
	cameraOriginalCFrame = Camera.CFrame
	Camera.CameraType = Enum.CameraType.Scriptable
	UpdateCamera()

	if gameData.afkConnection then gameData.afkConnection:Disconnect() end
	gameData.afkConnection = RunService.Heartbeat:Connect(function()
		-- AFK death is a VERSUS rule only. isVersusMode used to be checked further
		-- down, where it only picked how to end the run - so a solo player who
		-- stood still still fell through to endGame() and died.
		if inGame and isVersusMode and not gameData.isJumping and not gameData.isCharging then
			if tick() - gameData.lastLandTime >= AFK_TIMEOUT then
				if gameData.afkConnection then gameData.afkConnection:Disconnect() gameData.afkConnection = nil end
				if gameData.dummy then gameData.dummy.Anchored = false end
				playSound(gameOverSound)
				task.wait(1.5)
				if isVersusMode then
					if PlayerDiedEvent then PlayerDiedEvent:FireServer() end
					MenuModule.ShowBottomAlert("YOU DIED!", "Waiting for winner...", Color3.fromRGB(225, 29, 72))
				else
					endGame()
				end
			end
		end
	end)

	task.delay(1.0, function() if inGame then SpawnNextPlatform() end end)
end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gn)
		if gn == "TapAndHold" and not inGame then
			InyectarConfiguracionTap()
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
			Cleanup3DGame(); inGame = false; isVersusMode = false
			MenuModule.ShowGameOver(data.Score or 0, win, ReturnToMainMenu, FullQuitGame)

			local titleColor = win and Color3.fromHex("fbbf24") or Color3.fromHex("881337")
			local textTitle = win and "VICTORY!" or "GAME OVER"
			MenuModule.ShowInfoOverlay(textTitle, "Winner: " .. (data.Winner or "") .. "\nScore: " .. tostring(data.Score or 0), titleColor)
		elseif type == "EliminatedEarly" then
			Cleanup3DGame(); inGame = false; isVersusMode = false
			MenuModule.ShowGameOver(data.Score or 0, false, ReturnToMainMenu, FullQuitGame)
		elseif type == "SuddenDeathWait" then
			MenuModule.ShowBottomAlert("MATCH ENDING...", "The game will close in 5 seconds!", Color3.fromRGB(255, 100, 100))
		elseif type == "SuddenDeath" then
			playSound(perfectSound)
			MenuModule.ShowBottomAlert("SUDDEN DEATH!", "THE GAME ENDS IN 5 SECONDS!", Color3.fromRGB(255, 50, 50))
		elseif type == "Kicked" or type == "RoomClosed" then
			MenuModule.DestroyAllMenus(); MenuModule.ShowMainMenu()
			local titleText = (type == "Kicked") and "KICKED" or "CLOSED"
			local msgText = (type == "Kicked") and "You were removed." or "Room closed."
			MenuModule.ShowInfoOverlay(titleText, msgText, Color3.fromRGB(225, 29, 72))
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not inGame then return end
	if UniversalController.EsBotonAtras(input) then
		if isVersusMode and LeaveRoomEvent then LeaveRoomEvent:FireServer() end
		FullQuitGame(); return
	end
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		if not processed then StartCharge() end
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if not inGame then return end
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		if not processed then ReleaseCharge() end
	end
end)
