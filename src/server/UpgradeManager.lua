--[[
	UpgradeManager.lua
	Manages equipment upgrades and building expansion for Magical Herb Tycoon.
	Dependencies: GameConfig, RemoteHelper, DataManager, EconomyManager
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))
local DataManager = require(Server:WaitForChild("DataManager"))
local EconomyManager = require(Server:WaitForChild("EconomyManager"))

local UpgradeManager = {}

-- Upgrade category definitions
local UPGRADE_CATEGORIES = {
	planter = {
		baseCost = 100,
		effectType = "growSpeedBonus",
		effectPerLevel = 0.15,
	},
	processingTable = {
		baseCost = 200,
		effectType = "craftSpeedBonus",
		effectPerLevel = 0.20,
	},
	shelf = {
		baseCost = 150,
		effectType = "displaySlots",
		effectPerLevel = 2,
	},
	register = {
		baseCost = 300,
		effectType = "collectSpeed",
		effectPerLevel = 0.25,
		autoCollectLevel = 3,
	},
	warehouse = {
		baseCost = 250,
		effectType = "storageSlots",
		effectPerLevel = 20,
	},
	sprinkler = {
		baseCost = 500,
		effectType = "waterRange",
		effectPerLevel = 1,
		autoWaterLevel = 1,
	},
	lighting = {
		baseCost = 400,
		effectType = "qualityBonus",
		effectPerLevel = 0.10,
	},
}

local MAX_UPGRADE_LEVEL = 5

-- Building upgrade conditions
local BUILDING_CONDITIONS = {
	[2] = { totalEarned = 500 },
	[3] = { totalEarned = 3000, brandRank = "Local" },
	[4] = { totalEarned = 15000, brandRank = "Popular" },
	[5] = { totalEarned = 80000, brandRank = "Famous" },
	[6] = { totalEarned = 200000 },
	[7] = { totalEarned = 1500000 },
}

-- Brand rank ordering for comparison
local RANK_ORDER = {
	Unknown = 0,
	Local = 1,
	Popular = 2,
	Famous = 3,
	Legend = 4,
}

local function rankMeetsRequirement(currentRank: string, requiredRank: string): boolean
	local current = RANK_ORDER[currentRank] or 0
	local required = RANK_ORDER[requiredRank] or 0
	return current >= required
end

local function getPlayerData(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end
	if not data.upgrades then
		data.upgrades = {}
	end
	if not data.shopLevel then
		data.shopLevel = 1
	end
	return data
end

-- Returns the current upgrade level for a category. 0 if not purchased.
function UpgradeManager.getUpgradeLevel(player: Player, category: string): number
	local data = getPlayerData(player)
	if not data then
		return 0
	end
	return data.upgrades[category] or 0
end

-- Returns the cost for a specific category and level.
-- Formula: baseCost * 3^(level - 1)
function UpgradeManager.getUpgradeCost(category: string, level: number): number?
	local config = UPGRADE_CATEGORIES[category]
	if not config then
		return nil
	end
	if level < 1 or level > MAX_UPGRADE_LEVEL then
		return nil
	end
	return math.floor(config.baseCost * (3 ^ (level - 1)))
end

-- Returns the numeric effect value for a given category and level.
function UpgradeManager.getEffectValue(category: string, level: number): number
	local config = UPGRADE_CATEGORIES[category]
	if not config then
		return 0
	end
	if level <= 0 then
		return 0
	end
	return config.effectPerLevel * level
end

-- Checks whether the player can purchase the next upgrade for a category.
function UpgradeManager.canUpgrade(player: Player, category: string): (boolean, string?)
	local config = UPGRADE_CATEGORIES[category]
	if not config then
		return false, "InvalidCategory"
	end

	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	local currentLevel = data.upgrades[category] or 0
	if currentLevel >= MAX_UPGRADE_LEVEL then
		return false, "MaxLevel"
	end

	local nextLevel = currentLevel + 1
	local cost = UpgradeManager.getUpgradeCost(category, nextLevel)
	if not cost then
		return false, "InvalidLevel"
	end

	local money = EconomyManager.getMoney(player)
	if money < cost then
		return false, "NotEnoughMoney"
	end

	-- Shop level requirements for certain upgrades
	if category == "processingTable" and (data.shopLevel or 1) < 3 then
		return false, "ShopLevelTooLow"
	end
	if category == "sprinkler" and (data.shopLevel or 1) < 2 then
		return false, "ShopLevelTooLow"
	end
	if category == "lighting" and (data.shopLevel or 1) < 4 then
		return false, "ShopLevelTooLow"
	end

	return true, nil
end

-- Purchases an upgrade. Validates cost and requirements, deducts money, updates data.
function UpgradeManager.buyUpgrade(player: Player, category: string, level: number): (boolean, string?)
	local config = UPGRADE_CATEGORIES[category]
	if not config then
		return false, "InvalidCategory"
	end

	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	local currentLevel = data.upgrades[category] or 0

	-- Must buy sequentially
	if level ~= currentLevel + 1 then
		return false, "MustBuyNextLevel"
	end

	if level > MAX_UPGRADE_LEVEL then
		return false, "MaxLevel"
	end

	local canBuy, reason = UpgradeManager.canUpgrade(player, category)
	if not canBuy then
		return false, reason
	end

	local cost = UpgradeManager.getUpgradeCost(category, level)
	if not cost then
		return false, "InvalidCost"
	end

	local deducted = EconomyManager.removeMoney(player, cost, "upgrade")
	if not deducted then
		return false, "DeductFailed"
	end

	data.upgrades[category] = level
	DataManager.savePlayerData(player)

	RemoteHelper.fireClient(player, "UpgradeCompleted", {
		category = category,
		level = level,
		effectType = config.effectType,
		effectValue = UpgradeManager.getEffectValue(category, level),
	})

	return true, nil
end

-- Checks whether the player can upgrade their building to the target level.
function UpgradeManager.canUpgradeBuilding(player: Player, targetLevel: number): (boolean, string?)
	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	local currentLevel = data.shopLevel or 1

	if targetLevel ~= currentLevel + 1 then
		return false, "MustUpgradeSequentially"
	end

	local conditions = BUILDING_CONDITIONS[targetLevel]
	if not conditions then
		return false, "InvalidLevel"
	end

	local stats = data.stats or {}
	local totalEarned = stats.totalEarned or 0
	if conditions.totalEarned and totalEarned < conditions.totalEarned then
		return false, "NotEnoughTotalEarned"
	end

	if conditions.brandRank then
		local currentRank = data.brandRank or "Unknown"
		if not rankMeetsRequirement(currentRank, conditions.brandRank) then
			return false, "BrandRankTooLow"
		end
	end

	local buildingCost = targetLevel * 1000
	local money = EconomyManager.getMoney(player)
	if money < buildingCost then
		return false, "NotEnoughMoney"
	end

	return true, nil
end

-- Upgrades the player building to the target level.
function UpgradeManager.upgradeBuilding(player: Player, targetLevel: number): (boolean, string?)
	local canDo, reason = UpgradeManager.canUpgradeBuilding(player, targetLevel)
	if not canDo then
		return false, reason
	end

	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	local buildingCost = targetLevel * 1000
	local deducted = EconomyManager.removeMoney(player, buildingCost, "building")
	if not deducted then
		return false, "DeductFailed"
	end

	data.shopLevel = targetLevel

	-- Unlock new seeds based on shop level tier
	local seeds = GameConfig.Seeds or {}
	local newlyUnlocked = {}
	if not data.unlockedSeeds then
		data.unlockedSeeds = {}
	end

	for seedId, seedInfo in pairs(seeds) do
		local requiredTier = seedInfo.tier or 1
		if requiredTier <= targetLevel and not data.unlockedSeeds[seedId] then
			data.unlockedSeeds[seedId] = true
			table.insert(newlyUnlocked, seedId)
		end
	end

	DataManager.savePlayerData(player)

	RemoteHelper.fireClient(player, "BuildingUpgraded", {
		shopLevel = targetLevel,
		unlockedSeeds = newlyUnlocked,
	})

	return true, nil
end

return UpgradeManager
