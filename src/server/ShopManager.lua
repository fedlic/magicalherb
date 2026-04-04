-- ShopManager: Manages product display on shelves and selling

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopManager = {}

local DataManager = nil
local EconomyManager = nil
local InventoryManager = nil
local RemoteHelper = nil
local GameConfig = nil

function ShopManager.init(dataManager, economyManager, inventoryManager, remoteHelper)
	DataManager = dataManager
	EconomyManager = economyManager
	InventoryManager = inventoryManager
	RemoteHelper = remoteHelper
	GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
end

local function ensureShelves(data)
	local building = GameConfig.getBuildingByLevel(data.shopLevel)
	if not building then
		return
	end
	-- Ensure shelf data exists for all available shelves
	for i = 1, building.maxShelves do
		local shelfId = "shelf_" .. i
		local found = false
		for _, shelf in ipairs(data.shelves) do
			if shelf.id == shelfId then
				found = true
				break
			end
		end
		if not found then
			table.insert(data.shelves, {
				id = shelfId,
				products = {},
			})
		end
	end
end

function ShopManager.displayProduct(player: Player, shelfId: string, productId: string, quality: string, quantity: number): boolean
	local data = DataManager.getPlayerData(player)
	if not data then
		return false
	end

	ensureShelves(data)

	-- Find shelf
	local shelf = nil
	for _, s in ipairs(data.shelves) do
		if s.id == shelfId then
			shelf = s
			break
		end
	end
	if not shelf then
		return false
	end

	-- Check shelf capacity
	local shelfUpgrade = data.upgrades.shelf or 0
	local maxSlots = 3 + (shelfUpgrade * 2)
	if #shelf.products >= maxSlots then
		return false
	end

	-- Check inventory
	if not InventoryManager.hasItem(player, productId, quality, quantity) then
		return false
	end

	-- Move from inventory to shelf
	if not InventoryManager.removeItem(player, productId, quality, quantity) then
		return false
	end

	-- Add to shelf (stack if same product+quality exists)
	local stacked = false
	for _, p in ipairs(shelf.products) do
		if p.productId == productId and p.quality == quality then
			p.quantity = p.quantity + quantity
			stacked = true
			break
		end
	end
	if not stacked then
		table.insert(shelf.products, {
			productId = productId,
			quality = quality,
			quantity = quantity,
		})
	end

	RemoteHelper.fireClient("ShelfUpdated", player, {
		shelfId = shelfId,
		products = shelf.products,
	})

	return true
end

function ShopManager.removeFromShelf(player: Player, shelfId: string, productId: string, quality: string, quantity: number): boolean
	local data = DataManager.getPlayerData(player)
	if not data then
		return false
	end

	local shelf = nil
	for _, s in ipairs(data.shelves) do
		if s.id == shelfId then
			shelf = s
			break
		end
	end
	if not shelf then
		return false
	end

	-- Find product on shelf
	for i, p in ipairs(shelf.products) do
		if p.productId == productId and p.quality == quality then
			local removeAmount = math.min(quantity, p.quantity)
			if InventoryManager.addItem(player, productId, quality, removeAmount) then
				p.quantity = p.quantity - removeAmount
				if p.quantity <= 0 then
					table.remove(shelf.products, i)
				end
				RemoteHelper.fireClient("ShelfUpdated", player, {
					shelfId = shelfId,
					products = shelf.products,
				})
				return true
			end
			return false
		end
	end
	return false
end

function ShopManager.getShelfContents(player: Player, shelfId: string)
	local data = DataManager.getPlayerData(player)
	if not data then
		return {}
	end

	for _, shelf in ipairs(data.shelves) do
		if shelf.id == shelfId then
			return shelf.products
		end
	end
	return {}
end

function ShopManager.getAllShelves(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return {}
	end
	ensureShelves(data)
	return data.shelves
end

function ShopManager.getAvailableProducts(player: Player, minQuality: string?)
	local data = DataManager.getPlayerData(player)
	if not data then
		return {}
	end

	ensureShelves(data)

	local available = {}
	for _, shelf in ipairs(data.shelves) do
		for pIndex, product in ipairs(shelf.products) do
			if product.quantity > 0 then
				if not minQuality or GameConfig.meetsMinQuality(product.quality, minQuality) then
					table.insert(available, {
						shelfId = shelf.id,
						productIndex = pIndex,
						productId = product.productId,
						quality = product.quality,
						quantity = product.quantity,
					})
				end
			end
		end
	end
	return available
end

function ShopManager.calculatePrice(productId: string, quality: string, npcType: string?, brandRank: string?): number
	-- Get base price from seed
	local seedId = string.gsub(productId, "^raw_", "")
	seedId = string.gsub(seedId, "^trimmed_", "")
	seedId = string.gsub(seedId, "^processed_", "")

	local seed = GameConfig.getSeedById(seedId)
	local basePrice = seed and seed.basePrice or 25

	-- Check if it's a processed product (from recipe)
	local isProcessed = string.find(productId, "^processed_") ~= nil
	local isTrimmed = string.find(productId, "^trimmed_") ~= nil

	if isTrimmed then
		basePrice = basePrice * 1.5
	end

	-- For processed products, price is determined by recipe
	if isProcessed then
		local recipeId = string.gsub(productId, "^processed_", "")
		local recipe = GameConfig.getRecipeById(recipeId)
		if recipe then
			basePrice = basePrice * recipe.sellMultiplier
		end
	end

	-- Quality multiplier
	local qualityMult = GameConfig.getQualityMultiplier(quality)

	-- NPC type pay multiplier
	local npcMult = 1.0
	if npcType then
		local npc = GameConfig.getNPCTypeById(npcType)
		if npc then
			npcMult = npc.payMultiplier
		end
	end

	-- Brand bonus
	local brandBonus = 1.0
	if brandRank then
		brandBonus = GameConfig.BrandBonuses[brandRank] or 1.0
	end

	return math.floor(basePrice * qualityMult * npcMult * brandBonus)
end

function ShopManager.sellProduct(player: Player, shelfId: string, productIndex: number, npcType: string?): number
	local data = DataManager.getPlayerData(player)
	if not data then
		return 0
	end

	local shelf = nil
	for _, s in ipairs(data.shelves) do
		if s.id == shelfId then
			shelf = s
			break
		end
	end
	if not shelf or not shelf.products[productIndex] then
		return 0
	end

	local product = shelf.products[productIndex]
	if product.quantity <= 0 then
		return 0
	end

	-- Calculate price
	local price = ShopManager.calculatePrice(
		product.productId,
		product.quality,
		npcType,
		data.brandRank
	)

	-- Remove one from shelf
	product.quantity = product.quantity - 1
	if product.quantity <= 0 then
		table.remove(shelf.products, productIndex)
	end

	-- Add to pending money (register)
	EconomyManager.addPendingMoney(player, price)

	-- Update stats
	data.stats.totalProductsSold = (data.stats.totalProductsSold or 0) + 1
	data.stats.totalCustomers = (data.stats.totalCustomers or 0) + 1

	RemoteHelper.fireClient("ProductSold", player, {
		productId = product.productId,
		quality = product.quality,
		price = price,
		npcType = npcType or "regular",
	})

	RemoteHelper.fireClient("ShelfUpdated", player, {
		shelfId = shelfId,
		products = shelf.products,
	})

	return price
end

-- Auto-stock shelves from inventory (called by Stocker staff)
function ShopManager.autoStockShelves(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return
	end

	ensureShelves(data)

	local shelfUpgrade = data.upgrades.shelf or 0
	local maxSlots = 3 + (shelfUpgrade * 2)

	for _, shelf in ipairs(data.shelves) do
		if #shelf.products < maxSlots then
			-- Find first item in inventory to stock
			local inv = data.inventory
			if #inv > 0 then
				local item = inv[1]
				local moveQty = math.min(item.quantity, 5) -- Stock up to 5 at a time
				ShopManager.displayProduct(player, shelf.id, item.productId, item.quality, moveQty)
			end
		end
	end
end

return ShopManager
