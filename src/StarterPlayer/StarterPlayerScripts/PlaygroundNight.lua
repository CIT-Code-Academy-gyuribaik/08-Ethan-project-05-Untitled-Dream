-- PlaygroundNight: Dream 12 "Playground at Night" (Chapter 2). The Golden Hour playground, after dark.
-- Hide and seek: you're it. Count to ten, then find the five kids before the streetlamps go out.
-- Found kids line up by the bench and watch. If it gets too dark, you count again (with less time).
-- After five: "That's everyone." ...Somebody giggles by the fence. There's a sixth.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CS = game:GetService("CollectionService")

local SFX = {
	Kids = "rbxassetid://9114295857",   -- distant children (played slow and short = a giggle)
	Squeak = "rbxassetid://9112892695",
	Step = "rbxassetid://85383897332935",
	Heart = "rbxassetid://9043365842",
}

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, active, gui = ctx.pop, ctx.setObjective, ctx.tween, ctx.active, ctx.gui
	local cam = workspace.CurrentCamera
	local O = Vector3.new(36000, 500, 0)
	local alive = true
	local cleanup, conns = {}, {}
	local function onCleanup(f) table.insert(cleanup, f) end
	local function conn(c) table.insert(conns, c) return c end
	local function hrpOf() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function humOf() local c = player.Character return c and c:FindFirstChildOfClass("Humanoid") end
	local function make(class, props, parent)
		local i = Instance.new(class) for k, v in props do i[k] = v end i.Parent = parent
		onCleanup(function() i:Destroy() end) return i
	end
	local function sfx(id, vol, parent, speed, stopAfter)
		local s = Instance.new("Sound") s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1 s.RollOffMinDistance = 8 s.RollOffMaxDistance = 120
		s.Parent = parent or SoundService s:Play()
		if stopAfter then task.delay(stopAfter, function() TweenService:Create(s, TweenInfo.new(0.4), {Volume = 0}):Play() end) end
		task.delay((stopAfter or 8) + 1, function() s:Destroy() end) return s
	end
	local function giggle(at) -- a short, slowed-down snippet of children: sounds like one giggle in the dark
		local p = make("Part", {Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at)}, workspace)
		local s = sfx(SFX.Kids, 1.2, p, 0.8 + math.random() * 0.15, 1.4)
		s.TimePosition = math.random() * 25
	end
	local popBusyUntil = 0
	local function say(text, hold) popBusyUntil = os.clock() + (hold or 3) + 0.5 pop(text, hold or 3) end
	local said = {}
	local function narrate(key, text, hold)
		if said[key] then return end said[key] = true
		task.spawn(function()
			local t0 = os.clock() repeat task.wait(0.3) until os.clock() >= popBusyUntil or os.clock() - t0 > 12
			if alive then say(text, hold or 4.5) end
		end)
	end
	local dark = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 14}, gui)
	local big = make("TextLabel", {Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.35), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 90,
		TextColor3 = Color3.fromRGB(230, 230, 255), Text = "", TextTransparency = 1, ZIndex = 15}, gui)

	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
	end
	task.spawn(function() while alive and active() do task.wait(0.3) end shutdown() end)
	local function body() local h = humOf() if h then h.WalkSpeed = 16 end end
	body()
	conn(player.CharacterAdded:Connect(function() task.wait(0.6) body() end))

	-- the Dream Door stays hidden until the end
	local door = D:FindFirstChild("Door")
	local doorParts = {}
	if door then
		for _, p in door:GetDescendants() do if p:IsA("BasePart") then doorParts[p] = p.Transparency p.Transparency = 1 p.CanCollide = false end end
		onCleanup(function() for p, t in doorParts do p.Transparency = t p.CanCollide = true end end)
	end

	-------------------------------------------------------- flashlight (F)
	local flPart = make("Part", {Name = "PGFlashlight", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2)}, workspace)
	local spot = make("SpotLight", {Range = 40, Angle = 45, Brightness = 2.2, Shadows = true, Color = Color3.fromRGB(255, 240, 210), Face = Enum.NormalId.Front, Enabled = true}, flPart)
	make("PointLight", {Range = 8, Brightness = 0.35, Shadows = false, Color = Color3.fromRGB(150, 160, 210)}, flPart)
	conn(RunService.RenderStepped:Connect(function() flPart.CFrame = cam.CFrame * CFrame.new(0.5, -0.6, -0.5) end))
	conn(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.F then spot.Enabled = not spot.Enabled end
	end))

	-------------------------------------------------------- night: lamps go out one by one
	local lamps = {}
	for _, l in D:GetChildren() do if l.Name == "LampHead" then table.insert(lamps, l) end end
	local lampState = {}
	for _, l in lamps do
		local light = l:FindFirstChildOfClass("PointLight")
		lampState[l] = {light = light, color = l.Color}
		onCleanup(function() l.Material = Enum.Material.Neon l.Color = lampState[l].color if light then light.Enabled = true end end)
	end
	local function lampOff(l)
		local st = lampState[l]
		for _ = 1, 4 do
			if st.light then st.light.Enabled = false end l.Material = Enum.Material.SmoothPlastic
			task.wait(0.08 + math.random() * 0.15)
			if st.light then st.light.Enabled = true end l.Material = Enum.Material.Neon
			task.wait(0.05 + math.random() * 0.2)
		end
		if st.light then st.light.Enabled = false end
		l.Material = Enum.Material.SmoothPlastic l.Color = Color3.fromRGB(60, 55, 50)
	end
	local function lampsOn()
		for _, l in lamps do local st = lampState[l] if st.light then st.light.Enabled = true end l.Material = Enum.Material.Neon l.Color = st.color end
	end
	local AMB0 = Color3.fromRGB(64, 68, 92)

	-------------------------------------------------------- the swings and the merry-go-round move on their own
	local swingSet = D:FindFirstChild("SwingSet")
	local swingParts = {}
	if swingSet and swingSet:FindFirstChild("Swing2") then
		local sw = swingSet.Swing2
		local seat = sw:FindFirstChild("Seat")
		local pivotY = sw:GetAttribute("PivotY") or (seat and seat.Position.Y + 9)
		local pivot = CFrame.new(seat.Position.X, pivotY, seat.Position.Z)
		for _, p in sw:GetChildren() do if p:IsA("BasePart") then swingParts[p] = pivot:ToObjectSpace(p.CFrame) end end
		onCleanup(function() for p, o in swingParts do p.CFrame = pivot * o end end)
		local squeak = make("Sound", {SoundId = SFX.Squeak, Volume = 0.35, Looped = true, PlaybackSpeed = 0.6, RollOffMinDistance = 6, RollOffMaxDistance = 60}, seat)
		squeak:Play()
		conn(RunService.RenderStepped:Connect(function()
			local cf = pivot * CFrame.Angles(math.sin(os.clock() * 1.9) * 0.4, 0, 0)
			for p, o in swingParts do p.CFrame = cf * o end
		end))
	end
	local mg = D:FindFirstChild("MerryGoRound")
	if mg and mg:FindFirstChild("Disc") then
		local axis = CFrame.new(mg.Disc.Position)
		local offs = {}
		for _, p in mg:GetChildren() do if p:IsA("BasePart") and p.Name ~= "Base" then offs[p] = axis:ToObjectSpace(p.CFrame) end end
		onCleanup(function() for p, o in offs do p.CFrame = axis * o end end)
		local ang = 0
		conn(RunService.Heartbeat:Connect(function(dt)
			ang += dt * 0.35
			local cf = axis * CFrame.Angles(0, ang, 0)
			for p, o in offs do p.CFrame = cf * o end
		end))
	end

	-------------------------------------------------------- the kids
	local kids = {}
	local sixth
	for _, k in D.Kids:GetChildren() do
		local order = k:GetAttribute("Order") or 9
		local entry = {model = k, order = order, home = k:GetPivot(), found = false}
		onCleanup(function() k:PivotTo(entry.home) for _, p in k:GetDescendants() do if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 elseif p:IsA("SurfaceGui") then p.Enabled = true end end end)
		if order == 6 then sixth = entry else table.insert(kids, entry) end
	end
	table.sort(kids, function(a, b) return a.order < b.order end)
	local function setVisible(k, vis)
		for _, p in k:GetDescendants() do
			if p:IsA("BasePart") then p.LocalTransparencyModifier = vis and 0 or 1
			elseif p:IsA("SurfaceGui") then p.Enabled = vis end
		end
	end
	if sixth then setVisible(sixth.model, false) end
	local foundCount = 0
	local TOTAL = 5
	local seeking = false
	local function objective()
		if foundCount < TOTAL then setObjective(("Find everyone (%d/%d) \u{b7} before the lamps go out"):format(foundCount, TOTAL)) end
	end
	local foundLines = {
		"Found you. They get up without a word.",
		"Two. Their hand is cold when you tag it.",
		"Three. None of them say anything. They just walk to the bench.",
		"Four. Behind you, the swing creaks.",
		"Five. That's everyone.",
	}
	local finish -- forward
	local function walkToLine(k, slot)
		local target = D:FindFirstChild("LineUp" .. slot)
		if not target then return end
		-- fade out where they hid, fade in at the bench
		for i = 1, 6 do for _, p in k:GetDescendants() do if p:IsA("BasePart") then p.LocalTransparencyModifier = i / 6 end end task.wait(0.05) end
		setVisible(k, false)
		local cur = k:GetPivot()
		local tp = target.Position
		k:PivotTo(CFrame.lookAt(Vector3.new(tp.X, cur.Position.Y, tp.Z), Vector3.new(tp.X, cur.Position.Y, tp.Z) + target.CFrame.LookVector))
		-- sitting kids stand up straight at the bench? keep them as they are: small and still
		task.wait(0.6)
		setVisible(k, true)
	end
	for _, e in kids do
		local torso = e.model:FindFirstChild("UpperTorso") or e.model:FindFirstChild("Torso")
		if torso then
			local pr = make("ProximityPrompt", {ActionText = "Found you!", ObjectText = "", HoldDuration = 0.2, MaxActivationDistance = 7, RequiresLineOfSight = false}, torso)
			e.prompt = pr
			conn(pr.Triggered:Connect(function()
				if e.found or not seeking then return end
				e.found = true pr.Enabled = false
				foundCount += 1
				objective()
				giggle(torso.Position)
				say(foundLines[foundCount], 4)
				task.spawn(walkToLine, e.model, foundCount)
				if foundCount >= TOTAL then task.delay(4.5, function() if alive then finish() end end) end
			end))
		end
	end

	-------------------------------------------------------- counting to ten
	local roundTime = 200
	local function countdown(again)
		seeking = false
		local hrp = hrpOf()
		if hrp then hrp.Anchored = true end
		dark.BackgroundTransparency = 0
		big.TextTransparency = 0
		big.Text = again and "Count again." or "You're it."
		task.wait(2)
		for n = 10, 1, -1 do
			if not alive then return end
			big.Text = tostring(n)
			if n == 8 or n == 5 or n == 2 then
				local e = kids[math.random(#kids)]
				giggle(e.model:GetPivot().Position)
			end
			if n % 3 == 0 then sfx(SFX.Step, 0.5, nil, 1.5) end
			task.wait(0.85)
		end
		big.Text = "Ready or not..."
		task.wait(1.4)
		big.Text = "" big.TextTransparency = 1
		lampsOn()
		Lighting.Ambient = AMB0
		if hrp then
			local s = D.Start.Position
			hrp.CFrame = CFrame.lookAt(s + Vector3.new(0, 3, 0), s + Vector3.new(0, 3, -10))
			hrp.Anchored = false
		end
		tween(dark, 1.5, {BackgroundTransparency = 1})
		seeking = true
		objective()
	end

	-------------------------------------------------------- one round: the lamps go out over time
	local function round()
		local t0 = os.clock()
		local step = roundTime / (#lamps + 1)
		local off = 0
		local nextGiggle = os.clock() + 15
		while alive and seeking and foundCount < TOTAL do
			task.wait(0.5)
			local t = os.clock() - t0
			-- it gets darker
			local k = math.clamp(t / roundTime, 0, 1)
			Lighting.Ambient = AMB0:Lerp(Color3.fromRGB(10, 10, 16), k)
			if off < #lamps and t > step * (off + 1) then
				off += 1
				task.spawn(lampOff, lamps[off])
				if off == 1 then say("One of the streetlamps goes out.", 3)
				elseif off == #lamps then say("The last lamp. Hurry.", 3)
				else say("Another lamp goes out. It's getting darker.", 3) end
			end
			-- a giggle somewhere, from someone you haven't found
			if os.clock() > nextGiggle then
				nextGiggle = os.clock() + 14 + math.random() * 10
				local left = {} for _, e in kids do if not e.found then table.insert(left, e) end end
				if #left > 0 then giggle(left[math.random(#left)].model:GetPivot().Position) end
			end
			if t > roundTime then
				-- too dark
				seeking = false
				say("Too dark. You can't see your own hands anymore.", 3.5)
				task.wait(3)
				tween(dark, 1.5, {BackgroundTransparency = 0}).Completed:Wait()
				roundTime = math.max(120, roundTime - 30)
				return false
			end
		end
		return true
	end

	-------------------------------------------------------- the sixth
	finish = function()
		seeking = false
		setObjective("")
		task.wait(1.5)
		if not sixth then return end
		local pos = sixth.model:GetPivot().Position
		setVisible(sixth.model, true)
		giggle(pos)
		say("...Somebody giggled. Over by the far fence.", 3.5)
		task.wait(4)
		setObjective("There's one more")
		say("You only counted five. There were always six.", 4)
		local torso = sixth.model:FindFirstChild("UpperTorso") or sixth.model:FindFirstChild("Torso")
		local pr = make("ProximityPrompt", {ActionText = "Found you!", ObjectText = "", HoldDuration = 0.6, MaxActivationDistance = 7, RequiresLineOfSight = false}, torso)
		local got = false
		pr.Triggered:Connect(function() got = true end)
		while alive and not got do task.wait(0.2) end
		if not alive then return end
		pr:Destroy()
		setObjective("")
		say("This one won't come out. It keeps its face hidden.", 4)
		task.wait(4.5)
		say("It's wearing a yellow raincoat. You had one just like it.", 4.5)
		task.wait(5)
		if door then for p, t in doorParts do p.CanCollide = true TweenService:Create(p, TweenInfo.new(2.5), {Transparency = t}):Play() end end
		task.wait(2.6)
		if alive then ctx.unlockDoor(D, 12) end
	end

	-------------------------------------------------------- things to notice
	local spots = {}
	if swingSet then table.insert(spots, {key = "swing", pos = swingSet:GetBoundingBox().Position, r = 12, text = "The swing is still moving. Nobody's on it."}) end
	table.insert(spots, {key = "bench", pos = D.LineUp3.Position, r = 9, text = "They all stand there watching you. Waiting for you to find the rest."})
	task.spawn(function()
		while alive do
			local hrp = hrpOf()
			if hrp and seeking then
				for _, sp in spots do
					if not said[sp.key] and (Vector3.new(sp.pos.X, hrp.Position.Y, sp.pos.Z) - hrp.Position).Magnitude < sp.r then
						if sp.key ~= "bench" or foundCount >= 2 then narrate(sp.key, sp.text, 4.5) end
					end
				end
			end
			task.wait(0.4)
		end
	end)

	-- debug hook (testing): PlayerGui.NightDebug:Fire("short") = 25s rounds, ("find", n) = tag kid n
	local dbg = make("BindableEvent", {Name = "NightDebug"}, player:WaitForChild("PlayerGui"))
	conn(dbg.Event:Connect(function(cmd, n)
		if cmd == "short" then roundTime = 25
		elseif cmd == "find" then local e = kids[n] if e and e.prompt and not e.found then local hrp = hrpOf() if hrp then hrp.CFrame = CFrame.new(e.model:GetPivot().Position + Vector3.new(0, 3, 3)) end end end
	end))

	-------------------------------------------------------- start
	say("The playground, at night. Nobody's here. ...No. They're hiding.", 4)
	task.wait(4.5)
	local again = false
	while alive and foundCount < TOTAL do
		countdown(again)
		if not alive then return end
		if not again then say("Find them before the streetlamps go out. [F] flashlight", 4) end
		if round() then break end
		again = true
	end
end

return M
