-- MonetizationManager: Handles all Robux monetization
-- Game Passes, Developer Products, Premium Payouts, and Rewarded Ads
-- All processing is server-authoritative to prevent exploits.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local MonetizationManager = {}

local DataManager = nil
local EconomyManager = nil
local InventoryManager = nil
local RemoteHelper = nil

-- Separate DataStore for receipt deduplication (survives data resets)
local receiptStore = DataStoreService:GetDataStore("MagicalHerb_Receipts_v1")

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

function MonetizationManager.init(dataManager, economyManager, inventoryManager, remoteHelper)
	DataManager = dataManager
	EconomyManager = economyManager
	InventoryManager = inventoryManager
	RemoteHelper = remoteHelper

	-- Set up MarketplaceService callbacks
	MonetizationManager._setupProcessReceipt()
	MonetizationManager._setupGamePassHandlers()
end

------------------------------------------------------------------------
-- Game Passes
------------------------------------------------------------------------

-- Check and grant all owned game passes for a player (call on join)
function MonetizationManager.checkGamePasses(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then return end

	for key, passInfo in pairs(GameConfig.GamePasses) do
		if passInfo.id > 0 then
			local success, ownsPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passInfo.id)
			end)

			if success and ownsPass then
				data.ownedGamePasses[key] = true
			end
		end
	end

	-- Send monetization state to client
	MonetizationManager._sendMonetizationData(player)
end

-- Check if a player owns a specific game pass
function MonetizationManager.hasGamePass(player: Player, passKey: string): boolean
	local data = DataManager.getPlayerData(player)
	if not data then return false end
	return data.ownedGamePasses[passKey] == true
end

-- Prompt the player to buy a game pass
function MonetizationManager.promptGamePass(player: Player, passKey: string)
	local passInfo = GameConfig.GamePasses[passKey]
	if not passInfo or passInfo.id <= 0 then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "Game Pass not available yet.",
			type = "warning",
		})
		return
	end

	-- Don't prompt if already owned
	if MonetizationManager.hasGamePass(player, passKey) then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "You already own " .. passInfo.name .. "!",
			type = "info",
		})
		return
	end

	local success, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passInfo.id)
	end)
	if not success then
		warn("[Monetization] Failed to prompt game pass: " .. tostring(err))
	end
end

function MonetizationManager._setupGamePassHandlers()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end

		local passKey, passInfo = GameConfig.getGamePassByProductId(passId)
		if not passKey then return end

		local data = DataManager.getPlayerData(player)
		if not data then return end

		data.ownedGamePasses[passKey] = true

		RemoteHelper.fireClient("GamePassGranted", player, {
			passKey = passKey,
			name = passInfo.name,
		})
		RemoteHelper.fireClient("NotifyClient", player, {
			text = passInfo.name .. " activated!",
			type = "success",
		})

		MonetizationManager._sendMonetizationData(player)
	end)
end

------------------------------------------------------------------------
-- Developer Products
------------------------------------------------------------------------

function MonetizationManager.promptProduct(player: Player, productKey: string)
	local productInfo = GameConfig.DevProducts[productKey]
	if not productInfo or productInfo.id <= 0 then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "Product not available yet.",
			type = "warning",
		})
		return
	end

	local success, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productInfo.id)
	end)
	if not success then
		warn("[Monetization] Failed to prompt product: " .. tostring(err))
	end
end

-- Grant the effects of a developer product
local function grantProduct(player, productKey, productInfo)
	local data = DataManager.getPlayerData(player)
	if not data then return false end

	if productKey == "coinPack_small" or productKey == "coinPack_medium" or productKey == "coinPack_large" then
		EconomyManager.addMoney(player, productInfo.coins, "purchase")
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "+" .. productInfo.coins .. " coins!",
			type = "success",
		})

	elseif productKey == "seedPack" then
		local possibleSeeds = productInfo.possibleSeeds
		for _ = 1, productInfo.seedCount do
			local seedId = possibleSeeds[math.random(1, #possibleSeeds)]
			local seed = GameConfig.getSeedById(seedId)
			if seed then
				-- Unlock the seed if not already unlocked
				local alreadyUnlocked = false
				for _, id in ipairs(data.unlockedSeeds) do
					if id == seedId then
						alreadyUnlocked = true
						break
					end
				end
				if not alreadyUnlocked then
					table.insert(data.unlockedSeeds, seedId)
				end
				-- Add to inventory as a raw herb with random quality
				local qualities = { "B", "A", "S" }
				local quality = qualities[math.random(1, #qualities)]
				InventoryManager.addItem(player, seedId, quality, 1)
			end
		end
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "Rare Seed Pack opened! Check inventory.",
			type = "success",
		})

	elseif productKey == "booster_2x" then
		data.boosterEndTime = os.time() + productInfo.duration
		RemoteHelper.fireClient("BoosterActivated", player, {
			multiplier = productInfo.multiplier,
			endTime = data.boosterEndTime,
			duration = productInfo.duration,
		})
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "2x Earnings active for 30 minutes!",
			type = "success",
		})
	end

	RemoteHelper.fireClient("ProductPurchased", player, {
		productKey = productKey,
		name = productInfo.name,
	})

	return true
end

-- Check if a receipt has already been processed (anti-dupe)
local function isReceiptProcessed(receiptId)
	local success, result = pcall(function()
		return receiptStore:GetAsync("Receipt_" .. receiptId)
	end)
	return success and result == true
end

-- Mark a receipt as processed
local function markReceiptProcessed(receiptId)
	local success, err = pcall(function()
		receiptStore:SetAsync("Receipt_" .. receiptId, true)
	end)
	if not success then
		warn("[Monetization] Failed to mark receipt " .. receiptId .. ": " .. tostring(err))
	end
	return success
end

function MonetizationManager._setupProcessReceipt()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- Player left, don't acknowledge so Roblox retries later
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local receiptId = tostring(receiptInfo.PurchaseId)

		-- Check DataStore-level deduplication
		if isReceiptProcessed(receiptId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		-- Also check in-memory player data
		local data = DataManager.getPlayerData(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		for _, rid in ipairs(data.processedReceipts) do
			if rid == receiptId then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end

		-- Identify the product
		local productKey, productInfo = GameConfig.getDevProductByProductId(receiptInfo.ProductId)
		if not productKey then
			warn("[Monetization] Unknown product ID: " .. receiptInfo.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Grant the product
		local granted = grantProduct(player, productKey, productInfo)
		if not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Record receipt in player data (in-memory, will be saved)
		table.insert(data.processedReceipts, receiptId)
		-- Keep only last 100 receipts in player data to prevent bloat
		if #data.processedReceipts > 100 then
			table.remove(data.processedReceipts, 1)
		end

		-- Record in persistent receipt store
		markReceiptProcessed(receiptId)

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

------------------------------------------------------------------------
-- Premium Payouts
------------------------------------------------------------------------

function MonetizationManager.checkPremiumStatus(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then return end

	local isPremium = player.MembershipType == Enum.MembershipType.Premium
	data.isPremium = isPremium

	RemoteHelper.fireClient("PremiumStatusChanged", player, {
		isPremium = isPremium,
		earningsBonus = isPremium and GameConfig.Premium.earningsBonus or 0,
	})
end

function MonetizationManager.isPremium(player: Player): boolean
	local data = DataManager.getPlayerData(player)
	if not data then return false end
	return data.isPremium == true
end

-- Get the total earnings multiplier for a player (Premium + Booster combined)
function MonetizationManager.getEarningsMultiplier(player: Player): number
	local multiplier = 1.0
	local data = DataManager.getPlayerData(player)
	if not data then return multiplier end

	-- Premium bonus
	if data.isPremium then
		multiplier = multiplier + GameConfig.Premium.earningsBonus
	end

	-- Booster
	if data.boosterEndTime and data.boosterEndTime > os.time() then
		local boosterProduct = GameConfig.DevProducts.booster_2x
		multiplier = multiplier * boosterProduct.multiplier
	end

	return multiplier
end

-- Check if booster is active
function MonetizationManager.isBoosterActive(player: Player): boolean
	local data = DataManager.getPlayerData(player)
	if not data then return false end
	return data.boosterEndTime and data.boosterEndTime > os.time()
end

-- Get remaining booster time in seconds
function MonetizationManager.getBoosterRemaining(player: Player): number
	local data = DataManager.getPlayerData(player)
	if not data or not data.boosterEndTime then return 0 end
	return math.max(0, data.boosterEndTime - os.time())
end

------------------------------------------------------------------------
-- Rewarded Ads (Roblox AdService)
------------------------------------------------------------------------

function MonetizationManager.requestAdWatch(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then return end

	-- Cooldown check
	local now = os.time()
	local timeSinceLastAd = now - (data.lastAdWatch or 0)
	if timeSinceLastAd < GameConfig.Ads.cooldown then
		local remaining = GameConfig.Ads.cooldown - timeSinceLastAd
		local mins = math.ceil(remaining / 60)
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "Ad available in " .. mins .. " min.",
			type = "warning",
		})
		return
	end

	-- Tell client to show the ad via AdService
	RemoteHelper.fireClient("ShowAdToClient", player, {
		rewardAmount = GameConfig.Ads.rewardPerWatch,
	})
end

-- Called after client confirms ad was watched successfully
function MonetizationManager.grantAdReward(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then return end

	-- Double-check cooldown server-side
	local now = os.time()
	local timeSinceLastAd = now - (data.lastAdWatch or 0)
	if timeSinceLastAd < GameConfig.Ads.cooldown then
		return
	end

	data.lastAdWatch = now
	local reward = GameConfig.Ads.rewardPerWatch
	EconomyManager.addMoney(player, reward, "ad_reward")

	RemoteHelper.fireClient("AdRewardGranted", player, {
		amount = reward,
	})
	RemoteHelper.fireClient("NotifyClient", player, {
		text = "+" .. reward .. " coins from ad!",
		type = "success",
	})
end

------------------------------------------------------------------------
-- Auto-Harvest (Game Pass feature)
------------------------------------------------------------------------

-- Called from the game loop to auto-harvest for pass owners
function MonetizationManager.processAutoHarvest(player: Player, PlantManager)
	if not MonetizationManager.hasGamePass(player, "autoHarvest") then
		return
	end

	local data = DataManager.getPlayerData(player)
	if not data then return end

	for _, plant in ipairs(data.plants) do
		if plant.progress and plant.progress >= 1.0 then
			PlantManager.harvestPlant(player, plant.planterId)
		end
	end
end

------------------------------------------------------------------------
-- Growth Speed Bonus (Game Pass feature)
------------------------------------------------------------------------

function MonetizationManager.getGrowthMultiplier(player: Player): number
	if MonetizationManager.hasGamePass(player, "premiumPlanter") then
		return GameConfig.GamePasses.premiumPlanter.growSpeedMultiplier
	end
	return 1.0
end

------------------------------------------------------------------------
-- Utility: Send full monetization state to client
------------------------------------------------------------------------

function MonetizationManager._sendMonetizationData(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then return end

	local now = os.time()
	local adCooldownRemaining = math.max(0, GameConfig.Ads.cooldown - (now - (data.lastAdWatch or 0)))
	local boosterRemaining = math.max(0, (data.boosterEndTime or 0) - now)

	RemoteHelper.fireClient("MonetizationData", player, {
		ownedGamePasses = data.ownedGamePasses,
		isPremium = data.isPremium,
		boosterActive = boosterRemaining > 0,
		boosterRemaining = boosterRemaining,
		adCooldownRemaining = adCooldownRemaining,
		earningsMultiplier = MonetizationManager.getEarningsMultiplier(player),
	})
end

-- Periodic refresh of monetization state (call from game loop)
function MonetizationManager.updateMonetization(player: Player)
	-- Check if booster just expired
	local data = DataManager.getPlayerData(player)
	if not data then return end

	if data.boosterEndTime and data.boosterEndTime > 0 and data.boosterEndTime <= os.time() then
		data.boosterEndTime = 0
		RemoteHelper.fireClient("BoosterActivated", player, {
			multiplier = 1.0,
			endTime = 0,
			duration = 0,
		})
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "2x Earnings booster expired.",
			type = "info",
		})
	end
end

return MonetizationManager
