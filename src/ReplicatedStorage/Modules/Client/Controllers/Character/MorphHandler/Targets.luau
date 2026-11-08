local Config = require("./Config")
local Types = require("./Types")

local Targets = {}

local function live(): Instance?
	local found: Instance? = workspace

	for _, segment in Config.LiveFolder do
		found = if found then found:FindFirstChild(segment) else nil
	end

	return found
end

local function segmentDistance(point: Vector3, from: Vector3, to: Vector3): number
	local axis = to - from
	local length = axis:Dot(axis)
	local along = if length > 1e-6 then math.clamp((point - from):Dot(axis) / length, 0, 1) else 0

	return (point - (from + axis * along)).Magnitude
end

function Targets.Ahead(session: Types.Session, range: number, cone: number): BasePart?
	local folder = live()
	local children: { Instance } = if folder then folder:GetChildren() else {}
	local origin = session.Root.Position
	local look = session:Look()
	local limit = math.cos(math.rad(cone))
	local best: BasePart? = nil
	local bestAlign = -math.huge

	for _, model in children do
		if model == session.Character or not model:IsA("Model") then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then continue end

		local offset = (root.Position - origin) * Vector3.new(1, 0, 1)
		local distance = offset.Magnitude
		if distance > range or distance < 1e-3 then continue end

		local align = offset.Unit:Dot(look)

		if align >= limit and align > bestAlign then
			best = root
			bestAlign = align
		end
	end

	return best
end

function Targets.Along(session: Types.Session, from: Vector3, to: Vector3, radius: number): { Model }
	local found: { Model } = {}
	local folder = live()
	local children: { Instance } = if folder then folder:GetChildren() else {}

	for _, model in children do
		if model == session.Character or not model:IsA("Model") then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")

		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and segmentDistance(root.Position, from, to) <= radius then
			table.insert(found, model)
		end
	end

	return found
end

return Targets
