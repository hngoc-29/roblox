local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG_FILE = "ServerTools_Config.json"

local DEFAULT_CONFIG = {
    autoHopEnabled = true,
    fpsThreshold    = 5,
    fpsDuration     = 8,
    gracePeriod     = 60,
    teleportDelay   = 5,
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
-- TELEPORT (ưu tiên __ServerBrowser, fallback TeleportService)
-- ============================================================
local function teleportByJobId(jobId)
    local sb = ReplicatedStorage:FindFirstChild("__ServerBrowser")
    if sb then
        -- Cách chính: dùng RemoteFunction của game
        local ok, err = pcall(function()
            sb:InvokeServer("teleport", jobId)
        end)
        if ok then return true end
        warn("[ServerTools] __ServerBrowser thất bại:", err)
    end
    -- Fallback: TeleportService thông thường
    local ok2, err2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId)
    end)
    if not ok2 then
        warn("[ServerTools] TeleportService thất bại:", err2)
        return false, err2
    end
    return true
end

-- ============================================================
-- TRẠNG THÁI
-- ============================================================
local isHopping    = false
local cancelHopping = false
local scriptStartTime = os.clock()
local lowFpsTimer  = 0
local frameCount   = 0
local lastUpdate   = tick()
local menuOpen     = false
local configOpen   = false

-- ============================================================
-- XÂY DỰNG GUI
-- ============================================================
if CoreGui:FindFirstChild("ServerTools_GUI") then
    CoreGui:FindFirstChild("ServerTools_GUI"):Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "ServerTools_GUI"
screenGui.ResetOnSpawn  = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

-- ── Màu palette ──────────────────────────────────────────────
local C = {
    bg      = Color3.fromRGB(13, 13, 22),
    panel   = Color3.fromRGB(20, 20, 35),
    accent  = Color3.fromRGB(0, 180, 255),
    green   = Color3.fromRGB(0, 200, 100),
    red     = Color3.fromRGB(210, 50, 50),
    text    = Color3.new(1, 1, 1),
    subtext = Color3.fromRGB(150, 150, 180),
    input   = Color3.fromRGB(28, 28, 46),
    btnDark = Color3.fromRGB(30, 30, 52),
}

-- ── Helper tạo UICorner ───────────────────────────────────────
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or C.accent
    s.Thickness = thick or 1
    s.Transparency = 0.5
    s.Parent = parent
    return s
end

-- ── Nút toggle nhỏ (luôn thấy) ───────────────────────────────
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size     = UDim2.new(0, 120, 0, 30)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.BackgroundColor3 = C.bg
toggleBtn.TextColor3       = C.accent
toggleBtn.TextSize         = 13
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.Text             = "☰  Server Tools"
toggleBtn.BorderSizePixel  = 0
toggleBtn.Parent = screenGui
corner(toggleBtn, 8) ; stroke(toggleBtn, C.accent, 1)

local fpsDisplay = Instance.new("TextLabel")
fpsDisplay.Size     = UDim2.new(0, 120, 0, 22)
fpsDisplay.Position = UDim2.new(0, 10, 0, 44)
fpsDisplay.BackgroundColor3  = C.bg
fpsDisplay.BackgroundTransparency = 0.2
fpsDisplay.TextColor3        = C.green
fpsDisplay.TextSize          = 12
fpsDisplay.Font              = Enum.Font.GothamBold
fpsDisplay.Text              = "FPS: ..."
fpsDisplay.BorderSizePixel   = 0
fpsDisplay.Parent = screenGui
corner(fpsDisplay, 6)

-- ============================================================
-- MENU CHÍNH
-- ============================================================
local menuFrame = Instance.new("Frame")
menuFrame.Name    = "Menu"
menuFrame.Size    = UDim2.new(0, 270, 0, 0) -- sẽ resize sau
menuFrame.Position = UDim2.new(0, 10, 0, 72)
menuFrame.BackgroundColor3 = C.bg
menuFrame.BorderSizePixel  = 0
menuFrame.Visible = false
menuFrame.ClipsDescendants = true
menuFrame.Parent = screenGui
corner(menuFrame, 10) ; stroke(menuFrame, C.accent, 1.2)

-- Thanh tiêu đề (kéo được)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = C.accent
titleBar.BorderSizePixel  = 0
titleBar.Parent = menuFrame
corner(titleBar, 10)

-- Che góc dưới của titleBar (để không bo dưới)
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 10)
titleFix.Position = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = C.accent
titleFix.BorderSizePixel  = 0
titleFix.Parent = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size   = UDim2.new(1, -10, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = C.text
titleLbl.TextSize   = 13
titleLbl.Font       = Enum.Font.GothamBold
titleLbl.Text       = "⚙  Server Tools"
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

-- Scroll container nội dung
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -34)
scrollFrame.Position = UDim2.new(0, 0, 0, 34)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 3
scrollFrame.ScrollBarImageColor3 = C.accent
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = menuFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = scrollFrame

local listPad = Instance.new("UIPadding")
listPad.PaddingTop    = UDim.new(0, 8)
listPad.PaddingBottom = UDim.new(0, 8)
listPad.PaddingLeft   = UDim.new(0, 10)
listPad.PaddingRight  = UDim.new(0, 10)
listPad.Parent = scrollFrame

-- ── Helper tạo widget trong menu ─────────────────────────────
local function makeBtn(text, bgColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = bgColor or C.btnDark
    b.TextColor3 = C.text
    b.TextSize   = 13
    b.Font       = Enum.Font.GothamSemibold
    b.Text       = text
    b.BorderSizePixel = 0
    b.Parent = scrollFrame
    corner(b, 7)
    return b
end

local function makeLabel(text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.TextColor3 = C.subtext
    l.TextSize   = 11
    l.Font       = Enum.Font.Gotham
    l.Text       = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = scrollFrame
    return l
end

local function makeTextBox(placeholder)
    local b = Instance.new("TextBox")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = C.input
    b.TextColor3 = C.text
    b.PlaceholderText  = placeholder or ""
    b.PlaceholderColor3 = C.subtext
    b.TextSize = 12
    b.Font = Enum.Font.Gotham
    b.ClearTextOnFocus = false
    b.BorderSizePixel = 0
    b.Parent = scrollFrame
    corner(b, 6) ; stroke(b, C.accent, 1)
    return b
end

-- ── Phần Join Job ID ─────────────────────────────────────────
makeLabel("  Job ID để join trực tiếp:")
local jobIdBox   = makeTextBox("Paste Job ID vào đây...")
local joinJobBtn = makeBtn("  ▶  Join theo Job ID", C.accent)

-- ── Separator ────────────────────────────────────────────────
local sep1 = Instance.new("Frame")
sep1.Size = UDim2.new(1, 0, 0, 1)
sep1.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
sep1.BorderSizePixel  = 0
sep1.Parent = scrollFrame

-- ── Đổi server ngẫu nhiên ────────────────────────────────────
local hopBtn = makeBtn("  🔄  Đổi Server Ngẫu Nhiên", C.btnDark)

-- ── Toggle auto hop ───────────────────────────────────────────
local autoHopBtn = makeBtn("", C.green)
local function refreshAutoBtn()
    if config.autoHopEnabled then
        autoHopBtn.BackgroundColor3 = C.green
        autoHopBtn.Text = "  ✅  Auto FPS Hop: BẬT"
    else
        autoHopBtn.BackgroundColor3 = C.red
        autoHopBtn.Text = "  ❌  Auto FPS Hop: TẮT"
    end
end
refreshAutoBtn()

-- ── Separator ────────────────────────────────────────────────
local sep2 = Instance.new("Frame")
sep2.Size = UDim2.new(1, 0, 0, 1)
sep2.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
sep2.BorderSizePixel  = 0
sep2.Parent = scrollFrame

-- ── Nút mở config editor ─────────────────────────────────────
local openCfgBtn = makeBtn("  ⚙  Chỉnh Config...", C.btnDark)

-- ── Resize menu theo nội dung ─────────────────────────────────
local function resizeMenu()
    local h = listLayout.AbsoluteContentSize.Y + 34 + 16
    menuFrame.Size = UDim2.new(0, 270, 0, math.min(h, 480))
end
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeMenu)

-- ============================================================
-- PANEL CONFIG (xuất hiện bên trong / thay thế nội dung)
-- ============================================================
local cfgPanel = Instance.new("Frame")
cfgPanel.Name    = "ConfigPanel"
cfgPanel.Size    = UDim2.new(1, 0, 1, -34)
cfgPanel.Position = UDim2.new(0, 0, 0, 34)
cfgPanel.BackgroundColor3 = C.bg
cfgPanel.BorderSizePixel  = 0
cfgPanel.Visible = false
cfgPanel.ClipsDescendants = true
cfgPanel.ZIndex = 10
cfgPanel.Parent = menuFrame

local cfgScroll = Instance.new("ScrollingFrame")
cfgScroll.Size = UDim2.new(1, 0, 1, 0)
cfgScroll.BackgroundTransparency = 1
cfgScroll.BorderSizePixel = 0
cfgScroll.ScrollBarThickness = 3
cfgScroll.ScrollBarImageColor3 = C.accent
cfgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
cfgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
cfgScroll.Parent = cfgPanel

local cfgList = Instance.new("UIListLayout")
cfgList.Padding = UDim.new(0, 6)
cfgList.HorizontalAlignment = Enum.HorizontalAlignment.Center
cfgList.Parent = cfgScroll

local cfgPad = Instance.new("UIPadding")
cfgPad.PaddingTop    = UDim.new(0, 8)
cfgPad.PaddingBottom = UDim.new(0, 8)
cfgPad.PaddingLeft   = UDim.new(0, 10)
cfgPad.PaddingRight  = UDim.new(0, 10)
cfgPad.Parent = cfgScroll

-- Helper tạo hàng label + input trong config panel
local cfgBoxes = {} -- { key, box }

local function makeCfgRow(label, key)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = C.subtext
    lbl.TextSize   = 11
    lbl.Font       = Enum.Font.Gotham
    lbl.Text       = label
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 11
    lbl.Parent = cfgScroll

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 30)
    box.BackgroundColor3 = C.input
    box.TextColor3 = C.text
    box.TextSize = 12
    box.Font = Enum.Font.GothamBold
    box.Text = tostring(config[key])
    box.ClearTextOnFocus = false
    box.BorderSizePixel  = 0
    box.ZIndex = 11
    box.Parent = cfgScroll
    corner(box, 6) ; stroke(box, C.accent, 1)

    table.insert(cfgBoxes, { key = key, box = box })
    return box
end

local function makeCfgBtn(text, bgColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = bgColor or C.btnDark
    b.TextColor3 = C.text
    b.TextSize   = 13
    b.Font       = Enum.Font.GothamSemibold
    b.Text       = text
    b.BorderSizePixel = 0
    b.ZIndex = 11
    b.Parent = cfgScroll
    corner(b, 7)
    return b
end

-- Tiêu đề panel config
local cfgTitle = Instance.new("TextLabel")
cfgTitle.Size = UDim2.new(1, 0, 0, 22)
cfgTitle.BackgroundTransparency = 1
cfgTitle.TextColor3 = C.accent
cfgTitle.TextSize   = 13
cfgTitle.Font       = Enum.Font.GothamBold
cfgTitle.Text       = "⚙  Chỉnh sửa Config"
cfgTitle.ZIndex = 11
cfgTitle.Parent = cfgScroll

makeCfgRow("FPS Threshold (tự động đổi khi FPS < ?):", "fpsThreshold")
makeCfgRow("FPS Duration (giây FPS thấp liên tục):", "fpsDuration")
makeCfgRow("Grace Period (giây chờ sau khi load):",  "gracePeriod")
makeCfgRow("Teleport Delay (giây đếm ngược):",       "teleportDelay")

local saveCfgBtn  = makeCfgBtn("  💾  Lưu Config", C.green)
local backCfgBtn  = makeCfgBtn("  ←  Quay lại",    C.btnDark)
local resetCfgBtn = makeCfgBtn("  🔄  Reset về mặc định", C.red)

-- ── Mở/đóng config panel ─────────────────────────────────────
local function openConfig()
    -- Sync giá trị hiện tại vào box
    for _, entry in ipairs(cfgBoxes) do
        entry.box.Text = tostring(config[entry.key])
    end
    cfgPanel.Visible = true
    scrollFrame.Visible = false
    configOpen = true
end

local function closeConfig()
    cfgPanel.Visible = false
    scrollFrame.Visible = true
    configOpen = false
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
            entry.box.Text = tostring(config[entry.key]) -- revert
        end
    end
    if dirty then
        saveConfig()
        sendNotify("Config đã được lưu!")
    end
end)

resetCfgBtn.MouseButton1Click:Connect(function()
    for k, v in pairs(DEFAULT_CONFIG) do config[k] = v end
    for _, entry in ipairs(cfgBoxes) do
        entry.box.Text = tostring(config[entry.key])
    end
    saveConfig()
    sendNotify("Config đã reset về mặc định!")
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
-- MỞ / ĐÓNG MENU
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
            Title = "Server Tools",
            Text  = msg,
            Duration = dur or 3,
        })
    end)
end

-- ============================================================
-- TELEPORT VỚI ĐẾM NGƯỢC + HỦY
-- ============================================================
local function teleportWithCountdown(jobId, reason)
    if isHopping then return end
    isHopping    = true
    cancelHopping = false

    sendNotify(reason, config.teleportDelay + 1)

    for i = config.teleportDelay, 1, -1 do
        if cancelHopping then
            isHopping = false
            hopBtn.Text = "  🔄  Đổi Server Ngẫu Nhiên"
            hopBtn.BackgroundColor3 = C.btnDark
            sendNotify("Đã hủy!")
            return
        end
        hopBtn.Text = "  ⏳  Hủy (" .. i .. "s)"
        hopBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        task.wait(1)
    end

    hopBtn.Text = "  ⏳  Đang teleport..."
    local ok, err = teleportByJobId(jobId)
    if not ok then
        sendNotify("Lỗi teleport: " .. tostring(err):sub(1,60))
        isHopping = false
        hopBtn.Text = "  🔄  Đổi Server Ngẫu Nhiên"
        hopBtn.BackgroundColor3 = C.btnDark
    end
    -- Nếu ok thì game sẽ load sang server mới, không cần reset
end

-- ============================================================
-- ĐỔI SERVER NGẪU NHIÊN
-- ============================================================
local function hopRandom(autoReason)
    local reason = autoReason or ("Đổi server sau " .. config.teleportDelay .. "s!")
    local ok, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/"
                    .. game.PlaceId
                    .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not result or not result.data then
        sendNotify("Lỗi lấy danh sách server!")
        return
    end
    local valid = {}
    for _, s in ipairs(result.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            table.insert(valid, s.id)
        end
    end
    if #valid == 0 then
        sendNotify("Không tìm được server trống!")
        return
    end
    local chosen = valid[math.random(1, #valid)]
    teleportWithCountdown(chosen, reason)
end

-- ============================================================
-- SỰ KIỆN NÚT
-- ============================================================
hopBtn.MouseButton1Click:Connect(function()
    if isHopping then cancelHopping = true
    else hopRandom() end
end)

joinJobBtn.MouseButton1Click:Connect(function()
    local id = jobIdBox.Text:match("^%s*(.-)%s*$")
    if #id < 10 then
        sendNotify("Job ID quá ngắn / không hợp lệ!")
        return
    end
    teleportWithCountdown(id, "Join Job ID sau " .. config.teleportDelay .. "s!")
end)

autoHopBtn.MouseButton1Click:Connect(function()
    config.autoHopEnabled = not config.autoHopEnabled
    saveConfig()
    refreshAutoBtn()
    sendNotify("Auto FPS Hop: " .. (config.autoHopEnabled and "BẬT" or "TẮT"))
end)

-- ============================================================
-- VÒNG LẶP FPS + AUTO HOP
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
            lowFpsTimer = lowFpsTimer + 1
            local elapsed = os.clock() - scriptStartTime
            if config.autoHopEnabled
               and not isHopping
               and lowFpsTimer >= config.fpsDuration
               and elapsed >= config.gracePeriod then
                lowFpsTimer = 0
                hopRandom("FPS thấp " .. config.fpsDuration .. "s liên tục! Tự động đổi server...")
            end
        else
            fpsDisplay.TextColor3 = C.green
            lowFpsTimer = 0
        end
    end
end)