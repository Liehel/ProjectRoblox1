local Menu1to7 = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- internal module state
local currentButtons = {}
local selectedButtonIndex = 1
local currentMenuType = nil
local activeConfig = nil
local inputConnection = nil
local currentScreenGui = nil

-- blur effect for the arcade menu overlay
local blurEffect = Lighting:FindFirstChild("ArcadeMenuBlur") or Instance.new("BlurEffect", Lighting)
blurEffect.Name = "ArcadeMenuBlur"
blurEffect.Enabled = false
blurEffect.Size = 0

local function getControlModule()
	return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
end

-- enables or disables the blur, freezes or restores camera and player controls, and toggles proximity prompts
function Menu1to7.EstablecerEnfoque(activo)
	local targetSize = activo and 56 or 0
	blurEffect.Enabled = true
	TweenService:Create(blurEffect, TweenInfo.new(0.3), { Size = targetSize }):Play()
	if not activo then task.delay(0.3, function() blurEffect.Enabled = false end) end

	local camera = workspace.CurrentCamera
	local controls = getControlModule()

	if activo then
		camera.CameraType = Enum.CameraType.Scriptable
		controls:Disable()
	else
		camera.CameraType = Enum.CameraType.Custom
		controls:Enable()
	end

	ProximityPromptService.Enabled = not activo
end

-- sound helpers
local function createSound(id, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = script
	return sound
end

local sounds = {
	hover = createSound("rbxassetid://500472891", 0.4),
	select = createSound("rbxassetid://70844388753756", 0.5),
	gameOver = createSound("rbxassetid://5855421995", 0.7),
	perfect = createSound("rbxassetid://89676801997437", 0.8)
}

local function playSound(soundName)
	local s = sounds[soundName]
	if s and not s.IsPlaying then s:Play() end
end

-- converts a 3 or 6-character hex string to a Color3
local function Color3FromHex(hex)
	hex = tostring(hex or ""):gsub("#","")
	if #hex == 3 then hex = hex:gsub(".", "%1%1") end
	local r = tonumber(hex:sub(1,2), 16) or 255
	local g = tonumber(hex:sub(3,4), 16) or 255
	local b = tonumber(hex:sub(5,6), 16) or 255
	return Color3.fromRGB(r, g, b)
end

-- overlays a semi-transparent white gradient and a 1px stroke on a frame to simulate glass
local function addGlassEffectToFrame(targetFrame)
	local glassOverlay = Instance.new("Frame")
	glassOverlay.Name = "GlassEffectOverlay"
	glassOverlay.Size = UDim2.new(1, 0, 1, 0)
	glassOverlay.BackgroundTransparency = 1
	glassOverlay.ZIndex = targetFrame.ZIndex + 1

	local corner = Instance.new("UICorner", glassOverlay)
	corner.CornerRadius = targetFrame:FindFirstChildOfClass("UICorner") and targetFrame:FindFirstChildOfClass("UICorner").CornerRadius or UDim.new(0, 10)

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

-- creates a small emoji/text label used as a decorative icon
local function createIcon(parent, iconString, size, color)
	local iconLabel = Instance.new("TextLabel", parent)
	iconLabel.Size = UDim2.fromOffset(size, size)
	iconLabel.BackgroundTransparency = 1
	iconLabel.TextScaled = true
	iconLabel.TextColor3 = color or Color3.new(1, 1, 1)
	iconLabel.Font = Enum.Font.SourceSans
	iconLabel.Text = iconString or ""
	return iconLabel
end

-- tweens the selected button larger and brighter; shrinks all others back to their original state
local function updateSelectionVisuals()
	for i, btn in ipairs(currentButtons) do
		local underline = btn:FindFirstChild("Underline")
		local origSize = btn:GetAttribute("OriginalSize")
		local origColor = btn:GetAttribute("OriginalColor")
		if not origSize then continue end

		if i == selectedButtonIndex then
			local hoverSize = UDim2.new(origSize.X.Scale * 1.1, origSize.X.Offset, origSize.Y.Scale * 1.1, origSize.Y.Offset)
			local targetColor = origColor and origColor:Lerp(Color3.new(1, 1, 1), 0.3) or btn.BackgroundColor3
			TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = hoverSize, BackgroundColor3 = targetColor }):Play()
			if underline then TweenService:Create(underline, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 3) }):Play() end
		else
			TweenService:Create(btn, TweenInfo.new(0.2), { Size = origSize, BackgroundColor3 = origColor or btn.BackgroundColor3 }):Play()
			if underline then TweenService:Create(underline, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 0, 3) }):Play() end
		end
	end
end

-- builds a rounded button with an optional icon, glass overlay, underline indicator, and hover handler
local function createStyledButton(parent, text, position, size, colorHex, iconString)
	local button = Instance.new("TextButton", parent)
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = Color3FromHex(colorHex)
	button.Text = ""
	button.BorderSizePixel = 0
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.AutoButtonColor = false
	button:SetAttribute("ActionName", text)

	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	addGlassEffectToFrame(button)

	local content = Instance.new("Frame", button)
	content.Size = UDim2.new(1, 0, 1, 0)
	content.BackgroundTransparency = 1
	content.ZIndex = button.ZIndex + 2

	local listLayout = Instance.new("UIListLayout", content)
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder

	if iconString then
		local icon = createIcon(content, iconString, 30, Color3.new(1,1,1))
		icon.LayoutOrder = 1
	end

	local label = Instance.new("TextLabel", content)
	label.Size = UDim2.new(iconString and 0.6 or 0.9, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.LayoutOrder = 2

	button:SetAttribute("OriginalSize", button.Size)
	button:SetAttribute("OriginalColor", button.BackgroundColor3)

	local underline = Instance.new("Frame", button)
	underline.Name = "Underline"
	underline.Size = UDim2.new(0, 0, 0, 3)
	underline.Position = UDim2.new(0.5, 0, 1, 0)
	underline.AnchorPoint = Vector2.new(0.5, 1)
	underline.BackgroundColor3 = Color3FromHex("192e03")
	underline.BorderSizePixel = 0

	button.MouseEnter:Connect(function()
		for i, btn in ipairs(currentButtons) do
			if btn == button then
				if selectedButtonIndex ~= i then playSound("hover") end
				selectedButtonIndex = i
				updateSelectionVisuals()
				break
			end
		end
	end)

	return button
end

-- destroys the current screen gui and empties the button list
local function limpiarPantalla()
	if currentScreenGui then currentScreenGui:Destroy() end
	table.clear(currentButtons)
end

-- disconnects the keyboard navigation listener
local function desactivarNavegacionTeclado()
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

-- plays the select sound, briefly squishes the button, then routes to the appropriate screen or callback
local function ejecutarAccionBoton(btnName, btnInstance)
	playSound("select")

	if btnInstance then
		local origSize = btnInstance:GetAttribute("OriginalSize")
		TweenService:Create(btnInstance, TweenInfo.new(0.1), {Size = UDim2.new(origSize.X.Scale*0.95, 0, origSize.Y.Scale*0.95, 0)}):Play()
		task.wait(0.1)
	end

	if btnName == "PLAY" then
		limpiarPantalla()
		desactivarNavegacionTeclado()
		currentMenuType = nil
		if activeConfig and activeConfig.OnPlay then activeConfig.OnPlay() end

	elseif btnName == "VIP" then
		Menu1to7.AbrirMenuVIP()

	elseif btnName == "EXIT" then
		Menu1to7.CerrarMenu()
		if activeConfig and activeConfig.OnExit then activeConfig.OnExit() end

	elseif btnName == "MENU" then
		Menu1to7.AbrirMenuPrincipal(activeConfig)

	else
		for _, prod in ipairs(activeConfig.Donaciones or {}) do
			if btnName == "DONATE_" .. prod.Id then
				MarketplaceService:PromptProductPurchase(player, prod.Id)
				break
			end
		end
	end
end

-- connects keyboard/gamepad navigation: back button, directional navigation, and confirm
local function activarNavegacionTeclado()
	if inputConnection then return end

	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if activeConfig.Controlador.EsBotonAtras(input) then
			if currentMenuType == "Main" then
				ejecutarAccionBoton("EXIT")
			elseif currentMenuType == "Donate" or currentMenuType == "GameOver" then
				ejecutarAccionBoton(currentMenuType == "GameOver" and "EXIT" or "MENU")
			end
			return
		end

		if processed or #currentButtons == 0 then return end

		local previousIndex = selectedButtonIndex
		local direccionMenu = activeConfig.Controlador.ObtenerDireccionMenu(input)

		if direccionMenu then
			if direccionMenu == "Arriba" then
				selectedButtonIndex = selectedButtonIndex - 1
				if selectedButtonIndex < 1 then selectedButtonIndex = #currentButtons end
			elseif direccionMenu == "Abajo" then
				selectedButtonIndex = selectedButtonIndex + 1
				if selectedButtonIndex > #currentButtons then selectedButtonIndex = 1 end
			elseif direccionMenu == "Izquierda" and (currentMenuType == "GameOver" or currentMenuType == "Donate") then
				selectedButtonIndex = selectedButtonIndex - 1
				if selectedButtonIndex < 1 then selectedButtonIndex = #currentButtons end
			elseif direccionMenu == "Derecha" and (currentMenuType == "GameOver" or currentMenuType == "Donate") then
				selectedButtonIndex = selectedButtonIndex + 1
				if selectedButtonIndex > #currentButtons then selectedButtonIndex = 1 end
			end
		elseif activeConfig.Controlador.EsBotonSeleccion(input) then
			local btn = currentButtons[selectedButtonIndex]
			if btn then ejecutarAccionBoton(btn:GetAttribute("ActionName"), btn) end
		end

		if previousIndex ~= selectedButtonIndex then
			playSound("hover")
			updateSelectionVisuals()
		end
	end)
end

-- builds and shows the main menu with PLAY / VIP / EXIT buttons
function Menu1to7.AbrirMenuPrincipal(config)
	if not config then return end
	activeConfig = config
	limpiarPantalla()
	currentMenuType = "Main"

	Menu1to7.EstablecerEnfoque(true)

	currentScreenGui = Instance.new("ScreenGui", playerGui)
	currentScreenGui.Name = "ArcadeMenuPrincipal"
	currentScreenGui.ResetOnSpawn = false

	local frame = Instance.new("Frame", currentScreenGui)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0.6, 0, 0.6, 0)
	frame.BackgroundColor3 = Color3FromHex(activeConfig.ColorFondo)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0

	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 400 / 320
	Instance.new("UISizeConstraint", frame).MaxSize = Vector2.new(600, 480)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15)
	addGlassEffectToFrame(frame)

	local titleContainer = Instance.new("Frame", frame)
	titleContainer.Size = UDim2.new(1, 0, 0.25, 0)
	titleContainer.Position = UDim2.new(0, 0, 0.03, 0)
	titleContainer.BackgroundTransparency = 1

	local titleLayout = Instance.new("UIListLayout", titleContainer)
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	titleLayout.Padding = UDim.new(0, 10)

	local icon = createIcon(titleContainer, activeConfig.IconoPrincipal, 50)
	icon.LayoutOrder = 1

	local textGroup = Instance.new("Frame", titleContainer)
	textGroup.Size = UDim2.new(0.6, 0, 1, 0)
	textGroup.BackgroundTransparency = 1
	textGroup.LayoutOrder = 2

	local titleShadow = Instance.new("TextLabel", textGroup)
	titleShadow.Size = UDim2.new(1, 0, 1, 0)
	titleShadow.Position = UDim2.fromOffset(2, 2)
	titleShadow.BackgroundTransparency = 1
	titleShadow.Text = activeConfig.Titulo
	titleShadow.Font = Enum.Font.GothamBold
	titleShadow.TextScaled = true
	titleShadow.TextColor3 = Color3.fromRGB(255, 220, 0)

	local title = Instance.new("TextLabel", textGroup)
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = activeConfig.Titulo
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)

	-- neon pulse tween on title and icon
	local tweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local neonColor = Color3.fromRGB(0, 255, 0)
	TweenService:Create(title, tweenInfo, { TextColor3 = neonColor }):Play()
	TweenService:Create(icon, tweenInfo, { TextColor3 = neonColor }):Play()
	TweenService:Create(titleShadow, tweenInfo, { TextColor3 = neonColor }):Play()

	local playBtn = createStyledButton(frame, "PLAY", UDim2.new(0.5, 0, 0.4, 0), UDim2.new(0.8, 0, 0.15, 0), activeConfig.ColorBtnPlay, activeConfig.IconosBotones.Play)
	local vipBtn = createStyledButton(frame, "VIP", UDim2.new(0.5, 0, 0.6, 0), UDim2.new(0.8, 0, 0.15, 0), activeConfig.ColorBtnVip, activeConfig.IconosBotones.Vip)
	local exitBtn = createStyledButton(frame, "EXIT", UDim2.new(0.5, 0, 0.8, 0), UDim2.new(0.8, 0, 0.15, 0), activeConfig.ColorBtnExit, activeConfig.IconosBotones.Exit)

	playBtn.MouseButton1Click:Connect(function() ejecutarAccionBoton("PLAY", playBtn) end)
	vipBtn.MouseButton1Click:Connect(function() ejecutarAccionBoton("VIP", vipBtn) end)
	exitBtn.MouseButton1Click:Connect(function() ejecutarAccionBoton("EXIT", exitBtn) end)

	table.insert(currentButtons, playBtn)
	table.insert(currentButtons, vipBtn)
	table.insert(currentButtons, exitBtn)

	selectedButtonIndex = 1
	updateSelectionVisuals()
	activarNavegacionTeclado()
end

-- builds and shows the VIP/donation menu with one button per product
function Menu1to7.AbrirMenuVIP()
	limpiarPantalla()
	currentMenuType = "Donate"
	Menu1to7.EstablecerEnfoque(true)

	currentScreenGui = Instance.new("ScreenGui", playerGui)
	currentScreenGui.Name = "ArcadeMenuVIP"
	currentScreenGui.ResetOnSpawn = false

	local frame = Instance.new("Frame", currentScreenGui)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0.65, 0, 0.65, 0)
	frame.BackgroundColor3 = Color3FromHex(activeConfig.ColorFondo)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0

	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 450 / 380
	Instance.new("UISizeConstraint", frame).MaxSize = Vector2.new(675, 570)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15)
	addGlassEffectToFrame(frame)

	local title = Instance.new("TextLabel", frame)
	title.Size = UDim2.new(1, 0, 0.13, 0)
	title.Text = "SUPPORT " .. activeConfig.Titulo
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3FromHex("192e03")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 0, 0.03, 0)

	local gridContainer = Instance.new("Frame", frame)
	gridContainer.Size = UDim2.new(0.9, 0, 0.65, 0)
	gridContainer.Position = UDim2.new(0.5, 0, 0.18, 0)
	gridContainer.AnchorPoint = Vector2.new(0.5, 0)
	gridContainer.BackgroundTransparency = 1

	local gridLayout = Instance.new("UIGridLayout", gridContainer)
	gridLayout.CellSize = UDim2.new(0.48, 0, 0.28, 0)
	gridLayout.CellPadding = UDim2.new(0.04, 0, 0.05, 0)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	for _, prod in ipairs(activeConfig.Donaciones or {}) do
		local btnText = prod.Name .. "\n" .. prod.Price
		local btn = createStyledButton(gridContainer, btnText, UDim2.new(0,0,0,0), UDim2.new(0,0,0,0), activeConfig.ColorBtnVip, nil)
		btn:SetAttribute("ActionName", "DONATE_" .. prod.Id)
		table.insert(currentButtons, btn)
		btn.MouseButton1Click:Connect(function() ejecutarAccionBoton("DONATE_" .. prod.Id, btn) end)
	end

	local backBtn = createStyledButton(frame, "MENU", UDim2.new(0.5, 0, 0.90, 0), UDim2.new(0.8, 0, 0.1, 0), activeConfig.ColorBtnExit, activeConfig.IconosBotones.Exit)
	backBtn.MouseButton1Click:Connect(function() ejecutarAccionBoton("MENU", backBtn) end)
	table.insert(currentButtons, backBtn)

	selectedButtonIndex = 1
	updateSelectionVisuals()
end

-- builds and shows the game-over screen with the final score and MENU / EXIT buttons
function Menu1to7.AbrirGameOver(score, perfect)
	limpiarPantalla()
	currentMenuType = "GameOver"
	Menu1to7.EstablecerEnfoque(true)

	if perfect then playSound("perfect") else playSound("gameOver") end

	currentScreenGui = Instance.new("ScreenGui", playerGui)
	currentScreenGui.Name = "ArcadeMenuGameOver"
	currentScreenGui.ResetOnSpawn = false

	local overlay = Instance.new("Frame", currentScreenGui)
	overlay.AnchorPoint = Vector2.new(0.5, 0.5)
	overlay.Position = UDim2.new(0.5, 0, 0.5, 0)
	overlay.Size = UDim2.new(0.6, 0, 0.4, 0)
	overlay.BackgroundColor3 = Color3FromHex(activeConfig.ColorFondo)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0

	Instance.new("UIAspectRatioConstraint", overlay).AspectRatio = 400 / 220
	Instance.new("UISizeConstraint", overlay).MaxSize = Vector2.new(600, 330)
	Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 15)
	addGlassEffectToFrame(overlay)

	local txt = Instance.new("TextLabel", overlay)
	txt.Size = UDim2.new(1, -20, 0.45, 0)
	txt.Position = UDim2.new(0.5, 0, 0.05, 0)
	txt.AnchorPoint = Vector2.new(0.5, 0)
	txt.BackgroundTransparency = 1
	txt.Text = (perfect and "PERFECT SCORE!" or "GAME OVER") .. "\nScore: " .. tostring(score)
	txt.TextScaled = true
	txt.TextColor3 = Color3.new(1,1,1)
	txt.Font = Enum.Font.GothamBold

	local menuBtn = createStyledButton(overlay, "MENU", UDim2.new(0.28, 0, 0.75, 0), UDim2.new(0.4, 0, 0.22, 0), activeConfig.ColorBtnPlay, activeConfig.IconosBotones.Play)
	local exitBtn = createStyledButton(overlay, "EXIT", UDim2.new(0.72, 0, 0.75, 0), UDim2.new(0.4, 0, 0.22, 0), activeConfig.ColorBtnExit, activeConfig.IconosBotones.Exit)

	menuBtn.MouseButton1Click:Connect(function() ejecutarAccionBoton("MENU", menuBtn) end)
	exitBtn.MouseButton1Click:Connect(function() ejecutarAccionBoton("EXIT", exitBtn) end)

	table.insert(currentButtons, menuBtn)
	table.insert(currentButtons, exitBtn)

	selectedButtonIndex = 1
	updateSelectionVisuals()
	activarNavegacionTeclado()
end

-- destroys all menu guis, disconnects input, and removes the blur effect
function Menu1to7.CerrarMenu()
	limpiarPantalla()
	desactivarNavegacionTeclado()
	currentMenuType = nil
	Menu1to7.EstablecerEnfoque(false)
end

return Menu1to7
