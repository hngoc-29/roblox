local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

-- --- CẤU HÌNH ---
local FPS_THRESHOLD = 10
local CHECK_INTERVAL = 5 
local GRACE_PERIOD = 60 -- Thời gian chờ 60 giây (1 phút) đầu tiên
local isHopping = false -- Biến kiểm tra để chống spam đổi server liên tục
local scriptStartTime = os.clock() -- Lưu lại thời điểm bắt đầu chạy script

-- --- TẠO GIAO DIỆN HIỂN THỊ ---
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FPS_Server_Tools"
local parent = CoreGui 
screenGui.Parent = parent

-- Nhãn FPS
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

-- Nút đổi Server
local hopButton = Instance.new("TextButton")
hopButton.Size = UDim2.new(0, 100, 0, 30)
hopButton.Position = UDim2.new(0, 10, 0, 45)
hopButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
hopButton.TextColor3 = Color3.new(1, 1, 1)
hopButton.TextSize = 14
hopButton.Font = Enum.Font.SourceSansBold
hopButton.Text = "Đổi Server"
hopButton.Parent = screenGui

-- Bo góc
local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 6)
corner1.Parent = fpsLabel
local corner2 = corner1:Clone()
corner2.Parent = hopButton

-- --- HÀM LẤY SERVER NGẪU NHIÊN ---
local function teleportToRandomServer(reasonMessage)
    if isHopping then return end
    isHopping = true

    -- Gửi thông báo cho người chơi
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Hệ thống Server",
            Text = reasonMessage,
            Duration = 2
        })
    end)

    -- Chờ 2 giây trước khi thực hiện
    task.wait(2)

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
            ReplicatedStorage.__ServerBrowser:InvokeServer("teleport", randomId)
        else
            isHopping = false -- Reset nếu không tìm thấy server
        end
    else
        isHopping = false -- Reset nếu lỗi HTTP
    end
end

-- --- XỬ LÝ NÚT BẤM ---
hopButton.MouseButton1Click:Connect(function()
    if not isHopping then
        hopButton.Text = "Đang chờ 2s..."
        teleportToRandomServer("Yêu cầu thủ công. Sẽ đổi server sau 2 giây!")
        task.wait(2)
        hopButton.Text = "Đổi Server"
    end
end)

-- --- VÒNG LẶP CẬP NHẬT FPS ---
local frameCount = 0
local lastUpdate = tick()

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    
    if now - lastUpdate >= 1 then
        local currentFps = frameCount
        fpsLabel.Text = "FPS: " .. currentFps
        
        if currentFps < FPS_THRESHOLD then
            fpsLabel.TextColor3 = Color3.new(1, 0, 0)
        else
            fpsLabel.TextColor3 = Color3.new(0, 1, 0)
        end
        
        frameCount = 0
        lastUpdate = now
    end
end)

-- --- TỰ ĐỘNG KIỂM TRA FPS ---
task.spawn(function()
    while task.wait(CHECK_INTERVAL) do
        local fps = math.floor(1 / RunService.RenderStepped:Wait())
        if fps < FPS_THRESHOLD and not isHopping then
            -- Tính số giây đã trôi qua kể từ khi chạy script
            local timePassed = os.clock() - scriptStartTime
            
            -- Chỉ đổi server nếu đã qua 60 giây đầu tiên
            if timePassed >= GRACE_PERIOD then
                teleportToRandomServer("FPS tụt xuống " .. fps .. ". Tự động đổi server sau 2 giây!")
            end
        end
    end
end)
