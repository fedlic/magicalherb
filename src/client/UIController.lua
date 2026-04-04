-- UIController.lua
-- Master UI module for Magical Herb Tycoon
-- Street/urban themed UI with neon accents

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIController = {}
UIController.__index = UIController

-- Theme colors
local COLORS = {
	bg_dark = Color3.fromHex("#1a1a2e"),
	bg_medium = Color3.fromHex("#16213e"),
	bg_light = Color3.fromHex("#0f3460"),
	accent_green = Color3.fromHex("#00ff88"),
	accent_purple = Color3.fromHex("#b388ff"),
	accent_orange = Color3.fromHex("#ff6b35"),
	text_white = Color3.fromRGB(240, 240, 240),
	text_gray = Color3.fromRGB(180, 180, 180),
	text_dim = Color3.fromRGB(120, 120, 120),
	success = Color3.fromHex("#00ff88"),
	warning = Color3.fromHex("#ffd700"),
	error = Color3.fromHex("#ff4444"),
	info = Color3.fromHex("#b388ff"),
	quality_C = Color3.fromRGB(150, 150, 150),
	quality_B = Color3.fromRGB(80, 140, 255),
	quality_A = Color3.fromRGB(255, 200, 50),
	quality_S = Color3.fromRGB(180, 100, 255),
	quality_SS = Color3.fromRGB(255, 100, 200),
	coin_gold = Color3.fromRGB(255, 215, 0),
}

local FONTS = {
	bold = Enum.Font.GothamBold,
	medium = Enum.Font.GothamMedium,
	regular = Enum.Font.Gotham,
	title = Enum.Font.GothamBold,
}

local CORNER_RADIUS = UDim.new(0, 8)
local CORNER_RADIUS_LARGE = UDim.new(0, 12)
local CORNER_RADIUS_SMALL = UDim.new(0, 4)

-- Internal state
local player = Players.LocalPlayer
local screenGui = nil
local panels = {}
local notifications = {}
local maxNotifications = 5
local currentMoney = 0
local displayedMoney = 0
local activePanel = nil
local tutorialVisible = false
local inputEnabled = true

-- Callback tables for button events
UIController.OnButtonPressed = {} -- panelName -> callback

------------------------------------------------------------------------
-- Utility helpers
------------------------------------------------------------------------

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or CORNER_RADIUS
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.accent_green
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function createPadding(parent, top, right, bottom, left)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top or 8)
	padding.PaddingRight = UDim.new(0, right or 8)
	padding.PaddingBottom = UDim.new(0, bottom or 8)
	padding.PaddingLeft = UDim.new(0, left or 8)
	padding.Parent = parent
	return padding
end

local function createListLayout(parent, direction, padding, hAlign, vAlign)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, padding or 4)
	layout.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function createGridLayout(parent, cellSize, cellPadding)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize or UDim2.new(0, 80, 0, 90)
	grid.CellPadding = cellPadding or UDim2.new(0, 6, 0, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = parent
	return grid
end

local function createFrame(props)
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Frame"
	frame.Size = props.Size or UDim2.new(1, 0, 1, 0)
	frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = props.BackgroundColor3 or COLORS.bg_dark
	frame.BackgroundTransparency = props.BackgroundTransparency or 0
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = props.ClipsDescendants or false
	frame.Visible = props.Visible ~= false
	frame.ZIndex = props.ZIndex or 1
	frame.LayoutOrder = props.LayoutOrder or 0
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

local function createText(props)
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "TextLabel"
	label.Size = props.Size or UDim2.new(1, 0, 0, 24)
	label.Position = props.Position or UDim2.new(0, 0, 0, 0)
	label.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	label.BackgroundTransparency = props.BackgroundTransparency or 1
	label.BackgroundColor3 = props.BackgroundColor3 or COLORS.bg_dark
	label.Text = props.Text or ""
	label.TextColor3 = props.TextColor3 or COLORS.text_white
	label.Font = props.Font or FONTS.medium
	label.TextSize = props.TextSize or 16
	label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	label.TextWrapped = props.TextWrapped or false
	label.BorderSizePixel = 0
	label.ZIndex = props.ZIndex or 1
	label.LayoutOrder = props.LayoutOrder or 0
	label.RichText = props.RichText or false
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

local function createButton(props)
	local btn = Instance.new("TextButton")
	btn.Name = props.Name or "Button"
	btn.Size = props.Size or UDim2.new(0, 120, 0, 36)
	btn.Position = props.Position or UDim2.new(0, 0, 0, 0)
	btn.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	btn.BackgroundColor3 = props.BackgroundColor3 or COLORS.accent_green
	btn.BackgroundTransparency = props.BackgroundTransparency or 0
	btn.Text = props.Text or "Button"
	btn.TextColor3 = props.TextColor3 or COLORS.bg_dark
	btn.Font = props.Font or FONTS.bold
	btn.TextSize = props.TextSize or 14
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.ZIndex = props.ZIndex or 2
	btn.LayoutOrder = props.LayoutOrder or 0
	if props.Parent then
		btn.Parent = props.Parent
	end
	createCorner(btn, CORNER_RADIUS_SMALL)
	return btn
end

local function createScrollFrame(props)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = props.Name or "ScrollFrame"
	scroll.Size = props.Size or UDim2.new(1, 0, 1, 0)
	scroll.Position = props.Position or UDim2.new(0, 0, 0, 0)
	scroll.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = COLORS.accent_green
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ClipsDescendants = true
	scroll.ZIndex = props.ZIndex or 1
	if props.Parent then
		scroll.Parent = props.Parent
	end
	return scroll
end

local function createGradient(parent, c1, c2, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(c1 or COLORS.bg_dark, c2 or COLORS.bg_medium)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

local function tweenProperty(instance, props, duration, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration or 0.3, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

local function formatMoney(amount)
	local formatted = tostring(math.floor(amount))
	local k = #formatted
	local result = ""
	for i = 1, k do
		if i > 1 and (k - i + 1) % 3 == 1 then
			result = result .. ","
		end
		result = result .. formatted:sub(i, i)
	end
	return "$" .. result
end

local function getQualityColor(quality)
	if quality == "SS" then return COLORS.quality_SS
	elseif quality == "S" then return COLORS.quality_S
	elseif quality == "A" then return COLORS.quality_A
	elseif quality == "B" then return COLORS.quality_B
	else return COLORS.quality_C end
end

------------------------------------------------------------------------
-- Panel: HUD (always visible)
------------------------------------------------------------------------

local hudElements = {}

local function createHUD(parent)
	-- Top bar
	local topBar = createFrame({
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = COLORS.bg_dark,
		BackgroundTransparency = 0.1,
		Parent = parent,
		ZIndex = 10,
	})
	createCorner(topBar, CORNER_RADIUS)
	createGradient(topBar, COLORS.bg_dark, COLORS.bg_medium, 0)

	-- Money display (left)
	local moneyFrame = createFrame({
		Name = "MoneyFrame",
		Size = UDim2.new(0, 200, 0, 40),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = topBar,
		ZIndex = 11,
	})
	createCorner(moneyFrame, CORNER_RADIUS_SMALL)
	createStroke(moneyFrame, COLORS.coin_gold, 1)

	local coinIcon = createText({
		Name = "CoinIcon",
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Text = "💰",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = moneyFrame,
		ZIndex = 12,
	})

	local moneyLabel = createText({
		Name = "MoneyLabel",
		Size = UDim2.new(1, -42, 1, 0),
		Position = UDim2.new(0, 38, 0, 0),
		Text = "$0",
		TextColor3 = COLORS.coin_gold,
		Font = FONTS.bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = moneyFrame,
		ZIndex = 12,
	})
	hudElements.moneyLabel = moneyLabel

	-- Brand name + rank (center)
	local brandFrame = createFrame({
		Name = "BrandFrame",
		Size = UDim2.new(0, 260, 0, 40),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = topBar,
		ZIndex = 11,
	})
	createCorner(brandFrame, CORNER_RADIUS_SMALL)
	createStroke(brandFrame, COLORS.accent_purple, 1)

	local brandLabel = createText({
		Name = "BrandLabel",
		Size = UDim2.new(0.65, 0, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		Text = "No Brand",
		TextColor3 = COLORS.text_white,
		Font = FONTS.bold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = brandFrame,
		ZIndex = 12,
	})
	hudElements.brandLabel = brandLabel

	local rankBadge = createFrame({
		Name = "RankBadge",
		Size = UDim2.new(0, 60, 0, 26),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.accent_purple,
		Parent = brandFrame,
		ZIndex = 12,
	})
	createCorner(rankBadge, CORNER_RADIUS_SMALL)

	local rankLabel = createText({
		Name = "RankLabel",
		Size = UDim2.new(1, 0, 1, 0),
		Text = "D",
		TextColor3 = COLORS.text_white,
		Font = FONTS.bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = rankBadge,
		ZIndex = 13,
	})
	hudElements.rankLabel = rankLabel
	hudElements.rankBadge = rankBadge

	-- Settings button (right)
	local settingsBtn = createButton({
		Name = "SettingsBtn",
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.bg_medium,
		Text = "⚙",
		TextColor3 = COLORS.text_white,
		TextSize = 22,
		Parent = topBar,
		ZIndex = 11,
	})
	createStroke(settingsBtn, COLORS.text_dim, 1)

	-- Bottom bar (quick action buttons)
	local bottomBar = createFrame({
		Name = "BottomBar",
		Size = UDim2.new(0, 480, 0, 56),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = COLORS.bg_dark,
		BackgroundTransparency = 0.1,
		Parent = parent,
		ZIndex = 10,
	})
	createCorner(bottomBar, CORNER_RADIUS_LARGE)
	createGradient(bottomBar, COLORS.bg_dark, COLORS.bg_medium, 0)
	createStroke(bottomBar, COLORS.accent_green, 1)

	local bottomLayout = createListLayout(bottomBar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	createPadding(bottomBar, 6, 10, 6, 10)

	local quickButtons = {
		{ name = "Inventory", icon = "📦", color = COLORS.accent_green },
		{ name = "Shop",      icon = "🛒", color = COLORS.accent_orange },
		{ name = "Upgrades",  icon = "⬆",  color = COLORS.coin_gold },
		{ name = "Staff",     icon = "👥", color = COLORS.accent_purple },
		{ name = "Brand",     icon = "🏷",  color = COLORS.accent_green },
		{ name = "Events",    icon = "🎉", color = COLORS.accent_orange },
	}

	for i, btnInfo in ipairs(quickButtons) do
		local qBtn = createFrame({
			Name = btnInfo.name .. "Btn",
			Size = UDim2.new(0, 68, 0, 44),
			BackgroundColor3 = COLORS.bg_medium,
			Parent = bottomBar,
			ZIndex = 11,
			LayoutOrder = i,
		})
		createCorner(qBtn, CORNER_RADIUS_SMALL)

		local qBtnClick = Instance.new("TextButton")
		qBtnClick.Name = "Clickable"
		qBtnClick.Size = UDim2.new(1, 0, 1, 0)
		qBtnClick.BackgroundTransparency = 1
		qBtnClick.Text = ""
		qBtnClick.ZIndex = 13
		qBtnClick.Parent = qBtn

		local iconLabel = createText({
			Name = "Icon",
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 0, 0, 2),
			Text = btnInfo.icon,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = qBtn,
			ZIndex = 12,
		})

		local nameLabel = createText({
			Name = "Label",
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.new(0, 0, 1, -18),
			Text = btnInfo.name,
			TextColor3 = btnInfo.color,
			Font = FONTS.bold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = qBtn,
			ZIndex = 12,
		})

		qBtnClick.MouseButton1Click:Connect(function()
			if not inputEnabled then return end
			if activePanel == btnInfo.name then
				UIController.hidePanel(btnInfo.name)
			else
				UIController.showPanel(btnInfo.name)
			end
		end)
	end

	panels.HUD = { topBar = topBar, bottomBar = bottomBar }
end

------------------------------------------------------------------------
-- Panel: Inventory (slide-in from right)
------------------------------------------------------------------------

local inventoryElements = {}

local function createInventoryPanel(parent)
	local panel = createFrame({
		Name = "InventoryPanel",
		Size = UDim2.new(0, 340, 0.75, 0),
		Position = UDim2.new(1, 350, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.bg_dark,
		ClipsDescendants = true,
		Parent = parent,
		Visible = false,
		ZIndex = 5,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.accent_green, 2)

	-- Header
	local header = createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(header, CORNER_RADIUS_LARGE)

	createText({
		Name = "Title",
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		Text = "INVENTORY",
		TextColor3 = COLORS.accent_green,
		Font = FONTS.title,
		TextSize = 18,
		Parent = header,
		ZIndex = 7,
	})

	local closeBtn = createButton({
		Name = "CloseBtn",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.error,
		Text = "X",
		TextColor3 = COLORS.text_white,
		TextSize = 14,
		Parent = header,
		ZIndex = 7,
	})
	closeBtn.MouseButton1Click:Connect(function()
		UIController.hidePanel("Inventory")
	end)

	-- Tab bar
	local tabBar = createFrame({
		Name = "TabBar",
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 50),
		BackgroundTransparency = 1,
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(tabBar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local tabs = { "All", "Raw", "Trimmed", "Processed" }
	inventoryElements.tabs = {}
	inventoryElements.activeTab = "All"

	for i, tabName in ipairs(tabs) do
		local tabBtn = createButton({
			Name = tabName .. "Tab",
			Size = UDim2.new(0, 72, 0, 28),
			BackgroundColor3 = (i == 1) and COLORS.accent_green or COLORS.bg_medium,
			Text = tabName,
			TextColor3 = (i == 1) and COLORS.bg_dark or COLORS.text_gray,
			TextSize = 12,
			Parent = tabBar,
			ZIndex = 7,
			LayoutOrder = i,
		})
		inventoryElements.tabs[tabName] = tabBtn

		tabBtn.MouseButton1Click:Connect(function()
			for _, t in pairs(inventoryElements.tabs) do
				t.BackgroundColor3 = COLORS.bg_medium
				t.TextColor3 = COLORS.text_gray
			end
			tabBtn.BackgroundColor3 = COLORS.accent_green
			tabBtn.TextColor3 = COLORS.bg_dark
			inventoryElements.activeTab = tabName
		end)
	end

	-- Item grid scroll
	local itemScroll = createScrollFrame({
		Name = "ItemScroll",
		Size = UDim2.new(1, -16, 1, -96),
		Position = UDim2.new(0, 8, 0, 88),
		Parent = panel,
		ZIndex = 6,
	})
	createGridLayout(itemScroll, UDim2.new(0, 74, 0, 86), UDim2.new(0, 6, 0, 6))
	inventoryElements.itemScroll = itemScroll

	panels.Inventory = panel
	inventoryElements.panel = panel
end

------------------------------------------------------------------------
-- Panel: Shop
------------------------------------------------------------------------

local shopElements = {}

local function createShopPanel(parent)
	local panel = createFrame({
		Name = "ShopPanel",
		Size = UDim2.new(0, 380, 0.8, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg_dark,
		ClipsDescendants = true,
		Parent = parent,
		Visible = false,
		ZIndex = 5,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.accent_orange, 2)

	-- Header
	local header = createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(header, CORNER_RADIUS_LARGE)

	createText({
		Name = "Title",
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		Text = "SEED SHOP",
		TextColor3 = COLORS.accent_orange,
		Font = FONTS.title,
		TextSize = 18,
		Parent = header,
		ZIndex = 7,
	})

	local closeBtn = createButton({
		Name = "CloseBtn",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.error,
		Text = "X",
		TextColor3 = COLORS.text_white,
		TextSize = 14,
		Parent = header,
		ZIndex = 7,
	})
	closeBtn.MouseButton1Click:Connect(function()
		UIController.hidePanel("Shop")
	end)

	-- Seed list scroll
	local seedScroll = createScrollFrame({
		Name = "SeedScroll",
		Size = UDim2.new(1, -16, 1, -56),
		Position = UDim2.new(0, 8, 0, 50),
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(seedScroll, Enum.FillDirection.Vertical, 6)
	createPadding(seedScroll, 4, 4, 4, 4)
	shopElements.seedScroll = seedScroll

	panels.Shop = panel
	shopElements.panel = panel
end

------------------------------------------------------------------------
-- Panel: Upgrades
------------------------------------------------------------------------

local upgradeElements = {}

local function createUpgradePanel(parent)
	local panel = createFrame({
		Name = "UpgradePanel",
		Size = UDim2.new(0, 440, 0.85, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg_dark,
		ClipsDescendants = true,
		Parent = parent,
		Visible = false,
		ZIndex = 5,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.coin_gold, 2)

	-- Header
	local header = createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(header, CORNER_RADIUS_LARGE)

	createText({
		Name = "Title",
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		Text = "UPGRADES",
		TextColor3 = COLORS.coin_gold,
		Font = FONTS.title,
		TextSize = 18,
		Parent = header,
		ZIndex = 7,
	})

	local closeBtn = createButton({
		Name = "CloseBtn",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.error,
		Text = "X",
		TextColor3 = COLORS.text_white,
		TextSize = 14,
		Parent = header,
		ZIndex = 7,
	})
	closeBtn.MouseButton1Click:Connect(function()
		UIController.hidePanel("Upgrades")
	end)

	-- Building upgrade section at top
	local buildingSection = createFrame({
		Name = "BuildingSection",
		Size = UDim2.new(1, -16, 0, 100),
		Position = UDim2.new(0, 8, 0, 50),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(buildingSection, CORNER_RADIUS)
	createStroke(buildingSection, COLORS.accent_purple, 1)

	createText({
		Name = "BuildingTitle",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 0, 6),
		Text = "BUILDING",
		TextColor3 = COLORS.accent_purple,
		Font = FONTS.bold,
		TextSize = 14,
		Parent = buildingSection,
		ZIndex = 7,
	})

	local buildingName = createText({
		Name = "BuildingName",
		Size = UDim2.new(0.5, -8, 0, 20),
		Position = UDim2.new(0, 8, 0, 32),
		Text = "Street Stand",
		TextColor3 = COLORS.text_white,
		Font = FONTS.medium,
		TextSize = 14,
		Parent = buildingSection,
		ZIndex = 7,
	})
	upgradeElements.buildingName = buildingName

	local buildingNextLabel = createText({
		Name = "NextBuilding",
		Size = UDim2.new(0.5, -8, 0, 20),
		Position = UDim2.new(0, 8, 0, 54),
		Text = "Next: Small Shop",
		TextColor3 = COLORS.text_gray,
		Font = FONTS.regular,
		TextSize = 12,
		Parent = buildingSection,
		ZIndex = 7,
	})
	upgradeElements.buildingNextLabel = buildingNextLabel

	local buildingUpgradeBtn = createButton({
		Name = "BuildingUpgradeBtn",
		Size = UDim2.new(0, 120, 0, 34),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.accent_purple,
		Text = "UPGRADE",
		TextColor3 = COLORS.text_white,
		TextSize = 13,
		Parent = buildingSection,
		ZIndex = 7,
	})
	upgradeElements.buildingUpgradeBtn = buildingUpgradeBtn

	-- Category tabs
	local tabBar = createFrame({
		Name = "UpgradeTabBar",
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 0, 156),
		BackgroundTransparency = 1,
		Parent = panel,
		ZIndex = 6,
		ClipsDescendants = true,
	})
	local tabScroll = createScrollFrame({
		Name = "TabScroll",
		Size = UDim2.new(1, 0, 1, 0),
		Parent = tabBar,
		ZIndex = 6,
	})
	tabScroll.ScrollBarThickness = 0
	tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	createListLayout(tabScroll, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local categories = { "Planter", "Processing", "Shelf", "Register", "Warehouse", "Sprinkler", "Lighting" }
	upgradeElements.categoryTabs = {}
	upgradeElements.activeCategory = "Planter"

	for i, cat in ipairs(categories) do
		local catBtn = createButton({
			Name = cat .. "Tab",
			Size = UDim2.new(0, 80, 0, 26),
			BackgroundColor3 = (i == 1) and COLORS.coin_gold or COLORS.bg_medium,
			Text = cat,
			TextColor3 = (i == 1) and COLORS.bg_dark or COLORS.text_gray,
			TextSize = 11,
			Parent = tabScroll,
			ZIndex = 7,
			LayoutOrder = i,
		})
		upgradeElements.categoryTabs[cat] = catBtn

		catBtn.MouseButton1Click:Connect(function()
			for _, t in pairs(upgradeElements.categoryTabs) do
				t.BackgroundColor3 = COLORS.bg_medium
				t.TextColor3 = COLORS.text_gray
			end
			catBtn.BackgroundColor3 = COLORS.coin_gold
			catBtn.TextColor3 = COLORS.bg_dark
			upgradeElements.activeCategory = cat
		end)
	end

	-- Upgrade list scroll
	local upgradeScroll = createScrollFrame({
		Name = "UpgradeScroll",
		Size = UDim2.new(1, -16, 1, -200),
		Position = UDim2.new(0, 8, 0, 192),
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(upgradeScroll, Enum.FillDirection.Vertical, 6)
	createPadding(upgradeScroll, 4, 4, 4, 4)
	upgradeElements.upgradeScroll = upgradeScroll

	panels.Upgrades = panel
	upgradeElements.panel = panel
end

------------------------------------------------------------------------
-- Panel: Staff
------------------------------------------------------------------------

local staffElements = {}

local function createStaffPanel(parent)
	local panel = createFrame({
		Name = "StaffPanel",
		Size = UDim2.new(0, 380, 0.75, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg_dark,
		ClipsDescendants = true,
		Parent = parent,
		Visible = false,
		ZIndex = 5,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.accent_purple, 2)

	-- Header
	local header = createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(header, CORNER_RADIUS_LARGE)

	createText({
		Name = "Title",
		Size = UDim2.new(0.6, 0, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		Text = "STAFF",
		TextColor3 = COLORS.accent_purple,
		Font = FONTS.title,
		TextSize = 18,
		Parent = header,
		ZIndex = 7,
	})

	local staffCountLabel = createText({
		Name = "StaffCount",
		Size = UDim2.new(0, 80, 1, 0),
		Position = UDim2.new(1, -50, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Text = "0/2",
		TextColor3 = COLORS.text_gray,
		Font = FONTS.medium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
		ZIndex = 7,
	})
	staffElements.staffCountLabel = staffCountLabel

	local closeBtn = createButton({
		Name = "CloseBtn",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.error,
		Text = "X",
		TextColor3 = COLORS.text_white,
		TextSize = 14,
		Parent = header,
		ZIndex = 7,
	})
	closeBtn.MouseButton1Click:Connect(function()
		UIController.hidePanel("Staff")
	end)

	-- Current staff section
	local currentLabel = createText({
		Name = "CurrentLabel",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 0, 50),
		Text = "Current Staff",
		TextColor3 = COLORS.accent_purple,
		Font = FONTS.bold,
		TextSize = 14,
		Parent = panel,
		ZIndex = 6,
	})

	local currentScroll = createScrollFrame({
		Name = "CurrentStaffScroll",
		Size = UDim2.new(1, -16, 0.35, 0),
		Position = UDim2.new(0, 8, 0, 76),
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(currentScroll, Enum.FillDirection.Vertical, 4)
	staffElements.currentScroll = currentScroll

	-- Hire section
	local hireLabel = createText({
		Name = "HireLabel",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 0.5, 10),
		Text = "Hire Staff",
		TextColor3 = COLORS.accent_green,
		Font = FONTS.bold,
		TextSize = 14,
		Parent = panel,
		ZIndex = 6,
	})

	local hireScroll = createScrollFrame({
		Name = "HireStaffScroll",
		Size = UDim2.new(1, -16, 0.35, 0),
		Position = UDim2.new(0, 8, 0.5, 36),
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(hireScroll, Enum.FillDirection.Vertical, 4)
	staffElements.hireScroll = hireScroll

	panels.Staff = panel
	staffElements.panel = panel
end

------------------------------------------------------------------------
-- Panel: Brand
------------------------------------------------------------------------

local brandElements = {}

local function createBrandPanel(parent)
	local panel = createFrame({
		Name = "BrandPanel",
		Size = UDim2.new(0, 340, 0, 320),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg_dark,
		ClipsDescendants = true,
		Parent = parent,
		Visible = false,
		ZIndex = 5,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.accent_green, 2)

	-- Header
	local header = createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(header, CORNER_RADIUS_LARGE)

	createText({
		Name = "Title",
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		Text = "BRAND",
		TextColor3 = COLORS.accent_green,
		Font = FONTS.title,
		TextSize = 18,
		Parent = header,
		ZIndex = 7,
	})

	local closeBtn = createButton({
		Name = "CloseBtn",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.error,
		Text = "X",
		TextColor3 = COLORS.text_white,
		TextSize = 14,
		Parent = header,
		ZIndex = 7,
	})
	closeBtn.MouseButton1Click:Connect(function()
		UIController.hidePanel("Brand")
	end)

	-- Brand name input
	local nameFrame = createFrame({
		Name = "NameFrame",
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.new(0, 8, 0, 52),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(nameFrame, CORNER_RADIUS)

	local nameInput = Instance.new("TextBox")
	nameInput.Name = "BrandNameInput"
	nameInput.Size = UDim2.new(0.65, -8, 0, 32)
	nameInput.Position = UDim2.new(0, 8, 0.5, 0)
	nameInput.AnchorPoint = Vector2.new(0, 0.5)
	nameInput.BackgroundColor3 = COLORS.bg_light
	nameInput.TextColor3 = COLORS.text_white
	nameInput.PlaceholderText = "Enter brand name..."
	nameInput.PlaceholderColor3 = COLORS.text_dim
	nameInput.Font = FONTS.medium
	nameInput.TextSize = 14
	nameInput.BorderSizePixel = 0
	nameInput.ClearTextOnFocus = false
	nameInput.ZIndex = 7
	nameInput.Parent = nameFrame
	createCorner(nameInput, CORNER_RADIUS_SMALL)
	brandElements.nameInput = nameInput

	local setNameBtn = createButton({
		Name = "SetNameBtn",
		Size = UDim2.new(0.3, 0, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.accent_green,
		Text = "SET",
		TextSize = 13,
		Parent = nameFrame,
		ZIndex = 7,
	})
	brandElements.setNameBtn = setNameBtn

	-- Rank display
	local rankFrame = createFrame({
		Name = "RankFrame",
		Size = UDim2.new(1, -16, 0, 80),
		Position = UDim2.new(0, 8, 0, 104),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(rankFrame, CORNER_RADIUS)

	createText({
		Name = "RankTitle",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 8, 0, 6),
		Text = "Current Rank",
		TextColor3 = COLORS.text_gray,
		Font = FONTS.regular,
		TextSize = 12,
		Parent = rankFrame,
		ZIndex = 7,
	})

	local brandRankLabel = createText({
		Name = "RankValue",
		Size = UDim2.new(0, 60, 0, 36),
		Position = UDim2.new(0, 8, 0, 28),
		Text = "D",
		TextColor3 = COLORS.accent_purple,
		Font = FONTS.bold,
		TextSize = 28,
		Parent = rankFrame,
		ZIndex = 7,
	})
	brandElements.rankLabel = brandRankLabel

	-- Progress bar
	local progressBg = createFrame({
		Name = "ProgressBg",
		Size = UDim2.new(0.55, 0, 0, 16),
		Position = UDim2.new(0, 80, 0, 40),
		BackgroundColor3 = COLORS.bg_light,
		Parent = rankFrame,
		ZIndex = 7,
	})
	createCorner(progressBg, CORNER_RADIUS_SMALL)

	local progressFill = createFrame({
		Name = "ProgressFill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = COLORS.accent_purple,
		Parent = progressBg,
		ZIndex = 8,
	})
	createCorner(progressFill, CORNER_RADIUS_SMALL)
	brandElements.progressFill = progressFill

	local progressText = createText({
		Name = "ProgressText",
		Size = UDim2.new(1, 0, 1, 0),
		Text = "0 / 100",
		TextColor3 = COLORS.text_white,
		Font = FONTS.bold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = progressBg,
		ZIndex = 9,
	})
	brandElements.progressText = progressText

	-- Bonus info
	local bonusFrame = createFrame({
		Name = "BonusFrame",
		Size = UDim2.new(1, -16, 0, 80),
		Position = UDim2.new(0, 8, 0, 192),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(bonusFrame, CORNER_RADIUS)

	createText({
		Name = "BonusTitle",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 8, 0, 6),
		Text = "Brand Bonuses",
		TextColor3 = COLORS.accent_green,
		Font = FONTS.bold,
		TextSize = 12,
		Parent = bonusFrame,
		ZIndex = 7,
	})

	local bonusText = createText({
		Name = "BonusText",
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.new(0, 8, 0, 26),
		Text = "No bonuses yet. Increase your rank!",
		TextColor3 = COLORS.text_gray,
		Font = FONTS.regular,
		TextSize = 12,
		TextWrapped = true,
		Parent = bonusFrame,
		ZIndex = 7,
	})
	brandElements.bonusText = bonusText

	panels.Brand = panel
	brandElements.panel = panel
end

------------------------------------------------------------------------
-- Panel: Events
------------------------------------------------------------------------

local eventElements = {}

local function createEventPanel(parent)
	local panel = createFrame({
		Name = "EventPanel",
		Size = UDim2.new(0, 400, 0.75, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg_dark,
		ClipsDescendants = true,
		Parent = parent,
		Visible = false,
		ZIndex = 5,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.accent_orange, 2)

	-- Header
	local header = createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(header, CORNER_RADIUS_LARGE)

	createText({
		Name = "Title",
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		Text = "EVENTS",
		TextColor3 = COLORS.accent_orange,
		Font = FONTS.title,
		TextSize = 18,
		Parent = header,
		ZIndex = 7,
	})

	local closeBtn = createButton({
		Name = "CloseBtn",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.error,
		Text = "X",
		TextColor3 = COLORS.text_white,
		TextSize = 14,
		Parent = header,
		ZIndex = 7,
	})
	closeBtn.MouseButton1Click:Connect(function()
		UIController.hidePanel("Events")
	end)

	-- Active event timer
	local activeEventFrame = createFrame({
		Name = "ActiveEventFrame",
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.new(0, 8, 0, 50),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		Visible = false,
		ZIndex = 6,
	})
	createCorner(activeEventFrame, CORNER_RADIUS)
	createStroke(activeEventFrame, COLORS.accent_green, 1)

	local activeEventLabel = createText({
		Name = "ActiveLabel",
		Size = UDim2.new(0.6, 0, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		Text = "Active: None",
		TextColor3 = COLORS.accent_green,
		Font = FONTS.bold,
		TextSize = 14,
		Parent = activeEventFrame,
		ZIndex = 7,
	})
	eventElements.activeEventLabel = activeEventLabel

	local activeTimerLabel = createText({
		Name = "TimerLabel",
		Size = UDim2.new(0.35, 0, 1, 0),
		Position = UDim2.new(0.6, 0, 0, 0),
		Text = "00:00",
		TextColor3 = COLORS.coin_gold,
		Font = FONTS.bold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = activeEventFrame,
		ZIndex = 7,
	})
	eventElements.activeTimerLabel = activeTimerLabel
	eventElements.activeEventFrame = activeEventFrame

	-- Event cards scroll
	local eventScroll = createScrollFrame({
		Name = "EventScroll",
		Size = UDim2.new(1, -16, 1, -116),
		Position = UDim2.new(0, 8, 0, 108),
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(eventScroll, Enum.FillDirection.Vertical, 8)
	createPadding(eventScroll, 4, 4, 4, 4)
	eventElements.eventScroll = eventScroll

	panels.Events = panel
	eventElements.panel = panel
end

------------------------------------------------------------------------
-- Panel: Processing
------------------------------------------------------------------------

local processingElements = {}

local function createProcessingPanel(parent)
	local panel = createFrame({
		Name = "ProcessingPanel",
		Size = UDim2.new(0, 420, 0.8, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg_dark,
		ClipsDescendants = true,
		Parent = parent,
		Visible = false,
		ZIndex = 5,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.accent_green, 2)

	-- Header
	local header = createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 6,
	})
	createCorner(header, CORNER_RADIUS_LARGE)

	createText({
		Name = "Title",
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		Text = "PROCESSING",
		TextColor3 = COLORS.accent_green,
		Font = FONTS.title,
		TextSize = 18,
		Parent = header,
		ZIndex = 7,
	})

	local closeBtn = createButton({
		Name = "CloseBtn",
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.error,
		Text = "X",
		TextColor3 = COLORS.text_white,
		TextSize = 14,
		Parent = header,
		ZIndex = 7,
	})
	closeBtn.MouseButton1Click:Connect(function()
		UIController.hidePanel("Processing")
	end)

	-- Active slots section
	createText({
		Name = "ActiveTitle",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 0, 50),
		Text = "Active Slots",
		TextColor3 = COLORS.accent_purple,
		Font = FONTS.bold,
		TextSize = 14,
		Parent = panel,
		ZIndex = 6,
	})

	local slotsFrame = createFrame({
		Name = "SlotsFrame",
		Size = UDim2.new(1, -16, 0, 110),
		Position = UDim2.new(0, 8, 0, 76),
		BackgroundTransparency = 1,
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(slotsFrame, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	processingElements.slotsFrame = slotsFrame

	-- Recipes section
	createText({
		Name = "RecipeTitle",
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 0, 192),
		Text = "Recipes",
		TextColor3 = COLORS.accent_orange,
		Font = FONTS.bold,
		TextSize = 14,
		Parent = panel,
		ZIndex = 6,
	})

	local recipeScroll = createScrollFrame({
		Name = "RecipeScroll",
		Size = UDim2.new(1, -16, 1, -228),
		Position = UDim2.new(0, 8, 0, 218),
		Parent = panel,
		ZIndex = 6,
	})
	createListLayout(recipeScroll, Enum.FillDirection.Vertical, 6)
	createPadding(recipeScroll, 4, 4, 4, 4)
	processingElements.recipeScroll = recipeScroll

	panels.Processing = panel
	processingElements.panel = panel
end

------------------------------------------------------------------------
-- Tutorial Dialog
------------------------------------------------------------------------

local tutorialElements = {}

local function createTutorialDialog(parent)
	local panel = createFrame({
		Name = "TutorialDialog",
		Size = UDim2.new(0, 520, 0, 140),
		Position = UDim2.new(0.5, 0, 1, -70),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = COLORS.bg_dark,
		Parent = parent,
		Visible = false,
		ZIndex = 20,
	})
	createCorner(panel, CORNER_RADIUS_LARGE)
	createStroke(panel, COLORS.accent_purple, 2)

	-- Portrait area (left)
	local portrait = createFrame({
		Name = "Portrait",
		Size = UDim2.new(0, 100, 0, 100),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = panel,
		ZIndex = 21,
	})
	createCorner(portrait, CORNER_RADIUS)
	createStroke(portrait, COLORS.accent_purple, 1)

	local portraitPlaceholder = createText({
		Name = "PortraitIcon",
		Size = UDim2.new(1, 0, 1, 0),
		Text = "🧙",
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = portrait,
		ZIndex = 22,
	})

	-- Name label
	local nameLabel = createText({
		Name = "SageName",
		Size = UDim2.new(0, 200, 0, 22),
		Position = UDim2.new(0, 122, 0, 8),
		Text = "DJ Sage",
		TextColor3 = COLORS.accent_purple,
		Font = FONTS.bold,
		TextSize = 16,
		Parent = panel,
		ZIndex = 21,
	})

	-- Dialog text
	local dialogText = createText({
		Name = "DialogText",
		Size = UDim2.new(1, -142, 0, 70),
		Position = UDim2.new(0, 122, 0, 30),
		Text = "",
		TextColor3 = COLORS.text_white,
		Font = FONTS.regular,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
		ZIndex = 21,
	})
	tutorialElements.dialogText = dialogText

	-- Step dots
	local dotsFrame = createFrame({
		Name = "StepDots",
		Size = UDim2.new(0, 100, 0, 14),
		Position = UDim2.new(0, 122, 1, -22),
		BackgroundTransparency = 1,
		Parent = panel,
		ZIndex = 21,
	})
	createListLayout(dotsFrame, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	tutorialElements.dotsFrame = dotsFrame

	-- Next button
	local nextBtn = createButton({
		Name = "NextBtn",
		Size = UDim2.new(0, 90, 0, 30),
		Position = UDim2.new(1, -12, 1, -12),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = COLORS.accent_green,
		Text = "Next",
		TextColor3 = COLORS.bg_dark,
		TextSize = 14,
		Parent = panel,
		ZIndex = 21,
	})
	tutorialElements.nextBtn = nextBtn

	panels.Tutorial = panel
	tutorialElements.panel = panel
end

------------------------------------------------------------------------
-- Notification system
------------------------------------------------------------------------

local notificationContainer = nil

local function createNotificationContainer(parent)
	notificationContainer = createFrame({
		Name = "NotificationContainer",
		Size = UDim2.new(0, 300, 0, 300),
		Position = UDim2.new(1, -12, 0, 56),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = parent,
		ZIndex = 30,
	})
	createListLayout(notificationContainer, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
end

------------------------------------------------------------------------
-- Planter floating UI creator (called per planter)
------------------------------------------------------------------------

local function createPlanterUI(planterPart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlanterUI"
	billboard.Size = UDim2.new(0, 160, 0, 90)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Active = true
	billboard.Adornee = planterPart
	billboard.Parent = planterPart

	local frame = createFrame({
		Name = "PlanterFrame",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = COLORS.bg_dark,
		BackgroundTransparency = 0.15,
		Parent = billboard,
	})
	createCorner(frame, CORNER_RADIUS)
	createPadding(frame, 4, 6, 4, 6)

	-- Stage name
	local stageLabel = createText({
		Name = "StageLabel",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "Empty",
		TextColor3 = COLORS.text_gray,
		Font = FONTS.bold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})

	-- Progress bar bg
	local progressBg = createFrame({
		Name = "ProgressBg",
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 0, 20),
		BackgroundColor3 = COLORS.bg_light,
		Parent = frame,
	})
	createCorner(progressBg, CORNER_RADIUS_SMALL)

	local progressFill = createFrame({
		Name = "ProgressFill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = COLORS.accent_green,
		Parent = progressBg,
	})
	createCorner(progressFill, CORNER_RADIUS_SMALL)

	-- Quality indicator
	local qualityLabel = createText({
		Name = "QualityLabel",
		Size = UDim2.new(0.5, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 34),
		Text = "",
		TextColor3 = COLORS.quality_C,
		Font = FONTS.bold,
		TextSize = 11,
		Parent = frame,
	})

	-- Water button
	local waterBtn = createButton({
		Name = "WaterBtn",
		Size = UDim2.new(0.45, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -4),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(60, 140, 255),
		Text = "💧 Water",
		TextColor3 = COLORS.text_white,
		TextSize = 10,
		Parent = frame,
	})
	waterBtn.Visible = false

	-- Harvest button
	local harvestBtn = createButton({
		Name = "HarvestBtn",
		Size = UDim2.new(0.45, 0, 0, 22),
		Position = UDim2.new(1, 0, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = COLORS.coin_gold,
		Text = "🌿 Harvest",
		TextColor3 = COLORS.bg_dark,
		TextSize = 10,
		Parent = frame,
	})
	harvestBtn.Visible = false

	return billboard
end

------------------------------------------------------------------------
-- UIController.init
------------------------------------------------------------------------

function UIController.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MagicalHerbUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	createHUD(screenGui)
	createInventoryPanel(screenGui)
	createShopPanel(screenGui)
	createUpgradePanel(screenGui)
	createStaffPanel(screenGui)
	createBrandPanel(screenGui)
	createEventPanel(screenGui)
	createProcessingPanel(screenGui)
	createTutorialDialog(screenGui)
	createNotificationContainer(screenGui)

	return UIController
end

------------------------------------------------------------------------
-- UIController.update (call every frame or on heartbeat)
------------------------------------------------------------------------

function UIController.update(dt)
	-- Animate money counter
	if displayedMoney ~= currentMoney then
		local diff = currentMoney - displayedMoney
		local step = math.max(1, math.abs(diff) * dt * 5)
		if math.abs(diff) < 2 then
			displayedMoney = currentMoney
		elseif diff > 0 then
			displayedMoney = math.min(displayedMoney + step, currentMoney)
		else
			displayedMoney = math.max(displayedMoney - step, currentMoney)
		end
		if hudElements.moneyLabel then
			hudElements.moneyLabel.Text = formatMoney(displayedMoney)
		end
	end
end

------------------------------------------------------------------------
-- Panel show/hide with animation
------------------------------------------------------------------------

function UIController.showPanel(panelName)
	if activePanel and activePanel ~= panelName then
		UIController.hidePanel(activePanel)
	end

	local panel = panels[panelName]
	if not panel then return end

	panel.Visible = true
	activePanel = panelName

	-- Slide-in animation for inventory (from right)
	if panelName == "Inventory" then
		panel.Position = UDim2.new(1, 350, 0.5, 0)
		tweenProperty(panel, { Position = UDim2.new(1, -8, 0.5, 0) }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	else
		-- Scale pop for center panels
		panel.Size = UDim2.new(panel.Size.X.Scale * 0.9, math.floor(panel.Size.X.Offset * 0.9), panel.Size.Y.Scale * 0.9, math.floor(panel.Size.Y.Offset * 0.9))
		panel.BackgroundTransparency = 0.5
		local targetSize = nil
		if panelName == "Shop" then
			targetSize = UDim2.new(0, 380, 0.8, 0)
		elseif panelName == "Upgrades" then
			targetSize = UDim2.new(0, 440, 0.85, 0)
		elseif panelName == "Staff" then
			targetSize = UDim2.new(0, 380, 0.75, 0)
		elseif panelName == "Brand" then
			targetSize = UDim2.new(0, 340, 0, 320)
		elseif panelName == "Events" then
			targetSize = UDim2.new(0, 400, 0.75, 0)
		elseif panelName == "Processing" then
			targetSize = UDim2.new(0, 420, 0.8, 0)
		end
		if targetSize then
			tweenProperty(panel, { Size = targetSize, BackgroundTransparency = 0 }, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end
end

function UIController.hidePanel(panelName)
	local panel = panels[panelName]
	if not panel then return end

	if panelName == "Inventory" then
		local tween = tweenProperty(panel, { Position = UDim2.new(1, 350, 0.5, 0) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Connect(function()
			panel.Visible = false
		end)
	else
		local tween = tweenProperty(panel, { BackgroundTransparency = 0.5 }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Connect(function()
			panel.Visible = false
		end)
	end

	if activePanel == panelName then
		activePanel = nil
	end
end

------------------------------------------------------------------------
-- Notifications
------------------------------------------------------------------------

function UIController.showNotification(text, notifType)
	if not notificationContainer then return end

	local color = COLORS.info
	if notifType == "success" then color = COLORS.success
	elseif notifType == "warning" then color = COLORS.warning
	elseif notifType == "error" then color = COLORS.error
	elseif notifType == "info" then color = COLORS.info end

	-- Remove oldest if at max
	local children = notificationContainer:GetChildren()
	local notifCount = 0
	for _, c in ipairs(children) do
		if c:IsA("Frame") then notifCount = notifCount + 1 end
	end
	if notifCount >= maxNotifications then
		for _, c in ipairs(children) do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end

	local notif = createFrame({
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = COLORS.bg_medium,
		Parent = notificationContainer,
		ZIndex = 31,
	})
	createCorner(notif, CORNER_RADIUS)
	createStroke(notif, color, 1.5)

	local colorBar = createFrame({
		Name = "ColorBar",
		Size = UDim2.new(0, 4, 0.7, 0),
		Position = UDim2.new(0, 6, 0.15, 0),
		BackgroundColor3 = color,
		Parent = notif,
		ZIndex = 32,
	})
	createCorner(colorBar, UDim.new(0, 2))

	createText({
		Name = "NotifText",
		Size = UDim2.new(1, -22, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		Text = text,
		TextColor3 = COLORS.text_white,
		Font = FONTS.medium,
		TextSize = 13,
		TextWrapped = true,
		Parent = notif,
		ZIndex = 32,
	})

	-- Slide in
	notif.Position = UDim2.new(1, 0, 0, 0)
	tweenProperty(notif, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	-- Auto dismiss after 3 seconds
	task.delay(3, function()
		if notif and notif.Parent then
			local tween = tweenProperty(notif, { Position = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween.Completed:Connect(function()
				if notif and notif.Parent then
					notif:Destroy()
				end
			end)
		end
	end)
end

------------------------------------------------------------------------
-- Update functions
------------------------------------------------------------------------

function UIController.updateMoney(amount)
	currentMoney = amount
end

function UIController.updateInventory(inventoryData)
	if not inventoryElements.itemScroll then return end

	-- Clear existing items
	for _, child in ipairs(inventoryElements.itemScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if not inventoryData then return end

	for i, item in ipairs(inventoryData) do
		-- Filter by tab
		local tab = inventoryElements.activeTab
		if tab ~= "All" and item.category ~= tab then continue end

		local slot = createFrame({
			Name = "Slot_" .. i,
			Size = UDim2.new(0, 74, 0, 86),
			BackgroundColor3 = COLORS.bg_medium,
			Parent = inventoryElements.itemScroll,
			ZIndex = 7,
			LayoutOrder = i,
		})
		createCorner(slot, CORNER_RADIUS_SMALL)
		createStroke(slot, COLORS.bg_light, 1)

		-- Item icon placeholder
		createText({
			Name = "Icon",
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.new(0, 0, 0, 4),
			Text = item.icon or "🌿",
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = slot,
			ZIndex = 8,
		})

		-- Quality badge
		local qColor = getQualityColor(item.quality or "C")
		local qualityBadge = createFrame({
			Name = "QualityBadge",
			Size = UDim2.new(0, 22, 0, 14),
			Position = UDim2.new(1, -2, 0, 2),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = qColor,
			Parent = slot,
			ZIndex = 9,
		})
		createCorner(qualityBadge, CORNER_RADIUS_SMALL)

		createText({
			Name = "QualityText",
			Size = UDim2.new(1, 0, 1, 0),
			Text = item.quality or "C",
			TextColor3 = COLORS.text_white,
			Font = FONTS.bold,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = qualityBadge,
			ZIndex = 10,
		})

		-- Item name
		createText({
			Name = "ItemName",
			Size = UDim2.new(1, -4, 0, 16),
			Position = UDim2.new(0, 2, 0, 42),
			Text = item.name or "Item",
			TextColor3 = COLORS.text_white,
			Font = FONTS.medium,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Parent = slot,
			ZIndex = 8,
		})

		-- Quantity
		createText({
			Name = "Quantity",
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.new(0, 0, 1, -18),
			Text = "x" .. tostring(item.quantity or 0),
			TextColor3 = COLORS.text_gray,
			Font = FONTS.medium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = slot,
			ZIndex = 8,
		})

		-- Click handler
		local clickBtn = Instance.new("TextButton")
		clickBtn.Name = "ClickHandler"
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.ZIndex = 11
		clickBtn.Parent = slot

		clickBtn.MouseButton1Click:Connect(function()
			if UIController.OnButtonPressed.InventoryItem then
				UIController.OnButtonPressed.InventoryItem(item)
			end
		end)
	end
end

function UIController.updateShelves(shelfData)
	-- Shelf data updates would be handled through BillboardGuis on shelf parts.
	-- This is a hook for when shelf contents change in the data model.
	if not shelfData then return end
	-- Emit event for external handlers
	if UIController.OnButtonPressed.ShelfUpdated then
		UIController.OnButtonPressed.ShelfUpdated(shelfData)
	end
end

function UIController.updatePlants(plantData)
	-- Updates planter BillboardGui displays.
	-- plantData is a table keyed by planterId.
	if not plantData then return end

	for planterId, data in pairs(plantData) do
		local planter = workspace:FindFirstChild(planterId, true)
		if not planter then continue end

		local billboard = planter:FindFirstChild("PlanterUI")
		if not billboard then
			billboard = createPlanterUI(planter)
		end

		local frame = billboard:FindFirstChild("PlanterFrame")
		if not frame then continue end

		local stageLabel = frame:FindFirstChild("StageLabel")
		if stageLabel then
			stageLabel.Text = data.stage or "Empty"
		end

		local progressBg = frame:FindFirstChild("ProgressBg")
		if progressBg then
			local fill = progressBg:FindFirstChild("ProgressFill")
			if fill then
				local pct = math.clamp(data.progress or 0, 0, 1)
				tweenProperty(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.3)
			end
		end

		local qualityLabel = frame:FindFirstChild("QualityLabel")
		if qualityLabel and data.quality then
			qualityLabel.Text = "Quality: " .. data.quality
			qualityLabel.TextColor3 = getQualityColor(data.quality)
		end

		local waterBtn = frame:FindFirstChild("WaterBtn")
		if waterBtn then
			waterBtn.Visible = (data.canWater == true)
		end

		local harvestBtn = frame:FindFirstChild("HarvestBtn")
		if harvestBtn then
			harvestBtn.Visible = (data.canHarvest == true)
		end
	end
end

------------------------------------------------------------------------
-- Tutorial
------------------------------------------------------------------------

function UIController.showTutorial(step, text)
	local panel = panels.Tutorial
	if not panel then return end

	panel.Visible = true
	tutorialVisible = true

	if tutorialElements.dialogText then
		tutorialElements.dialogText.Text = text or ""
	end

	-- Update step dots
	if tutorialElements.dotsFrame then
		for _, child in ipairs(tutorialElements.dotsFrame:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local totalSteps = step and math.max(step, 5) or 5
		for i = 1, totalSteps do
			local dot = createFrame({
				Name = "Dot" .. i,
				Size = UDim2.new(0, 8, 0, 8),
				BackgroundColor3 = (i <= (step or 1)) and COLORS.accent_purple or COLORS.bg_light,
				Parent = tutorialElements.dotsFrame,
				LayoutOrder = i,
			})
			createCorner(dot, UDim.new(0.5, 0))
		end
	end

	-- Animate in
	panel.Position = UDim2.new(0.5, 0, 1, 20)
	tweenProperty(panel, { Position = UDim2.new(0.5, 0, 1, -70) }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function UIController.hideTutorial()
	local panel = panels.Tutorial
	if not panel then return end

	tutorialVisible = false
	local tween = tweenProperty(panel, { Position = UDim2.new(0.5, 0, 1, 20) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween.Completed:Connect(function()
		panel.Visible = false
	end)
end

------------------------------------------------------------------------
-- Building upgrade panel display
------------------------------------------------------------------------

function UIController.showBuildingUpgrade(options)
	if not upgradeElements.buildingName then return end

	if options.currentBuilding then
		upgradeElements.buildingName.Text = options.currentBuilding
	end
	if options.nextBuilding then
		upgradeElements.buildingNextLabel.Text = "Next: " .. options.nextBuilding
	end

	UIController.showPanel("Upgrades")
end

------------------------------------------------------------------------
-- Processing panel display
------------------------------------------------------------------------

function UIController.showProcessing(recipes, slots)
	if not processingElements.recipeScroll then return end

	-- Clear existing recipe entries
	for _, child in ipairs(processingElements.recipeScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- Populate recipes
	if recipes then
		for i, recipe in ipairs(recipes) do
			local row = createFrame({
				Name = "Recipe_" .. i,
				Size = UDim2.new(1, 0, 0, 70),
				BackgroundColor3 = COLORS.bg_medium,
				Parent = processingElements.recipeScroll,
				ZIndex = 7,
				LayoutOrder = i,
			})
			createCorner(row, CORNER_RADIUS)
			createPadding(row, 6, 8, 6, 8)

			createText({
				Name = "RecipeName",
				Size = UDim2.new(0.6, 0, 0, 18),
				Text = recipe.name or "Recipe",
				TextColor3 = COLORS.accent_green,
				Font = FONTS.bold,
				TextSize = 13,
				Parent = row,
				ZIndex = 8,
			})

			-- Ingredients list
			local ingredientStr = ""
			if recipe.ingredients then
				local parts = {}
				for _, ing in ipairs(recipe.ingredients) do
					table.insert(parts, ing.name .. " x" .. tostring(ing.amount))
				end
				ingredientStr = table.concat(parts, ", ")
			end

			createText({
				Name = "Ingredients",
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 0, 20),
				Text = "Needs: " .. ingredientStr,
				TextColor3 = COLORS.text_gray,
				Font = FONTS.regular,
				TextSize = 11,
				TextWrapped = true,
				Parent = row,
				ZIndex = 8,
			})

			createText({
				Name = "CraftTime",
				Size = UDim2.new(0.5, 0, 0, 14),
				Position = UDim2.new(0, 0, 0, 36),
				Text = "Time: " .. tostring(recipe.craftTime or 30) .. "s",
				TextColor3 = COLORS.text_dim,
				Font = FONTS.regular,
				TextSize = 10,
				Parent = row,
				ZIndex = 8,
			})

			local craftBtn = createButton({
				Name = "CraftBtn",
				Size = UDim2.new(0, 70, 0, 26),
				Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = COLORS.accent_green,
				Text = "CRAFT",
				TextSize = 11,
				Parent = row,
				ZIndex = 9,
			})

			craftBtn.MouseButton1Click:Connect(function()
				if UIController.OnButtonPressed.CraftRecipe then
					UIController.OnButtonPressed.CraftRecipe(recipe)
				end
			end)
		end
	end

	-- Update active slots
	for _, child in ipairs(processingElements.slotsFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if slots then
		for i, slot in ipairs(slots) do
			local slotFrame = createFrame({
				Name = "Slot_" .. i,
				Size = UDim2.new(0, 120, 0, 100),
				BackgroundColor3 = COLORS.bg_medium,
				Parent = processingElements.slotsFrame,
				ZIndex = 7,
				LayoutOrder = i,
			})
			createCorner(slotFrame, CORNER_RADIUS)
			createStroke(slotFrame, slot.finished and COLORS.accent_green or COLORS.bg_light, 1)

			createText({
				Name = "SlotName",
				Size = UDim2.new(1, -8, 0, 16),
				Position = UDim2.new(0, 4, 0, 4),
				Text = slot.name or "Empty",
				TextColor3 = COLORS.text_white,
				Font = FONTS.bold,
				TextSize = 11,
				Parent = slotFrame,
				ZIndex = 8,
			})

			-- Progress bar
			local slotProgressBg = createFrame({
				Name = "ProgressBg",
				Size = UDim2.new(1, -12, 0, 8),
				Position = UDim2.new(0, 6, 0, 26),
				BackgroundColor3 = COLORS.bg_light,
				Parent = slotFrame,
				ZIndex = 8,
			})
			createCorner(slotProgressBg, CORNER_RADIUS_SMALL)

			local slotProgress = createFrame({
				Name = "ProgressFill",
				Size = UDim2.new(math.clamp(slot.progress or 0, 0, 1), 0, 1, 0),
				BackgroundColor3 = COLORS.accent_green,
				Parent = slotProgressBg,
				ZIndex = 9,
			})
			createCorner(slotProgress, CORNER_RADIUS_SMALL)

			local timerLabel = createText({
				Name = "Timer",
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.new(0, 0, 0, 38),
				Text = slot.timeLeft or "",
				TextColor3 = COLORS.text_gray,
				Font = FONTS.medium,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = slotFrame,
				ZIndex = 8,
			})

			if slot.finished then
				local collectBtn = createButton({
					Name = "CollectBtn",
					Size = UDim2.new(0.8, 0, 0, 24),
					Position = UDim2.new(0.5, 0, 1, -6),
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = COLORS.coin_gold,
					Text = "COLLECT",
					TextColor3 = COLORS.bg_dark,
					TextSize = 11,
					Parent = slotFrame,
					ZIndex = 9,
				})
				collectBtn.MouseButton1Click:Connect(function()
					if UIController.OnButtonPressed.CollectProcessing then
						UIController.OnButtonPressed.CollectProcessing(i)
					end
				end)
			end
		end
	end

	UIController.showPanel("Processing")
end

------------------------------------------------------------------------
-- Brand panel display
------------------------------------------------------------------------

function UIController.showBrandPanel(brandInfo)
	if not brandElements.panel then return end

	if brandInfo then
		if brandInfo.name and brandInfo.name ~= "" then
			brandElements.nameInput.Text = brandInfo.name
			hudElements.brandLabel.Text = brandInfo.name
		end
		if brandInfo.rank then
			brandElements.rankLabel.Text = brandInfo.rank
			hudElements.rankLabel.Text = brandInfo.rank
		end
		if brandInfo.score and brandInfo.maxScore then
			local pct = math.clamp(brandInfo.score / brandInfo.maxScore, 0, 1)
			tweenProperty(brandElements.progressFill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.3)
			brandElements.progressText.Text = tostring(brandInfo.score) .. " / " .. tostring(brandInfo.maxScore)
		end
		if brandInfo.bonusDescription then
			brandElements.bonusText.Text = brandInfo.bonusDescription
		end
	end

	UIController.showPanel("Brand")
end

------------------------------------------------------------------------
-- Event panel display
------------------------------------------------------------------------

function UIController.showEventPanel(events)
	if not eventElements.eventScroll then return end

	for _, child in ipairs(eventElements.eventScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if events then
		for i, evt in ipairs(events) do
			local card = createFrame({
				Name = "Event_" .. i,
				Size = UDim2.new(1, 0, 0, 110),
				BackgroundColor3 = COLORS.bg_medium,
				Parent = eventElements.eventScroll,
				ZIndex = 7,
				LayoutOrder = i,
			})
			createCorner(card, CORNER_RADIUS)
			createStroke(card, COLORS.accent_orange, 1)
			createPadding(card, 8, 10, 8, 10)

			-- Event type label
			createText({
				Name = "EventType",
				Size = UDim2.new(0.6, 0, 0, 20),
				Text = evt.name or "Event",
				TextColor3 = COLORS.accent_orange,
				Font = FONTS.bold,
				TextSize = 15,
				Parent = card,
				ZIndex = 8,
			})

			-- Cost
			createText({
				Name = "Cost",
				Size = UDim2.new(0.35, 0, 0, 18),
				Position = UDim2.new(0.65, 0, 0, 2),
				Text = "Cost: $" .. tostring(evt.cost or 0),
				TextColor3 = COLORS.coin_gold,
				Font = FONTS.medium,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = card,
				ZIndex = 8,
			})

			-- Duration
			createText({
				Name = "Duration",
				Size = UDim2.new(0.5, 0, 0, 16),
				Position = UDim2.new(0, 0, 0, 24),
				Text = "Duration: " .. tostring(evt.duration or 60) .. "s",
				TextColor3 = COLORS.text_gray,
				Font = FONTS.regular,
				TextSize = 11,
				Parent = card,
				ZIndex = 8,
			})

			-- Effects
			createText({
				Name = "Effects",
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.new(0, 0, 0, 42),
				Text = evt.effects or "Boosts customer traffic.",
				TextColor3 = COLORS.text_white,
				Font = FONTS.regular,
				TextSize = 11,
				TextWrapped = true,
				Parent = card,
				ZIndex = 8,
			})

			-- Requirements
			if evt.requirements then
				createText({
					Name = "Requirements",
					Size = UDim2.new(0.6, 0, 0, 14),
					Position = UDim2.new(0, 0, 1, -28),
					Text = "Req: " .. evt.requirements,
					TextColor3 = COLORS.text_dim,
					Font = FONTS.regular,
					TextSize = 10,
					Parent = card,
					ZIndex = 8,
				})
			end

			local meetsReq = evt.meetsRequirements ~= false
			local startBtn = createButton({
				Name = "StartBtn",
				Size = UDim2.new(0, 80, 0, 28),
				Position = UDim2.new(1, -10, 1, -8),
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = meetsReq and COLORS.accent_orange or COLORS.text_dim,
				Text = "START",
				TextColor3 = meetsReq and COLORS.text_white or COLORS.text_gray,
				TextSize = 12,
				Parent = card,
				ZIndex = 9,
			})

			if meetsReq then
				startBtn.MouseButton1Click:Connect(function()
					if UIController.OnButtonPressed.StartEvent then
						UIController.OnButtonPressed.StartEvent(evt)
					end
				end)
			end
		end
	end

	UIController.showPanel("Events")
end

------------------------------------------------------------------------
-- Staff panel display
------------------------------------------------------------------------

function UIController.showStaffPanel(staff, maxStaff)
	if not staffElements.panel then return end

	staffElements.staffCountLabel.Text = tostring(#(staff or {})) .. "/" .. tostring(maxStaff or 2)

	-- Clear current staff list
	for _, child in ipairs(staffElements.currentScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if staff then
		for i, member in ipairs(staff) do
			local row = createFrame({
				Name = "Staff_" .. i,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = COLORS.bg_medium,
				Parent = staffElements.currentScroll,
				ZIndex = 7,
				LayoutOrder = i,
			})
			createCorner(row, CORNER_RADIUS_SMALL)
			createPadding(row, 4, 8, 4, 8)

			createText({
				Name = "Role",
				Size = UDim2.new(0.4, 0, 1, 0),
				Text = member.role or "Worker",
				TextColor3 = COLORS.accent_purple,
				Font = FONTS.bold,
				TextSize = 13,
				Parent = row,
				ZIndex = 8,
			})

			createText({
				Name = "Salary",
				Size = UDim2.new(0.3, 0, 1, 0),
				Position = UDim2.new(0.4, 0, 0, 0),
				Text = "$" .. tostring(member.salary or 0) .. "/min",
				TextColor3 = COLORS.coin_gold,
				Font = FONTS.medium,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = row,
				ZIndex = 8,
			})

			local fireBtn = createButton({
				Name = "FireBtn",
				Size = UDim2.new(0, 50, 0, 24),
				Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = COLORS.error,
				Text = "FIRE",
				TextColor3 = COLORS.text_white,
				TextSize = 10,
				Parent = row,
				ZIndex = 9,
			})

			fireBtn.MouseButton1Click:Connect(function()
				if UIController.OnButtonPressed.FireStaff then
					UIController.OnButtonPressed.FireStaff(member)
				end
			end)
		end
	end

	UIController.showPanel("Staff")
end

------------------------------------------------------------------------
-- Getters / Utility
------------------------------------------------------------------------

function UIController.getScreenGui()
	return screenGui
end

function UIController.isInputEnabled()
	return inputEnabled
end

function UIController.setInputEnabled(enabled)
	inputEnabled = enabled
end

function UIController.getTutorialNextButton()
	return tutorialElements.nextBtn
end

function UIController.getBrandSetNameButton()
	return brandElements.setNameBtn
end

function UIController.getBrandNameInput()
	return brandElements.nameInput
end

function UIController.getBuildingUpgradeButton()
	return upgradeElements.buildingUpgradeBtn
end

return UIController
