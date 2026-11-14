-- School: Dream 7 "After Hours". An empty school at night. Everything here is local to the player.
--  Goal: open your locker (124). The 3-digit code is random each time; each digit is hidden somewhere
--        (Room 101 chalkboard, a test paper in Room 106, a drawing in the art room). The locker holds the key
--        for the chained front doors.
--  Danger: the hall monitor patrols with a flashlight. Hide in lockers/cupboards. Caught = back to the start.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PFS = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local CS = game:GetService("CollectionService")

local SFX = {
	Whistle = "rbxassetid://9118113825",
	Whistle2 = "rbxassetid://9118114334",
	Bell = "rbxassetid://9113583960",
	Buzz = "rbxassetid://9112823813",
	Locker = "rbxassetid://9116646197",
	Heart = "rbxassetid://9043365842",
	Step = "rbxassetid://85383897332935",
}
local ANIM = {Idle = "rbxassetid://507766666", Walk = "rbxassetid://507777826", Run = "rbxassetid://507767714"}

local CX, CZ, FY = 21000, 0, 501
local function W(x, z) return Vector3.new(CX + x, FY, CZ + z) end
local HALL = {W(-60, 0), W(-44, 0), W(-15, 0), W(0, 0), W(15, 0), W(44, 0), W(72, 0)}
local ROOMS = {W(-46, 22.5), W(0, 22), W(44, 22.5), W(-46, -22.5), W(44, -22.5), W(-15, -13)} -- aisles between desks
local DOORWAYS = {W(-44, 7), W(0, 7), W(44, 7), W(-44, -7), W(44, -7), W(-15, -7)}

local LINES = {
	spot = {"Out of class?", "You. Stop right there.", "No running in the halls."},
	lost = {"...I know you're still here.", "School ended hours ago.", "Hiding won't help you."},
	linger = {"I can hear you breathing."},
	leave = {"...Hmm.", "Not this time."},
	mumble = {"Everyone else went home.", "Why are you still here?", "Hall passes only.", "Someone should call your parents."},
}
local function pick(t) return t[math.random(#t)] end

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, fade, gui, active = ctx.pop, ctx.setObjective, ctx.tween, ctx.fade, ctx.gui, ctx.active
	local cam = workspace.CurrentCamera

	-------------------------------------------------------- bookkeeping
	local alive = true
	local cleanup, conns = {}, {}
	local function onCleanup(f) table.insert(cleanup, f) end
	local function conn(c) table.insert(conns, c) return c end
	local function make(class, props, parent)
		local i = Instance.new(class)
		for k, v in props do i[k] = v end
		i.Parent = parent
		onCleanup(function() i:Destroy() end)
		return i
	end
	local function setp(inst, props)
		local old = {}
		for k, v in props do old[k] = inst[k] inst[k] = v end
		onCleanup(function() for k, v in old do pcall(function() inst[k] = v end) end end)
	end
	local function sound(id, vol, parent, looped)
		return make("Sound", {SoundId = id, Volume = vol or 0.5, Looped = looped or false, RollOffMaxDistance = 100, RollOffMinDistance = 8}, parent or SoundService)
	end
	local function sfx(id, vol, parent, speed)
		local s = Instance.new("Sound")
		s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1 s.RollOffMaxDistance = 100 s.RollOffMinDistance = 8
		s.Parent = parent or SoundService s:Play()
		task.delay(14, function() s:Destroy() end)
		return s
	end
	local function hrpOf() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function humOf() local c = player.Character return c and c:FindFirstChildOfClass("Humanoid") end
	local function stat(k, v) player:SetAttribute("SC_" .. k, v) end

	-- narrator
	local popBusyUntil = 0
	local function say(text, hold) popBusyUntil = os.clock() + (hold or 3) + 0.5 pop(text, hold or 3) end
	local said = {}
	local function narrate(key, text, hold)
		if said[key] then return end
		said[key] = true
		task.spawn(function()
			local t0 = os.clock()
			repeat task.wait(0.4) until os.clock() >= popBusyUntil or os.clock() - t0 > 14
			if alive and not said.__stop then say(text, hold or 4.5) end
		end)
	end
	local function prompt(part, action, object, hold, dist)
		return make("ProximityPrompt", {ActionText = action, ObjectText = object or "", HoldDuration = hold or 0.25, MaxActivationDistance = dist or 8, RequiresLineOfSight = false}, part)
	end

	local debugEvent = make("BindableEvent", {Name = "SchoolDebug"}, player:WaitForChild("PlayerGui"))

	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
		cam.CameraType = Enum.CameraType.Custom
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		RunService:UnbindFromRenderStep("SchoolMouse")
	end
	task.spawn(function()
		while alive and active() do task.wait(0.3) end
		shutdown()
	end)

	-------------------------------------------------------- UI bits
	local speech = make("TextLabel", {Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0.78, 0), BackgroundTransparency = 1, Font = Enum.Font.SpecialElite, TextSize = 30, TextColor3 = Color3.fromRGB(235, 160, 70), TextStrokeTransparency = 0.4, Text = "", TextTransparency = 1, ZIndex = 4}, gui)
	local sayToken = 0
	local function monitorSay(text, hold)
		sayToken += 1 local my = sayToken
		speech.Text = "\u{201C}" .. text .. "\u{201D}" speech.TextTransparency = 0 speech.TextStrokeTransparency = 0.4
		task.delay(hold or 3, function() if sayToken == my then tween(speech, 0.6, {TextTransparency = 1, TextStrokeTransparency = 1}) end end)
	end
	local hint = make("TextLabel", {Size = UDim2.new(0, 420, 0, 26), Position = UDim2.new(0, 24, 0, 102), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 215), TextStrokeTransparency = 0.5, Text = ""}, gui)
	local flash = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7}, gui)
	local slats = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 3}, gui)
	for i = 0, 13 do
		make("Frame", {Size = UDim2.new(1, 0, 0.05, 0), Position = UDim2.new(0, 0, i * 0.075, 0), BackgroundColor3 = Color3.fromRGB(20, 26, 32), BackgroundTransparency = 0.02, BorderSizePixel = 0}, slats)
	end
	make("Frame", {Size = UDim2.new(0.3, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(20, 26, 32), BorderSizePixel = 0}, slats)
	make("Frame", {Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(20, 26, 32), BorderSizePixel = 0}, slats)
	make("TextLabel", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.9, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 22, TextColor3 = Color3.fromRGB(220, 220, 230), TextStrokeTransparency = 0.4, Text = "Hiding...  press E to come out", ZIndex = 4}, slats)

	-------------------------------------------------------- look & sound of the place
	workspace.Gravity = 196.2
	local function schoolHumanoid() local h = humOf() if h then h.WalkSpeed = 15 h.JumpPower = 38 end end
	schoolHumanoid()
	conn(player.CharacterAdded:Connect(function() task.wait(0.5) schoolHumanoid() end))
	local lights = {}
	for _, p in CS:GetTagged("SchoolLight") do if p:IsDescendantOf(D) then table.insert(lights, p) end end
	for _, p in lights do
		setp(p, {Material = p.Material})
		local l = p:FindFirstChildWhichIsA("Light") if l then setp(l, {Enabled = l.Enabled}) end
	end
	local function setLight(p, on)
		p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local l = p:FindFirstChildWhichIsA("Light") if l then l.Enabled = on end
	end
	-- a few lights are dead, the rest flicker now and then
	for i, p in lights do if i % 4 == 2 then setLight(p, false) end end
	task.spawn(function()
		while alive do
			task.wait(1 + math.random() * 3)
			local p = lights[math.random(#lights)]
			if p and p.Material == Enum.Material.Neon then
				for _ = 1, math.random(2, 5) do setLight(p, false) task.wait(0.05 + math.random() * 0.1) setLight(p, true) task.wait(0.04 + math.random() * 0.15) end
			end
		end
	end)
	local buzz = sound(SFX.Buzz, 0.12, SoundService, true) buzz:Play()
	local heart = sound(SFX.Heart, 0, SoundService, true) heart:Play()

	-- player flashlight
	local flashOn = false
	local flPart = make("Part", {Name = "SCFlashlight", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2)}, workspace)
	local spot = make("SpotLight", {Range = 45, Angle = 50, Brightness = 2.2, Shadows = true, Color = Color3.fromRGB(255, 240, 215), Enabled = false}, flPart)
	make("PointLight", {Range = 9, Brightness = 0.3, Shadows = false, Color = Color3.fromRGB(150, 165, 210)}, flPart)
	local function setFlash(on)
		flashOn = on spot.Enabled = on
		hint.Text = on and "\u{1F526} Flashlight ON  [F]  - he can see the light!" or "\u{1F526} Flashlight  [F]"
	end
	setFlash(false)
	conn(RunService.RenderStepped:Connect(function() flPart.CFrame = cam.CFrame * CFrame.new(0.5, -0.6, -0.5) end))

	-------------------------------------------------------- the code
	local code = {math.random(1, 9), math.random(0, 9), math.random(0, 9)}
	local known = {false, false, false}
	stat("Code", table.concat(code))
	local haveKey = false
	local lockerOpen = false
	local function codeText()
		local t = {}
		for i = 1, 3 do t[i] = known[i] and tostring(code[i]) or "_" end
		return table.concat(t, " ")
	end
	local phase = "find"
	local function objective()
		if phase == "find" then setObjective("Find a way out")
		elseif phase == "locker" then setObjective("Open locker 124   (code: " .. codeText() .. ")")
		elseif phase == "key" then setObjective("Take what's inside the locker")
		else setObjective("Unlock the front doors") end
	end
	local rooms = D.Rooms
	local board = rooms.Room101.Chalkboard
	board.BoardGui.Text.Text = "Don't forget:\n" .. code[1] .. "  _  _"
	local paper = rooms.Room106.TestPaper
	paper.SurfaceGui.Text.Text = "Name: ________\n\nSee me after class.\n\n_  " .. code[2] .. "  _"
	paper.SurfaceGui.Text.TextColor3 = Color3.fromRGB(190, 30, 30)
	local drawing = rooms.ArtRoom.ClueDrawing
	drawing.SurfaceGui.Text.Text = "\u{1F3E0}  \u{1F319}\n\n_  _  " .. code[3]
	local function learn(i, where)
		if known[i] then return end
		known[i] = true
		say(where .. "   \u{201C}" .. (i == 1 and (code[1] .. " _ _") or i == 2 and ("_ " .. code[2] .. " _") or ("_ _ " .. code[3])) .. "\u{201D}", 4.5)
		if phase == "find" then phase = "locker" end
		objective()
	end
	conn(prompt(board, "Read", "Chalkboard", 0.2, 14).Triggered:Connect(function() learn(1, "Chalk on the board:") end))
	conn(prompt(paper, "Read", "Test paper", 0.2, 7).Triggered:Connect(function() learn(2, "Scribbled in the margin:") end))
	conn(prompt(drawing, "Look", "Drawing", 0.2, 8).Triggered:Connect(function() learn(3, "In the corner of the drawing:") end))
	-- things to read that are just... things
	local attend = rooms.Room102:FindFirstChild("Attendance")
	if attend then conn(prompt(attend, "Read", "Attendance sheet", 0.2, 7).Triggered:Connect(function()
		say("An attendance sheet. One name is marked absent every day this month. The name is smudged.", 5)
	end)) end
	local note = rooms.Room105:FindFirstChild("CallHomeNote")
	if note then conn(prompt(note, "Read", "Sticky note", 0.2, 7).Triggered:Connect(function()
		say("\u{201C}Please call home.\u{201D}  The phone number is scribbled out. Twice.", 5)
	end)) end

	-------------------------------------------------------- the locker
	local mine = D.Lockers:FindFirstChild("MyLocker")
	local mineDoor = mine.Door
	local closedCF = mineDoor.CFrame
	local doorBits = {}
	for _, p in mine:GetChildren() do
		if p:IsA("BasePart") and p ~= mine.Body and p.Name ~= "Base" then doorBits[p] = closedCF:ToObjectSpace(p.CFrame) end
	end
	onCleanup(function() for p, o in doorBits do p.CFrame = closedCF * o end end)
	local function setDoor(cf) for p, o in doorBits do p.CFrame = cf * o end end
	-- combination UI
	local ui = make("Frame", {Size = UDim2.fromOffset(330, 220), Position = UDim2.new(0.5, -165, 0.5, -110), BackgroundColor3 = Color3.fromRGB(28, 32, 40), BackgroundTransparency = 0.05, Visible = false, ZIndex = 10}, gui)
	make("UICorner", {CornerRadius = UDim.new(0, 12)}, ui)
	make("TextLabel", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), Text = "Locker 124", ZIndex = 11}, ui)
	local digits = {0, 0, 0}
	local digitLabels = {}
	for i = 1, 3 do
		local x = 45 + (i - 1) * 85
		local up = make("TextButton", {Size = UDim2.fromOffset(70, 34), Position = UDim2.fromOffset(x, 40), BackgroundColor3 = Color3.fromRGB(60, 66, 80), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 20, Text = "\u{25B2}", ZIndex = 11}, ui)
		local lbl = make("TextLabel", {Size = UDim2.fromOffset(70, 50), Position = UDim2.fromOffset(x, 76), BackgroundColor3 = Color3.fromRGB(15, 17, 22), TextColor3 = Color3.fromRGB(240, 230, 200), Font = Enum.Font.Code, TextSize = 36, Text = "0", ZIndex = 11}, ui)
		local down = make("TextButton", {Size = UDim2.fromOffset(70, 34), Position = UDim2.fromOffset(x, 128), BackgroundColor3 = Color3.fromRGB(60, 66, 80), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 20, Text = "\u{25BC}", ZIndex = 11}, ui)
		digitLabels[i] = lbl
		conn(up.Activated:Connect(function() digits[i] = (digits[i] + 1) % 10 lbl.Text = tostring(digits[i]) end))
		conn(down.Activated:Connect(function() digits[i] = (digits[i] + 9) % 10 lbl.Text = tostring(digits[i]) end))
	end
	local openBtn = make("TextButton", {Size = UDim2.fromOffset(140, 36), Position = UDim2.fromOffset(25, 172), BackgroundColor3 = Color3.fromRGB(70, 140, 90), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 18, Text = "Open", ZIndex = 11}, ui)
	local closeBtn = make("TextButton", {Size = UDim2.fromOffset(140, 36), Position = UDim2.fromOffset(165, 172), BackgroundColor3 = Color3.fromRGB(110, 60, 60), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 18, Text = "Leave it", ZIndex = 11}, ui)
	for _, b in {openBtn, closeBtn} do make("UICorner", {CornerRadius = UDim.new(0, 8)}, b) end
	local uiOpen = false
	local function showUI(on)
		uiOpen = on ui.Visible = on
		local hrp = hrpOf() if hrp then hrp.Anchored = on end
	end
	RunService:BindToRenderStep("SchoolMouse", Enum.RenderPriority.Camera.Value + 4, function()
		if uiOpen then UIS.MouseBehavior = Enum.MouseBehavior.Default UIS.MouseIconEnabled = true end
	end)
	local investigate -- forward
	local lockP = prompt(mineDoor, "Open", "Locker 124", 0.2, 7)
	conn(lockP.Triggered:Connect(function()
		if lockerOpen then return end
		if phase == "find" then phase = "locker" objective() end
		showUI(true)
	end))
	conn(closeBtn.Activated:Connect(function() showUI(false) end))
	local inside -- forward
	local function tryOpen()
		if digits[1] == code[1] and digits[2] == code[2] and digits[3] == code[3] then
			showUI(false)
			lockerOpen = true lockP.Enabled = false
			sfx(SFX.Locker, 0.8, mineDoor)
			-- swing the door open on its left hinge
			local face = mineDoor.Position.Z > CZ and -1 or 1
			local hinge = closedCF * CFrame.new(-mineDoor.Size.X / 2, 0, 0)
			local t0 = os.clock()
			while os.clock() - t0 < 0.5 do
				local a = math.min((os.clock() - t0) / 0.5, 1) * math.rad(105) * face
				setDoor(hinge * CFrame.Angles(0, a, 0) * CFrame.new(mineDoor.Size.X / 2, 0, 0))
				task.wait()
			end
			phase = "key" objective()
			investigate(mineDoor.Position - Vector3.new(0, 4, 0), "...What was that?")
			inside.Transparency = 0
			for _, c in inside:GetChildren() do if c:IsA("BasePart") then c.Transparency = 0 end end
		else
			sfx(SFX.Locker, 0.35, mineDoor, 1.6)
			say("Click. It doesn't open.", 2)
		end
	end
	conn(openBtn.Activated:Connect(tryOpen))
	-- inside the locker: a key ring and half of a torn photo
	local body = mine.Body
	local inward = Vector3.new(0, 0, (body.Position.Z > mineDoor.Position.Z) and 1 or -1)
	inside = make("Part", {Name = "SC_Key", Anchored = true, CanCollide = false, Size = Vector3.new(0.6, 0.12, 0.35), CFrame = CFrame.new(body.Position + Vector3.new(0, -0.6, 0) - inward * 0.2) * CFrame.Angles(0, 0.5, 0), Color = Color3.fromRGB(205, 175, 80), Material = Enum.Material.Metal, Transparency = 1}, D)
	make("Part", {Name = "PhotoHalf", Anchored = true, CanCollide = false, Size = Vector3.new(0.05, 1, 0.75), CFrame = CFrame.new(body.Position + Vector3.new(0.4, 1.2, 0) + inward * 0.85) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(225, 215, 195), Material = Enum.Material.SmoothPlastic, Transparency = 1}, inside)
	make("PointLight", {Range = 4, Brightness = 0.7, Color = Color3.fromRGB(255, 225, 160)}, inside)
	local takeP = prompt(inside, "Take", "Key and photo", 0.4, 7)
	local function takeKey()
		if not lockerOpen or haveKey then return end
		haveKey = true takeP.Enabled = false
		inside.Transparency = 1
		for _, c in inside:GetChildren() do if c:IsA("BasePart") then c.Transparency = 1 elseif c:IsA("Light") then c.Enabled = false end end
		phase = "door" objective()
		say("A key... and the other half of a torn photo.", 4)
		task.delay(4.3, function() if alive then say("A tall figure, cut off at the shoulders.", 4) end end)
	end
	conn(takeP.Triggered:Connect(takeKey))

	-------------------------------------------------------- front doors
	local fd = D.FrontDoors
	local escaped = false
	local escape -- forward
	local function tryUnlock()
		if escaped then return end
		if not haveKey then
			say("A heavy padlock and a chain. You need a key.", 3.5)
			if phase == "find" then
				task.delay(3.8, function() if alive and phase == "find" then say("For some reason, you remember your locker number. 124.", 4.5) phase = "locker" objective() end end)
			end
			return
		end
		escape()
	end
	conn(prompt(fd.Padlock, "Unlock", "Front doors", 0.6, 8).Triggered:Connect(tryUnlock))

	-------------------------------------------------------- the hall monitor
	local template = D:FindFirstChild("HallMonitor")
	local mon = template:Clone()
	local tParent = template.Parent
	template.Parent = nil
	onCleanup(function() template.Parent = tParent end)
	for _, d in mon:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
	local root = mon:WaitForChild("HumanoidRootPart")
	for _, p in mon:GetDescendants() do
		if p:IsA("BasePart") then p.CanCollide = false p.CanTouch = false p.CanQuery = false p.Anchored = (p == root) end
	end
	local mhum = mon:FindFirstChildOfClass("Humanoid")
	mhum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	mhum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local hipOffset = root.Position.Y - FY
	mon.Name = "SchoolMonitor"
	mon.Parent = workspace
	onCleanup(function() mon:Destroy() end)
	local head = mon:WaitForChild("Head")
	local lens = mon:FindFirstChild("Lens")
	local beam = make("SpotLight", {Range = 42, Angle = 38, Brightness = 3, Shadows = true, Color = Color3.fromRGB(255, 245, 215), Face = Enum.NormalId.Front}, lens or head)
	local animator = mhum:FindFirstChildOfClass("Animator") or Instance.new("Animator", mhum)
	local tracks = {}
	for k, id in ANIM do
		local a = Instance.new("Animation") a.AnimationId = id
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then tracks[k] = tr end
	end
	local curTrack
	local function playAnim(name, speed)
		local tr = tracks[name] if not tr then return end
		if curTrack ~= tr then if curTrack then curTrack:Stop(0.25) end tr:Play(0.25) curTrack = tr end
		tr:AdjustSpeed(speed or 1)
	end
	local stepSound = sound(SFX.Step, 0.7, root) stepSound.RollOffMaxDistance = 70 stepSound.RollOffMinDistance = 6

	local function placeMon(floorPos, lookAt)
		local p = floorPos + Vector3.new(0, hipOffset, 0)
		local l = lookAt and Vector3.new(lookAt.X, p.Y, lookAt.Z) or (p + Vector3.new(-1, 0, 0))
		root.CFrame = CFrame.lookAt(p, l)
	end
	placeMon(W(72, 0), W(60, 0))

	local path = PFS:CreatePath({AgentRadius = 1.4, AgentHeight = 7, AgentCanJump = false, WaypointSpacing = 3})
	local waypoints, wpIndex = nil, 1
	local pathBusy = false
	local speed = 6
	local frozen = false
	local faceTarget = nil -- when standing still, turn toward this point
	local function feet() return root.Position - Vector3.new(0, hipOffset, 0) end
	local function goTo(target, onFail)
		if pathBusy then return end
		pathBusy = true
		task.spawn(function()
			local ok = pcall(function() path:ComputeAsync(feet(), target) end)
			if ok and path.Status == Enum.PathStatus.Success then waypoints = path:GetWaypoints() wpIndex = 2
			else waypoints = nil if onFail then onFail() end end
			pathBusy = false
		end)
	end
	local function arrived() return waypoints == nil or wpIndex > #waypoints end
	local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
	local stepClock = 0
	conn(RunService.Heartbeat:Connect(function(dt)
		if frozen then return end
		local pos = root.Position
		local newPos = pos
		local moving = false
		local want
		if waypoints and wpIndex <= #waypoints then
			local wp = waypoints[wpIndex].Position
			local target = Vector3.new(wp.X, FY + hipOffset, wp.Z)
			local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			local dist = flat.Magnitude
			local step = speed * dt
			if dist <= step then newPos = target wpIndex += 1
			else newPos = pos + flat.Unit * step end
			if dist > 0.2 then want = math.atan2(-flat.X, -flat.Z) end
			moving = true
		elseif faceTarget then
			local f = Vector3.new(faceTarget.X - pos.X, 0, faceTarget.Z - pos.Z)
			if f.Magnitude > 0.3 then want = math.atan2(-f.X, -f.Z) end
		end
		if want then
			local diff = (want - yaw + math.pi) % (2 * math.pi) - math.pi
			yaw += diff * math.min(1, dt * 6)
		end
		newPos = Vector3.new(newPos.X, FY + hipOffset, newPos.Z)
		root.CFrame = CFrame.new(newPos) * CFrame.Angles(0, yaw, 0)
		if moving then
			if speed > 9 then playAnim("Run", speed / 16) else playAnim("Walk", speed / 10) end
			stepClock += dt
			if stepClock > (speed > 9 and 0.33 or 0.62) then stepClock = 0 stepSound.PlaybackSpeed = 1.05 + math.random() * 0.15 stepSound:Play() end
		else
			playAnim("Idle", 1)
		end
	end))

	-- sight: his flashlight beam (a cone) - or you being right next to him
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function clearLine(a, b)
		local ignore = {mon, player.Character, flPart}
		for _ = 1, 8 do
			rayParams.FilterDescendantsInstances = ignore
			local r = workspace:Raycast(a, b - a, rayParams)
			if not r then return true end
			if r.Instance.Transparency > 0.8 or (not r.Instance.CanCollide and r.Instance.Transparency > 0.3) or r.Instance.Name == "Window" then
				table.insert(ignore, r.Instance)
			else return false end
		end
		return true
	end
	local hidden = nil
	local graceUntil = os.clock() + 12
	local function canSee(ignoreHidden)
		if hidden and not ignoreHidden then return false end
		if os.clock() < graceUntil then return false end
		local c = player.Character
		local ph = c and c:FindFirstChild("Head")
		if not ph then return false end
		local eye = head.Position
		local to = ph.Position - eye
		local d = to.Magnitude
		if d > (flashOn and 60 or 44) then return false end
		if d > 5 then
			local flatTo = Vector3.new(to.X, 0, to.Z)
			local facing = flatTo.Magnitude > 0 and root.CFrame.LookVector:Dot(flatTo.Unit) or 1
			if facing < 0.72 and not (flashOn and d < 25 and facing > -0.2) then return false end
		end
		return clearLine(eye, ph.Position)
	end

	-------------------------------------------------------- hiding (lockers + cupboards)
	local spots = {}
	for _, p in D:GetDescendants() do if p:IsA("BasePart") and p:GetAttribute("HideSpot") then table.insert(spots, p) end end
	local function frontOf(cl)
		local sum, n = Vector3.zero, 0
		for _, d in cl.Parent:GetChildren() do
			if (d.Name == "Door" or d.Name == "CupboardDoor") and (d.Position - cl.Position).Magnitude < 4 then sum += d.Position n += 1 end
		end
		local dir = n > 0 and (sum / n - cl.Position) or cl.CFrame.LookVector
		dir = Vector3.new(dir.X, 0, dir.Z)
		return dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)
	end
	local function doorsOf(cl)
		local t = {}
		for _, d in cl.Parent:GetChildren() do
			if d:IsA("BasePart") and d ~= cl and (d.Position - cl.Position).Magnitude < 4.5 and (d.Name == "Door" or d.Name == "CupboardDoor" or d.Name == "Vent") then table.insert(t, d) end
		end
		return t
	end
	local function exitHide()
		if not hidden then return end
		local cl = hidden hidden = nil
		stat("Hidden", false)
		slats.Visible = false
		for _, d in doorsOf(cl) do d.LocalTransparencyModifier = 0 end
		local f = frontOf(cl)
		local hrp = hrpOf()
		if hrp then
			local depth = math.abs(f.X) > 0.5 and cl.Size.X or cl.Size.Z
			local p = Vector3.new(cl.Position.X, FY + 3, cl.Position.Z) + f * (depth / 2 + 2.5)
			hrp.CFrame = CFrame.lookAt(p, p + f)
			hrp.Anchored = false
		end
		cam.CameraType = Enum.CameraType.Custom
	end
	local function eyeOf(cl)
		local f = frontOf(cl)
		local depth = math.abs(f.X) > 0.5 and cl.Size.X or cl.Size.Z
		return Vector3.new(cl.Position.X, FY + 5, cl.Position.Z) + f * (depth / 2 - 0.4), f
	end
	local function enterHide(cl)
		if hidden or frozen or uiOpen then return end
		local hrp = hrpOf() if not hrp then return end
		hidden = cl stat("Hidden", true)
		local eye, f = eyeOf(cl)
		hrp.Anchored = true
		hrp.CFrame = CFrame.lookAt(Vector3.new(cl.Position.X, FY + 3, cl.Position.Z) - f * 0.2, Vector3.new(cl.Position.X, FY + 3, cl.Position.Z) + f)
		for _, d in doorsOf(cl) do d.LocalTransparencyModifier = 0.9 end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(eye, eye + f * 10 - Vector3.new(0, 1.5, 0))
		slats.Visible = true
		if said.hide then say("Shh...", 1.5) else narrate("hide", "It smells like old sneakers in here. You've hidden in one of these before.", 4.5) end
	end
	for _, cl in spots do
		local target = cl
		if cl.Name == "Body" and cl.Parent:FindFirstChild("Door") then target = cl.Parent.Door end
		local pr = prompt(target, "Hide", cl.Name == "Body" and "Locker" or "Cupboard", 0.2, 6)
		conn(pr.Triggered:Connect(function() enterHide(cl) end))
	end
	conn(RunService.RenderStepped:Connect(function()
		if hidden then
			local eye, f = eyeOf(hidden)
			local m = UIS:GetMouseLocation()
			local ox = (m.X / cam.ViewportSize.X - 0.5) * 2
			cam.CFrame = CFrame.lookAt(eye, eye + f * 10 + f:Cross(Vector3.yAxis) * ox * 4 - Vector3.new(0, 1.5, 0))
		end
	end))
	conn(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.E and hidden then exitHide()
		elseif input.KeyCode == Enum.KeyCode.F and not hidden then setFlash(not flashOn) end
	end))

	-------------------------------------------------------- brain
	local state = "patrol"
	local function setState(s) state = s stat("MonState", s) end
	setState("patrol")
	local lastSeen, lastSeenAt = nil, 0
	local investigatePos
	local waitUntil = os.clock() + 10
	local nextMumble = os.clock() + 15
	local peekAt = nil
	investigate = function(pos, line)
		if state == "chase" or state == "caught" then return end
		investigatePos = pos setState("investigate") waypoints = nil faceTarget = nil
		if line then monitorSay(line, 3) end
	end
	local function playerFloor()
		local hrp = hrpOf() if not hrp then return nil end
		return Vector3.new(hrp.Position.X, FY, hrp.Position.Z)
	end
	local function spotted()
		lastSeen = playerFloor() lastSeenAt = os.clock()
		if state ~= "chase" then
			setState("chase") faceTarget = nil
			sfx(SFX.Whistle, 0.9, root)
			monitorSay(pick(LINES.spot), 2.5)
			task.delay(1.5, function() narrate("freeze", "You freeze for a second. Your body remembers being in trouble.", 4.5) end)
		end
	end
	local caughtCount = 0
	local function caught()
		if frozen then return end
		frozen = true setState("caught")
		caughtCount += 1 stat("Caught", caughtCount)
		if hidden then exitHide() end
		showUI(false)
		local hrp = hrpOf() if not hrp then frozen = false return end
		hrp.Anchored = true
		local eye = hrp.Position + Vector3.new(0, 1.5, 0)
		local away = Vector3.new(root.Position.X - hrp.Position.X, 0, root.Position.Z - hrp.Position.Z)
		away = away.Magnitude > 0.1 and away.Unit or -hrp.CFrame.LookVector
		local mpos = Vector3.new(hrp.Position.X, root.Position.Y, hrp.Position.Z) + away * 2.6
		root.CFrame = CFrame.lookAt(mpos, Vector3.new(hrp.Position.X, mpos.Y, hrp.Position.Z))
		cam.CameraType = Enum.CameraType.Scriptable
		-- he leans down to look at you
		local startCF = CFrame.lookAt(eye, head.Position)
		cam.CFrame = startCF
		TweenService:Create(cam, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {CFrame = CFrame.lookAt(eye, head.Position + Vector3.new(0, 0.6, 0)), FieldOfView = 45}):Play()
		heart.Volume = 1
		task.wait(0.9)
		sfx(SFX.Whistle2, 1)
		flash.BackgroundColor3 = Color3.new(1, 1, 1) flash.BackgroundTransparency = 0
		tween(flash, 0.5, {BackgroundColor3 = Color3.new(0, 0, 0)})
		task.wait(1.8)
		if not alive then return end
		cam.FieldOfView = 70
		player.Character:PivotTo(D.Start.CFrame + Vector3.new(0, 3, 0))
		hrp.Anchored = false
		cam.CameraType = Enum.CameraType.Custom
		placeMon(W(72, 0), W(60, 0))
		waypoints = nil faceTarget = nil
		graceUntil = os.clock() + 7 waitUntil = os.clock() + 5
		setState("patrol")
		frozen = false
		tween(flash, 1.5, {BackgroundTransparency = 1})
		if caughtCount == 1 then narrate("caught", "You end up back where you started. Like you never left.", 4.5)
		else say("...Back to the start.", 2.5) end
	end

	escape = function()
		escaped = true frozen = true
		said.__stop = true -- no more narrator lines queued from before the escape
		setObjective("") hint.Text = ""
		local hrp = hrpOf() if hrp then hrp.Anchored = true end
		setp(fd.Chain, {CanCollide = false}) setp(fd.Padlock, {CanCollide = false})
		for _, n in {"DoorL", "DoorR"} do
			local leaf = fd:FindFirstChild(n)
			if leaf then
				setp(leaf, {CanCollide = false, Transparency = leaf.Transparency})
				tween(leaf, 0.8, {Transparency = 1})
			end
		end
		for _, p in fd:GetChildren() do if p:IsA("BasePart") and p.Name ~= "ExitSign" then setp(p, {Transparency = p.Transparency}) tween(p, 0.8, {Transparency = 1}) end end
		make("PointLight", {Range = 40, Brightness = 5, Color = Color3.fromRGB(220, 225, 240)}, fd.ExitSign)
		local rain = sound("rbxassetid://9112853422", 0, SoundService, true) rain:Play() tween(rain, 2, {Volume = 0.5})
		tween(heart, 1, {Volume = 0}) tween(buzz, 1, {Volume = 0})
		task.wait(1)
		say("Outside, it's raining. Just like the day you watched that video.", 5)
		task.wait(5.5)
		if alive and ctx.goThrough then ctx.goThrough(7) end
	end

	-- debug: PlayerGui.SchoolDebug:Fire("code" | "grace" | "nograce" | "key")
	conn(debugEvent.Event:Connect(function(cmd)
		if cmd == "code" then for i = 1, 3 do known[i] = true end phase = "locker" objective()
		elseif cmd == "grace" then graceUntil = os.clock() + 9999
		elseif cmd == "nograce" then graceUntil = 0 waitUntil = 0
		elseif cmd == "key" then haveKey = true phase = "door" objective()
		elseif cmd == "wrong" then digits = {(code[1] + 1) % 10, 0, 0} tryOpen()
		elseif cmd == "solve" then digits = {code[1], code[2], code[3]} tryOpen()
		elseif cmd == "take" then takeKey()
		elseif cmd == "unlock" then tryUnlock()
		elseif cmd == "learn" then learn(1, "Chalk on the board:") learn(2, "Scribbled in the margin:") learn(3, "In the corner of the drawing:")
		end
	end))

	-------------------------------------------------------- start
	sfx(SFX.Bell, 0.4, SoundService, 0.85)
	say("A school hallway. You don't remember coming in.", 4.5)
	narrate("clock", "The clock says 3:15. Everyone went home hours ago. You didn't.", 5)
	task.delay(11, function() if alive and not escaped then objective() setFlash(false) end end)
	task.delay(16, function() if alive and not escaped then narrate("someone", "Someone else is here. Hide in a locker if he sees you.", 4) end end)
	stat("Caught", 0) stat("Hidden", false)

	-- proximity flavor
	local flavor = {
		{key = "mine", part = mineDoor, r = 7, text = "Locker 124. There's a little bear sticker on it. It's yours. You don't know how you know."},
		{key = "black", part = rooms.ArtRoom:FindFirstChild("BlackDrawing"), r = 9, text = "One drawing is colored completely black. Pressed so hard the paper tore."},
		{key = "art", part = rooms.ArtRoom:FindFirstChild("ClueDrawing"), r = 14, text = "Drawings of families. Smiling suns, green grass, holding hands."},
	}

	local lingerUntil = 0
	while alive and not escaped do
		task.wait(0.2)
		local hrp = hrpOf()
		if hrp then
			for _, f in flavor do
				if f.part and not said[f.key] and (f.part.Position - hrp.Position).Magnitude < f.r then
					narrate(f.key, f.text, 5)
					if f.key == "mine" and phase == "find" then phase = "locker" task.delay(5, objective) end
				end
			end
		end
		if frozen or not hrp then continue end
		local now = os.clock()
		local d = hrp.Position - root.Position
		local flatD = Vector3.new(d.X, 0, d.Z).Magnitude
		local want = math.clamp((32 - d.Magnitude) / 32, 0, 1) * 0.7
		if state == "chase" then want = math.max(want, 0.6) end
		heart.Volume += (want - heart.Volume) * 0.3

		local sees = canSee()
		if sees then spotted() end
		if not hidden and flatD < 3.6 and (state == "chase" or sees) and now > graceUntil then
			task.spawn(caught) continue
		end
		if now < waitUntil then continue end

		if state == "chase" then
			speed = 14
			if hidden then
				if now - lastSeenAt < 1.2 and flatD < 16 then
					setState("linger") lingerUntil = now + 6
					local eye, f = eyeOf(hidden)
					goTo(Vector3.new(eye.X, FY, eye.Z) + f * 3.5)
					faceTarget = Vector3.new(hidden.Position.X, FY, hidden.Position.Z)
					monitorSay(pick(LINES.linger), 3)
				else
					setState("search") investigatePos = lastSeen monitorSay(pick(LINES.lost), 3)
				end
			elseif sees then
				if not pathBusy then goTo(lastSeen) end
			elseif now - lastSeenAt > 4 then
				setState("search") investigatePos = lastSeen monitorSay(pick(LINES.lost), 3)
			elseif arrived() and not pathBusy and lastSeen then goTo(lastSeen) end
		elseif state == "linger" then
			speed = 6
			if not hidden then
				if canSee(true) or flatD < 9 then spotted() end
			elseif now > lingerUntil then
				monitorSay(pick(LINES.leave), 2.5)
				faceTarget = nil setState("patrol") waypoints = nil waitUntil = now + 1.5
			end
		elseif state == "search" or state == "investigate" then
			speed = 8
			if investigatePos then goTo(investigatePos, function() investigatePos = nil end) investigatePos = nil
			elseif arrived() and not pathBusy then waitUntil = now + 2.5 + math.random() * 2 setState("patrol") end
		else -- patrol: walk the hall, shine the light into rooms
			speed = 6.5
			if arrived() and not pathBusy then
				if waypoints then
					waypoints = nil
					-- look into the nearest doorway for a moment
					local best, bd
					for _, dw in DOORWAYS do local dd = (dw - feet()).Magnitude if not bd or dd < bd then best, bd = dw, dd end end
					if best and bd < 9 then
						faceTarget = best + (best - Vector3.new(best.X, FY, CZ)).Unit * 10
						waitUntil = now + 2.5 + math.random() * 2
					else
						faceTarget = nil
						waitUntil = now + 1 + math.random() * 2
					end
				else
					faceTarget = nil
					local target
					if math.random() < 0.3 then target = ROOMS[math.random(#ROOMS)]
					else
						-- usually a hallway spot, leaning toward where you are
						local sorted = table.clone(HALL)
						if math.random() < 0.5 then table.sort(sorted, function(a, b) return (a - hrp.Position).Magnitude < (b - hrp.Position).Magnitude end) target = sorted[math.random(1, 3)]
						else target = sorted[math.random(#sorted)] end
					end
					goTo(target)
				end
			end
			if now > nextMumble and flatD < 40 then nextMumble = now + 12 + math.random() * 10 monitorSay(pick(LINES.mumble), 3) end
		end
	end
end

return M
