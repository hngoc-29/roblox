-- ============================================================
-- Roblox Dashboard Reporter v2 — with Kick support
-- ============================================================
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")

-- ⚠️ Set API key BEFORE loading this script:
getgenv().ApiKey = "RBX-YOURKEYHERE"

local BASE_URL        = "https://rb-dashboard-psi.vercel.app"  -- ← đổi thành URL ngrok hoặc Vercel
local REPORT_INTERVAL = 5  -- giây (phải < TTL Redis / 2)
local SEA             = 1  -- 1, 2 hoặc 3

-- ─────────────────────────────────────────────────────────────
-- HTTP helper — tự detect executor
-- ─────────────────────────────────────────────────────────────
local function httpPost(url, body)
    if syn and syn.request then
        syn.request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body })
    elseif http and http.request then
        http.request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body })
    elseif request then
        request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body })
    else
        HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
    end
end

local function httpGet(url)
    if syn and syn.request then
        return syn.request({ Url=url, Method="GET" })
    elseif http and http.request then
        return http.request({ Url=url, Method="GET" })
    elseif request then
        return request({ Url=url, Method="GET" })
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────
-- Report: gửi trạng thái online lên dashboard
-- ─────────────────────────────────────────────────────────────
local function report()
    local player = Players.LocalPlayer
    if not player then return end

    local ok, err = pcall(function()
        httpPost(BASE_URL .. "/api/report", HttpService:JSONEncode({
            apiKey   = getgenv().ApiKey or "",
            username = player.Name,
            sea      = SEA,
            jobId    = game.JobId,
        }))
    end)

    if not ok then
        warn("[Dashboard] Report failed:", err)
    end
end

-- ─────────────────────────────────────────────────────────────
-- Check kick: dashboard có gửi lệnh kick không?
-- ─────────────────────────────────────────────────────────────
local function checkKick()
    local player = Players.LocalPlayer
    if not player then return end

    local ok, res = pcall(function()
        return httpGet(
            BASE_URL .. "/api/check-kick"
            .. "?apiKey="   .. (getgenv().ApiKey or "")
            .. "&username=" .. player.Name
        )
    end)

    if not ok or not res then return end

    -- Parse response body
    local body = res.Body or res.body
    if not body then return end

    local parseOk, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if parseOk and data and data.kick == true then
        local reason = data.reason or "Kicked by admin"
        warn("[Dashboard] Kick received:", reason)
        task.wait(0.5)
        player:Kick(reason)
    end
end

-- ─────────────────────────────────────────────────────────────
-- Validate
-- ─────────────────────────────────────────────────────────────
if not getgenv().ApiKey or getgenv().ApiKey == "" then
    warn("[Dashboard] ⚠️  ApiKey chưa được set!")
    warn("[Dashboard] Dùng: getgenv().ApiKey = 'RBX-...'")
    return
end

-- ─────────────────────────────────────────────────────────────
-- Main loop
-- ─────────────────────────────────────────────────────────────
task.spawn(function()
    report()     -- ping ngay lập tức
    while true do
        task.wait(REPORT_INTERVAL)
        report()
        checkKick()
    end
end)

print("[Dashboard] ✅ Reporter started. Ping every", REPORT_INTERVAL, "s | Kick-check: ON")
