local Tracker = require("../../client/games/logic/CollisionTracker")
local tracker = Tracker.new()
local function part(collidable)
	return { Parent = true, CanCollide = collidable, IsA = function(_, name) return name == "BasePart" end }
end
local solid = part(true)
local ghost = part(false)
local first = { GetDescendants = function() return { solid, ghost } end }
tracker:apply(first)
assert(not solid.CanCollide and not ghost.CanCollide, "Noclip should disable collisions")
local later = part(true)
first.GetDescendants = function() return { solid, ghost, later } end
tracker:apply(first)
assert(not later.CanCollide, "Parts added while active should be tracked")
tracker:restore()
assert(solid.CanCollide and not ghost.CanCollide and later.CanCollide, "Restore must preserve original values")
tracker:apply(first)
local newPart = part(true)
local second = { GetDescendants = function() return { newPart } end }
tracker:apply(second)
assert(solid.CanCollide and not ghost.CanCollide and not newPart.CanCollide, "Character switch must restore old parts")
tracker:restore()
assert(newPart.CanCollide, "New character must restore on stop")
print("CollisionTracker tests passed")

