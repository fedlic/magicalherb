-- GameConfig: Master data module for Magical Herb Tycoon
-- Contains ALL game constants, seed data, recipes, buildings, upgrades, NPC types, etc.

local GameConfig = {}

-- Quality ranks and their sell price multipliers
GameConfig.QualityRanks = { "C", "B", "A", "S", "SS" }
GameConfig.QualityMultipliers = {
	C = 1.0,
	B = 1.5,
	A = 2.0,
	S = 3.0,
	SS = 5.0,
}

-- Brand ranks and score thresholds
GameConfig.BrandRanks = {
	{ name = "Unknown", threshold = 0 },
	{ name = "Local", threshold = 100 },
	{ name = "Popular", threshold = 500 },
	{ name = "Famous", threshold = 2000 },
	{ name = "Legend", threshold = 10000 },
}

GameConfig.BrandBonuses = {
	Unknown = 1.0,
	Local = 1.1,
	Popular = 1.2,
	Famous = 1.4,
	Legend = 1.8,
}

-- Growth stages and their progress thresholds
GameConfig.GrowthStages = {
	{ name = "seed", threshold = 0.0 },
	{ name = "sprout", threshold = 0.2 },
	{ name = "young", threshold = 0.4 },
	{ name = "mature", threshold = 0.6 },
	{ name = "ready", threshold = 0.8 },
}

-- Seeds
GameConfig.Seeds = {
	{
		id = "chill_mint",
		name = "Chill Mint",
		description = "A cool, refreshing herb with a frosty blue glow.",
		tier = 1,
		cost = 10,
		growTime = 30,
		baseQuality = "C",
		maxQuality = "A",
		waterNeeds = 2,
		basePrice = 25,
		unlockCondition = nil,
	},
	{
		id = "solar_leaf",
		name = "Solar Leaf",
		description = "Golden leaves that shimmer like sunlight.",
		tier = 1,
		cost = 15,
		growTime = 45,
		baseQuality = "C",
		maxQuality = "A",
		waterNeeds = 3,
		basePrice = 38,
		unlockCondition = nil,
	},
	{
		id = "mystic_basil",
		name = "Mystic Basil",
		description = "Purple-veined leaves with a mysterious aroma.",
		tier = 1,
		cost = 20,
		growTime = 60,
		baseQuality = "C",
		maxQuality = "S",
		waterNeeds = 3,
		basePrice = 50,
		unlockCondition = nil,
	},
	{
		id = "thunder_root",
		name = "Thunder Root",
		description = "Electric yellow roots that crackle with energy.",
		tier = 2,
		cost = 50,
		growTime = 90,
		baseQuality = "B",
		maxQuality = "S",
		waterNeeds = 4,
		basePrice = 125,
		unlockCondition = "shopLevel >= 2",
	},
	{
		id = "neon_bloom",
		name = "Neon Bloom",
		description = "Flowers that glow neon pink in the dark.",
		tier = 2,
		cost = 75,
		growTime = 120,
		baseQuality = "B",
		maxQuality = "S",
		waterNeeds = 5,
		basePrice = 188,
		unlockCondition = "shopLevel >= 3",
	},
	{
		id = "crystal_sage",
		name = "Crystal Sage",
		description = "Translucent leaves with crystalline structures inside.",
		tier = 2,
		cost = 100,
		growTime = 150,
		baseQuality = "B",
		maxQuality = "SS",
		waterNeeds = 5,
		basePrice = 250,
		unlockCondition = "shopLevel >= 3",
	},
	{
		id = "rainbow_herb",
		name = "Rainbow Herb",
		description = "Shifts through all colors of the spectrum as it grows.",
		tier = 3,
		cost = 500,
		growTime = 300,
		baseQuality = "A",
		maxQuality = "SS",
		waterNeeds = 7,
		basePrice = 1250,
		unlockCondition = "shopLevel >= 5",
	},
	{
		id = "shadow_fern",
		name = "Shadow Fern",
		description = "Dark, ethereal fronds that seem to absorb light.",
		tier = 3,
		cost = 750,
		growTime = 360,
		baseQuality = "A",
		maxQuality = "SS",
		waterNeeds = 8,
		basePrice = 1875,
		unlockCondition = "shopLevel >= 5",
	},
	{
		id = "dragon_vine",
		name = "Dragon Vine",
		description = "Legendary vine with scales that shimmer like dragon hide.",
		tier = 4,
		cost = 2000,
		growTime = 600,
		baseQuality = "S",
		maxQuality = "SS",
		waterNeeds = 10,
		basePrice = 5000,
		unlockCondition = "shopLevel >= 6",
	},
}

-- Recipes for processing
GameConfig.Recipes = {
	{
		id = "herb_tea",
		name = "Herb Tea",
		ingredients = { { type = "any_herb", quantity = 1 } },
		craftTime = 15,
		sellMultiplier = 2.0,
		requiredTableLevel = 1,
		description = "A soothing brew made from fresh herbs.",
	},
	{
		id = "aroma_oil",
		name = "Aroma Oil",
		ingredients = { { type = "any_herb", quantity = 2 } },
		craftTime = 30,
		sellMultiplier = 3.5,
		requiredTableLevel = 1,
		description = "Concentrated aromatic essence in a small bottle.",
	},
	{
		id = "bath_bomb",
		name = "Bath Bomb",
		ingredients = { { type = "any_herb", quantity = 1 } },
		craftTime = 25,
		sellMultiplier = 3.0,
		requiredTableLevel = 1,
		description = "Fizzy bath additive infused with herbal goodness.",
	},
	{
		id = "herb_incense",
		name = "Herb Incense",
		ingredients = { { type = "any_herb", quantity = 3 } },
		craftTime = 45,
		sellMultiplier = 5.0,
		requiredTableLevel = 2,
		description = "Slow-burning incense with a deep, complex aroma.",
	},
	{
		id = "rainbow_extract",
		name = "Rainbow Extract",
		ingredients = { { type = "specific", seedId = "rainbow_herb", quantity = 1 } },
		craftTime = 60,
		sellMultiplier = 10.0,
		requiredTableLevel = 3,
		description = "A prismatic liquid that shimmers with all colors.",
	},
	{
		id = "mystic_blend",
		name = "Mystic Blend",
		ingredients = {
			{ type = "specific", seedId = "thunder_root", quantity = 1 },
			{ type = "specific", seedId = "neon_bloom", quantity = 1 },
		},
		craftTime = 40,
		sellMultiplier = 6.0,
		requiredTableLevel = 2,
		description = "An electrifying blend of thunder and neon.",
	},
	{
		id = "dragon_elixir",
		name = "Dragon Elixir",
		ingredients = {
			{ type = "specific", seedId = "dragon_vine", quantity = 1 },
			{ type = "specific", seedId = "crystal_sage", quantity = 1 },
		},
		craftTime = 90,
		sellMultiplier = 12.0,
		requiredTableLevel = 3,
		description = "The most potent elixir known to herbalists.",
	},
	{
		id = "chill_essence",
		name = "Chill Essence",
		ingredients = {
			{ type = "specific", seedId = "chill_mint", quantity = 2 },
			{ type = "specific", seedId = "shadow_fern", quantity = 1 },
		},
		craftTime = 50,
		sellMultiplier = 7.0,
		requiredTableLevel = 2,
		description = "An icy-cool extract with dark undertones.",
	},
}

-- Buildings (shop stages)
GameConfig.Buildings = {
	{
		id = "street_stall",
		name = "Street Stall",
		nameJP = "露店",
		level = 1,
		cost = 0,
		maxPlanters = 2,
		maxShelves = 1,
		maxStaff = 0,
		hasProcessing = false,
		hasStage = false,
		unlockCondition = nil,
	},
	{
		id = "small_shop",
		name = "Small Shop",
		nameJP = "小型ショップ",
		level = 2,
		cost = 500,
		maxPlanters = 4,
		maxShelves = 3,
		maxStaff = 1,
		hasProcessing = false,
		hasStage = false,
		unlockCondition = { totalEarned = 500 },
	},
	{
		id = "street_shop",
		name = "Street Shop",
		nameJP = "路面店",
		level = 3,
		cost = 3000,
		maxPlanters = 8,
		maxShelves = 5,
		maxStaff = 2,
		hasProcessing = true,
		hasStage = false,
		unlockCondition = { totalEarned = 3000, brandRank = "Local" },
	},
	{
		id = "large_store",
		name = "Large Store",
		nameJP = "大型店",
		level = 4,
		cost = 15000,
		maxPlanters = 16,
		maxShelves = 8,
		maxStaff = 4,
		hasProcessing = true,
		hasStage = false,
		unlockCondition = { totalEarned = 15000, brandRank = "Popular" },
	},
	{
		id = "brand_shop",
		name = "Brand Shop",
		nameJP = "ブランドショップ",
		level = 5,
		cost = 80000,
		maxPlanters = 24,
		maxShelves = 12,
		maxStaff = 6,
		hasProcessing = true,
		hasStage = false,
		unlockCondition = { totalEarned = 80000, brandRank = "Famous" },
	},
	{
		id = "complex",
		name = "Complex",
		nameJP = "複合施設",
		level = 6,
		cost = 200000,
		maxPlanters = 32,
		maxShelves = 16,
		maxStaff = 8,
		hasProcessing = true,
		hasStage = true,
		unlockCondition = { totalEarned = 200000 },
	},
	{
		id = "festival_ground",
		name = "Festival Ground",
		nameJP = "フェス会場",
		level = 7,
		cost = 500000,
		maxPlanters = 40,
		maxShelves = 20,
		maxStaff = 10,
		hasProcessing = true,
		hasStage = true,
		unlockCondition = { totalEarned = 1500000 },
	},
}

-- Upgrade definitions
GameConfig.Upgrades = {
	planter = {
		baseCost = 100,
		maxLevel = 5,
		effect = "growSpeedBonus",
		effectPerLevel = 0.15,
		description = "Growth Speed +15%",
	},
	processingTable = {
		baseCost = 200,
		maxLevel = 5,
		effect = "craftSpeedBonus",
		effectPerLevel = 0.20,
		description = "Craft Speed +20%",
	},
	shelf = {
		baseCost = 150,
		maxLevel = 5,
		effect = "displaySlots",
		effectPerLevel = 2,
		description = "Display Slots +2",
	},
	register = {
		baseCost = 300,
		maxLevel = 5,
		effect = "collectSpeed",
		effectPerLevel = 0.25,
		autoCollectLevel = 3,
		description = "Collect Speed +25%",
	},
	warehouse = {
		baseCost = 250,
		maxLevel = 5,
		effect = "storageSlots",
		effectPerLevel = 20,
		description = "Storage +20 slots",
	},
	sprinkler = {
		baseCost = 500,
		maxLevel = 5,
		effect = "waterRange",
		effectPerLevel = 1,
		autoWaterLevel = 1,
		description = "Auto-Water Range +1",
	},
	lighting = {
		baseCost = 400,
		maxLevel = 5,
		effect = "qualityBonus",
		effectPerLevel = 0.10,
		description = "Quality Bonus +10%",
	},
}

-- NPC customer types
GameConfig.NPCTypes = {
	{
		id = "regular",
		type = "regular",
		displayName = "Customer",
		minQuality = "C",
		payMultiplier = 1.0,
		spawnWeight = 70,
		requiredBrandRank = nil,
		maxBuy = 2,
	},
	{
		id = "gourmet",
		type = "gourmet",
		displayName = "Gourmet",
		minQuality = "B",
		payMultiplier = 1.8,
		spawnWeight = 20,
		requiredBrandRank = "Local",
		maxBuy = 3,
	},
	{
		id = "vip",
		type = "vip",
		displayName = "VIP",
		minQuality = "A",
		payMultiplier = 3.0,
		spawnWeight = 8,
		requiredBrandRank = "Famous",
		maxBuy = 5,
	},
	{
		id = "collector",
		type = "collector",
		displayName = "Collector",
		minQuality = "S",
		payMultiplier = 5.0,
		spawnWeight = 2,
		requiredBrandRank = "Legend",
		maxBuy = 10,
	},
}

-- Staff types
GameConfig.StaffTypes = {
	{
		id = "cashier",
		role = "Cashier",
		cost = 500,
		salary = 5,
		effect = "autoCollectRegister",
		interval = 30,
		description = "Auto-collects money from register every 30s",
	},
	{
		id = "waterer",
		role = "Waterer",
		cost = 300,
		salary = 3,
		effect = "autoWaterPlants",
		interval = 15,
		description = "Auto-waters plants every 15s (no quality bonus)",
	},
	{
		id = "harvester",
		role = "Harvester",
		cost = 800,
		salary = 8,
		effect = "autoHarvest",
		interval = 20,
		description = "Auto-harvests ready plants (50% quality penalty)",
	},
	{
		id = "stocker",
		role = "Stocker",
		cost = 600,
		salary = 5,
		effect = "autoStockShelves",
		interval = 25,
		description = "Auto-stocks shelves from inventory every 25s",
	},
}

-- Event types
GameConfig.Events = {
	{
		id = "mini_live",
		name = "Mini Live",
		cost = 5000,
		duration = 300,
		customerMultiplier = 1.5,
		boothIncome = 0,
		requiredShopLevel = 6,
		description = "A small live music performance to attract customers.",
	},
	{
		id = "market",
		name = "Market",
		cost = 15000,
		duration = 600,
		customerMultiplier = 2.0,
		boothIncome = 1000,
		requiredShopLevel = 6,
		description = "Open-air market with vendor booths and extra traffic.",
	},
	{
		id = "festival",
		name = "Festival",
		cost = 50000,
		duration = 900,
		customerMultiplier = 3.0,
		boothIncome = 5000,
		requiredShopLevel = 7,
		description = "The ultimate street festival with massive crowds.",
	},
}

-- Tutorial steps
GameConfig.TutorialSteps = {
	{ step = 1, action = "welcome", text = "Yo! Welcome to the block! I'm DJ Sage. Let's get your shop started!", reward = nil },
	{ step = 2, action = "plant", text = "First, plant this seed in your planter. Tap the planter to begin!", reward = nil },
	{ step = 3, action = "water", text = "Nice! Now tap the planter to water it. Water makes it grow faster!", reward = nil },
	{ step = 4, action = "harvest", text = "It's ready! Tap to harvest your first herb!", reward = nil },
	{ step = 5, action = "display", text = "Now put it on the shelf so customers can see it.", reward = nil },
	{ step = 6, action = "sell", text = "Here comes your first customer... watch the magic happen!", reward = nil },
	{ step = 7, action = "collect", text = "Money in the register! Tap to collect it.", reward = nil },
	{ step = 8, action = "expand", text = "Invest in a new planter or a new seed type. Keep growing!", reward = nil },
	{ step = 9, action = "complete", text = "You're in business now! The sky's the limit!", reward = 100 },
}

-- Max stack size
GameConfig.MAX_STACK = 99

-- Base inventory slots
GameConfig.BASE_INVENTORY_SLOTS = 20

-- NPC behavior timings (seconds)
GameConfig.NPC_ENTER_TIME = 2
GameConfig.NPC_BROWSE_TIME = 3
GameConfig.NPC_SELECT_TIME = 1
GameConfig.NPC_PAY_TIME = 2
GameConfig.NPC_LEAVE_TIME = 2
GameConfig.NPC_MAX_QUEUE = 5
GameConfig.NPC_LEAVE_CHANCE = 0.3

-- Base NPC spawn interval
GameConfig.BASE_SPAWN_INTERVAL = 8

-- Water cooldown
GameConfig.WATER_COOLDOWN = 10

-- Auto-save interval
GameConfig.AUTO_SAVE_INTERVAL = 60

-- Salary charge interval
GameConfig.SALARY_INTERVAL = 60

-- Tutorial first plant grow time override
GameConfig.TUTORIAL_GROW_TIME = 10

-- Helper functions

function GameConfig.getQualityMultiplier(rank: string): number
	return GameConfig.QualityMultipliers[rank] or 1.0
end

function GameConfig.getQualityIndex(rank: string): number
	for i, q in ipairs(GameConfig.QualityRanks) do
		if q == rank then
			return i
		end
	end
	return 1
end

function GameConfig.meetsMinQuality(rank: string, minRank: string): boolean
	return GameConfig.getQualityIndex(rank) >= GameConfig.getQualityIndex(minRank)
end

function GameConfig.getSeedById(id: string)
	for _, seed in ipairs(GameConfig.Seeds) do
		if seed.id == id then
			return seed
		end
	end
	return nil
end

function GameConfig.getRecipeById(id: string)
	for _, recipe in ipairs(GameConfig.Recipes) do
		if recipe.id == id then
			return recipe
		end
	end
	return nil
end

function GameConfig.getBuildingByLevel(level: number)
	for _, building in ipairs(GameConfig.Buildings) do
		if building.level == level then
			return building
		end
	end
	return nil
end

function GameConfig.getUpgradeCost(category: string, level: number): number
	local upgrade = GameConfig.Upgrades[category]
	if not upgrade then
		return math.huge
	end
	return math.floor(upgrade.baseCost * math.pow(3, level - 1))
end

function GameConfig.getUpgradeEffect(category: string, level: number): number
	local upgrade = GameConfig.Upgrades[category]
	if not upgrade or level <= 0 then
		return 0
	end
	return upgrade.effectPerLevel * level
end

function GameConfig.getBrandRank(score: number): string
	local rank = "Unknown"
	for _, entry in ipairs(GameConfig.BrandRanks) do
		if score >= entry.threshold then
			rank = entry.name
		end
	end
	return rank
end

function GameConfig.getBrandRankIndex(rankName: string): number
	for i, entry in ipairs(GameConfig.BrandRanks) do
		if entry.name == rankName then
			return i
		end
	end
	return 1
end

function GameConfig.meetsRankRequirement(currentRank: string, requiredRank: string?): boolean
	if not requiredRank then
		return true
	end
	return GameConfig.getBrandRankIndex(currentRank) >= GameConfig.getBrandRankIndex(requiredRank)
end

function GameConfig.getNextBrandThreshold(score: number): number?
	for _, entry in ipairs(GameConfig.BrandRanks) do
		if score < entry.threshold then
			return entry.threshold
		end
	end
	return nil
end

function GameConfig.getNPCTypeById(id: string)
	for _, npcType in ipairs(GameConfig.NPCTypes) do
		if npcType.id == id then
			return npcType
		end
	end
	return nil
end

function GameConfig.getStaffTypeById(id: string)
	for _, staffType in ipairs(GameConfig.StaffTypes) do
		if staffType.id == id then
			return staffType
		end
	end
	return nil
end

function GameConfig.getEventById(id: string)
	for _, event in ipairs(GameConfig.Events) do
		if event.id == id then
			return event
		end
	end
	return nil
end

function GameConfig.getStageFromProgress(progress: number): string
	local stage = "seed"
	for _, s in ipairs(GameConfig.GrowthStages) do
		if progress >= s.threshold then
			stage = s.name
		end
	end
	return stage
end

function GameConfig.getQualityFromScore(score: number): string
	if score >= 81 then
		return "SS"
	elseif score >= 61 then
		return "S"
	elseif score >= 41 then
		return "A"
	elseif score >= 21 then
		return "B"
	else
		return "C"
	end
end

function GameConfig.getUnlockedSeeds(shopLevel: number)
	local unlocked = {}
	for _, seed in ipairs(GameConfig.Seeds) do
		if seed.tier <= shopLevel then
			table.insert(unlocked, seed)
		end
	end
	return unlocked
end

return GameConfig
