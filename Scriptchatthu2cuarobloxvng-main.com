--[[
    CUSTOM PRIVATE CHAT - ANTI-LAG & AUTO-CLEAN VERSION
    Tính năng mới: Tự động xóa sạch tin nhắn khi đối phương thoát game hoặc khi phòng trống.
    Giới hạn: Tối đa hiển thị 30 tin nhắn để đảm bảo 0% lag cho điện thoại.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Server phòng chat dùng chung
local CHAT_ROOM_NAME = "phong_chat_sieu_toc_kuro_bacon_2026" 
local API_URL = "https://ntfy.sh/" .. CHAT_ROOM_NAME

local custom_request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

-- 1. KHỞI TẠO GIAO DIỆN CHUẨN
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VNG_AntiLagPrivateChat"
ScreenGui.Parent = CoreGui
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

--- HÀM XÓA SẠCH BỘ NHỚ CHAT (ĐỂ CHỐNG LAG) ---
local DisplayedMessages = {}
local function ClearAllChatLogs()
    for _, child in ipairs(ChatLog:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    table.clear(DisplayedMessages)
end

--- 2. HÀM HIỂN THỊ TIN NHẮN THÔNG MINH (GIỚI HẠN TỐI ĐA 30 TIN NHẮN) ---
local function AppendMessage(senderName, message, msgId)
    if message == "" then return end
    if msgId and DisplayedMessages[msgId] then return end
    if msgId then DisplayedMessages[msgId] = true end

    -- Kiểm tra số lượng tin nhắn hiện tại để tự động xóa bớt tin nhắn cũ (Chống lag UI)
    local currentLabels = {}
    for _, child in ipairs(ChatLog:GetChildren()) do
        if child:IsA("TextLabel") then
            table.insert(currentLabels, child)
        end
    end
    if #currentLabels >= 30 then
        currentLabels[1]:Destroy() -- Xóa tin nhắn cũ nhất đi
    end

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

    task.wait(0.01)
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
    ChatLog.CanvasPosition = Vector2.new(0, UIListLayout.AbsoluteContentSize.Y)
end

--- 3. GỬI TIN NHẮN TỐC ĐỘ CAO ---
local function TriggerSend()
    local text = TextBox.Text
    if text ~= "" then
        TextBox.Text = "" 

        if not custom_request then
            AppendMessage("HỆ THỐNG", "Executor của bạn không hỗ trợ kết nối mạng!")
            return
        end

        local uniqueId = "local_" .. tostring(os.clock())
        AppendMessage(LocalPlayer.Name, text, uniqueId)

        task.spawn(function()
            pcall(function()
                custom_request({
                    Url = API_URL,
                    Method = "POST",
                    Headers = { ["Title"] = LocalPlayer.Name },
                    Body = text
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
    if input.KeyCode == Enum.KeyCode.Slash then MainFrame.Visible = true task.wait(0.01) TextBox:CaptureFocus() end
end)

--- 4. VÒNG LẶP ĐỒNG BỘ + XỬ LÝ LỆNH LÀM SẠCH TỪ XA ---
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
                            local data = HttpService:JSONDecode(line)
                            if data.event == "message" then
                                local sender = data.title or "Người lạ"
                                local msg = data.message
                                local msgId = data.id
                                
                                -- NẾU NHẬN ĐƯỢC LỆNH LÀM SẠCH TỪ ĐỐI PHƯƠNG KHI HỌ THOÁT
                                if sender == "SYSTEM_COMMAND" and msg == "CLEAR_LOGS" then
                                    ClearAllChatLogs()
                                    AppendMessage("HỆ THỐNG", "Đối phương đã thoát hoặc phòng chat trống. Đã dọn dẹp dữ liệu để tránh lag!", "sys_clear")
                                else
                                    -- Nếu là tin nhắn bình thường của người kia
                                    if sender ~= LocalPlayer.Name and sender ~= "SYSTEM_COMMAND" then
                                        AppendMessage(sender, msg, msgId)
                                    end
                                end
                                lastId = msgId
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.3)
    end
end)

--- 5. TỰ ĐỘNG PHÁT TÍN HIỆU XÓA PHÒNG KHI BẠN THOÁT GAME/OUT SCRIPT ---
local function AutoCleanOnLeave()
    if custom_request then
        pcall(function()
            custom_request({
                Url = API_URL,
                Method = "POST",
                Headers = { ["Title"] = "SYSTEM_COMMAND" },
                Body = "CLEAR_LOGS"
            })
        end)
    end
end

-- Kích hoạt lệnh xóa khi người chơi đóng game hoặc sập tab
game:BindToClose(AutoCleanOnLeave)
