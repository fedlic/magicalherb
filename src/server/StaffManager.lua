--[[
	StaffManager.lua
	Manages NPC staff hiring, firing, and their automated tasks for Magical Herb Tycoon.
	Dependencies: GameConfig, RemoteHelper, DataManager, EconomyManager, InventoryManager, ShopManager
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))
local DataManager = require(Server:WaitForChild("DataManager"))
local EconomyManager = require(Server:WaitForChild("EconomyManager"))
local InventoryManager = require(Server:WaitForChild("InventoryManager"))
local ShopManager = require(Server:WaitForChild("ShopManager"))
local PlantManager = require(Server:WaitForChild("PlantManager"))

local StaffManager = {}

-- Staff type definitions
local STAFF_TYPES = {
	Cashier = {
		cost = 500,
		salary = 5, -- per minute
		taskInterval = 30,
		description = "Auto-collects register money",
	},
	Waterer = {
		cost = 300,
		salary = 3,
		taskInterval = 15,
		description = "Auto-waters plants (no quality bonus)",
	},
	Harvester = {
		cost = 800,
		salary = 8,
		taskInterval = 20,
		description = "Auto-harvests ready plants (50% quality penalty)",
	},
	Stocker = {
		cost = 600,
		salary = 5,
		taskInterval = 25,
		description = "Auto-stocks shelves from inventory",
	},
}

-- Track last task execution time per staff member: { [userId] = { [staffId] = lastTaskTime } }
local staffTimers: { [number]: { [string]: number } } = {}

-- Track last salary processing time per player
local salaryTimers: { [number]: number } = {}

local function getPlayerData(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end
	if not data.staff then
		data.staff = {}
	end
	return data
end

-- Generates a unique staff ID.
local function generateStaffId(staffList: { any }): string
	local maxIndex = 0
	for _, staff in ipairs(staffList) do
		local num = tonumber(string.match(staff.id, "staff_(%d+)"))
		if num and num > maxIndex then
			maxIndex = num
		end
	end
	return "staff_" .. tostring(maxIndex + 1)
end

-- Returns the max number of staff allowed based on building config.
function StaffManager.getMaxStaff(player: Player): number
	local data = getPlayerData(player)
	if not data then
		return 0
	end

	local shopLevel = data.shopLevel or 1

	-- Building config determines max staff
	-- Default: shopLevel - 1 staff slots (min 0)
	local buildingConfig = GameConfig.Buildings and GameConfig.Buildings[shopLevel]
	if buildingConfig and buildingConfig.maxStaff then
		return buildingConfig.maxStaff
	end

	-- Fallback formula: starts at 0 for level 1, increases by 1 per level
	return math.max(0, shopLevel - 1)
end

-- Checks if the player already has a staff member with the given role.
local function hasRoleDuplicate(staffList: { any }, role: string): boolean
	for _, staff in ipairs(staffList) do
		if staff.role == role then
			return true
		end
	end
	return false
end

-- Hires a new staff member.
function StaffManager.hireStaff(player: Player, staffType: string): (boolean, string?)
	local config = STAFF_TYPES[staffType]
	if not config then
		return false, "InvalidStaffType"
	end

	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	-- Check staff limit
	local maxStaff = StaffManager.getMaxStaff(player)
	if #data.staff >= maxStaff then
		return false, "StaffLimitReached"
	end

	-- Check for duplicate role
	if hasRoleDuplicate(data.staff, staffType) then
		return false, "DuplicateRole"
	end

	-- Check money
	local money = EconomyManager.getMoney(player)
	if money < config.cost then
		return false, "NotEnoughMoney"
	end

	-- Deduct hiring cost
	local deducted = EconomyManager.removeMoney(player, config.cost, "staff_hire")
	if not deducted then
		return false, "DeductFailed"
	end

	-- Create staff entry
	local staffId = generateStaffId(data.staff)
	local newStaff = {
		id = staffId,
		role = staffType,
		hiredAt = os.time(),
	}
	table.insert(data.staff, newStaff)
	DataManager.savePlayerData(player)

	-- Initialize task timer
	local userId = player.UserId
	if not staffTimers[userId] then
		staffTimers[userId] = {}
	end
	staffTimers[userId][staffId] = os.clock()

	-- Initialize salary timer if not set
	if not salaryTimers[userId] then
		salaryTimers[userId] = os.clock()
	end

	RemoteHelper.fireClient(player, "StaffHired", {
		staffId = staffId,
		role = staffType,
		cost = config.cost,
		salary = config.salary,
	})

	return true, nil
end

-- Fires (removes) a staff member.
function StaffManager.fireStaff(player: Player, staffId: string): (boolean, string?)
	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	local foundIndex = nil
	local foundStaff = nil
	for i, staff in ipairs(data.staff) do
		if staff.id == staffId then
			foundIndex = i
			foundStaff = staff
			break
		end
	end

	if not foundIndex then
		return false, "StaffNotFound"
	end

	table.remove(data.staff, foundIndex)
	DataManager.savePlayerData(player)

	-- Clean up timer
	local userId = player.UserId
	if staffTimers[userId] then
		staffTimers[userId][staffId] = nil
	end

	RemoteHelper.fireClient(player, "StaffFired", {
		staffId = staffId,
		role = foundStaff.role,
	})

	return true, nil
end

-- Returns the list of staff for a player.
function StaffManager.getStaff(player: Player): { any }
	local data = getPlayerData(player)
	if not data then
		return {}
	end
	return data.staff
end

-- Performs the automated task for a Cashier: collect register money.
local function doCashierTask(player: Player)
	local collected = EconomyManager.collectPendingMoney(player)
	if collected > 0 then
		RemoteHelper.fireClient(player, "StaffAction", {
			role = "Cashier",
			action = "CollectRegister",
		})
	end
end

-- Performs the automated task for a Waterer: water all plants (no quality bonus).
local function doWatererTask(player: Player)
	PlantManager.autoWater(player)
	RemoteHelper.fireClient(player, "StaffAction", {
		role = "Waterer",
		action = "WaterPlants",
	})
end

-- Performs the automated task for a Harvester: harvest ready plants (50% quality penalty).
local function doHarvesterTask(player: Player)
	PlantManager.autoHarvest(player)
	RemoteHelper.fireClient(player, "StaffAction", {
		role = "Harvester",
		action = "HarvestPlants",
	})
end

-- Performs the automated task for a Stocker: stock shelves from inventory.
local function doStockerTask(player: Player)
	local stocked = ShopManager.autoStockShelves(player)
	if stocked and stocked > 0 then
		RemoteHelper.fireClient(player, "StaffAction", {
			role = "Stocker",
			action = "StockShelves",
			count = stocked,
		})
	end
end

local TASK_FUNCTIONS = {
	Cashier = doCashierTask,
	Waterer = doWatererTask,
	Harvester = doHarvesterTask,
	Stocker = doStockerTask,
}

-- Called each tick. Performs automated tasks for all staff members.
function StaffManager.updateStaff(dt: number)
	local Players = game:GetService("Players")

	for _, player in ipairs(Players:GetPlayers()) do
		local data = getPlayerData(player)
		if data and #data.staff > 0 then
			local userId = player.UserId
			if not staffTimers[userId] then
				staffTimers[userId] = {}
			end

			local now = os.clock()

			for _, staff in ipairs(data.staff) do
				local config = STAFF_TYPES[staff.role]
				if config then
					local lastTask = staffTimers[userId][staff.id] or 0
					local elapsed = now - lastTask

					if elapsed >= config.taskInterval then
						staffTimers[userId][staff.id] = now

						local taskFn = TASK_FUNCTIONS[staff.role]
						if taskFn then
							local ok, err = pcall(taskFn, player)
							if not ok then
								warn("[StaffManager] Task error for " .. staff.role .. ": " .. tostring(err))
							end
						end
					end
				end
			end
		end
	end
end

-- Deducts salary costs per minute for all staff. Fires staff if player cannot afford.
function StaffManager.processSalaries(player: Player)
	local data = getPlayerData(player)
	if not data or #data.staff == 0 then
		return
	end

	local userId = player.UserId
	local now = os.clock()
	local lastSalary = salaryTimers[userId] or now
	local elapsed = now - lastSalary

	-- Process salaries every 60 seconds
	if elapsed < 60 then
		return
	end

	salaryTimers[userId] = now
	local minutesPassed = math.floor(elapsed / 60)

	-- Calculate total salary
	local totalSalary = 0
	for _, staff in ipairs(data.staff) do
		local config = STAFF_TYPES[staff.role]
		if config then
			totalSalary = totalSalary + (config.salary * minutesPassed)
		end
	end

	if totalSalary <= 0 then
		return
	end

	local money = EconomyManager.getMoney(player)
	if money >= totalSalary then
		EconomyManager.removeMoney(player, totalSalary, "salary")
	else
		-- Cannot afford: fire staff one by one from the most expensive
		-- Sort by salary descending
		local staffByExpense = {}
		for i, staff in ipairs(data.staff) do
			local config = STAFF_TYPES[staff.role]
			table.insert(staffByExpense, {
				index = i,
				staff = staff,
				salary = config and config.salary or 0,
			})
		end
		table.sort(staffByExpense, function(a, b)
			return a.salary > b.salary
		end)

		-- Fire staff until affordable or none left
		for _, entry in ipairs(staffByExpense) do
			if money >= totalSalary then
				break
			end

			local config = STAFF_TYPES[entry.staff.role]
			local staffSalary = config and (config.salary * minutesPassed) or 0

			StaffManager.fireStaff(player, entry.staff.id)
			totalSalary = totalSalary - staffSalary
		end

		-- Deduct remaining affordable salary
		if totalSalary > 0 and money > 0 then
			EconomyManager.removeMoney(player, math.min(totalSalary, money), "salary")
		end
	end
end

return StaffManager
