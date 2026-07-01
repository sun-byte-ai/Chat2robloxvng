--[[
    CUSTOM PRIVATE CHAT - V2 (FIXED & OPTIMIZED)
    Bản sửa lỗi: Chống Rate-limit, thêm Header, Tối ưu hóa UI/UX, Sửa lỗi xóa chat hàng loạt.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Xác định môi trường GUI an toàn (Tránh bị Anti-cheat quét CoreGui)
local TargetGui = (gethui and gethui()) or game:GetService("CoreGui")

local CHAT_ROOM_NAME = "phong_chat_sieu_toc_kuro_bacon_2026" 
local API_URL = "https://ntfy.sh/" .. CHAT_ROOM_NAME

local custom_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- 1. KHỞI TẠO GIAO DIỆN CHUẨN
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

-- Tự động cuộn xuống dưới cùng khi có tin nhắn mới (Tối ưu hóa)
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
TextBox.PlaceholderText = " Nhập tin nhắn gửi bạn hiền..."
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

-- 2. HÀM HIỂN THỊ TIN NHẮN TỐI ƯU CHỐNG LAG
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

    if senderName == "HỆ THỐNG" then
        MessageLabel.Text = string.format("<font color='#FFDD00'><b>[HỆ THỐNG]</b></font>: <font color='#FFFFFF'>%s</font>", message)
    else
        MessageLabel.Text = string.format("<font color='#A394B8'><b>[%s]</b></font>: <font color='#FFFFFF'>%s</font>", senderName, message)
    end
    
    MessageLabel.Parent = ChatLog
end

-- 3. GỬI TIN NHẮN ĐÃ ĐƯỢC ĐÓNG GÓI BẢO MẬT
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
                    Headers = { ["Content-Type"] = "text/plain" }, -- Đã fix lỗi Header chặn của Executor
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
    -- Đổi sang nút Insert để tránh đụng chạm vào nút `/` mở chat mặc định của Roblox
    if input.KeyCode == Enum.KeyCode.Insert then 
        MainFrame.Visible = true 
        task.wait(0.05) 
        TextBox:CaptureFocus() 
    end
end)

-- 4. BỘ PHÂN TÍCH VÀ ĐỒNG BỘ SIÊU TỐC TỪ XA
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
        task.wait(2.5) -- Đã tăng thời gian lên 2.5s để tránh bị ntfy ban IP (Lỗi 429)
    end
end)

-- 5. THÔNG BÁO TỪ BỎ PHÒNG THAY VÌ XÓA CHAT HÀNG LOẠT
game:BindToClose(function()
    if custom_request then
        -- Chuyển từ lệnh xóa phòng thành lệnh báo out game an toàn
        local leavePacket = HttpService:JSONEncode({ 
            sender = "SYSTEM_COMMAND", 
            message = LocalPlayer.Name .. " đã mất kết nối." 
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

AppendMessage("HỆ THỐNG", "Kênh Chat Đa Nền Tảng đã sẵn sàng (Nhấn phím Insert để mở nhanh)!")
