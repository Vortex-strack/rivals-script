-- ========================================================
--                      VORTEX HUB (FIXED)
-- ========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Configuration State
local VortexConfig = {
    Aimbot = false,
    AimbotFOV = 150,
    ESP = false,
    Fly = false,
    FlySpeed = 50,
    NoClip = false
}

-- Target Storage
local CurrentTarget = nil

-- ========================================================
--                       UI CREATION
-- ========================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VortexHub"
ScreenGui.ResetOnSpawn = false

-- Hỗ trợ chạy trên nhiều Executor khác nhau
if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game:GetService("CoreGui")
else
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 250)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Title.Text = "VORTEX HUB"
Title.TextColor3 = Color3.fromRGB(140, 80, 255)
Title.TextSize = 16
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

local Layout = Instance.new("UIListLayout")
Layout.Parent = MainFrame
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim2.new(0, 5)

Title.LayoutOrder = 0

-- Helper Tạo Nút Toggle
local function CreateToggle(name, layoutOrder, callback)
    local Button = Instance.new("TextButton")
    Button.Name = name .. "Button"
    Button.Size = UDim2.new(0.9, 0, 0, 35)
    Button.Position = UDim2.new(0.05, 0, 0, 0)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Button.Text = name .. ": OFF"
    Button.TextColor3 = Color3.fromRGB(200, 200, 200)
    Button.Font = Enum.Font.SourceSans
    Button.TextSize = 14
    Button.LayoutOrder = layoutOrder
    Button.Parent = MainFrame

    local enabled = false
    Button.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            Button.Text = name .. ": ON"
            Button.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
            Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            Button.Text = name .. ": OFF"
            Button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            Button.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        callback(enabled)
    end)
end

CreateToggle("Aimbot", 1, function(val) VortexConfig.Aimbot = val end)
CreateToggle("ESP", 2, function(val) VortexConfig.ESP = val end)
CreateToggle("Fly", 3, function(val) VortexConfig.Fly = val end)
CreateToggle("NoClip", 4, function(val) VortexConfig.NoClip = val end)

-- Vòng tròn FOV Aimbot
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.fromRGB(140, 80, 255)
FOVCircle.Visible = false
FOVCircle.NumSides = 32
FOVCircle.Radius = VortexConfig.AimbotFOV
FOVCircle.Filled = false

-- ========================================================
--                     MODULE FUNCTIONS
-- ========================================================

-- Quét mục tiêu gần tâm chuột nhất (Đã tối ưu cho Rivals FFA)
local function GetClosestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closestDistance = VortexConfig.AimbotFOV
    local target = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then -- Bỏ check team để quét chính xác trong Rivals
            local character = player.Character
            if character and character:FindFirstChild("Head") and character:FindFirstChildOfClass("Humanoid") then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid.Health > 0 then
                    local head = character.Head
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            target = head
                        end
                    end
                end
            end
        end
    end
    return target
end

-- Hệ thống ESP Highlight
local ESPHighlights = {}
local function UpdateESP()
    if not VortexConfig.ESP then
        for _, highlight in pairs(ESPHighlights) do
            if highlight then highlight:Destroy() end
        end
        table.clear(ESPHighlights)
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character and character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").Health > 0 then
                if not ESPHighlights[player] or not ESPHighlights[player].Parent then
                    if ESPHighlights[player] then ESPHighlights[player]:Destroy() end
                    
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "VortexESP"
                    highlight.Adornee = character
                    highlight.FillColor = Color3.fromRGB(255, 50, 50)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.OutlineTransparency = 0
                    highlight.Parent = character
                    
                    ESPHighlights[player] = highlight
                end
            else
                if ESPHighlights[player] then
                    ESPHighlights[player]:Destroy()
                    ESPHighlights[player] = nil
                end
            end
        end
    end
end

-- Hệ thống Fly
local bodyVelocity = nil
local bodyGyro = nil

local function HandleFly()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if VortexConfig.Fly then
        if not bodyVelocity then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bodyVelocity.Parent = hrp
        end
        if not bodyGyro then
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
            bodyGyro.Parent = hrp
        end

        bodyGyro.CFrame = Camera.CFrame
        
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        bodyVelocity.Velocity = moveDir * VortexConfig.FlySpeed
    else
        if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
        if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    end
end

-- ========================================================
--                     MAIN LOOP CHẠY SCRIPT
-- ========================================================

RunService.RenderStepped:Connect(function()
    -- Xử lý vòng tròn FOV công cụ Aimbot
    if VortexConfig.Aimbot then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Visible = true
        
        CurrentTarget = GetClosestTarget()
        if CurrentTarget and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then -- Giữ chuột phải để Aim
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, CurrentTarget.Position)
        end
    else
        FOVCircle.Visible = false
    end

    -- Xử lý NoClip (Đi xuyên tường)
    if VortexConfig.NoClip then
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end

    -- Cập nhật Fly và ESP liên tục
    HandleFly()
    UpdateESP()
end)
