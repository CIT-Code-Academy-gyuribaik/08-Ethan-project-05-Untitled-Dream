-- Nightmare: Dream 5 "Home". Everything here is local to the player (single-player horror).
--  Phase A  slowly wrong : find 3 memories - each one makes the house a little more wrong -> rest by the fire
--  Phase B  night        : Dad comes home drunk. Sneak, hide in closets, find the car keys, torn photo, music box
--  Phase C  run          : he knows. Run to the kitchen back door.
-- Caught = he swings at you (red flash), you wake up at a checkpoint. Violence is only ever shown as a scare.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CS = game:GetService("CollectionService")
local PFS = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local SFX = {
	Rain = "rbxassetid://9112853422",
	Heart = "rbxassetid://9043365842",
	MusicBox = "rbxassetid://139053896078359",
	Glass = "rbxassetid://9114591515",
	Hit = "rbxassetid://9113500009",
	Pound = "rbxassetid://9114140683",
	Step = "rbxassetid://85383897332935",
}
local ANIM = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Slash = "rbxassetid://522635514",
}

-- floor-level points (world) the father wanders between
local PATROL = {
	Vector3.new(12000, 501, 18),  -- foyer
	Vector3.new(11968, 501, 18),  -- living room
	Vector3.new(11968, 501, -12), -- library
	Vector3.new(12030, 501, 25),  -- dining
	Vector3.new(12030, 501, -28), -- kitchen
	Vector3.new(12000, 501, -31), -- back hall
	Vector3.new(12000, 518, -14), -- landing
	Vector3.new(11966, 518, 20),  -- master bedroom
	Vector3.new(11968, 518, -20), -- child's room
	Vector3.new(12028, 518, 10),  -- guest room
	Vector3.new(12028, 518, -20), -- study
}
local CHECKPOINT_B = Vector3.new(11966, 521.5, -16)  -- child's room
local CHECKPOINT_C = Vector3.new(12000, 521.5, -12)  -- top of the stairs

local LINES = {
	mumble = {"Where'd you go?", "Come out. I just wanna talk.", "*hic* ...who left this mess?", "You can't hide in here forever.", "I'm not mad. ...I'm not mad.", "I can hear you.", "Don't make me count to three."},
	spot = {"THERE you are.", "Don't you run from me!", "GET BACK HERE!"},
	lost = {"...Where'd you go?", "I'll find you.", "Fine. Hide."},
	linger = {"I know you're in there..."},
	leave = {"...Must be hearing things.", "Hmph."},
	hunt = {"THAT'S NOT YOURS!", "YOU'RE NOT LEAVING!", "GET BACK HERE!"},
}
local function pick(t) return t[math.random(#t)] end

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, fade, gui = ctx.pop, ctx.setObjective, ctx.tween, ctx.fade, ctx.gui
	local active = ctx.active
	local house = D.House
	-- narrator lines: second person, each said only once. They hint that this is familiar, never why.
	local rawPop = pop
	local popBusyUntil = 0
	pop = function(text, hold)
		popBusyUntil = os.clock() + (hold or 2.5) + 0.5
		rawPop(text, hold)
	end
	local said = {}
	local function narrate(key, text, hold, stillValid)
		if said[key] then return end
		said[key] = true
		task.spawn(function() -- wait for the current line to finish instead of talking over it
			local t0 = os.clock()
			repeat
				task.wait(0.4) -- let any line said at the same moment go first
			until os.clock() >= popBusyUntil or os.clock() - t0 > 14
			if not active() or (stillValid and not stillValid()) then return end
			pop(text, hold or 4.5)
		end)
	end
	local cam = workspace.CurrentCamera

	-------------------------------------------------------- bookkeeping: everything is undone if the dream is left
	local cleanup, conns = {}, {}
	local alive = true
	local function onCleanup(f) table.insert(cleanup, f) end
	local function conn(c) table.insert(conns, c) return c end
	local function setp(inst, props)
		local old = {}
		for k, v in props do old[k] = inst[k] inst[k] = v end
		onCleanup(function() for k, v in old do pcall(function() inst[k] = v end) end end)
	end
	local function hideLocal(inst)
		local par = inst.Parent
		inst.Parent = nil
		onCleanup(function() inst.Parent = par end)
	end
	local function make(class, props, parent)
		local i = Instance.new(class)
		for k, v in props do i[k] = v end
		i.Parent = parent
		onCleanup(function() i:Destroy() end)
		return i
	end
	local function sound(id, vol, parent, looped)
		return make("Sound", {SoundId = id, Volume = vol or 0.5, Looped = looped or false, RollOffMaxDistance = 90, RollOffMinDistance = 8}, parent or SoundService)
	end
	local function sfx(id, vol, parent, speed)
		local s = Instance.new("Sound")
		s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1 s.RollOffMaxDistance = 90 s.RollOffMinDistance = 8
		s.Parent = parent or SoundService
		s:Play()
		task.delay(12, function() s:Destroy() end)
		return s
	end

	local function hrpOf() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function humOf() local c = player.Character return c and c:FindFirstChildOfClass("Humanoid") end

	-------------------------------------------------------- UI: Dad's lines + hide overlay + hints
	local dadLine = make("TextLabel", {Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0.78, 0), BackgroundTransparency = 1, Font = Enum.Font.SpecialElite, TextSize = 30, TextColor3 = Color3.fromRGB(225, 70, 60), TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "", TextTransparency = 1, ZIndex = 4}, gui)
	local sayToken = 0
	local function dadSay(text, hold)
		sayToken += 1 local my = sayToken
		if text:find("count to three") then
			task.delay(2.8, function() narrate("count", "You catch yourself counting along. One... two...", 4) end)
		end
		dadLine.Text = "\u{201C}" .. text .. "\u{201D}" dadLine.TextTransparency = 0 dadLine.TextStrokeTransparency = 0.4
		task.delay(hold or 3, function() if sayToken == my then tween(dadLine, 0.6, {TextTransparency = 1, TextStrokeTransparency = 1}) end end)
	end
	local hint = make("TextLabel", {Size = UDim2.new(0, 420, 0, 26), Position = UDim2.new(0, 24, 0, 102), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 215), TextStrokeTransparency = 0.5, Text = ""}, gui)
	local red = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7}, gui)
	local slats = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 3}, gui)
	for i = 0, 9 do
		make("Frame", {Size = UDim2.new(1, 0, 0.045, 0), Position = UDim2.new(0, 0, i * 0.1 + 0.03, 0), BackgroundColor3 = Color3.fromRGB(12, 8, 5), BackgroundTransparency = 0.1, BorderSizePixel = 0, Rotation = 0}, slats)
	end
	make("Frame", {Size = UDim2.new(0.22, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(12, 8, 5), BorderSizePixel = 0}, slats)
	make("Frame", {Size = UDim2.new(0.22, 0, 1, 0), Position = UDim2.new(0.78, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(12, 8, 5), BorderSizePixel = 0}, slats)
	local leaveHint = make("TextLabel", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.9, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 22, TextColor3 = Color3.fromRGB(220, 220, 230), TextStrokeTransparency = 0.4, Text = "Hiding...  press E to come out", ZIndex = 4}, slats)

	-------------------------------------------------------- prompts / glints
	local function prompt(part, action, object, hold)
		return make("ProximityPrompt", {ActionText = action, ObjectText = object or "", HoldDuration = hold or 0.25, MaxActivationDistance = 9, RequiresLineOfSight = false}, part)
	end
	local function glint(part, color, range)
		return make("PointLight", {Color = color or Color3.fromRGB(255, 225, 160), Range = range or 5, Brightness = 0.8, Shadows = false}, part)
	end
	local function whenNotLooking(pos, timeout)
		local t0 = os.clock()
		while alive and os.clock() - t0 < (timeout or 25) do
			local dir = pos - cam.CFrame.Position
			if dir.Magnitude > 1 and cam.CFrame.LookVector:Dot(dir.Unit) < 0.2 then return end
			task.wait(0.2)
		end
	end

	-------------------------------------------------------- lamps
	local lamps = {}
	for _, p in CS:GetTagged("HouseLight") do if p:IsDescendantOf(house) then table.insert(lamps, p) end end
	local function lampsOn(on, color)
		for _, p in lamps do
			p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			for _, l in p:GetChildren() do if l:IsA("Light") then l.Enabled = on if color then l.Color = color end end end
		end
	end
	do -- remember original lamp state
		for _, p in lamps do
			setp(p, {Material = p.Material, Color = p.Color})
			for _, l in p:GetChildren() do if l:IsA("Light") then setp(l, {Enabled = l.Enabled, Color = l.Color, Brightness = l.Brightness}) end end
		end
	end
	local function flicker(times)
		for i = 1, times do
			lampsOn(false) task.wait(0.06 + math.random() * 0.12)
			lampsOn(true) task.wait(0.05 + math.random() * 0.2)
		end
	end

	-------------------------------------------------------- debug hook (testing): fire PlayerGui.NightmareDebug
	local debugEvent = make("BindableEvent", {Name = "NightmareDebug"}, player:WaitForChild("PlayerGui"))
	local debugSkip = nil
	conn(debugEvent.Event:Connect(function(cmd) debugSkip = cmd end))
	local function stat(k, v) player:SetAttribute("NM_" .. k, v) end
	stat("Phase", "A") stat("Items", 0) stat("DadState", "none") stat("Caught", 0) stat("Hidden", false)

	-------------------------------------------------------- watcher: leaving the dream undoes everything
	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
		cam.CameraType = Enum.CameraType.Custom
		stat("Phase", "off")
	end
	task.spawn(function()
		while alive and active() do task.wait(0.3) end
		shutdown()
	end)

	-- ====================================================================================
	-- PHASE A: slowly wrong
	-- ====================================================================================
	local father0 = house:FindFirstChild("Father")
	setObjective("Look around the house")
	local inside = false
	while alive and not inside and not debugSkip do
		local hrp = hrpOf()
		if hrp then
			local rel = hrp.Position - D.Start.Position
			if math.abs(rel.X) < 49 and rel.Z < -46 and rel.Z > -114 then inside = true end
		end
		task.wait(0.3)
	end
	if not alive then return end
	if not debugSkip then
		said.comfy = true
		pop("For some reason, you feel very comfortable in here.", 4)
		task.wait(5)
		pop("It smells like cookies and firewood.", 3)
		task.wait(3.5)
	end
	-- small moments while exploring in daylight
	local nightfall = false
	local function day() return not nightfall end
	task.spawn(function()
		task.wait(6)
		while alive and not nightfall do
			local hrp = hrpOf()
			if hrp then
				local p = hrp.Position
				if p.Y > 510 then narrate("stairs", "You skip one of the steps without thinking. You just know it creaks.", 4.5, day) end
				if p.Y > 515 and p.X < 11988 and p.Z < -6 then narrate("childroom", "Your hand reaches for the light switch before your eyes find it.", 4.5, day) end
				if father0 and father0.Parent and (father0:GetPivot().Position - p).Magnitude < 17 then
					narrate("face", "You don't want to look at his face. You're not sure why.", 4.5, day)
				end
				local sofa = house.LivingRoom.SofaSeat.Position
				if (sofa - p).Magnitude < 8 then narrate("sofa", "You somehow know which cushion is the softest.", 4, day) end
			end
			task.wait(0.4)
		end
	end)

	local found = 0
	local function wrongStep(n)
		if n == 1 then
			whenNotLooking(house.LivingRoom.Cat.Position, 30)
			if not alive then return end
			hideLocal(house.LivingRoom.Cat) hideLocal(house.LivingRoom.CatHead)
			for _, p in house.Foyer:GetChildren() do if p.Name == "Painting" then setp(p, {Color = Color3.fromRGB(15, 12, 12)}) end end
			for _, p in house.Landing:GetChildren() do if p.Name == "Painting" then setp(p, {Color = Color3.fromRGB(15, 12, 12)}) end end
			setp(house.Foyer.ClockFace, {Color = Color3.fromRGB(120, 20, 20)})
			task.wait(2)
			pop("The cat is gone. ...And the paintings have gone dark.", 4)
		elseif n == 2 then
			tween(Lighting, 10, {ClockTime = 19.0, Brightness = 0.9, Ambient = Color3.fromRGB(80, 60, 70), OutdoorAmbient = Color3.fromRGB(110, 80, 90)})
			local rain = sound(SFX.Rain, 0, SoundService, true) rain.Name = "NMRain" rain:Play()
			tween(rain, 8, {Volume = 0.35})
			if father0 then
				whenNotLooking(father0:GetPivot().Position, 30)
				if not alive then return end
				hideLocal(father0)
			end
			task.wait(1.5)
			pop("It's getting dark... Wasn't someone sitting in the dining room?", 4.5)
		elseif n == 3 then
			sfx(SFX.Glass, 0.5, SoundService, 0.9)
			flicker(4)
			setp(house.ChildRoom.Drawing, {Color = Color3.fromRGB(90, 15, 15)})
			pop("Something broke downstairs...", 3.5)
			task.wait(5)
			if alive then pop("...Was that drawing always red?", 3.5) end
		end
	end
	local mems = {
		{part = house.LivingRoom.Photo, action = "Look", obj = "Photo", text = "A family at a lake. The faces are too blurry to make out.", after = "You don't remember this trip. ...Do you?"},
		{part = house.Bedroom.Plush, action = "Pick up", obj = "Teddy bear", text = "An old teddy bear. It's been squeezed flat.", after = "Your hands remember exactly how hard to squeeze it."},
		{part = house.ChildRoom.Drawing, action = "Look", obj = "Drawing", text = "A crayon drawing of a house. ...This house.", after = "The name in the corner is smudged. The letters look a lot like yours."},
	}
	local function updateMemObjective() setObjective(("Look around (%d/3)"):format(found)) end
	if not debugSkip then
		updateMemObjective()
		pop("A few things here are glowing faintly...", 4)
		for _, m in mems do
			local g = glint(m.part)
			local pr = prompt(m.part, m.action, m.obj, 0.4)
			conn(pr.Triggered:Connect(function()
				pr.Enabled = false g.Enabled = false
				found += 1
				updateMemObjective()
				pop(m.text, 5)
				if m.after then task.delay(5.3, function() if alive then pop(m.after, 4.5) end end) end
				local n = found
				task.delay(5, function() if alive then wrongStep(n) end end)
			end))
		end
		while alive and found < 3 and not debugSkip do task.wait(0.3) end
		if not alive then return end
		if not debugSkip then task.wait(9) end
	end

	-- rest by the fire
	local rest = house.LivingRoom.SofaSeat:FindFirstChild("RestPrompt")
	if not debugSkip and rest then
		setObjective("Rest by the fire")
		pop("You suddenly feel very, very tired.", 3.5)
		rest.Enabled = true
		local rested = false
		local c = rest.Triggered:Connect(function() rested = true end)
		while alive and not rested and not debugSkip do task.wait(0.2) end
		c:Disconnect()
		rest.Enabled = false
		if not alive then return end
	end
	if debugSkip == "night" or debugSkip == "items" or debugSkip == "run" then debugSkip = debugSkip else debugSkip = nil end

	-- ====================================================================================
	-- PHASE B: night
	-- ====================================================================================
	nightfall = true
	setObjective("")
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	tween(fade, 2.5, {BackgroundTransparency = 0}).Completed:Wait()
	if not alive then return end
	pop("You drift off by the warm fire. You haven't slept this well in years.", 3.5)
	task.wait(3)

	-- night look
	Lighting.ClockTime = 0.3 Lighting.Brightness = 0.8
	Lighting.Ambient = Color3.fromRGB(42, 42, 60) Lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 90)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then atm.Density = 0.5 atm.Color = Color3.fromRGB(25, 25, 40) atm.Decay = Color3.fromRGB(10, 10, 22) atm.Haze = 1 atm.Glare = 0 end
	local cc = Lighting:FindFirstChild("PrologueCC")
	if cc then cc.Saturation = -0.4 cc.TintColor = Color3.fromRGB(195, 205, 240) cc.Brightness = 0 cc.Contrast = 0.14 end
	lampsOn(false)
	local fire = house.LivingRoom.Fire
	for _, k in fire:GetChildren() do if k:IsA("ParticleEmitter") or k:IsA("Light") then setp(k, {Enabled = false}) end end
	setp(fire, {Transparency = 1})
	workspace.Gravity = 196.2
	local function nightHumanoid()
		local h = humOf() if h then h.WalkSpeed = 16 h.JumpPower = 38 end
	end
	nightHumanoid()
	conn(player.CharacterAdded:Connect(function() task.wait(0.5) nightHumanoid() end))
	local rainS = SoundService:FindFirstChild("NMRain") or sound(SFX.Rain, 0.5, SoundService, true)
	rainS.Volume = 0.55 if not rainS.IsPlaying then rainS:Play() end
	local heart = sound(SFX.Heart, 0, SoundService, true) heart:Play()

	-- front doors shut and locked
	local M_ = house.Mansion
	local fdl, fdr = M_:FindFirstChild("FrontDoorL"), M_:FindFirstChild("FrontDoorR")
	if fdl and fdr then
		setp(fdl, {CFrame = CFrame.new(11998, 507, 29.25), CanCollide = true})
		setp(fdr, {CFrame = CFrame.new(12002, 507, 29.25), CanCollide = true})
		local lp = prompt(fdl, "Open", "Front door", 0.2)
		conn(lp.Triggered:Connect(function() pop("It won't open.", 2.5) end))
	end

	-- player wakes on the sofa
	local hrp0 = hrpOf()
	if hrp0 then
		local seat = house.LivingRoom.SofaSeat
		player.Character:PivotTo(CFrame.lookAt(seat.Position + Vector3.new(-3.5, 2.5, 0), seat.Position + Vector3.new(-12, 2.5, 0)))
	end

	-- flashlight
	local flashOn = false
	local flPart = make("Part", {Name = "NMFlashlight", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2)}, workspace)
	local spot = make("SpotLight", {Range = 50, Angle = 52, Brightness = 2.4, Shadows = true, Color = Color3.fromRGB(255, 238, 210), Enabled = false, Face = Enum.NormalId.Front}, flPart)
	local near = make("PointLight", {Range = 9, Brightness = 0.35, Shadows = false, Color = Color3.fromRGB(150, 160, 210)}, flPart)
	local function setFlash(on)
		flashOn = on spot.Enabled = on
		hint.Text = on and "🔦 Flashlight ON  [F]  - he can see the light!" or "🔦 Flashlight  [F]"
		stat("Flash", on)
	end
	setFlash(false)
	conn(RunService.RenderStepped:Connect(function()
		flPart.CFrame = cam.CFrame * CFrame.new(0.5, -0.6, -0.5)
	end))

	-------------------------------------------------------- the father
	local template = father0 or house:FindFirstChild("Father")
	local dad = template:Clone()
	for _, d in dad:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
	local pixels = dad:FindFirstChild("CensorPixels")
	if pixels then
		for _, d in pixels:GetDescendants() do if d:IsA("WeldConstraint") or d:IsA("Weld") then d:Destroy() end end
		for _, d in dad:GetDescendants() do
			if (d:IsA("WeldConstraint") or d:IsA("Weld")) and ((d.Part0 and d.Part0:IsDescendantOf(pixels)) or (d.Part1 and d.Part1:IsDescendantOf(pixels))) then d:Destroy() end
		end
	end
	local root = dad:WaitForChild("HumanoidRootPart")
	for _, p in dad:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false p.CanTouch = false p.CanQuery = false
			p.Anchored = (p == root) or (pixels ~= nil and p:IsDescendantOf(pixels))
		end
	end
	-- censor pixels: carried along with the head here (with the same broken-censor jitter)
	local pixelOffsets = {}
	if pixels then
		CS:RemoveTag(pixels, "CensorGlitch")
		local h0 = dad:FindFirstChild("Head")
		for _, px in pixels:GetChildren() do
			if px:IsA("BasePart") then pixelOffsets[px] = h0.CFrame:ToObjectSpace(px.CFrame) end
		end
	end
	local dhum = dad:FindFirstChildOfClass("Humanoid")
	dhum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	dhum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local floorY0 = 501
	local hipOffset = root.Position.Y - floorY0 -- template stands on the ground floor
	dad.Name = "Dad"
	dad.Parent = workspace
	onCleanup(function() dad:Destroy() end)
	local head = dad:WaitForChild("Head")

	local animator = dhum:FindFirstChildOfClass("Animator") or Instance.new("Animator", dhum)
	local tracks = {}
	for k, id in ANIM do
		local a = Instance.new("Animation") a.AnimationId = id
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then tracks[k] = tr end
	end
	local curTrack
	local function playAnim(name, speed)
		local tr = tracks[name]
		if not tr then return end
		if curTrack ~= tr then
			if curTrack then curTrack:Stop(0.25) end
			tr:Play(0.25) curTrack = tr
		end
		tr:AdjustSpeed(speed or 1)
	end

	local glitchAcc = 0
	conn(RunService.RenderStepped:Connect(function(dt)
		glitchAcc += dt
		local tick = glitchAcc > 0.07
		if tick then glitchAcc = 0 end
		local headCF = head.CFrame
		local burst = tick and math.random() < 0.08
		for px, off in pixelOffsets do
			local j = Vector3.zero
			if tick and (burst or math.random() < 0.12) then
				local s = burst and 0.35 or 0.12
				j = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, (math.random() - 0.5) * s)
			end
			px.CFrame = headCF * off + j
			if tick then px.Transparency = (math.random() < 0.04) and 1 or 0 end
		end
	end))

	local stepSound = sound(SFX.Step, 0.9, root)
	stepSound.RollOffMaxDistance = 70 stepSound.RollOffMinDistance = 6

	local function placeDad(floorPos, lookAt)
		local p = floorPos + Vector3.new(0, hipOffset, 0)
		local l = lookAt and Vector3.new(lookAt.X, p.Y, lookAt.Z) or (p + Vector3.new(0, 0, -1))
		if (l - p).Magnitude < 0.1 then l = p + Vector3.new(0, 0, -1) end
		root.CFrame = CFrame.lookAt(p, l)
	end
	placeDad(Vector3.new(12030, 501, -28), Vector3.new(12030, 501, -40)) -- starts in the kitchen

	-- movement along a computed path
	local path = PFS:CreatePath({AgentRadius = 1.6, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 3})
	local waypoints, wpIndex = nil, 1
	local pathBusy, pathGoal = false, nil
	local speed = 6
	local frozen = false
	local function feet() return root.Position - Vector3.new(0, hipOffset, 0) end
	local function goTo(target, onFail)
		if pathBusy then return end
		pathBusy = true pathGoal = target
		task.spawn(function()
			local ok = pcall(function() path:ComputeAsync(feet(), target) end)
			if ok and path.Status == Enum.PathStatus.Success then
				waypoints = path:GetWaypoints() wpIndex = 2
			else
				waypoints = nil
				if onFail then onFail() end
			end
			pathBusy = false
		end)
	end
	local function arrived() return waypoints == nil or wpIndex > #waypoints end

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.RespectCanCollide = true
	local function groundY(x, z, feetY)
		groundParams.FilterDescendantsInstances = {dad, player.Character}
		local r = workspace:Raycast(Vector3.new(x, feetY + 3, z), Vector3.new(0, -9, 0), groundParams)
		return r and r.Position.Y
	end
	local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
	local stepClock = 0
	local moving = false
	conn(RunService.Heartbeat:Connect(function(dt)
		if frozen then return end
		local t = os.clock()
		local pos = root.Position
		local newPos = pos
		moving = false
		if waypoints and wpIndex <= #waypoints then
			local wp = waypoints[wpIndex].Position
			local target = Vector3.new(wp.X, wp.Y + hipOffset, wp.Z)
			local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			local dist = flat.Magnitude
			local step = speed * dt
			if dist <= step then
				newPos = target
				wpIndex += 1
			else
				local frac = step / dist
				newPos = Vector3.new(pos.X + flat.X * frac, pos.Y + (target.Y - pos.Y) * frac, pos.Z + flat.Z * frac)
			end
			if dist > 0.2 then
				local want = math.atan2(-flat.X, -flat.Z)
				local diff = (want - yaw + math.pi) % (2 * math.pi) - math.pi
				yaw += diff * math.min(1, dt * 7)
			end
			moving = true
			-- stand on the real floor (pathfinding waypoint heights can float)
			local gy = groundY(newPos.X, newPos.Z, pos.Y - hipOffset)
			if gy then
				local wantY = gy + hipOffset
				newPos = Vector3.new(newPos.X, pos.Y + (wantY - pos.Y) * math.min(1, dt * 12), newPos.Z)
			end
		end
		local sway = math.sin(t * 1.7) * 0.07 -- drunk lean
		root.CFrame = CFrame.new(newPos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, sway)
		if moving then
			if speed > 9 then playAnim("Run", speed / 16) else playAnim("Walk", speed / 10) end
			stepClock += dt
			if stepClock > (speed > 9 and 0.34 or 0.6) then
				stepClock = 0
				stepSound.PlaybackSpeed = 0.85 + math.random() * 0.2
				stepSound:Play()
			end
		else
			playAnim("Idle", 1)
		end
	end))

	-- sight
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function clearLine(a, b)
		local ignore = {dad, player.Character, flPart}
		for _ = 1, 8 do
			rayParams.FilterDescendantsInstances = ignore
			local r = workspace:Raycast(a, b - a, rayParams)
			if not r then return true end
			if r.Instance.Transparency > 0.8 or (not r.Instance.CanCollide and r.Instance.Transparency > 0.3) then
				table.insert(ignore, r.Instance)
			else
				return false
			end
		end
		return true
	end
	local hidden = nil
	local graceUntil = os.clock() + 6
	local function canSee(ignoreHidden)
		if hidden and not ignoreHidden then return false end
		if os.clock() < graceUntil then return false end
		local c = player.Character
		local ph = c and c:FindFirstChild("Head")
		if not ph then return false end
		local eye = head.Position
		local to = ph.Position - eye
		local d = to.Magnitude
		if d > (flashOn and 42 or 28) then return false end
		if d > 6 then
			local look = root.CFrame.LookVector
			local flatTo = Vector3.new(to.X, 0, to.Z)
			local facing = flatTo.Magnitude > 0 and look:Dot(flatTo.Unit) or 1
			if facing < 0.55 and not (flashOn and d < 15) then return false end
		end
		return clearLine(eye, ph.Position)
	end
	local function playerFloor()
		local hrp = hrpOf()
		if not hrp then return nil end
		rayParams.FilterDescendantsInstances = {dad, player.Character, flPart}
		local r = workspace:Raycast(hrp.Position, Vector3.new(0, -12, 0), rayParams)
		return r and r.Position or (hrp.Position - Vector3.new(0, 3, 0))
	end

	-------------------------------------------------------- hiding
	local closets = {}
	for _, p in house:GetDescendants() do if p:IsA("BasePart") and p:GetAttribute("HideSpot") then table.insert(closets, p) end end
	local phase = "B"
	local savedCam
	local function closetFront(cl)
		local sum, n = Vector3.zero, 0
		for _, d in cl.Parent:GetChildren() do
			if d.Name == "WardrobeDoor" and (d.Position - cl.Position).Magnitude < 4 then sum += d.Position n += 1 end
		end
		local dir = n > 0 and (sum / n - cl.Position) or cl.CFrame.LookVector
		dir = Vector3.new(dir.X, 0, dir.Z)
		return dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)
	end
	local function closetDoors(cl)
		local t = {}
		for _, d in cl.Parent:GetChildren() do
			if (d.Name == "WardrobeDoor" or d.Name == "Knob") and (d.Position - cl.Position).Magnitude < 4 then table.insert(t, d) end
		end
		return t
	end
	local function exitHide()
		if not hidden then return end
		local cl = hidden
		hidden = nil
		stat("Hidden", false)
		slats.Visible = false
		for _, d in closetDoors(cl) do d.LocalTransparencyModifier = 0 end
		local front = closetFront(cl)
		local hrp = hrpOf()
		if hrp then
			local p = Vector3.new(cl.Position.X, cl.Position.Y - cl.Size.Y / 2 + 3, cl.Position.Z) + front * (cl.Size.Z / 2 + 2.5)
			hrp.CFrame = CFrame.lookAt(p, p + front)
			hrp.Anchored = false
		end
		cam.CameraType = Enum.CameraType.Custom
	end
	local function enterHide(cl)
		if hidden or frozen then return end
		if phase == "C" then pop("No time to hide! RUN!", 2) return end
		local hrp = hrpOf()
		if not hrp then return end
		hidden = cl
		stat("Hidden", true)
		local front = closetFront(cl)
		hrp.Anchored = true
		hrp.CFrame = CFrame.lookAt(cl.Position - front * 0.3 - Vector3.new(0, 1.2, 0), cl.Position - front * 0.3 - Vector3.new(0, 1.2, 0) + front)
		for _, d in closetDoors(cl) do d.LocalTransparencyModifier = 0.85 end
		cam.CameraType = Enum.CameraType.Scriptable
		local eye = cl.Position + front * (cl.Size.Z / 2 - 0.6) + Vector3.new(0, 1.3, 0)
		cam.CFrame = CFrame.lookAt(eye, eye + front * 10 - Vector3.new(0, 1, 0))
		slats.Visible = true
		if said.hide then pop("Shh...", 1.5) else narrate("hide", "You hold your breath. It comes naturally.", 3.5) end
	end
	for _, cl in closets do
		local pr = prompt(cl, "Hide", "Closet", 0.2)
		pr.MaxActivationDistance = 7
		conn(pr.Triggered:Connect(function() enterHide(cl) end))
	end
	conn(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.E and hidden then exitHide()
		elseif input.KeyCode == Enum.KeyCode.F and not hidden then setFlash(not flashOn) end
	end))
	-- small look-around while hidden (mouse moves the view a little)
	conn(RunService.RenderStepped:Connect(function()
		if hidden then
			local cl = hidden
			local front = closetFront(cl)
			local eye = cl.Position + front * (cl.Size.Z / 2 - 0.6) + Vector3.new(0, 1.3, 0)
			local m = UIS:GetMouseLocation()
			local vs = cam.ViewportSize
			local ox = (m.X / vs.X - 0.5) * 2
			local right = front:Cross(Vector3.yAxis)
			cam.CFrame = CFrame.lookAt(eye, eye + front * 10 + right * ox * 4 - Vector3.new(0, 1, 0))
		end
	end))

	-------------------------------------------------------- items
	local items = 0
	local itemNames = {}
	local function itemObjective()
		local function mark(n) return itemNames[n] and ("✓ " .. n) or n end
		if phase == "C" then return end
		setObjective(("Find a way out: %s · %s · %s"):format(mark("Keys"), mark("Torn photo"), mark("Music box")))
	end
	local investigate -- forward
	local startRun -- forward
	local function makeItem(name, cf, size, color, material, line)
		local p = make("Part", {Name = "NM_" .. name:gsub(" ", ""), Anchored = true, CanCollide = false, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic}, house)
		glint(p, Color3.fromRGB(255, 220, 150), 4)
		local pr = prompt(p, "Take", name, 0.5)
		conn(pr.Triggered:Connect(function()
			if itemNames[name] then return end
			itemNames[name] = true
			items += 1
			stat("Items", items)
			p.Transparency = 1 pr.Enabled = false
			for _, c in p:GetChildren() do if c:IsA("Light") then c.Enabled = false end end
			pop(line, 4)
			if name == "Music box" then
				local mb = sfx(SFX.MusicBox, 0.7, p)
				task.delay(6, function() if mb.Parent then tween(mb, 1, {Volume = 0}) end end)
				if items < 3 then investigate(p.Position - Vector3.new(0, 2, 0), "...What was that?") end
			end
			itemObjective()
			if items >= 3 then task.delay(1.5, function() if alive then startRun() end end) end
		end))
		return p
	end
	makeItem("Keys", CFrame.new(12040.6, 521.28, -31.3) * CFrame.Angles(0, 0.6, 0), Vector3.new(0.7, 0.12, 0.35), Color3.fromRGB(205, 170, 70), Enum.Material.Metal, "A ring of keys. One of them looks like a door key.")
	makeItem("Torn photo", CFrame.new(11974.2, 504.24, -21.8) * CFrame.Angles(0, -0.4, 0), Vector3.new(1, 0.05, 0.75), Color3.fromRGB(225, 215, 195), Enum.Material.SmoothPlastic, "Half of a torn photo. Someone is missing from it.")
	makeItem("Music box", CFrame.new(11980, 520.78, -36.5), Vector3.new(1.1, 0.75, 0.85), Color3.fromRGB(120, 70, 40), Enum.Material.Wood, "A little music box. It starts playing by itself.")

	-- back door (the way out)
	local backDoor = M_:FindFirstChild("BackDoor")
	local escaped = false
	local escape -- forward
	if backDoor then
		local bp = prompt(backDoor, "Open", "Back door", 0.6)
		conn(bp.Triggered:Connect(function()
			if phase ~= "C" then
				if not itemNames["Keys"] then pop("Locked. There has to be a key somewhere...", 3.5)
				else pop("Not yet. You're forgetting something.", 3.5) end
				return
			end
			bp.Enabled = false
			escape()
		end))
	end

	-------------------------------------------------------- brain
	local state = "patrol"
	local function setState(s) state = s stat("DadState", s) end
	stat("DadState", "patrol")
	local lastSeen, lastSeenAt = nil, 0
	local investigatePos = nil
	local waitUntil = 0
	local nextMumble = os.clock() + 8
	investigate = function(pos, line)
		if state == "chase" or state == "hunt" or state == "attack" then return end
		investigatePos = pos
		setState("investigate")
		waypoints = nil
		if line then dadSay(line, 3.5) end
	end
	local function farthestPatrolFrom(p)
		local best, bd = PATROL[1], -1
		for _, q in PATROL do local d = (q - p).Magnitude if d > bd then best, bd = q, d end end
		return best
	end
	local function patrolTarget()
		local hrp = hrpOf()
		if hrp and math.random() < 0.55 then
			-- drift toward the player's area
			local sorted = table.clone(PATROL)
			table.sort(sorted, function(a, b) return (a - hrp.Position).Magnitude < (b - hrp.Position).Magnitude end)
			return sorted[math.random(1, 3)]
		end
		return PATROL[math.random(#PATROL)]
	end

	-- getting caught
	local caughtCount = 0
	local function caught()
		if frozen then return end
		frozen = true
		setState("attack")
		caughtCount += 1 stat("Caught", caughtCount)
		if hidden then exitHide() end
		local hrp = hrpOf()
		if not hrp then frozen = false return end
		hrp.Anchored = true
		local eye = hrp.Position + Vector3.new(0, 1.5, 0)
		local away = Vector3.new(root.Position.X - hrp.Position.X, 0, root.Position.Z - hrp.Position.Z)
		away = away.Magnitude > 0.1 and away.Unit or -hrp.CFrame.LookVector
		local dpos = Vector3.new(hrp.Position.X, root.Position.Y, hrp.Position.Z) + away * 3.2
		root.CFrame = CFrame.lookAt(dpos, Vector3.new(hrp.Position.X, dpos.Y, hrp.Position.Z))
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(eye, head.Position)
		if tracks.Slash then
			if curTrack then curTrack:Stop(0.1) end
			tracks.Slash:Play(0.05) curTrack = tracks.Slash tracks.Slash:AdjustSpeed(0.8)
		end
		heart.Volume = 1
		task.wait(0.45)
		-- the swing
		local lunge = root.CFrame * CFrame.new(0, 0, -1.4)
		tween(root, 0.12, {CFrame = lunge}, Enum.EasingStyle.Quad)
		task.wait(0.1)
		sfx(SFX.Hit, 0.9)
		red.BackgroundColor3 = Color3.fromRGB(170, 0, 0) red.BackgroundTransparency = 0.05
		local base = cam.CFrame
		for i = 1, 8 do
			cam.CFrame = base * CFrame.Angles((math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.25, (math.random() - 0.5) * 0.4) * CFrame.new(0, -i * 0.12, 0)
			task.wait(0.03)
		end
		tween(red, 0.6, {BackgroundColor3 = Color3.new(0, 0, 0)})
		task.wait(1.6)
		if not alive then return end
		-- wake at the checkpoint
		local cp = phase == "C" and CHECKPOINT_C or CHECKPOINT_B
		player.Character:PivotTo(CFrame.new(cp))
		hrp.Anchored = false
		cam.CameraType = Enum.CameraType.Custom
		local far = phase == "C" and Vector3.new(11968, 501, -12) or farthestPatrolFrom(cp)
		placeDad(far, Vector3.new(12000, far.Y, 0))
		waypoints = nil
		graceUntil = os.clock() + (phase == "C" and 4 or 8)
		setState(phase == "C" and "hunt" or "patrol")
		waitUntil = os.clock() + (phase == "C" and 4 or 4)
		frozen = false
		tween(red, 1.5, {BackgroundTransparency = 1})
		if caughtCount == 1 and phase ~= "C" then
			narrate("caught", "You wake up curled in a corner. Somehow, that feels familiar too.", 4.5)
		else
			pop(phase == "C" and "Get up. RUN. The back door!" or "...Don't let him find you.", 3.5)
		end
	end

	startRun = function()
		phase = "C" stat("Phase", "C")
		if hidden then exitHide() end
		setObjective("RUN to the back door in the kitchen!")
		sfx(SFX.Glass, 0.8, root)
		dadSay("THAT'S NOT YOURS!", 3.5)
		pop("He knows. RUN!", 3)
		lampsOn(true, Color3.fromRGB(255, 30, 20))
		for _, p in lamps do p.Color = Color3.fromRGB(255, 40, 30) end
		if cc then cc.TintColor = Color3.fromRGB(255, 180, 180) end
		graceUntil = 0
		waitUntil = os.clock() + 3
		setState("hunt")
		task.spawn(function()
			while alive and phase == "C" and not escaped do
				task.wait(0.3 + math.random() * 1.2)
				if math.random() < 0.3 then
					for _, p in lamps do for _, l in p:GetChildren() do if l:IsA("Light") then l.Enabled = false end end end
					task.wait(0.08)
					for _, p in lamps do for _, l in p:GetChildren() do if l:IsA("Light") then l.Enabled = true end end end
				end
			end
		end)
	end

	escape = function()
		escaped = true
		frozen = true
		setState("gone")
		stat("Phase", "done")
		setObjective("")
		hint.Text = ""
		setFlash(false) hint.Text = ""
		local hrp = hrpOf()
		if hrp then hrp.Anchored = true end
		if backDoor then
			local hinge = backDoor.CFrame * CFrame.new(backDoor.Size.X / 2, 0, 0)
			local open = hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(-backDoor.Size.X / 2, 0, 0)
			setp(backDoor, {CanCollide = false})
			tween(backDoor, 0.8, {CFrame = open})
			make("PointLight", {Range = 40, Brightness = 6, Color = Color3.fromRGB(255, 250, 235)}, backDoor)
		end
		dadSay("NO-", 1.2)
		task.wait(0.6)
		fade.BackgroundColor3 = Color3.new(1, 1, 1)
		tween(fade, 1.6, {BackgroundTransparency = 0})
		tween(heart, 1.5, {Volume = 0})
		tween(rainS, 3, {Volume = 0})
		task.wait(2.2)
		if not alive then return end
		dad.Parent = nil
		ctx.title.TextColor3 = Color3.fromRGB(60, 50, 70)
		ctx.sub.TextColor3 = Color3.fromRGB(60, 50, 70)
		ctx.titleCard("You got out.", "...didn't you?")
		task.wait(0.8)
		ctx.title.TextColor3 = Color3.new(1, 1, 1)
		ctx.sub.TextColor3 = Color3.new(1, 1, 1)
		if ctx.goThrough then ctx.goThrough(5) end -- on to the next dream
	end

	-- spot the player
	local function spotted()
		local hrp = hrpOf()
		lastSeen = playerFloor() lastSeenAt = os.clock()
		if state ~= "chase" and state ~= "hunt" then
			setState("chase")
			waitUntil = os.clock() + 1.0 -- he needs a moment to react: a head start
			dadSay(pick(LINES.spot), 2.5)
			task.delay(1.2, function() narrate("run", "Your legs move before you decide to run. Like they've done this before.", 4) end)
			red.BackgroundColor3 = Color3.fromRGB(150, 0, 0) red.BackgroundTransparency = 0.75
			tween(red, 0.8, {BackgroundTransparency = 1})
		end
	end

	-- wake-up sequence
	tween(fade, 3, {BackgroundTransparency = 1})
	task.wait(1.5)
	sfx(SFX.Pound, 0.9)
	task.wait(1.2)
	sfx(SFX.Glass, 0.7, root)
	dadSay("...WHERE IS EVERYBODY?", 4)
	task.wait(2.5)
	narrate("yell", "You jump a bit at the yell. It's unsettlingly familiar.", 4)
	task.wait(5)
	pop("Someone is in the house. You need to get out.", 4)
	stat("Phase", "B")
	itemObjective()
	setFlash(false)
	task.delay(4.5, function() if alive then pop("Hide in a closet if he sees you.  [F] flashlight", 4) end end)
	graceUntil = os.clock() + 8
	waitUntil = os.clock() + 8

	-- debug skips
	conn(debugEvent.Event:Connect(function(cmd)
		if cmd == "items" or cmd == "run" then
			itemNames = {["Keys"] = true, ["Torn photo"] = true, ["Music box"] = true} items = 3 stat("Items", 3)
			startRun()
		elseif cmd == "freeze" then frozen = not frozen
		elseif cmd == "grace" then graceUntil = os.clock() + 9999
		elseif cmd == "nograce" then graceUntil = 0
		end
	end))
	if debugSkip == "items" or debugSkip == "run" then debugEvent:Fire("run") end

	local lingerUntil, lingerCloset = 0, nil
	while alive and not escaped do
		task.wait(0.2)
		if frozen then continue end
		local now = os.clock()
		local hrp = hrpOf()
		if not hrp then continue end
		local d = (hrp.Position - root.Position)
		local flatD = Vector3.new(d.X, 0, d.Z).Magnitude
		-- heartbeat gets louder when he is close
		local want = math.clamp((34 - d.Magnitude) / 34, 0, 1) * 0.8
		if state == "chase" or state == "hunt" then want = math.max(want, 0.65) end
		heart.Volume += (want - heart.Volume) * 0.3

		if flatD < 16 and math.abs(d.Y) < 6 and state ~= "chase" and state ~= "hunt" then
			narrate("steps", "You know the sound of those footsteps. Heavy heel first.", 4.5)
		end
		local sees = canSee()
		if sees then spotted() end

		-- caught?
		if not hidden and flatD < 3 and math.abs(d.Y) < 5 and (state == "chase" or state == "hunt" or state == "search" or sees) and now > graceUntil then
			task.spawn(caught)
			continue
		end
		if now < waitUntil then continue end

		if state == "hunt" then
			speed = 11.5 + math.sin(now * 0.9) * 0.8
			if not pathBusy then goTo(playerFloor() or hrp.Position) end
			if math.random() < 0.025 then dadSay(pick(LINES.hunt), 2.5) end
		elseif state == "chase" then
			speed = 10.5 + math.sin(now * 1.3) * 1.2 -- drunk: uneven
			if hidden then
				-- did he see you get in?
				if now - lastSeenAt < 1.2 and flatD < 16 then
					setState("linger") lingerCloset = hidden lingerUntil = now + 6
					local f = closetFront(hidden)
					goTo(Vector3.new(hidden.Position.X, hidden.Position.Y - hidden.Size.Y / 2, hidden.Position.Z) + f * 4)
					dadSay(pick(LINES.linger), 3)
				else
					setState("search") investigatePos = lastSeen
					dadSay(pick(LINES.lost), 3)
				end
			elseif sees then
				if not pathBusy then goTo(lastSeen) end
			elseif now - lastSeenAt > 2.5 then
				setState("search") investigatePos = lastSeen
				dadSay(pick(LINES.lost), 3)
			elseif arrived() and not pathBusy and lastSeen then
				goTo(lastSeen)
			end
		elseif state == "linger" then
			speed = 6
			if not hidden then
				-- you came out while he was standing there
				if canSee(true) or flatD < 10 then spotted() end
			elseif now > lingerUntil then
				dadSay(pick(LINES.leave), 2.5)
				setState("patrol") waypoints = nil waitUntil = now + 1.5
			end
		elseif state == "search" or state == "investigate" then
			speed = state == "search" and 8 or 7
			if investigatePos then
				goTo(investigatePos, function() investigatePos = nil end)
				investigatePos = nil
			elseif arrived() and not pathBusy then
				waitUntil = now + 2.5 + math.random() * 2
				setState("patrol")
			end
		else -- patrol
			speed = 6 + math.sin(now * 0.7) * 0.8
			if arrived() and not pathBusy then
				if waypoints then
					waypoints = nil
					waitUntil = now + 1.5 + math.random() * 3 -- stands there swaying
					if math.random() < 0.25 then sfx(SFX.Glass, 0.6, root, 0.9 + math.random() * 0.2) end
				else
					goTo(patrolTarget())
				end
			end
			if now > nextMumble and flatD < 45 then
				nextMumble = now + 9 + math.random() * 8
				dadSay(pick(LINES.mumble), 3)
			end
		end
	end
end

return M
