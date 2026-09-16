--!strict
-- TSB Advanced Hub - Standalone Rewrite
-- Single LocalScript
--
-- UI/state:
--   - dynamic scrolling
--   - sliders with immediate click/drag updates
--   - synchronized keybinds
--   - respawn handling
--   - centralized cleanup
--
-- Runtime:
--   - Auto Block
--   - Aimlock
--   - Hitbox Expander
--   - WalkSpeed
--   - Auto Dash
--   - Fly
--   - Noclip
--   - Tech keybind state

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------

local Config = {
	AutoBlock = false,
	AutoBlockRange = 18,

	HitboxExpander = false,
	HitboxSize = 8,

	Aimlock = false,
	AimPrediction = 0.14,

	NoDashCooldown = false,
	AutoDash = false,

	WalkSpeedEnabled = false,
	WalkSpeed = 16,

	Fly = false,
	FlySpeed = 50,
	Noclip = false,
}

local Tech = {
	LoopDash = {
		Enabled = false,
		Key = Enum.KeyCode.Q,
		Interval = 0.16,
	},

	SupaTech = {
		Enabled = false,
		Key = Enum.KeyCode.E,
		Interval = 0.30,
	},

	OreoDash = {
		Enabled = false,
		Key = Enum.KeyCode.R,
		Interval = 0.25,
	},

	LethalDash = {
		Enabled = false,
		Key = Enum.KeyCode.T,
		Interval = 0.28,
	},
}

----------------------------------------------------------------
-- RUNTIME STATE
----------------------------------------------------------------

local Character = LocalPlayer.Character
local Humanoid: Humanoid? = nil
local RootPart: BasePart? = nil

local Camera = workspace.CurrentCamera

local isBlocking = false
local lastBlock = 0
local lastAutoDash = 0

local flyBV: BodyVelocity? = nil
local flyBG: BodyGyro? = nil

local lastTech = {
	LoopDash = 0,
	SupaTech = 0,
	OreoDash = 0,
	LethalDash = 0,
}

local originalPartState = {}
local originalWalkSpeed: number? = nil

local destroyed = false

----------------------------------------------------------------
-- CONNECTIONS
----------------------------------------------------------------

local connections = {}
local uiConnections = {}

local function connect(signal, callback, list)
	local connection = signal:Connect(callback)
	table.insert(list or connections, connection)
	return connection
end

local function disconnectList(list)
	for _, connection in ipairs(list) do
		if connection.Connected then
			connection:Disconnect()
		end
	end

	table.clear(list)
end

----------------------------------------------------------------
-- STATE LISTENERS
----------------------------------------------------------------

local configListeners = {}
local techListeners = {}

local function emitConfigChanged(name, value)
	for _, callback in ipairs(configListeners) do
		task.spawn(callback, name, value, Config)
	end
end

local function emitTechChanged(name)
	local entry = Tech[name]

	if not entry then
		return
	end

	for _, callback in ipairs(techListeners) do
		task.spawn(callback, name, entry)
	end
end

local function OnConfigChanged(callback)
	table.insert(configListeners, callback)

	return {
		Disconnect = function()
			local index = table.find(configListeners, callback)

			if index then
				table.remove(configListeners, index)
			end
		end,
	}
end

local function OnTechChanged(callback)
	table.insert(techListeners, callback)

	return {
		Disconnect = function()
			local index = table.find(techListeners, callback)

			if index then
				table.remove(techListeners, index)
			end
		end,
	}
end

local function SetConfig(name, value)
	if Config[name] == nil then
		warn("[TSB] Unknown config:", name)
		return
	end

	Config[name] = value
	emitConfigChanged(name, value)
end

local function SetTechEnabled(name, enabled)
	local entry = Tech[name]

	if not entry then
		return
	end

	entry.Enabled = enabled
	emitTechChanged(name)
end

local function ToggleTech(name)
	local entry = Tech[name]

	if not entry then
		return
	end

	SetTechEnabled(name, not entry.Enabled)
end

local function SetTechKey(name, key)
	local entry = Tech[name]

	if not entry then
		return
	end

	entry.Key = key
	emitTechChanged(name)
end

----------------------------------------------------------------
-- CHARACTER MANAGEMENT
----------------------------------------------------------------

local function updateCharacter(character)
	Character = character
	Humanoid = character:FindFirstChildOfClass("Humanoid")
	RootPart = character:FindFirstChild("HumanoidRootPart")

	originalWalkSpeed = Humanoid and Humanoid.WalkSpeed or nil

	if flyBV then
		flyBV:Destroy()
		flyBV = nil
	end

	if flyBG then
		flyBG:Destroy()
		flyBG = nil
	end
end

if Character then
	updateCharacter(Character)
end

connect(
	LocalPlayer.CharacterAdded,
	function(character)
		task.wait()

		if destroyed then
			return
		end

		updateCharacter(character)
		emitConfigChanged("__CharacterAdded", character)
	end
)

connect(
	workspace:GetPropertyChangedSignal("CurrentCamera"),
	function()
		Camera = workspace.CurrentCamera
	end
)

local function refreshCharacterReferences()
	if not Character then
		return
	end

	if not Character.Parent then
		Character = LocalPlayer.Character
	end

	if not Character then
		Humanoid = nil
		RootPart = nil
		return
	end

	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")
end

----------------------------------------------------------------
-- TARGETING
----------------------------------------------------------------

local function getClosest(range: number)
	refreshCharacterReferences()

	if not RootPart then
		return nil
	end

	local bestPlayer = nil
	local bestDistance = range

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character

			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				local humanoid = character:FindFirstChildOfClass("Humanoid")

				if root and humanoid and humanoid.Health > 0 then
					local distance =
						(root.Position - RootPart.Position).Magnitude

					if distance < bestDistance then
						bestDistance = distance
						bestPlayer = player
					end
				end
			end
		end
	end

	return bestPlayer
end

----------------------------------------------------------------
-- ATTACK DETECTION
----------------------------------------------------------------

local function isAttackTrack(track: AnimationTrack)
	if not track or not track.IsPlaying then
		return false
	end

	local name = string.lower(track.Name or "")

	local attackNames = {
		"attack",
		"m1",
		"punch",
		"skill",
		"ability",
		"combo",
		"slash",
		"hit",
		"strike",
		"barrage",
		"upper",
		"slam",
		"grab",
		"throw",
		"ultimate",
	}

	for _, pattern in ipairs(attackNames) do
		if string.find(name, pattern, 1, true) then
			return track.TimePosition < 0.5
		end
	end

	return false
end

----------------------------------------------------------------
-- KEY SIMULATION
----------------------------------------------------------------

local function tapKey(keyCode: Enum.KeyCode)
	if destroyed then
		return
	end

	pcall(function()
		VirtualInputManager:SendKeyEvent(
			true,
			keyCode,
			false,
			game
		)

		task.delay(0.03, function()
			if destroyed then
				return
			end

			VirtualInputManager:SendKeyEvent(
				false,
				keyCode,
				false,
				game
			)
		end)
	end)
end

----------------------------------------------------------------
-- AUTO BLOCK
----------------------------------------------------------------

connect(
	RunService.Heartbeat,
	function()
		if destroyed or not Config.AutoBlock then
			return
		end

		if isBlocking then
			return
		end

		local now = time()

		if now - lastBlock < 0.4 then
			return
		end

		local target = getClosest(Config.AutoBlockRange)

		if not target then
			return
		end

		local character = target.Character

		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if not humanoid then
			return
		end

		local animator = humanoid:FindFirstChildOfClass("Animator")

		if not animator then
			return
		end

		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if isAttackTrack(track) then
				isBlocking = true
				lastBlock = now

				pcall(function()
					VirtualInputManager:SendKeyEvent(
						true,
						Enum.KeyCode.F,
						false,
						game
					)
				end)

				task.delay(0.8, function()
					if destroyed then
						return
					end

					pcall(function()
						VirtualInputManager:SendKeyEvent(
							false,
							Enum.KeyCode.F,
							false,
							game
						)
					end)

					isBlocking = false
				end)

				break
			end
		end
	end
)

----------------------------------------------------------------
-- AIMLOCK
----------------------------------------------------------------

connect(
	RunService.RenderStepped,
	function()
		if destroyed or not Config.Aimlock then
			return
		end

		Camera = workspace.CurrentCamera

		if not Camera then
			return
		end

		local target = getClosest(200)

		if not target or not target.Character then
			return
		end

		local targetPart =
			target.Character:FindFirstChild("Head")
			or target.Character:FindFirstChild("HumanoidRootPart")

		if not targetPart or not targetPart:IsA("BasePart") then
			return
		end

		local predictedPosition =
			targetPart.Position
			+ targetPart.AssemblyLinearVelocity * Config.AimPrediction

		Camera.CFrame = CFrame.new(
			Camera.CFrame.Position,
			predictedPosition
		)
	end
)

----------------------------------------------------------------
-- HITBOX STATE
----------------------------------------------------------------

local function savePartState(part)
	if originalPartState[part] then
		return
	end

	originalPartState[part] = {
		Size = part.Size,
		Transparency = part.Transparency,
		CanCollide = part.CanCollide,
	}
end

local function restorePartState()
	for part, state in pairs(originalPartState) do
		if part and part.Parent then
			part.Size = state.Size
			part.Transparency = state.Transparency
			part.CanCollide = state.CanCollide
		end
	end

	table.clear(originalPartState)
end

connect(
	RunService.Heartbeat,
	function()
		if destroyed then
			return
		end

		if not Config.HitboxExpander then
			restorePartState()
			return
		end

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local character = player.Character

				if character then
					local root = character:FindFirstChild("HumanoidRootPart")

					if root and root:IsA("BasePart") then
						savePartState(root)

						root.Size = Vector3.new(
							Config.HitboxSize,
							Config.HitboxSize,
							Config.HitboxSize
						)

						root.Transparency = 0.6
						root.CanCollide = false
					end
				end
			end
		end
	end
)

----------------------------------------------------------------
-- WALKSPEED
----------------------------------------------------------------

connect(
	RunService.Heartbeat,
	function()
		if destroyed then
			return
		end

		refreshCharacterReferences()

		if not Humanoid then
			return
		end

		if Config.WalkSpeedEnabled then
			if originalWalkSpeed == nil then
				originalWalkSpeed = Humanoid.WalkSpeed
			end

			Humanoid.WalkSpeed = Config.WalkSpeed
		elseif originalWalkSpeed ~= nil then
			if math.abs(Humanoid.WalkSpeed - Config.WalkSpeed) < 0.01 then
				Humanoid.WalkSpeed = originalWalkSpeed
			end
		end
	end
)

----------------------------------------------------------------
-- AUTO DASH
----------------------------------------------------------------

connect(
	RunService.Heartbeat,
	function()
		if destroyed or not Config.AutoDash then
			return
		end

		local now = time()

		if now - lastAutoDash < 0.25 then
			return
		end

		lastAutoDash = now
		tapKey(Enum.KeyCode.Q)
	end
)

----------------------------------------------------------------
-- FLY
----------------------------------------------------------------

local function destroyFlyObjects()
	if flyBV then
		flyBV:Destroy()
		flyBV = nil
	end

	if flyBG then
		flyBG:Destroy()
		flyBG = nil
	end
end

connect(
	RunService.RenderStepped,
	function()
		if destroyed then
			destroyFlyObjects()
			return
		end

		refreshCharacterReferences()

		if not Config.Fly or not RootPart then
			destroyFlyObjects()
			return
		end

		Camera = workspace.CurrentCamera

		if not Camera then
			return
		end

		if not flyBV then
			flyBV = Instance.new("BodyVelocity")
			flyBV.Name = "TSB_FlyVelocity"
			flyBV.MaxForce = Vector3.new(
				9e9,
				9e9,
				9e9
			)
			flyBV.Parent = RootPart
		end

		if flyBV.Parent ~= RootPart then
			flyBV.Parent = RootPart
		end

		if not flyBG then
			flyBG = Instance.new("BodyGyro")
			flyBG.Name = "TSB_FlyGyro"
			flyBG.MaxTorque = Vector3.new(
				9e9,
				9e9,
				9e9
			)
			flyBG.P = 9e4
			flyBG.Parent = RootPart
		end

		if flyBG.Parent ~= RootPart then
			flyBG.Parent = RootPart
		end

		flyBG.CFrame = Camera.CFrame

		local direction = Vector3.zero

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			direction += Camera.CFrame.LookVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			direction -= Camera.CFrame.LookVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			direction -= Camera.CFrame.RightVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			direction += Camera.CFrame.RightVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			direction += Vector3.yAxis
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			direction -= Vector3.yAxis
		end

		if direction.Magnitude > 0.01 then
			flyBV.Velocity =
				direction.Unit * Config.FlySpeed
		else
			flyBV.Velocity = Vector3.zero
		end
	end
)

----------------------------------------------------------------
-- NOCLIP
----------------------------------------------------------------

connect(
	RunService.Stepped,
	function()
		if destroyed or not Config.Noclip then
			return
		end

		refreshCharacterReferences()

		if not Character then
			return
		end

		for _, object in ipairs(Character:GetDescendants()) do
			if object:IsA("BasePart") then
				object.CanCollide = false
			end
		end
	end
)

----------------------------------------------------------------
-- TECH EXECUTION
----------------------------------------------------------------

connect(
	RunService.Heartbeat,
	function()
		if destroyed or not Character then
			return
		end

		local now = time()

		for name, entry in pairs(Tech) do
			if entry.Enabled then
				local previous = lastTech[name] or 0

				if now - previous >= entry.Interval then
					lastTech[name] = now
					tapKey(Enum.KeyCode.Q)
				end
			end
		end
	end
)

----------------------------------------------------------------
-- TECH HOTKEYS
----------------------------------------------------------------

connect(
	UserInputService.InputBegan,
	function(input, gameProcessed)
		if destroyed or gameProcessed then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		for name, entry in pairs(Tech) do
			if input.KeyCode == entry.Key then
				ToggleTech(name)
			end
		end
	end
)

----------------------------------------------------------------
-- UI
----------------------------------------------------------------

local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("TSBHub")

if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TSBHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer.PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(340, 500)
main.Position = UDim2.new(0.5, -170, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

----------------------------------------------------------------
-- TITLE BAR
----------------------------------------------------------------

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -55, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "TSB Advanced Hub"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -35, 0, 3)
close.BackgroundTransparency = 1
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 80, 80)
close.Font = Enum.Font.GothamBold
close.TextSize = 22
close.Parent = titleBar

----------------------------------------------------------------
-- DRAG
----------------------------------------------------------------

do
	local dragging = false
	local dragStart
	local startPosition

	connect(
		titleBar.InputBegan,
		function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPosition = main.Position
			end
		end,
		uiConnections
	)

	connect(
		UserInputService.InputChanged,
		function(input)
			if not dragging then
				return
			end

			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local delta = input.Position - dragStart

			main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end,
		uiConnections
	)

	connect(
		UserInputService.InputEnded,
		function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end,
		uiConnections
	)
end

----------------------------------------------------------------
-- SCROLL
----------------------------------------------------------------

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -50)
scroll.Position = UDim2.fromOffset(8, 42)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

----------------------------------------------------------------
-- UI HELPERS
----------------------------------------------------------------

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function createSection(text)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 28)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	frame.BorderSizePixel = 0
	frame.Parent = scroll

	createCorner(frame, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(200, 200, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame
end

local function createToggle(name, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	frame.BorderSizePixel = 0
	frame.Parent = scroll

	createCorner(frame, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -65, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(44, 22)
	button.Position = UDim2.new(1, -52, 0.5, -11)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.Parent = frame

	createCorner(button, 4)

	local state = default

	local function render(value)
		state = value

		button.Text = value and "ON" or "OFF"

		button.BackgroundColor3 =
			value
			and Color3.fromRGB(80, 180, 80)
			or Color3.fromRGB(60, 60, 70)
	end

	render(default)

	connect(
		button.MouseButton1Click,
		function()
			render(not state)
			callback(state)
		end,
		uiConnections
	)
end

local function createSlider(name, minimum, maximum, default, callback)
	default = math.clamp(default, minimum, maximum)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 50)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	frame.BorderSizePixel = 0
	frame.Parent = scroll

	createCorner(frame, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 0, 20)
	label.Position = UDim2.fromOffset(10, 4)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -20, 0, 8)
	bar.Position = UDim2.fromOffset(10, 30)
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	bar.BorderSizePixel = 0
	bar.Active = true
	bar.Parent = frame

	createCorner(bar, 4)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(100, 140, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	createCorner(fill, 4)

	local dragging = false
	local currentValue = default

	local function render(value, callCallback)
		currentValue =
			math.clamp(
				math.round(value),
				minimum,
				maximum
			)

		local alpha =
			(currentValue - minimum)
			/ math.max(maximum - minimum, 1)

		fill.Size = UDim2.new(alpha, 0, 1, 0)

		label.Text =
			name .. ": " .. tostring(currentValue)

		if callCallback then
			callback(currentValue)
		end
	end

	local function updateFromX(x)
		local width = bar.AbsoluteSize.X

		if width <= 0 then
			return
		end

		local alpha =
			math.clamp(
				(x - bar.AbsolutePosition.X) / width,
				0,
				1
			)

		local value =
			minimum
			+ (maximum - minimum) * alpha

		render(value, true)
	end

	render(default, false)

	connect(
		bar.InputBegan,
		function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				updateFromX(input.Position.X)
			end
		end,
		uiConnections
	)

	connect(
		UserInputService.InputChanged,
		function(input)
			if dragging and
				input.UserInputType == Enum.UserInputType.MouseMovement then

				updateFromX(input.Position.X)
			end
		end,
		uiConnections
	)

	connect(
		UserInputService.InputEnded,
		function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end,
		uiConnections
	)
end

----------------------------------------------------------------
-- TECH UI
----------------------------------------------------------------

local techControls = {}

local function createTechControl(name, entry)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	frame.BorderSizePixel = 0
	frame.Parent = scroll

	createCorner(frame, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.42, 0, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local keyButton = Instance.new("TextButton")
	keyButton.Size = UDim2.fromOffset(55, 22)
	keyButton.Position = UDim2.new(0.45, 0, 0.5, -11)
	keyButton.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	keyButton.TextColor3 = Color3.fromRGB(200, 200, 255)
	keyButton.Font = Enum.Font.GothamBold
	keyButton.TextSize = 11
	keyButton.BorderSizePixel = 0
	keyButton.Parent = frame

	createCorner(keyButton, 4)

	local toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.fromOffset(44, 22)
	toggleButton.Position = UDim2.new(1, -52, 0.5, -11)
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.TextSize = 11
	toggleButton.BorderSizePixel = 0
	toggleButton.Parent = frame

	createCorner(toggleButton, 4)

	local listening = false

	local function render()
		keyButton.Text = entry.Key.Name

		toggleButton.Text =
			entry.Enabled and "ON" or "OFF"

		toggleButton.BackgroundColor3 =
			entry.Enabled
			and Color3.fromRGB(80, 180, 80)
			or Color3.fromRGB(60, 60, 70)
	end

	render()

	connect(
		keyButton.MouseButton1Click,
		function()
			listening = true

			keyButton.Text = "..."
			keyButton.BackgroundColor3 =
				Color3.fromRGB(100, 80, 40)
		end,
		uiConnections
	)

	connect(
		UserInputService.InputBegan,
		function(input)
			if not listening then
				return
			end

			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end

			if input.KeyCode == Enum.KeyCode.Escape then
				listening = false
				render()
				return
			end

			SetTechKey(name, input.KeyCode)

			listening = false
			render()
		end,
		uiConnections
	)

	connect(
		toggleButton.MouseButton1Click,
		function()
			ToggleTech(name)
		end,
		uiConnections
	)

	techControls[name] = {
		Render = render,
		KeyButton = keyButton,
		ToggleButton = toggleButton,
	}
end

OnTechChanged(function(name)
	local control = techControls[name]

	if control then
		control.Render()
	end
end)

----------------------------------------------------------------
-- BUILD UI
----------------------------------------------------------------

createSection("Combat")

createToggle(
	"Auto Block / Perfect Block",
	false,
	function(value)
		SetConfig("AutoBlock", value)
	end
)

createSlider(
	"Auto Block Range",
	5,
	40,
	18,
	function(value)
		SetConfig("AutoBlockRange", value)
	end
)

createToggle(
	"Hitbox Expander",
	false,
	function(value)
		SetConfig("HitboxExpander", value)
	end
)

createSlider(
	"Hitbox Size",
	2,
	25,
	8,
	function(value)
		SetConfig("HitboxSize", value)
	end
)

createToggle(
	"Aimlock / Camlock",
	false,
	function(value)
		SetConfig("Aimlock", value)
	end
)

createSlider(
	"Aim Prediction",
	0,
	30,
	14,
	function(value)
		SetConfig("AimPrediction", value / 100)
	end
)

createSection("Movement")

createToggle(
	"No Dash Cooldown",
	false,
	function(value)
		SetConfig("NoDashCooldown", value)
	end
)

createToggle(
	"Auto Dash",
	false,
	function(value)
		SetConfig("AutoDash", value)
	end
)

createToggle(
	"WalkSpeed Enabled",
	false,
	function(value)
		SetConfig("WalkSpeedEnabled", value)
	end
)

createSlider(
	"WalkSpeed",
	16,
	200,
	16,
	function(value)
		SetConfig("WalkSpeed", value)
	end
)

createToggle(
	"Fly",
	false,
	function(value)
		SetConfig("Fly", value)

		if not value then
			destroyFlyObjects()
		end
	end
)

createSlider(
	"Fly Speed",
	20,
	150,
	50,
	function(value)
		SetConfig("FlySpeed", value)
	end
)

createToggle(
	"Noclip",
	false,
	function(value)
		SetConfig("Noclip", value)
	end
)

createSection("Tech (Keybindable)")

for name, entry in pairs(Tech) do
	createTechControl(name, entry)
end

----------------------------------------------------------------
-- CLEANUP
----------------------------------------------------------------

local function Destroy()
	if destroyed then
		return
	end

	destroyed = true

	Config.Fly = false
	Config.Noclip = false
	Config.HitboxExpander = false

	restorePartState()
	destroyFlyObjects()

	disconnectList(uiConnections)
	disconnectList(connections)

	table.clear(configListeners)
	table.clear(techListeners)

	if gui then
		gui:Destroy()
	end

	print("[TSB] Destroyed")
end

connect(
	close.MouseButton1Click,
	Destroy,
	uiConnections
)

----------------------------------------------------------------
-- STATE EXPORT
----------------------------------------------------------------

_G.TSBHub = {
	Config = Config,
	Tech = Tech,

	GetCharacter = function()
		return Character
	end,

	GetHumanoid = function()
		return Humanoid
	end,

	GetRootPart = function()
		return RootPart
	end,

	SetConfig = SetConfig,
	GetConfig = function(name)
		return Config[name]
	end,

	SetTechEnabled = SetTechEnabled,
	ToggleTech = ToggleTech,
	SetTechKey = SetTechKey,

	OnConfigChanged = OnConfigChanged,
	OnTechChanged = OnTechChanged,

	Destroy = Destroy,
}

----------------------------------------------------------------
-- STARTUP
----------------------------------------------------------------

print("[TSB] Advanced Hub loaded")
print("[TSB] GUI:", gui:GetFullName())
