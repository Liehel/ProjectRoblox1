local UniversalController = {}

local ContextActionService = game:GetService("ContextActionService")
local UserInputService     = game:GetService("UserInputService")
local GuiService           = game:GetService("GuiService")
local Players              = game:GetService("Players")

local accionesActivas      = {}
local conexionesSueltas    = {}
local controlesVirtualesGui = nil

local ESTILO = {
	ColorSombra         = Color3.fromRGB(20, 25, 10),
	ColorNeon           = Color3.fromRGB(154, 230, 0),
	ColorTexto          = Color3.fromRGB(216, 249, 153),
	ColorGris           = Color3.fromRGB(150, 150, 150),
	TransparenciaBg     = 0.4,
	TransparenciaBorde  = 0.3,
	RadioEsquinaCruceta = UDim.new(0.2, 0),
	RadioEsquinaCirculo = UDim.new(1, 0),
	GrosorBorde         = 2,
}

-- show/hide virtual controls and toggle gamepad gui navigation based on input type
UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
	if lastInputType == Enum.UserInputType.Gamepad1 then
		if controlesVirtualesGui then controlesVirtualesGui.Enabled = false end
		GuiService.AutoSelectGuiEnabled = true
	elseif lastInputType == Enum.UserInputType.Touch then
		if controlesVirtualesGui then controlesVirtualesGui.Enabled = true end
		GuiService.AutoSelectGuiEnabled = false
	end
end)

-- returns true if input is a menu confirm key (enter, space, A button)
function UniversalController.EsBotonSeleccion(input)
	local kc = input.KeyCode
	return kc == Enum.KeyCode.Return or kc == Enum.KeyCode.Space or kc == Enum.KeyCode.KeypadEnter or kc == Enum.KeyCode.ButtonA
end

-- returns true if input is a back/cancel key (escape, B button)
function UniversalController.EsBotonAtras(input)
	local kc = input.KeyCode
	return kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.ButtonB
end

-- returns a direction string for keyboard/dpad navigation, or nil
function UniversalController.ObtenerDireccionMenu(input)
	local kc = input.KeyCode
	if kc == Enum.KeyCode.W or kc == Enum.KeyCode.Up or kc == Enum.KeyCode.DPadUp then return "Arriba"
	elseif kc == Enum.KeyCode.S or kc == Enum.KeyCode.Down or kc == Enum.KeyCode.DPadDown then return "Abajo"
	elseif kc == Enum.KeyCode.A or kc == Enum.KeyCode.Left or kc == Enum.KeyCode.DPadLeft then return "Izquierda"
	elseif kc == Enum.KeyCode.D or kc == Enum.KeyCode.Right or kc == Enum.KeyCode.DPadRight then return "Derecha"
	end
	return nil
end

-- create a single d-pad direction button
local function crearBotonDpad(parent, nombre, posScale, texto, callback, customSize)
	local btn = Instance.new("TextButton", parent)
	btn.Name = nombre
	btn.Size = customSize or UDim2.fromScale(0.33, 0.33)
	btn.Position = posScale
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.BackgroundColor3 = ESTILO.ColorSombra
	btn.BackgroundTransparency = ESTILO.TransparenciaBg
	btn.Text = texto
	btn.Font = Enum.Font.ArialBold
	btn.TextScaled = true
	btn.TextColor3 = ESTILO.ColorTexto

	local padding = Instance.new("UIPadding", btn)
	padding.PaddingTop    = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft   = UDim.new(0.10, 0)
	padding.PaddingRight  = UDim.new(0.10, 0)

	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = ESTILO.RadioEsquinaCruceta
	local stroke = Instance.new("UIStroke", btn)
	stroke.Thickness    = ESTILO.GrosorBorde
	stroke.Color        = ESTILO.ColorNeon
	stroke.Transparency = ESTILO.TransparenciaBorde

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callback(nombre, Enum.UserInputState.Begin, input) end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callback(nombre, Enum.UserInputState.End, input) end
	end)
end

-- create a 4-direction cross pad (up, down, left, right)
local function crearCrucetaCompleta(parent, nombreContenedor, posicionUDim2, callbacks)
	local container = Instance.new("Frame", parent)
	container.Name = nombreContenedor
	container.Size = UDim2.new(0.28, 0, 0.28, 0)
	container.Position = posicionUDim2
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	Instance.new("UIAspectRatioConstraint", container).AspectRatio = 1

	local centro = Instance.new("Frame", container)
	centro.Size = UDim2.fromScale(0.34, 0.34)
	centro.Position = UDim2.fromScale(0.5, 0.5)
	centro.AnchorPoint = Vector2.new(0.5, 0.5)
	centro.BackgroundColor3 = ESTILO.ColorSombra
	centro.BackgroundTransparency = ESTILO.TransparenciaBg
	centro.BorderSizePixel = 0

	crearBotonDpad(container, "Izquierda", UDim2.fromScale(0.165, 0.5), "◄", callbacks.Izq)
	crearBotonDpad(container, "Derecha",   UDim2.fromScale(0.835, 0.5), "►", callbacks.Der)
	crearBotonDpad(container, "Arriba",    UDim2.fromScale(0.5, 0.165), "▲", callbacks.Arriba)
	crearBotonDpad(container, "Abajo",     UDim2.fromScale(0.5, 0.835), "▼", callbacks.Abajo)
end

-- resilio variant: left, right and a wide launch button instead of up/down
local function crearCrucetaResilio(parent, nombreContenedor, posicionUDim2, callbacks)
	local container = Instance.new("Frame", parent)
	container.Name = nombreContenedor
	container.Size = UDim2.new(0.28, 0, 0.28, 0)
	container.Position = posicionUDim2
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	Instance.new("UIAspectRatioConstraint", container).AspectRatio = 1

	local centro = Instance.new("Frame", container)
	centro.Size = UDim2.fromScale(0.34, 0.34)
	centro.Position = UDim2.fromScale(0.5, 0.5)
	centro.AnchorPoint = Vector2.new(0.5, 0.5)
	centro.BackgroundColor3 = ESTILO.ColorSombra
	centro.BackgroundTransparency = ESTILO.TransparenciaBg
	centro.BorderSizePixel = 0

	crearBotonDpad(container, "Izquierda", UDim2.fromScale(0.165, 0.5), "◄", callbacks.Izq)
	crearBotonDpad(container, "Derecha",   UDim2.fromScale(0.835, 0.5), "►", callbacks.Der)
	crearBotonDpad(container, "Launch",    UDim2.fromScale(0.5, 0.835), "PUSH", callbacks.Launch, UDim2.fromScale(1.0, 0.33))
end

-- create a circular action button
local function crearBotonCircular(parent, nombre, posicionUDim2, texto, callback, tamanoEspecial)
	local btn = Instance.new("TextButton", parent)
	btn.Name = nombre
	btn.Size = tamanoEspecial or UDim2.new(0.20, 0, 0.20, 0)
	btn.Position = posicionUDim2
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	Instance.new("UIAspectRatioConstraint", btn).AspectRatio = 1

	btn.BackgroundColor3 = ESTILO.ColorSombra
	btn.BackgroundTransparency = ESTILO.TransparenciaBg
	btn.Text = texto
	btn.Font = Enum.Font.GothamBlack
	btn.TextScaled = true
	btn.TextColor3 = ESTILO.ColorTexto

	local padding = Instance.new("UIPadding", btn)
	padding.PaddingTop    = UDim.new(0.25, 0)
	padding.PaddingBottom = UDim.new(0.25, 0)
	padding.PaddingLeft   = UDim.new(0.10, 0)
	padding.PaddingRight  = UDim.new(0.10, 0)

	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = ESTILO.RadioEsquinaCirculo
	local stroke = Instance.new("UIStroke", btn)
	stroke.Thickness    = ESTILO.GrosorBorde
	stroke.Color        = ESTILO.ColorNeon
	stroke.Transparency = ESTILO.TransparenciaBorde

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callback(nombre, Enum.UserInputState.Begin, input) end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callback(nombre, Enum.UserInputState.End, input) end
	end)
end

-- create a draggable virtual joystick
local function crearJoystick(parent, nombre, posicionUDim2, textoCentral, callbackVec)
	local bg = Instance.new("Frame", parent)
	bg.Name = nombre
	bg.Size = UDim2.new(0.26, 0, 0.26, 0)
	bg.Position = posicionUDim2
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.BackgroundColor3 = ESTILO.ColorSombra
	bg.BackgroundTransparency = ESTILO.TransparenciaBg

	Instance.new("UIAspectRatioConstraint", bg).AspectRatio = 1
	Instance.new("UICorner", bg).CornerRadius = ESTILO.RadioEsquinaCirculo
	local stroke = Instance.new("UIStroke", bg)
	stroke.Thickness    = ESTILO.GrosorBorde
	stroke.Color        = ESTILO.ColorNeon
	stroke.Transparency = ESTILO.TransparenciaBorde

	if textoCentral and textoCentral ~= "" then
		local label = Instance.new("TextLabel", bg)
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = textoCentral
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = ESTILO.ColorGris
		label.ZIndex = bg.ZIndex + 1
		local pad = Instance.new("UIPadding", label)
		pad.PaddingTop    = UDim.new(0.3, 0)
		pad.PaddingBottom = UDim.new(0.3, 0)
	end

	local thumb = Instance.new("Frame", bg)
	thumb.Name = "Thumb"
	thumb.Size = UDim2.fromScale(0.35, 0.35)
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.fromScale(0.5, 0.5)
	thumb.BackgroundColor3 = ESTILO.ColorNeon
	thumb.BackgroundTransparency = 0.2
	thumb.ZIndex = bg.ZIndex + 2
	Instance.new("UICorner", thumb).CornerRadius = ESTILO.RadioEsquinaCirculo

	local dragging = false
	local touchId  = nil

	-- move thumb within joystick bounds and fire normalized vector callback
	local function updateThumb(input)
		local bgPos  = bg.AbsolutePosition + bg.AbsoluteSize / 2
		local delta  = Vector2.new(input.Position.X, input.Position.Y) - bgPos
		local maxDist = bg.AbsoluteSize.X / 2
		if delta.Magnitude > maxDist then delta = delta.Unit * maxDist end
		thumb.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
		if callbackVec then callbackVec(Vector2.new(delta.X / maxDist, -(delta.Y / maxDist))) end
	end

	local c1 = bg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			touchId = input.UserInputType == Enum.UserInputType.Touch and input.UserInputState or nil
			updateThumb(input)
		end
	end)

	local c2 = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or (input.UserInputType == Enum.UserInputType.Touch and input.UserInputIndex == touchId)) then
			updateThumb(input)
		end
	end)

	local c3 = UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and input.UserInputIndex == touchId)) then
			dragging = false
			touchId  = nil
			thumb.Position = UDim2.fromScale(0.5, 0.5)
			if callbackVec then callbackVec(Vector2.new(0, 0)) end
		end
	end)

	table.insert(conexionesSueltas, c1)
	table.insert(conexionesSueltas, c2)
	table.insert(conexionesSueltas, c3)
end

-- map keyboard keys and gamepad thumbstick to a Vector2 callback
local function mapearJoystickTecladoGamepad(nombreAccion, teclasMapping, thumbstickEnum, callback)
	local vec = Vector2.new(0, 0)
	local function onInput(action, state, input)
		if input.KeyCode == thumbstickEnum then
			vec = Vector2.new(input.Position.X, input.Position.Y)
		else
			local val = (state == Enum.UserInputState.Begin) and 1 or 0
			if input.KeyCode == teclasMapping.Up    then vec = Vector2.new(vec.X,  val)
			elseif input.KeyCode == teclasMapping.Down  then vec = Vector2.new(vec.X, -val)
			elseif input.KeyCode == teclasMapping.Left  then vec = Vector2.new(-val, vec.Y)
			elseif input.KeyCode == teclasMapping.Right then vec = Vector2.new( val, vec.Y)
			end
		end
		if callback then callback(vec) end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction(nombreAccion, onInput, false, teclasMapping.Up, teclasMapping.Down, teclasMapping.Left, teclasMapping.Right, thumbstickEnum)
	table.insert(accionesActivas, nombreAccion)
end

-- bind 4-direction controls for oxybelis (snake)
function UniversalController.CrearControlesOxybelis(cbArr, cbAba, cbIzq, cbDer)
	UniversalController.LimpiarControles()

	local accs = {"Oxy_A", "Oxy_S", "Oxy_D", "Oxy_W"}
	for _, a in ipairs(accs) do table.insert(accionesActivas, a) end
	ContextActionService:BindAction("Oxy_W", cbArr, false, Enum.KeyCode.W, Enum.KeyCode.Up,    Enum.KeyCode.DPadUp)
	ContextActionService:BindAction("Oxy_S", cbAba, false, Enum.KeyCode.S, Enum.KeyCode.Down,  Enum.KeyCode.DPadDown)
	ContextActionService:BindAction("Oxy_A", cbIzq, false, Enum.KeyCode.A, Enum.KeyCode.Left,  Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("Oxy_D", cbDer, false, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		local cbs = {Arriba=cbArr, Abajo=cbAba, Izq=cbIzq, Der=cbDer}
		crearCrucetaCompleta(controlesVirtualesGui, "Izq", UDim2.new(0.15, 0, 0.70, 0), cbs)
		crearCrucetaCompleta(controlesVirtualesGui, "Der", UDim2.new(0.85, 0, 0.70, 0), cbs)
	end
end

-- bind single flap/jump action for avis toucan
function UniversalController.CrearControlesFlappy(cbSalto)
	UniversalController.LimpiarControles()

	table.insert(accionesActivas, "Flappy_Salto")
	ContextActionService:BindAction("Flappy_Salto", cbSalto, false, Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.ButtonA)

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		crearBotonCircular(controlesVirtualesGui, "Btn_Izq", UDim2.new(0.15, 0, 0.70, 0), "SPACE", cbSalto)
		crearBotonCircular(controlesVirtualesGui, "Btn_Der", UDim2.new(0.85, 0, 0.70, 0), "SPACE", cbSalto)
	end
end

-- bind left/right movement and launch for resilio (breakout)
function UniversalController.CrearControlesResilio(cbIzq, cbDer, cbLaunch)
	UniversalController.LimpiarControles()

	local accs = {"Resilio_A", "Resilio_D", "Resilio_Launch"}
	for _, a in ipairs(accs) do table.insert(accionesActivas, a) end
	ContextActionService:BindAction("Resilio_A",      cbIzq,   false, Enum.KeyCode.A, Enum.KeyCode.Left,  Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("Resilio_D",      cbDer,   false, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)
	ContextActionService:BindAction("Resilio_Launch", cbLaunch, false, Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.ButtonA, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		local cbs = {Izq=cbIzq, Der=cbDer, Launch=cbLaunch}
		crearCrucetaResilio(controlesVirtualesGui, "Izq", UDim2.new(0.15, 0, 0.70, 0), cbs)
		crearCrucetaResilio(controlesVirtualesGui, "Der", UDim2.new(0.85, 0, 0.70, 0), cbs)
	end
end

-- bind 4-direction controls for foxy fruit (pac-man style)
function UniversalController.CrearControlesFoxyFruit(cbArr, cbAba, cbIzq, cbDer)
	UniversalController.LimpiarControles()

	local accs = {"Foxy_A", "Foxy_S", "Foxy_D", "Foxy_W"}
	for _, a in ipairs(accs) do table.insert(accionesActivas, a) end
	ContextActionService:BindAction("Foxy_W", cbArr, false, Enum.KeyCode.W, Enum.KeyCode.Up,    Enum.KeyCode.DPadUp)
	ContextActionService:BindAction("Foxy_S", cbAba, false, Enum.KeyCode.S, Enum.KeyCode.Down,  Enum.KeyCode.DPadDown)
	ContextActionService:BindAction("Foxy_A", cbIzq, false, Enum.KeyCode.A, Enum.KeyCode.Left,  Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("Foxy_D", cbDer, false, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		local cbs = {Arriba=cbArr, Abajo=cbAba, Izq=cbIzq, Der=cbDer}
		crearCrucetaCompleta(controlesVirtualesGui, "Izq", UDim2.new(0.15, 0, 0.70, 0), cbs)
		crearCrucetaCompleta(controlesVirtualesGui, "Der", UDim2.new(0.85, 0, 0.70, 0), cbs)
	end
end

-- bind 4-direction movement plus fire button for firmament defender
function UniversalController.CrearControlesFirmament(cbArr, cbAba, cbIzq, cbDer, cbDisparo)
	UniversalController.LimpiarControles()

	local accs = {"Firm_Arriba", "Firm_Abajo", "Firm_Izquierda", "Firm_Derecha", "Firm_Disparo"}
	for _, a in ipairs(accs) do table.insert(accionesActivas, a) end
	ContextActionService:BindAction("Firm_Arriba",    cbArr,    false, Enum.KeyCode.W, Enum.KeyCode.Up,    Enum.KeyCode.DPadUp)
	ContextActionService:BindAction("Firm_Abajo",     cbAba,    false, Enum.KeyCode.S, Enum.KeyCode.Down,  Enum.KeyCode.DPadDown)
	ContextActionService:BindAction("Firm_Izquierda", cbIzq,    false, Enum.KeyCode.A, Enum.KeyCode.Left,  Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("Firm_Derecha",   cbDer,    false, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)
	ContextActionService:BindAction("Firm_Disparo",   cbDisparo, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2, Enum.UserInputType.MouseButton1)

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		local cbs = {Arriba = cbArr, Abajo = cbAba, Izq = cbIzq, Der = cbDer}
		crearCrucetaCompleta(controlesVirtualesGui, "CrucetaIzquierda", UDim2.new(0.18, 0, 0.55, 0), cbs)
		crearBotonCircular(controlesVirtualesGui, "Boton_Shoot_Izq", UDim2.new(0.18, 0, 0.85, 0), "FIRE", cbDisparo)
		crearCrucetaCompleta(controlesVirtualesGui, "CrucetaDerecha", UDim2.new(0.82, 0, 0.55, 0), cbs)
		crearBotonCircular(controlesVirtualesGui, "Boton_Shoot_Der", UDim2.new(0.82, 0, 0.85, 0), "FIRE", cbDisparo)
	end
end

-- bind dual joystick and fire for firmament siege (twin-stick shooter)
function UniversalController.CrearControlesFirmamentSiege(cbJoyIzq, cbJoyDer, cbDisparo)
	UniversalController.LimpiarControles()

	mapearJoystickTecladoGamepad("GVD_JoyL", {Up=Enum.KeyCode.W,   Down=Enum.KeyCode.S,    Left=Enum.KeyCode.A,    Right=Enum.KeyCode.D},    Enum.KeyCode.Thumbstick1, cbJoyIzq)
	mapearJoystickTecladoGamepad("GVD_JoyR", {Up=Enum.KeyCode.Up,  Down=Enum.KeyCode.Down,  Left=Enum.KeyCode.Left, Right=Enum.KeyCode.Right}, Enum.KeyCode.Thumbstick2, cbJoyDer)

	local function disparoSeguro(action, state, input)
		cbDisparo(action, state, input)
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindAction("GVD_Disparo", disparoSeguro, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
	table.insert(accionesActivas, "GVD_Disparo")

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		crearJoystick(controlesVirtualesGui, "JoyIzq", UDim2.new(0.18, 0, 0.55, 0), "", cbJoyIzq)
		crearBotonCircular(controlesVirtualesGui, "Boton_Shoot_Izq", UDim2.new(0.18, 0, 0.85, 0), "FIRE", cbDisparo)
		crearJoystick(controlesVirtualesGui, "JoyDer", UDim2.new(0.82, 0, 0.55, 0), "CAMERA", cbJoyDer)
		crearBotonCircular(controlesVirtualesGui, "Boton_Shoot_Der", UDim2.new(0.82, 0, 0.85, 0), "FIRE", cbDisparo)
	end
end

-- bind joystick and cut action for juice cutter
function UniversalController.CrearControlesJuiceCutter(cbJoystick, cbCorte)
	UniversalController.LimpiarControles()

	local acciones = {"Juice_Joystick", "Juice_Corte"}
	for _, a in ipairs(acciones) do table.insert(accionesActivas, a) end

	local function onJoystick(actionName, inputState, inputObject)
		local vec = Vector2.new(inputObject.Position.X, -inputObject.Position.Y)
		if cbJoystick then cbJoystick(vec) end
		return Enum.ContextActionResult.Pass
	end

	local function onCorteSeguro(actionName, inputState, inputObject)
		if cbCorte then cbCorte(actionName, inputState, inputObject) end
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindAction("Juice_Joystick", onJoystick, false, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2)
	ContextActionService:BindAction("Juice_Corte", onCorteSeguro, false,
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonA,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.MouseMovement,
		Enum.UserInputType.Touch
	)
end

-- bind single drop/place action for turris casei (stack game)
function UniversalController.CrearControlesTurris(cbPlace)
	UniversalController.LimpiarControles()

	table.insert(accionesActivas, "Turris_Drop")
	local function onInput(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then cbPlace() end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("Turris_Drop", onInput, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		crearBotonCircular(controlesVirtualesGui, "Btn_Drop", UDim2.new(0.85, 0, 0.70, 0), "DROP", function(nombre, state, input)
			if state == Enum.UserInputState.Begin then cbPlace() end
		end)
	end
end

-- bind hold/release action for tap and hold
function UniversalController.CrearControlesTapAndHold(cbAccion)
	UniversalController.LimpiarControles()

	table.insert(accionesActivas, "Tap_Accion")
	local function onInput(actionName, inputState, inputObject)
		cbAccion(inputState)
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("Tap_Accion", onInput, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		crearBotonCircular(controlesVirtualesGui, "Btn_Jump", UDim2.new(0.85, 0, 0.70, 0), "HOLD\nJUMP", function(nombre, state, input)
			cbAccion(state)
		end)
	end
end

-- bind dual joystick, jump and power for im not a sphere
function UniversalController.CrearControlesImNotASphere(cbMover, cbCamara, cbSalto, cbPoder)
	UniversalController.LimpiarControles()

	mapearJoystickTecladoGamepad("Sphere_Move", {Up=Enum.KeyCode.W,   Down=Enum.KeyCode.S,    Left=Enum.KeyCode.A,    Right=Enum.KeyCode.D},    Enum.KeyCode.Thumbstick1, cbMover)
	mapearJoystickTecladoGamepad("Sphere_Cam",  {Up=Enum.KeyCode.Up,  Down=Enum.KeyCode.Down,  Left=Enum.KeyCode.Left, Right=Enum.KeyCode.Right}, Enum.KeyCode.Thumbstick2, cbCamara)

	local function onJump(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then cbSalto() end
		return Enum.ContextActionResult.Sink
	end

	local function onPower(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then cbPoder() end
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindAction("Sphere_Jump",  onJump,  false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	table.insert(accionesActivas, "Sphere_Jump")

	ContextActionService:BindAction("Sphere_Power", onPower, false, Enum.KeyCode.ButtonR2, Enum.UserInputType.MouseButton1)
	table.insert(accionesActivas, "Sphere_Power")

	if UserInputService.TouchEnabled then
		controlesVirtualesGui = Instance.new("ScreenGui")
		controlesVirtualesGui.Name = "ControlesVirtualesArcade"
		controlesVirtualesGui.DisplayOrder = 99999
		controlesVirtualesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		crearJoystick(controlesVirtualesGui, "JoyIzq", UDim2.new(0.18, 0, 0.65, 0), "", cbMover)
		crearJoystick(controlesVirtualesGui, "JoyDer", UDim2.new(0.82, 0, 0.55, 0), "CAMERA", cbCamara)

		local tamanoJump  = UDim2.new(0.30, 0, 0.20, 0)
		local tamanoClick = UDim2.new(0.20, 0, 0.15, 0)

		crearBotonCircular(controlesVirtualesGui, "Btn_Click", UDim2.new(0.84, 0, 0.85, 0), "CLICK", function(nombre, state, input)
			if state == Enum.UserInputState.Begin then cbPoder() end
		end, tamanoClick)

		crearBotonCircular(controlesVirtualesGui, "Btn_Jump", UDim2.new(0.92, 0, 0.85, 0), "JUMP", function(nombre, state, input)
			if state == Enum.UserInputState.Begin then cbSalto() end
		end, tamanoJump)
	end
end


-- WORLD MOVEMENT: SPRINT ONLY
local SPEED_WALK   = 16
local SPEED_SPRINT = 28

local accionesMundo  = {}
local conexionesMundo = {}
local mundoGui        = nil
local estaCorriendo   = false

local function limpiarMovimientoMundo()
	for _, conn in ipairs(conexionesMundo) do
		if conn and typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
	end
	table.clear(conexionesMundo)
	for _, accion in ipairs(accionesMundo) do
		ContextActionService:UnbindAction(accion)
	end
	table.clear(accionesMundo)
	if mundoGui then mundoGui:Destroy(); mundoGui = nil end
	estaCorriendo = false
end

function UniversalController.IniciarMovimientoMundo()
	limpiarMovimientoMundo()

	local player   = Players.LocalPlayer
	local char     = player.Character or player.CharacterAdded:Wait()
	local humanoid = char:WaitForChild("Humanoid")

	local function onSprint(_, state, _)
		estaCorriendo = (state == Enum.UserInputState.Begin)
		-- SwimController enforces SPEED_SWIM every frame while in water,
		-- so sprint speed only takes effect when NOT swimming.
		humanoid.WalkSpeed = estaCorriendo and SPEED_SPRINT or SPEED_WALK
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindAction("Mundo_Sprint", onSprint, false,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.ButtonL3
	)
	table.insert(accionesMundo, "Mundo_Sprint")

	if UserInputService.TouchEnabled then
		mundoGui = Instance.new("ScreenGui")
		mundoGui.Name         = "WorldMovementGui"
		mundoGui.DisplayOrder = 9998
		mundoGui.ResetOnSpawn = false
		mundoGui.Parent       = player:WaitForChild("PlayerGui")

		crearBotonCircular(mundoGui, "Btn_Sprint",
			UDim2.new(0.12, 0, 0.88, 0),
			"RUN",
			function(_, state, _)
				estaCorriendo = (state == Enum.UserInputState.Begin)
				humanoid.WalkSpeed = estaCorriendo and SPEED_SPRINT or SPEED_WALK
			end,
			UDim2.new(0.14, 0, 0.10, 0)
		)
	end
end

function UniversalController.LimpiarMovimientoMundo()
	limpiarMovimientoMundo()
end

-- unbind all active actions, disconnect loose events and destroy virtual controls gui
function UniversalController.LimpiarControles()
	for _, accion in ipairs(accionesActivas) do
		ContextActionService:UnbindAction(accion)
	end
	table.clear(accionesActivas)

	for _, conn in ipairs(conexionesSueltas) do
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	table.clear(conexionesSueltas)

	if controlesVirtualesGui then
		controlesVirtualesGui:Destroy()
		controlesVirtualesGui = nil
	end

	-- also remove any leftover virtual gui that may have been reparented
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do
			if child.Name == "ControlesVirtualesArcade" then
				child:Destroy()
			end
		end
	end
end

return UniversalController
