-- Birthday: Dream 9 "The Birthday". A party in the living room. Lots of chairs; only two guests came.
-- Mission: open 3 presents -> sit in your seat (everyone sings) -> make a wish -> the Dream Door appears.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local SFX = {
	Song = "rbxassetid://97102550389175", -- Happy Birthday (lullaby music box)
	Blow = "rbxassetid://9113702967",
	Paper = "rbxassetid://9117410302",
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
	local function setp(inst, props)
		local old = {}
		for k, v in props do old[k] = inst[k] inst[k] = v end
		onCleanup(function() for k, v in old do pcall(function() inst[k] = v end) end end)
	end
	local function sfx(id, vol, parent, speed)
		local s = Instance.new("Sound")
		s.SoundId = id s.Volume = vol or 0.6 s.PlaybackSpeed = speed or 1
		s.Parent = parent or SoundService s:Play()
		task.delay(20, function() s:Destroy() end)
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
	local function glint(part)
		local l = make("PointLight", {Color = Color3.fromRGB(255, 225, 160), Range = 7, Brightness = 1.2, Shadows = false}, part)
		local s = make("Sparkles", {SparkleColor = Color3.fromRGB(255, 235, 180)}, part)
		return function() l:Destroy() s:Destroy() end
	end
	-- sung lines (gold, in quotes, centred higher up)
	local song = make("TextLabel", {Size = UDim2.new(1, -40, 0, 44), Position = UDim2.new(0, 20, 0.22, 0), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 32,
		TextColor3 = Color3.fromRGB(255, 225, 140), TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.fromRGB(120, 70, 90), Text = "", TextTransparency = 1, TextWrapped = true, ZIndex = 15}, gui)
	local function sing(text, hold)
		song.Text = "\u{266A} " .. text .. " \u{266A}" song.TextTransparency = 0 song.TextStrokeTransparency = 0.3
		task.delay(hold - 0.3, function() if alive then tween(song, 0.3, {TextTransparency = 1, TextStrokeTransparency = 1}) end end)
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

	local party = D.Party
	local chairs = party.Chairs
	local opened = 0
	local seated, wished = false, false
	local function objective()
		local pres = opened >= 3 and "\u{2713} Presents" or ("Presents %d/3"):format(opened)
		setObjective(("%s \u{b7} %s \u{b7} %s"):format(pres, seated and "\u{2713} Your seat" or "Your seat", wished and "\u{2713} Make a wish" or "Make a wish"))
	end

	-------------------------------------------------------- everyone turns to look at you
	local heads = {}
	local function addHead(m)
		local head, torso = m:FindFirstChild("Head"), m:FindFirstChild("UpperTorso")
		if not (head and torso) then return end
		local neck = torso.CFrame * CFrame.new(0, torso.Size.Y / 2, 0)
		local parts = {}
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and (p == head or p.Name == "ScribbleFace" or p.Name:match("^Hair")) then parts[p] = neck:ToObjectSpace(p.CFrame) end
		end
		local h = {neck = neck, parts = parts, yaw = 0, look = nil}
		table.insert(heads, h)
		onCleanup(function() for p, o in parts do p.CFrame = neck * o end end)
	end
	for _, m in D.Guests:GetChildren() do addHead(m) end
	local lookTarget = nil -- when set, everyone looks there instead of at you
	conn(RunService.RenderStepped:Connect(function(dt)
		local hrp = hrpOf()
		local target = lookTarget or (hrp and hrp.Position + Vector3.new(0, 1.5, 0))
		if not target then return end
		for _, h in heads do
			local rel = h.neck:PointToObjectSpace(target)
			local want = (rel.Magnitude < 40) and math.clamp(math.atan2(-rel.X, -rel.Z), -1.3, 1.3) or 0
			h.yaw += (want - h.yaw) * math.min(dt * (lookTarget and 3 or 1.2), 1)
			local r = h.neck * CFrame.Angles(0, h.yaw, 0)
			for p, o in h.parts do p.CFrame = r * o end
		end
	end))

	-------------------------------------------------------- presents
	local gifts = D.Presents
	local yourChair = chairs.YourChair
	local sitP -- forward
	local giftInfo = {
		PresentRed = {text = "A little red toy car. You lost one just like it, a long time ago.", item = "car"},
		PresentBlue = {text = "A box of crayons. The black one is already worn down to a stub.", item = "crayons"},
		PresentSmall = {text = "It's empty. There's only a card inside: \"Sorry I couldn't make it.\" It isn't signed.", item = "card"},
	}
	local function showItem(kind, at)
		if kind == "car" then
			local body = make("Part", {Name = "ToyCar", Size = Vector3.new(1.2, 0.35, 0.6), Anchored = true, CanCollide = false, Color = Color3.fromRGB(215, 40, 40), CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0))}, workspace)
			make("Part", {Size = Vector3.new(0.6, 0.3, 0.55), Anchored = true, CanCollide = false, Color = Color3.fromRGB(180, 220, 240), Material = Enum.Material.Glass, CFrame = body.CFrame * CFrame.new(-0.1, 0.3, 0)}, workspace)
			for _, x in {-0.4, 0.4} do for _, z in {-0.32, 0.32} do
				make("Part", {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.3, 0.3), Anchored = true, CanCollide = false, Color = Color3.fromRGB(30, 30, 30), CFrame = body.CFrame * CFrame.new(x, -0.15, z) * CFrame.Angles(0, math.rad(90), 0)}, workspace)
			end end
		elseif kind == "crayons" then
			local box = make("Part", {Name = "Crayons", Size = Vector3.new(1, 0.15, 0.7), Anchored = true, CanCollide = false, Color = Color3.fromRGB(250, 210, 60), CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0))}, workspace)
			local cols = {Color3.fromRGB(220, 50, 50), Color3.fromRGB(60, 120, 220), Color3.fromRGB(60, 180, 80), Color3.fromRGB(250, 200, 40), Color3.fromRGB(150, 80, 200), Color3.fromRGB(20, 20, 20)}
			for i, c in cols do
				local len = (i == 6) and 0.25 or 0.9
				make("Part", {Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 0.12, 0.12), Anchored = true, CanCollide = false, Color = c, CFrame = box.CFrame * CFrame.new(-0.4 + i * 0.13 - 0.05, 0.12, (0.9 - len) / 2 - 0.05) * CFrame.Angles(0, math.rad(90), 0)}, workspace)
			end
		else
			local c = make("Part", {Name = "Card", Size = Vector3.new(0.7, 0.04, 0.5), Anchored = true, CanCollide = false, Color = Color3.fromRGB(250, 248, 240), CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0.3, 0)}, workspace)
		end
	end
	for _, box in gifts:GetChildren() do
		local info = giftInfo[box.Name]
		if info then
			local unglint = glint(box)
			local pr = prompt(box, "Open", "Present", 0.6, 8)
			conn(pr.Triggered:Connect(function()
				pr.Enabled = false unglint()
				sfx(SFX.Paper, 0.7, box)
				local ground = box.Position - Vector3.new(0, box.Size.Y / 2, 0)
				setp(box, {Transparency = 1, CanCollide = false})
				for _, r in box:GetChildren() do if r:IsA("BasePart") then setp(r, {Transparency = 1}) end end
				-- torn paper bits
				for i = 1, 4 do
					make("Part", {Size = Vector3.new(0.6, 0.03, 0.4), Anchored = true, CanCollide = false, Color = box.Color, CFrame = CFrame.new(ground + Vector3.new(math.random(-12, 12) / 10, 0.02, math.random(-12, 12) / 10)) * CFrame.Angles(0, math.random() * 6, 0)}, workspace)
				end
				showItem(info.item, ground)
				opened += 1 objective()
				say(info.text, 5)
				if opened >= 3 then
					task.delay(5.5, function()
						if not alive then return end
						sitP.Enabled = true
						glint(yourChair.Seat)
						narrate("sitnow", "They're waiting for you. Your seat is the one with the balloons.", 4)
					end)
				end
			end))
		end
	end
	-- the present on the empty chair
	local cp = party:FindFirstChild("ChairPresent")
	if cp then
		local pr = prompt(cp, "Open", "Present", 0.6, 7)
		conn(pr.Triggered:Connect(function() say("It isn't yours. You leave it where it is.", 3) end))
	end

	-------------------------------------------------------- your seat + the song
	local cake = party.Cake
	local flames = {}
	for _, p in cake:GetChildren() do if p.Name == "Flame" then table.insert(flames, p) end end
	local wishP = prompt(cake.Frosting, "Make a wish", "Cake", 1.2, 16)
	wishP.Enabled = false
	sitP = prompt(yourChair.Seat, "Sit", "Your seat", 0.4, 8)
	sitP.Enabled = false
	conn(sitP.Triggered:Connect(function()
		if seated then return end
		local hrp = hrpOf() if not hrp then return end
		sitP.Enabled = false
		seated = true objective()
		hrp.Anchored = true
		local seat = yourChair.Seat
		local tablePos = party.TableTop.Position
		local p = seat.Position + Vector3.new(0, 2.2, 0)
		hrp.CFrame = CFrame.lookAt(p, Vector3.new(tablePos.X, p.Y, tablePos.Z))
		say("The name card at this seat is smudged. It's your seat anyway. You can tell.", 4.5)
		task.wait(5)
		if not alive then return end
		local music = sfx(SFX.Song, 0.6)
		local lines = {"Happy birthday to you", "Happy birthday to you", "Happy birthday, dear  ~  ~  ~", "Happy birthday to you"}
		for i, l in lines do
			sing(l, 3.2)
			task.wait(3.4)
			if not alive then return end
			if i == 3 then narrate("name", "They both hum through the name. Neither of them seems to know it.", 4) end
		end
		tween(music, 2, {Volume = 0})
		say("Make a wish.", 3)
		wishP.Enabled = true
	end))
	conn(wishP.Triggered:Connect(function()
		if wished then return end
		wishP.Enabled = false
		wished = true objective()
		say("Seven candles. ...That isn't how old you are. Is it?", 4)
		task.wait(4.3)
		sfx(SFX.Blow, 0.8)
		for i = 1, #flames - 1 do
			local f = flames[i]
			setp(f, {Transparency = 1})
			for _, l in f:GetChildren() do if l:IsA("Light") then setp(l, {Enabled = false}) end end
			task.wait(0.12)
		end
		task.wait(1.5)
		if not alive then return end
		say("One candle won't go out. You let it burn.", 4)
		task.wait(4.5)
		-- everyone looks at the empty chair... then back at you
		local ec = chairs.EmptyChair.Seat.Position + Vector3.new(0, 3, 0)
		lookTarget = ec
		say("They both turn to look at the big empty chair.", 3.5)
		task.wait(4)
		lookTarget = nil
		say("Then, all at once, back at you.", 3.5)
		task.wait(4.2)
		if not alive then return end
		local hrp = hrpOf() if hrp then hrp.Anchored = false end
		if door then
			for p, t in doorParts do p.CanCollide = true TweenService:Create(p, TweenInfo.new(2.5), {Transparency = t}):Play() end
		end
		task.wait(2.6)
		if alive then ctx.unlockDoor(D, 9) end
	end))

	-------------------------------------------------------- small things (by proximity)
	local tt = party.TableTop.Position
	local spots = {
		{key = "table", pos = tt, r = 11, text = "Eight places set at the table. Only one friend came."},
		{key = "banner", pos = party.Banner.Position, r = 13, text = "The name on the banner is scribbled out. Somebody pressed very hard."},
		{key = "empty", pos = chairs.EmptyChair.Seat.Position, r = 7, text = "One chair is bigger than the others. Nobody's sitting in it. There's a present on it anyway."},
	}
	local woman = D.Guests:FindFirstChild("Woman")
	if woman then table.insert(spots, {key = "woman", pos = woman.Head.Position, r = 7, text = "She's standing by the cake, waiting for you to sit down."}) end
	local friend = D.Guests:FindFirstChild("Friend")
	if friend then table.insert(spots, {key = "friend", pos = friend.Head.Position, r = 6, text = "Your friend saved the seat right next to yours. You can't remember their name, but you're glad they came."}) end
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
	say("A birthday party in the living room. Lots of chairs. Only two of them are taken.", 4.5)
	task.wait(5)
	objective()
	say("Your presents are by the chair with the balloons. They're sparkling.", 4.5)
end

return M
