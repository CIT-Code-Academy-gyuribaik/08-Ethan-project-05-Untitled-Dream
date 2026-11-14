-- Extras: badge hints that the client sees first (caught, hidden room) + the Flashlight game pass.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local badgeRemote = RS:WaitForChild("BadgeRemote", 30)
local FLASHLIGHT_PASS = 2089886827

------------------------------------------------------------ Not Alone: the first time anything catches you
local CAUGHT_ATTRS = {"NM_Caught", "SC_Caught", "HS_Caught", "HS_RunCaught", "TB_Caught"}
for _, a in CAUGHT_ATTRS do
	player:GetAttributeChangedSignal(a):Connect(function()
		local v = player:GetAttribute(a)
		if typeof(v) == "number" and v > 0 and badgeRemote then badgeRemote:FireServer("NotAlone") end
	end)
end

------------------------------------------------------------ Flashlight pass: a brighter, wider light
local LIGHTS = {NMFlashlight = true, SCFlashlight = true, PGFlashlight = true}
local function boost(part)
	for _, l in part:GetChildren() do
		if l:IsA("SpotLight") and not l:GetAttribute("Boosted") then
			l:SetAttribute("Boosted", true)
			l.Range = math.max(l.Range, 60) * 1.4
			l.Angle = math.min(l.Angle * 1.35, 90)
			l.Brightness = l.Brightness * 1.5
			l.Color = Color3.fromRGB(235, 245, 255)
		end
	end
end
-- small buy button, only while a flashlight exists and you don't own the pass
local gui = Instance.new("ScreenGui") gui.Name = "FlashlightPassUI" gui.ResetOnSpawn = false gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")
local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(230, 40) btn.AnchorPoint = Vector2.new(1, 1) btn.Position = UDim2.new(1, -16, 1, -64)
btn.BackgroundColor3 = Color3.fromRGB(40, 45, 60) btn.BackgroundTransparency = 0.15 btn.BorderSizePixel = 0
btn.Font = Enum.Font.FredokaOne btn.TextSize = 18 btn.TextColor3 = Color3.fromRGB(255, 235, 180)
btn.Text = "\u{1F526} Brighter flashlight" btn.Visible = false btn.Parent = gui
local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 10) corner.Parent = btn
btn.MouseButton1Click:Connect(function()
	pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, FLASHLIGHT_PASS)
end)
local function refresh()
	local owns = player:GetAttribute("FlashlightPass") == true
	local any = false
	for name in LIGHTS do
		local p = workspace:FindFirstChild(name)
		if p then any = true if owns then boost(p) end end
	end
	btn.Visible = any and not owns
end
workspace.ChildAdded:Connect(function(c) if LIGHTS[c.Name] then task.wait(0.2) refresh() end end)
workspace.ChildRemoved:Connect(function(c) if LIGHTS[c.Name] then refresh() end end)
player:GetAttributeChangedSignal("FlashlightPass"):Connect(refresh)
refresh()

------------------------------------------------------------ Dream Explorer: the hidden room (hospital, floor 2)
local msg = Instance.new("TextLabel")
msg.Size = UDim2.new(1, -40, 0, 90) msg.Position = UDim2.new(0, 20, 0.5, 0) msg.BackgroundTransparency = 1
msg.Font = Enum.Font.FredokaOne msg.TextSize = 26 msg.TextWrapped = true msg.TextYAlignment = Enum.TextYAlignment.Top
msg.TextColor3 = Color3.fromRGB(230, 220, 255) msg.TextStrokeTransparency = 0.4 msg.Text = "" msg.TextTransparency = 1 msg.TextStrokeTransparency = 1 msg.Parent = gui
local function show(text, hold)
	msg.Text = text msg.TextTransparency = 0 msg.TextStrokeTransparency = 0.4
	task.delay(hold, function() TweenService:Create(msg, TweenInfo.new(0.6), {TextTransparency = 1, TextStrokeTransparency = 1}):Play() end)
end
local found = false
task.spawn(function()
	while not found do
		task.wait(0.5)
		local room = workspace:FindFirstChild("Dreams") and workspace.Dreams:FindFirstChild("Dream10") and workspace.Dreams.Dream10:FindFirstChild("HiddenRoom")
		local zone = room and room:FindFirstChild("Zone")
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if zone and hrp then
			local l = zone.CFrame:PointToObjectSpace(hrp.Position)
			if math.abs(l.X) < zone.Size.X / 2 and math.abs(l.Y) < zone.Size.Y / 2 and math.abs(l.Z) < zone.Size.Z / 2 then
				found = true
				if badgeRemote then badgeRemote:FireServer("Explorer") end
				show("A room that isn't on any sign. The present from the empty chair is here. Still wrapped.", 5)
				task.wait(5.5)
				show("Someone keeps putting it back.", 3.5)
			end
		end
	end
end)
