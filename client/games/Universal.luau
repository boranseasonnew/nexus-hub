--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local UI = require(script.Parent.Parent.ui.Components)
local Controls = require(script.Parent.Parent.ui.Controls)
local Scope = require(script.Parent.Parent.core.Scope)

local LocalPlayer = Players.LocalPlayer

local Universal = {}

type ESPRecord = {
	highlight: Highlight?,
	billboard: BillboardGui?,
	label: TextLabel?,
}

local function createRow(parent: Instance): Frame
	local row = UI.make("Frame", parent, {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	})
	UI.make("UIListLayout", row, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	return row
end

local function setButtonState(button: TextButton, active: boolean, activeText: string?, inactiveText: string?)
	if active then
		button.BackgroundColor3 = UI.colors.indigo
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		if activeText then
			button.Text = activeText
		end
	else
		button.BackgroundColor3 = UI.colors.panel
		button.TextColor3 = UI.colors.text
		if inactiveText then
			button.Text = inactiveText
		end
	end
end

function Universal.mount(context)
	local parent = context.parent
	local scope = context.scope

	------------------------------------------------------------------------
	-- State
	------------------------------------------------------------------------
	local espEnabled = false
	local teamCheckEnabled = false
	local espRecords: { [Player]: ESPRecord } = {}
	local lastEspUpdate = 0

	local fullbrightEnabled = false
	local origBrightness = Lighting.Brightness
	local origClockTime = Lighting.ClockTime
	local origFogEnd = Lighting.FogEnd
	local origGlobalShadows = Lighting.GlobalShadows
	local origOutdoorAmbient = Lighting.OutdoorAmbient
	local origAmbient = Lighting.Ambient

	local speedEnabled = false
	local speedValue = 16

	local jumpEnabled = false
	local jumpValue = 50

	local infJumpEnabled = false
	local noclipEnabled = false

	local flyEnabled = false
	local flySpeedValue = 50
	local flyBV: BodyVelocity? = nil
	local flyBG: BodyGyro? = nil

	local selectedPlayer = "Select Player"
	local dropdownScope: any = nil

	------------------------------------------------------------------------
	-- Feature Implementations
	------------------------------------------------------------------------

	-- 1. Player ESP
	local function cleanupPlayerESP(player: Player)
		local record = espRecords[player]
		if record then
			if record.highlight then
				pcall(function() record.highlight:Destroy() end)
			end
			if record.billboard then
				pcall(function() record.billboard:Destroy() end)
			end
			espRecords[player] = nil
		end
	end

	local function applyPlayerESP(player: Player)
		if player == LocalPlayer then return end
		cleanupPlayerESP(player)

		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = character:FindFirstChild("Head") :: BasePart?
		if not hrp then return end

		local isSameTeam = teamCheckEnabled and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
		if isSameTeam then return end

		-- Highlight (green fill, white outline)
		local highlight = Instance.new("Highlight")
		highlight.Name = "NexusESP_Highlight"
		highlight.FillColor = Color3.fromRGB(46, 204, 113)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Adornee = character
		highlight.Parent = character

		-- BillboardGui (AlwaysOnTop, name + distance)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NexusESP_Billboard"
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.new(0, 160, 0, 36)
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
		billboard.Adornee = head or hrp

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 13
		label.TextWrapped = true
		label.Text = player.DisplayName .. "\n[-- studs]"
		label.Parent = billboard

		billboard.Parent = character

		espRecords[player] = {
			highlight = highlight,
			billboard = billboard,
			label = label,
		}
	end

	local function refreshAllESP()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				if espEnabled then
					applyPlayerESP(player)
				else
					cleanupPlayerESP(player)
				end
			end
		end
	end

	-- 2. Speed Hack
	local function updateSpeed()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = speedEnabled and speedValue or 16
		end
	end

	-- 3. Jump Power
	local function updateJump()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = jumpEnabled and jumpValue or 50
		end
	end

	-- 5. Noclip cleanup
	local function restoreCollisions()
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Head" then
						part.CanCollide = true
					end
				end
			end
		end
	end

	-- 6. Fly
	local function enableFly()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end

		if not flyBV or flyBV.Parent ~= hrp then
			if flyBV then flyBV:Destroy() end
			flyBV = Instance.new("BodyVelocity")
			flyBV.Name = "NexusFlyBV"
			flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
			flyBV.Velocity = Vector3.zero
			flyBV.Parent = hrp
		end

		if not flyBG or flyBG.Parent ~= hrp then
			if flyBG then flyBG:Destroy() end
			flyBG = Instance.new("BodyGyro")
			flyBG.Name = "NexusFlyBG"
			flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
			flyBG.P = 10000
			flyBG.CFrame = hrp.CFrame
			flyBG.Parent = hrp
		end

		hum.PlatformStand = true
	end

	local function disableFly()
		if flyBV then
			flyBV:Destroy()
			flyBV = nil
		end
		if flyBG then
			flyBG:Destroy()
			flyBG = nil
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
	end

	-- 7. Fullbright
	local function applyFullbright(enabled: boolean)
		if enabled then
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
			Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
			Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		else
			Lighting.Brightness = origBrightness
			Lighting.ClockTime = origClockTime
			Lighting.FogEnd = origFogEnd
			Lighting.GlobalShadows = origGlobalShadows
			Lighting.OutdoorAmbient = origOutdoorAmbient
			Lighting.Ambient = origAmbient
		end
	end

	-- 8. Teleport
	local function getPlayerChoices(): { string }
		local choices: { string } = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				table.insert(choices, player.Name)
			end
		end
		if #choices == 0 then
			table.insert(choices, "None")
		end
		return choices
	end

	local function executeTeleport()
		if selectedPlayer == "Select Player" or selectedPlayer == "None" then return end
		local target = Players:FindFirstChild(selectedPlayer)
		if target and target.Character then
			local targetHrp = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local localChar = LocalPlayer.Character
			local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetHrp and localHrp then
				localHrp.CFrame = targetHrp.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end

	------------------------------------------------------------------------
	-- UI Layout
	------------------------------------------------------------------------

	-- Section Header
	UI.label(parent, "Universal - Nexus Hub", 26, false)

	-- ==========================================
	-- -- Visuals --
	-- ==========================================
	local visualsHeader = UI.label(parent, "-- Visuals --", 22, true)
	visualsHeader.Font = Enum.Font.GothamBold

	-- [Player ESP] [On/Off] [Team Check On/Off]
	local espRow = createRow(parent)
	local espTitle = UI.label(espRow, "Player ESP", 32, false)
	espTitle.Size = UDim2.new(0.38, -4, 0, 32)

	local espToggleBtn = UI.button(espRow, "Off")
	espToggleBtn.Size = UDim2.new(0.28, -4, 0, 32)

	local teamToggleBtn = UI.button(espRow, "Team: Off")
	teamToggleBtn.Size = UDim2.new(0.34, -4, 0, 32)

	scope:connect(espToggleBtn.Activated, function()
		espEnabled = not espEnabled
		setButtonState(espToggleBtn, espEnabled, "On", "Off")
		refreshAllESP()
	end)

	scope:connect(teamToggleBtn.Activated, function()
		teamCheckEnabled = not teamCheckEnabled
		setButtonState(teamToggleBtn, teamCheckEnabled, "Team: On", "Team: Off")
		if espEnabled then
			refreshAllESP()
		end
	end)

	-- [Fullbright] [On/Off]
	local fbRow = createRow(parent)
	local fbTitle = UI.label(fbRow, "Fullbright", 32, false)
	fbTitle.Size = UDim2.new(0.65, -3, 0, 32)

	local fbToggleBtn = UI.button(fbRow, "Off")
	fbToggleBtn.Size = UDim2.new(0.35, -3, 0, 32)

	scope:connect(fbToggleBtn.Activated, function()
		fullbrightEnabled = not fullbrightEnabled
		setButtonState(fbToggleBtn, fullbrightEnabled, "On", "Off")
		applyFullbright(fullbrightEnabled)
	end)

	-- ==========================================
	-- -- Movement --
	-- ==========================================
	local movementHeader = UI.label(parent, "-- Movement --", 22, true)
	movementHeader.Font = Enum.Font.GothamBold

	-- [Speed] [On/Off] [Input: 16]
	local speedRow = createRow(parent)
	local speedTitle = UI.label(speedRow, "Speed", 32, false)
	speedTitle.Size = UDim2.new(0.38, -4, 0, 32)

	local speedToggleBtn = UI.button(speedRow, "Off")
	speedToggleBtn.Size = UDim2.new(0.28, -4, 0, 32)

	local speedInput = UI.input(speedRow, "16")
	speedInput.Size = UDim2.new(0.34, -4, 0, 32)
	speedInput.Text = "16"

	scope:connect(speedToggleBtn.Activated, function()
		speedEnabled = not speedEnabled
		setButtonState(speedToggleBtn, speedEnabled, "On", "Off")
		updateSpeed()
	end)

	scope:connect(speedInput:GetPropertyChangedSignal("Text"), function()
		local parsed = tonumber(speedInput.Text)
		if parsed and parsed > 0 then
			speedValue = parsed
			if speedEnabled then
				updateSpeed()
			end
		end
	end)

	-- [Jump Power] [On/Off] [Input: 50]
	local jumpRow = createRow(parent)
	local jumpTitle = UI.label(jumpRow, "Jump Power", 32, false)
	jumpTitle.Size = UDim2.new(0.38, -4, 0, 32)

	local jumpToggleBtn = UI.button(jumpRow, "Off")
	jumpToggleBtn.Size = UDim2.new(0.28, -4, 0, 32)

	local jumpInput = UI.input(jumpRow, "50")
	jumpInput.Size = UDim2.new(0.34, -4, 0, 32)
	jumpInput.Text = "50"

	scope:connect(jumpToggleBtn.Activated, function()
		jumpEnabled = not jumpEnabled
		setButtonState(jumpToggleBtn, jumpEnabled, "On", "Off")
		updateJump()
	end)

	scope:connect(jumpInput:GetPropertyChangedSignal("Text"), function()
		local parsed = tonumber(jumpInput.Text)
		if parsed and parsed > 0 then
			jumpValue = parsed
			if jumpEnabled then
				updateJump()
			end
		end
	end)

	-- [Infinite Jump] [On/Off]
	local infJumpRow = createRow(parent)
	local infJumpTitle = UI.label(infJumpRow, "Infinite Jump", 32, false)
	infJumpTitle.Size = UDim2.new(0.65, -3, 0, 32)

	local infJumpToggleBtn = UI.button(infJumpRow, "Off")
	infJumpToggleBtn.Size = UDim2.new(0.35, -3, 0, 32)

	scope:connect(infJumpToggleBtn.Activated, function()
		infJumpEnabled = not infJumpEnabled
		setButtonState(infJumpToggleBtn, infJumpEnabled, "On", "Off")
	end)

	-- [Noclip] [On/Off]
	local noclipRow = createRow(parent)
	local noclipTitle = UI.label(noclipRow, "Noclip", 32, false)
	noclipTitle.Size = UDim2.new(0.65, -3, 0, 32)

	local noclipToggleBtn = UI.button(noclipRow, "Off")
	noclipToggleBtn.Size = UDim2.new(0.35, -3, 0, 32)

	scope:connect(noclipToggleBtn.Activated, function()
		noclipEnabled = not noclipEnabled
		setButtonState(noclipToggleBtn, noclipEnabled, "On", "Off")
		if not noclipEnabled then
			restoreCollisions()
		end
	end)

	-- [Fly] [On/Off] [Input: 50]
	local flyRow = createRow(parent)
	local flyTitle = UI.label(flyRow, "Fly", 32, false)
	flyTitle.Size = UDim2.new(0.38, -4, 0, 32)

	local flyToggleBtn = UI.button(flyRow, "Off")
	flyToggleBtn.Size = UDim2.new(0.28, -4, 0, 32)

	local flyInput = UI.input(flyRow, "50")
	flyInput.Size = UDim2.new(0.34, -4, 0, 32)
	flyInput.Text = "50"

	scope:connect(flyToggleBtn.Activated, function()
		flyEnabled = not flyEnabled
		setButtonState(flyToggleBtn, flyEnabled, "On", "Off")
		if flyEnabled then
			enableFly()
		else
			disableFly()
		end
	end)

	scope:connect(flyInput:GetPropertyChangedSignal("Text"), function()
		local parsed = tonumber(flyInput.Text)
		if parsed and parsed > 0 then
			flySpeedValue = parsed
		end
	end)

	-- ==========================================
	-- -- Teleport --
	-- ==========================================
	local teleportHeader = UI.label(parent, "-- Teleport --", 22, true)
	teleportHeader.Font = Enum.Font.GothamBold

	-- Dropdown Container
	local dropdownContainer = UI.make("Frame", parent, {
		Size = UDim2.new(1, 0, 0, 32),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})

	local function renderDropdown()
		if dropdownScope then
			dropdownScope:close()
		end
		dropdownContainer:ClearAllChildren()
		dropdownScope = Scope.new()

		local choices = getPlayerChoices()
		if not table.find(choices, selectedPlayer) then
			selectedPlayer = choices[1] or "None"
		end

		Controls.dropdown(dropdownContainer, dropdownScope, "Target", selectedPlayer, choices, function(choice)
			selectedPlayer = choice
		end)
	end

	renderDropdown()

	-- Teleport + Refresh buttons row
	local tpActionRow = createRow(parent)
	local tpExecBtn = UI.button(tpActionRow, "Teleport to Player")
	tpExecBtn.Size = UDim2.new(0.72, -3, 0, 32)

	local tpRefreshBtn = UI.button(tpActionRow, "Refresh")
	tpRefreshBtn.Size = UDim2.new(0.28, -3, 0, 32)

	scope:connect(tpExecBtn.Activated, executeTeleport)
	scope:connect(tpRefreshBtn.Activated, renderDropdown)

	------------------------------------------------------------------------
	-- Runtime Connections & Handlers
	------------------------------------------------------------------------

	-- Infinite Jump
	scope:connect(UserInputService.JumpRequest, function()
		if not infJumpEnabled then return end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)

	-- Noclip loop on Stepped
	scope:connect(RunService.Stepped, function()
		if not noclipEnabled then return end
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end)

	-- Speed & Jump Power enforcement loop on Heartbeat
	scope:connect(RunService.Heartbeat, function()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		if speedEnabled and hum.WalkSpeed ~= speedValue then
			hum.WalkSpeed = speedValue
		end

		if jumpEnabled and hum.JumpPower ~= jumpValue then
			hum.UseJumpPower = true
			hum.JumpPower = jumpValue
		end
	end)

	-- Fly movement loop on RenderStepped
	scope:connect(RunService.RenderStepped, function()
		if not flyEnabled or not flyBV or not flyBG then return end
		local cam = workspace.CurrentCamera
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not cam or not hrp or not hum or hum.Health <= 0 then return end

		flyBG.CFrame = cam.CFrame

		local moveDir = hum.MoveDirection
		local velocity = Vector3.zero

		if moveDir.Magnitude > 0 then
			local camLook = cam.CFrame.LookVector
			local camRight = cam.CFrame.RightVector
			local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
			local flatRight = Vector3.new(camRight.X, 0, camRight.Z)
			if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit end
			if flatRight.Magnitude > 0.001 then flatRight = flatRight.Unit end

			local forwardDot = moveDir:Dot(flatLook)
			local rightDot = moveDir:Dot(flatRight)

			local flightDir = (camLook * forwardDot + camRight * rightDot)
			if flightDir.Magnitude > 0.001 then
				velocity = flightDir.Unit * flySpeedValue
			end
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			velocity = velocity + Vector3.new(0, flySpeedValue * 0.75, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			velocity = velocity - Vector3.new(0, flySpeedValue * 0.75, 0)
		end

		flyBV.Velocity = velocity
	end)

	-- ESP distance updater (0.5s throttle)
	scope:connect(RunService.Heartbeat, function()
		if not espEnabled then return end
		local now = os.clock()
		if now - lastEspUpdate < 0.5 then return end
		lastEspUpdate = now

		local localChar = LocalPlayer.Character
		local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart") :: BasePart?

		for player, record in pairs(espRecords) do
			if not player.Parent then
				cleanupPlayerESP(player)
			else
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local head = char and char:FindFirstChild("Head") :: BasePart?
				local isSameTeam = teamCheckEnabled and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team

				if isSameTeam or not char or not hrp then
					if record.highlight then record.highlight.Enabled = false end
					if record.billboard then record.billboard.Enabled = false end
				else
					if record.highlight then
						record.highlight.Enabled = true
						if record.highlight.Adornee ~= char then
							record.highlight.Adornee = char
						end
					end
					if record.billboard then
						record.billboard.Enabled = true
						local targetPart = head or hrp
						if record.billboard.Adornee ~= targetPart then
							record.billboard.Adornee = targetPart
						end
					end
					if localHrp and record.label then
						local dist = (localHrp.Position - hrp.Position).Magnitude
						record.label.Text = string.format("%s\n[%d studs]", player.DisplayName, math.floor(dist))
					end
				end
			end
		end
	end)

	-- Handle player join/leave & respawn for ESP and Teleport
	scope:connect(Players.PlayerAdded, function(p)
		renderDropdown()
		p.CharacterAdded:Connect(function()
			if espEnabled then
				task.wait(0.2)
				applyPlayerESP(p)
			end
		end)
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			scope:connect(p.CharacterAdded, function()
				if espEnabled then
					task.wait(0.2)
					applyPlayerESP(p)
				end
			end)
		end
	end

	scope:connect(Players.PlayerRemoving, function(p)
		cleanupPlayerESP(p)
		renderDropdown()
	end)

	-- Character respawn handler for LocalPlayer
	scope:connect(LocalPlayer.CharacterAdded, function(newChar)
		local hrp = newChar:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		local hum = newChar:WaitForChild("Humanoid", 5) :: Humanoid?
		if not hrp or not hum then return end

		if flyEnabled then
			task.wait(0.2)
			enableFly()
		end
		if speedEnabled then
			hum.WalkSpeed = speedValue
		end
		if jumpEnabled then
			hum.UseJumpPower = true
			hum.JumpPower = jumpValue
		end
	end)

	-- Fullbright lighting enforcement
	scope:connect(Lighting.Changed, function()
		if fullbrightEnabled then
			if Lighting.Brightness ~= 2 or Lighting.ClockTime ~= 14 or Lighting.GlobalShadows ~= false then
				applyFullbright(true)
			end
		end
	end)

	------------------------------------------------------------------------
	-- Complete Cleanup on Unmount
	------------------------------------------------------------------------
	scope:add(function()
		-- Reset Visuals
		espEnabled = false
		for player, _ in pairs(espRecords) do
			cleanupPlayerESP(player)
		end
		table.clear(espRecords)

		if fullbrightEnabled then
			applyFullbright(false)
		end

		-- Reset Movement
		speedEnabled = false
		updateSpeed()

		jumpEnabled = false
		updateJump()

		infJumpEnabled = false

		if noclipEnabled then
			noclipEnabled = false
			restoreCollisions()
		end

		if flyEnabled then
			flyEnabled = false
			disableFly()
		end

		-- Close dropdown
		if dropdownScope then
			dropdownScope:close()
			dropdownScope = nil
		end
	end)
end

return table.freeze(Universal)

