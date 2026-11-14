-- Hospital: Dream 10 "Visiting Hours". Night. Visiting hours are over, but you need to get to Room 12.
-- Sign in -> take the yellow flowers -> get past the orderly in the hall (hide in supply rooms) -> Room 12.
-- In the room: flowers in the vase, sit with her, hold her hand. She is gone.
-- Then you run, in shock. Room 12 shuts behind you. The nurse from the desk stops you at the exit -> the Dream Door appears.
-- Nothing ever says who she is.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UIS = game:GetService("UserInputService")

local SFX = {
	Beep = "rbxassetid://9119141141",
	Flat = "rbxassetid://4646216954",
	Step = "rbxassetid://85383897332935",
	Music = "rbxassetid://9043538930", -- "Ruins": sorrowful piano
	Paper = "rbxassetid://9117410302",
	Heart = "rbxassetid://9043365842",
	Slam = "rbxassetid://9116646197",
}
local ANIM = {Idle = "rbxassetid://507766666", Walk = "rbxassetid://507777826", Run = "rbxassetid://507767714"}
local LINES = {
	spot = {"Hey! Visiting hours are over!", "You can't be back here!", "Excuse me! Stop right there!"},
	lost = {"...Where did you go?", "I know you're on this floor.", "Kids."},
	mumble = {"Room six, fine. Room eight, fine...", "Lights out at ten.", "*sigh*"},
}
local function pick(t) return t[math.random(#t)] end

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, active, gui, fade = ctx.pop, ctx.setObjective, ctx.tween, ctx.active, ctx.gui, ctx.fade
	local cam = workspace.CurrentCamera
	local O = Vector3.new(30000, 500, 0)
	local FY = 500
	local F3 = 32 -- the patient floor (hall, wards, Room 12) is on floor 3

	local alive = true
	local cleanup, conns = {}, {}
	local function onCleanup(f) table.insert(cleanup, f) end
	local function conn(c) table.insert(conns, c) return c end
	local function hrpOf() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function humOf() local c = player.Character return c and c:FindFirstChildOfClass("Humanoid") end
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
	local function sfx(id, vol, parent, speed)
		local s = Instance.new("Sound")
		s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1 s.RollOffMaxDistance = 80 s.RollOffMinDistance = 6
		s.Parent = parent or SoundService s:Play()
		task.delay(15, function() s:Destroy() end)
		return s
	end

	-- narrator: once-only lines that wait their turn
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
		return make("ProximityPrompt", {ActionText = action, ObjectText = object or "", HoldDuration = hold or 0.3, MaxActivationDistance = dist or 8, RequiresLineOfSight = false}, part)
	end
	local function glint(part)
		local l = make("PointLight", {Color = Color3.fromRGB(255, 225, 160), Range = 7, Brightness = 1.2, Shadows = false}, part)
		local s = make("Sparkles", {SparkleColor = Color3.fromRGB(255, 235, 180)}, part)
		return function() l:Destroy() s:Destroy() end
	end
	-- spoken lines of other people (quoted, under the narrator)
	local voice = make("TextLabel", {Size = UDim2.new(1, -40, 0, 60), Position = UDim2.new(0, 20, 0.8, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 26,
		TextColor3 = Color3.fromRGB(190, 225, 235), TextStrokeTransparency = 0.4, Text = "", TextTransparency = 1, TextWrapped = true, ZIndex = 15}, gui)
	local voiceTok = 0
	local function speak(text, hold)
		voiceTok += 1 local my = voiceTok
		voice.Text = "\u{201C}" .. text .. "\u{201D}" voice.TextTransparency = 0 voice.TextStrokeTransparency = 0.4
		task.delay(hold or 3, function() if voiceTok == my and alive then tween(voice, 0.5, {TextTransparency = 1, TextStrokeTransparency = 1}) end end)
	end
	local hideHint = make("TextLabel", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.9, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 22,
		TextColor3 = Color3.fromRGB(220, 230, 235), TextStrokeTransparency = 0.4, Text = "Hiding...  press E to come out", Visible = false, ZIndex = 15}, gui)
	local dark = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 14}, gui)

	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
		cam.CameraType = Enum.CameraType.Custom
		local h = humOf() if h then h.WalkSpeed = 18 end
	end
	task.spawn(function()
		while alive and active() do task.wait(0.3) end
		shutdown()
	end)
	local function hospHumanoid() local h = humOf() if h then h.WalkSpeed = 16 end end
	hospHumanoid()
	conn(player.CharacterAdded:Connect(function() task.wait(0.5) hospHumanoid() end))

	-- the door stays hidden until the end
	local door = D:FindFirstChild("Door")
	local doorParts = {}
	if door then
		for _, p in door:GetDescendants() do
			if p:IsA("BasePart") then doorParts[p] = p.Transparency p.Transparency = 1 p.CanCollide = false end
		end
		onCleanup(function() for p, t in doorParts do p.Transparency = t p.CanCollide = true end end)
	end

	local room = D.Room12
	local people = D.People
	local signed, hasFlowers, inRoom = false, false, false
	local function objective()
		if inRoom then return end
		setObjective(("%s \u{b7} %s \u{b7} Room 12 (3rd floor)"):format(signed and "\u{2713} Sign in" or "Sign in", hasFlowers and "\u{2713} Flowers" or "Flowers"))
	end

	-------------------------------------------------------- heart monitor (beeps + moving trace)
	local screen = room.HeartMonitor.Screen
	local display = screen.Display
	local trace = display.Frame.Trace
	local bpmLabel = display.Frame.BPM
	local bpm = 62
	local monitorOn = true
	local flat = false
	local dots = {}
	for i = 1, 48 do
		dots[i] = make("Frame", {Size = UDim2.fromOffset(5, 5), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(80, 255, 120), Position = UDim2.fromOffset(i * 5, 110)}, trace)
	end
	local beepSound = make("Sound", {SoundId = SFX.Beep, Volume = 0.25, PlaybackSpeed = 1.35, RollOffMinDistance = 4, RollOffMaxDistance = 40}, screen)
	local flatSound = make("Sound", {SoundId = SFX.Flat, Volume = 0, Looped = true, PlaybackSpeed = 0.9, RollOffMinDistance = 4, RollOffMaxDistance = 40}, screen)
	local head = 1
	local lastBeat = os.clock()
	local spike = 0
	conn(RunService.Heartbeat:Connect(function(dt)
		if not monitorOn then return end
		local now = os.clock()
		if not flat and now - lastBeat >= 60 / bpm then
			lastBeat = now spike = 4
			beepSound:Play()
		end
		-- advance the trace by one column ~ 30 times a second
		head = head % #dots + 1
		local y = 110
		if spike > 0 then y = ({110, 40, 150, 95})[spike] spike -= 1 end
		dots[head].Position = UDim2.fromOffset(head * 5, y)
		dots[head].BackgroundTransparency = 0
		for i = 1, #dots do
			local age = (head - i) % #dots
			dots[i].BackgroundTransparency = math.clamp(age / #dots, 0, 0.9)
		end
		bpmLabel.Text = flat and "--" or tostring(math.floor(bpm))
	end))
	onCleanup(function() bpmLabel.Text = "62" end)

	-------------------------------------------------------- sign in + flowers
	local desk = D.Lobby.Desk
	local unglintClip = glint(desk.Clipboard)
	local signP = prompt(desk.Clipboard, "Sign in", "Visitor log", 0.6, 8)
	local startOrderly -- forward
	conn(signP.Triggered:Connect(function()
		if signed then return end
		signed = true signP.Enabled = false unglintClip()
		objective()
		say("You write your name. The pen smudges it before you finish.", 4)
		task.wait(4.3)
		speak("Visiting hours ended an hour ago, sweetie. Come back tomorrow.", 4)
		task.wait(4.5)
		narrate("tomorrow", "You don't have until tomorrow. You don't know how you know that.", 4.5)
		startOrderly()
	end))
	local cart = D.Lobby.GiftCart
	local unglintFlowers = glint(cart.FlowerBucket)
	local flowerP = prompt(cart.FlowerBucket, "Take flowers", "Yellow flowers", 0.4, 8)
	conn(flowerP.Triggered:Connect(function()
		if hasFlowers then return end
		hasFlowers = true flowerP.Enabled = false unglintFlowers()
		sfx(SFX.Paper, 0.5, cart.FlowerBucket)
		for _, p in cart:GetChildren() do if p.Name == "Bloom" or p.Name == "Stem" then setp(p, {Transparency = 1}) end end
		objective()
		say("Yellow ones. You didn't stop to think about which. Your hand just went to them.", 4.5)
	end))

	-------------------------------------------------------- the orderly
	local template = people.Orderly
	local ord = template:Clone()
	local tParent = template.Parent
	template.Parent = nil
	onCleanup(function() template.Parent = tParent end)
	local root = ord:WaitForChild("HumanoidRootPart")
	for _, p in ord:GetDescendants() do
		if p:IsA("BasePart") then p.CanCollide = false p.CanTouch = false p.CanQuery = false p.Anchored = (p == root) end
	end
	local ohum = ord:FindFirstChildOfClass("Humanoid")
	local hipOffset = root.Position.Y - FY
	ord.Name = "HospitalOrderly"
	ord.Parent = workspace
	onCleanup(function() ord:Destroy() end)
	local ohead = ord:WaitForChild("Head")
	local animator = ohum:FindFirstChildOfClass("Animator") or Instance.new("Animator", ohum)
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
	local stepSound = make("Sound", {SoundId = SFX.Step, Volume = 0.6, RollOffMinDistance = 6, RollOffMaxDistance = 60}, root)
	local function placeOrd(x, z, lookZ)
		root.CFrame = CFrame.lookAt(O + Vector3.new(x, hipOffset, z), O + Vector3.new(x, hipOffset, lookZ))
	end
	placeOrd(0, -180.6, 0)
	local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
	local target = nil -- world point he walks toward (straight line: the hall is straight)
	local speed = 7
	local frozen = false
	local stepClock = 0
	conn(RunService.Heartbeat:Connect(function(dt)
		if frozen then return end
		local pos = root.Position
		local moving = false
		if target then
			local flatD = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			local dist = flatD.Magnitude
			if dist > 0.3 then
				local step = math.min(speed * dt, dist)
				local np = pos + flatD.Unit * step
				-- stay inside the hall (x -3.6..3.6, z -94..0)
				local lx = np.X - O.X
				local lz = np.Z - O.Z
				np = Vector3.new(O.X + math.clamp(lx, -7.5, 7.5), FY + hipOffset, O.Z + math.clamp(lz, -197.4, 0))
				moving = (np - pos).Magnitude > 0.01
				pos = np
				local want = math.atan2(-flatD.X, -flatD.Z)
				local diff = (want - yaw + math.pi) % (2 * math.pi) - math.pi
				yaw += diff * math.min(1, dt * 6)
			end
		end
		root.CFrame = CFrame.new(pos.X, FY + hipOffset, pos.Z) * CFrame.Angles(0, yaw, 0)
		if moving then
			if speed > 9 then playAnim("Run", speed / 16) else playAnim("Walk", speed / 10) end
			stepClock += dt
			if stepClock > (speed > 9 and 0.32 or 0.6) then stepClock = 0 stepSound.PlaybackSpeed = 1.1 + math.random() * 0.15 stepSound:Play() end
		else
			playAnim("Idle", 1)
		end
	end))
	local function arrived() return not target or (Vector3.new(target.X, 0, target.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude < 0.5 end

	-- sight
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function clearLine(a, b)
		local ignore = {ord, player.Character}
		for _ = 1, 8 do
			rayParams.FilterDescendantsInstances = ignore
			local r = workspace:Raycast(a, b - a, rayParams)
			if not r then return true end
			if r.Instance.Transparency > 0.8 or not r.Instance.CanCollide then table.insert(ignore, r.Instance) else return false end
		end
		return true
	end
	local hidden = nil
	local graceUntil = 0
	local function localPos(p) return p - O end
	local function inHall(p) local l = localPos(p) return l.Y > 25 and l.Z < 1.05 and l.Z > -203.7 and math.abs(l.X) < 10.9 end
	local function inRoom12(p) local l = localPos(p) return l.Y > 25 and l.X < -11.8 and l.X > -54.6 and l.Z < -170.8 and l.Z > -203.7 end
	local function canSee()
		if hidden or os.clock() < graceUntil then return false end
		local c = player.Character
		local ph = c and c:FindFirstChild("Head")
		if not ph then return false end
		if not inHall(ph.Position) then return false end -- he only cares about his hall
		local to = ph.Position - ohead.Position
		local d = to.Magnitude
		if d > 55 then return false end
		if d > 4 then
			local flatTo = Vector3.new(to.X, 0, to.Z)
			if root.CFrame.LookVector:Dot(flatTo.Unit) < 0.6 then return false end
		end
		return clearLine(ohead.Position, ph.Position)
	end

	-------------------------------------------------------- hiding in supply rooms
	local hideDoors = {}
	for _, d in D.Hall:GetChildren() do if d:GetAttribute("HideSpot") then table.insert(hideDoors, d) end end
	local function exitHide()
		if not hidden then return end
		local d = hidden hidden = nil
		d.LocalTransparencyModifier = 0
		hideHint.Visible = false
		local hrp = hrpOf()
		if hrp then
			local p = Vector3.new(d.Position.X - 3.5, FY + F3 + 3, d.Position.Z)
			hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(-1, 0, 0))
			hrp.Anchored = false
		end
		cam.CameraType = Enum.CameraType.Custom
	end
	local function enterHide(d)
		if hidden or frozen then return end
		local hrp = hrpOf() if not hrp then return end
		hidden = d
		hrp.Anchored = true
		hrp.CFrame = CFrame.new(d.Position.X + 3.5, FY + F3 + 3, d.Position.Z)
		d.LocalTransparencyModifier = 0.85
		cam.CameraType = Enum.CameraType.Scriptable
		hideHint.Visible = true
		if said.hide then say("Shh...", 1.5) else narrate("hide", "A supply room. You hold your breath and watch through the little window.", 4) end
	end
	for _, d in hideDoors do
		local pr = prompt(d, "Hide", "Supply room", 0.2, 6)
		conn(pr.Triggered:Connect(function() enterHide(d) end))
	end
	conn(RunService.RenderStepped:Connect(function()
		if hidden then
			local eye = Vector3.new(hidden.Position.X + 1, FY + F3 + 7, hidden.Position.Z + 2.1)
			local m = UIS:GetMouseLocation()
			local ox = (m.X / cam.ViewportSize.X - 0.5) * 2
			cam.CFrame = CFrame.lookAt(eye, eye + Vector3.new(-10, -1, ox * 8))
		end
	end))
	conn(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.E and hidden then exitHide() end
	end))

	-------------------------------------------------------- his brain
	local state = "off" -- off, patrol, chase, search, done
	local function setState(s) state = s player:SetAttribute("HS_OrdState", s) end
	setState("off")
	local lastSeen, lastSeenAt = nil, 0
	local waitUntil = 0
	local nextMumble = os.clock() + 10
	local patrolZ = {-8.4, -180.6}
	local pIdx = 1
	startOrderly = function()
		if state ~= "off" then return end
		setState("patrol")
		graceUntil = os.clock() + 4
		narrate("orderly", "A man in a white coat is walking the hall. If he sees you, he'll send you back.", 4.5)
	end
	local caughtCount = 0
	local function caught()
		if frozen then return end
		frozen = true setState("caught")
		caughtCount += 1 player:SetAttribute("HS_Caught", caughtCount)
		if hidden then exitHide() end
		local hrp = hrpOf()
		if not hrp then frozen = false return end
		hrp.Anchored = true
		playAnim("Idle", 1)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 1.5, 0), ohead.Position)
		speak("Visiting hours are over.", 2.5)
		task.wait(1.6)
		tween(dark, 0.8, {BackgroundTransparency = 0}).Completed:Wait()
		if not alive then return end
		local s = D.Start.Position
		hrp.CFrame = CFrame.lookAt(s + Vector3.new(0, 3, 0), s + Vector3.new(0, 3, -10))
		hrp.Anchored = false
		cam.CameraType = Enum.CameraType.Custom
		placeOrd(0, -180.6, 0) target = nil
		yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
		graceUntil = os.clock() + 5
		waitUntil = os.clock() + 3
		setState("patrol")
		frozen = false
		tween(dark, 1.2, {BackgroundTransparency = 1})
		if caughtCount == 1 then
			narrate("caught1", "He walks you all the way back to the lobby. He doesn't let go of your arm until you're there.", 5)
		else
			say("Back in the lobby. Try again. The supply rooms on the right are unlocked.", 4)
		end
	end
	local function spotted()
		local hrp = hrpOf()
		lastSeen = hrp and hrp.Position lastSeenAt = os.clock()
		if state ~= "chase" then
			setState("chase")
			waitUntil = os.clock() + 0.8 -- a moment to react
			speak(pick(LINES.spot), 2.5)
			task.delay(1.2, function() narrate("run", "You run. You've never run in a hospital before. It feels wrong.", 4) end)
		end
	end
	local function finishChase()
		-- you made it into Room 12: he stops at the door
		if state == "done" then return end
		local wasChasing = state == "chase" or state == "search"
		setState("done")
		target = O + Vector3.new(-6.3, 0, -186.9)
		speed = 6
		task.delay(2.5, function()
			if not alive then return end
			if wasChasing then speak("...Five minutes. That's all.", 3) end
			task.wait(3.5)
			target = O + Vector3.new(0, 0, -4.2)
			task.wait(14)
			if alive and not player:GetAttribute("HS_Escaping") then ord.Parent = nil end
		end)
	end

	task.spawn(function()
		while alive do
			task.wait(0.15)
			if frozen or state == "off" or state == "done" then continue end
			local now = os.clock()
			local hrp = hrpOf()
			if not hrp then continue end
			if inRoom12(hrp.Position) then finishChase() continue end
			local d = hrp.Position - root.Position
			local flatD = Vector3.new(d.X, 0, d.Z).Magnitude
			local sees = canSee()
			if sees then spotted() end
			if state == "chase" and not hidden and flatD < 3 and now > graceUntil then task.spawn(caught) continue end
			if now < waitUntil then continue end
			if state == "chase" then
				speed = 13.5
				if sees then target = hrp.Position
				elseif not inHall(hrp.Position) and not hidden then
					-- you got back to the lobby
					speak("And stay out there!", 2.5)
					setState("patrol") target = nil waitUntil = now + 3
				elseif now - lastSeenAt > 3 then
					setState("search") target = lastSeen speak(pick(LINES.lost), 3)
				elseif lastSeen then target = lastSeen end
			elseif state == "search" then
				speed = 8
				if arrived() then waitUntil = now + 2.5 setState("patrol") target = nil end
			else -- patrol
				speed = 7
				if arrived() then
					if target then
						target = nil waitUntil = now + 1.5 + math.random() * 2
					else
						-- walk to the other end of the hall, sometimes stopping halfway to check a door
						pIdx = pIdx % 2 + 1
						local z = patrolZ[pIdx]
						if math.random() < 0.35 then z = -12.6 - 25.2 * math.random(1, 6) end
						target = O + Vector3.new(math.random(-15, 15) / 10, 0, z)
					end
				end
				if now > nextMumble and flatD < 30 then nextMumble = now + 10 + math.random() * 8 speak(pick(LINES.mumble), 2.5) end
			end
		end
	end)
	-- going down the hall before signing in also wakes him up
	task.spawn(function()
		while alive and state == "off" do
			local hrp = hrpOf()
			if hrp and inHall(hrp.Position) and localPos(hrp.Position).Z < -6 then startOrderly() end
			task.wait(0.3)
		end
	end)

	-------------------------------------------------------- the elevator (lobby <-> floor 3)
	local atrium = D:FindFirstChild("Atrium")
	if atrium and atrium:FindFirstChild("ElevatorCar") then
		local car = atrium.ElevatorCar
		local carHome = car:GetPivot()
		onCleanup(function() car:PivotTo(carHome) end)
		local riding = false
		local function ride(toY)
			if riding then return end
			if player:GetAttribute("HS_Escaping") then say("You press the button again and again. The elevator won't come. The stairs!", 3.5) return end
			local hrp = hrpOf() if not hrp then return end
			riding = true
			local fromY = (hrp.Position.Y - O.Y > 25) and F3 or 0
			if fromY == toY then riding = false return end
			car:PivotTo(carHome + Vector3.new(0, fromY, 0))
			hrp.Anchored = true
			sfx(SFX.Beep, 0.3, car.PrimaryPart, 0.8)
			local t0, dur = os.clock(), 5
			local c = RunService.Heartbeat:Connect(function()
				local a = math.clamp((os.clock() - t0) / dur, 0, 1)
				local e = a * a * (3 - 2 * a)
				car:PivotTo(carHome + Vector3.new(0, fromY + (toY - fromY) * e, 0))
				local p = car.PrimaryPart.Position + Vector3.new(0, 3, 0)
				hrp.CFrame = CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
			end)
			if toY > fromY then narrate("elevatorUp", "The elevator hums. The numbers light up one at a time. 1... 2... 3.", 4) end
			task.wait(dur)
			c:Disconnect()
			if not alive then return end
			sfx(SFX.Beep, 0.3, car.PrimaryPart, 0.8)
			local out = car.PrimaryPart.Position + Vector3.new(0, 3, 5)
			hrp.CFrame = CFrame.lookAt(out, out + Vector3.new(0, 0, 1))
			hrp.Anchored = false
			riding = false
		end
		local bG, b3 = atrium:FindFirstChild("CallButtonG"), atrium:FindFirstChild("CallButton3")
		if bG then conn(prompt(bG, "Go up", "Elevator to floor 3", 0.3, 9).Triggered:Connect(function() task.spawn(ride, F3) end)) end
		if b3 then conn(prompt(b3, "Go down", "Elevator to the lobby", 0.3, 9).Triggered:Connect(function() task.spawn(ride, 0) end)) end
	end

	-------------------------------------------------------- Room 12
	local vase = room.Vase
	local woman = people.Woman
	local music
	local vaseP = prompt(vase, "Put flowers in", "Vase", 0.5, 10)
	vaseP.Enabled = false
	local sitP = prompt(room.VisitorChair.Seat, "Sit with her", "Chair", 0.4, 10)
	sitP.Enabled = false
	local hand = woman:FindFirstChild("RightHand") or woman:FindFirstChild("LeftHand")
	do -- use whichever hand is closer to your chair
		local cpos = room.VisitorChair.Seat.Position
		local l, r = woman:FindFirstChild("LeftHand"), woman:FindFirstChild("RightHand")
		if l and r then hand = ((l.Position - cpos).Magnitude < (r.Position - cpos).Magnitude) and l or r end
	end
	local handP = prompt(hand, "Hold her hand", "", 1.5, 12)
	handP.Enabled = false

	-------------------------------------------------------- afterwards: you run, the door shuts, the nurse stops you
	local runAway
	runAway = function()
		if not alive then return end
		player:SetAttribute("HS_Escaping", true)
		onCleanup(function() player:SetAttribute("HS_Escaping", nil) end)
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
		local h = humOf() if h then h.WalkSpeed = 20 end
		setObjective("Get out of the hospital. Don't let them stop you.")
		say("Your chest won't stop shaking. You can't be in here. You have to get out.", 4.5)
		if music then tween(music, 1.5, {Volume = 0}) end
		local heart = make("Sound", {SoundId = SFX.Heart, Volume = 0.9, Looped = true, PlaybackSpeed = 1.35}, SoundService)
		heart:Play()
		-- dark pulse at the edges of your vision, flickering lights
		local panicking = true
		conn(RunService.RenderStepped:Connect(function()
			if panicking then dark.BackgroundTransparency = 0.8 + math.sin(os.clock() * 8.5) * 0.08 end
		end))
		local lights = {}
		for _, l in game:GetService("CollectionService"):GetTagged("HospitalLight") do
			if l:IsDescendantOf(D) then local s = l:FindFirstChildOfClass("SurfaceLight") if s then table.insert(lights, s) setp(s, {Enabled = true}) end end
		end
		task.spawn(function()
			while alive and panicking do
				local s = lights[math.random(#lights)]
				if s then s.Enabled = false task.wait(0.05 + math.random() * 0.15) s.Enabled = true end
				task.wait(0.1 + math.random() * 0.4)
			end
		end)
		-- Room 12 shuts behind you once you're out in the hall
		local r12 = D.Hall:FindFirstChild("Room12Door")
		task.spawn(function()
			while alive do
				local hrp2 = hrpOf()
				if hrp2 and localPos(hrp2.Position).X > -8.4 and localPos(hrp2.Position).Z < 0 then break end
				task.wait(0.1)
			end
			if not alive or not r12 then return end
			setp(r12, {Transparency = 0, CanCollide = true})
			local sign = r12:FindFirstChild("NoVisitors")
			if sign then setp(sign, {Transparency = 0}) local g = sign:FindFirstChildOfClass("SurfaceGui") if g then setp(g, {Enabled = true}) end end
			sfx(SFX.Slam, 0.9, r12, 0.8)
			say("The door slams shut behind you.", 2.5)
			local op = prompt(r12, "Open", "Room 12", 0.3, 7)
			conn(op.Triggered:Connect(function() say("It won't open. It's not going to open again.", 3) end))
		end)

		---------------- the staff try to stop you: the orderly from behind, the nurse in the lobby
		local function walker(model)
			local r = model:WaitForChild("HumanoidRootPart")
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then p.CanCollide = false p.CanTouch = false p.CanQuery = false p.Anchored = (p == r) end
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			local an = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
			local tr = {}
			for k, id in ANIM do
				local anim = Instance.new("Animation") anim.AnimationId = id
				local ok, t = pcall(function() return an:LoadAnimation(anim) end)
				if ok then tr[k] = t end
			end
			return {model = model, root = r, hip = r.Position.Y - FY, yaw = select(2, r.CFrame:ToEulerAnglesYXZ()), tracks = tr, cur = nil, speed = 0, target = nil, wait = 0, step = 0,
				snd = make("Sound", {SoundId = SFX.Step, Volume = 0.6, RollOffMinDistance = 6, RollOffMaxDistance = 60}, r)}
		end
		local function play(w, name, sp)
			local t = w.tracks[name] if not t then return end
			if w.cur ~= t then if w.cur then w.cur:Stop(0.2) end t:Play(0.2) w.cur = t end
			t:AdjustSpeed(sp or 1)
		end
		local function place(w, x, z, lookX, lookZ)
			w.root.CFrame = CFrame.lookAt(O + Vector3.new(x, w.hip, z), O + Vector3.new(lookX, w.hip, lookZ))
			w.yaw = select(2, w.root.CFrame:ToEulerAnglesYXZ())
		end
		-- the orderly (reuse him), the nurse (a moving copy of the one at the desk)
		frozen = true -- stop his old patrol brain
		ord.Parent = workspace
		local orderly = walker(ord)
		orderly.upper = true
		local nurseT = people:FindFirstChild("Nurse")
		local nurseCopy = nurseT:Clone()
		local nParent = nurseT.Parent
		nurseT.Parent = nil
		onCleanup(function() nurseT.Parent = nParent end)
		nurseCopy.Name = "HospitalNurse" nurseCopy.Parent = workspace
		onCleanup(function() nurseCopy:Destroy() end)
		local nurseW = walker(nurseCopy)
		local chasers = {orderly, nurseW}
		local START_ORD, START_NURSE = {0, -198.8}, {-2.1, 16}
		local function resetChasers()
			place(orderly, START_ORD[1], START_ORD[2], 0, 0) orderly.target = nil orderly.wait = os.clock() + 2.5
			place(nurseW, START_NURSE[1], START_NURSE[2], -2.1, 42) nurseW.target = nil nurseW.wait = 0
		end
		resetChasers()
		-- where can they walk: the hall (x -3.6..3.6, z -95..1) or the lobby (x -15..15, z 0..28.5), not through the desk
		local function route(w, goal)
			local p = w.root.Position - O
			local g = goal - O
			-- hall -> lobby (or back) goes through the hall opening
			if p.Z < 1.05 and g.Z > 1.05 and math.abs(p.X) > 6.3 then return O + Vector3.new(0, 0, p.Z + 8.4) end
			if p.Z < 1.05 and g.Z > 1.05 then return O + Vector3.new(0, 0, 4.2) end
			-- around the desk (x -7.5..7.5, z 8.5..11.5)
			local crosses = (p.Z < 19.5 and g.Z > 22.5) or (p.Z > 22.5 and g.Z < 19.5)
			if crosses then
				local t = (21 - p.Z) / (g.Z - p.Z)
				local x = p.X + (g.X - p.X) * t
				if math.abs(x) < 8.5 then
					local side = (x >= 0) and 9.5 or -9.5
					return O + Vector3.new(side, 0, (p.Z < 21) and 19.5 or 22.5)
				end
			end
			if p.Z > 19.5 and p.Z < 22.5 and math.abs(p.X) < 8 then return O + Vector3.new((p.X >= 0) and 9.5 or -9.5, 0, p.Z) end
			return goal
		end
		local function clampPos(v, upper)
			local l = v - O
			if upper and l.Z >= 1.05 then return O + Vector3.new(math.clamp(l.X, -31, 21), 0, math.clamp(l.Z, 1.05, 8.5)) end
			if l.Z < 1.05 then return O + Vector3.new(math.clamp(l.X, -7.5, 7.5), 0, math.clamp(l.Z, -198.8, 2.1)) end
			return O + Vector3.new(math.clamp(l.X, -31.5, 31.5), 0, math.clamp(l.Z, 0, 60))
		end
		local escaped = false
		local catching = false
		conn(RunService.Heartbeat:Connect(function(dt)
			if escaped then return end
			for _, w in chasers do
				local pos = w.root.Position
				local moving = false
				if w.target and not catching and os.clock() > w.wait then
					local goal = route(w, w.target)
					local f = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
					local dist = f.Magnitude
					if dist > 0.3 then
						local np = clampPos(pos + f.Unit * math.min(w.speed * dt, dist), w.upper)
						moving = true
						pos = Vector3.new(np.X, pos.Y, np.Z)
						local want = math.atan2(-f.X, -f.Z)
						local diff = (want - w.yaw + math.pi) % (2 * math.pi) - math.pi
						w.yaw += diff * math.min(1, dt * 7)
					end
				end
				w.root.CFrame = CFrame.new(pos.X, FY + w.hip, pos.Z) * CFrame.Angles(0, w.yaw, 0)
				if moving then
					if w.speed > 9 then play(w, "Run", w.speed / 16) else play(w, "Walk", w.speed / 10) end
					w.step += dt
					if w.step > (w.speed > 9 and 0.32 or 0.55) then w.step = 0 w.snd.PlaybackSpeed = 1.1 + math.random() * 0.15 w.snd:Play() end
				else
					play(w, "Idle", 1)
				end
			end
		end))
		-- the automatic front doors slide open when you get close
		local gl, gr = D.Lobby.GlassDoorL, D.Lobby.GlassDoorR
		local glCF, grCF = gl.CFrame, gr.CFrame
		onCleanup(function() gl.CFrame = glCF gr.CFrame = grCF gl.CanCollide = true gr.CanCollide = true end)
		local doorsOpen = false
		local function setDoors(open)
			if doorsOpen == open then return end
			doorsOpen = open
			tween(gl, 0.6, {CFrame = open and glCF * CFrame.new(-9.7, 0, 0) or glCF})
			tween(gr, 0.6, {CFrame = open and grCF * CFrame.new(9.7, 0, 0) or grCF})
			gl.CanCollide = not open gr.CanCollide = not open
		end
		-- caught: back to the door of Room 12
		local caughtN = 0
		local function caughtBy(w)
			if catching then return end
			catching = true
			caughtN += 1 player:SetAttribute("HS_RunCaught", caughtN)
			local hrp2 = hrpOf()
			if hrp2 then hrp2.Anchored = true end
			cam.CameraType = Enum.CameraType.Scriptable
			if hrp2 then cam.CFrame = CFrame.lookAt(hrp2.Position + Vector3.new(0, 1.5, 0), w.model.Head.Position) end
			speak(w == nurseW and "Whoa, whoa! Slow down!" or "Hey! Stop!", 2)
			task.wait(1.3)
			tween(dark, 0.6, {BackgroundTransparency = 0}).Completed:Wait()
			if not alive then return end
			local byNurse = (w == nurseW)
			if hrp2 then
				-- caught downstairs: back to the floor-2 balcony. caught upstairs: back outside Room 12
				local p = byNurse and (O + Vector3.new(-18, 19, 5)) or (O + Vector3.new(0, F3 + 3, -176.4))
				hrp2.CFrame = CFrame.lookAt(p, p + Vector3.new(byNurse and -1 or 0, 0, byNurse and 0 or 1))
				hrp2.Anchored = false
			end
			cam.CameraType = Enum.CameraType.Custom
			setDoors(false)
			if byNurse then
				place(nurseW, START_NURSE[1], START_NURSE[2], -2.1, 42) nurseW.target = nil nurseW.wait = os.clock() + 2
			else
				resetChasers()
			end
			task.wait(0.4)
			tween(dark, 0.6, {BackgroundTransparency = 0.8})
			if caughtN == 1 then say("Again. Faster. Don't let them hold on to you.", 3.5) else say("Again.", 1.5) end
			catching = false
		end
		-- the chase brain
		task.wait(1)
		local nurseWarned = false
		local orderlyGo = false
		while alive and not escaped do
			task.wait(0.1)
			if catching then continue end
			local hrp2 = hrpOf() if not hrp2 then continue end
			local pl = hrp2.Position - O
			-- the orderly comes out of the far end of the hall once you've left the room
			if not orderlyGo and pl.X > -5 then
				orderlyGo = true
				orderly.wait = math.max(orderly.wait, os.clock() + 1.2)
				speak("Hey! You can't run in here!", 2.5)
			end
			orderly.speed = 15
			local upstairs = pl.Y > 25
			if orderlyGo then
				if upstairs then orderly.target = Vector3.new(hrp2.Position.X, 0, hrp2.Position.Z)
				else
					orderly.target = O + Vector3.new(math.clamp(pl.X, -31, 21), 0, 8)
					if not said.railShout then said.railShout = true speak("Somebody stop that kid!", 2.5) end
				end
			else orderly.target = nil end
			-- the nurse wakes up once you reach the lobby side of the hall
			if pl.Y < 25 then
				if not nurseWarned then nurseWarned = true speak("Hey! Where are you going?", 2.5) end
				nurseW.speed = 10.5
			end
			if pl.Y < 25 and pl.Y > 8 then
				nurseW.target = O + Vector3.new(-4, 0, 34) -- waits in the middle of the lobby
			elseif pl.Y <= 8 then
				nurseW.target = Vector3.new(hrp2.Position.X, 0, math.max(hrp2.Position.Z, O.Z + 5.6)) -- she stays in the lobby
			end
			for _, w in chasers do
				local d = Vector3.new(w.root.Position.X - hrp2.Position.X, 0, w.root.Position.Z - hrp2.Position.Z).Magnitude
				if d < 3 and math.abs(w.root.Position.Y - hrp2.Position.Y) < 6 and os.clock() > w.wait then task.spawn(caughtBy, w) break end
			end
			-- the doors open when you're close
			setDoors(pl.Z > 46 and math.abs(pl.X) < 14)
			if pl.Z > 65.1 then escaped = true end
		end
		if not alive then return end
		---------------- outside
		for _, w in chasers do play(w, "Idle", 1) end
		setObjective("")
		panicking = false
		tween(dark, 2, {BackgroundTransparency = 1})
		tween(heart, 5, {PlaybackSpeed = 0.9, Volume = 0.3})
		local h3 = humOf() if h3 then h3.WalkSpeed = 16 end
		task.delay(1.5, function() if alive then setDoors(false) end end)
		say("You don't stop running until the rain is all you can hear.", 4.5)
		task.wait(5)
		say("Nobody follows you out.", 3)
		task.wait(3.5)
		tween(heart, 3, {Volume = 0})
		if not alive then return end
		-- the Dream Door waits out in the rain
		if door then
			local pv = door:GetPivot()
			onCleanup(function() door:PivotTo(pv) end)
			local cf = door:GetBoundingBox()
			door:PivotTo(pv + (O + Vector3.new(0, cf.Position.Y - O.Y - F3, 92.4) - cf.Position))
			for p, t in doorParts do p.CanCollide = true TweenService:Create(p, TweenInfo.new(3), {Transparency = t}):Play() end
		end
		task.wait(3)
		if alive then ctx.unlockDoor(D, 10) end
	end
	local unglintVase
	task.spawn(function()
		while alive and not inRoom do
			local hrp = hrpOf()
			if hrp and inRoom12(hrp.Position) then
				inRoom = true
				setObjective(hasFlowers and "Put the flowers in the vase" or "Sit with her")
				say("Room 12. The monitor beeps, slow and steady.", 4)
				if hasFlowers then vaseP.Enabled = true unglintVase = glint(vase) else sitP.Enabled = true end
				task.delay(6, function() narrate("chair2", "There's a second chair on the other side of the bed. It stays empty.", 4.5) end)
			end
			task.wait(0.3)
		end
	end)
	conn(vaseP.Triggered:Connect(function()
		vaseP.Enabled = false
		if unglintVase then unglintVase() end
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			make("Part", {Name = "Stem", Size = Vector3.new(0.08, 1.4, 0.08), Anchored = true, CanCollide = false, Color = Color3.fromRGB(70, 140, 60), CFrame = CFrame.new(vase.Position + Vector3.new(math.cos(a) * 0.15, 1.1, math.sin(a) * 0.15))}, room)
			make("Part", {Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), Anchored = true, CanCollide = false, Color = Color3.fromRGB(255, 215, 60), CFrame = CFrame.new(vase.Position + Vector3.new(math.cos(a) * 0.3, 1.85 + (i % 2) * 0.15, math.sin(a) * 0.3))}, room)
		end
		say("The room looks a little brighter now.", 3.5)
		setObjective("Sit with her")
		sitP.Enabled = true
	end))
	conn(sitP.Triggered:Connect(function()
		sitP.Enabled = false
		local hrp = hrpOf() if not hrp then return end
		hrp.Anchored = true
		local seat = room.VisitorChair.Seat
		local p = seat.Position + Vector3.new(0, 2.3, 0)
		hrp.CFrame = CFrame.lookAt(p, Vector3.new(woman.Head.Position.X, p.Y, woman.Head.Position.Z))
		setObjective("")
		say("You sit down. You don't know her. You're sure you don't.", 4.5)
		music = make("Sound", {SoundId = SFX.Music, Volume = 0, Looped = false}, SoundService)
		music:Play() tween(music, 6, {Volume = 0.4})
		task.wait(5)
		if not alive then return end
		handP.Enabled = true
		setObjective("Hold her hand")
	end))
	conn(handP.Triggered:Connect(function()
		handP.Enabled = false
		setObjective("")
		say("Her hand is small and cool. It moves a little in yours.", 4.5)
		task.wait(5)
		say("You hold on. You aren't sure why it matters this much.", 5)
		-- the beeps slow down
		local light = room:FindFirstChild("RoomLight")
		local sl = light and light:FindFirstChildOfClass("SurfaceLight")
		for _, b in {54, 46, 38, 30, 22} do
			task.wait(3.2)
			if not alive then return end
			bpm = b
			if sl then sl.Brightness = math.max(0.25, sl.Brightness - 0.2) end
		end
		task.wait(3.5)
		-- the flatline
		flat = true
		flatSound.Volume = 0.12 flatSound:Play()
		task.wait(2.5)
		say("Her hand is warm. ...And then it isn't.", 5)
		task.wait(5.5)
		if not alive then return end
		-- the top note slips off her face; underneath is just another note
		local top = woman.ScribbleFace.Notes:FindFirstChild("TopNote")
		if top then
			local p0, r0 = top.Position, top.Rotation
			onCleanup(function() top.Position = p0 top.Rotation = r0 top.Visible = true end)
			tween(top, 2.5, {Position = top.Position + UDim2.fromOffset(40, 220), Rotation = r0 + 40})
			task.delay(2.4, function() top.Visible = false end)
		end
		say("The top note slips off. Underneath, there's only another note.", 5)
		task.wait(5.5)
		tween(flatSound, 3, {Volume = 0})
		said.__stop = true
		-- quiet white fade, then the room is empty
		fade.BackgroundColor3 = Color3.new(1, 1, 1)
		tween(fade, 4, {BackgroundTransparency = 0}).Completed:Wait()
		if not alive then return end
		monitorOn = false flatSound:Stop()
		for _, d in dots do d.BackgroundTransparency = 1 end
		bpmLabel.Text = ""
		local wParent = woman.Parent woman.Parent = nil
		onCleanup(function() woman.Parent = wParent end)
		setp(room.Bed.Blanket, {Transparency = 1})
		setp(room.Bed.MadeSheet, {Transparency = 0})
		if sl then sl.Brightness = 0.4 end
		task.wait(2)
		tween(fade, 4, {BackgroundTransparency = 1})
		task.wait(3)
		said.__stop = false
		say("The bed is made. Like nobody was ever here. Only the yellow flowers are left.", 4.5)
		task.wait(5)
		runAway()
	end))

	-------------------------------------------------------- lobby lines
	local nurse = people:FindFirstChild("Nurse")
	local spots = {}
	if nurse then table.insert(spots, {key = "nurse", pos = nurse.Head.Position, r = 9, text = "The nurse at the desk doesn't look up. Her pen keeps moving."}) end
	table.insert(spots, {key = "clock", pos = O + Vector3.new(-29.4, 0, 42), r = 6, text = "The clock in the waiting room says 11:58. It said that when you walked in, too."})
	task.spawn(function()
		while alive do
			local hrp = hrpOf()
			if hrp then
				for _, s in spots do
					if not said[s.key] and (Vector3.new(s.pos.X, hrp.Position.Y, s.pos.Z) - hrp.Position).Magnitude < s.r then narrate(s.key, s.text, 4.5) end
				end
			end
			task.wait(0.4)
		end
	end)

	-------------------------------------------------------- start
	say("A hospital, late at night. It's raining again.", 4)
	task.wait(4.5)
	objective()
	say("Sign in at the desk. Room 12 is up on the third floor. The flowers on the cart might be nice to bring.", 5.5)
	-- debug hook for testing: PlayerGui.HospitalDebug:Fire("grace"/"nograce"/"sign"/"flowers")
	local dbg = make("BindableEvent", {Name = "HospitalDebug"}, player:WaitForChild("PlayerGui"))
	conn(dbg.Event:Connect(function(cmd)
		if cmd == "grace" then graceUntil = os.clock() + 9999
		elseif cmd == "nograce" then graceUntil = 0
		elseif cmd == "sign" then signed = true objective() startOrderly()
		elseif cmd == "flowers" then hasFlowers = true objective()
		elseif cmd == "run" then -- jump straight to the escape (testing)
			inRoom = true finishChase()
			local hrp = hrpOf() if hrp then hrp.CFrame = CFrame.new(O + Vector3.new(-18.9, F3 + 3, -186.9)) end
			task.spawn(runAway)
		end
	end))
end

return M
