-- GameServer: moves players from the prologue into the dreams, and from dream to dream.
-- Set workspace attribute "DebugStartDream" to 1-7 to skip the prologue while testing.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local prologueRemote = RS:WaitForChild("PrologueRemote")
local dreamRemote = RS:WaitForChild("DreamRemote")
local Dreams = workspace:WaitForChild("Dreams")

local current = {} -- [player] = dream index (nil = still in the prologue)

local function sendTo(player, i)
	local dream = Dreams:FindFirstChild("Dream" .. i)
	local char = player.Character
	if not (dream and dream:FindFirstChild("Start") and char) then return false end
	current[player] = i
	char:PivotTo(dream.Start.CFrame + Vector3.new(0, 4, 0))
	dreamRemote:FireClient(player, "Enter", i)
	return true
end

prologueRemote.OnServerEvent:Connect(function(player, action)
	if action ~= "Sleep" or current[player] then return end
	if sendTo(player, 1) then
		prologueRemote:FireClient(player, "Arrived")
	else
		prologueRemote:FireClient(player, "ComingSoon")
	end
end)

dreamRemote.OnServerEvent:Connect(function(player, action, i)
	if action == "Door" and typeof(i) == "number" and current[player] == i then
		if not sendTo(player, i + 1) then dreamRemote:FireClient(player, "End") end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local debugStart = workspace:GetAttribute("DebugStartDream") or 0
		task.wait(0.5)
		if current[player] then
			sendTo(player, current[player]) -- respawned: put them back in their dream
		elseif debugStart > 0 then
			sendTo(player, debugStart)
		end
	end)
end)
Players.PlayerRemoving:Connect(function(p) current[p] = nil end)

------------------------------------------------------------ admin panel: skip stages
-- Admins: anyone testing in Studio, the place owner, and the user ids listed here.
local ADMINS = { [2673636205] = true }
local RunService = game:GetService("RunService")
local adminRemote = RS:FindFirstChild("AdminRemote") or Instance.new("RemoteEvent")
adminRemote.Name = "AdminRemote"
adminRemote.Parent = RS

local function isAdmin(player)
	return RunService:IsStudio() or ADMINS[player.UserId] or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

local function markAdmin(player)
	if isAdmin(player) then player:SetAttribute("IsAdmin", true) end
end
Players.PlayerAdded:Connect(markAdmin)
for _, p in Players:GetPlayers() do markAdmin(p) end

adminRemote.OnServerEvent:Connect(function(player, action, i)
	if not isAdmin(player) then return end
	if action == "Next" then
		i = (current[player] or 0) + 1
	elseif action ~= "Goto" or typeof(i) ~= "number" then
		return
	end
	i = math.floor(i)
	if not Dreams:FindFirstChild("Dream" .. i) then return end
	local wasInPrologue = current[player] == nil
	if sendTo(player, i) and wasInPrologue then
		prologueRemote:FireClient(player, "Arrived") -- ends the prologue on the client
	end
end)
