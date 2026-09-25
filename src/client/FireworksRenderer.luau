-- FireworksRenderer.luau  (ModuleScript, client)
-- Renders every firework kind locally. Pools all parts so a busy sky never
-- thrashes the GC; particle counts scale with device tier (PC/console/mobile).

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local GuiService        = game:GetService("GuiService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local FireworksModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FireworksModule"))

local Renderer = {}

local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

-- ── Device quality ────────────────────────────────────────────────────────
local function deviceTier()
	if GuiService:IsTenFootInterface() then return "console" end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return "mobile" end
	return "pc"
end
local TIER       = deviceTier()
local QUALITY    = ({ pc = 1.0, console = 0.72, mobile = 0.45 })[TIER]
local MAX_NORMAL = (TIER == "mobile") and 8 or 18

-- ── Performance safeguards ────────────────────────────────────────────────
-- Per-burst dynamic lights are the #1 mobile cost; neon already self-glows,
-- so we drop them on phones.
local USE_LIGHTS = (TIER ~= "mobile")
-- How many colossal shows (comet/mega/explosion) may render at once on THIS
-- device. Extra ones degrade to a single big burst so the device never chokes
-- even if a full lobby spams them.
local MAX_BIG  = (TIER == "mobile") and 1 or 2
local activeBig = 0

-- Global look tuning (edit to change height / width / size of all fireworks)
local APEX_SCALE  = 0.62  -- height: lower = fireworks lower in the sky
local WIDTH_SCALE = 1.45  -- radius: higher = wider bursts
local SIZE_SCALE  = 1.5   -- spark size: higher = thicker

-- ── Effects container ─────────────────────────────────────────────────────
local effectsFolder = workspace:FindFirstChild("FireworkEffects")
if not effectsFolder then
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "FireworkEffects"
	effectsFolder.Parent = workspace
end

-- ── Helpers ───────────────────────────────────────────────────────────────
local function rand(a, b) return a + math.random() * (b - a) end

local function colorSeq(colors)
	if #colors == 1 then return ColorSequence.new(colors[1]) end
	local kp = {}
	for i, c in ipairs(colors) do
		kp[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)
	end
	return ColorSequence.new(kp)
end

local function lighten(c, f)
	return Color3.new(c.R + (1 - c.R) * f, c.G + (1 - c.G) * f, c.B + (1 - c.B) * f)
end

-- Cabeza blanca que se enfria hasta el color del fuego.
local function hotSeq(colors)
	local kp = {
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 248)),
		ColorSequenceKeypoint.new(0.10, lighten(colors[1], 0.62)),
	}
	local n = #colors
	for i = 1, n do
		kp[#kp + 1] = ColorSequenceKeypoint.new(math.min(0.10 + 0.82 * (i / n), 0.97), colors[i])
	end
	kp[#kp + 1] = ColorSequenceKeypoint.new(1, colors[n])
	return ColorSequence.new(kp)
end

-- ── Shockwave (one neon sphere, pooled) ───────────────────────────────────
-- Onda expansiva: una esfera Neon que se expande y se desvanece.
local wavePool = {}
local function newWavePart()
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(1, 1, 1)
	p.Material = Enum.Material.Neon; p.Anchored = true
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false; p.Locked = true; p.Transparency = 1
	p.Parent = effectsFolder
	return p
end

local function shockwave(center, radius, color, dur)
	if TIER == "mobile" and radius < 34 then return end  -- phones: only the big ones
	local p = table.remove(wavePool) or newWavePart()
	p.Color = color
	p.Position = center
	p.Size = Vector3.new(2, 2, 2)
	p.Transparency = 0.55
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius, radius, radius), Transparency = 1,
	}):Play()
	task.delay(dur + 0.06, function()
		p.Transparency = 1
		table.insert(wavePool, p)
	end)
end

-- Flicker transparency for strobe (alternating visible / invisible)
local STROBE_SEQ do
	local kp = {}
	local n = 14
	for i = 0, n do
		local t = i / n
		kp[#kp + 1] = NumberSequenceKeypoint.new(t, (i % 2 == 0) and 0 or 1)
	end
	STROBE_SEQ = NumberSequence.new(kp)
end

local FADE_SEQ = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.75, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})

-- ── Burst part pool ───────────────────────────────────────────────────────
local burstPool = {}

local function newBurstPart()
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false; part.CanQuery = false; part.CanTouch = false
	part.CastShadow = false; part.Locked = true

	-- Tres capas por rafaga que se reparten el mismo presupuesto de particulas.
	for _, layer in ipairs({ "Burst", "Core", "Glitter", "Pistil" }) do
		local e = Instance.new("ParticleEmitter")
		e.Name = layer; e.Enabled = false
		e.Texture = SPARK_TEX
		e.LightEmission = 1; e.LightInfluence = 0
		e.Rotation = NumberRange.new(0, 360)
		pcall(function() e.Brightness = 2.6 end)  -- HDR bloom, free
		e.Parent = part
	end

	if USE_LIGHTS then
		local l = Instance.new("PointLight")
		l.Name = "Glow"; l.Range = 32; l.Brightness = 0
		l.Parent = part
	end

	part.Parent = effectsFolder
	return part
end

local function acquireBurst() return table.remove(burstPool) or newBurstPart() end
local function releaseBurst(part)
	for _, layer in ipairs({ "Burst", "Core", "Glitter", "Pistil" }) do
		local e = part:FindFirstChild(layer); if e then e.Enabled = false end
	end
	local l = part:FindFirstChild("Glow");  if l then l.Brightness = 0 end
	table.insert(burstPool, part)
end

-- Fire one configured burst at a position
local function explode(def, position, sizeMul, overrides)
	sizeMul = sizeMul or 1
	overrides = overrides or {}
	local part = acquireBurst()
	part.Position = position
	local cols = overrides.colors or def.colors
	local s    = (def.size or 1) * sizeMul * SIZE_SCALE
	local spd  = (def.speed or 50) * WIDTH_SCALE  -- wider bursts
	local life = def.lifetime or 1.5

	-- Presupuesto a repartir entre las capas.
	local budget = math.max(8, math.floor((def.count or 120) * sizeMul * QUALITY))

	-- Capa 1: petalos de color, la forma reconocible.
	local e = part.Burst
	e.Color        = hotSeq(cols)
	e.Lifetime     = NumberRange.new(life * 0.72, life)
	e.Speed        = NumberRange.new(spd * sizeMul * 0.6, spd * sizeMul)
	e.SpreadAngle  = Vector2.new(def.spread or 175, def.spread or 175)
	e.Acceleration = Vector3.new(0, def.accelY or -25, 0)
	e.Drag         = def.drag or 2
	e.EmissionDirection = Enum.NormalId.Top
	e.Squash       = NumberSequence.new(def.squash or 0)
	e.RotSpeed     = def.erratic and NumberRange.new(-200, 200) or NumberRange.new(0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s * 1.15),
		NumberSequenceKeypoint.new(0.18, s),
		NumberSequenceKeypoint.new(0.65, s * 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = def.strobe and STROBE_SEQ or FADE_SEQ
	e:Emit(math.floor(budget * 0.70))

	-- Capa 2: destello de ignicion, nucleo blanco muy corto.
	local core = part.Core
	core.Color        = ColorSequence.new(Color3.fromRGB(255, 255, 245), lighten(cols[1], 0.5))
	core.Lifetime     = NumberRange.new(0.16, 0.36)
	core.Speed        = NumberRange.new(spd * sizeMul * 0.08, spd * sizeMul * 0.32)
	core.SpreadAngle  = Vector2.new(180, 180)
	core.Acceleration = Vector3.new(0, 0, 0)
	core.Drag         = 8
	core.Squash       = NumberSequence.new(0)
	core.RotSpeed     = NumberRange.new(0)
	core.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s * 1.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	core.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	core:Emit(math.floor(budget * 0.15))

	-- ── Layer 3: embers that hang and twinkle after the petals die ──
	-- The lingering sparkle is what sells the whole thing. Phones skip it.
	if TIER ~= "mobile" then
		local g = part.Glitter
		g.Color        = ColorSequence.new(lighten(cols[#cols], 0.30))
		g.Lifetime     = NumberRange.new(life * 1.15, life * 1.95)
		g.Speed        = NumberRange.new(spd * sizeMul * 0.18, spd * sizeMul * 0.7)
		g.SpreadAngle  = Vector2.new(180, 180)
		g.Acceleration = Vector3.new(0, (def.accelY or -25) * 0.5, 0)
		g.Drag         = (def.drag or 2) + 1.8
		g.Squash       = NumberSequence.new(0)
		g.RotSpeed     = NumberRange.new(-120, 120)
		g.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, s * 0.42),
			NumberSequenceKeypoint.new(0.5, s * 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		g.Transparency = STROBE_SEQ
		g:Emit(math.floor(budget * 0.15))
	end

	-- Onda expansiva.
	shockwave(position, spd * sizeMul * 0.17 + s * 2.5, lighten(cols[1], 0.35),
		0.40 + 0.10 * sizeMul)

	-- Pistil: flor interior brillante. Emisor propio para no repintar el nucleo.
	if def.pistil then
		local p2 = part.Pistil
		p2.Color        = ColorSequence.new(Color3.fromRGB(210, 240, 255), Color3.fromRGB(140, 205, 255))
		p2.Lifetime     = NumberRange.new(life * 0.5, life * 0.85)
		p2.Speed        = NumberRange.new(6, 20)
		p2.SpreadAngle  = Vector2.new(180, 180)
		p2.Acceleration = Vector3.new(0, (def.accelY or -25) * 0.4, 0)
		p2.Drag         = 3
		p2.Squash       = NumberSequence.new(0)
		p2.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, s * 0.85),
			NumberSequenceKeypoint.new(1, 0),
		})
		p2.Transparency = FADE_SEQ
		p2:Emit(math.floor(budget * 0.30))
	end

	-- glow (skipped on mobile)
	local l = part:FindFirstChild("Glow")
	if l then
		l.Color = cols[1]
		l.Brightness = 7 * sizeMul
		l.Range = math.clamp(30 * sizeMul, 16, 64)
		TweenService:Create(l, TweenInfo.new(0.55), { Brightness = 0 }):Play()
	end

	-- hold the part until the longest-lived layer has finished
	local hold = ((TIER ~= "mobile") and life * 1.95 or life) + 0.6
	task.delay(hold, releaseBurst, part)
	return part
end

-- ── Shell pool (rising streak) ────────────────────────────────────────────
local shellPool = {}

local function newShell()
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.6, 0.6, 0.6)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false; part.CanQuery = false; part.CanTouch = false
	part.CastShadow = false; part.Locked = true

	local a0 = Instance.new("Attachment"); a0.Name = "A0"; a0.Position = Vector3.new(0, 0.45, 0);  a0.Parent = part
	local a1 = Instance.new("Attachment"); a1.Name = "A1"; a1.Position = Vector3.new(0, -0.45, 0); a1.Parent = part
	local t = Instance.new("Trail")
	t.Name = "Trail"; t.Attachment0 = a0; t.Attachment1 = a1
	t.Lifetime = 0.45; t.LightEmission = 1; t.LightInfluence = 0
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	t.Parent = part

	-- Chispas que suelta la bengala al subir.
	local sp = Instance.new("ParticleEmitter")
	sp.Name = "Sparks"; sp.Enabled = false
	sp.Texture = SPARK_TEX
	sp.LightEmission = 1; sp.LightInfluence = 0
	sp.Lifetime = NumberRange.new(0.22, 0.55)
	sp.Speed = NumberRange.new(1, 7)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Acceleration = Vector3.new(0, -34, 0)
	sp.Drag = 1.5
	sp.Rotation = NumberRange.new(0, 360)
	sp.RotSpeed = NumberRange.new(-160, 160)
	sp.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	sp.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	pcall(function() sp.Brightness = 2.6 end)
	sp.Parent = part

	part.Parent = effectsFolder
	return part
end

local function acquireShell() return table.remove(shellPool) or newShell() end
local function releaseShell(part)
	local t = part:FindFirstChild("Trail"); if t then t.Enabled = false; t:Clear() end
	local sp = part:FindFirstChild("Sparks"); if sp then sp.Enabled = false end
	table.insert(shellPool, part)
end

-- Rise a shell from origin to apex, then call onArrive(apexPos).
-- If a tracker table is passed, tracker.part follows the live shell so the
-- camera can chase the projectile.
local function riseShell(def, origin, onArrive, tracker)
	local a = def.ascent or {}
	local apexH = (def.apex or 140) * APEX_SCALE  -- global height scale
	local apexPos = origin + Vector3.new(rand(-10, 10), apexH + rand(-10, 10), rand(-10, 10))
	local shell = acquireShell()
	shell.Color = def.swatch
	shell.Position = origin
	if tracker then tracker.part = shell end
	local t = shell.Trail
	t.Color = ColorSequence.new(def.swatch)
	t.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, a.trail or 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	t.Enabled = true

	if not a.silent then
		local sp = shell:FindFirstChild("Sparks")
		if sp then
			sp.Color = ColorSequence.new(lighten(def.swatch, 0.45), def.swatch)
			sp.Rate = math.floor(70 * QUALITY * (a.trail or 1))
			sp.Enabled = true
		end
	end

	local riseTime = (a.speed or 1) * rand(0.85, 1.0)
	local tw = TweenService:Create(shell, TweenInfo.new(riseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = apexPos,
	})
	tw:Play()
	tw.Completed:Once(function()
		onArrive(shell.Position)
		releaseShell(shell)
	end)
end

-- ── Ring pool (Saturn) ────────────────────────────────────────────────────
local ringPool = {}
local function newRingPart()
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(0.8, 0.8, 0.8)
	p.Material = Enum.Material.Neon; p.Anchored = true
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Locked = true
	p.Transparency = 1; p.Parent = effectsFolder
	return p
end
local function ringEffect(def, center)
	local count = math.max(10, math.floor(26 * QUALITY))
	local radius = (def.size or 1) * 9
	local tilt = math.rad(def.ringTilt or 25)
	local basis = CFrame.new(center) * CFrame.Angles(tilt, rand(0, math.pi * 2), 0)
	for i = 1, count do
		local ang = (i / count) * math.pi * 2
		local p = table.remove(ringPool) or newRingPart()
		p.Color = def.ringColor or def.swatch
		p.Size = Vector3.new(0.8, 0.8, 0.8)
		p.Transparency = 0
		p.CFrame = CFrame.new(center)
		local target = basis * CFrame.new(math.cos(ang) * radius, 0, math.sin(ang) * radius)
		TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = target, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
		}):Play()
		task.delay(0.9, function() table.insert(ringPool, p) end)
	end
end

-- ── Screen flash (sky-light, never touches Lighting) ──────────────────────
local function screenFlash(peak, upT, downT, tint)
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FwFlash"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 50; gui.ResetOnSpawn = false
	gui.Parent = pg
	local f = Instance.new("Frame", gui)
	f.Size = UDim2.fromScale(1, 1); f.BorderSizePixel = 0
	f.BackgroundColor3 = tint or Color3.fromRGB(225, 240, 255)
	f.BackgroundTransparency = 1
	TweenService:Create(f, TweenInfo.new(upT, Enum.EasingStyle.Quad), { BackgroundTransparency = peak }):Play()
	task.delay(upT, function()
		TweenService:Create(f, TweenInfo.new(downT, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		task.delay(downT + 0.1, function() gui:Destroy() end)
	end)
end

-- ── Sky darkening (for the big shows: comet / mega / explosion) ───────────
-- We darken via Brightness + ClockTime (night) + ambient - NOT exposure, which
-- would also dim the neon fireworks. Neon self-illuminates, so it stays bright
-- against the dark sky. IslandSky watches "FireworkOverride" and backs off
-- while it is set, then restores the sunset once we clear it.
local darkenToken = 0
-- restore values match IslandSky.applyIslandLook so the handoff is seamless
local DAY = { ClockTime = 18.1, Brightness = 2.2,
	OutdoorAmbient = Color3.fromRGB(200, 140, 100), Ambient = Color3.fromRGB(120, 100, 90) }
local NIGHT = { ClockTime = 24, Brightness = 0.3,
	OutdoorAmbient = Color3.fromRGB(18, 20, 38), Ambient = Color3.fromRGB(10, 12, 24) }

local function darkenSky(holdTime)
	darkenToken += 1
	local myToken = darkenToken
	Lighting:SetAttribute("FireworkOverride", true)
	TweenService:Create(Lighting, TweenInfo.new(0.9, Enum.EasingStyle.Quad), NIGHT):Play()

	task.delay(holdTime, function()
		if myToken ~= darkenToken then return end  -- a newer darken is in charge
		-- SNAP the sky color/time back instantly so it never sweeps through
		-- daytime; the sky is already the correct sunset, just still dark.
		Lighting.ClockTime      = DAY.ClockTime
		Lighting.OutdoorAmbient = DAY.OutdoorAmbient
		Lighting.Ambient        = DAY.Ambient
		-- then only fade the darkness out (brightness) - reveals the sunset
		local restore = TweenService:Create(Lighting, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
			Brightness = DAY.Brightness,
		})
		restore:Play()
		restore.Completed:Once(function()
			if myToken == darkenToken then
				Lighting:SetAttribute("FireworkOverride", nil)  -- let IslandSky resume
			end
		end)
	end)
end

-- ── Standard launch dispatcher for shell-based kinds ──────────────────────
local activeNormal = 0

local function launchBurst(def, origin, tracker)
	if activeNormal >= MAX_NORMAL then
		-- at capacity: don't render, but release the camera so it never hangs
		if tracker then tracker.exploded = true; tracker.explodePos = origin end
		return
	end
	activeNormal += 1
	riseShell(def, origin, function(apex)
		if tracker then tracker.exploded = true; tracker.explodePos = apex end
		if def.kind == "crossette" then
			-- primary big stars, then secondary detonations around them
			explode(def, apex, 1.4)
			task.delay(0.32, function()
				local n = math.max(4, math.floor(6 * QUALITY + 2))
				for i = 1, n do
					local off = Vector3.new(rand(-14, 14), rand(-6, 10), rand(-14, 14))
					explode(def, apex + off, 0.6, { colors = def.colors })
				end
			end)
		elseif def.kind == "ring" then
			explode(def, apex, 1)
			ringEffect(def, apex)
		else
			explode(def, apex, 1)
			if def.colorShift then
				-- Ghost shell: a second wave in the shifted color a beat later
				task.delay(0.25, function()
					explode(def, apex, 0.8, { colors = { def.colors[#def.colors] } })
				end)
			end
		end
		activeNormal -= 1
	end, tracker)
end

-- ── Mine: ground fountain (no shell) ──────────────────────────────────────
local function launchMine(def, origin, tracker)
	if tracker then tracker.exploded = true; tracker.explodePos = origin + Vector3.new(0, 35, 0) end
	local part = acquireBurst()
	part.Position = origin + Vector3.new(0, 2, 0)
	local e = part.Burst
	e.Color = colorSeq(def.colors)
	e.Lifetime = NumberRange.new(def.lifetime * 0.7, def.lifetime)
	e.Speed = NumberRange.new(def.speed * 0.7, def.speed)
	e.SpreadAngle = Vector2.new(def.spread, def.spread)
	e.Acceleration = Vector3.new(0, def.accelY, 0)
	e.Drag = def.drag
	e.EmissionDirection = Enum.NormalId.Top
	e.Squash = NumberSequence.new(def.squash or 2)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, def.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = FADE_SEQ
	e:Emit(math.floor(def.count * QUALITY))
	local l = part:FindFirstChild("Glow")
	if l then
		l.Color = def.colors[1]; l.Brightness = 5; l.Range = 40
		TweenService:Create(l, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	end
	task.delay(def.lifetime + 0.6, releaseBurst, part)
end

-- ── Salute: blinding flash, no fall ───────────────────────────────────────
local function launchSalute(def, origin, tracker)
	riseShell({ swatch = def.swatch, ascent = { trail = 0.5, speed = 0.7 }, apex = def.apex or 130 }, origin, function(apex)
		if tracker then tracker.exploded = true; tracker.explodePos = apex end
		local part = acquireBurst()
		part.Position = apex
		local e = part.Burst
		e.Color = colorSeq(def.colors)
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(45, 80)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -10, 0)
		e.Drag = 6
		e.Squash = NumberSequence.new(0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.0), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		e:Emit(math.floor(80 * QUALITY))
		local l = part:FindFirstChild("Glow")
		if l then
			l.Color = def.colors[1]; l.Brightness = 16; l.Range = 60
			TweenService:Create(l, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		end
		-- blue flash (not white)
		screenFlash(0.55, 0.06, 0.3, Color3.fromRGB(120, 180, 255))
		task.delay(0.9, releaseBurst, part)
	end, tracker)
end

-- When MAX_BIG colossal shows already run on this device, extra presses
-- degrade to one big burst so weak hardware never chokes (even a full lobby).
local function bigConsolation(def, origin, tracker)
	local pos = origin + Vector3.new(rand(-30, 30), 150 * APEX_SCALE, rand(-30, 30))
	if tracker then tracker.exploded = true; tracker.explodePos = pos; tracker.degraded = true end
	explode({ colors = def.colors, speed = 72, spread = 178, lifetime = 2.4, size = 2.0,
		accelY = -40, drag = 2.5, count = 200, squash = 3 }, pos, 2.4)
end

-- Tony: the comet, a diagonal shooting star
local function launchComet(def, origin, tracker)
	if activeBig >= MAX_BIG then return bigConsolation(def, origin, tracker) end
	activeBig += 1
	task.delay(9, function() activeBig -= 1 end)
	-- Diagonal arc: high on one side, swooping down across to the other side.
	local startP  = origin + Vector3.new(-300, 210, 150)
	local finishP = origin + Vector3.new( 280, 95, -90)
	local crossT  = 4.2

	local comet = Instance.new("Part")
	comet.Shape = Enum.PartType.Ball
	comet.Size = Vector3.new(26, 26, 26) * (0.75 + 0.25 * QUALITY)  -- big bright head
	comet.Material = Enum.Material.Neon
	comet.Color = def.colors[1]
	comet.Anchored = true
	comet.CanCollide = false; comet.CanQuery = false; comet.CanTouch = false; comet.CastShadow = false
	comet.Position = startP
	comet.Parent = effectsFolder
	if tracker then tracker.part = comet end

	-- wide glowing tail
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 7, 0);  a0.Parent = comet
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -7, 0); a1.Parent = comet
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0; trail.Attachment1 = a1
	trail.Lifetime = 2.6; trail.LightEmission = 1; trail.LightInfluence = 0
	trail.Color = colorSeq(def.colors)
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 0) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = comet

	local light = Instance.new("PointLight", comet)
	light.Range = 60; light.Brightness = 14; light.Color = def.colors[2] or def.colors[1]

	-- dense sparkle field shedding from the head (the Genshin "stardust")
	local shed = Instance.new("ParticleEmitter", comet)
	shed.Texture = SPARK_TEX; shed.Color = colorSeq(def.colors)
	shed.LightEmission = 1; shed.LightInfluence = 0
	shed.Rate = math.floor(260 * QUALITY)
	shed.Speed = NumberRange.new(2, 10)
	shed.Lifetime = NumberRange.new(0.8, 1.8)
	shed.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0) })
	shed.SpreadAngle = Vector2.new(180, 180)
	shed.Squash = NumberSequence.new(3)

	-- darken the sky so the comet + shower stand out, then restore
	darkenSky(crossT + 4.5)
	-- soft violet sky glow as it sweeps across (no harsh white flash)
	screenFlash(0.74, crossT * 0.45, crossT * 0.55, Color3.fromRGB(150, 120, 235))

	local tw = TweenService:Create(comet, TweenInfo.new(crossT, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Position = finishP,
	})
	tw:Play()
	tw.Completed:Once(function()
		if tracker then tracker.exploded = true; tracker.explodePos = finishP end
		shed.Enabled = false
		TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
		task.delay(2.4, function() comet:Destroy() end)

		-- big shower of fireworks where the comet ended
		local n = (TIER == "mobile") and 10 or 22
		for i = 1, n do
			task.delay(rand(0, 1.9), function()
				local pick = FireworksModule.Types[math.random(1, 12)]
				if pick.kind ~= "burst" then pick = FireworksModule.Types[1] end
				local pos = finishP + Vector3.new(rand(-240, 240), rand(-30, 90), rand(-200, 200))
				local sizeMul = (math.random() < 0.3) and rand(2.6, 3.6) or rand(1.4, 2.2)
				explode(pick, pos, sizeMul)
			end)
		end
	end)
end

-- ── Steamboat Springs: the colossal finale ────────────────────────────────
local function launchMega(def, origin, tracker)
	if activeBig >= MAX_BIG then return bigConsolation(def, origin, tracker) end
	activeBig += 1
	task.delay(10, function() activeBig -= 1 end)
	-- huge bright ascent (apex passes through APEX_SCALE inside riseShell)
	local megaShell = { swatch = def.colors[1], ascent = { trail = 4, speed = 1.5 }, apex = 240 }
	-- darken the sky for the colossal dome, then restore
	darkenSky((def.viewTime or 9) + 2)
	-- soft violet sky glow builds during ascent (no white)
	screenFlash(0.78, 1.4, 2.6, Color3.fromRGB(150, 110, 235))

	riseShell(megaShell, origin, function(apex)
		if tracker then tracker.exploded = true; tracker.explodePos = apex end
		-- titanic central detonation
		explode({ colors = def.colors, speed = 74, spread = 178, lifetime = 3.0, size = 2.8,
			accelY = -45, drag = 3, count = 260, squash = 3 }, apex, 3.4)

		-- colossal dome of many sub-fireworks (Steamboat = 380 comets, scaled down)
		local domeShells = (TIER == "mobile") and 14 or 30
		local pool = { 2, 3, 5, 8, 10 }  -- chrysanthemum, willow, brocade, kamuro, horsetail
		for i = 1, domeShells do
			task.delay(rand(0, 2.6), function()
				local ang  = rand(0, math.pi * 2)
				local rad  = rand(60, 320)
				local pos  = origin + Vector3.new(math.cos(ang) * rad, rand(110, 190), math.sin(ang) * rad)
				local def2 = FireworksModule.Types[pool[math.random(1, #pool)]]
				explode(def2, pos, rand(2.0, 3.4))
			end)
		end
		-- violet afterglow
		task.delay(1.2, function() screenFlash(0.7, 0.4, 2.2, Color3.fromRGB(150, 100, 235)) end)
	end)
end

-- EXPLOSION: colossal sustained blast (15s+)
local function launchExplosion(def, origin, tracker)
	local TOTAL = 16  -- whole show lasts ~16s
	if activeBig >= MAX_BIG then return bigConsolation(def, origin, tracker) end
	activeBig += 1
	task.delay(TOTAL + 1, function() activeBig -= 1 end)
	darkenSky(TOTAL + 1.5)

	local apexH = 150 * APEX_SCALE
	local center = origin + Vector3.new(0, apexH, 0)

	-- ── Phase 1: charge-up orb that sucks energy inward (~2.2s) ──────────
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2, 2, 2)
	orb.Material = Enum.Material.Neon
	orb.Color = def.colors[1]
	orb.Anchored = true
	orb.CanCollide = false; orb.CanQuery = false; orb.CanTouch = false; orb.CastShadow = false
	orb.Position = origin
	orb.Parent = effectsFolder
	if tracker then tracker.part = orb end

	local orbLight = Instance.new("PointLight", orb)
	orbLight.Range = 60; orbLight.Brightness = 8; orbLight.Color = def.colors[1]

	local intake = Instance.new("ParticleEmitter", orb)
	intake.Texture = SPARK_TEX; intake.Color = colorSeq(def.colors)
	intake.LightEmission = 1; intake.LightInfluence = 0
	intake.Rate = math.floor(120 * QUALITY)
	intake.Speed = NumberRange.new(-40, -20)   -- negative = pulled inward
	intake.Lifetime = NumberRange.new(0.6, 1.0)
	intake.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 3) })
	intake.SpreadAngle = Vector2.new(180, 180)
	intake.Acceleration = Vector3.new(0, 10, 0)

	-- rise + swell while charging
	TweenService:Create(orb, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = center, Size = Vector3.new(14, 14, 14),
	}):Play()
	TweenService:Create(orbLight, TweenInfo.new(2.2), { Brightness = 18 }):Play()

	task.delay(2.2, function()
		if tracker then tracker.exploded = true; tracker.explodePos = center end
		intake.Enabled = false
		orb:Destroy()

		-- ── Phase 2: the titanic detonation ─────────────────────────
		screenFlash(0.45, 0.08, 1.1, Color3.fromRGB(150, 110, 235))
		-- gigantic core blast (much bigger / wider than mega)
		explode({ colors = def.colors, speed = 105, spread = 178, lifetime = 3.4, size = 2.4,
			accelY = -40, drag = 2.5, count = 340, squash = 3 }, center, 3.6)
		-- a couple of massive expanding shock rings
		for r = 1, 3 do
			task.delay((r - 1) * 0.18, function()
				ringEffect({ ringColor = def.colors[(r % #def.colors) + 1], ringTilt = rand(0, 60), size = 4 + r }, center)
			end)
		end

		-- ── Phase 3: sustained cascade across a huge area (~13s) ─────
		local pool = { 1, 2, 3, 5, 8, 10, 16 }
		local waveGap = (TIER == "mobile") and 0.7 or 0.42
		local perWave = (TIER == "mobile") and 2 or 4
		task.spawn(function()
			local elapsed = 0
			while elapsed < TOTAL - 3 do
				for _ = 1, perWave do
					local ang = rand(0, math.pi * 2)
					local rad = rand(40, 360)
					local pos = origin + Vector3.new(
						math.cos(ang) * rad,
						apexH + rand(-40, 90),
						math.sin(ang) * rad
					)
					local d2 = FireworksModule.Types[pool[math.random(1, #pool)]]
					explode(d2, pos, rand(1.6, 3.2))
				end
				task.wait(waveGap)
				elapsed += waveGap
			end
		end)
	end)
end

-- ── Public dispatcher ─────────────────────────────────────────────────────
-- tracker (optional): table the launcher's client reads so the camera can
-- follow the projectile and pull back on explosion.
function Renderer.Play(index, origin, tracker)
	local def = FireworksModule.Types[index]
	if not def then return end
	local k = def.kind
	if k == "comet" then
		launchComet(def, origin, tracker)
	elseif k == "mega" then
		launchMega(def, origin, tracker)
	elseif k == "explosion" then
		launchExplosion(def, origin, tracker)
	elseif k == "mine" then
		launchMine(def, origin, tracker)
	elseif k == "salute" then
		launchSalute(def, origin, tracker)
	else
		launchBurst(def, origin, tracker)  -- burst / crossette / ring
	end
end

return Renderer
