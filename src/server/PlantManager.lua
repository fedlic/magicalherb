-- PlantManager: Handles planting, growing, watering, and harvesting

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local PlantManager = {}

local DataManager = nil
local EconomyManager = nil
local InventoryManager = nil
local RemoteHelper = nil
local GameConfig = nil

-- Track water cooldowns per plant: { [playerId] = { [planterId] = lastWaterTime } }
local waterCooldowns = {}

function PlantManager.init(dataManager, economyManager, inventoryManager, remoteHelper)
	DataManager = dataManager
	EconomyManager = economyManager
	InventoryManager = inventoryManager
	RemoteHelper = remoteHelper
	GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
end

function PlantManager.plantSeed(player: Player, planterId: string, seedId: string)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end

	-- Validate seed exists and is unlocked
	local seed = GameConfig.getSeedById(seedId)
	if not seed then
		return nil
	end

	local isUnlocked = false
	for _, id in ipairs(data.unlockedSeeds) do
		if id == seedId then
			isUnlocked = true
			break
		end
	end
	if not isUnlocked then
		return nil
	end

	-- Validate planter is within building limit
	local building = GameConfig.getBuildingByLevel(data.shopLevel)
	local planterNum = tonumber(string.match(planterId, "%d+"))
	if not planterNum or planterNum > building.maxPlanters then
		return nil
	end

	-- Check planter is empty
	for _, plant in ipairs(data.plants) do
		if plant.planterId == planterId then
			return nil
		end
	end

	-- Deduct seed cost
	if not EconomyManager.removeMoney(player, seed.cost, "seed_purchase") then
		return nil
	end

	-- Create plant instance
	local plant = {
		id = HttpService:GenerateGUID(false),
		seedId = seedId,
		planterId = planterId,
		stage = "seed",
		progress = 0,
		qualityScore = 0,
		waterCount = 0,
		fertilizerUsed = nil,
		plantedAt = os.time(),
	}

	table.insert(data.plants, plant)

	RemoteHelper.fireClient("PlantUpdated", player, {
		action = "planted",
		plant = plant,
	})

	return plant
end

function PlantManager.waterPlant(player: Player, planterId: string): boolean
	local data = DataManager.getPlayerData(player)
	if not data then
		return false
	end

	-- Find plant
	local plant = nil
	for _, p in ipairs(data.plants) do
		if p.planterId == planterId then
			plant = p
			break
		end
	end

	if not plant or plant.stage == "ready" then
		return false
	end

	-- Check cooldown
	local userId = player.UserId
	if not waterCooldowns[userId] then
		waterCooldowns[userId] = {}
	end

	local lastWater = waterCooldowns[userId][planterId] or 0
	if os.time() - lastWater < GameConfig.WATER_COOLDOWN then
		return false
	end

	-- Water the plant
	waterCooldowns[userId][planterId] = os.time()
	plant.waterCount = plant.waterCount + 1
	plant.qualityScore = plant.qualityScore + 5
	-- Growth boost: add 10% progress
	plant.progress = math.min(plant.progress + 0.1, 1.0)

	-- Update stage
	plant.stage = GameConfig.getStageFromProgress(plant.progress)

	RemoteHelper.fireClient("PlantUpdated", player, {
		action = "watered",
		plant = plant,
	})

	return true
end

function PlantManager.harvestPlant(player: Player, planterId: string)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end

	-- Find plant
	local plantIndex = nil
	local plant = nil
	for i, p in ipairs(data.plants) do
		if p.planterId == planterId then
			plant = p
			plantIndex = i
			break
		end
	end

	if not plant or plant.stage ~= "ready" then
		return nil
	end

	-- Calculate final quality
	local seed = GameConfig.getSeedById(plant.seedId)
	if not seed then
		return nil
	end

	local planterLevel = data.upgrades.planter or 0
	local lightingLevel = data.upgrades.lighting or 0
	local totalScore = plant.qualityScore + (planterLevel * 3) + (lightingLevel * 4)

	local quality = GameConfig.getQualityFromScore(totalScore)

	-- Clamp to seed's max quality
	local maxQualityIdx = GameConfig.getQualityIndex(seed.maxQuality)
	local qualityIdx = GameConfig.getQualityIndex(quality)
	if qualityIdx > maxQualityIdx then
		quality = seed.maxQuality
	end

	-- Create product in inventory
	local productId = "raw_" .. plant.seedId
	local added = InventoryManager.addItem(player, productId, quality, 1)
	if not added then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "Inventory full! Make space first.",
			type = "warning",
		})
		return nil
	end

	-- Update stats
	data.stats.totalHarvests = (data.stats.totalHarvests or 0) + 1
	if quality == "S" then
		data.stats.sRankHarvests = (data.stats.sRankHarvests or 0) + 1
	elseif quality == "SS" then
		data.stats.ssRankHarvests = (data.stats.ssRankHarvests or 0) + 1
	end

	-- Remove plant
	table.remove(data.plants, plantIndex)

	-- Clean up cooldown
	if waterCooldowns[player.UserId] then
		waterCooldowns[player.UserId][planterId] = nil
	end

	local result = {
		productId = productId,
		seedId = plant.seedId,
		quality = quality,
		qualityScore = totalScore,
	}

	RemoteHelper.fireClient("PlantHarvested", player, result)

	return result
end

function PlantManager.updateGrowth(dt: number)
	local Players = game:GetService("Players")
	local now = os.time()

	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataManager.getPlayerData(player)
		if data and data.plants then
			local anyUpdated = false
			for _, plant in ipairs(data.plants) do
				if plant.stage ~= "ready" then
					local seed = GameConfig.getSeedById(plant.seedId)
					if seed then
						-- Calculate growth speed with upgrades + game pass
						local planterLevel = data.upgrades.planter or 0
						local speedBonus = 1 + GameConfig.getUpgradeEffect("planter", planterLevel)

						-- Premium Planter game pass multiplier
						local ServerSS = game:GetService("ServerScriptService")
						local ServerFolder = ServerSS:FindFirstChild("Server")
						if ServerFolder then
							local MonetizationMgr = require(ServerFolder:WaitForChild("MonetizationManager"))
							speedBonus = speedBonus * MonetizationMgr.getGrowthMultiplier(player)
						end

						-- Tutorial override: first plant grows fast
						local growTime = seed.growTime
						if data.tutorialStep <= 4 and plant.planterId == "planter_1" then
							growTime = GameConfig.TUTORIAL_GROW_TIME
						end

						local elapsed = now - plant.plantedAt
						local newProgress = (elapsed * speedBonus) / growTime
						newProgress = math.min(newProgress, 1.0)

						if newProgress ~= plant.progress then
							plant.progress = newProgress
							local newStage = GameConfig.getStageFromProgress(newProgress)
							if newStage ~= plant.stage then
								plant.stage = newStage
								anyUpdated = true
							end
						end
					end
				end
			end

			if anyUpdated then
				RemoteHelper.fireClient("PlantUpdated", player, {
					action = "growth",
					plants = data.plants,
				})
			end
		end
	end
end

function PlantManager.getPlantInfo(player: Player, planterId: string)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end

	for _, plant in ipairs(data.plants) do
		if plant.planterId == planterId then
			return plant
		end
	end
	return nil
end

function PlantManager.getAllPlants(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return {}
	end
	return data.plants
end

-- Auto-water called by staff system (no quality bonus)
function PlantManager.autoWater(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return
	end

	for _, plant in ipairs(data.plants) do
		if plant.stage ~= "ready" then
			plant.waterCount = plant.waterCount + 1
			-- No quality bonus for auto-water
			plant.progress = math.min(plant.progress + 0.05, 1.0)
			plant.stage = GameConfig.getStageFromProgress(plant.progress)
		end
	end
end

-- Auto-harvest called by staff system (reduced quality)
function PlantManager.autoHarvest(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return
	end

	local readyPlanters = {}
	for _, plant in ipairs(data.plants) do
		if plant.stage == "ready" then
			table.insert(readyPlanters, plant.planterId)
		end
	end

	for _, planterId in ipairs(readyPlanters) do
		-- Reduce quality score by 50% for auto-harvest
		for _, plant in ipairs(data.plants) do
			if plant.planterId == planterId then
				plant.qualityScore = math.floor(plant.qualityScore * 0.5)
				break
			end
		end
		PlantManager.harvestPlant(player, planterId)
	end
end

function PlantManager.cleanupPlayer(player: Player)
	waterCooldowns[player.UserId] = nil
end

return PlantManager
