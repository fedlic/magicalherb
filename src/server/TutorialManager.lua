--[[
	TutorialManager.lua
	Manages the tutorial flow for new players in Magical Herb Tycoon.
	Dependencies: RemoteHelper, DataManager, EconomyManager, InventoryManager
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))
local DataManager = require(Server:WaitForChild("DataManager"))
local EconomyManager = require(Server:WaitForChild("EconomyManager"))
local InventoryManager = require(Server:WaitForChild("InventoryManager"))

local TutorialManager = {}

local TUTORIAL_COMPLETE_STEP = 9

-- Tutorial step definitions
local STEPS = {
	[1] = {
		name = "Welcome",
		description = "DJ Sage intro. Receive 1 free Chill Mint seed.",
		autoAdvanceAction = nil, -- advances after giveStarterKit
	},
	[2] = {
		name = "Plant",
		description = "Plant the seed in planter_1.",
		autoAdvanceAction = "PlantSeed",
	},
	[3] = {
		name = "Water",
		description = "Water the plant.",
		autoAdvanceAction = "WaterPlant",
	},
	[4] = {
		name = "Harvest",
		description = "Harvest when ready. First plant grows in 10s for tutorial.",
		autoAdvanceAction = "HarvestPlant",
	},
	[5] = {
		name = "Display",
		description = "Put product on shelf.",
		autoAdvanceAction = "DisplayProduct",
	},
	[6] = {
		name = "Sell",
		description = "Wait for NPC to buy.",
		autoAdvanceAction = "ProductSold",
	},
	[7] = {
		name = "Collect",
		description = "Collect money from register.",
		autoAdvanceAction = "CollectMoney",
	},
	[8] = {
		name = "Expand",
		description = "Buy a second planter or new seed.",
		autoAdvanceAction = "BuySeed",
		altAction = "BuyUpgrade",
	},
	[9] = {
		name = "Complete",
		description = "Tutorial done! Receive 100 bonus coins.",
		autoAdvanceAction = nil,
	},
}

local function getPlayerData(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end
	if not data.tutorialStep then
		data.tutorialStep = 1
	end
	return data
end

-- Initializes the tutorial for a player. Starts from their saved step.
function TutorialManager.init(player: Player)
	local data = getPlayerData(player)
	if not data then
		return
	end

	if data.tutorialStep >= TUTORIAL_COMPLETE_STEP then
		return -- Already completed
	end

	local currentStep = data.tutorialStep

	-- If player is at step 1, give starter kit
	if currentStep == 1 then
		TutorialManager.giveStarterKit(player)
	end

	-- Fire current step to client
	local stepInfo = STEPS[currentStep]
	if stepInfo then
		RemoteHelper.fireClient(player, "TutorialStep", {
			step = currentStep,
			name = stepInfo.name,
			description = stepInfo.description,
		})
	end
end

-- Returns the current tutorial step number and step info.
function TutorialManager.getCurrentStep(player: Player): (number, any)
	local data = getPlayerData(player)
	if not data then
		return 1, STEPS[1]
	end

	local step = data.tutorialStep
	return step, STEPS[step]
end

-- Checks if the tutorial is complete.
function TutorialManager.isComplete(player: Player): boolean
	local data = getPlayerData(player)
	if not data then
		return false
	end
	return data.tutorialStep >= TUTORIAL_COMPLETE_STEP
end

-- Gives the starter kit (1 free Chill Mint seed) at step 1.
function TutorialManager.giveStarterKit(player: Player)
	local data = getPlayerData(player)
	if not data then
		return
	end

	-- Only give at step 1
	if data.tutorialStep ~= 1 then
		return
	end

	InventoryManager.addItem(player, "raw_chill_mint", "B", 1)

	-- Auto-advance past the welcome step
	TutorialManager.advanceStep(player)
end

-- Advances the tutorial to the next step. Gives rewards for certain steps.
function TutorialManager.advanceStep(player: Player): (boolean, string?)
	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	local currentStep = data.tutorialStep
	if currentStep >= TUTORIAL_COMPLETE_STEP then
		return false, "AlreadyComplete"
	end

	local nextStep = currentStep + 1
	data.tutorialStep = nextStep
	DataManager.savePlayerData(player)

	local stepInfo = STEPS[nextStep]

	-- Give rewards for completing specific steps
	if nextStep == TUTORIAL_COMPLETE_STEP then
		-- Tutorial complete: give 100 bonus coins
		EconomyManager.addMoney(player, 100)

		RemoteHelper.fireClient(player, "TutorialComplete", {
			bonusCoins = 100,
		})

		return true, nil
	end

	-- Fire step update to client
	if stepInfo then
		RemoteHelper.fireClient(player, "TutorialStep", {
			step = nextStep,
			name = stepInfo.name,
			description = stepInfo.description,
		})
	end

	return true, nil
end

-- Called after various game actions to auto-advance the tutorial if the action
-- matches the current step requirement.
function TutorialManager.checkAutoAdvance(player: Player, action: string)
	local data = getPlayerData(player)
	if not data then
		return
	end

	local currentStep = data.tutorialStep
	if currentStep >= TUTORIAL_COMPLETE_STEP then
		return
	end

	local stepInfo = STEPS[currentStep]
	if not stepInfo then
		return
	end

	local shouldAdvance = false

	if stepInfo.autoAdvanceAction and stepInfo.autoAdvanceAction == action then
		shouldAdvance = true
	end

	-- Check alternate action (step 8 accepts BuySeed or BuyUpgrade)
	if not shouldAdvance and stepInfo.altAction and stepInfo.altAction == action then
		shouldAdvance = true
	end

	if shouldAdvance then
		TutorialManager.advanceStep(player)
	end
end

return TutorialManager
