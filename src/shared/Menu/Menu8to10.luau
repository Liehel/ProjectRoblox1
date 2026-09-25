local Menu8to10 = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- visual config and color palette (can be overridden by the client script)
Menu8to10.Config = {
	Title = "TURRIS CASEI",
	SupportTitle = "TURRIS SUPPORT",
	MainIcon = "cheese",

	Emotes = {
		controller = "🎮", crown = "👑", door = "🚪", bird = "🐦",
		cheese = "🧀", solo = "👤", duo = "👥", back = "⬅️", jump = "🚀"
	},

	Colors = {
		BG = Color3.fromHex("fef9c3"),
		BtnBase = Color3.fromHex("eab308"),
		BtnPlay = Color3.fromHex("facc15"),
		BtnExit = Color3.fromHex("a16207"),
		Underline = Color3.fromHex("a16207"),
		TitleMain = Color3.fromHex("a16207"),
		TitleAlt = Color3.fromHex("eab308"),
		LabelText = Color3.fromHex("fef9c3"),
		HUDMuteOn = Color3.fromHex("22c55e"),
		HUDMuteOff = Color3.fromHex("6b7280"),
		HUDExit = Color3.fromHex("ef4444")
	},

	LobbyColors = {
		BG = Color3.fromHex("c4b5fd"),
		Primary = Color3.fromHex("8b5cf6"),
		Accent = Color3.fromHex("7c3aed"),
		Dark = Color3.fromHex("5b21b6"),
		TextLight = Color3.fromHex("f5f3ff"),
		ExitRed = Color3.fromHex("ef4444"),
		WinGold = Color3.fromHex("fbbf24")
	},

	Donations = {
		{ Id = 3518446349, Price = 5,    Name = "Tip" },
		{ Id = 3518446440, Price = 15,   Name = "Treat" },
		{ Id = 3518446529, Price = 50,   Name = "Sub" },
		{ Id = 3518446659, Price = 100,  Name = "Sponsor" },
		{ Id = 3518446761, Price = 500,  Name = "Whale" },
		{ Id = 3518446854, Price = 1000, Name = "Legend" },
	},

	Sounds = { Hover = nil, Select = nil, GameOver = nil, Perfect = nil },
}

-- callbacks assigned by the client script
Menu8to10.Callbacks = {
	OnPlaySolo = function() end,
	OnExitGame = function() end,
	OnToggleAudio = function(state) end,
	OnCreateRoom = function() return "0000" end,
	OnJoinRoom = function(pin) return true end,
	OnStartMatch = function() end,
	OnLeaveRoom = function() end,
	OnKickPlayer = function(name) end
}

-- internal navigation state
local currentButtons = {}
local buttonCallbacks = {}
local selectedButtonIndex = 1
local currentMenuType = nil
local isHost = false
local roomPlayers = {}
local blurEffect = nil
local activeGuis = {}
local inputConnection = nil

-- plays a named sound from the config table if it exists
local function playSound(soundKey)
	local snd = Menu8to10.Config.Sounds[soundKey]
	if snd then snd:Play() end
end

-- tweens the blur in/out, locks or restores camera and controls, and toggles proximity prompts
function Menu8to10.EstablecerEnfoque(activo)
	if not blurEffect then
		blurEffect = Lighting:FindFirstChild("TurrisMenuBlur") or Instance.new("BlurEffect", Lighting)
		blurEffect.Name = "TurrisMenuBlur"
	end
	blurEffect.Enabled = true
	TweenService:Create(blurEffect, TweenInfo.new(0.3), { Size = activo and 56 or 0 }):Play()
	if not activo then task.delay(0.3, function() blurEffect.Enabled = false end) end

	local camera = workspace.CurrentCamera
	local success, PlayerModule = pcall(function() return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) end)
	local controls = success and PlayerModule:GetControls() or nil

	if activo then
		camera.CameraType = Enum.CameraType.Scriptable
		if controls then controls:Disable() end
	else
		camera.CameraType = Enum.CameraType.Custom
		if controls then controls:Enable() end
	end
	ProximityPromptService.Enabled = not activo
end

-- destroys any existing gui with the same name, then parents the new one and tracks it
local function registerGui(guiName, guiInstance)
	if playerGui:FindFirstChild(guiName) then playerGui[guiName]:Destroy() end
	guiInstance.Name = guiName; guiInstance.Parent = playerGui; activeGuis[guiName] = guiInstance
	return guiInstance
end

-- destroys all tracked guis and clears button/callback lists
Menu8to10.DestroyAllMenus = function()
	if inputConnection then inputConnection:Disconnect(); inputConnection = nil end
	for name, gui in pairs(activeGuis) do if gui and gui.Parent then gui:Destroy() end end
	table.clear(activeGuis); table.clear(currentButtons); table.clear(buttonCallbacks)
end

-- destroys all menus and removes the blur effect
Menu8to10.CerrarMenuCompleto = function()
	Menu8to10.DestroyAllMenus()
	Menu8to10.EstablecerEnfoque(false)
	currentMenuType = nil
end

-- routes the back/escape action based on the current menu type
local function HandleBackAction()
	if currentMenuType == "Main" or currentMenuType == "GameOver" then
		Menu8to10.Callbacks.OnExitGame()
	elseif currentMenuType == "LobbyRoom" then
		Menu8to10.Callbacks.OnLeaveRoom()
		Menu8to10.ShowMainMenu()
	else
		Menu8to10.ShowMainMenu()
	end
end

-- starts listening for keyboard/gamepad input for navigation, selection, and back
local function startInputListener()
	if inputConnection then inputConnection:Disconnect() end
	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		-- release focus on text box with Escape but don't navigate away
		if processed and UserInputService:GetFocusedTextBox() then
			if input.KeyCode == Enum.KeyCode.Escape then UserInputService:GetFocusedTextBox():ReleaseFocus() end
			return
		end

		local kc = input.KeyCode
		if kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB then
			HandleBackAction(); return
		end

		if #currentButtons == 0 then return end

		-- confirm selection
		if kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return or kc == Enum.KeyCode.KeypadEnter or kc == Enum.KeyCode.ButtonA then
			local btn = currentButtons[selectedButtonIndex]
			if btn and btn.Visible then
				playSound("Select")
				local origSize = btn:GetAttribute("OriginalSize")
				if origSize then
					TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(origSize.X.Scale*0.95, 0, origSize.Y.Scale*0.95, 0)}):Play()
					task.delay(0.1, function() if btn and btn.Parent then TweenService:Create(btn, TweenInfo.new(0.1), {Size = origSize}):Play() end end)
				end
				if buttonCallbacks[btn] then buttonCallbacks[btn]() end
			end
			return
		end

		-- directional navigation
		if kc == Enum.KeyCode.W or kc == Enum.KeyCode.Up or kc == Enum.KeyCode.DPadUp or kc == Enum.KeyCode.A or kc == Enum.KeyCode.Left or kc == Enum.KeyCode.DPadLeft then
			selectedButtonIndex = selectedButtonIndex - 1
			if selectedButtonIndex < 1 then selectedButtonIndex = #currentButtons end
			playSound("Hover"); Menu8to10.UpdateSelectionVisuals()
		elseif kc == Enum.KeyCode.S or kc == Enum.KeyCode.Down or kc == Enum.KeyCode.DPadDown or kc == Enum.KeyCode.D or kc == Enum.KeyCode.Right or kc == Enum.KeyCode.DPadRight then
			selectedButtonIndex = selectedButtonIndex + 1
			if selectedButtonIndex > #currentButtons then selectedButtonIndex = 1 end
			playSound("Hover"); Menu8to10.UpdateSelectionVisuals()
		end
	end)
end

-- adds a 1px border and a rounded UICorner to a frame for a glass-card look
local function addGlassEffectToFrame(targetFrame, customColor)
	local glassOverlay = Instance.new("Frame", targetFrame)
	glassOverlay.Size = UDim2.new(1, 0, 1, 0); glassOverlay.BackgroundTransparency = 1; glassOverlay.ZIndex = targetFrame.ZIndex + 1
	local existingCorner = targetFrame:FindFirstChildOfClass("UICorner")
	Instance.new("UICorner", glassOverlay).CornerRadius = existingCorner and existingCorner.CornerRadius or UDim.new(0, 10)
	local uiStroke = Instance.new("UIStroke", glassOverlay)
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; uiStroke.Color = customColor or Menu8to10.Config.Colors.TitleMain
	uiStroke.Thickness = 1; uiStroke.Transparency = 0.5
end

-- creates a text label displaying an emote from the config emotes table
local function createIcon(parent, iconType, size, color)
	local l = Instance.new("TextLabel", parent)
	l.Size = UDim2.fromOffset(size, size); l.BackgroundTransparency = 1; l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1); l.Font = Enum.Font.SourceSans
	l.Text = Menu8to10.Config.Emotes[iconType] or ""
	return l
end

-- tweens the selected button larger and brighter; resets all others to their original state
function Menu8to10.UpdateSelectionVisuals()
	for i, btn in ipairs(currentButtons) do
		local underline = btn:FindFirstChild("Underline")
		local origSize = btn:GetAttribute("OriginalSize")
		local origColor = btn:GetAttribute("OriginalColor")
		if not origSize or not origColor then continue end

		if i == selectedButtonIndex then
			local hoverSize = UDim2.new(origSize.X.Scale * 1.1, 0, origSize.Y.Scale * 1.1, 0)
			local targetColor = origColor:Lerp(Color3.new(1, 1, 1), 0.3)
			TweenService:Create(btn, TweenInfo.new(0.2), { Size = hoverSize, BackgroundColor3 = targetColor }):Play()
			if underline then TweenService:Create(underline, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 3) }):Play() end
		else
			TweenService:Create(btn, TweenInfo.new(0.2), { Size = origSize, BackgroundColor3 = origColor }):Play()
			if underline then TweenService:Create(underline, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 0, 3) }):Play() end
		end
	end
end

-- stores original size/color, adds an underline indicator, and wires mouse-enter and click callbacks
local function setupButtonBehavior(button, callback)
	button:SetAttribute("OriginalSize", button.Size); button:SetAttribute("OriginalColor", button.BackgroundColor3)
	local underline = Instance.new("Frame", button)
	underline.Name = "Underline"; underline.Size = UDim2.new(0, 0, 0, 3); underline.Position = UDim2.new(0.5, 0, 1, 0)
	underline.AnchorPoint = Vector2.new(0.5, 1); underline.BackgroundColor3 = Menu8to10.Config.Colors.Underline
	underline.BorderSizePixel = 0; underline.ZIndex = button.ZIndex + 3

	buttonCallbacks[button] = callback

	button.MouseEnter:Connect(function()
		for i, btn in ipairs(currentButtons) do
			if btn == button then
				if selectedButtonIndex ~= i then playSound("Hover") end
				selectedButtonIndex = i; Menu8to10.UpdateSelectionVisuals(); break
			end
		end
	end)

	if button:IsA("GuiButton") then
		button.MouseButton1Click:Connect(function() playSound("Select"); if callback then callback() end end)
	elseif button:IsA("TextBox") then
		button.Focused:Connect(function()
			for i, btn in ipairs(currentButtons) do
				if btn == button then selectedButtonIndex = i; Menu8to10.UpdateSelectionVisuals(); break end
			end
		end)
	end
end

-- builds a rounded button with an optional emote icon, glass border, and a click callback
local function createStyledButton(parent, text, position, size, colorHex, iconType, callback)
	local button = Instance.new("TextButton", parent)
	button.Position = position; button.Size = size
	button.BackgroundColor3 = typeof(colorHex) == "Color3" and colorHex or Menu8to10.Config.Colors.BtnBase
	button.Text = ""; button.BorderSizePixel = 0; button.AnchorPoint = Vector2.new(0.5, 0.5); button.AutoButtonColor = false
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10); addGlassEffectToFrame(button)

	local content = Instance.new("Frame", button)
	content.Size = UDim2.new(1, 0, 1, 0); content.BackgroundTransparency = 1; content.ZIndex = button.ZIndex + 2
	local layout = Instance.new("UIListLayout", content)
	layout.FillDirection = Enum.FillDirection.Horizontal; layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.Padding = UDim.new(0, 10)

	if iconType then local icon = createIcon(content, iconType, 30, Menu8to10.Config.Colors.LabelText); icon.LayoutOrder = 1 end
	local label = Instance.new("TextLabel", content)
	label.Size = UDim2.new(iconType and 0.6 or 0.9, 0, 1, 0); label.BackgroundTransparency = 1
	label.Text = text; label.TextScaled = true; label.TextColor3 = Menu8to10.Config.Colors.LabelText
	label.Font = Enum.Font.GothamBold; label.LayoutOrder = 2

	setupButtonBehavior(button, callback); table.insert(currentButtons, button)
	return button
end

-- builds and shows the main menu with PLAY / VIP / EXIT buttons
function Menu8to10.ShowMainMenu()
	Menu8to10.DestroyAllMenus(); Menu8to10.EstablecerEnfoque(true); currentMenuType = "Main"
	local screenGui = Instance.new("ScreenGui")
	local frame = Instance.new("Frame", screenGui)
	frame.Size = UDim2.new(0.6, 0, 0.6, 0); frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BackgroundColor3 = Menu8to10.Config.Colors.BG
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15); addGlassEffectToFrame(frame)
	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 400 / 320

	local titleContainer = Instance.new("Frame", frame)
	titleContainer.Size = UDim2.new(1, 0, 0.25, 0); titleContainer.Position = UDim2.new(0, 0, 0.03, 0); titleContainer.BackgroundTransparency = 1
	local tLayout = Instance.new("UIListLayout", titleContainer)
	tLayout.FillDirection = Enum.FillDirection.Horizontal; tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; tLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local icon = createIcon(titleContainer, Menu8to10.Config.MainIcon, 50, Menu8to10.Config.Colors.TitleAlt)
	local textGroup = Instance.new("Frame", titleContainer); textGroup.Size = UDim2.new(0.6, 0, 1, 0); textGroup.BackgroundTransparency = 1

	local shadow = Instance.new("TextLabel", textGroup)
	shadow.Size = UDim2.new(1, 0, 1, 0); shadow.Position = UDim2.fromOffset(2, 2); shadow.BackgroundTransparency = 1
	shadow.Text = Menu8to10.Config.Title; shadow.Font = Enum.Font.GothamBold; shadow.TextScaled = true; shadow.TextColor3 = Menu8to10.Config.Colors.TitleAlt

	local title = Instance.new("TextLabel", textGroup)
	title.Size = UDim2.new(1, 0, 1, 0); title.BackgroundTransparency = 1
	title.Text = Menu8to10.Config.Title; title.Font = Enum.Font.GothamBold; title.TextScaled = true; title.TextColor3 = Menu8to10.Config.Colors.TitleMain

	createStyledButton(frame, "PLAY", UDim2.new(0.5, 0, 0.4, 0), UDim2.new(0.8, 0, 0.15, 0), Menu8to10.Config.Colors.BtnPlay, "controller", Menu8to10.ShowPlayModeMenu)
	createStyledButton(frame, "VIP", UDim2.new(0.5, 0, 0.6, 0), UDim2.new(0.8, 0, 0.15, 0), Menu8to10.Config.Colors.BtnBase, "crown", Menu8to10.ShowDonateMenu)
	createStyledButton(frame, "EXIT", UDim2.new(0.5, 0, 0.8, 0), UDim2.new(0.8, 0, 0.15, 0), Menu8to10.Config.Colors.BtnExit, "door", Menu8to10.Callbacks.OnExitGame)

	selectedButtonIndex = 1; Menu8to10.UpdateSelectionVisuals(); registerGui("TurrisMainMenu", screenGui)
	startInputListener()
end

-- builds and shows the mode-select screen with SOLO / VERSUS / BACK buttons
function Menu8to10.ShowPlayModeMenu()
	Menu8to10.DestroyAllMenus(); Menu8to10.EstablecerEnfoque(true); currentMenuType = "PlayMode"
	local screenGui = Instance.new("ScreenGui"); local frame = Instance.new("Frame", screenGui)
	frame.Size = UDim2.new(0.6, 0, 0.6, 0); frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BackgroundColor3 = Menu8to10.Config.Colors.BG
	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 400 / 320; addGlassEffectToFrame(frame)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15)

	local title = Instance.new("TextLabel", frame)
	title.Text = "SELECT MODE"; title.Font = Enum.Font.GothamBlack; title.TextScaled = true
	title.TextColor3 = Menu8to10.Config.Colors.TitleMain; title.Size = UDim2.new(1,0,0.2,0); title.BackgroundTransparency = 1; title.Position = UDim2.new(0,0,0.03,0)

	createStyledButton(frame, "SOLO", UDim2.new(0.5,0,0.35,0), UDim2.new(0.6,0,0.15,0), Menu8to10.Config.Colors.BtnPlay, "solo", Menu8to10.Callbacks.OnPlaySolo)
	createStyledButton(frame, "VERSUS", UDim2.new(0.5,0,0.55,0), UDim2.new(0.6,0,0.15,0), Menu8to10.Config.Colors.BtnBase, "duo", Menu8to10.ShowLobbyEntry)
	createStyledButton(frame, "BACK", UDim2.new(0.5,0,0.75,0), UDim2.new(0.6,0,0.15,0), Menu8to10.Config.Colors.BtnExit, "back", Menu8to10.ShowMainMenu)

	selectedButtonIndex = 1; Menu8to10.UpdateSelectionVisuals(); registerGui("TurrisPlayMode", screenGui)
	startInputListener()
end

-- builds and shows the donation screen with a grid of purchase buttons
function Menu8to10.ShowDonateMenu()
	Menu8to10.DestroyAllMenus(); Menu8to10.EstablecerEnfoque(true); currentMenuType = "Donate"
	local screenGui = Instance.new("ScreenGui"); local frame = Instance.new("Frame", screenGui)
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Position = UDim2.new(0.5, 0, 0.5, 0); frame.Size = UDim2.new(0.65, 0, 0.65, 0)
	frame.BackgroundColor3 = Menu8to10.Config.Colors.BG; addGlassEffectToFrame(frame)
	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 450 / 380
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15)

	local title = Instance.new("TextLabel", frame)
	title.Size = UDim2.new(1, 0, 0.13, 0); title.Text = Menu8to10.Config.SupportTitle; title.Font = Enum.Font.GothamBlack
	title.TextScaled = true; title.TextColor3 = Menu8to10.Config.Colors.TitleMain; title.BackgroundTransparency = 1; title.Position = UDim2.new(0, 0, 0.03, 0)

	local gridContainer = Instance.new("Frame", frame)
	gridContainer.Size = UDim2.new(0.9, 0, 0.65, 0); gridContainer.Position = UDim2.new(0.5, 0, 0.18, 0)
	gridContainer.AnchorPoint = Vector2.new(0.5, 0); gridContainer.BackgroundTransparency = 1
	local gridLayout = Instance.new("UIGridLayout", gridContainer)
	gridLayout.CellSize = UDim2.new(0.48, 0, 0.28, 0); gridLayout.CellPadding = UDim2.new(0.04, 0, 0.05, 0); gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	for _, prod in ipairs(Menu8to10.Config.Donations) do
		createStyledButton(gridContainer, prod.Name .. "\n" .. prod.Price, UDim2.new(), UDim2.new(), Menu8to10.Config.Colors.BtnBase, nil, function()
			MarketplaceService:PromptProductPurchase(player, prod.Id)
		end)
	end
	createStyledButton(frame, "MENU", UDim2.new(0.5, 0, 0.90, 0), UDim2.new(0.8, 0, 0.1, 0), Menu8to10.Config.Colors.BtnExit, "door", Menu8to10.ShowMainMenu)

	selectedButtonIndex = 1; Menu8to10.UpdateSelectionVisuals(); registerGui("TurrisDonate", screenGui)
	startInputListener()
end

-- creates a text label with a drop-shadow clone beneath it
local function createShadowText(parent, text, size, pos, color)
	local container = Instance.new("Frame", parent)
	container.Size = size; container.Position = pos; container.BackgroundTransparency = 1
	local lbl = Instance.new("TextLabel", container); lbl.Size = UDim2.fromScale(1,1); lbl.BackgroundTransparency = 1;
	lbl.Text = text; lbl.Font = Enum.Font.GothamBlack; lbl.TextScaled = true; lbl.TextColor3 = color; lbl.ZIndex = 2
	local shadow = lbl:Clone(); shadow.TextColor3 = Color3.new(0,0,0); shadow.TextTransparency = 0.8; shadow.Position = UDim2.fromOffset(2, 2); shadow.ZIndex = 1; shadow.Parent = container
	return lbl
end

-- shows a centered overlay with a title and subtitle that auto-destroys after 4 seconds
function Menu8to10.ShowInfoOverlay(titleText, subtitleText, titleColorHex)
	local screen = Instance.new("ScreenGui", playerGui); screen.Name = "InfoOverlay"; screen.DisplayOrder = 100000
	local frame = Instance.new("Frame", screen); frame.Size = UDim2.fromScale(0.6, 0.5); frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BackgroundColor3 = Menu8to10.Config.LobbyColors.BG
	Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 400 / 300
	local c = Instance.new("UICorner", frame); c.CornerRadius = UDim.new(0, 15)

	createShadowText(frame, titleText, UDim2.new(1,0,0.3,0), UDim2.new(0,0,0.15,0), titleColorHex or Menu8to10.Config.LobbyColors.Dark)
	local sLbl = Instance.new("TextLabel", frame); sLbl.Size = UDim2.new(0.9,0,0.4,0); sLbl.Position = UDim2.new(0.05,0,0.5,0); sLbl.BackgroundTransparency = 1
	sLbl.Text = subtitleText; sLbl.Font = Enum.Font.GothamBold; sLbl.TextScaled = true; sLbl.TextColor3 = Menu8to10.Config.LobbyColors.Dark

	task.delay(4, function() if screen.Parent then screen:Destroy() end end)
end

-- shows a pulsing bottom-of-screen alert that auto-destroys after 5 seconds
function Menu8to10.ShowBottomAlert(titleText, subtitleText, colorHex)
	if activeGuis["BottomAlert"] then activeGuis["BottomAlert"]:Destroy() end
	local screen = Instance.new("ScreenGui"); screen.Name = "BottomAlert"; screen.DisplayOrder = 100000
	local container = Instance.new("Frame", screen); container.BackgroundTransparency = 1; container.Size = UDim2.new(0.8, 0, 0.15, 0); container.Position = UDim2.new(0.5, 0, 0.95, 0); container.AnchorPoint = Vector2.new(0.5, 1)

	local title = Instance.new("TextLabel", container); title.Size = UDim2.new(1, 0, 0.6, 0); title.BackgroundTransparency = 1
	title.Text = titleText; title.Font = Enum.Font.GothamBlack; title.TextScaled = true; title.TextColor3 = colorHex or Color3.new(1, 0, 0)
	local strokeT = Instance.new("UIStroke", title); strokeT.Thickness = 3

	local subtitle = Instance.new("TextLabel", container); subtitle.Size = UDim2.new(1, 0, 0.4, 0); subtitle.Position = UDim2.new(0, 0, 0.6, 0); subtitle.BackgroundTransparency = 1
	subtitle.Text = subtitleText; subtitle.Font = Enum.Font.GothamBold; subtitle.TextScaled = true; subtitle.TextColor3 = Color3.new(1, 1, 1)
	local strokeS = Instance.new("UIStroke", subtitle); strokeS.Thickness = 2

	registerGui("BottomAlert", screen)

	-- pulse the title text and its stroke in sync
	TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {TextTransparency = 0.5}):Play()
	TweenService:Create(strokeT, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.5}):Play()

	task.delay(5, function() if screen.Parent then screen:Destroy() end end)
end

-- rebuilds the keyboard navigation button list from the current lobby room gui
local function RebuildLobbyNavigation()
	local gui = activeGuis["LobbyRoom"]
	if not gui then return end

	local exitBtn = gui:FindFirstChild("ExitButton", true)
	local playBtn = gui:FindFirstChild("StartButton", true)
	local scroll = gui:FindFirstChild("ScrollingFrame", true)

	table.clear(currentButtons)

	if exitBtn then table.insert(currentButtons, exitBtn) end

	if scroll then
		for _, row in ipairs(scroll:GetChildren()) do
			if row:IsA("Frame") then
				local kickBtn = row:FindFirstChild("KickButton")
				if kickBtn then table.insert(currentButtons, kickBtn) end
			end
		end
	end

	if playBtn then table.insert(currentButtons, playBtn) end

	if selectedButtonIndex > #currentButtons then selectedButtonIndex = math.max(1, #currentButtons) end
	Menu8to10.UpdateSelectionVisuals()
end

-- shows the create-room / join-room lobby entry screen
function Menu8to10.ShowLobbyEntry()
	Menu8to10.DestroyAllMenus(); Menu8to10.EstablecerEnfoque(true); currentMenuType = "LobbyEntry"
	local screen = Instance.new("ScreenGui"); local frame = Instance.new("Frame", screen); frame.Size = UDim2.new(0.6, 0, 0.5, 0); frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BackgroundColor3 = Menu8to10.Config.LobbyColors.BG
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15); Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 400 / 300

	createShadowText(frame, "MULTIPLAYER", UDim2.new(1,0,0.2,0), UDim2.new(0,0,0,10), Menu8to10.Config.LobbyColors.Dark)

	local createBtn = Instance.new("TextButton", frame)
	createBtn.Size = UDim2.new(0.8, 0, 0.25, 0); createBtn.Position = UDim2.new(0.1, 0, 0.3, 0); createBtn.BackgroundColor3 = Menu8to10.Config.LobbyColors.Primary
	createBtn.Text = "CREATE ROOM"; createBtn.Font = Enum.Font.GothamBold; createBtn.TextScaled = true; createBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 10)

	local pinInput = Instance.new("TextBox", frame)
	pinInput.Size = UDim2.new(0.5, 0, 0.2, 0); pinInput.Position = UDim2.new(0.1, 0, 0.65, 0); pinInput.BackgroundColor3 = Color3.new(1,1,1)
	pinInput.PlaceholderText = "PIN"; pinInput.TextScaled = true; pinInput.ClearTextOnFocus = true; Instance.new("UICorner", pinInput).CornerRadius = UDim.new(0, 8)

	local joinBtn = Instance.new("TextButton", frame)
	joinBtn.Size = UDim2.new(0.25, 0, 0.2, 0); joinBtn.Position = UDim2.new(0.65, 0, 0.65, 0); joinBtn.BackgroundColor3 = Menu8to10.Config.LobbyColors.Accent
	joinBtn.Text = "JOIN"; joinBtn.Font = Enum.Font.GothamBold; joinBtn.TextScaled = true; joinBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", joinBtn).CornerRadius = UDim.new(0, 8)

	local close = Instance.new("TextButton", frame)
	close.Size = UDim2.new(0.1, 0, 0.1, 0); close.Position = UDim2.new(0.95, 0, 0.05, 0); close.AnchorPoint = Vector2.new(1, 0); close.BackgroundColor3 = Menu8to10.Config.LobbyColors.ExitRed
	close.Text = "X"; close.TextScaled = true; close.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)

	local function attemptJoin() if #pinInput.Text >= 4 then if Menu8to10.Callbacks.OnJoinRoom(pinInput.Text) then Menu8to10.ShowLobbyRoom(pinInput.Text, false) end end end

	setupButtonBehavior(createBtn, function() local pin = Menu8to10.Callbacks.OnCreateRoom(); if pin then Menu8to10.ShowLobbyRoom(pin, true) end end)
	setupButtonBehavior(pinInput, function() pinInput:CaptureFocus() end)
	setupButtonBehavior(joinBtn, attemptJoin)
	setupButtonBehavior(close, Menu8to10.ShowPlayModeMenu)
	pinInput.FocusLost:Connect(function(enter) if enter then attemptJoin() end end)

	table.insert(currentButtons, createBtn); table.insert(currentButtons, pinInput); table.insert(currentButtons, joinBtn); table.insert(currentButtons, close)
	selectedButtonIndex = 1; Menu8to10.UpdateSelectionVisuals(); registerGui("LobbyEntry", screen); startInputListener()
end

-- clears and redraws all player rows in the scrolling list, adding kick buttons for the host
function Menu8to10.RefreshPlayerList(container)
	for _, c in ipairs(container:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	for i, playerName in ipairs(roomPlayers) do
		local row = Instance.new("Frame", container); row.Size = UDim2.new(1, 0, 0, 50); row.BackgroundColor3 = Menu8to10.Config.LobbyColors.Primary; Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		local nameLbl = Instance.new("TextLabel", row); nameLbl.Size = UDim2.new(0.6, 0, 1, 0); nameLbl.Position = UDim2.new(0, 10, 0, 0); nameLbl.BackgroundTransparency = 1
		nameLbl.Text = playerName; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextColor3 = Menu8to10.Config.LobbyColors.TextLight; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.TextScaled = true
		if isHost and playerName ~= player.Name then
			local kickBtn = Instance.new("TextButton", row); kickBtn.Name = "KickButton"; kickBtn.Size = UDim2.new(0.15, 0, 0.8, 0); kickBtn.Position = UDim2.new(0.98, 0, 0.5, 0); kickBtn.AnchorPoint = Vector2.new(1, 0.5); kickBtn.BackgroundColor3 = Menu8to10.Config.LobbyColors.ExitRed; kickBtn.Text = "X"; kickBtn.TextColor3 = Color3.new(1,1,1); kickBtn.Font = Enum.Font.GothamBlack; kickBtn.TextScaled = true; Instance.new("UICorner", kickBtn).CornerRadius = UDim.new(0, 5); Instance.new("UIAspectRatioConstraint", kickBtn).AspectRatio = 1
			setupButtonBehavior(kickBtn, function() Menu8to10.Callbacks.OnKickPlayer(playerName) end)
		end
	end
	RebuildLobbyNavigation()
end

-- shows the waiting room screen with the PIN, player list, and (for the host) a start button
function Menu8to10.ShowLobbyRoom(pinCode, amHost)
	Menu8to10.DestroyAllMenus(); Menu8to10.EstablecerEnfoque(true); isHost = amHost; roomPlayers = {player.Name}; currentMenuType = "LobbyRoom"
	local gui = Instance.new("ScreenGui")
	local bg = Instance.new("Frame", gui); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Menu8to10.Config.LobbyColors.BG
	local mainFrame = Instance.new("Frame", bg); mainFrame.Size = UDim2.new(0.6, 0, 0.8, 0); mainFrame.Position = UDim2.fromScale(0.5, 0.5); mainFrame.AnchorPoint = Vector2.new(0.5, 0.5); mainFrame.BackgroundTransparency = 1; Instance.new("UIAspectRatioConstraint", mainFrame).AspectRatio = 400 / 450
	createShadowText(mainFrame, "PIN: " .. pinCode, UDim2.new(1, 0, 0.1, 0), UDim2.new(0, 0, 0, 0), Menu8to10.Config.LobbyColors.Dark)
	local listBg = Instance.new("Frame", mainFrame); listBg.Size = UDim2.new(1, 0, 0.7, 0); listBg.Position = UDim2.new(0, 0, 0.15, 0); listBg.BackgroundColor3 = Menu8to10.Config.LobbyColors.Accent; Instance.new("UICorner", listBg).CornerRadius = UDim.new(0, 15)
	local scroll = Instance.new("ScrollingFrame", listBg); scroll.Size = UDim2.new(0.9, 0, 0.9, 0); scroll.Position = UDim2.fromScale(0.5, 0.5); scroll.AnchorPoint = Vector2.new(0.5, 0.5); scroll.BackgroundTransparency = 1; Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 8)

	local exitBtn = Instance.new("TextButton", bg); exitBtn.Name = "ExitButton"; exitBtn.Size = UDim2.new(0.15, 0, 0.08, 0); exitBtn.Position = UDim2.new(0.95, 0, 0.05, 0); exitBtn.AnchorPoint = Vector2.new(1, 0); exitBtn.BackgroundColor3 = Menu8to10.Config.LobbyColors.ExitRed; exitBtn.Text = "EXIT"; exitBtn.Font = Enum.Font.GothamBlack; exitBtn.TextColor3 = Color3.new(1,1,1); exitBtn.TextScaled = true; Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0, 12)
	setupButtonBehavior(exitBtn, function() Menu8to10.Callbacks.OnLeaveRoom(); Menu8to10.ShowMainMenu() end)

	if isHost then
		local playBtn = Instance.new("TextButton", mainFrame); playBtn.Name = "StartButton"; playBtn.Size = UDim2.new(0.8, 0, 0.1, 0); playBtn.Position = UDim2.new(0.5, 0, 0.9, 0); playBtn.AnchorPoint = Vector2.new(0.5, 0); playBtn.BackgroundColor3 = Color3.fromHex("a3e635"); playBtn.Text = "START GAME"; playBtn.Font = Enum.Font.GothamBlack; playBtn.TextScaled = true; Instance.new("UICorner", playBtn).CornerRadius = UDim.new(0, 15)
		setupButtonBehavior(playBtn, function() Menu8to10.Callbacks.OnStartMatch() end)
	end

	registerGui("LobbyRoom", gui)
	Menu8to10.RefreshPlayerList(scroll)
	selectedButtonIndex = 1; Menu8to10.UpdateSelectionVisuals(); startInputListener()
end

-- updates the room player list and refreshes the scrolling frame
function Menu8to10.UpdateLobbyPlayers(playersList)
	roomPlayers = playersList; local gui = activeGuis["LobbyRoom"]; if gui then local scroll = gui:FindFirstChild("ScrollingFrame", true); if scroll then Menu8to10.RefreshPlayerList(scroll) end end
end

-- creates and shows the in-game HUD with a score label, mute toggle, and exit button; returns the score label
function Menu8to10.ShowInGameHUD(isMuted, onMuteToggle, onExit)
	local screenGui = Instance.new("ScreenGui")
	local scoreFrame = Instance.new("Frame", screenGui); scoreFrame.Size = UDim2.new(0.2, 0, 0.08, 0); scoreFrame.Position = UDim2.new(0.02, 0, 0.02, 0); scoreFrame.BackgroundColor3 = Menu8to10.Config.Colors.BtnBase; Instance.new("UICorner", scoreFrame).CornerRadius = UDim.new(0, 8); addGlassEffectToFrame(scoreFrame)
	local hudScoreLabel = Instance.new("TextLabel", scoreFrame); hudScoreLabel.Name = "ScoreLabel"; hudScoreLabel.Size = UDim2.new(1,0,1,0); hudScoreLabel.BackgroundTransparency = 1; hudScoreLabel.Text = "SCORE: 0"; hudScoreLabel.Font = Enum.Font.GothamBlack; hudScoreLabel.TextColor3 = Color3.new(1,1,1); hudScoreLabel.TextScaled = true

	local btnContainer = Instance.new("Frame", screenGui); btnContainer.Size = UDim2.new(0.25, 0, 0.08, 0); btnContainer.Position = UDim2.new(0.73, 0, 0.02, 0); btnContainer.BackgroundTransparency = 1; local list = Instance.new("UIListLayout", btnContainer); list.FillDirection = Enum.FillDirection.Horizontal; list.Padding = UDim.new(0, 10); list.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local hudMuteBtn = Instance.new("TextButton", btnContainer); hudMuteBtn.Size = UDim2.new(0.5, 0, 1, 0); hudMuteBtn.TextScaled = true; hudMuteBtn.Font = Enum.Font.GothamBold; hudMuteBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", hudMuteBtn).CornerRadius = UDim.new(0,8); addGlassEffectToFrame(hudMuteBtn)
	local function updateMute(muted) if not muted then hudMuteBtn.Text = "SOUND"; hudMuteBtn.BackgroundColor3 = Menu8to10.Config.Colors.HUDMuteOn else hudMuteBtn.Text = "MUTED"; hudMuteBtn.BackgroundColor3 = Menu8to10.Config.Colors.HUDMuteOff end end
	updateMute(isMuted); hudMuteBtn.MouseButton1Click:Connect(function() isMuted = not isMuted; updateMute(isMuted); if onMuteToggle then onMuteToggle(isMuted) end end)

	local exitBtn = Instance.new("TextButton", btnContainer); exitBtn.Size = UDim2.new(0.4, 0, 1, 0); exitBtn.BackgroundColor3 = Menu8to10.Config.Colors.HUDExit; exitBtn.Text = "EXIT"; exitBtn.TextScaled = true; exitBtn.Font = Enum.Font.GothamBold; exitBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0,8); addGlassEffectToFrame(exitBtn); exitBtn.MouseButton1Click:Connect(function() if onExit then onExit() end end)

	registerGui("TurrisHUD", screenGui); return hudScoreLabel
end

-- shows the end-of-game screen with score and MENU / EXIT buttons
function Menu8to10.ShowGameOver(score, isWin, callbackMenu, callbackExit)
	Menu8to10.DestroyAllMenus(); Menu8to10.EstablecerEnfoque(true); currentMenuType = "GameOver"; playSound(isWin and "Perfect" or "GameOver")
	local screenGui = Instance.new("ScreenGui"); screenGui.DisplayOrder = 99999; local frame = Instance.new("Frame", screenGui); frame.Size = UDim2.new(0.6, 0, 0.4, 0); frame.Position = UDim2.fromScale(0.5, 0.5); frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BackgroundColor3 = Menu8to10.Config.Colors.BG; Instance.new("UIAspectRatioConstraint", frame).AspectRatio = 400 / 250; Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15); addGlassEffectToFrame(frame)
	local title = Instance.new("TextLabel", frame); title.Text = (isWin and "VICTORY!" or "GAME OVER") .. "\nSCORE: " .. tostring(score); title.Font = Enum.Font.GothamBlack; title.TextScaled = true; title.TextColor3 = Menu8to10.Config.Colors.TitleMain; title.Size = UDim2.new(1,0,0.35,0); title.Position = UDim2.new(0,0,0.05,0); title.BackgroundTransparency = 1
	createStyledButton(frame, "MENU", UDim2.new(0.28, 0, 0.75, 0), UDim2.new(0.4, 0, 0.22, 0), Menu8to10.Config.Colors.BtnBase, "controller", function() if callbackMenu then callbackMenu() else Menu8to10.ShowMainMenu() end end)
	createStyledButton(frame, "EXIT", UDim2.new(0.72, 0, 0.75, 0), UDim2.new(0.4, 0, 0.22, 0), Menu8to10.Config.Colors.BtnExit, "door", callbackExit)
	selectedButtonIndex = 1; Menu8to10.UpdateSelectionVisuals(); registerGui("TurrisEnd", screenGui); startInputListener()
end

return Menu8to10
