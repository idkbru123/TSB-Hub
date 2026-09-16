-- TSB Advanced Hub - Fully Fixed
-- Auto Block only on real attacks + 0.8s hold
-- Working Techs + No Dash Cooldown
-- Made for Nono

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ====================== SETTINGS ======================
local Settings = {
    AutoBlock = false,
    AutoBlockRange = 18,
    HitboxExpander = false,
    HitboxSize = 8,
    Aimlock = false,
    AimPart = "Head",
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
    LoopDash   = {Enabled = false, Key = Enum.KeyCode.Q},
    SupaTech   = {Enabled = false, Key = Enum.KeyCode.E},
    OreoDash   = {Enabled = false, Key = Enum.KeyCode.R},
    LethalDash = {Enabled = false, Key = Enum.KeyCode.F},
}

local Flying = false
local BodyVelocity, BodyGyro
local isBlocking = false
local lastBlockTime = 0
local BLOCK_HOLD = 0.80          -- hold duration you requested

-- Common attack animation patterns (TSB uses many IDs, we catch by name + time)
local function isAttackAnimation(track)
    if not track or not track.IsPlaying then return false end
    local name = string.lower(track.Name or "")
    local id = track.Animation and track.Animation.AnimationId or ""
    
    -- Catch M1s, skills, dashes that hit, ultimates, etc.
    if name:find("attack") or name:find("m1") or name:find("punch") or 
       name:find("skill") or name:find("ability") or name:find("combo") or
       name:find("slash") or name:find("hit") or name:find("strike") or
       name:find("barrage") or name:find("uppercut") or name:find("downslam") or
       name:find("grab") or name:find("throw") or name:find("ultimate") then
        return track.TimePosition < 0.55   -- only early frames of the attack
    end
    return false
end

-- ====================== UI ======================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TSBHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 330, 0, 480)
Main.Position = UDim2.new(0.5, -165, 0.5, -240)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 36)
Title.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
Title.Text = "TSB Advanced Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

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
Scroll.CanvasSize = UDim2.new(0, 0, 0, 1020)
Scroll.Parent = Main

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0, 6)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Scroll

local function createSection(name)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
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
end

local function createToggle(name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
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
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
        btn.Text = state and "ON" or "OFF"
        callback(state)
    end)
end

local function createSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
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
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 140, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
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
end

-- ====================== BUILD UI ======================
createSection("Combat / Kill Features")

createToggle("Auto Block / Perfect Block", false, function(v)
    Settings.AutoBlock = v
end)

createSlider("Auto Block Range", 5, 40, 18, function(v)
    Settings.AutoBlockRange = v
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

createSection("Tech (Keybindable)")

local function createTechToggle(name, techTable)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

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
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 4)

    local togBtn = Instance.new("TextButton")
    togBtn.Size = UDim2.new(0, 44, 0, 22)
    togBtn.Position = UDim2.new(1, -52, 0.5, -11)
    togBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    togBtn.Text = "OFF"
    togBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    togBtn.Font = Enum.Font.GothamBold
    togBtn.TextSize = 11
    togBtn.Parent = frame
    Instance.new("UICorner", togBtn).CornerRadius = UDim.new(0, 4)

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

-- ====================== CORE LOGIC ======================

local function getClosestInRange(range)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest, closestDist = nil, range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = plr
                end
            end
        end
    end
    return closest
end

-- FIXED AUTO BLOCK: only on real attack anim + hold 0.8s
local function performBlock()
    if isBlocking then return end
    isBlocking = true
    lastBlockTime = tick()

    -- Press and HOLD block
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    end)

    task.delay(BLOCK_HOLD, function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
        isBlocking = false
    end)
end

RunService.Heartbeat:Connect(function()
    if not Settings.AutoBlock then return end
    if isBlocking then return end
    if tick() - lastBlockTime < 0.35 then return end   -- small recovery

    local target = getClosestInRange(Settings.AutoBlockRange)
    if not target or not target.Character then return end

    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if isAttackAnimation(track) then
            performBlock()
            break
        end
    end
end)

-- Aimlock
local function getClosestForAim()
    local closest, dist = nil, Settings.AimFOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
                if onScreen then
                    local mag = (Vector2.new(pos.X, pos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                    if mag < dist then
                        dist = mag
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if not Settings.Aimlock then return end
    local target = getClosestForAim()
    if target and target.Character then
        local part = target.Character:FindFirstChild(Settings.AimPart) or target.Character:FindFirstChild("HumanoidRootPart")
        if part then
            local predicted = part.Position + (part.AssemblyLinearVelocity * Settings.AimPrediction)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, predicted)
        end
    end
end)

-- Hitbox Expander
RunService.Heartbeat:Connect(function()
    if not Settings.HitboxExpander then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                hrp.Transparency = 0.65
                hrp.CanCollide = false
            end
        end
    end
end)

-- No Dash Cooldown + WalkSpeed
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if Settings.WalkSpeedEnabled then
        hum.WalkSpeed = Settings.WalkSpeed
    end

    if Settings.NoDashCooldown then
        -- Clear common cooldown values
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                local n = string.lower(obj.Name)
                if n:find("dash") or n:find("cooldown") or n:find("cd") or n:find("delay") then
                    obj.Value = 0
                end
            end
        end
        -- Also try attributes
        pcall(function()
            char:SetAttribute("DashCooldown", 0)
            char:SetAttribute("DashCD", 0)
        end)
    end
end)

-- Fly
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if Settings.Fly and hrp then
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
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        BodyVelocity.Velocity = dir.Magnitude > 0.1 and dir.Unit * Settings.FlySpeed or Vector3.zero
    elseif Flying then
        Flying = false
        if BodyVelocity then BodyVelocity:Destroy() end
        if BodyGyro then BodyGyro:Destroy() end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if not Settings.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end)

-- Tech keybinds + execution
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    for name, data in pairs(Tech) do
        if input.KeyCode == data.Key then
            data.Enabled = not data.Enabled
            -- visual feedback in console
            print("[TSB] " .. name .. " → " .. (data.Enabled and "ON" or "OFF"))
        end
    end
end)

-- Tech loops (now actually fire)
local lastTechFire = {}
RunService.Heartbeat:Connect(function()
    local now = tick()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    -- Loop Dash: rapid Q presses
    if Tech.LoopDash.Enabled then
        if not lastTechFire.LoopDash or now - lastTechFire.LoopDash > 0.18 then
            lastTechFire.LoopDash = now
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                task.wait(0.03)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            end)
        end
    end

    -- Supa Tech: Q + slight camera help + Q
    if Tech.SupaTech.Enabled then
        if not lastTechFire.SupaTech or now - lastTechFire.SupaTech > 0.35 then
            lastTechFire.SupaTech = now
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            end)
        end
    end

    -- Oreo Dash
    if Tech.OreoDash.Enabled then
        if not lastTechFire.OreoDash or now - lastTechFire.OreoDash > 0.28 then
            lastTechFire.OreoDash = now
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                task.wait(0.04)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            end)
        end
    end

    -- Lethal Dash
    if Tech.LethalDash.Enabled then
        if not lastTechFire.LethalDash or now - lastTechFire.LethalDash > 0.32 then
            lastTechFire.LethalDash = now
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
            end)
        end
    end
end)

print("TSB Advanced Hub fully loaded - Auto Block fixed, Techs working, No Dash CD improved")
