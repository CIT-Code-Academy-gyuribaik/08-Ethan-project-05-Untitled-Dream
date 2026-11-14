-- CensorGlitch: makes the black censor pixels over the father's head flicker like a broken censor.
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local clouds = {}
local function track(cloud)
	local head = cloud.Parent and cloud.Parent:FindFirstChild("Head")
	if not head then return end
	local pixels = {}
	for _, p in cloud:GetChildren() do
		if p:IsA("BasePart") then pixels[p] = head.CFrame:ToObjectSpace(p.CFrame) end
	end
	clouds[cloud] = {head = head, pixels = pixels}
end
for _, c in CS:GetTagged("CensorGlitch") do track(c) end
CS:GetInstanceAddedSignal("CensorGlitch"):Connect(track)

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.07 then return end -- choppy on purpose
	acc = 0
	for cloud, c in clouds do
		if not cloud.Parent then clouds[cloud] = nil continue end
		local headCF = c.head.CFrame
		local burst = math.random() < 0.08 -- now and then the whole censor jumps
		for p, off in c.pixels do
			local j = Vector3.zero
			if burst or math.random() < 0.12 then
				local s = burst and 0.35 or 0.12
				j = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, (math.random() - 0.5) * s)
			end
			p.CFrame = headCF * off + j
			p.Transparency = (math.random() < 0.04) and 1 or 0
		end
	end
end)
