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

