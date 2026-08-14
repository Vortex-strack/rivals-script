-- ========================================================
-- BIBILABU HUB - RIVALS SCRIPT (ULTIMATE FIXED VERSION)
-- Giao diện Fluent UI (Nameless / Unnamed Style)
-- ========================================================

-- 1. TẢI THƯ VIỆN GIAO DIỆN (FLUENT UI)
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- 2. BIẾN TOÀN CỤC & TÙY CHỌN (SETTINGS)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Aimbot = false,
    SilentAim = false,
    RageBot = false,
    AimFOV = 150,
    ShowFOV = true,
    TargetPart = "Head",
    Fly = false,
    FlySpeed = 50,
    BypassAntiCheat = true
}

-- VÒNG TRÒN FOV TRỰC QUAN (DRAWING API)
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 170)
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8
FOVCircle.Visible = false

-- 3. CƠ CHẾ ANTI-CHEAT BYPASS AN TOÀN
if Settings.BypassAntiCheat and getrawmetatable then
    pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                local remoteName = tostring(self):lower()
                if remoteName:find("ban") or remoteName:find("cheat") or remoteName:find("detect") or remoteName:find("kick") then
                    return nil
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

-- 4. HÀM TÌM MỤC TIÊU GẦN TÂM CHUỘT NHẤT
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = Settings.AimFOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local part = char:FindFirstChild(Settings.TargetPart)

            if hum and hum.Health > 0 and part then
                local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local distance = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- 5. CAN THIỆP SILENT AIM CHUẨN (INDEX HOOK)
if hookmetamethod then
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() and Settings.SilentAim then
            if key == "Hit" or key == "CFrame" then
                local target = GetClosestPlayer()
                if target and target.Character and target.Character:FindFirstChild(Settings.TargetPart) then
                    return target.Character[Settings.TargetPart].CFrame
                end
            end
        end
        return oldIndex(self, key)
    end)
end

-- 6. VÒNG LẶP RENDER (AIMBOT / RAGEBOT / CẬP NHẬT FOV)
RunService.RenderStepped:Connect(function()
    -- Cập nhật vòng tròn FOV theo vị trí chuột
    local mousePos = UserInputService:GetMouseLocation()
    FOVCircle.Position = mousePos
    FOVCircle.Radius = Settings.AimFOV
    FOVCircle.Visible = Settings.ShowFOV and (Settings.Aimbot or Settings.SilentAim)

    -- Aimbot mềm
    if Settings.Aimbot then
        local target = GetClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild(Settings.TargetPart) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character[Settings.TargetPart].Position)
        end
    end

    -- RageBot (Xoay nhân vật & Khóa ngắm liên tục)
    if Settings.RageBot and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local target = GetClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild(Settings.TargetPart) then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            local targetPos = target.Character.HumanoidRootPart.Position
            hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character[Settings.TargetPart].Position)
        end
    end
end)

-- 7. VÒNG LẶP FLY (AssemblyLinearVelocity - CHỐNG GIẬT LAG)
RunService.Heartbeat:Connect(function()
    if Settings.Fly and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

        if hrp and hum then
            hum:ChangeState(Enum.HumanoidStateType.Swimming)
            
            local flyVec = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyVec = flyVec + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyVec = flyVec - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyVec = flyVec - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyVec = flyVec + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyVec = flyVec + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyVec = flyVec - Vector3.new(0, 1, 0) end

            if flyVec.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = flyVec.Unit * Settings.FlySpeed
            else
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end)

-- 8. THIẾT LẬP GIAO DIỆN (UI SETUP)
local Window = Fluent:CreateWindow({
    Title = "Bibilabu Hub | Rivals Testing",
    SubTitle = "by Bibilabu Dev",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift -- Đã đổi phím bật/tắt UI thành Right Shift
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "move" }),
    Bypass = Window:AddTab({ Title = "Bypass / System", Icon = "shield" })
}

-- UI Elements: Combat Tab
Tabs.Combat:AddToggle("AimbotToggle", { Title = "Enable Aimbot", Default = false, Callback = function(v) Settings.Aimbot = v end })
Tabs.Combat:AddToggle("SilentAimToggle", { Title = "Enable Silent Aim", Default = false, Callback = function(v) Settings.SilentAim = v end })
Tabs.Combat:AddToggle("RageBotToggle", { Title = "Enable Rage Bot Mode", Default = false, Callback = function(v) Settings.RageBot = v end })
Tabs.Combat:AddToggle("ShowFOVToggle", { Title = "Show FOV Circle", Default = true, Callback = function(v) Settings.ShowFOV = v end })

Tabs.Combat:AddSlider("FOVSetting", {
    Title = "Aimbot FOV",
    Default = 150,
    Min = 30,
    Max = 800,
    Rounding = 0,
    Callback = function(v) Settings.AimFOV = v end
})

-- UI Elements: Movement Tab
Tabs.Movement:AddToggle("FlyToggle", { Title = "Enable Fly", Default = false, Callback = function(v) Settings.Fly = v end })
Tabs.Movement:AddSlider("FlySpeedSetting", {
    Title = "Fly Speed",
    Default = 50,
    Min = 10,
    Max = 300,
    Rounding = 0,
    Callback = function(v) Settings.FlySpeed = v end
})

-- UI Elements: Bypass Tab
Tabs.Bypass:AddToggle("BypassToggle", { Title = "Enable Anti-Cheat Bypass", Default = true, Callback = function(v) Settings.BypassAntiCheat = v end })

-- Thông báo khởi chạy
Fluent:Notify({
    Title = "Bibilabu Hub Loaded",
    Content = "Đã tối ưu hoàn chỉnh! Sử dụng Right Shift để ẩn/hiện giao diện.",
    Duration = 5
})
