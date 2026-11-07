local Config = require("./Config")

local Render = {}

local function visualsFolder(): Instance
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Visuals") or workspace
end

local function attachment(name: string): Attachment
	local point = Instance.new("Attachment")
	point.Name = name
	point.Parent = workspace.Terrain
	return point
end

local function marker(style): BasePart?
	local spec = style.Marker
	if typeof(spec) ~= "table" then return nil end

	local part = Instance.new("Part")
	part.Name = Config.Names.Marker
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(spec.Thickness or 0.04, spec.Diameter or 0.5, spec.Diameter or 0.5)
	part.Color = spec.Color or style.Color or Color3.new(1, 1, 1)
	part.Material = spec.Material or Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = visualsFolder()

	return part
end

function Render.Create(style)
	local start = attachment(Config.Names.Start)
	local finish = attachment(Config.Names.Finish)
	local width = style.Width or {}

	local beam = Instance.new("Beam")
	beam.Name = Config.Names.Beam
	beam.Attachment0 = start
	beam.Attachment1 = finish
	beam.FaceCamera = true
	beam.Segments = style.Segments or 24
	beam.Width0 = width.Start or 0.06
	beam.Width1 = width.Finish or width.Start or 0.06
	beam.Color = ColorSequence.new(style.Color or Color3.new(1, 1, 1))
	beam.LightEmission = style.LightEmission or 0
	beam.LightInfluence = style.LightInfluence or 0
	beam.Texture = style.Texture or ""
	beam.TextureMode = style.TextureMode or Enum.TextureMode.Stretch
	beam.TextureLength = style.TextureLength or 1
	beam.TextureSpeed = style.TextureSpeed or 0
	beam.Enabled = false
	beam.Parent = workspace.Terrain

	return {
		style = style,
		start = start,
		finish = finish,
		beam = beam,
		marker = marker(style),
		alpha = -1,
	}
end

function Render.Place(parts, startFrame: CFrame, finishFrame: CFrame, curve0: number, curve1: number)
	parts.start.CFrame = startFrame
	parts.finish.CFrame = finishFrame
	parts.beam.CurveSize0 = curve0
	parts.beam.CurveSize1 = curve1
end

function Render.Mark(parts, result: RaycastResult?)
	local part = parts.marker
	if not part then return end

	parts.marked = result ~= nil
	if not result then
		part.Transparency = 1
		return
	end

	local normal = result.Normal
	local reference = if math.abs(normal.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local lift = parts.style.Marker.Lift or 0.02

	part.CFrame = CFrame.fromMatrix(result.Position + normal * lift, normal, normal:Cross(reference).Unit)
	part.Transparency = parts.markTransparency or 1
end

local function scaled(value: number, alpha: number): number
	return 1 - (1 - value) * alpha
end

function Render.Fade(parts, alpha: number)
	if math.abs(alpha - parts.alpha) < Config.Refade and not (alpha == 1 and parts.alpha ~= 1) then return end

	parts.alpha = alpha

	local keys = {}

	for _, key in parts.style.Transparency or { { 0, 0.5 }, { 1, 1 } } do
		table.insert(keys, NumberSequenceKeypoint.new(key[1], scaled(key[2], alpha)))
	end

	parts.beam.Transparency = NumberSequence.new(keys)

	local spec = parts.style.Marker
	if typeof(spec) == "table" then
		parts.markTransparency = scaled(spec.Transparency or 0.5, alpha)

		if parts.marked then
			parts.marker.Transparency = parts.markTransparency
		end
	end
end

function Render.Show(parts, visible: boolean)
	if parts.beam.Enabled ~= visible then
		parts.beam.Enabled = visible
	end

	if not visible and parts.marker then
		parts.marker.Transparency = 1
		parts.marked = false
	end
end

function Render.Destroy(parts)
	parts.beam:Destroy()
	parts.start:Destroy()
	parts.finish:Destroy()

	if parts.marker then
		parts.marker:Destroy()
	end
end

return Render
