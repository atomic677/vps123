-- Roblox Enhanced Neon Blue Dark-Theme Speed, Jump, & Multi-Jump Utility
-- Put this script inside a LocalScript in StarterGui (or run via an executor)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Color Palette (Neon Blue & Dark Theme)
local BG_COLOR = Color3.fromRGB(10, 10, 14)
local HEADER_COLOR = Color3.fromRGB(15, 16, 22)
local CONTAINER_COLOR = Color3.fromRGB(18, 19, 27)
local NEON_BLUE = Color3.fromRGB(0, 212, 255)
local NEON_GLOW = Color3.fromRGB(0, 130, 255)
local TEXT_DARK = Color3.fromRGB(140, 145, 160)
local TEXT_LIGHT = Color3.fromRGB(240, 245, 255)

-- Active connection storage for cleanup
local trackingConnections = {}
local globalConnections = {}

-- Target State
local targetPlayer = Player
local MIN_VALUE = 10
local MAX_VALUE = 200
local DEFAULT_SPEED = 16
local DEFAULT_JUMP = 50

local targetSpeed = DEFAULT_SPEED
local targetJump = DEFAULT_JUMP
local multiJumpEnabled = false

-- Function to safely apply values to current target
local function applyToTarget()
	if not targetPlayer or not targetPlayer.Character then return end
	local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = true
		if humanoid.WalkSpeed ~= targetSpeed then
			humanoid.WalkSpeed = targetSpeed
		end
		if humanoid.JumpPower ~= targetJump then
			humanoid.JumpPower = targetJump
		end
	end
end

-- Track target player character resets
local function startTargetTracking()
	for _, conn in ipairs(trackingConnections) do
		conn:Disconnect()
	end
	table.clear(trackingConnections)

	if not targetPlayer then return end

	local function onCharacter(char)
		if not char then return end
		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			applyToTarget()
			table.insert(trackingConnections, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(applyToTarget))
			table.insert(trackingConnections, humanoid:GetPropertyChangedSignal("JumpPower"):Connect(applyToTarget))
		end
	end

	if targetPlayer.Character then
		task.spawn(onCharacter, targetPlayer.Character)
	end
	table.insert(trackingConnections, targetPlayer.CharacterAdded:Connect(onCharacter))
end

-- Infinite Jump (Multi-Jump) implementation
table.insert(globalConnections, UserInputService.JumpRequest:Connect(function()
	if multiJumpEnabled and targetPlayer == Player then
		local char = Player.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end
end))

-- Initialize tracking on startup
startTargetTracking()

-- Create GUI Elements
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NeonUtilityGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local success, err = pcall(function()
	ScreenGui.Parent = game:GetService("CoreGui")
end)
if not success then
	ScreenGui.Parent = PlayerGui
end

-- Main Frame (Neon Dark Theme)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 360)
MainFrame.Position = UDim2.new(0.5, -160, 0.4, -180)
MainFrame.BackgroundColor3 = BG_COLOR
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 14)
UICorner.Parent = MainFrame

-- Outer Neon Glow Border
local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 2
UIStroke.Color = NEON_BLUE
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UIStroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = HEADER_COLOR
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = Header

local BottomHider = Instance.new("Frame")
BottomHider.Size = UDim2.new(1, 0, 0.5, 0)
BottomHider.Position = UDim2.new(0, 0, 0.5, 0)
BottomHider.BackgroundColor3 = HEADER_COLOR
BottomHider.BorderSizePixel = 0
BottomHider.Parent = Header

-- Aesthetic Neon Accent Line under Header
local NeonLine = Instance.new("Frame")
NeonLine.Size = UDim2.new(1, 0, 0, 2)
NeonLine.Position = UDim2.new(0, 0, 1, -2)
NeonLine.BackgroundColor3 = NEON_BLUE
NeonLine.BorderSizePixel = 0
NeonLine.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -85, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NEON CONTROL"
Title.TextColor3 = TEXT_LIGHT
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Smooth Dragging Functionality
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
	local delta = input.Position - dragStart
	MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

MainFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

table.insert(globalConnections, UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then updateDrag(input) end
end))

-- Container for Content
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, 0, 1, -48)
Container.Position = UDim2.new(0, 0, 0, 48)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

-- Dropdown Player Selector UI
local DropdownButton = Instance.new("TextButton")
DropdownButton.Name = "DropdownButton"
DropdownButton.Size = UDim2.new(1, -30, 0, 36)
DropdownButton.Position = UDim2.new(0, 15, 0, 16)
DropdownButton.BackgroundColor3 = CONTAINER_COLOR
DropdownButton.Text = "Target: " .. Player.Name
DropdownButton.TextColor3 = TEXT_LIGHT
DropdownButton.TextSize = 13
DropdownButton.Font = Enum.Font.GothamSemibold
DropdownButton.AutoButtonColor = false
DropdownButton.Parent = Container

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 8)
DropdownCorner.Parent = DropdownButton

local DropdownStroke = Instance.new("UIStroke")
DropdownStroke.Color = Color3.fromRGB(40, 42, 55)
DropdownStroke.Thickness = 1
DropdownStroke.Parent = DropdownButton

-- Dropdown Scrolling Container
local DropdownScroll = Instance.new("ScrollingFrame")
DropdownScroll.Name = "DropdownScroll"
DropdownScroll.Size = UDim2.new(1, -30, 0, 0)
DropdownScroll.Position = UDim2.new(0, 15, 0, 56)
DropdownScroll.BackgroundColor3 = BG_COLOR
DropdownScroll.BorderSizePixel = 0
DropdownScroll.ZIndex = 5
DropdownScroll.Visible = false
DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownScroll.ScrollBarThickness = 4
DropdownScroll.ScrollBarImageColor3 = NEON_GLOW
DropdownScroll.Parent = Container

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 8)
ScrollCorner.Parent = DropdownScroll

local ScrollStroke = Instance.new("UIStroke")
ScrollStroke.Color = NEON_BLUE
ScrollStroke.Thickness = 1.5
ScrollStroke.Parent = DropdownScroll

local DropdownLayout = Instance.new("UIListLayout")
DropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
DropdownLayout.Padding = UDim.new(0, 4)
DropdownLayout.Parent = DropdownScroll

local DropdownPadding = Instance.new("UIPadding")
DropdownPadding.PaddingTop = UDim.new(0, 6)
DropdownPadding.PaddingBottom = UDim.new(0, 6)
DropdownPadding.PaddingLeft = UDim.new(0, 6)
DropdownPadding.PaddingRight = UDim.new(0, 6)
DropdownPadding.Parent = DropdownScroll

-- Dropdown Open/Close Animations
local dropdownOpen = false
local function toggleDropdown()
	dropdownOpen = not dropdownOpen
	if dropdownOpen then
		DropdownScroll.Visible = true
		TweenService:Create(DropdownScroll, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -30, 0, 120)}):Play()
		TweenService:Create(DropdownStroke, TweenInfo.new(0.2), {Color = NEON_BLUE}):Play()
	else
		local tween = TweenService:Create(DropdownScroll, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -30, 0, 0)})
		tween:Play()
		TweenService:Create(DropdownStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(40, 42, 55)}):Play()
		tween.Completed:Connect(function()
			if not dropdownOpen then DropdownScroll.Visible = false end
		end)
	end
end

DropdownButton.MouseButton1Click:Connect(toggleDropdown)

-- Update Dropdown Items Function
local function populateDropdown()
	for _, child in ipairs(DropdownScroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		local Item = Instance.new("TextButton")
		Item.Size = UDim2.new(1, 0, 0, 28)
		Item.BackgroundTransparency = 1
		Item.Text = p.Name
		Item.TextColor3 = (p == targetPlayer) and NEON_BLUE or TEXT_DARK
		Item.TextSize = 12
		Item.Font = Enum.Font.Gotham
		Item.Parent = DropdownScroll

		local ItemCorner = Instance.new("UICorner")
		ItemCorner.CornerRadius = UDim.new(0, 4)
		ItemCorner.Parent = Item

		Item.MouseEnter:Connect(function()
			TweenService:Create(Item, TweenInfo.new(0.15), {BackgroundTransparency = 0.9, TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		end)
		Item.MouseLeave:Connect(function()
			local activeColor = (p == targetPlayer) and NEON_BLUE or TEXT_DARK
			TweenService:Create(Item, TweenInfo.new(0.15), {BackgroundTransparency = 1, TextColor3 = activeColor}):Play()
		end)

		Item.MouseButton1Click:Connect(function()
			targetPlayer = p
			DropdownButton.Text = "Target: " .. p.Name
			startTargetTracking()
			applyToTarget()
			toggleDropdown()
			populateDropdown()
		end)
	end

	DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, DropdownLayout.AbsoluteContentSize.Y + 12)
end

populateDropdown()
table.insert(globalConnections, Players.PlayerAdded:Connect(populateDropdown))
table.insert(globalConnections, Players.PlayerRemoving:Connect(function(p)
	if targetPlayer == p then
		targetPlayer = Player
		DropdownButton.Text = "Target: " .. Player.Name
		startTargetTracking()
	end
	populateDropdown()
end))

-- Slider Creator Function
local function CreateSlider(name, displayName, defaultVal, tempMin, tempMax, position, updateCallback)
	local SliderFrame = Instance.new("Frame")
	SliderFrame.Name = name .. "Slider"
	SliderFrame.Size = UDim2.new(1, -30, 0, 65)
	SliderFrame.Position = position
	SliderFrame.BackgroundTransparency = 1
	SliderFrame.Parent = Container

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, 0, 0, 20)
	Label.BackgroundTransparency = 1
	Label.Text = displayName .. ": " .. tostring(defaultVal)
	Label.TextColor3 = TEXT_DARK
	Label.TextSize = 13
	Label.Font = Enum.Font.GothamSemibold
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = SliderFrame

	local SliderTrack = Instance.new("Frame")
	SliderTrack.Size = UDim2.new(1, 0, 0, 8)
	SliderTrack.Position = UDim2.new(0, 0, 0, 32)
	SliderTrack.BackgroundColor3 = Color3.fromRGB(25, 27, 38)
	SliderTrack.BorderSizePixel = 0
	SliderTrack.Parent = SliderFrame

	local TrackCorner = Instance.new("UICorner")
	TrackCorner.CornerRadius = UDim.new(1, 0)
	TrackCorner.Parent = SliderTrack

	local SliderFill = Instance.new("Frame")
	SliderFill.Size = UDim2.new((defaultVal - tempMin) / (tempMax - tempMin), 0, 1, 0)
	SliderFill.BackgroundColor3 = NEON_BLUE
	SliderFill.BorderSizePixel = 0
	SliderFill.Parent = SliderTrack

	local FillCorner = Instance.new("UICorner")
	FillCorner.CornerRadius = UDim.new(1, 0)
	FillCorner.Parent = SliderFill

	local SliderButton = Instance.new("ImageButton")
	SliderButton.Size = UDim2.new(0, 16, 0, 16)
	SliderButton.AnchorPoint = Vector2.new(0.5, 0.5)
	SliderButton.Position = UDim2.new((defaultVal - tempMin) / (tempMax - tempMin), 0, 0.5, 0)
	SliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	SliderButton.BorderSizePixel = 0
	SliderButton.Parent = SliderTrack

	local ButtonCorner = Instance.new("UICorner")
	ButtonCorner.CornerRadius = UDim.new(1, 0)
	ButtonCorner.Parent = SliderButton
	
	local ButtonStroke = Instance.new("UIStroke")
	ButtonStroke.Color = NEON_GLOW
	ButtonStroke.Thickness = 1.5
	ButtonStroke.Parent = SliderButton

	SliderButton.MouseEnter:Connect(function()
		TweenService:Create(SliderButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 245, 255)}):Play()
	end)
	SliderButton.MouseLeave:Connect(function()
		TweenService:Create(SliderButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end)

	local isDragging = false

	local function updateSlider(input)
		local inputLoc = input.Position.X
		local trackPos = SliderTrack.AbsolutePosition.X
		local trackWidth = SliderTrack.AbsoluteSize.X
		local percentage = math.clamp((inputLoc - trackPos) / trackWidth, 0, 1)

		local val = math.floor(tempMin + (percentage * (tempMax - tempMin)))
		
		TweenService:Create(SliderFill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(percentage, 0, 1, 0)}):Play()
		TweenService:Create(SliderButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(percentage, 0, 0.5, 0)}):Play()
		
		Label.Text = displayName .. ": " .. tostring(val)
		updateCallback(val)
	end

	SliderButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			TweenService:Create(SliderButton, TweenInfo.new(0.15), {Size = UDim2.new(0, 20, 0, 20)}):Play()
		end
	end)

	table.insert(globalConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isDragging then
				isDragging = false
				TweenService:Create(SliderButton, TweenInfo.new(0.15), {Size = UDim2.new(0, 16, 0, 16)}):Play()
			end
		end
	end))

	table.insert(globalConnections, UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateSlider(input)
		end
	end))
	
	SliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			updateSlider(input)
			isDragging = true
		end
	end)
end

-- Create WalkSpeed and JumpPower Sliders
CreateSlider("WalkSpeed", "Walk Speed", DEFAULT_SPEED, MIN_VALUE, MAX_VALUE, UDim2.new(0, 15, 0, 75), function(val)
	targetSpeed = val
	applyToTarget()
end)

CreateSlider("JumpPower", "Jump Power", DEFAULT_JUMP, MIN_VALUE, MAX_VALUE, UDim2.new(0, 15, 0, 150), function(val)
	targetJump = val
	applyToTarget()
end)

-- Multi-Jump Toggle Switch Component
local ToggleFrame = Instance.new("Frame")
ToggleFrame.Name = "MultiJumpToggle"
ToggleFrame.Size = UDim2.new(1, -30, 0, 40)
ToggleFrame.Position = UDim2.new(0, 15, 0, 235)
ToggleFrame.BackgroundTransparency = 1
ToggleFrame.Parent = Container

local ToggleLabel = Instance.new("TextLabel")
ToggleLabel.Size = UDim2.new(1, -60, 1, 0)
ToggleLabel.BackgroundTransparency = 1
ToggleLabel.Text = "Multi Jump (Air Jump)"
ToggleLabel.TextColor3 = TEXT_DARK
ToggleLabel.TextSize = 13
ToggleLabel.Font = Enum.Font.GothamSemibold
ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
ToggleLabel.Parent = ToggleFrame

local ToggleSwitch = Instance.new("TextButton")
ToggleSwitch.Name = "Switch"
ToggleSwitch.Size = UDim2.new(0, 44, 0, 22)
ToggleSwitch.Position = UDim2.new(1, -44, 0.5, -11)
ToggleSwitch.BackgroundColor3 = Color3.fromRGB(25, 27, 38)
ToggleSwitch.Text = ""
ToggleSwitch.AutoButtonColor = false
ToggleSwitch.Parent = ToggleFrame

local SwitchCorner = Instance.new("UICorner")
SwitchCorner.CornerRadius = UDim.new(1, 0)
SwitchCorner.Parent = ToggleSwitch

local SwitchStroke = Instance.new("UIStroke")
SwitchStroke.Color = Color3.fromRGB(40, 42, 55)
SwitchStroke.Thickness = 1.5
SwitchStroke.Parent = ToggleSwitch

local ToggleCircle = Instance.new("Frame")
ToggleCircle.Name = "Circle"
ToggleCircle.Size = UDim2.new(0, 16, 0, 16)
ToggleCircle.Position = UDim2.new(0, 3, 0.5, -8)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(150, 155, 170)
ToggleCircle.BorderSizePixel = 0
ToggleCircle.Parent = ToggleSwitch

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

-- Handle toggle action with animations
ToggleSwitch.MouseButton1Click:Connect(function()
	multiJumpEnabled = not multiJumpEnabled
	
	if multiJumpEnabled then
		TweenService:Create(ToggleSwitch, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(0, 45, 75)}):Play()
		TweenService:Create(ToggleCircle, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -19, 0.5, -8), BackgroundColor3 = NEON_BLUE}):Play()
		TweenService:Create(SwitchStroke, TweenInfo.new(0.2), {Color = NEON_BLUE}):Play()
	else
		TweenService:Create(ToggleSwitch, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(25, 27, 38)}):Play()
		TweenService:Create(ToggleCircle, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3.fromRGB(150, 155, 170)}):Play()
		TweenService:Create(SwitchStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(40, 42, 55)}):Play()
	end
end)

-- Toggle Minimize/Expand Button (—)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "CollapseButton"
ToggleButton.Size = UDim2.new(0, 30, 0, 30)
ToggleButton.Position = UDim2.new(1, -70, 0, 9)
ToggleButton.BackgroundTransparency = 1
ToggleButton.Text = "—"
ToggleButton.TextColor3 = Color3.fromRGB(140, 145, 160)
ToggleButton.TextSize = 16
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = Header

local isOpen = true
ToggleButton.MouseButton1Click:Connect(function()
	isOpen = not isOpen
	if dropdownOpen then toggleDropdown() end
	
	if not isOpen then
		TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 320, 0, 48)}):Play()
		Container.Visible = false
		ToggleButton.Text = "+"
		ToggleButton.TextColor3 = NEON_BLUE
	else
		TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 320, 0, 360)}):Play()
		task.delay(0.1, function()
			if isOpen then Container.Visible = true end
		end)
		ToggleButton.Text = "—"
		ToggleButton.TextColor3 = Color3.fromRGB(140, 145, 160)
	end
end)

-- Close Button (X)
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -38, 0, 9)
CloseButton.BackgroundTransparency = 1
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(140, 145, 160)
CloseButton.TextSize = 15
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = Header

CloseButton.MouseEnter:Connect(function()
	TweenService:Create(CloseButton, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 75, 75)}):Play()
end)
CloseButton.MouseLeave:Connect(function()
	TweenService:Create(CloseButton, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(140, 145, 160)}):Play()
end)

CloseButton.MouseButton1Click:Connect(function()
	-- Clean up all global connections and loops to prevent memory leaks
	for _, conn in ipairs(trackingConnections) do
		conn:Disconnect()
	end
	for _, conn in ipairs(globalConnections) do
		conn:Disconnect()
	end
	
	-- Close down animations smoothly
	local closeTween = TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 320, 0, 0), Position = MainFrame.Position + UDim2.new(0, 0, 0, 180)})
	local strokeTween = TweenService:Create(UIStroke, TweenInfo.new(0.2), {Thickness = 0}):Play()
	closeTween:Play()
	closeTween.Completed:Connect(function()
		ScreenGui:Destroy()
	end)
end)
