local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

-- --- CẤU HÌNH ---
local FPS_THRESHOLD = 5
local CHECK_INTERVAL = 1 -- Kiểm tra mỗi giây để chính xác hơn
local FPS_LOW_DURATION = 8 -- Thời gian FPS phải thấp liên tục (8 giây)
local GRACE_PERIOD = 60 
local TELEPORT_DELAY = 5 
local isHopping = false 
local cancelHopping = false 
local scriptStartTime = os.clock() 

-- Biến theo dõi thời gian FPS thấp
local lowFpsTimer = 0 

-- --- TẠO GIAO DIỆN HIỂN THỊ ---
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FPS_Server_Tools"
screenGui.Parent = CoreGui 

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 100, 0, 30)
fpsLabel.Position = UDim2.new(0, 10, 0, 10)
fpsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.TextColor3 = Color3.new(0, 1, 0)
fpsLabel.TextSize = 18
fpsLabel.Font = Enum.Font.SourceSansBold
fpsLabel.Text = "FPS: ..."
fpsLabel.Parent = screenGui

local hopButton = Instance.new("TextButton")
hopButton.Size = UDim2.new(0, 100, 0, 30)
hopButton.Position = UDim2.new(0, 10, 0, 45)
hopButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
hopButton.TextColor3 = Color3.new(1, 1, 1)
hopButton.TextSize = 14
hopButton.Font = Enum.Font.SourceSansBold
hopButton.Text = "Đổi Server"
hopButton.Parent = screenGui

local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 6)
corner1.Parent = fpsLabel
local corner2 = corner1:Clone()
corner2.Parent = hopButton

-- --- HÀM THÔNG BÁO ---
local function sendNotify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Hệ thống Server",
            Text = msg,
            Duration = 3
        })
    end)
end

-- --- HÀM LẤY SERVER ---
local function teleportToRandomServer(reasonMessage)
    if isHopping then return end
    isHopping = true
    cancelHopping = false

    sendNotify(reasonMessage)

    for i = TELEPORT_DELAY, 1, -1 do
        if cancelHopping then
            isHopping = false
            hopButton.Text = "Đổi Server"
            hopButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
            sendNotify("Đã hủy đổi server!")
            return
        end
        hopButton.Text = "Hủy (" .. i .. "s)"
        hopButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
        task.wait(1)
    end

    hopButton.Text = "Đang đổi..."
    
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if success and result and result.data then
        local validServers = {}
        for _, s in ipairs(result.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(validServers, s.id)
            end
        end
        
        if #validServers > 0 then
            local randomId = validServers[math.random(1, #validServers)]
            local teleportService = ReplicatedStorage:FindFirstChild("__ServerBrowser")
            if teleportService then
                teleportService:InvokeServer("teleport", randomId)
            else
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, randomId)
            end
        else
            isHopping = false
            hopButton.Text = "Đổi Server"
            hopButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        end
    else
        isHopping = false
        hopButton.Text = "Đổi Server"
        hopButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    end
end

hopButton.MouseButton1Click:Connect(function()
    if isHopping then
        cancelHopping = true 
    else
        teleportToRandomServer("Sẽ đổi server sau 5 giây!")
    end
end)

-- --- CẬP NHẬT FPS VÀ KIỂM TRA ĐIỀU KIỆN 8 GIÂY ---
local frameCount = 0
local lastUpdate = tick()

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
end)

task.spawn(function()
    while task.wait(CHECK_INTERVAL) do
        local now = tick()
        local currentFps = frameCount / (now - lastUpdate)
        
        fpsLabel.Text = "FPS: " .. math.floor(currentFps)
        frameCount = 0
        lastUpdate = now

        local timePassed = os.clock() - scriptStartTime

        if currentFps < FPS_THRESHOLD then
            fpsLabel.TextColor3 = Color3.new(1, 0, 0)
            -- Nếu FPS thấp, tăng biến đếm thời gian
            lowFpsTimer = lowFpsTimer + CHECK_INTERVAL
            
            -- Nếu FPS thấp liên tục >= 8 giây và không đang trong quá trình đổi
            if lowFpsTimer >= FPS_LOW_DURATION and not isHopping and timePassed >= GRACE_PERIOD then
                teleportToRandomServer("FPS thấp liên tục 8s. Tự động đổi!")
                lowFpsTimer = 0 -- Reset sau khi kích hoạt
            end
        else
            fpsLabel.TextColor3 = Color3.new(0, 1, 0)
            lowFpsTimer = 0 -- Nếu FPS ổn định lại, reset biến đếm ngay lập tức
        end
    end
end)
