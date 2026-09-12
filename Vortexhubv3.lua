--[[
================================================================================
    VORTEX V3 - FULL MERGE EDITION
    ============================================================================
    Sources merged:
      âœ“ yy.lua              â†’ Crosshair (Yurei-style, RGB, rotating)
      âœ“ UE-dagiai.lua       â†’ Linoria UI + ESP + Aimbot + Theme + Config
      âœ“ w7w7_source.lua     â†’ TP + KICK + VOID + HVH features
    ============================================================================
    All features preserved + optimizations:
      â€¢ Safe UI parent (gethui / syn.protect_gui / RobloxGui)
      â€¢ Drawing fallback (náº¿u executor thiáº¿u Drawing lib)
      â€¢ Auto cleanup on Character respawn
      â€¢ Crosshair mode toggle (M key)
      â€¢ Menu toggle (RightShift / Insert)
      â€¢ Aimbot hold (Right Mouse)
      â€¢ Notifications
      â€¢ Watermark + FPS
      â€¢ 6 built-in themes
      â€¢ Config save/load (JSON)
================================================================================
]]

-- ============================================================
-- SERVICES (cloneref-safe)
-- ============================================================
local cloneref = cloneref or function(o) return o end
local Players           = cloneref(game:GetService("Players"))
local Workspace         = cloneref(game:GetService("Workspace"))
local RunService        = cloneref(game:GetService("RunService"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local TweenService      = cloneref(game:GetService("TweenService"))
local HttpService       = cloneref(game:GetService("HttpService"))
local Lighting          = cloneref(game:GetService("Lighting"))
local TextService       = cloneref(game:GetService("TextService"))
local CoreGui           = cloneref(game:GetService("CoreGui"))
local GuiService        = cloneref(game:GetService("GuiService"))

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- ============================================================
-- SAFE PARENT RESOLVER
-- ============================================================
local function GetSafeGuiParent()
    if gethui then
        local ok, ui = pcall(gethui)
        if ok and ui then return ui end
    end
    if syn and syn.protect_gui then
        local ok = pcall(function() syn.protect_gui(CoreGui) end)
        if ok then return CoreGui end
    end
    if protect_gui then
        local ok = pcall(function() protect_gui(CoreGui) end)
        if ok then return CoreGui end
    end
    local ok, rg = pcall(function() return CoreGui:FindFirstChild("RobloxGui") or CoreGui end)
    if ok and rg then return rg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local DrawingLib = Drawing
local HasDrawing = type(DrawingLib) == "table" and type(DrawingLib.new) == "function"

-- Clean old UIs (all versions)
for _, name in ipairs({
    "VortexV3_UI", "VortexV3_Crosshair", "VortexV3_Notif",
    "VortexHubV2", "VortexHub", "VortexLua_UI",
    "w7w7_HVH", "UnnamedEnhancements_UI", "SleepyStaticCenterCrosshair"
}) do
    for _, parent in ipairs({CoreGui, LocalPlayer:FindFirstChild("PlayerGui")}) do
        if parent then
            local old = parent:FindFirstChild(name)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end

-- ============================================================
-- DRAWING WRAPPER
-- ============================================================
local function NewDrawing(kind)
    if HasDrawing then
        local ok, obj = pcall(DrawingLib.new, kind)
        if ok then return obj end
    end
    return nil
end

-- ============================================================
-- GLOBAL CONFIG
-- ============================================================
local Vortex = {
    Config = {
        Crosshair = {
            Enabled = true,
            BaseLength = 17,
            Thickness = 1,
            CenterGap = 8,
            RotationSpeed = 150,
            RGBSpeed = 0.05,
            SizeRange = 5,
            PulseSpeed = 3.5,
            MinSpeedMult = 0.35,
            MaxSpeedMult = 1.75,
            ShowText = true,
            TextContent = "vortex.win",
        },
        Aimbot = {
            Enabled = false,
            FOV = 150,
            Smoothness = 0.35,
            WallCheck = true,
            TeamCheck = true,
            TargetPart = "Head",
            Visible = true,
            Prediction = true,
        },
        ESP = {
            Enabled = false,
            Box = true,
            HealthBar = true,
            Name = true,
            Distance = true,
            TeamCheck = true,
            BoxColor = Color3.fromRGB(162, 205, 255),
            NameColor = Color3.fromRGB(255, 255, 255),
            DistanceColor = Color3.fromRGB(200, 200, 200),
        },
        HVH = {
            KickEnabled = false,
            TpEnabled = false,
            VoidEnabled = false,
            TargetPos = CFrame.new(9000, 9000, 9000),
        },
        Misc = {
            Watermark = true,
            FPS = true,
            Notifications = true,
        },
    },
    Connections = {},
    ESPObjects = {},
    Projectiles = {},
    CurrentTarget = nil,
    CrosshairMode = false,
    FakeY = -21827262828,
    CurrentValue = 2147483647,
    Flip = true,
    LastPos = nil,
    FPS = 0,
}

getgenv().VortexConfig = Vortex.Config

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================
local NotifArea
local Notifications = {}

local function SetupNotifArea(parent)
    NotifArea = Instance.new("Frame")
    NotifArea.Name = "VortexV3_Notif"
    NotifArea.BackgroundTransparency = 1
    NotifArea.Position = UDim2.new(1, -240, 0, 20)
    NotifArea.Size = UDim2.new(0, 220, 1, -40)
    NotifArea.Parent = parent

    local layout = Instance.new("UIListLayout", NotifArea)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

local function Notify(text, duration)
    if not NotifArea then return end
    duration = duration or 4

    local notif = Instance.new("Frame")
    notif.BackgroundColor3 = Color3.fromRGB(19, 19, 19)
    notif.BorderSizePixel = 0
    notif.Size = UDim2.new(1, 0, 0, 32)
    notif.Parent = NotifArea

    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", notif)
    stroke.Color = Color3.fromRGB(60, 60, 60)

    local accent = Instance.new("Frame", notif)
    accent.BackgroundColor3 = Color3.fromRGB(162, 205, 255)
    accent.BorderSizePixel = 0
    accent.Size = UDim2.new(0, 3, 1, 0)

    local lbl = Instance.new("TextLabel", notif)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Size = UDim2.new(1, -16, 1, 0)
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    task.delay(duration, function()
        pcall(function()
            TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.wait(0.3)
            notif:Destroy()
        end)
    end)
end

-- ============================================================
-- UI LIBRARY (Linoria-style, compact)
-- ============================================================
local UI = {
    Registry = {},
    FontColor = Color3.fromRGB(255, 255, 255),
    MainColor = Color3.fromRGB(19, 19, 19),
    BackgroundColor = Color3.fromRGB(21, 21, 21),
    AccentColor = Color3.fromRGB(162, 205, 255),
    AccentColorDark = Color3.fromRGB(108, 136, 170),
    OutlineColor = Color3.fromRGB(40, 40, 40),
    Font = Enum.Font.Code,
    ScreenGui = nil,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
}

local Toggles = {}
local Options = {}
getgenv().Toggles = Toggles
getgenv().Options = Options

local function C(instType, props)
    local inst = typeof(instType) == "string" and Instance.new(instType) or instType
    for p, v in next, props or {} do
        pcall(function() inst[p] = v end)
    end
    return inst
end

local function L(props, parent)
    local l = C("TextLabel", {
        BackgroundTransparency = 1,
        Font = UI.Font,
        TextColor3 = UI.FontColor,
        TextSize = 13,
        TextStrokeTransparency = 0,
    })
    C("UIStroke", {Color = Color3.new(0,0,0), Thickness = 1, Parent = l})
    for k, v in next, props or {} do pcall(function() l[k] = v end) end
    if parent then l.Parent = parent end
    return l
end

-- ============================================================
-- CROSSHAIR (from yy.lua)
-- ============================================================
local Crosshair = {
    ScreenGui = nil,
    CenterContainer = nil,
    TextContainer = nil,
    TextLabel = nil,
    Lines = {},
    Outlines = {},
    TickCounter = 0,
}

local function BuildCrosshair(parent)
    local sg = Instance.new("ScreenGui")
    sg.Name = "VortexV3_Crosshair"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 9999
    sg.Parent = parent
    Crosshair.ScreenGui = sg

    local cc = Instance.new("Frame")
    cc.Name = "Centro"
    cc.Size = UDim2.new(0,0,0,0)
    cc.Position = UDim2.new(0.5, 0, 0.5, 0)
    cc.BackgroundTransparency = 1
    cc.Parent = sg
    Crosshair.CenterContainer = cc

    local tc = Instance.new("Frame")
    tc.Name = "TextoContenedor"
    tc.Size = UDim2.new(0,0,0,0)
    tc.Position = UDim2.new(0.5, 0, 0.5, 0)
    tc.BackgroundTransparency = 1
    tc.Parent = sg
    Crosshair.TextContainer = tc

    local tl = Instance.new("TextLabel")
    tl.Name = "YokaiText"
    tl.Size = UDim2.new(0, 300, 0, 20)
    tl.Position = UDim2.new(0, -150, 0, 22)
    tl.BackgroundTransparency = 1
    tl.RichText = true
    tl.Text = '<font letter-spacing="6">' .. Vortex.Config.Crosshair.TextContent .. '</font>'
    tl.Font = Enum.Font.Arial
    tl.TextSize = 14
    tl.TextStrokeTransparency = 0
    tl.TextStrokeColor3 = Color3.new(0,0,0)
    tl.Parent = tc
    Crosshair.TextLabel = tl

    for i = 1, 4 do
        local outline = Instance.new("Frame")
        outline.Name = "Borde" .. i
        outline.BorderSizePixel = 0
        outline.BackgroundColor3 = Color3.new(0,0,0)
        outline.BackgroundTransparency = 0.5
        outline.AnchorPoint = Vector2.new(0.5, 0.5)
        outline.Parent = cc
        Crosshair.Outlines[i] = outline

        local line = Instance.new("Frame")
        line.Name = "Linea" .. i
        line.BorderSizePixel = 0
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Parent = cc
        Crosshair.Lines[i] = line
    end
end

local function UpdateCrosshair(dt)
    if not Crosshair.ScreenGui then return end
    if not Vortex.Config.Crosshair.Enabled then
        Crosshair.ScreenGui.Enabled = false
        return
    end
    Crosshair.ScreenGui.Enabled = true

    local cc = Crosshair.CenterContainer
    if not cc or not cc.Parent then return end

    local CFG = Vortex.Config.Crosshair
    Crosshair.TickCounter = Crosshair.TickCounter + dt

    -- Position
    local currentPos
    if not Vortex.CrosshairMode then
        currentPos = UDim2.new(0.5, 0, 0.5, 0)
    else
        local cursor
        if GuiService.SelectedObject then
            local ap = GuiService.SelectedObject.AbsolutePosition
            local as = GuiService.SelectedObject.AbsoluteSize
            cursor = Vector2.new(ap.X + as.X/2, ap.Y + as.Y/2)
        else
            cursor = UserInputService:GetMouseLocation()
        end
        currentPos = UDim2.new(0, cursor.X, 0, cursor.Y)
    end
    cc.Position = currentPos
    Crosshair.TextContainer.Position = currentPos

    -- Pulse
    local pulse = math.sin(Crosshair.TickCounter * CFG.PulseSpeed)
    local speedPct = (pulse + 1) / 2
    local speedLerp = CFG.MinSpeedMult + speedPct * (CFG.MaxSpeedMult - CFG.MinSpeedMult)
    local curRotSpeed = CFG.RotationSpeed * speedLerp
    cc.Rotation = (cc.Rotation + curRotSpeed * dt) % 360

    -- RGB
    local hue = (Crosshair.TickCounter * CFG.RGBSpeed) % 1
    local col = Color3.fromHSV(hue, 1, 1)

    Crosshair.TextLabel.TextColor3 = col
    Crosshair.TextLabel.Visible = CFG.ShowText
    Crosshair.TextLabel.Text = '<font letter-spacing="6">' .. CFG.TextContent .. '</font>'

    -- Dynamic size
    local dynLen = CFG.BaseLength + pulse * CFG.SizeRange
    local spread = 1

    -- L1 Top
    Crosshair.Lines[1].Size = UDim2.new(0, CFG.Thickness, 0, dynLen)
    Crosshair.Lines[1].Position = UDim2.new(0, 0, 0, -CFG.CenterGap - dynLen/2)
    Crosshair.Lines[1].BackgroundColor3 = col
    Crosshair.Outlines[1].Size = UDim2.new(0, CFG.Thickness + spread*2, 0, dynLen + spread*2)
    Crosshair.Outlines[1].Position = UDim2.new(0, 0, 0, -CFG.CenterGap - dynLen/2)

    -- L2 Bottom
    Crosshair.Lines[2].Size = UDim2.new(0, CFG.Thickness, 0, dynLen)
    Crosshair.Lines[2].Position = UDim2.new(0, 0, 0, CFG.CenterGap + dynLen/2)
    Crosshair.Lines[2].BackgroundColor3 = col
    Crosshair.Outlines[2].Size = UDim2.new(0, CFG.Thickness + spread*2, 0, dynLen + spread*2)
    Crosshair.Outlines[2].Position = UDim2.new(0, 0, 0, CFG.CenterGap + dynLen/2)

    -- L3 Left
    Crosshair.Lines[3].Size = UDim2.new(0, dynLen, 0, CFG.Thickness)
    Crosshair.Lines[3].Position = UDim2.new(0, -CFG.CenterGap - dynLen/2, 0, 0)
    Crosshair.Lines[3].BackgroundColor3 = col
    Crosshair.Outlines[3].Size = UDim2.new(0, dynLen + spread*2, 0, CFG.Thickness + spread*2)
    Crosshair.Outlines[3].Position = UDim2.new(0, -CFG.CenterGap - dynLen/2, 0, 0)

    -- L4 Right
    Crosshair.Lines[4].Size = UDim2.new(0, dynLen, 0, CFG.Thickness)
    Crosshair.Lines[4].Position = UDim2.new(0, CFG.CenterGap + dynLen/2, 0, 0)
    Crosshair.Lines[4].BackgroundColor3 = col
    Crosshair.Outlines[4].Size = UDim2.new(0, dynLen + spread*2, 0, CFG.Thickness + spread*2)
    Crosshair.Outlines[4].Position = UDim2.new(0, CFG.CenterGap + dynLen/2, 0, 0)
end

-- ============================================================
-- FOV CIRCLE
-- ============================================================
local FOVCircle = NewDrawing("Circle")
if FOVCircle then
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 64
    FOVCircle.Filled = false
    FOVCircle.Transparency = 0.8
    FOVCircle.Color = Color3.fromRGB(162, 205, 255)
    FOVCircle.Visible = false
end

-- FOV fallback (náº¿u khĂ´ng cĂ³ Drawing)
local FOVFallback
if not FOVCircle then
    FOVFallback = C("Frame", {
        Name = "VortexV3_FOVFallback",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 300, 0, 300),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = false,
    })
    C("UICorner", {CornerRadius = UDim.new(1, 0), Parent = FOVFallback})
    C("UIStroke", {
        Color = Color3.fromRGB(162, 205, 255),
        Thickness = 1.5,
        Parent = FOVFallback,
    })
end

-- ============================================================
-- WALL CHECK
-- ============================================================
local WallParams = RaycastParams.new()
WallParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsVisible(targetPart)
    if not targetPart then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    WallParams.FilterDescendantsInstances = {char, targetPart.Parent}
    local origin = Camera.CFrame.Position
    local dir = targetPart.Position - origin
    local hit = Workspace:Raycast(origin, dir, WallParams)
    return hit == nil
end

-- ============================================================
-- AIMBOT
-- ============================================================
local function GetClosestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closest, closestDist = nil, Vortex.Config.Aimbot.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local skip = false
            if Vortex.Config.Aimbot.TeamCheck and p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
                skip = true
            end
            if not skip and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local part = p.Character:FindFirstChild(Vortex.Config.Aimbot.TargetPart)
                    or p.Character:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and part then
                    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                        if d < closestDist then
                            if Vortex.Config.Aimbot.WallCheck then
                                if IsVisible(part) then
                                    closestDist = d
                                    closest = part
                                end
                            else
                                closestDist = d
                                closest = part
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- ============================================================
-- ESP (Drawing-based)
-- ============================================================
local function CreateESPFor(player)
    if player == LocalPlayer or not HasDrawing then return end
    if Vortex.ESPObjects[player] then return end

    pcall(function()
        local obj = {
            Box = NewDrawing("Square"),
            HealthBar = NewDrawing("Square"),
            Name = NewDrawing("Text"),
            Distance = NewDrawing("Text"),
        }
        if obj.Box then
            obj.Box.Thickness = 1
            obj.Box.Filled = false
            obj.Box.Transparency = 0.7
        end
        if obj.HealthBar then
            obj.HealthBar.Thickness = 1
            obj.HealthBar.Filled = true
            obj.HealthBar.Transparency = 0.3
        end
        if obj.Name then
            obj.Name.Center = true
            obj.Name.Outline = true
            obj.Name.Size = 13
        end
        if obj.Distance then
            obj.Distance.Center = true
            obj.Distance.Outline = true
            obj.Distance.Size = 12
        end
        Vortex.ESPObjects[player] = obj
    end)
end

local function RemoveESPFor(player)
    local obj = Vortex.ESPObjects[player]
    if obj then
        for _, o in pairs(obj) do
            if o then pcall(function() o:Remove() end) end
        end
        Vortex.ESPObjects[player] = nil
    end
end

local function UpdateESP()
    if not HasDrawing then return end

    for player, obj in pairs(Vortex.ESPObjects) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        local shouldShow = Vortex.Config.ESP.Enabled and char and root and hum and hum.Health > 0

        if shouldShow and Vortex.Config.ESP.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            shouldShow = false
        end

        if shouldShow then
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local head = char:FindFirstChild("Head")
                local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    or Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2, 0))
                local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                local boxH = math.abs(headPos.Y - legPos.Y)
                local boxW = boxH / 1.6
                local boxPos = Vector2.new(pos.X - boxW/2, headPos.Y)

                if obj.Box then
                    if Vortex.Config.ESP.Box then
                        obj.Box.Position = boxPos
                        obj.Box.Size = Vector2.new(boxW, boxH)
                        obj.Box.Color = Vortex.Config.ESP.BoxColor
                        obj.Box.Visible = true
                    else
                        obj.Box.Visible = false
                    end
                end

                if obj.HealthBar then
                    if Vortex.Config.ESP.HealthBar then
                        local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        obj.HealthBar.Position = Vector2.new(boxPos.X - 6, boxPos.Y + boxH * (1 - pct))
                        obj.HealthBar.Size = Vector2.new(3, boxH * pct)
                        obj.HealthBar.Color = Color3.fromHSV(pct * 0.33, 1, 1)
                        obj.HealthBar.Visible = true
                    else
                        obj.HealthBar.Visible = false
                    end
                end

                if obj.Name then
                    if Vortex.Config.ESP.Name then
                        obj.Name.Text = player.DisplayName or player.Name
                        obj.Name.Position = Vector2.new(pos.X, headPos.Y - 16)
                        obj.Name.Color = Vortex.Config.ESP.NameColor
                        obj.Name.Visible = true
                    else
                        obj.Name.Visible = false
                    end
                end

                if obj.Distance then
                    if Vortex.Config.ESP.Distance then
                        local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                        obj.Distance.Text = dist .. " studs"
                        obj.Distance.Position = Vector2.new(pos.X, legPos.Y + 2)
                        obj.Distance.Color = Vortex.Config.ESP.DistanceColor
                        obj.Distance.Visible = true
                    else
                        obj.Distance.Visible = false
                    end
                end
            else
                for _, o in pairs(obj) do if o then o.Visible = false end end
            end
        else
            for _, o in pairs(obj) do if o then o.Visible = false end end
        end
    end
end

-- ============================================================
-- MAIN UI WINDOW (Linoria-style)
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VortexV3_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GetSafeGuiParent()
UI.ScreenGui = ScreenGui

SetupNotifArea(ScreenGui)

-- Main frame
local MainFrame = C("Frame", {
    Name = "MainFrame",
    BackgroundColor3 = UI.BackgroundColor,
    BorderColor3 = UI.OutlineColor,
    Position = UDim2.new(0.5, -325, 0.5, -250),
    Size = UDim2.new(0, 650, 0, 500),
    Active = true,
    Draggable = true,
    Parent = ScreenGui,
})

-- Topbar
local Topbar = C("Frame", {
    Name = "Topbar",
    BackgroundColor3 = UI.MainColor,
    BorderColor3 = UI.OutlineColor,
    Size = UDim2.new(1, 0, 0, 30),
    Parent = MainFrame,
})

local AccentLine = C("Frame", {
    BackgroundColor3 = UI.AccentColor,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2),
    Parent = Topbar,
})

L({
    Text = "VORTEX V3 | RIVALS EDITION",
    Position = UDim2.new(0, 10, 0, 2),
    Size = UDim2.new(1, -20, 1, -2),
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = UI.Font,
    TextSize = 13,
    Parent = Topbar,
})

-- Tab bar
local TabBar = C("Frame", {
    Name = "TabBar",
    BackgroundColor3 = Color3.fromRGB(16, 16, 16),
    BorderColor3 = UI.OutlineColor,
    Position = UDim2.new(0, 0, 0, 30),
    Size = UDim2.new(1, 0, 0, 32),
    Parent = MainFrame,
})

C("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
    Parent = TabBar,
})

local Container = C("Frame", {
    Name = "Container",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 70),
    Size = UDim2.new(1, -20, 1, -80),
    Parent = MainFrame,
})

-- Window object
local Window = { Tabs = {} }

function Window:AddTab(tabName)
    local Tab = { Name = tabName }

    local TabButton = C("TextButton", {
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderColor3 = UI.OutlineColor,
        Size = UDim2.new(0, 95, 1, 0),
        Text = tabName,
        TextColor3 = Color3.fromRGB(140, 140, 140),
        Font = UI.Font,
        TextSize = 12,
        Parent = TabBar,
    })

    local TabFrame = C("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        Parent = Container,
    })

    local LeftCol = C("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.49, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 1.8, 0),
        ScrollBarThickness = 2,
        Parent = TabFrame,
    })
    C("UIListLayout", { Padding = UDim.new(0, 10), Parent = LeftCol })

    local RightCol = C("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.51, 0, 0, 0),
        Size = UDim2.new(0.49, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 1.8, 0),
        ScrollBarThickness = 2,
        Parent = TabFrame,
    })
    C("UIListLayout", { Padding = UDim.new(0, 10), Parent = RightCol })

    function Tab:Show()
        for _, t in pairs(Window.Tabs) do
            t.Frame.Visible = false
            t.Button.TextColor3 = Color3.fromRGB(140, 140, 140)
            t.Button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        end
        TabFrame.Visible = true
        TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.BackgroundColor3 = UI.MainColor
    end

    TabButton.MouseButton1Click:Connect(function() Tab:Show() end)

    local function CreateGroupbox(parentCol, title)
        local GBox = {}
        local boxFrame = C("Frame", {
            BackgroundColor3 = UI.MainColor,
            BorderColor3 = UI.OutlineColor,
            Size = UDim2.new(1, -4, 0, 100),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = parentCol,
        })

        local boxTitle = L({
            Text = title,
            Position = UDim2.new(0, 8, 0, -6),
            Size = UDim2.new(0, 0, 0, 12),
            AutomaticSize = Enum.AutomaticSize.X,
            TextColor3 = UI.AccentColor,
            Font = UI.Font,
            TextSize = 11,
            Parent = boxFrame,
        })

        local content = C("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 12),
            Size = UDim2.new(1, -16, 1, -18),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = boxFrame,
        })
        C("UIListLayout", { Padding = UDim.new(0, 6), Parent = content })

        function GBox:AddToggle(idx, info)
            local tog = {
                Value = info.Default or false,
                Type = "Toggle",
                Idx = idx,
                Callback = info.Callback or function() end,
            }

            local row = C("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Parent = content,
            })
            local box = C("Frame", {
                BackgroundColor3 = tog.Value and UI.AccentColor or Color3.fromRGB(20, 20, 20),
                BorderColor3 = UI.OutlineColor,
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0, 0, 0.5, -6),
                Parent = row,
            })
            L({
                Text = info.Text or idx,
                Position = UDim2.new(0, 18, 0, 0),
                Size = UDim2.new(1, -18, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 12,
                Parent = row,
            })

            local function UpdateVisual()
                box.BackgroundColor3 = tog.Value and UI.AccentColor or Color3.fromRGB(20, 20, 20)
            end

            row.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    tog.Value = not tog.Value
                    UpdateVisual()
                    pcall(tog.Callback, tog.Value)
                end
            end)

            function tog:SetValue(v)
                tog.Value = not not v
                UpdateVisual()
                pcall(tog.Callback, tog.Value)
            end

            Toggles[idx] = tog
            return tog
        end

        function GBox:AddSlider(idx, info)
            local sld = {
                Value = info.Default or info.Min,
                Min = info.Min or 0,
                Max = info.Max or 100,
                Rounding = info.Rounding or 0,
                Type = "Slider",
                Callback = info.Callback or function() end,
            }

            local wrap = C("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                Parent = content,
            })
            local lbl = L({
                Text = string.format("%s: %." .. sld.Rounding .. "f", info.Text or idx, sld.Value),
                Size = UDim2.new(1, 0, 0, 14),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 12,
                Parent = wrap,
            })
            local track = C("Frame", {
                BackgroundColor3 = Color3.fromRGB(15, 15, 15),
                BorderColor3 = UI.OutlineColor,
                Position = UDim2.new(0, 0, 0, 18),
                Size = UDim2.new(1, 0, 0, 8),
                Parent = wrap,
            })
            local fill = C("Frame", {
                BackgroundColor3 = UI.AccentColor,
                BorderSizePixel = 0,
                Size = UDim2.new(math.clamp((sld.Value - sld.Min) / (sld.Max - sld.Min), 0, 1), 0, 1, 0),
                Parent = track,
            })

            local function UpdateSlider(pct)
                sld.Value = math.clamp(sld.Min + (sld.Max - sld.Min) * pct, sld.Min, sld.Max)
                fill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
                lbl.Text = string.format("%s: %." .. sld.Rounding .. "f", info.Text or idx, sld.Value)
                pcall(sld.Callback, sld.Value)
            end

            track.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    local conn
                    conn = RunService.RenderStepped:Connect(function()
                        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                            conn:Disconnect()
                            return
                        end
                        local mX = UserInputService:GetMouseLocation().X
                        local pct = math.clamp((mX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                        UpdateSlider(pct)
                    end)
                end
            end)

            function sld:SetValue(v)
                local pct = (v - sld.Min) / (sld.Max - sld.Min)
                UpdateSlider(pct)
            end

            Options[idx] = sld
            return sld
        end

        function GBox:AddDropdown(idx, info)
            local dd = {
                Value = info.Values and info.Values[info.Default or 1] or "",
                Values = info.Values or {},
                Callback = info.Callback or function() end,
            }
            local wrap = C("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 36),
                Parent = content,
            })
            L({
                Text = info.Text or idx,
                Size = UDim2.new(1, 0, 0, 14),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 12,
                Parent = wrap,
            })
            local btn = C("TextButton", {
                BackgroundColor3 = Color3.fromRGB(15, 15, 15),
                BorderColor3 = UI.OutlineColor,
                Position = UDim2.new(0, 0, 0, 16),
                Size = UDim2.new(1, 0, 0, 18),
                Text = tostring(dd.Value),
                TextColor3 = UI.FontColor,
                Font = UI.Font,
                TextSize = 11,
                Parent = wrap,
            })
            local cur = info.Default or 1
            btn.MouseButton1Click:Connect(function()
                cur = (cur % #dd.Values) + 1
                dd.Value = dd.Values[cur]
                btn.Text = tostring(dd.Value)
                pcall(dd.Callback, dd.Value)
            end)
            function dd:SetValue(v)
                dd.Value = v
                btn.Text = tostring(v)
            end
            Options[idx] = dd
            return dd
        end

        function GBox:AddButton(text, callback)
            local btn = C("TextButton", {
                BackgroundColor3 = Color3.fromRGB(24, 24, 24),
                BorderColor3 = UI.OutlineColor,
                Size = UDim2.new(1, 0, 0, 22),
                Text = text,
                TextColor3 = UI.FontColor,
                Font = UI.Font,
                TextSize = 11,
                Parent = content,
            })
            btn.MouseButton1Click:Connect(function() pcall(callback) end)
            return btn
        end

        function GBox:AddLabel(text)
            return L({
                Text = text,
                Size = UDim2.new(1, 0, 0, 16),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 12,
                Parent = content,
            })
        end

        return GBox
    end

    function Tab:AddLeftGroupbox(title) return CreateGroupbox(LeftCol, title) end
    function Tab:AddRightGroupbox(title) return CreateGroupbox(RightCol, title) end

    Tab.Frame = TabFrame
    Tab.Button = TabButton
    table.insert(Window.Tabs, Tab)
    if #Window.Tabs == 1 then Tab:Show() end
    return Tab
end

-- ============================================================
-- THEME MANAGER
-- ============================================================
local ThemeManager = {
    BuiltInThemes = {
        ["Default"]     = { AccentColor = Color3.fromHex("a2cdff"), MainColor = Color3.fromHex("131313"), BackgroundColor = Color3.fromHex("151515"), OutlineColor = Color3.fromHex("282828") },
        ["Tokyo Night"] = { AccentColor = Color3.fromHex("6956cb"), MainColor = Color3.fromHex("191925"), BackgroundColor = Color3.fromHex("15151e"), OutlineColor = Color3.fromHex("272727") },
        ["Nord"]        = { AccentColor = Color3.fromHex("9effc8"), MainColor = Color3.fromHex("1c1e20"), BackgroundColor = Color3.fromHex("1c1e20"), OutlineColor = Color3.fromHex("24282d") },
        ["Skeet"]       = { AccentColor = Color3.fromHex("81ff54"), MainColor = Color3.fromHex("131313"), BackgroundColor = Color3.fromHex("151515"), OutlineColor = Color3.fromHex("2a2a2a") },
        ["Fatality"]    = { AccentColor = Color3.fromHex("ca0756"), MainColor = Color3.fromHex("181537"), BackgroundColor = Color3.fromHex("201c46"), OutlineColor = Color3.fromHex("39335a") },
        ["Neverlose"]   = { AccentColor = Color3.fromHex("01a3f1"), MainColor = Color3.fromHex("0c1014"), BackgroundColor = Color3.fromHex("0c0f14"), OutlineColor = Color3.fromHex("191919") },
    }
}

function ThemeManager:ApplyTheme(name)
    local t = self.BuiltInThemes[name]
    if not t then return end
    for k, v in pairs(t) do UI[k] = v end
    MainFrame.BackgroundColor3 = UI.BackgroundColor
    Topbar.BackgroundColor3 = UI.MainColor
    AccentLine.BackgroundColor3 = UI.AccentColor
    if FOVCircle then FOVCircle.Color = UI.AccentColor end
    Notify("Theme: " .. name, 2)
end

-- ============================================================
-- SAVE MANAGER
-- ============================================================
local SaveManager = { Folder = "VortexV3", FileName = "config" }
function SaveManager:Save(name)
    if not writefile then return Notify("Executor khĂ´ng há»— trá»£ writefile", 3) end
    name = name or self.FileName
    pcall(function()
        if not isfolder(self.Folder) then makefolder(self.Folder) end
        local d = { toggles = {}, sliders = {}, crosshair = Vortex.Config.Crosshair }
        for k, v in pairs(Toggles) do d.toggles[k] = v.Value end
        for k, v in pairs(Options) do
            if v.Type == "Slider" then d.sliders[k] = v.Value end
        end
        writefile(self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(d))
        Notify("Config saved: " .. name, 2)
    end)
end

function SaveManager:Load(name)
    if not readfile or not isfile then return Notify("Executor khĂ´ng há»— trá»£ readfile", 3) end
    name = name or self.FileName
    pcall(function()
        local path = self.Folder .. "/" .. name .. ".json"
        if isfile(path) then
            local d = HttpService:JSONDecode(readfile(path))
            for k, v in pairs(d.toggles or {}) do
                if Toggles[k] then Toggles[k]:SetValue(v) end
            end
            for k, v in pairs(d.sliders or {}) do
                if Options[k] then Options[k]:SetValue(v) end
            end
            Notify("Config loaded: " .. name, 2)
        else
            Notify("KhĂ´ng tĂ¬m tháº¥y config!", 3)
        end
    end)
end

-- ============================================================
-- HVH FEATURES (from w7w7)
-- ============================================================
local HVH = {
    LastPos = nil,
    FakeY = -21827262828,
    CurrentValue = 2147483647,
    Flip = true,
}

local function ToggleKick(state)
    Vortex.Config.HVH.KickEnabled = state
    Notify("KICK: " .. (state and "ON" or "OFF"), 2)
end

local function ToggleTP(state)
    Vortex.Config.HVH.TpEnabled = state
    if not state then Vortex.CurrentTarget = nil end
    Notify("TP: " .. (state and "ON" or "OFF"), 2)
end

local function ToggleVoid(state)
    Vortex.Config.HVH.VoidEnabled = state
    if state then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then HVH.LastPos = hrp.CFrame end
        HVH.FakeY = -21827262828
    else
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and HVH.LastPos then
            pcall(function()
                hrp.CFrame = HVH.LastPos
                hrp.AssemblyLinearVelocity = Vector3.zero
            end)
        end
    end
    Notify("VOID: " .. (state and "ON" or "OFF"), 2)
end

-- ============================================================
-- BUILD TABS
-- ============================================================
local CombatTab   = Window:AddTab("Combat")
local VisualsTab  = Window:AddTab("Visuals")
local CrossTab    = Window:AddTab("Crosshair")
local HVHTab      = Window:AddTab("HVH")
local MiscTab     = Window:AddTab("Misc")
local SettingsTab = Window:AddTab("Settings")

-- COMBAT TAB
local AimbotBox = CombatTab:AddLeftGroupbox("Silent Aim")
AimbotBox:AddToggle("aimbot_enabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(v) Vortex.Config.Aimbot.Enabled = v end,
})
AimbotBox:AddDropdown("aimbot_target_part", {
    Values = { "Head", "HumanoidRootPart", "UpperTorso" },
    Default = 1,
    Text = "Target Hitbox",
    Callback = function(v) Vortex.Config.Aimbot.TargetPart = v end,
})
AimbotBox:AddSlider("aimbot_fov", {
    Text = "Field of View",
    Default = 150, Min = 30, Max = 500, Rounding = 0,
    Callback = function(v)
        Vortex.Config.Aimbot.FOV = v
        if FOVCircle then FOVCircle.Radius = v end
    end,
})
AimbotBox:AddToggle("aimbot_show_fov", {
    Text = "Show FOV Circle",
    Default = true,
    Callback = function(v) Vortex.Config.Aimbot.Visible = v end,
})
AimbotBox:AddToggle("aimbot_wallcheck", {
    Text = "Wall Check",
    Default = true,
    Callback = function(v) Vortex.Config.Aimbot.WallCheck = v end,
})
AimbotBox:AddToggle("aimbot_teamcheck", {
    Text = "Team Check",
    Default = true,
    Callback = function(v) Vortex.Config.Aimbot.TeamCheck = v end,
})
AimbotBox:AddSlider("aimbot_smoothness", {
    Text = "Smoothness %",
    Default = 35, Min = 1, Max = 100, Rounding = 0,
    Callback = function(v) Vortex.Config.Aimbot.Smoothness = v / 100 end,
})

local InfoBox = CombatTab:AddRightGroupbox("Info")
InfoBox:AddLabel("Aimbot hold: Right Mouse")
InfoBox:AddLabel("Wall check khuyĂªn báº­t")
InfoBox:AddLabel("Team check trĂ¡nh Ä‘á»“ng Ä‘á»™i")

-- VISUALS TAB
local ESPBox = VisualsTab:AddLeftGroupbox("Player ESP")
ESPBox:AddToggle("esp_enabled", {
    Text = "Enable ESP",
    Default = false,
    Callback = function(v)
        Vortex.Config.ESP.Enabled = v
        if not v then
            for p in pairs(Vortex.ESPObjects) do RemoveESPFor(p) end
        end
    end,
})
ESPBox:AddToggle("esp_box", {
    Text = "2D Box",
    Default = true,
    Callback = function(v) Vortex.Config.ESP.Box = v end,
})
ESPBox:AddToggle("esp_healthbar", {
    Text = "Health Bar",
    Default = true,
    Callback = function(v) Vortex.Config.ESP.HealthBar = v end,
})
ESPBox:AddToggle("esp_names", {
    Text = "Names",
    Default = true,
    Callback = function(v) Vortex.Config.ESP.Name = v end,
})
ESPBox:AddToggle("esp_distance", {
    Text = "Distance",
    Default = true,
    Callback = function(v) Vortex.Config.ESP.Distance = v end,
})
ESPBox:AddToggle("esp_teamcheck", {
    Text = "Team Check",
    Default = true,
    Callback = function(v) Vortex.Config.ESP.TeamCheck = v end,
})

-- CROSSHAIR TAB
local CrossBox = CrossTab:AddLeftGroupbox("Crosshair")
CrossBox:AddToggle("ch_enabled", {
    Text = "Enable Crosshair",
    Default = true,
    Callback = function(v) Vortex.Config.Crosshair.Enabled = v end,
})
CrossBox:AddToggle("ch_text", {
    Text = "Show Text",
    Default = true,
    Callback = function(v) Vortex.Config.Crosshair.ShowText = v end,
})
CrossBox:AddSlider("ch_base_length", {
    Text = "Base Length",
    Default = 17, Min = 5, Max = 40, Rounding = 0,
    Callback = function(v) Vortex.Config.Crosshair.BaseLength = v end,
})
CrossBox:AddSlider("ch_thickness", {
    Text = "Thickness",
    Default = 1, Min = 1, Max = 5, Rounding = 0,
    Callback = function(v) Vortex.Config.Crosshair.Thickness = v end,
})
CrossBox:AddSlider("ch_center_gap", {
    Text = "Center Gap",
    Default = 8, Min = 0, Max = 30, Rounding = 0,
    Callback = function(v) Vortex.Config.Crosshair.CenterGap = v end,
})
CrossBox:AddSlider("ch_rotation_speed", {
    Text = "Rotation Speed",
    Default = 150, Min = 0, Max = 500, Rounding = 0,
    Callback = function(v) Vortex.Config.Crosshair.RotationSpeed = v end,
})
CrossBox:AddSlider("ch_rgb_speed", {
    Text = "RGB Speed x100",
    Default = 5, Min = 1, Max = 50, Rounding = 0,
    Callback = function(v) Vortex.Config.Crosshair.RGBSpeed = v / 100 end,
})

local CrossInfo = CrossTab:AddRightGroupbox("Crosshair Info")
CrossInfo:AddLabel("M = Ä‘á»•i mode (giá»¯a/chuá»™t)")
CrossInfo:AddLabel("Yurei style, RGB, xoay")
CrossInfo:AddButton("Reset Crosshair", function()
    Vortex.Config.Crosshair = {
        Enabled = true, BaseLength = 17, Thickness = 1, CenterGap = 8,
        RotationSpeed = 150, RGBSpeed = 0.05, SizeRange = 5, PulseSpeed = 3.5,
        MinSpeedMult = 0.35, MaxSpeedMult = 1.75, ShowText = true,
        TextContent = "vortex.win",
    }
    Notify("Crosshair reset", 2)
end)

-- HVH TAB
local HVHLeft = HVHTab:AddLeftGroupbox("HVH Features")
HVHLeft:AddToggle("hvh_kick", {
    Text = "KICK (Ä‘áº©y ngÆ°á»i chÆ¡i)",
    Default = false,
    Callback = ToggleKick,
})
HVHLeft:AddToggle("hvh_tp", {
    Text = "TP (bĂ¡m ngÆ°á»i chÆ¡i)",
    Default = false,
    Callback = ToggleTP,
})
HVHLeft:AddToggle("hvh_void", {
    Text = "VOID (K8X flashing)",
    Default = false,
    Callback = ToggleVoid,
})

local HVHRight = HVHTab:AddRightGroupbox("Status")
local YLabel = HVHRight:AddLabel("Y: 0")
local StatusLabel = HVHRight:AddLabel("Status: IDLE")
HVHRight:AddLabel("â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€")
HVHRight:AddLabel("KICK: Ä‘áº©y HRP ngÆ°á»i khĂ¡c")
HVHRight:AddLabel("TP: bĂ¡m má»¥c tiĂªu má»—i 1.5s")
HVHRight:AddLabel("VOID: random teleport HRP")

-- MISC TAB
local MiscLeft = MiscTab:AddLeftGroupbox("Interface")
MiscLeft:AddToggle("misc_watermark", {
    Text = "Watermark",
    Default = true,
    Callback = function(v) Vortex.Config.Misc.Watermark = v end,
})
MiscLeft:AddToggle("misc_fps", {
    Text = "FPS Counter",
    Default = true,
    Callback = function(v) Vortex.Config.Misc.FPS = v end,
})
MiscLeft:AddToggle("misc_notif", {
    Text = "Notifications",
    Default = true,
    Callback = function(v) Vortex.Config.Misc.Notifications = v end,
})

local MiscRight = MiscTab:AddRightGroupbox("Actions")
MiscRight:AddButton("Reset Character", function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
end)
MiscRight:AddButton("Random Sky Color", function()
    Lighting.Ambient = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
end)

-- SETTINGS TAB
local ThemeBox = SettingsTab:AddLeftGroupbox("Theme Manager")
ThemeBox:AddDropdown("theme_select", {
    Values = { "Default", "Tokyo Night", "Nord", "Skeet", "Fatality", "Neverlose" },
    Default = 1,
    Text = "Select Theme",
    Callback = function(v) ThemeManager:ApplyTheme(v) end,
})

local ConfigBox = SettingsTab:AddRightGroupbox("Configuration")
ConfigBox:AddButton("Save Config", function() SaveManager:Save("vortex_v3") end)
ConfigBox:AddButton("Load Config", function() SaveManager:Load("vortex_v3") end)
ConfigBox:AddButton("Unload Script", function()
    for _, c in ipairs(Vortex.Connections) do pcall(function() c:Disconnect() end) end
    for p in pairs(Vortex.ESPObjects) do RemoveESPFor(p) end
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() Crosshair.ScreenGui:Destroy() end)
    Notify("Vortex V3 unloaded", 2)
end)

-- ============================================================
-- WATERMARK + FPS
-- ============================================================
local Watermark = C("Frame", {
    Name = "Watermark",
    BackgroundColor3 = UI.MainColor,
    BorderColor3 = UI.OutlineColor,
    Position = UDim2.new(0, 15, 0, 15),
    Size = UDim2.new(0, 240, 0, 26),
    Parent = ScreenGui,
})
C("Frame", {
    BackgroundColor3 = UI.AccentColor,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2),
    Parent = Watermark,
})
local WatermarkText = L({
    Text = "VORTEX V3  |  FPS: 0",
    Position = UDim2.new(0, 8, 0, 2),
    Size = UDim2.new(1, -16, 1, -2),
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Watermark,
})

-- ============================================================
-- BUILD CROSSHAIR
-- ============================================================
BuildCrosshair(GetSafeGuiParent())
if FOVFallback then FOVFallback.Parent = ScreenGui end

-- ============================================================
-- KEYBINDS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- Menu toggle
    if input.KeyCode == Enum.KeyCode.RightShift
        or input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end

    -- Crosshair mode toggle
    if input.KeyCode == Enum.KeyCode.M
        or input.KeyCode == Enum.KeyCode.ButtonSelect then
        Vortex.CrosshairMode = not Vortex.CrosshairMode
        Notify("Crosshair mode: " .. (Vortex.CrosshairMode and "CHUá»˜T" or "GIá»®A"), 2)
    end
end)

-- ============================================================
-- FPS COUNTER
-- ============================================================
local fpsFrames = 0
local fpsTimer = 0

-- ============================================================
-- RENDER LOOP
-- ============================================================
table.insert(Vortex.Connections, RunService.RenderStepped:Connect(function(dt)
    -- FPS count
    fpsFrames = fpsFrames + 1
    fpsTimer = fpsTimer + dt
    if fpsTimer >= 1 then
        Vortex.FPS = fpsFrames
        fpsFrames = 0
        fpsTimer = 0
        if Vortex.Config.Misc.Watermark then
            WatermarkText.Text = string.format("VORTEX V3  |  FPS: %d", Vortex.FPS)
        end
    end

    -- Watermark visibility
    Watermark.Visible = Vortex.Config.Misc.Watermark
    if not Vortex.Config.Misc.FPS then
        WatermarkText.Text = "VORTEX V3"
    end

    -- Crosshair
    UpdateCrosshair(dt)

    -- FOV circle
    local mousePos = UserInputService:GetMouseLocation()
    if FOVCircle then
        if Vortex.Config.Aimbot.Visible and Vortex.Config.Aimbot.Enabled then
            FOVCircle.Position = mousePos
            FOVCircle.Radius = Vortex.Config.Aimbot.FOV
            FOVCircle.Color = UI.AccentColor
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end
    elseif FOVFallback then
        if Vortex.Config.Aimbot.Visible and Vortex.Config.Aimbot.Enabled then
            FOVFallback.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
            FOVFallback.Size = UDim2.new(0, Vortex.Config.Aimbot.FOV * 2, 0, Vortex.Config.Aimbot.FOV * 2)
            FOVFallback.Visible = true
        else
            FOVFallback.Visible = false
        end
    end

    -- Aimbot
    if Vortex.Config.Aimbot.Enabled
        and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        Vortex.CurrentTarget = GetClosestTarget()
        if Vortex.CurrentTarget then
            local targetCF = CFrame.new(Camera.CFrame.Position, Vortex.CurrentTarget.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, Vortex.Config.Aimbot.Smoothness)
        end
    end
end))

-- ============================================================
-- HEARTBEAT LOOP (ESP + HVH)
-- ============================================================
table.insert(Vortex.Connections, RunService.Heartbeat:Connect(function(dt)
    -- ESP
    UpdateESP()

    -- HVH: KICK
    if Vortex.Config.HVH.KickEnabled then
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = Vortex.Config.HVH.TargetPos
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end
            for proj in pairs(Vortex.Projectiles) do
                if proj and proj.Parent then
                    proj.CFrame = Vortex.Config.HVH.TargetPos
                    proj.AssemblyLinearVelocity = Vector3.zero
                else
                    Vortex.Projectiles[proj] = nil
                end
            end
        end)
    end

    -- HVH: TP
    if Vortex.Config.HVH.TpEnabled and Vortex.CurrentTarget and Vortex.CurrentTarget.Character then
        local targetRoot = Vortex.CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and myRoot then
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
            myRoot.AssemblyLinearVelocity = Vector3.zero
        end
    end
end))

-- ============================================================
-- HVH: TP TARGET SWITCHING
-- ============================================================
task.spawn(function()
    while true do
        if Vortex.Config.HVH.TpEnabled then
            local plrs = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(plrs, p) end
            end
            for _, plr in ipairs(plrs) do
                if not Vortex.Config.HVH.TpEnabled then break end
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    Vortex.CurrentTarget = plr
                    task.wait(1.5)
                end
            end
        end
        task.wait(0.5)
    end
end)

-- ============================================================
-- HVH: VOID LOOP (K8X flashing)
-- ============================================================
task.spawn(function()
    while true do
        if Vortex.Config.HVH.VoidEnabled then
            HVH.FakeY = HVH.FakeY + math.random(1000, 3000)
            HVH.CurrentValue = HVH.CurrentValue + (HVH.FakeY - HVH.CurrentValue) * 0.1
            YLabel.Text = "Y: " .. math.floor(HVH.CurrentValue)
            StatusLabel.Text = "Status: VOID ACTIVE"

            pcall(function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local min, max = 10000000000, 100000000000
                    local rX = math.random(min, max)
                    local rY = math.random(min, max)
                    local rZ = math.random(min, max)
                    if not HVH.Flip then
                        rX, rY, rZ = -rX, -rY, -rZ
                    end
                    HVH.Flip = not HVH.Flip
                    hrp.CFrame = CFrame.new(rX, rY, rZ)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end)
        else
            pcall(function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    YLabel.Text = "Y: " .. math.floor(hrp.Position.Y)
                    StatusLabel.Text = "Status: IDLE"
                end
            end)
        end
        task.wait(0.12)
    end
end)

-- ============================================================
-- PROJECTILE TRACKING
-- ============================================================
table.insert(Vortex.Connections, Workspace.ChildAdded:Connect(function(obj)
    if obj:IsA("BasePart") then
        task.wait(0.1)
        if obj.Name == "CoreProjectile"
            or (obj.AssemblyLinearVelocity and obj.AssemblyLinearVelocity.Magnitude > 50) then
            Vortex.Projectiles[obj] = true
        end
    end
end))

-- ============================================================
-- PLAYER EVENTS
-- ============================================================
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESPFor(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        CreateESPFor(p)
        task.wait(1)
    end
end)
Players.PlayerRemoving:Connect(function(p)
    RemoveESPFor(p)
end)

-- ============================================================
-- CHARACTER RESPAWN HOOK
-- ============================================================
local function OnCharacterAdded(char)
    char:WaitForChild("Humanoid", 5)
    -- Reset HVH state
    if Vortex.Config.HVH.VoidEnabled then
        HVH.FakeY = -21827262828
        HVH.CurrentValue = 2147483647
    end
end

if LocalPlayer.Character then
    task.spawn(OnCharacterAdded, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

-- ============================================================
-- EXPORTS
-- ============================================================
getgenv().VortexV3 = Vortex
getgenv().VortexLibrary = UI
getgenv().VortexToggles = Toggles
getgenv().VortexOptions = Options
getgenv().VortexThemeManager = ThemeManager
getgenv().VortexSaveManager = SaveManager

-- ============================================================
-- WELCOME
-- ============================================================
task.wait(0.5)
Notify("VORTEX V3 LOADED", 4)
task.wait(0.3)
Notify("RightShift/Insert: Menu", 4)
task.wait(0.3)
Notify("M: Crosshair Mode", 4)
task.wait(0.3)
Notify("Right Mouse: Aimbot Hold", 4)

print("========================================")
print("  VORTEX V3 - FULL MERGE EDITION")
print("  All 3 sources merged successfully")
print("========================================")

return Vortex
