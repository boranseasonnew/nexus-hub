local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local UI = require(script.Parent.Parent.ui.Components)
local Controls = require(script.Parent.Parent.ui.Controls)
local CollisionTracker = require(script.Parent.logic.CollisionTracker)

local Doors = {}

function Doors.mount(context)
	local scope, parent = context.scope, context.parent
	local enabled = false
	local highlights = {}
	local elapsed = 0
	local evadeEnabled = false
	local undergroundEnabled = false
	local hiddenCharacter = nil
	local returnPosition = nil
	local hidePlatform = nil
	local clearSince = nil
	local hideDestination = nil
	local hideAttempts = 0
	local lastHideAttempt = 0
	local hideConfirmed = false
	local hiddenRoot, originalAnchored = nil, nil
	local hideEvents = {}
	local lastHideLog = 0
	local lastEvade = 0
	local doorEnabled, keyEnabled, alertsEnabled = false, false, false
	local tracked = {}
	local seenEntities = {}
	local scanElapsed = 0
	local doorScanElapsed = 0
	local diagnosticElapsed = 0
	local diagnosticSaveElapsed = 0
	local diagnosticSamples = {}
	local diagnosticPosition = nil
	local diagnosticTime = nil
	local fullbrightEnabled = false
	local ambientBeforeFullbright = nil
	local fullbrightAmbient = Color3.new(1, 1, 1)
	local boostEnabled, boostValue = false, 4
	local boostedCharacter, originalBoost = nil, nil
	local noclipEnabled, antiAfkEnabled, fovEnabled = false, false, false
	local collisions = CollisionTracker.new()
	local fovValue, savedFovs = 90, {}
	local entityNames = {
		RushMoving = "Rush", AmbushMoving = "Ambush", Eyes = "Eyes",
		SeekMoving = "Seek", FigureRagdoll = "Figure", A60 = "A-60", A120 = "A-120",
	}
	local names = {
		RushMoving = Color3.fromRGB(255, 75, 75),
		AmbushMoving = Color3.fromRGB(255, 75, 75),
		KeyObtain = Color3.fromRGB(255, 215, 70),
		LiveHintBook = Color3.fromRGB(255, 215, 70),
	}
	UI.label(parent, "DOORS - Nexus Hub", 26, false)
	UI.label(parent, "Highlights visible door, key, book and entity objects.", 40, true)
	local button = UI.button(parent, "Object ESP · Off")
	local doorButton = UI.button(parent, "Current room door ESP · Off")
	local keyButton = UI.button(parent, "Key ESP · Off")
	local alertButton = UI.button(parent, "Entity alerts · Off")
	local fullbrightButton = UI.button(parent, "Fullbright · Off")
	scope:connect(fullbrightButton.Activated, function()
		fullbrightEnabled = not fullbrightEnabled
		fullbrightButton.Text = fullbrightEnabled and "Fullbright · On" or "Fullbright · Off"
		if fullbrightEnabled then
			ambientBeforeFullbright = Lighting.Ambient
			Lighting.Ambient = fullbrightAmbient
		elseif ambientBeforeFullbright then
			Lighting.Ambient = ambientBeforeFullbright
			ambientBeforeFullbright = nil
		end
	end)
	scope:connect(Lighting:GetPropertyChangedSignal("Ambient"), function()
		if fullbrightEnabled and Lighting.Ambient ~= fullbrightAmbient then
			ambientBeforeFullbright = Lighting.Ambient
			Lighting.Ambient = fullbrightAmbient
		end
	end)
	local info = UI.label(parent, "Door and alerts: Off", 36, true)
	local function removeMarker(object)
		local record = tracked[object]
		if record then
			record.highlight:Destroy()
			record.billboard:Destroy()
			tracked[object] = nil
		end
	end
	local function mark(object, kind, label, color)
		if tracked[object] then return end
		local part = object:IsA("BasePart") and object or object:FindFirstChildWhichIsA("BasePart", true)
		if not part then return end
		local highlight = Instance.new("Highlight")
		highlight.Name = "NexusDoorsHighlight"
		highlight.Adornee = object
		highlight.FillColor = color
		highlight.FillTransparency = 0.55
		highlight.Parent = object
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NexusDoorsLabel"
		billboard.Adornee = part
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(160, 35)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = color
		text.TextStrokeTransparency = 0
		text.TextSize = 16
		text.Text = label
		text.Parent = billboard
		billboard.Parent = object
		tracked[object] = { kind = kind, highlight = highlight, billboard = billboard }
	end
	local function clearKind(kind)
		for object, record in pairs(tracked) do
			if record.kind == kind then removeMarker(object) end
		end
	end
	local function doorNumber(door)
		if not door then return nil end
		for _, descendant in ipairs(door:GetDescendants()) do
			if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and not descendant:FindFirstAncestor("NexusDoorsLabel") then
				local number = string.match(descendant.Text, "^%s*(%d+)%s*$")
				if number then return number end
			end
		end
		return nil
	end
	local function updateDoor()
		if not doorEnabled then return end
		local rooms = Workspace:FindFirstChild("CurrentRooms")
		local current = Players.LocalPlayer:GetAttribute("CurrentRoom")
		local gameData = ReplicatedStorage:FindFirstChild("GameData")
		local latest = gameData and gameData:FindFirstChild("LatestRoom")
		if type(current) ~= "number" and latest and latest:IsA("IntValue") then current = latest.Value end
		local room = rooms and type(current) == "number" and rooms:FindFirstChild(tostring(current))
		local door = room and room:FindFirstChild("Door")
		local number = doorNumber(door)
		for object, record in pairs(tracked) do
			if record.kind == "door" and (object ~= door or not number) then removeMarker(object) end
		end
		if door and number and (door:IsA("Model") or door:IsA("BasePart")) then
			mark(door, "door", "Door " .. number, Color3.fromRGB(85, 180, 255))
		elseif not alertsEnabled then
			info.Text = "Door: Current room exit not found"
		end
	end
	scope:connect(Players.LocalPlayer:GetAttributeChangedSignal("CurrentRoom"), updateDoor)
	scope:connect(doorButton.Activated, function()
		doorEnabled = not doorEnabled
		doorButton.Text = doorEnabled and "Current room door ESP · On" or "Current room door ESP · Off"
		if not doorEnabled then clearKind("door") end
		updateDoor()
	end)
	scope:connect(keyButton.Activated, function()
		keyEnabled = not keyEnabled
		keyButton.Text = keyEnabled and "Key ESP · On" or "Key ESP · Off"
		if not keyEnabled then clearKind("key") end
		scanElapsed = 1
	end)
	scope:connect(alertButton.Activated, function()
		alertsEnabled = not alertsEnabled
		alertButton.Text = alertsEnabled and "Entity alerts · On" or "Entity alerts · Off"
		table.clear(seenEntities)
		info.Text = alertsEnabled and "Entity alerts: Monitoring" or "Entity alerts: Off"
		scanElapsed = 1
	end)
	local diagnosticStatus = UI.label(parent, "Speed diagnostics: Waiting", 26, true)
	local saveDiagnostics = UI.button(parent, "Save speed diagnostics")
	local function saveSpeedDiagnostics()
		if type(writefile) ~= "function" then
			diagnosticStatus.Text = "Speed diagnostics: File writing unavailable"
			return
		end
		local ok = pcall(function()
			writefile("nexus-doors-speed-diagnostics.json", HttpService:JSONEncode({
				version = 1, samples = diagnosticSamples,
			}))
		end)
		diagnosticStatus.Text = ok and ("Speed diagnostics: Saved " .. #diagnosticSamples .. " samples") or "Speed diagnostics: Save failed"
	end
	scope:connect(saveDiagnostics.Activated, saveSpeedDiagnostics)
	local evadeButton = UI.button(parent, "Evade Rush / Ambush · Off")
	local undergroundButton = UI.button(parent, "Rush / Ambush underground · Off")
	local status = UI.label(parent, "Movement: Idle", 36, true)
	local function logHide(event, threat, root, humanoid)
		local position = root and root.Position
		table.insert(hideEvents, {
			time = os.clock(), event = event, threat = threat and threat.Name or nil,
			position = position and { x = position.X, y = position.Y, z = position.Z } or nil,
			destination = hideDestination and { x = hideDestination.Position.X, y = hideDestination.Position.Y, z = hideDestination.Position.Z } or nil,
			health = humanoid and humanoid.Health or nil, attempts = hideAttempts, confirmed = hideConfirmed,
		})
		if #hideEvents > 100 then table.remove(hideEvents, 1) end
		if type(writefile) == "function" then
			pcall(function() writefile("nexus-doors-hide-diagnostics.json", HttpService:JSONEncode({ version = 1, events = hideEvents })) end)
		end
	end
	local function returnFromUnderground()
		if hiddenRoot and hiddenRoot.Parent then
			hiddenRoot.Anchored = originalAnchored
		end
		hiddenRoot, originalAnchored = nil, nil
		if hideConfirmed and hiddenCharacter and hiddenCharacter == Players.LocalPlayer.Character and hiddenCharacter.Parent and returnPosition then
			local alive = hiddenCharacter:FindFirstChildOfClass("Humanoid")
			if alive and alive.Health > 0 then hiddenCharacter:PivotTo(returnPosition) end
		end
		if hidePlatform then hidePlatform:Destroy() end
		hidePlatform = nil
		hideDestination = nil
		hideAttempts = 0
		hideConfirmed = false
		hiddenCharacter = nil
		returnPosition = nil
		clearSince = nil
	end
	scope:connect(undergroundButton.Activated, function()
		undergroundEnabled = not undergroundEnabled
		undergroundButton.Text = undergroundEnabled and "Rush / Ambush underground · On" or "Rush / Ambush underground · Off"
		if not undergroundEnabled then
			returnFromUnderground()
			status.Text = "Movement: Idle"
		end
	end)
	local boostButton = UI.button(parent, "SpeedBoost · Off")
	local boostStatus = UI.label(parent, "SpeedBoost: Off", 26, true)
	local function restoreBoost()
		if boostedCharacter and boostedCharacter.Parent then
			boostedCharacter:SetAttribute("SpeedBoost", originalBoost)
		end
		boostedCharacter, originalBoost = nil, nil
	end
	local function applyBoost()
		local character = Players.LocalPlayer.Character
		if not character then boostStatus.Text = "SpeedBoost: Waiting for character"; return end
		if character ~= boostedCharacter then
			restoreBoost()
			boostedCharacter = character
			originalBoost = character:GetAttribute("SpeedBoost")
		end
		character:SetAttribute("SpeedBoost", boostValue)
		boostStatus.Text = "SpeedBoost: " .. tostring(boostValue) .. " · experimental"
	end
	local function disableBoost()
		if boostEnabled and #diagnosticSamples > 0 then saveSpeedDiagnostics() end
		boostEnabled = false
		boostButton.Text = "SpeedBoost · Off"
		boostStatus.Text = "SpeedBoost: Off"
		restoreBoost()
	end
	scope:connect(boostButton.Activated, function()
		if boostEnabled then disableBoost(); return end
		boostEnabled = true
		table.clear(diagnosticSamples)
		diagnosticPosition, diagnosticTime = nil, nil
		diagnosticElapsed, diagnosticSaveElapsed = 0, 0
		boostButton.Text = "SpeedBoost · On"
		applyBoost()
	end)
	Controls.valueSlider(parent, scope, "SpeedBoost", boostValue, 0, 8, function(value)
		boostValue = value
		if boostEnabled then applyBoost() end
	end)
	scope:connect(Players.LocalPlayer.CharacterAdded, function()
		if boostEnabled then applyBoost() end
	end)
	local noclipButton = UI.button(parent, "Noclip · Off")
	scope:connect(noclipButton.Activated, function()
		noclipEnabled = not noclipEnabled
		noclipButton.Text = noclipEnabled and "Noclip · On" or "Noclip · Off"
		if not noclipEnabled then collisions:restore() end
	end)
	scope:connect(RunService.Stepped, function()
		if noclipEnabled then collisions:apply(Players.LocalPlayer.Character) end
	end)
	local antiAfkButton = UI.button(parent, "Anti-AFK · Off")
	local antiAfkStatus = UI.label(parent, "Anti-AFK: Off", 26, true)
	scope:connect(antiAfkButton.Activated, function()
		antiAfkEnabled = not antiAfkEnabled
		antiAfkButton.Text = antiAfkEnabled and "Anti-AFK · On" or "Anti-AFK · Off"
		antiAfkStatus.Text = antiAfkEnabled and "Anti-AFK: Waiting for idle" or "Anti-AFK: Off"
	end)
	scope:connect(Players.LocalPlayer.Idled, function()
		if not antiAfkEnabled then return end
		local ok = pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
		antiAfkStatus.Text = ok and "Anti-AFK: Idle input sent" or "Anti-AFK: Input unavailable"
	end)
	local fovButton = UI.button(parent, "FOV · Off")
	local function applyFov()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		if savedFovs[camera] == nil then savedFovs[camera] = camera.FieldOfView end
		if camera.FieldOfView ~= fovValue then camera.FieldOfView = fovValue end
	end
	local function restoreFov()
		for camera, original in pairs(savedFovs) do
			if camera.Parent then camera.FieldOfView = original end
		end
		table.clear(savedFovs)
	end
	scope:connect(fovButton.Activated, function()
		fovEnabled = not fovEnabled
		fovButton.Text = fovEnabled and "FOV · On" or "FOV · Off"
		if fovEnabled then applyFov() else restoreFov() end
	end)
	Controls.valueSlider(parent, scope, "FOV", fovValue, 40, 120, function(value)
		fovValue = value
		if fovEnabled then applyFov() end
	end)
	scope:connect(RunService.RenderStepped, function()
		if fovEnabled then applyFov() end
	end)
	scope:connect(evadeButton.Activated, function()
		evadeEnabled = not evadeEnabled
		evadeButton.Text = evadeEnabled and "Evade Rush / Ambush · On" or "Evade Rush / Ambush · Off"
		status.Text = "Movement: Idle"
	end)
	local function clear()
		for object, highlight in pairs(highlights) do
			highlight:Destroy()
			highlights[object] = nil
		end
	end
	scope:connect(button.Activated, function()
		enabled = not enabled
		button.Text = enabled and "Object ESP · On" or "Object ESP · Off"
		if not enabled then clear() end
	end)
	scope:connect(RunService.Heartbeat, function(dt)
		doorScanElapsed += dt
		if doorEnabled and doorScanElapsed >= 0.1 then
			doorScanElapsed = 0
			updateDoor()
		end
		scanElapsed += dt
		if scanElapsed >= 0.5 then
			scanElapsed = 0
			local rooms = Workspace:FindFirstChild("CurrentRooms")
			for object, record in pairs(tracked) do
				if not object:IsDescendantOf(Workspace) then removeMarker(object) end
			end
			if keyEnabled and rooms then
				for _, object in ipairs(rooms:GetDescendants()) do
					if (object.Name == "KeyObtain" or object.Name == "ElectricalKeyObtain") and (object:IsA("Model") or object:IsA("BasePart")) then
						mark(object, "key", "Key", Color3.fromRGB(255, 215, 70))
					end
				end
			end
			if alertsEnabled then
				for entity in pairs(seenEntities) do
					if not entity:IsDescendantOf(Workspace) then seenEntities[entity] = nil end
				end
				for _, entity in ipairs(Workspace:GetDescendants()) do
					local name = entityNames[entity.Name]
					if name and (entity:IsA("Model") or entity:IsA("BasePart")) and not seenEntities[entity] then
						seenEntities[entity] = true
						info.Text = "Entity detected: " .. name
						pcall(function() StarterGui:SetCore("SendNotification", { Title = "DOORS", Text = name .. " detected", Duration = 5 }) end)
					end
				end
			end
		end
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if hiddenCharacter and (hiddenCharacter ~= character or not humanoid or humanoid.Health <= 0) then
			logHide("character_lost_or_dead", nil, character and character:FindFirstChild("HumanoidRootPart"), humanoid)
			returnFromUnderground()
		end
		if undergroundEnabled and character and humanoid and humanoid.Health > 0 then
			local threat = Workspace:FindFirstChild("RushMoving", true) or Workspace:FindFirstChild("AmbushMoving", true)
			local root = character:FindFirstChild("HumanoidRootPart")
			if threat then
				clearSince = nil
				if not hiddenCharacter and root and root:IsA("BasePart") then
					local destination = root.Position - Vector3.new(0, 25, 0)
					if destination.Y - 5 > Workspace.FallenPartsDestroyHeight then
						returnPosition = character:GetPivot()
						hideDestination = returnPosition - Vector3.new(0, 25, 0)
						hiddenCharacter = character
						hidePlatform = Instance.new("Part")
						hidePlatform.Name = "NexusHidePlatform"
						hidePlatform.Size = Vector3.new(12, 1, 12)
						hidePlatform.Anchored = true
						hidePlatform.Transparency = 1
						hidePlatform.CFrame = CFrame.new(destination - Vector3.new(0, 3.5, 0))
						hidePlatform.Parent = Workspace
						character:PivotTo(hideDestination)
						hiddenRoot = root
						originalAnchored = root.Anchored
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						root.Anchored = true
						hideAttempts = 1
						lastHideAttempt = os.clock()
						lastHideLog = lastHideAttempt
						logHide("attempt", threat, root, humanoid)
						status.Text = "Movement: Underground attempt; checking"
					else
						status.Text = "Movement: Underground position too low"
					end
				elseif hiddenCharacter and root and root:IsA("BasePart") and hideDestination and os.clock() - lastHideAttempt >= 0.75 then
					if (root.Position - hideDestination.Position).Magnitude > 12 then
						if hideConfirmed then
							hideConfirmed = false
							logHide("returned_from_underground", threat, root, humanoid)
						end
						if hideAttempts < 3 then
							character:PivotTo(hideDestination)
							hideAttempts += 1
							logHide("retry", threat, root, humanoid)
							status.Text = "Movement: Retrying underground"
						else
							status.Text = "Movement: Underground move rejected"
							if os.clock() - lastHideLog >= 3 then
								lastHideLog = os.clock()
								logHide("rejected", threat, root, humanoid)
							end
						end
					else
						if not hideConfirmed then logHide("locally_at_destination", threat, root, humanoid) end
						hideConfirmed = true
						status.Text = "Movement: Underground locally; server not verified"
					end
					lastHideAttempt = os.clock()
				end
			elseif hiddenCharacter then
				clearSince = clearSince or os.clock()
				if os.clock() - clearSince >= 3 then
					logHide("threat_cleared", nil, root, humanoid)
					returnFromUnderground()
					status.Text = "Movement: Returned to previous position"
				end
			end
		end
		if boostEnabled and character and humanoid then
			local root = character:FindFirstChild("HumanoidRootPart")
			diagnosticElapsed += dt
			diagnosticSaveElapsed += dt
			if root and root:IsA("BasePart") and diagnosticElapsed >= 0.1 then
				local now, position = os.clock(), root.Position
				local displacement = diagnosticPosition and position - diagnosticPosition or Vector3.zero
				local function vector(value) return { x = value.X, y = value.Y, z = value.Z } end
				local pingOk, ping = pcall(function() return Players.LocalPlayer:GetNetworkPing() end)
				local collisionPart = character:FindFirstChild("Collision")
				local crouching = character:GetAttribute("Crouching") == true
					or (collisionPart and collisionPart:IsA("BasePart") and collisionPart.CollisionGroup == "PlayerCrouching")
					or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				table.insert(diagnosticSamples, {
					mode = "boost", time = now, interval = diagnosticTime and now - diagnosticTime or 0,
					position = vector(position), displacement = vector(displacement), velocity = vector(root.AssemblyLinearVelocity),
					direction = vector(humanoid.MoveDirection), walkSpeed = humanoid.WalkSpeed,
					requestedBoost = boostValue, observedBoost = character:GetAttribute("SpeedBoost"),
					crouching = crouching and true or false, state = humanoid:GetState().Name,
					ping = pingOk and ping or nil, hidden = hiddenCharacter ~= nil,
				})
				if #diagnosticSamples > 300 then table.remove(diagnosticSamples, 1) end
				diagnosticPosition, diagnosticTime, diagnosticElapsed = position, now, 0
			end
			if diagnosticSaveElapsed >= 5 and #diagnosticSamples > 0 then
				diagnosticSaveElapsed = 0
				saveSpeedDiagnostics()
			end
		end
		if evadeEnabled and not hiddenCharacter and humanoid and character and os.clock() - lastEvade >= 0.5 then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local threat = Workspace:FindFirstChild("RushMoving", true) or Workspace:FindFirstChild("AmbushMoving", true)
				local position = threat and (threat:IsA("Model") and threat:GetPivot().Position or threat:IsA("BasePart") and threat.Position)
				if position and (root.Position - position).Magnitude < 80 then
					local direction = root.Position - position
					direction = Vector3.new(direction.X, 0, direction.Z)
					if direction.Magnitude > 0.1 then
						local destination = root.Position + direction.Unit * 12
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = { character }
						local ground = Workspace:Raycast(destination + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
						if ground and ground.Instance.CanCollide then
							humanoid:MoveTo(destination)
							status.Text = "Movement: Evading " .. threat.Name
						else
							status.Text = "Movement: No ground detected for evasion"
						end
					end
				else
					status.Text = "Movement: No nearby threat detected"
				end
				lastEvade = os.clock()
			end
		end
		if not enabled then return end
		elapsed += dt
		if elapsed < 1 then return end
		elapsed = 0
		for object, highlight in pairs(highlights) do
			if not object:IsDescendantOf(Workspace) then
				highlight:Destroy()
				highlights[object] = nil
			end
		end
		for _, object in ipairs(Workspace:GetDescendants()) do
			local color = names[object.Name]
			if color and (object:IsA("Model") or object:IsA("BasePart")) and not highlights[object] then
				local highlight = Instance.new("Highlight")
				highlight.Adornee = object
				highlight.FillColor = color
				highlight.FillTransparency = 0.6
				highlight.Parent = object
				highlights[object] = highlight
			end
		end
	end)
	scope:add(function()
		disableBoost()
		collisions:restore()
		restoreFov()
		if fullbrightEnabled then
			fullbrightEnabled = false
			if ambientBeforeFullbright then Lighting.Ambient = ambientBeforeFullbright end
		end
		if #diagnosticSamples > 0 then saveSpeedDiagnostics() end
		returnFromUnderground()
		clear()
		for object in pairs(tracked) do removeMarker(object) end
	end)
end

return table.freeze(Doors)

