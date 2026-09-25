local Resilio = {}
Resilio.__index = Resilio

-- canvas and HUD dimensions in pixels
Resilio.CANVAS_W = 16 * 30
Resilio.CANVAS_H = 12 * 30
Resilio.HUD_H = 30

Resilio.PADDLE_W = 120
Resilio.PADDLE_H = 12
Resilio.PADDLE_Y = Resilio.CANVAS_H - 20

Resilio.PADDLE_MAX_SPEED = 350
Resilio.PADDLE_ACCEL     = 1800
Resilio.PADDLE_FRICTION  = 1500

Resilio.BALL_R        = 6
Resilio.BALL_SPEED    = 195
Resilio.BALL_SPEED_INC= 10
Resilio.BALL_SPEED_MAX= 250

Resilio.BRICK_COLS = 12
Resilio.BRICK_MARGIN_X = 12
Resilio.BRICK_TOP = Resilio.HUD_H + 10
Resilio.BRICK_AREA_W = Resilio.CANVAS_W - Resilio.BRICK_MARGIN_X * 2

-- built-in level layouts (1 = normal brick, 2 = medium, 3 = hard, 0 = empty)
local defaultLevels = {}

defaultLevels[1] = {
	{1,1,1,1,1,1,1,1,1,1,1,1},
	{1,1,1,1,1,1,1,1,1,1,1,1},
	{1,1,1,1,1,1,1,1,1,1,1,1},
	{1,1,1,1,1,1,1,1,1,1,1,1},
	{2,2,2,2,2,2,2,2,2,2,2,2},
	{2,2,2,2,2,2,2,2,2,2,2,2},
	{3,3,3,3,3,3,3,3,3,3,3,3},
	{3,3,3,3,3,3,3,3,3,3,3,3},
}

defaultLevels[2] = {
	{0,0,0,0,1,1,1,1,0,0,0,0},
	{0,0,0,1,1,1,1,1,1,0,0,0},
	{0,0,1,1,1,1,1,1,1,1,0,0},
	{0,1,1,1,1,1,1,1,1,1,1,0},
	{0,0,0,0,0,0,0,0,0,0,0,0},
	{0,1,1,1,1,1,1,1,1,1,1,0},
	{0,1,1,0,0,0,0,0,0,1,1,0},
	{0,1,1,0,0,0,0,0,0,1,1,0},
	{0,1,1,1,1,1,1,1,1,1,1,0},
}

defaultLevels[3] = {
	{1,1,0,0,0,0,0,0,0,0,1,1},
	{0,1,1,0,0,0,0,0,0,1,1,0},
	{0,0,1,1,0,0,0,0,1,1,0,0},
	{0,0,0,1,1,0,0,1,1,0,0,0},
	{0,0,0,0,1,1,1,1,0,0,0,0},
	{0,0,0,0,1,1,1,1,0,0,0,0},
	{0,0,0,1,1,0,0,1,1,0,0,0},
	{0,0,1,1,0,0,0,0,1,1,0,0},
	{0,1,1,0,0,0,0,0,0,1,1,0},
	{1,1,0,0,0,0,0,0,0,0,1,1},
}

defaultLevels[4] = {
	{1,1,0,0,0,0,0,0,1,1,0,0},
	{1,1,1,0,0,0,0,0,1,1,0,0},
	{1,1,1,1,0,0,0,0,1,1,0,0},
	{1,1,0,1,1,0,0,0,1,1,0,0},
	{1,1,0,0,1,1,0,0,1,1,0,0},
	{1,1,0,0,0,1,1,0,1,1,0,0},
	{1,1,0,0,0,0,1,1,1,1,0,0},
	{1,1,0,0,0,0,0,1,1,1,0,0},
	{1,1,0,0,0,0,0,0,1,1,0,0},
}

defaultLevels[5] = {
	{0,0,1,1,0,0,0,1,1,0,0,0},
	{0,1,1,1,1,0,1,1,1,1,0,0},
	{1,1,1,1,1,1,1,1,1,1,1,0},
	{1,1,1,1,1,1,1,1,1,1,1,0},
	{1,1,1,1,1,1,1,1,1,1,1,0},
	{0,1,1,1,1,1,1,1,1,1,0,0},
	{0,0,1,1,1,1,1,1,1,0,0,0},
	{0,0,0,1,1,1,1,1,0,0,0,0},
	{0,0,0,0,1,1,1,0,0,0,0,0},
	{0,0,0,0,0,1,0,0,0,0,0,0},
}

local LEVEL_ORDER = {1,2,3,4,5}

local function clamp(v, a, b) if v < a then return a end if v > b then return b end return v end
local function aabb(ax,ay,aw,ah, bx,by,bw,bh) return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah end

-- creates a new breakout game, loads the first level, and positions the ball
function Resilio.new(customLevels)
	local self = setmetatable({}, Resilio)
	self.levels = customLevels or defaultLevels
	self.levelOrder = LEVEL_ORDER
	self.levelOrderPos = 1
	self.levelIndex = self.levelOrder[self.levelOrderPos]
	self.score = 0
	self.lives = 3
	self.alive = true
	self.perfect = false

	self.paddleX = math.floor(Resilio.CANVAS_W/2 - Resilio.PADDLE_W/2)
	self.paddleW = Resilio.PADDLE_W
	self.paddleVel = 0
	self.moveDir = 0

	self.ballX, self.ballY = 0, 0
	self.ballVX, self.ballVY = 0, 0
	self.ballAttached = true
	self.ballSpeed = Resilio.BALL_SPEED

	self.bricks = {}
	self.brickW = math.floor(Resilio.BRICK_AREA_W / Resilio.BRICK_COLS)
	self.brickH = 18
	self.bricksRemaining = 0

	self.autoFireUntil = 0
	self.autoFireCooldown = 0
	self.shots = {}

	self:loadLevel(self.levelIndex)
	self:resetBallOnPaddle()
	return self
end

-- places the ball on top of the paddle and resets its velocity
function Resilio:resetBallOnPaddle()
	self.ballAttached = true
	self.ballSpeed = Resilio.BALL_SPEED
	self.ballX = self.paddleX + self.paddleW/2
	self.ballY = Resilio.PADDLE_Y - Resilio.BALL_R - 1
	self.ballVX = 0
	self.ballVY = 0
end

-- detaches the ball from the paddle and shoots it upward
function Resilio:launchBall()
	if not self.ballAttached then return end
	self.ballAttached = false
	self.ballSpeed = math.max(self.ballSpeed, Resilio.BALL_SPEED)
	self.ballVX = 0
	self.ballVY = -self.ballSpeed
end

-- maps input strings to paddle direction and ball launch
function Resilio:handleInput(input)
	if input == "Left" then
		self.moveDir = -1
	elseif input == "Right" then
		self.moveDir = 1
	elseif input == "Stop" then
		self.moveDir = 0
	elseif input == "Fire" then
		self:launchBall()
	end
end

-- accelerates or decelerates the paddle and moves the attached ball with it
function Resilio:movePaddle(dt)
	if self.moveDir ~= 0 then
		self.paddleVel = self.paddleVel + self.moveDir * Resilio.PADDLE_ACCEL * dt
	else
		if self.paddleVel > 0 then
			self.paddleVel = math.max(0, self.paddleVel - Resilio.PADDLE_FRICTION * dt)
		elseif self.paddleVel < 0 then
			self.paddleVel = math.min(0, self.paddleVel + Resilio.PADDLE_FRICTION * dt)
		end
	end

	self.paddleVel = clamp(self.paddleVel, -Resilio.PADDLE_MAX_SPEED, Resilio.PADDLE_MAX_SPEED)
	self.paddleX = self.paddleX + self.paddleVel * dt
	self.paddleX = clamp(self.paddleX, 0, Resilio.CANVAS_W - self.paddleW)

	if (self.paddleX == 0 and self.paddleVel < 0) or (self.paddleX == Resilio.CANVAS_W - self.paddleW and self.paddleVel > 0) then
		self.paddleVel = 0
	end

	if self.ballAttached then
		self.ballX = self.paddleX + self.paddleW/2
		self.ballY = Resilio.PADDLE_Y - Resilio.BALL_R - 1
	end
end

-- reflects the ball off a brick surface by finding the shallowest penetration axis
local function reflectBallOnBrick(self, brick)
	local cx, cy, r = self.ballX, self.ballY, Resilio.BALL_R
	local bx, by, bw, bh = brick.x, brick.y, brick.w, brick.h
	local leftPen   = (cx + r) - bx
	local rightPen  = (bx + bw) - (cx - r)
	local topPen    = (cy + r) - by
	local bottomPen = (by + bh) - (cy - r)
	local minPen, axis, sgn = leftPen, "x", -1
	if rightPen < minPen then minPen, axis, sgn = rightPen, "x", 1 end
	if topPen < minPen then minPen, axis, sgn = topPen, "y", -1 end
	if bottomPen < minPen then minPen, axis, sgn = bottomPen, "y", 1 end
	if axis == "x" then
		self.ballVX = -self.ballVX
		self.ballX = self.ballX + sgn * (minPen + 0.5)
	else
		self.ballVY = -self.ballVY
		self.ballY = self.ballY + sgn * (minPen + 0.5)
	end
end

-- builds the brick grid from a level layout; randomly assigns extra HP and one auto-fire brick
function Resilio:loadLevel(levelKey)
	local layout = self.levels[levelKey]
	self.bricks = {}
	self.bricksRemaining = 0
	if not layout then self.alive = false return end

	local startX = Resilio.BRICK_MARGIN_X
	local startY = Resilio.BRICK_TOP
	for r = 1, #layout do
		local row = layout[r]
		for c = 1, Resilio.BRICK_COLS do
			local t = row[c]
			if t and t > 0 then
				local bx = startX + (c-1) * self.brickW
				local by = startY + (r-1) * self.brickH
				table.insert(self.bricks, {
					x = bx, y = by,
					w = self.brickW - 2, h = self.brickH - 2,
					type = t, hp = 1, alive = true, special = nil
				})
				self.bricksRemaining += 1
			end
		end
	end

	if #self.bricks > 0 then
		local toughCount = math.clamp(math.random(5,10), 1, #self.bricks)
		local chosen = {}
		while #chosen < toughCount do
			local idx = math.random(1, #self.bricks)
			local already=false
			for _,v in ipairs(chosen) do if v==idx then already=true break end end
			if not already then table.insert(chosen, idx) end
		end
		for _,i in ipairs(chosen) do
			local b = self.bricks[i]
			b.hp = math.random(2,4)
		end
		local specialIndex = chosen[math.random(1, #chosen)]
		if specialIndex then
			local sb = self.bricks[specialIndex]
			sb.special = "auto_fire"
			if sb.hp < 3 then sb.hp = 3 end
		end
	end

	self.shots = {}
end

-- fires laser shots from the paddle toward the nearest bricks while auto-fire is active
function Resilio:autoFireTick(dt)
	local now = os.clock()
	if now >= self.autoFireUntil then return end
	self.autoFireCooldown = self.autoFireCooldown - dt
	if self.autoFireCooldown > 0 then return end
	self.autoFireCooldown = 0.125

	local pxCenter = self.paddleX + self.paddleW/2
	local targetIdx, targetY = nil, -1
	for i, b in ipairs(self.bricks) do
		if b.alive then
			local bxCenter = b.x + b.w/2
			if math.abs(bxCenter - pxCenter) <= self.brickW*0.6 then
				if b.y > targetY then
					targetY = b.y
					targetIdx = i
				end
			end
		end
	end
	if not targetIdx then
		local bestDist = 1e9
		for i, b in ipairs(self.bricks) do
			if b.alive then
				local bxCenter = b.x + b.w/2
				local d = math.abs(bxCenter - pxCenter)
				if d < bestDist then
					bestDist = d
					targetIdx = i
				end
			end
		end
	end

	if targetIdx then
		local b = self.bricks[targetIdx]
		if b.alive then
			b.hp -= 1
			if b.hp <= 0 then
				b.alive = false
				self.bricksRemaining -= 1
				if b.special == "auto_fire" then
					self.score += 50
				else
					self.score += 10
				end
			end
			table.insert(self.shots, {
				x = pxCenter,
				y0 = Resilio.PADDLE_Y,
				y1 = b.y + b.h*0.5,
				expire = now + 0.15
			})
		end
	end
end

-- moves the ball, bounces it off walls and the paddle, and detects brick hits
function Resilio:updateBall(dt)
	if self.ballAttached then return end

	self.ballX = self.ballX + self.ballVX * dt
	self.ballY = self.ballY + self.ballVY * dt

	local r = Resilio.BALL_R

	if self.ballX - r < 0 then
		self.ballX = r
		self.ballVX = math.abs(self.ballVX)
	elseif self.ballX + r > Resilio.CANVAS_W then
		self.ballX = Resilio.CANVAS_W - r
		self.ballVX = -math.abs(self.ballVX)
	end

	if self.ballY - r < Resilio.HUD_H then
		self.ballY = Resilio.HUD_H + r
		self.ballVY = math.abs(self.ballVY)
	elseif self.ballY - r > Resilio.CANVAS_H then
		self.lives -= 1
		if self.lives <= 0 then
			self.alive = false
			return
		else
			self:resetBallOnPaddle()
			return
		end
	end

	local px, py, pw, ph = self.paddleX, Resilio.PADDLE_Y, self.paddleW, Resilio.PADDLE_H
	if aabb(self.ballX - r, self.ballY - r, r*2, r*2, px, py, pw, ph) and self.ballVY > 0 then
		local hitpos = (self.ballX - (px + pw/2)) / (pw/2)
		hitpos = clamp(hitpos, -1, 1)

		if math.abs(hitpos) < 0.05 and math.abs(self.paddleVel) < 10 then
			hitpos = (math.random() > 0.5 and 0.2 or -0.2)
		end

		local angle = math.rad(60) * hitpos
		local speed = clamp(math.sqrt(self.ballVX*self.ballVX + self.ballVY*self.ballVY) + Resilio.BALL_SPEED_INC, Resilio.BALL_SPEED, Resilio.BALL_SPEED_MAX)
		self.ballSpeed = speed
		self.ballVX = math.sin(angle) * speed
		self.ballVY = -math.cos(angle) * speed
		self.ballY = py - r - 0.5
	end

	for i = #self.bricks, 1, -1 do
		local b = self.bricks[i]
		if b.alive and aabb(self.ballX - r, self.ballY - r, r*2, r*2, b.x, b.y, b.w, b.h) then
			b.hp -= 1
			if b.hp <= 0 then
				b.alive = false
				self.bricksRemaining -= 1
				if b.special == "auto_fire" then
					self.score += 50
					self.autoFireUntil = os.clock() + 4
					self.autoFireCooldown = 0
				else
					self.score += 10
				end
			end
			reflectBallOnBrick(self, b)
			break
		end
	end

	-- advance to next level or set perfect flag when all bricks are cleared
	if self.bricksRemaining <= 0 then
		if self.levelOrderPos < #self.levelOrder then
			self.levelOrderPos += 1
			self.levelIndex = self.levelOrder[self.levelOrderPos]
			self.lives += 1
			self:loadLevel(self.levelIndex)
			self:resetBallOnPaddle()
		else
			self.perfect = true
			self.alive = false
		end
	end
end

-- runs one frame: moves paddle, updates ball, fires auto-shots
function Resilio:step(dt)
	if not self.alive then return false end
	self:movePaddle(dt)
	self:updateBall(dt)
	if os.clock() < self.autoFireUntil then
		self:autoFireTick(dt)
	end
	return self.alive
end

-- returns a snapshot of all game objects for the client to render
function Resilio:getState()
	local now = os.clock()
	local shotsOut = {}
	local keep = {}
	for _,s in ipairs(self.shots) do
		if s.expire and s.expire > now then
			table.insert(shotsOut, {x=s.x, y0=s.y0, y1=s.y1})
			table.insert(keep, s)
		end
	end
	self.shots = keep

	local bricksState = {}
	for _,b in ipairs(self.bricks) do
		if b.alive then
			bricksState[#bricksState+1] = {
				x=b.x, y=b.y, w=b.w, h=b.h,
				hp=b.hp, type=b.type, special=b.special
			}
		end
	end

	return {
		alive = self.alive,
		score = self.score,
		lives = self.lives,
		level = self.levelIndex,
		canvasW = Resilio.CANVAS_W,
		canvasH = Resilio.CANVAS_H,
		paddle = {x=self.paddleX, y=Resilio.PADDLE_Y, w=self.paddleW, h=Resilio.PADDLE_H},
		ball = {x=self.ballX, y=self.ballY, r=Resilio.BALL_R, attached=self.ballAttached},
		bricks = bricksState,
		autoFireActive = (now < self.autoFireUntil),
		shots = shotsOut,
		perfect = self.perfect,
	}
end

return Resilio
