-- Loading overlay shown on join: freezes the player until IslandSky lighting
-- is applied, with an animated progress bar, then fades out.
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLOR_BG    = Color3.fromRGB(5, 10, 20)
local COLOR_NEON  = Color3.fromRGB(154, 230, 0)
local COLOR_TEXT  = Color3.fromRGB(216, 249, 153)
local COLOR_GREY  = Color3.fromRGB(150, 150, 150)
local COLOR_DARK  = Color3.fromRGB(20, 25, 10)

-- Build screen immediately so the black frame covers the world from frame 1
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "LoadingScreen"
screenGui.DisplayOrder     = 100000
screenGui.IgnoreGuiInset   = true
screenGui.ResetOnSpawn     = false
screenGui.Parent           = playerGui

local bg = Instance.new("Frame", screenGui)
bg.Size                    = UDim2.fromScale(1, 1)
bg.BackgroundColor3        = COLOR_BG
bg.BackgroundTransparency  = 0
bg.BorderSizePixel         = 0

-- Title
local title = Instance.new("TextLabel", bg)
title.Size                 = UDim2.new(0.7, 0, 0.12, 0)
title.Position             = UDim2.fromScale(0.5, 0.36)
title.AnchorPoint          = Vector2.new(0.5, 0.5)
title.BackgroundTransparency = 1
title.Text                 = "ISLAND ARCADE"
title.Font                 = Enum.Font.GothamBlack
title.TextScaled           = true
title.TextColor3           = COLOR_NEON
title.TextTransparency     = 1

local titleStroke = Instance.new("UIStroke", title)
titleStroke.Color          = COLOR_NEON
titleStroke.Thickness      = 2
titleStroke.Transparency   = 1

-- Subtitle
local subtitle = Instance.new("TextLabel", bg)
subtitle.Size              = UDim2.new(0.55, 0, 0.05, 0)
subtitle.Position          = UDim2.fromScale(0.5, 0.46)
subtitle.AnchorPoint       = Vector2.new(0.5, 0.5)
subtitle.BackgroundTransparency = 1
subtitle.Text              = "Preparing your adventure..."
subtitle.Font              = Enum.Font.Gotham
subtitle.TextScaled        = true
subtitle.TextColor3        = COLOR_GREY
subtitle.TextTransparency  = 1

-- Progress bar container
local barBg = Instance.new("Frame", bg)
barBg.Size                 = UDim2.new(0.5, 0, 0.018, 0)
barBg.Position             = UDim2.fromScale(0.5, 0.57)
barBg.AnchorPoint          = Vector2.new(0.5, 0.5)
barBg.BackgroundColor3     = COLOR_DARK
barBg.BackgroundTransparency = 0
barBg.BorderSizePixel      = 0
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
local barStroke = Instance.new("UIStroke", barBg)
barStroke.Thickness        = 1.5
barStroke.Color            = COLOR_NEON
barStroke.Transparency     = 0.3

-- Progress bar fill
local barFill = Instance.new("Frame", barBg)
barFill.Size               = UDim2.fromScale(0, 1)
barFill.BackgroundColor3   = COLOR_NEON
barFill.BackgroundTransparency = 0
barFill.BorderSizePixel    = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

-- Shimmer sweep on fill
local shimmer = Instance.new("Frame", barFill)
shimmer.Size               = UDim2.fromScale(0.45, 1)
shimmer.Position           = UDim2.fromScale(-0.45, 0)
shimmer.BackgroundColor3   = Color3.new(1, 1, 1)
shimmer.BackgroundTransparency = 0.6
shimmer.BorderSizePixel    = 0
Instance.new("UICorner", shimmer).CornerRadius = UDim.new(1, 0)
local shimGrad = Instance.new("UIGradient", shimmer)
shimGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.3),
	NumberSequenceKeypoint.new(1, 1),
})
shimGrad.Rotation = 0

-- Status label
local statusLabel = Instance.new("TextLabel", bg)
statusLabel.Size           = UDim2.new(0.5, 0, 0.04, 0)
statusLabel.Position       = UDim2.fromScale(0.5, 0.63)
statusLabel.AnchorPoint    = Vector2.new(0.5, 0.5)
statusLabel.BackgroundTransparency = 1
statusLabel.Text           = "Initializing..."
statusLabel.Font           = Enum.Font.Gotham
statusLabel.TextScaled     = true
statusLabel.TextColor3     = COLOR_GREY
statusLabel.TextTransparency = 1

-- Percentage label
local pctLabel = Instance.new("TextLabel", bg)
pctLabel.Size              = UDim2.new(0.15, 0, 0.045, 0)
pctLabel.Position          = UDim2.fromScale(0.5, 0.69)
pctLabel.AnchorPoint       = Vector2.new(0.5, 0.5)
pctLabel.BackgroundTransparency = 1
pctLabel.Text              = "0%"
pctLabel.Font              = Enum.Font.GothamBlack
pctLabel.TextScaled        = true
pctLabel.TextColor3        = COLOR_NEON
pctLabel.TextTransparency  = 1

-- ─── Helpers ────────────────────────────────────────────────────────────────

local currentPct = 0

local function setProgress(pct, status)
	currentPct = pct
	TweenService:Create(barFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(pct / 100, 1)
	}):Play()
	pctLabel.Text    = math.floor(pct) .. "%"
	statusLabel.Text = status
end

local function tweenTransparency(inst, props, t)
	TweenService:Create(inst, TweenInfo.new(t or 0.5, Enum.EasingStyle.Quad), props):Play()
end

-- Fade all content IN
local function fadeIn()
	local t = 0.6
	tweenTransparency(title,       {TextTransparency = 0}, t)
	tweenTransparency(titleStroke, {Transparency = 0.2},   t)
	tweenTransparency(subtitle,    {TextTransparency = 0},  t)
	tweenTransparency(statusLabel, {TextTransparency = 0},  t)
	tweenTransparency(pctLabel,    {TextTransparency = 0},  t)
end

-- Fade everything OUT
local function fadeOut()
	local t = 0.75
	tweenTransparency(bg,          {BackgroundTransparency = 1}, t)
	tweenTransparency(title,       {TextTransparency = 1},       t)
	tweenTransparency(titleStroke, {Transparency = 1},           t)
	tweenTransparency(subtitle,    {TextTransparency = 1},        t)
	tweenTransparency(statusLabel, {TextTransparency = 1},        t)
	tweenTransparency(pctLabel,    {TextTransparency = 1},        t)
	tweenTransparency(barBg,       {BackgroundTransparency = 1},  t)
	tweenTransparency(barFill,     {BackgroundTransparency = 1},  t)
	tweenTransparency(barStroke,   {Transparency = 1},            t)
end

-- ─── Animations ─────────────────────────────────────────────────────────────

-- Pulsing glow on title
task.spawn(function()
	while screenGui and screenGui.Parent do
		tweenTransparency(titleStroke, {Transparency = 0.8}, 0.9)
		task.wait(0.9)
		tweenTransparency(titleStroke, {Transparency = 0.05}, 0.9)
		task.wait(0.9)
	end
end)

-- Shimmer sweep across bar
task.spawn(function()
	while screenGui and screenGui.Parent do
		TweenService:Create(shimmer, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Position = UDim2.fromScale(1.0, 0)
		}):Play()
		task.wait(1.6)
		shimmer.Position = UDim2.fromScale(-0.45, 0)
		task.wait(0.1)
	end
end)

-- ─── Loading sequence ────────────────────────────────────────────────────────

-- Wait for character and freeze movement
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")

local savedWalk   = humanoid.WalkSpeed
local savedJump   = humanoid.JumpHeight
local savedJumpP  = humanoid.JumpPower
humanoid.WalkSpeed  = 0
humanoid.JumpHeight = 0
humanoid.JumpPower  = 0

-- Start showing content
fadeIn()
setProgress(10, "Initializing world...")
task.wait(0.4)

setProgress(25, "Loading character...")
task.wait(0.35)

-- Wait for IslandAtmosphere (IslandSky runs and creates it)
local TIMEOUT = 6
local elapsed = 0
while not Lighting:FindFirstChild("IslandAtmosphere") and elapsed < TIMEOUT do
	task.wait(0.1)
	elapsed += 0.1
end
setProgress(50, "Applying atmosphere...")
task.wait(0.4)

-- Wait for sky + color correction
elapsed = 0
while (not Lighting:FindFirstChild("IslandSky") or not Lighting:FindFirstChild("IslandGrade")) and elapsed < TIMEOUT do
	task.wait(0.1)
	elapsed += 0.1
end
setProgress(70, "Setting up lighting...")
task.wait(0.4)

-- Wait for bloom
elapsed = 0
while not Lighting:FindFirstChild("IslandBloom") and elapsed < TIMEOUT do
	task.wait(0.1)
	elapsed += 0.1
end
setProgress(88, "Almost ready...")
task.wait(0.5)

setProgress(100, "Welcome!")
task.wait(0.45)

-- Restore player movement
humanoid.WalkSpeed  = savedWalk
humanoid.JumpHeight = savedJump
humanoid.JumpPower  = savedJumpP

-- Fade out and destroy
fadeOut()
task.wait(0.85)
screenGui:Destroy()
