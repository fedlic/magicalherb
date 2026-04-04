-- DataManager: Handles player data persistence using Roblox DataStoreService

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}

local dataStore = DataStoreService:GetDataStore("MagicalHerbTycoon_v1")
local playerDataCache = {}
local autoSaveRunning = false

local DEFAULT_DATA = {
	money = 0,
	totalEarned = 0,
	shopLevel = 1,
	brandName = "",
	brandRank = "Unknown",
	brandScore = 0,
	inventory = {},
	upgrades = {
		planter = 0,
		processingTable = 0,
		shelf = 0,
		register = 0,
		warehouse = 0,
		sprinkler = 0,
		lighting = 0,
	},
	unlockedSeeds = { "chill_mint", "solar_leaf", "mystic_basil" },
	unlockedRecipes = {},
	staff = {},
	plants = {},
	shelves = {},
	stats = {
		totalCustomers = 0,
		totalHarvests = 0,
		eventsHosted = 0,
		totalProductsSold = 0,
		sRankHarvests = 0,
		ssRankHarvests = 0,
	},
	decorations = {},
	tutorialStep = 1,
	lastLoginAt = 0,
	processingSlots = {},
	pendingMoney = 0,
}

local function deepCopy(original)
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = deepCopy(value)
	end
	return copy
end

local function reconcileData(saved, default)
	local data = deepCopy(saved)
	for key, defaultValue in pairs(default) do
		if data[key] == nil then
			data[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(data[key]) == "table" then
			-- Only reconcile dict-style tables, not arrays
			if #defaultValue == 0 and #data[key] == 0 then
				for subKey, subDefault in pairs(defaultValue) do
					if data[key][subKey] == nil then
						data[key][subKey] = deepCopy(subDefault)
					end
				end
			end
		end
	end
	return data
end

function DataManager.loadPlayerData(player: Player)
	local key = "PlayerData_" .. player.UserId
	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	local data
	if success and result then
		data = reconcileData(result, DEFAULT_DATA)
	else
		if not success then
			warn("[DataManager] Failed to load data for " .. player.Name .. ": " .. tostring(result))
		end
		data = deepCopy(DEFAULT_DATA)
	end

	data.lastLoginAt = os.time()
	playerDataCache[player.UserId] = data
	return data
end

function DataManager.savePlayerData(player: Player): boolean
	local data = playerDataCache[player.UserId]
	if not data then
		return false
	end

	local key = "PlayerData_" .. player.UserId
	local success, err = pcall(function()
		dataStore:SetAsync(key, data)
	end)

	if not success then
		warn("[DataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
	return success
end

function DataManager.getPlayerData(player: Player)
	return playerDataCache[player.UserId]
end

function DataManager.updatePlayerData(player: Player, key: string, value: any)
	local data = playerDataCache[player.UserId]
	if data then
		data[key] = value
	end
end

function DataManager.updateNestedData(player: Player, path: string, value: any)
	local data = playerDataCache[player.UserId]
	if not data then
		return
	end

	local keys = string.split(path, ".")
	local current = data
	for i = 1, #keys - 1 do
		current = current[keys[i]]
		if not current then
			return
		end
	end
	current[keys[#keys]] = value
end

function DataManager.startAutoSave()
	if autoSaveRunning then
		return
	end
	autoSaveRunning = true

	task.spawn(function()
		while autoSaveRunning do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				if playerDataCache[player.UserId] then
					DataManager.savePlayerData(player)
				end
			end
		end
	end)
end

function DataManager.stopAutoSave()
	autoSaveRunning = false
end

function DataManager.onPlayerLeaving(player: Player)
	if playerDataCache[player.UserId] then
		DataManager.savePlayerData(player)
		playerDataCache[player.UserId] = nil
	end
end

function DataManager.getDefaultData()
	return deepCopy(DEFAULT_DATA)
end

return DataManager
