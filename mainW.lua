--[[ Wrench Universal — single-file Luau, executor-agnostic.
     RightShift or the floating "W" button toggles the menu. ]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local VirtualUser      = game:GetService("VirtualUser")
local CoreGui          = game:GetService("CoreGui")

local LP = Players.LocalPlayer

-- single-instance guard ------------------------------------------------
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.__WrenchUnload then pcall(env.__WrenchUnload) end

-- state ----------------------------------------------------------------
local S = {
    speed = false,  speedValue = 50,
    infJump = false,
    noclip = false,
    fly = false,    flySpeed = 60,
    esp = false,    espNames = true, espTeam = false,
    fullbright = false,
    fovOn = false,  fov = 90,
    antiAfk = true,
}

local conns = {}
local function track(c) conns[#conns + 1] = c; return c end

local function getChar() return LP.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = getChar()
    return c and (c:FindFirstChild("HumanoidRootPart"))
end

-- theme ----------------------------------------------------------------
local T = {
    bg      = Color3.fromRGB(22, 20, 32),
    panel   = Color3.fromRGB(30, 27, 44),
    row     = Color3.fromRGB(40, 36, 58),
    accent  = Color3.fromRGB(255, 125, 195),
    accent2 = Color3.fromRGB(150, 120, 255),
    text    = Color3.fromRGB(240, 235, 250),
    dim     = Color3.fromRGB(165, 155, 190),
    off     = Color3.fromRGB(70, 64, 95),
}

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r) make("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function tween(o, t, goal)
    local tw = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    tw:Play(); return tw
end

-- gui root -------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "WrenchUniversal"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
do
    local ok = false
    if typeof(gethui) == "function" then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then ok = pcall(function() gui.Parent = CoreGui end) end
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end
local espFolder = make("Folder", {Name = "E"}, gui)

-- main window ----------------------------------------------------------
local main = make("Frame", {
    Size = UDim2.fromOffset(480, 340), Position = UDim2.new(0.5, -240, 0.5, -170),
    BackgroundColor3 = T.bg, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(main, 12)
local scale = make("UIScale", {Scale = 0}, main)
make("UIStroke", {Color = T.accent, Thickness = 1.5, Transparency = 0.4}, main)

local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local baseScale = math.clamp(vp.X / 700, 0.6, 1)

local title = make("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.panel, BorderSizePixel = 0}, main)
local grad = make("UIGradient", {
    Color = ColorSequence.new(T.accent, T.accent2), Rotation = 0,
}, make("Frame", {Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1)}, title))
make("TextLabel", {
    Text = "wrench ~ universal", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = T.text,
    BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(14, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, title)

local function titleBtn(txt, xoff, color)
    local b = make("TextButton", {
        Text = txt, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.text,
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xoff, 0.5, -13),
        BackgroundColor3 = color, AutoButtonColor = false, BorderSizePixel = 0,
    }, title)
    corner(b, 8)
    return b
end
local btnHide  = titleBtn("-", -66, T.row)
local btnClose = titleBtn("x", -34, Color3.fromRGB(200, 70, 110))

-- dragging -------------------------------------------------------------
do
    local dragging, startPos, startInput
    track(title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, main.Position, i.Position
        end
    end))
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

-- sidebar + pages ------------------------------------------------------
local sidebar = make("Frame", {
    Size = UDim2.new(0, 112, 1, -38), Position = UDim2.fromOffset(0, 38),
    BackgroundColor3 = T.panel, BorderSizePixel = 0,
}, main)
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
make("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, sidebar)

local content = make("Frame", {
    Size = UDim2.new(1, -112, 1, -38), Position = UDim2.fromOffset(112, 38), BackgroundTransparency = 1,
}, main)

local pages, tabButtons = {}, {}
local function selectTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabButtons) do
        tween(b, 0.18, {BackgroundColor3 = (n == name) and T.accent or T.row,
                        TextColor3 = (n == name) and Color3.new(1, 1, 1) or T.dim})
    end
end

local function addTab(name, order)
    local page = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false,
    }, content)
    make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    make("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 10)}, page)
    pages[name] = page

    local b = make("TextButton", {
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.dim,
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.row, AutoButtonColor = false,
        BorderSizePixel = 0, LayoutOrder = order,
    }, sidebar)
    corner(b, 8)
    tabButtons[name] = b
    track(b.MouseButton1Click:Connect(function() selectTab(name) end))
    return page
end

-- components -----------------------------------------------------------
local function addToggle(page, label, default, cb)
    local row = make("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.row, BorderSizePixel = 0}, page)
    corner(row, 8)
    make("TextLabel", {
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.text,
        BackgroundTransparency = 1, Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(12, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = make("Frame", {Size = UDim2.fromOffset(42, 20), Position = UDim2.new(1, -54, 0.5, -10), BackgroundColor3 = T.off, BorderSizePixel = 0}, row)
    corner(pill, 10)
    local knob = make("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, pill)
    corner(knob, 8)
    local state = false
    local function set(v, silent)
        state = v
        tween(pill, 0.18, {BackgroundColor3 = v and T.accent or T.off})
        tween(knob, 0.18, {Position = v and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2)})
        if not silent then task.spawn(cb, v) end
    end
    local hit = make("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0)}, row)
    track(hit.MouseButton1Click:Connect(function() set(not state) end))
    set(default, true)
    if default then task.spawn(cb, true) end
    return set
end

local function addSlider(page, label, min, max, default, step, cb)
    local row = make("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.row, BorderSizePixel = 0}, page)
    corner(row, 8)
    local lab = make("TextLabel", {
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.text,
        BackgroundTransparency = 1, Size = UDim2.new(1, -70, 0, 22), Position = UDim2.fromOffset(12, 4),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local val = make("TextLabel", {
        Text = tostring(default), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.accent,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 22), Position = UDim2.new(1, -68, 0, 4),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local bar = make("Frame", {Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 34), BackgroundColor3 = T.off, BorderSizePixel = 0}, row)
    corner(bar, 3)
    local fill = make("Frame", {Size = UDim2.new((default - min) / (max - min), 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0}, bar)
    corner(fill, 3)
    make("UIGradient", {Color = ColorSequence.new(T.accent, T.accent2)}, fill)

    local dragging = false
    local function update(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = min + (max - min) * a
        v = math.floor(v / step + 0.5) * step
        v = math.clamp(v, min, max)
        val.Text = tostring(v)
        tween(fill, 0.06, {Size = UDim2.new((v - min) / (max - min), 0, 1, 0)})
        cb(v)
    end
    track(bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    cb(default)
end

local function addButton(page, label, cb)
    local b = make("TextButton", {
        Text = label, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.accent2, AutoButtonColor = false, BorderSizePixel = 0,
    }, page)
    corner(b, 8)
    make("UIGradient", {Color = ColorSequence.new(T.accent, T.accent2)}, b)
    track(b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundTransparency = 0.12}) end))
    track(b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundTransparency = 0}) end))
    track(b.MouseButton1Click:Connect(function()
        tween(b, 0.07, {Size = UDim2.new(1, -8, 0, 32)}).Completed:Connect(function()
            tween(b, 0.1, {Size = UDim2.new(1, 0, 0, 36)})
        end)
        task.spawn(cb)
    end))
end

-- features -------------------------------------------------------------
-- Speed
local origWalk
track(RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if S.speed then
        if origWalk == nil then origWalk = hum.WalkSpeed end
        hum.WalkSpeed = S.speedValue
    elseif origWalk ~= nil then
        hum.WalkSpeed = origWalk
        origWalk = nil
    end
end))
track(LP.CharacterAdded:Connect(function() origWalk = nil end))

-- Infinite jump
track(UserInputService.JumpRequest:Connect(function()
    if not S.infJump then return end
    local hum = getHum()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

-- Noclip (remembers exactly which parts it changed)
local noclipped = {}
track(RunService.Stepped:Connect(function()
    local c = getChar()
    if S.noclip and c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
                noclipped[p] = true
            end
        end
    elseif next(noclipped) then
        for p in pairs(noclipped) do
            if p.Parent then p.CanCollide = true end
            noclipped[p] = nil
        end
    end
end))

-- Fly (horizontal from MoveDirection so keyboard and touch both work)
local flyBV
local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
end
track(RunService.Heartbeat:Connect(function()
    local root, hum = getRoot(), getHum()
    if not (S.fly and root and hum) then stopFly(); return end
    if not flyBV or flyBV.Parent ~= root then
        stopFly()
        flyBV = make("BodyVelocity", {MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero}, root)
    end
    local up = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then up += 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then up -= 1 end
    flyBV.Velocity = hum.MoveDirection * S.flySpeed + Vector3.new(0, up * S.flySpeed, 0)
end))

-- ESP
local esp = {}
local function removeEsp(plr)
    local e = esp[plr]
    if e then
        for _, o in pairs(e) do if typeof(o) == "Instance" then o:Destroy() end end
        esp[plr] = nil
    end
end
local function createEsp(plr)
    removeEsp(plr)
    if plr == LP or not S.esp then return end
    local ch = plr.Character
    local head = ch and ch:FindFirstChild("Head")
    if not (ch and head) then return end
    local hl = make("Highlight", {
        Adornee = ch, FillColor = T.accent, OutlineColor = Color3.new(1, 1, 1),
        FillTransparency = 0.6, OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    }, espFolder)
    local bb = make("BillboardGui", {
        Adornee = head, Size = UDim2.fromOffset(160, 34), StudsOffset = Vector3.new(0, 2.5, 0),
        AlwaysOnTop = true,
    }, espFolder)
    local lab = make("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBold,
        TextSize = 13, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = plr.Name,
    }, bb)
    esp[plr] = {hl = hl, bb = bb, lab = lab}
end
local function rebuildEsp()
    for _, p in ipairs(Players:GetPlayers()) do createEsp(p) end
end
local function hookPlayer(p)
    track(p.CharacterAdded:Connect(function() task.wait(0.3); createEsp(p) end))
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then hookPlayer(p) end end
track(Players.PlayerAdded:Connect(function(p) hookPlayer(p); createEsp(p) end))
track(Players.PlayerRemoving:Connect(removeEsp))

local espAcc = 0
track(RunService.Heartbeat:Connect(function(dt)
    espAcc += dt
    if espAcc < 0.1 then return end
    espAcc = 0
    local myRoot = getRoot()
    for plr, e in pairs(esp) do
        local ch = plr.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not (ch and root and e.hl.Parent) then
            removeEsp(plr)
        else
            local hide = S.espTeam and plr.Team ~= nil and plr.Team == LP.Team
            e.hl.Enabled = not hide
            e.bb.Enabled = (not hide) and S.espNames
            if plr.Team and plr.TeamColor then e.hl.FillColor = plr.TeamColor.Color end
            local d = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
            e.lab.Text = plr.Name .. " [" .. d .. "m]"
        end
    end
end))

-- Fullbright (saves and restores the exact originals)
local lightSaved
local function setFullbright(on)
    if on then
        lightSaved = lightSaved or {
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    elseif lightSaved then
        for k, v in pairs(lightSaved) do Lighting[k] = v end
        lightSaved = nil
    end
end
track(RunService.RenderStepped:Connect(function()
    if S.fullbright and lightSaved then
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
    end
end))

-- FOV
local origFov
track(RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    if S.fovOn then
        origFov = origFov or cam.FieldOfView
        cam.FieldOfView = S.fov
    elseif origFov then
        cam.FieldOfView = origFov; origFov = nil
    end
end))

-- Anti-AFK
track(LP.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

-- menu content ---------------------------------------------------------
local pMove  = addTab("Movement", 1)
local pVis   = addTab("Visuals", 2)
local pMisc  = addTab("Misc", 3)

addToggle(pMove, "Speed hack", false, function(v) S.speed = v end)
addSlider(pMove, "Walk speed", 16, 200, 50, 1, function(v) S.speedValue = v end)
addToggle(pMove, "Infinite jump", false, function(v) S.infJump = v end)
addToggle(pMove, "Fly (Space up / Ctrl down)", false, function(v) S.fly = v end)
addSlider(pMove, "Fly speed", 10, 200, 60, 1, function(v) S.flySpeed = v end)
addToggle(pMove, "Noclip", false, function(v) S.noclip = v end)

addToggle(pVis, "Player ESP", false, function(v) S.esp = v; rebuildEsp() end)
addToggle(pVis, "ESP names + distance", true, function(v) S.espNames = v end)
addToggle(pVis, "Hide teammates", false, function(v) S.espTeam = v end)
addToggle(pVis, "Fullbright", false, function(v) S.fullbright = v; setFullbright(v) end)
addToggle(pVis, "Custom FOV", false, function(v) S.fovOn = v end)
addSlider(pVis, "FOV", 40, 120, 90, 1, function(v) S.fov = v end)

addToggle(pMisc, "Anti-AFK", true, function(v) S.antiAfk = v end)
addButton(pMisc, "Reset character", function()
    local h = getHum(); if h then h.Health = 0 end
end)
addButton(pMisc, "Unload script", function() if env.__WrenchUnload then env.__WrenchUnload() end end)

selectTab("Movement")

-- open / close ---------------------------------------------------------
local open = false
local function setOpen(v)
    open = v
    main.Visible = true
    local tw = tween(scale, 0.25, {Scale = v and baseScale or 0})
    if not v then tw.Completed:Connect(function() if not open then main.Visible = false end end) end
end

local fab = make("TextButton", {
    Text = "W", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
    Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 12, 0.5, -22),
    BackgroundColor3 = T.accent, AutoButtonColor = false, BorderSizePixel = 0,
}, gui)
corner(fab, 22)
make("UIGradient", {Color = ColorSequence.new(T.accent, T.accent2), Rotation = 45}, fab)
track(fab.MouseButton1Click:Connect(function() setOpen(not open) end))
track(btnHide.MouseButton1Click:Connect(function() setOpen(false) end))
track(UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.RightShift then setOpen(not open) end
end))

-- gradient shimmer on the title accent line
track(RunService.RenderStepped:Connect(function()
    grad.Rotation = (os.clock() * 60) % 360
end))

-- unload ---------------------------------------------------------------
local function unload()
    S.speed, S.noclip, S.fly, S.esp, S.fovOn, S.fullbright, S.infJump = false, false, false, false, false, false, false
    local hum = getHum()
    if hum and origWalk then hum.WalkSpeed = origWalk end
    for p in pairs(noclipped) do if p.Parent then p.CanCollide = true end end
    stopFly()
    setFullbright(false)
    local cam = workspace.CurrentCamera
    if cam and origFov then cam.FieldOfView = origFov end
    for plr in pairs(esp) do removeEsp(plr) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    env.__WrenchUnload = nil
end
env.__WrenchUnload = unload

setOpen(true)
