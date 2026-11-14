local Perception = require("./Perception")
local Sight = require("./Sight")
local Spacing = require("../Body/Spacing")

local Predators = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function hunters(mob, range: number, names: { string }, into: { Model })
	local crowd = mob.Crowd
	if not crowd or #names == 0 then return end

	local origin = mob.Root.Position
	local span = math.ceil(range / Spacing.Settings.CellSize)

	for dx = -span, span do
		for dz = -span, span do
			for _, other in crowd:Cell(origin, dx, dz) or {} do
				if other == mob or other.Dead or not other.Root or not table.find(names, other.Name) then continue end
				if (other.Root.Position - origin).Magnitude > range then continue end

				if Sight.Notices(mob, other.Model) then
					table.insert(into, other.Model)
				end
			end
		end
	end
end

local function within(mob, target: Model, range: number): boolean
	local root = Perception.RootOf(target)
	return root ~= nil and (root.Position - mob.Root.Position).Magnitude <= range
end

function Predators.Near(mob, range: number, names: { string }?, grace: number?): { Model }
	local found = Sight.Noticed(mob, range)
	local provoker = mob:Provoker()
	local fresh = mob.HurtAt ~= nil and os.clock() - mob.HurtAt < (grace or 0)

	if provoker and not table.find(found, provoker) and (fresh or within(mob, provoker, range)) then
		table.insert(found, provoker)
	end

	hunters(mob, range, names or {}, found)

	return found
end

function Predators.Away(mob, predators: { Model }): Vector3?
	local origin = mob.Root.Position
	local total = Vector3.zero

	for _, predator in predators do
		local root = Perception.RootOf(predator)
		if not root or not Perception.IsValidTarget(predator) then continue end

		local offset = flat(origin - root.Position)
		local distance = math.max(offset.Magnitude, 1)

		total += (if offset.Magnitude > 1e-3 then offset.Unit else -flat(mob.Root.CFrame.LookVector)) / distance
	end

	return if total.Magnitude > 1e-6 then total.Unit else nil
end

function Predators.Alive(predators: { Model }?): { Model }
	local alive = {}
	local known: { Model } = predators or {}

	for _, predator in known do
		if Perception.IsValidTarget(predator) then
			table.insert(alive, predator)
		end
	end

	return alive
end

return Predators
