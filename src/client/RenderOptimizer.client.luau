-- Client-side culling: hides decorative objects that are far away or behind the
-- camera, and restores them when back in view. Lowers GPU load, no server cost.
-- Only purely decorative objects are touched (anything with a Humanoid, a script,
-- or an interactive object is skipped). Use a "NoCull" attribute/tag to exclude.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local GuiService        = game:GetService("GuiService")
local UserInputService  = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local ENABLED = true
if not ENABLED then return end

-- ── Device-based budgets ──────────────────────────────────────────────────
local function deviceTier()
	if GuiService:IsTenFootInterface() then return "console" end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return "mobile" end
	return "pc"
end

-- cull     : hide once farther than this (studs), regardless of facing
-- frustum  : beyond this distance, also hide things behind / outside the view
-- showMul  : restore at cull*showMul (hysteresis stops flicker at the edge)
-- slice    : candidates evaluated per tick (spreads cost across frames)
local CFG = ({
	pc      = { cull = 420, frustum = 150, showMul = 0.9, slice = 60 },
	console = { cull = 340, frustum = 130, showMul = 0.9, slice = 45 },
	mobile  = { cull = 230, frustum = 95,  showMul = 0.88, slice = 30 },
})[deviceTier()]

local FRUSTUM_COS = math.cos(math.rad(62))  -- generous half-cone so edges never pop
local TICK = 0.12                            -- seconds between evaluation batches

-- Never cull these top-level names
local EXCLUDE_NAMES = {
	Terrain = true, Camera = true, Water = true,
	Baseplate = true, SpawnLocation = true,
	FireworkEffects = true, FireworksButton = true,
}

-- ── State ─────────────────────────────────────────────────────────────────
local Workspace = workspace
local camera = Workspace.CurrentCamera

local records = {}   -- array of { inst, parent, center, radius, hidden }
local managed = {}   -- inst -> record  (so our own reparenting is ignored)

-- ── Qualification ─────────────────────────────────────────────────────────
local function isCharacter(inst)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character == inst then return true end
	end
	return false
end

local function hasBlocker(inst)
	if inst:FindFirstChildWhichIsA("Humanoid", true) then return true end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("LuaSourceContainer")  -- Script / LocalScript / ModuleScript
			or d:IsA("ProximityPrompt")
			or d:IsA("ClickDetector")
			or d:IsA("Seat")
			or d:IsA("VehicleSeat") then
			return true
		end
	end
	return false
end

local function getBounds(inst)
	if inst:IsA("BasePart") then
		return inst.Position, inst.Size.Magnitude / 2
	elseif inst:IsA("Model") then
		local ok, cf, size = pcall(function()
			local c, s = inst:GetBoundingBox()
			return c, s
		end)
		if ok and cf then
			return cf.Position, size.Magnitude / 2
		end
	end
	return nil
end

-- True if inst (or any ancestor up to workspace) has an excluded name.
-- This protects whole subtrees like the Water folder + the swim mesh inside it,
-- and the FireworkEffects pool, even when we descend into folders.
-- Gameplay content is never decor. Each arcade game builds its world far from
-- the hub (TapAndHold at 50000 studs) and moves pieces of it around while you
-- play, which is exactly what this culler is bad at. Keep it out entirely.
local EXCLUDE_PATTERNS = {
	"^Local_",   -- Local_TapAndHold_Game, Local_TurrisCasei_Game, ...
	"^Level%d",  -- ImNotASphere levels cloned into workspace
}

local function isExcludedName(name)
	if EXCLUDE_NAMES[name] then return true end
	for _, pat in ipairs(EXCLUDE_PATTERNS) do
		if string.match(name, pat) then return true end
	end
	return false
end

local function hasExcludedAncestor(inst)
	local cur = inst
	while cur and cur ~= Workspace do
		if isExcludedName(cur.Name) then return true end
		cur = cur.Parent
	end
	return false
end

local function qualifies(inst)
	if managed[inst] then return false end
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then return false end
	if hasExcludedAncestor(inst) then return false end
	if inst:GetAttribute("NoCull") then return false end
	if CollectionService:HasTag(inst, "NoCull") then return false end
	if isCharacter(inst) then return false end
	if hasBlocker(inst) then return false end
	return true
end

local function register(inst)
	if not qualifies(inst) then return end
	local center, radius = getBounds(inst)
	if not center then return end
	local rec = {
		inst   = inst,
		parent = inst.Parent,
		center = center,
		radius = radius,
		hidden = false,
	}
	records[#records + 1] = rec
	managed[inst] = rec
end

-- Register a top-level child, and (one level) the contents of plain Folders.
-- Excluded-name subtrees (Water, FireworkEffects, …) are skipped entirely.
local function consider(child)
	if isExcludedName(child.Name) then return end
	if child:IsA("Folder") then
		for _, sub in ipairs(child:GetChildren()) do
			register(sub)
		end
	else
		register(child)
	end
end

for _, child in ipairs(Workspace:GetChildren()) do
	consider(child)
end

-- ── Manual opt-in via "Cull" tag ──────────────────────────────────────────
-- Automatic culling skips anything nested in a scripted Model (for safety).
-- If your decor lives inside such a model, tag the specific Model/Part with
-- "Cull" (CollectionService) to force it into the system anyway.
local function forceRegister(inst)
	if managed[inst] then return end
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
	if isCharacter(inst) then return end
	local center, radius = getBounds(inst)
	if not center then return end
	local rec = { inst = inst, parent = inst.Parent, center = center, radius = radius, hidden = false }
	records[#records + 1] = rec
	managed[inst] = rec
end

for _, inst in ipairs(CollectionService:GetTagged("Cull")) do
	forceRegister(inst)
end
CollectionService:GetInstanceAddedSignal("Cull"):Connect(forceRegister)

-- ── Keep registry in sync with the world ──────────────────────────────────
Workspace.ChildAdded:Connect(function(child)
	if managed[child] then return end  -- our own restore
	task.defer(consider, child)        -- defer so the model finishes loading
end)

local function dropRecord(inst)
	local rec = managed[inst]
	if not rec then return end
	managed[inst] = nil
	for i, r in ipairs(records) do
		if r == rec then
			records[i] = records[#records]
			records[#records] = nil
			break
		end
	end
end

Workspace.ChildRemoved:Connect(function(child)
	local rec = managed[child]
	if rec and rec.hidden then return end  -- we hid it on purpose
	dropRecord(child)
end)

-- ── Cull / restore ────────────────────────────────────────────────────────
-- Reparenting a destroyed instance throws (locked Parent); pcall + drop guards
-- against decor that the game removed while we were tracking it.
local function hide(rec)
	rec.hidden = true
	local ok = pcall(function() rec.inst.Parent = nil end)  -- Lua ref keeps it alive
	if not ok then dropRecord(rec.inst) end
end

local function show(rec)
	rec.hidden = false
	local target = (rec.parent and rec.parent.Parent) and rec.parent or Workspace
	local ok = pcall(function() rec.inst.Parent = target end)
	if not ok then dropRecord(rec.inst) end
end

-- Live position. The center captured at register() is only correct for scenery that never moves;
-- parts that DO move (TapAndHold slides its water floor under the player to fake an infinite
-- sea, ImNotASphere pivots levels into place) were being measured against where they used
-- to be, so they got hidden while the player was standing right on them.
-- BasePart.Position and PrimaryPart.Position are plain property reads, so this is cheap;
-- models without a PrimaryPart keep the cached value (GetBoundingBox is not).
local function liveCenter(rec)
	local inst = rec.inst
	if inst:IsA("BasePart") then
		return inst.Position
	end
	local pp = inst.PrimaryPart
	if pp then
		return pp.Position
	end
	return rec.center
end

-- ── Evaluation loop (round-robin slices) ──────────────────────────────────
local cursor = 1
local accum = 0

RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < TICK then return end
	accum = 0

	camera = Workspace.CurrentCamera
	if not camera then return end
	local camCF  = camera.CFrame
	local camPos = camCF.Position
	local look   = camCF.LookVector

	local n = #records
	if n == 0 then return end

	local count = math.min(CFG.slice, n)
	for _ = 1, count do
		if cursor > n then cursor = 1 end
		local rec = records[cursor]
		cursor += 1
		if rec then
			local inst = rec.inst
			-- A visible record with no Parent means the game destroyed it
			-- (folder children don't reach our Workspace.ChildRemoved); drop it.
			if not inst or (not rec.hidden and not inst.Parent) then
				dropRecord(inst)
				n = #records
			else
				local toC  = liveCenter(rec) - camPos
				local dist = toC.Magnitude
				local wantHidden

				if rec.hidden then
					-- show again only well inside the cull radius AND in view
					local inView = dist <= CFG.frustum
						or look:Dot(toC.Unit) >= FRUSTUM_COS
					-- rec.radius belongs on BOTH sides. Hiding measured from the model's edge
					-- but restoring measured from its CENTRE, so anything big enough (a whole
					-- ImNotASphere level) could never come back once hidden: the camera would
					-- have to stand near its centre, which is inside the geometry.
					wantHidden = (dist > CFG.cull * CFG.showMul + rec.radius)
						or (not inView and dist > CFG.frustum + rec.radius)
				else
					if dist > CFG.cull + rec.radius then
						wantHidden = true
					elseif dist > CFG.frustum then
						wantHidden = look:Dot(toC.Unit) < FRUSTUM_COS
					else
						wantHidden = false
					end
				end

				if wantHidden and not rec.hidden then
					hide(rec)
				elseif not wantHidden and rec.hidden then
					show(rec)
				end
			end
		end
	end
end)
