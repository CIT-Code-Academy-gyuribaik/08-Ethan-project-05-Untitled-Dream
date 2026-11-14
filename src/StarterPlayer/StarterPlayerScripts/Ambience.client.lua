-- Ambience: background music / ambient loops for each area. Crossfades by where the player is.
-- The nightmare (night part of Dream5) and the school play their own sounds on top.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local function loop(id, vol)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id s.Looped = true s.Volume = 0
	s:SetAttribute("Target", vol)
	s.Parent = SoundService
	return s
end

-- prologue: rain outside + city traffic; muffled inside the apartment
local rain = loop(9112853422, 0.55)
local traffic = loop(9112784190, 0.18)
local muffle = Instance.new("EqualizerSoundEffect")
muffle.HighGain = -25 muffle.MidGain = -8 muffle.LowGain = 0 muffle.Enabled = false muffle.Parent = rain
local muffle2 = muffle:Clone() muffle2.Parent = traffic

local AREAS = {
	Prologue = {rain, traffic},
	Dream1 = {loop(96240272516811, 0.45)},                                     -- soft dreamy ambient
	Dream2 = {loop(134630424395946, 0.4), loop(9113996221, 0.3)},             -- calm music + creek at night
	Dream3 = {loop(9047785119, 0.4)},                                          -- music box lullaby
	Dream4 = {loop(9125742262, 0.18), loop(9112795463, 0.15)},                -- airy wind + a low hum
	Dream5 = {loop(133505549946221, 0.3)},                                     -- gentle lullaby (daytime only)
	Dream6 = {loop(139022063348798, 0.3), loop(9125742262, 0.06)},            -- slow strings, faint air
	Dream7 = {loop(9112795463, 0.25)},                                         -- empty building hum
}

local starts = {}
for _, d in workspace:WaitForChild("Dreams"):GetChildren() do
	local s = d:FindFirstChild("Start", true)
	if s then starts[d.Name] = s.Position end
end

local function areaAt(pos)
	if pos.Magnitude < 1200 then return "Prologue" end
	local best, bd = nil, 900
	for name, p in starts do
		local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bd then best, bd = name, d end
	end
	return best
end

local playing = {}
local function fadeTo(s, vol)
	if vol > 0 and not s.IsPlaying then s:Play() end
	TweenService:Create(s, TweenInfo.new(2.5), {Volume = vol}):Play()
	if vol == 0 then
		task.delay(2.6, function() if s.Volume < 0.01 then s:Pause() end end)
	end
end

local current
while true do
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local area = hrp and areaAt(hrp.Position)
	-- the nightmare takes over at night
	if area == "Dream5" then
		local ph = player:GetAttribute("NM_Phase")
		if ph == "B" or ph == "C" or ph == "done" then area = "Dream5Night" end
	end
	if area ~= current then
		current = area
		local want = {}
		for _, s in (area and AREAS[area]) or {} do want[s] = true end
		for _, list in AREAS do
			for _, s in list do
				if want[s] then fadeTo(s, s:GetAttribute("Target")) elseif s.IsPlaying then fadeTo(s, 0) end
			end
		end
	end
	-- inside the apartment the rain is quieter and muffled
	if current == "Prologue" and hrp then
		local p = hrp.Position
		local inside = math.abs(p.X) < 13 and math.abs(p.Z) < 11 and p.Y < 14
		muffle.Enabled = inside muffle2.Enabled = inside
	end
	task.wait(0.5)
end
