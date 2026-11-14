-- MouseFree: a button (and the M key) that frees the mouse from first-person lock,
-- so the player can move the cursor and click things. Press again to lock it back.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local free = false

local gui = Instance.new("ScreenGui")
gui.Name = "MouseFreeUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Name = "FreeMouse"
btn.AnchorPoint = Vector2.new(1, 1)
btn.Position = UDim2.new(1, -16, 1, -16)
btn.Size = UDim2.fromOffset(170, 40)
btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
btn.BackgroundTransparency = 0.35
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamMedium
btn.TextSize = 16
btn.AutoButtonColor = true
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", btn)
stroke.Color = Color3.fromRGB(255, 255, 255) stroke.Transparency = 0.7

local function refresh()
	btn.Text = free and "🔒 Lock mouse  [M]" or "🖱 Free mouse  [M]"
	UIS.MouseIconEnabled = true
	if not free then
		-- hand control back to the camera
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function toggle()
	free = not free
	refresh()
end

-- run after the camera so our setting wins every frame while the mouse is free
RunService:BindToRenderStep("MouseFree", Enum.RenderPriority.Camera.Value + 2, function()
	if free then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end
end)

btn.Activated:Connect(toggle)
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end -- e.g. typing in chat
	if input.KeyCode == Enum.KeyCode.M then toggle() end
end)

-- the button only makes sense with a mouse
btn.Visible = UIS.MouseEnabled
refresh()
