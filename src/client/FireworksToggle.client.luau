-- Boton para ver o no los fuegos artificiales de otros jugadores.

local ToggleButton = require(script.Parent:WaitForChild("ToggleButton"))

ToggleButton.new({
	label          = "FIREWORKS",
	attribute      = "FireworksGlobalOn",
	order          = 1,
	onHint         = "Showing everyone's fireworks",
	offHint        = "Others' fireworks hidden",
	keyCode        = Enum.KeyCode.F,
	gamepadKeyCode = Enum.KeyCode.ButtonR3,
	actionName     = "FwGlobalToggle",
})
