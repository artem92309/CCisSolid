--[[ Mayle Hub — single-file universal Luau, executor-agnostic.
     RightShift or the floating button toggles the menu. ]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UIS              = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local VirtualUser      = game:GetService("VirtualUser")
local CoreGui          = game:GetService("CoreGui")
local Stats            = game:GetService("Stats")
local TeleportService  = game:GetService("TeleportService")

local LP = Players.LocalPlayer
local TOUCH = UIS.TouchEnabled

local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.__MayleUnload then pcall(env.__MayleUnload) end

-- state ------------------------------------------------------------------
local S = {
    speed = false, speedValue = 50,
    jump = false, jumpValue = 80,
    gravity = false, gravityValue = 60,
    infJump = false, noclip = false, spin = false, spinSpeed = 8,
    fly = false, flySpeed = 60, flySteer = true, flyPad = TOUCH,
    clickTp = false,
    esp = false, espNames = true, espHealth = true, espTeam = false,
    fullbright = false, noFog = false,
    clockOn = false, clock = 14,
    fovOn = false, fov = 90,
    zoom = false, crosshair = false, hud = false,
    antiAfk = true,
    target = nil, spectate = false,
}

local conns = {}
local function track(c) conns[#conns + 1] = c; return c end
local function cam() return workspace.CurrentCamera end
local function getChar() return LP.Character end
local function getHum() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

-- theme ------------------------------------------------------------------
local T = {
    bg = Color3.fromRGB(18, 18, 20), panel = Color3.fromRGB(24, 24, 27),
    row = Color3.fromRGB(33, 33, 37), line = Color3.fromRGB(52, 52, 58),
    text = Color3.fromRGB(232, 232, 236), dim = Color3.fromRGB(150, 150, 158),
    off = Color3.fromRGB(58, 58, 64), accent = Color3.fromRGB(70, 200, 150),
}
local PRESETS = {
    {"Green",  Color3.fromRGB(70, 200, 150)},
    {"Blue",   Color3.fromRGB(80, 150, 255)},
    {"Red",    Color3.fromRGB(235, 80, 90)},
    {"Amber",  Color3.fromRGB(240, 175, 55)},
    {"Violet", Color3.fromRGB(160, 120, 255)},
}
local themeHooks = {}
local function onTheme(fn) themeHooks[#themeHooks + 1] = fn; fn() end
local function applyTheme(c)
    T.accent = c
    for _, fn in ipairs(themeHooks) do pcall(fn) end
end
-- text color that stays readable on top of the given background
local function contrast(c)
    return (c.R * 0.299 + c.G * 0.587 + c.B * 0.114) > 0.6 and Color3.fromRGB(20, 20, 22) or Color3.new(1, 1, 1)
end

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r) return make("UICorner", {CornerRadius = UDim.new(0, r or 6)}, o) end
local function tween(o, t, goal, style)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    tw:Play(); return tw
end
local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function copy(text, okMsg, toastFn)
    if typeof(setclipboard) == "function" then setclipboard(text); toastFn(okMsg)
    else toastFn("Clipboard not available") end
end

-- gui root ---------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MayleHub"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.DisplayOrder = 999
do
    local ok = false
    if typeof(gethui) == "function" then ok = pcall(function() gui.Parent = gethui() end) end
    if not ok then ok = pcall(function() gui.Parent = CoreGui end) end
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end
local espFolder = make("Folder", {Name = "E"}, gui)
local vp = (cam() and cam().ViewportSize) or Vector2.new(1280, 720)

-- generic draggable ------------------------------------------------------
local function draggable(handle, target, opts)
    opts = opts or {}
    local dragInput, startMouse, startPos, moved
    track(handle.InputBegan:Connect(function(i)
        if isPress(i) then
            dragInput, startMouse, startPos, moved = i, i.Position, target.Position, false
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if not dragInput then return end
        local match = (i == dragInput)
            or (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement)
        if not match then return end
        local d = i.Position - startMouse
        if not moved and d.Magnitude > 6 then moved = true end
        if moved then
            local x, y = startPos.X.Offset + d.X, startPos.Y.Offset + d.Y
            if opts.clamp then
                local v = cam() and cam().ViewportSize or vp
                x = math.clamp(x, 0, math.max(v.X - target.AbsoluteSize.X, 0))
                y = math.clamp(y, 0, math.max(v.Y - target.AbsoluteSize.Y, 0))
            end
            target.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
        end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if dragInput and i.UserInputType == dragInput.UserInputType then
            dragInput = nil
            if moved then if opts.onDrop then opts.onDrop() end
            elseif opts.onClick then opts.onClick() end
        end
    end))
end

-- toasts -----------------------------------------------------------------
local toastHolder = make("Frame", {
    Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 50,
}, gui)
make("UIListLayout", {Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center}, toastHolder)
local function toast(msg)
    local f = make("Frame", {Size = UDim2.fromOffset(220, 28), BackgroundColor3 = T.panel, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50}, toastHolder)
    corner(f, 5)
    local st = make("UIStroke", {Color = T.line, Thickness = 1, Transparency = 1}, f)
    local l = make("TextLabel", {Text = msg, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.text,
        TextTransparency = 1, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 51}, f)
    tween(f, 0.15, {BackgroundTransparency = 0.05}); tween(st, 0.15, {Transparency = 0}); tween(l, 0.15, {TextTransparency = 0})
    task.delay(1.6, function()
        if not f.Parent then return end
        tween(f, 0.25, {BackgroundTransparency = 1}); tween(st, 0.25, {Transparency = 1}); tween(l, 0.25, {TextTransparency = 1})
        task.wait(0.3)
        if f.Parent then f:Destroy() end
    end)
end

-- window -----------------------------------------------------------------
local holder = make("Frame", {Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1}, gui)
local main = make("Frame", {Size = UDim2.fromOffset(540, 370), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = T.bg, BorderSizePixel = 0, ClipsDescendants = true}, holder)
corner(main, 8)
local uiScale = make("UIScale", {Scale = 0}, main)
make("UIStroke", {Color = T.line, Thickness = 1}, main)

local userScale = 1
local function baseScale()
    local v = cam() and cam().ViewportSize or vp
    return math.clamp(math.min(v.X / 580, v.Y / 410, 1), 0.5, 1) * userScale
end

local titleBar = make("Frame", {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = T.panel, BorderSizePixel = 0}, main)
local titleLine = make("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BorderSizePixel = 0}, titleBar)
onTheme(function() titleLine.BackgroundColor3 = T.accent end)

local logo = make("Frame", {Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(12, 9), BorderSizePixel = 0}, titleBar)
corner(logo, 6)
local logoText = make("TextLabel", {Text = "M", Font = Enum.Font.GothamBlack, TextSize = 17, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, logo)
onTheme(function() logo.BackgroundColor3 = T.accent; logoText.TextColor3 = contrast(T.accent) end)

make("TextLabel", {Text = "Mayle Hub", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = T.text, BackgroundTransparency = 1,
    Size = UDim2.fromOffset(200, 20), Position = UDim2.fromOffset(52, 6), TextXAlignment = Enum.TextXAlignment.Left}, titleBar)
local subtitle = make("TextLabel", {Text = "@" .. LP.Name, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.dim, BackgroundTransparency = 1,
    Size = UDim2.new(1, -170, 0, 14), Position = UDim2.fromOffset(52, 27), TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd}, titleBar)

local function titleBtn(txt, xoff, color)
    local b = make("TextButton", {Text = txt, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, xoff, 0.5, -14), BackgroundColor3 = color,
        AutoButtonColor = false, BorderSizePixel = 0}, titleBar)
    corner(b, 5)
    track(b.MouseEnter:Connect(function() tween(b, 0.1, {BackgroundTransparency = 0.25}) end))
    track(b.MouseLeave:Connect(function() tween(b, 0.1, {BackgroundTransparency = 0}) end))
    return b
end
local btnHide  = titleBtn("-", -72, Color3.fromRGB(70, 70, 78))
local btnClose = titleBtn("x", -38, Color3.fromRGB(190, 60, 70))
draggable(titleBar, holder, {})

-- sidebar + pages --------------------------------------------------------
local sidebar = make("Frame", {Size = UDim2.new(0, 120, 1, -48), Position = UDim2.fromOffset(0, 48), BackgroundColor3 = T.panel, BorderSizePixel = 0}, main)
make("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.line, BorderSizePixel = 0}, sidebar)
local tabList = make("Frame", {Size = UDim2.new(1, 0, 1, -28), BackgroundTransparency = 1}, sidebar)
make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, tabList)
make("UIPadding", {PaddingTop = UDim.new(0, 8)}, tabList)
make("TextLabel", {Text = "RShift: toggle menu", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.dim, BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -26)}, sidebar)
local content = make("Frame", {Size = UDim2.new(1, -120, 1, -48), Position = UDim2.fromOffset(120, 48), BackgroundTransparency = 1, ClipsDescendants = true}, main)

local pages, tabs, currentTab, orders = {}, {}, nil, {}
local function ord(page) orders[page] = (orders[page] or 0) + 1; return orders[page] end

local function paintTabs()
    for n, t in pairs(tabs) do
        local on = (n == currentTab)
        tween(t.btn, 0.15, {BackgroundColor3 = on and T.row or T.panel, TextColor3 = on and T.text or T.dim})
        t.bar.BackgroundColor3 = T.accent
        t.bar.Visible = on
    end
end
local function selectTab(name)
    currentTab = name
    for n, p in pairs(pages) do
        if n == name then
            p.Visible = true; p.Position = UDim2.fromOffset(0, 10)
            tween(p, 0.2, {Position = UDim2.fromOffset(0, 0)})
        else p.Visible = false end
    end
    paintTabs()
end
onTheme(paintTabs)

local function addTab(name, order)
    local page = make("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false}, content)
    onTheme(function() page.ScrollBarImageColor3 = T.accent end)
    make("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    make("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12)}, page)
    pages[name] = page
    local b = make("TextButton", {Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.panel,
        AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order}, tabList)
    make("UIPadding", {PaddingLeft = UDim.new(0, 16)}, b)
    local bar = make("Frame", {Size = UDim2.new(0, 3, 1, -10), Position = UDim2.fromOffset(-16, 5), BorderSizePixel = 0, Visible = false}, b)
    tabs[name] = {btn = b, bar = bar}
    track(b.MouseButton1Click:Connect(function() selectTab(name) end))
    return page
end

-- badge (active feature count) -------------------------------------------
local toggleState, badge, badgeLabel = {}, nil, nil
local function refreshBadge()
    if not badge then return end
    local n = 0
    for _, v in pairs(toggleState) do if v then n += 1 end end
    badgeLabel.Text = tostring(n)
    badge.Visible = n > 0
end

-- components -------------------------------------------------------------
local function addSection(page, text)
    local f = make("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = ord(page)}, page)
    make("TextLabel", {Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.dim,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(2, 2), TextXAlignment = Enum.TextXAlignment.Left}, f)
    make("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.line, BorderSizePixel = 0}, f)
end

local function addToggle(page, label, default, cb, noBadge)
    local row = make("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.row, BorderSizePixel = 0, LayoutOrder = ord(page)}, page)
    corner(row, 6)
    make("TextLabel", {Text = label, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = T.text, BackgroundTransparency = 1,
        Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(12, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd}, row)
    local box = make("Frame", {Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -32, 0.5, -10), BackgroundColor3 = T.off, BorderSizePixel = 0}, row)
    corner(box, 4)
    local mark = make("Frame", {Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, BorderSizePixel = 0}, box)
    corner(mark, 2)
    local state = false
    local function visual()
        tween(box, 0.15, {BackgroundColor3 = state and T.accent or T.off})
        mark.BackgroundColor3 = contrast(T.accent)
        tween(mark, 0.15, {BackgroundTransparency = state and 0 or 1})
    end
    local function set(v, silent)
        state = v; visual()
        if not noBadge then toggleState[label] = v; refreshBadge() end
        if not silent then toast(label .. (v and ": on" or ": off")); task.spawn(cb, v) end
    end
    onTheme(visual)
    local hit = make("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0)}, row)
    track(hit.MouseButton1Click:Connect(function() set(not state) end))
    set(default, true)
    if default then task.spawn(cb, true) end
    return set
end

local function addSlider(page, label, min, max, default, step, cb)
    local row = make("Frame", {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = T.row, BorderSizePixel = 0, LayoutOrder = ord(page)}, page)
    corner(row, 6)
    make("TextLabel", {Text = label, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = T.text, BackgroundTransparency = 1,
        Size = UDim2.new(1, -80, 0, 22), Position = UDim2.fromOffset(12, 4), TextXAlignment = Enum.TextXAlignment.Left}, row)
    local val = make("TextLabel", {Text = tostring(default), Font = Enum.Font.GothamBold, TextSize = 14, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(60, 22), Position = UDim2.new(1, -72, 0, 4), TextXAlignment = Enum.TextXAlignment.Right}, row)
    onTheme(function() val.TextColor3 = T.accent end)
    local bar = make("Frame", {Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 34), BackgroundColor3 = T.off, BorderSizePixel = 0}, row)
    corner(bar, 3)
    local fill = make("Frame", {Size = UDim2.new((default - min) / (max - min), 0, 1, 0), BorderSizePixel = 0}, bar)
    corner(fill, 3)
    onTheme(function() fill.BackgroundColor3 = T.accent end)
    local dragging = false
    local function update(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.clamp(math.floor((min + (max - min) * a) / step + 0.5) * step, min, max)
        val.Text = tostring(v)
        tween(fill, 0.05, {Size = UDim2.new((v - min) / (max - min), 0, 1, 0)})
        cb(v)
    end
    local function stop() if dragging then dragging = false; page.ScrollingEnabled = true end end
    track(bar.InputBegan:Connect(function(i)
        if isPress(i) then dragging = true; page.ScrollingEnabled = false; update(i.Position.X) end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end
    end))
    track(UIS.InputEnded:Connect(function(i) if isPress(i) then stop() end end))
    cb(default)
end

-- button: colored frame behind, text on its own transparent button (text is never tinted)
local function addButton(page, label, cb)
    local bg = make("Frame", {Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0, LayoutOrder = ord(page)}, page)
    corner(bg, 6)
    local b = make("TextButton", {Text = label, Font = Enum.Font.GothamBold, TextSize = 14, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), AutoButtonColor = false}, bg)
    onTheme(function() bg.BackgroundColor3 = T.accent; b.TextColor3 = contrast(T.accent) end)
    track(b.MouseEnter:Connect(function() tween(bg, 0.1, {BackgroundTransparency = 0.18}) end))
    track(b.MouseLeave:Connect(function() tween(bg, 0.1, {BackgroundTransparency = 0}) end))
    track(b.MouseButton1Click:Connect(function()
        tween(bg, 0.06, {Size = UDim2.new(1, -6, 0, 31)}).Completed:Connect(function() tween(bg, 0.08, {Size = UDim2.new(1, 0, 0, 34)}) end)
        task.spawn(cb)
    end))
end

local function addSwatches(page, label, cb)
    local row = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.row, BorderSizePixel = 0, LayoutOrder = ord(page)}, page)
    corner(row, 6)
    make("TextLabel", {Text = label, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = T.text, BackgroundTransparency = 1,
        Size = UDim2.new(0, 70, 1, 0), Position = UDim2.fromOffset(12, 0), TextXAlignment = Enum.TextXAlignment.Left}, row)
    local box = make("Frame", {Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(84, 0), BackgroundTransparency = 1}, row)
    make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6)}, box)
    for _, p in ipairs(PRESETS) do
        local s = make("TextButton", {Text = "", Size = UDim2.fromOffset(24, 24), BackgroundColor3 = p[2], AutoButtonColor = false, BorderSizePixel = 0}, box)
        corner(s, 5)
        track(s.MouseButton1Click:Connect(function() cb(p[2]); toast("Accent: " .. p[1]) end))
    end
end

-- info card: optional avatar header + key/value rows; returns label refs
local function addCard(page, withHeader, keys)
    local card = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.row,
        BorderSizePixel = 0, LayoutOrder = ord(page)}, page)
    corner(card, 6)
    make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, card)
    make("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, card)
    local refs = {}
    if withHeader then
        local head = make("Frame", {Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, LayoutOrder = 0}, card)
        refs.thumb = make("ImageLabel", {Size = UDim2.fromOffset(54, 54), BackgroundColor3 = T.panel, BorderSizePixel = 0, Image = ""}, head)
        corner(refs.thumb, 6)
        refs.name = make("TextLabel", {Text = "-", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.text, BackgroundTransparency = 1,
            Size = UDim2.new(1, -64, 0, 22), Position = UDim2.fromOffset(64, 6), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd}, head)
        refs.sub = make("TextLabel", {Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.dim, BackgroundTransparency = 1,
            Size = UDim2.new(1, -64, 0, 18), Position = UDim2.fromOffset(64, 28), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd}, head)
    end
    for idx, k in ipairs(keys) do
        local r = make("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = idx}, card)
        make("TextLabel", {Text = k, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.dim, BackgroundTransparency = 1,
            Size = UDim2.new(0, 96, 1, 0), TextXAlignment = Enum.TextXAlignment.Left}, r)
        refs[k] = make("TextLabel", {Text = "-", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.text, BackgroundTransparency = 1,
            Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(100, 0), TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd}, r)
    end
    return refs
end

local function loadThumb(label, userId, stillWanted)
    task.spawn(function()
        local ok, img = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        if ok and label.Parent and stillWanted() then label.Image = img end
    end)
end

-- pages ------------------------------------------------------------------
local pMove = addTab("Movement", 1)
local pVis  = addTab("Visuals", 2)
local pPl   = addTab("Players", 3)
local pMisc = addTab("Misc", 4)
local pSet  = addTab("Settings", 5)

-- floating button --------------------------------------------------------
local fab = make("Frame", {Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(12, math.floor(vp.Y / 2) - 27), BackgroundTransparency = 1, ZIndex = 20}, gui)
local ring = make("Frame", {Size = UDim2.fromOffset(54, 54), BackgroundTransparency = 1, ZIndex = 19}, fab)
corner(ring, 27)
local ringStroke = make("UIStroke", {Thickness = 2, Transparency = 0.3}, ring)
onTheme(function() ringStroke.Color = T.accent end)
local core = make("Frame", {Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    BorderSizePixel = 0, ZIndex = 21}, fab)
corner(core, 22)
local coreBtn = make("TextButton", {Text = "M", Font = Enum.Font.GothamBlack, TextSize = 20, BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), AutoButtonColor = false, ZIndex = 22}, core)
local spark = make("TextLabel", {Text = "✦", Font = Enum.Font.GothamBold, TextSize = 13, BackgroundTransparency = 1,
    Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -9, 0, 9), ZIndex = 25, Active = false}, fab)
onTheme(function()
    core.BackgroundColor3 = T.accent; coreBtn.TextColor3 = contrast(T.accent); spark.TextColor3 = T.accent
end)
badge = make("Frame", {Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, -4, 1, -16), BackgroundColor3 = T.bg, BorderSizePixel = 0, ZIndex = 23, Visible = false}, fab)
corner(badge, 10)
local badgeStroke = make("UIStroke", {Thickness = 1.5}, badge)
onTheme(function() badgeStroke.Color = T.accent end)
badgeLabel = make("TextLabel", {Text = "0", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.text, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 24}, badge)

-- open / close -----------------------------------------------------------
local open = false
local function setOpen(v)
    open = v
    main.Visible = true
    local tw = tween(uiScale, 0.28, {Scale = v and baseScale() or 0}, v and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
    if not v then tw.Completed:Connect(function() if not open then main.Visible = false end end) end
end
draggable(coreBtn, fab, {clamp = true,
    onClick = function() setOpen(not open) end,
    onDrop = function()
        local v = cam() and cam().ViewportSize or vp
        local cx = fab.AbsolutePosition.X + fab.AbsoluteSize.X / 2
        local x = (cx < v.X / 2) and 8 or (v.X - fab.AbsoluteSize.X - 8)
        tween(fab, 0.28, {Position = UDim2.fromOffset(x, fab.AbsolutePosition.Y)}, Enum.EasingStyle.Back)
    end})
track(btnHide.MouseButton1Click:Connect(function() setOpen(false) end))
track(UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then setOpen(not open) end
end))

-- crosshair + HUD --------------------------------------------------------
local cross = make("Frame", {Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false}, gui)
local crossParts = {}
for _, d in ipairs({{-9, -1, 7, 2}, {2, -1, 7, 2}, {-1, -9, 2, 7}, {-1, 2, 2, 7}}) do
    crossParts[#crossParts + 1] = make("Frame", {Position = UDim2.fromOffset(d[1], d[2]), Size = UDim2.fromOffset(d[3], d[4]), BorderSizePixel = 0}, cross)
end
onTheme(function() for _, p in ipairs(crossParts) do p.BackgroundColor3 = T.accent end end)

local hud = make("TextLabel", {Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.text, BackgroundColor3 = T.panel, BackgroundTransparency = 0.15,
    Size = UDim2.fromOffset(130, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), BorderSizePixel = 0, Visible = false}, gui)
corner(hud, 5)
local fpsAvg, hudAcc = 60, 0
local function getPing()
    local ping = 0
    pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    return ping
end

-- features: movement -----------------------------------------------------
local orig = {}
local function restoreMovement()
    local hum = getHum()
    if hum then
        if orig.walk then hum.WalkSpeed = orig.walk end
        if orig.jp ~= nil then hum.UseJumpPower = orig.uj; hum.JumpPower = orig.jp end
    end
    if orig.grav then workspace.Gravity = orig.grav end
    orig = {}
end
track(RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if hum then
        if S.speed then orig.walk = orig.walk or hum.WalkSpeed; hum.WalkSpeed = S.speedValue
        elseif orig.walk then hum.WalkSpeed = orig.walk; orig.walk = nil end
        if S.jump then
            if orig.jp == nil then orig.jp = hum.JumpPower; orig.uj = hum.UseJumpPower end
            hum.UseJumpPower = true; hum.JumpPower = S.jumpValue
        elseif orig.jp ~= nil then
            hum.UseJumpPower = orig.uj; hum.JumpPower = orig.jp; orig.jp = nil; orig.uj = nil
        end
    end
    if S.gravity then orig.grav = orig.grav or workspace.Gravity; workspace.Gravity = S.gravityValue
    elseif orig.grav then workspace.Gravity = orig.grav; orig.grav = nil end
end))
track(LP.CharacterAdded:Connect(function() orig.walk = nil; orig.jp = nil; orig.uj = nil end))

track(UIS.JumpRequest:Connect(function()
    if not S.infJump then return end
    local hum = getHum()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

local noclipped = {}
track(RunService.Stepped:Connect(function()
    local c = getChar()
    if S.noclip and c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false; noclipped[p] = true end
        end
    elseif next(noclipped) then
        for p in pairs(noclipped) do if p.Parent then p.CanCollide = true end; noclipped[p] = nil end
    end
end))

-- fly (camera-steered, mobile pad) --------------------------------------
local flyBV, flyBG, flyVel, flyUp, flyDown, flyPlat = nil, nil, Vector3.zero, false, false, false
local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    flyVel = Vector3.zero
    if flyPlat then
        local hum = getHum(); if hum then hum.PlatformStand = false end
        flyPlat = false
    end
end

local pad = make("Frame", {Size = UDim2.fromOffset(60, 178), Position = UDim2.fromOffset(math.floor(vp.X - 84), math.floor(vp.Y - 250)), BackgroundTransparency = 1, Visible = false, ZIndex = 20}, gui)
local padButtons = {}
local function padBtn(txt, y, h)
    local b = make("TextButton", {Text = txt, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.text, Size = UDim2.fromOffset(60, h),
        Position = UDim2.fromOffset(0, y), BackgroundColor3 = T.panel, BackgroundTransparency = 0.05, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 21}, pad)
    corner(b, 8)
    local st = make("UIStroke", {Thickness = 1.5}, b)
    onTheme(function() st.Color = T.accent end)
    padButtons[#padButtons + 1] = b
    return b
end
local btnUp   = padBtn("UP", 0, 52)
local btnFly  = padBtn("FLY", 58, 62)
local btnDown = padBtn("DN", 126, 52)
local function holdBtn(b, setter)
    track(b.InputBegan:Connect(function(i) if isPress(i) then setter(true) end end))
    track(b.InputEnded:Connect(function(i) if isPress(i) then setter(false) end end))
end
holdBtn(btnUp, function(v) flyUp = v end)
holdBtn(btnDown, function(v) flyDown = v end)

local flyToggleSet
local function refreshPad()
    pad.Visible = S.flyPad
    btnUp.Visible, btnDown.Visible = S.fly, S.fly
    btnFly.BackgroundColor3 = S.fly and T.accent or T.panel
    btnFly.TextColor3 = S.fly and contrast(T.accent) or T.text
end
onTheme(refreshPad)
draggable(btnFly, pad, {clamp = true, onClick = function() if flyToggleSet then flyToggleSet(not S.fly) end end})

track(RunService.Heartbeat:Connect(function(dt)
    local root, hum, c = getRoot(), getHum(), cam()
    if not (S.fly and root and hum and c) then stopFly(); return end
    if not flyBV or flyBV.Parent ~= root then
        stopFly()
        flyBV = make("BodyVelocity", {MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero}, root)
        flyBG = make("BodyGyro", {MaxTorque = Vector3.new(4e5, 4e5, 4e5), P = 2e4, D = 1e3, CFrame = root.CFrame}, root)
    end
    hum.PlatformStand = true; flyPlat = true
    local look, right = c.CFrame.LookVector, c.CFrame.RightVector
    local flat = Vector3.new(look.X, 0, look.Z)
    flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.zero
    local mv, dir = hum.MoveDirection, Vector3.zero
    if mv.Magnitude > 0.01 then
        if S.flySteer then
            local rflat = Vector3.new(right.X, 0, right.Z)
            rflat = rflat.Magnitude > 1e-3 and rflat.Unit or Vector3.zero
            dir = look * mv:Dot(flat) + rflat * mv:Dot(rflat)
        else dir = mv end
    end
    local vert = 0
    if UIS:IsKeyDown(Enum.KeyCode.Space) or flyUp then vert += 1 end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or flyDown then vert -= 1 end
    local goal = dir * S.flySpeed + Vector3.new(0, vert * S.flySpeed, 0)
    flyVel = flyVel:Lerp(goal, math.clamp(dt * 10, 0, 1))
    flyBV.Velocity = flyVel
    if flat ~= Vector3.zero then flyBG.CFrame = CFrame.lookAt(root.Position, root.Position + flat) end
end))

-- spin -------------------------------------------------------------------
track(RunService.Heartbeat:Connect(function(dt)
    if not S.spin or S.fly then return end
    local root = getRoot()
    if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(S.spinSpeed * 60 * dt), 0) end
end))

-- click / tap teleport ---------------------------------------------------
local taps = {}
local function tapKey(i) return i.UserInputType == Enum.UserInputType.Touch and i or i.UserInputType end
track(UIS.InputBegan:Connect(function(i, gp)
    if gp or not S.clickTp or not isPress(i) then return end
    taps[tapKey(i)] = {pos = i.Position, t = os.clock()}
end))
track(UIS.InputEnded:Connect(function(i)
    if not isPress(i) then return end
    local k = tapKey(i); local st = taps[k]; taps[k] = nil
    if not st or not S.clickTp then return end
    if i.UserInputType ~= Enum.UserInputType.Touch and not UIS:IsKeyDown(Enum.KeyCode.LeftControl) then return end
    if (i.Position - st.pos).Magnitude > 12 or os.clock() - st.t > 0.35 then return end
    local c, root = cam(), getRoot()
    if not (c and root) then return end
    local ray = c:ScreenPointToRay(i.Position.X, i.Position.Y)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {getChar()}
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, rp)
    if hit then
        root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.5, 0)) * (root.CFrame - root.CFrame.Position)
        toast("Teleported")
    end
end))

-- ESP --------------------------------------------------------------------
local esp = {}
local playerPickerRefresh
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
    local hl = make("Highlight", {Adornee = ch, FillColor = T.accent, OutlineColor = Color3.new(1, 1, 1),
        FillTransparency = 0.6, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, espFolder)
    local bb = make("BillboardGui", {Adornee = head, Size = UDim2.fromOffset(200, 34), StudsOffset = Vector3.new(0, 2.6, 0), AlwaysOnTop = true}, espFolder)
    local lab = make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = plr.Name}, bb)
    esp[plr] = {hl = hl, bb = bb, lab = lab}
end
local function rebuildEsp() for _, p in ipairs(Players:GetPlayers()) do createEsp(p) end end
local function hookPlayer(p) track(p.CharacterAdded:Connect(function() task.wait(0.3); createEsp(p) end)) end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then hookPlayer(p) end end
track(Players.PlayerAdded:Connect(function(p) hookPlayer(p); createEsp(p); if playerPickerRefresh then playerPickerRefresh() end end))
track(Players.PlayerRemoving:Connect(function(p)
    removeEsp(p)
    if S.target == p then S.target = nil; S.spectate = false end
    task.defer(function() if playerPickerRefresh then playerPickerRefresh() end end)
end))

local espAcc = 0
track(RunService.Heartbeat:Connect(function(dt)
    espAcc += dt
    if espAcc < 0.1 then return end
    espAcc = 0
    local myRoot = getRoot()
    for plr, e in pairs(esp) do
        local ch = plr.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not (ch and root and e.hl.Parent) then removeEsp(plr)
        else
            local hide = S.espTeam and plr.Team ~= nil and plr.Team == LP.Team
            e.hl.Enabled = not hide
            e.bb.Enabled = (not hide) and S.espNames
            if plr.Team and plr.TeamColor then e.hl.FillColor = plr.TeamColor.Color end
            local d = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
            local txt = plr.Name .. "  [" .. d .. "m]"
            if S.espHealth then
                local h = ch:FindFirstChildOfClass("Humanoid")
                if h then txt ..= "  HP " .. math.floor(h.Health) end
            end
            e.lab.Text = txt
        end
    end
end))

-- lighting ---------------------------------------------------------------
local lightSaved, atmSaved, lightKey = nil, nil, 0
local function restoreLight()
    if lightSaved then for k, v in pairs(lightSaved) do Lighting[k] = v end end
    if atmSaved and atmSaved.atm.Parent then atmSaved.atm.Density = atmSaved.Density; atmSaved.atm.Haze = atmSaved.Haze end
    lightSaved, atmSaved = nil, nil
end
track(RunService.RenderStepped:Connect(function()
    local key = (S.fullbright and 1 or 0) + (S.noFog and 2 or 0) + (S.clockOn and 4 or 0)
    if key ~= lightKey then restoreLight(); lightKey = key end
    if key == 0 then return end
    if not lightSaved then
        lightSaved = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
            GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient}
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atmSaved = {atm = atm, Density = atm.Density, Haze = atm.Haze} end
    end
    if S.fullbright then
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    end
    if S.noFog then
        Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6
        if atmSaved and atmSaved.atm.Parent then atmSaved.atm.Density = 0; atmSaved.atm.Haze = 0 end
    end
    if S.clockOn then Lighting.ClockTime = S.clock end
end))

-- camera: fov, zoom, spectate, hud --------------------------------------
local origFov, origZoom
local function restoreCamera()
    local c = cam()
    if c and origFov then c.FieldOfView = origFov end
    origFov = nil
    if origZoom then LP.CameraMaxZoomDistance = origZoom[1]; LP.CameraMinZoomDistance = origZoom[2]; origZoom = nil end
    local hum = getHum()
    if c and hum and c.CameraSubject ~= hum then c.CameraSubject = hum end
end
track(RunService.RenderStepped:Connect(function(dt)
    local c = cam()
    if not c then return end
    if S.fovOn then origFov = origFov or c.FieldOfView; c.FieldOfView = S.fov
    elseif origFov then c.FieldOfView = origFov; origFov = nil end
    if S.zoom then
        origZoom = origZoom or {LP.CameraMaxZoomDistance, LP.CameraMinZoomDistance}
        LP.CameraMaxZoomDistance = 1e4; LP.CameraMinZoomDistance = 0
    elseif origZoom then LP.CameraMaxZoomDistance = origZoom[1]; LP.CameraMinZoomDistance = origZoom[2]; origZoom = nil end
    if S.spectate then
        local th = S.target and S.target.Character and S.target.Character:FindFirstChildOfClass("Humanoid")
        if th and c.CameraSubject ~= th then c.CameraSubject = th end
    end
    cross.Visible = S.crosshair
    fpsAvg = fpsAvg + ((1 / math.max(dt, 1e-3)) - fpsAvg) * 0.05
    hudAcc += dt
    if S.hud and hudAcc > 0.4 then
        hudAcc = 0
        hud.Text = string.format("%d FPS  |  %d ms", math.floor(fpsAvg + 0.5), getPing())
    end
    hud.Visible = S.hud
end))

-- anti-afk ---------------------------------------------------------------
track(LP.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
end))

-- menu content: movement -------------------------------------------------
addSection(pMove, "Speed and jump")
addToggle(pMove, "Speed hack", false, function(v) S.speed = v end)
addSlider(pMove, "Walk speed", 16, 200, 50, 1, function(v) S.speedValue = v end)
addToggle(pMove, "Jump power", false, function(v) S.jump = v end)
addSlider(pMove, "Power", 50, 300, 80, 5, function(v) S.jumpValue = v end)
addToggle(pMove, "Infinite jump", false, function(v) S.infJump = v end)
addSection(pMove, "Flight")
flyToggleSet = addToggle(pMove, "Fly", false, function(v) S.fly = v; if not v then flyUp, flyDown = false, false end; refreshPad() end)
addSlider(pMove, "Fly speed", 10, 250, 60, 1, function(v) S.flySpeed = v end)
addToggle(pMove, "Steer with camera (look to climb)", true, function(v) S.flySteer = v end, true)
addToggle(pMove, "On-screen fly pad", TOUCH, function(v) S.flyPad = v; refreshPad() end, true)
addSection(pMove, "World")
addToggle(pMove, "Noclip", false, function(v) S.noclip = v end)
addToggle(pMove, "Custom gravity", false, function(v) S.gravity = v end)
addSlider(pMove, "Gravity", 0, 196, 60, 2, function(v) S.gravityValue = v end)
addToggle(pMove, "Click / tap teleport (Ctrl+click on PC)", false, function(v) S.clickTp = v end)
addToggle(pMove, "Spin", false, function(v) S.spin = v end)
addSlider(pMove, "Spin speed", 1, 30, 8, 1, function(v) S.spinSpeed = v end)

-- menu content: visuals --------------------------------------------------
addSection(pVis, "Players")
addToggle(pVis, "Player ESP", false, function(v) S.esp = v; rebuildEsp() end)
addToggle(pVis, "ESP names + distance", true, function(v) S.espNames = v end, true)
addToggle(pVis, "ESP health", true, function(v) S.espHealth = v end, true)
addToggle(pVis, "Hide teammates", false, function(v) S.espTeam = v end, true)
addSection(pVis, "World")
addToggle(pVis, "Fullbright", false, function(v) S.fullbright = v end)
addToggle(pVis, "No fog", false, function(v) S.noFog = v end)
addToggle(pVis, "Custom time of day", false, function(v) S.clockOn = v end)
addSlider(pVis, "Hour", 0, 24, 14, 0.5, function(v) S.clock = v end)
addSection(pVis, "Camera")
addToggle(pVis, "Custom FOV", false, function(v) S.fovOn = v end)
addSlider(pVis, "FOV", 40, 120, 90, 1, function(v) S.fov = v end)
addToggle(pVis, "Unlock zoom distance", false, function(v) S.zoom = v end)
addToggle(pVis, "Crosshair", false, function(v) S.crosshair = v end)

-- menu content: players --------------------------------------------------
addSection(pPl, "You and server")
local meCard = addCard(pPl, true, {"User ID", "Account age", "Server players", "Ping", "FPS", "Place ID", "Job ID", "Position"})
meCard.name.Text = LP.DisplayName
meCard.sub.Text = "@" .. LP.Name .. "  (you)"
meCard["User ID"].Text = tostring(LP.UserId)
meCard["Account age"].Text = LP.AccountAge .. " days"
meCard["Place ID"].Text = tostring(game.PlaceId)
meCard["Job ID"].Text = (game.JobId ~= "" and string.sub(game.JobId, 1, 8) .. "...") or "studio"
loadThumb(meCard.thumb, LP.UserId, function() return true end)

addSection(pPl, "Target")
local pickerLabel
local tgtCard
local function setTarget(p)
    S.target = p
    if pickerLabel then pickerLabel.Text = p and ("Target: " .. p.Name) or "Target: none" end
    if tgtCard then
        tgtCard.thumb.Image = ""
        if p then loadThumb(tgtCard.thumb, p.UserId, function() return S.target == p end) end
    end
    if not p then S.spectate = false end
end

local function addPlayerPicker(page)
    local wrap = make("Frame", {Size = UDim2.new(1, 0, 0, 34), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.row, BorderSizePixel = 0, LayoutOrder = ord(page)}, page)
    corner(wrap, 6)
    make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, wrap)
    local head = make("TextButton", {Text = "", Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 1}, wrap)
    pickerLabel = make("TextLabel", {Text = "Target: none", Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = T.text, BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(12, 0), TextXAlignment = Enum.TextXAlignment.Left}, head)
    make("TextLabel", {Text = "v", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.dim, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(24, 34), Position = UDim2.new(1, -30, 0, 0)}, head)
    local list = make("ScrollingFrame", {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, LayoutOrder = 2,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3}, wrap)
    make("UIListLayout", {Padding = UDim.new(0, 3)}, list)
    make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6)}, list)
    local isOpen = false
    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local others = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then others[#others + 1] = p end end
        for _, p in ipairs(others) do
            local b = make("TextButton", {Text = p.DisplayName .. "  (@" .. p.Name .. ")", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.text,
                Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.panel, AutoButtonColor = false, BorderSizePixel = 0}, list)
            corner(b, 5)
            track(b.MouseButton1Click:Connect(function() setTarget(p); isOpen = false; list.Visible = false end))
        end
        list.Size = UDim2.new(1, 0, 0, math.max(math.min(#others, 4) * 31 + 6, 6))
        if S.target and not S.target.Parent then setTarget(nil) end
    end
    track(head.MouseButton1Click:Connect(function() isOpen = not isOpen; list.Visible = isOpen; rebuild() end))
    playerPickerRefresh = rebuild
    rebuild()
end
addPlayerPicker(pPl)

tgtCard = addCard(pPl, true, {"User ID", "Account age", "Team", "Status", "Health", "Walk speed", "Distance", "Position", "Holding"})
tgtCard.name.Text = "No target selected"

addButton(pPl, "Teleport to target", function()
    local root = getRoot()
    local tr = S.target and S.target.Character and S.target.Character:FindFirstChild("HumanoidRootPart")
    if root and tr then root.CFrame = tr.CFrame * CFrame.new(0, 0, 3); toast("Teleported to " .. S.target.Name)
    else toast("Pick a target first") end
end)
addToggle(pPl, "Spectate target", false, function(v)
    if v and not S.target then toast("Pick a target first") end
    S.spectate = v and S.target ~= nil
    if not S.spectate then
        local c, hum = cam(), getHum()
        if c and hum then c.CameraSubject = hum end
    end
end, true)
addButton(pPl, "Copy target username", function()
    if S.target then copy(S.target.Name, "Username copied", toast) else toast("Pick a target first") end
end)
addButton(pPl, "Copy target user ID", function()
    if S.target then copy(tostring(S.target.UserId), "User ID copied", toast) else toast("Pick a target first") end
end)

-- live info refresh (cards + subtitle) ----------------------------------
local function fmtPos(p) return string.format("%.0f, %.0f, %.0f", p.X, p.Y, p.Z) end
local infoAcc = 0
track(RunService.Heartbeat:Connect(function(dt)
    infoAcc += dt
    if infoAcc < 0.3 then return end
    infoAcc = 0
    local count = #Players:GetPlayers()
    local ping = getPing()
    subtitle.Text = string.format("@%s  |  %d/%d players  |  %d ms  |  %d fps", LP.Name, count, Players.MaxPlayers, ping, math.floor(fpsAvg + 0.5))
    if open and currentTab == "Players" then
        meCard["Server players"].Text = count .. " / " .. Players.MaxPlayers
        meCard["Ping"].Text = ping .. " ms"
        meCard["FPS"].Text = tostring(math.floor(fpsAvg + 0.5))
        local r = getRoot()
        meCard["Position"].Text = r and fmtPos(r.Position) or "-"
        local t = S.target
        if t and t.Parent then
            tgtCard.name.Text = t.DisplayName
            tgtCard.sub.Text = "@" .. t.Name
            tgtCard["User ID"].Text = tostring(t.UserId)
            tgtCard["Account age"].Text = t.AccountAge .. " days"
            tgtCard["Team"].Text = t.Team and t.Team.Name or "none"
            local ch = t.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if hum and root then
                tgtCard["Status"].Text = hum.Health > 0 and "Alive" or "Dead"
                tgtCard["Health"].Text = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
                tgtCard["Walk speed"].Text = string.format("%.0f", hum.WalkSpeed)
                tgtCard["Position"].Text = fmtPos(root.Position)
                tgtCard["Distance"].Text = r and (math.floor((r.Position - root.Position).Magnitude) .. " studs") or "-"
                local tool = ch:FindFirstChildOfClass("Tool")
                tgtCard["Holding"].Text = tool and tool.Name or "nothing"
            else
                tgtCard["Status"].Text = "No character"
                for _, k in ipairs({"Health", "Walk speed", "Distance", "Position", "Holding"}) do tgtCard[k].Text = "-" end
            end
        else
            tgtCard.name.Text = "No target selected"
            tgtCard.sub.Text = ""
            for _, k in ipairs({"User ID", "Account age", "Team", "Status", "Health", "Walk speed", "Distance", "Position", "Holding"}) do tgtCard[k].Text = "-" end
        end
    end
end))

-- menu content: misc / settings -----------------------------------------
addSection(pMisc, "Utility")
addToggle(pMisc, "Anti-AFK", true, function(v) S.antiAfk = v end, true)
addToggle(pMisc, "FPS / ping overlay", false, function(v) S.hud = v end)
addButton(pMisc, "Copy position", function()
    local r = getRoot()
    if r then local p = r.Position; copy(string.format("%.2f, %.2f, %.2f", p.X, p.Y, p.Z), "Position copied", toast) end
end)
addButton(pMisc, "Reset character", function() local h = getHum(); if h then h.Health = 0 end end)
addButton(pMisc, "Rejoin server", function()
    pcall(function()
        if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, LP)
        else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end
    end)
end)

addSection(pSet, "Look")
addSwatches(pSet, "Accent", applyTheme)
addSlider(pSet, "UI scale", 0.6, 1.4, 1, 0.05, function(v)
    userScale = v
    if open then uiScale.Scale = baseScale() end
end)
addSection(pSet, "Script")
addButton(pSet, "Unload Mayle Hub", function() if env.__MayleUnload then env.__MayleUnload() end end)

selectTab("Movement")

-- unload -----------------------------------------------------------------
local function unload()
    for k in pairs(S) do if type(S[k]) == "boolean" then S[k] = false end end
    S.target = nil
    stopFly(); restoreMovement(); restoreLight(); restoreCamera()
    for p in pairs(noclipped) do if p.Parent then p.CanCollide = true end end
    for plr in pairs(esp) do removeEsp(plr) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    env.__MayleUnload = nil
end
track(btnClose.MouseButton1Click:Connect(unload))
env.__MayleUnload = unload

-- idle animation: ring pulse + spark spin --------------------------------
track(RunService.RenderStepped:Connect(function()
    local t = os.clock()
    ringStroke.Transparency = 0.45 + 0.3 * math.sin(t * 2.4)
    spark.Rotation = (t * 40) % 360
end))

setOpen(true)
toast("Mayle Hub loaded")
