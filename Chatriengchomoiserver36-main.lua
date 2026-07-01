--[[
    CUSTOM PRIVATE CHAT - V5.2 (AUTO NICKNAME & RAINBOW COLORS)
    Tính năng mới:
    - TỰ ĐỘNG chuyển Username thành Biệt danh (Roblox DisplayName) cho TẤT CẢ người chơi.
    - TỰ ĐỘNG phát màu sắc riêng biệt, rực rỡ cho từng người (Bảng 15 màu VIP).
    - Giữ nguyên: Ưu tiên danh bạ riêng, Tự xóa khi treo máy, Khóa theo Server.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local TargetGui = (gethui and gethui()) or game:GetService("CoreGui")

local BASE_ROOM_NAME = "phong_chat_kuro_bacon_2026_"
local CHAT_ROOM_NAME = BASE_ROOM_NAME .. (game.JobId ~= "" and game.JobId or "studio_test")
local API_URL = "https://ntfy.sh/" .. CHAT_ROOM_NAME

local custom_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- ==========================================================
-- ⚙️ CẤU HÌNH THỜI GIAN CHỜ & DANH BẠ BÍ MẬT
-- ==========================================================
local INACTIVITY_TIMEOUT = 300 -- 5 phút không hoạt động tự xóa chatlog.

local DanhBaBiMat = {
    -- [ƯU TIÊN CAO NHẤT]: Biệt danh đặc biệt CHỈ MÌNH BẠN THẤY (Có thể để trống nếu không dùng)
    ["kuro_2230"] = { Nickname = "sun ☀️", Color = "#FFCC00" }, 
    
    -- Tên và màu của chính bạn
    [LocalPlayer.Name]   = { Nickname = "Tôi 👑", Color = "#FFD700" }
}

-- Bảng 15 màu rực rỡ để tự động chia cho mọi người chơi ngẫu nhiên
local BangMauRainbow = {
    "#FF5733", "#33FF57", "#3357FF", "#F333FF", "#33FFF0", 
    "#FFAF33", "#AF33FF", "#33FFAF", "#FF3333", "#33FF33", 
    "#3333FF", "#FFFF33", "#00FF7F", "#FF1493", "#00CED1"
}

-- Hàm tự động tính toán màu cố định cho từng người chơi
local function GetAutoColor(name)
    local hash = 0
    for i = 1, #name do hash = hash + string.byte(name, i) end
    return BangMauRainbow[(hash % #BangMauRainbow) + 1]
end

-- Các biến quản lý thời gian thực
local lastMessageTime = os.time()
local chatCleared = false

-- 1. KHỞI TẠO GIAO DIỆN (UI)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VNG_UniversalPrivateChat"
ScreenGui.Parent = TargetGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 220)
MainFrame.Position = UDim2.new(0, 15, 0, 60)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BackgroundTransparency = 0.5
MainFrame.BorderSizePixel = 0
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local ChatLog = Instance.new("ScrollingFrame")
ChatLog.Size = UDim2.new(1, -10, 1, -45)
ChatLog.Position = UDim2.new(0, 5, 0, 5)
ChatLog.BackgroundTransparency = 1
ChatLog.ScrollBarThickness = 2
ChatLog.CanvasSize = UDim2.new(0, 0, 0, 0)
ChatLog.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.Parent = ChatLog

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
    ChatLog.CanvasPosition = Vector2.new(0, UIListLayout.AbsoluteContentSize.Y)
end)

local InputContainer = Instance.new("Frame")
InputContainer.Size = UDim2.new(1, -10, 0, 30)
InputContainer.Position = UDim2.new(0, 5, 1, -35)
InputContainer.BackgroundTransparency = 1
InputContainer.Parent = MainFrame

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, -40, 1, 0)
TextBox.Position = UDim2.new(0, 0, 0, 0)
TextBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
TextBox.BackgroundTransparency = 0.3
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.PlaceholderText = " Nhập tin nhắn nội bộ server..."
TextBox.Text = ""
TextBox.Font = Enum.Font.SourceSans
TextBox.TextSize = 15
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.ClearTextOnFocus = false
TextBox.Parent = InputContainer

local SendButton = Instance.new("TextButton")
SendButton.Size = UDim2.new(0, 35, 1, 0)
SendButton.Position = UDim2.new(1, -35, 0, 0)
SendButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
SendButton.BackgroundTransparency = 0.3
SendButton.Text = "✅"
SendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SendButton.Font = Enum.Font.SourceSansBold
SendButton.TextSize = 16
SendButton.Parent = InputContainer

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 40, 0, 40)
ToggleButton.Position = UDim2.new(0, 15, 0, 290)
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ToggleButton.BackgroundTransparency = 0.4
ToggleButton.Text = "💬"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 20
ToggleButton.Parent = ScreenGui

local DisplayedMessages = {}

-- 2. HÀM HIỂN THỊ TIN NHẮN (TỰ ĐỘNG HÓA BIỆT DANH & MÀU RAINBOW)
local function AppendMessage(senderName, message, msgId)
    if message == "" then return end
    if msgId and DisplayedMessages[msgId] then return end
    if msgId then DisplayedMessages[msgId] = true end

    if senderName ~= "HỆ THỐNG" then
        lastMessageTime = os.time()
        chatCleared = false
    end

    local currentLabels = {}
    for _, child in ipairs(ChatLog:GetChildren()) do
        if child:IsA("TextLabel") then table.insert(currentLabels, child) end
    end
    if #currentLabels >= 30 then currentLabels[1]:Destroy() end

    local MessageLabel = Instance.new("TextLabel")
    MessageLabel.Size = UDim2.new(1, 0, 0, 0)
    MessageLabel.AutomaticSize = Enum.AutomaticSize.Y
    MessageLabel.BackgroundTransparency = 1
    MessageLabel.Font = Enum.Font.SourceSans
    MessageLabel.TextSize = 16
    MessageLabel.TextXAlignment = Enum.TextXAlignment.Left
    MessageLabel.TextWrapped = true
    MessageLabel.RichText = true 

    -- Logic xử lý tên tự động
    local displayName = senderName
    local nameColor = "#A394B8"

    if DanhBaBiMat[senderName] then
        -- Ưu tiên 1: Tên tự đặt thủ công trong danh bạ
        displayName = DanhBaBiMat[senderName].Nickname
        nameColor = DanhBaBiMat[senderName].Color
    elseif senderName ~= "HỆ THỐNG" then
        -- Ưu tiên 2: Tự động lấy Roblox DisplayName (Biệt danh Roblox của họ)
        local targetPlayer = Players:FindFirstChild(senderName)
        if targetPlayer then
            displayName = targetPlayer.DisplayName
        end
        -- Tự động cấp một màu Rainbow riêng biệt dựa trên tên
        nameColor = GetAutoColor(senderName)
    end

    if senderName == "HỆ THỐNG" then
        MessageLabel.Text = string.format("<font color='#FFDD00'><b>[HỆ THỐNG]</b></font>: <font color='#FFFFFF'>%s</font>", message)
    else
        MessageLabel.Text = string.format("<font color='%s'><b>[%s]</b></font>: <font color='#FFFFFF'>%s</font>", nameColor, displayName, message)
    end
    
    MessageLabel.Parent = ChatLog
end

-- 3. GỬI TIN NHẮN
local function TriggerSend()
    local text = TextBox.Text
    if text ~= "" then
        TextBox.Text = "" 

        if not custom_request then
            AppendMessage("HỆ THỐNG", "Executor không hỗ trợ kết nối mạng!")
            return
        end

        local uniqueId = "local_" .. tostring(os.clock())
        AppendMessage(LocalPlayer.Name, text, uniqueId)

        local packet = HttpService:JSONEncode({
            sender = LocalPlayer.Name,
            message = text
        })

        task.spawn(function()
            pcall(function()
                custom_request({
                    Url = API_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "text/plain" },
                    Body = packet
                })
            end)
        end)
    end
end

SendButton.MouseButton1Click:Connect(TriggerSend)
TextBox.FocusLost:Connect(function(enterPressed) if enterPressed then TriggerSend() end end)
ToggleButton.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Insert then 
        MainFrame.Visible = true 
        task.wait(0.05) 
        TextBox:CaptureFocus() 
    end
end)

-- 4. BỘ PHÂN TÍCH, ĐỒNG BỘ TIN NHẮN & KIỂM TRA THỜI GIAN TRỐNG
task.spawn(function()
    local lastId = ""
    while true do
        if not chatCleared and (os.time() - lastMessageTime) > INACTIVITY_TIMEOUT then
            chatCleared = true
            for _, child in ipairs(ChatLog:GetChildren()) do
                if child:IsA("TextLabel") then child:Destroy() end
            end
            local NoticeLabel = Instance.new("TextLabel")
            NoticeLabel.Size = UDim2.new(1, 0, 0, 0)
            NoticeLabel.AutomaticSize = Enum.AutomaticSize.Y
            NoticeLabel.BackgroundTransparency = 1
            NoticeLabel.Font = Enum.Font.SourceSans
            NoticeLabel.TextSize = 15
            NoticeLabel.TextXAlignment = Enum.TextXAlignment.Left
            NoticeLabel.TextWrapped = true
            NoticeLabel.RichText = true 
            NoticeLabel.Text = "<font color='#FFDD00'><b>[HỆ THỐNG]</b></font>: <font color='#FFA500'><i>Cuộc trò chuyện cũ đã được tự động dọn dẹp do không có hoạt động.</i></font>"
            NoticeLabel.Parent = ChatLog
        end

        if custom_request then
            pcall(function()
                local pollUrl = API_URL .. "/json?poll=1"
                if lastId ~= "" then
                    pollUrl = API_URL .. "/json?poll=1&since=" .. lastId
                end

                local response = custom_request({
                    Url = pollUrl,
                    Method = "GET"
                })
                
                if response and response.StatusCode == 200 then
                    local lines = string.split(response.Body, "\n")
                    for _, line in ipairs(lines) do
                        if string.find(line, "{") then
                            local success, data = pcall(function() return HttpService:JSONDecode(line) end)
                            if success and data and data.event == "message" then
                                local success2, rawData = pcall(function() return HttpService:JSONDecode(data.message) end)
                                
                                if success2 and rawData and rawData.sender and rawData.message then
                                    local sender = rawData.sender
                                    local msg = rawData.message
                                    
                                    if sender == "SYSTEM_COMMAND" then
                                        AppendMessage("HỆ THỐNG", msg)
                                    elseif sender ~= LocalPlayer.Name then
                                        AppendMessage(sender, msg, data.id)
                                    end
                                end
                                lastId = data.id
                            end
                        end
                    end
                end
            end)
        end
        task.wait(2.5) 
    end
end)

-- 5. THÔNG BÁO RỜI SERVER
game:BindToClose(function()
    if custom_request then
        local myDisplay = LocalPlayer.DisplayName
        if DanhBaBiMat[LocalPlayer.Name] then myDisplay = DanhBaBiMat[LocalPlayer.Name].Nickname end
        
        local leavePacket = HttpService:JSONEncode({ 
            sender = "SYSTEM_COMMAND", 
            message = myDisplay .. " đã rời khỏi server." 
        })
        pcall(function()
            custom_request({ 
                Url = API_URL, 
                Method = "POST", 
                Headers = { ["Content-Type"] = "text/plain" },
                Body = leavePacket 
            })
        end)
    end
end)

AppendMessage("HỆ THỐNG", "Hệ thống tự động đồng bộ Biệt danh & Đa sắc màu Rainbow đã hoạt động!")
