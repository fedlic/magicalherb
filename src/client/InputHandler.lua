-- InputHandler.lua
-- Handles player input for game interactions in Magical Herb Tycoon
-- Uses raycasting for 3D object detection and CollectionService for tagged instances

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InputHandler = {}
InputHandler.__index = InputHandler

-- Dependencies (loaded on init)
local RemoteHelper = nil
local UIController = nil

-- State
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local enabled = true
local connections = {}

-- Tags used by CollectionService to identify interactable objects
local TAGS = {
	Planter = "Planter",
	Shelf = "Shelf",
	Register = "Register",
	NPC = "NPC",
}

-- Raycast parameters
local RAY_DISTANCE = 200
local raycastParams = nil

-- Callbacks registered by other modules
InputHandler.OnPlanterClicked = nil  -- function(planterId)
InputHandler.OnShelfClicked = nil    -- function(shelfId)
InputHandler.OnRegisterClicked = nil -- function()
InputHandler.OnNPCClicked = nil      -- function(npcId)

------------------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------------------

local function getTagForInstance(instance)
	-- Walk up the hierarchy to find a tagged ancestor (up to 5 levels)
	local current = instance
	for _ = 1, 5 do
		if current == nil or current == workspace then
			break
		end
		for _, tag in pairs(TAGS) do
			if CollectionService:HasTag(current, tag) then
				return tag, current
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function performRaycast(screenPosition)
	if not camera then
		camera = workspace.CurrentCamera
	end
	if not camera then return nil end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_DISTANCE, raycastParams)
	return result
end

local function getIdFromInstance(instance)
	-- Try to get a unique ID from the instance: check for an attribute, a StringValue child, or use the Name
	local id = instance:GetAttribute("Id")
	if id then return tostring(id) end

	local idValue = instance:FindFirstChild("Id")
	if idValue and idValue:IsA("StringValue") then
		return idValue.Value
	end

	return instance.Name
end

------------------------------------------------------------------------
-- Click/Tap handler
------------------------------------------------------------------------

local function handleWorldClick(screenPosition)
	if not enabled then return end

	local result = performRaycast(screenPosition)
	if not result or not result.Instance then return end

	local tag, taggedInstance = getTagForInstance(result.Instance)
	if not tag or not taggedInstance then return end

	local id = getIdFromInstance(taggedInstance)

	if tag == TAGS.Planter then
		InputHandler.onPlanterClicked(id)
	elseif tag == TAGS.Shelf then
		InputHandler.onShelfClicked(id)
	elseif tag == TAGS.Register then
		InputHandler.onRegisterClicked()
	elseif tag == TAGS.NPC then
		InputHandler.onNPCClicked(id)
	end
end

------------------------------------------------------------------------
-- Public: Interaction handlers
------------------------------------------------------------------------

-- Track which planter was selected (for seed shop)
InputHandler.selectedPlanterId = nil

function InputHandler.onPlanterClicked(planterId)
	if not enabled then return end

	if RemoteHelper then
		-- Try harvest first, then water. Server validates and rejects if wrong state.
		-- If both fail, open seed shop for planting.
		RemoteHelper.fireServer("HarvestPlant", planterId)
		RemoteHelper.fireServer("WaterPlant", planterId)

		-- Store selected planter so seed shop can use it
		InputHandler.selectedPlanterId = planterId
	end

	if InputHandler.OnPlanterClicked then
		InputHandler.OnPlanterClicked(planterId)
	end
end

function InputHandler.onShelfClicked(shelfId)
	if not enabled then return end

	-- Open inventory panel for shelf stocking
	if UIController then
		UIController.showPanel("Inventory")
	end

	if InputHandler.OnShelfClicked then
		InputHandler.OnShelfClicked(shelfId)
	end
end

function InputHandler.onRegisterClicked()
	if not enabled then return end

	if RemoteHelper then
		RemoteHelper.fireServer("CollectMoney")
	end

	if InputHandler.OnRegisterClicked then
		InputHandler.OnRegisterClicked()
	end
end

function InputHandler.onNPCClicked(npcId)
	if not enabled then return end

	-- NPCs are autonomous; clicking just shows info
	if UIController then
		UIController.showNotification("Customer is browsing...", "info")
	end

	if InputHandler.OnNPCClicked then
		InputHandler.OnNPCClicked(npcId)
	end
end

------------------------------------------------------------------------
-- Input enable/disable
------------------------------------------------------------------------

function InputHandler.enableInput()
	enabled = true
	if UIController then
		UIController.setInputEnabled(true)
	end
end

function InputHandler.disableInput()
	enabled = false
	if UIController then
		UIController.setInputEnabled(false)
	end
end

------------------------------------------------------------------------
-- World click detection setup
------------------------------------------------------------------------

function InputHandler.setupWorldClickDetection()
	-- Setup raycast params to ignore UI and player character
	raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {}

	-- Exclude player character from raycasts
	local function updateCharacterFilter()
		local char = player.Character
		if char then
			raycastParams.FilterDescendantsInstances = { char }
		end
	end
	updateCharacterFilter()
	player.CharacterAdded:Connect(updateCharacterFilter)

	-- Mouse click (desktop)
	local mouseConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not enabled then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = UserInputService:GetMouseLocation()
			handleWorldClick(pos)
		end
	end)
	table.insert(connections, mouseConn)

	-- Touch tap (mobile)
	local touchConn = UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
		if gameProcessed then return end
		if not enabled then return end

		if #touchPositions > 0 then
			handleWorldClick(touchPositions[1])
		end
	end)
	table.insert(connections, touchConn)
end

------------------------------------------------------------------------
-- Keyboard shortcuts
------------------------------------------------------------------------

local function setupKeyboardShortcuts()
	local keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not enabled then return end

		if input.KeyCode == Enum.KeyCode.I then
			-- Toggle inventory
			if UIController then
				UIController.showPanel("Inventory")
			end
		elseif input.KeyCode == Enum.KeyCode.B then
			-- Toggle shop (buy)
			if UIController then
				UIController.showPanel("Shop")
			end
		elseif input.KeyCode == Enum.KeyCode.U then
			-- Toggle upgrades
			if UIController then
				UIController.showPanel("Upgrades")
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			-- Close any open panel
			if UIController then
				UIController.hidePanel("Inventory")
				UIController.hidePanel("Shop")
				UIController.hidePanel("Upgrades")
				UIController.hidePanel("Staff")
				UIController.hidePanel("Brand")
				UIController.hidePanel("Events")
				UIController.hidePanel("Processing")
			end
		end
	end)
	table.insert(connections, keyConn)
end

------------------------------------------------------------------------
-- Highlight on hover
------------------------------------------------------------------------

local currentHighlight = nil

local function setupHoverHighlight()
	local hoverConn = RunService.Heartbeat:Connect(function()
		if not enabled then return end

		local pos = UserInputService:GetMouseLocation()
		local result = performRaycast(pos)

		-- Remove previous highlight
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end

		if result and result.Instance then
			local tag, taggedInstance = getTagForInstance(result.Instance)
			if tag and taggedInstance then
				local highlight = Instance.new("Highlight")
				highlight.Name = "InputHoverHighlight"
				highlight.FillColor = Color3.fromHex("#00ff88")
				highlight.FillTransparency = 0.8
				highlight.OutlineColor = Color3.fromHex("#00ff88")
				highlight.OutlineTransparency = 0.3
				highlight.Adornee = taggedInstance
				highlight.Parent = taggedInstance
				currentHighlight = highlight
			end
		end
	end)
	table.insert(connections, hoverConn)
end

------------------------------------------------------------------------
-- Init / Cleanup
------------------------------------------------------------------------

function InputHandler.init()
	-- Try to load dependencies
	local ok1, mod1 = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteHelper", 5))
	end)
	if ok1 and mod1 then
		RemoteHelper = mod1
	end

	-- UIController should be required from the caller; accept it as optional
	local ok2, mod2 = pcall(function()
		return require(script.Parent:WaitForChild("UIController", 5))
	end)
	if ok2 and mod2 then
		UIController = mod2
	end

	InputHandler.setupWorldClickDetection()
	setupKeyboardShortcuts()
	setupHoverHighlight()

	return InputHandler
end

function InputHandler.cleanup()
	for _, conn in ipairs(connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	connections = {}

	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
end

return InputHandler
