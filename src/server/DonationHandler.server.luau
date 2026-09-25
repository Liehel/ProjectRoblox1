-- The single MarketplaceService.ProcessReceipt for the whole experience.
-- Roblox allows only one callback; the per-game ones were neutralized. Attributes
-- each purchase to its game via DonationRegistry and dedupes by PurchaseId.

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService   = game:GetService("DataStoreService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Modules          = ReplicatedStorage:WaitForChild("Modules")
local DonationRegistry = require(Modules:WaitForChild("DonationRegistry"))
local AnalyticsModule  = require(Modules:WaitForChild("AnalyticsModule"))

-- one shared history store; PurchaseId is globally unique so this dedupes
-- every product across every game
local SafeStore = require(Modules:WaitForChild("DataStoreSafe"))
local PurchaseHistory = SafeStore.Get("Donations_PurchaseHistory_v1")

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- idempotency: never grant the same PurchaseId twice
	local key = "p_" .. tostring(receiptInfo.PurchaseId)
	local okGet, already = pcall(function() return PurchaseHistory:GetAsync(key) end)
	if not okGet then
		return Enum.ProductPurchaseDecision.NotProcessedYet  -- retry later
	elseif already then
		return Enum.ProductPurchaseDecision.PurchaseGranted   -- already done
	end

	local okSet = pcall(function() PurchaseHistory:SetAsync(key, true) end)
	if not okSet then
		return Enum.ProductPurchaseDecision.NotProcessedYet  -- couldn't record -> retry
	end

	-- attribute to the right game (donations grant nothing tangible, so we
	-- always grant even if the product id is unmapped - never leave it pending)
	local gameId = DonationRegistry.GameFor(receiptInfo.ProductId)
	AnalyticsModule.ReportDonationAsync(gameId, receiptInfo)
	print(("[Donation] %s -> %s (product %s)"):format(player.Name, gameId, tostring(receiptInfo.ProductId)))

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("centralized donation handler ready.")
