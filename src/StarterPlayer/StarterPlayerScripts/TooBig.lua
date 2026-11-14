-- TooBig: Dream 11 "Too Big" (Chapter 2). Your own apartment, but everything is three times bigger.
-- Part 1, the room: get three big books to the door to make a staircase up to the handle.
--   one is on the bottom shelf, one is up on the desk (crayon box -> chair -> desk), one is on the bed (pillow -> bed).
--   Heavy footsteps come down the hall at random times; when they stop at your door, hide under the desk.
--   If it catches you out in the open, someone puts your last book back.
-- Part 2, the hallway: something enormous walks up and down. You only see it up to the knees.
--   Sneak from cover to cover to the Dream Door at the far end. If it sees you, you're back at the door.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local SFX = {
	Step = "rbxassetid://85383897332935",
	Heart = "rbxassetid://9043365842",
	Drag = "rbxassetid://9113577920",
	Creak = "rbxassetid://9116646197",
	Thud = "rbxassetid://9114140683",
}

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, active, gui = ctx.pop, ctx.setObjective, ctx.tween, ctx.active, ctx.gui
	local O = Vector3.new(33000, 500, 0)
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
	local function sfx(id, vol, parent, speed)
		local s = Instance.new("Sound") s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1 s.RollOffMinDistance = 10 s.RollOffMaxDistance = 160
		s.Parent = parent or SoundService s:Play() task.delay(10, function() s:Destroy() end) return s
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
	local function prompt(part, action, object, hold, dist)
		return make("ProximityPrompt", {ActionText = action, ObjectText = object or "", HoldDuration = hold or 0.3, MaxActivationDistance = dist or 9, RequiresLineOfSight = false}, part)
	end
	local function glint(part)
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 225, 160) l.Range = 9 l.Brightness = 1 l.Shadows = false l.Parent = part
		local s = Instance.new("Sparkles") s.SparkleColor = Color3.fromRGB(255, 235, 180) s.Parent = part
		local function off() l:Destroy() s:Destroy() end
		onCleanup(off)
		return off
	end
	local dark = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 14}, gui)

	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
	end
	task.spawn(function() while alive and active() do task.wait(0.3) end shutdown() end)
	local function smallBody() local h = humOf() if h then h.UseJumpPower = true h.JumpPower = 32 h.WalkSpeed = 14 end end
	smallBody()
	conn(player.CharacterAdded:Connect(function() task.wait(0.6) smallBody() end))
	local timesCaught = 0
	local function caughtCount() timesCaught += 1 player:SetAttribute("TB_Caught", timesCaught) end

	-- the Dream Door waits at the end of the hallway (hidden until the end)
	local door = D:FindFirstChild("Door")
	local doorParts = {}
	if door then
		for _, p in door:GetDescendants() do if p:IsA("BasePart") then doorParts[p] = p.Transparency p.Transparency = 1 p.CanCollide = false end end
		onCleanup(function() for p, t in doorParts do p.Transparency = t p.CanCollide = true end end)
	end

	local R = D.Apartment.Room
	local roomDoor, knob, gap = R.Door, R.DoorKnob, R.DoorGap
	local doorCF, knobCF = roomDoor.CFrame, knob.CFrame
	onCleanup(function() roomDoor.CFrame = doorCF knob.CFrame = knobCF roomDoor.CanCollide = true end)
	local hideZone = D.HideZone
	local function isHidden()
		local hrp = hrpOf() if not hrp then return false end
		local l = hideZone.CFrame:PointToObjectSpace(hrp.Position)
		return math.abs(l.X) < hideZone.Size.X / 2 and math.abs(l.Y) < hideZone.Size.Y / 2 + 2 and math.abs(l.Z) < hideZone.Size.Z / 2
	end
	local doorOpen = false

	-------------------------------------------------------- the books -> a staircase under the handle
	local spot = D.StackSpot.Position
	local stack = {}
	local knobP -- forward
	local function objective()
		if doorOpen then return end
		if #stack < 3 then setObjective(("Get 3 books to the door (%d/3) \u{b7} hide under the desk when it stops"):format(#stack))
		else setObjective("Climb the books and turn the handle") end
	end
	local function stackCF(level) return CFrame.new(spot + Vector3.new(0, 1.5 + (level - 1) * 3, -5 + (level - 1) * 2.5)) * CFrame.Angles(0, 0, math.rad(90)) end
	local function moveBook(b, cf, t)
		local kids = {} for _, k in b:GetChildren() do if k:IsA("BasePart") then kids[k] = b.CFrame:ToObjectSpace(k.CFrame) end end
		local tw = tween(b, t, {CFrame = cf})
		local c = RunService.Heartbeat:Connect(function() for k, o in kids do k.CFrame = b.CFrame * o end end)
		task.delay(t + 0.05, function() c:Disconnect() for k, o in kids do k.CFrame = b.CFrame * o end end)
		return tw
	end
	local books = {
		{part = D.Books.Book1, kind = "shelf", fall = nil, lines = "A book as big as a mattress. You drag it all the way to the door."},
		{part = D.Books.Book2, kind = "high", fall = CFrame.new(O + Vector3.new(19, 1.5, -19)) * CFrame.Angles(0, 0.4, math.rad(90)), lines = "It slams onto the floor. The whole room shakes. ...Did anyone hear that?"},
		{part = D.Books.Book3, kind = "high", fall = CFrame.new(O + Vector3.new(-5, 1.5, -17)) * CFrame.Angles(0, -0.3, math.rad(90)), lines = "It slides off the bed and lands with a soft thump."},
	}
	local stackLines = {"One step.", "Two. Your arms are shaking. It's only a book.", "Three. If you stand on top, you might just reach."}
	local pass -- forward
	local passing = false
	local function addToStack(bk)
		bk.stage = "moving"
		table.insert(stack, bk)
		local level = #stack
		sfx(SFX.Drag, 0.8, bk.part, 0.7)
		moveBook(bk.part, stackCF(level), 2.4)
		task.wait(2.5)
		bk.stage = "stacked"
		objective()
		say(stackLines[level], 3.5)
		if level == 3 then knobP.Enabled = true end
	end
	local setupBook
	setupBook = function(bk)
		bk.origin = bk.origin or bk.part.CFrame
		bk.stage = bk.kind
		if bk.prompt then bk.prompt:Destroy() end
		if bk.unglint then bk.unglint() end
		bk.unglint = glint(bk.part)
		if bk.kind == "shelf" then
			bk.prompt = prompt(bk.part, "Pull out", "Big book", 0.8, 10)
		else
			bk.prompt = prompt(bk.part, "Push off", "Big book", 0.6, 8)
		end
		bk.prompt.Triggered:Connect(function()
			if passing then say("Not now. Hide!", 2) return end
			if bk.stage == "shelf" or bk.stage == "floor" then
				bk.prompt.Enabled = false bk.unglint()
				if bk.stage == "shelf" then say(bk.lines, 4.5) end
				addToStack(bk)
			elseif bk.stage == "high" then
				bk.prompt.Enabled = false
				bk.stage = "falling"
				moveBook(bk.part, bk.fall, 0.7)
				task.wait(0.75)
				sfx(SFX.Thud, 0.9, bk.part, 0.8)
				say(bk.lines, 4)
				bk.stage = "floor"
				bk.prompt.ActionText = "Drag to the door"
				bk.prompt.MaxActivationDistance = 10
				bk.prompt.Enabled = true
				-- a loud noise: the footsteps come sooner
				if bk.part == D.Books.Book2 then task.delay(4, function() if alive and not passing and not doorOpen then pass() end end) end
			end
		end)
	end
	for _, bk in books do
		bk.origin = bk.part.CFrame
		local o = bk.origin
		onCleanup(function() bk.part.CFrame = o for _, k in bk.part:GetChildren() do if k:IsA("BasePart") then k.CFrame = o * CFrame.new(0, 2, 1.95) end end end)
		setupBook(bk)
	end
	local function putBack()
		local bk = table.remove(stack)
		if not bk then return false end
		moveBook(bk.part, bk.origin, 0.1)
		setupBook(bk)
		if #stack < 3 then knobP.Enabled = false end
		objective()
		return true
	end

	-------------------------------------------------------- the footsteps in the hallway (random times)
	local stepper = make("Part", {Name = "Steps", Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(O + Vector3.new(-20, 3, 36))}, workspace)
	local feet = {}
	for i = 1, 2 do
		feet[i] = make("Part", {Name = "FootShadow", Anchored = true, CanCollide = false, CanQuery = false, Color = Color3.fromRGB(8, 6, 6), Material = Enum.Material.SmoothPlastic,
			Size = Vector3.new(2.6, 0.28, 0.2), Transparency = 1, CFrame = gap.CFrame * CFrame.new(-8, 0, -0.5)}, workspace)
	end
	local calm = false -- (testing) no footsteps
	pass = function()
		if passing or not alive or doorOpen or calm then return end
		passing = true
		local walking = true
		task.spawn(function()
			local x = -16
			while alive and walking do
				x = math.min(x + 2, 0)
				stepper.CFrame = CFrame.new(O + Vector3.new(x, 3, 36))
				sfx(SFX.Step, 0.4 + (16 + x) / 16 * 0.6, stepper, 0.75)
				if x > -8 then for i, f in feet do f.Transparency = 0.1 f.CFrame = gap.CFrame * CFrame.new(x + (i == 1 and -1.6 or 1.6), 0, -0.5) end end
				if x >= 0 then walking = false end
				task.wait(0.55)
			end
		end)
		if not said.firstSteps then said.firstSteps = true say("Footsteps in the hallway. Heavy heel first. You know that sound.", 3.5) end
		while alive and walking do task.wait(0.15) end
		if not alive then return end
		setObjective("Hide under the desk!")
		say("It stopped at your door.", 2.5)
		local heart = make("Sound", {SoundId = SFX.Heart, Volume = 0.7, Looped = true, PlaybackSpeed = 1.25}, SoundService)
		heart:Play()
		task.wait(3.5)
		if not alive then return end
		if isHidden() then
			say("You hold your breath under the desk. The shadow stays there for a long, long time.", 4)
			task.wait(4.5)
		else
			caughtCount()
			say("The handle starts to turn. Slowly.", 2.2)
			for i = 1, 10 do knob.CFrame = knobCF * CFrame.Angles(0, 0, math.rad(i * 6)) task.wait(0.1) end
			sfx(SFX.Creak, 0.6, knob, 0.6)
			tween(dark, 0.5, {BackgroundTransparency = 0}).Completed:Wait()
			knob.CFrame = knobCF
			local tookOne = putBack()
			local hrp = hrpOf()
			if hrp then local st = D.Start.Position hrp.CFrame = CFrame.lookAt(st + Vector3.new(0, 3, 0), st + Vector3.new(0, 3, -10)) end
			task.wait(1)
			tween(dark, 1.5, {BackgroundTransparency = 1})
			if tookOne then
				say("...You're back on the rug. One of the books is back where it was. Someone put it back.", 5)
			else
				say("...You're back on the rug, curled up small. The footsteps are gone.", 4.5)
			end
		end
		for _, f in feet do f.Transparency = 1 end
		for k = 1, 4 do sfx(SFX.Step, 0.6 - k * 0.12, stepper, 0.75) stepper.CFrame = CFrame.new(O + Vector3.new(k * 3, 3, 40 + k * 3)) task.wait(0.6) end
		tween(heart, 1.5, {Volume = 0}) task.delay(1.6, function() heart:Destroy() end)
		objective()
		passing = false
	end
	-- random visits while you work
	task.spawn(function()
		task.wait(16)
		while alive and not doorOpen do
			if not passing then pass() end
			task.wait(22 + math.random() * 16)
		end
	end)

	-------------------------------------------------------- the handle
	knobP = prompt(knob, "Turn the handle", "Door", 1.2, 7)
	knobP.Enabled = false
	local hallway -- forward
	conn(knobP.Triggered:Connect(function()
		if passing then say("Not now. Hide!", 2) return end
		knobP.Enabled = false
		doorOpen = true
		setObjective("")
		say("The handle is so heavy. You hang on it with your whole body.", 3.5)
		for i = 1, 10 do knob.CFrame = knobCF * CFrame.Angles(0, 0, math.rad(i * 6)) task.wait(0.08) end
		sfx(SFX.Creak, 0.7, roomDoor, 0.5)
		local hinge = doorCF * CFrame.new(-roomDoor.Size.X / 2, 0, 0)
		local knobRel, doorRel = hinge:ToObjectSpace(knob.CFrame), hinge:ToObjectSpace(doorCF)
		roomDoor.CanCollide = false
		local t0 = os.clock()
		local c c = RunService.Heartbeat:Connect(function()
			local a = math.clamp((os.clock() - t0) / 2.5, 0, 1)
			local r = hinge * CFrame.Angles(0, -math.rad(95) * (1 - (1 - a) ^ 2), 0)
			roomDoor.CFrame = r * doorRel knob.CFrame = r * knobRel
			if a >= 1 then c:Disconnect() end
		end)
		task.wait(2.6)
		hallway()
	end))

	-------------------------------------------------------- part 2: the hallway, and what walks in it
	local G = D.Giant
	local gParts = {}
	for _, p in G:GetDescendants() do if p:IsA("BasePart") then gParts[p] = p:GetAttribute("T") or 0 end end
	local gHome = G:GetPivot()
	onCleanup(function() G:PivotTo(gHome) for p in gParts do p.Transparency = 1 end end)
	local footL, footR = G.FootL, G.FootR
	local legL, legR = G.LegL, G.LegR
	local cuffL, cuffR = G.CuffL, G.CuffR
	-- remember each part relative to the pair's centre so we can walk it
	local function centre() return (footL.Position + footR.Position) / 2 end
	local base = CFrame.new(centre())
	local rel = {}
	for p in gParts do rel[p] = base:ToObjectSpace(p.CFrame) end
	local gPos = Vector3.new(O.X, O.Y, O.Z + 80)
	local gYaw = 0 -- 0 = facing -z (toward the room)
	local gTarget = nil
	local gSpeed = 6.5
	local gWait = 0
	local stride = 0
	local gActive = false
	local function placeGiant()
		local cf = CFrame.new(gPos) * CFrame.Angles(0, gYaw, 0)
		local lift = math.max(0, math.sin(stride)) * 1.6
		local lift2 = math.max(0, -math.sin(stride)) * 1.6
		for p, o in rel do
			local up = 0
			if p == footL or p == legL or p == cuffL then up = lift elseif p == footR or p == legR or p == cuffR then up = lift2 end
			p.CFrame = cf * o + Vector3.new(0, up, 0)
		end
	end
	-- the giant is YOU: a copy of your own avatar, four times bigger (a grown-up, next to how small you are here)
	local me, meRoot, meHip, meTracks, meCur = nil, nil, 0, {}, nil
	local function buildMe()
		local ch = player.Character
		if not ch then return false end
		local ok = pcall(function()
			local was = ch.Archivable
			ch.Archivable = true
			me = ch:Clone()
			ch.Archivable = was
		end)
		if not ok or not me then me = nil return false end
		for _, d in me:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Sound") then d:Destroy() end
		end
		local h = me:FindFirstChildOfClass("Humanoid")
		if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff h.NameDisplayDistance = 0 end
		me.Name = "GrownUp"
		meRoot = me:FindFirstChild("HumanoidRootPart")
		if not meRoot then me:Destroy() me = nil return false end
		for _, p in me:GetDescendants() do
			if p:IsA("BasePart") then p.CanCollide = false p.CanQuery = false p.CanTouch = false p.Anchored = (p == meRoot) p.LocalTransparencyModifier = 0 end
		end
		me.Parent = workspace
		onCleanup(function() if me then me:Destroy() end end)
		me:ScaleTo(4)
		if h then
			for _, st in {Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Physics, Enum.HumanoidStateType.Seated} do pcall(function() h:SetStateEnabled(st, false) end) end
			h.PlatformStand = false
		end
		-- stand on the floor: root height = hip height + half the root (R15), or leg length + half the root (R6)
		if h and h.RigType == Enum.HumanoidRigType.R15 then
			meHip = h.HipHeight + meRoot.Size.Y / 2
		else
			local leg = me:FindFirstChild("Left Leg")
			meHip = meRoot.Size.Y / 2 + (leg and leg.Size.Y or meRoot.Size.Y)
		end
		me:PivotTo(CFrame.new(gPos + Vector3.new(0, meHip, 0)))
		-- measure where the feet really are and lift the whole thing onto the floor
		task.wait(0.2)
		local lowest = math.huge
		for _, p in me:GetDescendants() do
			if p:IsA("BasePart") and p ~= meRoot and not p:FindFirstAncestorOfClass("Accessory") then
				local hy = 0.5 * (math.abs(p.CFrame.RightVector.Y) * p.Size.X + math.abs(p.CFrame.UpVector.Y) * p.Size.Y + math.abs(p.CFrame.LookVector.Y) * p.Size.Z)
				lowest = math.min(lowest, p.Position.Y - hy)
			end
		end
		if lowest < math.huge then meHip += (gPos.Y - lowest) end
		-- the giant body sags a little under its own weight; keep its feet on the floor
		task.spawn(function()
			while alive and me and me.Parent do
				task.wait(0.4)
				local low = math.huge
				for _, n in {"LeftFoot", "RightFoot", "Left Leg", "Right Leg"} do
					local f = me:FindFirstChild(n)
					if f then low = math.min(low, f.Position.Y - f.Size.Y / 2) end
				end
				if low < math.huge then
					local err = gPos.Y - low
					if math.abs(err) > 0.2 then meHip += err * 0.8 end
				end
			end
		end)
		local animator = h and (h:FindFirstChildOfClass("Animator") or Instance.new("Animator", h))
		local r15 = h and h.RigType == Enum.HumanoidRigType.R15
		local ids = r15 and {Walk = "rbxassetid://507777826", Idle = "rbxassetid://507766666"} or {Walk = "rbxassetid://180426354", Idle = "rbxassetid://180435571"}
		for k, id in ids do
			local a = Instance.new("Animation") a.AnimationId = id
			local ok2, tr = pcall(function() return animator:LoadAnimation(a) end)
			if ok2 then meTracks[k] = tr end
		end
		-- hide the blocky stand-in legs
		for p in gParts do p.Transparency = 1 end
		return true
	end
	local function placeMe(moving)
		if not me or not meRoot then return end
		meRoot.CFrame = CFrame.new(gPos + Vector3.new(0, meHip, 0)) * CFrame.Angles(0, gYaw, 0)
		local want = moving and meTracks.Walk or meTracks.Idle
		if want and meCur ~= want then if meCur then meCur:Stop(0.3) end want:Play(0.3) want:AdjustSpeed(moving and 0.55 or 1) meCur = want end
	end
	local stepSnd = make("Sound", {SoundId = SFX.Step, Volume = 1, RollOffMinDistance = 10, RollOffMaxDistance = 120, PlaybackSpeed = 0.7}, footL)
	conn(RunService.Heartbeat:Connect(function(dt)
		if not gActive then return end
		local movingNow = false
		if gTarget and os.clock() > gWait then
			local d = Vector3.new(gTarget.X - gPos.X, 0, gTarget.Z - gPos.Z)
			if d.Magnitude < 0.4 then
				gTarget = nil
			else
				local want = math.atan2(-d.X, -d.Z)
				local diff = (want - gYaw + math.pi) % (2 * math.pi) - math.pi
				gYaw += diff * math.min(1, dt * 4)
				gPos += d.Unit * math.min(gSpeed * dt, d.Magnitude)
				movingNow = true
				local before = math.sin(stride)
				stride += dt * 5
				if (before > 0) ~= (math.sin(stride) > 0) then stepSnd.PlaybackSpeed = 0.65 + math.random() * 0.1 stepSnd:Play() end
			end
		end
		placeGiant()
		placeMe(movingNow)
	end))
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function seesYou()
		local hrp = hrpOf() if not hrp then return false end
		local flat = Vector3.new(hrp.Position.X - gPos.X, 0, hrp.Position.Z - gPos.Z)
		if flat.Magnitude > 11 then return false end
		local eye = gPos + Vector3.new(0, 6, 0) -- it's knee-height to us, and it doesn't look down well
		rayParams.FilterDescendantsInstances = {G, player.Character}
		local r = workspace:Raycast(eye, (hrp.Position + Vector3.new(0, 1.5, 0)) - eye, rayParams)
		return r == nil
	end
	hallway = function()
		if not alive then return end
		for p, t in gParts do p.Transparency = t end
		buildMe()
		gActive = true
		placeGiant()
		placeMe(false)
		setObjective("Sneak to the end of the hallway. Stay behind things.")
		say("Something enormous is walking in the hallway.", 3.5)
		task.wait(4.8)
		say("Those are your shoes. Your clothes. ...Your face. It's you. A grown-up you, towering over the small one.", 5)
		task.wait(5)
		say("It hasn't noticed you. Stay behind things. Don't let it see you.", 4)
		-- patrol: up and down the hall, weaving a little, pausing
		task.spawn(function()
			local lanes = {53, 59, 65, 71, 77, 82}
			local dir = -1
			local idx = #lanes
			while alive and gActive do
				idx += dir
				if idx < 1 then idx = 2 dir = 1 elseif idx > #lanes then idx = #lanes - 1 dir = -1 end
				gTarget = Vector3.new(O.X + (math.random() * 4 - 2), O.Y, O.Z + lanes[idx])
				while alive and gTarget do task.wait(0.1) end
				if math.random() < 0.35 then gWait = os.clock() + 1.2 + math.random() * 1.5 end
				task.wait(0.1)
			end
		end)
		-- watch for being seen / reaching the end
		local start = O + Vector3.new(0, 3, 37)
		while alive and gActive do
			task.wait(0.1)
			local hrp = hrpOf()
			if hrp then
				if hrp.Position.Z - O.Z > 85 then break end
				if hrp.Position.Z - O.Z > 31 and seesYou() then
					caughtCount()
					gActive = false
					say("It stops. The shoes turn toward you, very slowly.", 2.5)
					local d = Vector3.new(hrp.Position.X - gPos.X, 0, hrp.Position.Z - gPos.Z)
					local t0 = os.clock()
					while os.clock() - t0 < 1.2 do
						local want = math.atan2(-d.X, -d.Z)
						gYaw += ((want - gYaw + math.pi) % (2 * math.pi) - math.pi) * 0.15
						placeGiant() placeMe(false) task.wait()
					end
					tween(dark, 0.6, {BackgroundTransparency = 0}).Completed:Wait()
					hrp.CFrame = CFrame.lookAt(start, start + Vector3.new(0, 0, 10))
					gPos = Vector3.new(O.X, O.Y, O.Z + 80) gYaw = 0 gTarget = nil gWait = os.clock() + 2
					placeGiant() placeMe(false)
					task.wait(0.8)
					tween(dark, 1.2, {BackgroundTransparency = 1})
					say("...You're back by your door. It's walking again, like nothing happened.", 4)
					gActive = true
				end
			end
		end
		if not alive then return end
		-- made it
		gTarget = nil
		setObjective("")
		say("It never looks down. You never did either.", 4)
		if door then for p, t in doorParts do p.CanCollide = true TweenService:Create(p, TweenInfo.new(2.5), {Transparency = t}):Play() end end
		task.wait(2.6)
		if alive then ctx.unlockDoor(D, 11) end
	end

	-------------------------------------------------------- things to notice
	local spots = {
		{key = "bed", pos = D.Apartment.Furniture.Bed.Mattress.Position, r = 16, text = "Your bed. There's a book up there. The pillow on the floor might help."},
		{key = "mirror", pos = D.Apartment.Furniture.Wardrobe.Mirror.Position, r = 14, text = "The mirror is so high up, you can't see yourself in it at all."},
		{key = "desk", pos = hideZone.Position, r = 10, text = "Under the desk. It feels safe down here. It always did."},
		{key = "crayons", pos = D.Steps.CrayonBox.Position, r = 9, text = "A box of crayons as big as a step. The black one is worn down to a stub."},
	}
	task.spawn(function()
		while alive do
			local hrp = hrpOf()
			if hrp then for _, sp in spots do if not said[sp.key] and (Vector3.new(sp.pos.X, hrp.Position.Y, sp.pos.Z) - hrp.Position).Magnitude < sp.r then narrate(sp.key, sp.text, 4.5) end end end
			task.wait(0.4)
		end
	end)

	-------------------------------------------------------- start
	say("Your room. But everything is so big. Or you're so small.", 4.5)
	task.wait(5)
	say("The door handle is way up there. You'll need books to stand on. One's on the shelf... the others are up high.", 5.5)
	objective()
	-- debug hook for testing: PlayerGui.TooBigDebug:Fire("stack"/"open")
	local dbg = make("BindableEvent", {Name = "TooBigDebug"}, player:WaitForChild("PlayerGui"))
	conn(dbg.Event:Connect(function(cmd)
		if cmd == "stack" then for _, bk in books do if bk.stage ~= "stacked" then bk.prompt.Enabled = false bk.unglint() task.spawn(addToStack, bk) task.wait(2.7) end end
		elseif cmd == "open" then knobP.Enabled = true
		elseif cmd == "calm" then calm = true end
	end))
end

return M
