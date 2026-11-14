-- GameServer: moves players from the prologue into the dreams, and from dream to dream.
-- Set workspace attribute "DebugStartDream" to 1-10 to skip the prologue while testing.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local prologueRemote = RS:WaitForChild("PrologueRemote")
local dreamRemote = RS:WaitForChild("DreamRemote")
local Dreams = workspace:WaitForChild("Dreams")

------------------------------------------------------------ badges + the Flashlight pass
local BadgeService = game:GetService("BadgeService")
local MarketplaceService = game:GetService("MarketplaceService")
local BADGES = {
	Welcome = 1046390004999951,   -- Welcome to the Dream: fell asleep for the first time
	WokeUp = 126044585121622,     -- Woke Up: went through the last Dream Door
	NotAlone = 73914747743142,    -- Not Alone: caught for the first time
	Insomniac = 2377420633501970, -- Insomniac: 30 minutes in the dream
	Explorer = 577707558726124,   -- Dream Explorer: found the hidden room
}
local FLASHLIGHT_PASS = 2089886827
local awarded = {} -- [player] = {key = true}
local function award(player, key)
	local id = BADGES[key]
	if not id then return end
	awarded[player] = awarded[player] or {}
	if awarded[player][key] then return end
	awarded[player][key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and has then return end
		local ok2, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		if not ok2 then warn("Badge " .. key .. " failed: " .. tostring(err)) end
	end)
end
-- the client may only report these two (the rest are decided here on the server)
local badgeRemote = RS:FindFirstChild("BadgeRemote") or Instance.new("RemoteEvent")
badgeRemote.Name = "BadgeRemote"
badgeRemote.Parent = RS
badgeRemote.OnServerEvent:Connect(function(player, key)
	if key == "NotAlone" or key == "Explorer" then award(player, key) end
end)
-- Flashlight pass: owners get the player attribute FlashlightPass (the client makes the light brighter)
local function checkPass(player)
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, FLASHLIGHT_PASS)
	if ok and owns then player:SetAttribute("FlashlightPass", true) end
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if bought and passId == FLASHLIGHT_PASS then player:SetAttribute("FlashlightPass", true) end
end)
Players.PlayerAdded:Connect(checkPass)
for _, p in Players:GetPlayers() do task.spawn(checkPass, p) end
-- Insomniac: 30 minutes in the dream
local dreamSince = {}
task.spawn(function()
	while true do
		task.wait(20)
		for p, t in dreamSince do
			if p.Parent and os.clock() - t >= 30 * 60 then award(p, "Insomniac") end
		end
	end
end)

local current = {} -- [player] = dream index (nil = still in the prologue, "wake" = Chapter 2 wake-up in the apartment)

------------------------------------------------------------ chapters + saved progress
-- Chapter 1 = Dream1..Dream10. Chapter 2 starts by waking up in the apartment, then Dream11 and on.
local CH1_LAST = 10
local CH2_FIRST = 11
local RunServiceC = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local store
pcall(function() store = DataStoreService:GetDataStore("DreamProgress_v1") end)
local progress = {}
local function loadProgress(player)
	local data
	if store then
		local ok, d = pcall(store.GetAsync, store, "u_" .. player.UserId)
		if ok then data = d end
	end
	if type(data) ~= "table" then data = {} end
	if RunServiceC:IsStudio() and workspace:GetAttribute("DebugCh1Done") then data.ch1 = true end
	progress[player] = data
	player:SetAttribute("Ch1Done", data.ch1 == true)
	player:SetAttribute("DataLoaded", true)
end
local function saveProgress(player)
	local data = progress[player]
	if not (store and data) then return end
	pcall(store.UpdateAsync, store, "u_" .. player.UserId, function(old)
		old = type(old) == "table" and old or {}
		for k, v in data do old[k] = v end
		return old
	end)
end
local chapterRemote = RS:FindFirstChild("ChapterRemote") or Instance.new("RemoteEvent")
chapterRemote.Name = "ChapterRemote"
chapterRemote.Parent = RS
local function apartmentCF()
	local spot = workspace.Prologue:FindFirstChild("Ch2Things") and workspace.Prologue.Ch2Things:FindFirstChild("WakeSpot")
	return spot and (spot.CFrame + Vector3.new(0, 3, 0)) or CFrame.new(1, 3, 1)
end
local dreamRemoteRef = RS:WaitForChild("DreamRemote")
local function startWake(player)
	local char = player.Character
	if not char then return end
	current[player] = "wake"
	dreamRemoteRef:FireClient(player, "Leave")
	char:PivotTo(apartmentCF())
	chapterRemote:FireClient(player, "WakeUp")
end

local function sendTo(player, i)
	if type(i) ~= "number" then return false end
	local dream = Dreams:FindFirstChild("Dream" .. i)
	local char = player.Character
	if not (dream and dream:FindFirstChild("Start") and char) then return false end
	current[player] = i
	dreamSince[player] = dreamSince[player] or os.clock()
	char:PivotTo(dream.Start.CFrame + Vector3.new(0, 4, 0))
	dreamRemote:FireClient(player, "Enter", i)
	return true
end

prologueRemote.OnServerEvent:Connect(function(player, action)
	if action ~= "Sleep" or current[player] then return end
	if sendTo(player, 1) then
		award(player, "Welcome")
		prologueRemote:FireClient(player, "Arrived")
	else
		prologueRemote:FireClient(player, "ComingSoon")
	end
end)

dreamRemote.OnServerEvent:Connect(function(player, action, i)
	if action == "Door" and typeof(i) == "number" and current[player] == i then
		if i == CH1_LAST then
			-- the end of Chapter 1: save it, then you wake up (Chapter 2)
			progress[player] = progress[player] or {}
			progress[player].ch1 = true
			player:SetAttribute("Ch1Done", true)
			task.spawn(saveProgress, player)
			award(player, "WokeUp")
			current[player] = "between"
			chapterRemote:FireClient(player, "Ch1End")
			task.delay(8, function() if player.Parent then startWake(player) end end)
		elseif not sendTo(player, i + 1) then
			dreamRemote:FireClient(player, "End")
		end
	end
end)

chapterRemote.OnServerEvent:Connect(function(player, action, n)
	if action == "Pick" and n == 2 and current[player] == nil and progress[player] and progress[player].ch1 then
		startWake(player)
	elseif action == "Sleep2" and current[player] == "wake" then
		-- fall asleep again: the first dream of Chapter 2 (or "to be continued" until it exists)
		if not sendTo(player, CH2_FIRST) then
			current[player] = "ch2end"
			chapterRemote:FireClient(player, "Ch2Soon")
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadProgress, player)
	player.CharacterAdded:Connect(function(char)
		local debugStart = workspace:GetAttribute("DebugStartDream") or 0
		task.wait(0.5)
		if current[player] == "wake" then
			char:PivotTo(apartmentCF())
		elseif type(current[player]) == "number" then
			sendTo(player, current[player]) -- respawned: put them back in their dream
		elseif debugStart > 0 then
			sendTo(player, debugStart)
		end
	end)
end)
Players.PlayerRemoving:Connect(function(p) current[p] = nil dreamSince[p] = nil awarded[p] = nil progress[p] = nil end)
for _, p in Players:GetPlayers() do task.spawn(loadProgress, p) end

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
	if action == "WakeUp" then
		local wasInPrologue = current[player] == nil
		startWake(player)
		if wasInPrologue then prologueRemote:FireClient(player, "Arrived") end
		return
	end
	if action == "Next" then
		i = (type(current[player]) == "number" and current[player] or 0) + 1
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
