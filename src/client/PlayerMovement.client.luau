local Players = game:GetService("Players")
local UC = require(script.Parent.UniversalController)

local function init()
	UC.IniciarMovimientoMundo()
end

init()

-- re-bind sprint controls after each respawn (swimming is handled by SwimController)
Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	init()
end)
