local RoleData = require("../../client/games/logic/RoleData")

local cache = {}
local first = RoleData.merge(cache, { Alice = { Role = "Murderer" }, Bob = { Role = "Sheriff" } })
assert(first.Alice == "Murderer" and cache.Bob == "Sheriff", "Valid role data must be recorded")
local second = RoleData.merge(cache, { Bob = { Role = "Hero" }, Carol = { Role = false }, Invalid = 3 })
assert(cache.Alice == "Murderer" and cache.Bob == "Hero", "Partial updates must preserve other roles")
assert(second.Alice == nil and second.Carol == nil and cache.Invalid == nil, "Snapshots must contain only valid received roles")
assert(next(RoleData.merge(cache, false)) == nil and cache.Alice == "Murderer", "Malformed updates must not erase roles")
print("RoleData tests passed")

