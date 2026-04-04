--[[
	EventManager.lua
	Manages live events and festivals for Magical Herb Tycoon.
	Dependencies: GameConfig, RemoteHelper, DataManager, EconomyManager, NPCManager, BrandManager
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))
local DataManager = require(Server:WaitForChild("DataManager"))
local EconomyManager = require(Server:WaitForChild("EconomyManager"))
local NPCManager = require(Server:WaitForChild("NPCManager"))

-- Lazy-load BrandManager to avoid circular dependency
local BrandManager = nil
local function getBrandManager()
	if not BrandManager then
		BrandManager = require(Server:WaitForChild("BrandManager"))
	end
	return BrandManager
end

local EventManager = {}

-- Event type definitions
local EVENT_TYPES = {
	MiniLive = {
		cost = 5000,
		duration = 300,
		customerMultiplier = 1.5,
		boothIncome = 0,
		requiredShopLevel = 6,
		expectedCustomers = 20,
	},
	Market = {
		cost = 15000,
		duration = 600,
		customerMultiplier = 2.0,
		boothIncome = 1000,
		requiredShopLevel = 6,
		expectedCustomers = 40,
	},
	Festival = {
		cost = 50000,
		duration = 900,
		customerMultiplier = 3.0,
		boothIncome = 5000,
		requiredShopLevel = 7,
		expectedCustomers = 80,
	},
}

-- Active events per player: { [userId] = { eventType, startedAt, duration, customersServed } }
local activeEvents: { [number]: any } = {}

local function getPlayerData(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end
	if not data.stats then
		data.stats = {}
	end
	return data
end

-- Checks all requirements for starting an event.
function EventManager.canStartEvent(player: Player, eventType: string): (boolean, string?)
	local config = EVENT_TYPES[eventType]
	if not config then
		return false, "InvalidEventType"
	end

	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	-- Check shop level
	local shopLevel = data.shopLevel or 1
	if shopLevel < config.requiredShopLevel then
		return false, "ShopLevelTooLow"
	end

	-- Check no active event
	local userId = player.UserId
	if activeEvents[userId] then
		return false, "EventAlreadyActive"
	end

	-- Check money
	local money = EconomyManager.getMoney(player)
	if money < config.cost then
		return false, "NotEnoughMoney"
	end

	return true, nil
end

-- Starts an event for the player.
function EventManager.startEvent(player: Player, eventType: string): (boolean, string?)
	local canStart, reason = EventManager.canStartEvent(player, eventType)
	if not canStart then
		return false, reason
	end

	local config = EVENT_TYPES[eventType]
	local deducted = EconomyManager.removeMoney(player, config.cost, "event")
	if not deducted then
		return false, "DeductFailed"
	end

	local userId = player.UserId
	activeEvents[userId] = {
		eventType = eventType,
		startedAt = os.clock(),
		duration = config.duration,
		customersServed = 0,
	}

	-- Boost NPC spawn rate
	NPCManager.setEventMultiplier(player, config.customerMultiplier)

	RemoteHelper.fireClient(player, "EventStarted", {
		eventType = eventType,
		duration = config.duration,
		customerMultiplier = config.customerMultiplier,
	})

	return true, nil
end

-- Calculates event results based on performance.
function EventManager.calculateEventResults(player: Player, eventType: string, customersServed: number): any
	local config = EVENT_TYPES[eventType]
	if not config then
		return nil
	end

	local expectedCustomers = config.expectedCustomers or 1
	local rating = math.clamp(customersServed / expectedCustomers, 0, 2)

	-- Bonus money scales with rating and booth income
	local bonusMoney = math.floor(config.boothIncome * rating)

	-- Award trophies for high performance
	local trophies = 0
	if rating >= 1.5 then
		trophies = 3
	elseif rating >= 1.0 then
		trophies = 2
	elseif rating >= 0.5 then
		trophies = 1
	end

	return {
		rating = rating,
		customersServed = customersServed,
		expectedCustomers = expectedCustomers,
		bonusMoney = bonusMoney,
		trophies = trophies,
	}
end

-- Ends an active event for the player.
function EventManager.endEvent(player: Player): any
	local userId = player.UserId
	local event = activeEvents[userId]
	if not event then
		return nil
	end

	-- Reset NPC multiplier
	NPCManager.setEventMultiplier(player, 1.0)

	-- Calculate results
	local results = EventManager.calculateEventResults(player, event.eventType, event.customersServed)
	if not results then
		activeEvents[userId] = nil
		return nil
	end

	-- Award bonus money
	if results.bonusMoney > 0 then
		EconomyManager.addMoney(player, results.bonusMoney)
	end

	-- Update stats
	local data = getPlayerData(player)
	if data then
		data.stats.eventsHosted = (data.stats.eventsHosted or 0) + 1
		DataManager.savePlayerData(player)

		-- Update brand score after event
		getBrandManager().updateBrandScore(player)
	end

	-- Clean up
	activeEvents[userId] = nil

	RemoteHelper.fireClient(player, "EventEnded", {
		eventType = event.eventType,
	})

	RemoteHelper.fireClient(player, "EventResults", results)

	return results
end

-- Returns the active event for a player, or nil.
function EventManager.getActiveEvent(player: Player): any
	local userId = player.UserId
	local event = activeEvents[userId]
	if not event then
		return nil
	end

	local elapsed = os.clock() - event.startedAt
	local remaining = math.max(0, event.duration - elapsed)

	return {
		eventType = event.eventType,
		elapsed = elapsed,
		remaining = remaining,
		customersServed = event.customersServed,
		isComplete = remaining <= 0,
	}
end

-- Called each tick. Checks active events and ends them when the timer expires.
function EventManager.updateEvents(dt: number)
	local Players = game:GetService("Players")

	-- Collect events to end (avoid modifying table during iteration)
	local toEnd = {}

	for userId, event in pairs(activeEvents) do
		local elapsed = os.clock() - event.startedAt
		if elapsed >= event.duration then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(toEnd, player)
			else
				-- Player left, clean up
				activeEvents[userId] = nil
			end
		end
	end

	for _, player in ipairs(toEnd) do
		EventManager.endEvent(player)
	end
end

-- Increment customers served for the active event (called by ShopManager on sale).
function EventManager.recordCustomerServed(player: Player)
	local userId = player.UserId
	local event = activeEvents[userId]
	if event then
		event.customersServed = event.customersServed + 1
	end
end

-- Clean up player event data on leave
function EventManager.cleanupPlayer(player: Player)
	activeEvents[player.UserId] = nil
end

return EventManager
