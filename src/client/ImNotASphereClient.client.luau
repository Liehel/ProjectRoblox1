local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local ControlModule = PlayerModule:GetControls()

local MenuModule = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu8to10"))
local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))

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
local coinSound = createSound("rbxassetid://87437544236708", 0.5)
local powerupSound = createSound("rbxassetid://500472891", 0.6)

local soundEnabled = true
local function playSound(s)
	if not soundEnabled then return end
	if s then s:Play() end
end

local ArcadeRemotes = ReplicatedStorage:WaitForChild("ArcadeRemotes", 10)
local SphereFolder = ArcadeRemotes and ArcadeRemotes:WaitForChild("ImNotASphere", 10)
local LobbySystem = SphereFolder and SphereFolder:FindFirstChild("LobbySystem")

local StartRequest = SphereFolder and SphereFolder:WaitForChild("StartImNotASphereRequest", 5)
local MatchStatus = SphereFolder and SphereFolder:WaitForChild("MatchStatus", 5)
local OpenArcadeMenu = ArcadeRemotes and ArcadeRemotes:WaitForChild("OpenArcadeMenu", 10)
local ToggleAudio = SphereFolder and SphereFolder:FindFirstChild("ToggleAudio")
local GetAudioState = SphereFolder and SphereFolder:FindFirstChild("GetAudioState")

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

local Assets = ReplicatedStorage:WaitForChild("ImNotASphere_Assets")
local SphereModule = require(ReplicatedStorage.Modules:WaitForChild("ImNotASphereModule"))

task.spawn(function()
	if GetAudioState then soundEnabled = not GetAudioState:InvokeServer() end
end)

local inGame = false
local isVersusMode = false
local localPlayerFinished = false
local currentLevelFolder = nil
local currentLevelNum = 1

-- ============================================================================
-- Progresion de niveles: nivel inicial y a cual se pasa al tocar la meta.
local START_LEVEL = 1

local function NEXT_LEVEL(actual)
	return actual + 1
end


local gameData = {
	score = 0, coinsCollected = {}, activePowers = {}, powerupCoroutines = {}, storedPower = nil,
	startTime = 0, spherePart = nil, camProxy = nil, vectorForce = nil, angularVelocity = nil,
	attachment = nil, physicsConnection = nil, jumpDebounce = false, spawnCFrame = CFrame.new(),
	originalPlayerCFrame = nil, ucMoveVec = Vector2.zero, jumpRequested = false, usePowerRequested = false,
}

-- snapshot of original lighting so it can be restored on exit
local originalLighting = {
	TimeOfDay = Lighting.TimeOfDay, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient, ColorShift_Bottom = Lighting.ColorShift_Bottom,
	ColorShift_Top = Lighting.ColorShift_Top, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}

local POWER_DISPLAY_NAMES = { fast = "FAST", Spring = "MEGA JUMP", big = "MEGA BIG", ALAS = "ANTIGRAVITY" }

local hudGui = nil
local hudScoreLabel, hudCoinsLabel, hudActivePowerLabel, hudMuteBtn
local versusGui = nil

local Setup3DGame, LoadLevel, FullQuitGame, DieAndRespawn, RebuildSphere

-- floats a styled text label above a part and fades it out
local function ShowFloatingText(text, color, targetPart)
	if not targetPart then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(5, 2)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack

	local stroke = Instance.new("UIStroke", label)
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)

	billboard.Adornee = targetPart; billboard.Parent = workspace

	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, tweenInfo, {StudsOffset = Vector3.new(0, 8, 0)}):Play()
	TweenService:Create(label, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(stroke, tweenInfo, {Transparency = 1}):Play()

	Debris:AddItem(billboard, 1.5)
end

-- floats a red warning above a part over 3 seconds
local function ShowWarningText(text, targetPart)
	if not targetPart then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(6, 2); billboard.AlwaysOnTop = true; billboard.StudsOffset = Vector3.new(0, 4, 0)
	local lbl = Instance.new("TextLabel", billboard)
	lbl.Size = UDim2.fromScale(1,1); lbl.BackgroundTransparency = 1; lbl.Text = text
	lbl.TextColor3 = Color3.new(1, 0, 0); lbl.Font = Enum.Font.GothamBlack; lbl.TextScaled = true
	local stroke = Instance.new("UIStroke", lbl)
	stroke.Thickness = 2

	billboard.Adornee = targetPart; billboard.Parent = playerGui

	local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, tweenInfo, {StudsOffset = Vector3.new(0, 8, 0)}):Play()
	TweenService:Create(lbl, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(stroke, tweenInfo, {Transparency = 1}):Play()

	Debris:AddItem(billboard, 3)
end

-- creates a full-screen loading overlay inside a screen gui
local function showLoadingOverlay(parentGui, text)
	local fullBg = Instance.new("Frame", parentGui)
	fullBg.Size = UDim2.fromScale(1, 1); fullBg.BackgroundColor3 = Color3.fromHex("111111"); fullBg.ZIndex = 998
	local overlay = Instance.new("Frame", parentGui)
	overlay.Size = UDim2.new(0.6, 0, 0.4, 0); overlay.Position = UDim2.new(0.5,0,0.5,0); overlay.AnchorPoint = Vector2.new(0.5,0.5)
	overlay.BackgroundColor3 = Color3.fromRGB(30, 41, 59); overlay.ZIndex = 999
	Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 14)
	Instance.new("UIAspectRatioConstraint", overlay).AspectRatio = 420 / 200

	local lbl = Instance.new("TextLabel", overlay)
	lbl.Size = UDim2.new(1,-40,0.7,0); lbl.Position = UDim2.new(0,20,0.1,0); lbl.BackgroundTransparency = 1
	lbl.Text = text or "LOADING..."; lbl.Font = Enum.Font.GothamBlack; lbl.TextScaled = true; lbl.TextColor3 = Color3.fromRGB(16, 185, 129); lbl.ZIndex = 1000
	return overlay
end

-- preloads all visible assets in a level folder before play
local function PreloadLevelAssets(levelFolder)
	local assetsToLoad = {}
	for _, obj in ipairs(levelFolder:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Decal") or obj:IsA("Texture") then table.insert(assetsToLoad, obj) end
	end
	if #assetsToLoad > 0 then pcall(function() ContentProvider:PreloadAsync(assetsToLoad) end) end
end

-- injects sphere-specific colors, sounds, and callbacks into the shared menu module
local function InyectarConfiguracionSphere()
	MenuModule.Config.Title = "I'M NOT SPHERA"
	MenuModule.Config.SupportTitle = "SPHERA SUPPORT"
	MenuModule.Config.MainIcon = "jump"
	MenuModule.Config.Emotes = { controller = "🎮", crown = "👑", door = "🚪", jump = "🎱", solo = "👤", duo = "👥", back = "⬅️" }

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
		{ Id = 3588134038, Price = 5, Name = "Sphera Tip" }, { Id = 3588134140, Price = 15, Name = "Sphera Treat" },
		{ Id = 3588134227, Price = 50, Name = "Sphera Sub" }, { Id = 3588134292, Price = 100, Name = "Sphera Sponsor" },
		{ Id = 3588134381, Price = 500, Name = "Sphera Whale" }, { Id = 3588134443, Price = 1000, Name = "Sphera Legend" }
	}
	MenuModule.Config.Sounds = { Hover = hoverSound, Select = selectSound, GameOver = gameOverSound, Perfect = perfectSound }

	MenuModule.Callbacks.OnPlaySolo = function()
		inGame = true; isVersusMode = false
		MenuModule.CerrarMenuCompleto()
		if StartRequest then pcall(function() StartRequest:FireServer("Solo") end) end

		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			gameData.originalPlayerCFrame = char.HumanoidRootPart.CFrame
		end

		local loadGui = Instance.new("ScreenGui", playerGui)
		showLoadingOverlay(loadGui, "LOADING MAP & LIGHTS...")
		currentLevelNum = START_LEVEL   -- <-- nivel inicial (ver bloque de arriba)
		local success = LoadLevel(currentLevelNum)
		if success and currentLevelFolder then PreloadLevelAssets(currentLevelFolder); task.wait(2.0) end
		loadGui:Destroy()

		Setup3DGame(true)
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

-- refreshes score, coin count, and active power labels
local function updateHUD()
	if not inGame then return end
	if hudScoreLabel then hudScoreLabel.Text = "SCORE: " .. tostring(gameData.score) end
	if hudCoinsLabel then
		local maxCoins = SphereModule.GameConfig and #SphereModule.GameConfig.RequiredCoins or 0
		hudCoinsLabel.Text = "COINS: " .. tostring(#gameData.coinsCollected) .. "/" .. tostring(maxCoins)
	end
	if hudActivePowerLabel then
		local activeNames = {}
		for pName, _ in pairs(gameData.activePowers) do table.insert(activeNames, POWER_DISPLAY_NAMES[pName] or string.upper(pName)) end
		local activeText = (#activeNames > 0) and ("ACTIVE: " .. table.concat(activeNames, ", ")) or ""
		local storedText = ""
		if gameData.storedPower then
			local displayName = POWER_DISPLAY_NAMES[gameData.storedPower] or string.upper(gameData.storedPower)
			local actionKey = (gameData.storedPower == "Spring") and "[SPACE]" or "[CLICK]"
			storedText = "POWER: " .. displayName .. " " .. actionKey
		end

		if activeText ~= "" and storedText ~= "" then
			hudActivePowerLabel.Text = storedText .. " | " .. activeText
			hudActivePowerLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
		elseif activeText ~= "" then
			hudActivePowerLabel.Text = activeText
			hudActivePowerLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
		elseif storedText ~= "" then
			hudActivePowerLabel.Text = storedText
			hudActivePowerLabel.TextColor3 = Color3.fromRGB(255, 255, 80)
		else
			hudActivePowerLabel.Text = "POWER: NONE"
			hudActivePowerLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	end
end

-- builds the score/coins/power label bar and exit/respawn buttons
local function createCustomHUD()
	if playerGui:FindFirstChild("ImNotASphereHUD") then playerGui.ImNotASphereHUD:Destroy() end
	local screenGui = Instance.new("ScreenGui", playerGui); screenGui.Name = "ImNotASphereHUD"

	local scoreFrame = Instance.new("Frame", screenGui)
	scoreFrame.Size = UDim2.new(0.4, 0, 0.08, 0); scoreFrame.Position = UDim2.new(0.02, 0, 0.02, 0); scoreFrame.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout", scoreFrame)
	list.FillDirection = Enum.FillDirection.Horizontal; list.Padding = UDim.new(0, 15); list.VerticalAlignment = Enum.VerticalAlignment.Center

	hudScoreLabel = Instance.new("TextLabel", scoreFrame)
	hudScoreLabel.Size = UDim2.new(0.3, 0, 0.8, 0); hudScoreLabel.BackgroundTransparency = 1; hudScoreLabel.Text = "SCORE: 0"; hudScoreLabel.Font = Enum.Font.GothamBlack; hudScoreLabel.TextColor3 = Color3.new(1,1,1); hudScoreLabel.TextScaled = true; hudScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	Instance.new("UIStroke", hudScoreLabel).Thickness = 2

	hudCoinsLabel = Instance.new("TextLabel", scoreFrame)
	hudCoinsLabel.Size = UDim2.new(0.3, 0, 0.8, 0); hudCoinsLabel.BackgroundTransparency = 1; hudCoinsLabel.Text = "COINS: 0/4"; hudCoinsLabel.Font = Enum.Font.GothamBlack; hudCoinsLabel.TextColor3 = Color3.new(1,1,1); hudCoinsLabel.TextScaled = true; hudCoinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	Instance.new("UIStroke", hudCoinsLabel).Thickness = 2

	hudActivePowerLabel = Instance.new("TextLabel", scoreFrame)
	hudActivePowerLabel.Size = UDim2.new(0.4, 0, 0.8, 0); hudActivePowerLabel.BackgroundTransparency = 1; hudActivePowerLabel.Text = "POWER: NONE"; hudActivePowerLabel.Font = Enum.Font.GothamBlack; hudActivePowerLabel.TextColor3 = Color3.new(1,1,1); hudActivePowerLabel.TextScaled = true; hudActivePowerLabel.TextXAlignment = Enum.TextXAlignment.Left
	Instance.new("UIStroke", hudActivePowerLabel).Thickness = 2

	local btnContainer = Instance.new("Frame", screenGui)
	btnContainer.Size = UDim2.new(0.3, 0, 0.08, 0); btnContainer.Position = UDim2.new(0.68, 0, 0.02, 0); btnContainer.BackgroundTransparency = 1
	local list2 = Instance.new("UIListLayout", btnContainer); list2.FillDirection = Enum.FillDirection.Horizontal; list2.Padding = UDim.new(0, 10); list2.HorizontalAlignment = Enum.HorizontalAlignment.Right; list2.VerticalAlignment = Enum.VerticalAlignment.Center

	local respawnBtn = Instance.new("TextButton", btnContainer)
	respawnBtn.Size = UDim2.new(0.35, 0, 0.8, 0); respawnBtn.BackgroundColor3 = Color3.fromHex("f59e0b"); respawnBtn.Text = "RESPAWN"; respawnBtn.TextScaled = true; respawnBtn.Font = Enum.Font.GothamBold; respawnBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", respawnBtn).CornerRadius = UDim.new(0,8)
	respawnBtn.MouseButton1Click:Connect(function() if inGame then DieAndRespawn() end end)

	local exitBtn = Instance.new("TextButton", btnContainer)
	exitBtn.Size = UDim2.new(0.25, 0, 0.8, 0); exitBtn.BackgroundColor3 = MenuModule.Config.Colors.HUDExit; exitBtn.Text = "EXIT"; exitBtn.TextScaled = true; exitBtn.Font = Enum.Font.GothamBold; exitBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0,8)
	exitBtn.MouseButton1Click:Connect(function()
		if isVersusMode and LeaveRoomEvent then pcall(function() LeaveRoomEvent:FireServer() end) end
		FullQuitGame()
	end)
	hudGui = screenGui
end

-- creates a vertical bar showing each player's score position
local function createVersusHUD()
	if playerGui:FindFirstChild("VersusHUD") then playerGui.VersusHUD:Destroy() end
	local gui = Instance.new("ScreenGui", playerGui); gui.Name = "VersusHUD"
	local barBg = Instance.new("Frame", gui); barBg.Size = UDim2.new(0.03, 0, 0.6, 0); barBg.Position = UDim2.new(0.95, 0, 0.2, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50); barBg.BorderSizePixel = 0; Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame", barBg); fill.Name = "Fill"; fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundTransparency = 1
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
		local icon = Instance.new("ImageLabel", fill); icon.Size = UDim2.new(1.5, 0, 1.5, 0); Instance.new("UIAspectRatioConstraint", icon).AspectRatio = 1
		icon.Position = UDim2.new(0.5, 0, 1 - percent, 0); icon.AnchorPoint = Vector2.new(0.5, 0.5); icon.BackgroundTransparency = 1; icon.ZIndex = 5
		icon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(pData.Id) .. "&w=150&h=150"; Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

		if not pData.Alive then
			icon.ImageColor3 = Color3.new(0.2, 0.2, 0.2)
			local x = Instance.new("TextLabel", icon); x.Size = UDim2.fromScale(1,1); x.BackgroundTransparency = 1; x.Text = "❌"; x.TextScaled = true; x.ZIndex = 6
		end
		if pData.Name == player.Name then
			local s = Instance.new("UIStroke", icon); s.Thickness=2; s.Color=Color3.new(1,1,0)
		end
	end
end

-- disconnects physics, destroys the level and sphere, restores camera and lighting
local function Cleanup3DGame()
	UniversalController.LimpiarControles()
	if gameData.physicsConnection then gameData.physicsConnection:Disconnect() end
	RunService:UnbindFromRenderStep("SphereCamTracking")

	for _, coro in pairs(gameData.powerupCoroutines) do task.cancel(coro) end
	table.clear(gameData.powerupCoroutines)

	if currentLevelFolder then currentLevelFolder:Destroy() end
	if gameData.spherePart then gameData.spherePart:Destroy() end
	if gameData.camProxy then gameData.camProxy:Destroy() end
	if hudGui then hudGui:Destroy(); hudGui = nil end
	if versusGui then versusGui:Destroy(); versusGui = nil end

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	cam.CameraSubject = player.Character and player.Character:FindFirstChild("Humanoid")

	if player.Character then
		for _, part in ipairs(player.Character:GetDescendants()) do
			if (part:IsA("BasePart") or part:IsA("Decal")) and part.Name ~= "HumanoidRootPart" then part.Transparency = 0 end
		end
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
			if gameData.originalPlayerCFrame then hrp.CFrame = gameData.originalPlayerCFrame; gameData.originalPlayerCFrame = nil end
		end
	end

	Lighting.TimeOfDay = originalLighting.TimeOfDay
	Lighting.Brightness = originalLighting.Brightness
	Lighting.Ambient = originalLighting.Ambient
	Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
	Lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom
	Lighting.ColorShift_Top = originalLighting.ColorShift_Top
	Lighting.FogColor = originalLighting.FogColor

	local customAtmo = Lighting:FindFirstChild("SunsetAtmosphere")
	if customAtmo then customAtmo:Destroy() end
	local customSky = Lighting:FindFirstChild("SunsetSky")
	if customSky then customSky:Destroy() end
	local customClouds = workspace.Terrain:FindFirstChild("SunsetClouds")
	if customClouds then customClouds:Destroy() end
end

function FullQuitGame()
	inGame = false; isVersusMode = false; localPlayerFinished = false
	MenuModule.CerrarMenuCompleto()
	Cleanup3DGame()
	ControlModule:Enable()
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

-- cancels all powers and resets the sphere to the spawn point
DieAndRespawn = function()
	if not inGame then return end
	playSound(gameOverSound)

	for _, coro in pairs(gameData.powerupCoroutines) do task.cancel(coro) end
	table.clear(gameData.powerupCoroutines)
	table.clear(gameData.activePowers)
	gameData.storedPower = nil
	updateHUD()

	if gameData.spherePart then
		gameData.spherePart.Size = SphereModule.GameConfig.PlayerDefaultSize
		gameData.spherePart.AssemblyLinearVelocity = Vector3.zero
		gameData.spherePart.AssemblyAngularVelocity = Vector3.zero
		gameData.spherePart.CFrame = gameData.spawnCFrame

		local stripe = gameData.spherePart:FindFirstChild("StripeVisual")
		if stripe then stripe.Size = Vector3.new(0.6, SphereModule.GameConfig.PlayerDefaultSize.Y + 0.2, SphereModule.GameConfig.PlayerDefaultSize.Z + 0.2) end
	end
end

-- activates a powerup for its duration, then removes it and resets size if needed
local function ApplyPowerUp(powerName)
	if not inGame then return end
	if not gameData.activePowers[powerName] then
		playSound(powerupSound)
		gameData.activePowers[powerName] = true

		if powerName == "big" and gameData.spherePart then
			local mult = SphereModule.PowerUps.big.SizeMult
			TweenService:Create(gameData.spherePart, TweenInfo.new(0.5), {Size = SphereModule.GameConfig.PlayerDefaultSize * mult}):Play()
			local stripe = gameData.spherePart:FindFirstChild("StripeVisual")
			if stripe then TweenService:Create(stripe, TweenInfo.new(0.5), {Size = Vector3.new(0.6, (SphereModule.GameConfig.PlayerDefaultSize.Y * mult) + 0.2, (SphereModule.GameConfig.PlayerDefaultSize.Z * mult) + 0.2)}):Play() end
		end
	end
	updateHUD()

	local duration = SphereModule.PowerUps[powerName].Duration
	if gameData.powerupCoroutines[powerName] then task.cancel(gameData.powerupCoroutines[powerName]) end

	gameData.powerupCoroutines[powerName] = task.spawn(function()
		task.wait(duration)
		if inGame and gameData.activePowers[powerName] then
			gameData.activePowers[powerName] = nil
			updateHUD()
			if powerName == "big" and gameData.spherePart then
				TweenService:Create(gameData.spherePart, TweenInfo.new(0.5), {Size = SphereModule.GameConfig.PlayerDefaultSize}):Play()
				local stripe = gameData.spherePart:FindFirstChild("StripeVisual")
				if stripe then TweenService:Create(stripe, TweenInfo.new(0.5), {Size = Vector3.new(0.6, SphereModule.GameConfig.PlayerDefaultSize.Y + 0.2, SphereModule.GameConfig.PlayerDefaultSize.Z + 0.2)}):Play() end
			end
		end
	end)
end

-- handles coin, powerup, death, and finish-line collisions
local function HandleSphereCollision(hit)
	if not inGame then return end
	local itemName = hit.Name
	local targetObj = hit

	if hit.Parent and hit.Parent:IsA("Model") and currentLevelFolder and hit.Parent.Name ~= currentLevelFolder.Name then
		local pName = hit.Parent.Name
		if table.find(SphereModule.GameConfig.RequiredCoins, pName) or pName == "Bitcoinsuper" or SphereModule.PowerUps[pName] then
			itemName = pName
			targetObj = hit.Parent
		end
	end

	if table.find(SphereModule.GameConfig.RequiredCoins, itemName) then
		if not table.find(gameData.coinsCollected, itemName) then
			table.insert(gameData.coinsCollected, itemName)
			local pts = SphereModule.GameConfig.Points.Bitcoin
			gameData.score = gameData.score + pts
			targetObj:Destroy()
			playSound(coinSound)
			ShowFloatingText("+" .. tostring(pts), Color3.fromRGB(255, 200, 0), gameData.spherePart)
			updateHUD()
			if isVersusMode and UpdateLiveScore then UpdateLiveScore:FireServer(gameData.score) end
		end
	elseif itemName == "Bitcoinsuper" then
		local pts = SphereModule.GameConfig.Points.Bitcoinsuper
		gameData.score = gameData.score + pts
		targetObj:Destroy()
		playSound(coinSound)
		ShowFloatingText("+" .. tostring(pts), Color3.fromRGB(255, 100, 0), gameData.spherePart)
		updateHUD()
		if isVersusMode and UpdateLiveScore then UpdateLiveScore:FireServer(gameData.score) end
	elseif itemName == "DeathPit" or hit.Name == "DeathPit" then
		DieAndRespawn()
	elseif hit.Name == "FinishLine0Finishline" or hit.Name == "FinishLine" then
		if #gameData.coinsCollected >= #SphereModule.GameConfig.RequiredCoins then
			currentLevelNum = NEXT_LEVEL(currentLevelNum)   -- <-- siguiente nivel (ver bloque de arriba)
			local nextLevel = Assets:FindFirstChild("Level" .. currentLevelNum)
			if nextLevel then
				local prevInGame = inGame
				inGame = false
				local loadGui = Instance.new("ScreenGui", playerGui)
				showLoadingOverlay(loadGui, "LOADING LEVEL " .. currentLevelNum .. "...")
				local success = LoadLevel(currentLevelNum)
				if gameData.spherePart then gameData.spherePart.Anchored = true end
				if success and currentLevelFolder then PreloadLevelAssets(currentLevelFolder); task.wait(2.5) end
				if loadGui then loadGui:Destroy() end
				-- Reconstruye la esfera: reutilizarla dejaba su fisica dormida.
				RebuildSphere()
				inGame = prevInGame

				-- Si no acabo en el spawn, la reponemos ahi a la fuerza.
				if gameData.spherePart and gameData.spawnCFrame then
					local d = (gameData.spherePart.Position - gameData.spawnCFrame.Position).Magnitude
					if d > 50 then
						warn("[ImNotASphere] la esfera quedo a " .. math.floor(d) .. " studs del spawn; reposicionando")
						gameData.spherePart.CFrame = gameData.spawnCFrame
						gameData.spherePart.AssemblyLinearVelocity = Vector3.zero
						gameData.spherePart.AssemblyAngularVelocity = Vector3.zero
					end
				end
			else
				if not isVersusMode then
					endGame()
				else
					localPlayerFinished = true
					ShowFloatingText("FINISHED! WAITING...", Color3.new(0, 255, 0), gameData.spherePart)
					if gameData.spherePart then
						gameData.spherePart.Anchored = true
						gameData.spherePart.AssemblyLinearVelocity = Vector3.zero
						gameData.spherePart.AssemblyAngularVelocity = Vector3.zero
					end
					if MatchStatus then MatchStatus:FireServer("GameOver", gameData.score, os.clock() - gameData.startTime) end
				end
			end
		else
			local faltan = #SphereModule.GameConfig.RequiredCoins - #gameData.coinsCollected
			ShowWarningText("MISSING " .. faltan .. " COINS!", gameData.spherePart)
		end
	elseif SphereModule.PowerUps and SphereModule.PowerUps[itemName] then
		if targetObj.Parent ~= nil then
			local originalParent = targetObj.Parent
			targetObj.Parent = nil
			playSound(powerupSound)

			if itemName == "big" or itemName == "ALAS" then ApplyPowerUp(itemName)
			elseif itemName == "fast" or itemName == "Spring" then gameData.storedPower = itemName; updateHUD() end

			local displayName = POWER_DISPLAY_NAMES[itemName] or string.upper(itemName)
			ShowFloatingText(displayName, Color3.fromRGB(0, 255, 255), gameData.spherePart)
			task.delay(SphereModule.GameConfig.PowerUpRespawnTime, function() if inGame and targetObj then targetObj.Parent = originalParent end end)
		end
	end
end

-- clones a level template, decorates collectibles with neon and lights, wires moving platforms
LoadLevel = function(levelNum)
	if currentLevelFolder then currentLevelFolder:Destroy() end
	local levelTemplate = Assets:FindFirstChild("Level" .. levelNum)
	if not levelTemplate then return false end

	currentLevelFolder = levelTemplate:Clone()

	for _, obj in ipairs(currentLevelFolder:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("MeshPart") then
			local itemName = obj.Name
			if obj.Parent and obj.Parent:IsA("Model") and obj.Parent.Name ~= currentLevelFolder.Name then
				local pName = obj.Parent.Name
				if table.find(SphereModule.GameConfig.RequiredCoins, pName) or pName == "Bitcoinsuper" or SphereModule.PowerUps[pName] then itemName = pName end
			end

			if table.find(SphereModule.GameConfig.RequiredCoins, itemName) or itemName == "Bitcoinsuper" then
				obj.Material = Enum.Material.Neon; obj.Color = Color3.fromHex("FF8800"); obj.CanCollide = false
				if not obj:FindFirstChildOfClass("PointLight") then
					local light = Instance.new("PointLight", obj); light.Color = Color3.fromHex("FF6600"); light.Brightness = 4; light.Range = 15
				end
			elseif SphereModule.PowerUps[itemName] then
				obj.Material = Enum.Material.Neon; obj.CanCollide = false
				if not obj:FindFirstChildOfClass("PointLight") then
					local light = Instance.new("PointLight", obj); light.Brightness = 3.0; light.Range = 15
					if itemName == "ALAS" then obj.Color = Color3.fromHex("#7F77DD"); light.Color = Color3.fromHex("#9E95FF")
					elseif itemName == "Spring" then obj.Color = Color3.fromHex("#1D9E75"); light.Color = Color3.fromHex("#55FF55")
					elseif itemName == "big" then obj.Color = Color3.fromHex("#D85A30"); light.Color = Color3.fromHex("#FF6F47")
					elseif itemName == "fast" then obj.Color = Color3.fromHex("#BA7517"); light.Color = Color3.fromHex("#FFD700") end
				end
			end
			if obj.Name == "FinishLine" or obj.Name == "FinishLine0Finishline" then
				obj.Material = Enum.Material.Neon; obj.Color = Color3.fromRGB(0, 150, 255)
				if not obj:FindFirstChildOfClass("PointLight") then
					local light = Instance.new("PointLight", obj); light.Color = Color3.fromRGB(0, 150, 255); light.Brightness = 2.5; light.Range = 18
				end
			end
		end
	end

	currentLevelFolder:PivotTo(currentLevelFolder:GetPivot() + Vector3.new(0, 800, 0))
	currentLevelFolder.Parent = workspace

	table.clear(gameData.coinsCollected)
	for _, coro in pairs(gameData.powerupCoroutines) do task.cancel(coro) end
	table.clear(gameData.powerupCoroutines)
	table.clear(gameData.activePowers)
	gameData.storedPower = nil
	updateHUD()

	if gameData.spherePart and SphereModule.GameConfig then
		gameData.spherePart.Size = SphereModule.GameConfig.PlayerDefaultSize
		local stripe = gameData.spherePart:FindFirstChild("StripeVisual")
		if stripe then stripe.Size = Vector3.new(0.6, SphereModule.GameConfig.PlayerDefaultSize.Y + 0.2, SphereModule.GameConfig.PlayerDefaultSize.Z + 0.2) end
	end

	local spawnPt = nil
	for _, obj in ipairs(currentLevelFolder:GetDescendants()) do
		if obj.Name == "SpawnPoint" and obj:IsA("BasePart") then
			spawnPt = obj
			break
		end
	end

	if not spawnPt then
		local sp = currentLevelFolder:FindFirstChild("SpawnPoint")
		if sp and sp:IsA("BasePart") then spawnPt = sp end
	end

	if spawnPt then
		gameData.spawnCFrame = CFrame.new(spawnPt.Position + Vector3.new(0, 5, 0))
		spawnPt.Transparency = 1; spawnPt.CanCollide = false
	else
		gameData.spawnCFrame = CFrame.new(currentLevelFolder:GetPivot().Position + Vector3.new(0, 20, 0))
	end

	if gameData.spherePart then
		gameData.spherePart.CFrame = gameData.spawnCFrame
		gameData.spherePart.AssemblyLinearVelocity = Vector3.zero
		gameData.spherePart.AssemblyAngularVelocity = Vector3.zero
	end

	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- Aparca el personaje lejos: encajado en la esfera la dejaba sin simular.
	if hrp then hrp.CFrame = gameData.spawnCFrame * CFrame.new(0, -60, 0) end

	local movingFolder = currentLevelFolder:FindFirstChild("MovingPlatforms")
	if movingFolder then
		for _, elevator in ipairs(movingFolder:GetChildren()) do
			local plat = elevator:FindFirstChild("Platform") or elevator:FindFirstChild("Plataform")
			local sPart = elevator:FindFirstChild("StartPart") or elevator:FindFirstChild("StarPart")
			local ePart = elevator:FindFirstChild("EndPart")
			if plat and sPart and ePart then
				plat.Anchored = false; sPart.Anchored = true; ePart.Anchored = true
				sPart.CanCollide = false; ePart.CanCollide = false; sPart.Transparency = 1; ePart.Transparency = 1

				local speed = elevator:GetAttribute("Speed") or 15
				local pauseTime = elevator:GetAttribute("PauseTime") or 2.0
				local dist = (ePart.Position - sPart.Position).Magnitude

				local a0 = Instance.new("Attachment", sPart)
				local a1 = Instance.new("Attachment", plat)
				local directionVec = (ePart.Position - sPart.Position).Unit
				local upVector = math.abs(directionVec.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
				a0.Axis = directionVec; a0.SecondaryAxis = upVector; a1.Axis = directionVec; a1.SecondaryAxis = upVector; a1.Position = Vector3.zero

				local prismatic = Instance.new("PrismaticConstraint", plat)
				prismatic.Attachment0 = a0; prismatic.Attachment1 = a1; prismatic.ActuatorType = Enum.ActuatorType.Servo
				prismatic.ServoMaxForce = 1000000; prismatic.Speed = speed; prismatic.LimitsEnabled = false

				local crusherSensor = Instance.new("Part")
				crusherSensor.Name = "DeathPit"; crusherSensor.Size = Vector3.new(plat.Size.X * 0.8, 0.5, plat.Size.Z * 0.8)
				crusherSensor.CFrame = plat.CFrame * CFrame.new(0, -(plat.Size.Y / 2) - 0.25, 0); crusherSensor.Transparency = 1
				crusherSensor.CanCollide = false; crusherSensor.Massless = true
				crusherSensor.Parent = plat
				local weld = Instance.new("WeldConstraint", plat); weld.Part0 = plat; weld.Part1 = crusherSensor

				task.spawn(function()
					while not inGame do if not plat.Parent then return end task.wait(0.1) end
					local targetPos = dist
					prismatic.TargetPosition = targetPos
					while plat.Parent and inGame do
						if math.abs(prismatic.CurrentPosition - targetPos) < 1.0 then
							task.wait(pauseTime)
							if not inGame or not plat.Parent then break end
							targetPos = (targetPos == dist) and 0 or dist
							prismatic.TargetPosition = targetPos
						end
						task.wait(0.1)
					end
				end)
			end
		end
	end
	return true
end

-- spawns the sphere, sets up physics, camera, lighting, and the per-frame heartbeat loop
-- Crea la esfera de cero y reengancha sus bucles de fisica y camara.
RebuildSphere = function()
	if gameData.spherePart then gameData.spherePart:Destroy() end
	if gameData.camProxy then gameData.camProxy:Destroy() end

	local customSphere = Assets:FindFirstChild("PlayerSphere")
	local sphere
	if customSphere then
		sphere = customSphere:Clone()
	else
		sphere = Instance.new("Part")
		sphere.Shape = Enum.PartType.Ball
		sphere.Size = SphereModule.GameConfig and SphereModule.GameConfig.PlayerDefaultSize or Vector3.new(4,4,4)
		sphere.Material = Enum.Material.Neon
		sphere.Color = Color3.fromHex("10b981")
	end

	sphere.Anchored = false
	sphere.CustomPhysicalProperties = PhysicalProperties.new(1, 0.8, 0.2)
	sphere.Parent = workspace

	local stripe = Instance.new("Part", sphere)
	stripe.Name = "StripeVisual"; stripe.Size = Vector3.new(0.6, sphere.Size.Y + 0.2, sphere.Size.Z + 0.2); stripe.Shape = Enum.PartType.Cylinder
	stripe.Material = Enum.Material.Neon; stripe.Color = Color3.fromHex("FFFFFF"); stripe.Transparency = 0.3; stripe.CanCollide = false; stripe.Massless = true
	stripe.CFrame = sphere.CFrame
	local weld = Instance.new("WeldConstraint", sphere); weld.Part0 = sphere; weld.Part1 = stripe

	local att = Instance.new("Attachment", sphere)
	local vf = Instance.new("VectorForce", sphere); vf.Attachment0 = att; vf.RelativeTo = Enum.ActuatorRelativeTo.World
	local av = Instance.new("AngularVelocity", sphere); av.Attachment0 = att; av.RelativeTo = Enum.ActuatorRelativeTo.World; av.AngularVelocity = Vector3.zero; av.MaxTorque = 0

	local camProxy = Instance.new("Part", workspace)
	camProxy.Size = Vector3.new(1,1,1); camProxy.Transparency = 1; camProxy.CanCollide = false; camProxy.Massless = true; camProxy.Anchored = true

	gameData.camProxy = camProxy; gameData.spherePart = sphere; gameData.vectorForce = vf; gameData.angularVelocity = av; gameData.attachment = att
	sphere.CFrame = gameData.spawnCFrame; sphere.AssemblyLinearVelocity = Vector3.zero; sphere.AssemblyAngularVelocity = Vector3.zero

	gameData.startTime = os.clock()
	createCustomHUD()

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom; cam.CameraSubject = camProxy; cam.FieldOfView = 80
	if gameData.physicsConnection then gameData.physicsConnection:Disconnect() end
	RunService:UnbindFromRenderStep("SphereCamTracking")

	gameData.physicsConnection = RunService.Heartbeat:Connect(function(dt)
		if not inGame or not sphere.Parent then return end

		local mass = sphere.AssemblyMass
		local currentVel = sphere.AssemblyLinearVelocity
		local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {sphere, player.Character, camProxy}; rayParams.FilterType = Enum.RaycastFilterType.Exclude

		local isGrounded = (workspace:Raycast(sphere.Position, Vector3.new(0, -(sphere.Size.Y / 2 + 1.0), 0), rayParams) ~= nil)
		local moveVec = ControlModule:GetMoveVector()
		if moveVec.Magnitude < 0.05 and gameData.ucMoveVec.Magnitude > 0 then moveVec = Vector3.new(gameData.ucMoveVec.X, 0, -gameData.ucMoveVec.Y) end

		local camLook = cam.CFrame.LookVector; local camRight = cam.CFrame.RightVector
		local inputDir = ((Vector3.new(camLook.X, 0, camLook.Z).Unit * -moveVec.Z) + (Vector3.new(camRight.X, 0, camRight.Z).Unit * moveVec.X))
		if inputDir.Magnitude > 0 then inputDir = inputDir.Unit end

		local moveForce = Vector3.zero; local levitationForce = Vector3.zero
		if SphereModule.GetMovementForce then moveForce = SphereModule.GetMovementForce(inputDir, currentVel, mass, isGrounded, gameData.activePowers) end

		if gameData.activePowers["ALAS"] and SphereModule.PowerUps.ALAS then
			local alas = SphereModule.PowerUps.ALAS
			local heightCheck = workspace:Raycast(sphere.Position, Vector3.new(0, -50, 0), rayParams)
			local currentHeight = heightCheck and (sphere.Position.Y - heightCheck.Position.Y) or 999
			local diff = (alas.MaxLiftHeight or 20.0) - currentHeight
			local upForce = workspace.Gravity * mass
			if diff > 0 then upForce = upForce + (diff * mass * (alas.LiftForce or 30)) end
			levitationForce = Vector3.new(0, upForce - (currentVel.Y * mass * (alas.Damping or 8)), 0)
		end

		vf.Force = moveForce + levitationForce

		if inputDir.Magnitude > 0 then
			av.MaxTorque = SphereModule.Physics.TorqueAcceleration * mass
			if SphereModule.GetTargetAngularVelocity then av.AngularVelocity = SphereModule.GetTargetAngularVelocity(inputDir, gameData.activePowers) end
		else
			av.MaxTorque = 0; av.AngularVelocity = Vector3.zero
		end

		if gameData.usePowerRequested then
			gameData.usePowerRequested = false
			if gameData.storedPower == "fast" then ApplyPowerUp("fast"); gameData.storedPower = nil; updateHUD() end
		end

		if isGrounded and (UserInputService:IsKeyDown(Enum.KeyCode.Space) or gameData.jumpRequested) and not gameData.jumpDebounce then
			gameData.jumpRequested = false; gameData.jumpDebounce = true
			if gameData.storedPower == "Spring" then ApplyPowerUp("Spring"); gameData.storedPower = nil; updateHUD() end
			if SphereModule.GetJumpImpulse then sphere:ApplyImpulse(Vector3.new(0, SphereModule.GetJumpImpulse(mass, gameData.activePowers), 0)) end
			task.delay(0.2, function() gameData.jumpDebounce = false end)
		else gameData.jumpRequested = false end
	end)

	RunService:BindToRenderStep("SphereCamTracking", Enum.RenderPriority.Camera.Value - 1, function()
		if inGame and camProxy and sphere.Parent then camProxy.CFrame = CFrame.new(sphere.Position) end
	end)

	sphere.Touched:Connect(HandleSphereCollision)
end

Setup3DGame = function(skipLoad)
	if not skipLoad then
		local success = LoadLevel(currentLevelNum)
		if not success then inGame = false; ReturnToMainMenu(); return end
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = true; hrp.CFrame = gameData.spawnCFrame end

	ControlModule:Disable()

	gameData.ucMoveVec = Vector2.zero
	gameData.jumpRequested = false
	gameData.usePowerRequested = false

	UniversalController.CrearControlesImNotASphere(
		function(vec) gameData.ucMoveVec = vec end,
		function(vec) end,
		function() gameData.jumpRequested = true end,
		function() gameData.usePowerRequested = true end
	)


	Lighting.TimeOfDay = "17:30:00"; Lighting.Brightness = 0.2; Lighting.Ambient = Color3.fromHex("FF6B2B")
	Lighting.OutdoorAmbient = Color3.fromHex("FF8C42"); Lighting.ColorShift_Bottom = Color3.fromHex("FF3300"); Lighting.ColorShift_Top = Color3.fromHex("FFAA00"); Lighting.FogColor = Color3.fromHex("FF7043")
	Lighting.FogEnd = 1500; Lighting.FogStart = 150

	local sky = Instance.new("Sky", Lighting); sky.Name = "SunsetSky"; sky.SunAngularSize = 1
	local atmosphere = Instance.new("Atmosphere", Lighting); atmosphere.Name = "SunsetAtmosphere"; atmosphere.Density = 0.25; atmosphere.Offset = 0.25; atmosphere.Color = Color3.fromHex("FF8C42"); atmosphere.Decay = Color3.fromHex("FF5522"); atmosphere.Glare = 2.0; atmosphere.Haze = 3.0
	local clouds = Instance.new("Clouds", workspace.Terrain); clouds.Name = "SunsetClouds"; clouds.Cover = 0.6; clouds.Density = 0.4; clouds.Color = Color3.fromHex("FFDAB3")

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			for _, part in ipairs(p.Character:GetDescendants()) do
				if (part:IsA("BasePart") or part:IsA("Decal")) and part.Name ~= "HumanoidRootPart" then part.Transparency = 1 end
			end
		end
	end

	RebuildSphere()
end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gn)
		if gn == "ImNotASphere" and not inGame then
			InyectarConfiguracionSphere()
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
			if versusGui then end
		elseif type == "PlayerJoined" or type == "PlayerLeft" then
			MenuModule.UpdateLobbyPlayers(data)
		elseif type == "StartGame" then
			FullQuitGame(); task.wait(0.1)
			inGame = true; isVersusMode = true
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then gameData.originalPlayerCFrame = char.HumanoidRootPart.CFrame end
			local loadGui = Instance.new("ScreenGui", playerGui)
			showLoadingOverlay(loadGui, "LOADING MAP & LIGHTS...")
			currentLevelNum = 1
			local success = LoadLevel(currentLevelNum)
			if success and currentLevelFolder then PreloadLevelAssets(currentLevelFolder); task.wait(2.5) end
			loadGui:Destroy()
			Setup3DGame(true)
		elseif type == "MatchEnded" then
			local win = (data.Winner == player.Name)
			Cleanup3DGame(); inGame = false; isVersusMode = false
			MenuModule.ShowGameOver(data.Score or 0, win, ReturnToMainMenu, FullQuitGame)
			local titleColor = win and Color3.fromHex("fbbf24") or Color3.fromHex("5b21b6")
			local textTitle = win and "VICTORY!" or "GAME OVER"
			MenuModule.ShowInfoOverlay(textTitle, "Winner: " .. (data.Winner or "") .. "\nScore: " .. tostring(data.Score or 0) .. "\nTime: " .. tostring(math.floor(data.Time or 0)) .. "s", titleColor)
		elseif type == "EliminatedEarly" then
			Cleanup3DGame(); inGame = false; isVersusMode = false
			MenuModule.ShowGameOver(data.Score or 0, false, ReturnToMainMenu, FullQuitGame)
		elseif type == "SuddenDeathWait" then
			MenuModule.ShowBottomAlert("MATCH ENDING...", "The game will close in 30 seconds!", Color3.fromRGB(255, 100, 100))
		elseif type == "SuddenDeath" then
			playSound(perfectSound)
			MenuModule.ShowBottomAlert("HURRY UP!", "THE GAME ENDS IN 30 SECONDS!", Color3.fromRGB(255, 50, 50))
		elseif type == "Kicked" or type == "RoomClosed" then
			MenuModule.DestroyAllMenus(); MenuModule.ShowMainMenu()
			local titleText = (type == "Kicked") and "KICKED" or "CLOSED"
			local msgText = (type == "Kicked") and "You were removed." or "Room closed."
			MenuModule.ShowInfoOverlay(titleText, msgText, Color3.fromRGB(239, 68, 68))
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not inGame then return end

	if UniversalController.EsBotonAtras(input) then
		if isVersusMode and LeaveRoomEvent then pcall(function() LeaveRoomEvent:FireServer() end) end
		FullQuitGame()
		return
	end

	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not processed then
		if gameData.storedPower == "fast" then
			ApplyPowerUp("fast")
			gameData.storedPower = nil
			updateHUD()
		end
	end
end)
