-- Chapters: the chapter-select menu, the "End of Chapter 1" card, and Chapter 2's opening:
-- you wake up in your apartment. Some things followed you out of the dream. Then you sleep again, deeper.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local remote = RS:WaitForChild("ChapterRemote")
local cam = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "ChaptersUI" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")
local function tween(o, t, p, style) local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Sine), p) tw:Play() return tw end
local function label(props)
	local l = Instance.new("TextLabel") l.BackgroundTransparency = 1 l.TextColor3 = Color3.new(1, 1, 1) l.TextWrapped = true
	for k, v in props do l[k] = v end l.Parent = gui return l
end
local black = Instance.new("Frame") black.Size = UDim2.fromScale(1, 1) black.BackgroundColor3 = Color3.new(0, 0, 0) black.BackgroundTransparency = 1 black.BorderSizePixel = 0 black.ZIndex = 1 black.Parent = gui
local title = label{Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0.36, 0), Font = Enum.Font.FredokaOne, TextSize = 54, Text = "", TextTransparency = 1, ZIndex = 3}
local sub = label{Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.36, 72), Font = Enum.Font.FredokaOne, TextSize = 26, Text = "", TextTransparency = 1, ZIndex = 3, TextColor3 = Color3.fromRGB(200, 200, 220)}
local line = label{Size = UDim2.new(1, -40, 0, 90), Position = UDim2.new(0, 20, 0.66, 0), Font = Enum.Font.FredokaOne, TextSize = 28, Text = "", TextTransparency = 1, TextStrokeTransparency = 1, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(255, 240, 170), ZIndex = 3}
local objective = label{Size = UDim2.new(1, -48, 0, 40), Position = UDim2.new(0, 24, 0, 70), Font = Enum.Font.FredokaOne, TextSize = 22, Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.4, ZIndex = 3}
local video = label{Size = UDim2.new(1, -40, 0, 50), Position = UDim2.new(0, 20, 0.2, 0), Font = Enum.Font.Code, TextSize = 30, Text = "", TextColor3 = Color3.fromRGB(230, 60, 70), TextStrokeTransparency = 0.5, ZIndex = 3}
local lineTok = 0
local busyUntil = 0
local function say(text, hold)
	hold = hold or 4
	local wait0 = math.max(0, busyUntil - os.clock())
	busyUntil = os.clock() + wait0 + hold + 0.4
	task.delay(wait0, function()
		lineTok += 1 local my = lineTok
		line.Text = text line.TextTransparency = 0 line.TextStrokeTransparency = 0.3
		task.delay(hold, function() if lineTok == my then tween(line, 0.5, {TextTransparency = 1, TextStrokeTransparency = 1}) end end)
	end)
	return wait0 + hold
end
local function card(t, s, hold)
	title.Text = t sub.Text = s or ""
	tween(title, 1.2, {TextTransparency = 0}) tween(sub, 1.6, {TextTransparency = 0})
	task.wait(hold or 3.5)
	tween(title, 1, {TextTransparency = 1}) tween(sub, 1, {TextTransparency = 1})
	task.wait(1)
end
-- the video "speaks" again: glitchy typewriter
local function videoSay(text, hold, screenLabel)
	video.Text = "" video.TextTransparency = 0
	for i = 1, #text do
		video.Text = text:sub(1, i)
		if screenLabel then screenLabel.Text = video.Text end
		task.wait(0.05)
	end
	task.wait(hold or 2)
	tween(video, 0.4, {TextTransparency = 1})
end

------------------------------------------------------------ chapter select (only after you've finished Chapter 1)
local function menu()
	local t0 = os.clock()
	while player:GetAttribute("DataLoaded") == nil and os.clock() - t0 < 8 do task.wait(0.1) end
	if not player:GetAttribute("Ch1Done") then return end
	if player:GetAttribute("ChapterPick") ~= nil then return end
	local m = Instance.new("Frame") m.Name = "Menu" m.Size = UDim2.fromScale(1, 1) m.BackgroundColor3 = Color3.fromRGB(10, 10, 18) m.BorderSizePixel = 0 m.ZIndex = 10 m.Parent = gui
	local t = Instance.new("TextLabel") t.Size = UDim2.new(1, 0, 0, 70) t.Position = UDim2.new(0, 0, 0.18, 0) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextSize = 56
	t.TextColor3 = Color3.new(1, 1, 1) t.Text = "Untitled Dream" t.ZIndex = 11 t.Parent = m
	local s = t:Clone() s.Position = UDim2.new(0, 0, 0.18, 70) s.TextSize = 22 s.TextColor3 = Color3.fromRGB(170, 170, 200) s.Text = "Your progress is saved. Where do you want to start?" s.Parent = m
	local picked = false
	local function button(y, text, desc, n)
		local b = Instance.new("TextButton") b.Size = UDim2.fromOffset(360, 74) b.AnchorPoint = Vector2.new(0.5, 0) b.Position = UDim2.new(0.5, 0, y, 0)
		b.BackgroundColor3 = Color3.fromRGB(45, 45, 70) b.BorderSizePixel = 0 b.AutoButtonColor = true b.Text = "" b.ZIndex = 11 b.Modal = true b.Parent = m
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 12) c.Parent = b
		local a = Instance.new("TextLabel") a.Size = UDim2.new(1, 0, 0.55, 0) a.BackgroundTransparency = 1 a.Font = Enum.Font.FredokaOne a.TextSize = 26 a.TextColor3 = Color3.new(1, 1, 1) a.Text = text a.ZIndex = 12 a.Parent = b
		local d = a:Clone() d.Position = UDim2.new(0, 0, 0.5, 0) d.Size = UDim2.new(1, 0, 0.45, 0) d.TextSize = 17 d.TextColor3 = Color3.fromRGB(190, 190, 215) d.Text = desc d.Parent = b
		b.MouseButton1Click:Connect(function()
			if picked then return end
			picked = true
			player:SetAttribute("ChapterPick", n)
			if n == 2 then remote:FireServer("Pick", 2) end
			tween(m, 0.6, {BackgroundTransparency = 1})
			for _, x in m:GetDescendants() do
				if x:IsA("TextLabel") then tween(x, 0.4, {TextTransparency = 1}) end
				if x:IsA("TextButton") then x.Modal = false tween(x, 0.4, {BackgroundTransparency = 1}) end
			end
			task.delay(0.7, function() m:Destroy() end)
		end)
	end
	button(0.42, "Chapter 1: The Dream", "From the beginning: the video, and the first dreams.", 1)
	button(0.56, "Chapter 2: Waking Up", "You wake up. Not everything stayed behind.", 2)
end
task.spawn(menu)

------------------------------------------------------------ Chapter 2 opening: waking up
local P = workspace:WaitForChild("Prologue")
local things = P:WaitForChild("Ch2Things", 30)
local function setObjective(t) objective.Text = (t and t ~= "") and ("\u{2726}  " .. t) or "" end
local function nightLook()
	Lighting.ClockTime = 0.6 Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(72, 76, 96) Lighting.OutdoorAmbient = Color3.fromRGB(55, 60, 80)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then atm.Density = 0.38 atm.Color = Color3.fromRGB(45, 50, 70) atm.Decay = Color3.fromRGB(25, 28, 40) atm.Haze = 1.5 end
	local cc = Lighting:FindFirstChild("PrologueCC")
	if cc then cc.Saturation = -0.25 cc.TintColor = Color3.fromRGB(205, 215, 240) cc.Brightness = 0 cc.Contrast = 0.1 end
	workspace.Gravity = 196.2
	-- night inside: no fake daylight through the window, a dim warm bedside lamp, the desk lamp + laptop glow
	local F = P:FindFirstChild("Furniture")
	if F then
		local day = F:FindFirstChild("DaylightSrc")
		if day then for _, l in day:GetDescendants() do if l:IsA("Light") then l.Enabled = false end end end
		local ns = F:FindFirstChild("Nightstand")
		if ns then for _, l in ns:GetDescendants() do if l:IsA("Light") then l.Enabled = true l.Brightness = 0.6 l.Range = 16 l.Color = Color3.fromRGB(255, 190, 130) end end end
		local desk = F:FindFirstChild("Desk")
		local head = desk and desk:FindFirstChild("DeskLampHead")
		if head then for _, l in head:GetDescendants() do if l:IsA("Light") then l.Brightness = 1.2 l.Color = Color3.fromRGB(255, 205, 150) end end end
	end
end
local function revealThings()
	for _, p in things:GetDescendants() do
		if p:IsA("BasePart") then p.Transparency = p:GetAttribute("BaseTransparency") or 0 end
		if p:IsA("SurfaceGui") then p.Enabled = true end
	end
end
local function prompt(part, action, object, hold, dist)
	local p = Instance.new("ProximityPrompt") p.ActionText = action p.ObjectText = object or "" p.HoldDuration = hold or 0.3
	p.MaxActivationDistance = dist or 8 p.RequiresLineOfSight = false p.Parent = part
	return p
end
local function glint(part)
	local l = Instance.new("PointLight") l.Range = 6 l.Brightness = 0.8 l.Color = Color3.fromRGB(255, 225, 160) l.Parent = part
	local s = Instance.new("Sparkles") s.SparkleColor = Color3.fromRGB(255, 235, 180) s.Parent = part
	return function() l:Destroy() s:Destroy() end
end
local woke = false
local function wakeUp()
	if woke then return end
	woke = true
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	black.BackgroundTransparency = 0
	nightLook()
	revealThings()
	-- the laptop glows with the video, the ceiling light is off, the desk lamp is on
	local desk = P.Furniture.Desk
	local screen = desk.Screen
	for _, g in screen:GetChildren() do if g:IsA("SurfaceGui") then g.Enabled = false end end
	local sg = Instance.new("SurfaceGui") sg.Name = "WakeScreen" sg.CanvasSize = Vector2.new(400, 260) sg.LightInfluence = 0
	sg.Face = Enum.NormalId.Left sg.Parent = screen
	local bg = Instance.new("Frame") bg.Size = UDim2.fromScale(1, 1) bg.BackgroundColor3 = Color3.fromRGB(10, 10, 14) bg.BorderSizePixel = 0 bg.Parent = sg
	local st = Instance.new("TextLabel") st.Size = UDim2.new(1, -20, 1, -20) st.Position = UDim2.fromOffset(10, 10) st.BackgroundTransparency = 1 st.Font = Enum.Font.Code st.TextScaled = true
	st.TextColor3 = Color3.fromRGB(230, 60, 70) st.Text = "\u{25B6} 11 / 12" st.Parent = bg
	local glow = Instance.new("PointLight") glow.Range = 9 glow.Brightness = 0.9 glow.Color = Color3.fromRGB(200, 120, 140) glow.Parent = screen
	local fixture = P.Furniture:FindFirstChild("CeilingFixture")
	if fixture then for _, l in fixture:GetDescendants() do if l:IsA("Light") then l.Enabled = false end end end
	-- you're on the floor: the camera starts low, looking at the ceiling, then you sit up
	hrp.Anchored = true
	local spot = things.WakeSpot.Position
	hrp.CFrame = CFrame.lookAt(spot + Vector3.new(0, 2.6, 0), spot + Vector3.new(-1, 2.6, 0))
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(spot + Vector3.new(0, 0.8, 0), spot + Vector3.new(0.3, 12, 0.6))
	task.wait(1)
	tween(black, 3, {BackgroundTransparency = 1})
	task.wait(2.5)
	say("You wake up on the floor. Inside the chalk circle.", 4)
	task.wait(3)
	tween(cam, 3, {CFrame = CFrame.lookAt(spot + Vector3.new(0, 4.5, 0), Vector3.new(-12, 6, 0))})
	task.wait(3.2)
	cam.CameraType = Enum.CameraType.Custom
	hrp.Anchored = false
	if hum then hum.WalkSpeed = 12 end
	say("It's still raining. It's dark out now. ...How long were you gone?", 4.5)
	-- the four things that followed you out
	local found = 0
	local function objectiveLook() setObjective(("Look around (%d/4)"):format(found)) end
	objectiveLook()
	local function thing(part, action, obj, text, extra)
		local un = glint(part)
		local pr = prompt(part, action, obj, 0.4, 8)
		pr.Triggered:Connect(function()
			pr:Destroy() un()
			found += 1 objectiveLook()
			say(text, 5)
			if extra then extra() end
		end)
	end
	thing(things.Flowers.FlowersSpot, "Look", "Flowers", "Yellow flowers in your coffee mug. You didn't bring anything back. You couldn't have.")
	thing(things.Drawing, "Look", "Drawing", "A crayon drawing, taped above your bed. The tape is old and yellow. It's been here for years.")
	thing(things.ToyCar, "Look", "Toy car", "The little red car. One of its wheels is still spinning.", function()
		local wheels = {} for _, w in things:GetChildren() do if w.Name == "Wheel" then table.insert(wheels, w) end end
		local t0 = os.clock()
		local c c = RunService.RenderStepped:Connect(function(dt)
			if os.clock() - t0 > 6 then c:Disconnect() return end
			if wheels[1] then wheels[1].CFrame = wheels[1].CFrame * CFrame.Angles(dt * 12, 0, 0) end
		end)
	end)
	thing(things.MirrorNote, "Look", "Mirror", "A sticky note on the mirror, right where your face would be. Someone drew a smile on it. ...You don't take it off.")
	while found < 4 do task.wait(0.3) end
	task.wait(5.5)
	-- the video still has one more step
	setObjective("Check the laptop")
	say("The laptop is still on. The video never finished.", 4)
	local unL = glint(screen)
	local lp = prompt(screen, "Watch", "Laptop", 0.5, 8)
	local watched = false
	lp.Triggered:Connect(function() watched = true end)
	while not watched do task.wait(0.2) end
	lp:Destroy() unL()
	setObjective("")
	if hum then hum.WalkSpeed = 0 end
	st.Text = "\u{25B6} 12 / 12" task.wait(1.2)
	videoSay("you left early.", 1.6, st)
	videoSay("there is more.", 1.6, st)
	videoSay("lie down. close your eyes.", 2, st)
	videoSay("go deeper.", 2.2, st)
	st.Text = "\u{25B6} 12 / 12"
	if hum then hum.WalkSpeed = 12 end
	say("You're so tired. You didn't sleep at all, did you? You were only dreaming.", 5)
	task.wait(5)
	-- lie down again
	setObjective("Lie down")
	local bed = P.Furniture.Bed.Mattress
	local unB = glint(bed)
	local bp = prompt(bed, "Lie down", "Bed", 0.8, 9)
	local lay = false
	bp.Triggered:Connect(function() lay = true end)
	while not lay do task.wait(0.2) end
	bp:Destroy() unB()
	setObjective("")
	hrp.Anchored = true
	cam.CameraType = Enum.CameraType.Scriptable
	local pillow = P.Furniture.Bed.Pillow1.Position
	tween(cam, 2.5, {CFrame = CFrame.lookAt(pillow + Vector3.new(1, 1.2, 1.5), pillow + Vector3.new(1, 12, 3))})
	task.wait(2.8)
	for _, n in {"1...", "2...", "3."} do
		videoSay(n, 0.8)
	end
	tween(black, 2.5, {BackgroundTransparency = 0}).Completed:Wait()
	task.wait(1)
	card("CHAPTER 2", "Deeper", 3.5)
	cam.CameraType = Enum.CameraType.Custom
	hrp.Anchored = false
	remote:FireServer("Sleep2")
	task.delay(1.5, function() tween(black, 2.5, {BackgroundTransparency = 1}) end)
end

remote.OnClientEvent:Connect(function(action)
	if action == "Ch1End" then
		tween(black, 1.5, {BackgroundTransparency = 0})
		task.wait(1.6)
		card("END OF CHAPTER 1", "The Dream", 4)
	elseif action == "WakeUp" then
		task.spawn(wakeUp)
	elseif action == "Ch2Soon" then
		black.BackgroundTransparency = 0
		card("CHAPTER 2", "to be continued...", 999)
	end
end)
