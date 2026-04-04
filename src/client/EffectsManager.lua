-- EffectsManager.lua
-- Handles all visual and audio effects for Magical Herb Tycoon
-- Uses ParticleEmitter, BillboardGui, TweenService for animations

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EffectsManager = {}
EffectsManager.__index = EffectsManager

local player = Players.LocalPlayer

-- Placeholder sound asset IDs (replace with actual Roblox audio IDs)
local SOUND_IDS = {
	coin       = "rbxassetid://138081500",    -- coin/cash register
	harvest    = "rbxassetid://142082167",    -- nature/pluck
	water      = "rbxassetid://142082167",    -- water splash
	upgrade    = "rbxassetid://138081500",    -- level up
	error      = "rbxassetid://138081500",    -- error buzz
	sale       = "rbxassetid://138081500",    -- ka-ching
	npcSpawn   = "rbxassetid://142082167",    -- poof
	rankUp     = "rbxassetid://138081500",    -- fanfare
	eventStart = "rbxassetid://138081500",    -- firework
	click      = "rbxassetid://138081500",    -- UI click
	bgm_chill  = "rbxassetid://142082167",   -- chill background
	bgm_hype   = "rbxassetid://142082167",   -- hype background
}

-- Theme colors (matching UIController)
local COLORS = {
	green  = Color3.fromHex("#00ff88"),
	purple = Color3.fromHex("#b388ff"),
	orange = Color3.fromHex("#ff6b35"),
	gold   = Color3.fromRGB(255, 215, 0),
	blue   = Color3.fromRGB(80, 160, 255),
	red    = Color3.fromHex("#ff4444"),
	white  = Color3.fromRGB(255, 255, 255),
	dark   = Color3.fromHex("#1a1a2e"),
}

-- Quality colors
local QUALITY_COLORS = {
	C  = Color3.fromRGB(150, 150, 150),
	B  = Color3.fromRGB(80, 140, 255),
	A  = Color3.fromRGB(255, 200, 50),
	S  = Color3.fromRGB(180, 100, 255),
	SS = Color3.fromRGB(255, 100, 200),
}

-- Sound cache
local soundCache = {}
local currentBGM = nil
local bgmFadeConnection = nil

------------------------------------------------------------------------
-- Utility
------------------------------------------------------------------------

local function createAttachment(position)
	local part = Instance.new("Part")
	part.Name = "EffectAnchor"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace
	return part
end

local function getPlayerGui()
	return player:FindFirstChild("PlayerGui")
end

------------------------------------------------------------------------
-- Sound helpers
------------------------------------------------------------------------

local function preloadSound(name, id)
	if soundCache[name] then return end
	local sound = Instance.new("Sound")
	sound.Name = "Effect_" .. name
	sound.SoundId = id
	sound.Volume = 0.5
	sound.Parent = SoundService
	soundCache[name] = sound
end

local function playOneShotSound(name, volume, playbackSpeed)
	local template = soundCache[name]
	if not template then return end

	local clone = template:Clone()
	clone.Volume = volume or 0.5
	clone.PlaybackSpeed = playbackSpeed or 1
	clone.Parent = SoundService
	clone:Play()
	Debris:AddItem(clone, clone.TimeLength / clone.PlaybackSpeed + 1)
end

------------------------------------------------------------------------
-- EffectsManager.init
------------------------------------------------------------------------

function EffectsManager.init()
	for name, id in pairs(SOUND_IDS) do
		preloadSound(name, id)
	end
	return EffectsManager
end

------------------------------------------------------------------------
-- Coin burst effect (yellow particles flying up)
------------------------------------------------------------------------

function EffectsManager.playCoinBurst(position)
	local anchor = createAttachment(position)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CoinBurst"
	emitter.Color = ColorSequence.new(COLORS.gold)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Rate = 0
	emitter.Acceleration = Vector3.new(0, -8, 0)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.LightEmission = 0.8
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.Parent = anchor

	emitter:Emit(15)

	playOneShotSound("coin", 0.6)

	Debris:AddItem(anchor, 2)
end

------------------------------------------------------------------------
-- Harvest effect (green sparkle burst, varies by quality)
------------------------------------------------------------------------

function EffectsManager.playHarvestEffect(position, quality)
	local anchor = createAttachment(position)
	local color = QUALITY_COLORS[quality] or COLORS.green
	local particleCount = ({ C = 10, B = 15, A = 20, S = 30, SS = 40 })[quality] or 10

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "HarvestSparkle"
	emitter.Color = ColorSequence.new(color, COLORS.white)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.5)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Acceleration = Vector3.new(0, 2, 0)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.LightEmission = 1
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.Parent = anchor

	emitter:Emit(particleCount)

	playOneShotSound("harvest", 0.5)

	Debris:AddItem(anchor, 2.5)
end

------------------------------------------------------------------------
-- Water effect (blue droplet particles)
------------------------------------------------------------------------

function EffectsManager.playWaterEffect(position)
	local anchor = createAttachment(position + Vector3.new(0, 2, 0))

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WaterDroplets"
	emitter.Color = ColorSequence.new(COLORS.blue, Color3.fromRGB(120, 200, 255))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Rate = 0
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.LightEmission = 0.3
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.Parent = anchor

	emitter:Emit(20)

	playOneShotSound("water", 0.4)

	Debris:AddItem(anchor, 1.5)
end

------------------------------------------------------------------------
-- Upgrade effect (golden glow + expanding ring)
------------------------------------------------------------------------

function EffectsManager.playUpgradeEffect(position)
	local anchor = createAttachment(position)

	-- Golden glow particles
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "UpgradeGlow"
	emitter.Color = ColorSequence.new(COLORS.gold, COLORS.orange)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(3, 8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightEmission = 1
	emitter.Parent = anchor

	emitter:Emit(25)

	-- Expanding ring
	local ring = Instance.new("Part")
	ring.Name = "UpgradeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.Position = position
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = COLORS.gold
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 12, 12),
		Transparency = 1,
	}):Play()

	playOneShotSound("upgrade", 0.7)

	Debris:AddItem(anchor, 2)
	Debris:AddItem(ring, 1)
end

------------------------------------------------------------------------
-- Building upgrade effect (construction dust + flash)
------------------------------------------------------------------------

function EffectsManager.playBuildingUpgrade(position)
	local anchor = createAttachment(position)

	-- Dust cloud
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "BuildDust"
	dust.Color = ColorSequence.new(Color3.fromRGB(180, 160, 140), Color3.fromRGB(120, 110, 100))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.4, 2),
		NumberSequenceKeypoint.new(1, 3),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(1, 2.5)
	dust.Speed = NumberRange.new(5, 15)
	dust.SpreadAngle = Vector2.new(120, 120)
	dust.Rate = 0
	dust.Acceleration = Vector3.new(0, -4, 0)
	dust.RotSpeed = NumberRange.new(-60, 60)
	dust.Parent = anchor

	dust:Emit(40)

	-- Screen flash
	local gui = getPlayerGui()
	if gui then
		local flash = Instance.new("ScreenGui")
		flash.Name = "BuildFlash"
		flash.IgnoreGuiInset = true
		flash.DisplayOrder = 100
		flash.Parent = gui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = COLORS.white
		frame.BackgroundTransparency = 0.3
		frame.BorderSizePixel = 0
		frame.Parent = flash

		TweenService:Create(frame, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()

		Debris:AddItem(flash, 1)
	end

	playOneShotSound("upgrade", 0.8, 0.7)

	Debris:AddItem(anchor, 3)
end

------------------------------------------------------------------------
-- Quality reveal popup (screen center, scale + bounce)
------------------------------------------------------------------------

function EffectsManager.playQualityReveal(quality)
	local gui = getPlayerGui()
	if not gui then return end

	local color = QUALITY_COLORS[quality] or COLORS.green

	local screen = Instance.new("ScreenGui")
	screen.Name = "QualityReveal"
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 90
	screen.Parent = gui

	-- Background dim
	local dim = Instance.new("Frame")
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = COLORS.dark
	dim.BackgroundTransparency = 0.7
	dim.BorderSizePixel = 0
	dim.Parent = screen

	-- Quality text container
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, 200, 0, 120)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = COLORS.dark
	container.BackgroundTransparency = 0.2
	container.BorderSizePixel = 0
	container.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = container

	-- "Quality" label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 28)
	titleLabel.Position = UDim2.new(0, 0, 0, 12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "QUALITY"
	titleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextSize = 16
	titleLabel.Parent = container

	-- Rank letter
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Size = UDim2.new(1, 0, 0, 60)
	rankLabel.Position = UDim2.new(0, 0, 0, 40)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = quality or "C"
	rankLabel.TextColor3 = color
	rankLabel.Font = Enum.Font.GothamBold
	rankLabel.TextSize = 48
	rankLabel.Parent = container

	-- Animate: scale up + bounce
	container.Size = UDim2.new(0, 40, 0, 24)
	TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 200, 0, 120),
	}):Play()

	-- Fade out after hold
	task.delay(1.5, function()
		TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 240, 0, 140),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(rankLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(titleLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end)

	playOneShotSound("rankUp", 0.6)

	Debris:AddItem(screen, 2.5)
end

------------------------------------------------------------------------
-- Notification sounds
------------------------------------------------------------------------

function EffectsManager.playNotificationSound(notifType)
	if notifType == "sale" then
		playOneShotSound("sale", 0.5)
	elseif notifType == "harvest" then
		playOneShotSound("harvest", 0.5)
	elseif notifType == "upgrade" then
		playOneShotSound("upgrade", 0.5)
	elseif notifType == "error" then
		playOneShotSound("error", 0.4)
	else
		playOneShotSound("click", 0.3)
	end
end

------------------------------------------------------------------------
-- Sale effect (floating "+$X" text that rises and fades)
------------------------------------------------------------------------

function EffectsManager.playSaleEffect(position, amount)
	EffectsManager.createFloatingText(
		position,
		"+$" .. tostring(amount),
		COLORS.gold
	)
	playOneShotSound("sale", 0.5)
end

------------------------------------------------------------------------
-- NPC spawn effect (subtle poof)
------------------------------------------------------------------------

function EffectsManager.playNPCSpawnEffect(position)
	local anchor = createAttachment(position)

	local poof = Instance.new("ParticleEmitter")
	poof.Name = "NPCPoof"
	poof.Color = ColorSequence.new(COLORS.white, Color3.fromRGB(200, 200, 220))
	poof.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	poof.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	poof.Lifetime = NumberRange.new(0.3, 0.7)
	poof.Speed = NumberRange.new(2, 5)
	poof.SpreadAngle = Vector2.new(180, 180)
	poof.Rate = 0
	poof.LightEmission = 0.5
	poof.Parent = anchor

	poof:Emit(8)

	playOneShotSound("npcSpawn", 0.3)

	Debris:AddItem(anchor, 1)
end

------------------------------------------------------------------------
-- Event start effect (screen flash + fireworks)
------------------------------------------------------------------------

function EffectsManager.playEventStartEffect()
	-- Screen flash
	local gui = getPlayerGui()
	if gui then
		local flash = Instance.new("ScreenGui")
		flash.Name = "EventFlash"
		flash.IgnoreGuiInset = true
		flash.DisplayOrder = 95
		flash.Parent = gui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = COLORS.orange
		frame.BackgroundTransparency = 0.5
		frame.BorderSizePixel = 0
		frame.Parent = flash

		TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()

		Debris:AddItem(flash, 0.6)
	end

	-- Firework particles from above the camera
	local cam = workspace.CurrentCamera
	if cam then
		local basePos = cam.CFrame.Position + cam.CFrame.LookVector * 30 + Vector3.new(0, 15, 0)

		for i = 1, 3 do
			local offset = Vector3.new(math.random(-8, 8), math.random(-2, 4), math.random(-8, 8))
			local anchor = createAttachment(basePos + offset)

			local firework = Instance.new("ParticleEmitter")
			firework.Name = "Firework"
			firework.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, COLORS.orange),
				ColorSequenceKeypoint.new(0.5, COLORS.gold),
				ColorSequenceKeypoint.new(1, COLORS.purple),
			})
			firework.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.3, 0.6),
				NumberSequenceKeypoint.new(1, 0),
			})
			firework.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.8, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			})
			firework.Lifetime = NumberRange.new(0.5, 1.5)
			firework.Speed = NumberRange.new(6, 14)
			firework.SpreadAngle = Vector2.new(180, 180)
			firework.Rate = 0
			firework.Acceleration = Vector3.new(0, -6, 0)
			firework.LightEmission = 1
			firework.Parent = anchor

			task.delay(i * 0.3, function()
				firework:Emit(20)
			end)

			Debris:AddItem(anchor, 3)
		end
	end

	playOneShotSound("eventStart", 0.7)
end

------------------------------------------------------------------------
-- Brand rank-up celebration (full screen)
------------------------------------------------------------------------

function EffectsManager.playBrandRankUpEffect(rank)
	local gui = getPlayerGui()
	if not gui then return end

	local color = QUALITY_COLORS[rank] or COLORS.purple

	local screen = Instance.new("ScreenGui")
	screen.Name = "RankUpCelebration"
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 99
	screen.Parent = gui

	-- Background dim with gradient
	local dim = Instance.new("Frame")
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = COLORS.dark
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Parent = screen

	-- "RANK UP" text
	local rankUpLabel = Instance.new("TextLabel")
	rankUpLabel.Size = UDim2.new(1, 0, 0, 40)
	rankUpLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
	rankUpLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	rankUpLabel.BackgroundTransparency = 1
	rankUpLabel.Text = "RANK UP!"
	rankUpLabel.TextColor3 = COLORS.gold
	rankUpLabel.Font = Enum.Font.GothamBold
	rankUpLabel.TextSize = 32
	rankUpLabel.Parent = screen

	-- Rank letter (large)
	local rankLetter = Instance.new("TextLabel")
	rankLetter.Size = UDim2.new(1, 0, 0, 100)
	rankLetter.Position = UDim2.new(0.5, 0, 0.5, 0)
	rankLetter.AnchorPoint = Vector2.new(0.5, 0.5)
	rankLetter.BackgroundTransparency = 1
	rankLetter.Text = rank or "?"
	rankLetter.TextColor3 = color
	rankLetter.Font = Enum.Font.GothamBold
	rankLetter.TextSize = 80
	rankLetter.TextTransparency = 1
	rankLetter.Parent = screen

	-- Animate rank letter: fade in + scale
	TweenService:Create(rankLetter, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 80,
	}):Play()

	-- Shimmer stroke effect
	local strokeFrame = Instance.new("Frame")
	strokeFrame.Size = UDim2.new(0, 140, 0, 140)
	strokeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	strokeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	strokeFrame.BackgroundTransparency = 1
	strokeFrame.BorderSizePixel = 0
	strokeFrame.Parent = screen

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = 3
	uiStroke.Parent = strokeFrame

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0.5, 0)
	uiCorner.Parent = strokeFrame

	TweenService:Create(strokeFrame, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 400, 0, 400),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(uiStroke, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()

	-- Fade everything out
	task.delay(2, function()
		TweenService:Create(dim, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(rankUpLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(rankLetter, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)

	playOneShotSound("rankUp", 0.8)

	Debris:AddItem(screen, 3)
end

------------------------------------------------------------------------
-- Floating text (BillboardGui that floats up and fades)
------------------------------------------------------------------------

function EffectsManager.createFloatingText(position, text, color)
	local anchor = createAttachment(position)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or COLORS.white
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = COLORS.dark
	label.Parent = billboard

	-- Float upward and fade over 2 seconds
	local startPos = position
	local endPos = position + Vector3.new(0, 5, 0)

	TweenService:Create(anchor, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = endPos,
	}):Play()

	TweenService:Create(label, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	Debris:AddItem(anchor, 2.2)
end

------------------------------------------------------------------------
-- Background music with crossfade
------------------------------------------------------------------------

function EffectsManager.setBackgroundMusic(trackName)
	local soundId = SOUND_IDS["bgm_" .. trackName]
	if not soundId then
		soundId = SOUND_IDS[trackName]
	end
	if not soundId then return end

	-- Fade out current BGM
	if currentBGM then
		local oldBGM = currentBGM
		TweenService:Create(oldBGM, TweenInfo.new(1), { Volume = 0 }):Play()
		task.delay(1.1, function()
			oldBGM:Stop()
			oldBGM:Destroy()
		end)
	end

	-- Create and fade in new BGM
	local newBGM = Instance.new("Sound")
	newBGM.Name = "BGM_" .. trackName
	newBGM.SoundId = soundId
	newBGM.Volume = 0
	newBGM.Looped = true
	newBGM.Parent = SoundService
	newBGM:Play()

	TweenService:Create(newBGM, TweenInfo.new(1.5), { Volume = 0.3 }):Play()

	currentBGM = newBGM
end

------------------------------------------------------------------------
-- General one-shot sound
------------------------------------------------------------------------

function EffectsManager.playSound(soundName)
	playOneShotSound(soundName, 0.5)
end

return EffectsManager
