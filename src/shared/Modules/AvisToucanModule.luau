local AvisToucanModule = {}
AvisToucanModule.__index = AvisToucanModule

-- canvas size in pixels (16×30 and 12×30 cells)
AvisToucanModule.CANVAS_W = 16 * 30
AvisToucanModule.CANVAS_H = 12 * 30

AvisToucanModule.BIRD_W = 76
AvisToucanModule.BIRD_H = 52

AvisToucanModule.PIPE_W       = 75
AvisToucanModule.PIPE_GAP     = 118
AvisToucanModule.PIPE_SPEED   = 117
AvisToucanModule.SPAWN_EVERY  = 1.8

AvisToucanModule.GRAVITY = 900
AvisToucanModule.FLAP_VY = -320

-- axis-aligned bounding box overlap test
local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
	return not (ax + aw < bx or bx + bw < ax or ay + ah < by or by + bh < ay)
end

-- returns a rect shrunk inward by frac on each side (used for hitbox reduction)
local function shrinkRect(x, y, w, h, frac)
	local dx = w * frac * 0.5
	local dy = h * frac * 0.5
	return x + dx, y + dy, w * (1 - frac), h * (1 - frac)
end

-- creates a new game instance with the bird centered and one pipe pre-spawned
function AvisToucanModule.new()
	local self = setmetatable({}, AvisToucanModule)
	self.alive = true
	self.started = false
	self.score = 0
	self.state = {
		birdX = math.floor(AvisToucanModule.CANVAS_W * 0.27),
		birdY = math.floor(AvisToucanModule.CANVAS_H * 0.50),
		velY  = 0,
		pipes = {},
		spawnT = 0,
	}

	local margin = 40
	local gapY = math.random(
		margin + math.floor(AvisToucanModule.PIPE_GAP/2),
		AvisToucanModule.CANVAS_H - margin - math.floor(AvisToucanModule.PIPE_GAP/2)
	)
	table.insert(self.state.pipes, {
		x = AvisToucanModule.CANVAS_W + 50,
		gapY = gapY,
		scored = false,
	})

	return self
end

-- applies an upward velocity impulse; also starts the game on first flap
function AvisToucanModule:flap()
	if not self.alive then return end

	if not self.started then
		self.started = true
	end

	self.state.velY = AvisToucanModule.FLAP_VY
end

-- adds a new pipe with a randomized gap position
local function spawnPipe(state)
	local margin = 60
	local gapY = math.random(
		margin + math.floor(AvisToucanModule.PIPE_GAP/2),
		AvisToucanModule.CANVAS_H - margin - math.floor(AvisToucanModule.PIPE_GAP/2)
	)
	table.insert(state.pipes, {
		x = AvisToucanModule.CANVAS_W + AvisToucanModule.PIPE_W,
		gapY = gapY,
		scored = false,
	})
end

-- advances physics, moves pipes, checks collisions, and increments score
function AvisToucanModule:step(dt)
	if not self.alive then return end
	local s = self.state

	-- idle bob animation before the first flap
	if not self.started then
		local time = os.clock() * 5
		s.birdY = (AvisToucanModule.CANVAS_H * 0.50) + math.sin(time) * 10
		s.velY = 0
		return
	end

	-- apply gravity and move the bird
	s.velY = s.velY + AvisToucanModule.GRAVITY * dt
	s.birdY = s.birdY + s.velY * dt

	-- clamp to canvas bounds; hitting the floor ends the game
	if s.birdY < 0 then
		s.birdY = 0
		s.velY = 0
	elseif s.birdY + AvisToucanModule.BIRD_H > AvisToucanModule.CANVAS_H then
		s.birdY = AvisToucanModule.CANVAS_H - AvisToucanModule.BIRD_H
		self.alive = false
	end

	-- spawn new pipes on a fixed interval
	s.spawnT += dt
	if s.spawnT >= AvisToucanModule.SPAWN_EVERY then
		s.spawnT -= AvisToucanModule.SPAWN_EVERY
		spawnPipe(s)
	end

	-- move pipes left and remove those that have left the canvas
	local i = 1
	while i <= #s.pipes do
		local p = s.pipes[i]
		p.x = p.x - AvisToucanModule.PIPE_SPEED * dt
		if p.x + AvisToucanModule.PIPE_W < -10 then
			table.remove(s.pipes, i)
		else
			i += 1
		end
	end

	-- check bird vs pipe collisions using shrunk hitboxes
	local bx, by = s.birdX, s.birdY
	local bw, bh = AvisToucanModule.BIRD_W, AvisToucanModule.BIRD_H

	bx, by, bw, bh = shrinkRect(bx, by, bw, bh, 0.33)

	for _, p in ipairs(s.pipes) do
		local topH = p.gapY - math.floor(AvisToucanModule.PIPE_GAP/2)
		local botY = p.gapY + math.floor(AvisToucanModule.PIPE_GAP/2)
		local botH = AvisToucanModule.CANVAS_H - botY

		if topH > 0 then
			local tX, tY, tW, tH = shrinkRect(p.x, 0, AvisToucanModule.PIPE_W, topH, 0.20)
			if aabb(bx, by, bw, bh, tX, tY, tW, tH) then
				self.alive = false
				break
			end
		end

		if botH > 0 then
			local bX, bY, bW, bH = shrinkRect(p.x, botY, AvisToucanModule.PIPE_W, botH, 0.20)
			if aabb(bx, by, bw, bh, bX, bY, bW, bH) then
				self.alive = false
				break
			end
		end

		if not p.scored and (p.x + AvisToucanModule.PIPE_W) < s.birdX then
			p.scored = true
			self.score += 1
		end
	end
end

-- returns a flat snapshot of the current game state for network transmission
function AvisToucanModule:serialize()
	local pipesOut = {}
	for _,p in ipairs(self.state.pipes) do
		table.insert(pipesOut, {
			x = math.floor(p.x),
			gapY = math.floor(p.gapY),
			scored = p.scored and true or false,
		})
	end
	return {
		score   = self.score,
		birdX   = math.floor(self.state.birdX),
		birdY   = math.floor(self.state.birdY),
		birdW   = AvisToucanModule.BIRD_W,
		birdH   = AvisToucanModule.BIRD_H,
		pipes   = pipesOut,
		pipeW   = AvisToucanModule.PIPE_W,
		gap     = AvisToucanModule.PIPE_GAP,
		canvasW = AvisToucanModule.CANVAS_W,
		canvasH = AvisToucanModule.CANVAS_H,
		alive   = self.alive,
		started = self.started
	}
end

return AvisToucanModule
