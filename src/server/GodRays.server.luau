local CollectionService = game:GetService("CollectionService")

-- turns any part tagged "GodRay" into a cheap 2D light-shaft look.
-- place thin angled parts in studio where you want light beams, then tag them.
local function styleRay(part)
	if not part:IsA("BasePart") then return end
	part.Material      = Enum.Material.Neon
	part.Color         = Color3.fromRGB(255, 220, 160)  -- warm light
	part.Transparency  = 0.88
	part.CastShadow    = false
	part.CanCollide    = false
	part.CanQuery      = false
	part.CanTouch      = false
	part.Anchored      = true
end

-- style existing rays and any added later
for _, p in ipairs(CollectionService:GetTagged("GodRay")) do
	styleRay(p)
end
CollectionService:GetInstanceAddedSignal("GodRay"):Connect(styleRay)

print("god rays ready.")
