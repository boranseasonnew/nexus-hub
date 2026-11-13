-- Nexus Hub local test bundle. Generated; do not edit directly.
local factories, cache = {}, {}
local nexusRequire

factories["ui/Components"] = function()
local UI = {}

UI.colors = table.freeze({
	surface = Color3.fromRGB(24, 25, 35),
	panel = Color3.fromRGB(33, 35, 49),
	border = Color3.fromRGB(58, 60, 82),
	text = Color3.fromRGB(240, 241, 249),
	muted = Color3.fromRGB(179, 183, 204),
	indigo = Color3.fromRGB(161, 150, 249),
	slate = Color3.fromRGB(153, 195, 224),
})

function UI.make(className, parent, props)
	local instance = Instance.new(className)
	for name, value in pairs(props or {}) do
		instance[name] = value
	end
	instance.Parent = parent
	return instance
end

function UI.round(frame, radius)
	UI.make("UICorner", frame, { CornerRadius = UDim.new(0, radius or 8) })
end

function UI.label(parent, text, height, muted)
	return UI.make("TextLabel", parent, {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = muted and UI.colors.muted or UI.colors.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
	})
end

function UI.button(parent, text, width)
	local button = UI.make("TextButton", parent, {
		Size = UDim2.new(width and 0 or 1, width or 0, 0, 32),
		BackgroundColor3 = UI.colors.panel,
		Text = text,
		TextColor3 = UI.colors.text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
	})
	UI.round(button)
	return button
end

function UI.input(parent, placeholder)
	local box = UI.make("TextBox", parent, {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = UI.colors.panel,
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = UI.colors.muted,
		TextColor3 = UI.colors.text,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
	})
	UI.round(box)
	return box
end

function UI.list(parent, spacing)
	return UI.make("UIListLayout", parent, {
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

return UI

end

factories["ui/Controls"] = function()
local Input = game:GetService("UserInputService")
local UI = nexusRequire("ui/Components")
local Controls = {}

function Controls.valueSlider(parent, scope, label, initial, low, high, onChange)
	local row = UI.make("Frame", parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) })
	local caption = UI.label(row, label, 32, false)
	caption.Size = UDim2.new(0.32, 0, 1, 0)
	local track = UI.button(row, "")
	track.Position = UDim2.new(0.32, 0, 0.5, -7)
	track.Size = UDim2.new(0.52, 0, 0, 14)
	local fill = UI.make("Frame", track, { BorderSizePixel = 0, BackgroundColor3 = UI.colors.indigo })
	UI.round(fill, 6)
	local number = UI.label(row, "", 32, false)
	number.Position = UDim2.new(0.85, 0, 0, 0)
	number.Size = UDim2.new(0.15, 0, 1, 0)
	number.TextXAlignment = Enum.TextXAlignment.Right
	local dragging = false
	local function display(value)
		number.Text = tostring(value)
		fill.Size = UDim2.fromScale((value - low) / (high - low), 1)
	end
	local function apply(x)
		if track.AbsoluteSize.X <= 0 then return end
		local ratio = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local value = math.floor(low + ratio * (high - low) + 0.5)
		display(value)
		onChange(value)
	end
	scope:connect(track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; apply(input.Position.X) end
	end)
	scope:connect(Input.InputChanged, function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then apply(input.Position.X) end
	end)
	scope:connect(Input.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	display(initial)
	return row
end

function Controls.slider(parent, scope, label, initial, low, high, onChange)
	local row = UI.make("Frame", parent, {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48),
	})
	local caption = UI.label(row, "", 23, false)
	local track = UI.button(row, "")
	track.Position = UDim2.fromOffset(0, 26)
	track.Size = UDim2.new(1, 0, 0, 17)
	local fill = UI.make("Frame", track, { BorderSizePixel = 0, BackgroundColor3 = UI.colors.indigo })
	UI.round(fill, 6)
	local dragging = false
	local function display(value)
		caption.Text = string.format("%s  %d%%", label, math.floor(value * 100 + 0.5))
		fill.Size = UDim2.fromScale((value - low) / (high - low), 1)
	end
	local function apply(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local ratio = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		local value = low + ratio * (high - low)
		display(value)
		onChange(value)
	end
	scope:connect(track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			apply(input.Position.X)
		end
	end)
	scope:connect(Input.InputChanged, function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			apply(input.Position.X)
		end
	end)
	scope:connect(Input.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	display(initial)
end

function Controls.dropdown(parent, scope, label, initial, choices, onChange)
	local row = UI.make("Frame", parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) })
	UI.list(row, 4)
	local button = UI.button(row, label .. "  ·  " .. initial .. "  ▾")
	local options = {}
	local expanded = false
	local function toggle()
		expanded = not expanded
		for _, option in ipairs(options) do
			option.Visible = expanded
		end
		row.Size = UDim2.new(1, 0, 0, expanded and (32 + #options * 36) or 32)
	end
	scope:connect(button.Activated, toggle)
	for _, choice in ipairs(choices) do
		local option = UI.button(row, choice)
		option.Visible = false
		table.insert(options, option)
		scope:connect(option.Activated, function()
			onChange(choice)
			button.Text = label .. "  ·  " .. choice .. "  ▾"
			toggle()
		end)
	end
end

return Controls

end

factories["ui/MainWindow"] = function()
local TweenService = game:GetService("TweenService")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UI = nexusRequire("ui/Components")
local Scope = nexusRequire("core/Scope")

local Window = {}

function Window.mount(screen, scope, settings)
	local frame = UI.make("Frame", screen, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(settings:get("x"), settings:get("y")),
		Size = UDim2.fromOffset(500, 328),
		BackgroundColor3 = UI.colors.surface,
	})
	UI.round(frame, 13)
	local mouseCapture = UI.make("TextButton", frame, {
		Name = "MouseUnlock", Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1, Text = "", Modal = true, AutoButtonColor = false,
	})
	local mouseReleased = false
	local function releaseMouse()
		if mouseReleased then return end
		mouseReleased = true
		mouseCapture.Modal = true
		Input.MouseBehavior = Enum.MouseBehavior.Default
		Input.MouseIconEnabled = true
	end
	local function restoreMouse()
		if not mouseReleased then return end
		mouseReleased = false
		mouseCapture.Modal = false
		-- Shift Lock may have changed while the menu was open; let the game regain control.
		Input.MouseBehavior = Enum.MouseBehavior.Default
		Input.MouseIconEnabled = true
	end
	releaseMouse()
	local mouseStepName = "NexusMouseUnlock_" .. HttpService:GenerateGUID(false)
	RunService:BindToRenderStep(mouseStepName, Enum.RenderPriority.Last.Value + 1, function()
		if mouseReleased and frame.Visible then
			if Input.MouseBehavior ~= Enum.MouseBehavior.Default then Input.MouseBehavior = Enum.MouseBehavior.Default end
			if not Input.MouseIconEnabled then Input.MouseIconEnabled = true end
		end
	end)
	scope:add(function() RunService:UnbindFromRenderStep(mouseStepName) end)
	local outline = UI.make("UIStroke", frame, { Color = UI.colors.border })
	local scale = UI.make("UIScale", frame)
	local titleBar = UI.make("Frame", frame, {
		Active = true, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48),
	})
	local title = UI.label(titleBar, "Nexus Hub", 48, false)
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -104, 0, 48)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 19
	local close = UI.button(titleBar, "×", 30)
	close.Position = UDim2.new(1, -40, 0, 8)
	local minimize = UI.button(titleBar, "–", 30)
	minimize.Position = UDim2.new(1, -76, 0, 8)
	local sidebar = UI.make("Frame", frame, {
		Position = UDim2.fromOffset(12, 56), Size = UDim2.fromOffset(108, 250),
		BackgroundTransparency = 1,
	})
	UI.list(sidebar, 7)
	local body = UI.make("ScrollingFrame", frame, {
		Position = UDim2.fromOffset(133, 56), Size = UDim2.new(1, -146, 1, -104),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	local status = UI.label(frame, "", 36, true)
	status.Size = UDim2.new(1, -28, 0, 36)
	status.Position = UDim2.new(0, 14, 1, -41)
	local rootPage
	local pageScope
	local window = { frame = frame }
	local tween

	local function clampPosition()
		local canvas = screen.AbsoluteSize
		if canvas.X == 0 or canvas.Y == 0 then
			return
		end
		local halfX = math.min(0.5, 250 * scale.Scale / canvas.X)
		local halfY = math.min(0.5, 164 * scale.Scale / canvas.Y)
		local x = math.clamp(settings:get("x"), halfX, 1 - halfX)
		local y = math.clamp(settings:get("y"), halfY, 1 - halfY)
		frame.Position = UDim2.fromScale(x, y)
	end

	function window:applySettings()
		local canvas = screen.AbsoluteSize
		local fit = canvas.X > 0 and canvas.Y > 0 and math.min((canvas.X - 8) / 500, (canvas.Y - 8) / 328) or 1
		scale.Scale = math.max(0.2, math.min(settings:get("scale"), fit))
		frame.BackgroundTransparency = settings:get("transparency")
		outline.Color = settings:get("theme") == "Slate" and UI.colors.slate or UI.colors.indigo
		clampPosition()
	end

	function window:page()
		if pageScope then
			pageScope:close()
			rootPage:Destroy()
		end
		body.CanvasPosition = Vector2.zero
		rootPage = UI.make("Frame", body, {
			Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		})
		UI.list(rootPage, 8)
		pageScope = Scope.new()
		return rootPage, pageScope
	end

	function window:tab(label, handler)
		scope:connect(UI.button(sidebar, label).Activated, handler)
	end

	function window:notify(message)
		status.Text = message
	end

	local function toggle()
		frame.Visible = not frame.Visible
		if frame.Visible then
			releaseMouse()
			if tween then
				tween:Cancel()
			end
			frame.BackgroundTransparency = math.min(1, settings:get("transparency") + 0.13)
			tween = TweenService:Create(frame, TweenInfo.new(0.12), { BackgroundTransparency = settings:get("transparency") })
			tween:Play()
		else
			restoreMouse()
		end
	end

	scope:add(function()
		restoreMouse()
		if pageScope then
			pageScope:close()
		end
		if tween then
			tween:Cancel()
		end
	end)
	scope:connect(close.Activated, function() scope:close() end)
	scope:connect(minimize.Activated, toggle)
	scope:connect(screen:GetPropertyChangedSignal("AbsoluteSize"), function() window:applySettings() end)
	scope:connect(Input.InputBegan, function(input, processed)
		if not processed and not Input:GetFocusedTextBox() and input.KeyCode.Name == settings:get("hotkey") then
			toggle()
		end
	end)
	local dragStart
	local positionStart
	scope:connect(titleBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local localX = input.Position.X - titleBar.AbsolutePosition.X
			if localX < titleBar.AbsoluteSize.X - 78 * scale.Scale then
				dragStart = input.Position
				positionStart = Vector2.new(frame.Position.X.Scale, frame.Position.Y.Scale)
			end
		end
	end)
	scope:connect(Input.InputChanged, function(input)
		if dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
			local size = screen.AbsoluteSize
			if size.X > 0 and size.Y > 0 then
				local delta = input.Position - dragStart
				settings:set("x", positionStart.X + delta.X / size.X)
				settings:set("y", positionStart.Y + delta.Y / size.Y)
				clampPosition()
			end
		end
	end)
	scope:connect(Input.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = nil
		end
	end)
	window:applySettings()
	return window
end

return Window

end

factories["core/Scope"] = function()
local Scope = {}
Scope.__index = Scope

function Scope.new()
	return setmetatable({ items = {}, closed = false }, Scope)
end

function Scope:add(cleanup)
	if self.closed then
		cleanup()
	else
		table.insert(self.items, cleanup)
	end
end

function Scope:connect(signal, handler)
	local connection = signal:Connect(handler)
	self:add(function()
		connection:Disconnect()
	end)
	return connection
end

function Scope:close()
	if self.closed then
		return
	end
	self.closed = true
	for index = #self.items, 1, -1 do
		local ok, message = pcall(self.items[index])
		if not ok then
			warn("Nexus cleanup failed:", message)
		end
	end
	table.clear(self.items)
end

return Scope

end

factories["core/SettingsManager"] = function()
local Settings = {}
Settings.__index = Settings

local values = {
	scale = { default = 1, low = 0.8, high = 1.3 },
	transparency = { default = 0, low = 0, high = 0.4 },
	theme = { default = "Indigo", allowed = { Indigo = true, Slate = true } },
	hotkey = { default = "RightControl", keyCode = true },
	mm2OverlayHotkey = { default = "F7", keyCode = true },
	mm2FlyHotkey = { default = "F", keyCode = true },
	mm2FlyNoclipHotkey = { default = "N", keyCode = true },
	x = { default = 0.5, low = 0, high = 1 },
	y = { default = 0.5, low = 0, high = 1 },
	feedback = { default = true },
}

function Settings.new(playerGui, moduleId)
	return setmetatable({ gui = playerGui, prefix = "Nexus_" .. moduleId .. "_" }, Settings)
end

local function normalize(rule, value)
	if typeof(value) ~= typeof(rule.default) then
		return rule.default
	end
	if rule.keyCode then
		for _, key in ipairs(Enum.KeyCode:GetEnumItems()) do
			if key.Name == value and key ~= Enum.KeyCode.Unknown then
				return value
			end
		end
		return rule.default
	end
	if rule.allowed and not rule.allowed[value] then
		return rule.default
	end
	if rule.low then
		if value ~= value then
			return rule.default
		end
		return math.clamp(value, rule.low, rule.high)
	end
	return value
end

function Settings:get(name)
	return normalize(values[name], self.gui:GetAttribute(self.prefix .. name))
end

function Settings:set(name, value)
	self.gui:SetAttribute(self.prefix .. name, normalize(values[name], value))
end

return Settings

end

factories["games/logic/BallTracker"] = function()
local BallTracker = {}

BallTracker.sensitivities = table.freeze({
	Relaxed = 1.5,
	Standard = 1.0,
	Precision = 0.7,
	Instant = 0.4,
})

function BallTracker.findBall(root: Instance): BasePart?
	local balls = root:FindFirstChild("Balls")
	if balls then
		local candidate = nil
		local unmarked = nil
		local unmarkedCount = 0
		for _, ball in balls:GetDescendants() do
			if ball:IsA("BasePart") then
				local real = ball:GetAttribute("realBall")
				if real == true then return ball end
				if real ~= false and (ball:GetAttribute("target") ~= nil or ball:GetAttribute("Target") ~= nil) then
					candidate = candidate or ball
				elseif real == nil and ball.Anchored == false then
					unmarked = ball
					unmarkedCount += 1
				end
			end
		end
		if candidate then return candidate end
		if unmarkedCount == 1 then return unmarked end
	end
	for _, child in root:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("realBall") ~= false and (child.Name == "Ball" or child:GetAttribute("Target") ~= nil or child:GetAttribute("target") ~= nil) then
			return child
		end
	end
	-- Search deeper in known folders
	for _, folder in root:GetChildren() do
		if folder ~= balls and folder:IsA("Folder") then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") and child:GetAttribute("realBall") ~= false and (child.Name == "Ball" or child:GetAttribute("Target") ~= nil or child:GetAttribute("target") ~= nil) then
					return child
				end
			end
		end
	end
	return nil
end

function BallTracker.isLocalTarget(targetName: string, playerName: string, userId: number, character: Model?): (boolean, string)
	if targetName ~= "" then
		return targetName == playerName or targetName == tostring(userId), targetName
	end
	-- Some versions signal the targeted character with a Highlight instead of a ball attribute.
	local marker = character and character:FindFirstChild("Highlight")
	if marker and marker:IsA("Highlight") and marker.Enabled then
		return true, playerName .. " (Highlight)"
	end
	return false, targetName
end

function BallTracker.findParryRemote(replicatedStorage: Instance): RemoteEvent?
	local names = { parry = true, clash = true, deflect = true }
	for _, child in replicatedStorage:GetDescendants() do
		if child:IsA("RemoteEvent") then
			if names[string.lower(child.Name)] then
				return child
			end
		end
	end
	return nil
end

function BallTracker.timeToImpact(ballPos: Vector3, ballVel: Vector3, playerPos: Vector3, playerVel: Vector3?, contactRadius: number?): (number, number, number)
	local distance = (playerPos - ballPos).Magnitude
	local speed = ballVel.Magnitude
	if distance <= math.max(0.001, contactRadius or 0) then
		return 0, distance, speed
	end
	local relativeVelocity = playerVel and (ballVel - playerVel) or ballVel
	local closingSpeed = relativeVelocity:Dot((playerPos - ballPos).Unit)
	if closingSpeed <= 0.001 then
		return math.huge, distance, speed
	end
	return math.max(0, distance - math.max(0, contactRadius or 0)) / closingSpeed, distance, speed
end

function BallTracker.baseThreshold(speed: number): number
	return math.clamp(0.18 + (speed * 0.0005), 0.15, 0.35)
end

function BallTracker.shouldParry(tti: number, speed: number, sensitivityMultiplier: number, extraLead: number?): boolean
	local threshold = BallTracker.baseThreshold(speed) * sensitivityMultiplier + math.max(0, extraLead or 0)
	return tti <= threshold
end

function BallTracker.predictPosition(ballPos: Vector3, ballVel: Vector3, dt: number): Vector3
	return ballPos + ballVel * dt
end

function BallTracker.isCurving(prevVel: Vector3, currentVel: Vector3, threshold: number?): boolean
	if prevVel.Magnitude < 1 or currentVel.Magnitude < 1 then
		return false
	end
	local dot = prevVel.Unit:Dot(currentVel.Unit)
	return dot < (threshold or 0.85)
end

return table.freeze(BallTracker)

end

factories["games/logic/SpeedController"] = function()
local SpeedController = {}
SpeedController.__index = SpeedController

function SpeedController.new(target, now)
	return setmetatable({ target = target, speed = target, lastAdjustment = now, corrections = 0 }, SpeedController)
end

function SpeedController:setTarget(target, now)
	self.target = target
	self.speed = target
	self.lastAdjustment = now
	self.corrections = 0
end

function SpeedController:sample(backwardDistance, directionAlignment, now)
	-- Only treat backwards movement as a possible correction while input continues in the same direction.
	if directionAlignment >= 0.85 and backwardDistance > 2 and now - self.lastAdjustment >= 0.5 then
		self.speed = math.max(8, self.speed * 0.8)
		self.lastAdjustment = now
		self.corrections += 1
	elseif now - self.lastAdjustment >= 10 then
		self.speed = math.min(self.target, self.speed + 1)
		self.lastAdjustment = now
	end
	return self.speed
end

return table.freeze(SpeedController)

end

factories["games/logic/CollisionTracker"] = function()
local CollisionTracker = {}
CollisionTracker.__index = CollisionTracker

function CollisionTracker.new()
	return setmetatable({ character = nil, parts = {} }, CollisionTracker)
end

function CollisionTracker:restore()
	for part, original in pairs(self.parts) do
		if part.Parent then part.CanCollide = original end
	end
	table.clear(self.parts)
	self.character = nil
end

function CollisionTracker:apply(character)
	if character ~= self.character then
		self:restore()
		self.character = character
	end
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if self.parts[part] == nil then self.parts[part] = part.CanCollide end
			if part.CanCollide then part.CanCollide = false end
		end
	end
end

return CollisionTracker

end

factories["games/logic/YARHMFling"] = function()
-- Fling routine adapted from YARHM; GPL-3.0: https://github.com/Joystickplays/psychic-octo-invention
local YARHMFling = {}
function YARHMFling.run(playerToFling, scope, notify)
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or not playerToFling.Character then return false end
    local originalDestroyHeight = workspace.FallenPartsDestroyHeight
    local oldPos = root.CFrame
    local originalCamera = workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject
    local originalSeated = humanoid:GetStateEnabled(Enum.HumanoidStateType.Seated)
    local fu = { notification = notify, dialog = function() end, waitfordialog = function() return "No" end, closedialog = function() end }
	local function miniFling(playerToFling)
		local a=game.Players.LocalPlayer;local b=a:GetMouse()local c={playerToFling}local d=game:GetService("Players")local e=d.LocalPlayer;local f=false;local g=function(h)local i=e.Character;local j=i and i:FindFirstChildOfClass("Humanoid")local k=j and j.RootPart;local l=h.Character;local m;local n;local o;local p;local q;if l:FindFirstChildOfClass("Humanoid")then m=l:FindFirstChildOfClass("Humanoid")end;if m and m.RootPart then n=m.RootPart end;if l:FindFirstChild("Head")then o=l.Head end;if l:FindFirstChildOfClass("Accessory")then p=l:FindFirstChildOfClass("Accessory")end;if p and p:FindFirstChild("Handle")then q=p.Handle end;if i and j and k then if k.Velocity.Magnitude<50 then oldPos=k.CFrame end;if m and m.Sit and not f then end;if o then if o.Velocity.Magnitude>500 then fu.dialog("Player flung","Player is already flung.\nFling again?",{"Fling again","No"})if fu.waitfordialog()=="No"then return fu.closedialog()end;fu.closedialog()end elseif not o and q then if q.Velocity.Magnitude>500 then fu.dialog("Player flung","Player is already flung.\nFling again?",{"Fling again","No"})if fu.waitfordialog()=="No"then return fu.closedialog()end;fu.closedialog()end end;if o then workspace.CurrentCamera.CameraSubject=o elseif not o and q then workspace.CurrentCamera.CameraSubject=q elseif m and n then workspace.CurrentCamera.CameraSubject=m end;if not l:FindFirstChildWhichIsA("BasePart")then return end;local r=function(s,t,u)k.CFrame=CFrame.new(s.Position)*t*u;i:SetPrimaryPartCFrame(CFrame.new(s.Position)*t*u)k.Velocity=Vector3.new(9e7,9e7*10,9e7)k.RotVelocity=Vector3.new(9e8,9e8,9e8)end;local v=function(s)local w=2;local x=tick()local y=0;repeat if k and m then if s.Velocity.Magnitude<50 then y=y+100;r(s,CFrame.new(0,1.5,0)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(0,-1.5,0)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(2.25,1.5,-2.25)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(-2.25,-1.5,2.25)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(0,1.5,0)+m.MoveDirection,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(0,-1.5,0)+m.MoveDirection,CFrame.Angles(math.rad(y),0,0))task.wait()else r(s,CFrame.new(0,1.5,m.WalkSpeed),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,-m.WalkSpeed),CFrame.Angles(0,0,0))task.wait()r(s,CFrame.new(0,1.5,m.WalkSpeed),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,1.5,n.Velocity.Magnitude/1.25),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,-n.Velocity.Magnitude/1.25),CFrame.Angles(0,0,0))task.wait()r(s,CFrame.new(0,1.5,n.Velocity.Magnitude/1.25),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(0,0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(math.rad(-90),0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(0,0,0))task.wait()end else break end until s.Velocity.Magnitude>500 or s.Parent~=h.Character or h.Parent~=d or h.Character~=l or m.Sit or j.Health<=0 or tick()>x+w end;workspace.FallenPartsDestroyHeight=0/0;local z=Instance.new("BodyVelocity")z.Name="EpixVel"z.Parent=k;z.Velocity=Vector3.new(9e8,9e8,9e8)z.MaxForce=Vector3.new(1/0,1/0,1/0)j:SetStateEnabled(Enum.HumanoidStateType.Seated,false)if n and o then if(n.CFrame.p-o.CFrame.p).Magnitude>5 then v(o)else v(n)end elseif n and not o then v(n)elseif not n and o then v(o)elseif not n and not o and p and q then v(q)else fu.notification("Can't find a proper part of target player to fling.")end;z:Destroy()j:SetStateEnabled(Enum.HumanoidStateType.Seated,true)workspace.CurrentCamera.CameraSubject=j;local recoveryDeadline=tick()+1;repeat k.CFrame=oldPos*CFrame.new(0,.5,0)i:SetPrimaryPartCFrame(oldPos*CFrame.new(0,.5,0))j:ChangeState("GettingUp")table.foreach(i:GetChildren(),function(A,B)if B:IsA("BasePart")then B.Velocity,B.RotVelocity=Vector3.new(),Vector3.new()end end)task.wait()until(k.Position-oldPos.p).Magnitude<25 or tick()>recoveryDeadline or scope.closed;workspace.FallenPartsDestroyHeight=originalDestroyHeight else fu.notification("No valid character of said target player.\nMay have died.")end end;g(c[1])
	end
    local ok, err = pcall(miniFling, playerToFling)
    workspace.FallenPartsDestroyHeight = originalDestroyHeight
    if humanoid.Parent then humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, originalSeated) end
    if workspace.CurrentCamera and originalCamera then workspace.CurrentCamera.CameraSubject = originalCamera end
    if root.Parent then
        local mover = root:FindFirstChild("EpixVel")
        if mover then mover:Destroy() end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if player.Character == character and humanoid.Health > 0 then character:PivotTo(oldPos) end
    end
    if not ok then notify("YARHM fling error: " .. tostring(err)) end
    return ok
end
return YARHMFling


end

factories["games/logic/RoleData"] = function()
local RoleData = {}

function RoleData.merge(cache, data)
	local snapshot = {}
	if type(data) ~= "table" then return snapshot end
	for name, info in pairs(data) do
		if type(name) == "string" and type(info) == "table" and type(info.Role) == "string" then
			cache[name] = info.Role
			snapshot[name] = info.Role
		end
	end
	return snapshot
end

return table.freeze(RoleData)

end

factories["games/BladeBall"] = function()
--!strict
-- Nexus Hub: Blade Ball Game Module
-- Comprehensive combat automation, threat detection, ESP overlays, and real-time status diagnostics.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = nexusRequire("ui/Components")
local Controls = nexusRequire("ui/Controls")
local BallTracker = nexusRequire("games/logic/BallTracker")

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

end

factories["games/logic/AimPrediction"] = function()
local AimPrediction = {}

function AimPrediction.leadTime(mode, offset, ping)
	local baseline = math.clamp(offset, 0, 10) / 15
	local network = type(ping) == "number" and ping == ping and ping >= 0 and math.clamp(ping * 1.15, 0, 0.35) or nil
	if mode == "YARHM" then return baseline end
	if mode == "HHB" then return network or 0.0575 end
	return math.clamp(network and (baseline + network) / 2 or baseline, 0, 0.35)
end

return table.freeze(AimPrediction)

end

factories["games/MM2"] = function()
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
local UI = nexusRequire("ui/Components")
local Controls = nexusRequire("ui/Controls")
local CollisionTracker = nexusRequire("games/logic/CollisionTracker")
local YARHMFling = nexusRequire("games/logic/YARHMFling")
local RoleData = nexusRequire("games/logic/RoleData")
local AimPrediction = nexusRequire("games/logic/AimPrediction")

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

end

factories["games/Universal"] = function()
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local UI = nexusRequire("ui/Components")
local Controls = nexusRequire("ui/Controls")
local Scope = nexusRequire("core/Scope")

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

end

factories["games/Doors"] = function()
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local UI = nexusRequire("ui/Components")
local Controls = nexusRequire("ui/Controls")
local CollisionTracker = nexusRequire("games/logic/CollisionTracker")

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

end

nexusRequire = function(id)
    if cache[id] == nil then cache[id] = assert(factories[id], "Missing module: " .. id)() end
    return cache[id]
end
local player = game:GetService("Players").LocalPlayer
assert(player, "Nexus requires a client session")
local playerGui = player:WaitForChild("PlayerGui")
local env = type(getgenv) == "function" and getgenv() or nil
if env and type(env.NexusTestClose) == "function" then pcall(env.NexusTestClose) end
local UI = nexusRequire("ui/Components")
local Controls = nexusRequire("ui/Controls")
local Scope = nexusRequire("core/Scope")
local Settings = nexusRequire("core/SettingsManager")
local Window = nexusRequire("ui/MainWindow")
local id
if game.PlaceId == 13772394625 or game.GameId == 4777817887 then id = "bladeball"
elseif game.PlaceId == 142823291 or game.GameId == 66654135 then id = "mm2"
elseif game.PlaceId == 6516141723 or game.GameId == 2440500124 then id = "doors"
else id = "universal" end
local moduleNames = { bladeball = "games/BladeBall", mm2 = "games/MM2", doors = "games/Doors", universal = "games/Universal" }
local scope = Scope.new()
local screen = UI.make("ScreenGui", playerGui, { Name = "NexusHubLocalTest", ResetOnSpawn = false, DisplayOrder = 11, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
scope:add(function() screen:Destroy(); if env then env.NexusTestClose = nil end end)
if env then env.NexusTestClose = function() scope:close() end end
local settings = Settings.new(playerGui, id)
local window = Window.mount(screen, scope, settings)
local function showHub()
    local page, pageScope = window:page()
    local ok, err = pcall(function() nexusRequire(moduleNames[id]).mount({parent = page, scope = pageScope, settings = settings}) end)
    if not ok then pageScope:close(); window:notify("Module error: " .. tostring(err)); warn("Nexus module error:", err) end
end
window:tab("Hub", showHub)
window:tab("Settings", function()
    local page, pageScope = window:page()
    Controls.slider(page, pageScope, "Scale", settings:get("scale"), 0.8, 1.3, function(v) settings:set("scale", v); window:applySettings() end)
    local key = UI.input(page, "Window key, e.g. RightControl")
    key.Text = settings:get("hotkey")
    pageScope:connect(key.FocusLost, function()
        local text = string.lower(string.match(key.Text, "^%s*(.-)%s*$") or "")
        for _, code in ipairs(Enum.KeyCode:GetEnumItems()) do
            if code ~= Enum.KeyCode.Unknown and string.lower(code.Name) == text then settings:set("hotkey", code.Name); break end
        end
        key.Text = settings:get("hotkey")
    end)
end)
window:notify("Local test · " .. id .. " · RightControl toggles window")
showHub()

