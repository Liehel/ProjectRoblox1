local FireworksModule = {}

FireworksModule.RemoteFolderName = "FireworksRemotes"
FireworksModule.Remotes = {
	RequestLaunch = "RequestLaunch",
	OpenMenu      = "OpenMenu",
	PlayFirework  = "PlayFirework",
}

FireworksModule.ButtonName = "FireworksButton"
FireworksModule.VipGamePassId = 1887238301
FireworksModule.MinInterval = 0.1
FireworksModule.BigCooldown = 1.5

-- Cool, high-visibility palette
local BLUE   = Color3.fromRGB(80, 160, 255)
local DEEP   = Color3.fromRGB(60, 110, 255)
local ICE    = Color3.fromRGB(150, 215, 255)
local VIOLET = Color3.fromRGB(170, 110, 255)
local PURPLE = Color3.fromRGB(140, 80, 255)
local MAGV   = Color3.fromRGB(205, 120, 255)
local GREEN  = Color3.fromRGB(90, 235, 140)
local LIME   = Color3.fromRGB(160, 255, 170)
local TEAL   = Color3.fromRGB(80, 230, 205)

FireworksModule.Types = {
	{
		id = 1, name = "Peony", tagline = "Clean symmetric sphere",
		kind = "burst", swatch = BLUE,
		colors = { BLUE, VIOLET, GREEN },
		ascent = { trail = 1, speed = 0.95 }, apex = 145,
		speed = 62, spread = 175, lifetime = 1.9, size = 1.8, accelY = -24, drag = 2.5, count = 160,
		squash = 0, viewTime = 4.0,
	},
	{
		id = 2, name = "Chrysanthemum", tagline = "Trailed petals curving down",
		kind = "burst", swatch = ICE,
		colors = { ICE, BLUE },
		ascent = { trail = 2, speed = 1.0 }, apex = 155,
		speed = 55, spread = 170, lifetime = 3.0, size = 1.5, accelY = -45, drag = 2, count = 160,
		squash = 4, viewTime = 4.4,
	},
	{
		id = 3, name = "Willow", tagline = "Slow drooping green threads",
		kind = "burst", swatch = GREEN,
		colors = { GREEN, TEAL },
		ascent = { trail = 1, speed = 1.2, silent = true }, apex = 170,
		speed = 44, spread = 160, lifetime = 3.8, size = 1.4, accelY = -78, drag = 4.5, count = 150,
		squash = 5, viewTime = 4.6,
	},
	{
		id = 4, name = "Palm", tagline = "Few big arcing fronds + pistil",
		kind = "burst", swatch = GREEN,
		colors = { GREEN, ICE },
		ascent = { trail = 3, speed = 1.0 }, apex = 155,
		speed = 74, spread = 150, lifetime = 2.8, size = 3.0, accelY = -34, drag = 1.3, count = 80,
		squash = 3, pistil = true, viewTime = 4.2,
	},
	{
		id = 5, name = "Brocade", tagline = "Giant violet glittering crown",
		kind = "burst", swatch = VIOLET,
		colors = { VIOLET, PURPLE },
		ascent = { trail = 3, speed = 1.0 }, apex = 165,
		speed = 52, spread = 175, lifetime = 3.8, size = 1.8, accelY = -55, drag = 3.5, count = 190,
		squash = 4, viewTime = 4.6,
	},
	{
		id = 6, name = "Crossette", tagline = "Stars split into a cross grid",
		kind = "crossette", swatch = BLUE,
		colors = { BLUE, MAGV },
		ascent = { trail = 1, speed = 0.85 }, apex = 140,
		speed = 50, spread = 150, lifetime = 1.3, size = 2.0, accelY = -20, drag = 1, count = 9,
		squash = 2, viewTime = 4.2,
	},
	{
		id = 7, name = "Fish / Bees", tagline = "Erratic swimming swarm",
		kind = "burst", swatch = TEAL,
		colors = { TEAL, GREEN },
		ascent = { trail = 1, speed = 0.85, silent = true }, apex = 135,
		speed = 36, spread = 180, lifetime = 2.2, size = 1.2, accelY = -10, drag = 1.5, count = 160,
		squash = 1, erratic = true, viewTime = 3.8,
	},
	{
		id = 8, name = "Kamuro", tagline = "Ultra-long falling curtain",
		kind = "burst", swatch = ICE,
		colors = { ICE, BLUE },
		ascent = { trail = 1, speed = 1.3, silent = true }, apex = 180,
		speed = 40, spread = 165, lifetime = 4.2, size = 1.3, accelY = -85, drag = 5, count = 160,
		squash = 6, viewTime = 5.0,
	},
	{
		id = 9, name = "Dahlia", tagline = "Few huge vivid diagonal stars",
		kind = "burst", swatch = PURPLE,
		colors = { PURPLE, VIOLET },
		ascent = { trail = 2, speed = 0.8 }, apex = 145,
		speed = 82, spread = 150, lifetime = 2.3, size = 3.4, accelY = -40, drag = 0.8, count = 50,
		squash = 2, viewTime = 4.0,
	},
	{
		id = 10, name = "Horsetail", tagline = "Vertical waterfall, no spread",
		kind = "burst", swatch = ICE,
		colors = { ICE, BLUE },
		ascent = { trail = 1, speed = 1.1, silent = true }, apex = 165,
		speed = 18, spread = 70, lifetime = 3.2, size = 1.4, accelY = -95, drag = 2, count = 130,
		squash = 5, viewTime = 4.4,
	},
	{
		id = 11, name = "Strobe", tagline = "Floating blinking fireflies",
		kind = "burst", swatch = ICE,
		colors = { ICE, BLUE },
		ascent = { trail = 1, speed = 0.9 }, apex = 145,
		speed = 30, spread = 180, lifetime = 3.0, size = 1.0, accelY = -14, drag = 2.5, count = 180,
		squash = 0, strobe = true, viewTime = 4.2,
	},
	{
		id = 12, name = "Spider", tagline = "Hard straight rigid legs",
		kind = "burst", swatch = LIME,
		colors = { LIME, GREEN },
		ascent = { trail = 1, speed = 0.7 }, apex = 135,
		speed = 95, spread = 160, lifetime = 1.1, size = 1.3, accelY = -8, drag = 0.2, count = 80,
		squash = 6, viewTime = 3.4,
	},
	{
		id = 13, name = "Saturn", tagline = "Sphere wrapped in a tilted ring",
		kind = "ring", swatch = BLUE,
		colors = { BLUE, ICE },
		ringColor = VIOLET, ringTilt = 28,
		ascent = { trail = 1, speed = 0.9 }, apex = 150,
		speed = 48, spread = 175, lifetime = 1.9, size = 1.6, accelY = -22, drag = 2, count = 130,
		squash = 0, viewTime = 4.2,
	},
	{
		id = 14, name = "Titanium Salute", tagline = "Blinding blue flash + bang",
		kind = "salute", swatch = ICE,
		colors = { ICE, BLUE },
		apex = 140, viewTime = 2.8,
	},
	{
		id = 15, name = "Mine", tagline = "Volcano fountain from the ground",
		kind = "mine", swatch = VIOLET,
		colors = { VIOLET, BLUE, GREEN },
		speed = 88, spread = 45, lifetime = 1.6, size = 1.6, accelY = -60, drag = 1, count = 240,
		squash = 4, viewTime = 3.4,
	},
	{
		id = 16, name = "Ghost Shell", tagline = "Color morphs green to violet",
		kind = "burst", swatch = GREEN,
		colors = { GREEN, VIOLET },
		colorShift = true,
		ascent = { trail = 1, speed = 0.95, silent = true }, apex = 150,
		speed = 52, spread = 175, lifetime = 2.6, size = 1.6, accelY = -26, drag = 2, count = 160,
		squash = 0, viewTime = 4.2,
	},
	{
		id = 17, name = "Tony", tagline = "THE COMET - crosses & lights the sky",
		kind = "comet", swatch = ICE,
		colors = { ICE, BLUE, VIOLET },
		viewTime = 6.5,
	},
	{
		id = 18, name = "Steamboat Springs", tagline = "World's biggest - colossal finale",
		kind = "mega", swatch = PURPLE,
		colors = { PURPLE, BLUE, GREEN },
		viewTime = 9.0,
	},
	{
		id = 19, name = "EXPLOSION", tagline = "Massive blast, darkens the sky, 16s",
		kind = "explosion", swatch = MAGV,
		colors = { PURPLE, VIOLET, BLUE, GREEN },
		viewTime = 16.0,
	},
}

return FireworksModule
