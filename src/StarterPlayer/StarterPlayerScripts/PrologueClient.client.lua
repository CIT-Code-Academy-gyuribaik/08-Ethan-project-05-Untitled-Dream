-- PROLOGUE: "The Video"
-- A mysterious video gives the player steps. Following them traps him in the dream.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = RS:WaitForChild("PrologueRemote")
local camera = workspace.CurrentCamera
local P = workspace:WaitForChild("Prologue")
local F = P:WaitForChild("Furniture")
F:WaitForChild("Desk"):WaitForChild("Screen")
local Room = P:WaitForChild("Room")
local Out = P:WaitForChild("Outside")

-- movement lock (works with or without the classic PlayerModule)
local controls
task.spawn(function()
	local pm = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
	if pm then pcall(function() controls = require(pm):GetControls() end) end
end)
local function lockMovement(on)
	if controls then if on then controls:Disable() else controls:Enable() end end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum then hum.WalkSpeed = on and 0 or 16 hum.JumpHeight = on and 0 or 7.2 hum.JumpPower = on and 0 or 50 end
	if hrp then hrp.Anchored = on end
end

------------------------------------------------------------ animations
local ANIM = {
	type   = "rbxassetid://139410198160695",
	reach  = "rbxassetid://89302453424242",
	pickup = "rbxassetid://114891291383208",
	draw   = "rbxassetid://109549039924144",
	cloth  = "rbxassetid://78988150680156",
	flinch = "rbxassetid://118720419074826",
	lie    = "rbxassetid://130955998226979",
}
local tracks = {}
local function getTrack(name)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local t = tracks[name]
	if t and t.Parent ~= nil then return t end
	local a = Instance.new("Animation") a.AnimationId = ANIM[name]
	t = animator:LoadAnimation(a)
	t.Priority = Enum.AnimationPriority.Action4
	tracks[name] = t
	return t
end
player.CharacterAdded:Connect(function() tracks = {} end)

local function faceTowards(pos)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not pos then return end
	local flat = Vector3.new(pos.X, hrp.Position.Y, pos.Z)
	if (flat - hrp.Position).Magnitude > 0.1 then hrp.CFrame = CFrame.lookAt(hrp.Position, flat) end
end

------------------------------------------------------------ first-person action cam (steady: no head-following)
local headCam = false -- kept for cutscene code that resets it
local tween
local function setHeadCam(on, pitch)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	headCam = on
	if not on then
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	if pitch == "up" then
		-- lying in bed: glide smoothly from standing view down onto the pillow, looking at the ceiling
		local eye = Vector3.new(-6.6, 3.5, -7.4)
		tween(camera, 2.5, {CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, 1, 0.12), Vector3.new(0, 0, -1))})
	elseif head and hrp then
		-- hold the view still at eye level and just tilt down a little toward your hands
		local eye = head.Position + Vector3.new(0, 0.2, 0)
		local rot = (hrp.CFrame - hrp.Position) * (pitch or CFrame.Angles(math.rad(-25), 0, 0))
		tween(camera, 0.5, {CFrame = CFrame.new(eye) * rot})
	end
end

-- play an action animation while frozen in place, facing the thing being used
local function act(name, target, maxTime)
	local t = getTrack(name)
	if not t then return end
	lockMovement(true)
	faceTowards(target and target.Position)
	setHeadCam(true)
	t:Play(0.2)
	local w = 0 while t.Length == 0 and w < 2 do w += task.wait() end
	task.wait(math.min(t.Length > 0 and t.Length or 1.5, maxTime or 99))
	t:Stop(0.3)
	task.wait(0.3)
	setHeadCam(false)
	lockMovement(false)
end

------------------------------------------------------------ UI
local gui = Instance.new("ScreenGui")
gui.Name = "PrologueUI" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1 l.TextColor3 = Color3.new(1,1,1) l.TextWrapped = true
	for k,v in props do l[k] = v end
	l.Parent = props.Parent or gui
	return l
end

local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1,1) fade.BackgroundColor3 = Color3.new(0,0,0) fade.BorderSizePixel = 0 fade.ZIndex = 5 fade.Parent = gui
local title = label{Size=UDim2.new(1,0,0,80), Position=UDim2.new(0,0,0.38,0), Text="", Font=Enum.Font.Fantasy, TextSize=64, ZIndex=6, TextTransparency=1}
local sub = label{Size=UDim2.new(1,0,0,40), Position=UDim2.new(0,0,0.38,90), Text="", Font=Enum.Font.Code, TextSize=24, ZIndex=6, TextTransparency=1, TextColor3=Color3.fromRGB(190,190,210)}
local big = label{Size=UDim2.new(1,0,0,160), Position=UDim2.new(0,0,0.5,-80), Text="", Font=Enum.Font.Code, TextSize=120, ZIndex=6, TextTransparency=1}

local objective = label{Size=UDim2.new(0,420,0,30), Position=UDim2.new(0,24,0,70), Text="", Font=Enum.Font.GothamMedium, TextSize=18, TextXAlignment=Enum.TextXAlignment.Left, TextStrokeTransparency=0.5}
local video = label{Size=UDim2.new(0.8,0,0,60), Position=UDim2.new(0.1,0,0.8,0), Text="", Font=Enum.Font.Code, TextSize=26, TextColor3=Color3.fromRGB(215,215,235), TextStrokeTransparency=0.3, ZIndex=7}
local thought = label{Size=UDim2.new(0.8,0,0,40), Position=UDim2.new(0.1,0,0.8,-50), Text="", Font=Enum.Font.SourceSansItalic, TextSize=26, TextColor3=Color3.fromRGB(255,240,210), TextStrokeTransparency=0.4, ZIndex=7}

function tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Sine), props)
	tw:Play() return tw
end

local screenText = F.Desk.Screen.ScreenGui.BG.Text
local screenBG = F.Desk.Screen.ScreenGui.BG
local GLITCH = "#%&@!?/\\|<>~*^$01"

-- the video "speaks": glitchy typewriter, mirrored on the laptop screen
local function speak(text, hold)
	thought.Text = ""
	for i = 1, #text do
		local shown = text:sub(1, i)
		if math.random() < 0.35 and i < #text then
			local g = math.random(#GLITCH)
			shown = shown .. GLITCH:sub(g, g)
		end
		video.Text = "▶ " .. shown
		screenText.Text = shown
		task.wait(0.045)
	end
	video.Text = "▶ " .. text
	task.wait(hold or 2.2)
end

local thoughtToken = 0
local function think(text, hold)
	thoughtToken += 1
	local my = thoughtToken
	thought.Text = text thought.TextTransparency = 1
	tween(thought, 0.4, {TextTransparency = 0})
	task.delay(hold or 3.5, function()
		if thoughtToken == my then tween(thought, 0.6, {TextTransparency = 1}) end
	end)
end

local function setObjective(t) objective.Text = t ~= "" and ("●  " .. t) or "" end

local function waitPrompt(pr)
	pr.Enabled = true
	local fired = false
	local c = pr.Triggered:Connect(function() fired = true end)
	repeat task.wait() until fired
	c:Disconnect()
	pr.Enabled = false
end

local function flash()
	local w = Instance.new("Frame")
	w.Size = UDim2.fromScale(1,1) w.BackgroundColor3 = Color3.fromRGB(220,230,255) w.BackgroundTransparency = 0.4 w.ZIndex = 4 w.Parent = gui
	tween(w, 0.7, {BackgroundTransparency = 1})
	task.delay(0.8, function() w:Destroy() end)
end

local function setWatcher(visible) end

------------------------------------------------------------ cutscenes
local barTop = Instance.new("Frame") barTop.BackgroundColor3 = Color3.new(0,0,0) barTop.BorderSizePixel = 0
barTop.Size = UDim2.new(1,0,0,0) barTop.ZIndex = 3 barTop.Parent = gui
local barBot = barTop:Clone() barBot.AnchorPoint = Vector2.new(0,1) barBot.Position = UDim2.fromScale(0,1) barBot.Parent = gui
local inCutscene = false

local function cutsceneBegin()
	inCutscene = true
	lockMovement(true)
	headCam = false
	camera.CameraType = Enum.CameraType.Scriptable
	objective.Visible = false
	tween(barTop, 0.5, {Size = UDim2.fromScale(1, 0.11)})
	tween(barBot, 0.5, {Size = UDim2.fromScale(1, 0.11)})
end
local function cutsceneEnd()
	tween(barTop, 0.5, {Size = UDim2.new(1,0,0,0)})
	tween(barBot, 0.5, {Size = UDim2.new(1,0,0,0)})
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
	objective.Visible = true
	lockMovement(false)
	inCutscene = false
end
-- camera moves from (fromPos looking at fromLook) to (toPos looking at toLook) over t seconds
local function shot(fromPos, fromLook, toPos, toLook, t, wait)
	camera.CFrame = CFrame.lookAt(fromPos, fromLook)
	tween(camera, t, {CFrame = CFrame.lookAt(toPos, toLook or fromLook)}, Enum.EasingStyle.Quad)
	if wait ~= false then task.wait(t) end
end

local function setBedside(visible) end

------------------------------------------------------------ side interactions
local watcherOut = false
Room.WindowGlass.WindowPrompt.Triggered:Connect(function()
	if watcherOut then
		think("The rain is just... hanging there.")
	else
		think("Rain. Gray sky. Nobody's out in this.")
	end
end)

------------------------------------------------------------ story
local function run()
	if (workspace:GetAttribute("DebugStartDream") or 0) > 0 then
		gui.Enabled = false
		return
	end
	-- players who finished Chapter 1 pick a chapter first (the Chapters script shows the menu)
	local t0 = os.clock()
	while player:GetAttribute("DataLoaded") == nil and os.clock() - t0 < 8 do task.wait(0.1) end
	if player:GetAttribute("Ch1Done") then
		while player:GetAttribute("ChapterPick") == nil do task.wait(0.1) end
		if player:GetAttribute("ChapterPick") ~= 1 then gui.Enabled = false return end
	end
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart")
	task.wait(1)

	title.Text = "PROLOGUE" sub.Text = "THE VIDEO"
	tween(title, 1.5, {TextTransparency = 0}) task.wait(0.8)
	tween(sub, 1.5, {TextTransparency = 0}) task.wait(3)
	tween(title, 1, {TextTransparency = 1}) tween(sub, 1, {TextTransparency = 1}) task.wait(1)

	-- CUTSCENE: rainy street -> push in through the window -> laptop autoplay
	cutsceneBegin()
	local V = Vector3.new
	tween(fade, 2.5, {BackgroundTransparency = 1})
	shot(V(-48, -9, 34), V(-12, 6, 0), V(-40, -5, 20), V(-12, 6, 0), 5)
	shot(V(-22, 7.5, 1.5), V(0, 4.5, -2), V(-13.6, 6.6, 0.3), V(2, 4.5, -2), 3.5)
	fade.BackgroundTransparency = 0 tween(fade, 0.6, {BackgroundTransparency = 1})
	shot(V(8.3, 4.7, -3.5), F.Desk.Screen.Position, V(9.7, 4.35, -3.5), F.Desk.Screen.Position, 3, false)
	for i = 3, 1, -1 do screenText.Text = "▶  ◬⟟⌖ ⍜⎎ ⏃⌇⏁⟒⍀\n\nautoplay in " .. i .. "..." task.wait(1) end
	screenText.Text = "▶  ◬⟟⌖ ⍜⎎ ⏃⌇⏁⟒⍀\n\n[ paused ]"
	cutsceneEnd()
	task.wait(0.5)

	think("2:14 PM. It's been raining all day. Didn't sleep at all last night.")
	task.wait(3.5)
	setObjective("Check the laptop")
	waitPrompt(F.Desk.Screen.WatchPrompt)
	setObjective("")
	task.spawn(act, "type", F.Desk.Screen, 2)

	screenBG.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
	speak("hello.")
	speak("you are tired. i know. i have been watching you not sleep.")
	speak("i can help you rest. do exactly what i say. do not skip a step.")
	task.wait(1.5)

	-- STEP 1: lights
	speak("step one. turn off every light.", 1)
	local lightsOff = 0
	setObjective("Turn off every light (0/2)")
	local function lamp(prompt, light, part)
		task.spawn(function()
			waitPrompt(prompt)
			act("reach", part, 1.2)
			light.Enabled = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(90, 85, 75)
			lightsOff += 1
			setObjective(("Turn off every light (%d/2)"):format(lightsOff))
		end)
	end
	lamp(F.Nightstand.LampShade.LampPrompt, F.Nightstand.LampShade.PointLight, F.Nightstand.LampShade)
	lamp(F.Desk.DeskLampHead.DeskLampPrompt, F.Desk.DeskLampHead.SpotLight, F.Desk.DeskLampHead)
	repeat task.wait() until lightsOff >= 2
	setObjective("")
	task.wait(0.6)
	-- CUTSCENE: the clock jumps to 3:33
	cutsceneBegin()
	local clockPos = F.Nightstand.Clock.Position
	shot(clockPos + Vector3.new(0.6, 0.8, 3.2), clockPos, clockPos + Vector3.new(0.15, 0.3, 1.4), clockPos, 3, false)
	local clockLabel = F.Nightstand.Clock.SurfaceGui.Time
	task.wait(1.2)
	for _, t in {"2:1_", "_:__", "8:88", "3:3_", "3:33"} do clockLabel.Text = t task.wait(0.12) end
	task.wait(1.6)
	cutsceneEnd()
	think("The clock says 3:33. It was 2:14 a minute ago.")
	task.wait(3)

	-- STEP 2: circle
	speak("good. step two. take the chalk. draw the circle.", 1)
	setObjective("Take the chalk from the desk")
	waitPrompt(F.Desk.Chalk.ChalkPrompt)
	act("pickup", F.Desk.Chalk, 1.4)
	F.Desk.Chalk.Transparency = 1
	setObjective("Draw the circle on the floor")
	waitPrompt(F.ChalkCircle.CirclePrompt)
	act("draw", F.ChalkCircle)
	F.ChalkCircle.Drawing.Enabled = true
	setObjective("")
	task.wait(0.6)
	-- CUTSCENE: the rain stops in mid-air
	cutsceneBegin()
	local rain = Out.RainEmitter.ParticleEmitter
	shot(Vector3.new(-8.5, 6.6, 2), Vector3.new(-26, 1, -3), Vector3.new(-11.2, 6.6, 0.6), Vector3.new(-26, 0, -2), 2.5, false)
	task.wait(1.2)
	for i = 1, 10 do rain.TimeScale = 1 - i / 10 task.wait(0.08) end
	rain.TimeScale = 0
	task.wait(1)
	shot(Vector3.new(-21, -10, 14), Vector3.new(-26, -2, 3), Vector3.new(-22.5, -8.5, 10), Vector3.new(-26, -1, 2), 3)
	cutsceneEnd()
	think("The rain sounds stopped. I can still see it. It's just... hanging there.")
	task.wait(3.5)

	-- STEP 3: door
	speak("step three. lock the door. no one comes in. no one leaves.", 1)
	setObjective("Lock the door")
	waitPrompt(Room.Door.DoorPrompt)
	act("reach", Room.DoorKnob, 1.2)
	-- CUTSCENE: the hallway light under the door dies
	cutsceneBegin()
	shot(Vector3.new(1.5, 1.6, 4.5), Room.DoorGap.Position, Vector3.new(0.6, 1, 6.5), Room.DoorGap.Position, 2.6, false)
	task.wait(1)
	for _ = 1, 3 do Room.DoorGap.Transparency = 1 task.wait(0.07) Room.DoorGap.Transparency = 0.4 task.wait(0.1) end
	Room.DoorGap.Transparency = 1
	task.wait(1.4)
	cutsceneEnd()
	think("*click*  ...the hallway light went out.")
	setObjective("")
	task.wait(3)

	-- STEP 4: mirror
	speak("step four. cover the mirror. it must not see you leave.", 1)
	setObjective("Cover the mirror")
	waitPrompt(F.Wardrobe.Mirror.MirrorPrompt)
	act("cloth", F.Wardrobe.Mirror, 1.4)
	F.Wardrobe.MirrorCloth.Transparency = 0
	setObjective("")
	task.wait(1)
	flash()
	think("Thunder. The whole room flickered.")
	task.wait(4)

	-- STEP 5: bed
	speak("last step. lie down. close your eyes. count back from ten.", 1.5)
	speak("and whatever you hear... do not open your eyes.", 1)
	setObjective("Lie down")
	waitPrompt(F.Bed.Mattress.BedPrompt)
	setObjective("")
	video.Text = ""

	-- lie down: lock controls, hide body, camera at ceiling
	lockMovement(true)
	local hrp = char.HumanoidRootPart
	local hum = char:FindFirstChildOfClass("Humanoid")
	local standY = 2.4 + (hum and hum.HipHeight or 2) + hrp.Size.Y / 2
	hrp.CFrame = CFrame.lookAt(Vector3.new(-6.5, standY, -5.6), Vector3.new(-6.5, standY, 0))
	local lie = getTrack("lie")
	if lie then
		lie:Play(0.3)
		local w = 0 while lie.Length == 0 and w < 2 do w += task.wait() end
		task.delay(math.max(lie.Length - 0.08, 0.5), function() lie:AdjustSpeed(0) end)
	end
	setHeadCam(true, "up")
	task.wait(4)

	-- closing eyes
	fade.BackgroundTransparency = 1
	tween(fade, 2, {BackgroundTransparency = 0}) task.wait(2.2)

	local events = {
		[8] = function() think("...") end,
		[6] = function() think("Was that... a knock?") end,
		[4] = function() think("I can't hear the rain anymore. I can't hear anything.") end,
		[2] = function() thought.Text = "" video.Text = "▶ you're almost here." end,
	}
	for n = 10, 1, -1 do
		big.Text = tostring(n) big.TextTransparency = 1
		tween(big, 0.4, {TextTransparency = 0.1})
		if events[n] then events[n]() end
		task.wait(1.4)
		tween(big, 0.4, {TextTransparency = 1})
		task.wait(0.4 + (10 - n) * 0.05)
	end
	thought.Text = "" video.Text = ""
	big.Text = "" 

	-- the white
	fade.BackgroundColor3 = Color3.new(1, 1, 1)
	sub.TextColor3 = Color3.fromRGB(40, 40, 50)
	title.TextColor3 = Color3.fromRGB(20, 20, 30)
	sub.Text = "thank you for coming."
	tween(sub, 1.5, {TextTransparency = 0})
	task.wait(3.5)
	tween(sub, 1.5, {TextTransparency = 1}) task.wait(1.5)
	remote:FireServer("Sleep")
end

local runThread
remote.OnClientEvent:Connect(function(result)
	-- an admin skip can arrive mid-story: stop the prologue where it is
	if runThread and coroutine.status(runThread) ~= "dead" and coroutine.running() ~= runThread then
		pcall(task.cancel, runThread)
	end
	-- restore normal camera / body / controls for the next area
	local char = player.Character
	if char then for _, d in char:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end end end
	if tracks.lie then tracks.lie:Stop(0.2) end
	setHeadCam(false)
	if result == "Arrived" then
		camera.CameraType = Enum.CameraType.Custom
		lockMovement(false)
		setWatcher(false)
		tween(fade, 3, {BackgroundTransparency = 1})
		setObjective("") video.Text = "" thought.Text = ""
		task.delay(3.2, function() gui.Enabled = false end)
	else
		title.Text = "END OF PROLOGUE"
		sub.Text = "Chapter 1 — coming soon"
		tween(title, 1.5, {TextTransparency = 0})
		tween(sub, 1.5, {TextTransparency = 0})
	end
end)

runThread = task.spawn(run)
