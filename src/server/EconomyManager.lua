-- EconomyManager: Server-side money management (anti-cheat)

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyManager = {}

local DataManager = nil
local RemoteHelper = nil

function EconomyManager.init(dataManager, remoteHelper)
	DataManager = dataManager
	RemoteHelper = remoteHelper
end

function EconomyManager.addMoney(player: Player, amount: number, source: string?): number
	if amount <= 0 then
		return EconomyManager.getMoney(player)
	end

	local data = DataManager.getPlayerData(player)
	if not data then
		return 0
	end

	data.money = data.money + amount
	if source == "sale" or source == "collect" then
		data.totalEarned = data.totalEarned + amount
	end

	RemoteHelper.fireClient("MoneyChanged", player, {
		money = data.money,
		totalEarned = data.totalEarned,
		change = amount,
		source = source or "unknown",
	})

	return data.money
end

function EconomyManager.removeMoney(player: Player, amount: number, reason: string?): boolean
	if amount <= 0 then
		return true
	end

	local data = DataManager.getPlayerData(player)
	if not data then
		return false
	end

	if data.money < amount then
		return false
	end

	data.money = data.money - amount

	RemoteHelper.fireClient("MoneyChanged", player, {
		money = data.money,
		totalEarned = data.totalEarned,
		change = -amount,
		source = reason or "purchase",
	})

	return true
end

function EconomyManager.getMoney(player: Player): number
	local data = DataManager.getPlayerData(player)
	return data and data.money or 0
end

function EconomyManager.getTotalEarned(player: Player): number
	local data = DataManager.getPlayerData(player)
	return data and data.totalEarned or 0
end

function EconomyManager.addPendingMoney(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local data = DataManager.getPlayerData(player)
	if data then
		data.pendingMoney = (data.pendingMoney or 0) + amount
	end
end

function EconomyManager.collectPendingMoney(player: Player): number
	local data = DataManager.getPlayerData(player)
	if not data then
		return 0
	end

	local pending = data.pendingMoney or 0
	if pending <= 0 then
		return 0
	end

	data.pendingMoney = 0
	EconomyManager.addMoney(player, pending, "collect")
	return pending
end

function EconomyManager.getPendingMoney(player: Player): number
	local data = DataManager.getPlayerData(player)
	return data and (data.pendingMoney or 0) or 0
end

function EconomyManager.canAfford(player: Player, amount: number): boolean
	return EconomyManager.getMoney(player) >= amount
end

function EconomyManager.processStaffSalaries(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data or not data.staff then
		return
	end

	local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
	local totalSalary = 0

	for _, staffMember in ipairs(data.staff) do
		local staffType = GameConfig.getStaffTypeById(staffMember.role:lower())
		if staffType then
			totalSalary = totalSalary + staffType.salary
		end
	end

	if totalSalary > 0 then
		if data.money >= totalSalary then
			EconomyManager.removeMoney(player, totalSalary, "salary")
		else
			-- Can't afford salaries - fire the most expensive staff member
			RemoteHelper.fireClient("NotifyClient", player, {
				text = "Can't afford staff salaries!",
				type = "warning",
			})
		end
	end
end

return EconomyManager
