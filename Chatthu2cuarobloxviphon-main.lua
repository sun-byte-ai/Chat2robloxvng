--[[
    CUSTOM PRIVATE CHAT - V3 (NICKNAME & COLOR UPDATE)
    Tính năng mới: 
    - Đặt biệt danh bí mật cho bạn bè (Chỉ máy bạn thấy).
    - Tự động tô màu riêng biệt cho từng người chơi khác nhau.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local TargetGui = (gethui and gethui()) or game:GetService("CoreGui")

local CHAT_ROOM_NAME = "phong_chat_sieu_toc_kuro_bacon_2026" 
local API_URL = "https://ntfy.sh/" .. CHAT_ROOM_NAME

local custom_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- ==========================================
-- 📕 DANH BẠ BÍ MẬT (CHỈ BẠN MỚI THẤY)
-- Thay "TênRoblox" bằng tên thật trong game của bạn bè.
-- Bạn có thể dùng mã màu HEX (như #FF0000)
-- ==========================================
local DanhBaBiMat = {
    ["TenRobloxCuaBan1"] = { Nickname = "Đại Ca 🐯", Color = "#FF4500" }, -- Màu Đỏ cam
    ["TenRobloxCuaBan2"] = { Nickname = "Bé Nấm 🍄", Color = "#FF69B4" }, -- Màu Hồng
    ["TenRobloxCuaBan3"] = { Nickname = "Bff ❤️", Color = "#00FFFF" },   -- Màu Xanh Neon
    
    -- Bạn có thể tự đổi tên và màu của chính mình luôn
    [LocalPlayer.Name]   = { Nickname = "Tôi (Ẩn danh) 👑", Color = "#FFD700" } -- Màu Vàng Gold
}

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
TextBox.PlaceholderText = " Nhập tin nhắn..."
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

-- Hàm tạo màu tự động cho người lạ (dựa trên tên để luôn ra 1 màu cố định cho người đó)
local function GetAutoColor(name)
    local colors = {"#00FF7F", "#7FFF00", "#FFA500", "#00BFFF", "#9370DB", "#FF1493", "#00CED1"}
    local hash = 0
    for i = 1, #name do hash = hash + string.byte(name, i) end
    return colors[(hash % #colors) + 1]
end

local DisplayedMessages = {}

-- 2. HÀM HIỂN THỊ TIN NHẮN (ĐÃ TÍCH HỢP BIỆT DANH & MÀU)
local function AppendMessage(senderName, message, msgId)
    if message == "" then return end
    if msgId and DisplayedMessages[msgId] then return end
    if msgId then DisplayedMessages[msgId] = true end

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

    -- XỬ LÝ BIỆT DANH VÀ MÀU SẮC TẠI ĐÂY
    local displayName = senderName
    local nameColor = "#A394B8" -- Màu mặc định (Xám nhạt)

    if DanhBaBiMat[senderName] then
        -- Nếu có trong danh bạ -> Lấy Biệt danh & Màu VIP
        displayName = DanhBaBiMat[senderName].Nickname
        nameColor = DanhBaBiMat[senderName].Color
    elseif senderName ~= "HỆ THỐNG" then
        -- Nếu là người lạ -> Sinh ra một màu ngẫu nhiên nhưng cố định cho người đó
        nameColor = GetAutoColor(senderName)
    end

    if senderName == "HỆ THỐNG" then
        MessageLabel.Text = string.format("<font color='#FFDD00'><b>[HỆ THỐNG]</b></font>: <font color='#FFFFFF'>%s</font>", message)
    else
        MessageLabel.Text = string.format("<font color='%s'><b>[%s]</b></font>: <font color='#FFFFFF'>%s</font>", nameColor, displayName, message)
    end
    
    MessageLabel.Parent = ChatLog
end

-- 3. GỬI TIN NHẮN (Vẫn gửi đi dưới tên thật để tránh rác server)
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
            sender = LocalPlayer.Name, -- Gửi đi bằng tên gốc
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

-- 4. BỘ PHÂN TÍCH VÀ ĐỒNG BỘ TIN NHẮN
task.spawn(function()
    local lastId = ""
    while true do
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

-- 5. THÔNG BÁO TỪ BỎ PHÒNG (Sử dụng tên danh bạ nếu có)
game:BindToClose(function()
    if custom_request then
        -- Lấy biệt danh của bản thân nếu có, không thì dùng tên game
        local myDisplay = LocalPlayer.Name
        if DanhBaBiMat[LocalPlayer.Name] then myDisplay = DanhBaBiMat[LocalPlayer.Name].Nickname end
        
        local leavePacket = HttpService:JSONEncode({ 
            sender = "SYSTEM_COMMAND", 
            message = myDisplay .. " đã rời khỏi kênh chat." 
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

AppendMessage("HỆ THỐNG", "Kênh Chat Bí Mật đã kết nối! Đang tải Danh bạ...")
