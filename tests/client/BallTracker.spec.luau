local tracker = require("../../client/games/logic/BallTracker")

local Vector = {}
local vectorMetatable = {}
vectorMetatable.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z) end
	if key == "Unit" then return Vector.new(self.x / self.Magnitude, self.y / self.Magnitude, self.z / self.Magnitude) end
	return Vector[key]
end
vectorMetatable.__sub = function(a, b) return Vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function Vector.new(x, y, z) return setmetatable({ x = x, y = y, z = z }, vectorMetatable) end
function Vector:Dot(other) return self.x * other.x + self.y * other.y + self.z * other.z end

local origin = Vector.new(0, 0, 0)
local player = Vector.new(20, 0, 0)
local incoming, distance, speed = tracker.timeToImpact(origin, Vector.new(10, 0, 0), player)
assert(incoming == 2 and distance == 20 and speed == 10, "Incoming ball timing")
assert(tracker.timeToImpact(origin, Vector.new(-10, 0, 0), player) == math.huge, "Receding ball")
assert(tracker.timeToImpact(origin, Vector.new(0, 10, 0), player) == math.huge, "Sideways ball")
assert(tracker.timeToImpact(origin, origin, origin) == 0, "Ball already at player")
assert(tracker.shouldParry(0.1, 100, 1) and not tracker.shouldParry(1, 100, 1), "Parry threshold")
assert(tracker.timeToImpact(origin, Vector.new(10, 0, 0), player, Vector.new(-5, 0, 0), 5) == 1, "Relative movement and contact radius")
assert(tracker.timeToImpact(origin, Vector.new(-10, 0, 0), Vector.new(1, 0, 0), nil, 2) == 0, "Overlapping target")
assert(tracker.shouldParry(0.37, 100, 1, 0.15), "Extra lead should trigger earlier")
assert(not tracker.shouldParry(0.4, 100, 1, 0.08), "Default lead should not fire this early")

local unrelated = { Name = "Other", IsA = function(_, class) return class == "RemoteEvent" end }
local remote = { Name = "Parry", IsA = unrelated.IsA }
assert(tracker.findParryRemote({ GetDescendants = function() return { unrelated } end }) == nil, "Unknown remote")
assert(tracker.findParryRemote({ GetDescendants = function() return { unrelated, remote } end }) == remote, "Known remote")
local function ball(name, attributes)
	return { Name = name, IsA = function(_, kind) return kind == "BasePart" end, GetAttribute = function(_, key) return attributes[key] end }
end
local decoy = ball("Ball", { realBall = false, target = "Player" })
local candidate = ball("Ball", { target = "Player" })
local real = ball("NamedDifferently", { realBall = true, target = "Player" })
local folder = { GetDescendants = function() return { decoy, candidate, real } end }
local root = { FindFirstChild = function(_, name) return name == "Balls" and folder or nil end }
assert(tracker.findBall(root) == real, "Real ball should take priority over decoys and target-only candidates")
local unmarked = ball("Unmarked", {})
unmarked.Anchored = false
folder.GetDescendants = function() return { decoy, unmarked } end
assert(tracker.findBall(root) == unmarked, "A single unanchored ball is an acceptable fallback")
local another = ball("Another", {})
another.Anchored = false
folder.GetDescendants = function() return { decoy, unmarked, another } end
root.GetChildren = function() return {} end
assert(tracker.findBall(root) == nil, "Ambiguous unmarked balls must not be guessed")
local marker = { Enabled = true, IsA = function(_, kind) return kind == "Highlight" end }
local character = { FindFirstChild = function(_, name) return name == "Highlight" and marker or nil end }
local targeted, display = tracker.isLocalTarget("", "Player", 123, character)
assert(targeted and display == "Player (Highlight)", "Highlight target fallback")
assert(not tracker.isLocalTarget("Other", "Player", 123, character), "Explicit target overrides Highlight")
marker.Enabled = false
assert(not tracker.isLocalTarget("", "Player", 123, character), "Disabled Highlight is not a target")
assert(tracker.isLocalTarget("123", "Player", 123, nil), "User ID target")
print("BallTracker tests passed")

