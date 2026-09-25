-- Boton pildora compartido de la esquina superior derecha.
-- Cada boton controla un atributo booleano del jugador.

local Players              = game:GetService("Players")
local TweenService         = game:GetService("TweenService")
local UserInputService     = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ToggleButton = {}

local BASE_W, BASE_H, HINT_H, GAP = 214, 52, 18, 6

local COL_BG       = Color3.fromRGB(8, 14, 22)
local COL_NEON     = Color3.fromRGB(154, 230, 0)
local COL_TEXT     = Color3.fromRGB(216, 249, 153)
local COL_OFF      = Color3.fromRGB(116, 122, 128)
local COL_OFF_TEXT = Color3.fromRGB(146, 152, 158)
local COL_TRACK    = Color3.fromRGB(30, 38, 30)

local FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP  = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- ── Shared stack (built once, on first .new) ──────────────────────────────
local stack

local function ensureStack()
	if stack then return stack end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TopRightToggles"
	gui.DisplayOrder = 55        -- above the firework flash (50), below its menu (60)
	gui.IgnoreGuiInset = false   -- sit under the Roblox topbar on mobile / console
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Stack"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -12, 0, 6)
	frame.Size = UDim2.fromOffset(BASE_W, 600)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local layout = Instance.new("UIListLayout", frame)
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)

	-- one scale for the whole stack: tappable on phones, sane on 4K
	local uiScale = Instance.new("UIScale", frame)
	local function fitScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		if vp.Y <= 0 then return end
		local s = math.clamp(vp.Y / 900, 0.85, 1.3)
		if vp.X < 600 then s = math.min(s, 1.0) end   -- narrow phones
		uiScale.Scale = s
	end
	fitScale()
	local function watchCam()
		local cam = workspace.CurrentCamera
		if cam then
			fitScale()
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
		end
	end
	watchCam()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCam)

	stack = frame
	return stack
end

-- ── One toggle ────────────────────────────────────────────────────────────
-- cfg = { label, attribute, order, onHint, offHint,
--         keyCode, gamepadKeyCode, actionName }
function ToggleButton.new(cfg)
	local parent = ensureStack()

	local row = Instance.new("Frame")
	row.Name = cfg.attribute
	row.Size = UDim2.fromOffset(BASE_W, BASE_H + HINT_H)
	row.BackgroundTransparency = 1
	row.LayoutOrder = cfg.order or 1
	row.Parent = parent

	local btn = Instance.new("TextButton")
	btn.Name = "Toggle"
	btn.Size = UDim2.fromOffset(BASE_W, BASE_H)
	btn.BackgroundColor3 = COL_BG
	btn.BackgroundTransparency = 0.08
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Selectable = true        -- reachable with gamepad UI navigation
	btn.Parent = row
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = COL_NEON
	stroke.Thickness = 1.8
	stroke.Transparency = 0.25

	local press = Instance.new("UIScale", btn)

	local led = Instance.new("Frame")
	led.Name = "Led"
	led.AnchorPoint = Vector2.new(0, 0.5)
	led.Position = UDim2.new(0, 14, 0.5, 0)
	led.Size = UDim2.fromOffset(14, 14)
	led.BackgroundColor3 = COL_NEON
	led.BorderSizePixel = 0
	led.Parent = btn
	Instance.new("UICorner", led).CornerRadius = UDim.new(1, 0)
	local ledGlow = Instance.new("UIStroke", led)
	ledGlow.Color = COL_NEON
	ledGlow.Thickness = 3
	ledGlow.Transparency = 0.55

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 36, 0.5, 0)
	label.Size = UDim2.fromOffset(104, 22)
	label.BackgroundTransparency = 1
	label.Text = cfg.label
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = COL_TEXT
	label.Parent = btn
	Instance.new("UITextSizeConstraint", label).MaxTextSize = 17

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -14, 0.5, 0)
	track.Size = UDim2.fromOffset(46, 24)
	track.BackgroundColor3 = COL_TRACK
	track.BorderSizePixel = 0
	track.Parent = btn
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
	local trackStroke = Instance.new("UIStroke", track)
	trackStroke.Color = COL_NEON
	trackStroke.Thickness = 1.4
	trackStroke.Transparency = 0.4

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(1, -12, 0.5, 0)
	knob.Size = UDim2.fromOffset(18, 18)
	knob.BackgroundColor3 = COL_NEON
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Position = UDim2.new(1, 0, 1, 0)
	hint.Size = UDim2.fromOffset(BASE_W, HINT_H - 3)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextScaled = true
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextColor3 = COL_OFF_TEXT
	hint.TextTransparency = 1
	hint.Text = ""
	hint.Parent = row
	Instance.new("UITextSizeConstraint", hint).MaxTextSize = 13

	local hintToken = 0
	local function flashHint(text)
		hint.Text = text
		hintToken += 1
		local mine = hintToken
		TweenService:Create(hint, FAST, { TextTransparency = 0 }):Play()
		task.delay(2.6, function()
			if mine == hintToken then
				TweenService:Create(hint, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
		end)
	end

	local function isOn()
		return player:GetAttribute(cfg.attribute) ~= false   -- nil counts as ON
	end

	local function paint(on, announce)
		local accent  = on and COL_NEON or COL_OFF
		local textCol = on and COL_TEXT or COL_OFF_TEXT

		TweenService:Create(stroke, FAST, { Color = accent, Transparency = on and 0.25 or 0.55 }):Play()
		TweenService:Create(led, FAST, { BackgroundColor3 = accent }):Play()
		TweenService:Create(ledGlow, FAST, { Color = accent, Transparency = on and 0.55 or 0.9 }):Play()
		TweenService:Create(label, FAST, { TextColor3 = textCol }):Play()
		TweenService:Create(trackStroke, FAST, { Color = accent, Transparency = on and 0.4 or 0.7 }):Play()
		TweenService:Create(knob, POP, {
			BackgroundColor3 = accent,
			Position = on and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 12, 0.5, 0),
		}):Play()
		TweenService:Create(btn, FAST, { BackgroundTransparency = on and 0.08 or 0.3 }):Play()

		if announce then
			flashHint(on and cfg.onHint or cfg.offHint)
		end
	end

	local function toggle()
		press.Scale = 0.94
		TweenService:Create(press, POP, { Scale = 1 }):Play()
		player:SetAttribute(cfg.attribute, not isOn())   -- listener repaints
	end

	btn.Activated:Connect(toggle)

	btn.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return end
		TweenService:Create(stroke, FAST, { Transparency = 0.05 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(stroke, FAST, { Transparency = isOn() and 0.25 or 0.55 }):Play()
	end)

	if cfg.actionName and (cfg.keyCode or cfg.gamepadKeyCode) then
		local keys = {}
		if cfg.keyCode then keys[#keys + 1] = cfg.keyCode end
		if cfg.gamepadKeyCode then keys[#keys + 1] = cfg.gamepadKeyCode end
		ContextActionService:BindAction(cfg.actionName, function(_, state)
			if state == Enum.UserInputState.Begin then toggle() end
			return Enum.ContextActionResult.Pass   -- never swallow keys from other systems
		end, false, table.unpack(keys))
	end

	-- Default ON. Set before listening so joining never flashes the hint.
	if player:GetAttribute(cfg.attribute) == nil then
		player:SetAttribute(cfg.attribute, true)
	end
	paint(isOn(), false)

	player:GetAttributeChangedSignal(cfg.attribute):Connect(function()
		paint(isOn(), true)
	end)

	return btn
end

return ToggleButton
