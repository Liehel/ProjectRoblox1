local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local SPEED_SWIM        = 10
local SPEED_WALK        = 16
local SWIM_DETECT_RANGE = 5.0   -- studs above water surface that trigger swim
local SWIM_FLOAT_OFFSET = 3.5   -- HRP rests this many studs above water surface
local STROKE_RATE       = 1.2   -- arm strokes per second
local TILT_ANGLE        = math.rad(-82)  -- how flat the character lies (−90 = fully horizontal)

local player = Players.LocalPlayer

-- water top Y, read from workspace.Water.Model.Cube1 (the swim mesh)
local function getWaterSurfaceY()
    local water = workspace:FindFirstChild("Water")
    if water then
        local model = water:FindFirstChild("Model")
        if model then
            local cube1 = model:FindFirstChild("Cube1")
            if cube1 and cube1:IsA("BasePart") then
                return cube1.Position.Y + cube1.Size.Y / 2
            end
        end
    end
    return nil
end

local function setupSwim(character)
    local hrp      = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")

    -- RootJoint: connects HRP (Part0) to LowerTorso (Part1).
    local rootJoint    = hrp:WaitForChild("RootJoint")
    local defRootJoint = rootJoint.C0

    -- CORRECCIÓN R15: Buscar las extremidades correctas para acceder a sus articulaciones
    local rightUpper = character:WaitForChild("RightUpperArm")
    local leftUpper  = character:WaitForChild("LeftUpperArm")
    local rightLower = character:WaitForChild("RightLowerArm")
    local leftLower  = character:WaitForChild("LeftLowerArm")
    local rightLeg   = character:WaitForChild("RightUpperLeg")
    local leftLeg    = character:WaitForChild("LeftUpperLeg")

    -- CORRECCIÓN R15: Los Motor6D viven dentro de las extremidades correspondientes
    local jRS = rightUpper:WaitForChild("RightShoulder")
    local jLS = leftUpper:WaitForChild("LeftShoulder")
    local jRH = rightLeg:WaitForChild("RightHip")
    local jLH = leftLeg:WaitForChild("LeftHip")
    local jRE = rightLower:WaitForChild("RightElbow")
    local jLE = leftLower:WaitForChild("LeftElbow")

    -- Save default C0 so we can restore on water exit
    local defRS = jRS and jRS.C0
    local defLS = jLS and jLS.C0
    local defRH = jRH and jRH.C0
    local defLH = jLH and jLH.C0
    local defRE = jRE and jRE.C0
    local defLE = jLE and jLE.C0

    -- VectorForce for buoyancy (Y axis only).
    local swimAttach = Instance.new("Attachment")
    swimAttach.Name  = "SwimAttachment"
    swimAttach.Parent = hrp

    local swimForce = Instance.new("VectorForce")
    swimForce.Name                = "SwimBuoyancy"
    swimForce.RelativeTo          = Enum.ActuatorRelativeTo.World
    swimForce.ApplyAtCenterOfMass = true
    swimForce.Force               = Vector3.zero
    swimForce.Attachment0         = swimAttach
    swimForce.Parent              = hrp

    local animator        = humanoid:FindFirstChildOfClass("Animator")
    local savedJumpHeight = humanoid.JumpHeight
    local estaEnAgua      = false
    local wasInWater      = false
    local connections     = {}

    local hb = RunService.Heartbeat:Connect(function()
        if not hrp.Parent then return end

        local waterY  = getWaterSurfaceY()
        local hrpY    = hrp.Position.Y
        local inWater = waterY ~= nil and (hrpY < waterY + SWIM_DETECT_RANGE)

        -- State enter
        if inWater and not estaEnAgua then
            estaEnAgua          = true
            humanoid.JumpHeight = 0       -- no jumping in water
            humanoid.WalkSpeed  = SPEED_SWIM
        end

        -- State exit
        if not inWater and estaEnAgua then
            estaEnAgua          = false
            swimForce.Force     = Vector3.zero
            humanoid.JumpHeight = savedJumpHeight
            humanoid.WalkSpeed  = SPEED_WALK
        end

        -- Buoyancy force while swimming
        if estaEnAgua and waterY then
            humanoid.WalkSpeed = SPEED_SWIM  -- enforce every frame

            local targetY  = waterY + SWIM_FLOAT_OFFSET
            local diff     = targetY - hrpY
            local velY     = hrp.AssemblyLinearVelocity.Y
            local gravComp = hrp.AssemblyMass * workspace.Gravity

            -- Spring-damper
            local spring  = diff * 500
            local damping = -velY * 300
            swimForce.Force = Vector3.new(0, gravComp + math.clamp(spring + damping, -2000, 7000), 0)
        end
    end)
    table.insert(connections, hb)

    local rs = RunService.RenderStepped:Connect(function()
        if not hrp.Parent then return end

        if estaEnAgua then
            -- Al entrar al agua desactivamos temporalmente el animador por defecto de Roblox
            if not wasInWater then
                wasInWater = true
                
                local animateScript = character:FindFirstChild("Animate")
                if animateScript then animateScript.Disabled = true end -- Apaga animaciones por defecto
                
                if animator then
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        track:Stop(0)
                    end
                end
            end

            rootJoint.C0 = defRootJoint * CFrame.Angles(TILT_ANGLE, 0, 0)

            local isMoving = hrp.AssemblyLinearVelocity.Magnitude > 2
            local phi    = isMoving and (tick() * STROKE_RATE * 2 * math.pi) or 0
            local legPhi = phi * 2  -- Las piernas patean al doble de velocidad

            -- Brazos alternados (Agregado un leve ángulo en Z para simular que salen del agua)
            if jRS and defRS then
                jRS.C0 = defRS * CFrame.Angles(math.sin(phi) * math.rad(70), 0, math.cos(phi) * math.rad(20))
            end
            if jLS and defLS then
                jLS.C0 = defLS * CFrame.Angles(math.sin(phi + math.pi) * math.rad(70), 0, -math.cos(phi + math.pi) * math.rad(20))
            end
            
            -- Codos que se flexionan dinámicamente en el ciclo
            if jRE and defRE then
                jRE.C0 = defRE * CFrame.Angles(math.max(0, math.sin(phi + math.pi * 0.5)) * math.rad(45), 0, 0)
            end
            if jLE and defLE then
                jLE.C0 = defLE * CFrame.Angles(math.max(0, math.sin(phi + math.pi * 1.5)) * math.rad(45), 0, 0)
            end
            
            -- Piernas (Pataleo arriba y abajo invertido)
            if jRH and defRH then
                jRH.C0 = defRH * CFrame.Angles(math.sin(legPhi) * math.rad(25), 0, 0)
            end
            if jLH and defLH then
                jLH.C0 = defLH * CFrame.Angles(math.sin(legPhi + math.pi) * math.rad(25), 0, 0)
            end

        elseif wasInWater then
            wasInWater       = false
            
            local animateScript = character:FindFirstChild("Animate")
            if animateScript then animateScript.Disabled = false end -- Reactiva animaciones de Roblox

            rootJoint.C0     = defRootJoint
            if jRS and defRS then jRS.C0 = defRS end
            if jLS and defLS then jLS.C0 = defLS end
            if jRH and defRH then jRH.C0 = defRH end
            if jLH and defLH then jLH.C0 = defLH end
            if jRE and defRE then jRE.C0 = defRE end
            if jLE and defLE then jLE.C0 = defLE end

            -- Despierta el script de animaciones nativo
            task.defer(function()
                if humanoid and humanoid.Parent then
                    local ws = humanoid.WalkSpeed
                    humanoid.WalkSpeed = ws + 0.001
                    task.wait()
                    humanoid.WalkSpeed = ws
                end
            end)
        end
    end)
    table.insert(connections, rs)

    -- Limpieza al morir o reaparecer
    local anc = character.AncestryChanged:Connect(function()
        if not character.Parent then
            for _, c in ipairs(connections) do
                if c.Connected then c:Disconnect() end
            end
            if swimAttach and swimAttach.Parent then swimAttach:Destroy() end
        end
    end)
    table.insert(connections, anc)
end

local function init()
    local char = player.Character or player.CharacterAdded:Wait()
    setupSwim(char)
end

init()

player.CharacterAdded:Connect(function(char)
    task.wait(0.5) 
    setupSwim(char)
end)