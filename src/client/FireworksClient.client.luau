local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local GuiService        = game:GetService("GuiService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")

local FireworksModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FireworksModule"))
local Renderer        = require(script.Parent:WaitForChild("FireworksRenderer"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteFolder = ReplicatedStorage:WaitForChild(FireworksModule.RemoteFolderName)
local rRequest = remoteFolder:WaitForChild(FireworksModule.Remotes.RequestLaunch)
local rOpen    = remoteFolder:WaitForChild(FireworksModule.Remotes.OpenMenu)
local rPlay    = remoteFolder:WaitForChild(FireworksModule.Remotes.PlayFirework)
local rNotify  = remoteFolder:WaitForChild("Notify")        -- inventory / reward messages
local rAvail   = remoteFolder:WaitForChild("Availability")  -- which types are launchable

local COL_BG    = Color3.fromRGB(8, 14, 22)
local COL_PANEL = Color3.fromRGB(16, 22, 14)
local COL_NEON  = Color3.fromRGB(154, 230, 0)
local COL_TEXT  = Color3.fromRGB(216, 249, 153)
local COL_GREY  = Color3.fromRGB(150, 150, 150)
local COL_RED   = Color3.fromRGB(255, 90, 80)

-- Camera tuning. Smaller numbers = closer camera; heights are studs off ground.
local CAM = {
	-- normal fireworks (1-16): chase the rising shell, then pull back
	GROUND_FOLLOW   = Vector3.new(16, 6, 16), -- offset from the rising shell
	GROUND_WIDE     = 70,                      -- pull-back distance on explosion
	GROUND_HEIGHT   = 0.35,                    -- pull-back height factor

	-- comet (Tony): low ground camera that pans to follow it
	COMET_BACK      = 60,
	COMET_HEIGHT    = 12,

	-- mega (Steamboat): low back camera framing the dome
	MEGA_BACK       = 110,
	MEGA_HEIGHT     = 28,
}

-- Total seconds a firework's whole animation lasts, from launch to fully done.
-- The camera returns ~0.3s after this and the menu ~0.6s after (both < 1.5s).
local function showTime(def)
	local k = def.kind
	if k == "comet" then return 8.5
	elseif k == "mega" then return 9.5
	elseif k == "explosion" then return 18.0
	elseif k == "salute" then return 1.8
	elseif k == "mine" then return (def.lifetime or 1.6) + 0.8
	else return (def.lifetime or 2) + 2.0 end  -- burst / crossette / ring
end

local camBusy = false

local function playCinematic(origin, def, tracker)
	if camBusy then return end
	camBusy = true
	local cam = workspace.CurrentCamera
	local prevType = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local kind = def.kind
	local sky = (kind == "comet" or kind == "mega" or kind == "explosion")

	-- ground camera params 
	local back   = (kind == "comet") and CAM.COMET_BACK or CAM.MEGA_BACK
	local height = (kind == "comet") and CAM.COMET_HEIGHT or CAM.MEGA_HEIGHT
	local groundPos = origin + Vector3.new(0, height, -back)

	-- Phase 1: follow the projectile until it explodes
	local followConn
	followConn = RunService.RenderStepped:Connect(function()
		if tracker.exploded then return end
		local p = tracker.part
		if p and p.Parent then
			if sky then
				cam.CFrame = CFrame.lookAt(groundPos, p.Position)
			else
				cam.CFrame = CFrame.lookAt(p.Position + CAM.GROUND_FOLLOW, p.Position)
			end
		end
	end)

	-- Phase 2: frame the burst once it explodes
	task.spawn(function()
		local t = os.clock()
		while not tracker.exploded and (os.clock() - t) < 6 do RunService.RenderStepped:Wait() end
		if followConn then followConn:Disconnect(); followConn = nil end
		local center = tracker.explodePos or origin
		local wideCF
		if sky then
			wideCF = CFrame.lookAt(groundPos, center)
		else
			local d = CAM.GROUND_WIDE
			wideCF = CFrame.lookAt(center + Vector3.new(d, d * CAM.GROUND_HEIGHT, d), center)
		end
		TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = wideCF,
		}):Play()
	end)

	-- Phase 3: guaranteed return after the whole show ends (< 1.5s after)
	task.spawn(function()
		RunService.RenderStepped:Wait()  -- let Renderer.Play set tracker.degraded
		local hold = tracker.degraded and 2.0 or (showTime(def) + 0.3)
		local remaining = hold - (os.clock() - t0)
		if remaining > 0 then task.wait(remaining) end
		if followConn then followConn:Disconnect(); followConn = nil end
		cam.CameraType = prevType
		camBusy = false
	end)
end


local menuGui, optionButtons, menuOpen = nil, {}, false
local optionMeta = {}   -- id -> { nameLbl, swatch, stroke, special } for greying
local navList    = {}   -- ordered { btn, action } for keyboard/gamepad navigation
local navIndex   = 1
local availability = {} -- id -> bool (sent by the server)
local openMenu          -- forward declaration (selectFirework schedules a re-show)
local applyAvailability -- forward declaration
local reshowToken = 0   -- bumped on every close so stale re-shows are cancelled

local PANEL_SIZE = UDim2.fromScale(0.4, 0.85)

local function closeMenu()
	if not menuOpen then return end
	menuOpen = false
	reshowToken += 1  -- cancel any pending auto re-show
	ContextActionService:UnbindAction("FwMenuNav")
	GuiService.SelectedObject = nil
	if menuGui then
		local panel = menuGui:FindFirstChild("Panel")
		if panel then TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(0, 0) }):Play() end
		task.delay(0.2, function() if menuGui then menuGui.Enabled = false end end)
	end
end

local function selectFirework(index)
	local btn = optionButtons[index]
	if btn then
		btn.BackgroundColor3 = COL_NEON
		TweenService:Create(btn, TweenInfo.new(0.25), { BackgroundColor3 = COL_BG }):Play()
	end
	rRequest:FireServer(index)
	closeMenu()

	local def = FireworksModule.Types[index]
	reshowToken += 1
	local myToken = reshowToken
	task.delay((def and showTime(def) or 4) + 0.6, function()
		if myToken == reshowToken and not menuOpen then openMenu() end
	end)
end

local function buildMenu()
	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "FireworksMenu"; menuGui.DisplayOrder = 60
	menuGui.IgnoreGuiInset = true; menuGui.ResetOnSpawn = false; menuGui.Enabled = false
	menuGui.Parent = playerGui

	-- Centered panel. It hides itself when you pick an option and pops back
	local panel = Instance.new("Frame", menuGui)
	panel.Name = "Panel"; panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5); panel.Size = UDim2.fromScale(0.4, 0.85)
	panel.BackgroundColor3 = COL_PANEL; panel.BackgroundTransparency = 0.12
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0.03, 0)
	local pStroke = Instance.new("UIStroke", panel); pStroke.Color = COL_NEON; pStroke.Thickness = 2; pStroke.Transparency = 0.2
	local ar = Instance.new("UIAspectRatioConstraint", panel); ar.AspectRatio = 0.62

	local title = Instance.new("TextLabel", panel)
	title.Size = UDim2.fromScale(0.78, 0.085); title.Position = UDim2.fromScale(0.46, 0.06)
	title.AnchorPoint = Vector2.new(0.5, 0.5); title.BackgroundTransparency = 1
	title.Text = "CHOOSE A FIREWORK"; title.Font = Enum.Font.GothamBlack
	title.TextScaled = true; title.TextColor3 = COL_NEON
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- close button
	local closeBtn = Instance.new("TextButton", panel)
	closeBtn.Name = "Close"; closeBtn.Size = UDim2.fromScale(0.1, 0.06)
	closeBtn.Position = UDim2.fromScale(0.93, 0.06); closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	closeBtn.BackgroundColor3 = COL_BG; closeBtn.BackgroundTransparency = 0.2
	closeBtn.Text = "X"; closeBtn.Font = Enum.Font.GothamBlack; closeBtn.TextScaled = true
	closeBtn.TextColor3 = COL_RED; closeBtn.Selectable = true
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.3, 0)
	local cAR = Instance.new("UIAspectRatioConstraint", closeBtn); cAR.AspectRatio = 1
	local cStroke = Instance.new("UIStroke", closeBtn); cStroke.Color = COL_RED; cStroke.Transparency = 0.3
	closeBtn.Activated:Connect(closeMenu)

	local list = Instance.new("ScrollingFrame", panel)
	list.Size = UDim2.fromScale(0.9, 0.70); list.Position = UDim2.fromScale(0.5, 0.50)
	list.AnchorPoint = Vector2.new(0.5, 0.5); list.BackgroundTransparency = 1; list.BorderSizePixel = 0
	list.ScrollBarThickness = 5; list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout", list)
	layout.Padding = UDim.new(0, 6); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	for _, def in ipairs(FireworksModule.Types) do
		local special = (def.kind == "comet" or def.kind == "mega")
		local btn = Instance.new("TextButton", list)
		btn.Name = "Opt_" .. def.id
		btn.Size = UDim2.new(1, -10, 0, 64)
		btn.BackgroundColor3 = COL_BG; btn.BackgroundTransparency = 0.2
		btn.Text = ""; btn.AutoButtonColor = true; btn.LayoutOrder = def.id; btn.Selectable = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0.16, 0)
		local bStroke = Instance.new("UIStroke", btn)
		bStroke.Color = special and def.swatch or COL_NEON
		bStroke.Thickness = special and 3 or 1.5; bStroke.Transparency = 0.25
		local pad = Instance.new("UIPadding", btn)
		pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)

		local swatch = Instance.new("Frame", btn)
		swatch.Size = UDim2.fromScale(0.13, 1); swatch.BackgroundColor3 = def.swatch; swatch.BorderSizePixel = 0
		Instance.new("UICorner", swatch).CornerRadius = UDim.new(0.3, 0)
		local sAR = Instance.new("UIAspectRatioConstraint", swatch); sAR.AspectRatio = 1
		local num = Instance.new("TextLabel", swatch)
		num.Size = UDim2.fromScale(1, 1); num.BackgroundTransparency = 1; num.Text = tostring(def.id)
		num.Font = Enum.Font.GothamBlack; num.TextScaled = true; num.TextColor3 = Color3.new(0, 0, 0)
		local nPad = Instance.new("UIPadding", num); nPad.PaddingTop = UDim.new(0.22, 0); nPad.PaddingBottom = UDim.new(0.22, 0)

		-- name only (no description shown)
		local nameLbl = Instance.new("TextLabel", btn)
		nameLbl.Size = UDim2.fromScale(0.8, 0.6); nameLbl.Position = UDim2.fromScale(0.17, 0.5)
		nameLbl.AnchorPoint = Vector2.new(0, 0.5)
		nameLbl.BackgroundTransparency = 1; nameLbl.Text = def.name
		nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextScaled = true
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextColor3 = special and def.swatch or COL_TEXT

		btn.Activated:Connect(function() selectFirework(def.id) end)
		optionButtons[def.id] = btn
		optionMeta[def.id] = { nameLbl = nameLbl, swatch = swatch, stroke = bStroke,
			baseColor = special and def.swatch or COL_TEXT }
	end

	-- VIP pass button
	local COL_GOLD = Color3.fromRGB(255, 205, 70)
	local vipBtn = Instance.new("TextButton", panel)
	vipBtn.Name = "VipBtn"
	vipBtn.Size = UDim2.fromScale(0.9, 0.08); vipBtn.Position = UDim2.fromScale(0.5, 0.90)
	vipBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	vipBtn.BackgroundColor3 = COL_GOLD; vipBtn.BackgroundTransparency = 0
	vipBtn.Font = Enum.Font.GothamBold; vipBtn.TextScaled = true; vipBtn.TextColor3 = Color3.fromRGB(20, 16, 0)
	vipBtn.Text = "GET VIP PASS"; vipBtn.Selectable = true
	Instance.new("UICorner", vipBtn).CornerRadius = UDim.new(0.25, 0)
	local vPad = Instance.new("UIPadding", vipBtn)
	vPad.PaddingTop = UDim.new(0.25, 0); vPad.PaddingBottom = UDim.new(0.25, 0)

	-- reflect ownership
	local function refreshVip()
		if player:GetAttribute("FireworksVIP") then
			vipBtn.Text = "VIP ACTIVE"
			vipBtn.BackgroundColor3 = Color3.fromRGB(110, 200, 120)  -- green when owned
			vipBtn.AutoButtonColor = false
		else
			vipBtn.Text = "GET VIP PASS"
			vipBtn.BackgroundColor3 = COL_GOLD
			vipBtn.AutoButtonColor = true
		end
	end
	refreshVip()
	player:GetAttributeChangedSignal("FireworksVIP"):Connect(refreshVip)

	vipBtn.Activated:Connect(function()
		if player:GetAttribute("FireworksVIP") then return end  -- already VIP
		MarketplaceService:PromptGamePassPurchase(player, FireworksModule.VipGamePassId)
	end)

	-- navigation order
	navList = {}
	for _, def in ipairs(FireworksModule.Types) do
		navList[#navList + 1] = { btn = optionButtons[def.id], action = function() selectFirework(def.id) end }
	end
	navList[#navList + 1] = { btn = vipBtn, action = function()
		if not player:GetAttribute("FireworksVIP") then
			MarketplaceService:PromptGamePassPurchase(player, FireworksModule.VipGamePassId)
		end
	end }
	navList[#navList + 1] = { btn = closeBtn, action = closeMenu }

	local hint = Instance.new("TextLabel", panel)
	hint.Size = UDim2.fromScale(0.9, 0.045); hint.Position = UDim2.fromScale(0.5, 0.965)
	hint.AnchorPoint = Vector2.new(0.5, 0.5); hint.BackgroundTransparency = 1
	hint.Text = "WASD / Arrows move   -   Enter / Space select   -   Esc close"
	hint.Font = Enum.Font.Gotham; hint.TextScaled = true; hint.TextColor3 = COL_GREY
end

-- grey out fireworks the player can't currently launch
function applyAvailability(avail)
	for id, meta in pairs(optionMeta) do
		local ok = avail[id]
		if ok then
			meta.nameLbl.TextColor3 = meta.baseColor
			meta.swatch.BackgroundTransparency = 0
			meta.stroke.Transparency = 0.25
		else
			meta.nameLbl.TextColor3 = COL_GREY
			meta.swatch.BackgroundTransparency = 0.6
			meta.stroke.Transparency = 0.7
		end
	end
end

-- move the keyboard/gamepad cursor through navList (wraps around)
local function setNav(i)
	if #navList == 0 then return end
	navIndex = ((i - 1) % #navList) + 1
	GuiService.SelectedObject = navList[navIndex].btn  -- highlights + scrolls into view
end

-- handles all menu keys; sinks them so WASD doesn't move the character
local function navAction(_, state, input)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB then
		closeMenu()
	elseif kc == Enum.KeyCode.W or kc == Enum.KeyCode.Up or kc == Enum.KeyCode.A
		or kc == Enum.KeyCode.Left or kc == Enum.KeyCode.DPadUp or kc == Enum.KeyCode.DPadLeft then
		setNav(navIndex - 1)
	elseif kc == Enum.KeyCode.S or kc == Enum.KeyCode.Down or kc == Enum.KeyCode.D
		or kc == Enum.KeyCode.Right or kc == Enum.KeyCode.DPadDown or kc == Enum.KeyCode.DPadRight then
		setNav(navIndex + 1)
	elseif kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return
		or kc == Enum.KeyCode.KeypadEnter or kc == Enum.KeyCode.ButtonA then
		local e = navList[navIndex]
		if e then e.action() end
	end
	return Enum.ContextActionResult.Sink
end

function openMenu()
	if not menuGui then buildMenu() end
	if menuOpen then return end
	menuOpen = true
	menuGui.Enabled = true
	applyAvailability(availability)
	local panel = menuGui.Panel
	panel.Size = UDim2.fromScale(0, 0)
	TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = PANEL_SIZE,
	}):Play()

	setNav(1)
	ContextActionService:BindAction("FwMenuNav", navAction, false,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
		Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
		Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight,
		Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA,
		Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
end


local toastSlots = {}
local MAX_TOASTS = 4
local function showToast(text)
	-- find the lowest free slot; drop the toast if all slots are taken
	local slot = 0
	while toastSlots[slot] do slot += 1 end
	if slot >= MAX_TOASTS then return end
	toastSlots[slot] = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "FwToast"; gui.DisplayOrder = 40; gui.ResetOnSpawn = false; gui.Parent = playerGui

	local lbl = Instance.new("TextLabel", gui)
	lbl.AnchorPoint           = Vector2.new(0, 1)
	lbl.Position              = UDim2.new(0.012, 0, 0.985 - slot * 0.05, 0)  -- bottom-left, stacked up
	lbl.Size                  = UDim2.fromScale(0.26, 0.042)
	lbl.BackgroundColor3      = COL_BG
	lbl.Text                  = "  " .. text
	lbl.Font                  = Enum.Font.GothamBold
	lbl.TextScaled            = true
	lbl.TextXAlignment        = Enum.TextXAlignment.Left
	lbl.TextColor3            = COL_TEXT
	lbl.TextTransparency      = 1
	lbl.BackgroundTransparency = 1
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0.25, 0)
	local st = Instance.new("UIStroke", lbl); st.Color = COL_NEON; st.Transparency = 1

	TweenService:Create(lbl, TweenInfo.new(0.3), { TextTransparency = 0, BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 0.35 }):Play()
	task.delay(2.6, function()
		TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.5, function()
			gui:Destroy()
			toastSlots[slot] = nil
		end)
	end)
end

rOpen.OnClientEvent:Connect(openMenu)

rPlay.OnClientEvent:Connect(function(index, origin, launcher)
	local def = FireworksModule.Types[index]
	if not def then return end

	-- Con el toggle apagado no renderizamos los lanzamientos de otros.
	local mine = (launcher == player)
	if not mine and player:GetAttribute("FireworksGlobalOn") == false then return end

	local tracker = { part = nil, exploded = false, explodePos = origin }

	if mine then
		playCinematic(origin, def, tracker)  -- only the launcher gets the camera
	elseif launcher then
		showToast(launcher.Name .. "  -  " .. def.name)
	end

	Renderer.Play(index, origin, tracker)
end)

-- inventory / reward / denial messages (bottom-left)
rNotify.OnClientEvent:Connect(function(message)
	if type(message) == "string" then showToast(message) end
end)

-- availability update: store it and refresh the menu greying if it exists
rAvail.OnClientEvent:Connect(function(avail)
	if type(avail) ~= "table" then return end
	availability = avail
	if menuGui then applyAvailability(availability) end
end)
