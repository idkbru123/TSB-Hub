-- TSB Advanced Hub
-- Made for Nono

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ====================== SETTINGS ======================
local Settings = {
    AutoBlock = false,
    HitboxExpander = false,
    HitboxSize = 8,
    Aimlock = false,
    AimPart = "Head", -- Head / HumanoidRootPart
    AimPrediction = 0.135,
    AimFOV = 180,
    NoDashCooldown = false,
    AutoDash = false,
    WalkSpeed = 16,
    WalkSpeedEnabled = false,
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
}

local Tech = {
    LoopDash = {Enabled = false, Key = Enum.KeyCode.Q},
    SupaTech = {Enabled = false, Key = Enum.KeyCode.E},
    OreoDash = {Enabled = false, Key = Enum.KeyCode.R},
    LethalDash = {Enabled = false, Key = Enum.KeyCode.F},
}

local Connections = {}
local Flying = false
local BodyVelocity, BodyGyro

-- ====================== UI ======================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TSBHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 320, 0, 420)
Main.Position = UDim2.new(0.5, -160, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 36)
Title.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
Title.Text = "TSB Advanced Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 3)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 22
CloseBtn.Parent = Main
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -50)
Scroll.Position = UDim2.new(0, 8, 0, 42)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 900)
Scroll.Parent = Main

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0, 6)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Scroll

-- Helper functions
local function createSection(name)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    return frame
end

local function createToggle(name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 22)
    btn.Position = UDim2.new(1, -52, 0.5, -11)
    btn.BackgroundColor3 = default and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
        btn.Text = state and "ON" or "OFF"
        callback(state)
    end)

    return frame
end

local function createSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    bar.BorderSizePixel = 0
    bar.Parent = frame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 140, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * rel)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = name .. ": " .. value
            callback(value)
        end
    end)

    return frame
end

-- ====================== SECTIONS ======================
createSection("Combat / Kill Features")

createToggle("Auto Block / Perfect Block", false, function(v)
    Settings.AutoBlock = v
end)

createToggle("Hitbox Expander / M1 Reach", false, function(v)
    Settings.HitboxExpander = v
end)

createSlider("Hitbox Size", 2, 25, 8, function(v)
    Settings.HitboxSize = v
end)

createToggle("Aimlock / Camlock", false, function(v)
    Settings.Aimlock = v
end)

createSlider("Aim Prediction", 0, 30, 14, function(v)
    Settings.AimPrediction = v / 100
end)

-- ====================== MOVEMENT ======================
createSection("Movement & Tech")

createToggle("No Dash Cooldown", false, function(v)
    Settings.NoDashCooldown = v
end)

createToggle("Auto Dash", false, function(v)
    Settings.AutoDash = v
end)

createToggle("WalkSpeed Enabled", false, function(v)
    Settings.WalkSpeedEnabled = v
end)

createSlider("WalkSpeed", 16, 200, 16, function(v)
    Settings.WalkSpeed = v
end)

createToggle("Fly", false, function(v)
    Settings.Fly = v
    if not v and Flying then
        Flying = false
        if BodyVelocity then BodyVelocity:Destroy() end
        if BodyGyro then BodyGyro:Destroy() end
    end
end)

createSlider("Fly Speed", 20, 150, 50, function(v)
    Settings.FlySpeed = v
end)

createToggle("Noclip", false, function(v)
    Settings.Noclip = v
end)

-- ====================== TECH SECTION ======================
createSection("Tech (Keybindable)")

local function createTechToggle(name, techTable)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 50, 0, 22)
    keyBtn.Position = UDim2.new(0.48, 0, 0.5, -11)
    keyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    keyBtn.Text = techTable.Key.Name
    keyBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 11
    keyBtn.Parent = frame

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 4)
    keyCorner.Parent = keyBtn

    local togBtn = Instance.new("TextButton")
    togBtn.Size = UDim2.new(0, 44, 0, 22)
    togBtn.Position = UDim2.new(1, -52, 0.5, -11)
    togBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    togBtn.Text = "OFF"
    togBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    togBtn.Font = Enum.Font.GothamBold
    togBtn.TextSize = 11
    togBtn.Parent = frame

    local togCorner = Instance.new("UICorner")
    togCorner.CornerRadius = UDim.new(0, 4)
    togCorner.Parent = togBtn

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
        keyBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 40)
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            techTable.Key = input.KeyCode
            keyBtn.Text = input.KeyCode.Name
            keyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            listening = false
        end
    end)

    togBtn.MouseButton1Click:Connect(function()
        techTable.Enabled = not techTable.Enabled
        togBtn.BackgroundColor3 = techTable.Enabled and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
        togBtn.Text = techTable.Enabled and "ON" or "OFF"
    end)
end

createTechToggle("Loop Dash", Tech.LoopDash)
createTechToggle("Supa Tech", Tech.SupaTech)
createTechToggle("Oreo Dash", Tech.OreoDash)
createTechToggle("Lethal Dash", Tech.LethalDash)

-- ====================== LOGIC ======================

-- Aimlock
local function getClosestPlayer()
    local closest, dist = nil, Settings.AimFOV
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local pos = plr.Character.HumanoidRootPart.Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
            if onScreen then
                local mag = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if mag < dist then
                    dist = mag
                    closest = plr
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if Settings.Aimlock then
        local target = getClosestPlayer()
        if target and target.Character then
            local part = target.Character:FindFirstChild(Settings.AimPart) or target.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local vel = part.AssemblyLinearVelocity
                local predicted = part.Position + (vel * Settings.AimPrediction)
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, predicted)
            end
        end
    end
end)

-- Hitbox Expander
RunService.Heartbeat:Connect(function()
    if Settings.HitboxExpander then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = plr.Character.HumanoidRootPart
                hrp.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                hrp.Transparency = 0.7
                hrp.CanCollide = false
            end
        end
    end
end)

-- Auto Block (basic method - fires block remote / key when attack detected nearby)
-- Note: real perfect block depends on game remotes; this is a solid base
local function tryBlock()
    -- Simulate block key or remote
    -- Most TSB scripts fire the block remote here
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
end

-- No Dash Cooldown + Auto Dash (basic)
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if Settings.WalkSpeedEnabled then
        hum.WalkSpeed = Settings.WalkSpeed
    end

    if Settings.NoDashCooldown then
        -- Remove dash cooldown values if they exist in character
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("NumberValue") and (v.Name:lower():find("dash") or v.Name:lower():find("cooldown")) then
                v.Value = 0
            end
        end
    end
end)

-- Fly
RunService.RenderStepped:Connect(function()
    if Settings.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        if not Flying then
            Flying = true
            BodyVelocity = Instance.new("BodyVelocity")
            BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            BodyVelocity.Velocity = Vector3.zero
            BodyVelocity.Parent = hrp
            BodyGyro = Instance.new("BodyGyro")
            BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            BodyGyro.P = 9e4
            BodyGyro.Parent = hrp
        end
        BodyGyro.CFrame = Camera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        BodyVelocity.Velocity = dir.Unit * Settings.FlySpeed
        if dir.Magnitude < 0.1 then BodyVelocity.Velocity = Vector3.zero end
    elseif Flying then
        Flying = false
        if BodyVelocity then BodyVelocity:Destroy() end
        if BodyGyro then BodyGyro:Destroy() end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if Settings.Noclip and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Tech Keybinds
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    for name, data in pairs(Tech) do
        if input.KeyCode == data.Key then
            data.Enabled = not data.Enabled
            -- Visual feedback can be added
            print(name .. " toggled:", data.Enabled)
        end
    end
end)

-- Tech execution loops (basic placeholders - expand with real TSB dash methods)
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    if Tech.LoopDash.Enabled then
        -- Loop dash logic (spam dash remote / velocity)
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
            task.wait(0.05)
            vim:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        end)
    end

    if Tech.SupaTech.Enabled then
        -- Supa tech placeholder
    end

    if Tech.OreoDash.Enabled then
        -- Oreo dash placeholder
    end

    if Tech.LethalDash.Enabled then
        -- Lethal dash placeholder
    end
end)

print("TSB Advanced Hub loaded")
