-- CarRain: Dream 14 "The Car in the Rain" (Chapter 2). You're small, in the back seat, on a rainy night road.
-- Buckle up. Then the arguing starts up front and the car goes faster. Keep your panic down:
-- hold C to cover your ears, hug the bear, draw on the fogged window. If it gets too much, you black out and it starts again.
-- Then headlights. A white flash. Silence. The front seats are empty. Your seatbelt is still buckled.
-- (A scare, never violence. Nobody is named.)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UIS = game:GetService("UserInputService")

local SFX = {
	Wipers = "rbxassetid://9112906346",  -- wipers + rain on the roof
	Engine = "rbxassetid://80317022777602",
	Radio = "rbxassetid://93244948579023",
	Horn = "rbxassetid://9063356162",
	Screech = "rbxassetid://9126104014",
	Buckle = "rbxassetid://101851019075798",
	Heart = "rbxassetid://9043365842",
}

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, active, gui, fade = ctx.pop, ctx.setObjective, ctx.tween, ctx.active, ctx.gui, ctx.fade
	local cam = workspace.CurrentCamera
	local O = Vector3.new(42000, 500, 0)
	local alive = true
	local cleanup, conns = {}, {}
	local function onCleanup(f) table.insert(cleanup, f) end
	local function conn(c) table.insert(conns, c) return c end
	local function hrpOf() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function make(class, props, parent)
		local i = Instance.new(class) for k, v in props do i[k] = v end i.Parent = parent
		onCleanup(function() i:Destroy() end) return i
	end
	local function setp(inst, props)
		local old = {} for k, v in props do old[k] = inst[k] inst[k] = v end
		onCleanup(function() for k, v in old do pcall(function() inst[k] = v end) end end)
	end
	local function sfx(id, vol, speed)
		local s = Instance.new("Sound") s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1 s.Parent = SoundService s:Play()
		task.delay(8, function() s:Destroy() end) return s
	end
	local popBusyUntil = 0
	local function say(text, hold) popBusyUntil = os.clock() + (hold or 3) + 0.5 pop(text, hold or 3) end

	-- spoken lines from the front seats (red = the driver, blue = her), muffled while you cover your ears
	local voice = make("TextLabel", {Size = UDim2.new(1, -40, 0, 60), Position = UDim2.new(0, 20, 0.8, 0), BackgroundTransparency = 1, Font = Enum.Font.SpecialElite, TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = "", TextTransparency = 1, TextWrapped = true, ZIndex = 15}, gui)
	local covering = false
	local voiceTok = 0
	local function speak(who, text, hold)
		voiceTok += 1 local my = voiceTok
		voice.TextColor3 = (who == "D") and Color3.fromRGB(235, 80, 70) or Color3.fromRGB(170, 210, 245)
		voice.Text = "\u{201C}" .. text .. "\u{201D}"
		voice.TextTransparency = covering and 0.75 or 0 voice.TextStrokeTransparency = covering and 0.9 or 0.4
		task.delay(hold or 2.8, function() if voiceTok == my and alive then tween(voice, 0.4, {TextTransparency = 1, TextStrokeTransparency = 1}) end end)
	end

	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
	end
	task.spawn(function() while alive and active() do task.wait(0.3) end shutdown() end)

	local door = D:FindFirstChild("Door")
	local doorParts = {}
	if door then
		for _, p in door:GetDescendants() do if p:IsA("BasePart") then doorParts[p] = p.Transparency p.Transparency = 1 p.CanCollide = false end end
		onCleanup(function() for p, t in doorParts do p.Transparency = t p.CanCollide = true end end)
	end

	local car = D.Car
	local driver, passenger = D:FindFirstChild("Driver"), D:FindFirstChild("Passenger")

	-------------------------------------------------------- you, in the back seat
	local seatPos = D.YourSpot.Position
	local function sitDown()
		local hrp = hrpOf() if not hrp then return end
		hrp.Anchored = true
		hrp.CFrame = CFrame.lookAt(seatPos, seatPos + Vector3.new(0, 0, -1))
	end
	sitDown()
	conn(player.CharacterAdded:Connect(function() task.wait(0.6) sitDown() end))

	-------------------------------------------------------- the road moves under the car
	local roadParts = {}
	for _, p in D.Road:GetDescendants() do if p:IsA("BasePart") then roadParts[p] = p.CFrame end end
	onCleanup(function() for p, cf in roadParts do p.CFrame = cf end end)
	local speed = 0 -- "mph" (shown on the speedometer)
	local targetSpeed = 40
	local moving = true
	conn(RunService.Heartbeat:Connect(function(dt)
		speed += (targetSpeed - speed) * math.min(1, dt * 0.6)
		if not moving then return end
		local dz = speed * 0.9 * dt
		for p in roadParts do
			local cf = p.CFrame + Vector3.new(0, 0, dz)
			if cf.Position.Z - O.Z > 340 then cf -= Vector3.new(0, 0, 700) end
			p.CFrame = cf
		end
	end))
	local speedo = car.Speedo.Display.Text
	local radioText = car.Radio.Display.Text
	conn(RunService.Heartbeat:Connect(function() speedo.Text = tostring(math.floor(speed + 0.5)) end))
	-- wipers swing faster as the rain and the speed pick up
	local wipers = {}
	for _, w in car:GetChildren() do if w.Name == "Wiper" then wipers[w] = w.CFrame end end
	onCleanup(function() for w, cf in wipers do w.CFrame = cf end end)
	local wiperOn = true
	local wipeT = 0
	conn(RunService.RenderStepped:Connect(function(dt)
		if not wiperOn then return end
		wipeT += dt * (1.8 + speed / 40)
		local a = math.sin(wipeT) * 0.9 + 0.9
		for w, cf in wipers do
			local pivot = cf * CFrame.new(0, 0, 1.6)
			w.CFrame = pivot * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.6)
		end
	end))
	-- sounds
	local wiperSnd = make("Sound", {SoundId = SFX.Wipers, Volume = 0.55, Looped = true}, SoundService) wiperSnd:Play()
	local engine = make("Sound", {SoundId = SFX.Engine, Volume = 0.25, Looped = true}, SoundService) engine:Play()
	local radio = make("Sound", {SoundId = SFX.Radio, Volume = 0.14, Looped = true, PlaybackSpeed = 0.97}, SoundService) radio:Play()
	make("EqualizerSoundEffect", {HighGain = -14, MidGain = -4, LowGain = 0}, radio)
	local heart = make("Sound", {SoundId = SFX.Heart, Volume = 0, Looped = true}, SoundService) heart:Play()
	conn(RunService.Heartbeat:Connect(function() engine.PlaybackSpeed = 0.7 + speed / 120 end))
	-- covering your ears muffles everything
	local muffle = {}
	for _, s in {wiperSnd, engine, radio} do muffle[s] = make("EqualizerSoundEffect", {HighGain = -30, MidGain = -16, LowGain = -2, Enabled = false}, s) end

	-------------------------------------------------------- panic
	local panic = 0
	local phase = "calm"
	local bar = make("Frame", {Size = UDim2.fromOffset(240, 16), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false, ZIndex = 16}, gui)
	make("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
	local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(240, 180, 90), BorderSizePixel = 0, ZIndex = 17}, bar)
	make("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
	local barLabel = make("TextLabel", {Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, 2), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 16,
		TextColor3 = Color3.fromRGB(230, 230, 240), Text = "\u{2665} panic   \u{b7}   hold [C] to cover your ears", ZIndex = 16}, bar)
	local function addPanic(n) if phase == "argue" then panic = math.clamp(panic + (covering and n * 0.85 or n * 1.8), 0, 100) end end
	conn(RunService.Heartbeat:Connect(function(dt)
		if phase ~= "argue" then return end
		panic = math.clamp(panic - (covering and 5 or 0.6) * dt + (speed > 75 and 3 * dt or 0), 0, 100)
		fill.Size = UDim2.fromScale(panic / 100, 1)
		fill.BackgroundColor3 = Color3.fromRGB(240, 180, 90):Lerp(Color3.fromRGB(230, 50, 50), panic / 100)
		heart.Volume = 0.15 + panic / 100 * 0.75
		heart.PlaybackSpeed = 1 + panic / 100 * 0.5
	end))
	conn(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.C then
			covering = true
			for _, e in muffle do e.Enabled = true end
			voice.TextTransparency = math.max(voice.TextTransparency, 0.75)
		end
	end))
	conn(UIS.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.C then
			covering = false
			for _, e in muffle do e.Enabled = false end
		end
	end))

	-------------------------------------------------------- things within reach
	local function prompt(part, action, object, hold)
		return make("ProximityPrompt", {ActionText = action, ObjectText = object or "", HoldDuration = hold or 0.3, MaxActivationDistance = 8, RequiresLineOfSight = false}, part)
	end
	local buckled = false
	local buckleP = prompt(car.Buckle, "Buckle up", "Seatbelt", 0.4)
	conn(buckleP.Triggered:Connect(function()
		if buckled then return end
		buckled = true buckleP.Enabled = false
		sfx(SFX.Buckle, 0.7)
		say("Click. You always buckle up first. You don't remember who taught you.", 4.5)
		setObjective("")
	end))
	local bearReadyAt = 0
	local bearP = prompt(car.Teddy.Body, "Hug the bear", "Teddy", 0.2)
	conn(bearP.Triggered:Connect(function()
		if os.clock() < bearReadyAt then return end
		bearReadyAt = os.clock() + 16
		panic = math.max(0, panic - 25)
		if phase == "argue" then say("You squeeze the bear as hard as you can.", 2.5) else say("The bear smells like the inside of this car.", 3) end
		bearP.Enabled = false
		task.delay(16, function() if alive then bearP.Enabled = true end end)
	end))
	local drew = false
	local fogP = prompt(car.Fog, "Draw on the window", "Foggy window", 0.6)
	conn(fogP.Triggered:Connect(function()
		if drew then return end
		drew = true fogP.Enabled = false
		local g = make("SurfaceGui", {Face = Enum.NormalId.Left, CanvasSize = Vector2.new(150, 110), LightInfluence = 0.3}, car.Fog)
		local function ln(x1, y1, x2, y2)
			local dx, dy = x2 - x1, y2 - y1
			make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(math.sqrt(dx*dx + dy*dy) + 4, 6), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
				Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = Color3.fromRGB(40, 50, 65), BackgroundTransparency = 0.2, BorderSizePixel = 0}, g)
		end
		ln(50, 35, 52, 45) ln(98, 35, 100, 45)
		for i = 0, 6 do local a1, a2 = math.rad(20 + i * 20), math.rad(20 + (i + 1) * 20) ln(75 + math.cos(a1) * 30, 55 + math.sin(a1) * 24, 75 + math.cos(a2) * 30, 55 + math.sin(a2) * 24) end
		panic = math.max(0, panic - 20)
		say("You draw a smiley face on the fogged-up window. It starts dripping right away.", 4)
	end))

	-------------------------------------------------------- he checks the mirror / the car swerves
	local mirror = make("Part", {Name = "RearMirror", Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(2.2, 0.7, 0.2),
		Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.Glass, CFrame = CFrame.new(O + Vector3.new(0, 7.1, -3.2))}, car)
	local mirrorGlow = make("PointLight", {Range = 6, Brightness = 0, Color = Color3.fromRGB(255, 60, 50)}, mirror)
	local grabbed = false
	local grabUI = make("TextLabel", {Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.42, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 44,
		TextColor3 = Color3.fromRGB(255, 220, 120), TextStrokeTransparency = 0.3, Text = "", ZIndex = 18}, gui)
	conn(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.F then grabbed = true end
	end))
	local function mirrorCheck()
		-- he looks at you in the mirror. Your hands had better not be over your ears.
		mirror.Material = Enum.Material.Neon mirror.Color = Color3.fromRGB(200, 40, 40)
		tween(mirrorGlow, 0.3, {Brightness = 2})
		speak("D", "Look at me when I'm talking to you.", 2.2)
		task.wait(1.6)
		if not alive then return end
		if covering then
			panic = math.clamp(panic + 30, 0, 100)
			say("He saw your hands over your ears.", 2.2)
		end
		mirror.Material = Enum.Material.Glass mirror.Color = Color3.fromRGB(25, 25, 30)
		tween(mirrorGlow, 0.5, {Brightness = 0})
	end
	local function swerve()
		-- the car lurches; grab the handle
		grabbed = false
		grabUI.Text = "GRAB THE HANDLE!  [F]"
		local t0 = os.clock()
		while alive and not grabbed and os.clock() - t0 < 1.2 do task.wait() end
		grabUI.Text = ""
		if not grabbed then
			panic = math.clamp(panic + 25, 0, 100)
			say("You slam into the door.", 2)
		else
			say("You hold on tight.", 1.6)
		end
	end

	-------------------------------------------------------- the argument
	local pHead = passenger and passenger:FindFirstChild("Head")
	local pHeadParts, pNeck = {}, nil
	if pHead then
		pNeck = CFrame.new(pHead.Position - Vector3.new(0, pHead.Size.Y / 2, 0))
		for _, p in passenger:GetChildren() do if p:IsA("BasePart") and (p == pHead or p.Name == "ScribbleFace" or p.Name:match("^Hair")) then pHeadParts[p] = pNeck:ToObjectSpace(p.CFrame) end end
		onCleanup(function() for p, o in pHeadParts do p.CFrame = pNeck * o end end)
	end
	local pYaw = 0
	local function turnHead(deg, t)
		if not pNeck then return end
		local start, from = os.clock(), pYaw
		local target = math.rad(deg)
		while alive and os.clock() - start < t do
			local f = (os.clock() - start) / t f = f * f * (3 - 2 * f)
			pYaw = from + (target - from) * f
			for p, o in pHeadParts do p.CFrame = pNeck * CFrame.Angles(0, pYaw, 0) * o end
			task.wait()
		end
		pYaw = target
		for p, o in pHeadParts do p.CFrame = pNeck * CFrame.Angles(0, pYaw, 0) * o end
	end
	local script = {
		{2.5, "P", "Can you slow down a little?", 8},
		{3, "D", "I'm fine.", 6, 50},
		{3.5, "P", "It's raining. There's a kid in the back.", 8},
		{3, "D", "I said I'm FINE.", 14, 60},
		{2, "D", "", 0, nil, "mirror"},
		{3.5, "D", "And turn that off.", 6, nil, "radio"},
		{3.5, "P", "Please. Just slow down.", 8, 70},
		{2, "P", "", 0, nil, "swerve"},
		{3, "D", "Don't tell me how to drive.", 12},
		{3, "P", "You're scaring \u{2014}", 6},
		{1.2, "D", "", 22, 82, "horn"},
		{3, "D", "Don't make me count to three.", 15},
		{1.5, "D", "", 0, nil, "mirror"},
		{3.5, "P", "", 0, nil, "turn"},
		{4, "P", "Hey. Hey. Cover your ears, okay? It's okay.", -15},
		{4, "D", "ONE.", 15, 90},
		{1.5, "P", "", 0, nil, "swerve"},
		{3, "D", "TWO.", 18, 96},
		{1.2, "D", "", 0, nil, "mirror"},
		{1.2, "P", "", 0, nil, "swerve"},
		{2.5, "P", "SLOW DOWN \u{2014}", 15},
	}
	local failed = false
	local function resetArgument()
		panic = 0 targetSpeed = 40 speed = 45
		radio.Volume = 0.14 radioText.Text = "FM 98.3"
		turnHead(0, 0.01)
	end
	local function runArgument()
		phase = "argue"
		bar.Visible = true
		for _, line in script do
			local t0 = os.clock()
			while alive and os.clock() - t0 < line[1] do
				if panic >= 100 then return false end
				task.wait(0.1)
			end
			if not alive then return false end
			if line[5] then targetSpeed = line[5] end
			if line[6] == "radio" then radio.Volume = 0 radioText.Text = "--" end
			if line[6] == "mirror" then mirrorCheck() end
			if line[6] == "swerve" then swerve() end
			if line[6] == "horn" then sfx(SFX.Horn, 0.8) say("He slams his hand on the wheel. The horn blares.", 2.5) end
			if line[6] == "turn" then
				task.spawn(turnHead, 160, 1.2)
				say("She turns around in her seat and looks at you. The smile drawn on her paper face is a little crooked.", 4.5)
			end
			if line[3] ~= "" then speak(line[2], line[3], line[1] + 0.5) end
			if line[4] < 0 then panic = math.max(0, panic + line[4]) else addPanic(line[4]) end
			if panic >= 100 then return false end
		end
		-- hold out to the end of the line, too
		task.wait(1)
		return panic < 100
	end

	-------------------------------------------------------- start
	say("The back seat of a car. It's night, and it's raining. You're small again.", 4.5)
	task.wait(5)
	say("The wipers go back and forth. The radio is on, very quietly.", 4)
	task.wait(4.5)
	setObjective("Buckle your seatbelt")
	while alive and not buckled do task.wait(0.2) end
	if not alive then return end
	task.wait(6)
	say("The two people up front haven't said a word. Then one of them does.", 4)
	task.wait(4.5)
	setObjective("Stay calm \u{b7} [C] cover ears (not when he looks in the mirror!) \u{b7} [F] grab the handle \u{b7} hug the bear")
	while alive do
		local ok = runArgument()
		if not alive then return end
		if ok then break end
		-- too much: black out, and it starts again
		phase = "out"
		bar.Visible = false
		voice.TextTransparency = 1
		say("It's too much. You squeeze your eyes shut and \u{2014}", 2.5)
		task.wait(1.5)
		fade.BackgroundColor3 = Color3.new(0, 0, 0)
		tween(fade, 0.6, {BackgroundTransparency = 0}).Completed:Wait()
		resetArgument()
		task.wait(1.5)
		tween(fade, 1.5, {BackgroundTransparency = 1})
		say("...You're back in the back seat. The rain hasn't stopped. It's starting again.", 4.5)
		task.wait(5)
	end

	-------------------------------------------------------- headlights. white. quiet.
	phase = "end"
	bar.Visible = false
	setObjective("")
	local on = make("Part", {Name = "Oncoming", Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(7, 0.8, 0.5), Color = Color3.fromRGB(255, 250, 230), Material = Enum.Material.Neon,
		CFrame = CFrame.new(O + Vector3.new(-1, 2.8, -300))}, workspace)
	local onBeam = make("SpotLight", {Face = Enum.NormalId.Back, Range = 60, Angle = 70, Brightness = 6, Color = Color3.fromRGB(255, 250, 230)}, on)
	sfx(SFX.Horn, 1, 0.8)
	tween(on, 2.2, {CFrame = CFrame.new(O + Vector3.new(-1, 2.8, -9))})
	task.wait(1.4)
	sfx(SFX.Screech, 1)
	task.wait(0.8)
	fade.BackgroundColor3 = Color3.new(1, 1, 1)
	fade.BackgroundTransparency = 0
	-- silence
	for _, s in {wiperSnd, engine, radio, heart} do s.Volume = 0 end
	moving = false wiperOn = false
	on:Destroy()
	local rainBox = D:FindFirstChild("RainBox")
	local pe = rainBox and rainBox:FindFirstChildOfClass("ParticleEmitter")
	if pe then setp(pe, {Enabled = false}) end
	if driver then local par = driver.Parent driver.Parent = nil onCleanup(function() driver.Parent = par end) end
	if passenger then local par = passenger.Parent passenger.Parent = nil onCleanup(function() passenger.Parent = par end) end
	setp(car.Headlights, {Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(60, 60, 60)})
	local beam = car.Headlights:FindFirstChildOfClass("SpotLight") if beam then setp(beam, {Enabled = false}) end
	-- cracks in the windshield
	local cg = make("SurfaceGui", {Face = Enum.NormalId.Bottom, CanvasSize = Vector2.new(420, 220), LightInfluence = 0.5}, car.Windshield)
	local rng = Random.new(3)
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextInteger(60, 200)
		make("Frame", {AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(len, 2), Position = UDim2.fromOffset(140, 90), Rotation = math.deg(a),
			BackgroundColor3 = Color3.fromRGB(230, 235, 240), BackgroundTransparency = 0.2, BorderSizePixel = 0}, cg)
	end
	task.wait(4)
	if not alive then return end
	tween(fade, 4, {BackgroundTransparency = 1})
	task.wait(4.5)
	say("Everything is very, very quiet.", 3.5)
	task.wait(4)
	say("The rain has stopped. The front seats are empty.", 4)
	task.wait(4.5)
	say("Your seatbelt is still buckled.", 4)
	task.wait(4.5)
	-- get out
	setObjective("Open the door")
	local doorSide = nil
	for _, d in car:GetChildren() do if d.Name == "Door" and d.Position.X > O.X then doorSide = d end end
	local openP = prompt(doorSide or car.Fog, "Open the door", "Car door", 0.8)
	local opened = false
	openP.Triggered:Connect(function() opened = true end)
	while alive and not opened do task.wait(0.2) end
	if not alive then return end
	openP:Destroy()
	setObjective("")
	local hrp = hrpOf()
	if hrp then
		local out = O + Vector3.new(7.5, 3, 2)
		hrp.CFrame = CFrame.lookAt(out, out + Vector3.new(0, 0, -1))
		hrp.Anchored = false
	end
	say("The road is empty. No other car. No lights. Only a door, standing in the road.", 5)
	if door then for p, t in doorParts do p.CanCollide = true TweenService:Create(p, TweenInfo.new(2.5), {Transparency = t}):Play() end end
	task.wait(2.6)
	if alive then ctx.unlockDoor(D, 14) end
end

return M
