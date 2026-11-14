-- AdminPanel: skip to any stage. Only shows for admins (server sets the IsAdmin attribute).
-- Press P (or click the Admin button) to open. The mouse is freed while the panel is open.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
while not player:GetAttribute("IsAdmin") do
	player:GetAttributeChangedSignal("IsAdmin"):Wait()
end
local remote = RS:WaitForChild("AdminRemote")
local Dreams = workspace:WaitForChild("Dreams")

local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanelUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 8) end
local function button(parent, text, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = color or Color3.fromRGB(60, 60, 85)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 15
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	return b
end

local open = false
local toggleBtn = Instance.new("TextButton")
toggleBtn.AnchorPoint = Vector2.new(0, 1)
toggleBtn.Position = UDim2.new(0, 16, 1, -16)
toggleBtn.Size = UDim2.fromOffset(120, 36)
toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 60)
toggleBtn.BackgroundTransparency = 0.15
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 15
toggleBtn.Text = "⚙ Admin  [P]"
toggleBtn.Parent = gui
corner(toggleBtn)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 16, 1, -60)
panel.Size = UDim2.fromOffset(230, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
corner(panel, 10)
local pad = Instance.new("UIPadding", panel)
pad.PaddingTop = UDim.new(0, 10) pad.PaddingBottom = UDim.new(0, 10) pad.PaddingLeft = UDim.new(0, 10) pad.PaddingRight = UDim.new(0, 10)
local list = Instance.new("UIListLayout", panel)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 24)
header.BackgroundTransparency = 1
header.TextColor3 = Color3.fromRGB(255, 200, 210)
header.Font = Enum.Font.GothamBold
header.TextSize = 16
header.Text = "ADMIN — Skip stage"
header.LayoutOrder = 0
header.Parent = panel

local function setOpen(v)
	open = v
	panel.Visible = v
end

local nextBtn = button(panel, "⏭  Next stage", Color3.fromRGB(150, 40, 60))
nextBtn.LayoutOrder = 1
nextBtn.Activated:Connect(function() remote:FireServer("Next") setOpen(false) end)

for i = 1, 10 do
	local d = Dreams:FindFirstChild("Dream" .. i)
	if not d then break end
	local b = button(panel, ("Dream %d — %s"):format(i, d:GetAttribute("Title") or ""))
	b.LayoutOrder = 1 + i
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Activated:Connect(function() remote:FireServer("Goto", i) setOpen(false) end)
end

toggleBtn.Activated:Connect(function() setOpen(not open) end)
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.P then setOpen(not open) end
end)

-- free the mouse while the panel is open (runs after the camera each frame)
RunService:BindToRenderStep("AdminMouse", Enum.RenderPriority.Camera.Value + 3, function()
	if open then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end
end)
