local RoleData = {}

function RoleData.merge(cache, data)
	local snapshot = {}
	if type(data) ~= "table" then return snapshot end
	for name, info in pairs(data) do
		if type(name) == "string" and type(info) == "table" and type(info.Role) == "string" then
			cache[name] = info.Role
			snapshot[name] = info.Role
		end
	end
	return snapshot
end

return table.freeze(RoleData)

