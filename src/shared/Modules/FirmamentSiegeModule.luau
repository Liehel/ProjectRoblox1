local FS = {}
FS.__index = FS

-- grid dimensions in cells
FS.CELL = 30
FS.COLS = 16
FS.ROWS = 12

local START_LIVES  = 3
local DYING_TIME   = 0.8
local INVULN_TIME  = 1.1

local READY_STEPS    = { "READY", "3", "2", "1" }
local READY_STEP_DUR = 0.20

local SHIP_ACCEL     = 35
local SHIP_MAX_SPEED = 10
local SHIP_DAMP_BASE = 0.82

local SHIP_ROT_SPEED  = math.rad(320)

local BULLET_SPEED    = 23
local BULLET_COOLDOWN = 0.08
local BULLET_LIFETIME = 0.8

local PLAYER_PX   = 40
local ENEMY_PX_A  = 48
local ENEMY_PX_B  = 58
local ENEMY_PX_C  = 65

local HITBOX_SHRINK_SHIP   = 0.8
local HITBOX_SHRINK_ENEMY  = 1.0

local pxMap = { A = ENEMY_PX_A, B = ENEMY_PX_B, C = ENEMY_PX_C }
local SCORE_A, SCORE_B, SCORE_C = 150, 100, 50
local scoreMap = { A = SCORE_A, B = SCORE_B, C = SCORE_C }

local ENEMIES_MIN_ON_SCREEN = 4
local ENEMIES_MAX_ON_SCREEN = 7
local COMPOSITION_CHECK_INTERVAL = 3.2

-- returns the target count per drone type for a given total enemy count
local function targetComposition(total)
	if total <= 4 then return {A = 2, B = 1, C = 1}
	elseif total == 5 then return {A = 2, B = 2, C = 1}
	elseif total == 6 then return {A = 2, B = 2, C = 2}
	else return {A = 2, B = 2, C = 3} end
end

local SPEED_A_MIN, SPEED_A_MAX = 1.4, 2.2
local SPEED_B_MIN, SPEED_B_MAX = 1.6, 2.4
local SPEED_C_MIN, SPEED_C_MAX = 1.8, 2.6

local RESPAWN_SAFE_RADIUS = 5.0
local SPAWN_SAFE_RADIUS   = 7.0

local function rnd(a,b) return a + math.random()*(b-a) end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
-- converts a sprite pixel size to a collision radius in cells
local function radiusCells(px) return (px / FS.CELL) * 0.5 end

-- creates a new game instance with the ship centered and an initial enemy composition
function FS.new()
	local self = setmetatable({}, FS)
	self.cell, self.cols, self.rows = FS.CELL, FS.COLS, FS.ROWS

	self.score, self.lives = 0, START_LIVES
	self.alive, self.win   = true, false

	self.gameState   = "ready"
	self._readyStepI = 1
	self._readyT     = 0
	self._readyText  = READY_STEPS[self._readyStepI]
	self._dyingT, self._invulnT = 0, INVULN_TIME

	self.ship = { r=self.rows*0.5, c=self.cols*0.5 }
	self._x, self._y = self.ship.c, self.ship.r

	self._vx, self._vy = 0, 0
	self._useAxes = true
	self._ax, self._ay = 0, 0

	self._ang, self._rotDir, self._thrustOn = 0, 0, false
	self._aimAng = 0

	self._fireCd, self._shootHeld = 0, false
	self.playerBullets = {}
	self.aliens = {}

	self._compTimer    = 0
	self._desiredTotal = ENEMIES_MIN_ON_SCREEN

	self.shields, self.enemyBullets, self.ufo = {}, {}, nil
	self._explosionEvent = false
	self._timeS = 0
	self._hasBegun = false

	self:_ensureComposition()
	return self
end

-- returns elapsed time in milliseconds
function FS:getTimeMs() return math.floor((self._timeS or 0) * 1000) end

-- sets movement via normalized axis values
function FS:setMoveAxes(ax, ay)
	self._useAxes = true
	self._ax = clamp(tonumber(ax) or 0, -1, 1)
	self._ay = clamp(tonumber(ay) or 0, -1, 1)
end

-- sets movement via a named direction string
function FS:setMoveDir(dir)
	self._useAxes = true
	if     dir=="Up"    then self._ax, self._ay = 0, -1
	elseif dir=="Down"  then self._ax, self._ay = 0,  1
	elseif dir=="Left"  then self._ax, self._ay = -1, 0
	elseif dir=="Right" then self._ax, self._ay =  1, 0
	else  self._ax, self._ay = 0, 0 end
end

-- sets the aim angle in degrees used for bullet direction
function FS:setAimAngle(deg)
	if type(deg)=="number" then self._aimAng = math.rad(deg) end
end

-- spawns a bullet in the current aim direction if the cooldown allows
function FS:fire()
	if self._fireCd > 0 or self.gameState ~= "playing" then return end

	local ang = self._aimAng
	local bx = self._x + math.cos(ang)*0.9
	local by = self._y + math.sin(ang)*0.9
	local bvx = math.cos(ang)*BULLET_SPEED
	local bvy = math.sin(ang)*BULLET_SPEED
	self.playerBullets[#self.playerBullets+1] = {x=bx,y=by,vx=bvx,vy=bvy,t=BULLET_LIFETIME}
	self._fireCd = BULLET_COOLDOWN
end

-- teleports the ship to a random position and briefly extends invulnerability
function FS:hyperspace()
	if self.gameState~="playing" then return end
	self._x, self._y = rnd(2, self.cols-2), rnd(2, self.rows-2)
	self._vx, self._vy = 0, 0
	self._invulnT = math.min(self._invulnT + 0.6, INVULN_TIME)
end

-- returns a random spawn point that is outside the safe radius around the ship
function FS:_randomSpawnPosition()
	local px = self._x or (self.cols * 0.5)
	local py = self._y or (self.rows * 0.5)
	local safeR2 = SPAWN_SAFE_RADIUS * SPAWN_SAFE_RADIUS

	for _ = 1, 64 do
		local x = rnd(0, self.cols)
		local y = rnd(0, self.rows)

		local dx = math.abs(x - px)
		local dy = math.abs(y - py)
		if dx > self.cols/2 then dx = self.cols - dx end
		if dy > self.rows/2 then dy = self.rows - dy end

		if dx*dx + dy*dy >= safeR2 then return x, y end
	end
	return 1, 1
end

-- assigns type, sprite size, and base speed to a drone table
function FS:_setupDroneType(d, typ)
	d.type = typ
	d.px   = pxMap[typ] or ENEMY_PX_A
	if typ == "A" then d.baseS = rnd(SPEED_A_MIN, SPEED_A_MAX)
	elseif typ == "B" then d.baseS = rnd(SPEED_B_MIN, SPEED_B_MAX)
	else d.baseS = rnd(SPEED_C_MIN, SPEED_C_MAX) end
end

-- creates a new drone of the given type at the given position
function FS:_newDrone(typ, x, y)
	local d = { x=x, y=y, vx=0, vy=0, baseS=0, px=pxMap[typ] or ENEMY_PX_A, rot=0 }
	self:_setupDroneType(d, typ)
	return d
end

-- spawns missing drones so the on-screen set matches the target type composition
function FS:_ensureComposition()
	local desiredTotal = clamp(self._desiredTotal or ENEMIES_MIN_ON_SCREEN, ENEMIES_MIN_ON_SCREEN, ENEMIES_MAX_ON_SCREEN)
	self._desiredTotal = desiredTotal
	local comp = targetComposition(desiredTotal)

	local countA, countB, countC, total = 0, 0, 0, 0
	for _, d in ipairs(self.aliens) do
		total += 1
		if d.type == "A" then countA += 1
		elseif d.type == "B" then countB += 1
		else d.type = "C"; countC += 1 end
	end

	while countA < comp.A and total < desiredTotal do
		local x, y = self:_randomSpawnPosition()
		table.insert(self.aliens, self:_newDrone("A", x, y))
		countA += 1; total += 1
	end
	while countB < comp.B and total < desiredTotal do
		local x, y = self:_randomSpawnPosition()
		table.insert(self.aliens, self:_newDrone("B", x, y))
		countB += 1; total += 1
	end
	while total < desiredTotal do
		local x, y = self:_randomSpawnPosition()
		table.insert(self.aliens, self:_newDrone("C", x, y))
		total += 1
	end
end

-- removes any drone within the respawn safe radius around the grid center, then refills
function FS:_clearAliensAroundSpawn()
	local cx, cy = self.cols * 0.5, self.rows * 0.5
	local safeR2 = RESPAWN_SAFE_RADIUS * RESPAWN_SAFE_RADIUS
	for i = #self.aliens, 1, -1 do
		local d = self.aliens[i]
		local dx = math.abs(d.x - cx)
		local dy = math.abs(d.y - cy)
		if dx > self.cols/2 then dx = self.cols - dx end
		if dy > self.rows/2 then dy = self.rows - dy end
		if dx*dx + dy*dy <= safeR2 then table.remove(self.aliens, i) end
	end
	self:_ensureComposition()
end

-- applies axis-based acceleration, speed cap, damping, and wraps the ship around grid edges
function FS:_updateShip(dt)
	if self._useAxes then
		local ax, ay = self._ax, self._ay
		local mag2 = ax*ax + ay*ay
		if mag2 > 1 then
			local mag = math.sqrt(mag2)
			ax, ay = ax/mag, ay/mag
		end
		self._vx += ax*SHIP_ACCEL*dt
		self._vy += ay*SHIP_ACCEL*dt
	end

	local sp = math.sqrt(self._vx*self._vx + self._vy*self._vy)
	if sp > SHIP_MAX_SPEED then
		local k = SHIP_MAX_SPEED/sp
		self._vx, self._vy = self._vx*k, self._vy*k
	end

	local damp = SHIP_DAMP_BASE^(dt*60)
	self._vx, self._vy = self._vx*damp, self._vy*damp

	self._x += self._vx*dt
	self._y += self._vy*dt

	if self._x < 0 then self._x += self.cols elseif self._x > self.cols then self._x -= self.cols end
	if self._y < 0 then self._y += self.rows elseif self._y > self.rows then self._y -= self.rows end

	self.ship.c, self.ship.r = self._x, self._y

	if self._fireCd > 0 then self._fireCd = math.max(0, self._fireCd - dt) end
	if self._invulnT > 0 then self._invulnT = math.max(0, self._invulnT - dt) end
end

-- moves all active player bullets and removes any that leave the grid or expire
function FS:_updateBullets(dt)
	for i = #self.playerBullets, 1, -1 do
		local b = self.playerBullets[i]
		b.t -= dt
		b.x += b.vx*dt
		b.y += b.vy*dt
		if b.t <= 0 or b.x < 0 or b.x > self.cols or b.y < 0 or b.y > self.rows then
			table.remove(self.playerBullets, i)
		end
	end
end

-- steers each drone toward the ship using toroidal distance, then wraps its position
function FS:_updateDrones(dt)
	for _, d in ipairs(self.aliens) do
		local dx = self._x - d.x
		local dy = self._y - d.y

		if dx > self.cols/2 then dx = dx - self.cols elseif dx < -self.cols/2 then dx = dx + self.cols end
		if dy > self.rows/2 then dy = dy - self.rows elseif dy < -self.rows/2 then dy = dy + self.rows end

		local l = math.sqrt(dx*dx + dy*dy)
		if l > 0 then
			local s = d.baseS
			d.vx = dx / l * s
			d.vy = dy / l * s
		else
			d.vx, d.vy = 0, 0
		end

		d.x += d.vx*dt
		d.y += d.vy*dt

		if d.x < 0 then d.x += self.cols elseif d.x > self.cols then d.x -= self.cols end
		if d.y < 0 then d.y += self.rows elseif d.y > self.rows then d.y -= self.rows end

		d.rot = math.deg(math.atan2(dy, dx))
	end
end

-- tests each bullet against every drone; awards score and removes both on hit
function FS:_collideBullets()
	for i = #self.playerBullets, 1, -1 do
		local b = self.playerBullets[i]
		local hit = false
		for j = #self.aliens, 1, -1 do
			local d = self.aliens[j]
			local r = radiusCells(d.px) * HITBOX_SHRINK_ENEMY

			local dx = b.x - d.x
			local dy = b.y - d.y
			if dx*dx + dy*dy <= r*r then
				self.score += (scoreMap[d.type] or 0)
				table.remove(self.aliens, j)
				self._explosionEvent = true
				hit = true
				break
			end
		end
		if hit then table.remove(self.playerBullets, i) end
	end
end

-- checks whether any drone has collided with the ship; triggers dying state if so
function FS:_collideShip()
	if self._invulnT > 0 then return end
	local shipR = radiusCells(PLAYER_PX) * HITBOX_SHRINK_SHIP
	for j = #self.aliens, 1, -1 do
		local d = self.aliens[j]
		local enemyR = radiusCells(d.px) * HITBOX_SHRINK_SHIP
		local totalR = shipR + enemyR

		local dx = math.abs(self._x - d.x)
		local dy = math.abs(self._y - d.y)
		if dx > self.cols/2 then dx = self.cols - dx end
		if dy > self.rows/2 then dy = self.rows - dy end

		if dx*dx + dy*dy <= totalR*totalR then
			self.gameState = "dying"
			self._dyingT = 0
			self._explosionEvent = true
			return
		end
	end
end

-- advances one frame: handles ready/dying states, tracks elapsed time, and runs all subsystems
function FS:update(dt)
	if not self.alive then return end

	if self.gameState == "playing" then self._hasBegun = true end
	if self._hasBegun then self._timeS += dt end

	self._compTimer += dt
	if self._compTimer >= COMPOSITION_CHECK_INTERVAL then
		self._compTimer = 0
		self._desiredTotal = math.random(ENEMIES_MIN_ON_SCREEN, ENEMIES_MAX_ON_SCREEN)
		self:_ensureComposition()
	end

	if self.gameState == "ready" then
		self._readyT += dt
		if self._readyT >= READY_STEP_DUR then
			self._readyT = 0
			self._readyStepI += 1
			if self._readyStepI > #READY_STEPS then
				self.gameState = "playing"
				self._hasBegun = true
			else
				self._readyText = READY_STEPS[self._readyStepI]
			end
		end
		return
	elseif self.gameState == "dying" then
		self._dyingT += dt
		if self._dyingT >= DYING_TIME then
			self.lives -= 1
			if self.lives <= 0 then self.alive = false; return end

			self._x, self._y = self.cols*0.5, self.rows*0.5
			self._vx, self._vy = 0, 0
			self._ax, self._ay = 0, 0
			self._useAxes = true
			self._ang, self._rotDir = 0, 0
			self._thrustOn, self.playerBullets = false, {}
			self._invulnT = INVULN_TIME

			self:_clearAliensAroundSpawn()
			self.gameState   = "ready"
			self._readyStepI = 1
			self._readyT     = 0
			self._readyText  = READY_STEPS[1]
		end
		return
	end

	self:_updateShip(dt)
	self:_updateBullets(dt)
	self:_updateDrones(dt)
	self:_collideBullets()
	self:_collideShip()
end

-- returns a snapshot of all game objects for the client renderer; clears the explosion flag
function FS:getState()
	local aliensOut = {}
	for _, d in ipairs(self.aliens) do
		aliensOut[#aliensOut+1] = { r=d.y, c=d.x, type=d.type, rot=d.rot, px=d.px }
	end

	local bulletsOut = {}
	for _, b in ipairs(self.playerBullets) do
		bulletsOut[#bulletsOut+1] = { r=b.y, c=b.x }
	end

	local exp = self._explosionEvent
	self._explosionEvent = false

	local state = {
		rows=self.rows, cols=self.cols, cell=self.cell,
		score=self.score, lives=self.lives,
		timeMs=self:getTimeMs(),
		ship={ r=self.ship.r, c=self.ship.c, rot=math.deg(self._aimAng or 0) },
		aliens=aliensOut, shields={}, ufo=nil,
		playerBullets=bulletsOut, enemyBullets={},
		gameState=self.gameState,
		explosionEvent=exp,
		hudText=("Score: %d   Lives: %d"):format(self.score, self.lives),
		alive=self.alive, win=false
	}

	if self.gameState == "ready" then state.overlayText = self._readyText end
	return state
end

return FS
