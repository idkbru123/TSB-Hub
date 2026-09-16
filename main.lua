-- TSB Advanced Hub - Clean Rewrite
-- All features properly gated, no leaks
-- Made for Nono

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ====================== CONFIG ======================
local Config = {
    AutoBlock = false,
    AutoBlockRange = 18,
    HitboxExpander = false,
    HitboxSize = 8,
    Aimlock = false,
    AimPrediction = 0.14,
    NoDashCooldown = false,
    AutoDash = false,          -- this was leaking before
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
}

local Tech = {
    LoopDash   = {Enabled = false, Key = Enum.KeyCode.Q},
    SupaTech   = {Enabled = false, Key = Enum.KeyCode.E},
    OreoDash   = {Enabled = false, Key = Enum.KeyCode.R},
    LethalDash = {Enabled = false, Key = Enum.KeyCode.T},
}

-- Internal state
local isBlocking = false
local lastBlock = 0
local flyBV, flyBG
local lastTech = {}

-- ====================== UI ======================
local gui = Instance.new("ScreenGui")
gui.Name = "TSBHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 500)
main.Position = UDim2.new(0.5, -170, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
title.Text = "TSB Advanced Hub"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 30, 0, 30)
close.Position = UDim2.new(1, -35, 0, 3)
close.BackgroundTransparency = 1
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 80, 80)
close.Font = Enum.Font.GothamBold
close.TextSize = 22
close.Parent = main
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -50)
scroll.Position = UDim2.new(0, 8, 0, 42)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 1100)
scroll.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.Parent = scroll

local function section(txt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    f.BorderSizePixel = 0
    f.Parent = scroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(200, 200, 255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
end

local function toggle(name, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 32)
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    f.BorderSizePixel = 0
    f.Parent = scroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -60, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(230, 230, 230)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 44, 0, 22)
    b.Position = UDim2.new(1, -52, 0.5, -11)
    b.BackgroundColor3 = default and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
    b.Text = default and "ON" or "OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    local state = default
    b.MouseButton1Click:Connect(function()
        state = not state
        b.BackgroundColor3 = state and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
        b.Text = state and "ON" or "OFF"
        cb(state)
    end)
end

local function slider(name, min, max, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 50)
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    f.BorderSizePixel = 0
    f.Parent = scroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 20)
    l.Position = UDim2.new(0, 10, 0, 4)
    l.BackgroundTransparency = 1
    l.Text = name .. ": " .. default
    l.TextColor3 = Color3.fromRGB(230, 230, 230)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    bar.BorderSizePixel = 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 140, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
    local drag = false
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local r = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(min + (max-min)*r)
            fill.Size = UDim2.new(r, 0, 1, 0)
            l.Text = name .. ": " .. v
            cb(v)
        end
    end)
end

-- Build UI
section("Combat")
toggle("Auto Block / Perfect Block", false, function(v) Config.AutoBlock = v end)
slider("Auto Block Range", 5, 40, 18, function(v) Config.AutoBlockRange = v end)
toggle("Hitbox Expander", false, function(v) Config.HitboxExpander = v end)
slider("Hitbox Size", 2, 25, 8, function(v) Config.HitboxSize = v end)
toggle("Aimlock / Camlock", false, function(v) Config.Aimlock = v end)
slider("Aim Prediction", 0, 30, 14, function(v) Config.AimPrediction = v/100 end)

section("Movement")
toggle("No Dash Cooldown", false, function(v) Config.NoDashCooldown = v end)
toggle("Auto Dash", false, function(v) Config.AutoDash = v end)   -- now correctly gated
toggle("WalkSpeed Enabled", false, function(v) Config.WalkSpeedEnabled = v end)
slider("WalkSpeed", 16, 200, 16, function(v) Config.WalkSpeed = v end)
toggle("Fly", false, function(v)
    Config.Fly = v
    if not v and flyBV then
        flyBV:Destroy() flyBG:Destroy()
        flyBV, flyBG = nil, nil
    end
end)
slider("Fly Speed", 20, 150, 50, function(v) Config.FlySpeed = v end)
toggle("Noclip", false, function(v) Config.Noclip = v end)

section("Tech (Keybindable)")
local function techToggle(name, data)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    f.BorderSizePixel = 0
    f.Parent = scroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.45, 0, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(230, 230, 230)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local keyB = Instance.new("TextButton")
    keyB.Size = UDim2.new(0, 50, 0, 22)
    keyB.Position = UDim2.new(0.48, 0, 0.5, -11)
    keyB.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    keyB.Text = data.Key.Name
    keyB.TextColor3 = Color3.fromRGB(200, 200, 255)
    keyB.Font = Enum.Font.GothamBold
    keyB.TextSize = 11
    keyB.Parent = f
    Instance.new("UICorner", keyB).CornerRadius = UDim.new(0, 4)
    local togB = Instance.new("TextButton")
    togB.Size = UDim2.new(0, 44, 0, 22)
    togB.Position = UDim2.new(1, -52, 0.5, -11)
    togB.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    togB.Text = "OFF"
    togB.TextColor3 = Color3.fromRGB(255, 255, 255)
    togB.Font = Enum.Font.GothamBold
    togB.TextSize = 11
    togB.Parent = f
    Instance.new("UICorner", togB).CornerRadius = UDim.new(0, 4)

    local listen = false
    keyB.MouseButton1Click:Connect(function()
        listen = true
        keyB.Text = "..."
        keyB.BackgroundColor3 = Color3.fromRGB(100, 80, 40)
    end)
    UserInputService.InputBegan:Connect(function(inp, gpe)
        if listen and inp.UserInputType == Enum.UserInputType.Keyboard then
            data.Key = inp.KeyCode
            keyB.Text = inp.KeyCode.Name
            keyB.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            listen = false
        end
    end)
    togB.MouseButton1Click:Connect(function()
        data.Enabled = not data.Enabled
        togB.BackgroundColor3 = data.Enabled and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 70)
        togB.Text = data.Enabled and "ON" or "OFF"
    end)
end

techToggle("Loop Dash", Tech.LoopDash)
techToggle("Supa Tech", Tech.SupaTech)
techToggle("Oreo Dash", Tech.OreoDash)
techToggle("Lethal Dash", Tech.LethalDash)

-- ====================== LOGIC (fully gated) ======================

local function isAttackTrack(track)
    if not track or not track.IsPlaying then return false end
    local n = string.lower(track.Name or "")
    return (n:find("attack") or n:find("m1") or n:find("punch") or n:find("skill")
         or n:find("ability") or n:find("combo") or n:find("slash") or n:find("hit")
         or n:find("strike") or n:find("barrage") or n:find("upper") or n:find("slam")
         or n:find("grab") or n:find("throw") or n:find("ultimate")) and track.TimePosition < 0.5
end

local function getClosest(range)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestD = nil, range
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 then
                local d = (r.Position - root.Position).Magnitude
                if d < bestD then bestD = d best = p end
            end
        end
    end
    return best
end

-- Auto Block (only on real attack + hold 0.8s)
RunService.Heartbeat:Connect(function()
    if not Config.AutoBlock then return end
    if isBlocking then return end
    if tick() - lastBlock < 0.4 then return end

    local target = getClosest(Config.AutoBlockRange)
    if not target or not target.Character then return end
    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local anim = hum:FindFirstChildOfClass("Animator")
    if not anim then return end

    for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
        if isAttackTrack(track) then
            isBlocking = true
            lastBlock = tick()
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            end)
            task.delay(0.80, function()
                pcall(function()
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                end)
                isBlocking = false
            end)
            break
        end
    end
end)

-- Aimlock
RunService.RenderStepped:Connect(function()
    if not Config.Aimlock then return end
    local target = getClosest(200)
    if not target or not target.Character then return end
    local part = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
    if part then
        local pred = part.Position + part.AssemblyLinearVelocity * Config.AimPrediction
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, pred)
    end
end)

-- Hitbox
RunService.Heartbeat:Connect(function()
    if not Config.HitboxExpander then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                hrp.Transparency = 0.6
                hrp.CanCollide = false
            end
        end
    end
end)

-- WalkSpeed + No Dash Cooldown
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if Config.WalkSpeedEnabled then
        hum.WalkSpeed = Config.WalkSpeed
    end

    if Config.NoDashCooldown then
        for _, obj in ipairs(char:GetDescendants()) do
            if (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
                local n = string.lower(obj.Name)
                if n:find("dash") or n:find("cooldown") or n:find("cd") or n:find("delay") or n:find("timer") then
                    obj.Value = 0
                end
            end
        end
        pcall(function()
            char:SetAttribute("DashCooldown", 0)
            char:SetAttribute("DashCD", 0)
            char:SetAttribute("Cooldown", 0)
        end)
    end
end)

-- Auto Dash (STRICTLY gated)
RunService.Heartbeat:Connect(function()
    if not Config.AutoDash then return end          -- <-- this was missing proper gate before
    if tick() % 0.25 > 0.03 then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
    end)
end)

-- Fly
RunService.RenderStepped:Connect(function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if Config.Fly and hrp then
        if not flyBV then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBV.Parent = hrp
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            flyBG.P = 9e4
            flyBG.Parent = hrp
        end
        flyBG.CFrame = Camera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        flyBV.Velocity = dir.Magnitude > 0.1 and dir.Unit * Config.FlySpeed or Vector3.zero
    elseif flyBV then
        flyBV:Destroy() flyBG:Destroy()
        flyBV, flyBG = nil, nil
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if not Config.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

-- Tech keybinds
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    for name, data in pairs(Tech) do
        if inp.KeyCode == data.Key then
            data.Enabled = not data.Enabled
            print("[TSB] " .. name .. " = " .. tostring(data.Enabled))
        end
    end
end)

-- Tech execution (only when Enabled == true)
RunService.Heartbeat:Connect(function()
    local now = tick()
    if not LocalPlayer.Character then return end

    local function fireDash()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
            task.wait(0.03)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        end)
    end

    if Tech.LoopDash.Enabled and (not lastTech.Loop or now - lastTech.Loop > 0.16) then
        lastTech.Loop = now
        fireDash()
    end
    if Tech.SupaTech.Enabled and (not lastTech.Supa or now - lastTech.Supa > 0.30) then
        lastTech.Supa = now
        fireDash()
    end
    if Tech.OreoDash.Enabled and (not lastTech.Oreo or now - lastTech.Oreo > 0.25) then
        lastTech.Oreo = now
        fireDash()
    end
    if Tech.LethalDash.Enabled and (not lastTech.Lethal or now - lastTech.Lethal > 0.28) then
        lastTech.Lethal = now
        fireDash()
    end
end)

print("TSB Hub loaded - all features properly gated")
