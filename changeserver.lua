local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- CẤU HÌNH MẶC ĐỊNH
-- ============================================================
local CONFIG_FILE = "ServerTools_Config.json"

local DEFAULT_CONFIG = {
    autoHopEnabled = true,
    fpsThreshold = 5,
    fpsDuration = 8,
    gracePeriod = 60,
    teleportDelay = 5,
}

-- ============================================================
-- ĐỌC / GHI CONFIG FILE
-- ============================================================
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
        -- Merge với default để không bị thiếu key
        for k, v in pairs(DEFAULT_CONFIG) do
            config[k] = (data[k] ~= nil) and data[k] or v
        end
    else
        for k, v in pairs(DEFAULT_CONFIG) do
            config[k] = v
        end
    end
end

loadConfig()

-- ============================================================
-- BIẾN TRẠNG THÁI
-- ============================================================
local isHopping = false
local cancelHopping = false
local scriptStartTime = os.clock()
local lowFpsTimer = 0
local frameCount = 0
local lastUpdate = tick()
local menuOpen = false

-- ============================================================
-- XÂY DỰNG GUI
-- ============================================================
-- Xoá GUI cũ nếu chạy lại
if CoreGui:FindFirstChild("ServerTools_GUI") then
    CoreGui:FindFirstChild("ServerTools_GUI"):Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ServerTools_GUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

-- ── Nút mở/đóng menu (luôn hiển thị) ──────────────────────
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 110, 0, 32)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
toggleBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Text = "☰  Server Tools"
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local fpsDisplay = Instance.new("TextLabel")
fpsDisplay.Size = UDim2.new(0, 110, 0, 24)
fpsDisplay.Position = UDim2.new(0, 10, 0, 46)
fpsDisplay.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
fpsDisplay.BackgroundTransparency = 0.3
fpsDisplay.TextColor3 = Color3.fromRGB(0, 255, 120)
fpsDisplay.TextSize = 13
fpsDisplay.Font = Enum.Font.GothamBold
fpsDisplay.Text = "FPS: ..."
fpsDisplay.BorderSizePixel = 0
fpsDisplay.Parent = screenGui
Instance.new("UICorner", fpsDisplay).CornerRadius = UDim.new(0, 6)

-- ── Khung menu chính (draggable) ───────────────────────────
local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.new(0, 260, 0, 310)
menuFrame.Position = UDim2.new(0, 10, 0, 76)
menuFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
menuFrame.BorderSizePixel = 0
menuFrame.Visible = false
menuFrame.Parent = screenGui
Instance.new("UICorner", menuFrame).CornerRadius = UDim.new(0, 10)

-- Viền sáng
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 180, 255)
stroke.Thickness = 1.2
stroke.Transparency = 0.5
stroke.Parent = menuFrame

-- Thanh tiêu đề (dùng để kéo)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 130, 200)
titleBar.BorderSizePixel = 0
titleBar.Parent = menuFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -10, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "⚙  Server Tools"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- ── Hàm tạo nút bên trong menu ─────────────────────────────
local contentY = 46
local function makeButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 36)
    btn.Position = UDim2.new(0, 10, 0, contentY)
    btn.BackgroundColor3 = color or Color3.fromRGB(30, 30, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = text
    btn.BorderSizePixel = 0
    btn.Parent = menuFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    contentY = contentY + 44
    return btn
end

local function makeLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, contentY)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(160, 160, 190)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = menuFrame
    contentY = contentY + 22
    return lbl
end

-- Nhãn "Nhập Job ID"
makeLabel("  Nhập Job ID để join:")

-- TextBox Job ID
local jobIdBox = Instance.new("TextBox")
jobIdBox.Size = UDim2.new(1, -20, 0, 32)
jobIdBox.Position = UDim2.new(0, 10, 0, contentY)
jobIdBox.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
jobIdBox.TextColor3 = Color3.new(1, 1, 1)
jobIdBox.PlaceholderText = "Paste Job ID vào đây..."
jobIdBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 130)
jobIdBox.TextSize = 12
jobIdBox.Font = Enum.Font.Gotham
jobIdBox.ClearTextOnFocus = false
jobIdBox.BorderSizePixel = 0
jobIdBox.Parent = menuFrame
Instance.new("UICorner", jobIdBox).CornerRadius = UDim.new(0, 7)
contentY = contentY + 38

local joinJobBtn  = makeButton("  ▶  Join Job ID",      Color3.fromRGB(0, 140, 200))
local hopBtn      = makeButton("  🔄  Đổi Server Ngẫu Nhiên", Color3.fromRGB(30, 30, 50))

-- Toggle auto-hop
local autoHopBtn = Instance.new("TextButton")
autoHopBtn.Size = UDim2.new(1, -20, 0, 36)
autoHopBtn.Position = UDim2.new(0, 10, 0, contentY)
autoHopBtn.BorderSizePixel = 0
autoHopBtn.TextSize = 13
autoHopBtn.Font = Enum.Font.GothamSemibold
autoHopBtn.TextColor3 = Color3.new(1, 1, 1)
autoHopBtn.Parent = menuFrame
Instance.new("UICorner", autoHopBtn).CornerRadius = UDim.new(0, 7)
contentY = contentY + 44

local function updateAutoHopBtn()
    if config.autoHopEnabled then
        autoHopBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
        autoHopBtn.Text = "  ✅  Auto FPS Hop: BẬT"
    else
        autoHopBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        autoHopBtn.Text = "  ❌  Auto FPS Hop: TẮT"
    end
end
updateAutoHopBtn()

-- Cập nhật size frame cho vừa nội dung
menuFrame.Size = UDim2.new(0, 260, 0, contentY + 10)

-- ============================================================
-- LOGIC MỞ / ĐÓNG MENU
-- ============================================================
toggleBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    menuFrame.Visible = menuOpen
end)

-- ============================================================
-- DRAGGABLE CHO MENU
-- ============================================================
local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = menuFrame.Position
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                     input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        menuFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- HÀM THÔNG BÁO
-- ============================================================
local function sendNotify(msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Server Tools",
            Text = msg,
            Duration = dur or 3,
        })
    end)
end

-- ============================================================
-- HÀM THỰC HIỆN TELEPORT (dùng lại cho cả 2 tính năng)
-- ============================================================
local function doTeleport(jobId)
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, jobId)
end

-- ============================================================
-- HÀM ĐỔI SERVER NGẪU NHIÊN
-- ============================================================
local function teleportToRandomServer(reason)
    if isHopping then return end
    isHopping = true
    cancelHopping = false

    sendNotify(reason, 4)

    for i = config.teleportDelay, 1, -1 do
        if cancelHopping then
            isHopping = false
            hopBtn.Text = "  🔄  Đổi Server Ngẫu Nhiên"
            hopBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
            sendNotify("Đã hủy đổi server!")
            return
        end
        hopBtn.Text = "  ⏳  Hủy (" .. i .. "s)"
        hopBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        task.wait(1)
    end

    hopBtn.Text = "  ⏳  Đang tìm server..."

    local ok, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
                    .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if ok and result and result.data then
        local valid = {}
        for _, s in ipairs(result.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(valid, s.id)
            end
        end
        if #valid > 0 then
            doTeleport(valid[math.random(1, #valid)])
            return
        else
            sendNotify("Không tìm thấy server phù hợp!")
        end
    else
        sendNotify("Lỗi khi lấy danh sách server!")
    end

    isHopping = false
    hopBtn.Text = "  🔄  Đổi Server Ngẫu Nhiên"
    hopBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
end

-- ============================================================
-- SỰ KIỆN CÁC NÚT
-- ============================================================
-- Nút đổi server ngẫu nhiên
hopBtn.MouseButton1Click:Connect(function()
    if isHopping then
        cancelHopping = true
    else
        teleportToRandomServer("Đổi server sau " .. config.teleportDelay .. "s!")
    end
end)

-- Nút join Job ID
joinJobBtn.MouseButton1Click:Connect(function()
    local id = jobIdBox.Text:match("^%s*(.-)%s*$") -- trim whitespace
    if id == "" or #id < 10 then
        sendNotify("Job ID không hợp lệ!")
        return
    end
    sendNotify("Đang join Job ID: " .. id:sub(1, 16) .. "...", 4)
    task.wait(1.5)
    local ok, err = pcall(doTeleport, id)
    if not ok then
        sendNotify("Lỗi: " .. tostring(err):sub(1, 60))
    end
end)

-- Nút toggle auto-hop
autoHopBtn.MouseButton1Click:Connect(function()
    config.autoHopEnabled = not config.autoHopEnabled
    updateAutoHopBtn()
    saveConfig()
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
        local fps = frameCount / (now - lastUpdate)
        frameCount = 0
        lastUpdate = now

        local fpsInt = math.floor(fps)
        fpsDisplay.Text = "FPS: " .. fpsInt

        if fps < config.fpsThreshold then
            fpsDisplay.TextColor3 = Color3.fromRGB(255, 80, 80)
            lowFpsTimer = lowFpsTimer + 1
            local elapsed = os.clock() - scriptStartTime
            if config.autoHopEnabled
               and lowFpsTimer >= config.fpsDuration
               and not isHopping
               and elapsed >= config.gracePeriod then
                lowFpsTimer = 0
                teleportToRandomServer("FPS thấp " .. config.fpsDuration .. "s liên tiếp! Tự động đổi server...")
            end
        else
            fpsDisplay.TextColor3 = Color3.fromRGB(0, 255, 120)
            lowFpsTimer = 0
        end
    end
end)