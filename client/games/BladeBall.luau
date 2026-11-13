--!strict
-- Nexus Hub: Blade Ball Game Module
-- Comprehensive combat automation, threat detection, ESP overlays, and real-time status diagnostics.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.Parent.ui.Components)
local Controls = require(script.Parent.Parent.ui.Controls)
local BallTracker = require(script.Parent.logic.BallTracker)

local BladeBall = {}

-- Module context types
export type MountContext = {
	parent: Frame,
	scope: any,
	settings: any,
}

-- ESP tracking data types
type BallEspData = {
	highlight: Highlight?,
	billboard: BillboardGui?,
	label: TextLabel?,
	ball: BasePart?,
}

type PlayerEspEntry = {
	highlight: Highlight?,
	billboard: BillboardGui?,
	label: TextLabel?,
}

-- Active runtime configuration state
type BladeBallState = {
	autoParry: boolean,
	sensitivity: string,
	autoSpam: boolean,
	manualSpam: boolean,
	manualSpamKey: Enum.KeyCode,
	manualSpamKeyName: string,
	antiCurve: boolean,
	antiFreeze: boolean,
	antiPulse: boolean,
	ballEsp: boolean,
	playerEsp: boolean,
}

function BladeBall.mount(context: MountContext)
	local parent = context.parent
	local scope = context.scope
	local settings = context.settings
	local localPlayer = Players.LocalPlayer

	-- Module state table
	local state: BladeBallState = {
		autoParry = false,
		sensitivity = "Standard",
		autoSpam = false,
		manualSpam = false,
		manualSpamKey = Enum.KeyCode.E,
		manualSpamKeyName = "E",
		antiCurve = false,
		antiFreeze = false,
		antiPulse = false,
		ballEsp = false,
		playerEsp = false,
	}

	-- Runtime telemetry and rate limiting
	local activeBall: BasePart? = nil
	local sampledBall: BasePart? = nil
	local sampledPosition: Vector3? = nil
	local estimatedBallVelocity: Vector3? = nil
	local sampledTime = 0
	local nextBallScan = 0
	local pingSeconds = 0
	local lastPingSample = 0
	local extraLeadSeconds = 0.08
	local lastDispatchReason = "None"
	local lastDispatchTime = 0
	local lastAttemptTime = 0
	local parryRemote: RemoteEvent? = nil
	local executorEnv = type(getgenv) == "function" and getgenv() or _G
	local pressKey = executorEnv and executorEnv.keypress
	local releaseKey = executorEnv and executorEnv.keyrelease
	local canSimulateParry = type(pressKey) == "function" and type(releaseKey) == "function"
	local virtualInput = nil
	pcall(function() virtualInput = game:GetService("VirtualInputManager") end)
	local nextRemoteScan: number = 0
	local lastParryTime: number = 0
	local lastAutoSpamTime: number = 0
	local lastManualSpamTime: number = 0
	local isHoldingManualSpam: boolean = false

	local prevBallVelocity: Vector3 = Vector3.zero
	local prevBallSpeed: number = 0
	local lastSpeedSampleTime: number = 0
	local ballFrozenSince: number? = nil

	local curveWarningUntil: number = 0
	local freezeWarningUntil: number = 0
	local pulseWarningUntil: number = 0

	local parryStatusText: string = "Ready"
	local parryStatusColor: Color3 = UI.colors.indigo

	-- ESP object tracking tables
	local ballEspData: BallEspData = {
		highlight = nil,
		billboard = nil,
		label = nil,
		ball = nil,
	}
	local playerEspEntries: { [Player]: PlayerEspEntry } = {}

	----------------------------------------------------------------------
	-- Remote Resolution & Dispatch
	----------------------------------------------------------------------
	local function resolveParryRemote(): RemoteEvent?
		if parryRemote and parryRemote.Parent and parryRemote:IsDescendantOf(game) then
			return parryRemote
		end
		if os.clock() < nextRemoteScan then return nil end
		nextRemoteScan = os.clock() + 1
		parryRemote = BallTracker.findParryRemote(ReplicatedStorage)
		return parryRemote
	end

	local function fireParry(reason: string)
		lastAttemptTime = os.clock()
		if canSimulateParry then
			local ok, result = pcall(pressKey, 0x46)
			if ok and result ~= false then
				task.delay(0.03, function() pcall(releaseKey, 0x46) end)
				lastParryTime = os.clock()
				lastDispatchTime = lastParryTime
				lastDispatchReason = reason .. " (keypress)"
				parryStatusText = "Input sent (" .. reason .. ")"
				parryStatusColor = UI.colors.indigo
				return
			end
			canSimulateParry = false
		end
		if virtualInput then
			local ok = pcall(function() virtualInput:SendKeyEvent(true, Enum.KeyCode.F, false, game) end)
			if ok then
				task.delay(0.05, function() pcall(function() virtualInput:SendKeyEvent(false, Enum.KeyCode.F, false, game) end) end)
				lastParryTime = os.clock()
				lastDispatchTime = lastParryTime
				lastDispatchReason = reason .. " (virtual input)"
				return
			end
			virtualInput = nil
		end
		local remote = resolveParryRemote()
		if not remote then
			parryStatusText = "No usable parry input or remote"
			parryStatusColor = Color3.fromRGB(255, 95, 95)
			return
		end

		local ok = pcall(function()
			remote:FireServer(0.5, CFrame.new(), {}, { 0, 0 })
		end)
		if not ok then
			parryStatusText = "Dispatch failed"
			parryStatusColor = Color3.fromRGB(255, 95, 95)
			return
		end
		lastParryTime = os.clock()
		lastDispatchTime = lastParryTime
		lastDispatchReason = reason
		parryStatusText = "Sent (" .. reason .. ")"
		parryStatusColor = Color3.fromRGB(100, 255, 120)

		task.delay(0.18, function()
			if not scope.closed and os.clock() - lastParryTime < 0.3 then
				parryStatusText = "Cooldown"
				parryStatusColor = Color3.fromRGB(255, 180, 80)
			end
		end)
	end

	----------------------------------------------------------------------
	-- Ball ESP Subsystem
	----------------------------------------------------------------------
	local function cleanupBallESP()
		if ballEspData.highlight then
			pcall(function()
				ballEspData.highlight:Destroy()
			end)
			ballEspData.highlight = nil
		end
		if ballEspData.billboard then
			pcall(function()
				ballEspData.billboard:Destroy()
			end)
			ballEspData.billboard = nil
		end
		ballEspData.label = nil
		ballEspData.ball = nil
	end

	local function updateBallESP(ball: BasePart, targetName: string, distance: number, speed: number, tti: number)
		if not ball or not ball.Parent or not ball:IsDescendantOf(Workspace) then
			cleanupBallESP()
			return
		end

		if ballEspData.ball ~= ball or not ballEspData.highlight or not ballEspData.billboard then
			cleanupBallESP()
			ballEspData.ball = ball

			local hl = Instance.new("Highlight")
			hl.Name = "Nexus_BallHighlight"
			hl.FillColor = Color3.fromRGB(255, 230, 0)
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 0.45
			hl.OutlineTransparency = 0
			hl.Adornee = ball
			hl.Parent = ball
			ballEspData.highlight = hl

			local bb = Instance.new("BillboardGui")
			bb.Name = "Nexus_BallBillboard"
			bb.Adornee = ball
			bb.Size = UDim2.fromOffset(160, 68)
			bb.StudsOffset = Vector3.new(0, 3.8, 0)
			bb.AlwaysOnTop = true
			bb.ResetOnSpawn = false

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 1, 0)
			frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
			frame.BackgroundTransparency = 0.2
			frame.BorderSizePixel = 0
			frame.Parent = bb
			UI.round(frame, 6)

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 230, 0)
			stroke.Thickness = 1.2
			stroke.Parent = frame

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -8, 1, -8)
			lbl.Position = UDim2.fromOffset(4, 4)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 11
			lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			lbl.TextXAlignment = Enum.TextXAlignment.Center
			lbl.TextYAlignment = Enum.TextYAlignment.Center
			lbl.Parent = frame

			ballEspData.label = lbl
			bb.Parent = ball
			ballEspData.billboard = bb
		end

		if ballEspData.label then
			local ttiDisplay = tti >= 99 and "Inf" or string.format("%.2fs", tti)
			ballEspData.label.Text = string.format(
				"Target: %s\nDist: %.1f studs\nSpeed: %.1f\nTTI: %s",
				targetName ~= "" and targetName or "None",
				distance,
				speed,
				ttiDisplay
			)
		end
	end

	----------------------------------------------------------------------
	-- Player ESP Subsystem
	----------------------------------------------------------------------
	local function cleanupPlayerESP(player: Player)
		local entry = playerEspEntries[player]
		if entry then
			if entry.highlight then
				pcall(function()
					entry.highlight:Destroy()
				end)
			end
			if entry.billboard then
				pcall(function()
					entry.billboard:Destroy()
				end)
			end
			playerEspEntries[player] = nil
		end
	end

	local function cleanupAllPlayerESP()
		for player, _ in pairs(playerEspEntries) do
			cleanupPlayerESP(player)
		end
		table.clear(playerEspEntries)
	end

	local function updatePlayerESP(player: Player, localPlayerPos: Vector3)
		if player == localPlayer then
			return
		end

		local char = player.Character
		if not char or not char:IsDescendantOf(Workspace) then
			cleanupPlayerESP(player)
			return
		end

		local root = char:FindFirstChild("HumanoidRootPart")
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			cleanupPlayerESP(player)
			return
		end

		local entry = playerEspEntries[player]
		if not entry or not entry.highlight or not entry.billboard or entry.highlight.Adornee ~= char then
			cleanupPlayerESP(player)

			local hl = Instance.new("Highlight")
			hl.Name = "Nexus_PlayerHighlight"
			hl.FillColor = Color3.fromRGB(50, 205, 50)
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 0.5
			hl.OutlineTransparency = 0
			hl.Adornee = char
			hl.Parent = char

			local bb = Instance.new("BillboardGui")
			bb.Name = "Nexus_PlayerBillboard"
			bb.Adornee = root
			bb.Size = UDim2.fromOffset(130, 36)
			bb.StudsOffset = Vector3.new(0, 3.2, 0)
			bb.AlwaysOnTop = true
			bb.ResetOnSpawn = false

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 1, 0)
			frame.BackgroundColor3 = Color3.fromRGB(20, 28, 22)
			frame.BackgroundTransparency = 0.3
			frame.BorderSizePixel = 0
			frame.Parent = bb
			UI.round(frame, 6)

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(50, 205, 50)
			stroke.Thickness = 1
			stroke.Parent = frame

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -6, 1, -4)
			lbl.Position = UDim2.fromOffset(3, 2)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 11
			lbl.TextColor3 = Color3.fromRGB(240, 241, 249)
			lbl.TextXAlignment = Enum.TextXAlignment.Center
			lbl.TextYAlignment = Enum.TextYAlignment.Center
			lbl.Parent = frame

			bb.Parent = char
			entry = {
				highlight = hl,
				billboard = bb,
				label = lbl,
			}
			playerEspEntries[player] = entry
		end

		if entry and entry.label and root:IsA("BasePart") then
			local distance = (root.Position - localPlayerPos).Magnitude
			local displayName = player.DisplayName
			if not displayName or displayName == "" then
				displayName = player.Name
			end
			entry.label.Text = string.format("%s\n[%.0f studs]", displayName, distance)
		end
	end

	----------------------------------------------------------------------
	-- UI Component Constructors
	----------------------------------------------------------------------
	local function createSectionHeader(headerText: string)
		local header = UI.make("TextLabel", parent, {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = headerText,
			TextColor3 = UI.colors.indigo,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		return header
	end

	local function createToggleRow(labelText: string, initial: boolean, onToggle: (boolean) -> ())
		local row = UI.make("Frame", parent, {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = UI.colors.panel,
			BackgroundTransparency = 0,
		})
		UI.round(row, 6)

		local title = UI.make("TextLabel", row, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -84, 1, 0),
			BackgroundTransparency = 1,
			Text = labelText,
			TextColor3 = UI.colors.text,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})

		local button = UI.button(row, initial and "ON" or "OFF", 60)
		button.Position = UDim2.new(1, -68, 0, 4)
		button.Size = UDim2.fromOffset(60, 28)
		button.BackgroundColor3 = initial and UI.colors.indigo or UI.colors.surface
		button.TextColor3 = initial and Color3.fromRGB(255, 255, 255) or UI.colors.muted

		local isEnabled = initial
		local function updateUI()
			button.Text = isEnabled and "ON" or "OFF"
			button.BackgroundColor3 = isEnabled and UI.colors.indigo or UI.colors.surface
			button.TextColor3 = isEnabled and Color3.fromRGB(255, 255, 255) or UI.colors.muted
		end

		scope:connect(button.Activated, function()
			isEnabled = not isEnabled
			updateUI()
			onToggle(isEnabled)
		end)

		return {
			set = function(val: boolean)
				isEnabled = val
				updateUI()
				onToggle(isEnabled)
			end,
			get = function(): boolean
				return isEnabled
			end,
		}
	end

	local function createKeyInputRow(labelText: string, defaultKey: string, onKeyChanged: (Enum.KeyCode, string) -> ())
		local row = UI.make("Frame", parent, {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = UI.colors.panel,
			BackgroundTransparency = 0,
		})
		UI.round(row, 6)

		local title = UI.make("TextLabel", row, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -84, 1, 0),
			BackgroundTransparency = 1,
			Text = labelText,
			TextColor3 = UI.colors.text,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})

		local box = UI.input(row, defaultKey)
		box.Position = UDim2.new(1, -68, 0, 4)
		box.Size = UDim2.fromOffset(60, 28)
		box.Text = defaultKey
		box.TextXAlignment = Enum.TextXAlignment.Center

		scope:connect(box.FocusLost, function()
			local raw = string.match(box.Text, "^%s*(.-)%s*$") or ""
			if raw == "" then
				box.Text = state.manualSpamKeyName
				return
			end
			for _, code in ipairs(Enum.KeyCode:GetEnumItems()) do
				if code ~= Enum.KeyCode.Unknown and string.lower(code.Name) == string.lower(raw) then
					box.Text = code.Name
					onKeyChanged(code, code.Name)
					return
				end
			end
			box.Text = state.manualSpamKeyName
		end)
	end

	local function createStatusPanel()
		local card = UI.make("Frame", parent, {
			Size = UDim2.new(1, 0, 0, 154),
			BackgroundColor3 = UI.colors.panel,
			BackgroundTransparency = 0,
		})
		UI.round(card, 8)

		local layout = UI.make("UIListLayout", card, {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local padding = UI.make("UIPadding", card, {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		})

		local targetLabel = UI.make("TextLabel", card, {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "Ball Target: None",
			TextColor3 = UI.colors.text,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		})

		local distanceLabel = UI.make("TextLabel", card, {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "Distance: 0.0 studs",
			TextColor3 = UI.colors.text,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		})

		local speedLabel = UI.make("TextLabel", card, {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "Ball Speed: 0.0 studs/s",
			TextColor3 = UI.colors.text,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 3,
		})

		local ttiLabel = UI.make("TextLabel", card, {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "Time to Impact: 0.00s",
			TextColor3 = UI.colors.text,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 4,
		})

		local parryLabel = UI.make("TextLabel", card, {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "Parry Status: Ready",
			TextColor3 = UI.colors.indigo,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 5,
		})

		local warningLabel = UI.make("TextLabel", card, {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "Threat Status: Normal",
			TextColor3 = UI.colors.muted,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 6,
		})

		return {
			setTarget = function(name: string, isMe: boolean)
				if isMe then
					targetLabel.Text = "Ball Target: " .. name .. " [TARGETING YOU]"
					targetLabel.TextColor3 = Color3.fromRGB(255, 95, 95)
				else
					targetLabel.Text = "Ball Target: " .. (name ~= "" and name or "None")
					targetLabel.TextColor3 = UI.colors.text
				end
			end,
			setDistance = function(dist: number)
				distanceLabel.Text = string.format("Distance: %.1f studs", dist)
			end,
			setSpeed = function(spd: number)
				speedLabel.Text = string.format("Ball Speed: %.1f studs/s", spd)
			end,
			setTTI = function(tti: number)
				if tti >= 99 then
					ttiLabel.Text = "Time to Impact: Inf"
				else
					ttiLabel.Text = string.format("Time to Impact: %.2fs", tti)
				end
			end,
			setParryStatus = function(txt: string, col: Color3)
				parryLabel.Text = "Parry Status: " .. txt
				parryLabel.TextColor3 = col
			end,
			setWarnings = function(warnings: { string })
				if #warnings > 0 then
					warningLabel.Text = "Threat Status: " .. table.concat(warnings, " | ")
					warningLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
				else
					warningLabel.Text = "Threat Status: Normal"
					warningLabel.TextColor3 = UI.colors.muted
				end
			end,
		}
	end

	----------------------------------------------------------------------
	-- Construct Full User Interface
	----------------------------------------------------------------------
	local title = UI.label(parent, "Blade Ball - Nexus Hub", 26, false)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16

	-- Combat Section
	createSectionHeader("-- Combat --")

	createToggleRow("Auto Parry", state.autoParry, function(enabled)
		state.autoParry = enabled
	end)

	Controls.dropdown(parent, scope, "Sensitivity", state.sensitivity, {
		"Relaxed",
		"Standard",
		"Precision",
		"Instant",
	}, function(choice)
		state.sensitivity = choice
	end)
	local timingInput = UI.input(parent, "Extra lead time in milliseconds (0–500)")
	timingInput.Text = "80"
	scope:connect(timingInput.FocusLost, function()
		local milliseconds = tonumber(timingInput.Text)
		if milliseconds and milliseconds == milliseconds then
			extraLeadSeconds = math.clamp(milliseconds, 0, 500) / 1000
		end
		timingInput.Text = tostring(math.floor(extraLeadSeconds * 1000 + 0.5))
	end)
	local inputTestButton = UI.button(parent, "Test parry input (F)")
	scope:connect(inputTestButton.Activated, function() fireParry("Input test") end)

	createToggleRow("Auto Spam (<15 studs)", state.autoSpam, function(enabled)
		state.autoSpam = enabled
	end)

	createToggleRow("Manual Spam (Hold)", state.manualSpam, function(enabled)
		state.manualSpam = enabled
		if not enabled then
			isHoldingManualSpam = false
		end
	end)

	createKeyInputRow("Spam Key", state.manualSpamKeyName, function(keyCode, keyName)
		state.manualSpamKey = keyCode
		state.manualSpamKeyName = keyName
	end)

	-- Protection Section
	createSectionHeader("-- Protection --")

	createToggleRow("Anti Curve", state.antiCurve, function(enabled)
		state.antiCurve = enabled
	end)

	createToggleRow("Anti Freeze Ball", state.antiFreeze, function(enabled)
		state.antiFreeze = enabled
	end)

	createToggleRow("Anti Pulse", state.antiPulse, function(enabled)
		state.antiPulse = enabled
	end)

	-- Visuals Section
	createSectionHeader("-- Visuals --")

	createToggleRow("Ball ESP", state.ballEsp, function(enabled)
		state.ballEsp = enabled
		if not enabled then
			cleanupBallESP()
		end
	end)

	createToggleRow("Player ESP", state.playerEsp, function(enabled)
		state.playerEsp = enabled
		if not enabled then
			cleanupAllPlayerESP()
		end
	end)

	-- Status Section
	createSectionHeader("-- Status --")
	local statusDisplay = createStatusPanel()

	----------------------------------------------------------------------
	-- Key Listeners for Manual Spam
	----------------------------------------------------------------------
	scope:connect(UserInputService.InputBegan, function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == state.manualSpamKey then
			isHoldingManualSpam = true
		end
	end)

	scope:connect(UserInputService.InputEnded, function(input)
		if input.KeyCode == state.manualSpamKey then
			isHoldingManualSpam = false
		end
	end)

	scope:connect(UserInputService.WindowFocusReleased, function()
		isHoldingManualSpam = false
	end)

	----------------------------------------------------------------------
	-- Player Lifecycle Connections
	----------------------------------------------------------------------
	scope:connect(Players.PlayerRemoving, function(leavingPlayer)
		cleanupPlayerESP(leavingPlayer)
	end)

	----------------------------------------------------------------------
	-- Core Runtime Loop (RenderStepped)
	----------------------------------------------------------------------
	local function onRenderStep(deltaTime: number)
		local now = os.clock()

		-- Resolve LocalPlayer character root part
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then
			statusDisplay.setTarget("No Character", false)
			statusDisplay.setDistance(0)
			statusDisplay.setSpeed(0)
			statusDisplay.setTTI(99)
			statusDisplay.setParryStatus("Waiting for Character", UI.colors.muted)
			statusDisplay.setWarnings({})
			return
		end

		local playerPos = rootPart.Position
		if state.manualSpam and isHoldingManualSpam and now - lastManualSpamTime >= 0.05 then
			lastManualSpamTime = now
			fireParry("Manual Spam")
		end

		-- Resolve and cache active Blade Ball instance
		if activeBall and (not activeBall.Parent or not activeBall:IsDescendantOf(Workspace) or activeBall:GetAttribute("realBall") == false) then
			activeBall = nil
			nextBallScan = 0
		end
		if now >= nextBallScan then
			activeBall = BallTracker.findBall(Workspace)
			nextBallScan = now + 0.12
		end

		-- Fallback when no active ball exists in match
		if not activeBall or not activeBall:IsA("BasePart") then
			sampledBall = nil
			sampledPosition = nil
			estimatedBallVelocity = nil
			cleanupBallESP()
			prevBallVelocity = Vector3.zero
			ballFrozenSince = nil

			if state.playerEsp then
				for _, player in ipairs(Players:GetPlayers()) do
					updatePlayerESP(player, playerPos)
				end
			end

			local remote = resolveParryRemote()
			local statusText = canSimulateParry and "Keypress available; waiting for ball" or virtualInput and "Virtual input untested; waiting for ball" or remote and "Remote found; waiting for ball" or "Parry input unavailable"
			local statusColor = (remote or canSimulateParry or virtualInput) and UI.colors.indigo or Color3.fromRGB(255, 95, 95)
			if lastDispatchTime > 0 and now - lastDispatchTime < 2 then statusText = "Sent: " .. lastDispatchReason end
			if lastAttemptTime > lastDispatchTime and now - lastAttemptTime < 2 then statusText = parryStatusText; statusColor = parryStatusColor end

			statusDisplay.setTarget("None", false)
			statusDisplay.setDistance(0)
			statusDisplay.setSpeed(0)
			statusDisplay.setTTI(99)
			statusDisplay.setParryStatus(statusText, statusColor)
			statusDisplay.setWarnings({})
			return
		end

		-- Read physical properties
		local ballPos = activeBall.Position
		local ballVel = activeBall.AssemblyLinearVelocity
		if sampledBall ~= activeBall then
			sampledBall = activeBall
			sampledPosition = ballPos
			sampledTime = now
			estimatedBallVelocity = nil
		elseif sampledPosition and now > sampledTime then
			local interval = now - sampledTime
			if interval >= 0.02 then
				estimatedBallVelocity = interval <= 0.2 and (ballPos - sampledPosition) / interval or nil
				sampledPosition = ballPos
				sampledTime = now
			end
		end
		if ballVel.Magnitude < 1 and estimatedBallVelocity then ballVel = estimatedBallVelocity end
		local speedMagnitude = ballVel.Magnitude

		-- Read target attribute / values
		local targetAttr = activeBall:GetAttribute("Target") or activeBall:GetAttribute("target")
		if not targetAttr then
			local targetChild = activeBall:FindFirstChild("Target") or activeBall:FindFirstChild("target")
			if targetChild and (targetChild:IsA("StringValue") or targetChild:IsA("ObjectValue")) then
				local val = targetChild.Value
				targetAttr = typeof(val) == "Instance" and val.Name or tostring(val)
			end
		end

		local targetName = typeof(targetAttr) == "string" and targetAttr or typeof(targetAttr) == "number" and tostring(targetAttr) or ""
		local isTargetMe, displayedTarget = BallTracker.isLocalTarget(targetName, localPlayer.Name, localPlayer.UserId, character)
		targetName = displayedTarget

		-- Compute trajectory physics
		local contactRadius = math.clamp(activeBall.Size.Magnitude * 0.5 + rootPart.Size.Magnitude * 0.5, 2, 8)
		local tti, distance, speed = BallTracker.timeToImpact(ballPos, ballVel, playerPos, rootPart.AssemblyLinearVelocity, contactRadius)
		if now - lastPingSample >= 1 then
			lastPingSample = now
			local ok, ping = pcall(function() return localPlayer:GetNetworkPing() end)
			if ok and type(ping) == "number" and ping == ping then pingSeconds = math.clamp(ping, 0, 0.5) end
		end

		-- Anti-Curve detection
		local isCurvingNow = false
		if prevBallVelocity.Magnitude > 1 and speedMagnitude > 1 then
			if BallTracker.isCurving(prevBallVelocity, ballVel, 0.85) then
				isCurvingNow = true
				curveWarningUntil = now + 0.35
			end
		end
		prevBallVelocity = ballVel
		local curveActive = (now < curveWarningUntil)

		-- Anti-Freeze detection
		local freezeActive = false
		if speedMagnitude < 0.5 and targetName ~= "" then
			if not ballFrozenSince then
				ballFrozenSince = now
			end
			if now - ballFrozenSince >= 0.1 then
				freezeActive = true
				freezeWarningUntil = now + 0.45
				if state.antiFreeze and isTargetMe and (now - lastParryTime >= 0.25) then
					fireParry("Anti Freeze")
				end
			end
		else
			ballFrozenSince = nil
		end
		if now < freezeWarningUntil then
			freezeActive = true
		end

		-- Anti-Pulse detection
		local pulseActive = false
		if now - lastSpeedSampleTime >= 0.1 then
			if prevBallSpeed > 5 and speedMagnitude >= prevBallSpeed * 1.9 and speedMagnitude > 25 then
				pulseActive = true
				pulseWarningUntil = now + 0.35
				if state.antiPulse and isTargetMe and (now - lastParryTime >= 0.2) then
					fireParry("Anti Pulse")
				end
			end
			prevBallSpeed = speedMagnitude
			lastSpeedSampleTime = now
		end
		if now < pulseWarningUntil then
			pulseActive = true
		end

		-- Auto Spam (Close proximity rapid clash)
		if state.autoSpam and isTargetMe and distance < 15 then
			if now - lastAutoSpamTime >= 0.05 then
				lastAutoSpamTime = now
				fireParry("Auto Spam")
			end
		end

		-- Core Auto Parry evaluation
		if state.autoParry and isTargetMe then
			local sensMultiplier = BallTracker.sensitivities[state.sensitivity] or 1.0
			if state.antiCurve and curveActive then
				sensMultiplier = sensMultiplier * 1.8
			end
			if BallTracker.shouldParry(tti, speed, sensMultiplier, extraLeadSeconds + pingSeconds * 0.5) then
				if now - lastParryTime >= 0.3 then
					fireParry("Auto Parry")
				end
			end
		end

		-- Update Ball ESP
		if state.ballEsp then
			updateBallESP(activeBall, targetName, distance, speed, tti)
		else
			cleanupBallESP()
		end

		-- Update Player ESP
		if state.playerEsp then
			for _, player in ipairs(Players:GetPlayers()) do
				updatePlayerESP(player, playerPos)
			end
		else
			cleanupAllPlayerESP()
		end

		-- Refresh Parry Status indicator
		local isCooldown = (now - lastParryTime < 0.3)
		local remote = resolveParryRemote()
		if not remote and not canSimulateParry and not virtualInput then
			parryStatusText = "Parry input unavailable"
			parryStatusColor = Color3.fromRGB(255, 95, 95)
		elseif not isCooldown and parryStatusText ~= "Ready" and (now - lastParryTime >= 0.35) and not (lastAttemptTime > lastDispatchTime and now - lastAttemptTime < 2) then
			parryStatusText = "Ready"
			parryStatusColor = UI.colors.indigo
		elseif isCooldown and parryStatusText ~= "Fired" then
			parryStatusText = string.format("Cooldown (%.1fs)", math.max(0, 0.3 - (now - lastParryTime)))
			parryStatusColor = Color3.fromRGB(255, 180, 80)
		end

		-- Assemble active warnings
		local activeWarnings: { string } = {}
		if curveActive then
			table.insert(activeWarnings, "CURVE DETECTED")
		end
		if freezeActive then
			table.insert(activeWarnings, "FREEZE DETECTED")
		end
		if pulseActive then
			table.insert(activeWarnings, "PULSE DETECTED")
		end

		-- Update Status Panel
		statusDisplay.setTarget(targetName, isTargetMe)
		statusDisplay.setDistance(distance)
		statusDisplay.setSpeed(speed)
		statusDisplay.setTTI(tti)
		if lastAttemptTime > lastDispatchTime and now - lastAttemptTime < 2 then
			statusDisplay.setParryStatus(parryStatusText, Color3.fromRGB(255, 95, 95))
		elseif lastDispatchTime > 0 and now - lastDispatchTime < 2 then
			statusDisplay.setParryStatus("Input sent: " .. lastDispatchReason, UI.colors.indigo)
		elseif state.autoParry and not isTargetMe then
			statusDisplay.setParryStatus("Waiting for target signal", UI.colors.muted)
		elseif state.autoParry then
			statusDisplay.setParryStatus("Targeted; waiting for timing", UI.colors.indigo)
		else
			statusDisplay.setParryStatus(parryStatusText, parryStatusColor)
		end
		statusDisplay.setWarnings(activeWarnings)
	end

	-- Connect frame loop to RenderStepped
	scope:connect(RunService.RenderStepped, onRenderStep)

	-- Scope teardown handling
	scope:add(function()
		cleanupBallESP()
		cleanupAllPlayerESP()
		isHoldingManualSpam = false
	end)
end

return table.freeze(BladeBall)

