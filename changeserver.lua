local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")
local UserInputService  = game:GetService("UserInputService")
local TeleportService   = game:GetService("TeleportService")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG_FILE = "ServerTools_Config.json"

local DEFAULT_CONFIG = {
    autoHopEnabled = true,
    fpsThreshold   = 5,
    fpsDuration    = 8,
    gracePeriod    = 60,
    teleportDelay  = 5,
    spamMaxHops    = 5,
    spamHopDelay   = 3,
}

local config = {}

local function saveConfig()
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(config))
    end)
end

local function loadConfig()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(DEFAULT_CONFIG) do
            config[k] = (data[k] ~= nil) and data[k] or v
        end
    else
        for k, v in pairs(DEFAULT_CONFIG) do config[k] = v end
    end
end

loadConfig()

-- ============================================================
-- GET JOB_ID
-- ============================================================
local function getJobId()
    return game.JobId
end

-- ============================================================
-- TELEPORT
-- ============================================================
local function teleportByJobId(jobId)
    local sb = ReplicatedStorage:FindFirstChild("__ServerBrowser")
    if sb then
        local ok, err = pcall(function()
            sb:InvokeServer("teleport", jobId)
        end)
        if ok then return true end
        warn("[ServerTools] __ServerBrowser that bai:", err)
    end
    local ok2, err2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId)
    end)
    if not ok2 then
        warn("[ServerTools] TeleportService that bai:", err2)
        return false
    end
    return true
end

-- ============================================================
-- TRANG THAI
-- ============================================================
local isHopping       = false
local cancelHopping   = false
local scriptStartTime = os.clock()
local lowFpsTimer     = 0
local frameCount      = 0
local lastUpdate      = tick()
local menuOpen        = false
local configOpen      = false

-- ============================================================
-- XAY DUNG GUI
-- ============================================================
if CoreGui:FindFirstChild("ServerTools_GUI") then
    CoreGui:FindFirstChild("ServerTools_GUI"):Destroy()
end

local screenGui          = Instance.new("ScreenGui")
screenGui.Name           = "ServerTools_GUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = CoreGui

local C = {
    bg      = Color3.fromRGB(13, 13, 22),
    panel   = Color3.fromRGB(20, 20, 35),
    accent  = Color3.fromRGB(0, 180, 255),
    green   = Color3.fromRGB(0, 200, 100),
    red     = Color3.fromRGB(210, 50, 50),
    orange  = Color3.fromRGB(200, 120, 0),
    purple  = Color3.fromRGB(130, 60, 210),
    text    = Color3.new(1, 1, 1),
    subtext = Color3.fromRGB(150, 150, 180),
    input   = Color3.fromRGB(28, 28, 46),
    btnDark = Color3.fromRGB(30, 30, 52),
}

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color        = color or C.accent
    s.Thickness    = thick or 1
    s.Transparency = 0.5
    s.Parent       = parent
    return s
end

-- nut toggle
local toggleBtn            = Instance.new("TextButton")
toggleBtn.Size             = UDim2.new(0, 120, 0, 30)
toggleBtn.Position         = UDim2.new(0, 10, 0, 10)
toggleBtn.BackgroundColor3 = C.bg
toggleBtn.TextColor3       = C.accent
toggleBtn.TextSize         = 13
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.Text             = "Server Tools"
toggleBtn.BorderSizePixel  = 0
toggleBtn.Parent           = screenGui
corner(toggleBtn, 8); stroke(toggleBtn, C.accent, 1)

local fpsDisplay                  = Instance.new("TextLabel")
fpsDisplay.Size                   = UDim2.new(0, 120, 0, 22)
fpsDisplay.Position               = UDim2.new(0, 10, 0, 44)
fpsDisplay.BackgroundColor3       = C.bg
fpsDisplay.BackgroundTransparency = 0.2
fpsDisplay.TextColor3             = C.green
fpsDisplay.TextSize               = 12
fpsDisplay.Font                   = Enum.Font.GothamBold
fpsDisplay.Text                   = "FPS: ..."
fpsDisplay.BorderSizePixel        = 0
fpsDisplay.Parent                 = screenGui
corner(fpsDisplay, 6)

-- ============================================================
-- MENU CHINH
-- ============================================================
local menuFrame            = Instance.new("Frame")
menuFrame.Name             = "Menu"
menuFrame.Size             = UDim2.new(0, 270, 0, 0)
menuFrame.Position         = UDim2.new(0, 10, 0, 72)
menuFrame.BackgroundColor3 = C.bg
menuFrame.BorderSizePixel  = 0
menuFrame.Visible          = false
menuFrame.ClipsDescendants = true
menuFrame.Parent           = screenGui
corner(menuFrame, 10); stroke(menuFrame, C.accent, 1.2)

local titleBar            = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = C.accent
titleBar.BorderSizePixel  = 0
titleBar.Parent           = menuFrame
corner(titleBar, 10)

local titleFix            = Instance.new("Frame")
titleFix.Size             = UDim2.new(1, 0, 0, 10)
titleFix.Position         = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = C.accent
titleFix.BorderSizePixel  = 0
titleFix.Parent           = titleBar

local titleLbl                  = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(1, -10, 1, 0)
titleLbl.Position               = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3             = C.text
titleLbl.TextSize               = 13
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.Text                   = "Server Tools"
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.Parent                 = titleBar

local scrollFrame                  = Instance.new("ScrollingFrame")
scrollFrame.Size                   = UDim2.new(1, 0, 1, -34)
scrollFrame.Position               = UDim2.new(0, 0, 0, 34)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel        = 0
scrollFrame.ScrollBarThickness     = 3
scrollFrame.ScrollBarImageColor3   = C.accent
scrollFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scrollFrame.Parent                 = menuFrame

local listLayout               = Instance.new("UIListLayout")
listLayout.Padding             = UDim.new(0, 6)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent              = scrollFrame

local listPad         = Instance.new("UIPadding")
listPad.PaddingTop    = UDim.new(0, 8)
listPad.PaddingBottom = UDim.new(0, 8)
listPad.PaddingLeft   = UDim.new(0, 10)
listPad.PaddingRight  = UDim.new(0, 10)
listPad.Parent        = scrollFrame

local function makeBtn(text, bgColor)
    local b            = Instance.new("TextButton")
    b.Size             = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = bgColor or C.btnDark
    b.TextColor3       = C.text
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamSemibold
    b.Text             = text
    b.BorderSizePixel  = 0
    b.Parent           = scrollFrame
    corner(b, 7)
    return b
end

local function makeLabel(text)
    local l                  = Instance.new("TextLabel")
    l.Size                   = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.TextColor3             = C.subtext
    l.TextSize               = 12
    l.Font                   = Enum.Font.GothamMedium
    l.Text                   = text
    l.TextXAlignment         = Enum.TextXAlignment.Left
    l.Parent                 = scrollFrame
    return l
end

local function makeTextBox(placeholder)
    local b             = Instance.new("TextBox")
    b.Size              = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3  = C.input
    b.TextColor3        = C.text
    b.PlaceholderText   = placeholder or ""
    b.PlaceholderColor3 = C.subtext
    b.TextSize          = 12
    b.Font              = Enum.Font.Gotham
    b.ClearTextOnFocus  = false
    b.BorderSizePixel   = 0
    b.Parent            = scrollFrame
    corner(b, 6); stroke(b, C.accent, 1)
    return b
end

local function makeSep()
    local s            = Instance.new("Frame")
    s.Size             = UDim2.new(1, 0, 0, 1)
    s.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    s.BorderSizePixel  = 0
    s.Parent           = scrollFrame
    return s
end

-- nut menu
makeLabel("Job ID: " .. getJobId())
local jobIdBox   = makeTextBox("Paste Job ID vao day...")
local joinJobBtn = makeBtn("  Join theo Job ID", C.accent)
local copyJobBtn = makeBtn("  Copy Job ID",      C.accent)

makeSep()

local SPAM_ORIG_TEXT     = "  Spam Hop Ngau Nhien"
local SPAM_LOW_ORIG_TEXT = "  Spam Hop It Player"

local spamHopBtn = makeBtn(SPAM_ORIG_TEXT,     C.btnDark)
local spamLowBtn = makeBtn(SPAM_LOW_ORIG_TEXT, C.purple)

local autoHopBtn = makeBtn("", C.green)
local function refreshAutoBtn()
    if config.autoHopEnabled then
        autoHopBtn.BackgroundColor3 = C.green
        autoHopBtn.Text             = "  Auto FPS Hop: BAT"
    else
        autoHopBtn.BackgroundColor3 = C.red
        autoHopBtn.Text             = "  Auto FPS Hop: TAT"
    end
end
refreshAutoBtn()

makeSep()
local openCfgBtn = makeBtn("  Chinh Config...", C.btnDark)

local function resizeMenu()
    local h = listLayout.AbsoluteContentSize.Y + 34 + 16
    menuFrame.Size = UDim2.new(0, 270, 0, math.min(h, 480))
end
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeMenu)

-- ============================================================
-- PANEL CONFIG
-- ============================================================
local cfgPanel            = Instance.new("Frame")
cfgPanel.Name             = "ConfigPanel"
cfgPanel.Size             = UDim2.new(1, 0, 1, -34)
cfgPanel.Position         = UDim2.new(0, 0, 0, 34)
cfgPanel.BackgroundColor3 = C.bg
cfgPanel.BorderSizePixel  = 0
cfgPanel.Visible          = false
cfgPanel.ClipsDescendants = true
cfgPanel.ZIndex           = 10
cfgPanel.Parent           = menuFrame

local cfgScroll                  = Instance.new("ScrollingFrame")
cfgScroll.Size                   = UDim2.new(1, 0, 1, 0)
cfgScroll.BackgroundTransparency = 1
cfgScroll.BorderSizePixel        = 0
cfgScroll.ScrollBarThickness     = 3
cfgScroll.ScrollBarImageColor3   = C.accent
cfgScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
cfgScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
cfgScroll.Parent                 = cfgPanel

local cfgList                    = Instance.new("UIListLayout")
cfgList.Padding                  = UDim.new(0, 10)
cfgList.HorizontalAlignment      = Enum.HorizontalAlignment.Center
cfgList.Parent                   = cfgScroll

local cfgPad         = Instance.new("UIPadding")
cfgPad.PaddingTop    = UDim.new(0, 10)
cfgPad.PaddingBottom = UDim.new(0, 10)
cfgPad.PaddingLeft   = UDim.new(0, 10)
cfgPad.PaddingRight  = UDim.new(0, 10)
cfgPad.Parent        = cfgScroll

local cfgBoxes = {}

local function makeCfgRow(label, key)
    local container                  = Instance.new("Frame")
    container.Size                   = UDim2.new(1, 0, 0, 50)
    container.BackgroundTransparency = 1
    container.Parent                 = cfgScroll

    local lbl                  = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 0, 16)
    lbl.Position               = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = C.subtext
    lbl.TextSize               = 11
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.Text                   = label
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 11
    lbl.Parent                 = container

    local box            = Instance.new("TextBox")
    box.Size             = UDim2.new(1, 0, 0, 30)
    box.Position         = UDim2.new(0, 0, 0, 20)
    box.BackgroundColor3 = C.input
    box.TextColor3       = C.text
    box.TextSize         = 12
    box.Font             = Enum.Font.GothamBold
    box.Text             = tostring(config[key])
    box.ClearTextOnFocus = false
    box.BorderSizePixel  = 0
    box.ZIndex           = 11
    box.Parent           = container
    corner(box, 6); stroke(box, C.accent, 1)

    table.insert(cfgBoxes, { key = key, box = box })
    return box
end

local function makeCfgBtn(text, bgColor)
    local b            = Instance.new("TextButton")
    b.Size             = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = bgColor or C.btnDark
    b.TextColor3       = C.text
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamSemibold
    b.Text             = text
    b.BorderSizePixel  = 0
    b.ZIndex           = 11
    b.Parent           = cfgScroll
    corner(b, 7)
    return b
end

local cfgTitle                  = Instance.new("TextLabel")
cfgTitle.Size                   = UDim2.new(1, 0, 0, 30)
cfgTitle.BackgroundTransparency = 1
cfgTitle.TextColor3             = C.accent
cfgTitle.TextSize               = 14
cfgTitle.Font                   = Enum.Font.GothamBold
cfgTitle.Text                   = "Chinh sua Config"
cfgTitle.ZIndex                 = 11
cfgTitle.Parent                 = cfgScroll

makeCfgRow("Nguong FPS de nhay Server:",           "fpsThreshold")
makeCfgRow("Thoi gian FPS thap lien tuc (s):",     "fpsDuration")
makeCfgRow("Thoi gian cho sau khi load game (s):", "gracePeriod")
makeCfgRow("Dem nguoc truoc khi bat dau Hop (s):", "teleportDelay")
makeCfgRow("So lan Spam Hop toi da:",              "spamMaxHops")
makeCfgRow("Delay giua moi lan Spam Hop (s):",     "spamHopDelay")

local saveCfgBtn  = makeCfgBtn("  Luu Config",          C.green)
local backCfgBtn  = makeCfgBtn("  Quay lai",            C.btnDark)
local resetCfgBtn = makeCfgBtn("  Khoi phuc Mac dinh",  C.red)

local function openConfig()
    for _, entry in ipairs(cfgBoxes) do
        entry.box.Text = tostring(config[entry.key])
    end
    cfgPanel.Visible    = true
    scrollFrame.Visible = false
    configOpen          = true
end

local function closeConfig()
    cfgPanel.Visible    = false
    scrollFrame.Visible = true
    configOpen          = false
end

openCfgBtn.MouseButton1Click:Connect(openConfig)
backCfgBtn.MouseButton1Click:Connect(closeConfig)

saveCfgBtn.MouseButton1Click:Connect(function()
    local dirty = false
    for _, entry in ipairs(cfgBoxes) do
        local n = tonumber(entry.box.Text)
        if n and n > 0 then
            config[entry.key] = n
            dirty = true
        else
            entry.box.Text = tostring(config[entry.key])
        end
    end
    if dirty then
        saveConfig()
        sendNotify("Config da duoc luu thanh cong!")
    end
end)

resetCfgBtn.MouseButton1Click:Connect(function()
    for k, v in pairs(DEFAULT_CONFIG) do config[k] = v end
    for _, entry in ipairs(cfgBoxes) do
        entry.box.Text = tostring(config[entry.key])
    end
    saveConfig()
    sendNotify("Da reset Config ve mac dinh!")
end)

-- ============================================================
-- DRAGGABLE
-- ============================================================
local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = inp.Position
        startPos  = menuFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - dragStart
        menuFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- MO / DONG MENU
-- ============================================================
toggleBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    menuFrame.Visible = menuOpen
    if not menuOpen then closeConfig() end
end)

-- ============================================================
-- NOTIFY
-- ============================================================
local function sendNotify(msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = "Server Tools",
            Text     = msg,
            Duration = dur or 3,
        })
    end)
end

-- ============================================================
-- LAY DANH SACH SERVER HOP LE
-- isLowPlayer = true  : 
-- isLowPlayer = false : 
-- ============================================================
local function fetchValidServers(isLowPlayer)

    local ok, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/"
            .. game.PlaceId
            .. "/servers/Public?limit=100&"
        if isLowPlayer then url = url .. "sortOrder=Asc"
        end
        print(url)
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not result or not result.data then return nil end

    local valid = {}
    for _, s in ipairs(result.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            table.insert(valid, s)
        end
    end
    if #valid == 0 then return {} end

    return valid
end

-- ============================================================
-- SPAM HOP  (dung chung cho ca random lan low-player)
--
-- isLowPlayer = false : chon server ngau nhien
-- isLowPlayer = true  : chon server it player nhat
--
-- Flow:
--   1. Dem nguoc teleportDelay (co nut huy)
--   2. Vong lap spamMaxHops lan:
--        fetch -> chon server -> teleport -> dem nguoc spamHopDelay
-- ============================================================
local function spamHop(triggerBtn, origText, origColor, isLowPlayer)
    if isHopping then return end
    isHopping     = true
    cancelHopping = false

    local maxHops = config.spamMaxHops
    local label   = isLowPlayer and "Low-Player Hop" or "Spam Hop"

    -- buoc 1: dem nguoc teleportDelay truoc khi bat dau
    sendNotify(label .. " bat dau sau " .. config.teleportDelay .. "s!", config.teleportDelay + 1)

    for i = config.teleportDelay, 1, -1 do
        if cancelHopping then
            isHopping                   = false
            triggerBtn.Text             = origText
            triggerBtn.BackgroundColor3 = origColor
            sendNotify("Da huy " .. label .. "!")
            return
        end
        triggerBtn.Text             = "  Huy (" .. i .. "s)"
        triggerBtn.BackgroundColor3 = C.red
        task.wait(1)
    end

    -- buoc 2: vong lap spam
    local count = 0

    task.spawn(function()
        local count = 0
        while isHopping and not cancelHopping and count < maxHops do

            -- lay server
            triggerBtn.Text             = "  " .. label .. " (" .. count .. "/" .. maxHops .. ") | Tim..."
            triggerBtn.BackgroundColor3 = C.orange

            local servers = fetchValidServers(isLowPlayer)

            if count > 5 then cancelHopping = true end

            if cancelHopping then break end

            if not servers then
                sendNotify("Loi lay server, thu lai...")
                count = count + 1
                task.wait(2)
            elseif #servers == 0 then
                count = count + 1
                sendNotify("Khong tim duoc server trong, thu lai...")
                task.wait(2)
            else
                -- low player -> lay phan tu dau (it player nhat)
                -- random    -> chon ngau nhien
                local chosen = servers[math.random(1, #servers)].id

                local ok = pcall(teleportByJobId, chosen)
                if ok then
                    count = count + 1
                    sendNotify(label .. " " .. count .. "/" .. maxHops .. " thanh cong!")
                end

                if cancelHopping or count >= maxHops then break end

                -- dem nguoc spamHopDelay giua cac lan hop
                for i = config.spamHopDelay, 1, -1 do
                    if cancelHopping then break end
                    triggerBtn.Text             = "  " .. label .. " (" .. count .. "/" .. maxHops .. ") | " .. i .. "s"
                    triggerBtn.BackgroundColor3 = C.orange
                    task.wait(1)
                end
            end
        end

        -- reset
        isHopping     = false
        cancelHopping = false

        if count >= maxHops then
            sendNotify(label .. " hoan tat! " .. count .. "/" .. maxHops .. " lan.")
        else
            sendNotify("Da dung " .. label .. "!")
        end
        triggerBtn.Text             = origText
        triggerBtn.BackgroundColor3 = origColor
    end)
end

-- ============================================================
-- SU KIEN NUT
-- ============================================================
spamHopBtn.MouseButton1Click:Connect(function()
    if isHopping then
        cancelHopping = true
    else
        spamHop(spamHopBtn, SPAM_ORIG_TEXT, C.btnDark, false)
    end
end)

spamLowBtn.MouseButton1Click:Connect(function()
    if isHopping then
        cancelHopping = true
    else
        spamHop(spamLowBtn, SPAM_LOW_ORIG_TEXT, C.purple, true)
    end
end)

joinJobBtn.MouseButton1Click:Connect(function()
    if isHopping then
        cancelHopping = true
        return
    end
    local id = jobIdBox.Text:match("^%s*(.-)%s*$")
    if #id < 10 then
        sendNotify("Job ID qua ngan hoac khong hop le!")
        return
    end
    isHopping     = true
    cancelHopping = false

    sendNotify("Join Job ID sau " .. config.teleportDelay .. "s!", config.teleportDelay + 1)
    for i = config.teleportDelay, 1, -1 do
        if cancelHopping then
            isHopping                   = false
            joinJobBtn.Text             = "  Join theo Job ID"
            joinJobBtn.BackgroundColor3 = C.accent
            sendNotify("Da huy Join Job ID!")
            return
        end
        joinJobBtn.Text             = "  Huy (" .. i .. "s)"
        joinJobBtn.BackgroundColor3 = C.red
        task.wait(1)
    end

    joinJobBtn.Text             = "  Dang ket noi..."
    joinJobBtn.BackgroundColor3 = C.orange

    task.spawn(function()
        local attempts = 0
        while isHopping and not cancelHopping and attempts < 3 do
            attempts = attempts + 1
            local ok = pcall(teleportByJobId, id)
            if ok then break end
            warn("[ServerTools] Thu lai lan " .. attempts)
            task.wait(3)
        end
        task.wait(2)
        isHopping                   = false
        joinJobBtn.Text             = "  Join theo Job ID"
        joinJobBtn.BackgroundColor3 = C.accent
    end)
end)

copyJobBtn.MouseButton1Click:Connect(function()
    setclipboard(getJobId())
end)

autoHopBtn.MouseButton1Click:Connect(function()
    config.autoHopEnabled = not config.autoHopEnabled
    saveConfig()
    refreshAutoBtn()
    sendNotify("Auto FPS Hop: " .. (config.autoHopEnabled and "BAT" or "TAT"))
end)

-- ============================================================
-- VONG LAP FPS + AUTO HOP
-- Auto hop khong co dem nguoc, nhay thang khi FPS thap
-- ============================================================
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
end)

task.spawn(function()
    while task.wait(1) do
        local now = tick()
        local fps = frameCount / math.max(now - lastUpdate, 0.001)
        frameCount = 0
        lastUpdate = now

        fpsDisplay.Text = "FPS: " .. math.floor(fps)

        if fps < config.fpsThreshold then
            fpsDisplay.TextColor3 = C.red
            lowFpsTimer           = lowFpsTimer + 1
            local elapsed         = os.clock() - scriptStartTime
            if config.autoHopEnabled
                and not isHopping
                and lowFpsTimer >= config.fpsDuration
                and elapsed >= config.gracePeriod then
                lowFpsTimer = 0
                isHopping   = true
                task.spawn(function()
                    local servers = fetchValidServers(true)
                    if servers and #servers > 0 then
                        local chosen = servers[math.random(1, #servers)].id
                        pcall(teleportByJobId, chosen)
                        sendNotify("Auto Hop: Da doi server do FPS thap!")
                    else
                        sendNotify("Auto Hop: Khong tim duoc server trong!")
                    end
                    task.wait(2)
                    isHopping = false
                end)
            end
        else
            fpsDisplay.TextColor3 = C.green
            lowFpsTimer           = 0
        end
    end
end)
