-- LocalScript: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local selectedPlayer = LocalPlayer

local walkSpeed = 16
local jumpPower = 50
local multiJumpEnabled = false
local godModeEnabled = false

local MIN_VALUE = 10
local MAX_VALUE = 700

-- Optional: restrict menu to specific user IDs
local ALLOWED_USER_IDS = {
    -- [123456789] = true,
}

if next(ALLOWED_USER_IDS) ~= nil and not ALLOWED_USER_IDS[LocalPlayer.UserId] then
    return
end

local function getHumanoid(player)
    local character = player.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function applyStats()
    local humanoid = getHumanoid(selectedPlayer)
    if not humanoid then return end

    humanoid.WalkSpeed = walkSpeed
    humanoid.JumpPower = jumpPower
    humanoid.UseJumpPower = true

    if godModeEnabled then
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
    end
end

local function clampNumber(value)
    value = tonumber(value) or MIN_VALUE
    return math.clamp(math.floor(value), MIN_VALUE, MAX_VALUE)
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "RobloxAdminMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scale = Instance.new("UIScale")
scale.Parent = gui

local function updateScale()
    local viewport = workspace.CurrentCamera.ViewportSize
    if viewport.X < 700 then
        scale.Scale = 0.82
    elseif viewport.X < 1000 then
        scale.Scale = 0.95
    else
        scale.Scale = 1
    end
end

updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local openButton = Instance.new("TextButton")
openButton.Size = UDim2.fromOffset(64, 64)
openButton.Position = UDim2.new(0, 18, 0.5, -32)
openButton.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
openButton.Text = "☰"
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.TextScaled = true
openButton.Font = Enum.Font.GothamBold
openButton.Parent = gui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(1, 0)
openCorner.Parent = openButton

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(360, 480)
frame.Position = UDim2.new(0.5, -180, 0.5, -240)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
frame.Visible = false
frame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 18)
frameCorner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 120, 255)
stroke.Thickness = 2
stroke.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 16)
padding.PaddingBottom = UDim.new(0, 16)
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 42)
title.BackgroundTransparency = 1
title.Text = "Player Mod Menu"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1, 0, 0, 32)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text = "Selected: " .. LocalPlayer.Name
selectedLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
selectedLabel.TextScaled = true
selectedLabel.Font = Enum.Font.GothamMedium
selectedLabel.Parent = frame

local playerBox = Instance.new("TextBox")
playerBox.Size = UDim2.new(1, 0, 0, 42)
playerBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
playerBox.PlaceholderText = "Type username..."
playerBox.Text = LocalPlayer.Name
playerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
playerBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 160)
playerBox.TextScaled = true
playerBox.Font = Enum.Font.Gotham
playerBox.ClearTextOnFocus = false
playerBox.Parent = frame

Instance.new("UICorner", playerBox).CornerRadius = UDim.new(0, 10)

local function createControl(labelText, defaultValue, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 82)
    holder.BackgroundTransparency = 1
    holder.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 28)
    label.BackgroundTransparency = 1
    label.Text = labelText .. ": " .. tostring(defaultValue)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamMedium
    label.Parent = holder

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 42)
    box.Position = UDim2.new(0, 0, 0, 36)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    box.Text = tostring(defaultValue)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextScaled = true
    box.Font = Enum.Font.GothamBold
    box.ClearTextOnFocus = false
    box.Parent = holder

    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)

    box.FocusLost:Connect(function()
        local value = clampNumber(box.Text)
        box.Text = tostring(value)
        label.Text = labelText .. ": " .. tostring(value)
        callback(value)
    end)

    return box
end

createControl("WalkSpeed", walkSpeed, function(value)
    walkSpeed = value
    applyStats()
end)

createControl("JumpPower", jumpPower, function(value)
    jumpPower = value
    applyStats()
end)

local function createToggle(text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 46)
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.Text = text .. ": OFF"
    button.Parent = frame

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

    local enabled = false

    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        button.Text = text .. ": " .. (enabled and "ON" or "OFF")

        TweenService:Create(
            button,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                BackgroundColor3 = enabled and Color3.fromRGB(65, 110, 255) or Color3.fromRGB(45, 45, 65)
            }
        ):Play()

        callback(enabled)
    end)

    return button
end

createToggle("Multi Jump", function(enabled)
    multiJumpEnabled = enabled
end)

createToggle("God Mode", function(enabled)
    godModeEnabled = enabled
    applyStats()
end)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(1, 0, 0, 46)
closeButton.BackgroundColor3 = Color3.fromRGB(160, 45, 65)
closeButton.Text = "Close"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = frame

Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 10)

local function setMenuVisible(visible)
    if visible then
        frame.Visible = true
        frame.BackgroundTransparency = 1
        frame.Size = UDim2.fromOffset(320, 430)

        TweenService:Create(
            frame,
            TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                BackgroundTransparency = 0,
                Size = UDim2.fromOffset(360, 480)
            }
        ):Play()
    else
        local tween = TweenService:Create(
            frame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(320, 430)
            }
        )

        tween:Play()
        tween.Completed:Once(function()
            frame.Visible = false
        end)
    end
end

openButton.MouseButton1Click:Connect(function()
    setMenuVisible(not frame.Visible)
end)

closeButton.MouseButton1Click:Connect(function()
    setMenuVisible(false)
end)

playerBox.FocusLost:Connect(function()
    local text = string.lower(playerBox.Text)

    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(player.Name):sub(1, #text) == text then
            selectedPlayer = player
            playerBox.Text = player.Name
            selectedLabel.Text = "Selected: " .. player.Name
            applyStats()
            return
        end
    end

    playerBox.Text = selectedPlayer.Name
end)

-- Multi-jump
UserInputService.JumpRequest:Connect(function()
    if not multiJumpEnabled then return end

    local humanoid = getHumanoid(selectedPlayer)
    if humanoid and selectedPlayer == LocalPlayer then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Keep stats active
RunService.Heartbeat:Connect(function()
    if selectedPlayer then
        applyStats()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    selectedPlayer = LocalPlayer
    selectedLabel.Text = "Selected: " .. LocalPlayer.Name
    applyStats()
end)
