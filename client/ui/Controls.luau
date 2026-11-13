local Input = game:GetService("UserInputService")
local UI = require(script.Parent.Components)
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

