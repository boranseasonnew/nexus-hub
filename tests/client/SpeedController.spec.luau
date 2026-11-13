local SpeedController = require("../../client/games/logic/SpeedController")

local controller = SpeedController.new(100, 0)
assert(controller:sample(3, -1, 1) == 100, "Direction changes must not lower speed")
assert(controller:sample(3, 1, 1) == 80, "Backwards movement while holding direction lowers speed")
assert(controller:sample(3, 1, 1.1) == 80, "Consecutive samples should not repeatedly lower speed")
assert(controller:sample(0, 1, 10) == 80, "Speed should not increase before the quiet period")
assert(controller:sample(0, 1, 11) == 81, "Speed should recover gradually after the quiet period")
controller:setTarget(30, 12)
assert(controller.speed == 30 and controller.corrections == 0, "Changing target resets calibration")
print("SpeedController tests passed")

