local AimPrediction = {}

function AimPrediction.leadTime(mode, offset, ping)
	local baseline = math.clamp(offset, 0, 10) / 15
	local network = type(ping) == "number" and ping == ping and ping >= 0 and math.clamp(ping * 1.15, 0, 0.35) or nil
	if mode == "YARHM" then return baseline end
	if mode == "HHB" then return network or 0.0575 end
	return math.clamp(network and (baseline + network) / 2 or baseline, 0, 0.35)
end

return table.freeze(AimPrediction)

