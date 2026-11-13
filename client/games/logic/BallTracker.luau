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

