local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Theme Colors
local Theme = {
    Background = Color3.fromRGB(12, 14, 20),
    Secondary = Color3.fromRGB(22, 26, 35),
    NeonBlue = Color3.fromRGB(0, 180, 255),
    NeonGlow = Color3.fromRGB(0, 120, 255),
    Text = Color3.fromRGB(240, 240, 250),
    TextDark = Color3.fromRGB(150, 160, 180)
}

-- Helper: Neon Stroke
local function addNeonStroke(parent, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.NeonBlue
    stroke.Thickness = thickness or 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    
    local glowTween = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Color = Theme.NeonGlow})
    glowTween:Play()
    return stroke
end

-- Helper: Corner
local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

-- ScreenGui Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NeonBlueHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 340, 0, 480)
MainFrame.Position = UDim2.new(0.5, -170, 0.5, -240)MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 12)
addNeonStroke(MainFrame, 2)

-- Credit Text (Above Main Frame)
local CreditText = Instance.new("TextLabel")
CreditText.Size = UDim2.new(0, 340, 0, 30)
CreditText.Position = UDim2.new(0.5, -170, 0.5, -270)
CreditText.BackgroundTransparency = 1
CreditText.Text = "MADE BY MEHRAZ"
CreditText.TextColor3 = Theme.NeonBlue
CreditText.Font = Enum.Font.GothamBold
CreditText.TextSize = 18
CreditText.TextStrokeTransparency = 0
CreditText.TextStrokeColor3 = Theme.NeonGlow
CreditText.Parent = ScreenGui

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Theme.Secondary
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
addCorner(TitleBar, 12)

local TitleBarBottom = Instance.new("Frame")
TitleBarBottom.Size = UDim2.new(1, 0, 0, 12)
TitleBarBottom.Position = UDim2.new(0, 0, 1, -12)
TitleBarBottom.BackgroundColor3 = Theme.Secondary
TitleBarBottom.BorderSizePixel = 0
TitleBarBottom.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -80, 1, 0)
TitleText.Position = UDim2.new(0, 15, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "NEON HUB"
TitleText.TextColor3 = Theme.NeonBlue
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 18
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -32, 0, 8)CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Theme.Text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
addCorner(CloseBtn, 6)

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 24, 0, 24)
MinBtn.Position = UDim2.new(1, -62, 0, 8)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
MinBtn.Text = "-"
MinBtn.TextColor3 = Theme.Text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
addCorner(MinBtn, 6)

-- Content Area
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -20, 1, -50)
Content.Position = UDim2.new(0, 10, 0, 45)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Theme.NeonBlue
Content.CanvasSize = UDim2.new(0, 0, 0, 450)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = MainFrame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 12)
Layout.Parent = Content

-- Helper: Draggable (Syncs Credit Text)
local function makeDraggable(frame, handle, credit)
    local dragging, dragInput, dragStart, startPos, creditStartPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            if credit then creditStartPos = credit.Position end
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if credit and creditStartPos then
                credit.Position = UDim2.new(creditStartPos.X.Scale, creditStartPos.X.Offset + delta.X, creditStartPos.Y.Scale, creditStartPos.Y.Offset + delta.Y)
            end
        end
    end)
end

-- Helper: Animated Slider
local function createSlider(name, min, max, default, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 60)
    Container.BackgroundTransparency = 1
    Container.Parent = Content

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.BackgroundTransparency = 1
    Label.Text = name .. ": " .. default
    Label.TextColor3 = Theme.Text
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container

    local Bg = Instance.new("Frame")
    Bg.Size = UDim2.new(1, 0, 0, 12)
    Bg.Position = UDim2.new(0, 0, 0, 30)
    Bg.BackgroundColor3 = Theme.Secondary
    Bg.BorderSizePixel = 0
    Bg.Parent = Container
    addCorner(Bg, 6)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Theme.NeonBlue
    Fill.BorderSizePixel = 0
    Fill.Parent = Bg
    addCorner(Fill, 6)
    local Handle = Instance.new("Frame")
    Handle.Size = UDim2.new(0, 18, 0, 18)
    Handle.Position = UDim2.new((default - min) / (max - min), -9, 0.5, -9)
    Handle.BackgroundColor3 = Theme.Text
    Handle.BorderSizePixel = 0
    Handle.ZIndex = 2
    Handle.Parent = Bg
    addCorner(Handle, 9)
    addNeonStroke(Handle, 2)

    local dragging = false
    
    local function updateSlider(input)
        local rel = (input.Position.X - Bg.AbsolutePosition.X) / Bg.AbsoluteSize.X
        rel = math.clamp(rel, 0, 1)
        
        TweenService:Create(Fill, TweenInfo.new(0.1), {Size = UDim2.new(rel, 0, 1, 0)}):Play()
        TweenService:Create(Handle, TweenInfo.new(0.1), {Position = UDim2.new(rel, -9, 0.5, -9)}):Play()
        
        local val = math.floor(min + (max - min) * rel)
        Label.Text = name .. ": " .. val
        callback(val)
    end

    Handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return Container
end

-- Helper: Toggle Button
local function createToggle(name, default, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 40)    Container.BackgroundColor3 = Theme.Secondary
    Container.BorderSizePixel = 0
    Container.Parent = Content
    addCorner(Container, 8)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Theme.Text
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 50, 0, 24)
    Btn.Position = UDim2.new(1, -60, 0.5, -12)
    Btn.BackgroundColor3 = default and Theme.NeonBlue or Theme.Background
    Btn.Text = ""
    Btn.BorderSizePixel = 0
    Btn.Parent = Container
    addCorner(Btn, 12)

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 18, 0, 18)
    Circle.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Circle.BackgroundColor3 = Theme.Text
    Circle.BorderSizePixel = 0
    Circle.Parent = Btn
    addCorner(Circle, 9)

    local enabled = default

    Btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        local newPos = enabled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        local newBg = enabled and Theme.NeonBlue or Theme.Background
        
        TweenService:Create(Circle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = newPos}):Play()
        TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = newBg}):Play()
        callback(enabled)
    end)
    
    return Container
end

-- Player Selection Setup
local selectedPlayer = LocalPlayer
local PlayerFrame = Instance.new("Frame")
PlayerFrame.Size = UDim2.new(1, 0, 0, 100)
PlayerFrame.BackgroundColor3 = Theme.Secondary
PlayerFrame.BorderSizePixel = 0
PlayerFrame.Parent = Content
addCorner(PlayerFrame, 8)

local PlayerTitle = Instance.new("TextLabel")
PlayerTitle.Size = UDim2.new(1, -20, 0, 25)
PlayerTitle.Position = UDim2.new(0, 10, 0, 0)
PlayerTitle.BackgroundTransparency = 1
PlayerTitle.Text = "Target Player"
PlayerTitle.TextColor3 = Theme.NeonBlue
PlayerTitle.Font = Enum.Font.GothamBold
PlayerTitle.TextSize = 14
PlayerTitle.TextXAlignment = Enum.TextXAlignment.Left
PlayerTitle.Parent = PlayerFrame

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size = UDim2.new(1, -10, 1, -30)
PlayerScroll.Position = UDim2.new(0, 5, 0, 25)
PlayerScroll.BackgroundTransparency = 1
PlayerScroll.BorderSizePixel = 0
PlayerScroll.ScrollBarThickness = 2
PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerScroll.Parent = PlayerFrame

local PlayerLayout = Instance.new("UIListLayout")
PlayerLayout.Padding = UDim.new(0, 4)
PlayerLayout.Parent = PlayerScroll

local function updatePlayerList()
    for _, child in pairs(PlayerScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    for _, plr in pairs(Players:GetPlayers()) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -4, 0, 26)
        btn.BackgroundColor3 = (plr == selectedPlayer) and Theme.NeonBlue or Theme.Background
        btn.Text = plr.Name .. ((plr == LocalPlayer) and " (You)" or "")
        btn.TextColor3 = Theme.Text
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = PlayerScroll
        addCorner(btn, 4)
                btn.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            updatePlayerList()
        end)
    end
end

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
updatePlayerList()

-- Features Logic
local multiJumpEnabled = false

local function getHumanoid()
    local char = selectedPlayer.Character or selectedPlayer.CharacterAdded:Wait()
    return char:WaitForChild("Humanoid")
end

createSlider("WalkSpeed", 12, 600, 16, function(val)
    pcall(function()
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = val end
    end)
end)

createSlider("JumpPower", 12, 600, 50, function(val)
    pcall(function()
        local hum = getHumanoid()
        if hum then 
            hum.JumpPower = val
            hum.JumpHeight = val * 0.35
        end
    end)
end)

createToggle("Multi-Jump (Infinite Air Jumps)", false, function(val)
    multiJumpEnabled = val
end)

-- Multi-Jump Logic
UserInputService.JumpRequest:Connect(function()
    if not multiJumpEnabled then return end
    pcall(function()
        local char = selectedPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.FloorMaterial == Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)end)

-- UI Animations and Events
makeDraggable(MainFrame, TitleBar, CreditText)

-- Open Animation
MainFrame.Size = UDim2.new(0, 340, 0, 0)
MainFrame.BackgroundTransparency = 1
TitleBar.BackgroundTransparency = 1
TitleBarBottom.BackgroundTransparency = 1
TitleText.TextTransparency = 1
CloseBtn.BackgroundTransparency = 1
MinBtn.BackgroundTransparency = 1
CreditText.TextTransparency = 1
CreditText.TextStrokeTransparency = 1
Content.Visible = false

TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 340, 0, 480), BackgroundTransparency = 0}):Play()
task.wait(0.2)
TweenService:Create(TitleBar, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
TweenService:Create(TitleBarBottom, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
TweenService:Create(TitleText, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
TweenService:Create(CloseBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
TweenService:Create(MinBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
TweenService:Create(CreditText, TweenInfo.new(0.3), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
task.wait(0.3)
Content.Visible = true

local isMinimized = false

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 340, 0, 40)}):Play()
        Content.Visible = false
    else
        Content.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 340, 0, 480)}):Play()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 340, 0, 0), BackgroundTransparency = 1}):Play()
    TweenService:Create(TitleBar, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    TweenService:Create(TitleBarBottom, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    TweenService:Create(TitleText, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
    TweenService:Create(CloseBtn, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    TweenService:Create(MinBtn, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    TweenService:Create(CreditText, TweenInfo.new(0.2), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    task.wait(0.3)    ScreenGui:Destroy()
end)
