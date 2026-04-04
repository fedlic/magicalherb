-- CameraController.lua
-- Manages camera for the tycoon view in Magical Herb Tycoon
-- Semi-isometric, 45-degree angle, WASD/drag to pan, scroll to zoom

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local CameraController = {}
CameraController.__index = CameraController

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Configuration
local CAMERA_ANGLE = 45             -- degrees from horizontal
local CAMERA_ROTATION = -45         -- Y-axis rotation (isometric-like view)
local MIN_ZOOM = 15                 -- closest zoom distance
local MAX_ZOOM = 80                 -- furthest zoom distance
local DEFAULT_ZOOM = 40             -- default zoom distance
local ZOOM_STEP = 8                 -- per scroll notch
local PAN_SPEED = 40                -- studs per second (WASD)
local DRAG_SENSITIVITY = 0.5        -- mouse drag sensitivity
local SMOOTH_SPEED = 8              -- camera lerp speed (higher = snappier)
local ZOOM_LEVELS = { 20, 28, 40, 55, 75 } -- zoom levels 1-5

-- Boundary (set per player's plot, defaults to a reasonable area)
local BOUNDS_MIN = Vector3.new(-100, 0, -100)
local BOUNDS_MAX = Vector3.new(100, 0, 100)

-- State
local targetPosition = Vector3.new(0, 0, 0)   -- world position the camera looks at
local currentZoom = DEFAULT_ZOOM
local targetZoom = DEFAULT_ZOOM
local dragEnabled = true
local isDragging = false
local lastMousePosition = Vector2.new(0, 0)
local connections = {}
local isInitialized = false
local introPlaying = false

-- Key tracking for WASD
local keysDown = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false,
}

------------------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------------------

local function clampPosition(pos)
	return Vector3.new(
		math.clamp(pos.X, BOUNDS_MIN.X, BOUNDS_MAX.X),
		0,
		math.clamp(pos.Z, BOUNDS_MIN.Z, BOUNDS_MAX.Z)
	)
end

local function calculateCameraCFrame(lookAtPos, zoomDist)
	local angleRad = math.rad(CAMERA_ANGLE)
	local rotationRad = math.rad(CAMERA_ROTATION)

	-- Calculate offset from target based on angle and zoom
	local horizontalDist = zoomDist * math.cos(angleRad)
	local verticalDist = zoomDist * math.sin(angleRad)

	local offsetX = horizontalDist * math.sin(rotationRad)
	local offsetZ = horizontalDist * math.cos(rotationRad)

	local cameraPos = lookAtPos + Vector3.new(offsetX, verticalDist, offsetZ)

	return CFrame.lookAt(cameraPos, lookAtPos)
end

------------------------------------------------------------------------
-- CameraController.init
------------------------------------------------------------------------

function CameraController.init()
	if isInitialized then return CameraController end

	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	-- Set initial position
	targetPosition = Vector3.new(0, 0, 0)
	currentZoom = DEFAULT_ZOOM
	targetZoom = DEFAULT_ZOOM

	-- Apply initial camera CFrame
	camera.CFrame = calculateCameraCFrame(targetPosition, currentZoom)

	-- Input: scroll wheel zoom
	local scrollConn = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if introPlaying then return end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local direction = input.Position.Z -- +1 or -1
			CameraController._adjustZoom(-direction * ZOOM_STEP)
		end
	end)
	table.insert(connections, scrollConn)

	-- Input: WASD key tracking
	local keyDownConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if introPlaying then return end

		if keysDown[input.KeyCode] ~= nil then
			keysDown[input.KeyCode] = true
		end

		-- Pinch zoom alternative: +/- keys
		if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus then
			CameraController.zoomIn()
		elseif input.KeyCode == Enum.KeyCode.Minus then
			CameraController.zoomOut()
		end
	end)
	table.insert(connections, keyDownConn)

	local keyUpConn = UserInputService.InputEnded:Connect(function(input, _)
		if keysDown[input.KeyCode] ~= nil then
			keysDown[input.KeyCode] = false
		end
	end)
	table.insert(connections, keyUpConn)

	-- Input: mouse drag
	local mouseDownConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not dragEnabled then return end
		if introPlaying then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			isDragging = true
			lastMousePosition = UserInputService:GetMouseLocation()
		end
	end)
	table.insert(connections, mouseDownConn)

	local mouseUpConn = UserInputService.InputEnded:Connect(function(input, _)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			isDragging = false
		end
	end)
	table.insert(connections, mouseUpConn)

	local mouseMoveConn = UserInputService.InputChanged:Connect(function(input, _)
		if not isDragging then return end
		if not dragEnabled then return end
		if introPlaying then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local currentMousePos = UserInputService:GetMouseLocation()
			local delta = currentMousePos - lastMousePosition
			lastMousePosition = currentMousePos

			-- Convert screen delta to world movement
			local rotationRad = math.rad(CAMERA_ROTATION)
			local rightDir = Vector3.new(math.cos(rotationRad), 0, -math.sin(rotationRad))
			local forwardDir = Vector3.new(math.sin(rotationRad), 0, math.cos(rotationRad))

			local zoomFactor = currentZoom / DEFAULT_ZOOM
			local moveX = -delta.X * DRAG_SENSITIVITY * zoomFactor
			local moveZ = -delta.Y * DRAG_SENSITIVITY * zoomFactor

			targetPosition = targetPosition + rightDir * moveX + forwardDir * moveZ
			targetPosition = clampPosition(targetPosition)
		end
	end)
	table.insert(connections, mouseMoveConn)

	-- Touch: pinch zoom and drag
	local touchPanConn = UserInputService.TouchPan:Connect(function(_, totalTranslation, _, _, gameProcessed)
		if gameProcessed then return end
		if not dragEnabled then return end
		if introPlaying then return end

		local rotationRad = math.rad(CAMERA_ROTATION)
		local rightDir = Vector3.new(math.cos(rotationRad), 0, -math.sin(rotationRad))
		local forwardDir = Vector3.new(math.sin(rotationRad), 0, math.cos(rotationRad))

		local zoomFactor = currentZoom / DEFAULT_ZOOM
		local moveX = -totalTranslation.X * 0.05 * zoomFactor
		local moveZ = -totalTranslation.Y * 0.05 * zoomFactor

		targetPosition = targetPosition + rightDir * moveX + forwardDir * moveZ
		targetPosition = clampPosition(targetPosition)
	end)
	table.insert(connections, touchPanConn)

	local touchPinchConn = UserInputService.TouchPinch:Connect(function(_, scale, _, _, gameProcessed)
		if gameProcessed then return end
		if introPlaying then return end

		if scale > 1 then
			CameraController._adjustZoom(-2)
		elseif scale < 1 then
			CameraController._adjustZoom(2)
		end
	end)
	table.insert(connections, touchPinchConn)

	isInitialized = true
	return CameraController
end

------------------------------------------------------------------------
-- Internal zoom adjustment
------------------------------------------------------------------------

function CameraController._adjustZoom(delta)
	targetZoom = math.clamp(targetZoom + delta, MIN_ZOOM, MAX_ZOOM)
end

------------------------------------------------------------------------
-- update (called every frame via RunService)
------------------------------------------------------------------------

function CameraController.update(dt)
	if not isInitialized then return end
	if introPlaying then return end

	camera = workspace.CurrentCamera
	if not camera then return end

	-- WASD panning
	local moveDir = Vector3.new(0, 0, 0)
	local rotationRad = math.rad(CAMERA_ROTATION)
	local rightDir = Vector3.new(math.cos(rotationRad), 0, -math.sin(rotationRad))
	local forwardDir = Vector3.new(math.sin(rotationRad), 0, math.cos(rotationRad))

	if keysDown[Enum.KeyCode.W] then
		moveDir = moveDir + forwardDir
	end
	if keysDown[Enum.KeyCode.S] then
		moveDir = moveDir - forwardDir
	end
	if keysDown[Enum.KeyCode.A] then
		moveDir = moveDir - rightDir
	end
	if keysDown[Enum.KeyCode.D] then
		moveDir = moveDir + rightDir
	end

	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
		local zoomFactor = currentZoom / DEFAULT_ZOOM
		targetPosition = targetPosition + moveDir * PAN_SPEED * zoomFactor * dt
		targetPosition = clampPosition(targetPosition)
	end

	-- Smoothly interpolate zoom
	currentZoom = currentZoom + (targetZoom - currentZoom) * math.min(1, SMOOTH_SPEED * dt)

	-- Smoothly interpolate camera position
	local targetCFrame = calculateCameraCFrame(targetPosition, currentZoom)
	camera.CFrame = camera.CFrame:Lerp(targetCFrame, math.min(1, SMOOTH_SPEED * dt))
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

function CameraController.setTarget(position)
	if typeof(position) == "Vector3" then
		targetPosition = clampPosition(Vector3.new(position.X, 0, position.Z))
	end
end

function CameraController.zoomIn()
	CameraController._adjustZoom(-ZOOM_STEP)
end

function CameraController.zoomOut()
	CameraController._adjustZoom(ZOOM_STEP)
end

function CameraController.setZoom(level)
	-- level is 1-5, maps to ZOOM_LEVELS
	level = math.clamp(level, 1, #ZOOM_LEVELS)
	targetZoom = ZOOM_LEVELS[level]
end

function CameraController.enableDrag()
	dragEnabled = true
end

function CameraController.disableDrag()
	dragEnabled = false
	isDragging = false
end

function CameraController.focusOnBuilding()
	-- Center on the player's shop (assumed to be at origin or a known position)
	-- Look for a tagged "PlayerShop" part, or default to origin
	local shop = workspace:FindFirstChild("PlayerShop", true)
	if shop then
		targetPosition = clampPosition(Vector3.new(shop.Position.X, 0, shop.Position.Z))
	else
		targetPosition = Vector3.new(0, 0, 0)
	end
	targetZoom = DEFAULT_ZOOM
end

function CameraController.setBounds(minPos, maxPos)
	BOUNDS_MIN = minPos
	BOUNDS_MAX = maxPos
end

------------------------------------------------------------------------
-- Intro cinematic sequence
------------------------------------------------------------------------

function CameraController.playIntroSequence()
	if introPlaying then return end
	introPlaying = true

	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	-- Cinematic: start far away and high, sweep across the street, then settle on the player's shop

	-- Waypoint 1: high overview
	local waypoint1Pos = Vector3.new(-40, 0, -40)
	local waypoint1Zoom = MAX_ZOOM

	-- Waypoint 2: mid sweep
	local waypoint2Pos = Vector3.new(10, 0, -10)
	local waypoint2Zoom = 55

	-- Waypoint 3: settle on shop
	local waypoint3Pos = Vector3.new(0, 0, 0)
	local waypoint3Zoom = DEFAULT_ZOOM

	-- Start at waypoint 1
	camera.CFrame = calculateCameraCFrame(waypoint1Pos, waypoint1Zoom)

	-- Tween to waypoint 2
	local duration1 = 2.0
	local startTime = tick()
	local conn1
	conn1 = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local alpha = math.clamp(elapsed / duration1, 0, 1)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

		local pos = waypoint1Pos:Lerp(waypoint2Pos, eased)
		local zoom = waypoint1Zoom + (waypoint2Zoom - waypoint1Zoom) * eased

		camera.CFrame = calculateCameraCFrame(pos, zoom)

		if alpha >= 1 then
			conn1:Disconnect()

			-- Tween to waypoint 3
			local duration2 = 1.5
			local startTime2 = tick()
			local conn2
			conn2 = RunService.Heartbeat:Connect(function()
				local elapsed2 = tick() - startTime2
				local alpha2 = math.clamp(elapsed2 / duration2, 0, 1)
				local eased2 = TweenService:GetValue(alpha2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

				local pos2 = waypoint2Pos:Lerp(waypoint3Pos, eased2)
				local zoom2 = waypoint2Zoom + (waypoint3Zoom - waypoint2Zoom) * eased2

				camera.CFrame = calculateCameraCFrame(pos2, zoom2)

				if alpha2 >= 1 then
					conn2:Disconnect()

					-- Set final state
					targetPosition = waypoint3Pos
					currentZoom = waypoint3Zoom
					targetZoom = waypoint3Zoom
					introPlaying = false
				end
			end)
		end
	end)
end

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------

function CameraController.cleanup()
	for _, conn in ipairs(connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	connections = {}
	isInitialized = false

	-- Restore default camera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end

	for key in pairs(keysDown) do
		keysDown[key] = false
	end
end

return CameraController
