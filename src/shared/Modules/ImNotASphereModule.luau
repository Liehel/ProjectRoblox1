local ImNotASphereModule = {}

ImNotASphereModule.GameConfig = {
	MaxLives = 8,
	PlayerDefaultSize = Vector3.new(4, 4, 4),
	RequiredCoins = { "Bitcoin1", "Bitcoin2", "Bitcoin3", "Bitcoin4" },
	Points = { Bitcoin = 5, Bitcoinsuper = 15 },
	PowerUpRespawnTime = 5
}

-- physics tuning values for the marble-style ball controller
ImNotASphereModule.Physics = {
	MaxSpeed = 40,         -- top flat speed
	Acceleration = 80,     -- linear push force
	Braking = 60,          -- deceleration when no input
	JumpImpulse = 50,      -- instant upward force on jump
	AirControl = 0.5,      -- fraction of acceleration available in the air

	MaxAngularSpeed = 35,  -- max self-rotation speed
	TorqueAcceleration = 100 -- rate of angular speed change
}

-- power-up durations and stat modifiers
ImNotASphereModule.PowerUps = {
	fast = { Duration = 1.5, SpeedMult = 3.0, AccelMult = 2.5 },
	big = { Duration = 6.0, SizeMult = 2.5 },

	-- magnetic levitation logic for the wings power-up
	ALAS = {
		Duration = 3.5,
		MaxLiftHeight = 20.0,  -- lift ceiling in studs
		LiftForce = 30,        -- spring force toward target height
		Damping = 8            -- aerodynamic damping to prevent overshoot
	},
	Spring = { Duration = 2.0, JumpMult = 2.0 }
}

-- computes the movement force vector given input direction, current velocity, mass, ground state, and active power-ups
function ImNotASphereModule.GetMovementForce(inputDir, currentVel, mass, isGrounded, activePowers)
	local acc = ImNotASphereModule.Physics.Acceleration
	local maxSpd = ImNotASphereModule.Physics.MaxSpeed
	local brake = ImNotASphereModule.Physics.Braking

	if activePowers then
		if activePowers["fast"] then
			maxSpd = maxSpd * ImNotASphereModule.PowerUps.fast.SpeedMult
			acc = acc * ImNotASphereModule.PowerUps.fast.AccelMult
		end
	end

	if not isGrounded then
		acc = acc * ImNotASphereModule.Physics.AirControl
	end

	local force = Vector3.zero
	local flatVel = Vector3.new(currentVel.X, 0, currentVel.Z)

	if inputDir.Magnitude > 0 then
		force = inputDir * acc * mass
		if flatVel.Magnitude > maxSpd then
			local overSpeed = flatVel.Magnitude - maxSpd
			if inputDir:Dot(flatVel.Unit) > 0 then
				force = force - (flatVel.Unit * (overSpeed * mass * 2))
			end
		end
	else
		if isGrounded and flatVel.Magnitude > 0.5 then
			force = -flatVel.Unit * brake * mass
		end
	end

	return force
end

-- returns the target angular velocity for visual ball rotation, scaled by the fast power-up if active
function ImNotASphereModule.GetTargetAngularVelocity(inputDir, activePowers)
	local maxAngSpd = ImNotASphereModule.Physics.MaxAngularSpeed

	if activePowers then
		if activePowers["fast"] then
			maxAngSpd = maxAngSpd * ImNotASphereModule.PowerUps.fast.SpeedMult
		end
	end

	if inputDir.Magnitude > 0 then
		local rotationAxis = Vector3.new(0, 1, 0):Cross(inputDir)
		return rotationAxis * maxAngSpd
	end

	return Vector3.zero
end

-- returns the jump impulse magnitude, multiplied by the spring power-up if active
function ImNotASphereModule.GetJumpImpulse(mass, activePowers)
	local jumpBase = ImNotASphereModule.Physics.JumpImpulse

	if activePowers then
		if activePowers["Spring"] then
			jumpBase = jumpBase * ImNotASphereModule.PowerUps.Spring.JumpMult
		end
	end

	return jumpBase * mass
end

-- returns the travel distance between two elevator endpoint parts
function ImNotASphereModule.CalculateElevatorLimits(startPart, endPart)
	if not startPart or not endPart then return 0 end
	return (endPart.Position - startPart.Position).Magnitude
end

return ImNotASphereModule
