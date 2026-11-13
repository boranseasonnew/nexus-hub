local AimPrediction = require("../../client/games/logic/AimPrediction")
local function near(actual, expected)
	assert(math.abs(actual - expected) < 1e-8, tostring(actual) .. " ~= " .. tostring(expected))
end
near(AimPrediction.leadTime("YARHM", 2.8, 0.05), 2.8 / 15)
near(AimPrediction.leadTime("HHB", 2.8, 0.05), 0.0575)
near(AimPrediction.leadTime("Adaptive", 2.8, 0.05), (2.8 / 15 + 0.0575) / 2)
near(AimPrediction.leadTime("Adaptive", 2.8, nil), 2.8 / 15)
near(AimPrediction.leadTime("HHB", 2.8, nil), 0.0575)
near(AimPrediction.leadTime("Adaptive", 10, 10), 0.35)
near(AimPrediction.leadTime("Adaptive", 0, 0), 0)
print("AimPrediction tests passed")

