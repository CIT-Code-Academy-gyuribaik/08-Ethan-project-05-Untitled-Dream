-- Lake: Dream 8 "The Lake Trip". A peaceful morning at a lake.
-- Mission: light the campfire, catch a fish off the pier, row to the island and take a timer photo -> the Dream Door appears.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local SFX = {
	Fire = "rbxassetid://109494611784143",
	Splash = "rbxassetid://9117941626",
	Row = "rbxassetid://9118729626",
	Shutter = "rbxassetid://9113025284",
}

local M = {}

function M.run(ctx, D)
	local player = ctx.player
	local pop, setObjective, tween, active, gui = ctx.pop, ctx.setObjective, ctx.tween, ctx.active, ctx.gui

	local alive = true
	local cleanup, conns = {}, {}
	local function onCleanup(f) table.insert(cleanup, f) end
	local function conn(c) table.insert(conns, c) return c end
	local function hrpOf() local c = player.Character return c and c:FindFirstChild("HumanoidRootPart") end
	local function make(class, props, parent)
		local i = Instance.new(class)
		for k, v in props do i[k] = v end
		i.Parent = parent
		onCleanup(function() i:Destroy() end)
		return i
	end
	local function sfx(id, vol, parent, speed)
		local s = Instance.new("Sound")
		s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1
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
			if alive then say(text, hold or 4.5) end
		end)
	end
	local function prompt(part, action, object, hold, dist)
		return make("ProximityPrompt", {ActionText = action, ObjectText = object or "", HoldDuration = hold or 0.3, MaxActivationDistance = dist or 8, RequiresLineOfSight = false}, part)
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

	-- the door stays hidden until the end
	local door = D:FindFirstChild("Door")
	local doorParts = {}
	if door then
		for _, p in door:GetDescendants() do
			if p:IsA("BasePart") then doorParts[p] = p.Transparency p.Transparency = 1 p.CanCollide = false end
		end
		onCleanup(function() for p, t in doorParts do p.Transparency = t p.CanCollide = true end end)
	end

	local done = {}
	local function objective()
		local function m(k, n) return done[k] and ("\u{2713} " .. n) or n end
		setObjective(("%s \u{b7} %s \u{b7} %s"):format(m("fire", "Campfire"), m("fish", "Fish"), m("photo", "Island photo")))
	end
	local busy = false
	-- things you can use glow softly (and sparkle) so they are easy to find
	local function glint(part)
		local l = make("PointLight", {Color = Color3.fromRGB(255, 225, 160), Range = 7, Brightness = 1.2, Shadows = false}, part)
		local s = make("Sparkles", {SparkleColor = Color3.fromRGB(255, 235, 180)}, part)
		return function() l:Destroy() s:Destroy() end
	end
	-- big centred hint (used while fishing)
	local bigHint = make("TextLabel", {Size = UDim2.new(1, -40, 0, 44), Position = UDim2.new(0, 20, 0.62, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 30,
		TextColor3 = Color3.fromRGB(255, 245, 220), TextStrokeTransparency = 0.3, Text = "", ZIndex = 15}, gui)

	-------------------------------------------------------- campfire
	local camp = D.Camp
	local fire = camp.Fire
	local firewood = camp:FindFirstChild("Firewood")
	local fireP = prompt(firewood, "Light", "Campfire", 0.8, 10)
	local unglintFire = glint(firewood)
	conn(fireP.Triggered:Connect(function()
		if done.fire then return end
		fireP.Enabled = false
		unglintFire()
		done.fire = true objective()
		make("Fire", {Size = 4, Heat = 6, Color = Color3.fromRGB(255, 150, 60), SecondaryColor = Color3.fromRGB(255, 80, 20)}, fire)
		make("PointLight", {Range = 16, Brightness = 1.6, Color = Color3.fromRGB(255, 170, 90), Shadows = true}, fire)
		make("Smoke", {Size = 2, Opacity = 0.06, RiseVelocity = 4, Color = Color3.fromRGB(200, 200, 200)}, fire)
		local crackle = make("Sound", {SoundId = SFX.Fire, Volume = 0, Looped = true, RollOffMinDistance = 6, RollOffMaxDistance = 60}, fire)
		crackle:Play() tween(crackle, 2, {Volume = 0.6})
		say("You strike the match on the first try. Someone must have shown you how.", 4.5)
	end))

	-------------------------------------------------------- fishing
	local pier = D.Pier
	local spot = pier.FishSpot
	local rodPart = pier.Rod
	local rodCF = rodPart.CFrame
	onCleanup(function() rodPart.CFrame = rodCF end)
	local fishP = prompt(rodPart, "Fish", "Fishing rod", 0.3, 10)
	local unglintRod = glint(rodPart)
	local bobber, line
	local biting = false
	local function fishLoop()
		local hrp = hrpOf() if not hrp then return end
		busy = true
		hrp.Anchored = true
		local stand = spot.Position + Vector3.new(0, 2.6, 0)
		hrp.CFrame = CFrame.lookAt(stand, stand + Vector3.new(0, 0, -1))
		local tip = stand + Vector3.new(1.2, 2.5, -5)
		rodPart.CFrame = CFrame.lookAt(stand + Vector3.new(1.2, -0.6, -0.5), tip) * CFrame.new(0, 0, -rodPart.Size.Z / 2)
		local water = Vector3.new(spot.Position.X + 1.2, 498.15, spot.Position.Z - 12)
		bobber = make("Part", {Name = "Bobber", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Anchored = true, CanCollide = false, Color = Color3.fromRGB(230, 50, 40), Material = Enum.Material.SmoothPlastic, Position = water}, workspace)
		line = make("Part", {Name = "Line", Size = Vector3.new(0.04, 0.04, 1), Anchored = true, CanCollide = false, Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.SmoothPlastic, Transparency = 0.3}, workspace)
		sfx(SFX.Splash, 0.35, bobber, 1.4)
		local t0 = os.clock()
		local dipAt = t0 + 4 + math.random() * 3
		local c = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			local dip = (biting and math.sin(t * 18) * 0.25 - 0.25) or math.sin(t * 2) * 0.05
			bobber.Position = water + Vector3.new(0, dip, 0)
			local tipNow = rodPart.CFrame * CFrame.new(0, 0, -rodPart.Size.Z / 2)
			local a, b = tipNow.Position, bobber.Position
			line.Size = Vector3.new(0.04, 0.04, (a - b).Magnitude)
			line.CFrame = CFrame.lookAt((a + b) / 2, b)
		end)
		bigHint.Text = "Wait for the red bobber to dip..."
		narrate("pierwait", "You sit very still. You used to be bad at waiting. Not here.", 4)
		while alive and os.clock() < dipAt do task.wait(0.1) end
		if not alive then c:Disconnect() return end
		biting = true
		sfx(SFX.Splash, 0.5, bobber)
		fishP.ActionText = "Reel in!" fishP.Enabled = true fishP.HoldDuration = 0
		bigHint.Text = "It's biting! Press E to reel in!"
		local caughtIt = false
		local rc = fishP.Triggered:Connect(function() caughtIt = true end)
		local tEnd = os.clock() + 6
		while alive and not caughtIt and os.clock() < tEnd do task.wait(0.05) end
		rc:Disconnect()
		bigHint.Text = ""
		biting = false
		fishP.Enabled = false
		c:Disconnect()
		if bobber then bobber:Destroy() end
		if line then line:Destroy() end
		rodPart.CFrame = rodCF
		if caughtIt then
			-- a little fish, shown for a moment, then let go
			local fish = make("Part", {Name = "Fish", Size = Vector3.new(0.35, 0.6, 1.4), Anchored = true, CanCollide = false, Color = Color3.fromRGB(190, 200, 210), Material = Enum.Material.Foil,
				CFrame = CFrame.new(stand + Vector3.new(0.6, 0.2, -2.2)) * CFrame.Angles(0, math.rad(90), 0)}, workspace)
			sfx(SFX.Splash, 0.4, fish, 1.6)
			say("A small silver fish. It wriggles in your hands.", 3.5)
			task.wait(3.8)
			tween(fish, 0.8, {CFrame = fish.CFrame * CFrame.new(0, -4, -3), Transparency = 1})
			sfx(SFX.Splash, 0.45, spot, 1.2)
			say("You let it go. It feels like the right thing to do.", 3.5)
			if woman then narrate("clap", "Somewhere behind you, someone claps softly.", 3.5) end
			done.fish = true objective()
			unglintRod()
		else
			say("It got away. That's okay. Press E at the rod to try again.", 3.5)
		end
		hrp.Anchored = false
		fishP.ActionText = "Fish" fishP.HoldDuration = 0.3
		fishP.Enabled = not done.fish
		busy = false
	end
	conn(fishP.Triggered:Connect(function()
		if busy or done.fish or fishP.ActionText ~= "Fish" then return end
		fishP.Enabled = false
		task.spawn(fishLoop)
	end))

	-------------------------------------------------------- the rowboat
	local boat = D.Rowboat
	local boatHome = boat:GetPivot()
	onCleanup(function() boat:PivotTo(boatHome) end)
	local stop = D.Island.BoatStop
	local atIsland = false
	local rowP = prompt(boat.Bench, "Row", "Rowboat", 0.4, 9)
	local function row(toIsland)
		local hrp = hrpOf() if not hrp or busy then return end
		busy = true rowP.Enabled = false
		hrp.Anchored = true
		local from = boat:GetPivot()
		local goalPos = toIsland and Vector3.new(stop.Position.X, from.Position.Y, stop.Position.Z) or boatHome.Position
		local dir = (goalPos - from.Position) * Vector3.new(1, 0, 1)
		local goal = CFrame.lookAt(goalPos, goalPos + dir.Unit) -- bow (-Z) points where we're going
		local startCF = CFrame.lookAt(from.Position, from.Position + dir.Unit)
		local waves = sfx(SFX.Row, 0.5, boat.Hull)
		local dur = 9
		local t0 = os.clock()
		local c = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local e = a * a * (3 - 2 * a)
			local turn = math.clamp(a * 6, 0, 1)
			local cf = from:Lerp(startCF, turn):Lerp(goal, e)
			cf = cf * CFrame.new(0, math.sin(os.clock() * 2.2) * 0.08, 0) * CFrame.Angles(math.sin(os.clock() * 1.7) * 0.02, 0, math.sin(os.clock() * 1.3) * 0.03)
			boat:PivotTo(cf)
			hrp.CFrame = boat.Bench.CFrame * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.pi, 0)
		end)
		if toIsland then narrate("row", "The oars knock against the side. Somebody used to row while you trailed your hand in the water.", 5) end
		task.wait(dur)
		c:Disconnect()
		waves:Destroy()
		if not alive then return end
		-- step out onto the dock / pier
		local out = toIsland and (D.Island.Dock.Position + Vector3.new(0, 3, -1)) or (D.Pier.PierEnd.Position + Vector3.new(0, 3, 4))
		hrp.CFrame = CFrame.new(out)
		hrp.Anchored = false
		atIsland = toIsland
		rowP.ActionText = toIsland and "Row back" or "Row"
		rowP.Enabled = true
		busy = false
	end
	conn(rowP.Triggered:Connect(function() task.spawn(row, not atIsland) end))

	-------------------------------------------------------- the photo
	local tri = D.Island.Tripod
	local camBody, camLight = tri.Camera, tri.Light
	local mark = D.Island.Mark
	local photoP = prompt(camBody, "Set timer", "Old camera", 0.4, 8)
	local function polaroid()
		local frame = make("Frame", {Size = UDim2.fromOffset(250, 290), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1.4, 0), BackgroundColor3 = Color3.fromRGB(248, 246, 238), BorderSizePixel = 0, Rotation = -4, ZIndex = 20}, gui)
		make("UIStroke", {Color = Color3.fromRGB(200, 195, 185), Thickness = 1}, frame)
		local pic = make("Frame", {Size = UDim2.fromOffset(222, 210), Position = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(30, 28, 26), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 21}, frame)
		-- the picture fades in ("develops")
		local inner = make("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 22}, pic)
		make("Frame", {Size = UDim2.new(1, 0, 0.55, 0), BackgroundColor3 = Color3.fromRGB(190, 215, 230), BorderSizePixel = 0, ZIndex = 22}, inner)
		make("Frame", {Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.new(0, 0, 0.43, 0), BackgroundColor3 = Color3.fromRGB(95, 130, 95), BorderSizePixel = 0, ZIndex = 22}, inner)
		make("Frame", {Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.new(0, 0, 0.55, 0), BackgroundColor3 = Color3.fromRGB(120, 160, 185), BorderSizePixel = 0, ZIndex = 22}, inner)
		make("Frame", {Size = UDim2.new(1, 0, 0.25, 0), Position = UDim2.new(0, 0, 0.75, 0), BackgroundColor3 = Color3.fromRGB(110, 150, 85), BorderSizePixel = 0, ZIndex = 22}, inner)
		-- three people by the water: tall, small, medium. No faces; it's a little blurry.
		local people = {{x = 62, h = 118, w = 30, shirt = Color3.fromRGB(225, 215, 190)}, {x = 108, h = 66, w = 22, shirt = Color3.fromRGB(240, 200, 80)}, {x = 152, h = 100, w = 28, shirt = Color3.fromRGB(170, 90, 110)}}
		for _, p in people do
			local base = 190
			make("Frame", {Size = UDim2.fromOffset(p.w, p.h * 0.45), Position = UDim2.fromOffset(p.x - p.w / 2, base - p.h * 0.45), BackgroundColor3 = Color3.fromRGB(70, 75, 90), BorderSizePixel = 0, ZIndex = 23}, inner)
			make("Frame", {Size = UDim2.fromOffset(p.w, p.h * 0.4), Position = UDim2.fromOffset(p.x - p.w / 2, base - p.h * 0.85), BackgroundColor3 = p.shirt, BorderSizePixel = 0, ZIndex = 23}, inner)
			local hd = make("Frame", {Size = UDim2.fromOffset(p.w * 0.7, p.w * 0.7), Position = UDim2.fromOffset(p.x - p.w * 0.35, base - p.h * 0.85 - p.w * 0.72), BackgroundColor3 = Color3.fromRGB(225, 190, 160), BorderSizePixel = 0, ZIndex = 23}, inner)
			make("UICorner", {CornerRadius = UDim.new(0.3, 0)}, hd)
		end
		make("Frame", {Size = UDim2.fromOffset(12, 6), Position = UDim2.fromOffset(112, 150), BackgroundColor3 = Color3.fromRGB(200, 210, 220), BorderSizePixel = 0, ZIndex = 24}, inner) -- the fish
		-- soft haze over everything (old film)
		make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 235, 200), BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 25}, inner)
		make("TextLabel", {Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 230), BackgroundTransparency = 1, Font = Enum.Font.PermanentMarker, TextSize = 22, TextColor3 = Color3.fromRGB(60, 60, 90), Text = "the lake \u{2661}", ZIndex = 21}, frame)
		tween(frame, 1.2, {Position = UDim2.new(0.5, 0, 0.5, 0)})
		task.wait(1.4)
		tween(inner, 6, {GroupTransparency = 0})
		return frame
	end
	conn(photoP.Triggered:Connect(function()
		if busy or done.photo then return end
		if not (done.fire and done.fish) then
			say("Not yet. You want the picture to be of a perfect day.", 3.5)
			return
		end
		busy = true photoP.Enabled = false
		say("10 seconds. Stand on the X!", 3)
		for i = 10, 1, -1 do
			camLight.Color = Color3.fromRGB(255, 60, 50)
			sfx(SFX.Shutter, 0.15, camBody, 3)
			task.wait(0.15) camLight.Color = Color3.fromRGB(80, 20, 20)
			task.wait(i <= 3 and 0.35 or 0.85)
			if not alive then return end
		end
		local hrp = hrpOf()
		local onMark = hrp and (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(mark.Position.X, 0, mark.Position.Z)).Magnitude < 3
		sfx(SFX.Shutter, 0.8, camBody)
		local flash = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 19}, gui)
		tween(flash, 1.2, {BackgroundTransparency = 1})
		if not onMark then
			task.wait(1)
			say("Click. ...You weren't on the X. Try again.", 3)
			busy = false photoP.Enabled = true
			return
		end
		done.photo = true objective()
		task.wait(1.3)
		if hrp then hrp.Anchored = true end
		local card = polaroid()
		say("The picture comes out slowly. Three people by the water.", 4.5)
		task.wait(5)
		say("You were alone on the island when you took it.", 3.5)
		task.wait(4)
		say("...It's a nice picture, though. You keep it.", 4)
		task.wait(4.5)
		if not alive then return end
		tween(card, 1, {Position = UDim2.new(0.5, 0, 1.5, 0)})
		if hrp then hrp.Anchored = false end
		busy = false
		if door then
			for p, t in doorParts do
				p.CanCollide = true
				TweenService:Create(p, TweenInfo.new(2.5), {Transparency = t}):Play()
			end
		end
		task.wait(2.6)
		if alive then ctx.unlockDoor(D, 8) end
	end))

	-------------------------------------------------------- the woman on the blanket (face covered with paper notes, like the kids)
	local woman = D:FindFirstChild("Woman")
	local womanPos
	if woman then
		local head, torso = woman.Head, woman.UpperTorso
		local neck = torso.CFrame * CFrame.new(0, torso.Size.Y / 2, 0)
		-- everything attached to the head turns with it
		local headParts = {}
		for _, p in woman:GetChildren() do
			if p:IsA("BasePart") and (p == head or p.Name:match("^Hair") or p.Name:match("^Hat") or p.Name == "ScribbleFace") then headParts[p] = neck:ToObjectSpace(p.CFrame) end
		end
		onCleanup(function() for p, o in headParts do p.CFrame = neck * o end end)
		local pxs = {} -- (face is paper notes now; nothing drifts)
		womanPos = head.Position
		local yaw = 0
		conn(RunService.RenderStepped:Connect(function(dt)
			local t = os.clock()
			local hrp = hrpOf()
			local want = 0
			if hrp then
				local rel = neck:PointToObjectSpace(hrp.Position)
				if rel.Magnitude < 22 then want = math.clamp(math.atan2(-rel.X, -rel.Z), -1.1, 1.1) end
			end
			yaw += (want - yaw) * math.min(dt * 1.5, 1)
			local r = neck * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.sin(t * 0.8) * 0.03, 0, 0)
			for p, o in headParts do p.CFrame = r * o end
		end))
		task.spawn(function()
			while alive do
				local hrp = hrpOf()
				if hrp then
					local d = (hrp.Position - womanPos).Magnitude
					if d < 16 then narrate("hum", "She's humming. You know the tune, but not the words.", 4.5) end
					if d < 7 then narrate("womanface", "Paper notes cover her face, with a smile drawn on top. You can't remember what was under it.", 5) end
					if d < 7 and said.womanface and os.clock() > (said.womanT or 0) then
						said.womanT = os.clock() + 1e9
						task.delay(9, function() if alive then narrate("womanstay", "You could sit here a while. Nobody would mind.", 4) end end)
					end
				end
				task.wait(0.4)
			end
		end)
	end

	-------------------------------------------------------- small things (by proximity)
	local spots = {
		{key = "pier", pos = D.Pier.Plank.Position, r = 6, text = "The boards creak in all the same places."},
		{key = "tent", pos = D.Camp.TentBack.Position, r = 8, text = "Three sleeping bags. The yellow one is very small."},
		{key = "food", pos = D.Camp.Sandwiches.Position, r = 6, text = "Sandwiches with the crusts cut off. Exactly how you like them."},
	}
	local car = D:FindFirstChild("FamilyCar")
	if car then table.insert(spots, {key = "car", pos = car:GetPivot().Position, r = 12, text = "Someone drew a smiley face in the dust on the back window. It's a little crooked."}) end
	local isl = D.Island.Dock.Position
	table.insert(spots, {key = "island", pos = isl, r = 8, text = "The island is smaller than it looks from the shore. It always was."})
	task.spawn(function()
		local t0 = os.clock()
		while alive do
			local hrp = hrpOf()
			if hrp then
				for _, s in spots do
					if not said[s.key] and (Vector3.new(s.pos.X, hrp.Position.Y, s.pos.Z) - hrp.Position).Magnitude < s.r then narrate(s.key, s.text, 4.5) end
				end
			end
			if os.clock() - t0 > 100 then narrate("calm", "Nobody is rushing you. You'd forgotten what that feels like.", 4.5) end
			task.wait(0.4)
		end
	end)

	-------------------------------------------------------- start
	say("A lake in the morning. It smells like pine needles and sunscreen.", 4.5)
	task.wait(5)
	objective()
	say("Things you can use are sparkling. The campfire is to the right, the fishing rod is on the pier to the left.", 5.5)
	-- once the fire and the fish are done, the boat and the camera sparkle too
	while alive and not (done.fire and done.fish) do task.wait(0.5) end
	if not alive then return end
	local unB = glint(D.Rowboat.Bench)
	local unC = glint(D.Island.Tripod.Camera)
	task.wait(4)
	narrate("rownow", "Now row the boat to the island and take a picture.", 4)
	while alive and not done.photo do task.wait(0.5) end
	unB() unC()
end

return M
