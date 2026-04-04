-- RemoteHelper: Unified Remote Event/Function wrapper
-- Auto-detects server/client and provides clean API for all network communication.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteHelper = {}
local isServer = RunService:IsServer()

-- All remote events used in the game
local REMOTE_EVENTS = {
	-- Player actions (client -> server)
	"PlantSeed",
	"WaterPlant",
	"HarvestPlant",
	"DisplayProduct",
	"CollectMoney",
	"BuySeed",
	"BuyUpgrade",
	"UpgradeBuilding",
	"HireStaff",
	"FireStaff",
	"StartProcessing",
	"CollectProcessed",
	"SetBrandName",
	"StartEvent",
	"BuyDecoration",
	"PlaceDecoration",
	"TutorialAdvance",
	-- Server notifications (server -> client)
	"MoneyChanged",
	"InventoryChanged",
	"PlantUpdated",
	"PlantHarvested",
	"ShelfUpdated",
	"ProductSold",
	"UpgradeCompleted",
	"BuildingUpgraded",
	"ProcessingStarted",
	"ProcessingCompleted",
	"RecipeDiscovered",
	"BrandUpdated",
	"BrandRankUp",
	"EventStarted",
	"EventEnded",
	"EventResults",
	"NPCSpawned",
	"NPCStateChanged",
	"NPCLeft",
	"StaffHired",
	"StaffFired",
	"StaffAction",
	"TutorialStep",
	"TutorialComplete",
	"NotifyClient",
	"PlayerDataLoaded",
}

-- Remote functions (client -> server, returns data)
local REMOTE_FUNCTIONS = {
	"GetPlayerData",
	"GetShopInfo",
}

local remotesFolder = nil
local remotes = {}
local functions = {}

function RemoteHelper.init()
	if isServer then
		-- Server: create all remotes
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage

		for _, name in ipairs(REMOTE_EVENTS) do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotesFolder
			remotes[name] = remote
		end

		for _, name in ipairs(REMOTE_FUNCTIONS) do
			local func = Instance.new("RemoteFunction")
			func.Name = name
			func.Parent = remotesFolder
			functions[name] = func
		end
	else
		-- Client: wait for remotes folder
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotesFolder then
			warn("[RemoteHelper] Remotes folder not found!")
			return
		end

		for _, name in ipairs(REMOTE_EVENTS) do
			local remote = remotesFolder:WaitForChild(name, 5)
			if remote then
				remotes[name] = remote
			else
				warn("[RemoteHelper] Remote event not found: " .. name)
			end
		end

		for _, name in ipairs(REMOTE_FUNCTIONS) do
			local func = remotesFolder:WaitForChild(name, 5)
			if func then
				functions[name] = func
			else
				warn("[RemoteHelper] Remote function not found: " .. name)
			end
		end
	end
end

-- Get a remote event by name
function RemoteHelper.getEvent(name: string): RemoteEvent?
	return remotes[name]
end

-- Get a remote function by name
function RemoteHelper.getFunction(name: string): RemoteFunction?
	return functions[name]
end

-- Fire event to server (client only)
function RemoteHelper.fireServer(eventName: string, ...)
	local remote = remotes[eventName]
	if remote then
		remote:FireServer(...)
	else
		warn("[RemoteHelper] Event not found: " .. eventName)
	end
end

-- Fire event to a specific client (server only)
-- Accepts both (eventName, player, ...) and (player, eventName, ...)
function RemoteHelper.fireClient(first, second, ...)
	local eventName, player
	if typeof(first) == "Instance" and first:IsA("Player") then
		player = first
		eventName = second
	else
		eventName = first
		player = second
	end

	local remote = remotes[eventName]
	if remote then
		remote:FireClient(player, ...)
	else
		warn("[RemoteHelper] Event not found: " .. tostring(eventName))
	end
end

-- Fire event to all clients (server only)
function RemoteHelper.fireAllClients(eventName: string, ...)
	local remote = remotes[eventName]
	if remote then
		remote:FireAllClients(...)
	else
		warn("[RemoteHelper] Event not found: " .. eventName)
	end
end

-- Connect to a remote event
function RemoteHelper.onEvent(eventName: string, callback)
	local remote = remotes[eventName]
	if remote then
		if isServer then
			return remote.OnServerEvent:Connect(callback)
		else
			return remote.OnClientEvent:Connect(callback)
		end
	else
		warn("[RemoteHelper] Event not found for connection: " .. eventName)
	end
	return nil
end

-- Invoke a remote function (client -> server)
function RemoteHelper.invoke(funcName: string, ...)
	local func = functions[funcName]
	if func then
		return func:InvokeServer(...)
	else
		warn("[RemoteHelper] Function not found: " .. funcName)
		return nil
	end
end

-- Set remote function callback (server only)
function RemoteHelper.onInvoke(funcName: string, callback)
	local func = functions[funcName]
	if func then
		func.OnServerInvoke = callback
	else
		warn("[RemoteHelper] Function not found for callback: " .. funcName)
	end
end

return RemoteHelper
