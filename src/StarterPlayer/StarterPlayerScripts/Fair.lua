-- Fair: Dream 13 "The Summer Fair" (Chapter 2). A rare happy dream: a fair at sunset.
-- Win a prize at the ring toss (timing game), get cotton candy, ride the Ferris wheel to the top for the fireworks.
-- The one small wrong thing: from the top, far past the trees, a big house with one window lit.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UIS = game:GetService("UserInputService")

local SFX = {
	Boom = "rbxassetid://75191072171555",
	Toss = "rbxassetid://9113577920",
	Clink = "rbxassetid://9118777437",
}

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, active, gui = ctx.pop, ctx.setObjective, ctx.tween, ctx.active, ctx.gui
	local cam = workspace.CurrentCamera
	local O = Vector3.new(39000, 500, 0)
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
		local s = Instance.new("Sound") s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1 s.RollOffMinDistance = 20 s.RollOffMaxDistance = 400
		s.Parent = parent or SoundService s:Play() task.delay(8, function() s:Destroy() end) return s
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
		return make("ProximityPrompt", {ActionText = action, ObjectText = object or "", HoldDuration = hold or 0.3, MaxActivationDistance = dist or 10, RequiresLineOfSight = false}, part)
	end
	local function glint(part)
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 225, 160) l.Range = 9 l.Brightness = 1 l.Parent = part
		local s = Instance.new("Sparkles") s.SparkleColor = Color3.fromRGB(255, 235, 180) s.Parent = part
		local function off() l:Destroy() s:Destroy() end
		onCleanup(off) return off
	end

	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
		cam.CameraType = Enum.CameraType.Custom
	end
	task.spawn(function() while alive and active() do task.wait(0.3) end shutdown() end)
	local function body() local h = humOf() if h then h.WalkSpeed = 16 end end
	body()

	-- the Dream Door stays hidden until the end
	local door = D:FindFirstChild("Door")
	local doorParts = {}
	if door then
		for _, p in door:GetDescendants() do if p:IsA("BasePart") then doorParts[p] = p.Transparency p.Transparency = 1 p.CanCollide = false end end
		onCleanup(function() for p, t in doorParts do p.Transparency = t p.CanCollide = true end end)
	end

	local done = {}
	local function objective()
		local function m(k, n) return done[k] and ("\u{2713} " .. n) or n end
		setObjective(("%s \u{b7} %s \u{b7} %s"):format(m("prize", "Win a prize"), m("candy", "Cotton candy"), m("ride", "Ferris wheel")))
	end

	-------------------------------------------------------- the carousel turns, the horses go up and down
	local spin = D.Carousel.Spin
	local axis = CFrame.new(spin.Center.Position.X, spin.Center.Position.Y, spin.Center.Position.Z)
	local offs = {}
	for _, p in spin:GetDescendants() do if p:IsA("BasePart") then offs[p] = axis:ToObjectSpace(p.CFrame) end end
	onCleanup(function() for p, o in offs do p.CFrame = axis * o end end)
	local horseOf = {}
	local hi = 0
	for _, h in spin:GetChildren() do if h.Name == "Horse" then hi += 1 for _, p in h:GetChildren() do if p.Name ~= "Pole" then horseOf[p] = hi end end end end
	local carAng = 0
	conn(RunService.RenderStepped:Connect(function(dt)
		carAng += dt * 0.45
		local r = axis * CFrame.Angles(0, carAng, 0)
		local t = os.clock()
		for p, o in offs do
			local k = horseOf[p]
			p.CFrame = r * o + (k and Vector3.new(0, math.sin(t * 2.2 + k * 1.3) * 0.7, 0) or Vector3.zero)
		end
	end))

	-------------------------------------------------------- the Ferris wheel
	local FW = D.FerrisWheel
	local C = D:GetAttribute("WheelCenter")
	local R = D:GetAttribute("WheelRadius")
	local center = CFrame.new(C)
	local wheelOffs = {}
	for _, p in FW.Wheel:GetDescendants() do if p:IsA("BasePart") then wheelOffs[p] = center:ToObjectSpace(p.CFrame) end end
	onCleanup(function() for p, o in wheelOffs do p.CFrame = center * o end end)
	local gondolas = {}
	for _, g in FW.Gondolas:GetChildren() do
		local a = g:GetAttribute("Angle")
		local tip = C + Vector3.new(math.cos(a) * R, math.sin(a) * R, 0)
		local parts = {}
		for _, p in g:GetDescendants() do if p:IsA("BasePart") then parts[p] = p.CFrame - tip end end
		gondolas[g.Name] = {model = g, a = a, parts = parts}
		onCleanup(function() for p, o in parts do p.CFrame = o + tip end end)
	end
	local theta = 0
	local wheelSpeed = 0.06
	local riding = nil -- gondola we're in
	local function placeWheel()
		local r = center * CFrame.Angles(0, 0, theta)
		for p, o in wheelOffs do p.CFrame = r * o end
		for _, g in gondolas do
			local a = g.a + theta
			local tip = C + Vector3.new(math.cos(a) * R, math.sin(a) * R, 0)
			for p, o in g.parts do p.CFrame = o + tip end
		end
	end
	local autoTurn = true
	conn(RunService.RenderStepped:Connect(function(dt)
		if autoTurn then theta += dt * wheelSpeed end
		placeWheel()
		if riding then
			local hrp = hrpOf()
			if hrp then
				local seat = riding.model.Seat
				hrp.CFrame = CFrame.lookAt(seat.Position + Vector3.new(0, 2.2, 0.4), seat.Position + Vector3.new(0, 2.2, 6))
			end
		end
	end))

	-------------------------------------------------------- ring toss (a timing game)
	local booth = D.RingToss
	local throwP = prompt(booth.Counter, "Play ring toss", "Ring toss", 0.3, 10)
	local unglintRT = glint(booth.Counter)
	local ui = make("Frame", {Size = UDim2.fromOffset(420, 150), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), BackgroundColor3 = Color3.fromRGB(30, 25, 40),
		BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, ZIndex = 20}, gui)
	make("UICorner", {CornerRadius = UDim.new(0, 12)}, ui)
	local info = make("TextLabel", {Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 235, 200), Text = "", ZIndex = 21}, ui)
	local bar = make("Frame", {Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 52), BackgroundColor3 = Color3.fromRGB(70, 60, 90), BorderSizePixel = 0, ZIndex = 21}, ui)
	local green = make("Frame", {Size = UDim2.fromScale(0.16, 1), Position = UDim2.fromScale(0.42, 0), BackgroundColor3 = Color3.fromRGB(110, 220, 120), BorderSizePixel = 0, ZIndex = 22}, bar)
	local marker = make("Frame", {Size = UDim2.new(0, 6, 1, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 23}, bar)
	local throwBtn = make("TextButton", {Size = UDim2.fromOffset(160, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), BackgroundColor3 = Color3.fromRGB(220, 70, 90),
		BorderSizePixel = 0, Font = Enum.Font.FredokaOne, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), Text = "Throw!  [E]", ZIndex = 21, Modal = true}, ui)
	make("UICorner", {CornerRadius = UDim.new(0, 10)}, throwBtn)
	local playing = false
	local throwNow = false
	throwBtn.MouseButton1Click:Connect(function() throwNow = true end)
	conn(UIS.InputBegan:Connect(function(input, processed)
		if playing and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space) then throwNow = true end
	end))
	local bottles = {} for _, b in booth:GetChildren() do if b.Name == "Bottle" then table.insert(bottles, b) end end
	local function flyRing(hit)
		local hrp = hrpOf() if not hrp then return end
		local target = bottles[math.random(#bottles)]
		local ring = make("Part", {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.1, 1.1), Anchored = true, CanCollide = false, Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon,
			CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))}, workspace)
		sfx(SFX.Toss, 0.4, ring, 1.6)
		local goal = hit and (target.Position + Vector3.new(0, 0.2, 0)) or (target.Position + Vector3.new(math.random(-2, 2), -1.2, math.random() < 0.5 and -2 or 2))
		tween(ring, 0.6, {CFrame = CFrame.new(goal) * CFrame.Angles(0, 0, math.rad(90))})
		task.delay(0.62, function() if hit then sfx(SFX.Clink, 0.5, target, 1.3) end end)
		task.delay(4, function() ring:Destroy() end)
	end
	local prizeBear
	local function giveBear()
		do return end -- (first person: things held in your hand block the view, so the prize is only described)
		local c = player.Character
		local hand = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
		if not hand then return end
		local m = Instance.new("Model") m.Name = "PrizeBear"
		local col = Color3.fromRGB(200, 150, 100)
		local bodyP = Instance.new("Part") bodyP.Shape = Enum.PartType.Ball bodyP.Size = Vector3.new(0.9, 0.9, 0.9) bodyP.Color = col bodyP.Material = Enum.Material.Fabric bodyP.CanCollide = false bodyP.Massless = true bodyP.Parent = m
		local headP = bodyP:Clone() headP.Size = Vector3.new(0.65, 0.65, 0.65) headP.Parent = m
		headP.CFrame = bodyP.CFrame * CFrame.new(0, 0.7, 0)
		local w1 = Instance.new("WeldConstraint") w1.Part0 = bodyP w1.Part1 = headP w1.Parent = headP
		bodyP.CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.4)
		headP.CFrame = bodyP.CFrame * CFrame.new(0, 0.7, 0)
		local w = Instance.new("WeldConstraint") w.Part0 = hand w.Part1 = bodyP w.Parent = bodyP
		m.Parent = c
		prizeBear = m
		onCleanup(function() m:Destroy() end)
	end
	conn(throwP.Triggered:Connect(function()
		if playing or done.prize then return end
		playing = true throwP.Enabled = false
		local hrp = hrpOf()
		local spotP = booth.ThrowSpot.Position
		if hrp then hrp.Anchored = true hrp.CFrame = CFrame.lookAt(spotP + Vector3.new(0, 3, 0), booth.BottleTable.Position + Vector3.new(0, 2.5, 0)) end
		ui.Visible = true
		local hits = 0
		for ringN = 1, 3 do
			info.Text = ("Ring %d of 3 \u{b7} land 2 to win  (hits: %d)"):format(ringN, hits)
			throwNow = false
			local t0 = os.clock()
			local speed = 1.1 + ringN * 0.25
			local x = 0
			while alive and not throwNow do
				x = (math.sin((os.clock() - t0) * speed * 2) + 1) / 2
				marker.Position = UDim2.fromScale(x, 0.5)
				task.wait()
			end
			if not alive then return end
			local hit = x >= 0.42 and x <= 0.58
			if hit then hits += 1 end
			flyRing(hit)
			info.Text = hit and "Ringer!" or "Missed!"
			task.wait(1)
		end
		ui.Visible = false
		if hrp then hrp.Anchored = false end
		playing = false
		if hits >= 2 then
			done.prize = true unglintRT() objective()
			giveBear()
			say("You win! The man hands you a little teddy bear. You hug it without thinking.", 4.5)
		else
			say(("%d out of 3. So close! The man smiles and hands you three more rings."):format(hits), 4)
			throwP.Enabled = true
		end
	end))

	-------------------------------------------------------- cotton candy
	local cart = D.CottonCandy.Cart
	local candyP = prompt(cart, "Get cotton candy", "Cotton candy", 0.5, 10)
	local unglintCC = glint(cart)
	conn(candyP.Triggered:Connect(function()
		if done.candy then return end
		done.candy = true candyP.Enabled = false unglintCC() objective()
		local c = player.Character
		local hand = c and (c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm"))
		if false and hand then -- (first person: a held item would block the view)
			local stick = Instance.new("Part") stick.Size = Vector3.new(0.1, 1.2, 0.1) stick.Color = Color3.fromRGB(240, 235, 220) stick.CanCollide = false stick.Massless = true
			stick.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.2)
			local fluff = Instance.new("Part") fluff.Shape = Enum.PartType.Ball fluff.Size = Vector3.new(0.8, 0.8, 0.8) fluff.Color = Color3.fromRGB(255, 170, 210) fluff.Material = Enum.Material.Fabric fluff.CanCollide = false fluff.Massless = true
			fluff.CFrame = stick.CFrame * CFrame.new(0, 0.7, 0)
			local w1 = Instance.new("WeldConstraint") w1.Part0 = hand w1.Part1 = stick w1.Parent = stick
			local w2 = Instance.new("WeldConstraint") w2.Part0 = stick w2.Part1 = fluff w2.Parent = fluff
			stick.Parent = c fluff.Parent = c
			onCleanup(function() stick:Destroy() fluff:Destroy() end)
		end
		say("Pink cotton candy, bigger than your head. It tastes exactly like you remember. You didn't know you remembered.", 5)
	end))

	-------------------------------------------------------- the ride (and the fireworks)
	local rideSign = make("Part", {Name = "RideSpot", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(C.X, O.Y + 3, C.Z + 9)}, D)
	local rideP = prompt(rideSign, "Ride the Ferris wheel", "Ferris wheel", 0.5, 10)
	rideP.Enabled = false
	local unglintRide
	local function firework()
		local pos = C + Vector3.new(math.random(-70, 70), math.random(25, 50), math.random(70, 170))
		local p = Instance.new("Part") p.Anchored = true p.CanCollide = false p.CanQuery = false p.Transparency = 1 p.Size = Vector3.new(1, 1, 1) p.CFrame = CFrame.new(pos) p.Parent = workspace
		local col = ({Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 210, 255), Color3.fromRGB(170, 255, 150), Color3.fromRGB(230, 140, 255)})[math.random(5)]
		local pe = Instance.new("ParticleEmitter") pe.Texture = "rbxasset://textures/particles/sparkles_main.dds" pe.Color = ColorSequence.new(col) pe.LightEmission = 1
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0)}) pe.Lifetime = NumberRange.new(1.4, 2.2) pe.Speed = NumberRange.new(18, 26)
		pe.SpreadAngle = Vector2.new(180, 180) pe.Drag = 1.5 pe.Acceleration = Vector3.new(0, -6, 0) pe.Rate = 0 pe.Parent = p
		pe:Emit(90)
		local l = Instance.new("PointLight") l.Range = 60 l.Brightness = 3 l.Color = col l.Parent = p
		TweenService:Create(l, TweenInfo.new(1.5), {Brightness = 0}):Play()
		sfx(SFX.Boom, 0.6, p, 0.9 + math.random() * 0.2)
		task.delay(4, function() p:Destroy() end)
	end
	conn(rideP.Triggered:Connect(function()
		if riding then return end
		rideP.Enabled = false if unglintRide then unglintRide() end
		-- bring gondola 1 to the bottom and climb in
		autoTurn = false
		local g1 = gondolas.Gondola1
		local function turnTo(target, t)
			local a0 = theta local t0 = os.clock()
			while alive and os.clock() - t0 < t do
				local f = (os.clock() - t0) / t f = f * f * (3 - 2 * f)
				theta = a0 + (target - a0) * f
				task.wait()
			end
			theta = target
		end
		-- the angle where gondola 1 is at the bottom (its base angle is -90 degrees)
		local bottom = math.ceil(theta / (2 * math.pi)) * 2 * math.pi
		turnTo(bottom, 2)
		local hrp = hrpOf()
		if hrp then hrp.Anchored = true end
		riding = g1
		setObjective("")
		say("You climb into the little car. It rocks a bit as it starts to rise.", 4)
		turnTo(bottom + math.pi, 14)
		if not alive then return end
		-- the top
		say("From up here you can see the whole fair. The lights, the music, everyone smiling.", 5)
		task.spawn(function() for _ = 1, 14 do if not alive then return end firework() task.wait(0.6 + math.random() * 0.9) end end)
		task.wait(5.5)
		say("Fireworks. Every color at once.", 3.5)
		task.wait(4)
		say("And far past the trees, a big house. One window is lit.", 4.5)
		task.wait(5)
		say("...You look back at the fireworks. Not tonight.", 4)
		task.wait(4.5)
		turnTo(bottom + 2 * math.pi, 14)
		if not alive then return end
		riding = nil
		if hrp then
			local off = Vector3.new(C.X, O.Y + 3, C.Z + 9)
			hrp.CFrame = CFrame.lookAt(off, off + Vector3.new(0, 0, 5))
			hrp.Anchored = false
		end
		autoTurn = true
		done.ride = true
		say("The best night. You don't want it to end.", 4)
		if door then for p, t in doorParts do p.CanCollide = true TweenService:Create(p, TweenInfo.new(2.5), {Transparency = t}):Play() end end
		task.wait(2.6)
		if alive then ctx.unlockDoor(D, 13) end
	end))
	task.spawn(function()
		while alive and not (done.prize and done.candy) do task.wait(0.3) end
		if not alive then return end
		task.wait(4)
		rideP.Enabled = true
		unglintRide = glint(rideSign)
		objective()
		narrate("ridenow", "The Ferris wheel is lit up like a crown. There's no line.", 4)
	end)

	-------------------------------------------------------- things to notice
	local spots = {
		{key = "carousel", pos = D.Carousel.Base.Position, r = 16, text = "The horses go up and down. A kid waves at you. You wave back."},
		{key = "family", pos = O + Vector3.new(0, 0, 30), r = 9, text = "A family laughing together. Nobody is in a hurry. Nobody is angry."},
	}
	task.spawn(function()
		while alive do
			local hrp = hrpOf()
			if hrp and not riding then for _, sp in spots do if not said[sp.key] and (Vector3.new(sp.pos.X, hrp.Position.Y, sp.pos.Z) - hrp.Position).Magnitude < sp.r then narrate(sp.key, sp.text, 4.5) end end end
			task.wait(0.4)
		end
	end)

	-- debug hook (testing): PlayerGui.FairDebug:Fire("prize")
	local dbg = make("BindableEvent", {Name = "FairDebug"}, player:WaitForChild("PlayerGui"))
	conn(dbg.Event:Connect(function(cmd) if cmd == "prize" and not done.prize then done.prize = true throwP.Enabled = false unglintRT() giveBear() objective() end end))

	-------------------------------------------------------- start
	say("A summer fair at sunset. Music, lights, the smell of popcorn. Everyone is smiling.", 5)
	task.wait(5.5)
	say("For once, nothing is wrong. Go and have fun.", 3.5)
	objective()
end

return M
