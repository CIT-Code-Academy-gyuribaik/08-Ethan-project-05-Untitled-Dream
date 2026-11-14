-- Playground: Dream 6 "Golden Hour". A calm breather after the house, with small things that are slightly off.
-- Mission: play on the swing, the slide and the merry-go-round -> the Dream Door appears.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, active = ctx.pop, ctx.setObjective, ctx.tween, ctx.active
	local cam = workspace.CurrentCamera

	local alive = true
	local cleanup, conns = {}, {}
	local function onCleanup(f) table.insert(cleanup, f) end
	local function conn(c) table.insert(conns, c) return c end
	local function hrpOf() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end

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
			if alive then say(text, hold or 4.5) end
		end)
	end
	local function prompt(part, action, object, hold, dist)
		local p = Instance.new("ProximityPrompt")
		p.ActionText = action p.ObjectText = object or "" p.HoldDuration = hold or 0.2 p.MaxActivationDistance = dist or 8 p.RequiresLineOfSight = false
		p.Parent = part
		onCleanup(function() p:Destroy() end)
		return p
	end

	local function shutdown()
		if not alive then return end
		alive = false
		for _, c in conns do c:Disconnect() end
		for i = #cleanup, 1, -1 do pcall(cleanup[i]) end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
	end
	task.spawn(function()
		while alive and active() do task.wait(0.3) end
		shutdown()
	end)

	-- the door stays hidden until you're done playing
	local door = D:FindFirstChild("Door")
	local doorParts = {}
	if door then
		for _, p in door:GetDescendants() do
			if p:IsA("BasePart") then
				doorParts[p] = p.Transparency
				p.Transparency = 1 p.CanCollide = false
			end
		end
		onCleanup(function() for p, t in doorParts do p.Transparency = t p.CanCollide = true end end)
	end

	local done = {}
	local function objective()
		local function m(k, n) return done[k] and ("\u{2713} " .. n) or n end
		setObjective(("Play:  %s  \u{b7}  %s  \u{b7}  %s"):format(m("swing", "Swing"), m("slide", "Slide"), m("spin", "Merry-go-round")))
	end
	local busy = false
	local function lockPlayer(on)
		local hrp = hrpOf()
		if hrp then hrp.Anchored = on end
	end

	-------------------------------------------------------- swings
	local swingSet = D.SwingSet
	local function swingRig(model)
		local pivotY = model:GetAttribute("PivotY")
		local seat = model.Seat
		local pivot = CFrame.new(seat.Position.X, pivotY, seat.Position.Z)
		local offs = {}
		for _, p in model:GetChildren() do if p:IsA("BasePart") then offs[p] = pivot:ToObjectSpace(p.CFrame) end end
		onCleanup(function() for p, o in offs do p.CFrame = pivot * o end end)
		return function(angle)
			local cf = pivot * CFrame.Angles(angle, 0, 0)
			for p, o in offs do p.CFrame = cf * o end
			return cf * offs[seat]
		end
	end
	local setSwing1 = swingRig(swingSet.Swing1)
	local setSwing2 = swingRig(swingSet.Swing2)
	local ghostSwing = 0 -- amplitude of the empty swing
	conn(RunService.RenderStepped:Connect(function()
		if ghostSwing > 0 then setSwing2(math.sin(os.clock() * 2.1) * ghostSwing) end
	end))
	local function doSwing(setter)
		if busy then return end
		busy = true
		local hrp = hrpOf()
		if not hrp then busy = false return end
		lockPlayer(true)
		local t0 = os.clock()
		local dur = 7
		local c = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local amp = math.min(t / 2.2, 1) * math.min((dur - t) / 1.5, 1) * 0.65
			local seatCF = setter(math.sin(t * 2.2) * math.max(amp, 0))
			hrp.CFrame = seatCF * CFrame.new(0, 2.4, 0.3)
		end)
		task.wait(dur)
		c:Disconnect()
		setter(0)
		local seat = hrp.CFrame
		hrp.CFrame = CFrame.new(seat.Position + Vector3.new(0, 0.3, 3))
		lockPlayer(false)
		busy = false
	end
	for i, s in {swingSet.Swing1, swingSet.Swing2} do
		local setter = (i == 1) and setSwing1 or setSwing2
		local pr = prompt(s.Seat, "Swing", "Swing", 0.2, 7)
		conn(pr.Triggered:Connect(function()
			if busy then return end
			if i == 2 and ghostSwing > 0 then say("It's already moving. You leave it alone.", 3) return end
			doSwing(setter)
			if not done.swing then
				done.swing = true objective()
				say("Higher. Higher. For a second you feel weightless.", 4)
				task.delay(6, function()
					if not alive then return end
					ghostSwing = 0.35
					narrate("ghost", "The other swing is still moving. There's no wind.", 4.5)
				end)
			end
		end))
	end

	-------------------------------------------------------- slide
	local slide = D.Slide
	local topPos = slide:GetAttribute("SlideTop")
	local botPos = slide:GetAttribute("SlideBottom")
	local ladderP = prompt(slide.Rung, "Climb up", "Ladder", 0.2, 8)
	local slideP = prompt(slide.Platform, "Slide down", "Slide", 0.2, 6)
	conn(ladderP.Triggered:Connect(function()
		if busy then return end
		local hrp = hrpOf() if not hrp then return end
		busy = true lockPlayer(true)
		local up = CFrame.lookAt(slide.Platform.Position + Vector3.new(0, 3.3, 0), slide.Platform.Position + Vector3.new(0, 3.3, 5))
		local tw = TweenService:Create(hrp, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {CFrame = up}) tw:Play() tw.Completed:Wait()
		lockPlayer(false) busy = false
		narrate("top", "From up here, the playground looks smaller than you remember.", 4.5)
	end))
	conn(slideP.Triggered:Connect(function()
		if busy then return end
		local hrp = hrpOf() if not hrp then return end
		if hrp.Position.Y < slide.Platform.Position.Y then say("You have to climb up first.", 2) return end
		busy = true lockPlayer(true)
		local dir = (botPos - topPos).Unit
		local flat = Vector3.new(dir.X, 0, dir.Z).Unit
		hrp.CFrame = CFrame.lookAt(topPos + Vector3.new(0, 2.6, 0), topPos + Vector3.new(0, 2.6, 0) + flat)
		task.wait(0.2)
		local tw = TweenService:Create(hrp, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = CFrame.lookAt(botPos + Vector3.new(0, 2.6, 0), botPos + Vector3.new(0, 2.6, 0) + flat)})
		tw:Play() tw.Completed:Wait()
		local tw2 = TweenService:Create(hrp, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.lookAt(botPos + flat * 2.5 + Vector3.new(0, 2.6, 0), botPos + flat * 5 + Vector3.new(0, 2.6, 0))})
		tw2:Play() tw2.Completed:Wait()
		lockPlayer(false) busy = false
		if not done.slide then
			done.slide = true objective()
			say("Whee. ...You laughed out loud. It sounded strange here.", 4.5)
		end
	end))

	-------------------------------------------------------- merry-go-round
	local mg = D.MerryGoRound
	local center = mg:GetAttribute("Center")
	local mgOffs = {}
	local axis = CFrame.new(center)
	for _, p in mg:GetChildren() do if p:IsA("BasePart") and p.Name ~= "Base" then mgOffs[p] = axis:ToObjectSpace(p.CFrame) end end
	onCleanup(function() for p, o in mgOffs do p.CFrame = axis * o end end)
	local mgAngle, mgSpeed = 0, 0
	conn(RunService.Heartbeat:Connect(function(dt)
		if mgSpeed > 0.01 then
			mgAngle += mgSpeed * dt
			mgSpeed *= (1 - 0.18 * dt)
			local cf = axis * CFrame.Angles(0, mgAngle, 0)
			for p, o in mgOffs do p.CFrame = cf * o end
		end
	end))
	local handle
	for _, p in mg:GetChildren() do if p.Name == "Handle" then handle = p break end end
	local spinP = prompt(mg.Disc, "Push", "Merry-go-round", 0.5, 9)
	conn(spinP.Triggered:Connect(function()
		mgSpeed = math.min(mgSpeed + 2.6, 4)
		if not done.spin then
			done.spin = true objective()
			say("Round and round it goes.", 3)
			task.delay(14, function() if alive then narrate("creak", "It's still turning. Faster than you pushed it.", 4) end end)
		end
	end))

	-------------------------------------------------------- the kids (faces covered with paper notes, a face drawn on top)
	local kidsFolder = D:FindFirstChild("Kids")
	local kids = {}
	if kidsFolder then
		for _, m in kidsFolder:GetChildren() do
			local head, plate, torso = m:FindFirstChild("Head"), m:FindFirstChild("ScribbleFace"), m:FindFirstChild("UpperTorso")
			if head and torso then
				local neck = torso.CFrame * CFrame.new(0, torso.Size.Y / 2, 0)
				local k = {model = m, head = head, plate = plate, neck = neck, yaw = 0,
					headOff = neck:ToObjectSpace(head.CFrame), plateOff = plate and neck:ToObjectSpace(plate.CFrame),
					trans = {}}
				for _, p in m:GetDescendants() do if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p ~= plate then k.trans[p] = p.Transparency end end
				table.insert(kids, k)
			end
		end
		onCleanup(function()
			for _, k in kids do
				k.head.CFrame = k.neck * k.headOff
				if k.plate then k.plate.CFrame = k.neck * k.plateOff end
				for p, t in k.trans do p.Transparency = t end
				if k.plate then for _, g in k.plate:GetDescendants() do if g:IsA("SurfaceGui") then g.Enabled = true end end end
			end
		end)
	end
	local kidsGone = false
	-- heads turn (slowly) to follow you
	conn(RunService.RenderStepped:Connect(function(dt)
		local hrp = hrpOf()
		if not hrp or kidsGone then return end
		for _, k in kids do
			local rel = k.neck:PointToObjectSpace(hrp.Position)
			local want = 0
			if rel.Magnitude < 45 then want = math.clamp(math.atan2(-rel.X, -rel.Z), -1.3, 1.3) end
			k.yaw += (want - k.yaw) * math.min(dt * 0.9, 1)
			local r = k.neck * CFrame.Angles(0, k.yaw, 0)
			k.head.CFrame = r * k.headOff
			if k.plate then k.plate.CFrame = r * k.plateOff end
		end
	end))
	local function kidsVanish()
		kidsGone = true
		for _, k in kids do
			for p in k.trans do TweenService:Create(p, TweenInfo.new(1.5), {Transparency = 1}):Play() end
			if k.plate then task.delay(1.2, function() for _, g in k.plate:GetDescendants() do if g:IsA("SurfaceGui") then g.Enabled = false end end end) end
		end
	end
	local function nearestKid(r)
		local hrp = hrpOf() if not hrp then return nil end
		for _, k in kids do if (k.head.Position - hrp.Position).Magnitude < r then return k end end
	end
	local kidSeen, seenSet = 0, {}
	task.spawn(function()
		while alive and not kidsGone do
			local k = nearestKid(9)
			if k and not seenSet[k] then seenSet[k] = true kidSeen += 1 end
			if k then
				if kidSeen == 1 then narrate("kidface", "Someone covered this kid's face with paper notes, then drew a new one on top.", 5)
				elseif kidSeen >= 3 then narrate("kidall", "All of them have one. You try to picture what's under the paper, and you can't.", 5)
				end
				if k.model.Name == "BalloonKid" then narrate("kidshoe", "This one is only wearing one red shoe.", 4) end
				if k.model.Name == "FenceKid" then narrate("kidfence", "This one isn't playing. It's just been watching you. Since you got here.", 4.5) end
			end
			task.wait(0.5)
		end
	end)

	-------------------------------------------------------- small things that are off (by proximity)
	local spots = {
		{key = "seesaw", pos = D.Seesaw.Fulcrum.Position, r = 10, text = "The kid on the seesaw is up high. The other end is pressed all the way down. Nobody is sitting on it."},
		{key = "shoe", pos = D.Sandbox.Shoe.Position, r = 8, text = "A tiny red shoe in the sand. It would have fit you, a long time ago."},
		{key = "jacket", pos = D.Bench.Jacket.Position, r = 7, text = "Someone left a jacket on the bench. It smells like smoke and something sweet."},
		{key = "balloon", pos = D.Bench.Balloon.Position - Vector3.new(0, 6, 0), r = 8, text = "The red balloon bobs on its string. The air is perfectly still."},
	}
	task.spawn(function()
		local t0 = os.clock()
		while alive do
			local hrp = hrpOf()
			if hrp then
				for _, s in spots do
					if not said[s.key] and (Vector3.new(s.pos.X, hrp.Position.Y, s.pos.Z) - hrp.Position).Magnitude < s.r then narrate(s.key, s.text, 4.5) end
				end
			end
			if os.clock() - t0 > 75 then narrate("sun", "The sun hasn't moved since you got here.", 4) end
			task.wait(0.4)
		end
	end)

	-------------------------------------------------------- start
	say("Warm light. Kids are playing everywhere. None of them make a sound.", 4.5)
	task.delay(20, function() if alive and not kidsGone then narrate("kidturn", "You keep feeling them turn to look at you.", 4) end end)
	task.wait(5)
	objective()
	while alive and not (done.swing and done.slide and done.spin) do task.wait(0.3) end
	if not alive then return end
	task.wait(4)
	say("It's getting late. You should go home.", 3.5)
	kidsVanish()
	task.wait(4.2)
	say("...No. Not home.", 3)
	task.delay(3.5, function() if alive then say("The other kids already went home. You didn't see them leave.", 4) end end)
	if door then
		for p, t in doorParts do
			p.CanCollide = true
			TweenService:Create(p, TweenInfo.new(2.5), {Transparency = t}):Play()
		end
	end
	task.wait(2.6)
	if alive then ctx.unlockDoor(D, 6) end
end

return M
