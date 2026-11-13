local TweenService = game:GetService("TweenService")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UI = require(script.Parent.Components)
local Scope = require(script.Parent.Parent.core.Scope)

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

