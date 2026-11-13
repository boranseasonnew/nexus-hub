--!strict
-- Uses replicated role data when available; visible tools are a fallback signal.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local UI = require(script.Parent.Parent.ui.Components)
local Controls = require(script.Parent.Parent.ui.Controls)
local CollisionTracker = require(script.Parent.logic.CollisionTracker)
local YARHMFling = require(script.Parent.logic.YARHMFling)
local RoleData = require(script.Parent.logic.RoleData)
local AimPrediction = require(script.Parent.logic.AimPrediction)

local MM2 = {}

local function isGunTool(tool: Instance?): boolean
	if not tool or not tool:IsA("Tool") then return false end
	local name = string.lower(tool.Name)
	return string.find(name, "gun", 1, true) ~= nil or string.find(name, "pistol", 1, true) ~= nil
		or string.find(name, "revolver", 1, true) ~= nil or tool:FindFirstChild("Shoot", true) ~= nil
end

local function findGun(container: Instance?): Tool?
	if not container then return nil end
	local exact = container:FindFirstChild("Gun")
	if exact and exact:IsA("Tool") then return exact end
	for _, child in ipairs(container:GetChildren()) do
		if isGunTool(child) then return child :: Tool end
	end
	return nil
end

local function visibleWeapon(player: Player): string
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local function inspect(container: Instance?): string?
		if not container then return nil end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") then
				local name = string.lower(item.Name)
				if string.find(name, "knife", 1, true) then return "Knife visible" end
				if isGunTool(item) then return "Gun visible" end
			end
		end
		return nil
	end
	return inspect(character) or inspect(backpack) or "Unknown"
end

function MM2.mount(context)
	local scope = context.scope
	local parent = context.parent
	local localPlayer = Players.LocalPlayer
	local enabled = true
	local shortcut = Enum.KeyCode[context.settings:get("mm2OverlayHotkey")]
	local flyShortcut = Enum.KeyCode[context.settings:get("mm2FlyNoclipHotkey")]
	local records = {}
	local roleData = {}
	local roleRemote = nil
	local roleConnection = nil
	local fadeRemote = nil
	local fadeConnection = nil
	local roleSources = { PlayerDataChanged = 0, Fade = 0, GetPlayerData = 0 }
	local roleSourceData = { PlayerDataChanged = {}, Fade = {}, GetPlayerData = {} }
	local roleGeneration, roleRefreshPending = 0, false
	local roleNotifications = true
	local announcedRoles = {}
	local elapsed = 0
	local gunOverlay = true
	local collectCoins = false
	local shotRequestPending = false
	local autoShoot = true
	local autoGun = true
	local gunPickup = nil
	local gunRetryAfter = 0
	local flying = false
	local noclip = false
	local collisions = CollisionTracker.new()
	local flingState = nil
	local flySpeed = 50
	local flyVelocity: BodyVelocity? = nil
	local flyGyro: BodyGyro? = nil
	local flyingHumanoid: Humanoid? = nil
	local oldPlatformStand = false
	local lastShot = 0
	local shotPending = false
	local murdererActionBusy = false
	local autoKnifeThrow = false
	local killAura = true
	local lastAuraAttempt = 0
	local lastKnifeThrow = 0
	local shootOffset = 2.8
	local predictionMode = "HHB"
	local gunHighlight: Highlight? = nil
	local gunTarget: Instance? = nil
	local diagnostics = {}
	local coinSpeed = 20
	local coinHumanoid, coinOriginalSpeed, coinAppliedSpeed = nil, nil, nil
	local coinTarget, coinStuckPosition, coinStuckSince = nil, nil, 0
	local coinBlacklist = {}
	local lastCoinUpdate = 0
	local spectatedPlayer = nil
	local previousCameraSubject = nil

	local header = UI.label(parent, "Murder Mystery 2", 26, false)
	local subtitle = UI.label(parent, "Roles use game data when available; visible weapons are a fallback.", 42, true)
	local button = UI.button(parent, "Player overlay · On")
	local keyBox = UI.input(parent, "Overlay shortcut")
	keyBox.Text = shortcut.Name
	local status = UI.label(parent, "Status: Scanning visible players", 26, true)
	local roleStatus = UI.label(parent, "Role data: Waiting for game", 26, true)
	local roleNotifyButton = UI.button(parent, "Role notifications · On")
	scope:connect(roleNotifyButton.Activated, function()
		roleNotifications = not roleNotifications
		roleNotifyButton.Text = roleNotifications and "Role notifications · On" or "Role notifications · Off"
	end)
	local function announceRoles(snapshot)
		if not roleNotifications then return end
		for name, role in pairs(snapshot) do
			local isLocal = name == localPlayer.Name
			if (isLocal or role == "Murderer" or role == "Sheriff" or role == "Hero") and announcedRoles[name] ~= role then
				announcedRoles[name] = role
				local text = isLocal and ("Your role: " .. role) or (role .. ": " .. name)
				task.spawn(function() pcall(function() StarterGui:SetCore("SendNotification", { Title = "MM2 Roles", Text = text, Duration = 5 }) end) end)
			end
		end
	end
	local refreshRolesButton = UI.button(parent, "Refresh role data")
	local function refreshRoles()
		if roleRefreshPending then return end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local extras = remotes and remotes:FindFirstChild("Extras")
		local getter = extras and extras:FindFirstChild("GetPlayerData")
		if not getter or not getter:IsA("RemoteFunction") then roleStatus.Text = "Role data: Refresh unavailable"; return end
		roleRefreshPending = true
		local generation = roleGeneration
		task.spawn(function()
			local ok, data = pcall(function() return getter:InvokeServer() end)
			roleRefreshPending = false
			if scope.closed or generation ~= roleGeneration then return end
			if not ok or type(data) ~= "table" then roleStatus.Text = "Role data: Refresh failed"; return end
			local snapshot = RoleData.merge(roleData, data)
			announceRoles(snapshot)
			roleSources.GetPlayerData += 1
			roleSourceData.GetPlayerData = snapshot
			roleStatus.Text = next(snapshot) and "Role data: Refresh received" or "Role data: No roles in refresh"
		end)
	end
	scope:connect(refreshRolesButton.Activated, refreshRoles)
	local function bindRoleRemote()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local gameplay = remotes and remotes:FindFirstChild("Gameplay")
		local remote = gameplay and gameplay:FindFirstChild("PlayerDataChanged")
		if remote == roleRemote then return end
		if roleConnection then roleConnection:Disconnect(); roleConnection = nil end
		roleRemote = remote
		table.clear(roleData)
		if remote and remote:IsA("RemoteEvent") then
			roleStatus.Text = "Role data: Waiting for update"
			roleConnection = remote.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" then return end
				local snapshot = RoleData.merge(roleData, data)
				announceRoles(snapshot)
				roleGeneration += 1
				roleSources.PlayerDataChanged += 1
				roleSourceData.PlayerDataChanged = snapshot
				roleStatus.Text = next(snapshot) and "Role data: PlayerDataChanged received" or "Role data: No roles in update"
			end)
		else
			roleStatus.Text = "Role data: Unavailable; showing weapons"
		end
	end
	local function bindFadeRemote()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local gameplay = remotes and remotes:FindFirstChild("Gameplay")
		local remote = gameplay and gameplay:FindFirstChild("Fade")
		if remote == fadeRemote then return end
		if fadeConnection then fadeConnection:Disconnect(); fadeConnection = nil end
		fadeRemote = remote
		if remote and remote:IsA("RemoteEvent") then
			fadeConnection = remote.OnClientEvent:Connect(function(data)
				if type(data) ~= "table" then return end
				local snapshot = RoleData.merge(roleData, data)
				announceRoles(snapshot)
				if next(snapshot) then roleGeneration += 1; roleSources.Fade += 1; roleSourceData.Fade = snapshot; roleStatus.Text = "Role data: Fade received" end
			end)
		end
	end
	bindRoleRemote()
	bindFadeRemote()
	task.defer(refreshRoles)
	scope:connect(ReplicatedStorage.DescendantAdded, function(object)
		if object.Name == "Remotes" or object.Name == "Gameplay" or object.Name == "PlayerDataChanged" or object.Name == "Fade" then bindRoleRemote(); bindFadeRemote() end
	end)
	scope:connect(ReplicatedStorage.DescendantRemoving, function(object)
		if object == roleRemote then
			if roleConnection then roleConnection:Disconnect(); roleConnection = nil end
			roleRemote = nil
			table.clear(roleData)
			table.clear(announcedRoles)
			roleStatus.Text = "Role data: Unavailable; showing weapons"
		end
		if object == fadeRemote then
			if fadeConnection then fadeConnection:Disconnect(); fadeConnection = nil end
			fadeRemote = nil
		end
	end)
	scope:connect(workspace.ChildRemoved, function(object)
		if object:FindFirstChild("CoinContainer") and object:FindFirstChild("Spawns") then
			roleGeneration += 1
			table.clear(roleData)
			table.clear(announcedRoles)
			roleSourceData.PlayerDataChanged, roleSourceData.Fade, roleSourceData.GetPlayerData = {}, {}, {}
			roleStatus.Text = "Role data: Waiting for next round"
		end
	end)
	scope:add(function() if roleConnection then roleConnection:Disconnect() end; if fadeConnection then fadeConnection:Disconnect() end end)
	local gunButton = UI.button(parent, "Dropped gun overlay · On")
	local collectButton = UI.button(parent, "Collect coins · Off")
	local coinStatus = UI.label(parent, "Coin farm: Off", 28, true)
	local shootOnceButton = UI.button(parent, "Equip & shoot · Mouse 4 / H")
	local autoShootButton = UI.button(parent, "Auto shoot on gun · On")
	local modernKillAllButton = UI.button(parent, "Murderer: event kill all (experimental)")
	local knifeThrowButton = UI.button(parent, "Murderer: throw at nearest")
	local autoKnifeThrowButton = UI.button(parent, "Murderer: auto throw · Off")
	local killAuraButton = UI.button(parent, "Murderer: kill aura · On")
	local offsetInput = UI.input(parent, "Shot prediction offset (0–10)")
	offsetInput.Text = tostring(shootOffset)
	local predictionButton = UI.button(parent, "Shot prediction · HHB")
	local moveGunButton = UI.button(parent, "Move to dropped gun")
	local autoGunButton = UI.button(parent, "Auto teleport & pick up gun · On")
	local flyButton = UI.button(parent, "Fly (all roles) · Off")
	local flyKeyLabel = UI.label(parent, "Fly + Noclip shortcut", 24, true)
	local flyKeyBox = UI.input(parent, "Fly + Noclip shortcut")
	flyKeyBox.Text = flyShortcut.Name
	local noclipButton = UI.button(parent, "Noclip · Off")
	local antiFlingButton = UI.button(parent, "Anti-fling · On")
	local antiVoidButton = UI.button(parent, "Anti-void · On")
	local aimButton = UI.button(parent, "Aim assist · Off")
	local aimHelp = UI.label(parent, "Hold right mouse with a gun to aim at the murderer.", 36, true)
	local flingMurdererButton = UI.button(parent, "Fling murderer")
	local flingSheriffButton = UI.button(parent, "Fling sheriff / hero")
	local flingPlayerName = UI.input(parent, "Player username or display name")
	local flingPlayerButton = UI.button(parent, "Fling selected player")
	local flyHelp = UI.label(parent, "Fly: WASD, Space up, Left Ctrl down", 30, true)
	local actionStatus = UI.label(parent, "Actions: Idle", 40, true)
	local rejoinButton = UI.button(parent, "Rejoin this server")
	local serverHopButton = UI.button(parent, "Switch server")
	local serverStatus = UI.label(parent, "Server: Ready", 32, true)
	local diagnosticButton = UI.button(parent, "Save weapon diagnostics")
	local diagnosticStatus = UI.label(parent, "Diagnostics: Not saved", 28, true)
	local fullbrightButton = UI.button(parent, "Fullbright · Off")
	local fovButton = UI.button(parent, "FOV · Off")
	local antiAfkButton = UI.button(parent, "Anti-AFK · Off")
	local afkStatus = UI.label(parent, "Anti-AFK: Off", 26, true)
	local spectateInput = UI.input(parent, "Player username or display name")
	local spectateButton = UI.button(parent, "Spectate player")
	local stopSpectateButton = UI.button(parent, "Stop spectating")
	local emoteDanceButton = UI.button(parent, "Emote: Take the L")
	local emoteZombieButton = UI.button(parent, "Emote: Zombie walk")
	local emoteStopButton = UI.button(parent, "Stop emote")

	local nav = UI.make("Frame", parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 105) })
	local groupNames = { "Combat", "Murderer", "ESP", "Movement", "Visuals", "Farm", "System" }
	local groups, navButtons = {}, {}
	for index, name in ipairs(groupNames) do
		local group = UI.make("Frame", parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = index == 1, LayoutOrder = 10 + index })
		UI.list(group, 8)
		groups[name] = group
		local navButton = UI.button(nav, name)
		navButton.Size = UDim2.new(1 / 3, -4, 0, 30)
		navButton.Position = UDim2.new(((index - 1) % 3) / 3, 0, 0, math.floor((index - 1) / 3) * 35)
		navButtons[name] = navButton
		scope:connect(navButton.Activated, function()
			for _, groupName in ipairs(groupNames) do
				groups[groupName].Visible = groupName == name
				navButtons[groupName].BackgroundColor3 = groupName == name and UI.colors.border or UI.colors.panel
			end
		end)
	end
	navButtons.Combat.BackgroundColor3 = UI.colors.border
	header.LayoutOrder, subtitle.LayoutOrder, nav.LayoutOrder, actionStatus.LayoutOrder = 1, 2, 3, 4
	local function moveToGroup(name, items)
		for index, item in ipairs(items) do item.LayoutOrder = index; item.Parent = groups[name] end
	end
	moveToGroup("Combat", { shootOnceButton, autoShootButton, aimButton, aimHelp, predictionButton, offsetInput, moveGunButton, autoGunButton, flingMurdererButton, flingSheriffButton, flingPlayerName, flingPlayerButton })
	moveToGroup("Murderer", { modernKillAllButton, knifeThrowButton, autoKnifeThrowButton, killAuraButton })
	moveToGroup("ESP", { button, keyBox, status, roleStatus, refreshRolesButton, roleNotifyButton, gunButton, spectateInput, spectateButton, stopSpectateButton })
	moveToGroup("Movement", { flyButton, flyKeyLabel, flyKeyBox, noclipButton, flyHelp, antiFlingButton, antiVoidButton })
	moveToGroup("Visuals", { fullbrightButton, fovButton, antiAfkButton, afkStatus, emoteDanceButton, emoteZombieButton, emoteStopButton })
	moveToGroup("Farm", { collectButton, coinStatus })
	moveToGroup("System", { rejoinButton, serverHopButton, serverStatus, diagnosticButton, diagnosticStatus })
	local coinSpeedSlider = Controls.valueSlider(groups.Farm, scope, "Farm speed", coinSpeed, 8, 32, function(value) coinSpeed = value end)
	coinSpeedSlider.LayoutOrder = 2
	coinStatus.LayoutOrder = 3
	local flySpeedSlider = Controls.valueSlider(groups.Movement, scope, "Fly speed", flySpeed, 10, 150, function(value) flySpeed = value end)
	flySpeedSlider.LayoutOrder = 5
	flyHelp.LayoutOrder = 6
	antiFlingButton.LayoutOrder, antiVoidButton.LayoutOrder = 7, 8
	local antiFling, antiVoid = true, true
	local protectedParts, lastSafePosition, safeCharacter = {}, nil, nil
	local lastVoidRecovery, protectionElapsed = 0, 0
	local function restoreProtectedParts()
		for part, record in pairs(protectedParts) do
			if part.Parent then part.CanCollide = record.original end
			protectedParts[part] = nil
		end
	end
	scope:connect(antiFlingButton.Activated, function()
		antiFling = not antiFling
		antiFlingButton.Text = antiFling and "Anti-fling · On" or "Anti-fling · Off"
		if not antiFling then restoreProtectedParts() end
	end)
	scope:connect(antiVoidButton.Activated, function()
		antiVoid = not antiVoid
		antiVoidButton.Text = antiVoid and "Anti-void · On" or "Anti-void · Off"
		if not antiVoid then lastSafePosition, safeCharacter = nil, nil end
	end)
	scope:connect(RunService.Heartbeat, function(dt)
		protectionElapsed += dt
		if protectionElapsed < 0.15 then return end
		protectionElapsed = 0
		local now = os.clock()
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if antiFling and not flingState and root and root:IsA("BasePart") then
			for _, player in ipairs(Players:GetPlayers()) do
				local other = player.Character
				local otherRoot = other and other:FindFirstChild("HumanoidRootPart")
				if player ~= localPlayer and otherRoot and otherRoot:IsA("BasePart") and (otherRoot.Position - root.Position).Magnitude < 45
					and (otherRoot.AssemblyLinearVelocity.Magnitude > 100 or otherRoot.AssemblyAngularVelocity.Magnitude > 50) then
					for _, part in ipairs(other:GetDescendants()) do
						if part:IsA("BasePart") then
							if not protectedParts[part] then protectedParts[part] = { original = part.CanCollide, untilTime = now + 2 } end
							protectedParts[part].untilTime = now + 2
							if part.CanCollide then part.CanCollide = false end
						end
					end
				end
			end
		elseif flingState then
			restoreProtectedParts()
		end
		for part, record in pairs(protectedParts) do
			if not part.Parent or now >= record.untilTime then
				if part.Parent then part.CanCollide = record.original end
				protectedParts[part] = nil
			end
		end
		if antiVoid and not flingState and not gunPickup and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			if safeCharacter ~= character then safeCharacter, lastSafePosition = character, nil end
			local threshold = workspace.FallenPartsDestroyHeight
			if root.Position.Y > threshold + 50 and not flying then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { character }
				local ground = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params)
				if ground and ground.Instance.CanCollide and math.abs(root.AssemblyLinearVelocity.Y) < 12 then lastSafePosition = character:GetPivot() end
			elseif root.Position.Y <= threshold + 50 and lastSafePosition and now - lastVoidRecovery > 1 then
				root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
				character:PivotTo(lastSafePosition)
				lastVoidRecovery = now
				actionStatus.Text = "Actions: Anti-void return attempted"
			end
		end
	end)
	scope:add(restoreProtectedParts)
	for _, control in ipairs(groups.Combat:GetChildren()) do
		if control:IsA("GuiObject") and control.LayoutOrder >= 5 then control.LayoutOrder += 1 end
	end
	local aimEnabled, aimRadius = false, 120
	local aimSlider = Controls.valueSlider(groups.Combat, scope, "Aim radius", aimRadius, 50, 300, function(value) aimRadius = value end)
	aimSlider.LayoutOrder = 5
	local aimGui = UI.make("ScreenGui", localPlayer:WaitForChild("PlayerGui"), { Name = "NexusAimCircle", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10 })
	local aimCircle = UI.make("Frame", aimGui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false })
	UI.make("UICorner", aimCircle, { CornerRadius = UDim.new(1, 0) })
	UI.make("UIStroke", aimCircle, { Color = UI.colors.indigo, Thickness = 1.5, Transparency = 0.15 })
	scope:connect(aimButton.Activated, function()
		aimEnabled = not aimEnabled
		aimButton.Text = aimEnabled and "Aim assist · On" or "Aim assist · Off"
		aimCircle.Visible = aimEnabled
	end)
	scope:connect(RunService.RenderStepped, function(dt)
		if not aimEnabled then return end
		aimCircle.Size = UDim2.fromOffset(aimRadius * 2, aimRadius * 2)
		if Input:GetFocusedTextBox() or not Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or spectatedPlayer then return end
		local camera = workspace.CurrentCamera
		local character = localPlayer.Character
		if not camera or not findGun(character) then return end
		local center = camera.ViewportSize / 2
		local bestPart, bestDistance = nil, aimRadius
		for _, player in ipairs(Players:GetPlayers()) do
			local target = player.Character
			local root = target and target:FindFirstChild("HumanoidRootPart")
			local humanoid = target and target:FindFirstChildOfClass("Humanoid")
			if player ~= localPlayer and (roleData[player.Name] == "Murderer" or visibleWeapon(player) == "Knife visible")
				and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local screen, visible = camera:WorldToViewportPoint(root.Position)
				if visible and screen.Z > 0 then
					local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
					if distance < bestDistance then bestPart, bestDistance = root, distance end
				end
			end
		end
		if bestPart then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			local hit = workspace:Raycast(camera.CFrame.Position, bestPart.Position - camera.CFrame.Position, params)
			if not hit or hit.Instance:IsDescendantOf(bestPart.Parent) then
				local desired = CFrame.lookAt(camera.CFrame.Position, bestPart.Position)
				camera.CFrame = camera.CFrame:Lerp(desired, 1 - math.exp(-8 * dt))
			end
		end
	end)
	scope:add(function() aimGui:Destroy() end)
	local emoteTrack = nil
	local function stopEmote()
		if emoteTrack then pcall(function() emoteTrack:Stop(); emoteTrack:Destroy() end); emoteTrack = nil end
	end
	local function playEmote(assetId)
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator or humanoid.Health <= 0 then actionStatus.Text = "Actions: Animator unavailable"; return end
		stopEmote()
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. assetId
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		animation:Destroy()
		if not ok or not track then actionStatus.Text = "Actions: Emote could not load"; return end
		emoteTrack = track
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		local played = pcall(function() track:Play() end)
		if not played then stopEmote(); actionStatus.Text = "Actions: Emote could not play"; return end
		actionStatus.Text = "Actions: Emote playback requested"
	end
	scope:connect(emoteDanceButton.Activated, function() playEmote("74430100028293") end)
	scope:connect(emoteZombieButton.Activated, function() playEmote("81931167118728") end)
	scope:connect(emoteStopButton.Activated, stopEmote)
	scope:connect(localPlayer.CharacterAdded, stopEmote)
	scope:add(stopEmote)
	local function recordDiagnostic(kind, data)
		table.insert(diagnostics, { time = os.clock(), event = kind, data = data })
		if #diagnostics > 120 then table.remove(diagnostics, 1) end
	end
	local function inspectTool(tool)
		if not tool then return nil end
		local entries = {}
		for _, item in ipairs(tool:GetDescendants()) do
			if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") or item:IsA("BindableEvent") then
				table.insert(entries, { name = item.Name, class = item.ClassName, parent = item.Parent and item.Parent.Name or "" })
			end
		end
		return { name = tool.Name, channels = entries }
	end
	local function saveDiagnostics()
		if type(writefile) ~= "function" then diagnosticStatus.Text = "Diagnostics: File writing unavailable"; return end
		local character = localPlayer.Character
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		local knife = character and character:FindFirstChild("Knife") or backpack and backpack:FindFirstChild("Knife")
		local gun = findGun(character) or findGun(backpack)
		local function hasEvent(name)
			local item = knife and knife:FindFirstChild(name, true)
			return item ~= nil and item:IsA("RemoteEvent")
		end
		local comparison = { legacyStab = hasEvent("Stab"), hhbKnifeStabbed = hasEvent("KnifeStabbed"), hhbHandleTouched = hasEvent("HandleTouched") }
		local ok = pcall(function()
			writefile("nexus-mm2-diagnostics.json", HttpService:JSONEncode({ version = 1, roleSources = roleSources, roleDataBySource = roleSourceData, knife = inspectTool(knife), knifeComparison = comparison, gun = inspectTool(gun), events = diagnostics }))
		end)
		diagnosticStatus.Text = not ok and "Diagnostics: Save failed" or not knife and "Diagnostics: Saved; knife unavailable"
			or comparison.hhbKnifeStabbed and comparison.hhbHandleTouched and "Diagnostics: Saved; HHB knife events found"
			or "Diagnostics: Saved; HHB knife events incomplete"
	end
	scope:connect(diagnosticButton.Activated, saveDiagnostics)

	local fullbright, originalAmbient = false, nil
	local whiteAmbient = Color3.new(1, 1, 1)
	scope:connect(fullbrightButton.Activated, function()
		fullbright = not fullbright
		fullbrightButton.Text = fullbright and "Fullbright · On" or "Fullbright · Off"
		if fullbright then originalAmbient = Lighting.Ambient; Lighting.Ambient = whiteAmbient
		elseif originalAmbient then Lighting.Ambient = originalAmbient; originalAmbient = nil end
	end)
	scope:connect(Lighting:GetPropertyChangedSignal("Ambient"), function()
		if fullbright and Lighting.Ambient ~= whiteAmbient then originalAmbient = Lighting.Ambient; Lighting.Ambient = whiteAmbient end
	end)
	local fovEnabled, fovValue, savedFovs = false, 90, {}
	local function applyFov()
		local camera = workspace.CurrentCamera
		if not camera then return end
		if savedFovs[camera] == nil then savedFovs[camera] = camera.FieldOfView end
		if camera.FieldOfView ~= fovValue then camera.FieldOfView = fovValue end
	end
	local function restoreFov()
		for camera, value in pairs(savedFovs) do if camera.Parent then camera.FieldOfView = value end end
		table.clear(savedFovs)
	end
	scope:connect(fovButton.Activated, function()
		fovEnabled = not fovEnabled
		fovButton.Text = fovEnabled and "FOV · On" or "FOV · Off"
		if fovEnabled then applyFov() else restoreFov() end
	end)
	local fovSlider = Controls.valueSlider(groups.Visuals, scope, "FOV", fovValue, 40, 120, function(value)
		fovValue = value
		if fovEnabled then applyFov() end
	end)
	fovSlider.LayoutOrder = 2
	fovButton.LayoutOrder, antiAfkButton.LayoutOrder, afkStatus.LayoutOrder = 1, 3, 4
	fullbrightButton.LayoutOrder = 0
	scope:connect(RunService.RenderStepped, function() if fovEnabled then applyFov() end end)
	local antiAfk = false
	scope:connect(antiAfkButton.Activated, function()
		antiAfk = not antiAfk
		antiAfkButton.Text = antiAfk and "Anti-AFK · On" or "Anti-AFK · Off"
		afkStatus.Text = antiAfk and "Anti-AFK: Waiting for idle" or "Anti-AFK: Off"
	end)
	scope:connect(localPlayer.Idled, function()
		if not antiAfk then return end
		local ok = pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
		afkStatus.Text = ok and "Anti-AFK: Idle input sent" or "Anti-AFK: Input unavailable"
	end)
	local function stopSpectate()
		spectatedPlayer = nil
		local camera = workspace.CurrentCamera
		local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if camera then camera.CameraSubject = previousCameraSubject and previousCameraSubject.Parent and previousCameraSubject or humanoid end
		previousCameraSubject = nil
	end
	scope:connect(spectateButton.Activated, function()
		local query = string.lower(string.match(spectateInput.Text, "^%s*(.-)%s*$") or "")
		if query == "" then actionStatus.Text = "Actions: Enter a player name"; return end
		local found = nil
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and (string.lower(player.Name) == query or string.lower(player.DisplayName) == query) then
				if found then actionStatus.Text = "Actions: Name matches multiple players"; return end
				found = player
			end
		end
		local humanoid = found and found.Character and found.Character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if not camera or not humanoid then actionStatus.Text = "Actions: Player or character unavailable"; return end
		if not spectatedPlayer then previousCameraSubject = camera.CameraSubject end
		spectatedPlayer = found
		camera.CameraSubject = humanoid
		actionStatus.Text = "Actions: Spectating " .. found.DisplayName
	end)
	scope:connect(stopSpectateButton.Activated, stopSpectate)
	scope:add(function()
		if fullbright then fullbright = false; if originalAmbient then Lighting.Ambient = originalAmbient end end
		fovEnabled = false; restoreFov()
		if spectatedPlayer then stopSpectate() end
	end)
	local serverBusy = false
	scope:connect(TeleportService.TeleportInitFailed, function(player, _, errorMessage)
		if player == localPlayer then
			serverBusy = false
			serverStatus.Text = "Server: Teleport failed: " .. tostring(errorMessage)
		end
	end)
	local function teleportToServer(serverId)
		local ok, err = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, localPlayer)
		end)
		if not ok then
			serverBusy = false
			serverStatus.Text = "Server: Teleport failed: " .. tostring(err)
		else
			serverStatus.Text = "Server: Teleport requested"
			task.delay(15, function()
				if not scope.closed and serverBusy then serverBusy = false; serverStatus.Text = "Server: Teleport not confirmed" end
			end)
		end
	end
	scope:connect(rejoinButton.Activated, function()
		if serverBusy then return end
		if game.JobId == "" then serverStatus.Text = "Server: Current server ID unavailable"; return end
		serverBusy = true
		serverStatus.Text = "Server: Rejoining current server"
		teleportToServer(game.JobId)
	end)
	scope:connect(serverHopButton.Activated, function()
		if serverBusy then return end
		serverBusy = true
		serverStatus.Text = "Server: Searching for another public server"
		task.spawn(function()
			local cursor = nil
			local choices = {}
			local failure = nil
			for _ = 1, 3 do
				local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
				if cursor then url ..= "&cursor=" .. HttpService:UrlEncode(cursor) end
				local ok, body = pcall(function() return game:HttpGet(url) end)
				if not ok or type(body) ~= "string" then failure = "Server list unavailable"; break end
				local decoded, page = pcall(function() return HttpService:JSONDecode(body) end)
				if not decoded or type(page) ~= "table" or type(page.data) ~= "table" then failure = "Invalid server list"; break end
				for _, server in ipairs(page.data) do
					if type(server) == "table" and type(server.id) == "string" and server.id ~= game.JobId
						and type(server.playing) == "number" and type(server.maxPlayers) == "number" and server.playing < server.maxPlayers then
						table.insert(choices, server.id)
					end
				end
				if #choices > 0 or type(page.nextPageCursor) ~= "string" or page.nextPageCursor == "" then break end
				cursor = page.nextPageCursor
			end
			if scope.closed then return end
			if #choices == 0 then
				serverBusy = false
				serverStatus.Text = "Server: " .. (failure or "No available server found")
				return
			end
			teleportToServer(choices[math.random(1, #choices)])
		end)
	end)

	local function findDroppedGun(): Instance?
		return workspace:FindFirstChild("GunDrop", true)
	end
	local function getPosition(object: Instance?): Vector3?
		if object and object:IsA("BasePart") then return object.Position end
		if object and object:IsA("Model") then return object:GetPivot().Position end
		return nil
	end
	local function clearGun()
		if gunHighlight then gunHighlight:Destroy() end
		gunHighlight = nil
		gunTarget = nil
	end
	local function finishGunPickup()
		local previous = gunPickup
		gunPickup = nil
		if not previous then return end
		if previous.backpackConnection then previous.backpackConnection:Disconnect() end
		if previous.characterConnection then previous.characterConnection:Disconnect() end
		if previous.moved and localPlayer.Character == previous.character and previous.character.Parent and previous.humanoid.Health > 0 then
			previous.character:PivotTo(previous.origin)
		end
	end
	local function startGunPickup(dropped: Instance?)
		if not autoGun or gunPickup or flingState or not dropped or os.clock() < gunRetryAfter then return end
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		if not character or not humanoid or humanoid.Health <= 0 or not backpack then
			actionStatus.Text = "Actions: Character or backpack unavailable"
			return
		end
		if findGun(character) or findGun(backpack) then return end
		local attempt = { character = character, humanoid = humanoid, moved = false, origin = nil, backpackConnection = nil, characterConnection = nil }
		gunPickup = attempt
		if scope.closed or not autoGun or gunPickup ~= attempt then return end
		local position = dropped.Parent and getPosition(dropped)
		if localPlayer.Character ~= character or not character.Parent or humanoid.Health <= 0 or not position then
			finishGunPickup()
			gunRetryAfter = os.clock() + 0.25
			actionStatus.Text = "Actions: Dropped gun or character no longer available"
			return
		end
		local function onAdded(item)
			if gunPickup == attempt and isGunTool(item) then
				finishGunPickup()
				actionStatus.Text = "Actions: Gun detected; returned to previous position"
			end
		end
		attempt.backpackConnection = backpack.ChildAdded:Connect(onAdded)
		attempt.characterConnection = character.ChildAdded:Connect(onAdded)
		if findGun(character) or findGun(backpack) then
			finishGunPickup()
			actionStatus.Text = "Actions: Gun already in inventory"
			return
		end
		attempt.origin = character:GetPivot()
		attempt.moved = true
		actionStatus.Text = "Actions: At dropped gun; waiting for pickup"
		local ok = pcall(function() character:MoveTo(position) end)
		if not ok then
			finishGunPickup()
			gunRetryAfter = os.clock() + 1
			actionStatus.Text = "Actions: Could not move to dropped gun"
			return
		end
		task.delay(6, function()
			if gunPickup == attempt then
				finishGunPickup()
				gunRetryAfter = os.clock() + 1
				actionStatus.Text = "Actions: Pickup not confirmed; returned"
			end
		end)
	end
	local function shoot()
		if shotPending or os.clock() - lastShot < 1 then return end
		local character = localPlayer.Character
		local gun = findGun(character)
		if not gun or not gun:IsA("Tool") then
			actionStatus.Text = "Actions: Equip the gun to shoot"
			return
		end
		local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
		local remote = gun and gun:FindFirstChild("Shoot", true)
		local knifeLocal = gun and gun:FindFirstChild("KnifeLocal")
		local createBeam = knifeLocal and knifeLocal:FindFirstChild("CreateBeam")
		local beamRemote = createBeam and createBeam:FindFirstChild("RemoteFunction")
		if not gun or not hand or not hand:IsA("BasePart") or not ((remote and remote:IsA("RemoteEvent")) or (beamRemote and beamRemote:IsA("RemoteFunction"))) then
			actionStatus.Text = "Actions: Compatible gun shooting interface not found"
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local target = player.Character
			local root = target and target:FindFirstChild("HumanoidRootPart")
			if player ~= localPlayer and (roleData[player.Name] == "Murderer" or visibleWeapon(player) == "Knife visible") and root and root:IsA("BasePart") then
				local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
				if not targetHumanoid or targetHumanoid.Health <= 0 then continue end
				local velocity = root.AssemblyLinearVelocity
				local pingOk, ping = pcall(function() return localPlayer:GetNetworkPing() end)
				if not pingOk or type(ping) ~= "number" or ping ~= ping or ping < 0 or ping == math.huge then ping = nil end
				local leadTime = AimPrediction.leadTime(predictionMode, shootOffset, ping)
				local predictedVelocity = velocity
				if predictionMode == "Adaptive" then
					local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
					if horizontal.Magnitude > 50 then horizontal = horizontal.Unit * 50 end
					predictedVelocity = Vector3.new(horizontal.X, math.clamp(velocity.Y, -40, 40), horizontal.Z)
				end
				local lead = predictedVelocity * Vector3.new(1, predictionMode == "HHB" and 1 or 0.5, 1) * leadTime
				if predictionMode == "Adaptive" and lead.Magnitude > 10 then lead = lead.Unit * 10 end
				local aim = root.Position + lead
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { character }
				local hit = workspace:Raycast(hand.Position, root.Position - hand.Position, params)
				if not hit or hit.Instance:IsDescendantOf(target) then
					lastShot = os.clock()
					shotPending = true
					local healthBefore = targetHumanoid.Health
					local channel = beamRemote and beamRemote:IsA("RemoteFunction") and "KnifeLocal.CreateBeam.RemoteFunction" or "Shoot RemoteEvent"
					local shooterRoot = character:FindFirstChild("HumanoidRootPart")
					local function xyz(vector) return { x = vector.X, y = vector.Y, z = vector.Z } end
					recordDiagnostic("shot_attempt", { gun = gun.Name, channel = channel, target = player.Name, healthBefore = healthBefore, prediction = predictionMode, ping = ping, leadTime = leadTime, targetPosition = xyz(root.Position), targetVelocity = xyz(velocity), aim = xyz(aim), origin = xyz(hand.Position), shooterVelocity = shooterRoot and shooterRoot:IsA("BasePart") and xyz(shooterRoot.AssemblyLinearVelocity) or nil })
					task.spawn(function()
						local sent = false
						local ok, err = pcall(function()
							if gun.Parent ~= character or localPlayer.Character ~= character then return end
							if beamRemote and beamRemote:IsA("RemoteFunction") then
								sent = true
								beamRemote:InvokeServer(1, aim, "AH2")
							elseif remote and remote:IsA("RemoteEvent") then
								sent = true
								remote:FireServer(hand.CFrame, CFrame.new(aim))
							end
						end)
						shotPending = false
						recordDiagnostic("shot_dispatch", { sent = sent, ok = ok, error = not ok and tostring(err) or nil })
						task.delay(1, function()
							if scope.closed then return end
							recordDiagnostic("shot_observation", { target = player.Name, healthBefore = healthBefore, healthAfter = targetHumanoid.Parent and targetHumanoid.Health or nil })
							saveDiagnostics()
						end)
						if not scope.closed then actionStatus.Text = not ok and "Actions: Shot failed" or sent and "Actions: Shot sent; server result unverified" or "Actions: Shot canceled; gun unequipped" end
					end)
					return
				end
			end
		end
		actionStatus.Text = "Actions: No visible knife holder in line of sight"
	end
	local function equipAndShoot()
		if shotRequestPending or shotPending then return end
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		local gun = findGun(character) or findGun(backpack)
		if not character or not humanoid or humanoid.Health <= 0 or not gun or not gun:IsA("Tool") then
			actionStatus.Text = "Actions: Living character and gun required"
			return
		end
		shotRequestPending = true
		task.spawn(function()
			if gun.Parent ~= character then
				local equipped = pcall(function() humanoid:EquipTool(gun) end)
				if not equipped then
					shotRequestPending = false
					if not scope.closed then actionStatus.Text = "Actions: Gun could not be equipped" end
					return
				end
			end
			local deadline = os.clock() + 1
			while not scope.closed and localPlayer.Character == character and humanoid.Health > 0 and gun.Parent ~= character and os.clock() < deadline do
				RunService.Heartbeat:Wait()
			end
			if not scope.closed and localPlayer.Character == character and humanoid.Health > 0 and gun.Parent == character then
				shoot()
			elseif not scope.closed then
				actionStatus.Text = "Actions: Gun could not be equipped"
			end
			shotRequestPending = false
		end)
	end
	local function withMurdererKnife(callback)
		if murdererActionBusy then return end
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		local knife = character and character:FindFirstChild("Knife") or backpack and backpack:FindFirstChild("Knife")
		if not character or not humanoid or humanoid.Health <= 0 or not knife or not knife:IsA("Tool") then
			actionStatus.Text = "Actions: Living character and murderer knife required"
			return
		end
		murdererActionBusy = true
		task.spawn(function()
			local ok, err = pcall(function()
				if knife.Parent ~= character then humanoid:EquipTool(knife) end
				local deadline = os.clock() + 1
				while not scope.closed and localPlayer.Character == character and humanoid.Health > 0 and knife.Parent ~= character and os.clock() < deadline do
					RunService.Heartbeat:Wait()
				end
				if scope.closed then return end
				if localPlayer.Character ~= character or humanoid.Health <= 0 or knife.Parent ~= character then
					actionStatus.Text = "Actions: Knife could not be equipped"
					return
				end
				callback(character, humanoid, knife)
			end)
			murdererActionBusy = false
			if not ok and not scope.closed then actionStatus.Text = "Actions: Knife action failed: " .. tostring(err) end
		end)
	end
	local function throwAtNearest()
		withMurdererKnife(function(character, _, knife)
			local root = character:FindFirstChild("HumanoidRootPart")
			local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
			local events = knife:FindFirstChild("Events")
			local remote = events and events:FindFirstChild("KnifeThrown")
			if not root or not root:IsA("BasePart") or not hand or not hand:IsA("BasePart") or not remote or not remote:IsA("RemoteEvent") then
				actionStatus.Text = "Actions: KnifeThrown or character part unavailable"
				recordDiagnostic("knife_throw_unavailable", { knife = inspectTool(knife) }); saveDiagnostics()
				return
			end
			local chosen, distance = nil, math.huge
			for _, player in ipairs(Players:GetPlayers()) do
				local target = player.Character
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
				if player ~= localPlayer and targetRoot and targetRoot:IsA("BasePart") and targetHumanoid and targetHumanoid.Health > 0 then
					local current = (targetRoot.Position - root.Position).Magnitude
					if current < distance then chosen, distance = targetRoot, current end
				end
			end
			if not chosen then actionStatus.Text = "Actions: No living target"; return end
			local aim = chosen.Position + chosen.AssemblyLinearVelocity * 0.1
			remote:FireServer(CFrame.new(hand.Position), CFrame.new(aim))
			recordDiagnostic("knife_throw", { channel = "Events.KnifeThrown", distance = distance })
			actionStatus.Text = "Actions: Knife throw sent; result unverified"
		end)
	end
	local function modernKillAll()
		withMurdererKnife(function(_, _, knife)
			local events = knife:FindFirstChild("Events")
			local stab = events and events:FindFirstChild("KnifeStabbed")
			local touch = events and events:FindFirstChild("HandleTouched")
			if not stab or not stab:IsA("RemoteEvent") or not touch or not touch:IsA("RemoteEvent") then
				actionStatus.Text = "Actions: HHB knife events unavailable; diagnostics saved"
				recordDiagnostic("modern_kill_all_unavailable", { knife = inspectTool(knife) }); saveDiagnostics()
				return
			end
			local attempted = 0
			for _, player in ipairs(Players:GetPlayers()) do
				if scope.closed or not knife.Parent or knife.Parent ~= localPlayer.Character then break end
				local target = player.Character
				local head = target and target:FindFirstChild("Head")
				local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
				if player ~= localPlayer and head and head:IsA("BasePart") and targetHumanoid and targetHumanoid.Health > 0 then
					stab:FireServer()
					touch:FireServer(head)
					attempted += 1
					recordDiagnostic("modern_kill_all_attempt", { target = player.Name, healthBefore = targetHumanoid.Health, channels = "KnifeStabbed, HandleTouched" })
					task.delay(1, function()
						if scope.closed then return end
						recordDiagnostic("modern_kill_all_observation", { target = player.Name, healthAfter = targetHumanoid.Parent and targetHumanoid.Health or nil })
						saveDiagnostics()
					end)
					task.wait(0.05)
				end
			end
			actionStatus.Text = "Actions: Knife events sent to " .. attempted .. " targets; result unverified"
		end)
	end
	scope:connect(modernKillAllButton.Activated, modernKillAll)
	scope:connect(knifeThrowButton.Activated, throwAtNearest)
	scope:connect(autoKnifeThrowButton.Activated, function()
		autoKnifeThrow = not autoKnifeThrow
		autoKnifeThrowButton.Text = autoKnifeThrow and "Murderer: auto throw · On" or "Murderer: auto throw · Off"
	end)
	scope:connect(killAuraButton.Activated, function()
		killAura = not killAura
		killAuraButton.Text = killAura and "Murderer: kill aura · On" or "Murderer: kill aura · Off"
	end)
	local function attackNearby()
		withMurdererKnife(function(character, _, knife)
			if not killAura then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then return end
			local nearest, nearestDistance = nil, 9
			for _, player in ipairs(Players:GetPlayers()) do
				local target = player.Character
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				local humanoid = target and target:FindFirstChildOfClass("Humanoid")
				if player ~= localPlayer and targetRoot and targetRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
					local distance = (targetRoot.Position - root.Position).Magnitude
					if distance < nearestDistance then nearest, nearestDistance = target, distance end
				end
			end
			if not nearest then return end
			local events = knife:FindFirstChild("Events")
			local stabbed = events and events:FindFirstChild("KnifeStabbed")
			local touched = events and events:FindFirstChild("HandleTouched")
			local head = nearest:FindFirstChild("Head")
			local legacy = knife:FindFirstChild("Stab")
			if stabbed and stabbed:IsA("RemoteEvent") and touched and touched:IsA("RemoteEvent") and head and head:IsA("BasePart") then
				stabbed:FireServer(); touched:FireServer(head)
				recordDiagnostic("kill_aura_attempt", { channel = "KnifeStabbed/HandleTouched", distance = nearestDistance })
			elseif legacy and legacy:IsA("RemoteEvent") then
				legacy:FireServer("Slash")
				recordDiagnostic("kill_aura_attempt", { channel = "Stab", distance = nearestDistance })
			else
				killAura = false
				killAuraButton.Text = "Murderer: kill aura · Off"
				actionStatus.Text = "Actions: Knife attack channels unavailable"
				recordDiagnostic("kill_aura_unavailable", { knife = inspectTool(knife) }); saveDiagnostics()
				return
			end
			actionStatus.Text = "Actions: Nearby knife attack sent; result unverified"
		end)
	end
	scope:connect(gunButton.Activated, function()
		gunOverlay = not gunOverlay
		gunButton.Text = gunOverlay and "Dropped gun overlay · On" or "Dropped gun overlay · Off"
		if not gunOverlay then clearGun() end
	end)
	scope:connect(collectButton.Activated, function()
		collectCoins = not collectCoins
		collectButton.Text = collectCoins and "Collect coins · On" or "Collect coins · Off"
		if not collectCoins then
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if coinHumanoid and root and root:IsA("BasePart") then coinHumanoid:MoveTo(root.Position) end
			if coinHumanoid and coinHumanoid.Parent and coinOriginalSpeed ~= nil and coinHumanoid.WalkSpeed == coinAppliedSpeed then coinHumanoid.WalkSpeed = coinOriginalSpeed end
			coinHumanoid, coinOriginalSpeed, coinAppliedSpeed = nil, nil, nil
			coinTarget, coinStuckPosition = nil, nil
			coinStatus.Text = "Coin farm: Off"
		end
	end)
	scope:connect(shootOnceButton.Activated, equipAndShoot)
	scope:connect(autoShootButton.Activated, function()
		autoShoot = not autoShoot
		autoShootButton.Text = autoShoot and "Auto shoot on gun · On" or "Auto shoot on gun · Off"
	end)
	scope:connect(predictionButton.Activated, function()
		predictionMode = predictionMode == "Adaptive" and "YARHM" or predictionMode == "YARHM" and "HHB" or "Adaptive"
		predictionButton.Text = "Shot prediction · " .. predictionMode
	end)
	scope:connect(offsetInput.FocusLost, function()
		local value = tonumber(offsetInput.Text)
		if value and value == value then shootOffset = math.clamp(value, 0, 10) end
		offsetInput.Text = tostring(shootOffset)
	end)
	scope:connect(moveGunButton.Activated, function()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local position = getPosition(findDroppedGun())
		if humanoid and position then
			humanoid:MoveTo(position)
			actionStatus.Text = "Actions: Moving toward dropped gun"
		else
			actionStatus.Text = "Actions: Dropped gun or character unavailable"
		end
	end)
	scope:connect(autoGunButton.Activated, function()
		autoGun = not autoGun
		gunRetryAfter = 0
		autoGunButton.Text = autoGun and "Auto teleport & pick up gun · On" or "Auto teleport & pick up gun · Off"
		if not autoGun then finishGunPickup() end
		if autoGun then
			actionStatus.Text = "Actions: Waiting for dropped gun"
			startGunPickup(findDroppedGun())
		end
	end)
	local function stopFly()
		if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
		if flyGyro then flyGyro:Destroy(); flyGyro = nil end
		if flyingHumanoid and flyingHumanoid.Parent then flyingHumanoid.PlatformStand = oldPlatformStand end
		flyingHumanoid = nil
	end
	local function restoreCollision()
		collisions:restore()
	end
	scope:connect(noclipButton.Activated, function()
		if flingState then actionStatus.Text = "Actions: Wait for fling to finish"; return end
		noclip = not noclip
		noclipButton.Text = noclip and "Noclip · On" or "Noclip · Off"
		if not noclip then restoreCollision() end
	end)
	scope:connect(RunService.Stepped, function()
		if not noclip then return end
		collisions:apply(localPlayer.Character)
	end)
	local function stopFling()
		-- The imported routine stops after its bounded attempt and restores the character.
	end
	local function startFling(targetPlayer: Player?)
		if flingState then actionStatus.Text = "Actions: Fling already in progress"; return end
		if gunPickup then actionStatus.Text = "Actions: Wait for gun pickup to finish"; return end
		if flying or noclip then actionStatus.Text = "Actions: Turn off Fly and Noclip before fling"; return end
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			actionStatus.Text = "Actions: Fling needs a living character; waiting for respawn"
			return
		end
		if not targetPlayer or not targetPlayer.Character then
			actionStatus.Text = "Actions: Target or role unavailable"
			return
		end
		flingState = true
		actionStatus.Text = "Actions: YARHM fling running"
		task.spawn(function()
			local ok = YARHMFling.run(targetPlayer, scope, function(message)
				if not scope.closed then actionStatus.Text = "Actions: " .. tostring(message) end
			end)
			flingState = nil
			if not scope.closed then actionStatus.Text = ok and "Actions: Fling finished; target result unverified" or "Actions: Fling failed" end
			if not scope.closed and autoGun then startGunPickup(findDroppedGun()) end
		end)
	end
	local function roleTarget(role: string, fallbackWeapon: string): Player?
		local match = nil
		for _, player in ipairs(Players:GetPlayers()) do
			local roleValue = roleData[player.Name]
			if player ~= localPlayer and (roleValue == role or (role == "Sheriff" and roleValue == "Hero")) then
				if match then actionStatus.Text = "Actions: Multiple matching roles"; return nil end
				match = player
			end
		end
		if match then return match end
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and visibleWeapon(player) == fallbackWeapon then
				if match then actionStatus.Text = "Actions: Multiple matching weapons"; return nil end
				match = player
			end
		end
		return match
	end
	scope:connect(flingMurdererButton.Activated, function() startFling(roleTarget("Murderer", "Knife visible")) end)
	scope:connect(flingSheriffButton.Activated, function() startFling(roleTarget("Sheriff", "Gun visible")) end)
	scope:connect(flingPlayerButton.Activated, function()
		local requested = string.lower(string.match(flingPlayerName.Text, "^%s*(.-)%s*$") or "")
		if requested == "" then actionStatus.Text = "Actions: Enter a player name"; return end
		local exact, partial = nil, nil
		local ambiguous = false
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer then
				local username, display = string.lower(player.Name), string.lower(player.DisplayName)
				if username == requested then exact = player; break end
				if string.sub(username, 1, #requested) == requested or string.sub(display, 1, #requested) == requested then
					if partial then ambiguous = true else partial = player end
				end
			end
		end
		if not exact and ambiguous then actionStatus.Text = "Actions: Name matches multiple players"; return end
		startFling(exact or partial)
	end)
	local function toggleFly()
		if flingState then actionStatus.Text = "Actions: Wait for fling to finish"; return end
		if gunPickup then actionStatus.Text = "Actions: Wait for gun pickup to finish"; return end
		flying = not flying
		flyButton.Text = flying and "Fly (all roles) · On" or "Fly (all roles) · Off"
		if not flying then stopFly() end
	end
	scope:connect(flyButton.Activated, toggleFly)
	local function toggleFlyAndNoclip()
		if flingState then actionStatus.Text = "Actions: Wait for fling to finish"; return end
		if gunPickup then actionStatus.Text = "Actions: Wait for gun pickup to finish"; return end
		local enable = not (flying and noclip)
		flying, noclip = enable, enable
		flyButton.Text = flying and "Fly (all roles) · On" or "Fly (all roles) · Off"
		noclipButton.Text = noclip and "Noclip · On" or "Noclip · Off"
		if not enable then stopFly(); restoreCollision() end
	end
	scope:connect(flyKeyBox.FocusLost, function()
		local requested = string.lower(string.match(flyKeyBox.Text, "^%s*(.-)%s*$") or "")
		for _, key in ipairs(Enum.KeyCode:GetEnumItems()) do
			if key ~= Enum.KeyCode.Unknown and string.lower(key.Name) == requested then
				if key == shortcut or key == Enum.KeyCode.H or key.Name == context.settings:get("hotkey") then
					actionStatus.Text = "Actions: Shortcut already in use"
				else
					flyShortcut = key
					context.settings:set("mm2FlyNoclipHotkey", key.Name)
				end
				break
			end
		end
		flyKeyBox.Text = flyShortcut.Name
	end)
	scope:connect(RunService.RenderStepped, function()
		if not flying then return end
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or not camera then
			stopFly()
			return
		end
		if flyingHumanoid ~= humanoid or not flyVelocity or flyVelocity.Parent ~= root then
			stopFly()
			flyingHumanoid = humanoid
			oldPlatformStand = humanoid.PlatformStand
			humanoid.PlatformStand = true
			flyVelocity = Instance.new("BodyVelocity")
			flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
			flyVelocity.Parent = root
			flyGyro = Instance.new("BodyGyro")
			flyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
			flyGyro.P = 10000
			flyGyro.Parent = root
		end
		local direction = Vector3.zero
		if not Input:GetFocusedTextBox() then
			if Input:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
			if Input:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
			if Input:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
			if Input:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
			if Input:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
			if Input:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
		end
		flyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * flySpeed or Vector3.zero
		if flyGyro then flyGyro.CFrame = camera.CFrame end
	end)

	local function cleanup(player)
		local record = records[player]
		if record then
			record.highlight:Destroy()
			record.billboard:Destroy()
			records[player] = nil
		end
	end
	local function clear()
		for player in pairs(records) do cleanup(player) end
	end
	local function toggle()
		enabled = not enabled
		button.Text = enabled and "Player overlay · On" or "Player overlay · Off"
		status.Text = enabled and "Status: Scanning visible players" or "Status: Off"
		if not enabled then clear() end
	end
	scope:connect(button.Activated, toggle)
	scope:connect(keyBox.FocusLost, function()
		local requested = string.lower(string.match(keyBox.Text, "^%s*(.-)%s*$") or "")
		for _, key in ipairs(Enum.KeyCode:GetEnumItems()) do
			if key ~= Enum.KeyCode.Unknown and string.lower(key.Name) == requested then
				if key == flyShortcut or key == Enum.KeyCode.H or key.Name == context.settings:get("hotkey") then
					actionStatus.Text = "Actions: Shortcut already in use"
				else
					shortcut = key
					context.settings:set("mm2OverlayHotkey", key.Name)
				end
				break
			end
		end
		keyBox.Text = shortcut.Name
	end)
	scope:connect(Input.InputBegan, function(input, processed)
		if not processed and not Input:GetFocusedTextBox() then
			if input.KeyCode == Enum.KeyCode.MouseBackButton then equipAndShoot()
			elseif input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == shortcut then toggle()
				elseif input.KeyCode == flyShortcut then toggleFlyAndNoclip()
				elseif input.KeyCode == Enum.KeyCode.H then equipAndShoot() end
			end
		end
	end)
	scope:connect(Players.PlayerRemoving, cleanup)
	scope:connect(Players.PlayerRemoving, function(player)
		roleData[player.Name] = nil
		if spectatedPlayer == player then stopSpectate() end
	end)
	scope:connect(workspace.DescendantAdded, function(object)
		if object.Name == "GunDrop" then startGunPickup(object) end
	end)
	scope:connect(RunService.Heartbeat, function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		if autoKnifeThrow and not murdererActionBusy and os.clock() - lastKnifeThrow >= 1.5 then
			local character = localPlayer.Character
			local backpack = localPlayer:FindFirstChildOfClass("Backpack")
			local knife = character and character:FindFirstChild("Knife") or backpack and backpack:FindFirstChild("Knife")
			if knife and knife:IsA("Tool") then lastKnifeThrow = os.clock(); throwAtNearest() end
		end
		if killAura and not murdererActionBusy and os.clock() - lastAuraAttempt >= 0.75 then
			local character = localPlayer.Character
			local backpack = localPlayer:FindFirstChildOfClass("Backpack")
			local knife = character and character:FindFirstChild("Knife") or backpack and backpack:FindFirstChild("Knife")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if knife and knife:IsA("Tool") and root and root:IsA("BasePart") then
				for _, player in ipairs(Players:GetPlayers()) do
					local other = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if player ~= localPlayer and other and other:IsA("BasePart") and hum and hum.Health > 0 and (other.Position - root.Position).Magnitude < 9 then
						lastAuraAttempt = os.clock(); attackNearby(); break
					end
				end
			end
		end
		if autoGun and not flingState and not gunPickup and os.clock() >= gunRetryAfter then
			local dropped = findDroppedGun()
			if dropped then startGunPickup(dropped) end
		end
		if gunOverlay then
			local dropped = findDroppedGun()
			if dropped ~= gunTarget then
				clearGun()
				if dropped and (dropped:IsA("BasePart") or dropped:IsA("Model")) then
					gunTarget = dropped
					gunHighlight = Instance.new("Highlight")
					gunHighlight.FillColor = Color3.fromRGB(255, 220, 40)
					gunHighlight.Adornee = dropped
					gunHighlight.Parent = dropped
				end
			end
		end
		if autoShoot and not gunPickup and not shotRequestPending and not shotPending and os.clock() - lastShot >= 1 then
			local character = localPlayer.Character
			local backpack = localPlayer:FindFirstChildOfClass("Backpack")
			local gun = findGun(character) or findGun(backpack)
			local ownRoot = character and character:FindFirstChild("HumanoidRootPart")
			if gun and gun:IsA("Tool") and ownRoot and ownRoot:IsA("BasePart") then
				for _, player in ipairs(Players:GetPlayers()) do
					local target = player.Character
					local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
					local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
					if player ~= localPlayer and (roleData[player.Name] == "Murderer" or visibleWeapon(player) == "Knife visible") and targetRoot and targetRoot:IsA("BasePart") and targetHumanoid and targetHumanoid.Health > 0 then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = { character }
						local hit = workspace:Raycast(ownRoot.Position, targetRoot.Position - ownRoot.Position, params)
						if not hit or hit.Instance:IsDescendantOf(target) then equipAndShoot(); break end
					end
				end
			end
		end
		if spectatedPlayer then
			local hum = spectatedPlayer.Character and spectatedPlayer.Character:FindFirstChildOfClass("Humanoid")
			if not spectatedPlayer.Parent then stopSpectate()
			elseif hum and workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject ~= hum then workspace.CurrentCamera.CameraSubject = hum end
		end
		if collectCoins and not gunPickup and not flingState and not flying then
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local map = workspace:FindFirstChild("Normal")
			if not map or not map:FindFirstChild("CoinContainer", true) then
				for _, candidate in ipairs(workspace:GetChildren()) do
					if candidate:FindFirstChild("CoinContainer", true) then map = candidate; break end
				end
			end
			local coins = map and map:FindFirstChild("CoinContainer", true)
			local fullBag = localPlayer.PlayerGui:FindFirstChild("FullBagIcon", true)
			local bagFull = fullBag and fullBag:IsA("GuiObject") and fullBag.Visible
			local ancestor = fullBag and fullBag.Parent
			while bagFull and ancestor do
				if ancestor:IsA("GuiObject") and not ancestor.Visible then bagFull = false end
				if ancestor:IsA("ScreenGui") and not ancestor.Enabled then bagFull = false end
				ancestor = ancestor.Parent
			end
			if bagFull then
				collectCoins = false
				collectButton.Text = "Collect coins · Off"
				coinStatus.Text = "Coin farm: Bag full; stopped"
				if coinHumanoid and root and root:IsA("BasePart") then coinHumanoid:MoveTo(root.Position) end
				if coinHumanoid and coinHumanoid.Parent and coinOriginalSpeed ~= nil and coinHumanoid.WalkSpeed == coinAppliedSpeed then coinHumanoid.WalkSpeed = coinOriginalSpeed end
				coinHumanoid, coinOriginalSpeed, coinAppliedSpeed = nil, nil, nil
			elseif root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and coins then
				if coinHumanoid ~= humanoid then
					if coinHumanoid and coinHumanoid.Parent and coinOriginalSpeed ~= nil and coinHumanoid.WalkSpeed == coinAppliedSpeed then coinHumanoid.WalkSpeed = coinOriginalSpeed end
					coinHumanoid, coinOriginalSpeed = humanoid, humanoid.WalkSpeed
				end
				coinAppliedSpeed = coinSpeed
				if humanoid.WalkSpeed ~= coinSpeed then humanoid.WalkSpeed = coinSpeed end
				local nearest, nearestDistance = nil, math.huge
				for _, coin in ipairs(coins:GetDescendants()) do
					if coin:IsA("BasePart") and coin.Name == "Coin_Server" and (not coinBlacklist[coin] or os.clock() >= coinBlacklist[coin]) then
						local distance = (coin.Position - root.Position).Magnitude
						if distance < nearestDistance then nearest, nearestDistance = coin, distance end
					end
				end
				if nearest then
					if nearest ~= coinTarget or not coinStuckPosition or (root.Position - coinStuckPosition).Magnitude > 2 then
						coinTarget, coinStuckPosition, coinStuckSince = nearest, root.Position, os.clock()
					elseif os.clock() - coinStuckSince >= 4 then
						coinBlacklist[nearest] = os.clock() + 10
						coinTarget, coinStuckPosition = nil, nil
					end
					if os.clock() - lastCoinUpdate >= 0.5 then humanoid:MoveTo(nearest.Position); lastCoinUpdate = os.clock() end
					coinStatus.Text = fullBag and "Coin farm: Moving to coin" or "Coin farm: Moving; bag status unavailable"
				else
					coinStatus.Text = "Coin farm: No available coins"
				end
			else
				coinStatus.Text = "Coin farm: Waiting for map or character"
			end
		elseif collectCoins then
			coinStatus.Text = "Coin farm: Paused during movement action"
			if coinHumanoid and coinHumanoid.Parent and coinOriginalSpeed ~= nil and coinHumanoid.WalkSpeed == coinAppliedSpeed then coinHumanoid.WalkSpeed = coinOriginalSpeed end
			coinHumanoid, coinOriginalSpeed, coinAppliedSpeed = nil, nil, nil
		end
		if not enabled then return end
		local ownRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not character or not root or not root:IsA("BasePart") then
					cleanup(player)
				else
					local record = records[player]
					if record and record.character ~= character then cleanup(player); record = nil end
					if not record then
						local highlight = Instance.new("Highlight")
						highlight.Adornee = character
						highlight.FillTransparency = 0.65
						highlight.Parent = character
						local billboard = Instance.new("BillboardGui")
						billboard.Adornee = root
						billboard.Size = UDim2.fromOffset(160, 45)
						billboard.StudsOffset = Vector3.new(0, 3.5, 0)
						billboard.AlwaysOnTop = true
						local label = Instance.new("TextLabel")
						label.Size = UDim2.fromScale(1, 1)
						label.BackgroundTransparency = 1
						label.TextColor3 = Color3.new(1, 1, 1)
						label.TextStrokeTransparency = 0
						label.TextSize = 13
						label.Parent = billboard
						billboard.Parent = character
						record = { character = character, highlight = highlight, billboard = billboard, label = label }
						records[player] = record
					end
					local weapon = visibleWeapon(player)
					local role = roleData[player.Name]
					local labelText = role == "Murderer" and "Murderer" or role == "Sheriff" and "Sheriff" or role == "Hero" and "Hero" or role == "Innocent" and "Innocent" or weapon
					record.highlight.FillColor = (role == "Murderer" or (not role and weapon == "Knife visible")) and Color3.fromRGB(255, 80, 80)
						or role == "Hero" and Color3.fromRGB(255, 200, 55)
						or (role == "Sheriff" or (not role and weapon == "Gun visible")) and Color3.fromRGB(80, 160, 255)
						or role == "Innocent" and Color3.fromRGB(80, 220, 110) or Color3.fromRGB(180, 180, 180)
					local distance = ownRoot and ownRoot:IsA("BasePart") and string.format(" · %.0f studs", (ownRoot.Position - root.Position).Magnitude) or ""
					local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
					local health = targetHumanoid and string.format(" · HP %.0f", targetHumanoid.Health) or ""
					record.label.Text = player.DisplayName .. distance .. health .. "\n" .. labelText
				end
			end
		end
	end)
	scope:add(function()
		if coinHumanoid and coinHumanoid.Parent and coinOriginalSpeed ~= nil and coinHumanoid.WalkSpeed == coinAppliedSpeed then coinHumanoid.WalkSpeed = coinOriginalSpeed end
		finishGunPickup()
		stopFling()
		restoreCollision()
		stopFly()
		clear()
		clearGun()
	end)
end

return table.freeze(MM2)

