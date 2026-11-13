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

