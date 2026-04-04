--[[
	ProcessingManager.lua
	Manages the crafting/processing system for Magical Herb Tycoon.
	Dependencies: GameConfig, RemoteHelper, DataManager, InventoryManager
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))
local DataManager = require(Server:WaitForChild("DataManager"))
local InventoryManager = require(Server:WaitForChild("InventoryManager"))

-- Lazy-load UpgradeManager to avoid circular dependency
local UpgradeManager = nil
local function getUpgradeManager()
	if not UpgradeManager then
		UpgradeManager = require(Server:WaitForChild("UpgradeManager"))
	end
	return UpgradeManager
end

local ProcessingManager = {}

-- Active processing slots indexed by player userId
-- Structure: { [userId] = { [slotIndex] = { recipeId, startedAt, duration, quality } } }
local activeProcessing: { [number]: { [number]: any } } = {}

-- Build recipe lookup table by id
local recipeLookup: { [string]: any } = {}
for _, recipe in ipairs(GameConfig.Recipes or {}) do
	recipeLookup[recipe.id] = recipe
end

local function getRecipeById(recipeId: string)
	return recipeLookup[recipeId]
end

local function getPlayerData(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end
	if not data.processingSlots then
		data.processingSlots = {}
	end
	if not data.unlockedRecipes then
		data.unlockedRecipes = {}
	end
	return data
end

------------------------------------------------------------------------
-- Ingredient matching helpers
-- GameConfig ingredients use: { type = "any_herb"|"specific", seedId?, quantity }
-- Inventory items have productId like "raw_chill_mint", quality, quantity
------------------------------------------------------------------------

-- Check if a single ingredient requirement is met
local function hasIngredient(player: Player, ingredient): boolean
	local qty = ingredient.quantity or 1
	if ingredient.type == "any_herb" then
		-- Any raw_* item counts
		local inventory = InventoryManager.getInventory(player)
		local total = 0
		for _, item in ipairs(inventory) do
			if string.find(item.productId, "^raw_") then
				total = total + item.quantity
			end
		end
		return total >= qty
	elseif ingredient.type == "specific" then
		local itemId = "raw_" .. ingredient.seedId
		return InventoryManager.hasItem(player, itemId, nil, qty)
	end
	return false
end

-- Remove ingredient items from inventory
local function consumeIngredient(player: Player, ingredient): boolean
	local qty = ingredient.quantity or 1
	if ingredient.type == "any_herb" then
		-- Remove from first available raw_* items
		local inventory = InventoryManager.getInventory(player)
		local remaining = qty
		for _, item in ipairs(inventory) do
			if string.find(item.productId, "^raw_") and remaining > 0 then
				local removeAmt = math.min(remaining, item.quantity)
				if InventoryManager.removeItem(player, item.productId, item.quality, removeAmt) then
					remaining = remaining - removeAmt
				end
			end
		end
		return remaining <= 0
	elseif ingredient.type == "specific" then
		local itemId = "raw_" .. ingredient.seedId
		return InventoryManager.removeItem(player, itemId, nil, qty)
	end
	return false
end

-- Determines the quality of the output based on the best ingredient quality.
local function determineBestQuality(player: Player, recipe: any): string
	local qualityOrder = { C = 1, B = 2, A = 3, S = 4, SS = 5 }
	local bestQualityValue = 0

	local inventory = InventoryManager.getInventory(player)
	for _, ingredient in ipairs(recipe.ingredients or {}) do
		if ingredient.type == "specific" then
			local itemId = "raw_" .. ingredient.seedId
			for _, item in ipairs(inventory) do
				if item.productId == itemId then
					local val = qualityOrder[item.quality or "C"] or 1
					if val > bestQualityValue then
						bestQualityValue = val
					end
				end
			end
		elseif ingredient.type == "any_herb" then
			for _, item in ipairs(inventory) do
				if string.find(item.productId, "^raw_") then
					local val = qualityOrder[item.quality or "C"] or 1
					if val > bestQualityValue then
						bestQualityValue = val
					end
				end
			end
		end
	end

	-- Reverse lookup
	for name, val in pairs(qualityOrder) do
		if val == bestQualityValue then
			return name
		end
	end

	return "C"
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Returns the max number of processing tables the player can use.
-- 0 if shopLevel < 3, otherwise 1 + processingTable upgrade level.
function ProcessingManager.getMaxTables(player: Player): number
	local data = getPlayerData(player)
	if not data then
		return 0
	end
	local shopLevel = data.shopLevel or 1
	if shopLevel < 3 then
		return 0
	end
	local upgradeLevel = getUpgradeManager().getUpgradeLevel(player, "processingTable")
	return 1 + upgradeLevel
end

-- Checks if a recipe is unlocked for the player.
function ProcessingManager.isRecipeUnlocked(player: Player, recipeId: string): boolean
	local data = getPlayerData(player)
	if not data then
		return false
	end
	return data.unlockedRecipes[recipeId] == true
end

-- Discovers (unlocks) a new recipe for the player.
function ProcessingManager.discoverRecipe(player: Player, recipeId: string)
	local data = getPlayerData(player)
	if not data then
		return
	end
	if data.unlockedRecipes[recipeId] then
		return
	end

	data.unlockedRecipes[recipeId] = true
	DataManager.savePlayerData(player)

	local recipe = getRecipeById(recipeId)
	RemoteHelper.fireClient(player, "RecipeDiscovered", {
		recipeId = recipeId,
		name = recipe and recipe.name or recipeId,
	})
end

-- Returns list of recipes the player can currently make (has ingredients).
function ProcessingManager.getAvailableRecipes(player: Player): { any }
	local data = getPlayerData(player)
	if not data then
		return {}
	end

	local available = {}

	for _, recipe in ipairs(GameConfig.Recipes or {}) do
		if data.unlockedRecipes[recipe.id] then
			local canMake = true
			for _, ingredient in ipairs(recipe.ingredients or {}) do
				if not hasIngredient(player, ingredient) then
					canMake = false
					break
				end
			end
			table.insert(available, {
				recipeId = recipe.id,
				name = recipe.name,
				canMake = canMake,
				craftTime = recipe.craftTime or 30,
				ingredients = recipe.ingredients,
			})
		end
	end

	return available
end

-- Finds the first available processing slot for the player.
local function findAvailableSlot(player: Player): number?
	local userId = player.UserId
	local maxTables = ProcessingManager.getMaxTables(player)
	local slots = activeProcessing[userId] or {}

	for i = 1, maxTables do
		if not slots[i] then
			return i
		end
	end

	return nil
end

-- Starts a processing job for the given recipe.
function ProcessingManager.startProcessing(player: Player, recipeId: string): (boolean, string?)
	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	local maxTables = ProcessingManager.getMaxTables(player)
	if maxTables <= 0 then
		return false, "NoProcessingTable"
	end

	local recipe = getRecipeById(recipeId)
	if not recipe then
		return false, "InvalidRecipe"
	end

	-- Check ingredients regardless of unlock status (auto-discover on valid combo)
	for _, ingredient in ipairs(recipe.ingredients or {}) do
		if not hasIngredient(player, ingredient) then
			return false, "MissingIngredients"
		end
	end

	-- Find an available slot
	local slotIndex = findAvailableSlot(player)
	if not slotIndex then
		return false, "AllTablesBusy"
	end

	-- Determine quality before removing ingredients
	local quality = determineBestQuality(player, recipe)

	-- Remove ingredients from inventory
	for _, ingredient in ipairs(recipe.ingredients or {}) do
		if not consumeIngredient(player, ingredient) then
			return false, "RemoveIngredientFailed"
		end
	end

	-- Auto-discover recipe if this is the first time
	if not ProcessingManager.isRecipeUnlocked(player, recipeId) then
		ProcessingManager.discoverRecipe(player, recipeId)
	end

	-- Calculate actual craft time with upgrade bonus
	local baseCraftTime = recipe.craftTime or 30
	local craftSpeedBonus = getUpgradeManager().getEffectValue(
		"processingTable",
		getUpgradeManager().getUpgradeLevel(player, "processingTable")
	)
	local actualTime = baseCraftTime / (1 + craftSpeedBonus)

	-- Create processing slot entry
	local userId = player.UserId
	if not activeProcessing[userId] then
		activeProcessing[userId] = {}
	end

	local now = os.time()
	activeProcessing[userId][slotIndex] = {
		recipeId = recipeId,
		startedAt = now,
		duration = actualTime,
		quality = quality,
		slotIndex = slotIndex,
	}

	-- Persist to player data
	data.processingSlots[slotIndex] = {
		recipeId = recipeId,
		startedAt = now,
		quality = quality,
		slotIndex = slotIndex,
	}
	DataManager.savePlayerData(player)

	RemoteHelper.fireClient(player, "ProcessingStarted", {
		recipeId = recipeId,
		slotIndex = slotIndex,
		duration = actualTime,
		quality = quality,
	})

	return true, nil
end

-- Completes a processing job for a specific slot. Creates the output product.
function ProcessingManager.completeProcessing(player: Player, slotIndex: number): (boolean, string?)
	local userId = player.UserId
	local slots = activeProcessing[userId]
	if not slots or not slots[slotIndex] then
		return false, "NoActiveProcessing"
	end

	local slot = slots[slotIndex]
	local recipe = getRecipeById(slot.recipeId)
	if not recipe then
		slots[slotIndex] = nil
		return false, "RecipeNotFound"
	end

	-- Create the finished product in inventory
	local outputId = "processed_" .. slot.recipeId

	local added = InventoryManager.addItem(player, outputId, slot.quality, 1)
	if not added then
		return false, "InventoryFull"
	end

	-- Clear slot
	slots[slotIndex] = nil

	-- Clear from persistent data
	local data = getPlayerData(player)
	if data and data.processingSlots then
		data.processingSlots[slotIndex] = nil
		DataManager.savePlayerData(player)
	end

	RemoteHelper.fireClient(player, "ProcessingCompleted", {
		recipeId = slot.recipeId,
		slotIndex = slotIndex,
		outputId = outputId,
		quality = slot.quality,
	})

	return true, nil
end

-- Player picks up a finished item from a specific table.
function ProcessingManager.collectProcessed(player: Player, tableId: number): (boolean, string?)
	return ProcessingManager.completeProcessing(player, tableId)
end

-- Returns the processing status for all slots.
function ProcessingManager.getProcessingStatus(player: Player): { any }
	local userId = player.UserId
	local slots = activeProcessing[userId] or {}
	local maxTables = ProcessingManager.getMaxTables(player)
	local status = {}

	for i = 1, maxTables do
		local slot = slots[i]
		if slot then
			local elapsed = os.time() - slot.startedAt
			local remaining = math.max(0, slot.duration - elapsed)
			local isComplete = remaining <= 0
			table.insert(status, {
				slotIndex = i,
				recipeId = slot.recipeId,
				quality = slot.quality,
				elapsed = elapsed,
				remaining = remaining,
				isComplete = isComplete,
			})
		else
			table.insert(status, {
				slotIndex = i,
				empty = true,
			})
		end
	end

	return status
end

-- Called each tick. Checks all active processing slots and auto-completes when done.
function ProcessingManager.updateProcessing(dt: number)
	local Players = game:GetService("Players")

	for userId, slots in pairs(activeProcessing) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			for slotIndex, slot in pairs(slots) do
				local elapsed = os.time() - slot.startedAt
				if elapsed >= slot.duration then
					ProcessingManager.completeProcessing(player, slotIndex)
				end
			end
		else
			-- Player left, clean up
			activeProcessing[userId] = nil
		end
	end
end

return ProcessingManager
