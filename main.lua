--!strict
-- TSB UI / State Management
-- Reusable Roblox Luau module.
--
-- Responsibilities:
--   * Centralized configuration/state
--   * UI construction
--   * Dynamic scrolling
--   * Slider dragging
--   * Keybind capture
--   * Keybind <-> toggle synchronization
--   * Character respawn tracking
--   * Connection cleanup
--   * Full teardown

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local TSBUiState = {}
TSBUiState.__index = TSBUiState

export type Config = {
	AutoBlock: boolean,
	AutoBlockRange: number,

	HitboxExpander: boolean,
	HitboxSize: number,

	Aimlock: boolean,
	AimPrediction: number,

	NoDashCooldown: boolean,
	AutoDash: boolean,

	WalkSpeedEnabled: boolean,
	WalkSpeed: number,

	Fly: boolean,
	FlySpeed: number,
	Noclip: boolean,
}

export type TechEntry = {
	Enabled: boolean,
	Key: Enum.KeyCode,
}

export type TechConfig = {
	LoopDash: TechEntry,
	SupaTech: TechEntry,
	OreoDash: TechEntry,
	LethalDash: TechEntry,
}

type ConnectionList = { RBXScriptConnection }

local DEFAULT_CONFIG: Config = {
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

local DEFAULT_TECH: TechConfig = {
	LoopDash = {
		Enabled = false,
		Key = Enum.KeyCode.Q,
	},

	SupaTech = {
		Enabled = false,
		Key = Enum.KeyCode.E,
	},

	OreoDash = {
		Enabled = false,
		Key = Enum.KeyCode.R,
	},

	LethalDash = {
		Enabled = false,
		Key = Enum.KeyCode.T,
	},
}

local function cloneTable<T>(source: T): T
	local result = table.clone(source :: any)

	for key, value in pairs(result :: any) do
		if type(value) == "table" then
			(result :: any)[key] = cloneTable(value)
		end
	end

	return result
end

local function createCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function disconnectAll(connections: ConnectionList)
	for _, connection in ipairs(connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end

	table.clear(connections)
end

local function clampNumber(value: number, minimum: number, maximum: number): number
	return math.clamp(value, minimum, maximum)
end

function TSBUiState.new(initialConfig: Config?, initialTech: TechConfig?)
	local self = setmetatable({}, TSBUiState)

	self.Config = initialConfig and cloneTable(initialConfig) or cloneTable(DEFAULT_CONFIG)
	self.Tech = initialTech and cloneTable(initialTech) or cloneTable(DEFAULT_TECH)

	self._connections = {} :: ConnectionList
	self._uiConnections = {} :: ConnectionList

	self._destroyed = false
	self.Character = LocalPlayer.Character

	self._changeListeners = {}
	self._techListeners = {}

	self:_watchCharacter()

	return self
end

----------------------------------------------------------------
-- Connection management
----------------------------------------------------------------

function TSBUiState:_connect(signal, callback, targetList: ConnectionList?)
	if self._destroyed then
		return nil
	end

	local connection = signal:Connect(callback)

	table.insert(
		targetList or self._connections,
		connection
	)

	return connection
end

----------------------------------------------------------------
-- State events
----------------------------------------------------------------

function TSBUiState:OnConfigChanged(callback)
	assert(type(callback) == "function", "callback must be a function")

	table.insert(self._changeListeners, callback)

	return {
		Disconnect = function()
			local index = table.find(self._changeListeners, callback)

			if index then
				table.remove(self._changeListeners, index)
			end
		end,
	}
end

function TSBUiState:OnTechChanged(callback)
	assert(type(callback) == "function", "callback must be a function")

	table.insert(self._techListeners, callback)

	return {
		Disconnect = function()
			local index = table.find(self._techListeners, callback)

			if index then
				table.remove(self._techListeners, index)
			end
		end,
	}
end

function TSBUiState:_emitConfigChanged(name, value)
	for _, callback in ipairs(self._changeListeners) do
		task.spawn(callback, name, value, self.Config)
	end
end

function TSBUiState:_emitTechChanged(name, entry)
	for _, callback in ipairs(self._techListeners) do
		task.spawn(callback, name, entry)
	end
end

function TSBUiState:SetConfig(name: string, value)
	if self._destroyed then
		return
	end

	if self.Config[name] == nil then
		warn(("Unknown config key: %s"):format(name))
		return
	end

	self.Config[name] = value
	self:_emitConfigChanged(name, value)
end

function TSBUiState:GetConfig(name: string)
	return self.Config[name]
end

function TSBUiState:SetTechEnabled(name: string, enabled: boolean)
	local entry = self.Tech[name]

	if not entry then
		warn(("Unknown tech key: %s"):format(name))
		return
	end

	entry.Enabled = enabled
	self:_emitTechChanged(name, entry)
end

function TSBUiState:ToggleTech(name: string)
	local entry = self.Tech[name]

	if not entry then
		warn(("Unknown tech key: %s"):format(name))
		return
	end

	self:SetTechEnabled(name, not entry.Enabled)
end

function TSBUiState:SetTechKey(name: string, keyCode: Enum.KeyCode)
	local entry = self.Tech[name]

	if not entry then
		warn(("Unknown tech key: %s"):format(name))
		return
	end

	entry.Key = keyCode
	self:_emitTechChanged(name, entry)
end

----------------------------------------------------------------
-- Character lifecycle
----------------------------------------------------------------

function TSBUiState:_watchCharacter()
	self:_connect(
		LocalPlayer.CharacterAdded,
		function(character)
			if self._destroyed then
				return
			end

			self.Character = character
			self:_emitConfigChanged("__CharacterAdded", character)
		end
	)
end

function TSBUiState:GetCharacter(): Model?
	return self.Character
end

function TSBUiState:GetHumanoid(): Humanoid?
	local character = self.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function TSBUiState:GetRootPart(): BasePart?
	local character = self.Character

	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

----------------------------------------------------------------
-- UI creation
----------------------------------------------------------------

function TSBUiState:CreateGui()
	assert(not self._destroyed, "TSBUiState has been destroyed")

	local gui = Instance.new("ScreenGui")
	gui.Name = "TSBHub"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local parent = nil

	-- CoreGui is intentionally not required.
	-- PlayerGui is the normal Roblox UI parent.
	pcall(function()
		parent = LocalPlayer:WaitForChild("PlayerGui")
	end)

	gui.Parent = parent

	self.Gui = gui

	self:_buildMainWindow()

	return gui
end

function TSBUiState:_buildMainWindow()
	local gui = self.Gui

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.fromOffset(340, 500)
	main.Position = UDim2.new(0.5, -170, 0.5, -250)
	main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	main.BorderSizePixel = 0
	main.Active = true
	main.Parent = gui

	createCorner(main, 10)

	self.Main = main

	------------------------------------------------------------
	-- Title bar
	------------------------------------------------------------

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	title.BorderSizePixel = 0
	title.Text = "TSB Advanced Hub"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.Parent = main

	createCorner(title, 10)

	------------------------------------------------------------
	-- Close button
	------------------------------------------------------------

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(30, 30)
	close.Position = UDim2.new(1, -35, 0, 3)
	close.BackgroundTransparency = 1
	close.Text = "×"
	close.TextColor3 = Color3.fromRGB(255, 80, 80)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 22
	close.Parent = main

	self:_connect(
		close.MouseButton1Click,
		function()
			self:Destroy()
		end,
		self._uiConnections
	)

	------------------------------------------------------------
	-- Scrolling content
	------------------------------------------------------------

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Content"
	scroll.Size = UDim2.new(1, -16, 1, -50)
	scroll.Position = UDim2.fromOffset(8, 42)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = main

	self.Scroll = scroll

	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	self.List = list

	------------------------------------------------------------
	-- Sections
	------------------------------------------------------------

	self:_createSection("Combat")

	self:_createToggle(
		"Auto Block / Perfect Block",
		self.Config.AutoBlock,
		function(value)
			self:SetConfig("AutoBlock", value)
		end
	)

	self:_createSlider(
		"Auto Block Range",
		5,
		40,
		self.Config.AutoBlockRange,
		function(value)
			self:SetConfig("AutoBlockRange", value)
		end
	)

	self:_createToggle(
		"Hitbox Expander",
		self.Config.HitboxExpander,
		function(value)
			self:SetConfig("HitboxExpander", value)
		end
	)

	self:_createSlider(
		"Hitbox Size",
		2,
		25,
		self.Config.HitboxSize,
		function(value)
			self:SetConfig("HitboxSize", value)
		end
	)

	self:_createToggle(
		"Aimlock / Camlock",
		self.Config.Aimlock,
		function(value)
			self:SetConfig("Aimlock", value)
		end
	)

	self:_createSlider(
		"Aim Prediction",
		0,
		30,
		math.round(self.Config.AimPrediction * 100),
		function(value)
			self:SetConfig("AimPrediction", value / 100)
		end
	)

	self:_createSection("Movement")

	self:_createToggle(
		"No Dash Cooldown",
		self.Config.NoDashCooldown,
		function(value)
			self:SetConfig("NoDashCooldown", value)
		end
	)

	self:_createToggle(
		"Auto Dash",
		self.Config.AutoDash,
		function(value)
			self:SetConfig("AutoDash", value)
		end
	)

	self:_createToggle(
		"WalkSpeed Enabled",
		self.Config.WalkSpeedEnabled,
		function(value)
			self:SetConfig("WalkSpeedEnabled", value)
		end
	)

	self:_createSlider(
		"WalkSpeed",
		16,
		200,
		self.Config.WalkSpeed,
		function(value)
			self:SetConfig("WalkSpeed", value)
		end
	)

	self:_createToggle(
		"Fly",
		self.Config.Fly,
		function(value)
			self:SetConfig("Fly", value)
		end
	)

	self:_createSlider(
		"Fly Speed",
		20,
		150,
		self.Config.FlySpeed,
		function(value)
			self:SetConfig("FlySpeed", value)
		end
	)

	self:_createToggle(
		"Noclip",
		self.Config.Noclip,
		function(value)
			self:SetConfig("Noclip", value)
		end
	)

	self:_createSection("Tech (Keybindable)")

	self.TechControls = {}

	for name, entry in pairs(self.Tech) do
		self.TechControls[name] = self:_createTechControl(name, entry)
	end
end

----------------------------------------------------------------
-- Section
----------------------------------------------------------------

function TSBUiState:_createSection(text: string)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 28)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	frame.BorderSizePixel = 0
	frame.Parent = self.Scroll

	createCorner(frame, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(200, 200, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	return frame
end

----------------------------------------------------------------
-- Toggle
----------------------------------------------------------------

function TSBUiState:_createToggle(
	name: string,
	default: boolean,
	callback
)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	frame.BorderSizePixel = 0
	frame.Parent = self.Scroll

	createCorner(frame, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -60, 1, 0)
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
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.BorderSizePixel = 0
	button.Parent = frame

	createCorner(button, 4)

	local function render(state: boolean)
		button.Text = state and "ON" or "OFF"

		button.BackgroundColor3 = state
			and Color3.fromRGB(80, 180, 80)
			or Color3.fromRGB(60, 60, 70)
	end

	render(default)

	self:_connect(
		button.MouseButton1Click,
		function()
			local current = button.Text == "ON"
			local nextState = not current

			render(nextState)
			callback(nextState)
		end,
		self._uiConnections
	)

	return {
		Frame = frame,
		Button = button,
		Set = render,
	}
end

----------------------------------------------------------------
-- Slider
----------------------------------------------------------------

function TSBUiState:_createSlider(
	name: string,
	minimum: number,
	maximum: number,
	default: number,
	callback
)
	default = clampNumber(default, minimum, maximum)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 50)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	frame.BorderSizePixel = 0
	frame.Parent = self.Scroll

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

	local function render(value: number, invokeCallback: boolean)
		currentValue = clampNumber(value, minimum, maximum)

		local alpha =
			(currentValue - minimum) /
			(maximum - minimum)

		fill.Size = UDim2.new(alpha, 0, 1, 0)
		label.Text = ("%s: %s"):format(
			name,
			tostring(currentValue)
		)

		if invokeCallback then
			callback(currentValue)
		end
	end

	local function updateFromX(x: number)
		local width = bar.AbsoluteSize.X

		if width <= 0 then
			return
		end

		local alpha = clampNumber(
			(x - bar.AbsolutePosition.X) / width,
			0,
			1
		)

		local rawValue =
			minimum + (maximum - minimum) * alpha

		local value = math.round(rawValue)

		render(value, true)
	end

	render(default, false)

	self:_connect(
		bar.InputBegan,
		function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				updateFromX(input.Position.X)
			end
		end,
		self._uiConnections
	)

	self:_connect(
		UserInputService.InputChanged,
		function(input)
			if not dragging then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement then
				updateFromX(input.Position.X)
			end
		end,
		self._uiConnections
	)

	self:_connect(
		UserInputService.InputEnded,
		function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end,
		self._uiConnections
	)

	return {
		Frame = frame,
		Set = function(value: number)
			render(value, true)
		end,
		Get = function()
			return currentValue
		end,
	}
end

----------------------------------------------------------------
-- Tech control
----------------------------------------------------------------

function TSBUiState:_createTechControl(name: string, entry: TechEntry)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	frame.BorderSizePixel = 0
	frame.Parent = self.Scroll

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

	local function renderKey(keyCode: Enum.KeyCode)
		keyButton.Text = keyCode.Name
	end

	local function renderEnabled(enabled: boolean)
		toggleButton.Text = enabled and "ON" or "OFF"

		toggleButton.BackgroundColor3 = enabled
			and Color3.fromRGB(80, 180, 80)
			or Color3.fromRGB(60, 60, 70)
	end

	renderKey(entry.Key)
	renderEnabled(entry.Enabled)

	------------------------------------------------------------
	-- Key capture
	------------------------------------------------------------

	self:_connect(
		keyButton.MouseButton1Click,
		function()
			listening = true

			keyButton.Text = "..."
			keyButton.BackgroundColor3 =
				Color3.fromRGB(100, 80, 40)
		end,
		self._uiConnections
	)

	self:_connect(
		UserInputService.InputBegan,
		function(input)
			if not listening then
				return
			end

			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end

			-- Escape cancels key capture.
			if input.KeyCode == Enum.KeyCode.Escape then
				listening = false
				renderKey(self.Tech[name].Key)
				keyButton.BackgroundColor3 =
					Color3.fromRGB(50, 50, 65)
				return
			end

			self:SetTechKey(name, input.KeyCode)

			listening = false
			keyButton.BackgroundColor3 =
				Color3.fromRGB(50, 50, 65)
		end,
		self._uiConnections
	)

	------------------------------------------------------------
	-- Toggle
	------------------------------------------------------------

	self:_connect(
		toggleButton.MouseButton1Click,
		function()
			self:ToggleTech(name)
		end,
		self._uiConnections
	)

	return {
		Frame = frame,
		KeyButton = keyButton,
		ToggleButton = toggleButton,

		SetKey = renderKey,
		SetEnabled = renderEnabled,
	}
end

----------------------------------------------------------------
-- Synchronize UI with state
----------------------------------------------------------------

function TSBUiState:_syncTechControl(name: string)
	local control = self.TechControls[name]
	local data = self.Tech[name]

	if not control or not data then
		return
	end

	control.SetKey(data.Key)
	control.SetEnabled(data.Enabled)
end

function TSBUiState:_syncAllTechControls()
	if not self.TechControls then
		return
	end

	for name in pairs(self.Tech) do
		self:_syncTechControl(name)
	end
end

----------------------------------------------------------------
-- Global input
--
-- This handles configured tech hotkeys.
-- UI key-capture takes priority while it is listening.
----------------------------------------------------------------

function TSBUiState:EnableGlobalKeybinds()
	if self._globalKeybindConnection then
		return
	end

	self._globalKeybindConnection = self:_connect(
		UserInputService.InputBegan,
		function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end

			for name, entry in pairs(self.Tech) do
				if input.KeyCode == entry.Key then
					self:ToggleTech(name)
				end
			end
		end
	)
end

----------------------------------------------------------------
-- React to external state changes
----------------------------------------------------------------

function TSBUiState:EnableSynchronization()
	if self._syncConnection then
		return
	end

	self._syncConnection = self:OnTechChanged(
		function(name)
			self:_syncTechControl(name)
		end
	)
end

----------------------------------------------------------------
-- Public rebuild
----------------------------------------------------------------

function TSBUiState:Rebuild()
	if self._destroyed then
		return
	end

	if self.Gui then
		self.Gui:Destroy()
	end

	self.Gui = nil
	self.Main = nil
	self.Scroll = nil
	self.List = nil
	self.TechControls = nil

	disconnectAll(self._uiConnections)

	self:CreateGui()
end

----------------------------------------------------------------
-- Destroy everything
----------------------------------------------------------------

function TSBUiState:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	disconnectAll(self._uiConnections)
	disconnectAll(self._connections)

	for _, listener in ipairs(self._changeListeners) do
		-- listeners are intentionally discarded below
	end

	table.clear(self._changeListeners)
	table.clear(self._techListeners)

	if self.Gui then
		self.Gui:Destroy()
		self.Gui = nil
	end

	self.Main = nil
	self.Scroll = nil
	self.List = nil
	self.TechControls = nil
	self.Character = nil

	self._globalKeybindConnection = nil
	self._syncConnection = nil
end

return TSBUiState
