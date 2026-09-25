-- Voice chat stays on in private/reserved servers, muted in public servers.
-- Requires voice enabled for the experience in the Creator Dashboard; this only
-- gates it. Mutes via the Audio API (AudioDeviceInput.Active = false).

local Players = game:GetService("Players")

-- private/reserved servers have a PrivateServerId.
-- For player-owned VIP servers only, use: game.PrivateServerOwnerId ~= 0
local VOICE_ALLOWED = game.PrivateServerId ~= ""

if VOICE_ALLOWED then
	return  -- private server: leave voice enabled
end

-- public server: keep every mic disabled
local function enforceMuted(device)
	if not device:IsA("AudioDeviceInput") then return end
	device.Active = false
	device:GetPropertyChangedSignal("Active"):Connect(function()
		if device.Active then
			device.Active = false  -- block any attempt to re-enable
		end
	end)
end

local function onPlayer(player)
	for _, child in ipairs(player:GetChildren()) do
		enforceMuted(child)
	end
	-- the AudioDeviceInput is added a moment after the player joins
	player.ChildAdded:Connect(enforceMuted)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
