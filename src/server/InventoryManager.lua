-- InventoryManager: Server-side inventory management

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryManager = {}

local DataManager = nil
local RemoteHelper = nil
local GameConfig = nil

function InventoryManager.init(dataManager, remoteHelper)
	DataManager = dataManager
	RemoteHelper = remoteHelper
	GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
end

function InventoryManager.addItem(player: Player, productId: string, quality: string, quantity: number): boolean
	local data = DataManager.getPlayerData(player)
	if not data then
		return false
	end

	if quantity <= 0 then
		return false
	end

	-- Try to stack with existing item
	for _, item in ipairs(data.inventory) do
		if item.productId == productId and item.quality == quality then
			local canAdd = math.min(quantity, GameConfig.MAX_STACK - item.quantity)
			if canAdd > 0 then
				item.quantity = item.quantity + canAdd
				quantity = quantity - canAdd
			end
			if quantity <= 0 then
				InventoryManager._notifyChange(player)
				return true
			end
		end
	end

	-- Need new slot(s)
	while quantity > 0 do
		if not InventoryManager.hasSpace(player) then
			InventoryManager._notifyChange(player)
			return false
		end

		local addAmount = math.min(quantity, GameConfig.MAX_STACK)
		table.insert(data.inventory, {
			productId = productId,
			quality = quality,
			quantity = addAmount,
		})
		quantity = quantity - addAmount
	end

	InventoryManager._notifyChange(player)
	return true
end

function InventoryManager.removeItem(player: Player, productId: string, quality: string?, quantity: number): boolean
	local data = DataManager.getPlayerData(player)
	if not data then
		return false
	end

	if not InventoryManager.hasItem(player, productId, quality, quantity) then
		return false
	end

	local remaining = quantity
	local toRemove = {}

	for i, item in ipairs(data.inventory) do
		if item.productId == productId and (quality == nil or item.quality == quality) and remaining > 0 then
			local removeAmount = math.min(remaining, item.quantity)
			item.quantity = item.quantity - removeAmount
			remaining = remaining - removeAmount
			if item.quantity <= 0 then
				table.insert(toRemove, 1, i)
			end
		end
	end

	for _, index in ipairs(toRemove) do
		table.remove(data.inventory, index)
	end

	InventoryManager._notifyChange(player)
	return true
end

function InventoryManager.hasItem(player: Player, productId: string, quality: string?, quantity: number?): boolean
	local count = InventoryManager.getItemCount(player, productId, quality)
	return count >= (quantity or 1)
end

function InventoryManager.getItemCount(player: Player, productId: string, quality: string?): number
	local data = DataManager.getPlayerData(player)
	if not data then
		return 0
	end

	local total = 0
	for _, item in ipairs(data.inventory) do
		if item.productId == productId then
			if quality == nil or item.quality == quality then
				total = total + item.quantity
			end
		end
	end
	return total
end

function InventoryManager.getInventory(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return {}
	end
	return data.inventory
end

function InventoryManager.getMaxSlots(player: Player): number
	local data = DataManager.getPlayerData(player)
	if not data then
		return GameConfig.BASE_INVENTORY_SLOTS
	end

	local warehouseLevel = data.upgrades.warehouse or 0
	return GameConfig.BASE_INVENTORY_SLOTS + (warehouseLevel * 20)
end

function InventoryManager.getUsedSlots(player: Player): number
	local data = DataManager.getPlayerData(player)
	if not data then
		return 0
	end
	return #data.inventory
end

function InventoryManager.hasSpace(player: Player): boolean
	return InventoryManager.getUsedSlots(player) < InventoryManager.getMaxSlots(player)
end

-- Find the best quality item of a given product
function InventoryManager.getBestQuality(player: Player, productId: string): string?
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end

	local bestIndex = 0
	local bestQuality = nil
	for _, item in ipairs(data.inventory) do
		if item.productId == productId then
			local idx = GameConfig.getQualityIndex(item.quality)
			if idx > bestIndex then
				bestIndex = idx
				bestQuality = item.quality
			end
		end
	end
	return bestQuality
end

-- Get first available item matching criteria
function InventoryManager.getFirstItem(player: Player, productId: string?, minQuality: string?)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end

	for _, item in ipairs(data.inventory) do
		local matchProduct = (productId == nil) or (item.productId == productId)
		local matchQuality = (minQuality == nil) or GameConfig.meetsMinQuality(item.quality, minQuality)
		if matchProduct and matchQuality and item.quantity > 0 then
			return item
		end
	end
	return nil
end

function InventoryManager._notifyChange(player: Player)
	local data = DataManager.getPlayerData(player)
	if data and RemoteHelper then
		RemoteHelper.fireClient("InventoryChanged", player, {
			inventory = data.inventory,
			usedSlots = #data.inventory,
			maxSlots = InventoryManager.getMaxSlots(player),
		})
	end
end

return InventoryManager
