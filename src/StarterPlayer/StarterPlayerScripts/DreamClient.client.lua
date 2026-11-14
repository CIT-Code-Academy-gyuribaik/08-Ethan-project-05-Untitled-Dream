-- DreamClient: the peaceful dreams. Each dream has a simple mission that opens the Dream Door.
--  1 Cloud Meadow : collect 5 dream stars
--  2 Lantern Lake : light 4 lanterns -> a bridge of light appears
--  3 Toy Town     : find 3 toy blocks and stack them on the pedestal
--  4 Empty Plain  : an endless grass field in the fog - just walk to the light
--  5 Home         : the nightmare - the house goes wrong, Dad comes home drunk (see Nightmare module)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = RS:WaitForChild("DreamRemote")
local Dreams = workspace:WaitForChild("Dreams")

local currentIndex, currentDream = nil, nil

------------------------------------------------------------ UI
local gui = Instance.new("ScreenGui")
gui.Name = "DreamUI" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true gui.DisplayOrder = 11
gui.Parent = player:WaitForChild("PlayerGui")
local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1 l.TextColor3 = Color3.new(1,1,1) l.TextWrapped = true
	for k, v in props do l[k] = v end
	l.Parent = gui
	return l
end
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1,1) fade.BackgroundColor3 = Color3.new(1,1,1) fade.BackgroundTransparency = 1 fade.BorderSizePixel = 0 fade.ZIndex = 5 fade.Parent = gui
local title = label{Size=UDim2.new(1,0,0,70), Position=UDim2.new(0,0,0.32,0), Font=Enum.Font.FredokaOne, TextSize=58, Text="", TextTransparency=1, ZIndex=6, TextStrokeTransparency=1, TextStrokeColor3=Color3.fromRGB(120,90,160)}
local sub = label{Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,0,0.32,72), Font=Enum.Font.FredokaOne, TextSize=26, Text="", TextTransparency=1, ZIndex=6, TextStrokeTransparency=1, TextStrokeColor3=Color3.fromRGB(120,90,160)}
local objective = label{Size=UDim2.new(0,460,0,32), Position=UDim2.new(0,24,0,70), Font=Enum.Font.FredokaOne, TextSize=22, TextXAlignment=Enum.TextXAlignment.Left, Text="", TextStrokeTransparency=0.4, TextStrokeColor3=Color3.fromRGB(90,60,120)}
local popup = label{Size=UDim2.new(1,0,0,40), Position=UDim2.new(0,0,0.68,0), Font=Enum.Font.FredokaOne, TextSize=30, Text="", TextTransparency=1, TextColor3=Color3.fromRGB(255,240,170), TextStrokeTransparency=1, TextStrokeColor3=Color3.fromRGB(110,80,150)}

local function tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Sine), props)
	tw:Play() return tw
end
local popToken = 0
local function pop(text, hold)
	popToken += 1 local my = popToken
	popup.Text = text popup.TextTransparency = 0 popup.TextStrokeTransparency = 0.3
	task.delay(hold or 2.5, function()
		if popToken == my then tween(popup, 0.6, {TextTransparency = 1, TextStrokeTransparency = 1}) end
	end)
end
local function setObjective(t) objective.Text = (t and t ~= "") and ("✦  " .. t) or "" end
local function titleCard(a, b)
	title.Text = a sub.Text = b
	tween(title, 1.2, {TextTransparency = 0, TextStrokeTransparency = 0.3})
	task.wait(0.5)
	tween(sub, 1.2, {TextTransparency = 0, TextStrokeTransparency = 0.3})
	task.wait(3)
	tween(title, 1, {TextTransparency = 1, TextStrokeTransparency = 1})
	tween(sub, 1, {TextTransparency = 1, TextStrokeTransparency = 1})
end

------------------------------------------------------------ dream look (local lighting) + floaty movement
local PRESETS = {
	{Clock=16.5, Bright=2.2, Amb={150,130,170}, Out={200,180,220}, Atm={0.42,{255,205,235},{190,170,255},2.2}, Sat=0.15, Tint={255,240,250}, Cloud={0.45,{255,220,240}}},
	{Clock=19.4, Bright=1.0, Amb={80,80,130},   Out={100,100,160}, Atm={0.52,{90,100,170},{60,50,120},2.6},   Sat=0.10, Tint={225,228,255}, Cloud={0.35,{150,140,200}}},
	{Clock=13.0, Bright=2.6, Amb={160,160,170}, Out={200,200,210}, Atm={0.36,{200,230,255},{255,230,200},1.6}, Sat=0.25, Tint={255,250,245}, Cloud={0.50,{255,255,255}}},
	{Clock=8.2,  Bright=1.6, Amb={140,140,130}, Out={180,180,165}, Atm={0.50,{225,228,215},{200,200,190},2.8}, Sat=-0.05, Tint={250,250,240}, Cloud={0.75,{235,235,230}}},
	{Clock=17.6, Bright=1.8, Amb={130,100,90},  Out={200,150,120}, Atm={0.40,{255,190,150},{200,120,120},2.2}, Sat=0.10, Tint={255,240,225}, Cloud={0.40,{255,200,170}}},
	{Clock=17.9, Bright=2.0, Amb={150,115,95},  Out={225,165,125}, Atm={0.36,{255,195,150},{235,140,110},2.0}, Sat=0.12, Tint={255,236,215}, Cloud={0.50,{255,190,150}}},
	{Clock=23.5, Bright=0.7, Amb={48,50,64},    Out={62,66,88},    Atm={0.45,{40,45,62},{20,22,36},1.2},     Sat=-0.35, Tint={210,220,235}, Cloud={0.60,{60,60,75}}},
}
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function applyLook(i)
	local p = PRESETS[i] if not p then return end
	Lighting.ClockTime = p.Clock Lighting.Brightness = p.Bright
	Lighting.Ambient = rgb(p.Amb) Lighting.OutdoorAmbient = rgb(p.Out)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then atm.Density = p.Atm[1] atm.Color = rgb(p.Atm[2]) atm.Decay = rgb(p.Atm[3]) atm.Haze = p.Atm[4] atm.Glare = 0.2 end
	local cc = Lighting:FindFirstChild("PrologueCC")
	if cc then cc.Saturation = p.Sat cc.TintColor = rgb(p.Tint) cc.Brightness = 0.02 cc.Contrast = 0.05 end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then clouds.Cover = p.Cloud[1] clouds.Color = rgb(p.Cloud[2]) clouds.Density = 0.5 end
	workspace.Gravity = 110 -- floaty dream jumps
end
local function setupHumanoid()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and currentIndex then
		hum.UseJumpPower = true hum.JumpPower = 55 hum.WalkSpeed = 18
	end
end
player.CharacterAdded:Connect(function() task.wait(0.3) setupHumanoid() end)

------------------------------------------------------------ ambient animation: bobbing / spinning tagged parts
local animated = {}
local function track(part, kind)
	local kids = {}
	for _, c in part:GetChildren() do if c:IsA("BasePart") then kids[c] = part.CFrame:ToObjectSpace(c.CFrame) end end
	animated[part] = {kind = kind, base = part.CFrame, phase = math.random() * 6, kids = kids}
end
for _, p in CS:GetTagged("DreamBob") do track(p, "bob") end
for _, p in CS:GetTagged("DreamSpin") do if not p:GetAttribute("RidesTrain") then track(p, "spin") end end

-- toy train
local train = Dreams:FindFirstChild("Dream3") and Dreams.Dream3:FindFirstChild("TrainSet") and Dreams.Dream3.TrainSet:FindFirstChild("Train")
local chimneyOffset
if train and train:FindFirstChild("Engine") and train.Engine:FindFirstChild("Chimney") then
	chimneyOffset = train.Engine.CFrame:ToObjectSpace(train.Engine.Chimney.CFrame)
end
local riders = {}
for _, b in CS:GetTagged("ToyBlock") do if b:GetAttribute("RidesTrain") then riders[b] = b:GetAttribute("RidesTrain") end end
local collected = {}

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for part, a in animated do
		if part.Parent and part.Transparency < 1 then
			local cf
			if a.kind == "bob" then
				cf = a.base * CFrame.new(0, math.sin(t * 1.3 + a.phase) * 0.8, 0) * CFrame.Angles(0, t * 0.6, 0)
			else
				cf = a.base * CFrame.Angles(0, t * 1.5 + a.phase, 0)
			end
			part.CFrame = cf
			for kid, off in a.kids do kid.CFrame = cf * off end
		end
	end
	if train and train.Parent then
		local cx, cz, r, y = train:GetAttribute("CX"), train:GetAttribute("CZ"), train:GetAttribute("R"), train:GetAttribute("Y")
		for _, car in train:GetChildren() do
			local idx = car:GetAttribute("Index")
			if idx then
				local ang = t * 0.35 - (idx - 1) * (7 / r)
				local pos = Vector3.new(cx + math.cos(ang) * r, y, cz + math.sin(ang) * r)
				local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
				car.CFrame = CFrame.lookAt(pos, pos + tangent)
			end
		end
		if chimneyOffset and train.Engine:FindFirstChild("Chimney") then train.Engine.Chimney.CFrame = train.Engine.CFrame * chimneyOffset end
		for b, wagonName in riders do
			local w = train:FindFirstChild(wagonName)
			if w and not collected[b] then b.CFrame = w.CFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, t * 1.5, 0) end
		end
	end
end)

------------------------------------------------------------ bounce pads (mushrooms / trampoline)
local lastBounce = 0
for _, pad in CS:GetTagged("DreamBounce") do
	local baseSize = pad.Size
	pad.Touched:Connect(function(hit)
		local char = player.Character
		if not char or not hit:IsDescendantOf(char) then return end
		if os.clock() - lastBounce < 0.4 then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		lastBounce = os.clock()
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, pad:GetAttribute("Power") or 80, v.Z)
		pad.Size = baseSize * Vector3.new(1.08, 0.7, 1.08)
		tween(pad, 0.35, {Size = baseSize}, Enum.EasingStyle.Elastic)
	end)
end

------------------------------------------------------------ falling off the dream -> drift back to the start
RunService.Heartbeat:Connect(function()
	if not currentDream then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local start = currentDream:FindFirstChild("Start")
	if hrp and start and hrp.Position.Y < start.Position.Y + (currentDream:GetAttribute("FallY") or -50) then
		hrp.AssemblyLinearVelocity = Vector3.zero
		char:PivotTo(start.CFrame + Vector3.new(0, 4, 0))
		fade.BackgroundTransparency = 0.2
		tween(fade, 1, {BackgroundTransparency = 1})
		pop("You drift back to where the dream began...", 2.5)
	end
end)

------------------------------------------------------------ doors
local function goThrough(i)
	setObjective("")
	tween(fade, 1.2, {BackgroundTransparency = 0})
	task.wait(1.3)
	remote:FireServer("Door", i)
end
local function unlockDoor(D, i)
	local door = D:FindFirstChild("Door")
	if not door then return end
	local panel = door.Panel
	panel.Material = Enum.Material.Neon
	tween(panel, 1.5, {Color = Color3.fromRGB(255, 250, 240), Transparency = 0.05})
	local l = Instance.new("PointLight") l.Range = 24 l.Brightness = 2.5 l.Color = Color3.fromRGB(255, 240, 220) l.Parent = panel
	if door:FindFirstChild("Lock") then tween(door.Lock, 0.8, {Transparency = 1}) end
	setObjective("Go through the Dream Door")
	pop("The Dream Door is open!", 3)
	local pr = panel.DoorPrompt
	pr.Enabled = true
	local c c = pr.Triggered:Connect(function()
		c:Disconnect()
		pr.Enabled = false
		goThrough(i)
	end)
end

------------------------------------------------------------ missions
local missions = {}

missions[1] = function(D) -- Cloud Meadow: 5 stars
	local stars = {}
	for _, s in CS:GetTagged("DreamStar") do if s:IsDescendantOf(D) then table.insert(stars, s) end end
	local total, got = #stars, 0
	setObjective(("Collect the dream stars (0/%d)"):format(total))
	pop("Find the glowing stars. Bouncy mushrooms help you jump high!", 4)
	for _, s in stars do
		local done = false
		s.Touched:Connect(function(hit)
			local char = player.Character
			if done or not char or not hit:IsDescendantOf(char) then return end
			done = true
			got += 1
			for _, d in s:GetDescendants() do if d:IsA("Light") or d:IsA("ParticleEmitter") then d.Enabled = false end end
			tween(s, 0.4, {Size = s.Size * 2, Transparency = 1})
			local slot = D.Door:FindFirstChild("Slot" .. got)
			if slot then slot.Material = Enum.Material.Neon tween(slot, 0.5, {Color = Color3.fromRGB(255, 235, 120)}) end
			setObjective(("Collect the dream stars (%d/%d)"):format(got, total))
			pop(("★  Dream star  %d / %d"):format(got, total), 2)
			if got >= total then task.wait(1) unlockDoor(D, 1) end
		end)
	end
end

missions[2] = function(D) -- Lantern Lake: 4 lanterns, then a bridge
	local lanterns = {}
	for _, m in CS:GetTagged("DreamLantern") do if m:IsDescendantOf(D) then table.insert(lanterns, m) end end
	local total, lit = #lanterns, 0
	setObjective(("Light the lanterns (0/%d)"):format(total))
	pop("Hop across the lily pads and light every lantern.", 4)
	for _, m in lanterns do
		local pr = m.Box.LightPrompt
		local c c = pr.Triggered:Connect(function()
			c:Disconnect()
			pr.Enabled = false
			lit += 1
			m.Flame.Material = Enum.Material.Neon
			tween(m.Flame, 0.6, {Color = Color3.fromRGB(255, 180, 80)})
			m.Flame.PointLight.Enabled = true
			-- a little light floats up into the sky
			local orb = Instance.new("Part") orb.Anchored = true orb.CanCollide = false orb.Shape = Enum.PartType.Ball
			orb.Size = Vector3.new(1.2, 1.2, 1.2) orb.Material = Enum.Material.Neon orb.Color = Color3.fromRGB(255, 220, 150)
			orb.CFrame = m.Flame.CFrame orb.Parent = D
			tween(orb, 6, {CFrame = m.Flame.CFrame + Vector3.new(0, 70, 0)})
			setObjective(("Light the lanterns (%d/%d)"):format(lit, total))
			pop(("🏮  Lantern  %d / %d"):format(lit, total), 2)
			if lit >= total then
				task.wait(1.2)
				pop("A bridge of light appears!", 3)
				local segs = {}
				for _, s in CS:GetTagged("LightBridge") do if s:IsDescendantOf(D) then table.insert(segs, s) end end
				table.sort(segs, function(a, b) return a.Position.Z > b.Position.Z end)
				for _, s in segs do
					s.CanCollide = true
					tween(s, 0.5, {Transparency = 0.25})
					task.wait(0.08)
				end
				unlockDoor(D, 2)
			end
		end)
	end
end

missions[3] = function(D) -- Toy Town: 3 blocks on the pedestal
	local blocks = {}
	for _, b in CS:GetTagged("ToyBlock") do if b:IsDescendantOf(D) then table.insert(blocks, b) end end
	local total, got = #blocks, 0
	setObjective(("Find the lost toy blocks (0/%d)"):format(total))
	pop("Three toy blocks are missing. One is riding the train!", 4)
	task.delay(4.5, function() pop("One sits on top of the block tower... one is inside the toy house.", 5) end)
	local ped = D.Pedestal
	local place = ped.Top.PlacePrompt
	for _, b in blocks do
		local pr = b.PickPrompt
		local c c = pr.Triggered:Connect(function()
			c:Disconnect()
			pr.Enabled = false
			collected[b] = true
			got += 1
			for _, d in b:GetDescendants() do if d:IsA("Light") then d.Enabled = false elseif d:IsA("SurfaceGui") then d.Enabled = false end end
			tween(b, 0.3, {Transparency = 1})
			b.CanQuery = false
			pop(("🧸  Toy block  %d / %d"):format(got, total), 2)
			if got >= total then
				setObjective("Stack the blocks on the pedestal")
				place.Enabled = true
			else
				setObjective(("Find the lost toy blocks (%d/%d)"):format(got, total))
				-- hint for whatever is still missing
				local left = {}
				for _, ob in blocks do
					if not collected[ob] then
						table.insert(left, ob:GetAttribute("RidesTrain") and "riding the train" or (ob.Position.Y > ob.Parent.Parent.Start.Position.Y + 15 and "on top of the block tower" or "inside the toy house"))
					end
				end
				task.delay(2.2, function() pop("Still missing: " .. table.concat(left, ", "), 4) end)
			end
		end)
	end
	local c c = place.Triggered:Connect(function()
		c:Disconnect()
		place.Enabled = false
		for i = 1, 3 do
			local g = ped:FindFirstChild("Ghost" .. i)
			if g then
				tween(g, 0.4, {Transparency = 0})
				for _, sg in g:GetChildren() do if sg:IsA("SurfaceGui") then sg.Enabled = true end end
			end
			task.wait(0.5)
		end
		pop("D · R · M  —  the tower is complete!", 3)
		task.wait(1)
		unlockDoor(D, 3)
	end)
end

missions[4] = function(D) -- Empty Plain: nothing here but grass and wind. Walk to the light.
	setObjective("Walk")
	pop("There's nothing here. Just grass... and wind.", 4)
	local door = D.Door
	local thoughts = {
		{60, "The grass is so soft."},
		{140, "It's quiet. Really quiet."},
		{220, "Is that... a light?"},
	}
	task.spawn(function()
		local start = D.Start.Position
		local n = 1
		while currentIndex == 4 do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local walked = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(start.X, 0, start.Z)).Magnitude
				if thoughts[n] and walked > thoughts[n][1] then
					pop(thoughts[n][2], 3)
					if n == 3 then setObjective("Walk toward the light") end
					n += 1
				end
				if (hrp.Position - door.Panel.Position).Magnitude < 45 then
					unlockDoor(D, 4)
					return
				end
				-- wandered too far into the fog: gently bring them back
				if walked > 700 then
					fade.BackgroundTransparency = 0.2
					tween(fade, 1.5, {BackgroundTransparency = 1})
					player.Character:PivotTo(D.Start.CFrame + Vector3.new(0, 4, 0))
					pop("The plain folds back on itself...", 3)
				end
			end
			task.wait(0.3)
		end
	end)
end

local function runModule(name, i, D)
	local ok, err = pcall(function()
		require(script.Parent:WaitForChild(name)).run({
			player = player, gui = gui, pop = pop, setObjective = setObjective, tween = tween, fade = fade,
			title = title, sub = sub, titleCard = titleCard, unlockDoor = unlockDoor, goThrough = goThrough,
			active = function() return currentIndex == i end,
		}, D)
	end)
	if not ok then warn(name .. " error: " .. tostring(err)) end
end
missions[5] = function(D) runModule("Nightmare", 5, D) end   -- the house nightmare
missions[6] = function(D) runModule("Playground", 6, D) end  -- Golden Hour: the playground
missions[7] = function(D) runModule("School", 7, D) end      -- After Hours: the school

------------------------------------------------------------ entering a dream
remote.OnClientEvent:Connect(function(action, i)
	if action == "Enter" then
		local D = Dreams:FindFirstChild("Dream" .. i)
		if not D then return end
		local first = currentIndex ~= i
		currentIndex, currentDream = i, D
		applyLook(i)
		setupHumanoid()
		fade.BackgroundColor3 = Color3.new(1, 1, 1)
		fade.BackgroundTransparency = 0
		tween(fade, 2.5, {BackgroundTransparency = 1})
		if first then
			task.spawn(function()
				task.wait(0.8)
				if currentIndex ~= i then return end
				title.TextColor3 = Color3.new(1, 1, 1) sub.TextColor3 = Color3.new(1, 1, 1)
				titleCard(i == 5 and "Home" or ("Dream " .. i), D:GetAttribute("Title") or "")
				-- skipped ahead (admin panel) while the title was showing: don't start this dream's mission
				if currentIndex ~= i then return end
				if missions[i] then missions[i](D) end
			end)
		end
	elseif action == "End" then
		titleCard("To be continued...", "")
	end
end)
