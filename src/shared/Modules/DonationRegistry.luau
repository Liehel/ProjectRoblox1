local DonationRegistry = {}

-- [productId] = "GameId"  (GameId must match what AnalyticsModule expects)
DonationRegistry.ProductToGame = {
	-- Oxybelis
	[3469886027] = "Oxybelis", [3469886194] = "Oxybelis", [3469886385] = "Oxybelis",
	[3469886458] = "Oxybelis", [3469886602] = "Oxybelis", [3469886735] = "Oxybelis",
	-- Resilio
	[3475290016] = "Resilio", [3475290155] = "Resilio", [3475290208] = "Resilio",
	[3475290357] = "Resilio", [3475290476] = "Resilio", [3475290784] = "Resilio",
	-- AvisToucan  (NOTE: 3474075594 is ALSO listed for TapAndHold - duplicate
	-- product id; create a separate product for one of them and fix this.)
	[3474073921] = "AvisToucan", [3474074313] = "AvisToucan", [3474074984] = "AvisToucan",
	[3474075222] = "AvisToucan", [3474075401] = "AvisToucan",
	-- FoxyFruit
	[3475288218] = "FoxyFruit", [3475288422] = "FoxyFruit", [3475288643] = "FoxyFruit",
	[3475288826] = "FoxyFruit", [3475288972] = "FoxyFruit", [3475289214] = "FoxyFruit",
	-- FirmamentDefender
	[3477824531] = "FirmamentDefender", [3477824658] = "FirmamentDefender",
	[3477824790] = "FirmamentDefender", [3477825231] = "FirmamentDefender",
	[3477825407] = "FirmamentDefender", [3477825563] = "FirmamentDefender",
	-- FirmamentSiege
	[3478073654] = "FirmamentSiege", [3478073816] = "FirmamentSiege",
	[3478073972] = "FirmamentSiege", [3478077889] = "FirmamentSiege",
	[3478078031] = "FirmamentSiege", [3478078163] = "FirmamentSiege",
	-- JuiceCutter
	[3485520379] = "JuiceCutter", [3485520618] = "JuiceCutter", [3485520810] = "JuiceCutter",
	[3485521145] = "JuiceCutter", [3485521376] = "JuiceCutter", [3485521765] = "JuiceCutter",
	-- ImNotASphere
	[3588134038] = "ImNotASphere", [3588134140] = "ImNotASphere", [3588134227] = "ImNotASphere",
	[3588134292] = "ImNotASphere", [3588134381] = "ImNotASphere", [3588134443] = "ImNotASphere",
	-- TapAndHold
	[3572911018] = "TapAndHold", [3572911230] = "TapAndHold", [3572911349] = "TapAndHold",
	[3572911440] = "TapAndHold", [3572911513] = "TapAndHold", [3474075594] = "TapAndHold",
	-- TurrisCasei
	[3518446349] = "TurrisCasei", [3518446440] = "TurrisCasei", [3518446529] = "TurrisCasei",
	[3518446659] = "TurrisCasei", [3518446761] = "TurrisCasei", [3518446854] = "TurrisCasei",
}

-- returns the game id for a product, or "Unknown" (still grant the purchase)
function DonationRegistry.GameFor(productId)
	return DonationRegistry.ProductToGame[productId] or "Unknown"
end

return DonationRegistry
