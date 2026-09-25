local Foxy = {}
Foxy.__index = Foxy

Foxy.CELL  = 30
Foxy.COLS  = 16
Foxy.ROWS  = 12
Foxy.HUD_H = 30

-- tile maps for each level (1=wall, 2=pellet, 3=power, 4=ghost-home, 0=empty)
local MAP_LEVEL_1 = {
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
	{1,3,2,2,2,2,2,1,1,2,2,2,2,2,3,1},
	{1,2,1,1,1,1,2,1,1,2,1,1,1,1,2,1},
	{1,2,1,2,2,2,2,2,2,2,2,2,2,1,2,1},
	{1,2,1,2,1,1,1,1,1,1,1,1,2,1,2,1},
	{1,2,2,2,1,4,4,4,4,4,4,1,2,2,2,1},
	{1,2,2,2,1,4,1,1,1,1,4,1,2,2,2,1},
	{1,2,1,2,1,1,1,2,2,1,1,1,2,1,2,1},
	{1,2,1,2,2,2,2,2,2,2,2,2,2,1,2,1},
	{1,0,1,1,1,1,2,1,1,2,1,1,1,1,2,1},
	{1,3,2,2,2,2,2,2,2,2,2,2,2,2,3,1},
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}
local MAP_LEVEL_2 = {
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
	{1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1},
	{1,2,1,1,2,1,1,2,2,1,1,2,1,1,2,1},
	{1,3,1,2,2,2,2,2,2,2,2,2,2,1,3,1},
	{1,2,1,2,1,2,2,1,1,2,2,1,2,1,2,1},
	{1,2,2,2,1,4,4,4,4,4,4,1,2,2,2,1},
	{1,2,2,2,1,4,1,1,1,1,4,1,2,2,2,1},
	{1,2,1,2,1,2,2,1,1,2,2,1,2,1,2,1},
	{1,2,1,2,2,2,2,2,2,2,2,2,2,1,2,1},
	{1,0,1,1,2,1,1,2,2,1,1,2,1,1,2,1},
	{1,3,2,2,2,2,2,2,2,2,2,2,2,2,3,1},
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}
local MAP_LEVEL_3 = {
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
	{1,3,2,2,2,2,2,2,2,2,2,2,2,2,3,1},
	{1,2,1,1,2,1,1,1,1,1,1,2,1,1,2,1},
	{1,2,1,1,2,1,1,1,1,1,1,2,1,1,2,1},
	{1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1},
	{1,2,1,1,2,1,1,4,4,1,1,2,1,1,2,1},
	{1,2,1,1,2,1,4,4,4,4,1,2,1,1,2,1},
	{1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1},
	{1,2,1,1,2,1,1,1,1,1,1,2,1,1,2,1},
	{1,0,1,1,2,1,1,1,1,1,1,2,1,1,2,1},
	{1,3,2,2,2,2,2,2,2,2,2,2,2,2,3,1},
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}
local MAPS = { [1]=MAP_LEVEL_1, [2]=MAP_LEVEL_2, [3]=MAP_LEVEL_3 }

local ENEMY_HOME        = { r = 6, c = 8 }
local ENEMY_SPAWN_DELAY = 1.0

-- deep-copies a level map so mutations don't affect the original
local function copyMap(levelNum)
	local MAP = MAPS[levelNum] or MAPS[1]
	local out = {}
	for r=1,Foxy.ROWS do
		out[r] = {}
		for c=1,Foxy.COLS do
			out[r][c] = MAP[r][c]
		end
	end
	return out
end

local function clamp(v,a,b) if v<a then return a elseif v>b then return v end return v end
local function distance(r1, c1, r2, c2) return math.sqrt((r2-r1)^2 + (c2-c1)^2) end

local DIRS = {
	Left = {dr=0, dc=-1},
	Right={dr=0, dc=1},
	Up   ={dr=-1, dc=0},
	Down ={dr=1, dc=0},
}
local DIR_ORDER = {"Up","Left","Down","Right"}

-- BFS pathfinding; returns the first step direction toward a target cell
local function bfsNextDir(self, sr, sc, tr, tc)
	if sr == tr and sc == tc then return nil end
	local q, qi = {}, 1
	local visited, prev = {}, {}
	for r=1,Foxy.ROWS do visited[r]={} prev[r]={} end
	table.insert(q, {r=sr, c=sc})
	visited[sr][sc] = true
	while qi <= #q do
		local cur = q[qi]; qi += 1
		if cur.r == tr and cur.c == tc then break end
		for _,dname in ipairs(DIR_ORDER) do
			local d = DIRS[dname]
			local nr, nc = cur.r + d.dr, cur.c + d.dc
			if nr>=1 and nr<=Foxy.ROWS and nc>=1 and nc<=Foxy.COLS then
				if not visited[nr][nc] then
					local cell = self:cell(nr,nc)
					if cell ~= 1 and cell ~= 4 then
						visited[nr][nc] = true
						prev[nr][nc] = {r=cur.r, c=cur.c}
						table.insert(q, {r=nr, c=nc})
					end
				end
			end
		end
	end
	if not visited[tr][tc] then
		local best, bestD
		for name,dd in pairs(DIRS) do
			local nr, nc = sr+dd.dr, sc+dd.dc
			if self:canMove(nr,nc) then
				local d = distance(nr,nc,tr,tc)
				if not bestD or d<bestD then bestD=d; best=name end
			end
		end
		return best
	end
	local rr, cc = tr, tc
	local pr = prev[rr][cc]
	while pr and not (pr.r == sr and pr.c == sc) do
		rr, cc = pr.r, pr.c
		pr = prev[rr][cc]
	end
	local dr, dc = rr - sr, cc - sc
	for name,dd in pairs(DIRS) do
		if dd.dr == dr and dd.dc == dc then return name end
	end
	return nil
end

-- creates a new pac-man style game on level 1 with all enemies spawning
function Foxy.new()
	local self = setmetatable({}, Foxy)
	self.currentLevel = 1
	self.maxLevel     = 3
	self.grid = copyMap(self.currentLevel)
	self.score = 0
	self.lives = 3
	self.alive = true
	self.win = false
	self.player = { r = 10, c = 2, dir = "Stop", nextDir = "Stop" }
	self.pelletsLeft = 0
	self.totalPellets = 0
	self.moveSpeed = 0.15
	self.powerMode = false
	self.powerTimer = 0.0
	self.powerDuration = 4.0
	self.enemiesEaten = 0
	self.gameState = "playing"
	self.deathTimer = 0.0
	self.deathDuration = 3.0
	self.countdownTimer = 0.0
	self.countdownValue = 3
	self.readyTimer = 0.0
	self.readyDuration = 1.0
	self.levelCompleteTimer = 0.0
	self.levelCompleteDuration = 2.0
	self.initialPos = { r = 10, c = 2 }
	self.started = false
	self.deathPosR, self.deathPosC = nil, nil

	self.extraPowerSpawned = false
	self.powersEaten = 0

	self.enemies = {
		{name="enemy1",     color="red",    r=7, c=7,  dir="Left",  state="spawning", spawnTimer=0.0, exitDelay=0.05, baseStep=0.18},
		{name="enemy2",     color="pink",   r=7, c=8,  dir="Right", state="spawning", spawnTimer=0.0, exitDelay=0.25, baseStep=0.20},
		{name="extraenemy", color="blue",   r=7, c=9,  dir="Up",    state="spawning", spawnTimer=0.0, exitDelay=0.45, baseStep=0.21},
		{name="enemy3",     color="orange", r=7, c=10, dir="Down",  state="spawning", spawnTimer=0.0, exitDelay=0.65, baseStep=0.22},
	}
	for _,e in ipairs(self.enemies) do
		e.stepTime = e.baseStep
		e._moveTimer = 0
	end
	self:countPellets()
	return self
end

-- counts all pellets and power pellets remaining on the current grid
function Foxy:countPellets()
	self.pelletsLeft = 0
	self.totalPellets = 0
	for r=1,Foxy.ROWS do
		for c=1,Foxy.COLS do
			if self.grid[r][c] == 2 or self.grid[r][c] == 3 then
				self.pelletsLeft += 1
				self.totalPellets += 1
			end
		end
	end
end

-- advances to the next level, resetting enemies and power state
function Foxy:nextLevel()
	if self.currentLevel < self.maxLevel then
		self.lives += 1
		self.currentLevel += 1
		self.grid = copyMap(self.currentLevel)
		self:countPellets()
		self.gameState = "ready"
		self.readyTimer = 0.0
		self.win = false
		self:resetPositions()
		self.powerMode = false
		self.powerTimer = 0.0
		self.enemiesEaten = 0
		self.extraPowerSpawned = false
		self.powersEaten = 0
	else
		self.win = true
		self.gameState = "playing"
	end
end

-- returns the tile value at a grid cell, treating out-of-bounds as walls
function Foxy:cell(r,c)
	if r<1 or r>Foxy.ROWS or c<1 or c>Foxy.COLS then return 1 end
	return self.grid[r][c]
end

-- returns true if the player or enemy can enter a cell
function Foxy:canMove(r,c)
	local v = self:cell(r,c)
	return v ~= 1 and v ~= 4
end

-- queues a direction change for the player; starts the game on first move
function Foxy:setMove(dir)
	self.player.nextDir = dir
	if dir ~= "Stop" and self.gameState == "playing" then
		self.started = true
	end
end

function Foxy:stopMove() self.player.nextDir = "Stop"; self.player.dir = "Stop" end
function Foxy:setSpeed(speed) self.moveSpeed = speed end

-- triggers the death animation and freezes all movement
function Foxy:startDeathSequence()
	if self.gameState ~= "playing" then return end
	self.gameState = "dying"
	self.deathTimer = 0.0
	self.player.dir = "Stop"
	self.player.nextDir = "Stop"
	self.deathPosR, self.deathPosC = self.player.r, self.player.c
	self.powerMode = false
	self.powerTimer = 0
	self.enemiesEaten = 0
end

-- resets the player and all enemies to their starting positions
function Foxy:resetPositions()
	self.player.r = self.initialPos.r
	self.player.c = self.initialPos.c
	self.player.dir = "Stop"
	self.player.nextDir = "Stop"
	local init = {
		{r=6,c=6,  dir="Left",  exit=0.05},
		{r=6,c=7,  dir="Right", exit=0.25},
		{r=6,c=9,  dir="Up",    exit=0.45},
		{r=6,c=10, dir="Down",  exit=0.65},
	}
	for i,e in ipairs(self.enemies) do
		local t = init[i]
		e.r, e.c = t.r, t.c
		e.dir = t.dir
		e.state = "spawning"
		e.spawnTimer = 0.0
		e.exitDelay = t.exit
		e._moveTimer = 0
		e.stepTime = e.baseStep
	end
	self.started = false
	self.powerMode = false
	self.powerTimer = 0
	self.enemiesEaten = 0
end

-- returns the target cell for an enemy based on its AI personality
function Foxy:getEnemyTarget(enemy)
	if enemy.state == "frightened" then
		return math.random(1, Foxy.ROWS), math.random(1, Foxy.COLS)
	elseif enemy.state == "spawning" then
		return ENEMY_HOME.r, ENEMY_HOME.c
	end

	if enemy.name == "enemy1" then
		return self.player.r, self.player.c
	elseif enemy.name == "enemy2" then
		local d = DIRS[self.player.dir] or {dr=0, dc=0}
		local offR, offC
		if self.player.dir == "Up" then offR, offC = -4, -4 else offR, offC = d.dr*4, d.dc*4 end
		return clamp(self.player.r + offR, 1, Foxy.ROWS), clamp(self.player.c + offC, 1, Foxy.COLS)
	elseif enemy.name == "extraenemy" then
		local d = DIRS[self.player.dir] or {dr=0, dc=0}
		local fr = clamp(self.player.r + d.dr*2, 1, Foxy.ROWS)
		local fc = clamp(self.player.c + d.dc*2, 1, Foxy.COLS)
		local leader = self.enemies[1]
		local vr = fr - leader.r
		local vc = fc - leader.c
		return clamp(leader.r + vr*2, 1, Foxy.ROWS), clamp(leader.c + vc*2, 1, Foxy.COLS)
	elseif enemy.name == "enemy3" then
		local dist = distance(enemy.r, enemy.c, self.player.r, self.player.c)
		if dist > 8 then
			return self.player.r, self.player.c
		else
			return Foxy.ROWS, 1
		end
	end
	return enemy.r, enemy.c
end

-- moves an enemy one step using BFS toward its target or fleeing when frightened
function Foxy:moveEnemy(enemy, dt)
	if enemy.state == "spawning" then return end
	if enemy.state == "frightened" then
		local best, bestD
		for name,d in pairs(DIRS) do
			local nr, nc = enemy.r + d.dr, enemy.c + d.dc
			if self:canMove(nr,nc) then
				local dPlayer = distance(nr,nc,self.player.r,self.player.c)
				if not bestD or dPlayer > bestD then bestD = dPlayer; best = name end
			end
		end
		if best then enemy.dir = best end
	else
		local tr, tc = self:getEnemyTarget(enemy)
		local ndir = bfsNextDir(self, enemy.r, enemy.c, tr, tc)
		if ndir then enemy.dir = ndir end
	end
	local d = DIRS[enemy.dir]
	if d then
		local nr, nc = enemy.r + d.dr, enemy.c + d.dc
		if self:canMove(nr, nc) then
			enemy.r, enemy.c = nr, nc
		end
	end
end

-- checks if any enemy has caught the player; eating a frightened enemy scores points
function Foxy:checkEnemyCollisions()
	for _, enemy in ipairs(self.enemies) do
		if enemy.state ~= "spawning" and enemy.r == self.player.r and enemy.c == self.player.c then
			if enemy.state == "frightened" then
				self.enemiesEaten += 1
				local points = 200 * (2^(self.enemiesEaten-1))
				self.score += points
				enemy.r, enemy.c = ENEMY_HOME.r, ENEMY_HOME.c
				enemy.state = "spawning"
				enemy.spawnTimer = 0.0
				enemy.exitDelay = ENEMY_SPAWN_DELAY
			elseif enemy.state == "normal" then
				self:startDeathSequence()
				return
			end
		end
	end
end

-- main update tick: handles death/ready/countdown states, player movement, pellet collection, and enemy AI
function Foxy:update(dt)
	if self.gameState == "level_complete" then
		self.levelCompleteTimer += dt
		if self.levelCompleteTimer >= self.levelCompleteDuration then
			self:nextLevel()
		end
		return
	end
	if self.gameState == "dying" then
		self.deathTimer += dt
		if self.deathTimer >= self.deathDuration then
			self.lives -= 1
			if self.lives <= 0 then
				self.alive = false
				return
			else
				self.gameState = "ready"
				self.readyTimer = 0.0
				self.deathPosR, self.deathPosC = nil, nil
				self:resetPositions()
			end
		end
		return
	elseif self.gameState == "ready" then
		self.readyTimer += dt
		if self.readyTimer >= self.readyDuration then
			self.gameState = "countdown"
			self.countdownTimer = 0.0
			self.countdownValue = 3
		end
		return
	elseif self.gameState == "countdown" then
		self.countdownTimer += dt
		if self.countdownTimer >= 1.0 then
			self.countdownTimer = 0.0
			self.countdownValue -= 1
			if self.countdownValue <= 0 then
				self.gameState = "playing"
				self.alive = true
			end
		end
		return
	end

	if not self.alive or self.win then return end

	if self.powerMode then
		self.powerTimer += dt
		if self.powerTimer >= self.powerDuration then
			self.powerMode = false
			self.powerTimer = 0.0
			self.enemiesEaten = 0
			for _,e in ipairs(self.enemies) do
				if e.state == "frightened" then e.state = "normal" end
			end

			-- if all power pellets are gone, respawn one at a random original spot
			if not self.extraPowerSpawned and self.pelletsLeft > 0 then
				local powerUpsLeft = 0
				for r=1, Foxy.ROWS do
					for c=1, Foxy.COLS do
						if self.grid[r][c] == 3 then powerUpsLeft += 1 end
					end
				end

				if powerUpsLeft == 0 then
					local originalMap = MAPS[self.currentLevel]
					local availableSpots = {}

					for r=1, Foxy.ROWS do
						for c=1, Foxy.COLS do
							if originalMap[r][c] == 3 and self.grid[r][c] == 0 then
								table.insert(availableSpots, {r=r, c=c})
							end
						end
					end

					if #availableSpots > 0 then
						local spot = availableSpots[math.random(1, #availableSpots)]
						self.grid[spot.r][spot.c] = 3
						-- the extra power does not count toward the pellet goal
						self.extraPowerSpawned = true
					end
				end
			end
		end
	end

	if self.player.nextDir ~= "Stop" then
		local d = DIRS[self.player.nextDir]
		if d then
			local nr, nc = self.player.r + d.dr, self.player.c + d.dc
			if self:canMove(nr,nc) then self.player.dir = self.player.nextDir end
		end
	else
		self.player.dir = "Stop"
	end

	local spdTimer = (self._moveTimer or 0) + dt
	local stepTime = self.moveSpeed

	if spdTimer >= stepTime then
		self._moveTimer = 0
		if self.player.dir ~= "Stop" then
			local d = DIRS[self.player.dir]
			if d then
				local nr, nc = self.player.r + d.dr, self.player.c + d.dc
				if self:canMove(nr,nc) then
					local oldR, oldC = self.player.r, self.player.c
					self.player.r, self.player.c = nr, nc
					if not self.started and (self.player.r ~= oldR or self.player.c ~= oldC) then
						self.started = true
					end
					local v = self.grid[nr][nc]
					if v == 2 then
						self.grid[nr][nc] = 0
						self.score += 10
						self.pelletsLeft -= 1
					elseif v == 3 then
						self.grid[nr][nc] = 0
						self.score += 50

						-- only the first 4 power pellets count toward the win condition
						self.powersEaten = (self.powersEaten or 0) + 1
						if self.powersEaten <= 4 then
							self.pelletsLeft -= 1
						end

						self.powerMode = true
						self.powerTimer = 0.0
						self.enemiesEaten = 0
						for _,e in ipairs(self.enemies) do
							if e.state == "normal" then e.state = "frightened" end
						end
					end
					if self.pelletsLeft <= 0 then
						if self.currentLevel >= self.maxLevel then
							self.win = true
						else
							self.gameState = "level_complete"
							self.levelCompleteTimer = 0.0
							self.player.dir = "Stop"
							self.player.nextDir = "Stop"
						end
					end
				else
					self.player.dir = "Stop"
				end
			end
		end
		self:checkEnemyCollisions()
	else
		self._moveTimer = spdTimer
	end

	if self.gameState == "playing" and self.started then
		for _,e in ipairs(self.enemies) do
			if e.state == "spawning" then
				e.spawnTimer += dt
				if e.spawnTimer >= (e.exitDelay or ENEMY_SPAWN_DELAY) then
					e.state = self.powerMode and "frightened" or "normal"
					e.spawnTimer = 0.0
					e.r, e.c = 8, 8
				end
			end
		end
	end

	if self.gameState == "playing" then
		for _,enemy in ipairs(self.enemies) do
			if enemy.state ~= "spawning" then
				local step = enemy.baseStep
				if enemy.name == "enemy1" then
					local dist = distance(enemy.r,enemy.c,self.player.r,self.player.c)
					if dist > 8 then step = math.min(step, 0.15) end
					local threshold = math.floor(self.totalPellets * 0.25)
					if self.pelletsLeft <= threshold then step = math.min(step, 0.15) end
				end
				enemy.stepTime = step
				enemy._moveTimer = (enemy._moveTimer or 0) + dt
				if enemy._moveTimer >= enemy.stepTime then
					enemy._moveTimer = 0
					self:moveEnemy(enemy, dt)
				end
			end
		end
		self:checkEnemyCollisions()
	end
end

-- returns the full game state snapshot for the client renderer
function Foxy:getState()
	local tiles = {}
	for r=1,Foxy.ROWS do
		for c=1,Foxy.COLS do
			local v = self.grid[r][c]
			if v ~= 0 then tiles[#tiles+1] = { r=r, c=c, v=v } end
		end
	end

	local enemiesData = {}
	for _, e in ipairs(self.enemies) do
		enemiesData[#enemiesData+1] = {
			name=e.name, color=e.color, r=e.r, c=e.c,
			state=e.state, spawnTimer=e.spawnTimer
		}
	end

	return {
		alive = self.alive,
		win = self.win,
		score = self.score,
		lives = self.lives,
		level = self.currentLevel,
		rows = Foxy.ROWS,
		cols = Foxy.COLS,
		cell = Foxy.CELL,
		player = { r = self.player.r, c = self.player.c, dir = self.player.dir },
		tiles = tiles,
		enemies = enemiesData,
		powerMode = self.powerMode,
		powerTimeLeft = self.powerDuration - self.powerTimer,
		gameState = self.gameState,
		deathTimer = self.deathTimer,
		deathDuration = self.deathDuration,
		countdownValue = self.countdownValue,
		readyTimer = self.readyTimer,
		deathPos = (self.deathPosR and { r = self.deathPosR, c = self.deathPosC } or nil),
		currentLevel = self.currentLevel,
		maxLevel = self.maxLevel,
		levelCompleteTimer = self.levelCompleteTimer,
		pelletsLeft = self.pelletsLeft,
		hud = { score=self.score, lives=self.lives, level=self.currentLevel },
		hudText = ("Score: %d   Lives: %d   Lv: %d"):format(self.score, self.lives, self.currentLevel)
	}
end

return Foxy
