-- WorldSetup.server.lua
-- Generates placeholder 3D models with CollectionService tags.
-- Runs once on server start. Replace with real models later.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local COLORS = {
	planter = Color3.fromRGB(76, 50, 30),     -- brown
	shelf = Color3.fromRGB(180, 140, 90),      -- wood
	register = Color3.fromRGB(50, 200, 100),   -- green
	floor = Color3.fromRGB(60, 60, 60),        -- dark gray
	wall = Color3.fromRGB(45, 45, 50),         -- charcoal
	npcSpawn = Color3.fromRGB(255, 200, 50),   -- yellow
	processingTable = Color3.fromRGB(100, 80, 160), -- purple
}

-- Container for all generated world parts
local worldFolder = Instance.new("Folder")
worldFolder.Name = "GameWorld"
worldFolder.Parent = workspace

------------------------------------------------------------------------
-- Helper: create a Part with common properties
------------------------------------------------------------------------
local function createPart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent or worldFolder
	return part
end

local function createLabel(text, parent, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.new(0, 120, 0, 40)
	billboard.StudsOffset = offset or Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.TextColor3 = Color3.fromRGB(180, 240, 0) -- neon green
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	return billboard
end

------------------------------------------------------------------------
-- Build the street shop layout (Level 1: Street Stall)
------------------------------------------------------------------------

print("[WorldSetup] Generating placeholder world...")

-- Floor / ground plane
local floor = createPart("Floor", Vector3.new(60, 1, 40), Vector3.new(0, -0.5, 0), COLORS.floor)
floor.Material = Enum.Material.Concrete

-- Back wall
createPart("BackWall", Vector3.new(60, 12, 1), Vector3.new(0, 5.5, -20), COLORS.wall)

-- Side walls
createPart("LeftWall", Vector3.new(1, 12, 40), Vector3.new(-30, 5.5, 0), COLORS.wall)
createPart("RightWall", Vector3.new(1, 12, 40), Vector3.new(30, 5.5, 0), COLORS.wall)

------------------------------------------------------------------------
-- Planters (up to 40 max for Festival Ground)
-- Start with Level 1 layout (2 planters), extras are placed but hidden
------------------------------------------------------------------------
local MAX_PLANTERS = 40
local PLANTER_SPACING = 4
local PLANTER_START_X = -18
local PLANTER_START_Z = -12
local PLANTERS_PER_ROW = 8

for i = 1, MAX_PLANTERS do
	local row = math.floor((i - 1) / PLANTERS_PER_ROW)
	local col = (i - 1) % PLANTERS_PER_ROW
	local x = PLANTER_START_X + col * PLANTER_SPACING
	local z = PLANTER_START_Z + row * PLANTER_SPACING

	local planter = createPart(
		"planter_" .. i,
		Vector3.new(3, 1.5, 3),
		Vector3.new(x, 0.75, z),
		COLORS.planter
	)
	planter:SetAttribute("Id", "planter_" .. i)
	CollectionService:AddTag(planter, "Planter")
	createLabel("Planter " .. i, planter)

	-- Only show planters for Level 1 initially
	if i > 2 then
		planter.Transparency = 0.8
	end
end

------------------------------------------------------------------------
-- Shelves (up to 20 max)
------------------------------------------------------------------------
local MAX_SHELVES = 20
local SHELF_SPACING = 4
local SHELF_X = 18

for i = 1, MAX_SHELVES do
	local z = -16 + (i - 1) * SHELF_SPACING
	local row = math.floor((i - 1) / 5)
	local col = (i - 1) % 5
	local x = SHELF_X - row * 5
	local zPos = -12 + col * SHELF_SPACING

	local shelf = createPart(
		"shelf_" .. i,
		Vector3.new(3, 3, 1.5),
		Vector3.new(x, 1.5, zPos),
		COLORS.shelf
	)
	shelf:SetAttribute("Id", "shelf_" .. i)
	CollectionService:AddTag(shelf, "Shelf")
	createLabel("Shelf " .. i, shelf)

	-- Only show 1 shelf for Level 1
	if i > 1 then
		shelf.Transparency = 0.8
	end
end

------------------------------------------------------------------------
-- Register (cash register)
------------------------------------------------------------------------
local register = createPart(
	"register_1",
	Vector3.new(2, 1.5, 2),
	Vector3.new(24, 0.75, 8),
	COLORS.register
)
register:SetAttribute("Id", "register_1")
CollectionService:AddTag(register, "Register")
createLabel("Register $", register)

------------------------------------------------------------------------
-- Processing Tables (up to 6)
------------------------------------------------------------------------
for i = 1, 6 do
	local table_ = createPart(
		"processing_" .. i,
		Vector3.new(3, 1, 3),
		Vector3.new(-24, 0.5, -12 + (i - 1) * 4),
		COLORS.processingTable
	)
	table_:SetAttribute("Id", "processing_" .. i)
	CollectionService:AddTag(table_, "ProcessingTable")
	createLabel("Processing " .. i, table_)

	-- Hidden by default (unlocks at shop level 3)
	table_.Transparency = 0.8
end

------------------------------------------------------------------------
-- NPC spawn/despawn points
------------------------------------------------------------------------
local npcSpawn = createPart(
	"NPCSpawnPoint",
	Vector3.new(3, 0.2, 3),
	Vector3.new(0, 0.1, 18),
	COLORS.npcSpawn
)
npcSpawn.Transparency = 0.5
createLabel("NPC Spawn", npcSpawn, Vector3.new(0, 1, 0))

local npcExit = createPart(
	"NPCExitPoint",
	Vector3.new(3, 0.2, 3),
	Vector3.new(0, 0.1, -18),
	Color3.fromRGB(255, 80, 80)
)
npcExit.Transparency = 0.5
createLabel("NPC Exit", npcExit, Vector3.new(0, 1, 0))

------------------------------------------------------------------------
-- Player spawn point
------------------------------------------------------------------------
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "PlayerSpawn"
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.Position = Vector3.new(0, 0.5, 12)
spawnLocation.Anchored = true
spawnLocation.Material = Enum.Material.Neon
spawnLocation.Color = Color3.fromRGB(180, 240, 0) -- neon green
spawnLocation.Transparency = 0.5
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.BottomSurface = Enum.SurfaceType.Smooth
spawnLocation.Parent = worldFolder

------------------------------------------------------------------------
-- Lighting / Atmosphere setup
------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 20 -- Night time for neon vibe
Lighting.Brightness = 0.5
Lighting.Ambient = Color3.fromRGB(30, 30, 40)
Lighting.OutdoorAmbient = Color3.fromRGB(40, 40, 60)
Lighting.FogEnd = 500

-- Bloom for neon glow
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if not bloom then
	bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.8
	bloom.Parent = Lighting
end

-- Color correction for street feel
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if not cc then
	cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.05
	cc.Contrast = 0.1
	cc.Saturation = 0.2
	cc.TintColor = Color3.fromRGB(255, 245, 230)
	cc.Parent = Lighting
end

------------------------------------------------------------------------
-- Neon accent lights along walls
------------------------------------------------------------------------
local accentColors = {
	Color3.fromRGB(180, 240, 0),   -- lime
	Color3.fromRGB(0, 200, 255),   -- cyan
	Color3.fromRGB(255, 50, 150),  -- pink
}

for i = 1, 5 do
	local x = -20 + (i - 1) * 10
	local light = createPart(
		"NeonLight_" .. i,
		Vector3.new(8, 0.3, 0.3),
		Vector3.new(x, 10, -19.5),
		accentColors[(i % #accentColors) + 1]
	)
	light.Material = Enum.Material.Neon
	light.Transparency = 0
end

print("[WorldSetup] Placeholder world generated!")
print("[WorldSetup] Level 1: 2 planters, 1 shelf, 1 register active")
print("[WorldSetup] Upgrade your building to unlock more!")
