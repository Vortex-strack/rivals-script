--[[
    ╔══════════════════════════════════════════════════════╗
    ║         VORTEX HUB v1.6.4 — FINAL FINAL ZERO-BUG     ║
    ║   Fixed thêm (ngoài 26 bug của v1.6.3):              ║
    ║  27. Hit hook retry loop dừng khi Unload             ║
    ║  28. Silent aim retry loop dừng khi Unload           ║
    ╚══════════════════════════════════════════════════════╝
]]

if _G.VORTEX_LOADED and _G.VORTEX_HUB then
    pcall(function() _G.VORTEX_HUB:Unload() end)
    task.wait(0.3)
end
getgenv().__VortexLoadTime = tick()

-- ═══════════════════════════════════════════════════════════════
-- [1] BYPASS
-- ═══════════════════════════════════════════════════════════════
local Bypass = { ok = false, verified = false, l1_hits = 0, installed_at = 0, error = nil }

local _hasAPIs = (getgenv ~= nil and hookfunction ~= nil and newcclosure ~= nil
    and getrenv ~= nil and rawget ~= nil and rawlen ~= nil and type ~= nil)

if not _hasAPIs then
    local missing = {}
    if not getgenv then table.insert(missing, "getgenv") end
    if not hookfunction then table.insert(missing, "hookfunction") end
    if not newcclosure then table.insert(missing, "newcclosure") end
    if not getrenv then table.insert(missing, "getrenv") end
    Bypass.error = "missing: " .. table.concat(missing, "/")
    print("[Vortex Bypass] SKIPPED — " .. Bypass.error)
elseif getgenv().__VortexBypassInstalled == true then
    Bypass.ok = true; Bypass.verified = true
    Bypass.error = "already installed"
else
    local _rawget = rawget; local _rawlen = rawlen; local _type = type
    local ok, err = pcall(function()
        local oldSetmt = getrenv().setmetatable
        local l1 = { hits = 0 }
        Bypass.l1 = l1
        getgenv().__VortexL1 = l1
        local newSetmt = newcclosure(function(t, mt)
            if _type(mt) == "table" and _rawget(mt, "__mode") == "kv"
               and _type(t) == "table" and _rawlen(t) == 4
               and _type(_rawget(t, 1)) == "table" and _rawget(t, 2) == 1
               and _rawget(t, 3) == "String" and _type(_rawget(t, 4)) == "userdata" then
                l1.hits = l1.hits + 1
                return oldSetmt({ 1, 2, 3 }, {})
            end
            return oldSetmt(t, mt)
        end)
        hookfunction(oldSetmt, newSetmt)
    end)
    if ok then
        Bypass.ok = true; Bypass.verified = true
        Bypass.installed_at = tick()
        getgenv().__VortexBypassInstalled = true
    else
        Bypass.error = tostring(err)
        print("[Vortex Bypass] Install FAILED: " .. tostring(err))
    end
end

task.delay(10, function()
    if Bypass.ok then
        print(string.format("[Vortex Bypass] OK | pattern hits: %d", Bypass.l1 and Bypass.l1.hits or 0))
    else
        print("[Vortex Bypass] FAILED — " .. tostring(Bypass.error))
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- [2] SERVICES
-- ═══════════════════════════════════════════════════════════════
local cloneref = cloneref or clonereference or function(o) return o end
local Players           = cloneref(game:GetService("Players"))
local RunService        = cloneref(game:GetService("RunService"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local TweenService      = cloneref(game:GetService("TweenService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CoreGui           = cloneref(game:GetService("CoreGui"))
local Stats             = cloneref(game:GetService("Stats"))
local SoundService      = cloneref(game:GetService("SoundService"))
local GuiService        = cloneref(game:GetService("GuiService"))

local _conns = {}
local _entityEventConns = {}
local _playerEventConns = {}
local _unloaded = false  -- [FIX #27, #28]

local lp = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local _camConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

local execName = "unknown"
pcall(function()
    if identifyexecutor then
        local ok, n = pcall(identifyexecutor)
        if ok and n then execName = tostring(n) end
    end
end)

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isIOS = (UserInputService.TouchEnabled and (not UserInputService.MouseEnabled))
    or (string.lower(execName):find("delta") ~= nil)
    or (string.lower(execName):find("ios") ~= nil)

print("[Vortex] Executor:", execName, "| Mobile:", tostring(isMobile), "| iOS:", tostring(isIOS))

local function safeRequire(m, t)
    if not m then return nil end
    t = t or 5
    local s = tick()
    while tick() - s < t do
        local ok, r = pcall(require, m)
        if ok then return r end
        task.wait(0.2)
    end
    return nil
end
local function waitChild(root, names, timeout)
    timeout = timeout or 8
    local o = root
    for _, n in ipairs(names) do
        if not o then return nil end
        local ok, c = pcall(function() return o:WaitForChild(n, timeout) end)
        o = ok and c or nil
    end
    return o
end

repeat task.wait() until game:IsLoaded()
if not lp.Character then
    local dl = tick() + 10
    while not lp.Character and tick() < dl do task.wait() end
end

pcall(function()
    if UserInputService.JumpRequest then
        table.insert(_conns, UserInputService.JumpRequest:Connect(function()
            getgenv().__VortexLastJumpT = tick()
        end))
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- [3] RIVALS MODULES
-- ═══════════════════════════════════════════════════════════════
local Rivals = { Ready = false }
do
    local jobs = {
        { ReplicatedStorage, {"Modules","Utility"},              "Util" },
        { lp.PlayerScripts,  {"Controllers","FighterController"}, "Fighter" },
        { ReplicatedStorage, {"Modules","EnumLibrary"},           "Enums" },
    }
    for _, j in ipairs(jobs) do
        task.spawn(function()
            local inst = waitChild(j[1], j[2], 6)
            local mod = safeRequire(inst, 4)
            if mod then Rivals[j[3]] = mod end
        end)
    end
    task.wait(2)
    Rivals.Ready = (Rivals.Util ~= nil and Rivals.Fighter ~= nil)
end

-- ═══════════════════════════════════════════════════════════════
-- [4] SIGNAL
-- ═══════════════════════════════════════════════════════════════
local function Signal()
    local s = { _cbs = {} }
    function s:Connect(fn)
        table.insert(self._cbs, fn)
        local cb = fn
        return { Disconnect = function()
            local i = table.find(self._cbs, cb)
            if i then table.remove(self._cbs, i) end
        end }
    end
    function s:Fire(...)
        for _, fn in ipairs(self._cbs) do task.spawn(fn, ...) end
    end
    return s
end

-- ═══════════════════════════════════════════════════════════════
-- [5] ENTITY
-- ═══════════════════════════════════════════════════════════════
local Entity = {
    List = {}, isAlive = false, character = nil,
    Events = { Added = Signal(), Removed = Signal(),
               LocalAdded = Signal(), LocalRemoved = Signal() },
}

local function cleanupEntityConns(ent)
    for _, c in ipairs(ent.Connections or {}) do
        pcall(function() c:Disconnect() end)
    end
    ent.Connections = {}
end

local function addEntity(char, plr)
    if not char or not char.Parent then return end
    if plr == lp then
        if Entity.character and Entity.character.Character == char then return end
        if Entity.character then
            cleanupEntityConns(Entity.character)
        end
    else
        for _, e in ipairs(Entity.List) do
            if e.Character == char then return end
        end
    end

    task.spawn(function()
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 8)
        if not hum then return end
        local hrp = hum.RootPart or char:WaitForChild("HumanoidRootPart", 8)
        if not hrp then return end
        if not char.Parent or hum.Parent ~= char then return end

        local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
        local ent = {
            Character = char, Humanoid = hum, HumanoidRootPart = hrp,
            RootPart = hrp, Head = head,
            Health = hum.Health, MaxHealth = hum.MaxHealth,
            Player = plr, NPC = (plr == nil),
            Targetable = true, Connections = {},
        }
        table.insert(ent.Connections, hum:GetPropertyChangedSignal("Health"):Connect(function()
            ent.Health = hum.Health
        end))
        table.insert(ent.Connections, hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
            ent.MaxHealth = hum.MaxHealth
        end))

        if not char.Parent or hum.Parent ~= char then
            cleanupEntityConns(ent)
            return
        end

        if plr == lp then
            if Entity.character and Entity.character.Character == char then
                cleanupEntityConns(ent); return
            end
            if Entity.character and Entity.character ~= ent then
                cleanupEntityConns(Entity.character)
            end
            Entity.character = ent
            Entity.isAlive = true
            Entity.Events.LocalAdded:Fire(ent)
        else
            for _, e in ipairs(Entity.List) do
                if e.Character == char then
                    cleanupEntityConns(ent); return
                end
            end
            table.insert(Entity.List, ent)
            Entity.Events.Added:Fire(ent)
        end
    end)
end

local function removeEntity(plr, char)
    if plr == lp then
        if Entity.isAlive and Entity.character then
            cleanupEntityConns(Entity.character)
            Entity.isAlive = false
            Entity.Events.LocalRemoved:Fire(Entity.character)
            Entity.character = nil
        end
        return
    end
    for i = #Entity.List, 1, -1 do
        local v = Entity.List[i]
        if v.Player == plr or v.Character == char then
            cleanupEntityConns(v)
            table.remove(Entity.List, i)
            Entity.Events.Removed:Fire(v)
            return
        end
    end
end

do
    local function hookPlayer(p)
        table.insert(_playerEventConns, p.CharacterAdded:Connect(function(c) addEntity(c, p) end))
        table.insert(_playerEventConns, p.CharacterRemoving:Connect(function(c) removeEntity(p, c) end))
        if p.Character then addEntity(p.Character, p) end
    end
    for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
    table.insert(_playerEventConns, Players.PlayerAdded:Connect(hookPlayer))
    table.insert(_playerEventConns, Players.PlayerRemoving:Connect(function(p) removeEntity(p) end))

    table.insert(_playerEventConns, lp.CharacterAdded:Connect(function(c) addEntity(c, lp) end))
    table.insert(_playerEventConns, lp.CharacterRemoving:Connect(function(c) removeEntity(lp, c) end))
    if lp.Character then addEntity(lp.Character, lp) end
end

-- ═══════════════════════════════════════════════════════════════
-- [6] PREDICTION
-- ═══════════════════════════════════════════════════════════════
local Prediction = (function()
    local M = {}
    local eps = 1e-9
    local function isZero(d) return d > -eps and d < eps end
    local function cbrt(x) return x > 0 and math.pow(x, 1/3) or -math.pow(math.abs(x), 1/3) end
    local function solveCubic(c0, c1, c2, c3)
        local A, B, C = c1/c0, c2/c0, c3/c0
        local sq_A = A*A
        local p = (1/3)*(-(1/3)*sq_A + B)
        local q = 0.5*((2/27)*A*sq_A - (1/3)*A*B + C)
        local cb_p = p*p*p
        local D = q*q + cb_p
        local s0, s1, s2, num
        if isZero(D) then
            if isZero(q) then s0, num = 0, 1
            else local u = cbrt(-q); s0, s1, num = 2*u, -u, 2 end
        elseif D < 0 then
            local phi = (1/3)*math.acos(-q/math.sqrt(-cb_p))
            local t = 2*math.sqrt(-p)
            s0 = t*math.cos(phi)
            s1 = -t*math.cos(phi + math.pi/3)
            s2 = -t*math.cos(phi - math.pi/3)
            num = 3
        else
            local sd = math.sqrt(D)
            local u = cbrt(sd - q)
            local v = -cbrt(sd + q)
            s0, num = u + v, 1
        end
        local sub = (1/3)*A
        if num > 0 then s0 = s0 - sub end
        if num > 1 then s1 = s1 - sub end
        if num > 2 then s2 = s2 - sub end
        return s0, s1, s2
    end
    function M.Solve(origin, speed, gravity, targetPos, targetVel)
        local disp = targetPos - origin
        local p, q, r = targetVel.X, targetVel.Y, targetVel.Z
        local h, j, k = disp.X, disp.Y, disp.Z
        local l = -0.5*gravity
        local a0 = l*l
        local a1 = -2*q*l
        local a2 = q*q - 2*j*l - speed*speed + p*p + r*r
        local a3 = 2*j*q + 2*h*p + 2*k*r
        local a4 = j*j + h*h + k*k
        local A, B, C, D = a1/a0, a2/a0, a3/a0, a4/a0
        local sq_A = A*A
        local P = -0.375*sq_A + B
        local Q = 0.125*sq_A*A - 0.5*A*B + C
        local R = -(3/256)*sq_A*sq_A + 0.0625*sq_A*B - 0.25*A*C + D
        local z = isZero(R) and select(1, solveCubic(1, 0, P, Q))
            or select(1, solveCubic(1, -0.5*P, -R, 0.5*R*P - 0.125*Q*Q))
        if not z then return nil end
        local u, v = z*z - R, 2*z - P
        if u < 0 or v < 0 then return nil end
        u, v = math.sqrt(u), math.sqrt(v)
        local roots = {}
        local function quad(b, c)
            local disc = b*b - 4*c
            if disc < 0 then return end
            local s = math.sqrt(disc)
            table.insert(roots, (-b + s)/2)
            table.insert(roots, (-b - s)/2)
        end
        if Q < 0 then quad(-v, z-u); quad(v, z+u)
        else quad(v, z-u); quad(-v, z+u) end
        local bestT
        for _, t in ipairs(roots) do
            local tt = t - 0.25*A
            if tt > 0 and (not bestT or tt < bestT) then bestT = tt end
        end
        if not bestT then return nil end
        return origin + Vector3.new(
            (h + p*bestT)/bestT,
            (j + q*bestT - l*bestT*bestT)/bestT,
            (k + r*bestT)/bestT)
    end
    return M
end)()

-- ═══════════════════════════════════════════════════════════════
-- [7] CONFIG
-- ═══════════════════════════════════════════════════════════════
local Config = {
    TeamCheck = true,
    SilentAim = false, SilentAimKey = "Always",
    SilentAimFOV = 200, SilentAimPart = "Head",
    SilentAimVisCheck = false, SilentAimHitChance = 100,
    SilentAimPredict = false,
    Aimbot = false, AimbotKey = "MB2",
    AimbotFOVDeg = 20, AimbotSmooth = 20,
    AimbotPart = "Head", AimbotVisCheck = true,
    AimbotPredict = false,
    TriggerBot = false, TriggerKey = "MB2",
    TriggerDelay = 0.05, TriggerMaxDist = 500,
    ESP = false, ESPTeamCheck = true,
    ESPBox = true, ESPName = true, ESPHealth = true,
    ESPDistance = true, ESPTracers = true,
    ESPMaxDist = 2000,
    ESPColor = Color3.fromRGB(230, 230, 240),
    Crosshair = false, CrosshairStyle = "cross",
    CrosshairColor = Color3.fromRGB(0, 255, 170),
    CrosshairLength = 6, CrosshairGap = 3, CrosshairThickness = 1,
    CrosshairDot = false,
    FOVCircleSilent = true, FOVCircleAimbot = true,
    FOVCircleColor = Color3.fromRGB(124, 92, 255),
    HitMarker = true, HitSound = true,
    HitMarkerColor = Color3.fromRGB(255, 255, 255),
    TargetHUD = true,
    TargetHUDPos = Vector2.new(16, 200),
    Fly = false, FlySpeed = 60,
    Speed = false, SpeedValue = 40,
    Weather = false, WeatherType = "snow",
    WeatherRate = 100, WeatherColor = Color3.fromRGB(255, 255, 255),
    Chams = false,
    ChamsFill = Color3.fromRGB(124, 92, 255),
    ChamsFillTrans = 0.5,
    ChamsOutline = Color3.fromRGB(255, 255, 255),
    ChamsOutlineTrans = 0,
    Watermark = true, MenuKey = "RightShift",
    ShowMenu = false, MenuTab = "Combat",
}

local SilentState = { Target = nil, Part = nil }
local AimbotState = { Target = nil, Part = nil }

-- ═══════════════════════════════════════════════════════════════
-- [8] VISIBILITY / TEAM
-- ═══════════════════════════════════════════════════════════════
local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
local _visChar = nil

local function isVisible(worldPos)
    local mc = lp.Character
    if mc ~= _visChar then
        visParams.FilterDescendantsInstances = { mc }
        _visChar = mc
    end
    local hit = workspace:Raycast(Camera.CFrame.Position, worldPos - Camera.CFrame.Position, visParams)
    if not hit then return true end
    local m = hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model")
    if m and Players:GetPlayerFromCharacter(m) then return true end
    return (hit.Position - worldPos).Magnitude < 3
end

local function isEnemy(plr)
    if not Config.TeamCheck then return plr ~= lp end
    if not plr or plr == lp then return false end
    local a, b = lp:GetAttribute("TeamID"), plr:GetAttribute("TeamID")
    if a == nil or b == nil then
        return not (lp.Team and plr.Team and lp.Team == plr.Team)
    end
    return a ~= b
end

-- ═══════════════════════════════════════════════════════════════
-- [9] UI BASE
-- ═══════════════════════════════════════════════════════════════
local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
local ScreenGui = Instance.new("ScreenGui")
ProtectGui(ScreenGui)
ScreenGui.Name = "VortexHub"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = gethui and gethui() or CoreGui end)
if not ScreenGui.Parent then pcall(function() ScreenGui.Parent = lp:WaitForChild("PlayerGui") end) end

local UI = {
    Font        = Enum.Font.GothamMedium,
    FontBold    = Enum.Font.GothamBold,
    FontColor   = Color3.fromHex("e8e8e8"),
    FontDim     = Color3.fromHex("8a8f98"),
    Background  = Color3.fromHex("0f1114"),
    Panel       = Color3.fromHex("1a1d22"),
    Outline     = Color3.fromHex("2a2d33"),
    Accent      = Color3.fromHex("7c5cff"),
    AccentDark  = Color3.fromHex("5a43c7"),
    OnColor     = Color3.fromHex("7c5cff"),
    OffColor    = Color3.fromHex("3a3d44"),
    Success     = Color3.fromHex("3ddc84"),
    Danger      = Color3.fromHex("ff4560"),
    Radius      = isIOS and 12 or 10,
    RowHeight   = isIOS and 44 or (isMobile and 38 or 32),
    FontSize    = isIOS and 15 or (isMobile and 14 or 13),
    FontSmall   = isIOS and 13 or (isMobile and 12 or 11),
}

local function round(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or UI.Radius)
    c.Parent = inst
    return c
end
local function outline(inst, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or UI.Outline
    s.Thickness = thick or 1
    s.Parent = inst
    return s
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    table.insert(_conns, handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = frame.Position
        end
    end))
    table.insert(_conns, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    table.insert(_conns, UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local notifyQueue = {}
local function Notify(text, dur)
    dur = dur or 4
    local W = isIOS and 240 or (isMobile and 220 or 280)
    local n = Instance.new("Frame")
    n.Size = UDim2.fromOffset(W, isIOS and 48 or 40)
    n.Position = UDim2.new(1, -(W + 12), 0, 60 + #notifyQueue * (isIOS and 54 or 46))
    n.BackgroundColor3 = UI.Panel
    n.BorderSizePixel = 0
    n.Parent = ScreenGui
    round(n, 8)
    outline(n, UI.Outline)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, -16)
    bar.Position = UDim2.new(0, 8, 0, 8)
    bar.BackgroundColor3 = UI.Accent
    bar.BorderSizePixel = 0
    bar.Parent = n
    round(bar, 2)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -30, 1, 0)
    lbl.Position = UDim2.fromOffset(20, 0)
    lbl.Font = UI.Font
    lbl.TextSize = isIOS and 14 or (isMobile and 13 or 12)
    lbl.TextColor3 = UI.FontColor
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Text = text
    lbl.Parent = n

    table.insert(notifyQueue, n)
    task.delay(dur, function()
        if not n.Parent then return end
        local tw = TweenService:Create(n, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
        tw:Play()
        for _, c in ipairs(n:GetDescendants()) do
            if c:IsA("TextLabel") then
                TweenService:Create(c, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
            end
        end
        tw.Completed:Connect(function()
            local i = table.find(notifyQueue, n)
            if i then table.remove(notifyQueue, i) end
            for idx, nn in ipairs(notifyQueue) do
                pcall(function()
                    nn.Position = UDim2.new(1, -(W + 12), 0, 60 + (idx - 1) * (isIOS and 54 or 46))
                end)
            end
            pcall(function() n:Destroy() end)
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- [10] WATERMARK
-- ═══════════════════════════════════════════════════════════════
local WM_W = isIOS and 240 or (isMobile and 220 or 280)
local wm = Instance.new("Frame")
wm.Size = UDim2.fromOffset(WM_W, isIOS and 30 or 26)
wm.Position = UDim2.new(0.5, -WM_W/2, 0, 8)
wm.BackgroundColor3 = UI.Panel
wm.BorderSizePixel = 0
wm.Active = true
wm.Parent = ScreenGui
round(wm, 8)
outline(wm, UI.Outline)

local wmAccent = Instance.new("Frame")
wmAccent.Size = UDim2.new(1, 0, 0, 2)
wmAccent.Position = UDim2.new(0, 0, 0, 0)
wmAccent.BackgroundColor3 = UI.Accent
wmAccent.BorderSizePixel = 0
wmAccent.Parent = wm

local wmLabel = Instance.new("TextLabel")
wmLabel.BackgroundTransparency = 1
wmLabel.Size = UDim2.new(1, -16, 1, 0)
wmLabel.Position = UDim2.fromOffset(8, 0)
wmLabel.Font = UI.Font
wmLabel.TextSize = isIOS and 13 or 12
wmLabel.TextColor3 = UI.FontColor
wmLabel.TextXAlignment = Enum.TextXAlignment.Left
wmLabel.TextTruncate = Enum.TextTruncate.AtEnd
wmLabel.Text = "Vortex Hub v1.6.4"
wmLabel.Parent = wm

makeDraggable(wm)

-- ═══════════════════════════════════════════════════════════════
-- [11] MENU
-- ═══════════════════════════════════════════════════════════════
local vpNow = Camera.ViewportSize
local MENU_W = math.clamp(vpNow.X - 60, 280, isIOS and 340 or 400)
local MENU_H = math.clamp(vpNow.Y - 120, 340, isIOS and 500 or 560)

local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(MENU_W, MENU_H)
menu.Position = UDim2.new(0.5, -MENU_W/2, 0.5, -MENU_H/2)
menu.BackgroundColor3 = UI.Background
menu.BorderSizePixel = 0
menu.Visible = false
menu.Active = true
menu.Parent = ScreenGui
round(menu, 14)
outline(menu, UI.Outline)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, isIOS and 50 or 42)
titleBar.BackgroundTransparency = 1
titleBar.Active = true
titleBar.Parent = menu

local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.new(1, -28, 0, 2)
titleAccent.Position = UDim2.new(0, 14, 0, 12)
titleAccent.BackgroundColor3 = UI.Accent
titleAccent.BorderSizePixel = 0
titleAccent.Parent = titleBar
round(titleAccent, 1)

local menuTitle = Instance.new("TextLabel")
menuTitle.BackgroundTransparency = 1
menuTitle.Size = UDim2.new(1, -80, 0, 28)
menuTitle.Position = UDim2.new(0, 16, 0, 16)
menuTitle.Font = UI.FontBold
menuTitle.TextSize = isIOS and 16 or 14
menuTitle.TextColor3 = UI.FontColor
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Text = "Vortex Hub"
menuTitle.Parent = titleBar

local closeBtnSize = isIOS and 40 or 32
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(closeBtnSize, closeBtnSize)
closeBtn.Position = UDim2.new(1, -(closeBtnSize + 8), 0, (isIOS and 50 or 42)/2 - closeBtnSize/2)
closeBtn.BackgroundColor3 = UI.Panel
closeBtn.BorderSizePixel = 0
closeBtn.Font = UI.FontBold
closeBtn.TextSize = isIOS and 20 or 16
closeBtn.TextColor3 = UI.FontDim
closeBtn.Text = "×"
closeBtn.AutoButtonColor = false
closeBtn.Parent = titleBar
round(closeBtn, 10)
closeBtn.MouseButton1Click:Connect(function()
    Config.ShowMenu = false
    menu.Visible = false
end)
closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = UI.Danger, TextColor3 = Color3.new(1,1,1) }):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = UI.Panel, TextColor3 = UI.FontDim }):Play()
end)

makeDraggable(menu, titleBar)

local tabH = isIOS and 40 or 32
local tabBar = Instance.new("Frame")
tabBar.BackgroundTransparency = 1
tabBar.Position = UDim2.fromOffset(10, isIOS and 56 or 48)
tabBar.Size = UDim2.new(1, -20, 0, tabH)
tabBar.Parent = menu

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Parent = tabBar

local TAB_NAMES = { "Combat", "Visuals", "Move", "Misc" }
local tabButtons = {}
local tabUnderlines = {}
local tabPages = {}

local function switchTab(name)
    if not tabPages[name] then name = "Combat" end
    Config.MenuTab = name
    for n, b in pairs(tabButtons) do
        local active = (n == name)
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = active and UI.Panel or UI.Background,
            TextColor3 = active and UI.FontColor or UI.FontDim,
        }):Play()
        if tabUnderlines[n] then
            TweenService:Create(tabUnderlines[n], TweenInfo.new(0.15), {
                BackgroundTransparency = active and 0 or 1,
            }):Play()
        end
    end
    for n, p in pairs(tabPages) do
        p.Visible = (n == name)
    end
end

local tabWidth = math.floor((MENU_W - 20 - (4 * (#TAB_NAMES - 1))) / #TAB_NAMES)

local function makeTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(tabWidth, tabH)
    btn.LayoutOrder = order
    btn.BackgroundColor3 = UI.Background
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = UI.FontBold
    btn.TextSize = isIOS and 13 or 12
    btn.TextColor3 = UI.FontDim
    btn.Text = name
    btn.Parent = tabBar
    round(btn, 8)
    tabButtons[name] = btn

    local ul = Instance.new("Frame")
    ul.Size = UDim2.new(0.4, 0, 0, 2)
    ul.Position = UDim2.new(0.3, 0, 1, -2)
    ul.BackgroundColor3 = UI.Accent
    ul.BorderSizePixel = 0
    ul.BackgroundTransparency = 1
    ul.Parent = btn
    round(ul, 1)
    tabUnderlines[name] = ul

    local pageTop = (isIOS and 56 or 48) + tabH + 10
    local page = Instance.new("ScrollingFrame")
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Position = UDim2.fromOffset(10, pageTop)
    page.Size = UDim2.new(1, -20, 1, -(pageTop + 10))
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ScrollingEnabled = true
    page.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    page.ScrollBarThickness = isIOS and 6 or 3
    page.ScrollBarImageColor3 = UI.Accent
    page.ScrollBarImageTransparency = 0.4
    page.Visible = false
    page.Parent = menu
    tabPages[name] = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = page

    btn.MouseButton1Click:Connect(function() switchTab(name) end)
end

for i, name in ipairs(TAB_NAMES) do makeTab(name, i) end

local function fmtNum(v, step)
    if step and step < 1 then
        local dec = math.max(0, -math.floor(math.log10(step) + 1e-9))
        return string.format("%." .. dec .. "f", v)
    end
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return tostring(v)
end

local function addToggle(page, label, key, onChange)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, UI.RowHeight)
    row.BackgroundColor3 = UI.Panel
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = page
    round(row, UI.Radius)

    local hoverStroke = outline(row, UI.Outline)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -90, 1, 0)
    lbl.Position = UDim2.fromOffset(16, 0)
    lbl.Font = UI.Font
    lbl.TextSize = UI.FontSize
    lbl.TextColor3 = UI.FontColor
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local trackW = isIOS and 52 or 40
    local trackH = isIOS and 30 or 22
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(trackW, trackH)
    track.Position = UDim2.new(1, -16 - trackW, 0.5, -trackH/2)
    track.BackgroundColor3 = UI.OffColor
    track.BorderSizePixel = 0
    track.Parent = row
    round(track, trackH/2)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(trackH - 4, trackH - 4)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = UI.FontDim
    knob.BorderSizePixel = 0
    knob.Parent = track
    round(knob, (trackH - 4)/2)

    local function update(animate)
        local ti = animate and TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) or TweenInfo.new(0)
        if Config[key] then
            TweenService:Create(track, ti, { BackgroundColor3 = UI.OnColor }):Play()
            TweenService:Create(knob, ti, {
                Position = UDim2.fromOffset(trackW - trackH + 2, 2),
                BackgroundColor3 = Color3.new(1, 1, 1),
            }):Play()
        else
            TweenService:Create(track, ti, { BackgroundColor3 = UI.OffColor }):Play()
            TweenService:Create(knob, ti, {
                Position = UDim2.fromOffset(2, 2),
                BackgroundColor3 = UI.FontDim,
            }):Play()
        end
    end

    row.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        update(true)
        if onChange then pcall(onChange, Config[key]) end
    end)

    row.MouseEnter:Connect(function() hoverStroke.Color = UI.Accent end)
    row.MouseLeave:Connect(function() hoverStroke.Color = UI.Outline end)

    update(false)
    return row
end

local function addSlider(page, label, key, min, max, step, suffix, onChange)
    local ROW_H = UI.RowHeight + (isIOS and 24 or 16)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.BackgroundColor3 = UI.Panel
    row.BorderSizePixel = 0
    row.Parent = page
    round(row, UI.Radius)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -110, 0, 20)
    lbl.Position = UDim2.fromOffset(16, 8)
    lbl.Font = UI.Font
    lbl.TextSize = UI.FontSize - 1
    lbl.TextColor3 = UI.FontColor
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local val = Instance.new("TextLabel")
    val.BackgroundTransparency = 1
    val.Size = UDim2.new(0, 90, 0, 20)
    val.Position = UDim2.new(1, -106, 0, 8)
    val.Font = UI.FontBold
    val.TextSize = UI.FontSize - 1
    val.TextColor3 = UI.Accent
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = fmtNum(Config[key], step) .. (suffix or "")
    val.Parent = row

    local trackY = UI.RowHeight + (isIOS and 8 or 0)
    local trackH = isIOS and 8 or 6
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -32, 0, trackH)
    track.Position = UDim2.fromOffset(16, trackY)
    track.BackgroundColor3 = UI.Outline
    track.BorderSizePixel = 0
    track.Parent = row
    round(track, trackH/2)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = UI.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    round(fill, trackH/2)

    local TH = isIOS and 26 or 18
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.fromOffset(TH, TH)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(0, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 3
    thumb.Parent = track
    round(thumb, TH/2)

    local hitboxH = isIOS and 44 or 28
    local hitbox = Instance.new("TextButton")
    hitbox.Size = UDim2.new(1, 0, 0, hitboxH)
    hitbox.Position = UDim2.new(0, 0, 0.5, -hitboxH/2)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.AutoButtonColor = false
    hitbox.ZIndex = 4
    hitbox.Parent = track

    local function setFromX(x)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local p = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        local v = math.floor((min + (max - min) * p) / step + 0.5) * step
        v = math.clamp(v, min, max)
        v = tonumber(string.format("%.6f", v))
        Config[key] = v
        fill.Size = UDim2.new(p, 0, 1, 0)
        thumb.Position = UDim2.new(p, 0, 0.5, 0)
        val.Text = fmtNum(v, step) .. (suffix or "")
        if onChange then pcall(onChange, v) end
    end

    hitbox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            _G.__VortexActiveSlider = setFromX
            setFromX(i.Position.X)
        end
    end)

    local p0 = (Config[key] - min) / (max - min)
    fill.Size = UDim2.new(p0, 0, 1, 0)
    thumb.Position = UDim2.new(p0, 0, 0.5, 0)
    return row
end

local function addHeader(page, text)
    local h = Instance.new("Frame")
    h.BackgroundTransparency = 1
    h.Size = UDim2.new(1, 0, 0, isIOS and 26 or 22)
    h.Parent = page

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = UI.Outline
    line.BorderSizePixel = 0
    line.Parent = h

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundColor3 = UI.Background
    lbl.Size = UDim2.new(0, 120, 1, 0)
    lbl.Position = UDim2.new(0.5, -60, 0, 0)
    lbl.Font = UI.FontBold
    lbl.TextSize = UI.FontSmall
    lbl.TextColor3 = UI.Accent
    lbl.Text = " " .. text .. " "
    lbl.Parent = h
    return h
end

local function addDropdown(page, label, key, options, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, UI.RowHeight)
    row.BackgroundColor3 = UI.Panel
    row.BorderSizePixel = 0
    row.Parent = page
    round(row, UI.Radius)
    outline(row, UI.Outline)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -140, 1, 0)
    lbl.Position = UDim2.fromOffset(16, 0)
    lbl.Font = UI.Font
    lbl.TextSize = UI.FontSize
    lbl.TextColor3 = UI.FontColor
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 0, UI.RowHeight - 10)
    btn.Position = UDim2.new(1, -120, 0.5, -(UI.RowHeight - 10)/2)
    btn.BackgroundColor3 = UI.Background
    btn.BorderSizePixel = 0
    btn.Font = UI.FontBold
    btn.TextSize = UI.FontSmall
    btn.TextColor3 = UI.Accent
    btn.AutoButtonColor = false
    btn.Parent = row
    round(btn, 6)
    outline(btn, UI.Outline)

    local idx = table.find(options, Config[key]) or 1
    Config[key] = options[idx]
    local function refresh() btn.Text = tostring(options[idx]) end
    refresh()

    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        Config[key] = options[idx]
        refresh()
        if onChange then pcall(onChange, Config[key]) end
    end)
    return row
end

local function addColor(page, label, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, UI.RowHeight)
    row.BackgroundColor3 = UI.Panel
    row.BorderSizePixel = 0
    row.Parent = page
    round(row, UI.Radius)
    outline(row, UI.Outline)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -180, 1, 0)
    lbl.Position = UDim2.fromOffset(16, 0)
    lbl.Font = UI.Font
    lbl.TextSize = UI.FontSize
    lbl.TextColor3 = UI.FontColor
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.fromOffset(24, 24)
    swatch.Position = UDim2.new(1, -158, 0.5, -12)
    swatch.BackgroundColor3 = Config[key]
    swatch.BorderSizePixel = 0
    swatch.Parent = row
    round(swatch, 5)
    outline(swatch, UI.Outline)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 110, 0, UI.RowHeight - 10)
    box.Position = UDim2.new(1, -126, 0.5, -(UI.RowHeight - 10)/2)
    box.BackgroundColor3 = UI.Background
    box.BorderSizePixel = 0
    box.Font = UI.FontBold
    box.TextSize = UI.FontSmall
    box.TextColor3 = UI.Accent
    box.Text = "#" .. Config[key]:ToHex()
    box.ClearTextOnFocus = false
    box.Parent = row
    round(box, 6)
    outline(box, UI.Outline)

    box.FocusLost:Connect(function()
        local txt = box.Text:gsub("#", ""):gsub("%s", "")
        local ok, col = pcall(Color3.fromHex, txt)
        if ok and typeof(col) == "Color3" then
            Config[key] = col
            swatch.BackgroundColor3 = col
            box.Text = "#" .. col:ToHex()
        else
            box.Text = "#" .. Config[key]:ToHex()
        end
    end)
    return row
end

local KEY_OPTS    = { "None", "MB1", "MB2", "E", "Q", "F", "R", "T", "G", "C", "V", "X", "Z",
                      "LeftShift", "LeftControl", "RightShift", "Always" }
local PART_OPTS   = { "Head", "HumanoidRootPart", "UpperTorso", "Torso", "HitboxHead" }
local WEATHER_OPTS = { "snow", "rain" }

do
    local P = tabPages.Combat
    addHeader(P, "SILENT AIM")
    addToggle(P, "Silent Aim", "SilentAim")
    addDropdown(P, "Activation", "SilentAimKey", KEY_OPTS)
    addDropdown(P, "Target part", "SilentAimPart", PART_OPTS)
    addSlider(P, "FOV radius", "SilentAimFOV", 20, 600, 5, "px")
    addSlider(P, "Hit chance", "SilentAimHitChance", 1, 100, 1, "%")
    addToggle(P, "Visibility check", "SilentAimVisCheck")
    addToggle(P, "Prediction", "SilentAimPredict")
    addToggle(P, "FOV circle", "FOVCircleSilent")

    addHeader(P, "AIMBOT")
    addToggle(P, "Aimbot", "Aimbot")
    addDropdown(P, "Activation", "AimbotKey", KEY_OPTS)
    addDropdown(P, "Target part", "AimbotPart", PART_OPTS)
    addSlider(P, "FOV (deg)", "AimbotFOVDeg", 1, 90, 1, "°")
    addSlider(P, "Smooth", "AimbotSmooth", 0, 100, 1, "")
    addToggle(P, "Visibility check", "AimbotVisCheck")
    addToggle(P, "Prediction", "AimbotPredict")
    addToggle(P, "FOV circle", "FOVCircleAimbot")

    addHeader(P, "TRIGGER BOT")
    addToggle(P, "Trigger Bot", "TriggerBot")
    addDropdown(P, "Activation", "TriggerKey", KEY_OPTS)
    addSlider(P, "Delay", "TriggerDelay", 0, 1, 0.01, "s")
    addSlider(P, "Max distance", "TriggerMaxDist", 50, 2000, 25, "m")

    addHeader(P, "TARGETING")
    addToggle(P, "Team check", "TeamCheck")
end

do
    local P = tabPages.Visuals
    addHeader(P, "ESP")
    addToggle(P, "ESP", "ESP")
    addToggle(P, "Team check", "ESPTeamCheck")
    addToggle(P, "Box", "ESPBox")
    addToggle(P, "Name", "ESPName")
    addToggle(P, "Health", "ESPHealth")
    addToggle(P, "Distance", "ESPDistance")
    addToggle(P, "Tracers", "ESPTracers")
    addSlider(P, "Max distance", "ESPMaxDist", 100, 5000, 50, "m")
    addColor(P, "ESP color", "ESPColor")

    addHeader(P, "CHAMS")
    addToggle(P, "Chams", "Chams")
    addColor(P, "Fill color", "ChamsFill")
    addColor(P, "Outline color", "ChamsOutline")
    addSlider(P, "Fill transparency", "ChamsFillTrans", 0, 1, 0.05, "")
    addSlider(P, "Outline transparency", "ChamsOutlineTrans", 0, 1, 0.05, "")

    addHeader(P, "CROSSHAIR")
    addToggle(P, "Crosshair", "Crosshair")
    addDropdown(P, "Style", "CrosshairStyle", { "cross", "x", "t", "dot" })
    addColor(P, "Color", "CrosshairColor")
    addSlider(P, "Gap", "CrosshairGap", 0, 20, 1, "px")
    addSlider(P, "Length", "CrosshairLength", 2, 30, 1, "px")
    addSlider(P, "Thickness", "CrosshairThickness", 1, 5, 1, "px")
    addToggle(P, "Center dot", "CrosshairDot")

    addHeader(P, "FEEDBACK")
    addToggle(P, "Hit marker", "HitMarker")
    addToggle(P, "Hit sound", "HitSound")
    addColor(P, "Marker color", "HitMarkerColor")
    addToggle(P, "Target HUD", "TargetHUD")

    addHeader(P, "WEATHER")
    addToggle(P, "Weather", "Weather")
    addDropdown(P, "Type", "WeatherType", WEATHER_OPTS)
    addColor(P, "Color", "WeatherColor")
    addSlider(P, "Rate", "WeatherRate", 100, 300, 10, "")
end

do
    local P = tabPages.Move
    addHeader(P, "FLY")
    addToggle(P, "Fly", "Fly")
    addSlider(P, "Speed", "FlySpeed", 10, 200, 1, " st")

    addHeader(P, "SPEED")
    addToggle(P, "Speed", "Speed")
    addSlider(P, "Value", "SpeedValue", 16, 150, 1, "")
end

do
    local P = tabPages.Misc
    addHeader(P, "SETTINGS")
    addToggle(P, "Watermark", "Watermark")
    addDropdown(P, "Menu key (PC)", "MenuKey",
        { "RightShift", "LeftShift", "RightControl", "LeftControl", "Insert", "Home", "Delete" })
    addHeader(P, "FOV CIRCLE COLOR")
    addColor(P, "Circle color", "FOVCircleColor")
    addHeader(P, "ABOUT")
    local info = Instance.new("TextLabel")
    info.BackgroundTransparency = 1
    info.Size = UDim2.new(1, -20, 0, 160)
    info.Position = UDim2.fromOffset(10, 0)
    info.Font = UI.Font
    info.TextSize = UI.FontSmall
    info.TextColor3 = UI.FontDim
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.TextWrapped = true
    info.Text = "Vortex Hub v1.6.4\nExecutor: " .. execName .. "\nMobile: " .. tostring(isMobile)
        .. "\niOS mode: " .. tostring(isIOS)
        .. "\n\nTap nút V (bên trái) để mở menu\nAPI: _G.VORTEX_HUB\nDropdown = tap để đổi giá trị\nColor = tap vào ô hex để chỉnh"
    info.Parent = P
end

switchTab(Config.MenuTab or "Combat")

table.insert(_conns, UserInputService.InputChanged:Connect(function(i)
    local fn = _G.__VortexActiveSlider
    if not fn then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement
       or i.UserInputType == Enum.UserInputType.Touch then
        fn(i.Position.X)
    end
end))
table.insert(_conns, UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
       or i.UserInputType == Enum.UserInputType.Touch then
        _G.__VortexActiveSlider = nil
    end
end))

-- ═══════════════════════════════════════════════════════════════
-- [12] FLOATING TOGGLE BUTTON + mobile fly buttons
-- ═══════════════════════════════════════════════════════════════
if isMobile then
    local btnSize = isIOS and 64 or 56
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.fromOffset(btnSize, btnSize)
    toggleBtn.Position = UDim2.new(0, 12, 0.4, -btnSize/2)
    toggleBtn.BackgroundColor3 = UI.Accent
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.Font = UI.FontBold
    toggleBtn.TextSize = isIOS and 22 or 18
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Text = "V"
    toggleBtn.Parent = ScreenGui
    round(toggleBtn, btnSize/2)
    outline(toggleBtn, UI.AccentDark, isIOS and 3 or 2)

    local pulse = TweenService:Create(toggleBtn, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundColor3 = UI.AccentDark })
    pulse:Play()

    toggleBtn.MouseButton1Click:Connect(function()
        Config.ShowMenu = not Config.ShowMenu
        menu.Visible = Config.ShowMenu
    end)

    makeDraggable(toggleBtn)

    local flyUpBtn = Instance.new("TextButton")
    flyUpBtn.Size = UDim2.fromOffset(btnSize, btnSize)
    flyUpBtn.Position = UDim2.new(0, 12, 0.7, -btnSize - 8)
    flyUpBtn.BackgroundColor3 = UI.Success
    flyUpBtn.BorderSizePixel = 0
    flyUpBtn.AutoButtonColor = false
    flyUpBtn.Font = UI.FontBold
    flyUpBtn.TextSize = isIOS and 26 or 22
    flyUpBtn.TextColor3 = Color3.new(1, 1, 1)
    flyUpBtn.Text = "↑"
    flyUpBtn.Visible = false
    flyUpBtn.Parent = ScreenGui
    round(flyUpBtn, btnSize/2)
    outline(flyUpBtn, UI.Outline, 2)

    local flyDownBtn = Instance.new("TextButton")
    flyDownBtn.Size = UDim2.fromOffset(btnSize, btnSize)
    flyDownBtn.Position = UDim2.new(0, 12, 0.7, 8)
    flyDownBtn.BackgroundColor3 = UI.Danger
    flyDownBtn.BorderSizePixel = 0
    flyDownBtn.AutoButtonColor = false
    flyDownBtn.Font = UI.FontBold
    flyDownBtn.TextSize = isIOS and 26 or 22
    flyDownBtn.TextColor3 = Color3.new(1, 1, 1)
    flyDownBtn.Text = "↓"
    flyDownBtn.Visible = false
    flyDownBtn.Parent = ScreenGui
    round(flyDownBtn, btnSize/2)
    outline(flyDownBtn, UI.Outline, 2)

    local flyUpHeld = false
    local flyDownHeld = false
    flyUpBtn.MouseButton1Down:Connect(function() flyUpHeld = true end)
    flyUpBtn.MouseButton1Up:Connect(function() flyUpHeld = false end)
    flyUpBtn.MouseLeave:Connect(function() flyUpHeld = false end)
    flyDownBtn.MouseButton1Down:Connect(function() flyDownHeld = true end)
    flyDownBtn.MouseButton1Up:Connect(function() flyDownHeld = false end)
    flyDownBtn.MouseLeave:Connect(function() flyDownHeld = false end)

    local flyVisCheck = tick()
    table.insert(_conns, RunService.Heartbeat:Connect(function()
        if tick() - flyVisCheck < 0.2 then return end
        flyVisCheck = tick()
        local shouldShow = Config.Fly and not Config.ShowMenu
        if flyUpBtn.Visible ~= shouldShow then
            flyUpBtn.Visible = shouldShow
            flyDownBtn.Visible = shouldShow
        end
    end))

    getgenv().__VortexFlyUp = function() return flyUpHeld end
    getgenv().__VortexFlyDown = function() return flyDownHeld end
end

table.insert(_conns, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not isMobile and Config.MenuKey and Enum.KeyCode[Config.MenuKey]
       and input.KeyCode == Enum.KeyCode[Config.MenuKey] then
        Config.ShowMenu = not Config.ShowMenu
        menu.Visible = Config.ShowMenu
    end
end))

-- ═══════════════════════════════════════════════════════════════
-- [13] FOV CIRCLES
-- ═══════════════════════════════════════════════════════════════
local _fovSilent, _fovAimbot
if Drawing and Drawing.new then
    _fovSilent = Drawing.new("Circle")
    _fovSilent.Filled = false; _fovSilent.NumSides = 48
    _fovSilent.Thickness = 1; _fovSilent.Transparency = 0.8
    _fovSilent.Visible = false
    _fovAimbot = Drawing.new("Circle")
    _fovAimbot.Filled = false; _fovAimbot.NumSides = 48
    _fovAimbot.Thickness = 1; _fovAimbot.Transparency = 0.8
    _fovAimbot.Visible = false
end

local function updateFOVCircles()
    local vp = Camera.ViewportSize
    if _fovSilent then
        if Config.SilentAim and Config.FOVCircleSilent then
            _fovSilent.Position = Vector2.new(vp.X/2, vp.Y/2)
            _fovSilent.Radius = Config.SilentAimFOV
            _fovSilent.Color = Config.FOVCircleColor
            _fovSilent.Visible = true
        else _fovSilent.Visible = false end
    end
    if _fovAimbot then
        if Config.Aimbot and Config.FOVCircleAimbot then
            local fovPx = (vp.Y/2) * math.tan(math.rad(Config.AimbotFOVDeg))
                          / math.tan(math.rad(Camera.FieldOfView/2))
            _fovAimbot.Position = Vector2.new(vp.X/2, vp.Y/2)
            _fovAimbot.Radius = math.clamp(fovPx, 4, math.max(vp.X, vp.Y))
            _fovAimbot.Color = Config.FOVCircleColor
            _fovAimbot.Visible = true
        else _fovAimbot.Visible = false end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- [14] HIT MARKER + SOUND
-- ═══════════════════════════════════════════════════════════════
local HitFX = { lines = {}, active = false, t0 = 0, sound = nil }
if Drawing and Drawing.new then
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 2; l.Visible = false
        table.insert(HitFX.lines, l)
    end
end
do
    local s = Instance.new("Sound")
    s.Name = "VortexHitSound"
    s.Volume = 0.5
    s.SoundId = "rbxassetid://5766898159"
    s.Parent = SoundService
    HitFX.sound = s
end

local function triggerHitFX(crit)
    HitFX.active = true
    HitFX.t0 = tick()
    if Config.HitSound and HitFX.sound then
        pcall(function()
            HitFX.sound.TimePosition = 0
            HitFX.sound.PlaybackSpeed = crit and 1.2 or 1
            HitFX.sound:Play()
        end)
    end
end

local function updateHitFX()
    if not HitFX.active then return end
    local a = tick() - HitFX.t0
    if a > 0.15 then
        HitFX.active = false
        for _, l in ipairs(HitFX.lines) do l.Visible = false end
        return
    end
    if not Config.HitMarker then
        for _, l in ipairs(HitFX.lines) do l.Visible = false end
        return
    end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X/2, vp.Y/2
    local gap = 4 + a * 30
    local len = 8 * (1 - a / 0.15)
    local col = Config.HitMarkerColor
    local arms = { { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }
    local d = 0.707
    for i, l in ipairs(HitFX.lines) do
        local a2 = arms[i]
        l.From = Vector2.new(cx + a2[1]*gap*d, cy + a2[2]*gap*d)
        l.To = Vector2.new(cx + a2[1]*(gap+len)*d, cy + a2[2]*(gap+len)*d)
        l.Color = col
        l.Transparency = 1 - (a / 0.15) * 0.5
        l.Visible = true
    end
end

-- Hit hook persistent
local _origReplicateFromServer = nil
local _hookedFighter = nil

local function tryHookHit()
    if not (Rivals.Ready and Rivals.Fighter) then return false end
    local lf = Rivals.Fighter.LocalFighter
    if not lf then return false end
    if _hookedFighter == lf then return true end

    if _hookedFighter and _origReplicateFromServer then
        pcall(function() _hookedFighter.ReplicateFromServer = _origReplicateFromServer end)
    end
    if type(lf.ReplicateFromServer) ~= "function" then return false end

    local old = lf.ReplicateFromServer
    _origReplicateFromServer = old
    _hookedFighter = lf

    lf.ReplicateFromServer = function(self, _type, ...)
        if _type == "DamageNumberEffect" then
            local args = {...}
            pcall(triggerHitFX, args[3] == true)
        end
        return old(self, _type, ...)
    end
    getgenv().__VortexHitHookInstalled = true
    return true
end

task.spawn(function()
    while not _unloaded do  -- [FIX #27]
        task.wait(0.5)
        pcall(tryHookHit)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- [15] TARGET HUD
-- ═══════════════════════════════════════════════════════════════
local TARGET_HUD = { target = nil, a = 0, hp = 1, name = "", dist = 0, tPoll = 0 }

local hudFrame = Instance.new("Frame")
hudFrame.Size = UDim2.fromOffset(180, 50)
hudFrame.Position = UDim2.fromOffset(Config.TargetHUDPos.X, Config.TargetHUDPos.Y)
hudFrame.BackgroundColor3 = UI.Panel
hudFrame.BackgroundTransparency = 0.1
hudFrame.BorderSizePixel = 0
hudFrame.Visible = false
hudFrame.Active = true
hudFrame.Parent = ScreenGui
round(hudFrame, 10)
outline(hudFrame, UI.Outline)

local hudAccent = Instance.new("Frame")
hudAccent.Size = UDim2.new(0, 3, 1, -16)
hudAccent.Position = UDim2.fromOffset(8, 8)
hudAccent.BackgroundColor3 = UI.Accent
hudAccent.BorderSizePixel = 0
hudAccent.Parent = hudFrame
round(hudAccent, 2)

local hudName = Instance.new("TextLabel")
hudName.BackgroundTransparency = 1
hudName.Size = UDim2.new(1, -30, 0, 18)
hudName.Position = UDim2.fromOffset(20, 6)
hudName.Font = UI.FontBold
hudName.TextSize = 14
hudName.TextColor3 = UI.FontColor
hudName.TextXAlignment = Enum.TextXAlignment.Left
hudName.TextTruncate = Enum.TextTruncate.AtEnd
hudName.Parent = hudFrame

local hudHPBg = Instance.new("Frame")
hudHPBg.Size = UDim2.new(1, -30, 0, 6)
hudHPBg.Position = UDim2.fromOffset(20, 26)
hudHPBg.BackgroundColor3 = UI.Outline
hudHPBg.BorderSizePixel = 0
hudHPBg.Parent = hudFrame
round(hudHPBg, 3)

local hudHPFill = Instance.new("Frame")
hudHPFill.Size = UDim2.new(1, 0, 1, 0)
hudHPFill.BackgroundColor3 = UI.Success
hudHPFill.BorderSizePixel = 0
hudHPFill.Parent = hudHPBg
round(hudHPFill, 3)

local hudInfo = Instance.new("TextLabel")
hudInfo.BackgroundTransparency = 1
hudInfo.Size = UDim2.new(1, -30, 0, 14)
hudInfo.Position = UDim2.fromOffset(20, 34)
hudInfo.Font = UI.Font
hudInfo.TextSize = 12
hudInfo.TextColor3 = UI.FontDim
hudInfo.TextXAlignment = Enum.TextXAlignment.Left
hudInfo.Parent = hudFrame

makeDraggable(hudFrame)

local function updateTargetHUD()
    if not Config.TargetHUD then
        hudFrame.Visible = false
        return
    end
    local now = tick()
    if now - TARGET_HUD.tPoll > 0.1 then
        TARGET_HUD.tPoll = now
        TARGET_HUD.target = SilentState.Target or AimbotState.Target
    end
    local tgt = TARGET_HUD.target
    if not tgt or not tgt.Character or tgt.Health <= 0 or not tgt.Player then
        TARGET_HUD.a = math.max(0, TARGET_HUD.a - 0.1)
        if TARGET_HUD.a <= 0.01 then
            hudFrame.Visible = false
            TARGET_HUD.name = ""
            TARGET_HUD.dist = 0
            TARGET_HUD.hp = 1
            return
        end
    else
        TARGET_HUD.a = math.min(1, TARGET_HUD.a + 0.1)
        TARGET_HUD.name = tgt.Player.Name
        local frac = math.clamp(tgt.Health / math.max(tgt.MaxHealth, 1), 0, 1)
        TARGET_HUD.hp = TARGET_HUD.hp + (frac - TARGET_HUD.hp) * 0.3
        local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and tgt.RootPart then
            TARGET_HUD.dist = (myRoot.Position - tgt.RootPart.Position).Magnitude
        end
    end
    hudFrame.Visible = true
    hudFrame.BackgroundTransparency = 1 - TARGET_HUD.a * 0.9
    hudName.Text = TARGET_HUD.name
    hudInfo.Text = string.format("%d HP · %dm", math.floor(TARGET_HUD.hp * 100 + 0.5), math.floor(TARGET_HUD.dist))
    hudHPFill.Size = UDim2.new(TARGET_HUD.hp, 0, 1, 0)
    hudHPFill.BackgroundColor3 = Color3.fromRGB(
        math.floor(255 * (1 - TARGET_HUD.hp)),
        math.floor(255 * TARGET_HUD.hp), 0)
end

-- ═══════════════════════════════════════════════════════════════
-- [16] SILENT AIM
-- ═══════════════════════════════════════════════════════════════
local _origRaycast = nil

local function getSilentTarget()
    if not Entity.isAlive or not Entity.character then return nil, nil end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, bestD, bestPart = nil, Config.SilentAimFOV, nil
    for _, ent in ipairs(Entity.List) do
        if ent.Targetable and ent.Health > 0 and ent.Character and ent.Player and isEnemy(ent.Player) then
            local p = ent.Character:FindFirstChild(Config.SilentAimPart)
                or ent.Character:FindFirstChild("HitboxHead")
                or ent.Character:FindFirstChild("Head")
            if p then
                local sp, on = Camera:WorldToViewportPoint(p.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD and (not Config.SilentAimVisCheck or isVisible(p.Position)) then
                        best, bestD, bestPart = ent, d, p
                    end
                end
            end
        end
    end
    return best, bestPart
end

local function silentKeyDown()
    local k = Config.SilentAimKey
    if k == "None" then return false end
    if k == "Always" then return true end
    if k == "MB1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    if k == "MB2" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    local kc = Enum.KeyCode[k]
    return kc and UserInputService:IsKeyDown(kc) or false
end

local function resolveAimArgIndex(args)
    local a1 = args[1]
    local isSelf = false
    if typeof(a1) == "Instance" then isSelf = true
    elseif type(a1) == "table" and (a1.Character ~= nil or a1.RootPart ~= nil or a1.Humanoid ~= nil) then
        isSelf = true
    end
    if isSelf then
        if typeof(args[4]) == "Vector3" then return 4 end
        if typeof(args[3]) == "Vector3" then return 3 end
        return 4
    end
    if typeof(args[3]) == "Vector3" then return 3 end
    if typeof(args[4]) == "Vector3" then return 4 end
    return nil
end

local function tryInstallSilentHook()
    if _origRaycast then return true end
    if not (Rivals.Util and type(Rivals.Util.Raycast) == "function") then return false end

    local old = Rivals.Util.Raycast
    _origRaycast = old

    Rivals.Util.Raycast = function(...)
        if not Config.SilentAim then return old(...) end
        if not silentKeyDown() then return old(...) end
        if math.random(1, 100) > Config.SilentAimHitChance then return old(...) end

        local callerOK = true
        if debug and debug.info then
            local matched, foundAny = false, false
            for lvl = 2, 8 do
                local ok, n = pcall(debug.info, lvl, "n")
                if ok and n and n ~= "" then
                    foundAny = true
                    local s = tostring(n):lower()
                    if s:find("shoot") or s:find("gun") or s:find("item")
                       or s:find("weapon") or s:find("fire") or s:find("attack")
                       or s:find("trigger") or s:find("hit") then
                        matched = true
                        break
                    end
                end
            end
            if foundAny and not matched then callerOK = false end
        end
        if not callerOK then return old(...) end

        local tgt, part = getSilentTarget()
        if not tgt or not part then return old(...) end
        SilentState.Target, SilentState.Part = tgt, part

        local aimPos = part.Position
        if Config.SilentAimPredict and tgt.RootPart then
            local predicted = Prediction.Solve(
                Camera.CFrame.Position, 3000, workspace.Gravity,
                part.Position, tgt.RootPart.AssemblyLinearVelocity)
            if predicted then aimPos = predicted end
        end

        local args = table.pack(...)
        local idx = resolveAimArgIndex(args)
        if idx and args.n >= idx then
            args[idx] = aimPos
        end
        return old(table.unpack(args, 1, args.n))
    end
    return true
end

task.spawn(function()
    while not _origRaycast and not _unloaded do  -- [FIX #28]
        if tryInstallSilentHook() then
            print("[Vortex] Silent Aim hook installed")
            break
        end
        task.wait(0.5)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- [17] AIMBOT
-- ═══════════════════════════════════════════════════════════════
local function aimbotKeyDown()
    local k = Config.AimbotKey
    if k == "Always" then return true end
    if k == "None" then return false end
    if k == "MB1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    if k == "MB2" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    local kc = Enum.KeyCode[k]
    return kc and UserInputService:IsKeyDown(kc) or false
end

local function findAimbotTarget()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local fovPx = (vp.Y/2) * math.tan(math.rad(Config.AimbotFOVDeg))
                  / math.tan(math.rad(Camera.FieldOfView/2))
    local best, bestD, bestPart = nil, fovPx, nil
    for _, ent in ipairs(Entity.List) do
        if ent.Targetable and ent.Health > 0 and ent.Character and ent.Player and isEnemy(ent.Player) then
            local p = ent.Character:FindFirstChild(Config.AimbotPart)
                or ent.Character:FindFirstChild("Head")
            if p then
                local sp, on = Camera:WorldToViewportPoint(p.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD and (not Config.AimbotVisCheck or isVisible(p.Position)) then
                        best, bestD, bestPart = ent, d, p
                    end
                end
            end
        end
    end
    return best, bestPart
end

local function aimbotStep(dt)
    if not Config.Aimbot or not aimbotKeyDown() then
        AimbotState.Target = nil
        return
    end
    local tgt, part = findAimbotTarget()
    if not tgt or not part then
        AimbotState.Target = nil
        return
    end
    AimbotState.Target, AimbotState.Part = tgt, part
    local aimPos = part.Position
    if Config.AimbotPredict and tgt.RootPart then
        local predicted = Prediction.Solve(
            Camera.CFrame.Position, 3000, workspace.Gravity,
            part.Position, tgt.RootPart.AssemblyLinearVelocity)
        if predicted then aimPos = predicted end
    end
    local goal = CFrame.new(Camera.CFrame.Position, aimPos)
    local a = Config.AimbotSmooth == 0 and 1
        or math.clamp(dt * (100 - Config.AimbotSmooth)/25, 0, 1)
    Camera.CFrame = Camera.CFrame:Lerp(goal, a)
end

pcall(function() RunService:UnbindFromRenderStep("VortexAimbot") end)
RunService:BindToRenderStep("VortexAimbot",
    Enum.RenderPriority.Camera.Value + 1,
    function(dt) pcall(aimbotStep, dt) end)

-- ═══════════════════════════════════════════════════════════════
-- [18] TRIGGER BOT
-- ═══════════════════════════════════════════════════════════════
local trigParams = RaycastParams.new()
trigParams.FilterType = Enum.RaycastFilterType.Exclude
local _lastTrig = 0

local function triggerKeyDown()
    local k = Config.TriggerKey
    if k == "Always" then return true end
    if k == "None" then return false end
    if k == "MB1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    if k == "MB2" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    local kc = Enum.KeyCode[k]
    return kc and UserInputService:IsKeyDown(kc) or false
end

local function applyTrigger()
    if not Config.TriggerBot or not triggerKeyDown() then return end
    if not Rivals.Ready or not Rivals.Fighter then return end
    local lf = Rivals.Fighter.LocalFighter
    if not lf then return end
    trigParams.FilterDescendantsInstances = { lp.Character }
    local hit = workspace:Raycast(
        Camera.CFrame.Position,
        Camera.CFrame.LookVector * Config.TriggerMaxDist,
        trigParams)
    if not hit or not hit.Instance then return end
    local m = hit.Instance:FindFirstAncestorOfClass("Model")
    if not m then return end
    local plr = Players:GetPlayerFromCharacter(m)
    if not plr or not isEnemy(plr) then return end
    local hum = m:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if tick() - _lastTrig < Config.TriggerDelay then return end
    _lastTrig = tick()
    task.spawn(function()
        pcall(function() lf:Input("StartShooting") end)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- [19] ESP
-- ═══════════════════════════════════════════════════════════════
local ESPData = {}
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "VortexESP"
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.DisplayOrder = 99990
pcall(function() ESPGui.Parent = gethui and gethui() or CoreGui end)
if not ESPGui.Parent then pcall(function() ESPGui.Parent = lp:WaitForChild("PlayerGui") end) end

local function mkFrame(parent, props)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    for k, v in pairs(props or {}) do f[k] = v end
    f.Parent = parent
    return f
end
local function mkText(parent, props)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = UI.Font
    t.TextSize = isIOS and 13 or 12
    t.TextStrokeTransparency = 0
    t.TextStrokeColor3 = Color3.new(0, 0, 0)
    t.TextColor3 = Color3.new(1, 1, 1)
    t.TextXAlignment = Enum.TextXAlignment.Center
    for k, v in pairs(props or {}) do t[k] = v end
    t.Parent = parent
    return t
end

local function buildESP(ent)
    if ESPData[ent] then return end
    if not ent.Character or not ent.Character.Parent or ent.Health <= 0 then return end

    local root = mkFrame(ESPGui, { BackgroundTransparency = 1, Visible = false, ZIndex = 2 })
    local box = mkFrame(root, { BackgroundTransparency = 1, ZIndex = 3 })
    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.ESPColor
    stroke.Thickness = isIOS and 1.5 or 1
    stroke.Parent = box
    local hpBg = mkFrame(root, { BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.4, ZIndex = 3, Visible = false })
    local hpFill = mkFrame(hpBg, { BackgroundColor3 = Color3.fromRGB(0, 255, 0), ZIndex = 4 })
    local name = mkText(root, { TextSize = isIOS and 13 or 12, Visible = false, ZIndex = 5,
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, -16) })
    local dist = mkText(root, { TextSize = isIOS and 12 or 11, TextColor3 = Color3.fromRGB(200,200,200),
        Visible = false, ZIndex = 5, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, 2) })
    local tracer
    if Drawing and Drawing.new then
        tracer = Drawing.new("Line")
        tracer.Thickness = 1
        tracer.Color = Config.ESPColor
        tracer.Visible = false
    end
    ESPData[ent] = { root = root, box = box, stroke = stroke,
        hpBg = hpBg, hpFill = hpFill, name = name, dist = dist, tracer = tracer }
end

local function destroyESP(ent)
    local d = ESPData[ent]
    if not d then return end
    for _, v in pairs(d) do
        if typeof(v) == "Instance" then pcall(function() v:Destroy() end)
        elseif type(v) == "userdata" and v.Remove then pcall(function() v:Remove() end) end
    end
    ESPData[ent] = nil
end

local function hideESP(ent)
    local d = ESPData[ent]
    if not d then return end
    d.root.Visible = false
    if d.tracer then d.tracer.Visible = false end
end

local function updateESP(ent)
    local d = ESPData[ent]
    if not d then return end
    if not Config.ESP or not ent.Character or not ent.RootPart or ent.RootPart.Parent == nil then
        hideESP(ent); return
    end
    if ent.Health <= 0 then hideESP(ent); return end
    if Config.ESPTeamCheck and ent.Player and not isEnemy(ent.Player) then hideESP(ent); return end
    local root = ent.RootPart
    local myChar = lp.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or Camera.CFrame.Position
    local dist = (myPos - root.Position).Magnitude
    if dist > Config.ESPMaxDist then hideESP(ent); return end
    local topPos, topOn = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.5, 0))
    local botPos, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
    if not topOn and not botOn then hideESP(ent); return end
    if topPos.Z <= 0 or botPos.Z <= 0 then hideESP(ent); return end
    local h = math.abs(botPos.Y - topPos.Y)
    if h < 4 or h > 1000 then hideESP(ent); return end
    local w = h * 0.55
    d.root.Position = UDim2.fromOffset(topPos.X - w/2, topPos.Y)
    d.root.Size = UDim2.fromOffset(w, h)
    d.root.Visible = true
    d.box.Visible = Config.ESPBox
    d.box.Size = UDim2.new(1, 0, 1, 0)
    d.stroke.Color = Config.ESPColor
    if Config.ESPHealth then
        local frac = math.clamp(ent.Health / math.max(ent.MaxHealth, 1), 0, 1)
        d.hpBg.Visible = true
        d.hpBg.Position = UDim2.new(0, -6, 0, 0)
        d.hpBg.Size = UDim2.new(0, 3, 1, 0)
        d.hpFill.Position = UDim2.new(0, 0, 1 - frac, 0)
        d.hpFill.Size = UDim2.new(1, 0, frac, 0)
        d.hpFill.BackgroundColor3 = Color3.fromRGB(
            math.floor(255 * (1 - frac)), math.floor(255 * frac), 0)
    else d.hpBg.Visible = false end
    if Config.ESPName and ent.Player then
        d.name.Visible = true
        d.name.Text = ent.Player.Name
    else d.name.Visible = false end
    if Config.ESPDistance then
        d.dist.Visible = true
        d.dist.Text = string.format("%dm", math.floor(dist))
    else d.dist.Visible = false end
    if d.tracer then
        if Config.ESPTracers then
            local vp = Camera.ViewportSize
            d.tracer.From = Vector2.new(vp.X/2, vp.Y)
            d.tracer.To = Vector2.new(topPos.X, topPos.Y)
            d.tracer.Color = Config.ESPColor
            d.tracer.Visible = true
        else d.tracer.Visible = false end
    end
end

table.insert(_entityEventConns, Entity.Events.Added:Connect(buildESP))
table.insert(_entityEventConns, Entity.Events.Removed:Connect(destroyESP))
for _, ent in ipairs(Entity.List) do buildESP(ent) end

-- ═══════════════════════════════════════════════════════════════
-- [20] CROSSHAIR
-- ═══════════════════════════════════════════════════════════════
local chLines = {}
if Drawing and Drawing.new then
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 1
        l.Visible = false
        chLines[i] = l
    end
end
local chDot = Drawing and Drawing.new and Drawing.new("Circle") or nil
if chDot then chDot.Filled = true; chDot.NumSides = 24; chDot.Visible = false end

local function updateCrosshair()
    if not chLines[1] then return end
    if not Config.Crosshair then
        for i = 1, 4 do chLines[i].Visible = false end
        if chDot then chDot.Visible = false end
        return
    end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X/2, vp.Y/2
    local gap, len, th = Config.CrosshairGap, Config.CrosshairLength, Config.CrosshairThickness
    local col = Config.CrosshairColor
    if Config.CrosshairStyle == "dot" then
        for i = 1, 4 do chLines[i].Visible = false end
        if chDot then
            chDot.Visible = true
            chDot.Position = Vector2.new(cx, cy)
            chDot.Radius = math.max(th * 2, 2)
            chDot.Color = col
        end
        return
    end
    local arms
    if Config.CrosshairStyle == "x" then
        local d = 0.70710678
        arms = {
            { cx - d*gap, cy - d*gap, cx - d*(gap+len), cy - d*(gap+len) },
            { cx + d*gap, cy + d*gap, cx + d*(gap+len), cy + d*(gap+len) },
            { cx - d*gap, cy + d*gap, cx - d*(gap+len), cy + d*(gap+len) },
            { cx + d*gap, cy - d*gap, cx + d*(gap+len), cy - d*(gap+len) },
        }
    elseif Config.CrosshairStyle == "t" then
        arms = {
            { cx, cy + gap, cx, cy + gap + len },
            { cx - gap, cy, cx - gap - len, cy },
            { cx + gap, cy, cx + gap + len, cy },
            nil,
        }
    else
        arms = {
            { cx, cy - gap, cx, cy - gap - len },
            { cx, cy + gap, cx, cy + gap + len },
            { cx - gap, cy, cx - gap - len, cy },
            { cx + gap, cy, cx + gap + len, cy },
        }
    end
    for i = 1, 4 do
        local a = arms[i]
        local l = chLines[i]
        if a then
            l.From = Vector2.new(a[1], a[2])
            l.To = Vector2.new(a[3], a[4])
            l.Color = col
            l.Thickness = th
            l.Visible = true
        else l.Visible = false end
    end
    if chDot then
        if Config.CrosshairDot then
            chDot.Visible = true
            chDot.Position = Vector2.new(cx, cy)
            chDot.Radius = math.max(th, 2)
            chDot.Color = col
        else chDot.Visible = false end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- [21] FLY + SPEED
-- ═══════════════════════════════════════════════════════════════
local _baseWS = 16
local _lastSpeedValue = nil

local function applyFly()
    if not Config.Fly or not Entity.isAlive or not Entity.character then return end
    local root = Entity.character.HumanoidRootPart
    local hum = Entity.character.Humanoid
    if not root or not root.Parent or not hum then return end

    local move = Vector3.zero
    if isMobile then
        local md = hum.MoveDirection
        if md.Magnitude > 0.1 then move = move + md end
        if getgenv().__VortexFlyUp and getgenv().__VortexFlyUp() then
            move = move + Vector3.new(0, 1, 0)
        elseif getgenv().__VortexLastJumpT and tick() - getgenv().__VortexLastJumpT < 0.15 then
            move = move + Vector3.new(0, 1, 0)
        end
        if getgenv().__VortexFlyDown and getgenv().__VortexFlyDown() then
            move = move - Vector3.new(0, 1, 0)
        end
    else
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
    end

    if move.Magnitude > 0 then
        root.AssemblyLinearVelocity = move.Unit * Config.FlySpeed
    else
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

local function applySpeed()
    if not Entity.isAlive or not Entity.character then return end
    local hum = Entity.character.Humanoid
    if not hum then return end
    if Config.Speed then
        hum.WalkSpeed = Config.SpeedValue
        _lastSpeedValue = Config.SpeedValue
    else
        if _lastSpeedValue and math.abs(hum.WalkSpeed - _lastSpeedValue) < 0.01 then
            hum.WalkSpeed = _baseWS
        end
        _lastSpeedValue = nil
    end
end

table.insert(_entityEventConns, Entity.Events.LocalAdded:Connect(function(ent)
    if ent.Humanoid then _baseWS = ent.Humanoid.WalkSpeed end
    _lastSpeedValue = nil
end))
if Entity.character and Entity.character.Humanoid then
    _baseWS = Entity.character.Humanoid.WalkSpeed
end

-- ═══════════════════════════════════════════════════════════════
-- [22] WEATHER
-- ═══════════════════════════════════════════════════════════════
local Weather = { part = nil, emitter = nil, lastType = "" }
do
    local part = Instance.new("Part")
    part.Name = "VortexWeather"
    part.Size = Vector3.new(40, 40, 85)
    part.CanCollide = false
    part.Massless = true
    part.CastShadow = false
    part.Transparency = 1
    part.Anchored = true
    part.Parent = workspace
    Weather.part = part
    Weather.presets = {
        snow = {
            Texture = "rbxassetid://99851851",
            SpreadAngle = Vector2.new(50, 50),
            Speed = NumberRange.new(30, 30),
            LightEmission = 10, Rate = 1000,
            EmissionDirection = Enum.NormalId.Bottom,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.33),
                NumberSequenceKeypoint.new(1, 0.33) }),
            Transparency = NumberSequence.new(0.3),
        },
        rain = {
            Speed = NumberRange.new(60, 60),
            LockedToPart = true, Rate = 600,
            Texture = "rbxassetid://1822883048",
            EmissionDirection = Enum.NormalId.Bottom,
            Lifetime = NumberRange.new(0.8, 0.8),
            LightEmission = 0.05,
            Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
            Size = NumberSequence.new(10),
            Transparency = NumberSequence.new(0.5),
        },
    }
end

local function rebuildWeather()
    if Weather.emitter then Weather.emitter:Destroy() end
    local preset = Weather.presets[Config.WeatherType] or Weather.presets.snow
    local e = Instance.new("ParticleEmitter")
    for k, v in pairs(preset) do e[k] = v end
    e.Color = ColorSequence.new(Config.WeatherColor)
    e.Enabled = false
    e.Parent = Weather.part
    Weather.emitter = e
    Weather.lastType = Config.WeatherType
end
rebuildWeather()

-- ═══════════════════════════════════════════════════════════════
-- [23] CHAMS
-- ═══════════════════════════════════════════════════════════════
local ChamsData = {}

local function clearChamsFor(ent)
    local hl = ChamsData[ent]
    if hl then
        pcall(function() hl:Destroy() end)
        ChamsData[ent] = nil
    end
end

local function applyChams(ent)
    if not ent.Character or not ent.Player then return end
    if Config.ESPTeamCheck and not isEnemy(ent.Player) then
        clearChamsFor(ent)
        return
    end
    local hl = ChamsData[ent]
    if not hl or hl.Parent ~= ent.Character then
        if hl then pcall(function() hl:Destroy() end) end
        hl = Instance.new("Highlight")
        hl.Name = "VortexChams"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = ent.Character
        hl.Parent = ent.Character
        ChamsData[ent] = hl
    end
    hl.FillColor = Config.ChamsFill
    hl.FillTransparency = Config.ChamsFillTrans
    hl.OutlineColor = Config.ChamsOutline
    hl.OutlineTransparency = Config.ChamsOutlineTrans
end

local function clearChams()
    for ent, hl in pairs(ChamsData) do pcall(function() hl:Destroy() end) end
    ChamsData = {}
end

table.insert(_entityEventConns, Entity.Events.Removed:Connect(clearChamsFor))

-- ═══════════════════════════════════════════════════════════════
-- [24] MAIN LOOP
-- ═══════════════════════════════════════════════════════════════
local _fpsAccum, _fps = 0, 60

table.insert(_conns, RunService.RenderStepped:Connect(function(dt)
    _fpsAccum = _fpsAccum + dt
    if _fpsAccum >= 0.5 then
        _fps = math.floor(1/math.max(dt, 0.0001) + 0.5)
        _fpsAccum = 0
    end

    pcall(applyFly)
    pcall(applySpeed)
    pcall(applyTrigger)
    pcall(updateCrosshair)
    pcall(updateFOVCircles)
    pcall(updateHitFX)
    pcall(updateTargetHUD)

    for ent in pairs(ESPData) do pcall(updateESP, ent) end
    for _, ent in ipairs(Entity.List) do
        if not ESPData[ent] and ent.Character and ent.Character.Parent and ent.Health > 0 then
            buildESP(ent)
        end
    end

    if Config.Chams then
        for _, ent in ipairs(Entity.List) do pcall(applyChams, ent) end
    elseif next(ChamsData) then
        clearChams()
    end

    if Config.Weather then
        if Weather.lastType ~= Config.WeatherType then rebuildWeather() end
        if Weather.emitter then
            Weather.emitter.Enabled = true
            Weather.emitter.Rate = Config.WeatherRate
            Weather.emitter.Color = ColorSequence.new(Config.WeatherColor)
        end
        Weather.part.CFrame = CFrame.new(Camera.CFrame.Position + Vector3.new(0, 20, 0))
    elseif Weather.emitter and Weather.emitter.Enabled then
        Weather.emitter.Enabled = false
    end

    if Config.Watermark then
        wm.Visible = true
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
        end)
        if isMobile then
            wmLabel.Text = string.format("Vortex · %d fps · %dms", _fps, ping)
        else
            wmLabel.Text = string.format("Vortex v1.6.4 · %d fps · %dms · %s",
                _fps, ping, lp.DisplayName)
        end
    else wm.Visible = false end
end))

-- ═══════════════════════════════════════════════════════════════
-- [25] EXPORT
-- ═══════════════════════════════════════════════════════════════
local Vortex = {
    Config = Config, Entity = Entity, Prediction = Prediction,
    Notify = Notify, SilentAim = SilentState, Aimbot = AimbotState,
    Bypass = Bypass, Version = "1.6.4",
    isIOS = isIOS, isMobile = isMobile, execName = execName,
}

function Vortex:Unload()
    _unloaded = true  -- [FIX #27, #28] dừng mọi retry loop

    for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    _conns = {}

    for _, c in ipairs(_entityEventConns) do pcall(function() c:Disconnect() end) end
    _entityEventConns = {}

    for _, c in ipairs(_playerEventConns) do pcall(function() c:Disconnect() end) end
    _playerEventConns = {}

    pcall(function() _camConn:Disconnect() end)
    pcall(function() RunService:UnbindFromRenderStep("VortexAimbot") end)

    for ent in pairs(ESPData) do destroyESP(ent) end
    clearChams()

    if chLines[1] then
        for _, l in ipairs(chLines) do pcall(function() l:Remove() end) end
    end
    if chDot then pcall(function() chDot:Remove() end) end
    if _fovSilent then pcall(function() _fovSilent:Remove() end) end
    if _fovAimbot then pcall(function() _fovAimbot:Remove() end) end
    if HitFX.lines[1] then
        for _, l in ipairs(HitFX.lines) do pcall(function() l:Remove() end) end
    end

    if _origRaycast and Rivals.Util then
        pcall(function() Rivals.Util.Raycast = _origRaycast end)
    end

    if _hookedFighter and _origReplicateFromServer then
        pcall(function()
            _hookedFighter.ReplicateFromServer = _origReplicateFromServer
        end)
    end

    if Weather.part then pcall(function() Weather.part:Destroy() end) end
    if HitFX.sound then pcall(function() HitFX.sound:Destroy() end) end
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() ESPGui:Destroy() end)

    TARGET_HUD.target = nil
    TARGET_HUD.a = 0
    notifyQueue = {}
    _lastSpeedValue = nil
    if Entity.character and Entity.character.Humanoid then
        _baseWS = Entity.character.Humanoid.WalkSpeed
    end

    pcall(function() getgenv().__VortexHitHookInstalled = nil end)
    pcall(function() getgenv().__VortexBypassInstalled = nil end)
    pcall(function() getgenv().__VortexL1 = nil end)
    pcall(function() _G.__VortexActiveSlider = nil end)
    pcall(function() getgenv().__VortexFlyUp = nil end)
    pcall(function() getgenv().__VortexFlyDown = nil end)
    pcall(function() getgenv().__VortexLastJumpT = nil end)

    _G.VORTEX_LOADED = nil
    _G.VORTEX_HUB = nil
    if getgenv then getgenv().Vortex = nil end
end

_G.VORTEX_HUB = Vortex
_G.VORTEX_LOADED = true
if getgenv then getgenv().Vortex = Vortex end

Notify("Vortex Hub v1.6.4 loaded", 4)
print("[Vortex Hub] v1.6.4 loaded")
print("  Executor:", execName)
print("  iOS mode:", isIOS and "YES" or "NO")
print("  Bypass:", Bypass.ok and "INSTALLED" or ("FAILED: " .. tostring(Bypass.error)))
print("  Rivals:", Rivals.Ready and "READY" or "PARTIAL")
print("  Open menu: tap 'V' button (mobile) or RightShift (PC)")
