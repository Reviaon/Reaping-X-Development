local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))

local Config = require("./Config")
local Types = require("./Types")

type Tinted = {
	Emitter: ParticleEmitter,
	Authored: ColorSequence,
	Shade: number,
}

type Copy = {
	Part: BasePart,
	Emitters: { Tinted },
}

type Kind = {
	Copies: { Copy },
	Next: number,
}

local Prints = {}

local kinds: { [string]: Kind } = {}

local function find(root: Instance, path: { string }): Instance?
	local found: Instance? = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function brightness(color: Color3): number
	return math.max(color.R, color.G, color.B)
end

local function copyOf(source: BasePart, parent: Instance): Copy
	local part = source:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Parent = parent

	local emitters: { Tinted } = {}
	local brightest = 0

	for _, emitter in part:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			brightest = math.max(brightest, brightness(emitter.Color.Keypoints[1].Value))
		end
	end

	for _, emitter in part:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			local grey = brightness(emitter.Color.Keypoints[1].Value)
			table.insert(emitters, { Emitter = emitter, Authored = emitter.Color, Shade = if brightest > 0 then grey / brightest else 1 })
		end
	end

	return { Part = part, Emitters = emitters }
end

local function kindOf(name: string): Kind?
	local cached = kinds[name]
	if cached then return cached end

	local assets = find(ReplicatedStorage, Config.Assets)
	local parent = find(workspace, Config.Visuals)
	local source = assets and assets:FindFirstChild(Config.Kinds[name] or "")

	if not source or not source:IsA("BasePart") or not parent then return nil end

	local kind: Kind = { Copies = {}, Next = 0 }

	for _ = 1, Config.PrintPool do
		table.insert(kind.Copies, copyOf(source, parent))
	end

	kinds[name] = kind

	return kind
end

local function tint(sequence: ColorSequence, color: Color3, shade: number): ColorSequence
	local keypoints = {}

	for _, keypoint in sequence.Keypoints do
		local value = keypoint.Value
		local ratio = if brightness(value) > 0 then brightness(value) / brightness(sequence.Keypoints[1].Value) else 1
		local scale = math.clamp(shade * ratio, 0, 1)

		table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, Color3.new(color.R * scale, color.G * scale, color.B * scale)))
	end

	return ColorSequence.new(keypoints)
end

function Prints.Step(ground: Types.Ground, heading: Vector3)
	local kind = kindOf(ground.Kind) or kindOf(Config.Fallback)
	if not kind then return end

	kind.Next = kind.Next % #kind.Copies + 1

	local copy = kind.Copies[kind.Next]
	local up = ground.Normal
	local forward = heading - up * heading:Dot(up)

	if forward.Magnitude < 1e-3 then
		forward = up:Cross(Vector3.xAxis)
	end

	copy.Part.CFrame = CFrame.lookAt(ground.Position, ground.Position + forward.Unit, up)

	for _, tinted in copy.Emitters do
		tinted.Emitter.Color = tint(tinted.Authored, ground.Color, tinted.Shade)
	end

	Jloader.GlobalFunctions.ForgeVFX.emit(copy.Part)
end

return Prints
