-- ModMenu LocalScript
-- Place in StarterPlayer > StarterPlayerScripts
-- Mobile + PC, auto-scaling UI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ===== State =====
local State = {
    SelectedPlayer = LocalPlayer,   -- default: the executor
    WalkSpeed = 16,
    JumpPower = 50,
    MultiJump = false,
    MaxJumps = 2,
    GodMode = false,
}

-- ===== Helpers =====
local function getCharacter()
    -- Client can only meaningfully control its own character
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char
end

local function getHumanoid()
    local char = getCharacter()
    return char:FindFirstChildOfClass("Humanoid")
end

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "ModMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = PlayerGui

-- Scale UI relative to screen (auto-adjust mobile/PC)
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    -- base design width 1280; clamp so it stays readable on phones
    local s = math.clamp(vp.X / 1280, 0.6, 1.4)
    uiScale.Scale = s
end
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()

-- Toggle button (always visible, draggable-friendly)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "Toggle"
toggleBtn.Size = UDim2.new(0, 110, 0, 44)
toggleBtn.Position = UDim2.new(0, 12, 0, 12)
toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextScaled = true
toggleBtn.Text = "MENU"
toggleBtn.AutoButtonColor = true
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

-- Main frame
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 360, 0, 460)
main.Position = UDim2.new(0.5, -180, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
main.Visible = false
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 120, 255)
stroke.Thickness = 2
stroke.Parent = main

-- Title bar (also used to drag)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Text = "Mod Menu"
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -40, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.Text = "X"
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Scrolling content area
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -16, 1, -56)
content.Position = UDim2.new(0, 8, 0, 50)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

-- ===== UI builders =====
local order = 0
local function nextOrder()
    order += 1
    return order
end

local function makeLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
    lbl.TextScaled = true
    lbl.Text = text
    lbl.LayoutOrder = nextOrder()
    lbl.Parent = content
    return lbl
end

-- Slider component
local function makeSlider(name, minV, maxV, default, onChange)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 56)
    holder.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    holder.LayoutOrder = nextOrder()
    holder.Parent = content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 0, 22)
    lbl.Position = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled = true
    lbl.Text = name .. ": " .. tostring(default)
    lbl.Parent = holder

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 10)
    bar.Position = UDim2.new(0, 8, 0, 34)
    bar.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    bar.Parent = holder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(90, 120, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Text = ""
    knob.Parent = bar
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function setFromAlpha(alpha)
        alpha = math.clamp(alpha, 0, 1)
        local value = math.floor(minV + (maxV - minV) * alpha + 0.5)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        lbl.Text = name .. ": " .. tostring(value)
        onChange(value)
    end

    -- init
    setFromAlpha((default - minV) / (maxV - minV))

    local dragging = false
    local function updateFromInput(input)
        local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
        setFromAlpha(rel)
    end

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromInput(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return holder
end

-- Toggle component
local function makeToggle(name, default, onToggle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = default and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(45, 45, 55)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.Text = name .. ": " .. (default and "ON" or "OFF")
    btn.LayoutOrder = nextOrder()
    btn.Parent = content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = name .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(45, 45, 55)
        onToggle(state)
    end)
    return btn
end

-- Player selection dropdown
local function makePlayerDropdown()
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 40)
    holder.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    holder.LayoutOrder = nextOrder()
    holder.Parent = content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundTransparency = 1
    header.TextColor3 = Color3.fromRGB(255, 255, 255)
    header.Font = Enum.Font.GothamBold
    header.TextScaled = true
    header.Text = "Player: " .. State.SelectedPlayer.Name
    header.Parent = holder

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, 0, 0, 0)
    listFrame.Position = UDim2.new(0, 0, 0, 40)
    listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    listFrame.ClipsDescendants = true
    listFrame.AutomaticSize = Enum.AutomaticSize.Y
    listFrame.Visible = false
    listFrame.Parent = holder
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 8)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = listFrame

    local open = false

    local function rebuild()
        for _, c in listFrame:GetChildren() do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, plr in Players:GetPlayers() do
            local opt = Instance.new("TextButton")
            opt.Size = UDim2.new(1, 0, 0, 32)
            opt.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            opt.TextColor3 = Color3.fromRGB(230, 230, 240)
            opt.Font = Enum.Font.Gotham
            opt.TextScaled = true
            opt.Text = plr.Name .. (plr == LocalPlayer and " (you)" or "")
            opt.Parent = listFrame
            opt.MouseButton1Click:Connect(function()
                State.SelectedPlayer = plr
                header.Text = "Player: " .. plr.Name
                open = false
                listFrame.Visible = false
                holder.Size = UDim2.new(1, 0, 0, 40)
            end)
        end
    end

    header.MouseButton1Click:Connect(function()
        open = not open
        listFrame.Visible = open
        if open then
            rebuild()
            holder.Size = UDim2.new(1, 0, 0, 40 + #Players:GetPlayers() * 32)
        else
            holder.Size = UDim2.new(1, 0, 0, 40)
        end
    end)

    Players.PlayerAdded:Connect(function() if open then rebuild() end end)
    Players.PlayerRemoving:Connect(function() if open then rebuild() end end)
end

-- ===== Build menu =====
makeLabel("Target Player")
makePlayerDropdown()

makeLabel("Movement")
makeSlider("Walk Speed", 10, 700, State.WalkSpeed, function(v)
    State.WalkSpeed = v
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = v end
end)
makeSlider("Jump Power", 10, 700, State.JumpPower, function(v)
    State.JumpPower = v
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end)

makeLabel("Abilities")
makeToggle("Multi Jump (air jump)", false, function(on)
    State.MultiJump = on
end)
makeToggle("God Mode", false, function(on)
    State.GodMode = on
end)

-- ===== Multi-jump logic =====
local jumpCount = 0
local canDoubleJump = false

local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid")
    -- apply current settings
    hum.WalkSpeed = State.WalkSpeed
    hum.UseJumpPower = true
    hum.JumpPower = State.JumpPower

    hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Landed then
            jumpCount = 0
            canDoubleJump = false
        elseif new == Enum.HumanoidStateType.Freefall then
            -- allow an air jump after leaving ground
            if State.MultiJump then canDoubleJump = true end
        elseif new == Enum.HumanoidStateType.Jumping then
            jumpCount += 1
        end
    end)
end

UserInputService.JumpRequest:Connect(function()
    if not State.MultiJump then return end
    local hum = getHumanoid()
    if not hum then return end
    if canDoubleJump and jumpCount < State.MaxJumps then
        canDoubleJump = false
        jumpCount += 1
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ===== God mode logic =====
RunService.Heartbeat:Connect(function()
    if not State.GodMode then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
end)

-- Re-apply on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    jumpCount = 0
    canDoubleJump = false
    setupCharacter(char)
end)
if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end

-- ===== Menu open/close + dragging =====
toggleBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)
closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
end)

-- Drag the window via title bar (mouse + touch)
do
    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

