local Lighting = game:GetService("Lighting")

-- global performance only: no real-time shadows, lightest technology for mobile.
-- the orange island look lives in the client IslandSky script so it can coexist
-- with each minigame's own lighting and be restored when returning to the island.
Lighting.GlobalShadows = false
pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)

print("lighting performance settings ready.")
