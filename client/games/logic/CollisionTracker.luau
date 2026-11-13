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

