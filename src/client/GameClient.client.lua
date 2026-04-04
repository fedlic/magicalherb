-- GameClient.client.lua
-- Main client entry point for Magical Herb Tycoon
-- Initializes UI, camera, effects, and handles server events

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))

-- Wait for client modules (loaded from StarterPlayerScripts/Client)
local clientFolder = script.Parent
local UIController = require(clientFolder:WaitForChild("UIController"))
local InputHandler = require(clientFolder:WaitForChild("InputHandler"))
local EffectsManager = require(clientFolder:WaitForChild("EffectsManager"))
local CameraController = require(clientFolder:WaitForChild("CameraController"))

print("[MagicalHerb] Client starting...")

-- Initialize RemoteHelper (client mode - gets references)
RemoteHelper.init()

-- Initialize client systems
UIController.init()
EffectsManager.init()
CameraController.init()
InputHandler.init()

-- Local state
local playerData = nil
local shopInfo = nil
local isFirstLogin = true

-- Wait for server to send initial data
RemoteHelper.onEvent("PlayerDataLoaded", function(data)
	playerData = data
	print("[MagicalHerb] Player data loaded, money: $" .. (data.money or 0))

	-- Update UI with initial data
	UIController.updateMoney(data.money)

	if data.inventory then
		UIController.updateInventory({
			inventory = data.inventory,
			usedSlots = #data.inventory,
			maxSlots = GameConfig.BASE_INVENTORY_SLOTS + ((data.upgrades.warehouse or 0) * 20),
		})
	end

	-- Show seed shop data
	-- Seed shop populated via UI panels

	-- Intro sequence on first login
	if isFirstLogin then
		isFirstLogin = false
		if data.tutorialStep and data.tutorialStep <= 1 then
			CameraController.playIntroSequence()
		end
	end

	-- Request full shop info
	task.spawn(function()
		shopInfo = RemoteHelper.invoke("GetShopInfo")
	end)
end)

-- Money updates
RemoteHelper.onEvent("MoneyChanged", function(data)
	if playerData then
		playerData.money = data.money
		playerData.totalEarned = data.totalEarned
	end
	UIController.updateMoney(data.money)

	if data.change > 0 and data.source == "collect" then
		UIController.showNotification("+$" .. data.change .. " collected!", "success")
	end
end)

-- Inventory updates
RemoteHelper.onEvent("InventoryChanged", function(data)
	if playerData then
		playerData.inventory = data.inventory
	end
	UIController.updateInventory(data)
end)

-- Plant updates
RemoteHelper.onEvent("PlantUpdated", function(data)
	if data.action == "planted" then
		UIController.showNotification("Seed planted!", "success")
	elseif data.action == "watered" then
		if data.plant then
			-- Play water effect at planter position (approximate)
			EffectsManager.playWaterEffect(Vector3.new(0, 2, 0))
		end
	elseif data.action == "growth" then
		-- Update plant displays
		UIController.updatePlants(data.plants)
	end
end)

-- Harvest
RemoteHelper.onEvent("PlantHarvested", function(data)
	EffectsManager.playQualityReveal(data.quality)
	EffectsManager.playHarvestEffect(Vector3.new(0, 2, 0), data.quality)
	UIController.showNotification(
		"Harvested " .. (data.seedId or "herb") .. " - " .. data.quality .. " Rank!",
		"success"
	)
end)

-- Shelf updates
RemoteHelper.onEvent("ShelfUpdated", function(data)
	UIController.updateShelves(data)
end)

-- Product sold
RemoteHelper.onEvent("ProductSold", function(data)
	EffectsManager.playSaleEffect(Vector3.new(0, 3, 0), data.price)
	if playerData then
		playerData.pendingMoney = (playerData.pendingMoney or 0) + data.price
	end
end)

-- Upgrades
RemoteHelper.onEvent("UpgradeCompleted", function(data)
	EffectsManager.playUpgradeEffect(Vector3.new(0, 2, 0))
	UIController.showNotification(
		data.category .. " upgraded to Lv." .. data.level .. "!",
		"success"
	)
end)

-- Building upgrade
RemoteHelper.onEvent("BuildingUpgraded", function(data)
	EffectsManager.playBuildingUpgrade(Vector3.new(0, 2, 0))
	UIController.showNotification(
		"Building upgraded to " .. data.name .. "!",
		"success"
	)
	if playerData then
		playerData.shopLevel = data.level
		playerData.unlockedSeeds = data.unlockedSeeds
	end
end)

-- Processing
RemoteHelper.onEvent("ProcessingStarted", function(data)
	UIController.showNotification("Processing started: " .. (data.recipeName or "item"), "info")
end)

RemoteHelper.onEvent("ProcessingCompleted", function(data)
	EffectsManager.playUpgradeEffect(Vector3.new(0, 2, 0))
	UIController.showNotification("Processing complete!", "success")
end)

RemoteHelper.onEvent("RecipeDiscovered", function(data)
	UIController.showNotification("New recipe discovered: " .. (data.name or "???"), "info")
	EffectsManager.playSound("rankup")
end)

-- Brand
RemoteHelper.onEvent("BrandUpdated", function(data)
	UIController.showBrandPanel(data)
end)

RemoteHelper.onEvent("BrandRankUp", function(data)
	EffectsManager.playBrandRankUpEffect(data.rank)
	UIController.showNotification("Brand ranked up to " .. data.rank .. "!", "success")
end)

-- Events
RemoteHelper.onEvent("EventStarted", function(data)
	EffectsManager.playEventStartEffect()
	UIController.showNotification("Event started: " .. (data.name or "Event") .. "!", "success")
end)

RemoteHelper.onEvent("EventEnded", function(data)
	UIController.showNotification("Event ended!", "info")
end)

RemoteHelper.onEvent("EventResults", function(data)
	UIController.showNotification(
		"Event results: " .. (data.customersServed or 0) .. " customers served!",
		"success"
	)
end)

-- NPC visuals
RemoteHelper.onEvent("NPCSpawned", function(data)
	EffectsManager.playNPCSpawnEffect(Vector3.new(math.random(-5, 5), 0, 10))
end)

RemoteHelper.onEvent("NPCStateChanged", function(data)
	-- NPC state changes handled by 3D world visualization
	if data.disappointed then
		EffectsManager.createFloatingText(
			Vector3.new(math.random(-5, 5), 3, math.random(-5, 5)),
			"...",
			Color3.fromRGB(255, 100, 100)
		)
	end
end)

-- Staff
RemoteHelper.onEvent("StaffHired", function(data)
	UIController.showNotification("Hired " .. (data.role or "staff") .. "!", "success")
end)

RemoteHelper.onEvent("StaffFired", function(data)
	UIController.showNotification("Staff member fired.", "info")
end)

-- Tutorial
RemoteHelper.onEvent("TutorialStep", function(data)
	local step = GameConfig.TutorialSteps[data.step]
	if step then
		UIController.showTutorial(data.step, step.text)
	end
end)

RemoteHelper.onEvent("TutorialComplete", function()
	UIController.hideTutorial()
	UIController.showNotification("Tutorial complete! You're on your own now!", "success")
	EffectsManager.playSound("rankup")
end)

-- Monetization: full state sync
RemoteHelper.onEvent("MonetizationData", function(data)
	UIController.updateRobuxShop(data)
end)

-- Monetization: game pass granted
RemoteHelper.onEvent("GamePassGranted", function(data)
	EffectsManager.playSound("rankup")
	UIController.showNotification(data.name .. " activated!", "success")
	UIController.updateRobuxShop(nil)
end)

-- Monetization: product purchased
RemoteHelper.onEvent("ProductPurchased", function(data)
	EffectsManager.playUpgradeEffect(Vector3.new(0, 3, 0))
end)

-- Monetization: booster activated/expired
RemoteHelper.onEvent("BoosterActivated", function(data)
	if data.multiplier > 1 then
		UIController.showNotification("2x Booster ON!", "success")
		EffectsManager.playSound("rankup")
	end
	UIController.updateRobuxShop(nil)
end)

-- Monetization: premium status changed
RemoteHelper.onEvent("PremiumStatusChanged", function(data)
	if data.isPremium then
		UIController.showNotification("Premium bonus: +20% earnings!", "success")
	end
	UIController.updateRobuxShop(nil)
end)

-- Monetization: ad reward
RemoteHelper.onEvent("AdRewardGranted", function(data)
	EffectsManager.playSaleEffect(Vector3.new(0, 3, 0), data.amount)
end)

-- Monetization: show ad to client
RemoteHelper.onEvent("ShowAdToClient", function(data)
	-- Use AdService to show a rewarded video ad
	local success, err = pcall(function()
		local AdService = game:GetService("AdService")
		AdService:ShowVideoAd()
	end)

	if success then
		-- Ad shown; listen for completion
		local adConn
		local function onAdComplete(adDone)
			if adConn then adConn:Disconnect() end
			if adDone then
				-- Tell server we watched the ad
				RemoteHelper.fireServer("AdRewardGranted")
			else
				UIController.showNotification("Ad not completed.", "warning")
			end
		end

		pcall(function()
			local AdService = game:GetService("AdService")
			adConn = AdService.VideoAdClosed:Connect(function()
				onAdComplete(true)
			end)
			-- Timeout fallback: disconnect after 2 minutes
			task.delay(120, function()
				if adConn then adConn:Disconnect() end
			end)
		end)
	else
		-- AdService not available or ad failed to show
		UIController.showNotification("Ads not available right now.", "warning")
		warn("[Monetization] AdService error: " .. tostring(err))
	end
end)

-- Generic notifications
RemoteHelper.onEvent("NotifyClient", function(data)
	UIController.showNotification(data.text, data.type)
	if data.type == "error" then
		EffectsManager.playNotificationSound("error")
	end
end)

-- Client update loop
RunService.RenderStepped:Connect(function(dt)
	UIController.update(dt)
end)

-- Connect tutorial next button
task.spawn(function()
	task.wait(1)

	local tutorialBtn = UIController.getTutorialNextButton()
	if tutorialBtn then
		tutorialBtn.MouseButton1Click:Connect(function()
			RemoteHelper.fireServer("TutorialAdvance")
		end)
	end

	-- Connect brand name set button
	local setNameBtn = UIController.getBrandSetNameButton()
	if setNameBtn then
		setNameBtn.MouseButton1Click:Connect(function()
			local input = UIController.getBrandNameInput()
			if input and input.Text ~= "" then
				RemoteHelper.fireServer("SetBrandName", input.Text)
			end
		end)
	end

	-- Connect building upgrade button
	local buildingBtn = UIController.getBuildingUpgradeButton()
	if buildingBtn then
		buildingBtn.MouseButton1Click:Connect(function()
			if playerData then
				RemoteHelper.fireServer("UpgradeBuilding", playerData.shopLevel + 1)
			end
		end)
	end
end)

print("[MagicalHerb] Client initialized successfully!")
