local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local UniversalController = require(PlayerScripts:WaitForChild("UniversalController"))
local Menu1to7 = require(ReplicatedStorage:WaitForChild("Menu"):WaitForChild("Menu1to7"))

-- logical canvas dimensions used for all fruit position math
local GAME_W = 480
local GAME_H = 390
local HEADER_H = 30
local SIDE_W = 100
local CANVAS_W = GAME_W - SIDE_W
local CANVAS_H = GAME_H - HEADER_H

local FRUIT_SIZE = 80
local FRUIT_R = FRUIT_SIZE / 2

local SIDE_PREVIEW_FIXED = "rbxassetid://94874887616458"
local GAME_BG_TEXTURE = "rbxassetid://90041088793917"

-- level 1 assets
local LEMON_ASSET = "rbxassetid://87613441938077"
local LEMON_CUT_ASSET = "rbxassetid://116731949603410"
local BAD_ORANGE = "rbxassetid://115742568427308"
local BAD_APPLE = "rbxassetid://80534751878619"
local BAD_STRAW = "rbxassetid://108408061489677"

local LEMONADE_SEQ = {
	"rbxassetid://96570862419330", "rbxassetid://82919640948266", "rbxassetid://73264138806608", "rbxassetid://86096089877360",
	"rbxassetid://91891615573645", "rbxassetid://122531119630858", "rbxassetid://73513184997020", "rbxassetid://75337104008393",
	"rbxassetid://84396711144034", "rbxassetid://81987040683070", "rbxassetid://78182016595305", "rbxassetid://134151612907956",
	"rbxassetid://95638744529511",
}

-- level 2 assets
local STRAW_ASSET = "rbxassetid://93823731383536"
local STRAW_CUT_ASSET = "rbxassetid://98537582411234"
local BANANA_ASSET = "rbxassetid://127957609828105"
local BANANA_CUT_ASSET = "rbxassetid://133899611380899"
local BAD_WATERMELON = "rbxassetid://137490048542264"
local BAD_PEAR = "rbxassetid://132369207739868"
local BAD_LEMON2 = "rbxassetid://135281270806438"

local FREBAN_SEQ = {
	"rbxassetid://106424905634904", "rbxassetid://73911050571540", "rbxassetid://89180390685388",
	"rbxassetid://106094014334504", "rbxassetid://77500166682202", "rbxassetid://83975347928813",
	"rbxassetid://113266595569599", "rbxassetid://104258071025733", "rbxassetid://86882442879472",
	"rbxassetid://79589420814290", "rbxassetid://136699661156809", "rbxassetid://73451945009389",
	"rbxassetid://116595100510253",
}

-- level 3 assets
local PINA_ASSET = "rbxassetid://92573832108058"
local PINA_CUT_ASSET = "rbxassetid://90547698574482"
local COCO_ASSET = "rbxassetid://90859035515149"
local COCO_CUT_ASSET = "rbxassetid://131856918091929"
local CEREZA_ASSET = "rbxassetid://89970067176669"
local CEREZA_CUT_ASSET = "rbxassetid://106658523467226"

local BAD_MANGO = "rbxassetid://94617794706195"
local BAD_BANANA = "rbxassetid://82461426778745"
local BAD_LEMON3 = "rbxassetid://135281270806438"
local BAD_ORANGE3 = "rbxassetid://115742568427308"

local TROPICAL_SEQ = {
	"rbxassetid://74687070317140", "rbxassetid://95334707285927", "rbxassetid://84937248423957",
	"rbxassetid://131788285571048", "rbxassetid://120544951387219", "rbxassetid://133497318740940",
	"rbxassetid://115786796697245", "rbxassetid://116667043762210", "rbxassetid://139017763894690",
	"rbxassetid://76278448059048", "rbxassetid://100768909117980", "rbxassetid://127777913107622",
	"rbxassetid://93933352717941",
}

-- level 4 assets
local CUCUMBER_ASSET = "rbxassetid://82376125372153"
local CUCUMBER_CUT = "rbxassetid://102677938909246"
local G_APPLE_ASSET = "rbxassetid://108090324091458"
local G_APPLE_CUT = "rbxassetid://77409311574725"
local KIWI_ASSET = "rbxassetid://109446326722635"
local KIWI_CUT = "rbxassetid://84567238056092"

local BAD_PUMPKIN = "rbxassetid://109830099390621"
local BAD_CARROT = "rbxassetid://111274229452780"
local BAD_ONION = "rbxassetid://103509495972861"

local DETOX_SEQ = {
	"rbxassetid://119570394825370", "rbxassetid://125495953052927", "rbxassetid://76193986914698",
	"rbxassetid://82166717224645", "rbxassetid://106212120057466", "rbxassetid://92550853521254",
	"rbxassetid://126160743109062", "rbxassetid://127917481765921", "rbxassetid://112776969775619",
	"rbxassetid://123059191102702", "rbxassetid://91069642045662", "rbxassetid://140033496179606",
	"rbxassetid://115365133595243",
}

-- level 5 assets
local GRAPES_ASSET = "rbxassetid://109631792901350"
local GRAPES_CUT = "rbxassetid://85189935140451"
local R_APPLE_ASSET = "rbxassetid://83268408265851"
local R_APPLE_CUT = "rbxassetid://82302665298042"
local ORANGE_ASSET = "rbxassetid://128480626544761"
local ORANGE_CUT = "rbxassetid://118837800983429"

local BAD_KIWI = "rbxassetid://111412231065394"

local PURERED_SEQ = {
	"rbxassetid://125350246398403", "rbxassetid://128001386525013", "rbxassetid://139811968759823",
	"rbxassetid://103571646077357", "rbxassetid://136403297414706", "rbxassetid://117129053298201",
	"rbxassetid://81718511054120", "rbxassetid://133392869721242", "rbxassetid://112915790279171",
	"rbxassetid://120681030937586", "rbxassetid://73237826859610", "rbxassetid://101115477360485",
	"rbxassetid://87031605620667",
}

-- lookup sets for hit detection categorization
local GOOD_ASSETS = {
	[LEMON_ASSET] = true, [LEMON_CUT_ASSET] = true,
	[STRAW_ASSET] = true, [STRAW_CUT_ASSET] = true,
	[BANANA_ASSET] = true, [BANANA_CUT_ASSET] = true,
	[PINA_ASSET] = true, [PINA_CUT_ASSET] = true,
	[COCO_ASSET] = true, [COCO_CUT_ASSET] = true,
	[CEREZA_ASSET] = true, [CEREZA_CUT_ASSET] = true,
	[CUCUMBER_ASSET] = true, [CUCUMBER_CUT] = true,
	[G_APPLE_ASSET] = true, [G_APPLE_CUT] = true,
	[KIWI_ASSET] = true, [KIWI_CUT] = true,
	[GRAPES_ASSET] = true, [GRAPES_CUT] = true,
	[R_APPLE_ASSET] = true, [R_APPLE_CUT] = true,
	[ORANGE_ASSET] = true, [ORANGE_CUT] = true,
}

local BAD_ASSETS = {
	[BAD_ORANGE] = true, [BAD_APPLE] = true, [BAD_STRAW] = true,
	[BAD_WATERMELON] = true, [BAD_PEAR] = true, [BAD_LEMON2] = true,
	[BAD_MANGO] = true, [BAD_BANANA] = true, [BAD_LEMON3] = true, [BAD_ORANGE3] = true,
	[BAD_PUMPKIN] = true, [BAD_CARROT] = true, [BAD_ONION] = true, [BAD_KIWI] = true,
}

local DONATION_PRODUCTS = {
	{ Id = 3485520379, Price = 5,    Name = "Juice Tip" },
	{ Id = 3485520618, Price = 15,   Name = "Juice Treat" },
	{ Id = 3485520810, Price = 50,   Name = "Juice Sub" },
	{ Id = 3485521145, Price = 100,  Name = "Juice Sponsor" },
	{ Id = 3485521376, Price = 500,  Name = "Juice Whale" },
	{ Id = 3485521765, Price = 1000, Name = "Juice Legend" },
}

local soundEnabled = true
local inGame = false
local gameGui, gameFrame = nil, nil
local canvasRight, sidePanel = nil, nil
local scoreLabel = nil
local hudExitBtn, hudMuteBtn = nil, nil

local sideTitleLabel, targetImg1, targetImg2, targetImg3, sidePreviewImage = nil, nil, nil, nil, nil
local currentLevelUI = 1

local fruitUIs  = {}
local fruitData = {}
local lastCutPoint = nil
local cutDown = false
local lastSendT = 0
local hitCooldown = {}
local isTransitioning = false
local dyingFruits = {}
local didPreloadOnce = false

-- virtual cursor state for gamepad input
local VIRTUAL_CURSOR_SPEED = 600
local virtualCursorPos = Vector2.new(CANVAS_W / 2, CANVAS_H / 2)
local isGamepadCutting = false
local gamepadJoystickVec = Vector2.new(0, 0)
local virtualCursorUI = nil

local function Color3FromHex(hex)
	hex = tostring(hex or ""):gsub("#","")
	if #hex == 3 then hex = hex:gsub(".", "%1%1") end
	local r = tonumber(hex:sub(1,2), 16) or 255
	local g = tonumber(hex:sub(3,4), 16) or 255
	local b = tonumber(hex:sub(5,6), 16) or 255
	return Color3.fromRGB(r, g, b)
end

local V = {
	Darkest  = Color3FromHex("3b0764"), Darker   = Color3FromHex("581c87"),
	Mid      = Color3FromHex("7e22ce"), Accent   = Color3FromHex("a855f7"),
	Light1   = Color3FromHex("d8b4fe"), Light2   = Color3FromHex("e9d5ff"),
	Light3   = Color3FromHex("f3e8ff"), Lightest = Color3FromHex("faf5ff"),
}

local BLUE_NEON  = Color3.fromRGB(80, 170, 255)
local GREEN_NEON = Color3.fromRGB(57, 255, 20)
local RED_NEON   = Color3.fromRGB(255, 40, 120)

local SELECT_SOUND_ID    = "rbxassetid://70844388753756"
local CUT_FRUIT_SOUND_ID = "rbxassetid://6881026094"
local ERROR_SOUND_ID     = "rbxassetid://1313873191"

local function createSound(id, volume)
	if not id or id == "rbxassetid://0" then return nil end
	local s = Instance.new("Sound", script)
	s.SoundId = id
	s.Volume = volume
	return s
end

local selectSound   = createSound(SELECT_SOUND_ID, 0.5)
local cutFruitSound = createSound(CUT_FRUIT_SOUND_ID, 0.9)
local errorSound    = createSound(ERROR_SOUND_ID, 1.0)

local function playSound(snd)
	if not soundEnabled or not snd then return end
	if snd.IsPlaying then snd:Stop() end
	snd.TimePosition = 0
	snd:Play()
end

-- plays cut sound and stops it after 1 second to avoid overlap
local function playCutFruitSound1s()
	playSound(cutFruitSound)
	task.delay(1.0, function() if cutFruitSound and cutFruitSound.IsPlaying then cutFruitSound:Stop() end end)
end

local function playErrorSound1s()
	playSound(errorSound)
	task.delay(1.0, function() if errorSound and errorSound.IsPlaying then errorSound:Stop() end end)
end

local function findJuiceRemotes()
	local arc = ReplicatedStorage:WaitForChild("ArcadeRemotes")
	local jc  = arc:WaitForChild("JuiceCutter")
	return jc:WaitForChild("StartJuiceCutterRequest"), jc:WaitForChild("SubmitMove"), jc:WaitForChild("GameState"), jc:WaitForChild("ToggleAudio"), arc:WaitForChild("OpenArcadeMenu")
end
local StartRequest, SubmitMove, GameState, ToggleAudio, OpenArcadeMenu = findJuiceRemotes()

-- overlays a subtle white glass sheen with a border stroke on any frame
local function addGlassEffectToFrame(targetFrame)
	local glassOverlay = Instance.new("Frame")
	glassOverlay.Name = "GlassEffectOverlay"
	glassOverlay.Size = UDim2.new(1, 0, 1, 0)
	glassOverlay.BackgroundTransparency = 1
	glassOverlay.ZIndex = targetFrame.ZIndex + 1
	glassOverlay.Active = false

	local existingCorner = targetFrame:FindFirstChildOfClass("UICorner")
	local corner = Instance.new("UICorner", glassOverlay)
	corner.CornerRadius = existingCorner and existingCorner.CornerRadius or UDim.new(0, 10)

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

-- draws a glow dot with a larger soft outer ring that fades out
local function makeGlowDot(parent, x, y, coreSize, glowSize, color, life)
	local g = Instance.new("Frame", parent)
	g.AnchorPoint = Vector2.new(0.5,0.5); g.Position = UDim2.new(x / CANVAS_W, 0, y / CANVAS_H, 0); g.Size = UDim2.new(glowSize / CANVAS_W, 0, glowSize / CANVAS_H, 0)
	g.BackgroundColor3 = color; g.BackgroundTransparency = 0.65; g.BorderSizePixel = 0; g.ZIndex = 60
	Instance.new("UICorner", g).CornerRadius = UDim.new(1,0)

	local c = Instance.new("Frame", parent)
	c.AnchorPoint = Vector2.new(0.5,0.5); c.Position = UDim2.new(x / CANVAS_W, 0, y / CANVAS_H, 0); c.Size = UDim2.new(coreSize / CANVAS_W, 0, coreSize / CANVAS_H, 0)
	c.BackgroundColor3 = color; c.BackgroundTransparency = 0.05; c.BorderSizePixel = 0; c.ZIndex = 61
	Instance.new("UICorner", c).CornerRadius = UDim.new(1,0)

	local tinfo = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(g, tinfo, {BackgroundTransparency = 1, Size = UDim2.new((glowSize*1.35) / CANVAS_W, 0, (glowSize*1.35) / CANVAS_H, 0)}):Play()
	TweenService:Create(c, tinfo, {BackgroundTransparency = 1}):Play()
	Debris:AddItem(g, life + 0.05)
	Debris:AddItem(c, life + 0.05)
end

-- spawns a line of glow dots between two canvas points to visualize a cut
local function spawnGlowTrail(parent, x0,y0,x1,y1, color, life)
	local dx, dy = x1-x0, y1-y0
	local len = math.sqrt(dx*dx + dy*dy)
	if len < 2 then return end
	local steps = math.clamp(math.floor(len / 14), 1, 18)
	for i=0,steps do local a = i/steps; makeGlowDot(parent, x0 + dx*a, y0 + dy*a, 6, 18, color, life) end
end

-- spawns three expanding red ring pulses centered on a bad fruit hit
local function spawnRedRippleEffect(parent, x, y)
	for i = 1, 3 do
		task.delay((i-1)*0.25, function()
			if not parent then return end
			local circle = Instance.new("Frame", parent)
			circle.AnchorPoint = Vector2.new(0.5, 0.5); circle.Position = UDim2.new(x / CANVAS_W, 0, y / CANVAS_H, 0); circle.Size = UDim2.new(10 / CANVAS_W, 0, 10 / CANVAS_H, 0)
			circle.BackgroundTransparency = 1; circle.ZIndex = 65

			local stroke = Instance.new("UIStroke", circle)
			stroke.Color = RED_NEON; stroke.Thickness = 4; stroke.Transparency = 0; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

			local tInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(circle, tInfo, {Size = UDim2.new(120 / CANVAS_W, 0, 120 / CANVAS_H, 0)}):Play()
			TweenService:Create(stroke, tInfo, {Transparency = 1}):Play()
			Debris:AddItem(circle, 1.25)
		end)
	end
end

-- returns true if segment (x0,y0)-(x1,y1) intersects circle at (cx,cy) with radius r
local function segCircleHit(x0,y0,x1,y1,cx,cy,r)
	local vx, vy = x1-x0, y1-y0; local wx, wy = cx-x0, cy-y0
	local vv = vx*vx + vy*vy
	if vv <= 1e-6 then local dx, dy = cx-x0, cy-y0; return (dx*dx + dy*dy) <= r*r end
	local t = math.clamp((wx*vx + wy*vy) / vv, 0, 1)
	local px = x0 + vx*t; local py = y0 + vy*t
	local dx, dy = cx-px, cy-py; return (dx*dx + dy*dy) <= r*r
end

-- converts an absolute screen position to logical canvas coordinates
local function getLocalOnCanvas(absPos: Vector2)
	if not canvasRight then return nil end
	local ap = canvasRight.AbsolutePosition; local as = canvasRight.AbsoluteSize
	return ((absPos.X - ap.X) / as.X) * CANVAS_W, ((absPos.Y - ap.Y) / as.Y) * CANVAS_H
end

local function clampToCanvas(x,y) return math.clamp(x, 0, CANVAS_W), math.clamp(y, 0, CANVAS_H) end

local function sendCut(x0,y0,x1,y1)
	if SubmitMove then SubmitMove:FireServer({ kind = "cut", x0 = x0, y0 = y0, x1 = x1, y1 = y1 }) end
end

-- checks each live fruit for collision, triggers vfx and marks bad fruits as dying
local function applyHitVFXForSegment(x0,y0,x1,y1)
	if not canvasRight then return end
	local now = os.clock()
	local anyHit = false

	for id, d in pairs(fruitData) do
		local last = hitCooldown[id] or 0
		if (now - last) < 0.25 then continue end

		local isBad = BAD_ASSETS[d.asset] ~= nil
		local collisionRadius = d.r or FRUIT_R
		if isBad then collisionRadius = collisionRadius * 1.15 end

		if segCircleHit(x0,y0,x1,y1,d.x,d.y,collisionRadius) then
			hitCooldown[id] = now
			anyHit = true

			if not isBad then
				spawnGlowTrail(canvasRight, x0,y0,x1,y1, GREEN_NEON, 0.22)
			else
				spawnRedRippleEffect(canvasRight, d.x, d.y)
				playErrorSound1s()
				dyingFruits[id] = true
				if fruitUIs[id] then fruitUIs[id].Visible = false end

				local ghost = Instance.new("ImageLabel", canvasRight)
				ghost.Name = "GhostEnemy_"..id; ghost.Image = d.asset; ghost.BackgroundTransparency = 1
				ghost.Size = UDim2.new(FRUIT_SIZE / CANVAS_W, 0, FRUIT_SIZE / CANVAS_H, 0)
				ghost.Position = UDim2.new((d.x - FRUIT_R) / CANVAS_W, 0, (d.y - FRUIT_R) / CANVAS_H, 0); ghost.ZIndex = 9

				task.delay(1.2, function()
					if ghost and ghost.Parent then
						local t = TweenService:Create(ghost, TweenInfo.new(0.2), {ImageTransparency = 1})
						t:Play(); t.Completed:Connect(function() ghost:Destroy() end)
					end
					dyingFruits[id] = nil
				end)
			end
		end
	end
	if anyHit then playCutFruitSound1s() end
end

-- updates the side panel title and target fruit icons for the given level
local function applyLevelUI(level)
	currentLevelUI = level or 1
	if not sideTitleLabel then return end

	targetImg1.Visible = true; targetImg2.Visible = false; targetImg3.Visible = false

	if currentLevelUI == 5 then sideTitleLabel.Text = "PURE RED"; targetImg1.Image = GRAPES_ASSET; targetImg2.Image = R_APPLE_ASSET; targetImg3.Image = ORANGE_ASSET; targetImg2.Visible = true; targetImg3.Visible = true
	elseif currentLevelUI == 4 then sideTitleLabel.Text = "GREEN DETOX"; targetImg1.Image = CUCUMBER_ASSET; targetImg2.Image = G_APPLE_ASSET; targetImg3.Image = KIWI_ASSET; targetImg2.Visible = true; targetImg3.Visible = true
	elseif currentLevelUI == 3 then sideTitleLabel.Text = "TROPICAL"; targetImg1.Image = PINA_ASSET; targetImg2.Image = COCO_ASSET; targetImg3.Image = CEREZA_ASSET; targetImg2.Visible = true; targetImg3.Visible = true
	elseif currentLevelUI == 2 then sideTitleLabel.Text = "FRESA-BANANA"; targetImg1.Image = STRAW_ASSET; targetImg2.Image = BANANA_ASSET; targetImg2.Visible = true
	else sideTitleLabel.Text = "LEMONADE"; targetImg1.Image = LEMON_ASSET end
end

-- preloads an image sequence using dummy ImageLabels
local function preloadSeq(seq)
	local preloadObjs = {}
	for i = 1, #seq do local tmp = Instance.new("ImageLabel"); tmp.Image = seq[i]; table.insert(preloadObjs, tmp) end
	pcall(function() ContentProvider:PreloadAsync(preloadObjs) end)
	for _, o in ipairs(preloadObjs) do o:Destroy() end
end

-- creates a pulsing title label inside a transition overlay
local function makeTransitionTitle(parentOverlay, text)
	local title = Instance.new("TextLabel", parentOverlay)
	title.Name = "TransitionTitle"; title.BackgroundTransparency = 1; title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 8); title.Size = UDim2.new(1, -24, 0, 54); title.ZIndex = 520
	title.Text = text or ""; title.TextScaled = true; title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.new(1,1,1); title.TextTransparency = 1

	local stroke = Instance.new("UIStroke", title); stroke.Color = Color3.new(0,0,0); stroke.Thickness = 2; stroke.Transparency = 0.15
	local scale = Instance.new("UIScale", title); scale.Scale = 1

	TweenService:Create(title, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Scale = 1.06}):Play()
	return title
end

-- cross-fades through an image sequence as a full-screen overlay, then calls onDone
local function playImageSequenceTransition(seq, overlayName, perImage, titleText, onDone)
	if not gameFrame or not gameFrame.Parent then if onDone then onDone() end return end
	if type(seq) ~= "table" or #seq == 0 then if onDone then onDone() end return end

	isTransitioning = true; cutDown = false; lastCutPoint = nil
	preloadSeq(seq)

	local PER_IMAGE = perImage or 0.46
	local FADE = math.min(0.10, PER_IMAGE * 0.25)
	local HOLD = math.max(0.02, PER_IMAGE - FADE)

	local overlay = Instance.new("Frame", gameFrame)
	overlay.Name = overlayName or "Transition"; overlay.Active = true; overlay.Selectable = true; overlay.BackgroundColor3 = Color3.new(0,0,0)
	overlay.BackgroundTransparency = 0; overlay.Position = UDim2.new(0, 0, 30/390, 0); overlay.Size = UDim2.new(1, 0, 360/390, 0); overlay.ZIndex = 500

	local aiBox = Instance.new("Frame", overlay)
	aiBox.Name = "AIBox"; aiBox.BackgroundColor3 = Color3.new(0,0,0); aiBox.BorderSizePixel = 0; aiBox.Size = UDim2.fromScale(0.2, 0.2)
	aiBox.AnchorPoint = Vector2.new(1, 1); aiBox.Position = UDim2.new(1, 0, 1, 0); aiBox.ZIndex = 550

	makeTransitionTitle(overlay, titleText)

	local function makeImg(name, z)
		local img = Instance.new("ImageLabel", overlay)
		img.Name = name; img.BackgroundTransparency = 1; img.Position = UDim2.new(0,0,0,0)
		img.Size = UDim2.new(1,0,1,0); img.ScaleType = Enum.ScaleType.Fit; img.ImageTransparency = 1; img.ZIndex = z
		return img
	end

	local front = makeImg("Front", 501); local back = makeImg("Back", 502)
	front.Image = seq[1]; front.ImageTransparency = 0; back.ImageTransparency = 1

	task.spawn(function()
		task.wait(HOLD)
		for i = 2, #seq do
			back.Image = seq[i]; back.ImageTransparency = 1
			local tIn  = TweenService:Create(back,  TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0})
			local tOut = TweenService:Create(front, TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1})
			tIn:Play(); tOut:Play()
			task.wait(FADE); front, back = back, front; task.wait(HOLD)
		end
		if overlay and overlay.Parent then overlay:Destroy() end
		isTransitioning = false
		if onDone then onDone() end
	end)
end

-- plays the correct juice-making transition for the level that was just completed
local function playTransitionForLevel(levelCompleted, onDone)
	if levelCompleted == 5 then playImageSequenceTransition(PURERED_SEQ, "PureRedTransition", 0.46, "PURE RED JUICE", onDone)
	elseif levelCompleted == 4 then playImageSequenceTransition(DETOX_SEQ, "DetoxTransition", 0.46, "GREEN DETOX JUICE", onDone)
	elseif levelCompleted == 3 then playImageSequenceTransition(TROPICAL_SEQ, "TropicalTransition", 0.46, "TROPICAL JUICE", onDone)
	elseif levelCompleted == 2 then playImageSequenceTransition(FREBAN_SEQ, "FreBanTransition", 0.46, "STRAWBERRY-BANANA JUICE", onDone)
	else playImageSequenceTransition(LEMONADE_SEQ, "LemonadeTransition", 0.46, "LEMONADE JUICE", onDone) end
end

-- shows a centered loading card with an animated pulsing dot
local function showLoadingOverlay(parentGui, text)
	local overlay = Instance.new("Frame", parentGui)
	overlay.Name = "JuicePreloadOverlay"; overlay.AnchorPoint = Vector2.new(0.5,0.5); overlay.Position = UDim2.new(0.5,0,0.5,0); overlay.Size = UDim2.new(0.6, 0, 0.4, 0)
	overlay.BackgroundColor3 = V.Mid; overlay.BackgroundTransparency = 0; overlay.BorderSizePixel = 0; overlay.ZIndex = 999

	Instance.new("UIAspectRatioConstraint", overlay).AspectRatio = 420 / 200
	Instance.new("UISizeConstraint", overlay).MaxSize = Vector2.new(630, 300)
	Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 14)
	addGlassEffectToFrame(overlay)

	local lbl = Instance.new("TextLabel", overlay)
	lbl.Size = UDim2.new(1,-40,1,-40); lbl.Position = UDim2.fromOffset(20,20); lbl.BackgroundTransparency = 1
	lbl.Text = text or "LOADING..."; lbl.Font = Enum.Font.GothamBlack; lbl.TextScaled = true; lbl.TextColor3 = Color3.new(1,1,1); lbl.ZIndex = overlay.ZIndex + 1

	local dot = Instance.new("Frame", overlay)
	dot.Size = UDim2.fromOffset(10,10); dot.Position = UDim2.new(0.5,0,1,-20); dot.AnchorPoint = Vector2.new(0.5,1)
	dot.BackgroundColor3 = Color3.new(1,1,1); dot.BorderSizePixel = 0; dot.ZIndex = overlay.ZIndex + 1
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

	task.spawn(function()
		while overlay.Parent do
			TweenService:Create(dot, TweenInfo.new(0.6), {Size = UDim2.fromOffset(3,3), BackgroundTransparency = 0.5}):Play()
			task.wait(0.6)
			TweenService:Create(dot, TweenInfo.new(0.6), {Size = UDim2.fromOffset(10,10), BackgroundTransparency = 0.0}):Play()
			task.wait(0.6)
		end
	end)
	return overlay
end

-- starts a cut gesture from canvas coordinates
local function beginCutLogical(x, y)
	if not inGame or not canvasRight or isTransitioning then return end
	x, y = clampToCanvas(x, y)
	cutDown = true; lastCutPoint = Vector2.new(x, y); lastSendT = 0
end

-- continues a cut gesture, spawns trail vfx, and throttles server sends to ~60 hz
local function moveCutLogical(x, y)
	if not inGame or not canvasRight or not cutDown or not lastCutPoint or isTransitioning then return end
	x, y = clampToCanvas(x, y)
	local p = Vector2.new(x, y); local d = (p - lastCutPoint).Magnitude
	if d < 10 then return end
	spawnGlowTrail(canvasRight, lastCutPoint.X, lastCutPoint.Y, p.X, p.Y, BLUE_NEON, 0.18)
	applyHitVFXForSegment(lastCutPoint.X, lastCutPoint.Y, p.X, p.Y)
	local t = os.clock()
	if (t - lastSendT) > (1/60) then sendCut(lastCutPoint.X, lastCutPoint.Y, p.X, p.Y); lastSendT = t end
	lastCutPoint = p
end

local function endCutLogical() cutDown = false; lastCutPoint = nil end

local function wipeFruitVisuals()
	for _, ui in pairs(fruitUIs) do if ui and ui.Parent then ui:Destroy() end end
	fruitUIs = {}; fruitData = {}; hitCooldown = {}; dyingFruits = {}
end

local function createHudExitButton(parentFrame)
	if hudExitBtn and hudExitBtn.Parent then hudExitBtn:Destroy() end
	hudExitBtn = Instance.new("TextButton", parentFrame); hudExitBtn.Name = "HudExitBtn"; hudExitBtn.AnchorPoint = Vector2.new(1,0); hudExitBtn.Position = UDim2.new(0.98, 0, 2/390, 0)
	hudExitBtn.Size = UDim2.new(0.15, 0, 26/390, 0); hudExitBtn.BackgroundColor3 = V.Darker; hudExitBtn.Text = "EXIT"; hudExitBtn.TextColor3 = Color3.new(1,1,1); hudExitBtn.TextScaled = true; hudExitBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudExitBtn).CornerRadius = UDim.new(0, 8)
	hudExitBtn.MouseButton1Click:Connect(function()
		local configJuice = _G.JuiceCutterConfig
		if inGame and configJuice then
			playSound(selectSound)
			if gameGui then gameGui:Destroy(); gameGui = nil end
			wipeFruitVisuals()
			inGame = false
			UniversalController.LimpiarControles()
			Menu1to7.AbrirMenuPrincipal(configJuice)
		end
	end)
end

local function updateMuteButtonVisuals(btn)
	if not btn then return end
	if soundEnabled then btn.BackgroundColor3 = V.Accent; btn.Text = "🔊 ON" else btn.BackgroundColor3 = Color3FromHex("666666"); btn.Text = "🔇 MUTED" end
end

local function createMuteButton(parentFrame)
	if hudMuteBtn and hudMuteBtn.Parent then hudMuteBtn:Destroy() end
	hudMuteBtn = Instance.new("TextButton", parentFrame); hudMuteBtn.Name = "HudMuteBtn"; hudMuteBtn.AnchorPoint = Vector2.new(1, 0); hudMuteBtn.Position = UDim2.new(0.82, 0, 2/390, 0)
	hudMuteBtn.Size = UDim2.new(0.20, 0, 26/390, 0); hudMuteBtn.TextColor3 = Color3.new(1,1,1); hudMuteBtn.TextScaled = true; hudMuteBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", hudMuteBtn).CornerRadius = UDim.new(0, 8)
	updateMuteButtonVisuals(hudMuteBtn)
	hudMuteBtn.MouseButton1Click:Connect(function()
		soundEnabled = not soundEnabled; updateMuteButtonVisuals(hudMuteBtn)
		if ToggleAudio then ToggleAudio:FireServer(soundEnabled) end
		if soundEnabled then playSound(selectSound) end
	end)
end

-- builds the entire game ui: score bar, side panel, canvas, and virtual cursor
local function initJuiceCutterGui()
	if gameGui then gameGui:Destroy() end
	wipeFruitVisuals()

	gameGui = Instance.new("ScreenGui", playerGui); gameGui.Name = "JuiceCutterGameGui"; gameGui.ResetOnSpawn = false; gameGui.IgnoreGuiInset = true; gameGui.DisplayOrder = 50
	gameFrame = Instance.new("Frame", gameGui); gameFrame.AnchorPoint = Vector2.new(0.5, 0.5); gameFrame.Position = UDim2.new(0.5, 0, 0.5, 0); gameFrame.Size = UDim2.new(0.85, 0, 0.85, 0)
	gameFrame.BackgroundColor3 = V.Lightest; gameFrame.BorderSizePixel = 0; gameFrame.ZIndex = 1; gameFrame.ClipsDescendants = true

	local aspectRatio = Instance.new("UIAspectRatioConstraint", gameFrame)
	aspectRatio.AspectRatio = GAME_W / GAME_H
	local sizeLim = Instance.new("UISizeConstraint", gameFrame)
	sizeLim.MaxSize = Vector2.new(960, 780)

	Instance.new("UICorner", gameFrame).CornerRadius = UDim.new(0, 10); addGlassEffectToFrame(gameFrame)

	scoreLabel = Instance.new("TextLabel", gameFrame); scoreLabel.Name = "ScoreLabel"; scoreLabel.Size = UDim2.new(1, -170, 30/390, 0); scoreLabel.Position = UDim2.new(0, 8, 0, 0)
	scoreLabel.BackgroundTransparency = 1; scoreLabel.TextColor3 = V.Darkest; scoreLabel.TextScaled = true; scoreLabel.TextXAlignment = Enum.TextXAlignment.Left; scoreLabel.Font = Enum.Font.GothamBold; scoreLabel.Text = "Score: 0"
	createHudExitButton(gameFrame); createMuteButton(gameFrame)

	sidePanel = Instance.new("Frame", gameFrame); sidePanel.Name = "SidePanel"; sidePanel.Position = UDim2.new(0, 0, 30/390, 0); sidePanel.Size = UDim2.new(100/480, 0, 360/390, 0)
	sidePanel.BackgroundTransparency = 1; sidePanel.BorderSizePixel = 0; sidePanel.ZIndex = 2

	local sideBGContainer = Instance.new("Frame", sidePanel); sideBGContainer.Name = "BGContainer"; sideBGContainer.Size = UDim2.new(1,0,1,0); sideBGContainer.ZIndex = 1; sideBGContainer.BorderSizePixel = 0
	local bgLayout = Instance.new("UIListLayout", sideBGContainer); bgLayout.SortOrder = Enum.SortOrder.LayoutOrder; bgLayout.FillDirection = Enum.FillDirection.Vertical
	local bgColors = {Color3FromHex("#082f49"), Color3FromHex("#0c4a6e"), Color3FromHex("#0369a1"), Color3FromHex("#7dd3fc")}
	for i, color in ipairs(bgColors) do
		local strip = Instance.new("Frame", sideBGContainer); strip.Name = "Strip"..i; strip.BackgroundColor3 = color; strip.Size = UDim2.new(1, 0, 0.25, 0); strip.BorderSizePixel = 0; strip.LayoutOrder = i
	end

	local stroke = Instance.new("UIStroke", sidePanel); stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Color = V.Mid; stroke.Thickness = 2; stroke.Transparency = 0

	local sideContent = Instance.new("Frame", sidePanel); sideContent.Name = "SideContent"; sideContent.BackgroundTransparency = 1; sideContent.Position = UDim2.new(0,0,0,0); sideContent.Size = UDim2.new(1,0,1,-110); sideContent.ZIndex = 3
	local sideLayout = Instance.new("UIListLayout", sideContent); sideLayout.FillDirection = Enum.FillDirection.Vertical; sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; sideLayout.SortOrder = Enum.SortOrder.LayoutOrder; sideLayout.Padding = UDim.new(0, 5)
	Instance.new("UIPadding", sideContent).PaddingTop = UDim.new(0, 8)

	sideTitleLabel = Instance.new("TextLabel", sideContent); sideTitleLabel.BackgroundTransparency = 1; sideTitleLabel.Size = UDim2.new(0.9, 0, 0, 24)
	sideTitleLabel.Text = "LEMONADE"; sideTitleLabel.TextScaled = true; sideTitleLabel.TextColor3 = V.Mid; sideTitleLabel.Font = Enum.Font.GothamBlack; sideTitleLabel.LayoutOrder = 1; sideTitleLabel.ZIndex = 3

	targetImg1 = Instance.new("ImageLabel", sideContent); targetImg1.BackgroundTransparency = 1; targetImg1.Size = UDim2.fromScale(0.6, 0.6); Instance.new("UIAspectRatioConstraint", targetImg1); targetImg1.Image = LEMON_ASSET; targetImg1.LayoutOrder = 2; targetImg1.ZIndex = 3
	targetImg2 = Instance.new("ImageLabel", sideContent); targetImg2.BackgroundTransparency = 1; targetImg2.Size = UDim2.fromScale(0.6, 0.6); Instance.new("UIAspectRatioConstraint", targetImg2); targetImg2.Image = BANANA_ASSET; targetImg2.LayoutOrder = 3; targetImg2.ZIndex = 3; targetImg2.Visible = false
	targetImg3 = Instance.new("ImageLabel", sideContent); targetImg3.BackgroundTransparency = 1; targetImg3.Size = UDim2.fromScale(0.6, 0.6); Instance.new("UIAspectRatioConstraint", targetImg3); targetImg3.Image = CEREZA_ASSET; targetImg3.LayoutOrder = 4; targetImg3.ZIndex = 3; targetImg3.Visible = false

	sidePreviewImage = Instance.new("ImageLabel", sidePanel); sidePreviewImage.Name = "SidePreview"; sidePreviewImage.BackgroundTransparency = 1; sidePreviewImage.Image = SIDE_PREVIEW_FIXED
	sidePreviewImage.Size = UDim2.new(0.8, 0, 0.28, 0); sidePreviewImage.AnchorPoint = Vector2.new(0.5, 1); sidePreviewImage.Position = UDim2.new(0.5, 0, 1, -6); sidePreviewImage.ZIndex = 4

	canvasRight = Instance.new("Frame", gameFrame); canvasRight.Name = "CanvasRight"; canvasRight.Position = UDim2.new(100/480, 0, 30/390, 0); canvasRight.Size = UDim2.new(380/480, 0, 360/390, 0)
	canvasRight.BackgroundTransparency = 1; canvasRight.BorderSizePixel = 0; canvasRight.ZIndex = 2; canvasRight.ClipsDescendants = true

	local gameBG = Instance.new("ImageLabel", canvasRight); gameBG.Name = "GameBackground"; gameBG.Image = GAME_BG_TEXTURE; gameBG.Size = UDim2.new(1, 0, 1, 0); gameBG.ZIndex = 1; gameBG.ScaleType = Enum.ScaleType.Crop; gameBG.ImageTransparency = 0.35

	-- small dot that shows where the gamepad joystick is aiming
	virtualCursorUI = Instance.new("Frame", canvasRight); virtualCursorUI.Name = "VirtualCursor"; virtualCursorUI.Size = UDim2.fromOffset(12, 12); virtualCursorUI.AnchorPoint = Vector2.new(0.5, 0.5)
	virtualCursorUI.BackgroundColor3 = GREEN_NEON; virtualCursorUI.ZIndex = 100; virtualCursorUI.Visible = false
	Instance.new("UICorner", virtualCursorUI).CornerRadius = UDim.new(1, 0)
	local vcStroke = Instance.new("UIStroke", virtualCursorUI); vcStroke.Color = Color3.new(1,1,1); vcStroke.Thickness = 2

	applyLevelUI(currentLevelUI)
end

-- removes ui entries for fruit ids that are no longer alive on the server
local function clearMissingFruits(aliveIds)
	for id, ui in pairs(fruitUIs) do
		if not aliveIds[id] and not dyingFruits[id] then
			if ui and ui.Parent then ui:Destroy() end; fruitUIs[id] = nil; fruitData[id] = nil
		end
	end
end

-- syncs fruit positions, score, and lives to the latest server state
local function renderState(state)
	if not inGame or isTransitioning then return end
	if not gameGui or not gameGui.Parent then initJuiceCutterGui() end
	if not state then return end

	local lvl = tonumber(state.level) or currentLevelUI
	if lvl ~= currentLevelUI then applyLevelUI(lvl); wipeFruitVisuals() end
	local s = tonumber(state.score) or 0; local lives = tonumber(state.lives) or 0
	local cutGood = tonumber(state.cutGood) or 0; local goal = tonumber(state.goal) or 0
	if scoreLabel then scoreLabel.Text = ("Lv%d | Score: %d    |    Lives: %d    |    %d/%d"):format(lvl, s, lives, cutGood, goal) end

	if state.fruits and canvasRight then
		local alive = {}
		for _, f in ipairs(state.fruits) do
			local id = tonumber(f.id)
			if dyingFruits[id] then alive[id] = true continue end

			if id then
				alive[id] = true
				local ui = fruitUIs[id]
				if not ui or not ui.Parent then
					ui = Instance.new("ImageLabel", canvasRight); ui.Name = "Fruit_"..id; ui.BackgroundTransparency = 1; ui.ZIndex = 10; fruitUIs[id] = ui
				else if ui.Parent ~= canvasRight then ui.Parent = canvasRight end end
				local x = tonumber(f.x) or 0; local y = tonumber(f.y) or 0; local asset = tostring(f.asset or ""); local rot = tonumber(f.rot) or 0

				ui.Size = UDim2.new(FRUIT_SIZE / CANVAS_W, 0, FRUIT_SIZE / CANVAS_H, 0); ui.Image = asset; ui.Rotation = rot;
				ui.Position = UDim2.new((x - FRUIT_R) / CANVAS_W, 0, (y - FRUIT_R) / CANVAS_H, 0)
				ui.Visible = ((y + FRUIT_R) <= CANVAS_H)
				fruitData[id] = { x = x, y = y, r = FRUIT_R, asset = asset }
			end
		end
		clearMissingFruits(alive)
	end
end

-- preloads all assets on first play, then starts the game session
local function startMainGame()
	if not didPreloadOnce then
		local tempGui = Instance.new("ScreenGui", playerGui)
		local overlay = showLoadingOverlay(tempGui, "LOADING...")
		local t0 = os.clock()

		local bucket = Instance.new("Folder", overlay); bucket.Name = "PreloadBucket"
		local bgDummy = Instance.new("ImageLabel", overlay); bgDummy.Image = GAME_BG_TEXTURE; bgDummy.Size = UDim2.fromScale(1,1); bgDummy.BackgroundTransparency = 1; bgDummy.ImageTransparency = 0.99; bgDummy.ZIndex = 1

		local function mkImg(id) local i = Instance.new("ImageLabel", bucket); i.Image = id; i.BackgroundTransparency = 1; i.Size = UDim2.fromOffset(1,1); i.Visible = false; return i end
		local function mkSnd(id) local s = Instance.new("Sound", bucket); s.SoundId = id; s.Volume = 0; return s end

		mkImg(SIDE_PREVIEW_FIXED)
		for _, id in ipairs(LEMONADE_SEQ) do mkImg(id) end
		for _, id in ipairs(FREBAN_SEQ) do mkImg(id) end
		for _, id in ipairs(TROPICAL_SEQ) do mkImg(id) end
		for _, id in ipairs(DETOX_SEQ) do mkImg(id) end
		for _, id in ipairs(PURERED_SEQ) do mkImg(id) end
		for id, _ in pairs(GOOD_ASSETS) do mkImg(id) end
		for id, _ in pairs(BAD_ASSETS) do mkImg(id) end
		mkSnd(SELECT_SOUND_ID); mkSnd(CUT_FRUIT_SOUND_ID); mkSnd(ERROR_SOUND_ID)

		pcall(function() ContentProvider:PreloadAsync(bucket:GetChildren()) end)
		pcall(function() ContentProvider:PreloadAsync({bgDummy}) end)

		local elapsed = os.clock() - t0
		local remain  = math.max(0, 4 - elapsed)
		if remain > 0 then task.wait(remain) end

		tempGui:Destroy()
		didPreloadOnce = true
	end

	inGame = true
	initJuiceCutterGui()
	applyLevelUI(1)

	virtualCursorPos = Vector2.new(CANVAS_W / 2, CANVAS_H / 2)
	gamepadJoystickVec = Vector2.new(0, 0)
	isGamepadCutting = false

	UniversalController.CrearControlesJuiceCutter(
		function(vec)
			gamepadJoystickVec = vec
		end,
		function(actionName, inputState, inputObject)
			local isGamepad = (inputObject.UserInputType == Enum.UserInputType.Gamepad1) or (inputObject.KeyCode == Enum.KeyCode.ButtonR2) or (inputObject.KeyCode == Enum.KeyCode.ButtonA)

			if isGamepad then
				if inputState == Enum.UserInputState.Begin then
					isGamepadCutting = true
					beginCutLogical(virtualCursorPos.X, virtualCursorPos.Y)
				elseif inputState == Enum.UserInputState.End then
					isGamepadCutting = false
					endCutLogical()
				end
			else
				local pos = (inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.MouseMovement) and UserInputService:GetMouseLocation() or Vector2.new(inputObject.Position.X, inputObject.Position.Y)
				if inputState == Enum.UserInputState.Begin then
					local x, y = getLocalOnCanvas(pos)
					if x then beginCutLogical(x, y) end
				elseif inputState == Enum.UserInputState.Change then
					local x, y = getLocalOnCanvas(pos)
					if x then moveCutLogical(x, y) end
				elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
					endCutLogical()
				end
			end
			return Enum.ContextActionResult.Pass
		end
	)

	if StartRequest then StartRequest:FireServer({level = 1, restart = true}) end
end

local configJuiceCutter = {
	Titulo = "JUICE CUTTER",
	IconoPrincipal = "🍑",
	ColorFondo = "faf5ff",
	ColorBtnPlay = "9333ea",
	ColorBtnVip = "7e22ce",
	ColorBtnExit = "581c87",
	IconosBotones = { Play = "🎮", Vip = "👑", Exit = "🚪" },
	Donaciones = DONATION_PRODUCTS,
	Controlador = UniversalController,
	OnPlay = function()
		startMainGame()
	end,
	OnExit = function()
		inGame = false
	end
}
_G.JuiceCutterConfig = configJuiceCutter

ToggleAudio.OnClientEvent:Connect(function(isEnabled)
	soundEnabled = isEnabled
	if hudMuteBtn then updateMuteButtonVisuals(hudMuteBtn) end
end)

GameState.OnClientEvent:Connect(function(mode, data)
	if mode == "Start" then
		if data.audioEnabled ~= nil then soundEnabled = data.audioEnabled; if hudMuteBtn then updateMuteButtonVisuals(hudMuteBtn) end end
		applyLevelUI(tonumber(data.level) or 1); wipeFruitVisuals()
	elseif mode == "Update" then
		if inGame then renderState(data) end
	elseif mode == "LevelComplete" then
		endCutLogical(); wipeFruitVisuals()
		local lvlDone = tonumber(data and data.level) or currentLevelUI
		local nextLevel = tonumber(data and data.nextLevel) or (lvlDone + 1)
		isTransitioning = true
		playTransitionForLevel(lvlDone, function()
			isTransitioning = false; applyLevelUI(nextLevel); wipeFruitVisuals()
			if StartRequest then StartRequest:FireServer({level = nextLevel, continue = true}) end
		end)
	elseif mode == "End" then
		inGame = false; endCutLogical(); wipeFruitVisuals()
		UniversalController.LimpiarControles()
		if gameGui then gameGui:Destroy(); gameGui = nil end

		local perfect = (data and data.perfect == true)
		local lvlEnd = tonumber(data and data.level) or currentLevelUI

		if perfect then
			isTransitioning = true
			playTransitionForLevel(lvlEnd, function()
				isTransitioning = false
				Menu1to7.AbrirGameOver(data.score, true)
			end)
		else
			Menu1to7.AbrirGameOver(data.score, false)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if UniversalController.EsBotonAtras(input) and inGame then
		playSound(selectSound)
		if gameGui then gameGui:Destroy(); gameGui = nil end
		wipeFruitVisuals()
		inGame = false
		UniversalController.LimpiarControles()
		Menu1to7.AbrirMenuPrincipal(configJuiceCutter)
	end
end)

-- moves the virtual gamepad cursor and triggers cuts when the stick is active
RunService.RenderStepped:Connect(function(dt)
	if not inGame or isTransitioning then return end
	if gamepadJoystickVec.Magnitude > 0.05 then
		if virtualCursorUI then virtualCursorUI.Visible = true end
		local moveDelta = gamepadJoystickVec * VIRTUAL_CURSOR_SPEED * dt
		virtualCursorPos = virtualCursorPos + moveDelta
		virtualCursorPos = Vector2.new(math.clamp(virtualCursorPos.X, 0, CANVAS_W), math.clamp(virtualCursorPos.Y, 0, CANVAS_H))
		if virtualCursorUI then virtualCursorUI.Position = UDim2.new(virtualCursorPos.X / CANVAS_W, 0, virtualCursorPos.Y / CANVAS_H, 0) end
		if isGamepadCutting then moveCutLogical(virtualCursorPos.X, virtualCursorPos.Y) end
	else
		if not isGamepadCutting and virtualCursorUI then virtualCursorUI.Visible = false end
	end
end)

OpenArcadeMenu.OnClientEvent:Connect(function(gameName)
	if gameName == "JuiceCutter" and not inGame then
		Menu1to7.AbrirMenuPrincipal(configJuiceCutter)
	end
end)
