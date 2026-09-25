local JuiceCutterModule = {}
JuiceCutterModule.__index = JuiceCutterModule

-- canvas size and fruit radius in pixels
local CANVAS_W, CANVAS_H = 380, 360
local FRUIT_R = 40
local CUT_LINGER = 1.2
local GRAVITY = 950
local MAX_LEVEL = 5
local BONUS_LIVES_PER_LEVEL = 1

-- asset ids for all fruit sprites (whole and cut variants)
local ASSETS = {
	lemon = "rbxassetid://87613441938077", lemonCut = "rbxassetid://116731949603410",
	orangeBad = "rbxassetid://115742568427308", appleBad = "rbxassetid://80534751878619", strawBad = "rbxassetid://108408061489677",

	straw = "rbxassetid://93823731383536", strawCut = "rbxassetid://98537582411234",
	banana = "rbxassetid://127957609828105", bananaCut = "rbxassetid://133899611380899",
	waterBad = "rbxassetid://137490048542264", pearBad = "rbxassetid://132369207739868", lemonBad2 = "rbxassetid://135281270806438",

	pina = "rbxassetid://92573832108058", pina_cut = "rbxassetid://90547698574482",
	coco = "rbxassetid://90859035515149", coco_cut = "rbxassetid://131856918091929",
	cereza = "rbxassetid://89970067176669", cereza_cut = "rbxassetid://106658523467226",
	mango_malo = "rbxassetid://94617794706195", banano_mal = "rbxassetid://82461426778745",
	limon_malo = "rbxassetid://135281270806438", naranja_mal = "rbxassetid://115742568427308",

	cucumber = "rbxassetid://82376125372153", cucumberCut = "rbxassetid://102677938909246",
	greenApple = "rbxassetid://108090324091458", greenAppleCut = "rbxassetid://77409311574725",
	kiwi = "rbxassetid://109446326722635", kiwiCut = "rbxassetid://84567238056092",
	pumpkinBad = "rbxassetid://109830099390621", carrotBad = "rbxassetid://111274229452780", onionBad = "rbxassetid://103509495972861",

	grapes = "rbxassetid://109631792901350", grapesCut = "rbxassetid://85189935140451",
	redApple = "rbxassetid://83268408265851", redAppleCut = "rbxassetid://82302665298042",
	orange = "rbxassetid://128480626544761", orangeCut = "rbxassetid://118837800983429",
	kiwiBad = "rbxassetid://111412231065394"
}

-- per-level config: fruit pools, spawn rates, goals, and scoring
local LEVELS = {
	[1] = {
		levelTitle = "LEMONADE", lives = 5, scorePerGood = 50, goodChance = 0.65,
		speedMin = 520, speedMax = 780, spawnIntervalMin = 0.55, spawnIntervalMax = 0.95,
		goodWeights = {{kind="lemon", asset=ASSETS.lemon, cutAsset=ASSETS.lemonCut, w=1.0}},
		badWeights = {
			{kind="orangeBad", asset=ASSETS.orangeBad, w=0.34},
			{kind="appleBad", asset=ASSETS.appleBad, w=0.33},
			{kind="strawBad", asset=ASSETS.strawBad, w=0.33}
		},
		goalMode = "total", goalTotal = 20,
	},
	[2] = {
		levelTitle = "STRAWBANANA",
		scorePerGood = 100, goodChance = 0.60,
		speedMin = 550, speedMax = 830, spawnIntervalMin = 0.50, spawnIntervalMax = 0.85,
		goodWeights = {{kind="straw", asset=ASSETS.straw, cutAsset=ASSETS.strawCut, w=0.5}, {kind="banana", asset=ASSETS.banana, cutAsset=ASSETS.bananaCut, w=0.5}},
		badWeights = {
			{kind="waterBad", asset=ASSETS.waterBad, w=0.25},
			{kind="pearBad", asset=ASSETS.pearBad, w=0.25},
			{kind="lemonBad2", asset=ASSETS.lemonBad2, w=0.25},
			{kind="appleBad", asset=ASSETS.appleBad, w=0.25}
		},
		goalMode = "split", goalSplit = {straw=15, banana=15}, goalTotal = 30,
	},
	[3] = {
		levelTitle = "TROPICAL",
		scorePerGood = 150, goodChance = 0.55,
		speedMin = 600, speedMax = 880, spawnIntervalMin = 0.45, spawnIntervalMax = 0.80,
		goodWeights = {
			{kind="pina", asset=ASSETS.pina, cutAsset=ASSETS.pina_cut, w=0.34},
			{kind="coco", asset=ASSETS.coco, cutAsset=ASSETS.coco_cut, w=0.33},
			{kind="cereza", asset=ASSETS.cereza, cutAsset=ASSETS.cereza_cut, w=0.33},
		},
		badWeights = {
			{kind="mango_malo", asset=ASSETS.mango_malo, w=0.20},
			{kind="banano_mal", asset=ASSETS.banano_mal, w=0.20},
			{kind="limon_malo", asset=ASSETS.limon_malo, w=0.20},
			{kind="naranja_mal", asset=ASSETS.naranja_mal, w=0.20},
			{kind="pumpkinBad", asset=ASSETS.pumpkinBad, w=0.20}
		},
		goalMode = "split", goalSplit = {pina=12, coco=12, cereza=12}, goalTotal = 36,
	},
	[4] = {
		levelTitle = "GREEN DETOX",
		scorePerGood = 200, goodChance = 0.48,
		speedMin = 550, speedMax = 850, spawnIntervalMin = 0.42, spawnIntervalMax = 0.75,
		goodWeights = {
			{kind="cucumber", asset=ASSETS.cucumber, cutAsset=ASSETS.cucumberCut, w=0.33},
			{kind="greenApple", asset=ASSETS.greenApple, cutAsset=ASSETS.greenAppleCut, w=0.33},
			{kind="kiwi", asset=ASSETS.kiwi, cutAsset=ASSETS.kiwiCut, w=0.34},
		},
		badWeights = {
			{kind="pumpkinBad", asset=ASSETS.pumpkinBad, w=0.25},
			{kind="carrotBad", asset=ASSETS.carrotBad, w=0.25},
			{kind="onionBad", asset=ASSETS.onionBad, w=0.25},
			{kind="lemonBad2", asset=ASSETS.lemonBad2, w=0.25}
		},
		goalMode = "split", goalSplit = {cucumber=12, greenApple=12, kiwi=12}, goalTotal = 36,
	},
	[5] = {
		levelTitle = "PURE RED JUICE",
		scorePerGood = 250, goodChance = 0.42,
		speedMin = 550, speedMax = 850, spawnIntervalMin = 0.38, spawnIntervalMax = 0.70,
		goodWeights = {
			{kind="grapes", asset=ASSETS.grapes, cutAsset=ASSETS.grapesCut, w=0.33},
			{kind="redApple", asset=ASSETS.redApple, cutAsset=ASSETS.redAppleCut, w=0.33},
			{kind="orange", asset=ASSETS.orange, cutAsset=ASSETS.orangeCut, w=0.34},
		},
		badWeights = {
			{kind="kiwiBad", asset=ASSETS.kiwiBad, w=0.25},
			{kind="carrotBad", asset=ASSETS.carrotBad, w=0.25},
			{kind="onionBad", asset=ASSETS.onionBad, w=0.25},
			{kind="mango_malo", asset=ASSETS.mango_malo, w=0.25}
		},
		goalMode = "split", goalSplit = {grapes=15, redApple=15, orange=15}, goalTotal = 45,
	},
}

local function randRange(a, b) return a + (b - a) * math.random() end
local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end

-- returns the minimum distance from point (px,py) to line segment (x0,y0)-(x1,y1)
local function distPointToSegment(px, py, x0, y0, x1, y1)
	local vx, vy = x1 - x0, y1 - y0;
	local wx, wy = px - x0, py - y0
	local c1 = wx * vx + wy * vy;
	if c1 <= 0 then local dx, dy = px - x0, py - y0;
		return math.sqrt(dx*dx + dy*dy) end
	local c2 = vx*vx + vy*vy;
	if c2 <= c1 then local dx, dy = px - x1, py - y1;
		return math.sqrt(dx*dx + dy*dy) end
	local t = c1 / c2; local bx, by = x0 + t*vx, y0 + t*vy;
	local dx, dy = px - bx, py - by;
	return math.sqrt(dx*dx + dy*dy)
end

-- picks a random item from a weighted pool; returns kind, asset, and cutAsset
local function pickWeighted(pool)
	if #pool == 0 then return nil, nil, nil end
	local total = 0;
	for _, it in ipairs(pool) do total += (it.w or 0) end
	if total <= 0 then return pool[1].kind, pool[1].asset, pool[1].cutAsset end
	local r = math.random() * total;
	local acc = 0; for _, it in ipairs(pool) do acc += (it.w or 0);
		if r <= acc then return it.kind, it.asset, it.cutAsset end end
	return pool[#pool].kind, pool[#pool].asset, pool[#pool].cutAsset
end

-- creates a new game instance starting at the given level, carrying over lives if provided
function JuiceCutterModule.new(levelIndex, lastLives)
	local self = setmetatable({}, JuiceCutterModule)
	self.score = 0;
	self:_initLevel(levelIndex or 1, lastLives)
	return self
end

-- loads level config, sets lives, resets fruit and counter state
function JuiceCutterModule:_initLevel(levelIndex, lastLives)
	self.levelIndex = levelIndex; self.level = LEVELS[self.levelIndex] or LEVELS[1]

	if self.levelIndex == 1 then
		self.lives = 5
	else
		if lastLives and type(lastLives) == "number" then
			self.lives = lastLives + BONUS_LIVES_PER_LEVEL
		else
			self.lives = 5
		end
	end

	self.goal = self.level.goalTotal or 20
	self.cutGood = 0;
	self.goodCounts = {}; self.fruits = {}; self.nextId = 1
	self.spawnTimer = 0; self.nextSpawnAt = randRange(self.level.spawnIntervalMin, self.level.spawnIntervalMax)
	self.gameOver = false; self.perfect = false;
	self.reason = nil; self.nextLevel = nil; self.levelCompleted = false
end

-- spawns a fruit at the bottom of the canvas; biases good fruit pool toward still-needed kinds in split modes
function JuiceCutterModule:_spawnFruit()
	local isGood = (math.random() < (self.level.goodChance or 0.65))
	local kind, asset, cutAsset

	if isGood then
		local pool = self.level.goodWeights
		if self.level.goalMode == "split" then
			local neededFruits = {}
			for _, item in ipairs(pool) do
				local currentCount = self.goodCounts[item.kind] or 0
				local requiredCount = self.level.goalSplit[item.kind] or 0
				if currentCount < requiredCount then
					table.insert(neededFruits, item)
				end
			end
			if #neededFruits > 0 then
				pool = neededFruits
			end
		end
		kind, asset, cutAsset = pickWeighted(pool)
	else
		kind, asset = pickWeighted(self.level.badWeights);
		cutAsset = asset
	end

	if not kind then return end

	local r = FRUIT_R; local x = randRange(r, CANVAS_W - r);
	local y = CANVAS_H + r + randRange(0, 20)
	local speed = randRange(self.level.speedMin, self.level.speedMax); local vy = -speed;
	local vx = randRange(-220, 220)
	table.insert(self.fruits, {id=self.nextId, kind=kind, isGood=isGood, asset=asset, cutAsset=cutAsset, x=x, y=y, vx=vx, vy=vy, r=r, rot=randRange(-20, 20), rotSpeed=randRange(-220, 220), cut=false, removeAt=nil})
	self.nextId += 1
end

-- applies gravity, moves each fruit, bounces off side walls, and removes those that fall off-screen
function JuiceCutterModule:_updateFruits(dt)
	local now = os.clock()
	for i = #self.fruits, 1, -1 do
		local f = self.fruits[i]
		if f.cut and f.removeAt and now >= f.removeAt then table.remove(self.fruits, i);
			continue end
		f.vy += GRAVITY * dt; f.x += f.vx * dt; f.y += f.vy * dt;
		f.rot += f.rotSpeed * dt
		if f.x < f.r then f.x = f.r;
			f.vx = math.abs(f.vx) elseif f.x > (CANVAS_W - f.r) then f.x = CANVAS_W - f.r;
			f.vx = -math.abs(f.vx) end
		if f.y > (CANVAS_H + f.r + 80) and (not f.cut) then table.remove(self.fruits, i) end
	end
end

-- returns true when all win conditions for the current level are satisfied
function JuiceCutterModule:_goalMet()
	if self.level.goalMode == "split" then
		for kind, needed in pairs(self.level.goalSplit or {}) do if (self.goodCounts[kind] or 0) < needed then return false end end
		return true
	else return self.cutGood >= (self.level.goalTotal or self.goal) end
end

-- marks the session as won; awards a life-preservation bonus and sets the next level index
function JuiceCutterModule:_finishAsLevelComplete()
	if self.lives >= 5 then
		self.score = self.score + 100
	end

	self.gameOver = true;
	self.perfect = true; self.reason = "levelComplete"; self.levelCompleted = true
	if self.levelIndex < MAX_LEVEL then self.nextLevel = self.levelIndex + 1 else self.nextLevel = nil end
end

-- marks the session as lost due to running out of lives
function JuiceCutterModule:_finishAsDead() self.gameOver = true;
	self.perfect = false; self.reason = "dead"; self.levelCompleted = false; self.nextLevel = nil end

-- tests the cut segment against all uncut fruits; scores good hits, penalizes bad ones, then checks win/lose
function JuiceCutterModule:_applyCutSegment(x0, y0, x1, y1)
	if self.gameOver then return end
	local pts = self.level.scorePerGood or 50

	for _, f in ipairs(self.fruits) do
		if not f.cut and distPointToSegment(f.x, f.y, x0, y0, x1, y1) <= f.r then
			f.cut = true;
			f.asset = f.cutAsset; f.removeAt = os.clock() + CUT_LINGER
			if f.isGood then
				self.score += pts
				self.cutGood += 1
				self.goodCounts[f.kind] = (self.goodCounts[f.kind] or 0) + 1
			else
				self.lives -= 1
				self.score -= pts
			end
		end
	end
	if self.lives <= 0 then self:_finishAsDead() elseif self:_goalMet() then self:_finishAsLevelComplete() end
end

-- processes a cut input payload by clamping coordinates and forwarding to the cut resolver
function JuiceCutterModule:handleInput(payload)
	if type(payload) ~= "table" or payload.kind ~= "cut" then return end
	local x0, y0, x1, y1 = tonumber(payload.x0), tonumber(payload.y0), tonumber(payload.x1), tonumber(payload.y1)
	if x0 and y0 and x1 and y1 then self:_applyCutSegment(clamp(x0,-60,440), clamp(y0,-60,420), clamp(x1,-60,440), clamp(y1,-60,420)) end
end

-- advances the spawn timer, triggers new fruit spawns, and updates all fruit physics
function JuiceCutterModule:step(dt)
	if self.gameOver then return false end
	self.spawnTimer += dt;
	if self.spawnTimer >= self.nextSpawnAt then self.spawnTimer = 0; self.nextSpawnAt = randRange(self.level.spawnIntervalMin, self.level.spawnIntervalMax); self:_spawnFruit() end
	self:_updateFruits(dt); if self.gameOver then return false end;
	return true
end

-- returns the full game state snapshot including all fruit positions and per-kind cut counts
function JuiceCutterModule:getState()
	local fruitsOut = table.create(#self.fruits)
	for i, f in ipairs(self.fruits) do fruitsOut[i] = {id=f.id,x=f.x,y=f.y,r=f.r,rot=f.rot,asset=f.asset,cut=f.cut} end

	return {
		level=self.levelIndex, levelTitle=self.level.levelTitle, score=self.score, lives=self.lives,
		goal=self.level.goalTotal, cutGood=self.cutGood, fruits=fruitsOut, perfect=self.perfect,
		reason=self.reason, nextLevel=self.nextLevel, levelCompleted=self.levelCompleted,

		c_lemon = self.goodCounts.lemon or 0,
		c_straw = self.goodCounts.straw or 0,
		c_banana = self.goodCounts.banana or 0,
		c_pina = self.goodCounts.pina or 0,
		c_coco = self.goodCounts.coco or 0,
		c_cereza = self.goodCounts.cereza or 0,
		c_cucumber = self.goodCounts.cucumber or 0,
		c_greenApple = self.goodCounts.greenApple or 0,
		c_kiwi = self.goodCounts.kiwi or 0,
		c_grapes = self.goodCounts.grapes or 0,
		c_redApple = self.goodCounts.redApple or 0,
		c_orange = self.goodCounts.orange or 0
	}
end

return JuiceCutterModule
