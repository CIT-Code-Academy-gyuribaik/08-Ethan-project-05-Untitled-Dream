-- Drives the cars up and down the street. Freezes when the rain freezes (Prologue attribute "Frozen").
local RunService = game:GetService("RunService")
local P = workspace:WaitForChild("Prologue")
local traffic = P:WaitForChild("City"):WaitForChild("Traffic")
local rain = P:WaitForChild("Outside"):WaitForChild("RainEmitter"):WaitForChild("ParticleEmitter")
RunService.Heartbeat:Connect(function(dt)
	local speedScale = rain.TimeScale -- 1 = normal, 0 = frozen
	if speedScale <= 0 then return end
	for _, car in traffic:GetChildren() do
		local dir, speed = car:GetAttribute("Dir"), car:GetAttribute("Speed")
		local cf = car:GetPivot()
		local z = cf.Position.Z + dir * speed * dt * speedScale
		if z > 210 then z = -210 elseif z < -210 then z = 210 end
		car:PivotTo(cf - cf.Position + Vector3.new(cf.Position.X, cf.Position.Y, z))
	end
end)
