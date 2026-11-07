local Obstacles = require("../Obstacles")
local Perception = require("../Perception")

local Eyes = {}

local casts = 0

function Eyes.Origin(mob, settings): Vector3
	return mob.Root.Position + Vector3.new(0, settings.eye_height, 0)
end

function Eyes.Clear(mob, target: Model, settings): boolean
	local origin = Eyes.Origin(mob, settings)

	for _, part in { target:FindFirstChild("Head"), Perception.RootOf(target) } do
		if not part or not part:IsA("BasePart") then continue end

		casts += 1

		if workspace:Raycast(origin, part.Position - origin, Obstacles.Params()) == nil then
			return true
		end
	end

	return false
end

function Eyes.Casts(): number
	return casts
end

return Eyes
