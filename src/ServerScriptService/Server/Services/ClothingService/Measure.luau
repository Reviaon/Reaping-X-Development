--[[@
	**Measure**: how much wider a piece must be so its limb never pokes through
	- **Test:** a grid of points on the limb's four side faces, at the piece's layout offset, against the mesh's real triangles (`EditableMesh`)
	  - A point is covered when a ray straight out of the face hits the piece
	  - It clips when that ray misses but a ray inward hits a wall within `Fit.Wall` of the face; the wall's depth sets the widening
	  - A wall must face out of the limb face (`Fit.Facing`), so hems, seams and folds turned inward never count
	  - Deeper hits are openings (a coat's front), and rows within `Fit.Rim` of the piece's ends are hems; neither widens it
	- **Result:** a Vector3 in the limb's axes (X and Z widen, Y stays 1), measured against the slot's R6 limb size
	- **Bake:** `require(ClothingService.Measure).Bake()` from the Studio command bar stores every piece's result as its `FitScale`
	  - Safe in Edit; it requires nothing that loads JLoader
]]
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require("./Config")
local Layout = require("./Layout")
local Types = require("./Types")

type Placed = Types.Placed

type Triangle = {
	Origin: Vector3,
	Edge1: Vector3,
	Edge2: Vector3,
	Normal: Vector3,
}

local Measure = {}

local function trianglesOf(placed: Placed): ({ Triangle }?, number, number)
	local source = placed.Source :: MeshPart
	local created, mesh = pcall(function(): EditableMesh
		return AssetService:CreateEditableMeshAsync(Content.fromUri(source.MeshId))
	end)

	if not created then return nil, 0, 0 end

	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge

	for _, vertex in mesh:GetVertices() do
		local position = mesh:GetPosition(vertex)
		low = low:Min(position)
		high = high:Max(position)
	end

	local center = (low + high) / 2
	local scale = source.Size / (high - low)
	local offset = placed.Offset
	local triangles: { Triangle } = {}
	local bottom, top = math.huge, -math.huge

	for _, face in mesh:GetFaces() do
		local vertices = mesh:GetFaceVertices(face)
		local a = offset * ((mesh:GetPosition(vertices[1]) - center) * scale)
		local b = offset * ((mesh:GetPosition(vertices[2]) - center) * scale)
		local c = offset * ((mesh:GetPosition(vertices[3]) - center) * scale)

		local edge1, edge2 = b - a, c - a
		local normal = edge1:Cross(edge2)

		bottom = math.min(bottom, a.Y, b.Y, c.Y)
		top = math.max(top, a.Y, b.Y, c.Y)
		table.insert(triangles, {
			Origin = a,
			Edge1 = edge1,
			Edge2 = edge2,
			Normal = if normal.Magnitude > 0 then normal.Unit else Vector3.zero,
		})
	end

	mesh:Destroy()

	return triangles, bottom, top
end

local function cast(triangles: { Triangle }, origin: Vector3, direction: Vector3, reach: number): (number?, Vector3?)
	local nearest: number? = nil
	local facing: Vector3? = nil

	for _, triangle in triangles do
		local a, edge1, edge2 = triangle.Origin, triangle.Edge1, triangle.Edge2
		local p = direction:Cross(edge2)
		local determinant = edge1:Dot(p)
		if math.abs(determinant) < 1e-9 then continue end

		local inverse = 1 / determinant
		local s = origin - a
		local u = s:Dot(p) * inverse
		if u < 0 or u > 1 then continue end

		local q = s:Cross(edge1)
		local v = direction:Dot(q) * inverse
		if v < 0 or u + v > 1 then continue end

		local distance = edge2:Dot(q) * inverse

		if distance > 1e-4 and distance < reach and (not nearest or distance < nearest) then
			nearest = distance
			facing = triangle.Normal
		end
	end

	return nearest, facing
end

function Measure.Scale(placed: Placed): Vector3?
	local fit = Config.Fit
	local triangles, bottom, top = trianglesOf(placed)
	if not triangles then return nil end

	local half = placed.Slot.Size / 2
	local low = math.max(-half.Y, bottom + fit.Rim)
	local high = math.min(half.Y, top - fit.Rim)
	local need = { X = 1, Z = 1 }

	if high <= low then return Vector3.one end

	for _, axis in { "X", "Z" } do
		local depth = if axis == "X" then half.X else half.Z
		local width = if axis == "X" then half.Z else half.X

		for _, sign in { -1, 1 } do
			local normal = if axis == "X" then Vector3.new(sign, 0, 0) else Vector3.new(0, 0, sign)

			for row = 0, fit.Rows - 1 do
				local y = low + (high - low) * row / (fit.Rows - 1)

				for column = 0, fit.Columns - 1 do
					local across = (column / (fit.Columns - 1) * 2 - 1) * width * fit.Edge
					local origin = if axis == "X"
						then Vector3.new(sign * depth, y, across)
						else Vector3.new(across, y, sign * depth)

					if cast(triangles, origin, normal, fit.Reach) then continue end

					local wall, facing = cast(triangles, origin, -normal, depth * fit.Wall)
					if not wall or not facing or facing:Dot(normal) < fit.Facing then continue end

					need[axis] = math.max(need[axis], (depth + fit.Margin) / (depth - wall))
				end
			end
		end
	end

	return Vector3.new(math.min(need.X, fit.MaxScale), 1, math.min(need.Z, fit.MaxScale))
end

function Measure.Bake(): string
	local folder = ServerStorage:FindFirstChild(Config.Folder)
	if not folder then return `ServerStorage.{Config.Folder} is missing` end

	local lines = {}

	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then continue end

		local placed, problem = Layout.Read(model)

		if not placed then
			table.insert(lines, `{model.Name}: {problem}`)
			continue
		end

		for _, piece in placed do
			local scale = Measure.Scale(piece)

			if scale then
				piece.Source:SetAttribute(Config.ScaleAttribute, scale)
			end

			table.insert(lines, `{model.Name}.{piece.Source.Name}: {if scale then string.format("%.2f x %.2f", scale.X, scale.Z) else "mesh unreadable"}`)
			task.wait()
		end
	end

	return table.concat(lines, "\n")
end

return Measure
