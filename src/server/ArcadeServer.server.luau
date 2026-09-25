local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local function findRemoteByName(name)
	for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
		if inst:IsA("RemoteEvent") and inst.Name == name then
			return inst
		end
	end
	return nil
end

local OpenArcadeMenu = findRemoteByName("OpenArcadeMenu")
if not OpenArcadeMenu then
	warn("ArcadeServer: OpenArcadeMenu RemoteEvent not found.")
	return
end


-- Antes de meter a nadie en un juego, apuntamos donde estaba plantado. Al salir
-- el personaje suele caer por debajo de MIN_Y y RespawnSystem lo mandaba al
-- spawn de la isla; con esto vuelve justo delante de la maquina que uso.
local ARCADE_RETURN_ATTR = "ArcadeReturnCF"

local function rememberReturn(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		player:SetAttribute(ARCADE_RETURN_ATTR, hrp.CFrame)
	end
end

-- returns the first basepart inside a descriptor or model
local function firstBasePartIn(desc)
	if desc:IsA("BasePart") then return desc end
	if desc:IsA("Model") then
		if desc.PrimaryPart and desc.PrimaryPart:IsA("BasePart") then return desc.PrimaryPart end
		for _,d in ipairs(desc:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
	end
	return nil
end

-- adds a click detector and proximity prompt to a tagged part that opens the arcade menu
local function setupButtonForGame(inst, gameName, displayName)
	local part = firstBasePartIn(inst)
	if not part then return end

	local nameToShow = displayName or gameName

	local click = part:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
	click.MaxActivationDistance = 10
	click.Parent = part
	click.MouseClick:Connect(function(player)
		rememberReturn(player)
		OpenArcadeMenu:FireClient(player, gameName)
	end)

	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ObjectText = "Arcade"
	prompt.ActionText = "Play " .. nameToShow
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		rememberReturn(player)
		OpenArcadeMenu:FireClient(player, gameName)
	end)
end

-- wire up all parts already tagged at startup
for _,b in ipairs(CollectionService:GetTagged("ButtonOxybelis")) do setupButtonForGame(b, "Oxybelis", "Oxybelis") end
for _,b in ipairs(CollectionService:GetTagged("ButtonAvisToucan")) do setupButtonForGame(b, "AvisToucan", "Avis Toucan") end
for _,b in ipairs(CollectionService:GetTagged("ButtonResilio")) do setupButtonForGame(b, "Resilio", "Resilio") end
for _,b in ipairs(CollectionService:GetTagged("ButtonFoxyFruit")) do setupButtonForGame(b, "FoxyFruit", "Foxy Fruit") end
for _,b in ipairs(CollectionService:GetTagged("ButtonFirmamentDefender")) do setupButtonForGame(b, "FirmamentDefender", "Firmament Defender") end
for _,b in ipairs(CollectionService:GetTagged("ButtonFirmamentSiege")) do setupButtonForGame(b, "FirmamentSiege", "Firmament Siege") end
for _,b in ipairs(CollectionService:GetTagged("ButtonJuiceCutter")) do setupButtonForGame(b, "JuiceCutter", "Juice Cutter") end
for _,b in ipairs(CollectionService:GetTagged("TurrisTerminal")) do setupButtonForGame(b, "TurrisCasei", "Turris Casei") end
for _,b in ipairs(CollectionService:GetTagged("TapAndHoldTerminal")) do setupButtonForGame(b, "TapAndHold", "Tap-and-Hold Jumper") end
for _,b in ipairs(CollectionService:GetTagged("ImNotASphereTerminal")) do setupButtonForGame(b, "ImNotASphere", "I'm Not A Sphere") end

-- also wire up parts added dynamically after server start
CollectionService:GetInstanceAddedSignal("ButtonOxybelis"):Connect(function(b) setupButtonForGame(b, "Oxybelis", "Oxybelis") end)
CollectionService:GetInstanceAddedSignal("ButtonAvisToucan"):Connect(function(b) setupButtonForGame(b, "AvisToucan", "Avis Toucan") end)
CollectionService:GetInstanceAddedSignal("ButtonResilio"):Connect(function(b) setupButtonForGame(b, "Resilio", "Resilio") end)
CollectionService:GetInstanceAddedSignal("ButtonFoxyFruit"):Connect(function(b) setupButtonForGame(b, "FoxyFruit", "Foxy Fruit") end)
CollectionService:GetInstanceAddedSignal("ButtonFirmamentDefender"):Connect(function(b) setupButtonForGame(b, "FirmamentDefender", "Firmament Defender") end)
CollectionService:GetInstanceAddedSignal("ButtonFirmamentSiege"):Connect(function(b) setupButtonForGame(b, "FirmamentSiege", "Firmament Siege") end)
CollectionService:GetInstanceAddedSignal("ButtonJuiceCutter"):Connect(function(b) setupButtonForGame(b, "JuiceCutter", "Juice Cutter") end)
CollectionService:GetInstanceAddedSignal("TurrisTerminal"):Connect(function(b) setupButtonForGame(b, "TurrisCasei", "Turris Casei") end)
CollectionService:GetInstanceAddedSignal("TapAndHoldTerminal"):Connect(function(b) setupButtonForGame(b, "TapAndHold", "Tap-and-Hold Jumper") end)
CollectionService:GetInstanceAddedSignal("ImNotASphereTerminal"):Connect(function(b) setupButtonForGame(b, "ImNotASphere", "I'm Not A Sphere") end)
