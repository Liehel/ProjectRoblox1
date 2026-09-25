-- FireworksServer.server.luau
-- Creates the remotes + the physical button, validates launches (cooldowns),
-- and broadcasts to every client so all players see the show.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local FireworksModule    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FireworksModule"))
local RemoteGuard        = require(ServerScriptService:WaitForChild("RemoteGuard"))
local FireworksInventory = require(ServerScriptService:WaitForChild("FireworksInventory"))
local is = RemoteGuard.is

-- ── Remotes ───────────────────────────────────────────────────────────────
local folder = Instance.new("Folder")
folder.Name   = FireworksModule.RemoteFolderName
folder.Parent = ReplicatedStorage

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

local rRequest = makeRemote(FireworksModule.Remotes.RequestLaunch)
local rOpen    = makeRemote(FireworksModule.Remotes.OpenMenu)
local rPlay    = makeRemote(FireworksModule.Remotes.PlayFirework)
local rNotify  = makeRemote("Notify")        -- server -> client messages
local rAvail   = makeRemote("Availability")  -- server -> client per-type availability

FireworksInventory.SetNotifier(rNotify)
FireworksInventory.SetAvailabilityRemote(rAvail)
FireworksInventory.Start()

-- ── Button: reuse an existing one named FireworksButton, else create it ────
local function getOrCreateButton()
	local existing = workspace:FindFirstChild(FireworksModule.ButtonName, true)
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local part = Instance.new("Part")
	part.Name        = FireworksModule.ButtonName
	part.Size        = Vector3.new(4, 6, 4)
	part.Position    = Vector3.new(0, 6, 0)  -- move this to wherever you like in Studio
	part.Anchored    = true
	part.Material    = Enum.Material.Neon
	part.Color       = Color3.fromRGB(154, 230, 0)
	part.Parent      = workspace

	local billboard = Instance.new("BillboardGui", part)
	billboard.Size           = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset    = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop    = true
	billboard.MaxDistance    = 60
	local lbl = Instance.new("TextLabel", billboard)
	lbl.Size                  = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text                  = "FIREWORKS"
	lbl.Font                  = Enum.Font.GothamBlack
	lbl.TextScaled            = true
	lbl.TextColor3            = Color3.fromRGB(216, 249, 153)
	lbl.TextStrokeTransparency = 0.4

	return part
end

local button = getOrCreateButton()

-- ProximityPrompt is natively cross-platform: keyboard key, gamepad button,
-- and a tappable prompt on mobile.
local prompt = button:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText        = "Fireworks"
	prompt.ObjectText        = "Launch Pad"
	prompt.HoldDuration      = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight   = false
	prompt.KeyboardKeyCode   = Enum.KeyCode.E
	prompt.GamepadKeyCode    = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt   = true
	prompt.Parent            = button
end

-- ── Launch (unlimited use; per-player rate-limit handled by RemoteGuard) ──
local lastOpen = {}   -- userId -> os.clock()
local lastBig  = 0    -- server-wide timestamp of the last colossal show

-- Server-wide broadcast budget. Each FireAllClients fans out to EVERY player,
-- so the real cost grows with player count. This caps total broadcasts/second
-- across the whole server so a packed lobby spamming can never melt the network.
local GLOBAL_BUDGET = 20   -- max fireworks broadcasts per second, server-wide
local budgetCount   = 0
local budgetWindow  = 0
local function canBroadcast()
	local now = os.clock()
	if now - budgetWindow >= 1 then budgetWindow = now; budgetCount = 0 end
	if budgetCount >= GLOBAL_BUDGET then return false end
	budgetCount += 1
	return true
end

prompt.Triggered:Connect(function(plr)
	local now = os.clock()
	if now - (lastOpen[plr.UserId] or 0) < 0.3 then return end
	lastOpen[plr.UserId] = now
	FireworksInventory.RefreshAvailability(plr)  -- fresh greying state for the menu
	rOpen:FireClient(plr)
end)

-- All validation (rate-limit + arg type/range) now runs in RemoteGuard, so the
-- handler can trust `index` is an integer within the catalog.
RemoteGuard.onEvent(rRequest, {
	rate = { max = 12, per = 1 },                  -- <=12 launches/sec per player
	args = { is.integer(1, #FireworksModule.Types) },
}, function(plr, index)
	local def = FireworksModule.Types[index]
	local isBig = (def.kind == "comet" or def.kind == "mega" or def.kind == "explosion")

	-- 1) does the player have the resource? (peek, no spend yet)
	local ok, reason = FireworksInventory.canLaunch(plr, index)
	if not ok then
		rNotify:FireClient(plr, reason)
		return
	end

	-- 2) server-wide colossal cooldown (don't spend the resource if blocked)
	if isBig and (os.clock() - lastBig < FireworksModule.BigCooldown) then
		rNotify:FireClient(plr, "The sky is busy, try again in a moment")
		return
	end

	-- 3) broadcast budget (network safety; don't spend if dropped)
	if not canBroadcast() then
		rNotify:FireClient(plr, "Too many fireworks right now, try again")
		return
	end

	-- 4) all checks passed: spend the resource and broadcast to everyone
	FireworksInventory.commit(plr, index)
	if isBig then lastBig = os.clock() end

	-- launch origin: a part named "FireworksSpawn" if present, else the button.
	-- (Tony/17 ignores this and crosses the sky; the rest rise from here.)
	local spawnPart = workspace:FindFirstChild("FireworksSpawn", true)
	local base = (spawnPart and spawnPart:IsA("BasePart") and spawnPart.Position) or button.Position

	-- small random horizontal offset so simultaneous launches don't overlap
	local spread = isBig and 45 or 20
	local origin = base + Vector3.new(
		(math.random() * 2 - 1) * spread, 0, (math.random() * 2 - 1) * spread)
	rPlay:FireAllClients(index, origin, plr, 1)
end)

Players.PlayerRemoving:Connect(function(plr)
	lastOpen[plr.UserId] = nil
end)
