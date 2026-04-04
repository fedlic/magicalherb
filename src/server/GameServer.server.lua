-- GameServer.server.lua
-- Main server entry point for Magical Herb Tycoon
-- Initializes all server systems, connects remote events, runs game loops

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

-- Load shared modules
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))

-- Load server modules
local DataManager = require(Server:WaitForChild("DataManager"))
local EconomyManager = require(Server:WaitForChild("EconomyManager"))
local InventoryManager = require(Server:WaitForChild("InventoryManager"))
local PlantManager = require(Server:WaitForChild("PlantManager"))
local ShopManager = require(Server:WaitForChild("ShopManager"))
local NPCManager = require(Server:WaitForChild("NPCManager"))
local UpgradeManager = require(Server:WaitForChild("UpgradeManager"))
local ProcessingManager = require(Server:WaitForChild("ProcessingManager"))
local BrandManager = require(Server:WaitForChild("BrandManager"))
local EventManager = require(Server:WaitForChild("EventManager"))
local TutorialManager = require(Server:WaitForChild("TutorialManager"))
local StaffManager = require(Server:WaitForChild("StaffManager"))

print("[MagicalHerb] Server starting...")

-- Initialize RemoteHelper (creates all RemoteEvents/Functions)
RemoteHelper.init()

-- Initialize modules with dependencies
-- Initialize modules that use dependency injection pattern
EconomyManager.init(DataManager, RemoteHelper)
InventoryManager.init(DataManager, RemoteHelper)
PlantManager.init(DataManager, EconomyManager, InventoryManager, RemoteHelper)
ShopManager.init(DataManager, EconomyManager, InventoryManager, RemoteHelper)
NPCManager.init(DataManager, ShopManager, RemoteHelper)
-- UpgradeManager, ProcessingManager, BrandManager, EventManager, TutorialManager, StaffManager
-- resolve their own dependencies via require()

-- Start auto-save
DataManager.startAutoSave()

-- Player join handler
Players.PlayerAdded:Connect(function(player)
	print("[MagicalHerb] Player joined: " .. player.Name)

	-- Load player data
	local data = DataManager.loadPlayerData(player)

	-- Initialize NPC system for this player
	NPCManager.initPlayer(player)

	-- Send initial data to client
	RemoteHelper.fireClient("PlayerDataLoaded", player, data)

	-- Start tutorial if not complete
	if data.tutorialStep < 9 then
		TutorialManager.init(player)
	end

	-- Update brand score on join
	BrandManager.updateBrandScore(player)
end)

-- Player leave handler
Players.PlayerRemoving:Connect(function(player)
	print("[MagicalHerb] Player leaving: " .. player.Name)
	DataManager.onPlayerLeaving(player)
	NPCManager.cleanupPlayer(player)
	PlantManager.cleanupPlayer(player)
	EventManager.cleanupPlayer(player)
end)

-- Remote Event Handlers

-- Planting
RemoteHelper.onEvent("PlantSeed", function(player, planterId, seedId)
	local result = PlantManager.plantSeed(player, planterId, seedId)
	if result then
		TutorialManager.checkAutoAdvance(player, "plant")
	end
end)

-- Watering
RemoteHelper.onEvent("WaterPlant", function(player, planterId)
	local success = PlantManager.waterPlant(player, planterId)
	if success then
		TutorialManager.checkAutoAdvance(player, "water")
	end
end)

-- Harvesting
RemoteHelper.onEvent("HarvestPlant", function(player, planterId)
	local result = PlantManager.harvestPlant(player, planterId)
	if result then
		TutorialManager.checkAutoAdvance(player, "harvest")
		BrandManager.updateBrandScore(player)
	end
end)

-- Display product on shelf
RemoteHelper.onEvent("DisplayProduct", function(player, shelfId, productId, quality, quantity)
	local success = ShopManager.displayProduct(player, shelfId, productId, quality, quantity or 1)
	if success then
		TutorialManager.checkAutoAdvance(player, "display")
	end
end)

-- Collect money from register
RemoteHelper.onEvent("CollectMoney", function(player)
	local amount = EconomyManager.collectPendingMoney(player)
	if amount > 0 then
		TutorialManager.checkAutoAdvance(player, "collect")
	end
end)

-- Buy seeds
RemoteHelper.onEvent("BuySeed", function(player, seedId, quantity)
	quantity = quantity or 1
	local seed = GameConfig.getSeedById(seedId)
	if not seed then
		return
	end

	local totalCost = seed.cost * quantity
	if EconomyManager.removeMoney(player, totalCost, "seed_purchase") then
		-- Seeds are planted directly, no inventory needed for raw seeds
		-- Just deduct money - planting handles the rest
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "Bought " .. quantity .. "x " .. seed.name,
			type = "success",
		})
		TutorialManager.checkAutoAdvance(player, "buy_seed")
	else
		RemoteHelper.fireClient("NotifyClient", player, {
			text = "Not enough money!",
			type = "error",
		})
	end
end)

-- Buy upgrade
RemoteHelper.onEvent("BuyUpgrade", function(player, category, level)
	local currentLevel = UpgradeManager.getUpgradeLevel(player, category)
	local success, reason = UpgradeManager.buyUpgrade(player, category, currentLevel + 1)
	if not success then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = reason or "Upgrade failed",
			type = "error",
		})
	else
		TutorialManager.checkAutoAdvance(player, "buy_upgrade")
	end
end)

-- Upgrade building
RemoteHelper.onEvent("UpgradeBuilding", function(player, targetLevel)
	local success, reason = UpgradeManager.upgradeBuilding(player, targetLevel)
	if not success then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = reason or "Building upgrade failed",
			type = "error",
		})
	end
end)

-- Hire staff
RemoteHelper.onEvent("HireStaff", function(player, staffType)
	local success, reason = StaffManager.hireStaff(player, staffType)
	if not success then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = reason or "Hiring failed",
			type = "error",
		})
	end
end)

-- Fire staff
RemoteHelper.onEvent("FireStaff", function(player, staffId)
	StaffManager.fireStaff(player, staffId)
end)

-- Start processing
RemoteHelper.onEvent("StartProcessing", function(player, recipeId)
	local success, reason = ProcessingManager.startProcessing(player, recipeId)
	if not success then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = reason or "Processing failed",
			type = "error",
		})
	end
end)

-- Collect processed item
RemoteHelper.onEvent("CollectProcessed", function(player, slotIndex)
	ProcessingManager.collectProcessed(player, slotIndex)
end)

-- Set brand name
RemoteHelper.onEvent("SetBrandName", function(player, name)
	local success, reason = BrandManager.setBrandName(player, name)
	if not success then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = reason or "Invalid brand name",
			type = "error",
		})
	end
end)

-- Start event
RemoteHelper.onEvent("StartEvent", function(player, eventType)
	local success, reason = EventManager.startEvent(player, eventType)
	if not success then
		RemoteHelper.fireClient("NotifyClient", player, {
			text = reason or "Event failed to start",
			type = "error",
		})
	end
end)

-- Tutorial advance
RemoteHelper.onEvent("TutorialAdvance", function(player)
	TutorialManager.advanceStep(player)
end)

-- Remote Function Handlers
RemoteHelper.onInvoke("GetPlayerData", function(player)
	return DataManager.getPlayerData(player)
end)

RemoteHelper.onInvoke("GetShopInfo", function(player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end

	local building = GameConfig.getBuildingByLevel(data.shopLevel)
	return {
		shopLevel = data.shopLevel,
		building = building,
		shelves = ShopManager.getAllShelves(player),
		plants = PlantManager.getAllPlants(player),
		upgrades = data.upgrades,
		staff = data.staff,
		brandInfo = BrandManager.getBrandInfo(player),
		activeEvent = EventManager.getActiveEvent(player),
		processingSlots = ProcessingManager.getProcessingStatus(player),
		pendingMoney = EconomyManager.getPendingMoney(player),
	}
end)

-- Game tick loops
local PLANT_UPDATE_INTERVAL = 1
local NPC_UPDATE_INTERVAL = 0.5
local STAFF_UPDATE_INTERVAL = 1
local PROCESSING_UPDATE_INTERVAL = 1
local EVENT_UPDATE_INTERVAL = 1
local SALARY_TIMER = 0

local plantTimer = 0
local npcTimer = 0
local staffTimer = 0
local processingTimer = 0
local eventTimer = 0

RunService.Heartbeat:Connect(function(dt)
	-- Plant growth updates
	plantTimer = plantTimer + dt
	if plantTimer >= PLANT_UPDATE_INTERVAL then
		PlantManager.updateGrowth(plantTimer)
		plantTimer = 0
	end

	-- NPC behavior updates
	npcTimer = npcTimer + dt
	if npcTimer >= NPC_UPDATE_INTERVAL then
		NPCManager.updateNPCs(npcTimer)
		npcTimer = 0
	end

	-- Staff automation
	staffTimer = staffTimer + dt
	if staffTimer >= STAFF_UPDATE_INTERVAL then
		StaffManager.updateStaff(staffTimer)
		staffTimer = 0
	end

	-- Processing updates
	processingTimer = processingTimer + dt
	if processingTimer >= PROCESSING_UPDATE_INTERVAL then
		ProcessingManager.updateProcessing(processingTimer)
		processingTimer = 0
	end

	-- Event updates
	eventTimer = eventTimer + dt
	if eventTimer >= EVENT_UPDATE_INTERVAL then
		EventManager.updateEvents(eventTimer)
		eventTimer = 0
	end

	-- Salary deduction (every 60s)
	SALARY_TIMER = SALARY_TIMER + dt
	if SALARY_TIMER >= GameConfig.SALARY_INTERVAL then
		SALARY_TIMER = 0
		for _, player in ipairs(Players:GetPlayers()) do
			EconomyManager.processStaffSalaries(player)
		end
	end
end)

print("[MagicalHerb] Server initialized successfully!")
