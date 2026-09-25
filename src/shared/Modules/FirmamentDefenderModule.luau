local Firmament = {}
Firmament.__index = Firmament

-- grid dimensions in cells
Firmament.CELL = 30
Firmament.COLS = 16
Firmament.ROWS = 12

local MAX_WAVE = 3
local START_LIVES = 4

local PLAYER_MOVE_STEP = 0.8
local PLAYER_MOVE_FIRST_DELAY = 0

local PLAYER_FIRE_COOLDOWN = 0.09
local PLAYER_MAX_BULLETS = 1
local PBULLET_STEP = 0.09

local ENEMY_STEP_BASE = 1.20
local ENEMY_STEP_MIN = 0.30
local ENEMY_DROP_ROWS = 1

local ENEMY_LOWCOUNT_THRESHOLD = 5
local ENEMY_LOWCOUNT_STEP_MULT = 0.65

local ENEMY_FIRE_BASE = 1.40
local ENEMY_FIRE_MIN = 0.40

local EBULLET_STEP = 0.08

local WAVE_OVERLAY_TIME = 1.0
local DYING_TIME = 1.2
local READY_TIME = 0.8

local UFO_SPAWN_MIN = 8.0
local UFO_SPAWN_MAX = 16.0
local UFO_STEP = 0.10

local SCORE_A = 100
local SCORE_B = 200
local SCORE_C = 300
local SCORE_UFO_FIXED = 1000
local BONUS_LAST5 = 500

local function toCellsPerSecond(px) return px / Firmament.CELL end
local SHIP_MAX_SPEED = toCellsPerSecond(350)
local SHIP_ACCEL = toCellsPerSecond(1800)
local SHIP_FRICTION = toCellsPerSecond(1500)

local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function rndf(a,b) return a + math.random()*(b-a) end
local function rndi(a,b) return math.random(a,b) end

-- returns the index of the alien at the given grid cell, or nil
local function findAlienAt(aliens, r, c)
	for i,a in ipairs(aliens) do
		if a.r == r and a.c == c then return i end
	end
	return nil
end

-- returns the base score for an alien type
local function baseScoreForType(t)
	if t == "A" then return SCORE_A
	elseif t == "B" then return SCORE_B
	else return SCORE_C end
end

-- creates a new game instance on wave 1 with full lives and a pre-built alien grid
function Firmament.new()
	local self = setmetatable({}, Firmament)
	self.cell = Firmament.CELL
	self.cols = Firmament.COLS
	self.rows = Firmament.ROWS

	self.wave = 1
	self.maxWave = MAX_WAVE
	self.score = 0
	self.lives = START_LIVES
	self.win = false
	self.alive = true
	self.timePlayed = 0

	self.gameState = "wave"
	self.overlayTimer = 0.0

	self.ship = { r = self.rows-1, c = math.floor(self.cols/2) }

	self._shipDir = 0
	self._shipPos = self.ship.c
	self._shipVel = 0.0

	self._playerFireCd = 0
	self._shootHeld = false

	self.aliens = {}
	self.alienDir = 1
	self._enemyStepTimer = 0
	self._levelSpeedScale = 1.0
	self._enemyStepTime = ENEMY_STEP_BASE
	self._lowcountBoosted = false

	self.playerBullets = {}
	self.enemyBullets = {}

	self.shields = {}
	self:_buildWave(self.wave)

	self.ufo = nil
	self._ufoTimer = rndf(UFO_SPAWN_MIN, UFO_SPAWN_MAX)
	self._ufoStepTimer = 0

	self._enemyFireTimer = 0
	self._enemyFireTime = ENEMY_FIRE_BASE

	self._explosionEvent = false

	self._dyingTimer = 0
	self._readyTimer = 0
	self._sineT = 0

	return self
end

-- resets the ship, bullets, alien grid, and shields for the given wave number
function Firmament:_buildWave(wave)
	self.ship.r = self.rows-1
	self.ship.c = math.floor(self.cols/2)

	self._shipDir = 0
	self._shipPos = self.ship.c
	self._shipVel = 0

	self.playerBullets = {}
	self.enemyBullets = {}

	self.aliens = {}
	local topR = 2
	local leftC = 1
	local stepC = 2
	local colsCount = 6

	local rowsTypes = { "C", "B", "B", "A", "A" }
	for rr=0, (#rowsTypes-1) do
		for cc=0, colsCount-1 do
			local aType = rowsTypes[rr+1]
			local ar = topR + rr
			local ac = leftC + cc*stepC
			table.insert(self.aliens, { r = ar, c = ac, type = aType })
		end
	end
	self.alienDir = 1

	self._enemyStepTime = math.max(ENEMY_STEP_MIN, ENEMY_STEP_BASE * self._levelSpeedScale)
	self._lowcountBoosted = false

	self.shields = {}
	local shieldRow = self.rows - 2
	local starts = {3, 6, 10, 13}
	for _,c0 in ipairs(starts) do
		for dc=0,1 do
			local c = clamp(c0 + dc, 1, self.cols)
			table.insert(self.shields, { r=shieldRow, c=c, hp=3 })
		end
	end

	self.gameState = "wave"
	self.overlayTimer = 0.0
	self._readyTimer = 0.0

	self._enemyFireTime = math.max(ENEMY_FIRE_MIN, ENEMY_FIRE_BASE - (wave-1)*0.2)

	self.ufo = nil
	self._ufoTimer = rndf(UFO_SPAWN_MIN, UFO_SPAWN_MAX)
	self._ufoStepTimer = 0
end

-- sets the horizontal movement direction: -1 left, 0 stop, 1 right
function Firmament:setMove(dir)
	if dir == "Left" then
		self._shipDir = -1
	elseif dir == "Right" then
		self._shipDir = 1
	else
		self._shipDir = 0
	end
end

-- fires a player bullet; instantly kills an alien directly above the ship if one is adjacent
function Firmament:shoot()
	if self._playerFireCd <= 0 then
		local spawnR = self.ship.r - 1
		local spawnC = self.ship.c

		local hitImmediate = false
		for i = #self.aliens, 1, -1 do
			local a = self.aliens[i]
			if a.r == spawnR and a.c == spawnC then
				local gain = baseScoreForType(a.type)
				if #self.aliens <= 5 then
					gain = gain + BONUS_LAST5
				end
				self.score = self.score + gain
				table.remove(self.aliens, i)
				self._explosionEvent = true
				hitImmediate = true
				break
			end
		end

		if hitImmediate then
			self._playerFireCd = PLAYER_FIRE_COOLDOWN
		else
			self:_spawnPlayerBullet()
		end
	end
end

-- enables or disables continuous fire while the button is held
function Firmament:setShooting(on)
	self._shootHeld = (on == true)
end

-- creates a player bullet at the ship's position if the bullet cap allows
function Firmament:_spawnPlayerBullet()
	if #self.playerBullets >= PLAYER_MAX_BULLETS then return end
	local spawnR = self.ship.r - 1
	local spawnC = self.ship.c
	if self:_hitShieldAt(spawnR, spawnC) then
		self._explosionEvent = true
		self._playerFireCd = PLAYER_FIRE_COOLDOWN
		return
	end
	table.insert(self.playerBullets, { r = spawnR, c = spawnC, lastR = spawnR, lastC = spawnC })
	self._playerFireCd = PLAYER_FIRE_COOLDOWN
end

-- creates an enemy bullet at the given cell, consuming a shield if one is there
function Firmament:_spawnEnemyBullet(spawnR, spawnC)
	if self:_hitShieldAt(spawnR, spawnC) then
		self._explosionEvent = true
		return
	end
	table.insert(self.enemyBullets, { r = spawnR, c = spawnC, lastR = spawnR, lastC = spawnC })
end

-- returns the leftmost and rightmost column occupied by any alien
function Firmament:_aliensBounds()
	local minC, maxC = 1e9, -1e9
	for _,a in ipairs(self.aliens) do
		if a.c < minC then minC = a.c end
		if a.c > maxC then maxC = a.c end
	end
	if minC == 1e9 then minC = 0; maxC = 0 end
	return minC, maxC
end

-- drops all aliens one row and reverses their horizontal direction
function Firmament:_dropAndReverse()
	for _,a in ipairs(self.aliens) do
		a.r = a.r + ENEMY_DROP_ROWS
	end
	self.alienDir = -self.alienDir
end

-- returns the index of the shield at a given cell, or nil
function Firmament:_shieldIndexAt(r,c)
	for i,s in ipairs(self.shields) do
		if s.r == r and s.c == c then return i end
	end
	return nil
end

-- removes any alien that occupies the same cell as a shield, destroying both
function Firmament:_resolveAlienShieldCollisions()
	if #self.aliens == 0 or #self.shields == 0 then return end
	for i=#self.aliens,1,-1 do
		local a = self.aliens[i]
		local si = self:_shieldIndexAt(a.r, a.c)
		if si then
			table.remove(self.shields, si)
			table.remove(self.aliens, i)
			self._explosionEvent = true
		end
	end
end

-- steps the alien march timer; drops and reverses at walls, speeds up when few remain, and ends the game if they reach the ship row
function Firmament:_updateAliens(dt)
	self._enemyStepTimer = self._enemyStepTimer + dt
	if self._enemyStepTimer >= self._enemyStepTime then
		self._enemyStepTimer = 0
		if (not self._lowcountBoosted) and (#self.aliens <= ENEMY_LOWCOUNT_THRESHOLD) then
			self._enemyStepTime = math.max(ENEMY_STEP_MIN, self._enemyStepTime * ENEMY_LOWCOUNT_STEP_MULT)
			self._lowcountBoosted = true
		end
		local minC, maxC = self:_aliensBounds()
		local willHitWall = false
		if self.alienDir == 1 then
			willHitWall = (maxC + 1 > self.cols)
		else
			willHitWall = (minC - 1 < 1)
		end
		if willHitWall then
			self:_dropAndReverse()
		else
			for _,a in ipairs(self.aliens) do
				a.c = a.c + self.alienDir
			end
		end
		self:_resolveAlienShieldCollisions()
		for _,a in ipairs(self.aliens) do
			if a.r >= self.ship.r then
				self.alive = false
				return
			end
		end
	end
	if #self.aliens == 0 then
		if self.wave >= self.maxWave then
			self.win = true
		else
			self.wave = self.wave + 1
			self.lives = self.lives + 1
			self._levelSpeedScale = self._levelSpeedScale * 0.9
			self:_buildWave(self.wave)
		end
	end
end

-- picks up to 3 random bottom-row aliens across different columns and fires a bullet from each
function Firmament:_chooseShooterAndFire()
	if #self.aliens == 0 then return end
	local cols = {}
	for _,a in ipairs(self.aliens) do
		local list = cols[a.c] or {}
		list[#list+1] = a
		cols[a.c] = list
	end
	local keys = {}
	for c,_ in pairs(cols) do keys[#keys+1]=c end
	if #keys == 0 then return end
	local bulletsToFire = math.min(3, #keys)

	for i = 1, bulletsToFire do
		local randomIndex = rndi(1, #keys)
		local col = keys[randomIndex]
		table.remove(keys, randomIndex)

		local list = cols[col]
		table.sort(list, function(x,y) return x.r > y.r end)
		local shooter = list[1]
		if shooter then
			local spawnR = shooter.r + 1
			local spawnC = shooter.c
			self:_spawnEnemyBullet(spawnR, spawnC)
		end
	end
end

-- advances the enemy fire timer and triggers a volley when it expires
function Firmament:_updateEnemyFire(dt)
	self._enemyFireTimer = self._enemyFireTimer + dt
	if self._enemyFireTimer >= self._enemyFireTime then
		self._enemyFireTimer = 0
		local alive = math.max(1, #self.aliens)
		self._enemyFireTime = math.max(ENEMY_FIRE_MIN, math.min(ENEMY_FIRE_BASE, ENEMY_FIRE_BASE * (alive/30)))
		self:_chooseShooterAndFire()
	end
end

-- damages or destroys the shield at a given cell; returns true if a shield was hit
function Firmament:_hitShieldAt(r,c)
	for i,s in ipairs(self.shields) do
		if s.r == r and s.c == c then
			s.hp = (s.hp or 3) - 1
			if s.hp <= 0 then
				table.remove(self.shields, i)
			end
			self._explosionEvent = true
			return true
		end
	end
	return false
end

-- returns true if two bullets are at the same or adjacent cells
local function bulletsAdjacentOrSame(pr,pc,er,ec)
	return math.abs(pr-er) <= 1 and math.abs(pc-ec) <= 1
end

-- cancels any player and enemy bullet that occupy the same or adjacent cells
function Firmament:_resolveBulletVsBullet()
	if #self.playerBullets == 0 or #self.enemyBullets == 0 then return end
	for i=#self.playerBullets,1,-1 do
		local p = self.playerBullets[i]
		for j=#self.enemyBullets,1,-1 do
			local e = self.enemyBullets[j]
			local sameOrNear = bulletsAdjacentOrSame(p.r,p.c,e.r,e.c)
			local crossed = (p.lastR and e.lastR) and (p.lastR == e.r and p.r == e.lastR and p.lastC == e.c and p.c == e.lastC)
			if sameOrNear or crossed then
				table.remove(self.playerBullets, i)
				table.remove(self.enemyBullets, j)
				self._explosionEvent = true
				break
			end
		end
	end
end

-- moves player bullets upward each step, testing for shield, ufo, and alien hits
function Firmament:_updatePlayerBullets(dt)
	self._playerFireCd = math.max(0, self._playerFireCd - dt)
	if self._shootHeld and self._playerFireCd <= 0 and self.gameState == "playing" then
		self:shoot()
	end
	self._pbtimer = (self._pbtimer or 0) + dt
	local steps = 0
	if self._pbtimer >= PBULLET_STEP then
		steps = math.floor(self._pbtimer / PBULLET_STEP)
		self._pbtimer = self._pbtimer - steps*PBULLET_STEP
	end
	if steps == 0 or #self.playerBullets == 0 then return end
	for _=1,steps do
		for i=#self.playerBullets,1,-1 do
			local b = self.playerBullets[i]
			if self:_hitShieldAt(b.r, b.c) then
				table.remove(self.playerBullets, i)
			else
				b.lastR, b.lastC = b.r, b.c
				b.r = b.r - 1
				if b.r < 1 then
					table.remove(self.playerBullets, i)
				else
					if self.ufo and b.r == self.ufo.r and b.c == self.ufo.c then
						self.score = self.score + SCORE_UFO_FIXED
						self.lives = self.lives + 1
						self.ufo = nil
						self._explosionEvent = true
						table.remove(self.playerBullets, i)
					else
						local ai = findAlienAt(self.aliens, b.r, b.c)
						if ai then
							local at = self.aliens[ai].type
							local aliveBefore = #self.aliens
							local gain = baseScoreForType(at)
							if aliveBefore <= 5 then
								gain = gain + BONUS_LAST5
							end
							self.score = self.score + gain
							table.remove(self.aliens, ai)
							self._explosionEvent = true
							table.remove(self.playerBullets, i)
						else
							if self:_hitShieldAt(b.r, b.c) then
								table.remove(self.playerBullets, i)
							end
						end
					end
				end
			end
		end
		self:_resolveBulletVsBullet()
	end
end

-- moves enemy bullets downward each step; hitting the ship row triggers the dying state
function Firmament:_updateEnemyBullets(dt)
	self._ebtimer = (self._ebtimer or 0) + dt
	local steps = 0
	if self._ebtimer >= EBULLET_STEP then
		steps = math.floor(self._ebtimer / EBULLET_STEP)
		self._ebtimer = self._ebtimer - steps*EBULLET_STEP
	end
	if steps == 0 or #self.enemyBullets == 0 then return end
	for _=1,steps do
		for i=#self.enemyBullets,1,-1 do
			local b = self.enemyBullets[i]
			b.lastR, b.lastC = b.r, b.c
			b.r = b.r + 1
			if b.r > self.rows then
				table.remove(self.enemyBullets, i)
			else
				if self:_hitShieldAt(b.r, b.c) then
					table.remove(self.enemyBullets, i)
				elseif b.r == self.ship.r and b.c == self.ship.c then
					table.remove(self.enemyBullets, i)
					self.gameState = "dying"
					self._dyingTimer = 0.0
					self._explosionEvent = true
				end
			end
		end
		self:_resolveBulletVsBullet()
	end
end

-- transitions the ship into the dying state
function Firmament:_startDying()
	if self.gameState ~= "playing" then return end
	self.gameState = "dying"
	self._dyingTimer = 0.0
	self._explosionEvent = true
end

-- accelerates the ship, applies friction when not moving, and clamps to the grid bounds
function Firmament:_updateShip(dt)
	if self._shipDir ~= 0 then
		self._shipVel = self._shipVel + (self._shipDir * SHIP_ACCEL * dt)
	else
		local f = SHIP_FRICTION * dt
		if self._shipVel > 0 then
			self._shipVel = math.max(0, self._shipVel - f)
		elseif self._shipVel < 0 then
			self._shipVel = math.min(0, self._shipVel + f)
		end
	end

	if self._shipVel > SHIP_MAX_SPEED then self._shipVel = SHIP_MAX_SPEED end
	if self._shipVel < -SHIP_MAX_SPEED then self._shipVel = -SHIP_MAX_SPEED end

	self._shipPos = self._shipPos + self._shipVel * dt

	if self._shipPos < 1 then
		self._shipPos = 1
		if self._shipVel < 0 then self._shipVel = 0 end
	elseif self._shipPos > self.cols then
		self._shipPos = self.cols
		if self._shipVel > 0 then self._shipVel = 0 end
	end

	self.ship.c = clamp(math.floor(self._shipPos + 0.5), 1, self.cols)
end

-- spawns the ufo when its timer expires and moves it one cell per step until it exits
function Firmament:_updateUfo(dt)
	self._ufoTimer = self._ufoTimer - dt
	if not self.ufo and self._ufoTimer <= 0 then
		local dir = (math.random() < 0.5) and 1 or -1
		local c = (dir == 1) and 1 or self.cols
		self.ufo = { r = 1, c = c, dir = dir }
		self._ufoStepTimer = 0
		self._ufoTimer = rndf(UFO_SPAWN_MIN, UFO_SPAWN_MAX)
	end
	if self.ufo then
		self._ufoStepTimer = self._ufoStepTimer + dt
		if self._ufoStepTimer >= UFO_STEP then
			self._ufoStepTimer = 0
			self.ufo.c = self.ufo.c + self.ufo.dir
			if self.ufo.c < 1 or self.ufo.c > self.cols then
				self.ufo = nil
			end
		end
	end
end

-- advances one frame; handles wave/ready/dying overlays, then runs all subsystem updates
function Firmament:update(dt)
	if self.win or not self.alive then return end

	if self.gameState == "wave" then
		self.overlayTimer = self.overlayTimer + dt
		if self.overlayTimer >= WAVE_OVERLAY_TIME then
			self.gameState = "ready"
			self._readyTimer = 0.0
		end
		return
	elseif self.gameState == "ready" then
		self._readyTimer = self._readyTimer + dt
		if self._readyTimer >= READY_TIME then
			self.gameState = "playing"
		end
		return
	elseif self.gameState == "dying" then
		self._dyingTimer = self._dyingTimer + dt
		if self._dyingTimer >= DYING_TIME then
			self.lives = self.lives - 1
			if self.lives <= 0 then
				self.alive = false
				return
			end
			self.ship.c = math.floor(self.cols/2)
			self._shipPos = self.ship.c
			self._shipVel = 0
			self.playerBullets = {}
			self.enemyBullets = {}
			self.gameState = "ready"
			self._readyTimer = 0.0
		end
		return
	end

	self.timePlayed = self.timePlayed + dt

	self:_updateShip(dt)
	self:_updateAliens(dt)
	self:_updateEnemyFire(dt)
	self:_updatePlayerBullets(dt)
	self:_updateEnemyBullets(dt)
	self:_resolveBulletVsBullet()
	self:_updateUfo(dt)

	self._sineT = self._sineT + dt
end

-- returns a snapshot of all game objects for the client renderer; clears the explosion flag
function Firmament:getState()
	local aliensData = {}

	for _,a in ipairs(self.aliens) do
		local phase = (a.c * 0.7 + a.r * 0.31)
		local yo = 0.18 * math.sin(self._sineT * 2.2 + phase)
		aliensData[#aliensData+1] = { r=a.r, c=a.c, type=a.type, yo=yo }
	end

	local shieldsData = {}
	for _,s in ipairs(self.shields) do
		shieldsData[#shieldsData+1] = { r=s.r, c=s.c, hp=s.hp or 3 }
	end

	local ufoData = nil
	if self.ufo then
		ufoData = { r=self.ufo.r, c=self.ufo.c }
	end

	local exp = self._explosionEvent
	self._explosionEvent = false

	return {
		rows = self.rows,
		cols = self.cols,
		cell = self.cell,
		score = self.score,
		lives = self.lives,
		wave = self.wave,
		timePlayed = self.timePlayed,
		ship = { r = self.ship.r, c = self.ship.c },
		aliens = aliensData,
		shields= shieldsData,
		ufo = ufoData,
		playerBullets = self.playerBullets,
		enemyBullets = self.enemyBullets,
		gameState = (self.gameState == "wave" and "wave")
			or (self.gameState == "ready" and "ready")
			or (self.gameState == "dying" and "dying")
			or "playing",
		explosionEvent = exp,
		hud = { score = self.score, lives = self.lives, level = self.wave },
		hudText = ("Score: %d   Lives: %d   Wave: %d"):format(self.score, self.lives, self.wave),
		alive = self.alive,
		win = self.win,
	}
end

return Firmament
