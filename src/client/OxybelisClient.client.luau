local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local ControlModule = PlayerModule:GetControls()

local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local Menu1to7 = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu1to7"))

-- searches multiple locations for the remotes to handle different project layouts
local function findOxybelisRemotes()
	local arc = ReplicatedStorage:FindFirstChild("ArcadeRemotes")
	local oxybelisFolder = arc and arc:FindFirstChild("Oxybelis") or nil

	local StartRequest = (oxybelisFolder and (oxybelisFolder:FindFirstChild("StartRequest") or oxybelisFolder:FindFirstChild("StartOxybelisRequest")))
		or (arc and (arc:FindFirstChild("StartRequest") or arc:FindFirstChild("StartOxybelisRequest")))
		or ReplicatedStorage:FindFirstChild("StartRequest") or ReplicatedStorage:FindFirstChild("StartOxybelisRequest")

	local SubmitMove = (oxybelisFolder and oxybelisFolder:FindFirstChild("SubmitMove"))
		or (arc and arc:FindFirstChild("SubmitMove")) or ReplicatedStorage:FindFirstChild("SubmitMove")

	local GameState = (oxybelisFolder and oxybelisFolder:FindFirstChild("GameState"))
		or (arc and arc:FindFirstChild("GameState")) or ReplicatedStorage:FindFirstChild("GameState")

	local ToggleAudio = (oxybelisFolder and oxybelisFolder:FindFirstChild("ToggleAudio"))
		or (arc and arc:FindFirstChild("Oxybelis") and arc.Oxybelis:FindFirstChild("ToggleAudio"))

	local OpenArcadeMenu = (arc and arc:FindFirstChild("OpenArcadeMenu")) or ReplicatedStorage:FindFirstChild("OpenArcadeMenu")

	local mods = ReplicatedStorage:FindFirstChild("Modules")
	if mods then
		StartRequest = StartRequest or mods:FindFirstChild("StartRequest") or mods:FindFirstChild("StartOxybelisRequest")
		SubmitMove = SubmitMove or mods:FindFirstChild("SubmitMove")
		GameState = GameState or mods:FindFirstChild("GameState")
		OpenArcadeMenu = OpenArcadeMenu or mods:FindFirstChild("OpenArcadeMenu")
	end

	return StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio
end

local StartRequest, SubmitMove, GameState, OpenArcadeMenu, ToggleAudio = findOxybelisRemotes()

local soundEnabled = true
local eatSound = Instance.new("Sound", script)
eatSound.SoundId = "rbxassetid://2940337254"
eatSound.Volume = 0.6

if ToggleAudio then
	ToggleAudio.OnClientEvent:Connect(function(isEnabled) soundEnabled = isEnabled end)
end

local function playEatSound()
	if soundEnabled and not eatSound.IsPlaying then eatSound:Play() end
end

local inGame = false
local gameGui = nil
local cols, rows = 16, 12
local lastScore = 0
local lastOxybelisLength = 0
local currentOxybelisPartInstances = {}
local unbindOxybelisControls

-- reuses or creates the blur effect used while the game is open
local blurEffect = Lighting:FindFirstChild("ArcadeMenuBlur") or Instance.new("BlurEffect", Lighting)
blurEffect.Name = "ArcadeMenuBlur"
blurEffect.Enabled = false
blurEffect.Size = 0

-- tweens the blur in or out and disables it once fully cleared
local function setBlurEnabled(enabled)
	blurEffect.Enabled = true
	TweenService:Create(blurEffect, TweenInfo.new(0.3), { Size = enabled and 56 or 0 }):Play()
	if not enabled then task.delay(0.3, function() blurEffect.Enabled = false end) end
end

local function Color3FromHex(hex)
	hex = tostring(hex or ""):gsub("#","")
	if #hex == 3 then hex = hex:gsub(".", "%1%1") end
	return Color3.fromRGB(tonumber(hex:sub(1,2), 16) or 255, tonumber(hex:sub(3,4), 16) or 255, tonumber(hex:sub(5,6), 16) or 255)
end

local fixedFoodColor = Color3FromHex("c10007")

local DONATION_PRODUCTS = {
	{ Id = 3469886027, Price = 5,    Name = "Oxybelis Tip" },
	{ Id = 3469886194, Price = 15,   Name = "Oxybelis Treat" },
	{ Id = 3469886385, Price = 50,   Name = "Oxybelis Sub" },
	{ Id = 3469886458, Price = 100,  Name = "Oxybelis Sponsor" },
	{ Id = 3469886602, Price = 500,  Name = "Oxybelis Whale" },
	{ Id = 3469886735, Price = 1000, Name = "Oxybelis Legend" },
}

local configOxybelis = {
	Titulo = "OXYBELIS",
	IconoPrincipal = "🐍",
	IconosBotones = { Play = "🎮", Vip = "👑", Exit = "🚪" },
	ColorFondo = "d8f999",
	ColorBtnPlay = "9ae600",
	ColorBtnVip = "5ea500",
	ColorBtnExit = "497d00",
	Donaciones = DONATION_PRODUCTS,

	Controlador = UniversalController,

	OnPlay = function()
		if StartRequest then StartRequest:FireServer() end
	end,
	OnExit = function()
		setBlurEnabled(false)
		ControlModule:Enable()
	end
}

local function exitCurrentGame()
	inGame = false
	if unbindOxybelisControls then unbindOxybelisControls() end
	if gameGui then gameGui:Destroy(); gameGui = nil end
	Menu1to7.AbrirMenuPrincipal(configOxybelis)
end

local function updateMuteButtonVisuals(btn)
	if not btn then return end
	if soundEnabled then
		btn.BackgroundColor3 = Color3FromHex("497d00")
		btn.Text = "🔊 ON"
	else
		btn.BackgroundColor3 = Color3FromHex("666666")
		btn.Text = "🔇 MUTED"
	end
end

-- builds the game frame, canvas, score label, exit and mute buttons
function initOxybelisGui()
	if gameGui then gameGui:Destroy() end
	setBlurEnabled(true)

	gameGui = Instance.new("ScreenGui", playerGui)
	gameGui.Name = "OxybelisGameGui"
	gameGui.ResetOnSpawn = false

	local gameFrame = Instance.new("Frame", gameGui)
	gameFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	gameFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	gameFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
	gameFrame.BackgroundColor3 = Color3.new(0,0,0)

	Instance.new("UIAspectRatioConstraint", gameFrame).AspectRatio = 480 / 390
	Instance.new("UISizeConstraint", gameFrame).MaxSize = Vector2.new(960, 780)

	local canvas = Instance.new("Frame", gameFrame)
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, 0, 360/390, 0)
	canvas.Position = UDim2.new(0, 0, 30/390, 0)
	canvas.BackgroundColor3 = Color3.fromRGB(30,30,30)

	local scoreLabel = Instance.new("TextLabel", gameFrame)
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(0.5, 0, 30/390, 0)
	scoreLabel.Position = UDim2.new(0, 6, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.new(1,1,1)
	scoreLabel.TextScaled = true
	scoreLabel.Text = "Score: 0"
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left

	local hudExitBtn = Instance.new("TextButton", gameFrame)
	hudExitBtn.AnchorPoint = Vector2.new(1,0)
	hudExitBtn.Position = UDim2.new(0.98, 0, 2/390, 0)
	hudExitBtn.Size = UDim2.new(0.15, 0, 26/390, 0)
	hudExitBtn.BackgroundColor3 = Color3FromHex("497d00")
	hudExitBtn.Text = "EXIT"
	hudExitBtn.TextColor3 = Color3.new(1,1,1)
	hudExitBtn.TextScaled = true
	hudExitBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudExitBtn).CornerRadius = UDim.new(0, 8)
	hudExitBtn.MouseButton1Click:Connect(exitCurrentGame)

	local hudMuteBtn = Instance.new("TextButton", gameFrame)
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

-- ripples a growth color wave from head to tail when the snake eats
local function animateOxybelisGrowth()
	local growthColor = Color3FromHex("d8f999")
	local originalHeadColor = Color3.fromRGB(0, 255, 0)
	local originalBodyColor = Color3.fromRGB(0, 180, 0)
	local initialLength = #currentOxybelisPartInstances

	for i = 1, initialLength do
		local partFrame = currentOxybelisPartInstances[i]
		if not (partFrame and partFrame.Parent) then continue end
		local previousPart = currentOxybelisPartInstances[i-1]
		partFrame.BackgroundColor3 = growthColor
		if previousPart and previousPart.Parent then
			previousPart.BackgroundColor3 = (i-1 == 1) and originalHeadColor or originalBodyColor
		end
		task.wait(0.025)
	end
	task.wait(0.1)

	local tail = currentOxybelisPartInstances[initialLength]
	if tail and tail.Parent then
		for _ = 1, 3 do
			tail.BackgroundColor3 = growthColor; task.wait(0.1)
			tail.BackgroundColor3 = originalBodyColor; task.wait(0.1)
		end
	end
end

-- rebuilds all snake segment and food frames from the latest server state
function renderState(data)
	if not gameGui or not gameGui.Parent then initOxybelisGui() end
	local canvas = gameGui:FindFirstChild("Canvas", true)
	if not canvas then return end

	local scoreLabel = gameGui:FindFirstChild("ScoreLabel", true)
	if scoreLabel then
		local newScore = data.score or 0
		scoreLabel.Text = "Score: " .. tostring(newScore)
		if newScore > lastScore then playEatSound() end
		lastScore = newScore
	end

	for _, child in ipairs(canvas:GetChildren()) do
		if child:IsA("Frame") and (child.Name == "OxybelisPart" or child.Name == "Food") then child:Destroy() end
	end

	table.clear(currentOxybelisPartInstances)
	local widthScale = 1 / cols
	local heightScale = 1 / rows

	if data.food then
		local f = Instance.new("Frame", canvas)
		f.Name = "Food"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.new(widthScale * 0.8, 0, heightScale * 0.8, 0)
		f.Position = UDim2.new(((data.food.x - 1) * widthScale) + (widthScale / 2), 0, ((data.food.y - 1) * heightScale) + (heightScale / 2), 0)
		f.BackgroundColor3 = fixedFoodColor
	end

	for i, part in ipairs(data.oxybelis or {}) do
		local s = Instance.new("Frame", canvas)
		s.Name = "OxybelisPart"
		s.Size = UDim2.new(widthScale, 0, heightScale, 0)
		s.Position = UDim2.new((part.x - 1) * widthScale, 0, (part.y - 1) * heightScale, 0)
		s.BackgroundColor3 = (i == 1) and Color3.fromRGB(0,255,0) or Color3.fromRGB(0,180,0)
		table.insert(currentOxybelisPartInstances, s)
	end

	local currentOxybelisLength = #(data.oxybelis or {})
	if currentOxybelisLength > lastOxybelisLength and lastOxybelisLength > 0 then task.spawn(animateOxybelisGrowth) end
	lastOxybelisLength = currentOxybelisLength
end

local function irArriba(n, s, i) if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Up")    end end
local function irAbajo(n, s, i)  if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Down")  end end
local function irIzq(n, s, i)    if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Left")  end end
local function irDer(n, s, i)    if s == Enum.UserInputState.Begin and SubmitMove then SubmitMove:FireServer("Right") end end

local function bindOxybelisControls() UniversalController.CrearControlesOxybelis(irArriba, irAbajo, irIzq, irDer) end
unbindOxybelisControls = function() UniversalController.LimpiarControles() end

if OpenArcadeMenu then
	OpenArcadeMenu.OnClientEvent:Connect(function(gameName)
		if gameName == "Oxybelis" then
			if inGame or playerGui:FindFirstChild("ArcadeMenuPrincipal") then return end
			ControlModule:Disable()
			Menu1to7.AbrirMenuPrincipal(configOxybelis)
		end
	end)
end

if GameState then
	GameState.OnClientEvent:Connect(function(mode, data)
		if mode == "Start" then
			inGame = true
			lastOxybelisLength = 0
			lastScore = 0
			ControlModule:Disable()
			bindOxybelisControls()
			initOxybelisGui()
		elseif mode == "Update" then
			if inGame then renderState(data) end
		elseif mode == "End" then
			if not inGame then return end
			inGame = false
			table.clear(currentOxybelisPartInstances)
			unbindOxybelisControls()
			if gameGui then gameGui:Destroy(); gameGui = nil end
			Menu1to7.AbrirGameOver(data.score or 0, data.perfect == true)
		end
	end)
end
