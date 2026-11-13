local Scope = {}
Scope.__index = Scope

function Scope.new()
	return setmetatable({ items = {}, closed = false }, Scope)
end

function Scope:add(cleanup)
	if self.closed then
		cleanup()
	else
		table.insert(self.items, cleanup)
	end
end

function Scope:connect(signal, handler)
	local connection = signal:Connect(handler)
	self:add(function()
		connection:Disconnect()
	end)
	return connection
end

function Scope:close()
	if self.closed then
		return
	end
	self.closed = true
	for index = #self.items, 1, -1 do
		local ok, message = pcall(self.items[index])
		if not ok then
			warn("Nexus cleanup failed:", message)
		end
	end
	table.clear(self.items)
end

return Scope

