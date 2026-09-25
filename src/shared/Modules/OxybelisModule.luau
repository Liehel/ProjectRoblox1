local OxybelisModule = {}

-- creates a new snake game on a cols×rows grid using a circular buffer for the body
function OxybelisModule.new(cols, rows)
	local self = {}
	self.cols = cols or 16
	self.rows = rows or 12

	self.dir = Vector2.new(1, 0)
	self.nextDir = Vector2.new(1, 0)

	self.score = 0
	self.alive = true

	self.capacity = self.cols * self.rows

	self.oxybelisBuffer = table.create(self.capacity)
	self.headIndex = 1
	self.tailIndex = 0
	self.length = 0

	self.occupied = {}
	self.freeIndices = {}
	self.freeIndicesPos = {}
	self.freeCount = 0

	self.food = nil

	-- converts grid coordinates to a flat buffer index
	local function idxFromXY(x, y)
		return (y - 1) * self.cols + x
	end

	-- converts a flat buffer index back to grid coordinates
	local function xyFromIdx(idx)
		local y = math.floor((idx - 1) / self.cols) + 1
		local x = ((idx - 1) % self.cols) + 1
		return x, y
	end

	-- adds a cell to the free-cell pool using a swap-and-pop structure
	local function addFreeCell(idx)
		if not self.freeIndicesPos[idx] then
			self.freeCount += 1
			self.freeIndices[self.freeCount] = idx
			self.freeIndicesPos[idx] = self.freeCount
		end
	end

	-- removes a cell from the free-cell pool in O(1)
	local function removeFreeCell(idx)
		local pos = self.freeIndicesPos[idx]
		if pos then
			local lastIdx = self.freeIndices[self.freeCount]
			self.freeIndices[pos] = lastIdx
			self.freeIndicesPos[lastIdx] = pos

			self.freeIndices[self.freeCount] = nil
			self.freeIndicesPos[idx] = nil
			self.freeCount -= 1
		end
	end

	-- mark all cells as free at startup
	for y = 1, self.rows do
		for x = 1, self.cols do
			local idx = idxFromXY(x, y)
			self.occupied[idx] = false
			addFreeCell(idx)
		end
	end

	-- appends a new segment to the tail of the snake in the circular buffer
	local function pushSegmentAtBack(pos)
		self.tailIndex += 1
		if self.tailIndex > self.capacity then
			self.tailIndex = 1
		end

		self.oxybelisBuffer[self.tailIndex] = pos
		self.length += 1

		local cellIdx = idxFromXY(pos.X, pos.Y)
		self.occupied[cellIdx] = true
		removeFreeCell(cellIdx)
	end

	-- removes the oldest segment from the head of the snake
	local function popSegmentFromFront()
		if self.length == 0 then
			return nil
		end

		local seg = self.oxybelisBuffer[self.headIndex]
		self.oxybelisBuffer[self.headIndex] = nil

		local cellIdx = idxFromXY(seg.X, seg.Y)
		self.occupied[cellIdx] = false
		addFreeCell(cellIdx)

		self.headIndex += 1
		if self.headIndex > self.capacity then
			self.headIndex = 1
		end

		self.length -= 1
		return seg
	end

	-- spawn the initial 3-segment snake near the center
	local midX, midY = math.floor(self.cols / 2), math.floor(self.rows / 2)
	local initialOxybelis = {
		Vector2.new(midX - 2, midY),
		Vector2.new(midX - 1, midY),
		Vector2.new(midX,     midY),
	}

	for _, seg in ipairs(initialOxybelis) do
		pushSegmentAtBack(seg)
	end

	-- places food on a random free cell
	local function spawnFood()
		if self.freeCount <= 0 then
			self.food = nil
			return
		end

		local r = math.random(1, self.freeCount)
		local cellIdx = self.freeIndices[r]
		local fx, fy = xyFromIdx(cellIdx)
		self.food = Vector2.new(fx, fy)
	end

	-- advances the snake one cell; kills it on wall or self collision, grows it on food
	function self:step()
		if not self.alive or self.length <= 0 then
			return
		end

		self.dir = self.nextDir

		local head = self.oxybelisBuffer[self.tailIndex]
		local nh = head + self.dir

		if nh.X < 1 or nh.X > self.cols or nh.Y < 1 or nh.Y > self.rows then
			self.alive = false
			return
		end

		local nhIdx = idxFromXY(nh.X, nh.Y)

		if self.occupied[nhIdx] then
			self.alive = false
			return
		end

		pushSegmentAtBack(nh)

		if self.food and nh.X == self.food.X and nh.Y == self.food.Y then
			self.score += 1

			if self.length >= self.capacity then
				self.alive = false
				return
			end

			spawnFood()
		else
			popSegmentFromFront()
		end
	end

	-- returns the snake body as an ordered array from head to tail
	function self:getOxybelis()
		local result = table.create(self.length)
		if self.length == 0 then
			return result
		end

		local capacity = self.capacity
		local idx = self.tailIndex

		for i = 1, self.length do
			result[i] = self.oxybelisBuffer[idx]
			idx -= 1
			if idx < 1 then
				idx = capacity
			end
		end

		return result
	end

	spawnFood()

	-- exposes the snake body via the `oxybelis` property without storing a copy
	setmetatable(self, {
		__index = function(t, key)
			if key == "oxybelis" then
				return t:getOxybelis()
			end
			return nil
		end
	})

	return self
end

return OxybelisModule
