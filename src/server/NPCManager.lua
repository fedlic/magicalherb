-- NPCManager: Manages NPC customer spawning, behavior AI, and purchasing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local NPCManager = {}

local DataManager = nil
local ShopManager = nil
local RemoteHelper = nil
local GameConfig = nil

-- Per-player active NPCs: { [userId] = { npcList = {}, spawnTimer = 0, eventMultiplier = 1 } }
local playerNPCs = {}

function NPCManager.init(dataManager, shopManager, remoteHelper)
	DataManager = dataManager
	ShopManager = shopManager
	RemoteHelper = remoteHelper
	GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
end

function NPCManager.initPlayer(player: Player)
	playerNPCs[player.UserId] = {
		npcList = {},
		spawnTimer = 0,
		eventMultiplier = 1,
		active = true,
	}
end

function NPCManager.stop(player: Player)
	if playerNPCs[player.UserId] then
		playerNPCs[player.UserId].active = false
	end
end

function NPCManager.cleanupPlayer(player: Player)
	playerNPCs[player.UserId] = nil
end

function NPCManager.getSpawnInterval(player: Player): number
	local data = DataManager.getPlayerData(player)
	if not data then
		return GameConfig.BASE_SPAWN_INTERVAL
	end

	local interval = GameConfig.BASE_SPAWN_INTERVAL
	-- Shop level bonus
	interval = interval - (data.shopLevel * 0.5)
	-- Brand rank bonus
	local rankIndex = GameConfig.getBrandRankIndex(data.brandRank)
	interval = interval - (rankIndex * 0.3)

	-- Event multiplier
	local npcData = playerNPCs[player.UserId]
	if npcData and npcData.eventMultiplier > 1 then
		interval = interval / npcData.eventMultiplier
	end

	return math.max(interval, 2)
end

function NPCManager.calculateSpawnWeights(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return { { npcType = GameConfig.NPCTypes[1], weight = 100 } }
	end

	local weights = {}
	local totalWeight = 0

	for _, npcType in ipairs(GameConfig.NPCTypes) do
		if GameConfig.meetsRankRequirement(data.brandRank, npcType.requiredBrandRank) then
			table.insert(weights, { npcType = npcType, weight = npcType.spawnWeight })
			totalWeight = totalWeight + npcType.spawnWeight
		end
	end

	-- Normalize
	for _, w in ipairs(weights) do
		w.normalizedWeight = w.weight / totalWeight
	end

	return weights
end

function NPCManager.selectNPCType(player: Player)
	local weights = NPCManager.calculateSpawnWeights(player)
	local roll = math.random()
	local cumulative = 0

	for _, w in ipairs(weights) do
		cumulative = cumulative + w.normalizedWeight
		if roll <= cumulative then
			return w.npcType
		end
	end

	return GameConfig.NPCTypes[1]
end

function NPCManager.spawnCustomer(player: Player)
	local npcData = playerNPCs[player.UserId]
	if not npcData or not npcData.active then
		return nil
	end

	-- Check if there are products to buy
	local available = ShopManager.getAvailableProducts(player)
	if #available == 0 then
		return nil
	end

	local npcType = NPCManager.selectNPCType(player)

	local npc = {
		id = HttpService:GenerateGUID(false),
		type = npcType.id,
		displayName = npcType.displayName,
		state = "entering",
		stateTimer = 0,
		targetShelf = nil,
		selectedProduct = nil,
		createdAt = os.time(),
	}

	table.insert(npcData.npcList, npc)

	RemoteHelper.fireClient("NPCSpawned", player, {
		id = npc.id,
		type = npc.type,
		displayName = npc.displayName,
	})

	return npc
end

function NPCManager.updateNPCs(dt: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local npcData = playerNPCs[player.UserId]
		if npcData and npcData.active then
			-- Spawn timer
			npcData.spawnTimer = npcData.spawnTimer + dt
			local interval = NPCManager.getSpawnInterval(player)
			if npcData.spawnTimer >= interval then
				npcData.spawnTimer = 0
				NPCManager.spawnCustomer(player)
			end

			-- Update each NPC's state machine
			local toRemove = {}
			for i, npc in ipairs(npcData.npcList) do
				npc.stateTimer = npc.stateTimer + dt
				NPCManager._updateNPCState(player, npc, i, toRemove)
			end

			-- Remove despawned NPCs (reverse order)
			table.sort(toRemove, function(a, b) return a > b end)
			for _, idx in ipairs(toRemove) do
				local npc = npcData.npcList[idx]
				if npc then
					RemoteHelper.fireClient("NPCLeft", player, { id = npc.id })
				end
				table.remove(npcData.npcList, idx)
			end
		end
	end
end

function NPCManager._updateNPCState(player: Player, npc, npcIndex: number, toRemove)
	if npc.state == "entering" then
		if npc.stateTimer >= GameConfig.NPC_ENTER_TIME then
			npc.state = "browsing"
			npc.stateTimer = 0
			RemoteHelper.fireClient("NPCStateChanged", player, {
				id = npc.id,
				state = "browsing",
			})
		end

	elseif npc.state == "browsing" then
		if npc.stateTimer >= GameConfig.NPC_BROWSE_TIME then
			-- Try to find a product to buy
			local npcType = GameConfig.getNPCTypeById(npc.type)
			local available = ShopManager.getAvailableProducts(player, npcType and npcType.minQuality or "C")

			if #available > 0 then
				-- Pick a random product
				local pick = available[math.random(1, #available)]
				npc.selectedProduct = pick
				npc.targetShelf = pick.shelfId
				npc.state = "selecting"
				npc.stateTimer = 0
				RemoteHelper.fireClient("NPCStateChanged", player, {
					id = npc.id,
					state = "selecting",
					targetShelf = pick.shelfId,
				})
			else
				-- Nothing to buy, leave disappointed
				npc.state = "leaving"
				npc.stateTimer = 0
				RemoteHelper.fireClient("NPCStateChanged", player, {
					id = npc.id,
					state = "leaving",
					disappointed = true,
				})
			end
		end

	elseif npc.state == "selecting" then
		if npc.stateTimer >= GameConfig.NPC_SELECT_TIME then
			-- Check queue length
			local npcData = playerNPCs[player.UserId]
			local queueCount = 0
			if npcData then
				for _, other in ipairs(npcData.npcList) do
					if other.state == "paying" then
						queueCount = queueCount + 1
					end
				end
			end

			if queueCount >= GameConfig.NPC_MAX_QUEUE and math.random() < GameConfig.NPC_LEAVE_CHANCE then
				-- Queue too long, leave
				npc.state = "leaving"
				npc.stateTimer = 0
				RemoteHelper.fireClient("NPCStateChanged", player, {
					id = npc.id,
					state = "leaving",
					disappointed = true,
				})
			else
				npc.state = "paying"
				npc.stateTimer = 0
				RemoteHelper.fireClient("NPCStateChanged", player, {
					id = npc.id,
					state = "paying",
				})
			end
		end

	elseif npc.state == "paying" then
		if npc.stateTimer >= GameConfig.NPC_PAY_TIME then
			-- Process purchase
			if npc.selectedProduct then
				ShopManager.sellProduct(
					player,
					npc.selectedProduct.shelfId,
					npc.selectedProduct.productIndex,
					npc.type
				)
			end
			npc.state = "leaving"
			npc.stateTimer = 0
			RemoteHelper.fireClient("NPCStateChanged", player, {
				id = npc.id,
				state = "leaving",
				purchased = true,
			})
		end

	elseif npc.state == "leaving" then
		if npc.stateTimer >= GameConfig.NPC_LEAVE_TIME then
			table.insert(toRemove, npcIndex)
		end
	end
end

function NPCManager.getActiveNPCs(player: Player)
	local npcData = playerNPCs[player.UserId]
	if not npcData then
		return {}
	end
	return npcData.npcList
end

function NPCManager.setEventMultiplier(player: Player, multiplier: number)
	local npcData = playerNPCs[player.UserId]
	if npcData then
		npcData.eventMultiplier = multiplier
	end
end

function NPCManager.getCustomerCount(player: Player): number
	local npcData = playerNPCs[player.UserId]
	if not npcData then
		return 0
	end
	return #npcData.npcList
end

return NPCManager
