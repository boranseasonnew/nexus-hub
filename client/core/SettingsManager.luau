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

