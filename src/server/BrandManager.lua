--[[
	BrandManager.lua
	Manages the brand identity and reputation system for Magical Herb Tycoon.
	Dependencies: RemoteHelper, DataManager
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local RemoteHelper = require(Shared:WaitForChild("RemoteHelper"))
local DataManager = require(Server:WaitForChild("DataManager"))

local BrandManager = {}

-- Rank thresholds (score required to reach each rank)
local RANK_THRESHOLDS = {
	{ rank = "Unknown", threshold = 0 },
	{ rank = "Local", threshold = 100 },
	{ rank = "Popular", threshold = 500 },
	{ rank = "Famous", threshold = 2000 },
	{ rank = "Legend", threshold = 10000 },
}

-- Sell price multiplier per rank
local RANK_BONUSES = {
	Unknown = 1.0,
	Local = 1.1,
	Popular = 1.2,
	Famous = 1.4,
	Legend = 1.8,
}

-- Basic profanity blocklist
local BLOCKED_WORDS = {
	"fuck", "shit", "ass", "damn", "bitch", "dick", "cock", "pussy",
	"nigger", "faggot", "retard", "cunt", "whore", "slut",
}

local function getPlayerData(player: Player)
	local data = DataManager.getPlayerData(player)
	if not data then
		return nil
	end
	if not data.brandName then
		data.brandName = ""
	end
	if not data.brandScore then
		data.brandScore = 0
	end
	if not data.brandRank then
		data.brandRank = "Unknown"
	end
	if not data.stats then
		data.stats = {}
	end
	return data
end

-- Returns the rank string for a given score.
local function rankForScore(score: number): string
	local result = "Unknown"
	for _, entry in ipairs(RANK_THRESHOLDS) do
		if score >= entry.threshold then
			result = entry.rank
		end
	end
	return result
end

-- Returns the next rank threshold above the current score, or nil if at max.
local function nextThreshold(score: number): number?
	for _, entry in ipairs(RANK_THRESHOLDS) do
		if score < entry.threshold then
			return entry.threshold
		end
	end
	return nil
end

-- Checks if a brand name contains blocked words.
local function containsProfanity(name: string): boolean
	local lower = string.lower(name)
	for _, word in ipairs(BLOCKED_WORDS) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

-- Sets the brand name for a player. Validates length and profanity.
function BrandManager.setBrandName(player: Player, name: string): (boolean, string?)
	if not name or type(name) ~= "string" then
		return false, "InvalidName"
	end

	-- Trim whitespace
	name = string.match(name, "^%s*(.-)%s*$") or ""

	if #name < 3 then
		return false, "TooShort"
	end
	if #name > 20 then
		return false, "TooLong"
	end

	if containsProfanity(name) then
		return false, "InappropriateName"
	end

	local data = getPlayerData(player)
	if not data then
		return false, "NoPlayerData"
	end

	data.brandName = name
	DataManager.savePlayerData(player)

	RemoteHelper.fireClient(player, "BrandUpdated", {
		name = data.brandName,
		rank = data.brandRank,
		score = data.brandScore,
	})

	return true, nil
end

-- Recalculates the brand score from all contributing factors.
function BrandManager.updateBrandScore(player: Player)
	local data = getPlayerData(player)
	if not data then
		return
	end

	local stats = data.stats

	-- varietyScore: unique products sold * 5
	local uniqueProductsSold = stats.uniqueProductsSold or 0
	local varietyScore = uniqueProductsSold * 5

	-- qualityScore: A/S/SS products sold weighted
	local aProductsSold = stats.aProductsSold or 0
	local sProductsSold = stats.sProductsSold or 0
	local ssProductsSold = stats.ssProductsSold or 0
	local qualityScore = (aProductsSold * 2) + (sProductsSold * 5) + (ssProductsSold * 10)

	-- decorScore: decorations placed * 3
	local decorationsPlaced = stats.decorationsPlaced or 0
	local decorScore = decorationsPlaced * 3

	-- salesScore: totalEarned / 100
	local totalEarned = stats.totalEarned or 0
	local salesScore = math.floor(totalEarned / 100)

	-- eventScore: eventsHosted * 50
	local eventsHosted = stats.eventsHosted or 0
	local eventScore = eventsHosted * 50

	local newScore = varietyScore + qualityScore + decorScore + salesScore + eventScore
	local oldRank = data.brandRank
	data.brandScore = newScore
	data.brandRank = rankForScore(newScore)

	DataManager.savePlayerData(player)

	RemoteHelper.fireClient(player, "BrandUpdated", {
		name = data.brandName,
		rank = data.brandRank,
		score = data.brandScore,
		bonus = RANK_BONUSES[data.brandRank] or 1.0,
	})

	-- Check for rank up
	if data.brandRank ~= oldRank then
		BrandManager.checkRankUp(player)
	end
end

-- Returns the current rank string.
function BrandManager.getBrandRank(player: Player): string
	local data = getPlayerData(player)
	if not data then
		return "Unknown"
	end
	return data.brandRank
end

-- Returns the current brand score.
function BrandManager.getBrandScore(player: Player): number
	local data = getPlayerData(player)
	if not data then
		return 0
	end
	return data.brandScore
end

-- Returns the sell price multiplier based on current rank.
function BrandManager.getBrandBonus(player: Player): number
	local rank = BrandManager.getBrandRank(player)
	return RANK_BONUSES[rank] or 1.0
end

-- Checks if the player crossed a rank threshold and fires the rank-up remote.
function BrandManager.checkRankUp(player: Player)
	local data = getPlayerData(player)
	if not data then
		return
	end

	RemoteHelper.fireClient(player, "BrandRankUp", {
		rank = data.brandRank,
		score = data.brandScore,
		bonus = RANK_BONUSES[data.brandRank] or 1.0,
	})
end

-- Returns full brand info for the player.
function BrandManager.getBrandInfo(player: Player): any
	local data = getPlayerData(player)
	if not data then
		return {
			name = "",
			rank = "Unknown",
			score = 0,
			nextRankThreshold = 100,
			bonus = 1.0,
		}
	end

	return {
		name = data.brandName,
		rank = data.brandRank,
		score = data.brandScore,
		nextRankThreshold = nextThreshold(data.brandScore),
		bonus = RANK_BONUSES[data.brandRank] or 1.0,
	}
end

return BrandManager
